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

/*****************************************************************
			G L O B A L   D E F I N E S
*****************************************************************/

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

StringMap
	g_hCacheStringMap,	  // Cache for non-banned players
	g_hPlayerBans;		  // Cache for active bans in memory

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
 * Structure for player ban information
 */
enum struct PlayerBanInfo
{
	int	 accountId;			  // Player's AccountID
	int	 banType;			  // Ban type (bit mask)
	int	 createdTimestamp;	  // Creation timestamp
	int	 durationMinutes;	  // Duration in minutes (0 = permanent)
	int	 expiresTimestamp;	  // Expiration timestamp
	bool isLoaded;			  // Whether the information is loaded
	bool isChecking;		  // Whether it's checking in database
}

PlayerBanInfo g_PlayerBans[MAXPLAYERS + 1];

enum SteamIDToolsHTTP
{
	SteamIDTools_None		= 0,	// No API used
	SteamIDTools_SteamWorks = 1,	// Use SteamWorks API
	SteamIDTools_System2	= 2,	// Use System2 API
}

/*****************************************************************
			L I B R A R Y   I N C L U D E S
*****************************************************************/

#include "callvote/cvb_logger.sp"
#include "callvote/cvb_api.sp"
#include "callvote/cvb_reason_config.sp"
#include "callvote/cvb_database.sp"
#include "callvote/cvb_cache.sp"
#include "callvote/cvb_commands.sp"
#include "callvote/cvb_menus.sp"
#include "callvote/cvb_threading.sp"

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

public APLRes
	AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max)
{
	InitForwards();
	RegisterNatives();

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

	if (!InitializeMessageCodeSystem())
	{
		LogError("Failed to initialize ban reasons system - using fallback");
	}

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

	AutoExecConfig(true, "callvote_bans");

	InitCache();
	InitThreadingQueue();
	RegisterCommands();

	if (!g_bLateLoad)
	{
		return;
	}

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

	// Verificar limpieza maestro después de la inicialización
	CreateTimer(5.0, Timer_CheckMasterCleanup, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnConfigsExecuted()
{
	if (!g_cvarEnable.BoolValue)
	{
		return;
	}

	InitDatabase();
}

public void OnPluginEnd()
{
	CleanupBanReasons();

	CloseDatabase();
	CloseCache();
	CloseThreading();
	CloseForwards();
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (!g_cvarEnable.BoolValue || !g_bCallVoteManagerLoaded || !IsValidClient(client))
	{
		return;
	}

	OnClientCacheConnect(client);
	OnClientConnectForwards(client);
}

public void OnClientDisconnect(int client)
{
	if (!g_cvarEnable.BoolValue || !g_bCallVoteManagerLoaded)
	{
		return;
	}

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
	// Verificar limpieza SQLite si este nodo es maestro SQLite
	if (g_cvarSQLiteMaster.BoolValue && g_hSQLiteDB != null)
	{
		CVBLog.Debug("Master node checking SQLite cleanup requirements...");
		
		// Verificar limpieza por threshold
		CheckThresholdCleanup();
		
		// Verificar limpieza por hora programada
		CheckScheduledCleanup();
	}
	
	// Verificar limpieza MySQL si este nodo es maestro MySQL
	if (g_cvarMySQLMaster.BoolValue && g_hMySQLDB != null)
	{
		CVBLog.Debug("Master node checking MySQL cleanup requirements...");
		
		// Verificar limpieza MySQL por threshold
		CheckMySQLThresholdCleanup();
		
		// Verificar limpieza MySQL por hora programada
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
	{
		CVBLog.Debug("MySQL cleanup completed: %d expired bans deactivated", affectedRows);
	}
	else
	{
		CVBLog.Debug("MySQL cleanup completed: no expired bans found");
	}
}