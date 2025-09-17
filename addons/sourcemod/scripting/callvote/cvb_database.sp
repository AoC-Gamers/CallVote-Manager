#if defined _cvb_database_included
	#endinput
#endif
#define _cvb_database_included

#define MAX_TABLE_NAME 64
#define TABLE_BANS "callvote_bans"
#define TABLE_CACHE_BANS "callvote_bans_cache"

/**
 * PlayerBanInfo methodmap - Modern interface for ban information management
 * Provides encapsulation, validation, and convenience methods for ban operations
 */
methodmap PlayerBanInfo < StringMap {
	
	/**
	 * Constructor - Creates a new PlayerBanInfo instance
	 * 
	 * @param accountId		The player's AccountID (optional, default: 0)
	 * @return				A new PlayerBanInfo instance
	 */
	public PlayerBanInfo(int accountId = 0) {
		StringMap data = new StringMap();
		
		data.SetValue("accountId", accountId);
		data.SetValue("banType", 0);
		data.SetValue("createdTimestamp", 0);
		data.SetValue("durationMinutes", 0);
		data.SetValue("expiresTimestamp", 0);
		data.SetValue("adminAccountId", 0);
		data.SetString("reason", "");
		data.SetValue("dbSource", view_as<int>(SourceDB_Unknown));
		data.SetValue("rsCMD", view_as<int>(SM_REPLY_TO_CONSOLE));
		
		return view_as<PlayerBanInfo>(data);
	}
	
	/**
	 * Property for accessing the AccountId of the object.
	 *
	 * Getter:
	 *   Retrieves the value of "accountId" and returns it as an integer.
	 *
	 * Setter:
	 *   Sets the value of "accountId" to the specified integer.
	 *
	 * Usage:
	 *   - Use the getter to obtain the current AccountId.
	 *   - Use the setter to update the AccountId.
	 */
	property int AccountId {
		public get() {
			int value;
			this.GetValue("accountId", value);
			return value;
		}
		public set(int value) {
			this.SetValue("accountId", value);
		}
	}
	
	/**
	 * Property representing the type of ban.
	 *
	 * Getter:
	 *   Retrieves the current ban type value from the underlying storage using the key "banType".
	 *
	 * Setter:
	 *   Sets the ban type value in the underlying storage using the key "banType".
	 *   If the provided value is less than 0, it defaults to 0.
	 *
	 * @property int BanType
	 */
	property int BanType {
		public get() {
			int value;
			this.GetValue("banType", value);
			return value;
		}
		public set(int value) {
			this.SetValue("banType", value >= 0 ? value : 0);
		}
	}
	
	/**
	 * Property for accessing and modifying the "createdTimestamp" value.
	 *
	 * Getter:
	 *   Retrieves the "createdTimestamp" value from the underlying storage.
	 *   @return int - The stored created timestamp value.
	 *
	 * Setter:
	 *   Sets the "createdTimestamp" value in the underlying storage.
	 *   Ensures the value is non-negative; if a negative value is provided, it sets it to 0.
	 *   @param value int - The new created timestamp value to set.
	 */
	property int CreatedTimestamp {
		public get() {
			int value;
			this.GetValue("createdTimestamp", value);
			return value;
		}
		public set(int value) {
			this.SetValue("createdTimestamp", value >= 0 ? value : 0);
		}
	}
	
	/**
	 * Property: DurationMinutes
	 * 
	 * Gets or sets the duration (in minutes) for the current object.
	 * 
	 * Getter:
	 *   - Retrieves the value of "durationMinutes".
	 * 
	 * Setter:
	 *   - Sets the "durationMinutes" value, ensuring it is not negative.
	 *   - Automatically updates the "expiresTimestamp" property:
	 *       - If duration is 0, sets "expiresTimestamp" to 0 (permanent).
	 *       - Otherwise, sets "expiresTimestamp" to the current time plus the duration (in seconds).
	 *
	 * Usage:
	 *   - Use this property to control how long an object remains valid.
	 */
	property int DurationMinutes {
		public get() {
			int value;
			this.GetValue("durationMinutes", value);
			return value;
		}
		public set(int value) {
			int duration = value >= 0 ? value : 0;
			this.SetValue("durationMinutes", duration);
			
			// Auto-calculate expiration when setting duration
			if (duration == 0) {
				this.SetValue("expiresTimestamp", 0); // Permanent
			} else {
				this.SetValue("expiresTimestamp", GetTime() + (duration * 60));
			}
		}
	}
	
	/**
	 * Property for managing the expiration timestamp.
	 *
	 * Getter:
	 *   Retrieves the "expiresTimestamp" value associated with this object.
	 *   @return int - The current expiration timestamp value.
	 *
	 * Setter:
	 *   Sets the "expiresTimestamp" value for this object.
	 *   If the provided value is negative, it will be set to 0 instead.
	 *   @param value int - The new expiration timestamp value.
	 */
	property int ExpiresTimestamp {
		public get() {
			int value;
			this.GetValue("expiresTimestamp", value);
			return value;
		}
		public set(int value) {
			this.SetValue("expiresTimestamp", value >= 0 ? value : 0);
		}
	}
	
	property int AdminAccountId {
		public get() {
			int value;
			this.GetValue("adminAccountId", value);
			return value;
		}
		public set(int value) {
			this.SetValue("adminAccountId", value);
		}
	}
	
	property SourceDB DbSource {
		public get() {
			int value;
			this.GetValue("dbSource", value);
			return view_as<SourceDB>(value);
		}
		public set(SourceDB value) {
			this.SetValue("dbSource", view_as<int>(value));
		}
	}
	
	property ReplySource CommandReplySource {
		public get() {
			int value;
			this.GetValue("rsCMD", value);
			return view_as<ReplySource>(value);
		}
		public set(ReplySource value) {
			this.SetValue("rsCMD", view_as<int>(value));
		}
	}
	
	// Reason management
	public void GetReason(char[] buffer, int maxlen) {
		this.GetString("reason", buffer, maxlen);
	}
	
	public void SetReason(const char[] reason) {
		this.SetString("reason", reason);
	}
	
	// State checking methods
	public bool IsValid() {
		return this.AccountId > 0;
	}
	
	public bool IsBanned() {
		return this.BanType > 0 && !this.IsExpired();
	}
	
	public bool IsExpired() {
		if (this.IsPermanent()) return false;
		return GetTime() >= this.ExpiresTimestamp;
	}
	
	public bool IsPermanent() {
		return this.ExpiresTimestamp == 0 && this.BanType > 0;
	}
	
	// Time utilities
	public int GetTimeRemaining() {
		if (this.IsPermanent()) return -1; // Permanent
		if (this.IsExpired()) return 0;    // Expired
		return this.ExpiresTimestamp - GetTime();
	}
	
	public void GetFormattedExpiration(char[] buffer, int maxlen) {
		if (this.IsPermanent()) {
			strcopy(buffer, maxlen, "Permanent");
		} else if (this.IsExpired()) {
			strcopy(buffer, maxlen, "Expired");
		} else {
			FormatTime(buffer, maxlen, "%Y-%m-%d %H:%M:%S", this.ExpiresTimestamp);
		}
	}
	
	public void GetFormattedDuration(char[] buffer, int maxlen) {
		if (this.IsPermanent()) {
			strcopy(buffer, maxlen, "Permanent");
		} else {
			Format(buffer, maxlen, "%d minutes", this.DurationMinutes);
		}
	}
	
	// Ban type utilities
	public void GetBanTypeString(char[] buffer, int maxlen) {
		GetBanTypeString(this.BanType, buffer, maxlen);
	}
	
	// Quick setup methods
	public void ApplyBan(int banType, int durationMinutes, const char[] reason, int adminAccountId) {
		this.BanType = banType;
		this.DurationMinutes = durationMinutes; // Auto-calculates expiration
		this.SetReason(reason);
		this.AdminAccountId = adminAccountId;
		this.CreatedTimestamp = GetTime();
	}
	
	public void Clear() {
		this.BanType = 0;
		this.CreatedTimestamp = 0;
		this.DurationMinutes = 0;
		this.ExpiresTimestamp = 0;
		this.AdminAccountId = 0;
		this.SetReason("");
	}
	
	// Debug utilities
	public void ToString(char[] buffer, int maxlen) {
		char reason[128], banTypes[64], expiration[32];
		this.GetReason(reason, sizeof(reason));
		this.GetBanTypeString(banTypes, sizeof(banTypes));
		this.GetFormattedExpiration(expiration, sizeof(expiration));
		
		Format(buffer, maxlen, "PlayerBanInfo[AccountID=%d, BanType=%d(%s), Duration=%d, Expires=%s, Reason=%s]",
			this.AccountId, this.BanType, banTypes, this.DurationMinutes, expiration, reason);
	}
}

