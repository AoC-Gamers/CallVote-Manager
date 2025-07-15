#if defined _cvb_database_included
	#endinput
#endif
#define _cvb_database_included

#define MAX_TABLE_NAME 64
#define TABLE_BANS "callvote_bans"
#define TABLE_CACHE_BANS "callvote_bans_cache"

enum struct InstallationStatus {
	bool mysqlTables;
	bool mysqlProcedures;
	bool sqliteTables;
	bool sqliteIndexes;
	int clientUserId;
	int totalOperations;
	int completedOperations;  // Nuevo campo para rastrear operaciones completadas
	Handle timeoutTimer;
}

InstallationStatus g_InstallStatus;
InstallationPR g_InstallConfig;

#define PROCEDURE_CHECK_ACTIVE_BAN      "sp_CheckActiveBan"
#define PROCEDURE_CHECK_FULL_BAN        "sp_CheckFullBan"
#define PROCEDURE_INSERT_BAN            "sp_InsertBanWithValidation"
#define PROCEDURE_REMOVE_BAN            "sp_RemoveBan"
#define PROCEDURE_CLEAN_EXPIRED         "sp_CleanExpiredBans"
#define PROCEDURE_GET_STATISTICS        "sp_GetBanStatistics"

enum Procedure
{
	PROC_CHECK_ACTIVE_BAN = 0,
	PROC_CHECK_FULL_BAN = 1,
	PROC_INSERT_BAN = 2,
	PROC_REMOVE_BAN = 3,
	PROC_CLEAN_EXPIRED = 4,
	PROC_GET_STATISTICS = 5,
	PROC_SIZE = 6
};

/**
 * Estructura para controlar qué procedimientos instalar
 */
enum struct InstallationPR {
	bool installCheckActiveBan;
	bool installCheckFullBan;
	bool installInsertBan;
	bool installRemoveBan;
	bool installCleanExpired;
	bool installGetStatistics;
	int current;
}

/**
 * Initializes the database connections required for the plugin.
 * This function attempts to connect to both MySQL and SQLite databases.
 * Ensure that the necessary database configuration is set up before calling this function.
 */
void InitDatabase()
{
	ConnectMySQL();
	ConnectSQLite();
}

/**
 * Attempts to establish a connection to a MySQL database using the configuration specified by TABLE_BANS.
 * If the configuration exists, initiates an asynchronous connection and sets MySQL_ConnectCallback as the callback.
 * If the configuration does not exist, logs a message and defaults to using SQLite.
 */
void ConnectMySQL()
{
	if (SQL_CheckConfig(TABLE_BANS))
	{
		SQL_TConnect(MySQL_ConnectCallback, TABLE_BANS);
	}
	else
	{
		CVBLog.SQL("MySQL configuration '%s' not found, using SQLite only", TABLE_BANS);
	}
}

public void MySQL_ConnectCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("Error connecting to MySQL: %s", error);
		return;
	}
	
	g_hMySQLDB = view_as<Database>(hndl);
	
	CVBLog.SQL("MySQL connection established");
}

/**
 * Establishes a connection to the local SQLite database used for storing callvote ban cache data.
 * Builds the database file path, attempts to connect, and logs the result.
 * If the connection fails, logs an error message.
 */
void ConnectSQLite()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/callvote_bans_cache.db");
	
	char sError[256];
	g_hSQLiteDB = SQLite_UseDatabase("callvote_bans_cache", sError, sizeof(sError));
	
	if (g_hSQLiteDB == null)
	{
		LogError("Error connecting to SQLite: %s", sError);
		return;
	}
	
	CVBLog.SQL("SQLite connection established: %s", sPath);
}

/**
 * Creates the necessary MySQL tables for the CallVote Manager plugin.
 *
 * This function constructs and executes a SQL query to create the bans table if it does not already exist.
 * The table includes fields for ban identification, account information, ban type, timestamps, duration,
 * admin information, reason, and active status. It also sets up unique and regular indexes to optimize
 * queries related to active bans and account lookups.
 */
void CreateMySQLTables()
{
	char sQuery[MAX_QUERY_LENGTH];
	int iLen = 0;
	
	iLen = 0;
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "CREATE TABLE IF NOT EXISTS %s (", TABLE_BANS);
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "id INT AUTO_INCREMENT PRIMARY KEY, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "account_id INT NOT NULL, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "ban_type INT NOT NULL, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "created_timestamp INT NOT NULL, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "duration_minutes INT NOT NULL DEFAULT 0, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "expires_timestamp INT NOT NULL DEFAULT 0, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "admin_account_id INT, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "reason TEXT DEFAULT NULL, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "is_active BOOLEAN DEFAULT TRUE, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "UNIQUE KEY unique_active_ban (account_id, is_active), ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "INDEX idx_account_id (account_id), ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "INDEX idx_active_account (account_id, is_active, expires_timestamp)");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
	
	SQL_TQuery(g_hMySQLDB, MySQLTables_Callback, sQuery);
}

public void QueryBan_MySQLCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	DataPack dpQueryBanMySQL = view_as<DataPack>(data);
	dpQueryBanMySQL.Reset();
	int accountId = dpQueryBanMySQL.ReadCell();
	int client = dpQueryBanMySQL.ReadCell();
	dpQueryBanMySQL.ReadCell();
	delete dpQueryBanMySQL;
	
	if (hndl == null)
	{
		CVBLog.MySQL("Error querying MySQL ban: %s", error);
		if (g_hSQLiteDB != null)
		{
			QueryBanByAccountId_SQLite(accountId, client);
		}
		return;
	}
	
	DBResultSet results = view_as<DBResultSet>(hndl);
	ProcessBanQueryResult(results, accountId, client, true);
}

/**
 * Creates the necessary SQLite tables for the plugin.
 *
 * This function constructs and executes a SQL query to create the bans table if it does not already exist.
 * NOTE: Indexes are created separately in CreateSQLiteIndexes() via callback control for consistent flow with MySQL.
 */
void CreateSQLiteTables()
{
	CVBLog.Debug("CreateSQLiteTables() called");
	
	if (g_hSQLiteDB == null)
	{
		CVBLog.Debug("SQLite database handle is null, aborting table creation");
		MarkOperationComplete("sqlite_tables", false);
		return;
	}
	
	char sQuery[MAX_QUERY_LENGTH];
	int iLen = 0;
	
	// Crear tabla de cache SQLite según el esquema en callvote_bans_sqlite.sql
	iLen = 0;
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "CREATE TABLE IF NOT EXISTS `%s` (", TABLE_CACHE_BANS);
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "`account_id` INTEGER PRIMARY KEY, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "`ban_type` INTEGER NOT NULL DEFAULT 0, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "`cached_timestamp` INTEGER NOT NULL DEFAULT 0, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "`ttl_expires` INTEGER NOT NULL DEFAULT 0");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, ")");
	
	CVBLog.Debug("Executing SQLite cache table creation query: %s", sQuery);
	SQL_TQuery(g_hSQLiteDB, SQLiteTables_Callback, sQuery);
}

/**
 * Creates necessary SQLite indexes for the bans table to optimize query performance.
 *
 * This function creates indexes on the 'expires_timestamp' and 'cached_timestamp'
 * columns of the bans table if they do not already exist. Indexes help speed up
 * database queries that filter or sort by these columns.
 *
 * The queries are executed asynchronously using SQL_TQuery with tracking callback.
 */
void CreateSQLiteIndexes()
{
	CVBLog.Debug("CreateSQLiteIndexes() called");
	
	if (g_hSQLiteDB == null)
	{
		CVBLog.Debug("SQLite database handle is null, aborting index creation");
		MarkOperationComplete("sqlite_indexes", false);
		return;
	}
	
	char sQuery[MAX_QUERY_LENGTH];
	
	// Crear índice para limpieza de TTL según el esquema en callvote_bans_sqlite.sql
	Format(sQuery, sizeof(sQuery), "CREATE INDEX IF NOT EXISTS `idx_cache_ttl_cleanup` ON `%s`(`ttl_expires`)", TABLE_CACHE_BANS);
	CVBLog.Debug("Executing SQLite TTL cleanup index creation: %s", sQuery);
	SQL_TQuery(g_hSQLiteDB, SQLiteIndexes_Callback, sQuery);
}

