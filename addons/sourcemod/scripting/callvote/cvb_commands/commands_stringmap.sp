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
		CReplyToCommand(client, "%t %t: sm_cvb_stringmap_check <player>", "Tag", "Usage");
		return Plugin_Handled;
	}

	char targetName[MAX_NAME_LENGTH];
	GetCmdArg(1, targetName, sizeof(targetName));

	int target = FindTarget(client, targetName, true, false);
	if (target == NO_INDEX)
		return Plugin_Handled;

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

	CReplyToCommand(client, "%t Checking StringMap cache for player %s [%s] (AccountID: %d)", "Tag", targetNameSafe, steamId2, accountId);

	PlayerBanInfo banInfo = new PlayerBanInfo(accountId);
	if (CVB_GetCacheStringMap(banInfo))
	{
		if (banInfo.BanType == 0)
			CReplyToCommand(client, "%t Player is cached as NOT BANNED in StringMap", "Tag");
		else
		{
			char banTypeStr[128];
			banInfo.GetBanTypeString(banTypeStr, sizeof(banTypeStr));
			CReplyToCommand(client, "%t Player is cached as BANNED in StringMap", "Tag");
			CReplyToCommand(client, "%t Ban Type: %s (%d)", "Tag", banTypeStr, banInfo.BanType);
		}
		delete banInfo;
		return Plugin_Handled;
	}

	CReplyToCommand(client, "%t Player is NOT FOUND in StringMap cache", "Tag");
	delete banInfo;
	return Plugin_Handled;
}

/**
 * Check player ban status in StringMap cache by SteamID (offline player)
 */
public Action Command_StringMapCheckOffline(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t: sm_cvb_stringmap_checkid <steamid>", "Tag", "Usage");
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
	{
		// Context has already been cleaned up by ValidateAndConvertSteamIDAsync
		return Plugin_Handled;
	}
	else if (validationResult == STEAMID_VALIDATION_SUCCESS)
	{
		// Validation was successful, continue immediately
		Continue_StringMapCheckOffline_Async(context);
	}
	// For STEAMID_VALIDATION_ASYNC, the callback will handle continuation

	return Plugin_Handled;
}

/**
 * Remove player from StringMap cache (online player)
 */
public Action Command_StringMapRemove(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t: sm_cvb_stringmap_remove <player>", "Tag", "Usage");
		return Plugin_Handled;
	}

	char targetName[MAX_NAME_LENGTH];
	GetCmdArg(1, targetName, sizeof(targetName));

	int target = FindTarget(client, targetName, true, false);
	if (target == NO_INDEX)
		return Plugin_Handled;

	if (!IsValidClient(target))
	{
		CReplyToCommand(client, "%t %t", "Tag", "PlayerNotValid");
		return Plugin_Handled;
	}

	int accountId = GetSteamAccountID(target);
	char steamId2[MAX_AUTHID_LENGTH];
	GetClientAuthId(target, AuthId_Steam2, steamId2, sizeof(steamId2));

	char sAccountId[16];
	IntToString(accountId, sAccountId, sizeof(sAccountId));
	
	bool wasInCache = (g_smClientCache != null) ? g_smClientCache.Remove(sAccountId) : false;

	char targetNameSafe[MAX_NAME_LENGTH];
	GetClientName(target, targetNameSafe, sizeof(targetNameSafe));

	if (wasInCache)
	{
		CReplyToCommand(client, "%t StringMap cache cleared for player %s [%s] (AccountID: %d)", "Tag", targetNameSafe, steamId2, accountId);
		
		CVBLog.Debug("Admin %N cleared StringMap cache for player %N [%s] (AccountID: %d)", client, target, steamId2, accountId);
	}
	else
		CReplyToCommand(client, "%t Player %s [%s] was not found in StringMap cache", "Tag", targetNameSafe, steamId2);


	return Plugin_Handled;
}

/**
 * Remove player from StringMap cache by SteamID (offline player)
 */
public Action Command_StringMapRemoveOffline(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t: sm_cvb_stringmap_removeid <steamid>", "Tag", "Usage");
		return Plugin_Handled;
	}

	char steamId[64];
	GetCmdArg(1, steamId, sizeof(steamId));

	// Para el comando remove, usamos la factory de check ya que no necesitamos información adicional
	AsyncContext context = CreateAsyncContextForCheckOffline(client);
	if (context == null)
	{
		return Plugin_Handled;
	}
	
	// Actualizamos el tipo de continuación específico para remove
	context.ContinuationType = CONTINUE_STRINGMAP_REMOVE;

	SteamIDValidationResult validationResult = ValidateAndConvertSteamIDAsync(client, steamId, context);
	if (validationResult == STEAMID_VALIDATION_ERROR)
	{
		// Context has already been cleaned up by ValidateAndConvertSteamIDAsync
		return Plugin_Handled;
	}
	else if (validationResult == STEAMID_VALIDATION_SUCCESS)
	{
		// Validation was successful, continue immediately
		Continue_StringMapRemoveOffline_Async(context);
	}
	// For STEAMID_VALIDATION_ASYNC, the callback will handle continuation

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

	CReplyToCommand(admin, "%t Checking StringMap cache for SteamID %s (AccountID: %d)", "Tag", steamId2, accountId);

	PlayerBanInfo banInfo = new PlayerBanInfo(accountId);
	if (CVB_GetCacheStringMap(banInfo))
	{
		if (banInfo.BanType == 0)
			CReplyToCommand(admin, "%t ✅ SteamID is cached as NOT BANNED in StringMap", "Tag");
		else
		{
			char banTypeStr[128];
			banInfo.GetBanTypeString(banTypeStr, sizeof(banTypeStr));
			CReplyToCommand(admin, "%t ❌ SteamID is cached as BANNED in StringMap", "Tag");
			CReplyToCommand(admin, "%t Ban Type: %s (%d)", "Tag", banTypeStr, banInfo.BanType);
		}
		delete banInfo;
		delete context;
		return;
	}

	CReplyToCommand(admin, "%t ⚪ SteamID is NOT FOUND in StringMap cache", "Tag");
	delete banInfo;
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

	char sAccountId[16];
	IntToString(accountId, sAccountId, sizeof(sAccountId));
	
	bool wasInCache = (g_smClientCache != null) ? g_smClientCache.Remove(sAccountId) : false;

	if (wasInCache)
	{
		CReplyToCommand(admin, "%t StringMap cache cleared for SteamID %s (AccountID: %d)", "Tag", steamId2, accountId);
		CVBLog.Debug("Admin %N cleared StringMap cache for SteamID %s (AccountID: %d)", admin, steamId2, accountId);
	}
	else
		CReplyToCommand(admin, "%t SteamID %s was not found in StringMap cache", "Tag", steamId2);


	delete context;
}
