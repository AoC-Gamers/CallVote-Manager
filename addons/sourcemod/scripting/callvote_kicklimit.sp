#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <dbi>
#include <steamidtools_helpers>

#undef REQUIRE_PLUGIN
#include <callvote_core>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "1.6.0"
#define CVKL_LOG_TAG "CVKL"
#define CVKL_LOG_FILE "callvote_kicklimit.log"
#define CVKL_SQL_QUERY_LENGTH 600
#define CVKL_WINDOW_SECONDS 86400
#define CVKL_CACHE_MAX_SECONDS 60
#define CVKL_RETRY_SECONDS 30.0

enum KickCountLoadState
{
	KickCount_Uninitialized = 0,
	KickCount_Pending,
	KickCount_Ready
}

enum SQLDriver
{
	SQL_MySQL = 0,
	SQL_SQLite
}

enum struct PlayerInfo
{
	int AccountID;
	int Kick;
	KickCountLoadState LoadState;
	int RequestId;
}

enum struct RuntimeState
{
	bool lateLoad;
	bool hasCore;

	void Reset()
	{
		this.lateLoad = false;
		this.hasCore = false;
	}

	void DetectLibraries()
	{
		this.hasCore = LibraryExists(CALLVOTECORE_LIBRARY);
	}

	void SetLibraryAvailability(const char[] name, bool available)
	{
		if (StrEqual(name, CALLVOTECORE_LIBRARY))
			this.hasCore = available;
	}
}

enum struct PassedKickEvent
{
	int AccountId;
	int Timestamp;
	int Revision;
	bool InsertConfirmed;
	char InsertConfig[64];
	char AbsorbedConfig[64];
}

enum struct KickCountRequestContext
{
	int UserId;
	int AccountId;
	int RequestId;
	int DatabaseGeneration;
	int MapGeneration;
	int QueryRevision;
}

enum struct SQLCallbackContext
{
	int DatabaseGeneration;
	int Revision;
	int SessionId;
	int CallerAccountId;
	int TargetAccountId;
	char Query[CVKL_SQL_QUERY_LENGTH];
}

PlayerInfo g_Players[MAXPLAYERS + 1];

ConVar g_cvarEnable, g_cvarLogMode, g_cvarDebugMask, g_cvarKickLimit, g_cvarSQL, g_cvarSQLConfig;
char g_sTable[] = "callvote_kicklimit";
bool g_bSQLConnected, g_bSQLTableExists, g_bSQLConnecting, g_bReconcilePending, g_bCoreRemovedCleanup;
RuntimeState g_Runtime;
Database g_db;
StringMap g_hSessionKickCounts, g_hSQLKickCounts, g_hSQLKickExpires, g_hSQLInsertPending;
ArrayList g_hPassedKickEvents;
Handle g_hRetryTimer;
CallVoteLogger g_Log = null;
SQLDriver g_SQLDriver;
char g_sConnectedConfig[64];
int g_iDatabaseGeneration, g_iMapGeneration, g_iNextRequestId, g_iNextKickRevision;

public Plugin myinfo =
{
	name = "Call Vote Kick Limit",
	author = "lechuga",
	description = "Limits the amount of callvote kick",
	version = PLUGIN_VERSION,
	url = "https://github.com/lechuga16/callvote_manager"
};

int CurrentTime()
{
	return GetTime();
}

void AccountIDToKey(int accountId, char[] key, int maxLen)
{
	IntToString(accountId, key, maxLen);
}

void SessionIdToKey(int sessionId, char[] key, int maxLen)
{
	IntToString(sessionId, key, maxLen);
}

bool IsLiveIdentity(int client, int accountId)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client)
		&& g_Players[client].AccountID == accountId && GetClientAccountID(client) == accountId;
}

bool FormatAccountIDAsSteamID2(int accountId, char[] output, int maxLen)
{
	if (AccountIDToSteamID2(accountId, output, maxLen))
		return true;
	Format(output, maxLen, "AID:%d", accountId);
	return false;
}

bool FormatTargetSteamID64(int accountId, char[] output, int maxLen)
{
	if (accountId == 0)
	{
		strcopy(output, maxLen, "0");
		return true;
	}
	return accountId > 0 && SteamIDTools_AccountIDToSteamID64(accountId, output, maxLen);
}

bool BuildMySQLKickInsertQuery(int callerAccountId, int targetAccountId, int createdAt, char[] query, int maxLen)
{
	char callerSteamId64[STEAMID64_EXACT_LENGTH + 1], targetSteamId64[STEAMID64_EXACT_LENGTH + 1];
	if (callerAccountId <= 0
		|| !SteamIDTools_AccountIDToSteamID64(callerAccountId, callerSteamId64, sizeof(callerSteamId64))
		|| !FormatTargetSteamID64(targetAccountId, targetSteamId64, sizeof(targetSteamId64)))
	{
		return false;
	}
	Format(query, maxLen, "INSERT INTO `%s` (`caller_account_id`, `caller_steamid64`, `created`, `target_account_id`, `target_steamid64`) VALUES (%d, '%s', %d, %d, '%s')", g_sTable, callerAccountId, callerSteamId64, createdAt, targetAccountId, targetSteamId64);
	return true;
}

