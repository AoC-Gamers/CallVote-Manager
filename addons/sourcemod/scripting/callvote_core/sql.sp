#if defined _callvote_core_sql_included
	#endinput
#endif
#define _callvote_core_sql_included

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

ConVar
	g_cvarRegLogSQL,
	g_cvarSQLConfig;

char
	g_sTable[] = "callvote_log";

bool
	g_bSQLConnected,
	g_bSQLTableExists;

enum SQLDriver
{
	SQL_MySQL  = 0,
	SQL_SQLite = 1,
}

Database
	g_db;

SQLDriver
	g_SQLDriver;

enum struct SQLClientContext
{
	int UserId;
}

enum struct SQLClientDaysContext
{
	int UserId;
	int Days;
}

static DataPack CreateSQLClientContextPack(int client)
{
	DataPack pack = new DataPack();
	pack.WriteCell(client == SERVER_INDEX ? SERVER_INDEX : GetClientUserId(client));
	return pack;
}

static void ReadSQLClientContext(DataPack pack, SQLClientContext context)
{
	pack.Reset();
	context.UserId = pack.ReadCell();
}

static DataPack CreateSQLClientDaysContextPack(int client, int days)
{
	DataPack pack = new DataPack();
	pack.WriteCell(client == SERVER_INDEX ? SERVER_INDEX : GetClientUserId(client));
	pack.WriteCell(days);
	return pack;
}

static void ReadSQLClientDaysContext(DataPack pack, SQLClientDaysContext context)
{
	pack.Reset();
	context.UserId = pack.ReadCell();
	context.Days = pack.ReadCell();
}

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public void OnPluginStart_SQL()
{
	g_cvarRegLogSQL = CreateConVar("sm_cvc_sql_log_flags", "0", "SQL logging flags <difficulty:1, restartgame:2, kick:4, changemission:8, lobby:16, chapter:32, alltalk:64, ALL:127, NONE:0>", FCVAR_NOTIFY, true, 0.0, true, 127.0);
	g_cvarSQLConfig = CreateConVar("sm_cvc_sql_config", "callvote", "Database config name from databases.cfg for callvote_core", FCVAR_NONE);
	
	RegAdminCmd("sm_cvc_sql_cleanup", Command_CleanupDB, ADMFLAG_ROOT, "Clean up database records");
	RegAdminCmd("sm_cvc_sql_truncate", Command_TruncateDB, ADMFLAG_ROOT, "Completely clear database table");
	RegAdminCmd("sm_cvc_sql_stats", Command_DBStats, ADMFLAG_GENERIC, "Show database statistics");
}

public void OnPluginEnd_SQL()
{
	if (!g_cvarRegLogSQL.IntValue)
		return;

	if (g_db == null)
		return;

	delete g_db;
	CVLog.Debug("[OnPluginEnd] Database connection closed.");
}

void OnConfigsExecuted_SQL()
{
	if (!g_cvarRegLogSQL.IntValue)
		return;

	if (g_db != null)
		return;

	char sConfigName[64];
	g_cvarSQLConfig.GetString(sConfigName, sizeof(sConfigName));
	CVLog.Debug("[OnConfigsExecuted_SQL] Connecting to the database with config '%s'...", sConfigName);
	ConnectDB(sConfigName);
}

void EnsureSQLiteSchema()
{
	if (g_SQLDriver != SQL_SQLite || g_db == null)
		return;

	char sQueryTable[1024];
	int iLen = 0;

	iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "CREATE TABLE IF NOT EXISTS `%s` ( ", g_sTable);
	iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`id` INTEGER PRIMARY KEY AUTOINCREMENT, ");
	iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`caller_account_id` INTEGER NOT NULL DEFAULT 0, ");
	iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`created` INTEGER NOT NULL DEFAULT 0, ");
	iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`type` INTEGER NOT NULL DEFAULT 0, ");
	iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`target_account_id` INTEGER NOT NULL DEFAULT 0 ");
	iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, ");");

	if (!SQL_FastQuery(g_db, sQueryTable))
	{
		char sError[256];
		SQL_GetError(g_db, sError, sizeof(sError));
		CVLog.Query("[EnsureSQLiteSchema] Failed to create SQLite table `%s`: %s", g_sTable, sError);
		return;
	}

	char sIndexQuery[256];
	FormatEx(sIndexQuery, sizeof(sIndexQuery), "CREATE INDEX IF NOT EXISTS `idx_callvote_log_caller_created` ON `%s` (`caller_account_id`, `created`)", g_sTable);
	if (!SQL_FastQuery(g_db, sIndexQuery))
	{
		char sError[256];
		SQL_GetError(g_db, sError, sizeof(sError));
		CVLog.Query("[EnsureSQLiteSchema] Failed to create SQLite index for `%s`: %s", g_sTable, sError);
	}

	FormatEx(sIndexQuery, sizeof(sIndexQuery), "CREATE INDEX IF NOT EXISTS `idx_callvote_log_target_account_created` ON `%s` (`target_account_id`, `created`)", g_sTable);
	if (!SQL_FastQuery(g_db, sIndexQuery))
	{
		char sError[256];
		SQL_GetError(g_db, sError, sizeof(sError));
		CVLog.Query("[EnsureSQLiteSchema] Failed to create SQLite target account index for `%s`: %s", g_sTable, sError);
	}

}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

