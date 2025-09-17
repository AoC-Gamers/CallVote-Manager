#if defined _cvb_commands_sql_included
	#endinput
#endif
#define _cvb_commands_sql_included

public Action Command_InstallDatabase(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	char installType[32];
	bool installMySQL = true;
	bool installSQLite = true;
	
	if (args > 0)
	{
		GetCmdArg(1, installType, sizeof(installType));
		
		for (int i = 0; i < strlen(installType); i++)
		{
			installType[i] = CharToLower(installType[i]);
		}
		
		if (StrEqual(installType, "mysql"))
		{
			installMySQL = true;
			installSQLite = false;
		}
		else if (StrEqual(installType, "sqlite"))
		{
			installMySQL = false;
			installSQLite = true;
		}
		else if (StrEqual(installType, "all"))
		{
			installMySQL = true;
			installSQLite = true;
		}
		else
		{
			CReplyToCommand(client, "%t %t: sm_cvb_install [mysql|sqlite|all]", "Tag", "Usage");
			return Plugin_Handled;
		}
	}
	
	bool mysqlAvailable = (g_hMySQLDB != null);
	bool sqliteAvailable = (g_hSQLiteDB != null);
	
	if (installMySQL && !mysqlAvailable)
	{
		CReplyToCommand(client, "%t %t", "Tag", "MySQLNotAvailableForInstall");
		CReplyToCommand(client, "%t", "CheckMySQLConfig");

		if (!installSQLite)
			return Plugin_Handled;
	}
	
	if (installSQLite && !sqliteAvailable)
	{
		CReplyToCommand(client, "%t %t", "Tag", "SQLiteNotAvailableForInstall");

		if (!installMySQL)
			return Plugin_Handled;
	}
	
	if (installMySQL && mysqlAvailable)
		CReplyToCommand(client, "%t %t", "Tag", "CreatingMySQLTables");
	
	if (installSQLite && sqliteAvailable)
		CReplyToCommand(client, "%t %t", "Tag", "CreatingSQLiteTables");
	
	CVBLog.Debug("Admin %N inició la instalación de base de datos - MySQL: %s, SQLite: %s", client, installMySQL ? "SI" : "NO", installSQLite ? "SI" : "NO");
	InitInstallationTracking(client, installMySQL, installSQLite);

	return Plugin_Handled;
}

public Action Command_VerifyInstallation(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}
	
	char verifyType[32];
	if (args > 0)
		GetCmdArg(1, verifyType, sizeof(verifyType));
	else
		strcopy(verifyType, sizeof(verifyType), "mysql");
	
	for (int i = 0; i < strlen(verifyType); i++)
	{
		verifyType[i] = CharToLower(verifyType[i]);
	}
	
	if (StrEqual(verifyType, "sqlite"))
		CReplyToCommand(client, "%t %t", "Tag", "SQLiteVerificationNotSupported");
	else if (StrEqual(verifyType, "mysql") || StrEqual(verifyType, ""))
		PerformMySQLVerify(client);
	else
		CReplyToCommand(client, "%t %t: sm_cvb_verify [mysql|sqlite]", "Tag", "Usage");
	
	return Plugin_Handled;
}

void PerformMySQLVerify(int client)
{
	if (g_hMySQLDB == null)
	{
		CReplyToCommand(client, "%t %t", "Tag", "MySQLRequiredStoredProcedures");
		return;
	}
	
	CReplyToCommand(client, "%t %t", "Tag", "VerifyingStoredProcedures");
	
	VerifyStoredProcedure(client, PROCEDURE_CHECK_ACTIVE_BAN);
	VerifyStoredProcedure(client, PROCEDURE_CHECK_FULL_BAN);
	VerifyStoredProcedure(client, PROCEDURE_INSERT_BAN);
	VerifyStoredProcedure(client, PROCEDURE_REMOVE_BAN);
	VerifyStoredProcedure(client, PROCEDURE_CLEAN_EXPIRED);
	VerifyStoredProcedure(client, PROCEDURE_GET_STATISTICS);
}

void VerifyStoredProcedure(int client, const char[] procedureName)
{
	char sQuery[256];
	Format(sQuery, sizeof(sQuery), "SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_NAME = '%s'", procedureName);
	
	DataPack dp = new DataPack();
	dp.WriteCell((client == SERVER_INDEX) ? 0 : GetClientUserId(client));
	dp.WriteString(procedureName);
	
	SQL_TQuery(g_hMySQLDB, VerifyStoredProcedure_Callback, sQuery, dp);
}

