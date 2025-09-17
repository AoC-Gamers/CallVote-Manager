#if defined _callvotemanager_sql_included
	#endinput
#endif
#define _callvotemanager_sql_included

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

ConVar
	g_cvarRegLogSQL,
	g_cvarCleanupDays,
	g_cvarIsMasterServer;

char
	g_sTable[] = "callvote_log",
	g_sControlTable[] = "callvote_cleanup_control";

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

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public void OnPluginStart_SQL()
{
	g_cvarRegLogSQL = CreateConVar("sm_cvm_sql", "0", "SQL logging flags <dificulty:1, restartgame:2, kick:4, changemission:8, lobby:16, chapter:32, alltalk:64, ALL:127, NONE:0>", FCVAR_NOTIFY, true, 0.0, true, 127.0);
	g_cvarCleanupDays = CreateConVar("sm_cvm_cleanup_days", "30", "Days to keep records in automatic cleanup", FCVAR_NOTIFY, true, 1.0, true, 365.0);
	g_cvarIsMasterServer = CreateConVar("sm_cvm_master_server", "0", "Designate this server as master for automatic cleanup (0=disabled, 1=enabled)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	RegAdminCmd("sm_cv_sql_install", Command_CreateSQL, ADMFLAG_ROOT, "Install SQL tables");
	RegAdminCmd("sm_cv_sql_cleanup", Command_CleanupDB, ADMFLAG_ROOT, "Clean up database records");
	RegAdminCmd("sm_cv_sql_truncate", Command_TruncateDB, ADMFLAG_ROOT, "Completely clear database table");
	RegAdminCmd("sm_cv_sql_stats", Command_DBStats, ADMFLAG_GENERIC, "Show database statistics");
	RegAdminCmd("sm_cv_sql_auto", Command_AutoCleanupControl, ADMFLAG_ROOT, "Control automatic cleanup system");
}

Action Command_CreateSQL(int iClient, int iArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (!g_cvarRegLogSQL.IntValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "SQLDisabled");
		return Plugin_Handled;
	}

	if (!g_bSQLConnected)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "DBNoConnect");
		return Plugin_Handled;
	}

	char sQueryTable[1024];
	char sQueryTrigger[512];
	bool bIsMySQL = false;
	int iLen = 0;

	switch (g_SQLDriver)
	{
		case SQL_MySQL:
		{
			bIsMySQL = true;
			iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "CREATE TABLE IF NOT EXISTS `%s` ( ", g_sTable);
			iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`id` INT AUTO_INCREMENT PRIMARY KEY, ");
			iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`authid` VARCHAR(64) NOT NULL DEFAULT '' COMMENT 'Client SteamID2 calling for a vote', ");
			iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`created` INT NOT NULL DEFAULT 0 COMMENT 'Creation date in UNIX format (auto-filled by trigger)', ");
			iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`type` INT NOT NULL DEFAULT 0 COMMENT 'Type of vote', ");
			iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`authidTarget` VARCHAR(64) NOT NULL DEFAULT '' COMMENT 'SteamID2 of the objective of a kick vote' ");
			iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, ") ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;");

			int iTriggerLen = 0;
			iTriggerLen += Format(sQueryTrigger[iTriggerLen], sizeof(sQueryTrigger) - iTriggerLen, "CREATE TRIGGER IF NOT EXISTS `trg_callvote_log_before_insert` ");
			iTriggerLen += Format(sQueryTrigger[iTriggerLen], sizeof(sQueryTrigger) - iTriggerLen, "BEFORE INSERT ON `%s` ", g_sTable);
			iTriggerLen += Format(sQueryTrigger[iTriggerLen], sizeof(sQueryTrigger) - iTriggerLen, "FOR EACH ROW ");
			iTriggerLen += Format(sQueryTrigger[iTriggerLen], sizeof(sQueryTrigger) - iTriggerLen, "SET NEW.created = UNIX_TIMESTAMP();");
		}
		case SQL_SQLite:
		{
			iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "CREATE TABLE IF NOT EXISTS `%s` ( ", g_sTable);
			iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`id` INTEGER PRIMARY KEY AUTOINCREMENT, ");
			iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`authid` TEXT NOT NULL DEFAULT '', ");
			iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`created` INTEGER NOT NULL DEFAULT 0, "); // SQLite will still rely on manual insertion of UNIX time
			iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`type` INTEGER NOT NULL DEFAULT 0, ");
			iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, "`authidTarget` TEXT NOT NULL DEFAULT '' ");
			iLen += Format(sQueryTable[iLen], sizeof(sQueryTable) - iLen, ");");
		}
		default:
		{
			CVLog.Debug("[Command_CreateSQL] Unknown SQL driver: %d", view_as<int>(g_SQLDriver));
			CReplyToCommand(iClient, "%t %t", "Tag", "DBUnknownDriver");
			return Plugin_Handled;
		}
	}

	CVLog.Query("[Command_CreateSQL] Executing table creation query: %s", sQueryTable);
	if (!SQL_FastQuery(g_db, sQueryTable))
	{
		char sSQLError[250];
		SQL_GetError(g_db, sSQLError, sizeof(sSQLError));
		CVLog.Query("[Command_CreateSQL] SQL_FastQuery failed for table creation. Error: %s", sSQLError);
		CReplyToCommand(iClient, "%t %t", "Tag", "DBQueryErrorTable");
		return Plugin_Handled;
	}

	CReplyToCommand(iClient, "%t %t", "Tag", "DBTableCreated", g_sTable);
	CVLog.Debug("[Command_CreateSQL] Table `%s` created successfully or already existed.", g_sTable);

	// Create control table for cleanup management
	CreateCleanupControlTable();

	if (bIsMySQL && sQueryTrigger[0] != '\0')
	{
		CVLog.Query("[Command_CreateSQL] Executing trigger creation query: %s", sQueryTrigger);
		if (!SQL_FastQuery(g_db, sQueryTrigger))
		{
			char sSQLError[250];
			SQL_GetError(g_db, sSQLError, sizeof(sSQLError));
			CVLog.Query("[Command_CreateSQL] SQL_FastQuery for trigger creation might have failed (or trigger already exists). Error: %s.", sSQLError);
			CReplyToCommand(iClient, "%t %t", "Tag", "DBTriggerIssue", g_sTable);
		}
	}

	return Plugin_Handled;
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
	CVLog.Debug("[OnConfigsExecuted_SQL] Connecting to the database...");
	ConnectDB("callvote");
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

