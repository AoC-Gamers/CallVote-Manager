#if defined _cvb_commands_stringmap_included
	#endinput
#endif
#define _cvb_commands_stringmap_included

/**
 * Check player ban status in StringMap cache (online player)
 */
public Action Command_StringMapCheck(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t", "Tag", "UsageStringMapCheck");
		return Plugin_Handled;
	}

	char targetName[MAX_NAME_LENGTH];
	GetCmdArg(1, targetName, sizeof(targetName));

	int target = FindTarget(client, targetName, true, false);
	if (target == -1)
	{
		return Plugin_Handled;
	}

	if (!IsValidClient(target))
	{
		CReplyToCommand(client, "%t %t", "Tag", "PlayerNotValid");
		return Plugin_Handled;
	}

	int accountId = GetSteamAccountID(target);
	char steamId2[MAX_AUTHID_LENGTH];
	GetClientAuthId(target, AuthId_Steam2, steamId2, sizeof(steamId2));

	char targetNameSafe[MAX_NAME_LENGTH];
	GetClientName(target, targetNameSafe, sizeof(targetNameSafe));

	CReplyToCommand(client, "%t Checking StringMap cache for player %s [%s] (AccountID: %d)", 
		"Tag", targetNameSafe, steamId2, accountId);

	// Check StringMap cache for non-banned players
	if (CheckStringMapCache(accountId))
	{
		CReplyToCommand(client, "%t ✅ Player is cached as NOT BANNED in StringMap", "Tag");
		return Plugin_Handled;
	}

	// Check PlayerBans cache for banned players
	int banType = GetCachedBanType(accountId);
	if (banType > 0)
	{
		char banTypeStr[128];
		GetBanTypeString(banType, banTypeStr, sizeof(banTypeStr));
		CReplyToCommand(client, "%t ❌ Player is cached as BANNED in StringMap", "Tag");
		CReplyToCommand(client, "%t Ban Type: %s (%d)", "Tag", banTypeStr, banType);
		return Plugin_Handled;
	}

	CReplyToCommand(client, "%t ⚪ Player is NOT FOUND in StringMap cache", "Tag");
	return Plugin_Handled;
}

/**
 * Check player ban status in StringMap cache by SteamID (offline player)
 */
public Action Command_StringMapCheckOffline(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t", "Tag", "UsageStringMapCheckID");
		return Plugin_Handled;
	}

	char steamId[64];
	GetCmdArg(1, steamId, sizeof(steamId));

	AsyncContext context = new AsyncContext();
	context.ContinuationType = CONTINUE_STRINGMAP_CHECK;

	if (!ValidateAndConvertSteamIDAsync(client, steamId, context))
	{
		// If validation fails immediately, clean up
		if (context.IsValid())
		{
			delete context;
		}
		return Plugin_Handled;
	}

	// If we reach here, validation was successful and we can proceed immediately
	Continue_StringMapCheckOffline_Async(context);
	return Plugin_Handled;
}

/**
 * Remove player from StringMap cache (online player)
 */
public Action Command_StringMapRemove(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t", "Tag", "UsageStringMapRemove");
		return Plugin_Handled;
	}

	char targetName[MAX_NAME_LENGTH];
	GetCmdArg(1, targetName, sizeof(targetName));

	int target = FindTarget(client, targetName, true, false);
	if (target == -1)
	{
		return Plugin_Handled;
	}

	if (!IsValidClient(target))
	{
		CReplyToCommand(client, "%t %t", "Tag", "PlayerNotValid");
		return Plugin_Handled;
	}

	int accountId = GetSteamAccountID(target);
	char steamId2[MAX_AUTHID_LENGTH];
	GetClientAuthId(target, AuthId_Steam2, steamId2, sizeof(steamId2));

	// Remove from StringMap cache only
	char sAccountId[16];
	IntToString(accountId, sAccountId, sizeof(sAccountId));
	
	bool wasInNonBanned = g_hCacheStringMap.Remove(sAccountId);
	bool wasInBanned = g_hPlayerBans.Remove(sAccountId);

	char targetNameSafe[MAX_NAME_LENGTH];
	GetClientName(target, targetNameSafe, sizeof(targetNameSafe));

	if (wasInNonBanned || wasInBanned)
	{
		CReplyToCommand(client, "%t StringMap cache cleared for player %s [%s] (AccountID: %d)", 
			"Tag", targetNameSafe, steamId2, accountId);
		
		CVBLog.Debug("Admin %N cleared StringMap cache for player %N [%s] (AccountID: %d)", 
			client, target, steamId2, accountId);
	}
	else
	{
		CReplyToCommand(client, "%t Player %s [%s] was not found in StringMap cache", 
			"Tag", targetNameSafe, steamId2);
	}

	return Plugin_Handled;
}