public void QueryBan_SQLiteCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	DataPack dpQueryBanSQLite = view_as<DataPack>(data);
	dpQueryBanSQLite.Reset();
	int accountId = dpQueryBanSQLite.ReadCell();
	int client = dpQueryBanSQLite.ReadCell();
	dpQueryBanSQLite.ReadCell();
	delete dpQueryBanSQLite;
	
	DBResultSet results = view_as<DBResultSet>(hndl);
	if (results == null)
	{
		CVBLog.SQLite("Error querying SQLite ban: %s", error);
		return;
	}
	
	ProcessBanQueryResult(results, accountId, client, false);
}

/**
 * Processes the result of a ban query for a specific player account.
 *
 * This function checks if a ban exists for the given account ID by examining the provided
 * database result set. If a ban is found, it populates the PlayerBanInfo structure for the
 * client, updates the string map cache, and, if the query originated from MySQL, updates
 * the SQLite cache as well. If no ban is found, it updates the cache and resets the ban
 * information for the client.
 *
 * @param results        The database result set containing the ban query results.
 * @param accountId      The account ID of the player being checked.
 * @param client         The client index associated with the player.
 * @param fromMySQL      True if the query was executed on a MySQL database, false otherwise.
 */
void ProcessBanQueryResult(DBResultSet results, int accountId, int client, bool fromMySQL)
{
	bool hasBan = results.FetchRow();
	
	if (hasBan)
	{
		PlayerBanInfo banInfo;
		banInfo.accountId = results.FetchInt(0);
		banInfo.banType = results.FetchInt(1);
		banInfo.createdTimestamp = results.FetchInt(2);
		banInfo.durationMinutes = results.FetchInt(3);
		banInfo.expiresTimestamp = results.FetchInt(4);
		banInfo.isLoaded = true;
		banInfo.isChecking = false;
		
		if (IsValidClientIndex(client))
		{
			g_PlayerBans[client] = banInfo;
		}
		
		UpdateStringMapCache(accountId, true, banInfo.banType);
		
		if (fromMySQL && g_hSQLiteDB != null)
		{
			UpdateSQLiteCache(banInfo);
		}
		
		CVBLog.Debug("Ban found for AccountID %d: Type=%d, Expires=%d", 
			accountId, banInfo.banType, banInfo.expiresTimestamp);
	}
	else
	{
		UpdateStringMapCache(accountId, false, 0);
		
		if (IsValidClientIndex(client))
		{
			g_PlayerBans[client].isLoaded = true;
			g_PlayerBans[client].isChecking = false;
			g_PlayerBans[client].banType = 0;
		}
		
		CVBLog.Debug("No active ban for AccountID %d", accountId);
	}
}

void QueryBanByAccountId_SQLite(int accountId, int client)
{
	char sQuery[MAX_QUERY_LENGTH];
	int iLen = 0;
	
	DataPack dp = new DataPack();
	dp.WriteCell(accountId);
	dp.WriteCell(client);
	dp.WriteCell(GetTime());
	
	iLen = 0;
	// Consultar la tabla de cache SQLite simplificada
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "SELECT account_id, ban_type, cached_timestamp, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "0 as duration_minutes, ttl_expires, 0 as admin_account_id, 0 as reason ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "FROM `%s` WHERE account_id = %d ", TABLE_CACHE_BANS, accountId);
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "AND (ttl_expires = 0 OR ttl_expires > %d) ", GetTime());
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "ORDER BY cached_timestamp DESC LIMIT 1");
	
	SQL_TQuery(g_hSQLiteDB, QueryBan_SQLiteCallback, sQuery, dp);
}

/**
 * Updates the local SQLite cache with ban information for a player.
 *
 * This function inserts or replaces a ban record in the local SQLite database cache.
 * It constructs an SQL REPLACE statement with the provided ban information.
 *
 * @param banInfo           Struct containing the player's ban information.
 */
void UpdateSQLiteCache(PlayerBanInfo banInfo)
{
	if (g_hSQLiteDB == null)
		return;
	
	char sQuery[MAX_QUERY_LENGTH];
	int iLen = 0;
	
	// Calcular TTL de expiración (24 horas por defecto para cache)
	int ttlExpires = GetTime() + (24 * 60 * 60); // 24 horas
	
	iLen = 0;
	// Actualizar tabla de cache SQLite simplificada
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "REPLACE INTO `%s` (", TABLE_CACHE_BANS);
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "`account_id`, `ban_type`, `cached_timestamp`, `ttl_expires`) ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "VALUES (%d, %d, %d, %d)",
		banInfo.accountId, banInfo.banType, GetTime(), ttlExpires);

	CVBLog.SQLite("SQLite cache updated for AccountID %d, ban type: %d, TTL expires: %d",
		banInfo.accountId, banInfo.banType, ttlExpires);
	
	SQL_TQuery(g_hSQLiteDB, Generic_QueryCallback, sQuery);
}

/**
 * Checks if the specified account has an active ban in the database.
 *
 * @param accountId  The unique identifier of the account to check.
 * @param client     (Optional) The client index associated with the account. Defaults to 0 if not specified.
 *
 * This function initiates an asynchronous SQL query to call the stored procedure 'sp_CheckActiveBan'
 * for the given accountId. The result is handled in the CheckActiveBan_Callback function.
 * If the database connection is not available, the function returns immediately.
 */
void CVB_CheckActiveBan(int accountId, int client = 0)
{
	if (g_hMySQLDB == null)
	{
		return;
	}
	
	char sQuery[512];
	DataPack dpCheckActiveBan = new DataPack();
	dpCheckActiveBan.WriteCell(accountId);
	dpCheckActiveBan.WriteCell(client);
	dpCheckActiveBan.WriteCell(GetTime());
	
	FormatEx(sQuery, sizeof(sQuery), 
		"CALL %s(%d)",
		PROCEDURE_CHECK_ACTIVE_BAN, accountId);
	
	CVBLog.MySQL("CVB_CheckActiveBan: %s", sQuery);
	SQL_TQuery(g_hMySQLDB, CheckActiveBan_Callback, sQuery, dpCheckActiveBan);
}

public void CheckActiveBan_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	DataPack dpCheckActiveBan = view_as<DataPack>(data);
	dpCheckActiveBan.Reset();
	int accountId = dpCheckActiveBan.ReadCell();
	int client = dpCheckActiveBan.ReadCell();
	dpCheckActiveBan.ReadCell();
	delete dpCheckActiveBan;

	if (hndl == null)
	{
		CVBLog.MySQL("Error in sp_CheckActiveBan: %s", error);
		return;
	}

	DBResultSet results = view_as<DBResultSet>(hndl);
	if (!results.FetchRow())
	{
		CVBLog.MySQL("sp_CheckActiveBan returned no results for AccountID %d", accountId);
		return;
	}

	bool isNull = results.IsFieldNull(0);
	int banType = 0;
	if (!isNull)
	{
		banType = results.FetchInt(0);
	}

	if (isNull)
	{
		return;
	}
	else if (banType > 0)
	{
		PlayerBanInfo banInfo;
		banInfo.accountId = accountId;
		banInfo.banType = banType;
		banInfo.isLoaded = true;
		banInfo.isChecking = false;

		if (IsValidClientIndex(client))
		{
			g_PlayerBans[client] = banInfo;
		}

		UpdateStringMapCache(accountId, true, banType);
	}
	else if (banType == 0)
	{
		UpdateStringMapCache(accountId, false, 0);

		if (IsValidClientIndex(client))
		{
			g_PlayerBans[client].isLoaded = true;
			g_PlayerBans[client].isChecking = false;
			g_PlayerBans[client].banType = 0;
		}
	}
}

