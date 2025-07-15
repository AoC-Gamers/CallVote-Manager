#if defined _cvb_commands_sqlite_included
	#endinput
#endif
#define _cvb_commands_sqlite_included

/**
 * Command to check a connected player's ban status in SQLite cache
 */
public Action Command_SQLiteCheck(int client, int args)
{
	if (g_hSQLiteDB == null)
	{
		CReplyToCommand(client, "%t %t", "Tag", "SQLiteNotAvailable");
		return Plugin_Handled;
	}

	if (args != 1)
	{
		CReplyToCommand(client, "%t sm_cvb_sqlite_check <player>", "Tag");
		return Plugin_Handled;
	}

	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	
	int target = FindTarget(client, arg, true, false);
	if (target == -1)
	{
		return Plugin_Handled;
	}

	int accountId = GetSteamAccountID(target);
	if (accountId <= 0)
	{
		CReplyToCommand(client, "%t %t", "Tag", "ErrorGettingTargetInfo");
		return Plugin_Handled;
	}

	char targetName[MAX_NAME_LENGTH];
	GetClientName(target, targetName, sizeof(targetName));
	
	AsyncContext context = new AsyncContext();
	context.AdminUserId = GetClientUserId(client);
	context.TargetAccountId = accountId;
	context.SetOriginalSteamId(targetName); // Store name for display
	
	CReplyToCommand(client, "%t %t", "Tag", "SQLiteCheckingCache", targetName);

	char query[256];
	FormatEx(query, sizeof(query), 
		"SELECT ban_type FROM callvote_bans_cache WHERE account_id = %d AND ttl_expires > strftime('%%s', 'now')", 
		accountId);
	
	SQL_TQuery(g_hSQLiteDB, SQLiteCheck_Callback, query, context);
	return Plugin_Handled;
}

/**
 * Command to check ban status by SteamID in SQLite cache
 */
public Action Command_SQLiteCheckOffline(int client, int args)
{
	if (g_hSQLiteDB == null)
	{
		CReplyToCommand(client, "%t %t", "Tag", "SQLiteNotAvailable");
		return Plugin_Handled;
	}

	if (args != 1)
	{
		CReplyToCommand(client, "%t sm_cvb_sqlite_checkid <steamid>", "Tag");
		return Plugin_Handled;
	}

	char steamId[64];
	GetCmdArg(1, steamId, sizeof(steamId));

	AsyncContext context = new AsyncContext();
	context.ContinuationType = CONTINUE_SQLITE_CHECK;
	
	if (!ValidateAndConvertSteamIDAsync(client, steamId, context))
	{
		// If validation fails immediately, context is cleaned up in ValidateAndConvertSteamIDAsync
		return Plugin_Handled;
	}

	// If we reach here, it means synchronous validation succeeded
	Continue_SQLiteCheckOffline_Async(context);
	return Plugin_Handled;
}

/**
 * Callback for SQLite check query results
 */
void SQLiteCheck_Callback(Database db, DBResultSet results, const char[] error, AsyncContext context)
{
	if (!context.IsValid()) {
		LogError("Invalid context received in SQLiteCheck callback");
		return;
	}

	int admin = GetClientOfUserId(context.AdminUserId);
	if (admin <= 0) {
		CVBLog.Debug("Admin disconnected during SQLite check operation");
		delete context;
		return;
	}

	char targetName[MAX_NAME_LENGTH];
	context.GetOriginalSteamId(targetName, sizeof(targetName));
    
	if (results == null)
	{
		CReplyToCommand(admin, "%t %t", "Tag", "SQLiteCheckError", error);
		delete context;
		return;
	}
	
	if (!results.FetchRow())
	{
		CReplyToCommand(admin, "%t %t", "Tag", "SQLiteCheckNotBanned", targetName);
		delete context;
		return;
	}
	
	int banType = results.FetchInt(0);
	
	char banTypeStr[128];
	GetBanTypeString(banType, banTypeStr, sizeof(banTypeStr));
	
	CReplyToCommand(admin, "%t %t", "Tag", "SQLiteCheckBanned", targetName);
	CReplyToCommand(admin, "%t %t", "Tag", "BanType", banTypeStr);
	CReplyToCommand(admin, "%t %t", "Tag", "CacheNote");
	
	delete context;
}

/**
 * Continue function for offline SQLite check after SteamID conversion
 */
void Continue_SQLiteCheckOffline_Async(AsyncContext context)
{
	int admin = GetClientOfUserId(context.AdminUserId);
	if (admin <= 0) {
		LogError("Admin disconnected during SQLite check operation");
		delete context;
		return;
	}

	int targetAccountId = context.TargetAccountId;
	char targetSteamId[MAX_AUTHID_LENGTH], originalSteamId[64];
	context.GetTargetSteamId(targetSteamId, sizeof(targetSteamId));
	context.GetOriginalSteamId(originalSteamId, sizeof(originalSteamId));

	CReplyToCommand(admin, "%t %t", "Tag", "SQLiteCheckingCache", originalSteamId);

	char query[256];
	FormatEx(query, sizeof(query), 
		"SELECT ban_type FROM callvote_bans_cache WHERE account_id = %d AND ttl_expires > strftime('%%s', 'now')", 
		targetAccountId);
	
	SQL_TQuery(g_hSQLiteDB, SQLiteCheckOffline_Callback, query, context);
}

/**
 * Callback for offline SQLite check query results
 */
void SQLiteCheckOffline_Callback(Database db, DBResultSet results, const char[] error, AsyncContext context)
{
	if (!context.IsValid()) {
		LogError("Invalid context received in SQLiteCheckOffline callback");
		return;
	}

	int admin = GetClientOfUserId(context.AdminUserId);
	if (admin <= 0) {
		CVBLog.Debug("Admin disconnected during SQLite check operation");
		delete context;
		return;
	}

	char targetSteamId[MAX_AUTHID_LENGTH], originalSteamId[64];
	context.GetTargetSteamId(targetSteamId, sizeof(targetSteamId));
	context.GetOriginalSteamId(originalSteamId, sizeof(originalSteamId));
    
	if (results == null)
	{
		CReplyToCommand(admin, "%t %t", "Tag", "SQLiteCheckError", error);
		delete context;
		return;
	}
	
	if (!results.FetchRow())
	{
		CReplyToCommand(admin, "%t %t", "Tag", "SQLiteCheckNotBanned", originalSteamId);
		delete context;
		return;
	}
	
	int banType = results.FetchInt(0);
	
	char banTypeStr[128];
	GetBanTypeString(banType, banTypeStr, sizeof(banTypeStr));
	
	CReplyToCommand(admin, "%t %t", "Tag", "SQLiteCheckBanned", targetSteamId);
	CReplyToCommand(admin, "%t %t", "Tag", "BanType", banTypeStr);
	CReplyToCommand(admin, "%t %t", "Tag", "CacheNote");
	
	delete context;
}