/**
 * Logs a vote action to the SQL database.
 * 
 * This function validates SQL logging settings, checks database connectivity,
 * retrieves client AccountIDs, and constructs appropriate SQL queries
 * based on the database driver type (MySQL/SQLite).
 *
 * @param type      The type of vote action (ChangeDifficulty, RestartGame, Kick, etc.).
 * @param iClient   The client index of the player initiating the vote.
 * @param iTarget   The client index of the target player (only used for Kick votes, default SERVER_INDEX).
 * @noreturn        Function returns early if logging is disabled or conditions are not met.
 * @error           Function logs errors and returns if AccountID retrieval fails or database is unavailable.
 */
void RegSQLVote(TypeVotes type, int iClient, int iTarget = SERVER_INDEX)
{
	if (!g_cvarRegLogSQL.IntValue)
		return;
	
	VoteType iVoteFlag = VOTE_NONE;
	iVoteFlag = GetVoteFlag(type);
	if (iVoteFlag == VOTE_NONE)
		return;
	
	if (!(g_cvarRegLogSQL.IntValue & view_as<int>(iVoteFlag)))
		return;
	
    if (!g_bSQLConnected || !g_bSQLTableExists)
        return;

    int iCallerAccountId = 0;
    if (g_bCurrentVoteSessionValid && g_CurrentVoteSession.callerClient == iClient)
        iCallerAccountId = g_CurrentVoteSession.callerAccountId;

    if (iCallerAccountId <= 0)
        iCallerAccountId = GetClientAccountID(iClient);

    if (iCallerAccountId <= 0)
    {
        CVLog.SQL("[RegSQLVote] Failed to resolve caller AccountID for client %d", iClient);
        return;
    }

    int iTargetAccountId = 0;
    char sTargetSteamID64[STEAMID64_EXACT_LENGTH + 1];
    sTargetSteamID64[0] = '\0';
    char sCallerSteamID64[STEAMID64_EXACT_LENGTH + 1];
    sCallerSteamID64[0] = '\0';

    if (g_SQLDriver == SQL_MySQL && (!g_bCurrentVoteSessionValid || !TryGetSessionSteamID64Info(g_CurrentVoteSession.sessionId, sCallerSteamID64, sizeof(sCallerSteamID64), sTargetSteamID64, sizeof(sTargetSteamID64))))
    {
        CVLog.SQL("[RegSQLVote] Failed to resolve frozen SteamID64 values for session %d", g_CurrentVoteSession.sessionId);
        return;
    }

    if (type == Kick && IsHuman(iTarget))
    {
        if (g_bCurrentVoteSessionValid && g_CurrentVoteSession.targetClient == iTarget)
            iTargetAccountId = g_CurrentVoteSession.targetAccountId;

        if (iTargetAccountId <= 0)
            iTargetAccountId = GetClientAccountID(iTarget);

        if (iTargetAccountId <= 0)
        {
            CVLog.SQL("[RegSQLVote] Failed to resolve target AccountID for client %d", iTarget);
            return;
        }
    }

    int iTime = GetTime();
    char sQuery[700];

    switch (g_SQLDriver)
    {
        case SQL_MySQL:
        {
            g_db.Format(sQuery, sizeof(sQuery),
                "INSERT INTO `%s` (caller_account_id, caller_steamid64, created, type, target_account_id, target_steamid64) VALUES (%d, '%s', %d, %d, %d, '%s')",
                g_sTable, iCallerAccountId, sCallerSteamID64, iTime, view_as<int>(type), iTargetAccountId, sTargetSteamID64);
        }
        case SQL_SQLite:
        {
            g_db.Format(sQuery, sizeof(sQuery),
                "INSERT INTO `%s` (caller_account_id, created, type, target_account_id) VALUES (%d, %d, %d, %d)",
                g_sTable, iCallerAccountId, iTime, view_as<int>(type), iTargetAccountId);
        }
        default:
        {
            CVLog.SQL("Unknown SQL driver in RegSQLVote.");
            return;
        }
    }

	CVLog.Query("[RegSQLVote] Executing %s INSERT query: %s", g_SQLDriver == SQL_MySQL ? "MySQL" : "SQLite", sQuery);
	
	g_db.Query(SQLVoteLogCallback, sQuery);
}