/**
 * Inserts a ban record into the database using a stored procedure with validation.
 *
 * @param targetAccountId   The account ID of the player to be banned.
 * @param banType           The type of ban to apply (e.g., temporary, permanent).
 * @param durationMinutes   The duration of the ban in minutes.
 * @param adminAccountId    The account ID of the admin issuing the ban.
 * @param reasonCode        The code representing the reason for the ban.
 *
 * This function escapes the reason text, prepares the SQL query, and executes it asynchronously.
 * The result is handled in the CVB_InsertBan_Callback function.
 * If the MySQL database handle is not available, an error is logged and the function returns early.
 */
void CVB_InsertBan(int targetAccountId, int banType, int durationMinutes, int adminAccountId, int reasonCode)
{
	if (g_hMySQLDB == null)
	{
		LogError("MySQL not available for InsertBan");
		int adminId = FindClientByAccountID(adminAccountId);
		CReplyToCommand(adminId, "MySQL not available for InsertBan"); // add translations
		return;
	}
	
	char reasonText[256];
	GetReasonTextByCode(reasonCode, reasonText, sizeof(reasonText));
	
	char sQuery[MAX_QUERY_LENGTH];
	char sEscapedReason[512];
	g_hMySQLDB.Escape(reasonText, sEscapedReason, sizeof(sEscapedReason));
	
	DataPack dpInsertBan = new DataPack();
	dpInsertBan.WriteCell(targetAccountId);
	dpInsertBan.WriteCell(banType);
	dpInsertBan.WriteCell(adminAccountId);
	
	FormatEx(sQuery, sizeof(sQuery), 
		"CALL %s(%d, %d, %d, %d, '%s')", 
		PROCEDURE_INSERT_BAN, targetAccountId, banType, durationMinutes, adminAccountId, sEscapedReason);
		
	CVBLog.MySQL("CVB_InsertBan: %s", sQuery);
	SQL_TQuery(g_hMySQLDB, CVB_InsertBan_Callback, sQuery, dpInsertBan);
}

public void CVB_InsertBan_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	DataPack dpInsertBan = view_as<DataPack>(data);
	dpInsertBan.Reset();
	int targetAccountId = dpInsertBan.ReadCell();
	int banType = dpInsertBan.ReadCell();
	int adminAccountId = dpInsertBan.ReadCell();
	delete dpInsertBan;

	int adminId = FindClientByAccountID(adminAccountId);
	if (hndl == null)
	{
		CVBLog.MySQL("Error in %s: %s", PROCEDURE_INSERT_BAN, error);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Error in %s: %s", PROCEDURE_INSERT_BAN, error); // add translations
		return;
	}

	DBResultSet results = view_as<DBResultSet>(hndl);
	if (!results.FetchRow())
	{
		CVBLog.MySQL("%s returned no results", PROCEDURE_INSERT_BAN);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "%s returned no results", PROCEDURE_INSERT_BAN); // add translations
		return;
	}

	if (results.IsFieldNull(0))
	{
		CVBLog.MySQL("Database error inserting ban for AccountID %d", targetAccountId);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Database error inserting ban for AccountID %d", targetAccountId); // add translations
		return;
	}

	int banId = 0;
	banId = results.FetchInt(0);

	int resultCode = results.FetchInt(1);
	char message[256];
	results.FetchString(2, message, sizeof(message));

	if (resultCode == 0)
	{
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Ban inserted successfully for AccountID %d: %s", targetAccountId, message); // add translations
		CVBLog.SQL("Ban inserted successfully: ID=%d, AccountID=%d, Message=%s", banId, targetAccountId, message);
		UpdateStringMapCache(targetAccountId, true, banType);
	}
	else if (resultCode == 1)
	{
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Ban already exists for AccountID %d: %s", targetAccountId, message); // add translations
		CVBLog.SQL("Existing more severe ban found: %s", message);
	}
	else if (resultCode == 2)
	{
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Ban inserted but not active for AccountID %d: %s", targetAccountId, message); // add translations
		CVBLog.MySQL("Error inserting ban: Code=%d, Message=%s", resultCode, message);
	}
}


/**
 * Removes a ban for a specified target account using a stored procedure.
 *
 * @param targetAccountId   The account ID of the user whose ban is to be removed.
 * @param adminAccountId    The account ID of the admin performing the removal.
 *
 * If the MySQL database connection is not available, logs an error and returns.
 * Otherwise, constructs and executes a stored procedure call to remove the ban,
 * passing the target and admin account IDs. The result is handled asynchronously
 * in the CVB_RemoveBan_Callback function.
 */
void CVB_RemoveBan(int targetAccountId, int adminAccountId)
{
	if (g_hMySQLDB == null)
	{
		LogError("MySQL not available for RemoveBan");
		int adminId = FindClientByAccountID(adminAccountId);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "MySQL not available for RemoveBan"); // add translations
		return;
	}

	char sQuery[MAX_QUERY_LENGTH];
	FormatEx(sQuery, sizeof(sQuery), "CALL %s(%d, %d)", PROCEDURE_REMOVE_BAN, targetAccountId, adminAccountId);
	CVBLog.MySQL("CVB_RemoveBan: %s", sQuery);

	DataPack dpRemoveBan = new DataPack();
	dpRemoveBan.WriteCell(targetAccountId);
	dpRemoveBan.WriteCell(adminAccountId);
	SQL_TQuery(g_hMySQLDB, CVB_RemoveBan_Callback, sQuery, dpRemoveBan);
}

public void CVB_RemoveBan_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	DataPack dpRemoveBan = view_as<DataPack>(data);
	dpRemoveBan.Reset();
	int targetAccountId = dpRemoveBan.ReadCell();
	int adminAccountId = dpRemoveBan.ReadCell();
	delete dpRemoveBan;

	int adminId = FindClientByAccountID(adminAccountId);

	if (hndl == null)
	{
		CVBLog.MySQL("Error in %s: %s", PROCEDURE_REMOVE_BAN, error);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Error in %s: %s", PROCEDURE_REMOVE_BAN, error); // add translations
		return;
	}

	DBResultSet results = view_as<DBResultSet>(hndl);
	if (!results.FetchRow())
	{
		CVBLog.MySQL("Error in %s: No results", PROCEDURE_REMOVE_BAN);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Error in %s: No results", PROCEDURE_REMOVE_BAN); // add translations
		return;
	}

	int resultCode = results.FetchInt(0);
	char message[256];
	results.FetchString(1, message, sizeof(message));
	bool isNull = results.IsFieldNull(2);
	int removedBanId = 0;
	if (!isNull)
	{
		removedBanId = results.FetchInt(2);
	}

	if (resultCode == 0)
	{
		CVBLog.SQL("Ban removed successfully: ID=%d, AccountID=%d, Message=%s", removedBanId, targetAccountId, message);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Ban removed successfully for AccountID %d", targetAccountId); // add translations
		UpdateStringMapCache(targetAccountId, false, 0);
		if (g_hSQLiteDB != null)
		{
			char sQuery[MAX_QUERY_LENGTH];
			Format(sQuery, sizeof(sQuery), "UPDATE %s SET is_active = 0 WHERE account_id = %d", TABLE_BANS, targetAccountId);
			SQL_TQuery(g_hSQLiteDB, Generic_QueryCallback, sQuery);
		}
	}
	else if (resultCode == 1)
	{
		CVBLog.SQL("No active ban found for AccountID %d: %s", targetAccountId, message);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "No active ban found for AccountID %d: %s", targetAccountId, message); // add translations
	}
	else if (resultCode == 4 && isNull)
	{
		CVBLog.MySQL("Database error removing ban for AccountID %d: %s", targetAccountId, message);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Database error removing ban for AccountID %d: %s", targetAccountId, message); // add translations
	}
	else
	{
		CVBLog.MySQL("Error removing ban: Code=%d, Message=%s", resultCode, message);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Error removing ban: Code=%d, Message=%s", resultCode, message); // add translations
	}
}

