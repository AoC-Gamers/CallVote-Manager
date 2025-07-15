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
	
	// Caso 1: Sin argumentos
	if (args < 1)
	{
		// Si es consola, mostrar uso correcto
		if (client == 0)
		{
			CReplyToCommand(client, "Use: sm_cvb_ban <#userid|name> <bantype> [duration] [reason]");
			return Plugin_Handled;
		}
		
		// Si es un jugador, abrir panel
		ShowMainBanPanel(client);
		return Plugin_Handled;
	}
	
	// Caso 2: Con argumentos - validar parámetros mínimos
	if (args < 2)
	{
		CReplyToCommand(client, "Use: sm_cvb_ban <#userid|name> <bantype> [duration] [reason]");
		CReplyToCommand(client, "%t %t", "Tag", "BanTypes");
		return Plugin_Handled;
	}
	
	// Verificar si el nombre/ID es válido
	char sTarget[MAX_NAME_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	int target = FindTarget(client, sTarget, false, false);

	// Si FindTarget devuelve -1, significa que no encontró el jugador
	if (target == -1)
	{
		CReplyToCommand(client, "Use: sm_cvb_ban <#userid|name> <bantype> [duration] [reason]");
		return Plugin_Handled;
	}

	// Verificar que el target sea válido y esté en el juego
	if (!IsValidClient(target))
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidPlayer");
		CReplyToCommand(client, "Use: sm_cvb_ban <#userid|name> <bantype> [duration] [reason]");
		return Plugin_Handled;
	}
	
	// Obtener parámetros del ban
	int banType = GetCmdArgInt(2);
	int durationMinutes = (args >= 3) ? GetCmdArgInt(3) : 0;
	char sReason[256] = "Admin ban via command";
	if (args >= 4)
	{
		GetCmdArgString(sReason, sizeof(sReason));
		// Remover los primeros argumentos de la razón
		int pos = 0;
		for (int i = 0; i < 3; i++)
		{
			pos = FindCharInString(sReason[pos], ' ');
			if (pos == -1) break;
			pos++;
		}
		if (pos > 0 && pos < strlen(sReason))
		{
			strcopy(sReason, sizeof(sReason), sReason[pos]);
		}
	}

	// Validar parámetros del ban
	if (banType <= 0 || banType > view_as<int>(VOTE_ALL))
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidBanType", banType, view_as<int>(VOTE_ALL));
		CReplyToCommand(client, "Use: sm_cvb_ban <#userid|name> <bantype> [duration] [reason]");
		return Plugin_Handled;
	}

	if (durationMinutes < 0)
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidDuration", durationMinutes);
		CReplyToCommand(client, "Use: sm_cvb_ban <#userid|name> <bantype> [duration] [reason]");
		return Plugin_Handled;
	}
	
	// Todo está correcto, aplicar el ban
	ApplyBanToPlayer(client, target, banType, durationMinutes, sReason);
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
		CReplyToCommand(client, "%t %t", "Tag", "UsageCommandBan", "sm_cvb_banid");
		CReplyToCommand(client, "%t %t", "Tag", "SupportedSteamIDFormats");
		CReplyToCommand(client, "%t %t", "Tag", "BanTypes");
		return Plugin_Handled;
	}
    
	char sSteamId[MAX_AUTHID_LENGTH];
	char sReason[256] = "Admin ban";
	GetCmdArg(1, sSteamId, sizeof(sSteamId));
	int banType = GetCmdArgInt(2);
	int durationMinutes = (args >= 3) ? GetCmdArgInt(3) : 0;
	if (args >= 4)
		GetCmdArgString(sReason, sizeof(sReason));

	// Validate ban parameters
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

	AsyncContext context = new AsyncContext();
	context.ContinuationType = CONTINUE_BAN_OFFLINE;
	context.BanType = banType;
	context.DurationMinutes = durationMinutes;
	context.SetReason(sReason);

	if (ValidateAndConvertSteamIDAsync(client, sSteamId, context))
	{
		Continue_BanOffline_Async(context);
	}

	return Plugin_Handled;
}