/**
 * Callback for SQL vote logging queries
 * Handles success/error reporting for vote logging operations
 */
public void SQLVoteLogCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null)
	{
		CVLog.Query("[SQLVoteLogCallback] Database handle is null");
		return;
	}

	if (error[0] != '\0')
	{
		CVLog.Query("[SQLVoteLogCallback] SQL Error: %s", error);
		return;
	}

	CVLog.Query("[SQLVoteLogCallback] Vote record inserted successfully");
}

/**
 * Command to clean up old database records
 * Usage: sm_cvc_sql_cleanup [days] - Clean records older than X days (default: 30)
 */
Action Command_CleanupDB(int iClient, int iArgs)
{
	if (!g_cvarRegLogSQL.IntValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "SQLDisabled");
		return Plugin_Handled;
	}

	if (!g_bSQLConnected || !g_bSQLTableExists)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "DBNoConnect");
		return Plugin_Handled;
	}

	int days = 30;
	if (iArgs >= 1)
	{
		char sArg[16];
		GetCmdArg(1, sArg, sizeof(sArg));
		days = StringToInt(sArg);
		
		if (days <= 0 || days > 365)
		{
			CReplyToCommand(iClient, "%t %t", "Tag", "InvalidDaysValue");
			return Plugin_Handled;
		}
	}

	char sQuery[256];
	int cutoffTime = GetTime() - (days * 86400); // Convert days to seconds

	switch (g_SQLDriver)
	{
		case SQL_MySQL:
		{
			g_db.Format(sQuery, sizeof(sQuery),
				"DELETE FROM `%s` WHERE created < %d",
				g_sTable, cutoffTime);
		}
		case SQL_SQLite:
		{
			g_db.Format(sQuery, sizeof(sQuery),
				"DELETE FROM `%s` WHERE created < %d",
				g_sTable, cutoffTime);
		}
		default:
		{
			CReplyToCommand(iClient, "%t %t", "Tag", "DBUnknownDriver");
			return Plugin_Handled;
		}
	}

	DataPack pack = CreateSQLClientDaysContextPack(iClient, days);

	CVLog.Query("[Command_CleanupDB] Executing cleanup DELETE query: %s", sQuery);
	g_db.Query(CleanupDB_Callback, sQuery, pack);
	CReplyToCommand(iClient, "%t %t", "Tag", "CleaningUpRecords", days);

	return Plugin_Handled;
}

/**
 * Command to completely truncate (empty) the database table
 * Usage: sm_cvc_sql_truncate - Requires confirmation
 */
Action Command_TruncateDB(int iClient, int iArgs)
{
	if (!g_cvarRegLogSQL.IntValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "SQLDisabled");
		return Plugin_Handled;
	}

	if (!g_bSQLConnected || !g_bSQLTableExists)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "DBNoConnect");
		return Plugin_Handled;
	}

	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "UsageTruncateConfirm");
		CReplyToCommand(iClient, "%t %t", "Tag", "WarningDeleteAllRecords");
		return Plugin_Handled;
	}

	char sConfirm[16];
	GetCmdArg(1, sConfirm, sizeof(sConfirm));
	
	if (!StrEqual(sConfirm, "CONFIRM", false))
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "MustTypeConfirm");
		return Plugin_Handled;
	}

	char sQuery[128];
	switch (g_SQLDriver)
	{
		case SQL_MySQL:
		{
			g_db.Format(sQuery, sizeof(sQuery), "TRUNCATE TABLE `%s`", g_sTable);
		}
		case SQL_SQLite:
		{
			g_db.Format(sQuery, sizeof(sQuery), "DELETE FROM `%s`", g_sTable);
		}
		default:
		{
			CReplyToCommand(iClient, "%t %t", "Tag", "DBUnknownDriver");
			return Plugin_Handled;
		}
	}

	DataPack pack = CreateSQLClientContextPack(iClient);

	CVLog.Query("[Command_TruncateDB] Executing table truncate query: %s", sQuery);
	g_db.Query(TruncateDB_Callback, sQuery, pack);
	CReplyToCommand(iClient, "%t %t", "Tag", "TruncatingTable");

	return Plugin_Handled;
}