void CVKLLogMessage(bool isError, const char[] format, any ...)
{
	char message[512];
	VFormat(message, sizeof(message), format, 3);
	if (isError)
		LogError("%s", message);
	if (g_Log == null)
		return;

	int mask = CVLogMask_Core;
	char category[16] = "Core";
	if (strncmp(message, "[SQL", 4, false) == 0 || strncmp(message, "[Connect", 8, false) == 0 || strncmp(message, "[CheckTable", 11, false) == 0)
	{
		mask = CVLogMask_SQL;
		strcopy(category, sizeof(category), "SQL");
	}
	else if (strncmp(message, "[CallVote_", 10, false) == 0)
	{
		mask = CVLogMask_Session;
		strcopy(category, sizeof(category), "Session");
	}
	g_Log.Debug(mask, category, "%s", message);
}

void ResetClientState(int client)
{
	g_Players[client].AccountID = 0;
	g_Players[client].Kick = 0;
	g_Players[client].LoadState = KickCount_Uninitialized;
	g_Players[client].RequestId = 0;
}

int CountRecentLocalKickEvents(int accountId, int now)
{
	if (g_hPassedKickEvents == null || accountId <= 0)
		return 0;
	int count;
	PassedKickEvent event;
	for (int index = 0; index < g_hPassedKickEvents.Length; index++)
	{
		g_hPassedKickEvents.GetArray(index, event, sizeof(event));
		if (event.AccountId == accountId && event.Timestamp > now - CVKL_WINDOW_SECONDS && event.Timestamp <= now)
			count++;
	}
	return count;
}

int CountSQLOverlayKickEvents(int accountId, int now)
{
	if (g_hPassedKickEvents == null || accountId <= 0)
		return 0;
	int count;
	PassedKickEvent event;
	for (int index = 0; index < g_hPassedKickEvents.Length; index++)
	{
		g_hPassedKickEvents.GetArray(index, event, sizeof(event));
		if (event.AccountId == accountId && event.Timestamp > now - CVKL_WINDOW_SECONDS && event.Timestamp <= now
			&& !StrEqual(event.AbsorbedConfig, g_sConnectedConfig))
			count++;
	}
	return count;
}

void PruneExpiredLocalKickEvents(int now)
{
	if (g_hPassedKickEvents == null)
		return;
	PassedKickEvent event;
	for (int index = g_hPassedKickEvents.Length - 1; index >= 0; index--)
	{
		g_hPassedKickEvents.GetArray(index, event, sizeof(event));
		if (event.Timestamp <= now - CVKL_WINDOW_SECONDS || event.Timestamp > now)
			g_hPassedKickEvents.Erase(index);
	}
}

int FindLocalEventRevision(int revision)
{
	PassedKickEvent event;
	for (int index = 0; index < g_hPassedKickEvents.Length; index++)
	{
		g_hPassedKickEvents.GetArray(index, event, sizeof(event));
		if (event.Revision == revision)
			return index;
	}
	return -1;
}

void RecordPassedKickVote(int callerAccountId, int targetAccountId, int now, int previousCount)
{
	if (callerAccountId <= 0)
		return;
	PruneExpiredLocalKickEvents(now);
	PassedKickEvent event;
	event.AccountId = callerAccountId;
	event.Timestamp = now;
	event.Revision = ++g_iNextKickRevision;
	event.InsertConfirmed = false;
	event.InsertConfig[0] = '\0';
	event.AbsorbedConfig[0] = '\0';
	g_hPassedKickEvents.PushArray(event, sizeof(event));
	UpdateConnectedClientKickCount(callerAccountId, previousCount + 1);
	if (CanUseKickLimitSQL())
		InsertKickRecordSQL(event.Revision, callerAccountId, targetAccountId, now);
}

int GetLocalKickCount(int accountId, int now)
{
	return CountRecentLocalKickEvents(accountId, now);
}

bool CanUseKickLimitSQL()
{
	return g_cvarSQL != null && g_cvarSQL.BoolValue && g_bSQLConnected && g_bSQLTableExists && g_db != null;
}

bool IsCurrentDatabaseCallback(Database db)
{
	return g_db != null && db != null && g_db.IsSameConnection(db);
}

bool IsSQLKickCountCacheFresh(int accountId, int now)
{
	char key[ACCOUNTID_LENGTH];
	AccountIDToKey(accountId, key, sizeof(key));
	int expiresAt;
	return g_hSQLKickExpires != null && g_hSQLKickExpires.GetValue(key, expiresAt) && now < expiresAt;
}

bool GetSQLKickCount(int accountId, int now, int &count)
{
	char key[ACCOUNTID_LENGTH];
	AccountIDToKey(accountId, key, sizeof(key));
	int dbCount;
	if (g_hSQLKickCounts == null || !g_hSQLKickCounts.GetValue(key, dbCount) || !IsSQLKickCountCacheFresh(accountId, now))
		return false;
	count = dbCount + CountSQLOverlayKickEvents(accountId, now);
	return true;
}

int GetPendingInsertCount(int accountId)
{
	char key[ACCOUNTID_LENGTH];
	AccountIDToKey(accountId, key, sizeof(key));
	int pending;
	if (g_hSQLInsertPending != null)
		g_hSQLInsertPending.GetValue(key, pending);
	return pending;
}

void ChangePendingInsertCount(int accountId, int delta)
{
	char key[ACCOUNTID_LENGTH];
	AccountIDToKey(accountId, key, sizeof(key));
	int pending = GetPendingInsertCount(accountId) + delta;
	if (pending <= 0)
		g_hSQLInsertPending.Remove(key);
	else
		g_hSQLInsertPending.SetValue(key, pending);
}

void UpdateConnectedClientKickCount(int accountId, int kickCount)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsLiveIdentity(client, accountId))
			continue;
		g_Players[client].Kick = kickCount;
		if (!g_cvarSQL.BoolValue || CanUseKickLimitSQL())
			g_Players[client].LoadState = KickCount_Ready;
	}
}