public void VerifyStoredProcedure_Callback(Handle owner, Handle hndl, const char[] error, DataPack dp)
{
	dp.Reset();
	int clientUserId = dp.ReadCell();
	char procedureName[64];
	dp.ReadString(procedureName, sizeof(procedureName));
	delete dp;
	
	int client = (clientUserId == 0) ? SERVER_INDEX : GetClientOfUserId(clientUserId);
	
	DBResultSet results = view_as<DBResultSet>(hndl);
	if (results == null)
	{
		if (client >= SERVER_INDEX)
			CReplyToCommand(client, "%t %t", "Tag", "VerificationError", procedureName, error);
		
		return;
	}
	
	int count = 0;
	if (results.FetchRow())
	{
		count = results.FetchInt(0);
	}
	
	if (client >= SERVER_INDEX)
	{
		if (count > 0)
			CReplyToCommand(client, "%t %t", "Tag", "VerificationInstalled", procedureName);
		else
			CReplyToCommand(client, "%t %t", "Tag", "VerificationNotFound", procedureName);
	}
}

public Action Command_Truncate(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}
	
	char truncateType[32], confirmArg[16];
	bool hasConfirmation = false;

	if (args >= 1)
	{
		GetCmdArg(1, truncateType, sizeof(truncateType));
		
		if (StrEqual(truncateType, "confirm", false))
		{
			strcopy(truncateType, sizeof(truncateType), "all");
			hasConfirmation = true;
		}
		else
		{
			for (int i = 0; i < strlen(truncateType); i++)
			{
				truncateType[i] = CharToLower(truncateType[i]);
			}
			
			if (args >= 2)
			{
				GetCmdArg(2, confirmArg, sizeof(confirmArg));
				hasConfirmation = StrEqual(confirmArg, "confirm", false);
			}
		}
	}
	else
		strcopy(truncateType, sizeof(truncateType), "all"); // Default to all databases
	
	if (!hasConfirmation)
	{
		CReplyToCommand(client, "%t %t", "Tag", "TruncateConfirmation");
		CReplyToCommand(client, "%t %t: sm_cvb_truncate [mysql|sqlite|all] [confirm]", "Usage");
		return Plugin_Handled;
	}
	
	if (StrEqual(truncateType, "mysql"))
		PerformMySQLTruncate(client);
	else if (StrEqual(truncateType, "sqlite"))
		PerformSQLiteTruncate(client);
	else if (StrEqual(truncateType, "all"))
	{
		PerformMySQLTruncate(client);
		PerformSQLiteTruncate(client);
		PerformCacheTruncate(client);
	}
	else
		CReplyToCommand(client, "%t %t: sm_cvb_truncate [mysql|sqlite|all] [confirm]", "Tag", "Usage");
	
	return Plugin_Handled;
}

void PerformMySQLTruncate(int client)
{
	if (g_hMySQLDB != null)
	{
		char query[128];
		FormatEx(query, sizeof(query), "TRUNCATE TABLE %s", TABLE_BANS);
		SQL_TQuery(g_hMySQLDB, Generic_QueryCallback, query);
		CReplyToCommand(client, "%t %t", "Tag", "MySQLTruncateSuccess");
		
		char sAdminName[MAX_NAME_LENGTH];
		if (client == SERVER_INDEX)
			strcopy(sAdminName, sizeof(sAdminName), "CONSOLE");
		else
			GetClientName(client, sAdminName, sizeof(sAdminName));

		CVBLog.Debug("Admin %s truncó la tabla MySQL de bans", sAdminName);
	}
	else
		CReplyToCommand(client, "%t %t", "Tag", "MySQLNotAvailable");
}

void PerformSQLiteTruncate(int client)
{
	if (g_hSQLiteDB != null)
	{
		char query[128];
		FormatEx(query, sizeof(query), "DELETE FROM `%s`", TABLE_CACHE_BANS);
		SQL_FastQuery(g_hSQLiteDB, query);
		CReplyToCommand(client, "%t %t", "Tag", "SQLiteTruncateSuccess");
		
		char sAdminName[MAX_NAME_LENGTH];
		if (client == SERVER_INDEX)
			strcopy(sAdminName, sizeof(sAdminName), "CONSOLE");
		else
			GetClientName(client, sAdminName, sizeof(sAdminName));

		CVBLog.Debug("Admin %s truncó la tabla SQLite de bans", sAdminName);
	}
	else
		CReplyToCommand(client, "%t %t", "Tag", "SQLiteNotAvailable");
}

void PerformCacheTruncate(int client)
{
	if (g_smClientCache != null)
		g_smClientCache.Clear();
		
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			g_ClientStates[i].isLoaded = true;
			g_ClientStates[i].isChecking = false;
		}
	}
	
	CReplyToCommand(client, "%t %t", "Tag", "CacheTruncateSuccess");
	
	char sAdminName[MAX_NAME_LENGTH];
	if (client == SERVER_INDEX)
		strcopy(sAdminName, sizeof(sAdminName), "CONSOLE");
	else
		GetClientName(client, sAdminName, sizeof(sAdminName));
	CVBLog.Debug("Admin %s limpió el cache de memoria de bans", sAdminName);
}