/**
 * Logs a vote action to the SQL database.
 * 
 * This function validates SQL logging settings, checks database connectivity,
 * retrieves client authentication IDs, and constructs appropriate SQL queries
 * based on the database driver type (MySQL/SQLite).
 *
 * @param type      The type of vote action (ChangeDifficulty, RestartGame, Kick, etc.).
 * @param iClient   The client index of the player initiating the vote.
 * @param iTarget   The client index of the target player (only used for Kick votes, default SERVER_INDEX).
 * @noreturn        Function returns early if logging is disabled or conditions are not met.
 * @error           Function logs errors and returns if AuthID retrieval fails or database is unavailable.
 */
void RegSQLVote(TypeVotes type, int iClient, int iTarget = SERVER_INDEX)
{
	if (!g_cvarRegLogSQL.IntValue)
		return;
	
	int iVoteFlag = 0;
	switch (type)
	{
		case ChangeDifficulty: iVoteFlag = VOTE_CHANGEDIFFICULTY;
		case RestartGame: iVoteFlag = VOTE_RESTARTGAME;
		case Kick: iVoteFlag = VOTE_KICK;
		case ChangeMission: iVoteFlag = VOTE_CHANGEMISSION;
		case ReturnToLobby: iVoteFlag = VOTE_RETURNTOLOBBY;
		case ChangeChapter: iVoteFlag = VOTE_CHANGECHAPTER;
		case ChangeAllTalk: iVoteFlag = VOTE_CHANGEALLTALK;
		default: return;
	}
	
	if (!(g_cvarRegLogSQL.IntValue & iVoteFlag))
		return;
	
    if (!g_bSQLConnected || !g_bSQLTableExists)
        return;

    char sAuthID_Client[MAX_AUTHID_LENGTH];
    char sAuthID_Target[MAX_AUTHID_LENGTH];
    
    if (!GetClientAuthId(iClient, AuthId_Steam2, sAuthID_Client, sizeof(sAuthID_Client)))
    {
        CVLog.Debug("[RegSQLVote] Failed to get AuthID for client %d", iClient);
        return;
    }

    if (type == Kick && IsHuman(iTarget))
    {
        if (!GetClientAuthId(iTarget, AuthId_Steam2, sAuthID_Target, sizeof(sAuthID_Target)))
        {
            LogError("[RegVote] Failed to get AuthID for client %N", iTarget);
            return;
        }
    }

    char sQuery[700];

    switch (g_SQLDriver)
    {
        case SQL_MySQL:
        {
            if (type == Kick && sAuthID_Target[0] != '\0')
            {
                g_db.Format(sQuery, sizeof(sQuery),
                    "INSERT INTO `%s` (authid, type, authidTarget) VALUES ('%s', %d, '%s')",
                    g_sTable, sAuthID_Client, view_as<int>(type), sAuthID_Target);
            }
            else
            {
                g_db.Format(sQuery, sizeof(sQuery),
                    "INSERT INTO `%s` (authid, type) VALUES ('%s', %d)",
                    g_sTable, sAuthID_Client, view_as<int>(type));
            }
        }
        case SQL_SQLite:
        {
            int iTime = GetTime();
            if (type == Kick && sAuthID_Target[0] != '\0')
            {
                g_db.Format(sQuery, sizeof(sQuery),
                    "INSERT INTO `%s` (authid, created, type, authidTarget) VALUES ('%s', %d, %d, '%s')",
                    g_sTable, sAuthID_Client, iTime, view_as<int>(type), sAuthID_Target);
            }
            else
            {
                g_db.Format(sQuery, sizeof(sQuery),
                    "INSERT INTO `%s` (authid, created, type) VALUES ('%s', %d, %d)",
                    g_sTable, sAuthID_Client, iTime, view_as<int>(type));
            }
        }
        default:
        {
            CVLog.Debug("Unknown SQL driver in RegSQLVote.");
            return;
        }
    }

	CVLog.Debug("Driver: %s | Query: %s", g_SQLDriver == SQL_MySQL ? "MySQL" : "SQLite", sQuery);
	
	// Log SQL queries with unified logging system
	CVLog.Query("[RegSQLVote] Executing %s INSERT query: %s", g_SQLDriver == SQL_MySQL ? "MySQL" : "SQLite", sQuery);
	
	// Execute query directly for essential logging
	g_db.Query(CallBack_logSQL, sQuery);
}