void SetSessionKickCountSnapshot(int sessionId, int kickCount)
{
	if (sessionId <= 0 || g_hSessionKickCounts == null)
		return;
	char key[16];
	SessionIdToKey(sessionId, key, sizeof(key));
	g_hSessionKickCounts.SetValue(key, kickCount);
}

bool TryGetSessionKickCountSnapshot(int sessionId, int &kickCount)
{
	if (sessionId <= 0 || g_hSessionKickCounts == null)
		return false;
	char key[16];
	SessionIdToKey(sessionId, key, sizeof(key));
	return g_hSessionKickCounts.GetValue(key, kickCount);
}

void ClearSessionKickCountSnapshot(int sessionId)
{
	if (sessionId <= 0 || g_hSessionKickCounts == null)
		return;
	char key[16];
	SessionIdToKey(sessionId, key, sizeof(key));
	g_hSessionKickCounts.Remove(key);
}

void ClearSessionSnapshots()
{
	if (g_hSessionKickCounts != null)
		g_hSessionKickCounts.Clear();
}

void InitializeClient(int client)
{
	if (!g_cvarEnable.BoolValue || client <= 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
	{
		if (client > 0 && client <= MaxClients)
			ResetClientState(client);
		return;
	}
	int accountId = GetClientAccountID(client);
	ResetClientState(client);
	if (accountId <= 0)
		return;
	g_Players[client].AccountID = accountId;
	if (!g_cvarSQL.BoolValue)
	{
		g_Players[client].Kick = GetLocalKickCount(accountId, CurrentTime());
		g_Players[client].LoadState = KickCount_Ready;
		return;
	}
	int count;
	if (!CanUseKickLimitSQL())
	{
		g_Players[client].LoadState = KickCount_Uninitialized;
		return;
	}
	if (GetSQLKickCount(accountId, CurrentTime(), count))
	{
		g_Players[client].Kick = count;
		g_Players[client].LoadState = KickCount_Ready;
		return;
	}
	RequestKickCountLoad(client, accountId);
}

void ReconcileConnectedClients()
{
	g_bReconcilePending = false;
	if (!g_cvarEnable.BoolValue)
	{
		for (int client = 1; client <= MaxClients; client++)
			ResetClientState(client);
		return;
	}
	for (int client = 1; client <= MaxClients; client++)
		if (IsClientInGame(client) && !IsFakeClient(client))
			InitializeClient(client);
}

public void OnGameFrame()
{
	if (g_bCoreRemovedCleanup)
	{
		g_bCoreRemovedCleanup = false;
		g_iMapGeneration++;
		ClearSessionSnapshots();
	}
	if (g_bReconcilePending)
		ReconcileConnectedClients();
}

void RequestReconcile()
{
	g_bReconcilePending = true;
}

void InvalidateSQLState(bool closeDatabase)
{
	g_iDatabaseGeneration++;
	g_bSQLConnected = false;
	g_bSQLTableExists = false;
	g_bSQLConnecting = false;
	if (g_hRetryTimer != null)
	{
		delete g_hRetryTimer;
		g_hRetryTimer = null;
	}
	if (closeDatabase && g_db != null)
	{
		delete g_db;
		g_db = null;
	}
	if (g_hSQLKickCounts != null)
		g_hSQLKickCounts.Clear();
	if (g_hSQLKickExpires != null)
		g_hSQLKickExpires.Clear();
	if (g_hSQLInsertPending != null)
		g_hSQLInsertPending.Clear();
	for (int client = 1; client <= MaxClients; client++)
	{
		if (g_Players[client].AccountID > 0)
		{
			g_Players[client].LoadState = KickCount_Uninitialized;
			g_Players[client].RequestId = 0;
		}
	}
}

void ScheduleSQLRetry()
{
	if (g_hRetryTimer == null && g_cvarSQL != null && g_cvarSQL.BoolValue)
		g_hRetryTimer = CreateTimer(CVKL_RETRY_SECONDS, Timer_SQLRetry, g_iDatabaseGeneration);
}

void TryConnectSQL()
{
	if (g_cvarSQL == null || !g_cvarSQL.BoolValue || g_db != null || g_bSQLConnecting)
		return;
	char configName[64];
	g_cvarSQLConfig.GetString(configName, sizeof(configName));
	if (!SQL_CheckConfig(configName))
	{
		CVKLLogMessage(true, "[ConnectDB] Missing database config '%s'; retry in %.0f seconds", configName, CVKL_RETRY_SECONDS);
		ScheduleSQLRetry();
		return;
	}
	g_bSQLConnecting = true;
	CVKLLogMessage(false, "[ConnectDB] Connecting to database config '%s'", configName);
	Database.Connect(ConnectCallback, configName, g_iDatabaseGeneration);
}

public Action Timer_SQLRetry(Handle timer, any generation)
{
	g_hRetryTimer = null;
	if (generation == g_iDatabaseGeneration)
		TryConnectSQL();
	return Plugin_Stop;
}

void OnConfigsExecuted_SQL()
{
	if (!g_cvarSQL.BoolValue)
	{
		InvalidateSQLState(true);
		return;
	}
	TryConnectSQL();
}

void CreateSQLiteSchema()
{
	if (g_db == null || g_SQLDriver != SQL_SQLite)
		return;
	char query[512];
	g_db.Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%s` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `caller_account_id` INTEGER NOT NULL DEFAULT 0, `created` INTEGER NOT NULL DEFAULT 0, `target_account_id` INTEGER NOT NULL DEFAULT 0)", g_sTable);
	g_db.Query(SQLiteTableCreatedCallback, query, g_iDatabaseGeneration);
}

public void SQLiteTableCreatedCallback(Database db, DBResultSet results, const char[] error, any generation)
{
	if (generation != g_iDatabaseGeneration || !IsCurrentDatabaseCallback(db))
		return;
	if (results == null)
	{
		CVKLLogMessage(true, "[SQLSQLiteSchema] Table creation failed: %s", error);
		InvalidateSQLState(true);
		ScheduleSQLRetry();
		return;
	}
	char query[512];
	g_db.Format(query, sizeof(query), "CREATE INDEX IF NOT EXISTS `idx_callvote_kicklimit_caller_created` ON `%s` (`caller_account_id`, `created`)", g_sTable);
	g_db.Query(SQLiteIndexCreatedCallback, query, generation);
}

public void SQLiteIndexCreatedCallback(Database db, DBResultSet results, const char[] error, any generation)
{
	if (generation != g_iDatabaseGeneration || !IsCurrentDatabaseCallback(db))
		return;
	if (results == null)
	{
		CVKLLogMessage(true, "[SQLSQLiteSchema] Index creation failed: %s", error);
		InvalidateSQLState(true);
		ScheduleSQLRetry();
		return;
	}
	CheckTableExists();
}

void CheckTableExists()
{
	if (!g_bSQLConnected || g_db == null)
		return;
	char query[256];
	if (g_SQLDriver == SQL_MySQL)
		g_db.Format(query, sizeof(query), "SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = '%s' LIMIT 1", g_sTable);
	else
		g_db.Format(query, sizeof(query), "SELECT 1 FROM sqlite_master WHERE type='table' AND name='%s' LIMIT 1", g_sTable);
	g_db.Query(CheckTableCallback, query, g_iDatabaseGeneration);
}

public void CheckTableCallback(Database db, DBResultSet results, const char[] error, any generation)
{
	if (generation != g_iDatabaseGeneration || !IsCurrentDatabaseCallback(db))
		return;
	if (results == null)
	{
		CVKLLogMessage(true, "[CheckTable] Failed to inspect table: %s", error);
		InvalidateSQLState(true);
		ScheduleSQLRetry();
		return;
	}
	g_bSQLTableExists = results.FetchRow();
	if (!g_bSQLTableExists)
	{
		CVKLLogMessage(true, "[CheckTable] Table '%s' is missing; SQL mode remains fail-closed", g_sTable);
		InvalidateSQLState(true);
		ScheduleSQLRetry();
		return;
	}
	RequestReconcile();
}

public void ConnectCallback(Database database, const char[] error, any generation)
{
	if (generation != g_iDatabaseGeneration)
	{
		if (database != null)
			delete database;
		return;
	}
	g_bSQLConnecting = false;
	if (database == null)
	{
		CVKLLogMessage(true, "[ConnectCallback] Connection failed: %s", error);
		ScheduleSQLRetry();
		return;
	}
	g_db = database;
	g_cvarSQLConfig.GetString(g_sConnectedConfig, sizeof(g_sConnectedConfig));
	DBDriver driver = database.Driver;
	if (driver == null)
	{
		CVKLLogMessage(true, "[ConnectCallback] Could not resolve database driver");
		InvalidateSQLState(true);
		ScheduleSQLRetry();
		return;
	}
	char driverName[64];
	driver.GetIdentifier(driverName, sizeof(driverName));
	if (StrEqual(driverName, "mysql", false))
	{
		g_SQLDriver = SQL_MySQL;
		database.SetCharset("utf8");
	}
	else if (StrEqual(driverName, "sqlite", false))
		g_SQLDriver = SQL_SQLite;
	else
	{
		CVKLLogMessage(true, "[ConnectCallback] Unsupported database driver '%s'", driverName);
		InvalidateSQLState(true);
		ScheduleSQLRetry();
		return;
	}
	g_bSQLConnected = true;
	if (g_SQLDriver == SQL_SQLite)
		CreateSQLiteSchema();
	else
		CheckTableExists();
}

void RequestKickCountLoad(int client, int accountId)
{
	if (!CanUseKickLimitSQL() || !IsLiveIdentity(client, accountId))
		return;
	if (GetPendingInsertCount(accountId) > 0)
	{
		g_Players[client].LoadState = KickCount_Pending;
		return;
	}
	if (g_Players[client].LoadState == KickCount_Pending)
		return;
	int now = CurrentTime();
	if (IsSQLKickCountCacheFresh(accountId, now))
	{
		int currentCount;
		if (GetSQLKickCount(accountId, now, currentCount))
		{
			g_Players[client].Kick = currentCount;
			g_Players[client].LoadState = KickCount_Ready;
			return;
		}
	}
	char query[384];
	if (g_SQLDriver == SQL_MySQL)
		g_db.Format(query, sizeof(query), "SELECT COUNT(*), COALESCE(MIN(`created`), 0) FROM `%s` WHERE `created` > UNIX_TIMESTAMP() - %d AND `caller_account_id` = %d", g_sTable, CVKL_WINDOW_SECONDS, accountId);
	else
		g_db.Format(query, sizeof(query), "SELECT COUNT(*), COALESCE(MIN(`created`), 0) FROM `%s` WHERE `created` > CAST(strftime('%%s','now') AS INTEGER) - %d AND `caller_account_id` = %d", g_sTable, CVKL_WINDOW_SECONDS, accountId);
	KickCountRequestContext context;
	context.UserId = GetClientUserId(client);
	context.AccountId = accountId;
	context.RequestId = ++g_iNextRequestId;
	context.DatabaseGeneration = g_iDatabaseGeneration;
	context.MapGeneration = g_iMapGeneration;
	context.QueryRevision = g_iNextKickRevision;
	g_Players[client].RequestId = context.RequestId;
	g_Players[client].LoadState = KickCount_Pending;
	g_db.Query(GetKickCountCallback, query, CreateKickCountRequestDataPack(context));
}

DataPack CreateKickCountRequestDataPack(KickCountRequestContext context)
{
	DataPack pack = new DataPack();
	pack.WriteCell(context.UserId);
	pack.WriteCell(context.AccountId);
	pack.WriteCell(context.RequestId);
	pack.WriteCell(context.DatabaseGeneration);
	pack.WriteCell(context.MapGeneration);
	pack.WriteCell(context.QueryRevision);
	return pack;
}

KickCountRequestContext ReadKickCountRequestDataPack(DataPack pack)
{
	KickCountRequestContext context;
	pack.Reset();
	context.UserId = pack.ReadCell();
	context.AccountId = pack.ReadCell();
	context.RequestId = pack.ReadCell();
	context.DatabaseGeneration = pack.ReadCell();
	context.MapGeneration = pack.ReadCell();
	context.QueryRevision = pack.ReadCell();
	return context;
}

void StoreSQLKickCount(int accountId, int dbCount, int oldestTimestamp, int now)
{
	char key[ACCOUNTID_LENGTH];
	AccountIDToKey(accountId, key, sizeof(key));
	g_hSQLKickCounts.SetValue(key, dbCount);
	int expiresAt = now + CVKL_CACHE_MAX_SECONDS;
	if (dbCount > 0 && oldestTimestamp > 0)
	{
		int oldestExpiry = oldestTimestamp + CVKL_WINDOW_SECONDS;
		if (oldestExpiry < expiresAt)
			expiresAt = oldestExpiry;
	}
	g_hSQLKickExpires.SetValue(key, expiresAt);
}

void RemoveConfirmedEventsThrough(int accountId, int revision)
{
	PassedKickEvent event;
	for (int index = g_hPassedKickEvents.Length - 1; index >= 0; index--)
	{
		g_hPassedKickEvents.GetArray(index, event, sizeof(event));
		if (event.AccountId == accountId && event.InsertConfirmed && event.Revision <= revision
			&& StrEqual(event.InsertConfig, g_sConnectedConfig))
		{
			strcopy(event.AbsorbedConfig, sizeof(event.AbsorbedConfig), g_sConnectedConfig);
			g_hPassedKickEvents.SetArray(index, event, sizeof(event));
		}
	}
}

bool ApplyKickCountQueryResult(int accountId, int queryRevision, int dbCount, int oldestTimestamp, int now, int &effectiveCount)
{
	if (queryRevision != g_iNextKickRevision || accountId <= 0 || dbCount < 0)
		return false;
	StoreSQLKickCount(accountId, dbCount, oldestTimestamp, now);
	RemoveConfirmedEventsThrough(accountId, queryRevision);
	effectiveCount = dbCount + CountSQLOverlayKickEvents(accountId, now);
	return true;
}

bool ApplyKickCountInsertResult(int revision, bool succeeded)
{
	int index = FindLocalEventRevision(revision);
	if (index < 0)
		return false;
	if (!succeeded)
		return true;
	PassedKickEvent event;
	g_hPassedKickEvents.GetArray(index, event, sizeof(event));
	event.InsertConfirmed = true;
	g_cvarSQLConfig.GetString(event.InsertConfig, sizeof(event.InsertConfig));
	g_hPassedKickEvents.SetArray(index, event, sizeof(event));
	return true;
}

public void GetKickCountCallback(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack pack = view_as<DataPack>(data);
	KickCountRequestContext context;
	context = ReadKickCountRequestDataPack(pack);
	delete pack;
	if (context.DatabaseGeneration != g_iDatabaseGeneration || context.MapGeneration != g_iMapGeneration
		|| !g_Runtime.hasCore || !IsCurrentDatabaseCallback(db))
		return;
	int client = GetClientOfUserId(context.UserId);
	if (client <= 0 || !IsLiveIdentity(client, context.AccountId) || g_Players[client].RequestId != context.RequestId)
		return;
	if (results == null || !results.FetchRow())
	{
		g_Players[client].LoadState = KickCount_Uninitialized;
		CVKLLogMessage(true, "[GetKickCountCallback] Query failed for AID %d: %s", context.AccountId, error);
		InvalidateSQLState(true);
		ScheduleSQLRetry();
		return;
	}
	int dbCount = results.FetchInt(0);
	int oldestTimestamp = results.FetchInt(1);
	int now = CurrentTime();
	int effective;
	if (!ApplyKickCountQueryResult(context.AccountId, context.QueryRevision, dbCount, oldestTimestamp, now, effective))
	{
		g_Players[client].LoadState = KickCount_Uninitialized;
		RequestKickCountLoad(client, context.AccountId);
		return;
	}
	g_Players[client].Kick = effective;
	g_Players[client].LoadState = KickCount_Ready;
}

DataPack CreateInsertContextDataPack(SQLCallbackContext context)
{
	DataPack pack = new DataPack();
	pack.WriteCell(context.DatabaseGeneration);
	pack.WriteCell(context.Revision);
	pack.WriteCell(context.SessionId);
	pack.WriteCell(context.CallerAccountId);
	pack.WriteCell(context.TargetAccountId);
	pack.WriteString(context.Query);
	return pack;
}

SQLCallbackContext ReadInsertContextDataPack(DataPack pack)
{
	SQLCallbackContext context;
	pack.Reset();
	context.DatabaseGeneration = pack.ReadCell();
	context.Revision = pack.ReadCell();
	context.SessionId = pack.ReadCell();
	context.CallerAccountId = pack.ReadCell();
	context.TargetAccountId = pack.ReadCell();
	pack.ReadString(context.Query, sizeof(context.Query));
	return context;
}

void InsertKickRecordSQL(int revision, int callerAccountId, int targetAccountId, int createdAt)
{
	if (!CanUseKickLimitSQL())
		return;
	char query[CVKL_SQL_QUERY_LENGTH];
	if (g_SQLDriver == SQL_MySQL)
	{
		if (!BuildMySQLKickInsertQuery(callerAccountId, targetAccountId, createdAt, query, sizeof(query)))
		{
			CVKLLogMessage(true, "[InsertKickRecordSQL] Failed to convert captured caller/target AccountIDs (revision %d)", revision);
			return;
		}
	}
	else
		g_db.Format(query, sizeof(query), "INSERT INTO `%s` (`caller_account_id`, `created`, `target_account_id`) VALUES (%d, %d, %d)", g_sTable, callerAccountId, createdAt, targetAccountId);
	SQLCallbackContext context;
	context.DatabaseGeneration = g_iDatabaseGeneration;
	context.Revision = revision;
	context.CallerAccountId = callerAccountId;
	context.TargetAccountId = targetAccountId;
	strcopy(context.Query, sizeof(context.Query), query);
	ChangePendingInsertCount(callerAccountId, 1);
	g_db.Query(SQLInsertCallback, query, CreateInsertContextDataPack(context));
}

public void SQLInsertCallback(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack pack = view_as<DataPack>(data);
	SQLCallbackContext context;
	context = ReadInsertContextDataPack(pack);
	delete pack;
	if (context.DatabaseGeneration != g_iDatabaseGeneration || !IsCurrentDatabaseCallback(db))
		return;
	ChangePendingInsertCount(context.CallerAccountId, -1);
	if (results == null)
	{
		CVKLLogMessage(true, "[SQLInsertCallback] INSERT failed for revision %d (no automatic retry): %s", context.Revision, error);
		ApplyKickCountInsertResult(context.Revision, false);
		ResetConnectedAccountLoadState(context.CallerAccountId);
		ForceRefreshConnectedAccount(context.CallerAccountId);
		return;
	}
	ApplyKickCountInsertResult(context.Revision, true);
	ResetConnectedAccountLoadState(context.CallerAccountId);
	ForceRefreshConnectedAccount(context.CallerAccountId);
}

void ResetConnectedAccountLoadState(int accountId)
{
	int client = FindLiveClientByAccountID(accountId);
	if (client > 0)
	{
		g_Players[client].LoadState = KickCount_Uninitialized;
		g_Players[client].RequestId = 0;
	}
}

void ForceRefreshConnectedAccount(int accountId)
{
	char key[ACCOUNTID_LENGTH];
	AccountIDToKey(accountId, key, sizeof(key));
	g_hSQLKickExpires.Remove(key);
	int client = FindLiveClientByAccountID(accountId);
	if (client > 0)
		RequestKickCountLoad(client, accountId);
}

int FindLiveClientByAccountID(int accountId)
{
	for (int client = 1; client <= MaxClients; client++)
		if (IsLiveIdentity(client, accountId))
			return client;
	return 0;
}

public void OnPluginStart()
{
	LoadTranslation("callvote_kicklimit.phrases");
	LoadTranslation("callvote_common.phrases");
	LoadTranslation("common.phrases");
	HookEvent("player_team", Event_PlayerTeam);
	g_cvarEnable = CreateConVar("sm_cvkl_enable", "1", "Enable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarLogMode = CallVoteEnsureLogModeConVar();
	g_cvarDebugMask = CreateConVar("sm_cvkl_debug_mask", "0", "Debug mask for callvote_kicklimit. Core=1 SQL=2 Cache=4 Commands=8 Identity=16 Forwards=32 Session=64 Localization=128 All=255.", FCVAR_NONE, true, 0.0, true, 255.0);
	g_Log = new CallVoteLogger(CVKL_LOG_TAG, CVKL_LOG_FILE, g_cvarLogMode, g_cvarDebugMask);
	g_cvarKickLimit = CreateConVar("sm_cvkl_kicklimit", "1", "Kick limit", FCVAR_NOTIFY, true, 0.0);
	g_cvarSQL = CreateConVar("sm_cvkl_sql", "0", "Enables kick counter registration to the database, if disabled it uses local memory.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarSQLConfig = CreateConVar("sm_cvkl_sql_config", "callvote", "Database config name from databases.cfg for callvote_kicklimit", FCVAR_NONE);
	HookConVarChange(g_cvarEnable, OnKickLimitSettingsChanged);
	HookConVarChange(g_cvarSQL, OnKickLimitSettingsChanged);
	HookConVarChange(g_cvarSQLConfig, OnKickLimitSettingsChanged);
	RegAdminCmd("sm_cvkl_show", Command_KickShow, ADMFLAG_KICK, "Shows in-memory kick records for connected players");
	RegConsoleCmd("sm_cvkl_count", Command_KickCount, "Shows the current kick count for a player");
	g_hSessionKickCounts = new StringMap();
	g_hSQLKickCounts = new StringMap();
	g_hSQLKickExpires = new StringMap();
	g_hSQLInsertPending = new StringMap();
	g_hPassedKickEvents = new ArrayList(sizeof(PassedKickEvent));
	CallVoteAutoExecConfig(true, "callvote_kicklimit");
	if (g_Runtime.lateLoad)
		RequestReconcile();
}

void OnKickLimitSettingsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvarEnable)
		ClearSessionSnapshots();
	if (convar == g_cvarSQL || convar == g_cvarSQLConfig)
		InvalidateSQLState(true);
	if (g_cvarSQL.BoolValue)
		TryConnectSQL();
	RequestReconcile();
}

void CVKL_RefreshLibraryState()
{
	g_Runtime.DetectLibraries();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
	g_Runtime.Reset();
	g_Runtime.lateLoad = late;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	CVKL_RefreshLibraryState();
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, CALLVOTECORE_LIBRARY))
	{
		g_Runtime.SetLibraryAvailability(name, false);
		g_bCoreRemovedCleanup = true;
	}
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, CALLVOTECORE_LIBRARY))
	{
		g_Runtime.SetLibraryAvailability(name, true);
		g_bReconcilePending = true;
	}
}

public void OnConfigsExecuted()
{
	EnsureCallVoteDebugLogFolderForMode(g_cvarLogMode);
	OnConfigsExecuted_SQL();
	RequestReconcile();
}

public void OnMapStart()
{
	g_iMapGeneration++;
	ClearSessionSnapshots();
	RequestReconcile();
	if (g_cvarSQL != null && g_cvarSQL.BoolValue)
		TryConnectSQL();
}

public void OnMapEnd()
{
	g_iMapGeneration++;
	ClearSessionSnapshots();
}

public void OnPluginEnd()
{
	if (g_hRetryTimer != null)
		delete g_hRetryTimer;
	if (g_db != null)
		delete g_db;
	if (g_Log != null)
		delete g_Log;
}

public void OnClientPostAdminCheck(int client)
{
	InitializeClient(client);
}

public void OnClientDisconnect(int client)
{
	ResetClientState(client);
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!event.GetBool("disconnect", false))
		return;
	int client = GetClientOfUserId(event.GetInt("userid", 0));
	if (client > 0 && client <= MaxClients && !IsFakeClient(client))
		ResetClientState(client);
}

Action Command_KickCount(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t sm_cvkl_count <#userid|name>", "Tag", "Usage");
		return Plugin_Handled;
	}
	char arguments[256], arg[65], targetName[MAX_TARGET_LENGTH];
	GetCmdArgString(arguments, sizeof(arguments));
	BreakString(arguments, arg, sizeof(arg));
	int targets[MAXPLAYERS], targetCount;
	bool targetNameIsMl;
	int flags = COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_MULTI;
	targetCount = ProcessTargetString(arg, client, targets, MAXPLAYERS, flags, targetName, sizeof(targetName), targetNameIsMl);
	if (targetCount > 0)
	{
		for (int i = 0; i < targetCount; i++)
		{
			int target = targets[i], count;
			if (!TryGetKickCount(target, g_Players[target].AccountID, count))
			{
				CReplyToCommand(client, "%t %t", "Tag", IsKickCountLoadPending(target, g_Players[target].AccountID) ? "KickDataPending" : "KickDataUnavailable");
				continue;
			}
			if (client == target)
				CReplyToCommand(client, "%t %t", "Tag", "KickLimit", count, g_cvarKickLimit.IntValue);
			else
				CReplyToCommand(client, "%t %t", "Tag", "KickLimitTarget", targetName, count, g_cvarKickLimit.IntValue);
		}
	}
	else
		ReplyToTargetError(client, targetCount);
	return Plugin_Handled;
}

Action Command_KickShow(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}
	if (client == SERVER_INDEX)
	{
		CReplyToCommand(client, "%t %t", "Tag", "BlockUserConsole");
		return Plugin_Handled;
	}
	int found, pending, unavailable;
	for (int target = 1; target <= MaxClients; target++)
	{
		if (!IsClientInGame(target) || IsFakeClient(target) || g_Players[target].AccountID <= 0)
			continue;
		int count;
		if (!TryGetKickCount(target, g_Players[target].AccountID, count))
		{
			if (IsKickCountLoadPending(target, g_Players[target].AccountID))
				pending++;
			else
				unavailable++;
			continue;
		}
		if (count <= 0)
			continue;
		char steamId2[MAX_AUTHID_LENGTH], name[MAX_NAME_LENGTH];
		FormatAccountIDAsSteamID2(g_Players[target].AccountID, steamId2, sizeof(steamId2));
		GetClientName(target, name, sizeof(name));
		found++;
		CPrintToChat(client, "%t %t", "Tag", "KickShow", name, steamId2, count);
	}
	if (pending > 0)
		CPrintToChat(client, "%t %t", "Tag", "KickRecordsPending");
	if (unavailable > 0)
		CPrintToChat(client, "%t %t", "Tag", "KickRecordsUnavailable");
	if (!found && !pending && !unavailable)
		CPrintToChat(client, "%t %t", "Tag", "NoKickRecords");
	return Plugin_Handled;
}

public Action CallVote_PreStart(int sessionId, int client, int callerAccountId, TypeVotes voteType, int target, int targetAccountId, const char[] argument)
{
	if (!g_cvarEnable.BoolValue || !g_Runtime.hasCore || voteType != Kick)
		return Plugin_Continue;
	int count;
	if (!TryGetKickCount(client, callerAccountId, count))
	{
		CallVoteCore_SetPendingRestriction(VoteRestriction_Plugin);
		if (IsLiveIdentity(client, callerAccountId))
			CPrintToChat(client, "%t %t", "Tag", IsKickCountLoadPending(client, callerAccountId) ? "KickDataPending" : "KickDataUnavailable");
		return Plugin_Handled;
	}
	if (IsLiveIdentity(client, callerAccountId))
		CVKLLogMessage(false, "[CallVote_PreStart] Session:%d CallerAID:%d TargetAID:%d Kicks:%d/%d Arg:%s", sessionId, callerAccountId, targetAccountId, count, g_cvarKickLimit.IntValue, argument);
	SetSessionKickCountSnapshot(sessionId, count);
	if (g_cvarKickLimit.IntValue <= count)
	{
		CallVoteCore_SetPendingRestriction(VoteRestriction_Plugin);
		if (IsLiveIdentity(client, callerAccountId))
		{
			char buffer[128];
			Format(buffer, sizeof(buffer), "%t", "KickReached", count, g_cvarKickLimit.IntValue);
			CPrintToChat(client, "%t %s", "Tag", buffer);
			if (g_Log != null)
				g_Log.Normal("KickBlocked", "Blocked kick vote from AID %d to AID %d (%d/%d)", callerAccountId, targetAccountId, count, g_cvarKickLimit.IntValue);
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

bool TryGetKickCount(int client, int accountId, int &count)
{
	if (!g_cvarSQL.BoolValue)
	{
		if (!IsLiveIdentity(client, accountId))
			return false;
		count = GetLocalKickCount(accountId, CurrentTime());
		g_Players[client].Kick = count;
		g_Players[client].LoadState = KickCount_Ready;
		return true;
	}
	if (!CanUseKickLimitSQL())
		return false;
	if (!IsLiveIdentity(client, accountId))
		return false;
	if (IsSQLKickCountCacheFresh(accountId, CurrentTime()))
	{
		if (!GetSQLKickCount(accountId, CurrentTime(), count))
			return false;
		g_Players[client].Kick = count;
		g_Players[client].LoadState = KickCount_Ready;
		return true;
	}
	if (g_Players[client].LoadState == KickCount_Pending)
		return false;
	RequestKickCountLoad(client, accountId);
	return false;
}

bool IsKickCountLoadPending(int client, int accountId)
{
	return client > 0 && client <= MaxClients && g_Players[client].AccountID == accountId && g_Players[client].LoadState == KickCount_Pending;
}

public void CallVote_End(int sessionId, CallVoteEndReason result, int yesCount, int noCount, int potentialVotes)
{
	if (!g_cvarEnable.BoolValue || !g_Runtime.hasCore)
		return;
	int callerClient, callerAccountId, targetClient, targetAccountId;
	TypeVotes voteType;
	char argument[64];
	if (!CallVoteCore_GetSessionInfo(sessionId, callerClient, callerAccountId, voteType, targetClient, targetAccountId, argument, sizeof(argument)) || voteType != Kick)
		return;
	if (result != CallVoteEnd_Passed)
	{
		ClearSessionKickCountSnapshot(sessionId);
		return;
	}
	int previousCount;
	if (!TryGetSessionKickCountSnapshot(sessionId, previousCount))
	{
		ClearSessionKickCountSnapshot(sessionId);
		return;
	}
	int now = CurrentTime();
	RecordPassedKickVote(callerAccountId, targetAccountId, now, previousCount);
	int count = previousCount + 1;
	char callerSteamId2[MAX_AUTHID_LENGTH], targetSteamId2[MAX_AUTHID_LENGTH];
	FormatAccountIDAsSteamID2(callerAccountId, callerSteamId2, sizeof(callerSteamId2));
	FormatAccountIDAsSteamID2(targetAccountId, targetSteamId2, sizeof(targetSteamId2));
	CVKLLogMessage(false, "[CallVote_End] Passed session %d from %s to %s (%d/%d)", sessionId, callerSteamId2, targetSteamId2, count, g_cvarKickLimit.IntValue);
	if (g_Log != null)
		g_Log.Normal("Kick", "Kick vote passed from %s to %s (%d/%d)", callerSteamId2, targetSteamId2, count, g_cvarKickLimit.IntValue);
	if (IsLiveIdentity(callerClient, callerAccountId))
	{
		DataPack timerData = new DataPack();
		timerData.WriteCell(GetClientUserId(callerClient));
		timerData.WriteCell(callerAccountId);
		CreateTimer(1.0, Timer_KickLimit, timerData, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
	}
	ClearSessionKickCountSnapshot(sessionId);
}

public void CallVote_Blocked(int sessionId, int client, int callerAccountId, TypeVotes voteType, VoteRestrictionType restriction, int target, int targetAccountId, const char[] argument)
{
	if (voteType == Kick)
		ClearSessionKickCountSnapshot(sessionId);
}

public Action Timer_KickLimit(Handle timer, DataPack data)
{
	data.Reset();
	int client = GetClientOfUserId(data.ReadCell());
	int accountId = data.ReadCell();
	int count;
	if (g_cvarEnable.BoolValue && IsLiveIdentity(client, accountId) && TryGetKickCount(client, accountId, count))
		CPrintToChat(client, "%t %t", "Tag", "KickLimit", count, g_cvarKickLimit.IntValue);
	return Plugin_Stop;
}

// Existing log settings and folder helper are owned by callvote_core.