public Action Command_CleanupBans(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}
	
	char cleanupType[32];
	if (args > 0)
		GetCmdArg(1, cleanupType, sizeof(cleanupType));
	else
		strcopy(cleanupType, sizeof(cleanupType), "mysql");
	
	for (int i = 0; i < strlen(cleanupType); i++)
	{
		cleanupType[i] = CharToLower(cleanupType[i]);
	}
	
	if (StrEqual(cleanupType, "cache"))
		PerformCacheCleanup(client);
	else if (StrEqual(cleanupType, "all"))
	{
		PerformMySQLCleanup(client);
		CReplyToCommand(client, "");
		PerformCacheCleanup(client);
	}
	else if (StrEqual(cleanupType, "mysql") || StrEqual(cleanupType, ""))
		PerformMySQLCleanup(client);
	else
		CReplyToCommand(client, "%t %t: sm_cvb_cleanup [mysql|cache|all]", "Tag", "Usage");
	
	return Plugin_Handled;
}

void PerformMySQLCleanup(int client)
{
	CReplyToCommand(client, "%t %t", "Tag", "CleanupStarting");
	if (g_hMySQLDB != null)
	{
		int accountId = (client == SERVER_INDEX) ? 0 : GetSteamAccountID(client);
		CVB_CleanExpiredMysqlBans(accountId, 100);
	}
	else
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseNotAvailable");
}

void PerformCacheCleanup(int client)
{
	ClearBanCache();
	CReplyToCommand(client, "%t %t", "Tag", "CacheCleanupMemorySuccess");

	if (g_hSQLiteDB != null)
	{
		int cleanedEntries = CleanupExpiredSQLiteCache();
		if (cleanedEntries > 0)
			CReplyToCommand(client, "%t %t", "Tag", "CacheCleanupExpiredBans", cleanedEntries);
		
		CReplyToCommand(client, "%t %t", "Tag", "CacheCleanupSuccess");
		
		LogAction(client, -1, "[CallVote Bans] Manual cache cleanup by admin - %d SQLite entries removed", cleanedEntries);
	}
	else
		CReplyToCommand(client, "%t %t", "Tag", "CacheCleanupSQLiteWarning");
}

public Action Command_Stats(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}
	
	char statType[32];
	if (args > 0)
		GetCmdArg(1, statType, sizeof(statType));
	else
		strcopy(statType, sizeof(statType), "mysql");
	
	for (int i = 0; i < strlen(statType); i++)
	{
		statType[i] = CharToLower(statType[i]);
	}
	
	if (StrEqual(statType, "cache"))
		ShowCacheStats(client);
	else if (StrEqual(statType, "all"))
	{
		ShowMySQLStats(client);
		CReplyToCommand(client, "");
		ShowCacheStats(client);
	}
	else if (StrEqual(statType, "mysql") || StrEqual(statType, ""))
		ShowMySQLStats(client);
	else
		CReplyToCommand(client, "%t %t: sm_cvb_stats [mysql|cache|all]", "Tag", "Usage");
	
	return Plugin_Handled;
}

void ShowMySQLStats(int client)
{
	CReplyToCommand(client, "%t %t", "Tag", "BanStatsHeader");
	if (g_hMySQLDB != null)
	{
		char query[128];
		int daysBack = 30;
		FormatEx(query, sizeof(query), "CALL %s(%d)", PROCEDURE_GET_STATISTICS, daysBack);
		SQL_TQuery(g_hMySQLDB, BanStats_Callback, query, client);
	}
	else
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseNotAvailable");
}

void ShowCacheStats(int client)
{
	int stringMapEntries, playerBanEntries;
	GetCacheStats(stringMapEntries, playerBanEntries);
	
	CReplyToCommand(client, "%t %t", "Tag", "CacheStatsHeader");
	CReplyToCommand(client, "%t %t", "Tag", "CacheStatsStringMap", stringMapEntries);
	CReplyToCommand(client, "%t %t", "Tag", "CacheStatsPlayerBans", playerBanEntries);
	
	char sConnectedMySQL[32], sConnectedSQLite[32];
	Format(sConnectedMySQL, sizeof(sConnectedMySQL), "%t", (g_hMySQLDB != null) ? "Connected" : "Disconnected");
	Format(sConnectedSQLite, sizeof(sConnectedSQLite), "%t", (g_hSQLiteDB != null) ? "Connected" : "Disconnected");
	
	CReplyToCommand(client, "%t %t", "Tag", "CacheStatsMySQL", sConnectedMySQL);
	CReplyToCommand(client, "%t %t", "Tag", "CacheStatsSQLite", sConnectedSQLite);
}