/**
 * Cleans expired bans from the database by calling a stored procedure.
 *
 * @param adminAccountId   The account ID of the admin performing the cleanup.
 * @param batchSize        (Optional) The maximum number of expired bans to clean in one batch. Defaults to 100.
 *
 * This function constructs a SQL query to call the stored procedure for cleaning expired bans,
 * then asynchronously executes the query. The adminAccountId is stored in a DataPack for use in the callback.
 */
void CVB_CleanExpiredBans(int adminAccountId, int batchSize = 100)
{
	char sQuery[MAX_QUERY_LENGTH];
	FormatEx(sQuery, sizeof(sQuery), "CALL %s(%d)", PROCEDURE_CLEAN_EXPIRED, batchSize);

	DataPack dpCleanExpiredBans = new DataPack();
	dpCleanExpiredBans.WriteCell(adminAccountId);
	SQL_TQuery(g_hMySQLDB, CVB_CleanExpiredBans_Callback, sQuery, dpCleanExpiredBans);
}

public void CVB_CleanExpiredBans_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	DataPack dpCleanExpiredBans = view_as<DataPack>(data);
	dpCleanExpiredBans.Reset();
	int adminAccountId = dpCleanExpiredBans.ReadCell();
	delete dpCleanExpiredBans;

	int adminId = FindClientByAccountID(adminAccountId);

	if (hndl == null)
	{
		CVBLog.MySQL("Error in %s: %s", PROCEDURE_CLEAN_EXPIRED, error);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Error in %s: %s", PROCEDURE_CLEAN_EXPIRED, error); // add translations
		return;
	}

	DBResultSet results = view_as<DBResultSet>(hndl);
	if (!results.FetchRow())
	{
		CVBLog.MySQL("Error in %s: No results", PROCEDURE_CLEAN_EXPIRED);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Error in %s: No results", PROCEDURE_CLEAN_EXPIRED); // add translations
		return;
	}

	int cleanedCount = results.FetchInt(0);
	int resultCode = results.FetchInt(1);
	char message[256];
	results.FetchString(2, message, sizeof(message));

	if (resultCode == 0)
	{
		CVBLog.SQL("Expired ban cleanup completed: %d bans cleaned - %s", cleanedCount, message);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Expired ban cleanup completed: %d bans cleaned - %s", cleanedCount, message); // add translations
	}
	else
	{
		CVBLog.MySQL("Error in expired ban cleanup: Code=%d, Message=%s", resultCode, message);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Error in expired ban cleanup: Code=%d, Message=%s", resultCode, message); // add translations
	}
}

public void Generic_QueryCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		CVBLog.SQL("Database query error: %s", error);
	}
}

/**
 * Closes any open database connections for both MySQL and SQLite.
 * 
 * This function checks if the global database handles (g_hMySQLDB and g_hSQLiteDB)
 * are not null, deletes them to free resources, and sets them to null.
 * After closing the connections, it logs the action for debugging purposes.
 */
void CloseDatabase()
{
	if (g_hMySQLDB != null)
	{
		delete g_hMySQLDB;
		g_hMySQLDB = null;
	}
	
	if (g_hSQLiteDB != null)
	{
		delete g_hSQLiteDB;
		g_hSQLiteDB = null;
	}
	
	CVBLog.SQL("Database connections closed");
}

/**
 * Installs all required stored procedures for the CallVote Manager plugin.
 *
 * This function checks if the MySQL database handle is available. If not, it logs an error and exits.
 * If the database is available, it logs the start of the installation process and sequentially creates
 * all necessary stored procedures used by the plugin for ban management and statistics.
 */
void InstallStoredProcedures()
{
	if (g_hMySQLDB == null)
	{
		LogError("MySQL not available to install stored procedures");
		MarkOperationComplete("mysql_procedures", false);
		return;
	}
	
	InstallationPR defaultConfig;
	InitInstallationPR(defaultConfig);
	
	// Guardar configuración en variable global para reporte
	g_InstallConfig = defaultConfig;
	
	CVBLog.SQL("Starting stored procedure installation (using InstallationPR system)...");
	InstallStoredProceduresWithConfig(defaultConfig);
}

/**
 * Checks if the specified account has a full ban in the database.
 *
 * This function asynchronously queries the database to determine if the given account ID
 * is currently fully banned. It prepares a SQL query to call the stored procedure `sp_CheckFullBan`
 * and retrieves relevant ban information. The result is handled in the `CheckFullBan_Callback` function.
 *
 * @param accountId  The account ID to check for a full ban.
 * @param client     (Optional) The client index associated with the account. Defaults to 0 if not specified.
 */
void CVB_CheckFullBan(int targetAccountId, int adminAccountId)
{
	if (g_hMySQLDB == null)
	{
		return;
	}
	
	char sQuery[MAX_QUERY_LENGTH];
	FormatEx(sQuery, sizeof(sQuery), 
		"CALL %s(%d)",
		PROCEDURE_CHECK_FULL_BAN, targetAccountId);
	CVBLog.MySQL("CVB_CheckFullBan: %s", sQuery);

	DataPack dpCheckFullBan = new DataPack();
	dpCheckFullBan.WriteCell(targetAccountId);
	dpCheckFullBan.WriteCell(adminAccountId);
	dpCheckFullBan.WriteCell(GetTime());
	SQL_TQuery(g_hMySQLDB, CheckFullBan_Callback, sQuery, dpCheckFullBan);
}