/**
 * Remove player from StringMap cache by SteamID (offline player)
 */
public Action Command_StringMapRemoveOffline(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t", "Tag", "UsageStringMapRemoveID");
		return Plugin_Handled;
	}

	char steamId[64];
	GetCmdArg(1, steamId, sizeof(steamId));

	AsyncContext context = new AsyncContext();
	context.ContinuationType = CONTINUE_STRINGMAP_REMOVE;

	if (!ValidateAndConvertSteamIDAsync(client, steamId, context))
	{
		// If validation fails immediately, clean up
		if (context.IsValid())
		{
			delete context;
		}
		return Plugin_Handled;
	}

	// If we reach here, validation was successful and we can proceed immediately
	Continue_StringMapRemoveOffline_Async(context);
	return Plugin_Handled;
}

/**
 * Continuation function for StringMap check by SteamID
 */
void Continue_StringMapCheckOffline_Async(AsyncContext context)
{
	int admin = GetClientOfUserId(context.AdminUserId);
	if (admin <= 0)
	{
		LogError("Admin disconnected during StringMap check operation");
		delete context;
		return;
	}

	int accountId = context.TargetAccountId;
	char steamId2[MAX_AUTHID_LENGTH];
	context.GetTargetSteamId(steamId2, sizeof(steamId2));

	CReplyToCommand(admin, "%t Checking StringMap cache for SteamID %s (AccountID: %d)", 
		"Tag", steamId2, accountId);

	// Check StringMap cache for non-banned players
	if (CheckStringMapCache(accountId))
	{
		CReplyToCommand(admin, "%t ✅ SteamID is cached as NOT BANNED in StringMap", "Tag");
		delete context;
		return;
	}

	// Check PlayerBans cache for banned players
	int banType = GetCachedBanType(accountId);
	if (banType > 0)
	{
		char banTypeStr[128];
		GetBanTypeString(banType, banTypeStr, sizeof(banTypeStr));
		CReplyToCommand(admin, "%t ❌ SteamID is cached as BANNED in StringMap", "Tag");
		CReplyToCommand(admin, "%t Ban Type: %s (%d)", "Tag", banTypeStr, banType);
		delete context;
		return;
	}

	CReplyToCommand(admin, "%t ⚪ SteamID is NOT FOUND in StringMap cache", "Tag");
	delete context;
}

/**
 * Continuation function for StringMap removal by SteamID
 */
void Continue_StringMapRemoveOffline_Async(AsyncContext context)
{
	int admin = GetClientOfUserId(context.AdminUserId);
	if (admin <= 0)
	{
		LogError("Admin disconnected during StringMap remove operation");
		delete context;
		return;
	}

	int accountId = context.TargetAccountId;
	char steamId2[MAX_AUTHID_LENGTH];
	context.GetTargetSteamId(steamId2, sizeof(steamId2));

	// Remove from StringMap cache only
	char sAccountId[16];
	IntToString(accountId, sAccountId, sizeof(sAccountId));
	
	bool wasInNonBanned = g_hCacheStringMap.Remove(sAccountId);
	bool wasInBanned = g_hPlayerBans.Remove(sAccountId);

	if (wasInNonBanned || wasInBanned)
	{
		CReplyToCommand(admin, "%t StringMap cache cleared for SteamID %s (AccountID: %d)", 
			"Tag", steamId2, accountId);
		
		CVBLog.Debug("Admin %N cleared StringMap cache for SteamID %s (AccountID: %d)", 
			admin, steamId2, accountId);
	}
	else
	{
		CReplyToCommand(admin, "%t SteamID %s was not found in StringMap cache", 
			"Tag", steamId2);
	}

	delete context;
}
