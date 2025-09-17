#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <callvote_stock>
#include <steamidtools>

#undef REQUIRE_PLUGIN
#include <callvotemanager>
#define REQUIRE_PLUGIN

#undef REQUIRE_EXTENSIONS
#include <SteamWorks>
#include <system2>
#define REQUIRE_EXTENSIONS

#define PLUGIN_VERSION	 "2.0.0"

#define DEBUG			 1	  // General usage, allows activating other flags
#define DEBUG_SQL		 1	  // General SQL statements
#define DEBUG_MYSQL		 1	  // SQL statements used in MySQL and related functions
#define DEBUG_SQLITE	 1	  // SQL statements used in SQLite and related functions
#define DEBUG_STRINGMAP	 1	  // Memory cache management process

#define MAX_QUERY_LENGTH 2048

ConVar
	g_cvarEnable,
	g_cvarStringMapCache,
	g_cvarSQLiteCache,
	g_cvarSQLiteTTLMinutes,
	g_cvarSQLiteMaster,
	g_cvarSQLiteForceCleanupHour,
	g_cvarSQLiteCleanupThreshold,
	g_cvarMySQLMaster,
	g_cvarMySQLForceCleanupHour,
	g_cvarMySQLCleanupThreshold,
	g_cvarAnnounceJoin,
	g_cvarSteamIDToolsHTTP,
	g_cvarSteamIDToolsIP,
	g_cvarSteamIDToolsPort;

// Unified cache system using single StringMap with AccountID as key
StringMap g_smClientCache;		  // Unified cache for all ban information

// Menu reason input system
bool g_PendingReasonInputs[MAXPLAYERS + 1];
char g_PendingReasonData[MAXPLAYERS + 1][64];

// String Pool Manager for buffer optimization
#define STRING_POOL_SIZE 8
#define STRING_BUFFER_SIZE 512

char g_StringPool[STRING_POOL_SIZE][STRING_BUFFER_SIZE];
bool g_PoolInUse[STRING_POOL_SIZE];

Database
	g_hSQLiteDB,	// Local SQLite cache
	g_hMySQLDB;		// Main database

bool
	g_bLateLoad,
	g_bCallVoteManagerLoaded,
	g_bSteamWorksLoaded,
	g_bSystem2Loaded;

char g_sLogPath[PLATFORM_MAX_PATH];


/**
 * Client state structure for connected players only
 */
enum struct ClientState
{
	int accountId;			  // Player's AccountID
	bool isLoaded;			  // Whether the information is loaded from DB
	bool isChecking;		  // Whether it's currently checking in database
}

ClientState g_ClientStates[MAXPLAYERS + 1];

enum SteamIDToolsHTTP
{
	SteamIDTools_None		= 0,	// No API used
	SteamIDTools_SteamWorks = 1,	// Use SteamWorks API
	SteamIDTools_System2	= 2,	// Use System2 API
}

/**
 * Enumeration for different log categories
 */
enum CVBLogCategory
{
	CVBLog_Debug	 = 0,	 // General debug information
	CVBLog_SQL		 = 1,	 // Generic SQL operations
	CVBLog_MySQL	 = 2,	 // MySQL-specific operations
	CVBLog_SQLite	 = 3,	 // SQLite-specific operations
	CVBLog_StringMap = 4	 // StringMap cache operations
}

/**
 * Modern logging system using methodmap
 * Maintains the same macro-based optimization philosophy
 */