/**
 * Command to show database statistics
 * Usage: sm_cvc_sql_stats - Show total records and breakdown by vote type
 */
Action Command_DBStats(int iClient, int iArgs)
{
	if (!g_cvarRegLogSQL.IntValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "SQLDisabled");
		return Plugin_Handled;
	}

	if (!g_bSQLConnected || !g_bSQLTableExists)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "DBNoConnect");
		return Plugin_Handled;
	}

	char sQuery[512];
	int iLen = 0;
	switch (g_SQLDriver)
	{
		case SQL_MySQL, SQL_SQLite:
		{
			iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "SELECT COUNT(*) as total, ");
			iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "SUM(CASE WHEN type = %d THEN 1 ELSE 0 END) as difficulty, ", view_as<int>(ChangeDifficulty));
			iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "SUM(CASE WHEN type = %d THEN 1 ELSE 0 END) as restart, ", view_as<int>(RestartGame));
			iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "SUM(CASE WHEN type = %d THEN 1 ELSE 0 END) as kick, ", view_as<int>(Kick));
			iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "SUM(CASE WHEN type = %d THEN 1 ELSE 0 END) as mission, ", view_as<int>(ChangeMission));
			iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "SUM(CASE WHEN type = %d THEN 1 ELSE 0 END) as lobby, ", view_as<int>(ReturnToLobby));
			iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "SUM(CASE WHEN type = %d THEN 1 ELSE 0 END) as chapter, ", view_as<int>(ChangeChapter));
			iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "SUM(CASE WHEN type = %d THEN 1 ELSE 0 END) as alltalk ", view_as<int>(ChangeAllTalk));
			iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "FROM `%s`", g_sTable);
		}
		default:
		{
			CReplyToCommand(iClient, "%t %t", "Tag", "DBUnknownDriver");
			return Plugin_Handled;
		}
	}

	DataPack pack = CreateSQLClientContextPack(iClient);

	CVLog.Query("[Command_DBStats] Executing statistics SELECT query: %s", sQuery);
	g_db.Query(DBStats_Callback, sQuery, pack);

	return Plugin_Handled;
}

/**
 * Callback for database cleanup operation
 */
public void CleanupDB_Callback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	SQLClientDaysContext context;
	ReadSQLClientDaysContext(pack, context);
	delete pack;

	int client = 0;
	if (context.UserId != 0)
	{
		client = GetClientOfUserId(context.UserId);
		if (!client)
			return;
	}

	if (results == null)
	{
		if (client == SERVER_INDEX)
		{
			char sMessage[256];
			FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseCleanupFailed", LANG_SERVER, error);
			LogError("[CleanupDB_Callback] %s", sMessage);
		}
		else
			CReplyToCommand(client, "%t %t", "Tag", "DatabaseCleanupFailed", error);
		CVLog.Debug("[CleanupDB_Callback] Error: %s", error);
		return;
	}

	int affectedRows = results.AffectedRows;
	if (client == SERVER_INDEX)
	{
		char sMessage[256];
		FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseCleanupCompleted", LANG_SERVER, affectedRows, context.Days);
		PrintToServer("[CallVote] %s", sMessage);
	}
	else
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseCleanupCompleted", affectedRows, context.Days);
	CVLog.Debug("[CleanupDB_Callback] Cleanup completed: %d rows affected", affectedRows);
}

/**
 * Callback for database truncate operation
 */
public void TruncateDB_Callback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	SQLClientContext context;
	ReadSQLClientContext(pack, context);
	delete pack;

	int client = 0;
	if (context.UserId != 0)
	{
		client = GetClientOfUserId(context.UserId);
		if (!client)
			return;
	}

	if (results == null)
	{
		if (client == SERVER_INDEX)
		{
			char sMessage[256];
			FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseTruncateFailed", LANG_SERVER, error);
			LogError("[TruncateDB_Callback] %s", sMessage);
		}
		else
			CReplyToCommand(client, "%t %t", "Tag", "DatabaseTruncateFailed", error);
		CVLog.Debug("[TruncateDB_Callback] Error: %s", error);
		return;
	}

	if (client == SERVER_INDEX)
	{
		char sMessage[256];
		FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseTruncateCompleted", LANG_SERVER);
		PrintToServer("[CallVote] %s", sMessage);
	}
	else
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseTruncateCompleted");
	CVLog.Debug("[TruncateDB_Callback] Table truncated successfully");
}