/**
 * Callback for SQL vote logging queries
 * Handles success/error reporting for vote logging operations
 */
public void CallBack_logSQL(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null)
	{
		CVLog.Query("[CallBack_logSQL] Database handle is null");
		return;
	}

	if (error[0] != '\0')
	{
		CVLog.Query("[CallBack_logSQL] SQL Error: %s", error);
		return;
	}

	CVLog.Query("[CallBack_logSQL] Vote record inserted successfully");
}

/**
 * Command to clean up old database records
 * Usage: sm_cv_sql_cleanup [days] - Clean records older than X days (default: 30)
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

	DataPack pack = new DataPack();
	pack.WriteCell(iClient == SERVER_INDEX ? SERVER_INDEX : GetClientUserId(iClient));
	pack.WriteCell(days);

	CVLog.Query("[Command_CleanupDB] Executing cleanup DELETE query: %s", sQuery);
	g_db.Query(CleanupDB_Callback, sQuery, pack);
	CReplyToCommand(iClient, "%t %t", "Tag", "CleaningUpRecords", days);

	return Plugin_Handled;
}

/**
 * Command to completely truncate (empty) the database table
 * Usage: sm_cv_sql_truncate - Requires confirmation
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

	DataPack pack = new DataPack();
	pack.WriteCell(iClient == SERVER_INDEX ? SERVER_INDEX : GetClientUserId(iClient));

	CVLog.Query("[Command_TruncateDB] Executing table truncate query: %s", sQuery);
	g_db.Query(TruncateDB_Callback, sQuery, pack);
	CReplyToCommand(iClient, "%t %t", "Tag", "TruncatingTable");

	return Plugin_Handled;
}

/**
 * Command to show database statistics
 * Usage: sm_cv_sql_stats - Show total records and breakdown by vote type
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

	DataPack pack = new DataPack();
	pack.WriteCell(iClient == SERVER_INDEX ? SERVER_INDEX : GetClientUserId(iClient)); // Handle server console

	CVLog.Query("[Command_DBStats] Executing statistics SELECT query: %s", sQuery);
	g_db.Query(DBStats_Callback, sQuery, pack);

	return Plugin_Handled;
}

/**
 * Command to control automatic cleanup system
 * Usage: sm_cv_sql_auto [start|stop|status|force]
 */