methodmap CVBLog
{
	/**
	 * Internal method to format and write log message
	 *
	 * @param category    Log category for prefix formatting
	 * @param message     Format string for the message
	 * @param args        Variable arguments for formatting
	 */
	public 	static void WriteLog(CVBLogCategory category, const char[] message, any...)
	{
		static char sFormat[1024];
		static char sPrefix[32];

		VFormat(sFormat, sizeof(sFormat), message, 3);

		switch (category)
		{
			case CVBLog_Debug: strcopy(sPrefix, sizeof(sPrefix), "[CVB][Debug]");
			case CVBLog_SQL: strcopy(sPrefix, sizeof(sPrefix), "[CVB][SQL]");
			case CVBLog_MySQL: strcopy(sPrefix, sizeof(sPrefix), "[CVB][MySQL]");
			case CVBLog_SQLite: strcopy(sPrefix, sizeof(sPrefix), "[CVB][SQLite]");
			case CVBLog_StringMap: strcopy(sPrefix, sizeof(sPrefix), "[CVB][StringMap]");
			default: strcopy(sPrefix, sizeof(sPrefix), "[CVB][Unknown]");
		}

		LogToFileEx(g_sLogPath, "%s %s", sPrefix, sFormat);
	}

/**
 * Logs debug information with timestamp
 * Only compiled when DEBUG macro is enabled
 *
 * @param message    Format string for the debug message
 * @param ...        Additional arguments for formatting
 */
#if DEBUG

	public 	static void Debug(const char[] message, any...)
	{
		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		CVBLog.WriteLog(CVBLog_Debug, sFormat);
	}
#else

public 	static void Debug(const char[] message, any...) {}
#endif

/**
 * Logs SQL-related information
 * Only compiled when DEBUG_SQL macro is enabled
 *
 * @param message    Format string for the SQL message
 * @param ...        Additional arguments for formatting
 */
#if DEBUG && DEBUG_SQL

	public 	static void SQL(const char[] message, any...)
	{
		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		CVBLog.WriteLog(CVBLog_SQL, sFormat);
	}
#else

public 	static void SQL(const char[] message, any...) {}
#endif

/**
 * Logs MySQL-specific information
 * Only compiled when DEBUG_MYSQL macro is enabled
 *
 * @param message    Format string for the MySQL message
 * @param ...        Additional arguments for formatting
 */
#if DEBUG && DEBUG_MYSQL

	public 	static void MySQL(const char[] message, any...)
	{
		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		CVBLog.WriteLog(CVBLog_MySQL, sFormat);
	}
#else

public 	static void MySQL(const char[] message, any...) {}
#endif

/**
 * Logs SQLite-specific information
 * Only compiled when DEBUG_SQLITE macro is enabled
 *
 * @param message    Format string for the SQLite message
 * @param ...        Additional arguments for formatting
 */
#if DEBUG && DEBUG_SQLITE

	public 	static void SQLite(const char[] message, any...)
	{
		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		CVBLog.WriteLog(CVBLog_SQLite, sFormat);
	}
#else

public 	static void SQLite(const char[] message, any...) {}
#endif

/**
 * Logs StringMap cache-related information
 * Only compiled when DEBUG_STRINGMAP macro is enabled
 *
 * @param message    Format string for the StringMap message
 * @param ...        Additional arguments for formatting
 */
#if DEBUG && DEBUG_STRINGMAP

	public 	static void StringMap(const char[] message, any...)
	{
		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		CVBLog.WriteLog(CVBLog_StringMap, sFormat);
	}
#else

public 	static void StringMap(const char[] message, any...) {}
#endif
}

/**
 * String Pool Manager for buffer optimization
 * Reduces memory allocations by reusing pre-allocated buffers
 */
