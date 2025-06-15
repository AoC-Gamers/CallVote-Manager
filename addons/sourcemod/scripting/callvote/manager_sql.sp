#if defined _callvotemanager_sql_included
	#endinput
#endif
#define _callvotemanager_sql_included

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

ConVar
	g_cvarRegLogSQL;

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

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public void OnPluginStart_SQL()
{
	g_cvarRegLogSQL = CreateConVar("sm_cvm_sql", "127", "SQL logging flags <dificulty:1, restartgame:2, kick:4, changemission:8, lobby:16, chapter:32, alltalk:64, ALL:127, NONE:0>", FCVAR_NOTIFY, true, 0.0, true, 127.0);
	RegAdminCmd("sm_cv_sql_install", Command_CreateSQL, ADMFLAG_ROOT, "Install SQL tables");
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
			LogDebug("[Command_CreateSQL] Unknown SQL driver: %d", view_as<int>(g_SQLDriver));
			CReplyToCommand(iClient, "%t %t", "Tag", "DBUnknownDriver");
			return Plugin_Handled;
		}
	}

	LogSQL("[Command_CreateSQL] Executing Table Query: %s", sQueryTable);
	if (!SQL_FastQuery(g_db, sQueryTable))
	{
		char sSQLError[250];
		SQL_GetError(g_db, sSQLError, sizeof(sSQLError));
		LogSQL("[Command_CreateSQL] SQL_FastQuery failed for table creation. Error: %s", sSQLError);
		CReplyToCommand(iClient, "%t %t", "Tag", "DBQueryErrorTable");
		return Plugin_Handled;
	}

	CReplyToCommand(iClient, "%t %t", "Tag", "DBTableCreated", g_sTable);
	LogDebug("[Command_CreateSQL] Table `%s` created successfully or already existed.", g_sTable);

	if (bIsMySQL && sQueryTrigger[0] != '\0')
	{
		LogDebug("[Command_CreateSQL] Executing Trigger Query: %s", sQueryTrigger);
		if (!SQL_FastQuery(g_db, sQueryTrigger))
		{
			char sSQLError[250];
			SQL_GetError(g_db, sSQLError, sizeof(sSQLError));
			LogSQL("[Command_CreateSQL] SQL_FastQuery for trigger creation might have failed (or trigger already exists). Error: %s.", sSQLError);
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
	LogDebug("[OnPluginEnd] Database connection closed.");
}

void OnConfigsExecuted_SQL()
{
	if (!g_cvarRegLogSQL.IntValue)
		return;

	if (g_db != null)
		return;
	LogDebug("[OnConfigsExecuted_SQL] Connecting to the database...");
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
	// Check if SQL logging is enabled (any flag > 0)
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
        LogDebug("[RegSQLVote] Failed to get AuthID for client %d", iClient);
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
            LogDebug("Unknown SQL driver in RegSQLVote.");
            return;
        }
    }

	LogDebug("Driver: %s | Query: %s", g_SQLDriver == SQL_MySQL ? "MySQL" : "SQLite", sQuery);
    g_db.Query(CallBack_logSQL, sQuery);
}

/**
 * Callback function for SQL query execution results.
 * Handles the response from database queries and logs success or failure.
 *
 * @param db        Database handle that executed the query.
 * @param results   Result set from the query execution (null if query failed).
 * @param error     Error message if the query failed (empty string if successful).
 * @param data      Additional data passed to the callback (unused in this implementation).
 * @noreturn
 */
public void CallBack_logSQL(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        LogDebug("[CallBack_logSQL] Error: %s", error);
        return;
    }

	LogDebug("[CallBack_logSQL] Vote action logged successfully.");
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
	// Initialize connection status
	g_bSQLConnected = false;
	g_bSQLTableExists = false;
	
	if (!SQL_CheckConfig(sConfigName))
	{
		LogDebug("[ConnectDB] Database failure: could not find database config: %s", sConfigName);
		return;
	}

	LogDebug("[ConnectDB] Attempting to connect to database config: %s", sConfigName);
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
	// Reset connection status
	g_bSQLConnected = false;
	g_bSQLTableExists = false;
	
	// Check for database handle validity first
	if (database == null)
	{
		LogDebug("[ConnectCallback] Could not connect to database: %s", error);
		return;
	}
	
	// Check for error message
	if (error[0] != '\0')
	{
		LogDebug("[ConnectCallback] Error to connect to database: %s", error);
		return;
	}

	// Connection successful
	g_db = database;
	g_bSQLConnected = true;
	LogDebug("[ConnectCallback] Successfully connected to database.");

	// Get and validate database driver
	DBDriver driver = database.Driver;
	if (driver == null)
	{
		LogDebug("[ConnectCallback] Failed to get database driver.");
		g_bSQLConnected = false;
		return;
	}

	char sSQLDriverName[64];
	driver.GetIdentifier(sSQLDriverName, sizeof(sSQLDriverName));
	LogDebug("[ConnectCallback] Driver: %s", sSQLDriverName);

	// Set driver type and configure based on driver
	if (StrEqual(sSQLDriverName, "mysql", false))
	{
		g_SQLDriver = SQL_MySQL;
		if (database.SetCharset("utf8"))
			LogDebug("[ConnectCallback] Database charset set to UTF-8.");
		else
			LogDebug("[ConnectCallback] Failed to set database charset.");
	}
	else if (StrEqual(sSQLDriverName, "sqlite", false))
	{
		g_SQLDriver = SQL_SQLite;
	}
	else
	{
		LogDebug("[ConnectCallback] Unknown database driver: %s", sSQLDriverName);
		g_bSQLConnected = false;
		return;
	}

	// Check if table exists
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
		LogDebug("[CheckTableExists] Not connected to database.");
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
			LogDebug("[CheckTableExists] Unknown SQL driver.");
			g_bSQLTableExists = false;
			return;
		}
	}

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
		LogDebug("[CheckTableCallback] Error checking table existence: %s", error);
		g_bSQLTableExists = false;
		return;
	}

	// If we have at least one row, the table exists
	g_bSQLTableExists = results.FetchRow();
	LogDebug("[CheckTableCallback] Table '%s' exists: %s", g_sTable, g_bSQLTableExists ? "true" : "false");
}