Action Command_AutoCleanupControl(int iClient, int iArgs)
{
	if (!g_cvarRegLogSQL.IntValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "SQLDisabled");
		return Plugin_Handled;
	}

	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t Usage: sm_cv_sql_auto <start|stop|status|force>", "Tag");
		CReplyToCommand(iClient, "%t - start: Start automatic cleanup", "Tag");
		CReplyToCommand(iClient, "%t - stop: Stop automatic cleanup", "Tag");
		CReplyToCommand(iClient, "%t - status: Show current status", "Tag");
		CReplyToCommand(iClient, "%t - force: Force cleanup now", "Tag");
		return Plugin_Handled;
	}

	char sAction[16];
	GetCmdArg(1, sAction, sizeof(sAction));

	if (StrEqual(sAction, "start", false))
	{
		if (!g_cvarIsMasterServer.BoolValue)
		{
			CReplyToCommand(iClient, "%t This server is not designated as master server.", "Tag");
			return Plugin_Handled;
		}

		// Manual trigger of cleanup check
		CheckCleanupConditions();
		CReplyToCommand(iClient, "%t Automatic cleanup check triggered.", "Tag");
	}
	else if (StrEqual(sAction, "stop", false))
	{
		// With event-based system, there's no persistent timer to stop
		CReplyToCommand(iClient, "%t Event-based cleanup system cannot be stopped (no persistent timers).", "Tag");
	}
	else if (StrEqual(sAction, "status", false))
	{
		CReplyToCommand(iClient, "%t === Automatic Cleanup Status ===", "Tag");
		CReplyToCommand(iClient, "%t Master Server: %s", "Tag", g_cvarIsMasterServer.BoolValue ? "Yes" : "No");
		CReplyToCommand(iClient, "%t Cleanup Days: %d", "Tag", g_cvarCleanupDays.IntValue);
		CReplyToCommand(iClient, "%t System Type: Event-based (no persistent timers)", "Tag");
		CReplyToCommand(iClient, "%t Database Connected: %s", "Tag", g_bSQLConnected ? "Yes" : "No");
		
		// Query control table for last cleanup info
		if (g_bSQLConnected)
		{
			GetLastCleanupInfo(iClient);
		}
	}
	else if (StrEqual(sAction, "force", false))
	{
		if (!g_bSQLConnected || !g_bSQLTableExists)
		{
			CReplyToCommand(iClient, "%t %t", "Tag", "DBNoConnect");
			return Plugin_Handled;
		}

		int days = g_cvarCleanupDays.IntValue;
		if (days <= 0)
		{
			CReplyToCommand(iClient, "%t Invalid cleanup days value: %d", "Tag", days);
			return Plugin_Handled;
		}

		CReplyToCommand(iClient, "%t Forcing automatic cleanup (records older than %d days)...", "Tag", days);
		PerformAutomaticCleanupSimple(days);
	}
	else
	{
		CReplyToCommand(iClient, "%t Invalid action. Use: start, stop, status, or force", "Tag");
	}

	return Plugin_Handled;
}

/**
 * Creates the cleanup control table for managing automatic cleanup across server restarts
 */
void CreateCleanupControlTable()
{
	if (!g_bSQLConnected || g_db == null)
		return;

	char sQuery[512];
	switch (g_SQLDriver)
	{
		case SQL_MySQL:
		{
			Format(sQuery, sizeof(sQuery),
				"CREATE TABLE IF NOT EXISTS `%s` ( "...
				"`id` INT PRIMARY KEY DEFAULT 1, "...
				"`last_cleanup` INT NOT NULL DEFAULT 0 COMMENT 'Last cleanup timestamp', "...
				"`cleanup_count` INT NOT NULL DEFAULT 0 COMMENT 'Total cleanup operations performed' "...
				") ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci",
				g_sControlTable);
		}
		case SQL_SQLite:
		{
			Format(sQuery, sizeof(sQuery),
				"CREATE TABLE IF NOT EXISTS `%s` ( "...
				"`id` INTEGER PRIMARY KEY DEFAULT 1, "...
				"`last_cleanup` INTEGER NOT NULL DEFAULT 0, "...
				"`cleanup_count` INTEGER NOT NULL DEFAULT 0 "...
				")",
				g_sControlTable);
		}
		default:
		{
			CVLog.Debug("[CreateCleanupControlTable] Unknown SQL driver");
			return;
		}
	}

	CVLog.Query("[CreateCleanupControlTable] Executing control table creation query: %s", sQuery);
	if (!SQL_FastQuery(g_db, sQuery))
	{
		char sSQLError[250];
		SQL_GetError(g_db, sSQLError, sizeof(sSQLError));
		CVLog.Debug("[CreateCleanupControlTable] Failed to create control table: %s", sSQLError);
		return;
	}

	CVLog.Debug("[CreateCleanupControlTable] Control table `%s` created successfully", g_sControlTable);
	
	// Initialize the table with default values if it's empty
	InitializeControlTable();
}