methodmap StringPool
{
	/**
	 * Gets an available buffer from the pool
	 *
	 * @param buffer     Buffer to store the result
	 * @param maxlen     Maximum length of the buffer
	 * @return           True if buffer was assigned, false if pool is full
	 */
	public static bool GetBuffer(char[] buffer, int maxlen)
	{
		for (int i = 0; i < STRING_POOL_SIZE; i++)
		{
			if (!g_PoolInUse[i])
			{
				g_PoolInUse[i] = true;
				g_StringPool[i][0] = '\0';  // Clear buffer
				strcopy(buffer, maxlen, g_StringPool[i]);
				return true;
			}
		}
		
		CVBLog.Debug("String pool exhausted! All %d buffers in use", STRING_POOL_SIZE);
		return false;  // Pool is full
	}
	
	/**
	 * Returns a buffer to the pool for reuse by index
	 *
	 * @param poolIndex    The index of the buffer in the pool
	 */
	public static void ReturnBufferByIndex(int poolIndex)
	{
		if (poolIndex >= 0 && poolIndex < STRING_POOL_SIZE)
		{
			g_PoolInUse[poolIndex] = false;
			g_StringPool[poolIndex][0] = '\0';  // Clear for next use
		}
	}
	
	/**
	 * Gets a pool buffer index for direct access (advanced usage)
	 *
	 * @return    Pool index, or -1 if pool is full
	 */
	public static int GetPoolIndex()
	{
		for (int i = 0; i < STRING_POOL_SIZE; i++)
		{
			if (!g_PoolInUse[i])
			{
				g_PoolInUse[i] = true;
				g_StringPool[i][0] = '\0';  // Clear buffer
				return i;
			}
		}
		
		CVBLog.Debug("String pool exhausted! All %d buffers in use", STRING_POOL_SIZE);
		return -1;  // Pool is full
	}
	
	/**
	 * Gets direct access to a pool buffer (advanced usage)
	 *
	 * @param poolIndex    The pool index
	 * @param buffer       Buffer to copy the pool buffer to
	 * @param maxlen       Maximum length of the buffer
	 */
	public static void GetPoolBuffer(int poolIndex, char[] buffer, int maxlen)
	{
		if (poolIndex >= 0 && poolIndex < STRING_POOL_SIZE)
		{
			strcopy(buffer, maxlen, g_StringPool[poolIndex]);
		}
	}
	
	/**
	 * Initializes the string pool (called on plugin start)
	 */
	public static void Initialize()
	{
		for (int i = 0; i < STRING_POOL_SIZE; i++)
		{
			g_PoolInUse[i] = false;
			g_StringPool[i][0] = '\0';
		}
		
		CVBLog.Debug("String pool initialized with %d buffers of %d bytes each", STRING_POOL_SIZE, STRING_BUFFER_SIZE);
	}
	
	/**
	 * Gets pool statistics for debugging
	 *
	 * @param used      Number of buffers currently in use
	 * @param total     Total number of buffers in pool
	 */
	public static void GetStats(int &used, int &total)
	{
		used = 0;
		total = STRING_POOL_SIZE;
		
		for (int i = 0; i < STRING_POOL_SIZE; i++)
		{
			if (g_PoolInUse[i])
				used++;
		}
	}
}

/*****************************************************************
			L I B R A R Y   I N C L U D E S
*****************************************************************/

#include "callvote/cvb_api.sp"
#include "callvote/cvb_reason_config.sp"
#include "callvote/cvb_database.sp"
#include "callvote/cvb_cache.sp"
#include "callvote/cvb_notification.sp"
#include "callvote/cvb_commands.sp"
#include "callvote/cvb_menus.sp"

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/
public Plugin myinfo =
{
	name		= "Call Vote Bans",
	author		= "lechuga",
	description = "Advanced voting blocking system with multi-level cache",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/lechuga16/callvote_manager"

}

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max)
{
	RegisterForwards();
	RegisterNatives();
	RegPluginLibrary("callvote_bans");

	g_bLateLoad = bLate;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bSteamWorksLoaded		 = LibraryExists("SteamWorks");
	g_bSystem2Loaded		 = LibraryExists("system2");
	g_bCallVoteManagerLoaded = LibraryExists("callvotemanager");
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "SteamWorks"))
		g_bSteamWorksLoaded = false;
	else if (StrEqual(sName, "system2"))
		g_bSystem2Loaded = false;
	if (StrEqual(sName, "callvotemanager"))
		g_bCallVoteManagerLoaded = false;
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "SteamWorks"))
		g_bSteamWorksLoaded = true;
	else if (StrEqual(sName, "system2"))
		g_bSystem2Loaded = true;
	if (StrEqual(sName, "callvotemanager"))
		g_bCallVoteManagerLoaded = true;
}

