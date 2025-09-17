#if defined _cvb_commands_sqlite_included
	#endinput
#endif
#define _cvb_commands_sqlite_included

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
	if (target == NO_INDEX)
		return Plugin_Handled;

	int accountId = GetSteamAccountID(target);

	char targetName[MAX_NAME_LENGTH];
	GetClientName(target, targetName, sizeof(targetName));
	
	PlayerBanInfo banInfo = new PlayerBanInfo(accountId);
	
	CReplyToCommand(client, "%t %t", "Tag", "SQLiteCheckingCache", targetName);

	if (CVB_CheckSQLiteBan(banInfo))
	{
		char banTypeStr[128];
		banInfo.GetBanTypeString(banTypeStr, sizeof(banTypeStr));
		
		CReplyToCommand(client, "%t %t", "Tag", "SQLiteCheckBanned", targetName);
		CReplyToCommand(client, "%t %t", "Tag", "BanType", banTypeStr);
		CReplyToCommand(client, "%t %t", "Tag", "CacheNote");
	}
	else
	{
		CReplyToCommand(client, "%t %t", "Tag", "SQLiteCheckNotBanned", targetName);
	}
	
	delete banInfo;
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

	AsyncContext context = CreateAsyncContextForCheckOffline(client);
	if (context == null)
	{
		return Plugin_Handled;
	}
	
	SteamIDValidationResult validationResult = ValidateAndConvertSteamIDAsync(client, steamId, context);
	if (validationResult == STEAMID_VALIDATION_ERROR)
		return Plugin_Handled;
	else if (validationResult == STEAMID_VALIDATION_SUCCESS)
		Continue_SQLiteCheckOffline_Async(context);

	return Plugin_Handled;
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

	PlayerBanInfo banInfo = new PlayerBanInfo(targetAccountId);

	if (CVB_CheckSQLiteBan(banInfo))
	{
		char banTypeStr[128];
		banInfo.GetBanTypeString(banTypeStr, sizeof(banTypeStr));
		
		CReplyToCommand(admin, "%t %t", "Tag", "SQLiteCheckBanned", targetSteamId);
		CReplyToCommand(admin, "%t %t", "Tag", "BanType", banTypeStr);
		CReplyToCommand(admin, "%t %t", "Tag", "CacheNote");
	}
	else
		CReplyToCommand(admin, "%t %t", "Tag", "SQLiteCheckNotBanned", targetSteamId);

	
	delete banInfo;
	delete context;
}