public void CheckFullBan_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	DataPack dpCheckFullBan = view_as<DataPack>(data);
	dpCheckFullBan.Reset();
	int targetAccountId = dpCheckFullBan.ReadCell();
	int adminAccountId = dpCheckFullBan.ReadCell();
	dpCheckFullBan.ReadCell();
	delete dpCheckFullBan;

	int adminId = FindClientByAccountID(adminAccountId);
	int targetId = FindClientByAccountID(targetAccountId);
	if (hndl == null)
	{
		CVBLog.MySQL("Error in %s: %s", PROCEDURE_CHECK_FULL_BAN, error);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Error in %s: %s", PROCEDURE_CHECK_FULL_BAN, error); // add translations
		return;
	}
	
	DBResultSet results = view_as<DBResultSet>(hndl);
	if (!results.FetchRow())
	{
		CVBLog.MySQL("Error in %s: No results for AccountID %d", PROCEDURE_CHECK_FULL_BAN, targetAccountId);
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Error in %s: No results for AccountID %d", PROCEDURE_CHECK_FULL_BAN, targetAccountId);
		return;
	}
	
	bool hasBan = results.FetchInt(0) > 0;
	
	if (hasBan)
	{
		PlayerBanInfo banInfo;
		banInfo.accountId = targetAccountId;
		banInfo.banType = results.FetchInt(1);
		banInfo.expiresTimestamp = results.FetchInt(2);
		banInfo.createdTimestamp = results.FetchInt(3);
		banInfo.durationMinutes = results.FetchInt(4);
		banInfo.isLoaded = true;
		banInfo.isChecking = false;
		
		if (targetId != NO_INDEX && IsValidClientIndex(targetId))
		{
			g_PlayerBans[targetId] = banInfo;
		}

		UpdateStringMapCache(targetAccountId, true, banInfo.banType);
		
		if (g_hSQLiteDB != null)
		{
			UpdateSQLiteCache(banInfo);
		}

		CVBLog.Debug("%s: Complete ban info loaded for AccountID %d: Type=%d, Expires=%d", 
			PROCEDURE_CHECK_FULL_BAN, targetAccountId, banInfo.banType, banInfo.expiresTimestamp);
		
		// Show formatted ban information to admin
		if (adminId != NO_INDEX)
		{
			char targetName[MAX_NAME_LENGTH] = "Unknown Player";
			char targetSteamId[MAX_AUTHID_LENGTH] = "Unknown";
			
			if (targetId != NO_INDEX && IsValidClientIndex(targetId))
			{
				GetClientName(targetId, targetName, sizeof(targetName));
				GetClientAuthId(targetId, AuthId_Steam2, targetSteamId, sizeof(targetSteamId));
			}
			else
			{
				// For offline players, try to construct SteamID2 from AccountID
				AccountIDToSteamID2(targetAccountId, targetSteamId, sizeof(targetSteamId));
			}
			
			char sBanTypes[128];
			GetBanTypeString(banInfo.banType, sBanTypes, sizeof(sBanTypes));
			
			char sExpiration[64];
			if (banInfo.expiresTimestamp == 0)
			{
				Format(sExpiration, sizeof(sExpiration), "%T", "BanStatusPermanent", adminId);
			}
			else
			{
				FormatTime(sExpiration, sizeof(sExpiration), "%Y-%m-%d %H:%M:%S", banInfo.expiresTimestamp);
			}
			
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusHeader", targetName);
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusSteamID2", targetSteamId);
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusAccountID", targetAccountId);
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusBanned");
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusRestrictedTypes", sBanTypes);
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusExpiration", sExpiration);
		}
	}
	else
	{
		UpdateStringMapCache(targetAccountId, false, 0);
		if (targetId != NO_INDEX && IsValidClientIndex(targetId))
		{
			g_PlayerBans[targetId].isLoaded = true;
			g_PlayerBans[targetId].isChecking = false;
			g_PlayerBans[targetId].banType = 0;
		}
		CVBLog.Debug("%s: No active ban for AccountID %d", PROCEDURE_CHECK_FULL_BAN, targetAccountId);
		
		// Show "not banned" message to admin
		if (adminId != NO_INDEX)
		{
			char targetName[MAX_NAME_LENGTH] = "Unknown Player";
			char targetSteamId[MAX_AUTHID_LENGTH] = "Unknown";
			
			if (targetId != NO_INDEX && IsValidClientIndex(targetId))
			{
				GetClientName(targetId, targetName, sizeof(targetName));
				GetClientAuthId(targetId, AuthId_Steam2, targetSteamId, sizeof(targetSteamId));
			}
			else
			{
				// For offline players, try to construct SteamID2 from AccountID
				AccountIDToSteamID2(targetAccountId, targetSteamId, sizeof(targetSteamId));
			}
			
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusHeader", targetName);
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusSteamID2", targetSteamId);
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusAccountID", targetAccountId);
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusUnbanned");
		}
	}
}

public void SyncTransaction_Success(Database db, any data, int numQueries, Handle[] results, any[] queryData)
{
	int syncCount = data;
	CVBLog.SQL("Initial synchronization completed: %d bans synchronized", syncCount);
}

public void SyncTransaction_Error(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	CVBLog.SQL("Error in synchronization transaction (query %d): %s", failIndex, error);
}

/**
 * Inicializa el seguimiento de instalación de base de datos
 *
 * @param client            Cliente que ejecutó el comando
 * @param installMySQL      Si debe instalar MySQL
 * @param installSQLite     Si debe instalar SQLite
 */