enum struct InstallationStatus {
	bool mysqlTables;
	bool mysqlProcedures;
	bool sqliteTables;
	bool sqliteIndexes;
	int clientUserId;
	int totalOperations;
	int completedOperations;  // Nuevo campo para rastrear operaciones completadas
	Handle timeoutTimer;
	ReplySource cmdReplySource;  // Contexto del comando original
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
		SQL_TConnect(MySQL_ConnectCallback, TABLE_BANS);
	else
		CVBLog.SQL("MySQL configuration '%s' not found, using SQLite only", TABLE_BANS);
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
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "id INT(11) NOT NULL AUTO_INCREMENT, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "account_id INT(11) NOT NULL, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "ban_type INT(11) NOT NULL, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "created_timestamp INT(11) NOT NULL, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "duration_minutes INT(11) DEFAULT 0, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "expires_timestamp INT(11) DEFAULT 0, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "admin_account_id INT(11) DEFAULT NULL, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "reason TEXT DEFAULT NULL, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "is_active TINYINT(1) DEFAULT 1, ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "PRIMARY KEY (id), ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "KEY idx_account_active (account_id, is_active, expires_timestamp), ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "KEY idx_expires (expires_timestamp, is_active), ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "KEY idx_admin (admin_account_id), ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "KEY idx_created (created_timestamp)");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
	
	SQL_TQuery(g_hMySQLDB, MySQLTables_Callback, sQuery);
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


/**
 * Updates the local SQLite cache with ban information for a player.
 *
 * This function inserts or replaces a ban record in the local SQLite database cache.
 * It constructs an SQL REPLACE statement with the provided ban information.
 *
 * @param banInfo           Struct containing the player's ban information.
 */
void CVB_UpdateSQLiteBan(PlayerBanInfo banInfo)
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
		banInfo.AccountId, banInfo.BanType, GetTime(), ttlExpires);

	CVBLog.SQLite("SQLite cache updated for AccountID %d, ban type: %d, TTL expires: %d",
		banInfo.AccountId, banInfo.BanType, ttlExpires);
	
	SQL_TQuery(g_hSQLiteDB, Generic_QueryCallback, sQuery);
}


/**
 * Checks if the given player has an active ban in the MySQL database.
 *
 * This function calls a stored procedure to verify if the specified account ID has an active ban.
 * If the database connection is unavailable, or if there is an error or no result, it returns false.
 * If a valid ban is found, it updates the banType in the provided PlayerBanInfo structure and returns true.
 *
 * @param banInfo      Reference to a PlayerBanInfo structure containing the player's account ID.
 *                     The banType field will be updated if an active ban is found.
 * @return             True if an active ban exists for the account, false otherwise.
 */