/**
 * Checks if cleanup control table exists and creates it if necessary
 */
void CheckCleanupControlTable()
{
	if (!g_bSQLConnected || g_db == null)
		return;

	char sQuery[256];
	switch (g_SQLDriver)
	{
		case SQL_MySQL:
		{
			g_db.Format(sQuery, sizeof(sQuery),
				"SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = '%s' LIMIT 1",
				g_sControlTable);
		}
		case SQL_SQLite:
		{
			g_db.Format(sQuery, sizeof(sQuery),
				"SELECT 1 FROM sqlite_master WHERE type='table' AND name='%s' LIMIT 1",
				g_sControlTable);
		}
		default:
		{
			CVLog.Debug("[CheckCleanupControlTable] Unknown SQL driver");
			return;
		}
	}

	CVLog.Query("[CheckCleanupControlTable] Executing table existence check query: %s", sQuery);
	g_db.Query(CheckControlTableCallback, sQuery);
}

/**
 * Callback for control table existence check
 */
public void CheckControlTableCallback(Database database, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		CVLog.Debug("[CheckControlTableCallback] Error checking control table: %s", error);
		return;
	}

	bool tableExists = results.FetchRow();
	if (!tableExists)
	{
		CVLog.Debug("[CheckControlTableCallback] Control table doesn't exist, creating it");
		CreateCleanupControlTable();
	}
	else
	{
		CVLog.Debug("[CheckControlTableCallback] Control table exists");
	}
}

/**
 * Initializes the control table with default values
 */
void InitializeControlTable()
{
	char sQuery[256];
	switch (g_SQLDriver)
	{
		case SQL_MySQL:
		{
			g_db.Format(sQuery, sizeof(sQuery),
				"INSERT IGNORE INTO `%s` (id, last_cleanup, cleanup_count) VALUES (1, 0, 0)",
				g_sControlTable);
		}
		case SQL_SQLite:
		{
			g_db.Format(sQuery, sizeof(sQuery),
				"INSERT OR IGNORE INTO `%s` (id, last_cleanup, cleanup_count) VALUES (1, 0, 0)",
				g_sControlTable);
		}
		default:
		{
			CVLog.Debug("[InitializeControlTable] Unknown SQL driver");
			return;
		}
	}

	CVLog.Query("[InitializeControlTable] Executing control table initialization query: %s", sQuery);
	g_db.Query(InitControlTableCallback, sQuery);
}

/**
 * Callback for control table initialization
 */
public void InitControlTableCallback(Database database, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		CVLog.Debug("[InitControlTableCallback] Error initializing control table: %s", error);
		return;
	}
	CVLog.Debug("[InitControlTableCallback] Control table initialized successfully");
}

/**
 * Callback for database cleanup operation
 */
public void CleanupDB_Callback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int userId = pack.ReadCell();
	int days = pack.ReadCell();
	delete pack;

	int client = 0;
	if (userId != 0)
	{
		client = GetClientOfUserId(userId);
		if (!client)
			return;
	}

	if (results == null)
	{
		if (client == SERVER_INDEX)
			LogError("[CleanupDB_Callback] Database cleanup failed: %s", error);
		else
			CReplyToCommand(client, "%t Database cleanup failed: %s", "Tag", error);
		CVLog.Debug("[CleanupDB_Callback] Error: %s", error);
		return;
	}

	int affectedRows = results.AffectedRows;
	if (client == SERVER_INDEX)
		PrintToServer("[CallVote] Database cleanup completed: %d records older than %d days removed.", affectedRows, days);
	else
		CReplyToCommand(client, "%t Database cleanup completed: %d records older than %d days removed.", "Tag", affectedRows, days);
	CVLog.Debug("[CleanupDB_Callback] Cleanup completed: %d rows affected", affectedRows);
}