void InitInstallationTracking(int client, bool installMySQL, bool installSQLite)
{
	g_InstallStatus.mysqlTables = false;
	g_InstallStatus.mysqlProcedures = false;
	g_InstallStatus.sqliteTables = false;
	g_InstallStatus.sqliteIndexes = false;
	g_InstallStatus.clientUserId = (client == SERVER_INDEX) ? 0 : GetClientUserId(client);
	g_InstallStatus.totalOperations = 0;
	g_InstallStatus.completedOperations = 0; // Resetear contador
	
	if (g_InstallStatus.timeoutTimer != null)
	{
		delete g_InstallStatus.timeoutTimer;
		g_InstallStatus.timeoutTimer = null;
	}
	
	if (installMySQL && g_hMySQLDB != null)
	{
		g_InstallStatus.totalOperations += 2;
	}
	
	if (installSQLite && g_hSQLiteDB != null)
	{
		g_InstallStatus.totalOperations += 2;
	}
	
	CVBLog.Debug("Installation tracking initialized: %d operations planned", g_InstallStatus.totalOperations);

	if (g_InstallStatus.totalOperations > 0)
	{
		g_InstallStatus.timeoutTimer = CreateTimer(30.0, Timer_InstallationTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
		
		CVBLog.Debug("Starting installation operations...");
		
		if (installMySQL && g_hMySQLDB != null)
		{
			CVBLog.Debug("Starting MySQL installation...");
			CreateMySQLTables();
		}
		
		if (installSQLite && g_hSQLiteDB != null)
		{
			CVBLog.Debug("Starting SQLite installation...");
			CreateSQLiteTables();
		}
	}
}

/**
 * Marca una operación como completada y verifica si todas terminaron
 *
 * @param operation     Tipo de operación completada
 * @param success       Si la operación fue exitosa
 */
void MarkOperationComplete(const char[] operation, bool success)
{
	bool changed = false;
	
	if (StrEqual(operation, "mysql_tables"))
	{
		g_InstallStatus.mysqlTables = success;
		changed = true;
	}
	else if (StrEqual(operation, "mysql_procedures"))
	{
		g_InstallStatus.mysqlProcedures = success;
		changed = true;
	}
	else if (StrEqual(operation, "sqlite_tables"))
	{
		g_InstallStatus.sqliteTables = success;
		changed = true;
	}
	else if (StrEqual(operation, "sqlite_indexes"))
	{
		g_InstallStatus.sqliteIndexes = success;
		changed = true;
	}
	
	if (!changed)
	{
		CVBLog.Debug("Unknown operation marked complete: %s", operation);
		return;
	}
	
	// Incrementar contador de operaciones completadas
	g_InstallStatus.completedOperations++;
	
	CVBLog.Debug("Operation '%s' marked as %s (%d/%d completed)", 
		operation, success ? "SUCCESS" : "FAILED", 
		g_InstallStatus.completedOperations, g_InstallStatus.totalOperations);
	
	CheckInstallationComplete();
}

/**
 * Verifica si todas las operaciones han terminado y genera el reporte final
 */
void CheckInstallationComplete()
{
	if (g_InstallStatus.totalOperations == 0) return;
	
	CVBLog.Debug("Checking installation completion: %d/%d operations completed",
		g_InstallStatus.completedOperations, g_InstallStatus.totalOperations);
	
	if (g_InstallStatus.completedOperations >= g_InstallStatus.totalOperations)
	{
		CVBLog.Debug("All operations completed, generating final report...");
		GenerateInstallationReport(false);
	}
	else
	{
		CVBLog.Debug("Installation not yet complete, waiting for more operations...");
	}
}

/**
 * Genera el reporte final de instalación
 *
 * @param isTimeout     Si el reporte se genera por timeout
 */
void GenerateInstallationReport(bool isTimeout)
{
	int client = (g_InstallStatus.clientUserId == 0) ? SERVER_INDEX : GetClientOfUserId(g_InstallStatus.clientUserId);
	
	if (client < SERVER_INDEX && g_InstallStatus.clientUserId != 0)
	{
		CVBLog.Debug("Client disconnected, skipping installation report");
		return;
	}

	CVBLog.Debug("Generating installation report for client %N (isTimeout: %s)", client, isTimeout ? "true" : "false");

	if (g_InstallStatus.timeoutTimer != null)
	{
		delete g_InstallStatus.timeoutTimer;
		g_InstallStatus.timeoutTimer = null;
	}
	
	bool isValidTarget = (client == SERVER_INDEX) || (client > 0 && IsValidClient(client));
	
	CVBLog.Debug("Report target validation - client: %d, SERVER_INDEX: %d, isValidTarget: %s", 
		client, SERVER_INDEX, isValidTarget ? "true" : "false");
	
	if (isValidTarget)
	{
		CReplyToCommand(client, "%t", "InstallResultHeader");
		
		if (isTimeout)
		{
			CReplyToCommand(client, "%t %t", "Tag", "InstallationTimeout");
		}
		
		if (g_InstallStatus.mysqlTables || g_InstallStatus.mysqlProcedures)
		{
			char status[64];
			if (g_InstallStatus.mysqlTables && g_InstallStatus.mysqlProcedures)
			{
				Format(status, sizeof(status), "%t", "InstallSuccess");
			}
			else if (g_InstallStatus.mysqlTables && !g_InstallStatus.mysqlProcedures)
			{
				Format(status, sizeof(status), "%t", "TablesCreatedProceduresFailed");
			}
			else if (!g_InstallStatus.mysqlTables && g_InstallStatus.mysqlProcedures)
			{
				Format(status, sizeof(status), "%t", "TablesFailedProceduresSuccess");
			}
			else
			{
				Format(status, sizeof(status), "%t", "InstallationFailed");
			}
			
			CReplyToCommand(client, "%t %t", "Tag", "MySQLStatus", status);
			
			if (g_InstallStatus.mysqlTables)
			{
				CReplyToCommand(client, "%t %t", "Tag", "ComponentSuccess", "Tablas principales");
			}
			else
			{
				CReplyToCommand(client, "%t %t", "Tag", "ComponentFailed", "Tablas principales");
			}
			
			if (g_InstallStatus.mysqlProcedures)
			{
				int procedureCount = 0;
				if (g_InstallConfig.installCheckActiveBan)
					procedureCount++;
				if (g_InstallConfig.installCheckFullBan)
					procedureCount++;
				if (g_InstallConfig.installInsertBan)
					procedureCount++;
				if (g_InstallConfig.installRemoveBan)
					procedureCount++;
				if (g_InstallConfig.installCleanExpired)
					procedureCount++;
				if (g_InstallConfig.installGetStatistics)
					procedureCount++;
				
				CReplyToCommand(client, "%t %t (%d/6)", "Tag", "ComponentSuccess", "Procedimientos almacenados", procedureCount);
			}
			else
			{
				CReplyToCommand(client, "%t %t", "Tag", "ComponentFailed", "Procedimientos almacenados");
			}
		}
		
		if (g_InstallStatus.sqliteTables || g_InstallStatus.sqliteIndexes)
		{
			char status[64];
			if (g_InstallStatus.sqliteTables && g_InstallStatus.sqliteIndexes)
			{
				Format(status, sizeof(status), "%t", "InstallSuccess");
			}
			else if (g_InstallStatus.sqliteTables && !g_InstallStatus.sqliteIndexes)
			{
				Format(status, sizeof(status), "%t", "TablesCreatedIndexesFailed");
			}
			else if (!g_InstallStatus.sqliteTables && g_InstallStatus.sqliteIndexes)
			{
				Format(status, sizeof(status), "%t", "TablesFailedIndexesSuccess");
			}
			else
			{
				Format(status, sizeof(status), "%t", "InstallationFailed");
			}
			
			CReplyToCommand(client, "%t %t", "Tag", "SQLiteStatus", status);

			if (g_InstallStatus.sqliteTables)
			{
				CReplyToCommand(client, "%t %t", "Tag", "ComponentSuccess", "Tabla de cache");
			}
			else
			{
				CReplyToCommand(client, "%t %t", "Tag", "ComponentFailed", "Tabla de cache");
			}
			
			if (g_InstallStatus.sqliteIndexes)
			{
				CReplyToCommand(client, "%t %t", "Tag", "ComponentSuccess", "Índices de optimización (1/1)");
			}
			else
			{
				CReplyToCommand(client, "%t %t", "Tag", "ComponentFailed", "Índices de optimización");
			}
		}
		
		if (isTimeout)
		{
			if (!g_InstallStatus.mysqlTables)
				CReplyToCommand(client, "%t %t", "Tag", "MissingOperation", "MySQL Tables");
			if (!g_InstallStatus.mysqlProcedures)
				CReplyToCommand(client, "%t %t", "Tag", "MissingOperation", "MySQL Procedures");
			if (!g_InstallStatus.sqliteTables)
				CReplyToCommand(client, "%t %t", "Tag", "MissingOperation", "SQLite Tables");
			if (!g_InstallStatus.sqliteIndexes)
				CReplyToCommand(client, "%t %t", "Tag", "MissingOperation", "SQLite Indexes");
		}
		
		if (g_InstallStatus.mysqlProcedures)
		{
			CReplyToCommand(client, "%t", "ProcedureConfigurationHeader");
			
			if (g_InstallConfig.installCheckActiveBan)
				CReplyToCommand(client, "%t %t", "Tag", "ProcedureEnabled", "CheckActiveBan");
			if (g_InstallConfig.installCheckFullBan)
				CReplyToCommand(client, "%t %t", "Tag", "ProcedureEnabled", "CheckFullBan");
			if (g_InstallConfig.installInsertBan)
				CReplyToCommand(client, "%t %t", "Tag", "ProcedureEnabled", "InsertBan");
			if (g_InstallConfig.installRemoveBan)
				CReplyToCommand(client, "%t %t", "Tag", "ProcedureEnabled", "RemoveBan");
			if (g_InstallConfig.installCleanExpired)
				CReplyToCommand(client, "%t %t", "Tag", "ProcedureEnabled", "CleanExpired");
			if (g_InstallConfig.installGetStatistics)
				CReplyToCommand(client, "%t %t", "Tag", "ProcedureEnabled", "GetStatistics");
			
			bool hasDisabled = false;
			if (!g_InstallConfig.installCheckActiveBan ||
				!g_InstallConfig.installCheckFullBan ||
				!g_InstallConfig.installInsertBan ||
				!g_InstallConfig.installRemoveBan ||
				!g_InstallConfig.installCleanExpired ||
				!g_InstallConfig.installGetStatistics)
			{
				hasDisabled = true;
				CReplyToCommand(client, "%t", "ProcedureDisabledHeader");
				
				if (!g_InstallConfig.installCheckActiveBan)
					CReplyToCommand(client, "%t %t", "Tag", "ProcedureDisabled", "CheckActiveBan");
				if (!g_InstallConfig.installCheckFullBan)
					CReplyToCommand(client, "%t %t", "Tag", "ProcedureDisabled", "CheckFullBan");
				if (!g_InstallConfig.installInsertBan)
					CReplyToCommand(client, "%t %t", "Tag", "ProcedureDisabled", "InsertBan");
				if (!g_InstallConfig.installRemoveBan)
					CReplyToCommand(client, "%t %t", "Tag", "ProcedureDisabled", "RemoveBan");
				if (!g_InstallConfig.installCleanExpired)
					CReplyToCommand(client, "%t %t", "Tag", "ProcedureDisabled", "CleanExpired");
				if (!g_InstallConfig.installGetStatistics)
					CReplyToCommand(client, "%t %t", "Tag", "ProcedureDisabled", "GetStatistics");
			}
			
			if (!hasDisabled)
			{
				CReplyToCommand(client, "%t %t", "Tag", "AllProceduresEnabled");
			}
		}
	}
	else
	{
		CVBLog.Debug("Report target not valid, skipping user messages but logging completion");
	}
	
	char sAdminName[MAX_NAME_LENGTH];
	if (client == SERVER_INDEX)
	{
		strcopy(sAdminName, sizeof(sAdminName), "CONSOLE");
	}
	else if (client > 0 && IsValidClient(client))
	{
		GetClientName(client, sAdminName, sizeof(sAdminName));
	}
	else
	{
		Format(sAdminName, sizeof(sAdminName), "Unknown Client (%d)", client);
	}
	
	CVBLog.Debug("Installation completed by %s - MySQL: T:%s P:%s | SQLite: T:%s I:%s %s", 
		sAdminName,
		g_InstallStatus.mysqlTables ? "OK" : "FAIL",
		g_InstallStatus.mysqlProcedures ? "OK" : "FAIL", 
		g_InstallStatus.sqliteTables ? "OK" : "FAIL",
		g_InstallStatus.sqliteIndexes ? "OK" : "FAIL",
		isTimeout ? "(TIMEOUT)" : "");
	
	// Reset installation status
	g_InstallStatus.totalOperations = 0;
	g_InstallStatus.completedOperations = 0;
	
	CVBLog.Debug("Installation report generation completed successfully");
}

/**
 * Timer de timeout para la instalación
 */
public Action Timer_InstallationTimeout(Handle timer)
{
	g_InstallStatus.timeoutTimer = null;
	CVBLog.Debug("Installation timeout reached - generating report");
	GenerateInstallationReport(true);
	return Plugin_Stop;
}

public void MySQLTables_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	bool success = (hndl != null);
	
	if (!success)
	{
		CVBLog.SQL("Error creating MySQL tables: %s", error);
	}
	else
	{
		CVBLog.SQL("MySQL tables created successfully");
		
		if (g_InstallStatus.totalOperations > 0)
		{
			InstallStoredProcedures();
		}
	}
	
	MarkOperationComplete("mysql_tables", success);
}

