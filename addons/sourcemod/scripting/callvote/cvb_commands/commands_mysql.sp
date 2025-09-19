#if defined _cvb_commands_mysql_included
	#endinput
#endif
#define _cvb_commands_mysql_included


public Action Command_Ban(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		if (client == SERVER_INDEX)
		{
			CReplyToCommand(client, "%t %t: sm_cvb_ban <#userid|name> <bantype> [duration] [reason]", "Tag", "Usage");
			return Plugin_Handled;
		}
		
		ShowMainBanPanel(client);
		return Plugin_Handled;
	}

	if (args < 2)
	{
		CReplyToCommand(client, "%t %t: sm_cvb_ban <#userid|name> <bantype> [duration] [reason]", "Tag", "Usage");
		CReplyToCommand(client, "%t %t", "Tag", "BanTypes");
		CReplyToCommand(client, "%t %t", "Tag", "TypeReasonsCommandForHelp");
		return Plugin_Handled;
	}
	
	char sTarget[MAX_NAME_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	int target = FindTarget(client, sTarget, false, false);

	if (target == NO_INDEX)
	{
		CReplyToCommand(client, "%t %t: sm_cvb_ban <#userid|name> <bantype> [duration] [reason]", "Tag", "Usage");
		return Plugin_Handled;
	}

	if (!IsValidClient(target))
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidPlayer");
		CReplyToCommand(client, "%t %t: sm_cvb_ban <#userid|name> <bantype> [duration] [reason]", "Tag", "Usage");
		return Plugin_Handled;
	}
	
	int
		banType = GetCmdArgInt(2),
		durationMinutes = (args >= 3) ? GetCmdArgInt(3) : 0;
	char sReason[256] = "";

	if (args >= 4)
	{
		GetCmdArgString(sReason, sizeof(sReason));
		int pos = 0;
		for (int i = 0; i < 3; i++)
		{
			pos = FindCharInString(sReason[pos], ' ');
			if (pos == -1) break;
			pos++;
		}

		if (pos > 0 && pos < strlen(sReason))
			strcopy(sReason, sizeof(sReason), sReason[pos]);
	}
	
	char processedReason[256];
	CVB_GetBanReason(sReason, processedReason, sizeof(processedReason));
	
	if (banType <= 0 || banType > view_as<int>(VOTE_ALL))
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidBanType", banType, view_as<int>(VOTE_ALL));
		CReplyToCommand(client, "%t %t: sm_cvb_ban <#userid|name> <bantype> [duration] [reason]", "Tag", "Usage");
		return Plugin_Handled;
	}

	if (durationMinutes < 0)
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidDuration", durationMinutes);
		CReplyToCommand(client, "%t %t: sm_cvb_ban <#userid|name> <bantype> [duration] [reason]", "Tag", "Usage");
		return Plugin_Handled;
	}
	
	ProcessBan(client, target, banType, durationMinutes, processedReason);
	return Plugin_Handled;
}

public Action Command_BanOffline(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (args < 2)
	{
		CReplyToCommand(client, "%t %t: sm_cvb_banid <steamid> <type> <duration> [reason]", "Tag", "Usage");
		CReplyToCommand(client, "%t %t", "Tag", "SupportedSteamIDFormats");
		CReplyToCommand(client, "%t %t", "Tag", "BanTypes");
		CReplyToCommand(client, "%t %t", "Tag", "TypeReasonsCommandForHelp");
		return Plugin_Handled;
	}
    
	char
		sSteamId[MAX_AUTHID_LENGTH],
		sReason[256] = "Admin ban",
		processedReason[256];
	GetCmdArg(1, sSteamId, sizeof(sSteamId));
	int
		banType = GetCmdArgInt(2),
		durationMinutes = (args >= 3) ? GetCmdArgInt(3) : 0;

	if (args >= 4)
		GetCmdArgString(sReason, sizeof(sReason));

	CVB_GetBanReason(sReason, processedReason, sizeof(processedReason));

	if (banType <= 0 || banType > view_as<int>(VOTE_ALL))
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidBanType", banType, view_as<int>(VOTE_ALL));
		return Plugin_Handled;
	}

	if (durationMinutes < 0)
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidDuration", durationMinutes);
		return Plugin_Handled;
	}

	AsyncContext context = CreateAsyncContextForBanOffline(GetClientUserId(client), banType, durationMinutes, processedReason);

	SteamIDValidationResult validationResult = ValidateAndConvertSteamIDAsync(client, sSteamId, context);
	if (validationResult == STEAMID_VALIDATION_SUCCESS)
		Continue_BanOffline_Async(context);

	return Plugin_Handled;
}