/**
 * Callback for database statistics query
 */
public void DBStats_Callback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	SQLClientContext context;
	ReadSQLClientContext(pack, context);
	delete pack;

	int client = 0;
	if (context.UserId != 0)
	{
		client = GetClientOfUserId(context.UserId);
		if (!client)
			return;
	}

	if (results == null)
	{
		if (client == SERVER_INDEX)
		{
			char sMessage[256];
			FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseStatsFailed", LANG_SERVER, error);
			LogError("[DBStats_Callback] %s", sMessage);
		}
		else
			CReplyToCommand(client, "%t %t", "Tag", "DatabaseStatsFailed", error);
		CVLog.Debug("[DBStats_Callback] Error: %s", error);
		return;
	}

	if (!results.FetchRow())
	{
		if (client == SERVER_INDEX)
		{
			char sMessage[256];
			FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseNoData", LANG_SERVER);
			PrintToServer("[CallVote] %s", sMessage);
		}
		else
			CReplyToCommand(client, "%t %t", "Tag", "DatabaseNoData");
		return;
	}

	int total = results.FetchInt(0);
	int difficulty = results.FetchInt(1);
	int restart = results.FetchInt(2);
	int kick = results.FetchInt(3);
	int mission = results.FetchInt(4);
	int lobby = results.FetchInt(5);
	int chapter = results.FetchInt(6);
	int alltalk = results.FetchInt(7);

	if (client == SERVER_INDEX)
	{
		char sMessage[256];
		FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseStatsHeader", LANG_SERVER);
		PrintToServer("[CallVote] %s", sMessage);
		FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseStatsTotal", LANG_SERVER, total);
		PrintToServer("[CallVote] %s", sMessage);
		FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseStatsChangeDifficulty", LANG_SERVER, difficulty);
		PrintToServer("[CallVote] %s", sMessage);
		FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseStatsRestartGame", LANG_SERVER, restart);
		PrintToServer("[CallVote] %s", sMessage);
		FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseStatsKick", LANG_SERVER, kick);
		PrintToServer("[CallVote] %s", sMessage);
		FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseStatsChangeMission", LANG_SERVER, mission);
		PrintToServer("[CallVote] %s", sMessage);
		FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseStatsReturnToLobby", LANG_SERVER, lobby);
		PrintToServer("[CallVote] %s", sMessage);
		FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseStatsChangeChapter", LANG_SERVER, chapter);
		PrintToServer("[CallVote] %s", sMessage);
		FormatEx(sMessage, sizeof(sMessage), "%T", "DatabaseStatsChangeAllTalk", LANG_SERVER, alltalk);
		PrintToServer("[CallVote] %s", sMessage);
	}
	else
	{
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseStatsHeader");
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseStatsTotal", total);
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseStatsChangeDifficulty", difficulty);
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseStatsRestartGame", restart);
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseStatsKick", kick);
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseStatsChangeMission", mission);
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseStatsReturnToLobby", lobby);
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseStatsChangeChapter", chapter);
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseStatsChangeAllTalk", alltalk);
	}
}

/**
 * Initiates an asynchronous database connection.
 * 
 * Validates the configuration exists, initializes connection status variables,
 * and attempts to establish a database connection using the specified configuration.
 *
 * @param sConfigName   Name of the database configuration in databases.cfg.
 * @noreturn           Function returns early if configuration is not found.
 */
void ConnectDB(char[] sConfigName)
{
	g_bSQLConnected = false;
	g_bSQLTableExists = false;
	
	if (!SQL_CheckConfig(sConfigName))
	{
		CVLog.Debug("[ConnectDB] Database failure: could not find database config: %s", sConfigName);
		return;
	}

	CVLog.Debug("[ConnectDB] Attempting to connect to database config: %s", sConfigName);
	Database.Connect(ConnectCallback, sConfigName);
}