public void OnPluginStart()
{
	LoadTranslations("callvote_bans.phrases");
	LoadTranslations("common.phrases");
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/callvote.log");

	// Initialize optimization systems
	StringPool.Initialize();

	if (!InitializeMessageCodeSystem())
		LogError("Failed to initialize ban reasons system - using fallback");

	CreateConVar("sm_cvb_version", PLUGIN_VERSION, "Plugin version", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	g_cvarEnable				 = CreateConVar("sm_cvb_enable", "1", "Enable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarStringMapCache		 = CreateConVar("sm_cvb_stringmap_cache", "1", "StringMap cache for non-banned players", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarSQLiteCache			 = CreateConVar("sm_cvb_sqlite_cache", "1", "SQLite cache for bans (only one record per user)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarSQLiteTTLMinutes		 = CreateConVar("sm_cvb_sqlite_ttl_minutes", "10080", "SQLite cache TTL in minutes (default 1 week)", FCVAR_NOTIFY, true, 60.0, true, 43200.0);
	g_cvarSQLiteMaster			 = CreateConVar("sm_cvb_sqlite_master", "0", "SQLite maintenance master (0=slave, 1=master)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarSQLiteForceCleanupHour = CreateConVar("sm_cvb_sqlite_force_cleanup_hour", "-1", "Daily forced cleanup hour (0-23, -1=disabled)", FCVAR_NOTIFY, true, -1.0, true, 23.0);
	g_cvarSQLiteCleanupThreshold = CreateConVar("sm_cvb_sqlite_cleanup_threshold", "-1", "Force cleanup at this record count (-1=disabled)", FCVAR_NOTIFY, true, -1.0, true, 100000.0);
	g_cvarMySQLMaster			 = CreateConVar("sm_cvb_mysql_master", "0", "MySQL maintenance master (0=slave, 1=master)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarMySQLForceCleanupHour	 = CreateConVar("sm_cvb_mysql_force_cleanup_hour", "-1", "MySQL daily forced cleanup hour (0-23, -1=disabled)", FCVAR_NOTIFY, true, -1.0, true, 23.0);
	g_cvarMySQLCleanupThreshold	 = CreateConVar("sm_cvb_mysql_cleanup_threshold", "-1", "MySQL force cleanup at this record count (-1=disabled)", FCVAR_NOTIFY, true, -1.0, true, 1000000.0);
	g_cvarAnnounceJoin			 = CreateConVar("sm_cvb_announce_join", "1", "0=off, 1=admins, 2=everyone", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_cvarSteamIDToolsHTTP		 = CreateConVar("sm_cvb_steamidtools_http", "0", "Use SteamIDTools HTTP API (0=No API, 1=SteamWorks, 2=System2)", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_cvarSteamIDToolsIP		 = CreateConVar("sm_cvb_steamidtools_ip", "http://localhost", "IP address for SteamIDTools HTTP API (includes http protocol)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarSteamIDToolsPort		 = CreateConVar("sm_cvb_steamidtools_port", "80", "Port for SteamIDTools HTTP API", FCVAR_NOTIFY, true, 0.0, true, 65535.0);

	// AutoExecConfig(true, "callvote_bans");

	InitCache();
	RegisterCommands();
	
	AddCommandListener(CommandListener_Say, "say");
	AddCommandListener(CommandListener_Say, "say_team");

	if (!g_bLateLoad)
		return;

	g_bSteamWorksLoaded		 = LibraryExists("SteamWorks");
	g_bSystem2Loaded		 = LibraryExists("system2");
	g_bCallVoteManagerLoaded = LibraryExists("callvotemanager");

	OnAllPluginsLoaded();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		OnClientCacheConnect(i);
	}

	CreateTimer(5.0, Timer_CheckMasterCleanup, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnConfigsExecuted()
{
	if (!g_cvarEnable.BoolValue)
		return;

	InitDatabase();
}

public void OnPluginEnd()
{
	CleanupBanReasons();

	CloseDatabase();
	CloseCache();
	CloseForwards();
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (!g_cvarEnable.BoolValue || !g_bCallVoteManagerLoaded || !IsValidClient(client))
		return;

	PlayerBanInfo banInfo = new PlayerBanInfo(GetSteamAccountID(client));

	if (IsPlayerBanned(client, banInfo))
	{
		CVBLog.Debug("Player %N is banned (AccountID: %d)", client, banInfo.AccountId);
		delete banInfo;
		AnnouncerJoin(client);
		return;
	}
	delete banInfo;
}

void AnnouncerJoin(int client)
{
	if (!g_cvarEnable.BoolValue || !g_bCallVoteManagerLoaded || g_cvarAnnounceJoin.IntValue == 0 || !IsValidClient(client))
		return;

	if (!IsClientBannedWithInfo(client))
		return;

	switch (g_cvarAnnounceJoin.IntValue)
	{
		case 1:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsValidClient(i))
					continue;

				AdminId adminId = GetUserAdmin(i);
				if (adminId == INVALID_ADMIN_ID)
					continue;

				CPrintToChat(i, "%t %t", "Tag", "PlayerJoinedWithRestrictions", client);
			}
		}
		case 2:
		{
			CPrintToChatAll("%t %t", "Tag", "PlayerJoinedWithRestrictions", client);
		}
	}

	CVBLog.Debug("Anunciado jugador con restricciones: %N", client);
}

public void OnClientDisconnect(int client)
{
	if (!g_cvarEnable.BoolValue || !g_bCallVoteManagerLoaded)
		return;

	g_PendingReasonInputs[client] = false;
	g_PendingReasonData[client][0] = '\0';
	
	OnClientCacheDisconnect(client);
}

/*****************************************************************
			M A S T E R   C L E A N U P   S Y S T E M
*****************************************************************/

/**
 * Timer callback para verificar limpieza maestro al iniciar plugin
 */
public Action Timer_CheckMasterCleanup(Handle timer)
{
	if (g_cvarSQLiteMaster.BoolValue && g_hSQLiteDB != null)
	{
		CVBLog.Debug("Master node checking SQLite cleanup requirements...");

		CheckThresholdCleanup();
		CheckScheduledCleanup();
	}
	
	if (g_cvarMySQLMaster.BoolValue && g_hMySQLDB != null)
	{
		CVBLog.Debug("Master node checking MySQL cleanup requirements...");
		
		CheckMySQLThresholdCleanup();
		CheckMySQLScheduledCleanup();
	}

	return Plugin_Stop;
}

/**
 * Verificar si necesita limpieza por cantidad de registros
 */
void CheckThresholdCleanup()
{
	int threshold = g_cvarSQLiteCleanupThreshold.IntValue;
	if (threshold <= 0)
	{
		CVBLog.Debug("Threshold cleanup disabled (threshold: %d)", threshold);
		return;
	}

	char query[] = "SELECT COUNT(*) FROM callvote_bans_cache";
	SQL_TQuery(g_hSQLiteDB, ThresholdCallback, query, threshold);
}

/**
 * Callback para verificación de threshold
 */
void ThresholdCallback(Database db, DBResultSet results, const char[] error, int threshold)
{
	if (results == null)
	{
		CVBLog.Debug("Error checking cache size: %s", error);
		return;
	}

	if (results.FetchRow())
	{
		int count = results.FetchInt(0);
		CVBLog.Debug("Current cache size: %d records (threshold: %d)", count, threshold);

		if (count >= threshold)
		{
			CVBLog.Debug("Threshold exceeded! Triggering master cleanup...");
			CleanupExpiredSQLiteCache();
		}
	}
}

/**
 * Verificar si necesita limpieza por hora programada
 */
void CheckScheduledCleanup()
{
	int cleanupHour = g_cvarSQLiteForceCleanupHour.IntValue;
	if (cleanupHour < 0 || cleanupHour > 23)
	{
		CVBLog.Debug("Scheduled cleanup disabled (hour: %d)", cleanupHour);
		return;
	}

	char timeStr[32];
	FormatTime(timeStr, sizeof(timeStr), "%H", GetTime());
	int currentHour = StringToInt(timeStr);

	CVBLog.Debug("Current hour: %d, cleanup hour: %d", currentHour, cleanupHour);

	if (currentHour == cleanupHour)
	{
		CVBLog.Debug("Scheduled cleanup hour reached! Triggering master cleanup...");
		CleanupExpiredSQLiteCache();
	}
}

/**
 * Verificar si necesita limpieza MySQL por cantidad de registros
 */
void CheckMySQLThresholdCleanup()
{
	int threshold = g_cvarMySQLCleanupThreshold.IntValue;
	if (threshold <= 0)
	{
		CVBLog.Debug("MySQL threshold cleanup disabled (threshold: %d)", threshold);
		return;
	}
	
	char query[] = "SELECT COUNT(*) FROM callvote_bans WHERE is_active = 1";
	SQL_TQuery(g_hMySQLDB, MySQLThresholdCallback, query, threshold);
}

/**
 * Callback para verificación de threshold MySQL
 */
void MySQLThresholdCallback(Database db, DBResultSet results, const char[] error, int threshold)
{
	if (results == null)
	{
		CVBLog.Debug("Error checking MySQL table size: %s", error);
		return;
	}
	
	if (results.FetchRow())
	{
		int count = results.FetchInt(0);
		CVBLog.Debug("Current MySQL active bans: %d records (threshold: %d)", count, threshold);
		
		if (count >= threshold)
		{
			CVBLog.Debug("MySQL threshold exceeded! Triggering master cleanup...");
			CleanupExpiredMySQLBans();
		}
	}
}

/**
 * Verificar si necesita limpieza MySQL por hora programada
 */
void CheckMySQLScheduledCleanup()
{
	int cleanupHour = g_cvarMySQLForceCleanupHour.IntValue;
	if (cleanupHour < 0 || cleanupHour > 23)
	{
		CVBLog.Debug("MySQL scheduled cleanup disabled (hour: %d)", cleanupHour);
		return;
	}
	
	char timeStr[32];
	FormatTime(timeStr, sizeof(timeStr), "%H", GetTime());
	int currentHour = StringToInt(timeStr);
	
	CVBLog.Debug("MySQL cleanup - Current hour: %d, cleanup hour: %d", currentHour, cleanupHour);
	
	if (currentHour == cleanupHour)
	{
		CVBLog.Debug("MySQL scheduled cleanup hour reached! Triggering master cleanup...");
		CleanupExpiredMySQLBans();
	}
}

/**
 * Limpiar bans expirados en MySQL
 */
void CleanupExpiredMySQLBans()
{
	if (g_hMySQLDB == null)
	{
		CVBLog.Debug("MySQL database not connected, skipping cleanup");
		return;
	}
	
	char query[512];
	Format(query, sizeof(query),
		"UPDATE callvote_bans SET is_active = 0 WHERE is_active = 1 AND expires_timestamp > 0 AND expires_timestamp <= %d",
		GetTime());
	
	SQL_TQuery(g_hMySQLDB, MySQLCleanupCallback, query);
}

/**
 * Callback para limpieza de MySQL
 */
void MySQLCleanupCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		CVBLog.Debug("Error in MySQL cleanup: %s", error);
		return;
	}
	
	int affectedRows = SQL_GetAffectedRows(db);
	if (affectedRows > 0)
		CVBLog.Debug("MySQL cleanup completed: %d expired bans deactivated", affectedRows);
	else
		CVBLog.Debug("MySQL cleanup completed: no expired bans found");
}

/*****************************************************************
			C A L L V O T E   M A N A G E R   F O R W A R D S
*****************************************************************/

/**
 * Forward del CallVoteManager - Intercepta intentos de voto antes de validación
 */
public Action CallVote_PreStart(int client, TypeVotes voteType, int target)
{
	if (!g_cvarEnable.BoolValue)
		return Plugin_Continue;

	if (!IsValidClient(client))
		return Plugin_Continue;

	PlayerBanInfo banInfo = new PlayerBanInfo(GetSteamAccountID(client));
	CVBLog.Debug("CallVote_PreStart: %N (AccountID: %d) attempting %d vote", client, banInfo.AccountId, voteType);

	if (IsPlayerBanned(client, banInfo))
	{
		ShowVoteBlockedMessage(client, voteType);

		Call_StartForward(g_gfBlocked);
		Call_PushCell(client);
		Call_PushCell(view_as<int>(voteType));
		Call_PushCell(target);
		Call_PushCell(banInfo.BanType);
		Call_Finish();

		CVBLog.Debug("Voto BLOQUEADO para %N (AccountID: %d, tipo: %d, banType: %d)", client, banInfo.AccountId, voteType, banInfo.BanType);

		delete banInfo;
		return Plugin_Handled;
	}

	CVBLog.Debug("Voto PERMITIDO para %N (AccountID: %d, tipo: %d)", client, banInfo.AccountId, voteType);
	delete banInfo;
	return Plugin_Continue;
}

/**
 * Forward del CallVoteManager - Se llama cuando el voto inicia exitosamente
 */
public void CallVote_Start(int client, TypeVotes voteType, int target)
{
	if (!g_cvarEnable.BoolValue)
		return;

	if (!IsValidClient(client))
		return;

	CVBLog.Debug("Voto permitido para %N (tipo: %d)", client, voteType);
}

/**
 * Forward del CallVoteManager - Se llama antes de ejecutar el voto (después de validación)
 * Este forward es opcional - permite hacer modificaciones de último momento
 */
public Action CallVote_PreExecute(int client, TypeVotes voteType, int target)
{
	if (!g_cvarEnable.BoolValue)
		return Plugin_Continue;

	if (!IsValidClient(client))
		return Plugin_Continue;

	CVBLog.Debug("CallVote_PreExecute: %N ejecutando voto tipo %d", client, voteType);
	
	return Plugin_Continue;
}

/**
 * Forward del CallVoteManager - Se llama cuando un voto es bloqueado por restricciones
 * Este forward es informativo - nos permite reaccionar a bloqueos del manager principal
 */
public void CallVote_Blocked(int client, TypeVotes voteType, VoteRestrictionType restriction, int target)
{
	if (!g_cvarEnable.BoolValue)
		return;

	if (!IsValidClient(client))
		return;

	char restrictionName[64];
	GetRestrictionTypeName(restriction, restrictionName, sizeof(restrictionName));
	
	CVBLog.Debug("CallVote_Blocked: %N bloqueado por manager - tipo: %d, restricción: %d", client, voteType, restriction);
}


/*****************************************************************
			H E L P E R   F U N C T I O N S
*****************************************************************/

/**
 * Función helper para obtener nombre legible de restricción
 */
void GetRestrictionTypeName(VoteRestrictionType restriction, char[] buffer, int maxlen)
{
	switch (restriction)
	{
		case VoteRestriction_None: strcopy(buffer, maxlen, "None");
		case VoteRestriction_ConVar: strcopy(buffer, maxlen, "ConVar");
		case VoteRestriction_GameMode: strcopy(buffer, maxlen, "GameMode");
		case VoteRestriction_SameState: strcopy(buffer, maxlen, "SameState");
		case VoteRestriction_Immunity: strcopy(buffer, maxlen, "Immunity");
		case VoteRestriction_Team: strcopy(buffer, maxlen, "Team");
		case VoteRestriction_Target: strcopy(buffer, maxlen, "Target");
		default: Format(buffer, maxlen, "Unknown_%d", restriction);
	}
}

/**
 * Command listener for handling custom ban reason input through chat
 */
public Action CommandListener_Say(int client, const char[] command, int argc)
{
	if (!IsValidClient(client) || !g_PendingReasonInputs[client])
		return Plugin_Continue;
		
	char message[256];
	GetCmdArgString(message, sizeof(message));

	if (message[0] == '"')
	{
		strcopy(message, sizeof(message), message[1]);
		if (message[strlen(message) - 1] == '"')
			message[strlen(message) - 1] = '\0';
	}
	
	TrimString(message);
	
	if (strlen(message) == 0 || StrEqual(message, "cancel", false) || StrEqual(message, "!cancel", false))
	{
		g_PendingReasonInputs[client] = false;
		g_PendingReasonData[client][0] = '\0';
		CPrintToChat(client, "%t %t", "Tag", "BanReasonInputCancelled");
		ShowMainBanPanel(client);
		return Plugin_Handled;
	}
	
	char sData[64];
	strcopy(sData, sizeof(sData), g_PendingReasonData[client]);
	
	char sParts[3][16];
	if (ExplodeString(sData, ":", sParts, sizeof(sParts), sizeof(sParts[])) == 3)
	{
		int userId = StringToInt(sParts[0]);
		int banType = StringToInt(sParts[1]);
		int durationMinutes = StringToInt(sParts[2]);
		int target = GetClientOfUserId(userId);
		
		if (target > 0 && IsValidClient(target))
		{
			char processedReason[256];
			CVB_GetBanReason(message, processedReason, sizeof(processedReason));
			ProcessBan(client, target, banType, durationMinutes, processedReason);
		}
		else
		{
			CPrintToChat(client, "%t %t", "Tag", "MenuPlayerDisconnected");
		}
	}
	
	g_PendingReasonInputs[client] = false;
	g_PendingReasonData[client][0] = '\0';
	
	return Plugin_Handled;
}