/**
 * Callback for database truncate operation
 */
public void TruncateDB_Callback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int userId = pack.ReadCell();
	delete pack;

	int client = 0;
	if (userId != 0)
	{
		client = GetClientOfUserId(userId);
		if (!client)
			return;
	}

	if (results == null)
	{
		if (client == SERVER_INDEX)
			LogError("[TruncateDB_Callback] Database truncate failed: %s", error);
		else
			CReplyToCommand(client, "%t Database truncate failed: %s", "Tag", error);
		CVLog.Debug("[TruncateDB_Callback] Error: %s", error);
		return;
	}

	if (client == SERVER_INDEX)
		PrintToServer("[CallVote] Database table truncated successfully. All vote records removed.");
	else
		CReplyToCommand(client, "%t Database table truncated successfully. All vote records removed.", "Tag");
	CVLog.Debug("[TruncateDB_Callback] Table truncated successfully");
}

/**
 * Callback for database statistics query
 */
public void DBStats_Callback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int userId = pack.ReadCell();
	delete pack;

	int client = 0;
	if (userId != 0)
	{
		client = GetClientOfUserId(userId);
		if (!client)
			return;
	}

	if (results == null)
	{
		if (client == SERVER_INDEX)
			LogError("[DBStats_Callback] Database stats query failed: %s", error);
		else
			CReplyToCommand(client, "%t Database stats query failed: %s", "Tag", error);
		CVLog.Debug("[DBStats_Callback] Error: %s", error);
		return;
	}

	if (!results.FetchRow())
	{
		if (client == SERVER_INDEX)
			PrintToServer("[CallVote] No data found in database.");
		else
			CReplyToCommand(client, "%t No data found in database.", "Tag");
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
		// Print to server console
		PrintToServer("[CallVote] === Database Statistics ===");
		PrintToServer("[CallVote] Total Records: %d", total);
		PrintToServer("[CallVote] ChangeDifficulty: %d", difficulty);
		PrintToServer("[CallVote] RestartGame: %d", restart);
		PrintToServer("[CallVote] Kick: %d", kick);
		PrintToServer("[CallVote] ChangeMission: %d", mission);
		PrintToServer("[CallVote] ReturnToLobby: %d", lobby);
		PrintToServer("[CallVote] ChangeChapter: %d", chapter);
		PrintToServer("[CallVote] ChangeAllTalk: %d", alltalk);
	}
	else
	{
		// Print to client
		CReplyToCommand(client, "%t === Database Statistics ===", "Tag");
		CReplyToCommand(client, "%t Total Records: %d", "Tag", total);
		CReplyToCommand(client, "%t ChangeDifficulty: %d", "Tag", difficulty);
		CReplyToCommand(client, "%t RestartGame: %d", "Tag", restart);
		CReplyToCommand(client, "%t Kick: %d", "Tag", kick);
		CReplyToCommand(client, "%t ChangeMission: %d", "Tag", mission);
		CReplyToCommand(client, "%t ReturnToLobby: %d", "Tag", lobby);
		CReplyToCommand(client, "%t ChangeChapter: %d", "Tag", chapter);
		CReplyToCommand(client, "%t ChangeAllTalk: %d", "Tag", alltalk);
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

	CheckTableExists();
	CheckCleanupControlTable();
	CreateTimer(5.0, Timer_CheckCleanupConditions, _, TIMER_FLAG_NO_MAPCHANGE);
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
}

/**
 * Checks when the last cleanup was performed and decides if a new one is needed
 */
void CheckLastCleanupTime(int days)
{
	char sQuery[256];
	g_db.Format(sQuery, sizeof(sQuery),
		"SELECT last_cleanup FROM `%s` WHERE id = 1",
		g_sControlTable);

	DataPack pack = new DataPack();
	pack.WriteCell(days);
	
	CVLog.Query("[CheckLastCleanupTime] Executing last cleanup time check query: %s", sQuery);
	g_db.Query(CheckLastCleanupCallback, sQuery, pack);
}

/**
 * Callback for checking last cleanup time
 */