bool CVB_CheckMysqlActiveBan(PlayerBanInfo banInfo)
{
	if (g_hMySQLDB == null)
		return false;

	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "CALL %s(%d)", PROCEDURE_CHECK_ACTIVE_BAN, banInfo.AccountId);
	CVBLog.MySQL("CVB_CheckActiveBan: %s", sQuery);

	DBResultSet results = SQL_Query(g_hMySQLDB, sQuery);
	if (results == null)
	{
		char sError[256];
		SQL_GetError(g_hMySQLDB, sError, sizeof(sError));
		CVBLog.MySQL("Error in sp_CheckActiveBan: %s", sError);
		return false;
	}

	if (!results.FetchRow())
	{
		CVBLog.MySQL("sp_CheckActiveBan returned no results for AccountID %d", banInfo.AccountId);
		delete results;
		return false;
	}

	bool isNull = results.IsFieldNull(0);
	if (isNull)
	{
		CVBLog.MySQL("sp_CheckActiveBan returned NULL for AccountID %d", banInfo.AccountId);
		delete results;
		return false;
	}

	banInfo.BanType = results.FetchInt(0);
	delete results;
	return true;
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
		CVBLog.MySQL("sp_CheckActiveBan returned no results for %N AccountID %d", client, accountId);
		return;
	}

	bool isNull = results.IsFieldNull(0);
	if (isNull)
	{
		CVBLog.MySQL("sp_CheckActiveBan returned NULL for %N AccountID %d", client, accountId);
		return;
	}

	if (!IsValidClientIndex(client))
	{
		CVBLog.MySQL("Invalid client index %d for AccountID %d in sp_CheckActiveBan", client, accountId);
		return;
	}

	int banType = results.FetchInt(0);
	if (banType > 0)
	{
		PlayerBanInfo banInfo = new PlayerBanInfo(accountId);
		banInfo.BanType = banType;
		banInfo.CreatedTimestamp = 0;
		banInfo.DurationMinutes = 0; // Duration is not returned by the procedure
		banInfo.ExpiresTimestamp = 0; // Will be calculated by MySQL procedure

		CVB_UpdateCacheStringMap(banInfo);
		g_ClientStates[client].isLoaded = true;
		g_ClientStates[client].isChecking = false;
		CVBLog.Debug("Client %d cache updated with banType=%d after DB check", client, banType);
		delete banInfo;
	}
	else if (banType == 0)
	{
		PlayerBanInfo banInfo = new PlayerBanInfo(accountId);
		banInfo.BanType = 0; // No ban
		banInfo.CreatedTimestamp = 0;
		banInfo.DurationMinutes = 0; // Permanent ban
		banInfo.ExpiresTimestamp = 0; // No expiration
		CVB_UpdateCacheStringMap(banInfo);

		g_ClientStates[client].isLoaded = true;
		g_ClientStates[client].isChecking = false;
		CVBLog.Debug("Client %d cache updated with banType=0 (no ban) after DB check", client);
		delete banInfo;
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
void CVB_InsertMysqlBan(int targetAccountId, int banType, int durationMinutes, int adminAccountId, const char[] reasonText)
{
	if (g_hMySQLDB == null)
	{
		LogError("MySQL not available for InsertBan");
		int adminId = FindClientByAccountID(adminAccountId);
		CReplyToCommand(adminId, "MySQL not available for InsertBan"); // add translations
		return;
	}
	
	char sQuery[MAX_QUERY_LENGTH];
	char sEscapedReason[512];
	g_hMySQLDB.Escape(reasonText, sEscapedReason, sizeof(sEscapedReason));
	
	DataPack dpInsertBan = new DataPack();
	dpInsertBan.WriteCell(targetAccountId);
	dpInsertBan.WriteCell(banType);
	dpInsertBan.WriteCell(adminAccountId);
	
	FormatEx(sQuery, sizeof(sQuery), "CALL %s(%d, %d, %d, %d, '%s')", PROCEDURE_INSERT_BAN, targetAccountId, banType, durationMinutes, adminAccountId, sEscapedReason);
		
	CVBLog.MySQL("CVB_InsertBanWithReason: %s", sQuery);
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
		
		// Also update SQLite cache when ban is inserted
		PlayerBanInfo banInfo = new PlayerBanInfo(targetAccountId);
		banInfo.BanType = banType;
		banInfo.CreatedTimestamp = GetTime();
		banInfo.DurationMinutes = 0;
		banInfo.ExpiresTimestamp = 0;

		// Update StringMap cache with the new ban type
		CVB_UpdateCacheStringMap(banInfo);
		CVBLog.Debug("StringMap cache updated for AccountID %d with new banType %d after successful insert", targetAccountId, banType);
		delete banInfo;
		
		// If target player is online, also update their client state
		int targetClient = FindClientByAccountID(targetAccountId);
		if (targetClient > 0 && IsValidClient(targetClient))
		{
			SetClientBanInfo(targetClient, banType, 0, 0); // durationMinutes=0 for permanent ban
			CVBLog.Debug("Client state updated for online player %N (AccountID: %d) with new banType %d", targetClient, targetAccountId, banType);
		}
		CVB_UpdateSQLiteBan(banInfo);
	}
	else if (resultCode == 1)
	{
		if (adminId != NO_INDEX)
			CReplyToCommand(adminId, "Player already has an active ban for AccountID %d: %s", targetAccountId, message); // add translations
		CVBLog.SQL("Active ban already exists: %s", message);
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
void CVB_RemoveMysqlBan(int targetAccountId, int adminAccountId)
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
	SQL_TQuery(g_hMySQLDB, CVB_RemoveMysqlBan_Callback, sQuery, dpRemoveBan);
}

public void CVB_RemoveMysqlBan_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	DataPack dpRemoveBan = view_as<DataPack>(data);
	dpRemoveBan.Reset();
	int targetAccountId = dpRemoveBan.ReadCell();
	int adminAccountId = dpRemoveBan.ReadCell();
	delete dpRemoveBan;

	int adminId = FindClientByAccountID(adminAccountId);

	if (hndl == null)
	{
		CVBLog.MySQL("Database error removing ban for AccountID %d: %s", targetAccountId, error);
		if (adminId != NO_INDEX)
		{
			CPrintToChat(adminId, "%t %t", "Tag", "DatabaseError");
		}
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

	int removedBanId = results.FetchInt(0);     // removed_ban_id 
	int resultCode = results.FetchInt(1);       // result_code
	char message[256];
	results.FetchString(2, message, sizeof(message)); // message

	if (resultCode == 0)
	{
		CVBLog.SQL("Ban removed successfully: ID=%d, AccountID=%d, Message=%s", removedBanId, targetAccountId, message);
		
		// Find target player for messaging
		int targetId = FindClientByAccountID(targetAccountId);
		
		// Message to admin
		if (adminId != NO_INDEX)
		{
			char targetName[MAX_NAME_LENGTH] = "Unknown Player";
			if (targetId != NO_INDEX)
				GetClientName(targetId, targetName, sizeof(targetName));
			CPrintToChat(adminId, "%t %t", "Tag", "BanRemovedSuccess", targetName);
		}
		
		// Message to target player if online
		if (targetId != NO_INDEX)
		{
			CPrintToChat(targetId, "%t %t", "Tag", "YourBanRemoved");
		}
		
		// Force refresh cache to ensure immediate update
		ForceRefreshCacheEntry(targetAccountId);
		
		// Update SQLite cache
		if (g_hSQLiteDB != null && g_cvarSQLiteCache.BoolValue)
		{
			char sQuery[MAX_QUERY_LENGTH];
			Format(sQuery, sizeof(sQuery), "DELETE FROM %s WHERE account_id = %d", TABLE_CACHE_BANS, targetAccountId);
			SQL_TQuery(g_hSQLiteDB, Generic_QueryCallback, sQuery);
			CVBLog.SQLite("SQLite cache cleared for removed ban AccountID %d", targetAccountId);
		}
	}
	else if (resultCode == 1)
	{
		CVBLog.SQL("No active ban found for AccountID %d: %s", targetAccountId, message);
		if (adminId != NO_INDEX)
		{
			CPrintToChat(adminId, "%t %t", "Tag", "NoBanFound");
		}
	}
	else if (resultCode == 4)
	{
		CVBLog.MySQL("Database error removing ban for AccountID %d: %s", targetAccountId, message);
		if (adminId != NO_INDEX)
		{
			CPrintToChat(adminId, "%t %t", "Tag", "DatabaseError");
		}
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
void CVB_CleanExpiredMysqlBans(int adminAccountId, int batchSize = 100)
{
	char sQuery[MAX_QUERY_LENGTH];
	FormatEx(sQuery, sizeof(sQuery), "CALL %s(%d)", PROCEDURE_CLEAN_EXPIRED, batchSize);

	DataPack dpCleanExpiredBans = new DataPack();
	dpCleanExpiredBans.WriteCell(adminAccountId);
	SQL_TQuery(g_hMySQLDB, CVB_CleanExpiredMysqlBans_Callback, sQuery, dpCleanExpiredBans);
}

public void CVB_CleanExpiredMysqlBans_Callback(Handle owner, Handle hndl, const char[] error, any data)
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

	int cleanedCount = results.FetchInt(0);     // cleaned_count
	int resultCode = results.FetchInt(1);       // result_code  
	char message[256];
	results.FetchString(2, message, sizeof(message)); // message

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

void CVB_CheckMysqlFullBan(PlayerBanInfo playerInfo)
{
	if (g_hMySQLDB == null)
	{
		int adminId = FindClientByAccountID(playerInfo.AdminAccountId);
		if (adminId != NO_INDEX)
		{
			CReplyToCommand(adminId, "%t %t", "Tag", "DatabaseError");
			CReplyToCommand(adminId, "MySQL connection is not available");
		}
		return;
	}
	
	char sQuery[MAX_QUERY_LENGTH];
	FormatEx(sQuery, sizeof(sQuery), "CALL %s(%d)", PROCEDURE_CHECK_FULL_BAN, playerInfo.AccountId);
	CVBLog.MySQL("Executing: %s", sQuery);
	
	DataPack dpCheckFullBan = new DataPack();
	dpCheckFullBan.WriteCell(playerInfo.AccountId);
	
	CVBLog.MySQL("Sending query via SQL_TQuery to callback CheckMysqlFullBan_Callback");
	SQL_TQuery(g_hMySQLDB, CheckMysqlFullBan_Callback, sQuery, dpCheckFullBan);
}

public void CheckMysqlFullBan_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	DataPack dpCheckFullBan = view_as<DataPack>(data);
	dpCheckFullBan.Reset();
	int targetAccountId = dpCheckFullBan.ReadCell();
	delete dpCheckFullBan;
	
	char sAccountId[32];
	IntToString(targetAccountId, sAccountId, sizeof(sAccountId));
	
	PlayerBanInfo banInfo = new PlayerBanInfo(targetAccountId);
	if (!CVB_GetCacheStringMap(banInfo))
	{
		CVBLog.Debug("Failed to retrieve player info from cache for AccountID %d", targetAccountId);
		delete banInfo;
		return;
	}

	int adminId = FindClientByAccountID(banInfo.AdminAccountId);
	int targetId = FindClientByAccountID(targetAccountId);
	SetCmdReplySource(banInfo.CommandReplySource);

	if (hndl == null)
	{
		if (adminId != NO_INDEX)
		{
			CReplyToCommand(adminId, "%t %t", "Tag", "DatabaseError");
			CReplyToCommand(adminId, "MySQL Error: %s", error);
		}
		return;
	}
	
	DBResultSet results = view_as<DBResultSet>(hndl);
	
	bool hasResults = results.HasResults;
	CVBLog.MySQL("DBResultSet.HasResults = %s for %s (AccountID %d)", hasResults ? "true" : "false", PROCEDURE_CHECK_FULL_BAN, banInfo.AccountId);

	if (!hasResults)
	{
		CVBLog.MySQL("CRITICAL: %s has no result set for AccountID %d - procedure may not exist", PROCEDURE_CHECK_FULL_BAN, banInfo.AccountId);
		if (adminId != NO_INDEX)
		{
			CReplyToCommand(adminId, "%t %t", "Tag", "DatabaseError");
			CReplyToCommand(adminId, "CRITICAL: Procedure %s has no result set", PROCEDURE_CHECK_FULL_BAN);
		}
		return;
	}
	
	bool fetchResult = results.FetchRow();
	CVBLog.MySQL("DBResultSet.FetchRow() = %s for %s (AccountID %d)", fetchResult ? "true" : "false", PROCEDURE_CHECK_FULL_BAN, banInfo.AccountId);
	
	bool hasBan = results.FetchInt(0) > 0;
	CVBLog.MySQL("%s: AccountID %d, has_ban = %d", PROCEDURE_CHECK_FULL_BAN, banInfo.AccountId, hasBan ? 1 : 0);
	
	if (hasBan)
	{
		// Orden de columnas del procedimiento sp_CheckFullBan:
		// 0: has_ban, 1: ban_type, 2: expires_timestamp, 3: created_timestamp, 
		// 4: duration_minutes, 5: admin_account_id, 6: reason, 7: ban_id
		banInfo.BanType = results.FetchInt(1);
		banInfo.ExpiresTimestamp = results.FetchInt(2);
		banInfo.CreatedTimestamp = results.FetchInt(3);
		banInfo.DurationMinutes = results.FetchInt(4);
		banInfo.AdminAccountId = results.FetchInt(5);
		char tempReason[128];
		results.FetchString(6, tempReason, sizeof(tempReason));
		banInfo.SetReason(tempReason);

		CVB_UpdateCacheStringMap(banInfo);

		if (targetId != NO_INDEX && IsValidClientIndex(targetId))
		{
			g_ClientStates[targetId].isLoaded = true;
			g_ClientStates[targetId].isChecking = false;
		}

		if (g_hSQLiteDB != null)
			CVB_UpdateSQLiteBan(banInfo);

		CVBLog.Debug("%s: Complete ban info loaded for AccountID %d: Type=%d, Expires=%d", PROCEDURE_CHECK_FULL_BAN, banInfo.AccountId, banInfo.BanType, banInfo.ExpiresTimestamp);

		if (adminId != NO_INDEX)
		{
			char targetName[MAX_NAME_LENGTH] = "Unknown Player";
			char targetSteamId[MAX_AUTHID_LENGTH] = "Unknown";
			
			if (targetId != NO_INDEX && IsValidClientIndex(targetId))
			{
				GetClientName(targetId, targetName, sizeof(targetName));
				GetClientAuthId(targetId, AuthId_Steam2, targetSteamId, sizeof(targetSteamId));
			}
			
			char sBanTypes[128];
			banInfo.GetBanTypeString(sBanTypes, sizeof(sBanTypes));
			
			char sExpiration[64];

			if (banInfo.ExpiresTimestamp == 0)
				Format(sExpiration, sizeof(sExpiration), "%T", "BanStatusPermanent", adminId);
			else
				FormatTime(sExpiration, sizeof(sExpiration), "%Y-%m-%d %H:%M:%S", banInfo.ExpiresTimestamp);
			
			CVBLog.Debug("Sending 'HAS BAN' messages to admin %d for player %s [%s], ban type: %s", adminId, targetName, targetSteamId, sBanTypes);
			
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusHeader", targetName);
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusAccountID", banInfo.AccountId);
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusBanned");
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusRestrictedTypes", sBanTypes);
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusExpiration", sExpiration);
		}
	}
	else
	{
		banInfo.AdminAccountId = 0;
		banInfo.CommandReplySource = SM_REPLY_TO_CONSOLE;

		CVB_UpdateCacheStringMap(banInfo);
		
		if (targetId != NO_INDEX && IsValidClientIndex(targetId))
		{
			g_ClientStates[targetId].isLoaded = true;
			g_ClientStates[targetId].isChecking = false;
		}

		CVBLog.Debug("%s: No active ban for AccountID %d", PROCEDURE_CHECK_FULL_BAN, banInfo.AccountId);
		
		if (adminId != NO_INDEX)
		{
			char targetName[MAX_NAME_LENGTH] = "Unknown Player";
			char targetSteamId[MAX_AUTHID_LENGTH] = "Unknown";
			
			if (targetId != NO_INDEX && IsValidClientIndex(targetId))
			{
				GetClientName(targetId, targetName, sizeof(targetName));
				GetClientAuthId(targetId, AuthId_Steam2, targetSteamId, sizeof(targetSteamId));
			}
			
			CVBLog.Debug("Sending 'NO BAN' messages to admin %d for player %s [%s]", adminId, targetName, targetSteamId);
			
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusHeader", targetName);
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusAccountID", banInfo.AccountId);
			CReplyToCommand(adminId, "%t %t", "Tag", "BanStatusUnbanned");
		}
	}
	delete banInfo;
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
	g_InstallStatus.cmdReplySource = GetCmdReplySource();  // Guardar contexto del comando
	CVBLog.Debug("Captured command context - ReplySource: %d (0=Console, 1=Chat)", g_InstallStatus.cmdReplySource);
	g_InstallStatus.totalOperations = 0;
	g_InstallStatus.completedOperations = 0; // Resetear contador
	
	if (g_InstallStatus.timeoutTimer != null)
	{
		delete g_InstallStatus.timeoutTimer;
		g_InstallStatus.timeoutTimer = null;
	}
	
	if (installMySQL && g_hMySQLDB != null)
		g_InstallStatus.totalOperations += 2;
	
	if (installSQLite && g_hSQLiteDB != null)
		g_InstallStatus.totalOperations += 2;
	
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

/*****************************************************************
			R E I N S T A L L A T I O N   T R A C K I N G
*****************************************************************/

/**
 * Inicializa el seguimiento de REINSTALACIÓN completa de base de datos
 * PELIGROSO: Elimina todo y lo recrea desde cero
 *
 * @param client            Cliente que ejecutó el comando
 * @param installMySQL      Si debe reinstalar MySQL completamente
 * @param installSQLite     Si debe reinstalar SQLite completamente
 */
void InitReinstallationTracking(int client, bool installMySQL, bool installSQLite)
{
	// Reset all installation status
	g_InstallStatus.mysqlTables = false;
	g_InstallStatus.mysqlProcedures = false;
	g_InstallStatus.sqliteTables = false;
	g_InstallStatus.sqliteIndexes = false;
	g_InstallStatus.clientUserId = (client == SERVER_INDEX) ? 0 : GetClientUserId(client);
	g_InstallStatus.cmdReplySource = GetCmdReplySource();
	CVBLog.Debug("REINSTALL: Captured command context - ReplySource: %d", g_InstallStatus.cmdReplySource);
	g_InstallStatus.totalOperations = 0;
	g_InstallStatus.completedOperations = 0;
	
	if (g_InstallStatus.timeoutTimer != null)
	{
		delete g_InstallStatus.timeoutTimer;
		g_InstallStatus.timeoutTimer = null;
	}
	
	// Count operations: DROP operations + CREATE operations
	if (installMySQL && g_hMySQLDB != null)
		g_InstallStatus.totalOperations += 4; // Drop procedures + Drop table + Create table + Create procedures
	
	if (installSQLite && g_hSQLiteDB != null)
		g_InstallStatus.totalOperations += 4; // Drop indexes + Drop table + Create table + Create indexes
	
	CVBLog.Debug("REINSTALL: Tracking initialized: %d operations planned (DANGEROUS)", g_InstallStatus.totalOperations);

	if (g_InstallStatus.totalOperations > 0)
	{
		g_InstallStatus.timeoutTimer = CreateTimer(45.0, Timer_InstallationTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
		
		CVBLog.Debug("REINSTALL: Starting DESTRUCTIVE operations...");
		
		if (installMySQL && g_hMySQLDB != null)
		{
			CVBLog.Debug("REINSTALL: Starting MySQL complete reinstallation...");
			DropMySQLStructures();
		}
		
		if (installSQLite && g_hSQLiteDB != null)
		{
			CVBLog.Debug("REINSTALL: Starting SQLite complete reinstallation...");
			DropSQLiteStructures();
		}
	}
}

/*****************************************************************
			D R O P   S T R U C T U R E S   F U N C T I O N S
*****************************************************************/

/**
 * DANGEROUS: Drops all MySQL stored procedures
 * This is part of the complete reinstallation process
 */
void DropMySQLStructures()
{
	CVBLog.Debug("REINSTALL: Dropping all MySQL stored procedures...");
	
	// Instead of dropping all procedures at once, we'll drop them one by one
	// Start with the first procedure
	DropNextMySQLProcedure(0);
}

/**
 * Recursively drops MySQL procedures one by one to avoid syntax errors
 */
void DropNextMySQLProcedure(int procedureIndex)
{
	char procedureNames[6][64] = {
		PROCEDURE_CHECK_ACTIVE_BAN,
		PROCEDURE_CHECK_FULL_BAN,
		PROCEDURE_INSERT_BAN,
		PROCEDURE_REMOVE_BAN,
		PROCEDURE_CLEAN_EXPIRED,
		PROCEDURE_GET_STATISTICS
	};
	
	if (procedureIndex >= sizeof(procedureNames))
	{
		// All procedures dropped, now drop the table
		CVBLog.Debug("REINSTALL: All MySQL procedures dropped successfully");
		MarkOperationComplete("mysql_drop_procedures", true);
		DropMySQLTable();
		return;
	}
	
	char sQuery[256];
	Format(sQuery, sizeof(sQuery), "DROP PROCEDURE IF EXISTS %s", procedureNames[procedureIndex]);
	
	DataPack dp = new DataPack();
	dp.WriteCell(procedureIndex);
	
	SQL_TQuery(g_hMySQLDB, DropMySQLProcedure_Callback, sQuery, dp);
}

/**
 * Callback for dropping individual MySQL procedure
 */
void DropMySQLProcedure_Callback(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	int procedureIndex = data.ReadCell();
	delete data;
	
	if (error[0])
	{
		CVBLog.Debug("REINSTALL: Error dropping MySQL procedure %d: %s", procedureIndex, error);
		LogError("[DropMySQLProcedure_Callback] Error dropping procedure %d: %s", procedureIndex, error);
		MarkOperationComplete("mysql_drop_procedures", false);
		return;
	}
	
	CVBLog.Debug("REINSTALL: MySQL procedure %d dropped successfully", procedureIndex);
	
	// Continue with next procedure
	DropNextMySQLProcedure(procedureIndex + 1);
}

/**
 * DANGEROUS: Drops the MySQL callvote_bans table
 */
void DropMySQLTable()
{
	CVBLog.Debug("REINSTALL: Dropping MySQL table %s...", TABLE_BANS);
	
	char sQuery[256];
	Format(sQuery, sizeof(sQuery), "DROP TABLE IF EXISTS %s", TABLE_BANS);
	
	SQL_TQuery(g_hMySQLDB, DropMySQLTable_Callback, sQuery);
}

/**
 * Callback for dropping MySQL table
 */
void DropMySQLTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (error[0])
	{
		CVBLog.Debug("REINSTALL: Error dropping MySQL table: %s", error);
		LogError("[DropMySQLTable_Callback] Error: %s", error);
		MarkOperationComplete("mysql_drop_table", false);
		return;
	}
	
	CVBLog.Debug("REINSTALL: MySQL table dropped successfully");
	MarkOperationComplete("mysql_drop_table", true);
	
	// Now recreate the table
	CreateMySQLTables();
}

/**
 * DANGEROUS: Drops all SQLite structures
 * This includes indexes and the cache table
 */
void DropSQLiteStructures()
{
	CVBLog.Debug("REINSTALL: Dropping SQLite indexes...");
	
	char sQuery[1024];
	Format(sQuery, sizeof(sQuery), 
		"DROP INDEX IF EXISTS idx_account_id; " ...
		"DROP INDEX IF EXISTS idx_ttl_expires; " ...
		"DROP INDEX IF EXISTS idx_cached_timestamp"
	);
	
	SQL_TQuery(g_hSQLiteDB, DropSQLiteIndexes_Callback, sQuery);
}

/**
 * Callback for dropping SQLite indexes
 */
void DropSQLiteIndexes_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (error[0])
	{
		CVBLog.Debug("REINSTALL: Error dropping SQLite indexes: %s", error);
		LogError("[DropSQLiteIndexes_Callback] Error: %s", error);
		MarkOperationComplete("sqlite_drop_indexes", false);
		return;
	}
	
	CVBLog.Debug("REINSTALL: SQLite indexes dropped successfully");
	MarkOperationComplete("sqlite_drop_indexes", true);
	
	// Now drop the table
	DropSQLiteTable();
}

/**
 * DANGEROUS: Drops the SQLite cache table
 */
void DropSQLiteTable()
{
	CVBLog.Debug("REINSTALL: Dropping SQLite table %s...", TABLE_CACHE_BANS);
	
	char sQuery[256];
	Format(sQuery, sizeof(sQuery), "DROP TABLE IF EXISTS %s", TABLE_CACHE_BANS);
	
	SQL_TQuery(g_hSQLiteDB, DropSQLiteTable_Callback, sQuery);
}

/**
 * Callback for dropping SQLite table
 */
void DropSQLiteTable_Callback(Database db, DBResultSet results, const char[] error, any data)
{
	if (error[0])
	{
		CVBLog.Debug("REINSTALL: Error dropping SQLite table: %s", error);
		LogError("[DropSQLiteTable_Callback] Error: %s", error);
		MarkOperationComplete("sqlite_drop_table", false);
		return;
	}
	
	CVBLog.Debug("REINSTALL: SQLite table dropped successfully");
	MarkOperationComplete("sqlite_drop_table", true);
	
	// Now recreate the table
	CreateSQLiteTables();
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
	// Handle DROP operations for reinstallation
	else if (StrEqual(operation, "mysql_drop_procedures") || 
			 StrEqual(operation, "mysql_drop_table") ||
			 StrEqual(operation, "sqlite_drop_indexes") ||
			 StrEqual(operation, "sqlite_drop_table"))
	{
		// For DROP operations, we just increment the counter
		// The actual status is tracked by the subsequent CREATE operations
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
		CVBLog.Debug("About to call GenerateInstallationReport(false) - current client: %d", g_InstallStatus.clientUserId);
		GenerateInstallationReport(false);
	}
	else
		CVBLog.Debug("Installation not yet complete, waiting for more operations...");
}

/**
 * Genera el reporte final de instalación
 *
 * @param isTimeout     Si el reporte se genera por timeout
 */
void GenerateInstallationReport(bool isTimeout)
{
	CVBLog.Debug("=== GenerateInstallationReport START ===");
	CVBLog.Debug("Timeout parameter: %s", isTimeout ? "true" : "false");
	CVBLog.Debug("g_InstallStatus.clientUserId: %d", g_InstallStatus.clientUserId);
	
	int client = (g_InstallStatus.clientUserId == 0) ? SERVER_INDEX : GetClientOfUserId(g_InstallStatus.clientUserId);
	CVBLog.Debug("Resolved client: %d", client);
	
	if (client == SERVER_INDEX && g_InstallStatus.clientUserId != 0)
	{
		CVBLog.Debug("Client disconnected (GetClientOfUserId returned 0), skipping installation report");
		return;
	}

	CVBLog.Debug("Generating installation report for client (isTimeout: %s)", isTimeout ? "true" : "false");

	if (g_InstallStatus.timeoutTimer != null)
	{
		CVBLog.Debug("Deleting timeout timer...");
		delete g_InstallStatus.timeoutTimer;
		g_InstallStatus.timeoutTimer = null;
	}
	
	bool isValidTarget = (client == SERVER_INDEX) || (client > 0 && IsValidClient(client));
	
	CVBLog.Debug("Report target validation - client: %d, SERVER_INDEX: %d, isValidTarget: %s", 
		client, SERVER_INDEX, isValidTarget ? "true" : "false");
	
	if (isValidTarget)
	{
		CVBLog.Debug("Target is valid, starting report generation...");
		CReplyToCommand(client, "%t", "InstallResultHeader");
		
		if (isTimeout)
		{
			CVBLog.Debug("Timeout detected, sending timeout message...");
			CReplyToCommand(client, "%t %t", "Tag", "InstallationTimeout");
		}
		
		if (g_InstallStatus.mysqlTables || g_InstallStatus.mysqlProcedures)
		{
			char status[64];
			if (g_InstallStatus.mysqlTables && g_InstallStatus.mysqlProcedures)
				Format(status, sizeof(status), "%t", "InstallSuccess");
			else if (g_InstallStatus.mysqlTables && !g_InstallStatus.mysqlProcedures)
				Format(status, sizeof(status), "%t", "TablesCreatedProceduresFailed");
			else if (!g_InstallStatus.mysqlTables && g_InstallStatus.mysqlProcedures)
				Format(status, sizeof(status), "%t", "TablesFailedProceduresSuccess");
			else
				Format(status, sizeof(status), "%t", "InstallationFailed");
			
			CReplyToCommand(client, "%t %t", "Tag", "MySQLStatus", status);
			
			if (g_InstallStatus.mysqlTables)
				CReplyToCommand(client, "%t %t", "Tag", "ComponentSuccess", "Tablas principales");
			else
				CReplyToCommand(client, "%t %t", "Tag", "ComponentFailed", "Tablas principales");
			
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
				CReplyToCommand(client, "%t %t", "Tag", "ComponentFailed", "Procedimientos almacenados");
		}
		
		if (g_InstallStatus.sqliteTables || g_InstallStatus.sqliteIndexes)
		{
			char status[64];
			if (g_InstallStatus.sqliteTables && g_InstallStatus.sqliteIndexes)
				Format(status, sizeof(status), "%t", "InstallSuccess");
			else if (g_InstallStatus.sqliteTables && !g_InstallStatus.sqliteIndexes)
				Format(status, sizeof(status), "%t", "TablesCreatedIndexesFailed");
			else if (!g_InstallStatus.sqliteTables && g_InstallStatus.sqliteIndexes)
				Format(status, sizeof(status), "%t", "TablesFailedIndexesSuccess");
			else
				Format(status, sizeof(status), "%t", "InstallationFailed");
			
			CReplyToCommand(client, "%t %t", "Tag", "SQLiteStatus", status);

			if (g_InstallStatus.sqliteTables)
				CReplyToCommand(client, "%t %t", "Tag", "ComponentSuccess", "Tabla de cache");
			else
				CReplyToCommand(client, "%t %t", "Tag", "ComponentFailed", "Tabla de cache");
			
			if (g_InstallStatus.sqliteIndexes)
				CReplyToCommand(client, "%t %t", "Tag", "ComponentSuccess", "Índices de optimización (1/1)");
			else
				CReplyToCommand(client, "%t %t", "Tag", "ComponentFailed", "Índices de optimización");
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
		
		bool installationSuccessful = true;
		CVBLog.Debug("Evaluating installation success - MySQL(T:%s P:%s) SQLite(T:%s I:%s)", 
			g_InstallStatus.mysqlTables ? "true" : "false",
			g_InstallStatus.mysqlProcedures ? "true" : "false",
			g_InstallStatus.sqliteTables ? "true" : "false", 
			g_InstallStatus.sqliteIndexes ? "true" : "false");
			
		if (g_InstallStatus.mysqlTables || g_InstallStatus.mysqlProcedures)
		{
			CVBLog.Debug("MySQL operations detected, checking success...");
			if (!g_InstallStatus.mysqlTables || !g_InstallStatus.mysqlProcedures)
			{
				CVBLog.Debug("MySQL operations incomplete - marking as failed");
				installationSuccessful = false;
			}
		}
		if (g_InstallStatus.sqliteTables || g_InstallStatus.sqliteIndexes)
		{
			CVBLog.Debug("SQLite operations detected, checking success...");
			if (!g_InstallStatus.sqliteTables || !g_InstallStatus.sqliteIndexes)
			{
				CVBLog.Debug("SQLite operations incomplete - marking as failed");
				installationSuccessful = false;
			}
		}
		
		CVBLog.Debug("Final installation success evaluation: %s, isTimeout: %s", 
			installationSuccessful ? "true" : "false", 
			isTimeout ? "true" : "false");
		
		CVBLog.Debug("About to send final message - checking conditions:");
		CVBLog.Debug("  installationSuccessful: %s", installationSuccessful ? "true" : "false");
		CVBLog.Debug("  !isTimeout: %s", !isTimeout ? "true" : "false");
		CVBLog.Debug("  Combined condition: %s", (installationSuccessful && !isTimeout) ? "true" : "false");
		
		if (installationSuccessful && !isTimeout)
		{
			CVBLog.Debug("=== SENDING SUCCESS MESSAGE ===");
			CVBLog.Debug("Client: %d, Saved ReplySource: %d", client, g_InstallStatus.cmdReplySource);
			
			ReplySource oldSource = SetCmdReplySource(g_InstallStatus.cmdReplySource);
			CVBLog.Debug("Applied saved command context, old source: %d", oldSource);
			
			CVBLog.Debug("Calling CReplyToCommand with success message...");
			CReplyToCommand(client, "%t %t", "Tag", "InstallationCompletedSuccessfully");
			
			SetCmdReplySource(oldSource);
			CVBLog.Debug("=== SUCCESS MESSAGE SENT ===");
		}
		else if (isTimeout)
		{
			CVBLog.Debug("=== SENDING TIMEOUT MESSAGE ===");
			CVBLog.Debug("Client: %d, Saved ReplySource: %d", client, g_InstallStatus.cmdReplySource);
			
			ReplySource oldSource = SetCmdReplySource(g_InstallStatus.cmdReplySource);
			
			CVBLog.Debug("Calling CReplyToCommand with timeout message...");
			CReplyToCommand(client, "%t %t", "Tag", "InstallationCompletedWithTimeout");
			
			SetCmdReplySource(oldSource);
			CVBLog.Debug("=== TIMEOUT MESSAGE SENT ===");
		}
		else
		{
			CVBLog.Debug("=== SENDING ERROR MESSAGE ===");
			CVBLog.Debug("Client: %d, Saved ReplySource: %d", client, g_InstallStatus.cmdReplySource);
			
			ReplySource oldSource = SetCmdReplySource(g_InstallStatus.cmdReplySource);
			
			CVBLog.Debug("Calling CReplyToCommand with error message...");
			CReplyToCommand(client, "%t %t", "Tag", "InstallationCompletedWithErrors");
			
			SetCmdReplySource(oldSource);
			CVBLog.Debug("=== ERROR MESSAGE SENT ===");
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
	CVBLog.Debug("Installation timeout reached - generating timeout report (client: %d)", g_InstallStatus.clientUserId);
	GenerateInstallationReport(true);
	return Plugin_Stop;
}

public void MySQLTables_Callback(Handle owner, Handle hndl, const char[] error, any data)
{
	bool success = (hndl != null);
	
	if (!success)
		CVBLog.SQL("Error creating MySQL tables: %s", error);
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
		CVBLog.SQL("Error creating SQLite indexes: %s", error);
	else
		CVBLog.SQL("SQLite indexes created successfully");
	
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
			return true;
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
		CreateProcedureWithConfig(firstProc, config);
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
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE ban_type_result INT DEFAULT 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN SELECT 0 as ban_type; END; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT IFNULL(ban_type, 0) INTO ban_type_result FROM callvote_bans ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "WHERE account_id = p_account_id AND is_active = 1 ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "AND (expires_timestamp = 0 OR expires_timestamp > UNIX_TIMESTAMP()) ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "ORDER BY created_timestamp DESC LIMIT 1; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT ban_type_result as ban_type; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "END");
		}
		case PROC_CHECK_FULL_BAN:
		{
			iLen = 0;
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "CREATE PROCEDURE %s(IN p_account_id INT) ", PROCEDURE_CHECK_FULL_BAN);
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "BEGIN ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT 0 as has_ban, 0 as ban_type, 0 as expires_timestamp, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "0 as created_timestamp, 0 as duration_minutes, 0 as admin_account_id, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "'' as reason, 0 as ban_id; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "END; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL((SELECT 1 FROM callvote_bans WHERE account_id = p_account_id AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > UNIX_TIMESTAMP()) LIMIT 1), 0) as has_ban, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL((SELECT ban_type FROM callvote_bans WHERE account_id = p_account_id AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > UNIX_TIMESTAMP()) ORDER BY created_timestamp DESC LIMIT 1), 0) as ban_type, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL((SELECT expires_timestamp FROM callvote_bans WHERE account_id = p_account_id AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > UNIX_TIMESTAMP()) ORDER BY created_timestamp DESC LIMIT 1), 0) as expires_timestamp, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL((SELECT created_timestamp FROM callvote_bans WHERE account_id = p_account_id AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > UNIX_TIMESTAMP()) ORDER BY created_timestamp DESC LIMIT 1), 0) as created_timestamp, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL((SELECT duration_minutes FROM callvote_bans WHERE account_id = p_account_id AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > UNIX_TIMESTAMP()) ORDER BY created_timestamp DESC LIMIT 1), 0) as duration_minutes, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL((SELECT admin_account_id FROM callvote_bans WHERE account_id = p_account_id AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > UNIX_TIMESTAMP()) ORDER BY created_timestamp DESC LIMIT 1), 0) as admin_account_id, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL((SELECT reason FROM callvote_bans WHERE account_id = p_account_id AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > UNIX_TIMESTAMP()) ORDER BY created_timestamp DESC LIMIT 1), '') as reason, ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IFNULL((SELECT id FROM callvote_bans WHERE account_id = p_account_id AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > UNIX_TIMESTAMP()) ORDER BY created_timestamp DESC LIMIT 1), 0) as ban_id; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "END");
		}
		case PROC_INSERT_BAN:
		{
			iLen = 0;
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "CREATE PROCEDURE %s(", PROCEDURE_INSERT_BAN);
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IN p_account_id INT, IN p_ban_type INT, IN p_duration_minutes INT, IN p_admin_account_id INT, IN p_reason TEXT) ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "BEGIN ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_existing_ban_type INT DEFAULT 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_existing_ban_id INT DEFAULT 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_expires_time INT; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_current_time INT DEFAULT UNIX_TIMESTAMP(); ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_ban_id INT DEFAULT 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_result_code INT DEFAULT 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_message VARCHAR(255) DEFAULT ''; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SELECT 0 as ban_id, 4 as result_code, 'Database error occurred' as message; END; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "START TRANSACTION; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT ban_type, id INTO v_existing_ban_type, v_existing_ban_id FROM callvote_bans WHERE account_id = p_account_id AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > v_current_time) ORDER BY created_timestamp DESC LIMIT 1; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "UPDATE callvote_bans SET is_active = 0 WHERE account_id = p_account_id AND is_active = 1; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_expires_time = CASE WHEN p_duration_minutes > 0 THEN v_current_time + (p_duration_minutes * 60) ELSE 0 END; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "INSERT INTO callvote_bans (account_id, ban_type, created_timestamp, duration_minutes, expires_timestamp, admin_account_id, reason, is_active) VALUES (p_account_id, p_ban_type, v_current_time, p_duration_minutes, v_expires_time, p_admin_account_id, p_reason, 1); ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_ban_id = LAST_INSERT_ID(); ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_result_code = 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_message = 'Ban inserted successfully'; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "COMMIT; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT v_ban_id as ban_id, v_result_code as result_code, v_message as message; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "END");
		}
		case PROC_REMOVE_BAN:
		{
			iLen = 0;
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "CREATE PROCEDURE %s(", PROCEDURE_REMOVE_BAN);
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IN p_account_id INT, IN p_admin_account_id INT) ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "BEGIN ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_current_time INT DEFAULT UNIX_TIMESTAMP(); ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_removed_ban_id INT DEFAULT 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_result_code INT DEFAULT 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE v_message VARCHAR(255) DEFAULT ''; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SELECT 0 as removed_ban_id, 4 as result_code, 'Database error occurred' as message; END; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "START TRANSACTION; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT id INTO v_removed_ban_id FROM callvote_bans WHERE account_id = p_account_id AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > v_current_time) ORDER BY created_timestamp DESC LIMIT 1; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "IF v_removed_ban_id IS NULL OR v_removed_ban_id = 0 THEN ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_result_code = 1; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_message = 'No active ban found for this player'; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_removed_ban_id = 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "COMMIT; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "ELSE ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "UPDATE callvote_bans SET is_active = 0 WHERE id = v_removed_ban_id; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_result_code = 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_message = 'Ban removed successfully'; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "COMMIT; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "END IF; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT v_removed_ban_id as removed_ban_id, v_result_code as result_code, v_message as message; ");
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
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SELECT 0 as cleaned_count, 4 as result_code, 'Database error during cleanup' as message; END; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "START TRANSACTION; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "UPDATE callvote_bans SET is_active = 0 WHERE is_active = 1 AND expires_timestamp > 0 AND expires_timestamp < v_current_time LIMIT p_batch_size; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_cleaned_count = ROW_COUNT(); ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_result_code = 0; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SET v_message = CONCAT('Cleaned ', v_cleaned_count, ' expired bans'); ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "COMMIT; ");
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "SELECT v_cleaned_count as cleaned_count, v_result_code as result_code, v_message as message; ");
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
			iLen += Format(szCreateQuery[iLen], sizeof(szCreateQuery) - iLen, "COUNT(CASE WHEN is_active = 0 OR (expires_timestamp > 0 AND expires_timestamp <= UNIX_TIMESTAMP()) THEN 1 END) as expired_bans, ");
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
			isExpectedWarning = true;
		
		if (isExpectedWarning)
			CVBLog.SQL("Procedure at index %d skipped (expected warning): %s", iPR.current, error);
		else
		{
			CVBLog.Debug("Actual error at index %d: '%s'", iPR.current, error);
			LogError("[CreateProcedureWithConfig_Callback] Failed to create procedure at index %d: %s", iPR.current, error);
			MarkOperationComplete("mysql_procedures", false);
			return;
		}
	}
	else
		CVBLog.SQL("Successfully created procedure at index: %d", iPR.current);
	
	if (AdvanceToNextProcedure(iPR))
	{
		Procedure nextProc = GetCurrentProcedure(iPR);
		if (nextProc != view_as<Procedure>(-1))
			CreateProcedureWithConfig(nextProc, iPR);
	}
	else
	{
		CVBLog.SQL("All configured procedures installed successfully");
		MarkOperationComplete("mysql_procedures", true);
	}
}