public Action Command_Unban(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		if (client == SERVER_INDEX)
		{
			CReplyToCommand(client, "%t %t: sm_cvb_unban <#userid|name>", "Tag", "Usage");
			return Plugin_Handled;
		}

		if (!HasBannedPlayersOnline())
		{
			CReplyToCommand(client, "%t %t", "Tag", "NoBannedPlayersOnline");
			CReplyToCommand(client, "%t If you want to unban a specific player, use: sm_cvb_unban <#userid|name>", "Tag");
			CReplyToCommand(client, "%t Or to unban by SteamID: sm_cvb_unbanid <steamid>", "Tag");
			return Plugin_Handled;
		}

		ShowMainUnbanPanel(client);
		return Plugin_Handled;
	}
	
	char sTarget[MAX_NAME_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	int target = FindTarget(client, sTarget, false, false);

	if (target == NO_INDEX)
	{
		CReplyToCommand(client, "%t %t: sm_cvb_unban <#userid|name>", "Tag", "Usage");
		return Plugin_Handled;
	}

	if (!IsValidClient(target))
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidPlayer");
		CReplyToCommand(client, "%t %t: sm_cvb_unban <#userid|name>", "Tag", "Usage");
		return Plugin_Handled;
	}
	
	if (!IsClientBannedWithInfo(target))
	{
		char targetName[MAX_NAME_LENGTH];
		GetClientName(target, targetName, sizeof(targetName));
		CReplyToCommand(client, "%t %t", "Tag", "PlayerNotBanned", targetName);
		return Plugin_Handled;
	}

	ApplyUnbanToPlayer(client, target);
	return Plugin_Handled;
}

public Action Command_UnbanOffline(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CReplyToCommand(client, "%t %t: sm_cvb_unbanid <steamid>", "Tag", "Usage");
		CReplyToCommand(client, "%t %t", "Tag", "SupportedSteamIDFormats");
		return Plugin_Handled;
	}
	
	char sSteamId[MAX_AUTHID_LENGTH];
	GetCmdArg(1, sSteamId, sizeof(sSteamId));

	AsyncContext context = CreateAsyncContextForUnbanOffline(GetClientUserId(client));

	SteamIDValidationResult validationResult = ValidateAndConvertSteamIDAsync(client, sSteamId, context);
	if (validationResult == STEAMID_VALIDATION_SUCCESS)
		Continue_UnbanOffline_Async(context);

	return Plugin_Handled;
}

public Action Command_Check(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		if (client == SERVER_INDEX)
		{
			CReplyToCommand(client, "%t %t: sm_cvb_check <#userid|name>", "Tag", "Usage");
			return Plugin_Handled;
		}
		
		ShowMainCheckPanel(client);
		return Plugin_Handled;
	}
	
	char sTarget[MAX_NAME_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	int target = FindTarget(client, sTarget, false, false);

	if (target == NO_INDEX)
	{
		CReplyToCommand(client, "%t %t: sm_cvb_check <#userid|name>", "Tag", "Usage");
		return Plugin_Handled;
	}

	if (!IsValidClient(target))
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidPlayer");
		CReplyToCommand(client, "%t %t: sm_cvb_check <#userid|name>", "Tag", "Usage");
		return Plugin_Handled;
	}

	PlayerBanInfo playerInfo = new PlayerBanInfo(GetSteamAccountID(target));

	CVB_GetCacheStringMap(playerInfo);
	playerInfo.AdminAccountId = GetSteamAccountID(client);
	playerInfo.DbSource = SourceDB_MySQL;
	playerInfo.CommandReplySource = GetCmdReplySource();
	CVB_UpdateCacheStringMap(playerInfo);
	
	CReplyToCommand(client, "%t %t", "Tag", "BanStatusCheckingPlayer", target);
	CVB_CheckMysqlFullBan(playerInfo);
	delete playerInfo;
	return Plugin_Handled;
}

public Action Command_CheckOffline(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CReplyToCommand(client, "%t %t: sm_cvb_checkid <steamid>", "Tag", "Usage");
		CReplyToCommand(client, "%t %t", "Tag", "SupportedSteamIDFormats");
		return Plugin_Handled;
	}
	
	char sSteamId[MAX_AUTHID_LENGTH];
	GetCmdArg(1, sSteamId, sizeof(sSteamId));

	AsyncContext context = CreateAsyncContextForCheckOffline(client);
	if (context == null)
	{
		return Plugin_Handled;
	}

	SteamIDValidationResult validationResult = ValidateAndConvertSteamIDAsync(client, sSteamId, context);
	if (validationResult == STEAMID_VALIDATION_ERROR)
		return Plugin_Handled;
	else if (validationResult == STEAMID_VALIDATION_SUCCESS)
		Continue_CheckOffline_Async(context);

	return Plugin_Handled;
}

/**
 * Checks if there are any banned players currently online.
 *
 * Iterates through all possible client slots and determines if any valid client
 * is banned using additional information. Returns true if at least one banned
 * player is found online, otherwise returns false.
 *
 * @return bool      True if a banned player is online, false otherwise.
 */
bool HasBannedPlayersOnline()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && IsClientBannedWithInfo(i))
            return true;
    }
    return false;
}