public void CheckLastCleanupCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int days = pack.ReadCell();
	delete pack;

	if (results == null)
	{
		CVLog.Debug("[CheckLastCleanupCallback] Error checking last cleanup: %s", error);
		return;
	}

	int currentTime = GetTime();
	int lastCleanup = 0;

	if (results.FetchRow())
	{
		lastCleanup = results.FetchInt(0);
	}

	int timeSinceLastCleanup = currentTime - lastCleanup;
	if (timeSinceLastCleanup < 86400 && lastCleanup > 0)
	{
		CVLog.Debug("[CheckLastCleanupCallback] Cleanup already performed recently (%d seconds ago)", timeSinceLastCleanup);
		return;
	}

	CVLog.Debug("[CheckLastCleanupCallback] Starting automatic cleanup (records older than %d days)", days);
	CVLog.Debug("[CheckLastCleanupCallback] Last cleanup: %d seconds ago", timeSinceLastCleanup);
	
	PerformAutomaticCleanupSimple(days);
}

/**
 * Performs automatic cleanup without server tracking (simplified version)
 */
void PerformAutomaticCleanupSimple(int days)
{
	char sQuery[256];
	int cutoffTime = GetTime() - (days * 86400);

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
			CVLog.Debug("[PerformAutomaticCleanupSimple] Unknown SQL driver, aborting cleanup");
			return;
		}
	}

	// Create data pack for callback
	DataPack pack = new DataPack();
	pack.WriteCell(0);
	pack.WriteCell(days);
	pack.WriteCell(1);

	CVLog.Query("[PerformAutomaticCleanupSimple] Executing automatic cleanup query: %s", sQuery);
	g_db.Query(AutoCleanupSimple_Callback, sQuery, pack);
	CVLog.Debug("[PerformAutomaticCleanupSimple] Automatic cleanup query executed");
}

/**
 * Callback for simplified automatic database cleanup operation
 */
public void AutoCleanupSimple_Callback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	pack.ReadCell(); // Skip userId
	int days = pack.ReadCell();
	int isAutomatic = pack.ReadCell();
	delete pack;

	if (results == null)
	{
		LogError("[AutoCleanupSimple_Callback] Automatic database cleanup failed: %s", error);
		return;
	}

	int affectedRows = results.AffectedRows;
	
	if (isAutomatic == 1)
	{
		UpdateCleanupControlTableSimple(affectedRows);
		
		PrintToServer("[CallVote] Automatic database cleanup completed: %d records older than %d days removed", 
			affectedRows, days);
		CVLog.Debug("[AutoCleanupSimple_Callback] Automatic cleanup completed: %d rows affected", affectedRows);
	}
}

/**
 * Updates the control table with cleanup information (simplified version without server tracking)
 */
void UpdateCleanupControlTableSimple(int affectedRows)
{
	char sQuery[256];
	int currentTime = GetTime();
	
	switch (g_SQLDriver)
	{
		case SQL_MySQL:
		{
			g_db.Format(sQuery, sizeof(sQuery),
				"UPDATE `%s` SET last_cleanup = %d, cleanup_count = cleanup_count + 1 WHERE id = 1",
				g_sControlTable, currentTime);
		}
		case SQL_SQLite:
		{
			g_db.Format(sQuery, sizeof(sQuery),
				"UPDATE `%s` SET last_cleanup = %d, cleanup_count = cleanup_count + 1 WHERE id = 1",
				g_sControlTable, currentTime);
		}
		default:
		{
			CVLog.Debug("[UpdateCleanupControlTableSimple] Unknown SQL driver");
			return;
		}
	}

	CVLog.Debug("[UpdateCleanupControlTableSimple] Updating control table: %d rows affected", affectedRows);
	CVLog.Query("[UpdateCleanupControlTableSimple] Executing control table update query: %s", sQuery);
	g_db.Query(UpdateControlTableCallback, sQuery);
}

/**
 * Callback for control table update
 */
public void UpdateControlTableCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		CVLog.Debug("[UpdateControlTableCallback] Error updating control table: %s", error);
		return;
	}
	CVLog.Debug("[UpdateControlTableCallback] Control table updated successfully");
}

/**
 * Gets information about the last cleanup for status display
 */
void GetLastCleanupInfo(int client)
{
	char sQuery[256];
	g_db.Format(sQuery, sizeof(sQuery),
		"SELECT last_cleanup, cleanup_count FROM `%s` WHERE id = 1",
		g_sControlTable);

	DataPack pack = new DataPack();
	pack.WriteCell(client == SERVER_INDEX ? SERVER_INDEX : GetClientUserId(client));

	CVLog.Query("[GetLastCleanupInfo] Executing cleanup info retrieval query: %s", sQuery);
	g_db.Query(LastCleanupInfoCallback, sQuery, pack);
}