/**
 * Checks if there is an active ban for the given player in the SQLite cache.
 *
 * This function queries the SQLite database for a ban entry matching the provided
 * account ID. It verifies if the ban is still valid based on the TTL (time-to-live)
 * and cache expiration settings. If a valid cached ban is found, the ban type is
 * updated in the provided PlayerBanInfo structure and the function returns true.
 * If the cache entry is expired or not found, it removes the expired entry and returns false.
 *
 * Logging is performed for cache hits, misses, errors, and expired entries.
 *
 * @param banInfo      Reference to a PlayerBanInfo structure containing the account ID.
 *                     The banType field will be updated if a valid cached ban is found.
 * @return             True if an active cached ban exists and is valid; false otherwise.
 */
bool CVB_CheckSQLiteBan(PlayerBanInfo banInfo)
{
	if (!g_cvarSQLiteCache.BoolValue || g_hSQLiteDB == null)
		return false;
	
	char sQuery[512];
	int iLen = 0;
	
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "SELECT ban_type, cached_timestamp ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "FROM %s WHERE account_id = %d ", TABLE_CACHE_BANS, banInfo.AccountId);
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "AND (ttl_expires = 0 OR ttl_expires > %d)", GetTime());

	CVBLog.SQLite("Executing SQLite cache query: %s", sQuery);
	DBResultSet results = SQL_Query(g_hSQLiteDB, sQuery);
	
	if (results == null)
	{
		char sError[256];
		SQL_GetError(g_hSQLiteDB, sError, sizeof(sError));
		CVBLog.SQLite("Error in SQLite cache query: %s", sError);
		return false;
	}
	
	if (!results.FetchRow())
	{
		delete results;
		CVBLog.SQLite("SQLite cache MISS for AccountID %d", banInfo.AccountId);
		return false;
	}

	banInfo.BanType = results.FetchInt(0);
	int cachedTimestamp = results.FetchInt(1);
	delete results;

	int sqliteTTLSeconds = g_cvarSQLiteTTLMinutes.IntValue * 60;
	if ((GetTime() - cachedTimestamp) < sqliteTTLSeconds)
	{
		CVBLog.SQLite("SQLite cache HIT for AccountID %d (type: %d)", banInfo.AccountId, banInfo.BanType);
		return true;
	}

	CVBLog.SQLite("SQLite cache EXPIRED for AccountID %d - removing entry", banInfo.AccountId);
	banInfo.BanType = 0;
	RemoveExpiredCacheEntry(banInfo.AccountId);
	return false;
}