/**
 * Callback function for database connection attempts.
 * 
 * Handles the result of database connection attempts, validates the connection,
 * identifies the database driver type, configures database settings (charset for MySQL),
 * and initiates table existence verification.
 *
 * @param database  Database handle if connection succeeded (null if failed).
 * @param error     Error message if connection failed (empty string if successful).
 * @param data      Additional data passed from the connection request (unused).
 * @noreturn       Sets global connection status variables and triggers table check.
 */
void ConnectCallback(Database database, const char[] error, any data)
{
	g_bSQLConnected = false;
	g_bSQLTableExists = false;

	if (database == null)
	{
		CVLog.Debug("[ConnectCallback] Could not connect to database: %s", error);
		return;
	}
	
	if (error[0] != '\0')
	{
		CVLog.Debug("[ConnectCallback] Error to connect to database: %s", error);
		return;
	}

	g_db = database;
	g_bSQLConnected = true;
	CVLog.Debug("[ConnectCallback] Successfully connected to database.");

	DBDriver driver = database.Driver;
	if (driver == null)
	{
		CVLog.Debug("[ConnectCallback] Failed to get database driver.");
		g_bSQLConnected = false;
		return;
	}

	char sSQLDriverName[64];
	driver.GetIdentifier(sSQLDriverName, sizeof(sSQLDriverName));
	CVLog.Debug("[ConnectCallback] Driver: %s", sSQLDriverName);

	if (StrEqual(sSQLDriverName, "mysql", false))
	{
		g_SQLDriver = SQL_MySQL;
		if (database.SetCharset("utf8"))
			CVLog.Debug("[ConnectCallback] Database charset set to UTF-8.");
		else
			CVLog.Debug("[ConnectCallback] Failed to set database charset.");
	}
	else if (StrEqual(sSQLDriverName, "sqlite", false))
	{
		g_SQLDriver = SQL_SQLite;
	}
	else
	{
		CVLog.Debug("[ConnectCallback] Unknown database driver: %s", sSQLDriverName);
		g_bSQLConnected = false;
		return;
	}

	if (g_SQLDriver == SQL_SQLite)
		EnsureSQLiteSchema();

	CheckTableExists();
}

/**
 * Verifies if the required database table exists.
 * 
 * Constructs and executes a database-specific query to check for table existence.
 * Uses information_schema for MySQL and sqlite_master for SQLite databases.
 *
 * @noreturn       Executes asynchronous query with CheckTableCallback as handler.
 * @error          Returns early if database is not connected or driver is unknown.
 */
void CheckTableExists()
{
	if (!g_bSQLConnected || g_db == null)
	{
		CVLog.Debug("[CheckTableExists] Not connected to database.");
		g_bSQLTableExists = false;
		return;
	}

	char sQuery[256];
	switch (g_SQLDriver)
	{
		case SQL_MySQL:
		{
			g_db.Format(sQuery, sizeof(sQuery),
				"SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = '%s' LIMIT 1",
				g_sTable);
		}
		case SQL_SQLite:
		{
			g_db.Format(sQuery, sizeof(sQuery),
				"SELECT 1 FROM sqlite_master WHERE type='table' AND name='%s' LIMIT 1",
				g_sTable);
		}
		default:
		{
			CVLog.Debug("[CheckTableExists] Unknown SQL driver.");
			g_bSQLTableExists = false;
			return;
		}
	}

	CVLog.Query("[CheckTableExists] Executing table existence verification query: %s", sQuery);
	g_db.Query(CheckTableCallback, sQuery);
}

/**
 * Callback function for table existence verification query.
 * 
 * Processes the result of table existence check and updates the global table status.
 * Sets g_bSQLTableExists based on whether the query returned any rows.
 *
 * @param database  Database handle that executed the query.
 * @param results   Result set from the table existence query (null if query failed).
 * @param error     Error message if the query failed (empty string if successful).
 * @param data      Additional data passed to the callback (unused).
 * @noreturn       Updates g_bSQLTableExists global variable.
 */
void CheckTableCallback(Database database, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		CVLog.Debug("[CheckTableCallback] Error checking table existence: %s", error);
		g_bSQLTableExists = false;
		return;
	}

	g_bSQLTableExists = results.FetchRow();
	CVLog.Debug("[CheckTableCallback] Table '%s' exists: %s", g_sTable, g_bSQLTableExists ? "true" : "false");

	if (!g_bSQLTableExists && g_SQLDriver == SQL_MySQL)
		CVLog.Debug("[CheckTableCallback] MySQL table `%s` is missing; apply schema migrations", g_sTable);
}