public Action Command_Unban(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}
	
	// Caso 1: Sin argumentos
	if (args < 1)
	{
		// Si es consola, mostrar uso correcto
		if (client == 0)
		{
			CReplyToCommand(client, "Use: sm_cvb_unban <#userid|name>");
			return Plugin_Handled;
		}
		
		// Si es un jugador, abrir panel
		ShowMainUnbanPanel(client);
		return Plugin_Handled;
	}
	
	// Caso 2: Con argumentos - verificar si el nombre/ID es válido
	char sTarget[MAX_NAME_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	int target = FindTarget(client, sTarget, false, false);

	// Si FindTarget devuelve -1, significa que no encontró el jugador
	if (target == -1)
	{
		CReplyToCommand(client, "Use: sm_cvb_unban <#userid|name>");
		return Plugin_Handled;
	}

	// Verificar que el target sea válido y esté en el juego
	if (!IsValidClient(target))
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidPlayer");
		CReplyToCommand(client, "Use: sm_cvb_unban <#userid|name>");
		return Plugin_Handled;
	}
	
	// Verificar que el jugador esté baneado
	if (!g_PlayerBans[target].isLoaded || g_PlayerBans[target].banType <= 0)
	{
		char targetName[MAX_NAME_LENGTH];
		GetClientName(target, targetName, sizeof(targetName));
		CReplyToCommand(client, "%t %t", "Tag", "PlayerNotBanned", targetName);
		return Plugin_Handled;
	}
	
	// Todo está correcto, aplicar el unban
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
		CReplyToCommand(client, "%t %t", "Tag", "UsageCommandSteamID", "sm_cvb_unbanid", "");
		CReplyToCommand(client, "%t %t", "Tag", "SupportedSteamIDFormats");
		return Plugin_Handled;
	}
	
	char sSteamId[MAX_AUTHID_LENGTH];
	GetCmdArg(1, sSteamId, sizeof(sSteamId));

	AsyncContext context = new AsyncContext();
	context.ContinuationType = CONTINUE_UNBAN_OFFLINE;

	if (ValidateAndConvertSteamIDAsync(client, sSteamId, context))
	{
		Continue_UnbanOffline_Async(context);
	}

	return Plugin_Handled;
}

public Action Command_Check(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}
	
	// Caso 1: Sin argumentos
	if (args < 1)
	{
		// Si es consola, mostrar uso correcto
		if (client == 0)
		{
			CReplyToCommand(client, "Use: sm_cvb_check <#userid|name>");
			return Plugin_Handled;
		}
		
		// Si es un jugador, abrir panel
		ShowMainCheckPanel(client);
		return Plugin_Handled;
	}
	
	// Caso 2: Con argumentos - verificar si el nombre/ID es válido
	char sTarget[MAX_NAME_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	int target = FindTarget(client, sTarget, false, false);

	// Si FindTarget devuelve -1, significa que no encontró el jugador
	if (target == -1)
	{
		// Mostrar el uso correcto
		CReplyToCommand(client, "Use: sm_cvb_check <#userid|name>");
		return Plugin_Handled;
	}

	// Verificar que el target sea válido y esté en el juego
	if (!IsValidClient(target))
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidPlayer");
		CReplyToCommand(client, "Use: sm_cvb_check <#userid|name>");
		return Plugin_Handled;
	}

	// Todo está correcto, proceder con la ejecución
	ShowPlayerBanInfo(client, target);
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
		CReplyToCommand(client, "%t %t", "Tag", "UsageCommandSteamID", "sm_cvb_checkid", "");
		CReplyToCommand(client, "%t %t", "Tag", "SupportedSteamIDFormats");
		return Plugin_Handled;
	}
	
	char sSteamId[MAX_AUTHID_LENGTH];
	GetCmdArg(1, sSteamId, sizeof(sSteamId));

	AsyncContext context = new AsyncContext();
	context.ContinuationType = CONTINUE_CHECK_OFFLINE;

	if (ValidateAndConvertSteamIDAsync(client, sSteamId, context))
	{
		Continue_CheckOffline_Async(context);
	}

	return Plugin_Handled;
}

void CheckOfflinePlayerBan(int admin, int accountId, const char[] steamId2)
{
	CReplyToCommand(admin, "%t %t", "Tag", "BanStatusVerifying", steamId2);

	DataPack dp = new DataPack();
	dp.WriteCell((admin == SERVER_INDEX) ? 0 : GetClientUserId(admin));
	dp.WriteString(steamId2);
	dp.WriteCell(accountId);

	if (g_hMySQLDB != null)
	{
		char sQuery[512];
		Format(sQuery, sizeof(sQuery),
			"SELECT ban_type, created_timestamp, duration_minutes, expires_timestamp FROM callvote_bans WHERE account_id = %d AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > UNIX_TIMESTAMP()) ORDER BY created_timestamp DESC LIMIT 1",
			accountId);
		SQL_TQuery(g_hMySQLDB, CheckOfflinePlayerBan_Callback, sQuery, dp);
	}
	else
	{
		delete dp;
		CReplyToCommand(admin, "%t %t", "Tag", "BanStatusMySQLUnavailable");
	}
}