public void SQLiteTables_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	bool success = (hndl != null);
	
	CVBLog.Debug("SQLiteTables_Callback called - success: %s", success ? "true" : "false");
	
	if (!success)
	{
		CVBLog.SQL("Error creating SQLite tables: %s", error);
	}
	else
	{
		CVBLog.SQL("SQLite tables created successfully");

		if (g_InstallStatus.totalOperations > 0)
		{
			CVBLog.Debug("Starting SQLite indexes creation after table completion");
			CreateSQLiteIndexes();
		}
	}
	
	MarkOperationComplete("sqlite_tables", success);
}

public void SQLiteIndexes_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	bool success = (hndl != null);
	
	CVBLog.Debug("SQLiteIndexes_Callback called - success: %s", success ? "true" : "false");
	
	if (!success)
	{
		CVBLog.SQL("Error creating SQLite indexes: %s", error);
	}
	else
	{
		CVBLog.SQL("SQLite indexes created successfully");
	}
	
	MarkOperationComplete("sqlite_indexes", success);
}

void InitInstallationPR(InstallationPR iPR)
{
	iPR.installCheckActiveBan = true;
	iPR.installCheckFullBan = true;
	iPR.installInsertBan = true;
	iPR.installRemoveBan = true;
	iPR.installCleanExpired = true;
	iPR.installGetStatistics = true;
	iPR.current = 0;
}

/**
 * Obtiene el procedimiento actual basado en el índice current
 * @param iPR      Estructura con la configuración
 * @return         Procedimiento a instalar o -1 si no hay más
 */
Procedure GetCurrentProcedure(InstallationPR iPR)
{
	switch (iPR.current)
	{
		case 0: return iPR.installCheckActiveBan ? PROC_CHECK_ACTIVE_BAN : view_as<Procedure>(-1);
		case 1: return iPR.installCheckFullBan ? PROC_CHECK_FULL_BAN : view_as<Procedure>(-1);
		case 2: return iPR.installInsertBan ? PROC_INSERT_BAN : view_as<Procedure>(-1);
		case 3: return iPR.installRemoveBan ? PROC_REMOVE_BAN : view_as<Procedure>(-1);
		case 4: return iPR.installCleanExpired ? PROC_CLEAN_EXPIRED : view_as<Procedure>(-1);
		case 5: return iPR.installGetStatistics ? PROC_GET_STATISTICS : view_as<Procedure>(-1);
		default: return view_as<Procedure>(-1);
	}
}

/**
 * Avanza al siguiente procedimiento habilitado
 * @param iPR      Estructura a modificar
 * @return         true si hay siguiente procedimiento, false si terminó
 */
bool AdvanceToNextProcedure(InstallationPR iPR)
{
	iPR.current++;
	
	while (iPR.current < view_as<int>(PROC_SIZE))
	{
		if (GetCurrentProcedure(iPR) != view_as<Procedure>(-1))
		{
			return true;
		}
		iPR.current++;
	}
	
	return false;
}


/**
 * Installs stored procedures in the MySQL database using the provided configuration.
 *
 * This function checks if the MySQL database handle is available. If not, it logs an error
 * and marks the operation as incomplete. If available, it attempts to retrieve the first
 * procedure from the configuration and creates it if found. If no procedures are configured,
 * it logs this information and marks the operation as complete.
 *
 * @param config    The installation configuration containing procedure definitions.
 */
void InstallStoredProceduresWithConfig(InstallationPR config)
{
	if (g_hMySQLDB == null)
	{
		LogError("MySQL not available to install stored procedures");
		MarkOperationComplete("mysql_procedures", false);
		return;
	}
	
	CVBLog.SQL("Starting configurable stored procedure installation...");

	Procedure firstProc = GetCurrentProcedure(config);
	if (firstProc != view_as<Procedure>(-1))
	{
		CreateProcedureWithConfig(firstProc, config);
	}
	else
	{
		CVBLog.SQL("No procedures configured for installation");
		MarkOperationComplete("mysql_procedures", true);
	}
}

/**
 * Versión de CreateProcedure que usa InstallationPR para control granular
 * @param pr       Procedimiento a crear
 * @param iPR      Estructura con configuración de instalación
 */