void BanStats_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	int client = data;
	if (results == null)
	{
		CReplyToCommand(client, "%t %t", "Tag", "StatsError", error);
		return;
	}

	if (results.FetchRow())
	{
		int activeBans = results.FetchInt(0);
		int expiredBans = results.FetchInt(1);
		int recentBans = results.FetchInt(2);
		int uniquePlayers = results.FetchInt(3);
		int uniqueAdmins = results.FetchInt(4);
		CReplyToCommand(client, "%t %t", "Tag", "ActiveBans", activeBans);
		CReplyToCommand(client, "%t %t", "Tag", "ExpiredBansStats", expiredBans);
		CReplyToCommand(client, "%t %t", "Tag", "RecentBans", recentBans);
		CReplyToCommand(client, "%t %t", "Tag", "UniquePlayers", uniquePlayers);
		CReplyToCommand(client, "%t %t", "Tag", "UniqueAdmins", uniqueAdmins);
	}

	int cacheSize = g_smClientCache.Size;
	CReplyToCommand(client, "");
	CReplyToCommand(client, "%t %t", "Tag", "BanStatsMemoryCache", cacheSize);
	
	if (g_hSQLiteDB != null)
		CReplyToCommand(client, "%t %t", "Tag", "BanStatsSQLiteActive");
	else
		CReplyToCommand(client, "%t %t", "Tag", "BanStatsSQLiteInactive");

	if (g_hMySQLDB != null)
		CReplyToCommand(client, "%t %t", "Tag", "BanStatsStoredProceduresAvailable");
	else
		CReplyToCommand(client, "%t %t", "Tag", "BanStatsStoredProceduresUnavailable");
}

/*****************************************************************
			R E I N S T A L L   D A T A B A S E   S Y S T E M
*****************************************************************/

/**
 * Command: sm_cvb_reinstall
 * DANGEROUS: Completely drops and recreates all database structures
 * Requires explicit confirmation to prevent accidental data loss
 */
public Action Command_ReinstallDatabase(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	char installType[32];
	bool installMySQL = true;
	bool installSQLite = true;
	
	// Parse arguments
	if (args > 0)
	{
		GetCmdArg(1, installType, sizeof(installType));
		
		for (int i = 0; i < strlen(installType); i++)
		{
			installType[i] = CharToLower(installType[i]);
		}
		
		if (StrEqual(installType, "mysql"))
		{
			installMySQL = true;
			installSQLite = false;
		}
		else if (StrEqual(installType, "sqlite"))
		{
			installMySQL = false;
			installSQLite = true;
		}
		else if (StrEqual(installType, "all"))
		{
			installMySQL = true;
			installSQLite = true;
		}
		else
		{
			CReplyToCommand(client, "%t Usage: sm_cvb_reinstall [mysql|sqlite|all]", "Tag");
			CReplyToCommand(client, "%t %t", "Tag", "ReinstallWarning");
			return Plugin_Handled;
		}
	}
	
	// Show warning but proceed without confirmation
	CReplyToCommand(client, "%t %t", "Tag", "ReinstallWarning");
	
	bool mysqlAvailable = (g_hMySQLDB != null);
	bool sqliteAvailable = (g_hSQLiteDB != null);
	
	// Validate database availability
	if (installMySQL && !mysqlAvailable)
	{
		CReplyToCommand(client, "%t %t", "Tag", "MySQLNotAvailableForInstall");
		CReplyToCommand(client, "%t", "CheckMySQLConfig");

		if (!installSQLite)
			return Plugin_Handled;
	}
	
	if (installSQLite && !sqliteAvailable)
	{
		CReplyToCommand(client, "%t %t", "Tag", "SQLiteNotAvailableForInstall");

		if (!installMySQL)
			return Plugin_Handled;
	}
	
	// Show what will be reinstalled
	if (installMySQL && mysqlAvailable)
		CReplyToCommand(client, "%t %t", "Tag", "ReinstallingMySQL");
	
	if (installSQLite && sqliteAvailable)
		CReplyToCommand(client, "%t %t", "Tag", "ReinstallingSQLite");
	
	CVBLog.Debug("Admin %N inició REINSTALACIÓN COMPLETA de base de datos - MySQL: %s, SQLite: %s", 
		client, installMySQL ? "SI" : "NO", installSQLite ? "SI" : "NO");
		
	// Start the dangerous reinstallation process
	InitReinstallationTracking(client, installMySQL, installSQLite);

	return Plugin_Handled;
}