public void CheckOfflinePlayerBan_Callback(Handle owner, Handle hndl, const char[] error, DataPack dp)
{
	dp.Reset();
	int adminUserId = dp.ReadCell();
	char sSteamId2[MAX_AUTHID_LENGTH];
	dp.ReadString(sSteamId2, sizeof(sSteamId2));
	int accountId = dp.ReadCell();
	delete dp;

	int admin = (adminUserId == 0) ? SERVER_INDEX : GetClientOfUserId(adminUserId);
	if (admin < SERVER_INDEX)
		return;

	DBResultSet results = view_as<DBResultSet>(hndl);
	if (results == null)
	{
		CReplyToCommand(admin, "%t %t", "Tag", "BanStatusQueryError", error);
		return;
	}

	if (results.FetchRow())
	{
		int banType = results.FetchInt(0);
		int createdTimestamp = results.FetchInt(1);
		results.FetchInt(2);
		int expiresTimestamp = results.FetchInt(3);

		char sBanTypes[128];
		GetBanTypeString(banType, sBanTypes, sizeof(sBanTypes));

		char sCreated[64], sExpiration[64];
		FormatTime(sCreated, sizeof(sCreated), "%Y-%m-%d %H:%M:%S", createdTimestamp);

		if (expiresTimestamp == 0)
		{
			Format(sExpiration, sizeof(sExpiration), "%T", "BanStatusPermanent", admin);
		}
		else
		{
			FormatTime(sExpiration, sizeof(sExpiration), "%Y-%m-%d %H:%M:%S", expiresTimestamp);
		}

		CReplyToCommand(admin, "%t %t", "Tag", "BanStatusHeaderOffline", sSteamId2);
		CReplyToCommand(admin, "%t %t", "Tag", "BanStatusAccountID", accountId);
		CReplyToCommand(admin, "%t %t", "Tag", "BanStatusBanned");
		CReplyToCommand(admin, "%t %t", "Tag", "BanStatusRestrictedTypes", sBanTypes);
		CReplyToCommand(admin, "%t %t", "Tag", "BanStatusCreated", sCreated);
		CReplyToCommand(admin, "%t %t", "Tag", "BanStatusExpiration", sExpiration);
	}
	else
	{
		CReplyToCommand(admin, "%t %t", "Tag", "BanStatusHeaderOffline", sSteamId2);
		CReplyToCommand(admin, "%t %t", "Tag", "BanStatusAccountID", accountId);
		CReplyToCommand(admin, "%t %t", "Tag", "BanStatusUnbanned");
	}
}

/**
 * Command: sm_mybans
 * 
 * Allows players to check their own vote ban status.
 * This command queries MySQL database and updates the local cache
 * to ensure the most up-to-date information is displayed.
 * 
 * @param client   The client executing the command
 * @param args     Command arguments (unused)
 * @return         Plugin_Handled
 */
public Action Command_MyBans(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}
	
	if (client == SERVER_INDEX)
	{
		CReplyToCommand(client, "%t %t", "Tag", "CommandOnlyFromGame");
		return Plugin_Handled;
	}
	
	if (!IsValidClient(client))
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidPlayer");
		return Plugin_Handled;
	}
	
	// Force cache update from MySQL for most accurate information
	CReplyToCommand(client, "%t %t", "Tag", "MyBansChecking");
	
	// Get player information
	int accountId = GetSteamAccountID(client);
	char steamId2[MAX_AUTHID_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, steamId2, sizeof(steamId2));
	
	// Mark player as not loaded to force fresh MySQL query
	g_PlayerBans[client].isLoaded = false;
	g_PlayerBans[client].isChecking = true;
	
	// Trigger async check which will update cache and then show ban info
	AsyncCheckPlayerBan(client, accountId, steamId2);
	
	return Plugin_Handled;
}

void ShowPlayerBanInfo(int admin, int target)
{
	int adminAccountId = GetSteamAccountID(admin);
	int targetAccountId = GetSteamAccountID(target);
	char sSteamId2[MAX_AUTHID_LENGTH];
	char sName[MAX_NAME_LENGTH];
	
	GetClientAuthId(target, AuthId_Steam2, sSteamId2, sizeof(sSteamId2));
	GetClientName(target, sName, sizeof(sName));
	
	// Force MySQL query instead of using cache for sm_cvb_check command
	CReplyToCommand(admin, "%t %t", "Tag", "BanStatusCheckingPlayer", sName);
	
	// Mark as checking to prevent duplicate queries
	g_PlayerBans[target].isChecking = true;
	
	// Always query MySQL directly for this command
	CVB_CheckFullBan(targetAccountId, adminAccountId);
}