void CreateProcedureWithConfig(Procedure pr, InstallationPR iPR)
{
	char szCreateQuery[8192];
	int iLen = 0;

	switch (pr)
	{
		case PROC_CHECK_ACTIVE_BAN:
		{
			iLen = 0;
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "CREATE PROCEDURE %s(IN p_account_id INT) ", PROCEDURE_CHECK_ACTIVE_BAN);
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "BEGIN ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE ban_type INT DEFAULT 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SELECT 0 as ban_type; END; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT ban_type INTO ban_type FROM callvote_bans ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "WHERE account_id = p_account_id AND is_active = 1 ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "AND (expires_timestamp = 0 OR expires_timestamp > UNIX_TIMESTAMP()) ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "ORDER BY created_timestamp DESC LIMIT 1; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT ban_type; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "END");
		}
		case PROC_CHECK_FULL_BAN:
		{
			iLen = 0;
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "CREATE PROCEDURE %s(IN p_account_id INT) ", PROCEDURE_CHECK_FULL_BAN);
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "BEGIN ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SELECT 0 as has_ban, 0 as ban_type, 0 as expires_timestamp, 0 as created_timestamp, 0 as duration_minutes, 0 as admin_account_id, '' as reason, 0 as ban_id; END; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT CASE WHEN b.id IS NOT NULL THEN 1 ELSE 0 END as has_ban, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL(b.ban_type, 0) as ban_type, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL(b.expires_timestamp, 0) as expires_timestamp, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL(b.created_timestamp, 0) as created_timestamp, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL(b.duration_minutes, 0) as duration_minutes, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL(b.admin_account_id, 0) as admin_account_id, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL(b.reason, '') as reason, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL(b.id, 0) as ban_id ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "FROM callvote_bans b ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "WHERE b.account_id = p_account_id AND b.is_active = 1 AND (b.expires_timestamp = 0 OR b.expires_timestamp > UNIX_TIMESTAMP()) ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "ORDER BY b.created_timestamp DESC LIMIT 1; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "END");
		}
		case PROC_INSERT_BAN:
		{
			iLen = 0;
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "CREATE PROCEDURE %s(", PROCEDURE_INSERT_BAN);
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IN p_account_id INT, IN p_ban_type INT, IN p_duration_minutes INT, IN p_admin_account_id INT, IN p_reason TEXT) ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "BEGIN ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE ban_id INT DEFAULT 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE result_code INT DEFAULT 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE message VARCHAR(255) DEFAULT ''; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE expires_ts INT DEFAULT 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; GET DIAGNOSTICS CONDITION 1 message = MESSAGE_TEXT; SELECT 0 as ban_id, 4 as result_code, message as message; END; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "START TRANSACTION; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT id INTO ban_id FROM callvote_bans WHERE account_id = p_account_id AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > UNIX_TIMESTAMP()) LIMIT 1; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IF ban_id > 0 THEN ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET result_code = 1; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET message = 'Player already has an active ban'; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT ban_id, result_code, message; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "ELSE ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IF p_duration_minutes > 0 THEN SET expires_ts = UNIX_TIMESTAMP() + (p_duration_minutes * 60); ELSE SET expires_ts = 0; END IF; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "INSERT INTO callvote_bans (account_id, ban_type, created_timestamp, duration_minutes, expires_timestamp, admin_account_id, reason, is_active) VALUES (p_account_id, p_ban_type, UNIX_TIMESTAMP(), p_duration_minutes, expires_ts, p_admin_account_id, p_reason, 1); ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET ban_id = LAST_INSERT_ID(); ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET result_code = 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET message = 'Ban inserted successfully'; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT ban_id, result_code, message; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "END IF; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "COMMIT; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "END");
		}
		case PROC_REMOVE_BAN:
		{
			iLen = 0;
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "CREATE PROCEDURE %s(", PROCEDURE_REMOVE_BAN);
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IN p_account_id INT, IN p_admin_account_id INT) ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "BEGIN ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE result_code INT DEFAULT 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE message VARCHAR(255) DEFAULT ''; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE removed_ban_id INT DEFAULT NULL; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_current_time INT DEFAULT UNIX_TIMESTAMP(); ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; GET DIAGNOSTICS CONDITION 1 message = MESSAGE_TEXT; SELECT 4 as result_code, message as message, NULL as removed_ban_id; END; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "START TRANSACTION; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT id INTO removed_ban_id FROM callvote_bans WHERE account_id = p_account_id AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > v_current_time) ORDER BY created_timestamp DESC LIMIT 1; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IF removed_ban_id IS NULL THEN ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET result_code = 1; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET message = 'No active ban found for this player'; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT result_code, message, removed_ban_id; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "ELSE ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "UPDATE callvote_bans SET is_active = 0 WHERE id = removed_ban_id; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET result_code = 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET message = 'Ban removed successfully'; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT result_code, message, removed_ban_id; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "END IF; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "COMMIT; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "END");
		}
		case PROC_CLEAN_EXPIRED:
		{
			iLen = 0;
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "CREATE PROCEDURE %s(", PROCEDURE_CLEAN_EXPIRED);
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IN p_batch_size INT) ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "BEGIN ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_current_time INT DEFAULT UNIX_TIMESTAMP(); ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_cleaned_count INT DEFAULT 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_result_code INT DEFAULT 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_message VARCHAR(255) DEFAULT ''; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SELECT 4 as result_code, 'Database error during cleanup' as message, NULL as cleaned_count; END; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "START TRANSACTION; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "UPDATE callvote_bans SET is_active = 0 WHERE is_active = 1 AND expires_timestamp > 0 AND expires_timestamp < v_current_time LIMIT p_batch_size; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_cleaned_count = ROW_COUNT(); ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_result_code = 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_message = CONCAT('Cleaned ', v_cleaned_count, ' expired bans'); ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "COMMIT; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT v_result_code as result_code, v_message as message, v_cleaned_count as cleaned_count; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "END");
		}
		case PROC_GET_STATISTICS:
		{
			iLen = 0;
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "CREATE PROCEDURE %s(IN p_days_back INT) ", PROCEDURE_GET_STATISTICS);
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "BEGIN ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_current_time INT DEFAULT UNIX_TIMESTAMP(); ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_cutoff_time INT DEFAULT v_current_time - (p_days_back * 86400); ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT COUNT(CASE WHEN is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > v_current_time) THEN 1 END) as active_bans, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "COUNT(CASE WHEN is_active = 0 OR (expires_timestamp > 0 AND expires_timestamp <= v_current_time) THEN 1 END) as expired_bans, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "COUNT(CASE WHEN created_timestamp >= v_cutoff_time THEN 1 END) as recent_bans, ");
		 	iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "COUNT(DISTINCT account_id) as unique_players, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "COUNT(DISTINCT admin_account_id) as unique_admins FROM callvote_bans; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT CASE WHEN ban_type = 1 THEN 'Difficulty' WHEN ban_type = 2 THEN 'Restart' WHEN ban_type = 4 THEN 'Kick' WHEN ban_type = 8 THEN 'Mission' WHEN ban_type = 16 THEN 'Lobby' WHEN ban_type = 32 THEN 'Chapter' WHEN ban_type = 64 THEN 'AllTalk' WHEN ban_type = 127 THEN 'All Types' ELSE CONCAT('Custom (', ban_type, ')') END as ban_type_name, COUNT(*) as count, AVG(duration_minutes) as avg_duration FROM callvote_bans WHERE created_timestamp >= v_cutoff_time GROUP BY ban_type ORDER BY count DESC; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT admin_account_id, COUNT(*) as total_bans, AVG(duration_minutes) as avg_duration, COUNT(CASE WHEN duration_minutes = 0 THEN 1 END) as permanent_bans FROM callvote_bans WHERE admin_account_id IS NOT NULL AND created_timestamp >= v_cutoff_time GROUP BY admin_account_id ORDER BY total_bans DESC LIMIT 10; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "END");
		}
		default:
		{
			LogError("[CreateProcedureWithConfig] Unknown procedure enum: %d", pr);
			return;
		}
	}

	CVBLog.SQL("Creating procedure %d (current index: %d)", pr, iPR.current);
	
	DataPack dp = new DataPack();
	dp.WriteCell(view_as<int>(iPR.installCheckActiveBan));
	dp.WriteCell(view_as<int>(iPR.installCheckFullBan));
	dp.WriteCell(view_as<int>(iPR.installInsertBan));
	dp.WriteCell(view_as<int>(iPR.installRemoveBan));
	dp.WriteCell(view_as<int>(iPR.installCleanExpired));
	dp.WriteCell(view_as<int>(iPR.installGetStatistics));
	dp.WriteCell(iPR.current);
	
	SQL_TQuery(g_hMySQLDB, CreateProcedureWithConfig_Callback, szCreateQuery, dp);
}

void CreateProcedureWithConfig_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	InstallationPR iPR;
	iPR.installCheckActiveBan = view_as<bool>(data.ReadCell());
	iPR.installCheckFullBan = view_as<bool>(data.ReadCell());
	iPR.installInsertBan = view_as<bool>(data.ReadCell());
	iPR.installRemoveBan = view_as<bool>(data.ReadCell());
	iPR.installCleanExpired = view_as<bool>(data.ReadCell());
	iPR.installGetStatistics = view_as<bool>(data.ReadCell());
	iPR.current = data.ReadCell();
	delete data;
	
	if (error[0])
	{
		bool isExpectedWarning = false;
		if (StrContains(error, "already exists", false) != -1)
		{
			isExpectedWarning = true;
		}
		
		if (isExpectedWarning)
		{
			CVBLog.SQL("Procedure at index %d skipped (expected warning): %s", iPR.current, error);
		}
		else
		{
			CVBLog.Debug("Actual error at index %d: '%s'", iPR.current, error);
			LogError("[CreateProcedureWithConfig_Callback] Failed to create procedure at index %d: %s", iPR.current, error);
			MarkOperationComplete("mysql_procedures", false);
			return;
		}
	}
	else
	{
		CVBLog.SQL("Successfully created procedure at index: %d", iPR.current);
	}
	
	if (AdvanceToNextProcedure(iPR))
	{
		Procedure nextProc = GetCurrentProcedure(iPR);
		if (nextProc != view_as<Procedure>(-1))
		{
			CreateProcedureWithConfig(nextProc, iPR);
		}
	}
	else
	{
		CVBLog.SQL("All configured procedures installed successfully");
		MarkOperationComplete("mysql_procedures", true);
	}
}