/**
 * Callback for last cleanup info query
 */
public void LastCleanupInfoCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int userId = pack.ReadCell();
	delete pack;

	int client = 0;
	if (userId != 0)
	{
		client = GetClientOfUserId(userId);
		if (!client)
			return; // Client disconnected
	}

	if (results == null)
	{
		if (client == SERVER_INDEX)
			PrintToServer("[CallVote] Error getting cleanup info: %s", error);
		else
			CReplyToCommand(client, "%t Error getting cleanup info: %s", "Tag", error);
		return;
	}

	if (results.FetchRow())
	{
		int lastCleanup = results.FetchInt(0);
		int cleanupCount = results.FetchInt(1);

		if (lastCleanup > 0)
		{
			int timeSince = GetTime() - lastCleanup;
			int hours = timeSince / 3600;
			int minutes = (timeSince % 3600) / 60;

			if (client == SERVER_INDEX)
			{
				PrintToServer("[CallVote] Last Cleanup: %d hours, %d minutes ago", hours, minutes);
				PrintToServer("[CallVote] Total Cleanups: %d", cleanupCount);
			}
			else
			{
				CReplyToCommand(client, "%t Last Cleanup: %d hours, %d minutes ago", "Tag", hours, minutes);
				CReplyToCommand(client, "%t Total Cleanups: %d", "Tag", cleanupCount);
			}
		}
		else
		{
			if (client == SERVER_INDEX)
				PrintToServer("[CallVote] No cleanup has been performed yet");
			else
				CReplyToCommand(client, "%t No cleanup has been performed yet", "Tag");
		}
	}
	else
	{
		if (client == SERVER_INDEX)
			PrintToServer("[CallVote] Control table not initialized");
		else
			CReplyToCommand(client, "%t Control table not initialized", "Tag");
	}
}

/**
 * Timer to check cleanup conditions on plugin load/config execution
 */
public Action Timer_CheckCleanupConditions(Handle timer)
{
	// Only check cleanup conditions if this is the master server
	if (!g_cvarIsMasterServer.BoolValue)
	{
		CVLog.Debug("[Timer_CheckCleanupConditions] Not master server, cleanup disabled");
		return Plugin_Stop;
	}

	CheckCleanupConditions();
	return Plugin_Stop;
}

/**
 * Checks if cleanup should run based on current conditions
 */
void CheckCleanupConditions()
{
	// Check all conditions for automatic cleanup
	if (!ShouldRunAutomaticCleanup())
	{
		CVLog.Debug("[CheckCleanupConditions] Conditions not met for automatic cleanup");
		return;
	}

	int days = g_cvarCleanupDays.IntValue;
	if (days <= 0)
	{
		CVLog.Debug("[CheckCleanupConditions] Invalid cleanup days value: %d", days);
		return;
	}

	// Check when was the last cleanup
	CheckLastCleanupTime(days);
}

/**
 * Validates all conditions required for automatic cleanup
 */
bool ShouldRunAutomaticCleanup()
{
	// Basic plugin and SQL conditions
	if (!g_cvarRegLogSQL.IntValue || !g_cvarIsMasterServer.BoolValue)
	{
		CVLog.Debug("[ShouldRunAutomaticCleanup] Basic conditions not met");
		return false;
	}

	// Database must be connected
	if (!g_bSQLConnected || !g_bSQLTableExists)
	{
		CVLog.Debug("[ShouldRunAutomaticCleanup] Database not available");
		return false;
	}

	// Check if server is empty (no human players)
	int humanCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			humanCount++;
		}
	}

	if (humanCount > 0)
	{
		CVLog.Debug("[ShouldRunAutomaticCleanup] Server has %d human players, skipping cleanup", humanCount);
		return false;
	}

	// Check if Confogl is loaded and in match mode
	if (g_bConfogl)
	{
		if (LGO_IsMatchModeLoaded())
		{
			CVLog.Debug("[ShouldRunAutomaticCleanup] Confogl match mode is active, skipping cleanup");
			return false;
		}
	}

	CVLog.Debug("[ShouldRunAutomaticCleanup] All conditions met for automatic cleanup");
	return true;
}