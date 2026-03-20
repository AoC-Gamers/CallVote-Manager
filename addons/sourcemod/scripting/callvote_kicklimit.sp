#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <dbi>
#include <steamidtools_helpers>

#undef REQUIRE_PLUGIN
#include <callvotemanager>
#define REQUIRE_PLUGIN

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define PLUGIN_VERSION "1.5.0"
#define CVKL_LOG_TAG "CVKL"
#define CVKL_LOG_FILE "callvote_kicklimit.log"

enum KickCountLoadState
{
	KickCount_Uninitialized = 0,
	KickCount_Pending,
	KickCount_Ready
}

/**
 * Player profile.
 *
 */
enum struct PlayerInfo
{
	int AccountID;						// Canonical Steam AccountID
	int Kick;							// kick voting call amount
	KickCountLoadState LoadState;		// Loading state for the current kick count
}

PlayerInfo g_Players[MAXPLAYERS + 1];

ConVar
	g_cvarDebug,
	g_cvarEnable,
	g_cvarLogMode,
	g_cvarDebugMask,
	g_cvarKickLimit,
	g_cvarSQL;

char
	g_sTable[] = "callvote_kicklimit";

bool
	g_bSQLConnected,
	g_bSQLTableExists,
	g_bCallVoteManager,
	g_bLateLoad = false;

Database
	g_db;

StringMap
	g_hLocalKickCounts;

CallVoteLogger g_Log = null;

enum SQLDriver
{
	SQL_MySQL = 0,
	SQL_SQLite
}

SQLDriver
	g_SQLDriver;

/*****************************************************************
			S Q L   H E L P E R S
*****************************************************************/

public void OnPluginStart_SQL()
{
	g_cvarSQL = CreateConVar("sm_cvkl_sql", "0", "Enables kick counter registration to the database, if disabled it uses local memory.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
}

void OnConfigsExecuted_SQL()
{
	if (!g_cvarSQL.BoolValue)
		return;

	if (g_db != null)
		return;

	ConnectDB("callvote", g_sTable);
}

void EnsureSQLiteSchema()
{
	if (g_SQLDriver != SQL_SQLite || g_db == null)
		return;

	char sQuery[512];
	g_db.Format(sQuery, sizeof(sQuery),
		"CREATE TABLE IF NOT EXISTS `%s` ( \
		`id` INTEGER PRIMARY KEY AUTOINCREMENT, \
		`caller_account_id` INTEGER NOT NULL DEFAULT 0, \
		`created` INTEGER NOT NULL DEFAULT 0, \
		`target_account_id` INTEGER NOT NULL DEFAULT 0 \
		)",
		g_sTable);

	if (!SQL_FastQuery(g_db, sQuery))
	{
		logErrorSQL(g_db, sQuery, "EnsureSQLiteSchema");
		return;
	}

	g_db.Format(sQuery, sizeof(sQuery),
		"CREATE INDEX IF NOT EXISTS `idx_callvote_kicklimit_caller_created` ON `%s` (`caller_account_id`, `created`)",
		g_sTable);

	if (!SQL_FastQuery(g_db, sQuery))
		logErrorSQL(g_db, sQuery, "EnsureSQLiteSchema");
}

bool CanUseKickLimitSQL()
{
	return (
		g_cvarSQL != null
		&& g_cvarSQL.BoolValue
		&& g_bSQLConnected
		&& g_bSQLTableExists
		&& g_db != null
	);
}

void sqlinsert(int iSessionId, int iClientAccountId, int iTargetAccountId)
{
	if (!CanUseKickLimitSQL())
		return;

	char sQuery[600];
	char sCallerSteamID64[STEAMID64_EXACT_LENGTH + 1];
	char sTargetSteamID64[STEAMID64_EXACT_LENGTH + 1];
	sCallerSteamID64[0] = '\0';
	sTargetSteamID64[0] = '\0';

	switch (g_SQLDriver)
	{
		case SQL_MySQL:
		{
			if (!CallVoteManager_GetSessionSteamID64Info(iSessionId, sCallerSteamID64, sizeof(sCallerSteamID64), sTargetSteamID64, sizeof(sTargetSteamID64)))
			{
				log(false, "[sqlinsert] Failed to resolve frozen SteamID64 values for session %d", iSessionId);
				return;
			}

			if (sCallerSteamID64[0] == '\0' || sTargetSteamID64[0] == '\0')
			{
				log(false, "[sqlinsert] Missing frozen SteamID64 values for session %d", iSessionId);
				return;
			}

			g_db.Format(sQuery, sizeof(sQuery),
				"INSERT INTO `%s` (`caller_account_id`, `caller_steamid64`, `created`, `target_account_id`, `target_steamid64`) VALUES (%d, '%s', UNIX_TIMESTAMP(), %d, '%s')",
				g_sTable, iClientAccountId, sCallerSteamID64, iTargetAccountId, sTargetSteamID64);
		}
		case SQL_SQLite:
		{
			g_db.Format(sQuery, sizeof(sQuery),
				"INSERT INTO `%s` (`caller_account_id`, `created`, `target_account_id`) VALUES (%d, strftime('%%s', 'now'), %d)",
				g_sTable, iClientAccountId, iTargetAccountId);
		}
		default:
		{
			log(false, "[sqlinsert] Unknown SQL driver.");
			return;
		}
	}

	log(true, "[sqlinsert] Driver: %s | Query: %s", g_SQLDriver == SQL_MySQL ? "MySQL" : "SQLite", sQuery);
	DataPack dp = new DataPack();
	dp.WriteString(sQuery);
	g_db.Query(CallBack_SQLInsert, sQuery, dp);
}

public void CallBack_SQLInsert(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack dp = view_as<DataPack>(data);

	if (results == null)
	{
		char sQuery[600];

		dp.Reset();
		dp.ReadString(sQuery, sizeof(sQuery));

		log(false, "[CallBack_SQLInsert] SQL failed: %s", error);
		log(false, "[CallBack_SQLInsert] Query dump: %s", sQuery);
		delete dp;
		return;
	}

	delete dp;
}

void GetCountKick(int iClient, int iAccountId)
{
	if (!CanUseKickLimitSQL())
		return;

	char sQuery[255];
	switch (g_SQLDriver)
	{
		case SQL_MySQL:
		{
			g_db.Format(sQuery, sizeof(sQuery),
				"SELECT COUNT(*) FROM `%s` WHERE created >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 1 DAY)) AND caller_account_id = %d",
				g_sTable, iAccountId);
		}
		case SQL_SQLite:
		{
			g_db.Format(sQuery, sizeof(sQuery),
				"SELECT COUNT(*) FROM `%s` WHERE created >= strftime('%%s', 'now', '-1 day') AND caller_account_id = %d",
				g_sTable, iAccountId);
		}
		default:
		{
			log(false, "[GetCountKick] Unknown SQL driver.");
			return;
		}
	}

	log(true, "[GetCountKick] Driver: %s | Query: %s", g_SQLDriver == SQL_MySQL ? "MySQL" : "SQLite", sQuery);
	DataPack dp = new DataPack();
	dp.WriteCell(GetClientUserId(iClient));
	dp.WriteCell(iAccountId);
	g_db.Query(CallBack_GetCountKick, sQuery, dp);
}

public void CallBack_GetCountKick(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack dp = view_as<DataPack>(data);
	dp.Reset();
	int iUserId = dp.ReadCell();
	int iAccountId = dp.ReadCell();
	delete dp;

	if (results == null)
	{
		log(false, "[CallBack_GetCountKick] Error: %s", error);

		int iClientOnError = GetClientOfUserId(iUserId);
		if (iClientOnError > 0 && g_Players[iClientOnError].AccountID == iAccountId)
		{
			g_Players[iClientOnError].LoadState = KickCount_Uninitialized;
		}

		return;
	}

	int iClient = GetClientOfUserId(iUserId);
	if (iClient == SERVER_INDEX)
		return;

	int iKick = 0;

	if (results.FetchRow())
	{
		iKick = results.FetchInt(0);
	}

	log(true, "[CallBack_GetCountKick] Client: %N | AccountID: %d | Kicks: %d", iClient, iAccountId, iKick);
	UpdateConnectedClientKickCount(iAccountId, iKick);
}

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/

public Plugin myinfo =
{
	name		= "Call Vote Kick Limit",
	author		= "lechuga",
	description = "Limits the amount of callvote kick",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/lechuga16/callvote_manager"
}

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max)
{
	g_bLateLoad = bLate;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bCallVoteManager = LibraryExists(CALLVOTEMANAGER_LIBRARY);
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, CALLVOTEMANAGER_LIBRARY))
		g_bCallVoteManager = false;
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, CALLVOTEMANAGER_LIBRARY))
		g_bCallVoteManager = true;
}

public void OnPluginStart()
{
	LoadTranslation("callvote_kicklimit.phrases");
	LoadTranslation("callvote_common.phrases");
	LoadTranslation("common.phrases");
	g_cvarDebug		= CreateConVar("sm_cvkl_debug", "0", "Enable debug", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarEnable	= CreateConVar("sm_cvkl_enable", "1", "Enable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarLogMode	= CallVoteEnsureLogModeConVar();
	g_cvarDebugMask = CreateConVar("sm_cvkl_debug_mask", "0", "Debug mask for callvote_kicklimit. Core=1 SQL=2 Cache=4 Commands=8 Identity=16 Forwards=32 Session=64 Localization=128 All=2147483647.", FCVAR_NONE, true, 0.0, true, 2147483647.0);
	g_Log			= new CallVoteLogger(CVKL_LOG_TAG, CVKL_LOG_FILE, g_cvarLogMode, g_cvarDebugMask);
	g_cvarKickLimit = CreateConVar("sm_cvkl_kicklimit", "1", "Kick limit", FCVAR_NOTIFY, true, 0.0);
	
	RegAdminCmd("sm_cvkl_show", Command_KickShow, ADMFLAG_KICK, "Shows in-memory kick records for connected players");
	RegConsoleCmd("sm_cvkl_count", Command_KickCount, "Shows the current kick count for a player");

	g_hLocalKickCounts = new StringMap();

	OnPluginStart_SQL();

	CallVoteAutoExecConfig(false, "callvote_kicklimit");

	if(!g_bLateLoad)
		return;
	
	g_bCallVoteManager = LibraryExists(CALLVOTEMANAGER_LIBRARY);
}

Action Command_KickCount(int iClient, int sArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (sArgs < 1)
	{
		CReplyToCommand(iClient, "%t %t sm_cvkl_count <#userid|name>", "Tag", "Usage");
		return Plugin_Handled;
	}

	char sArguments[256];
	GetCmdArgString(sArguments, sizeof(sArguments));

	char sArg[65];
	BreakString(sArguments, sArg, sizeof(sArg));

	char sTargetName[MAX_TARGET_LENGTH];
	int	 sTargetList[MAXPLAYERS], sTargetCount;
	bool bTnIsMl;
	int	 iFlags = COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_NO_MULTI;

	if ((sTargetCount = ProcessTargetString(sArg, iClient, sTargetList, MAXPLAYERS, iFlags, sTargetName, sizeof(sTargetName), bTnIsMl)) > 0)
	{
		for (int i = 0; i < sTargetCount; i++)
		{
			if (sTargetList[i] == iClient)
				CReplyToCommand(iClient, "%t %t", "Tag", "KickLimit", g_Players[iClient].Kick, g_cvarKickLimit.IntValue);
			else
				CReplyToCommand(iClient, "%t %t", "Tag", "KickLimitTarget", sTargetName, g_Players[sTargetList[i]].Kick, g_cvarKickLimit.IntValue);
		}
	}
	else
		ReplyToTargetError(iClient, sTargetCount);

	return Plugin_Handled;
}

Action Command_KickShow(int iClient, int sArgs)
{
	if (!g_cvarEnable.BoolValue)
	{
		CPrintToChat(iClient, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (iClient == SERVER_INDEX)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "BlockUserConsole");
		return Plugin_Handled;
	}

	int iFound = 0;
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		if (g_Players[i].AccountID <= 0 || !g_Players[i].Kick)
			continue;

		char sSteamID2[MAX_AUTHID_LENGTH];
		FormatAccountIDAsSteamID2(g_Players[i].AccountID, sSteamID2, sizeof(sSteamID2));

		char sName[MAX_NAME_LENGTH];
		GetClientName(i, sName, sizeof(sName));

		iFound++;
		CPrintToChat(iClient, "%t %t", "Tag", "KickShow", sName, sSteamID2, g_Players[i].Kick);
	}

	if (!iFound)
		CPrintToChat(iClient, "%t %t", "Tag", "NoFound");

	return Plugin_Handled;
}

public void OnPluginEnd()
{
	if (g_hLocalKickCounts != null)
		delete g_hLocalKickCounts;

	if (g_db == null)
	{
		if (g_Log != null)
			delete g_Log;
		return;
	}

	delete g_db;
	log(true, "[OnPluginEnd] Database connection closed.");

	if (g_Log != null)
		delete g_Log;
}

public void OnConfigsExecuted()
{
	if (!g_cvarEnable.BoolValue)
		return;

	OnConfigsExecuted_SQL();
}

public void OnClientPostAdminCheck(int iClient)
{
	if (!g_cvarEnable.BoolValue || IsFakeClient(iClient))
		return;

	int iAccountId = GetClientAccountID(iClient);
	if (iAccountId <= 0)
	{
		ResetClientState(iClient);
		return;
	}

	ResetClientState(iClient);
	g_Players[iClient].AccountID = iAccountId;

	if (CanUseKickLimitSQL())
	{
		g_Players[iClient].LoadState = KickCount_Pending;
		GetCountKick(iClient, iAccountId);
	}
	else
		LoadLocalKickCount(iClient, iAccountId);
}

public void OnClientDisconnect(int iClient)
{
	ResetClientState(iClient);
}

/*****************************************************************
			F O R W A R D   P L U G I N S
*****************************************************************/

public Action CallVote_PreStartEx(int iSessionId, int iClient, int iCallerAccountId, TypeVotes iVotes, int iTarget, int iTargetAccountId, const char[] sArgument)
{
	if (!g_cvarEnable.BoolValue || !g_bCallVoteManager)
		return Plugin_Continue;

	if (iVotes != Kick)
		return Plugin_Continue;

	int iKickCount = 0;
	if (!TryGetKickCount(iClient, iCallerAccountId, iKickCount))
	{
		CPrintToChat(iClient, "%t %t", "Tag", "KickDataPending");
		return Plugin_Handled;
	}

	log(false, "[CallVote_PreStartEx] Session:%d | Caller:%N (AID:%d) | Target:%N (AID:%d) | Kicks:%d/%d | Arg:%s",
		iSessionId,
		iClient,
		iCallerAccountId,
		iTarget,
		iTargetAccountId,
		iKickCount,
		g_cvarKickLimit.IntValue,
		sArgument);

	if (g_cvarKickLimit.IntValue <= iKickCount)
	{
		char sBuffer[128];
		Format(sBuffer, sizeof(sBuffer), "%t", "KickReached", iKickCount, g_cvarKickLimit.IntValue);
		CPrintToChat(iClient, "%t %s", "Tag", sBuffer);
		if (g_Log != null)
			g_Log.Normal("KickBlocked", "Blocked kick vote from AID %d to AID %d (%d/%d)", iCallerAccountId, iTargetAccountId, iKickCount, g_cvarKickLimit.IntValue);
		return Plugin_Handled; // Block the vote
	}

	return Plugin_Continue; // Allow the vote
}

/****************************************************************
			C A L L B A C K   F U N C T I O N S
****************************************************************/

public void CallVote_EndEx(int iSessionId, CallVoteEndReason iResult, int iYesCount, int iNoCount, int iPotentialVotes)
{
	if (!g_cvarEnable.BoolValue || !g_bCallVoteManager)
		return;

	int iCallerClient;
	int iCallerAccountId;
	TypeVotes iVoteType;
	int iTargetClient;
	int iTargetAccountId;
	char sArgument[64];

	if (!CallVoteManager_GetSessionInfo(iSessionId, iCallerClient, iCallerAccountId, iVoteType, iTargetClient, iTargetAccountId, sArgument, sizeof(sArgument)))
		return;

	if (iVoteType != Kick)
		return;

	int iLiveCaller = FindClientByAccountID(iCallerAccountId);
	int iKnownKickCount = 0;
	bool bHasKickCount = TryGetKickCount(iLiveCaller, iCallerAccountId, iKnownKickCount);

	log(false, "[CallVote_EndEx] Session:%d | Result:%d | CallerAID:%d | TargetAID:%d | Votes:%d/%d/%d | Current:%d | Arg:%s",
		iSessionId,
		iResult,
		iCallerAccountId,
		iTargetAccountId,
		iYesCount,
		iNoCount,
		iPotentialVotes,
		iKnownKickCount,
		sArgument);

	if (iResult != CallVoteEnd_Passed)
		return;

	int iNewKickCount;
	if (CanUseKickLimitSQL())
	{
		if (!bHasKickCount)
		{
			log(false, "[CallVote_EndEx] Skipping SQL increment because caller AccountID %d is still loading.", iCallerAccountId);
			return;
		}

		iNewKickCount = iKnownKickCount + 1;
		UpdateConnectedClientKickCount(iCallerAccountId, iNewKickCount);
		sqlinsert(iSessionId, iCallerAccountId, iTargetAccountId);
	}
	else
	{
		iNewKickCount = IncrementLocalKickCount(iCallerAccountId);
	}

	char sCallerSteamID2[MAX_AUTHID_LENGTH];
	char sTargetSteamID2[MAX_AUTHID_LENGTH];
	FormatAccountIDAsSteamID2(iCallerAccountId, sCallerSteamID2, sizeof(sCallerSteamID2));
	FormatAccountIDAsSteamID2(iTargetAccountId, sTargetSteamID2, sizeof(sTargetSteamID2));

	log(false, "[CallVote_EndEx] Kick vote passed from %s to %s (%d/%d)",
		sCallerSteamID2,
		sTargetSteamID2,
		iNewKickCount,
		g_cvarKickLimit.IntValue);
	if (g_Log != null)
		g_Log.Normal("Kick", "Kick vote passed from %s to %s (%d/%d)", sCallerSteamID2, sTargetSteamID2, iNewKickCount, g_cvarKickLimit.IntValue);

	if (iLiveCaller > 0)
		CreateTimer(1.0, Timer_KickLimit, GetClientUserId(iLiveCaller), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_KickLimit(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (iClient > 0 && IsClientInGame(iClient) && !IsFakeClient(iClient))
		CPrintToChat(iClient, "%t %t", "Tag", "KickLimit", g_Players[iClient].Kick, g_cvarKickLimit.IntValue);

	return Plugin_Stop;
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

void ResetClientState(int iClient)
{
	g_Players[iClient].AccountID = 0;
	g_Players[iClient].Kick = 0;
	g_Players[iClient].LoadState = KickCount_Uninitialized;
}

void AccountIDToKey(int iAccountId, char[] sKey, int iMaxLen)
{
	IntToString(iAccountId, sKey, iMaxLen);
}

bool FormatAccountIDAsSteamID2(int iAccountId, char[] sBuffer, int iMaxLen)
{
	if (AccountIDToSteamID2(iAccountId, sBuffer, iMaxLen))
		return true;

	Format(sBuffer, iMaxLen, "AID:%d", iAccountId);
	return false;
}

void SetLocalKickCount(int iAccountId, int iKickCount)
{
	if (g_hLocalKickCounts == null || iAccountId <= 0)
		return;

	char sKey[ACCOUNTID_LENGTH];
	AccountIDToKey(iAccountId, sKey, sizeof(sKey));
	g_hLocalKickCounts.SetValue(sKey, iKickCount);
}

int GetLocalKickCount(int iAccountId)
{
	if (g_hLocalKickCounts == null || iAccountId <= 0)
		return 0;

	char sKey[ACCOUNTID_LENGTH];
	AccountIDToKey(iAccountId, sKey, sizeof(sKey));

	int iKickCount = 0;
	g_hLocalKickCounts.GetValue(sKey, iKickCount);
	return iKickCount;
}

void LoadLocalKickCount(int iClient, int iAccountId)
{
	g_Players[iClient].AccountID = iAccountId;
	g_Players[iClient].Kick = GetLocalKickCount(iAccountId);
	g_Players[iClient].LoadState = KickCount_Ready;
}

void UpdateConnectedClientKickCount(int iAccountId, int iKickCount)
{
	SetLocalKickCount(iAccountId, iKickCount);

	int iClient = FindClientByAccountID(iAccountId);
	if (iClient <= 0)
		return;

	g_Players[iClient].AccountID = iAccountId;
	g_Players[iClient].Kick = iKickCount;
	g_Players[iClient].LoadState = KickCount_Ready;
}

bool TryGetKickCount(int iClient, int iAccountId, int &iKickCount)
{
	if (iClient > 0 && iClient <= MaxClients && g_Players[iClient].AccountID == iAccountId)
	{
		if (g_Players[iClient].LoadState == KickCount_Ready)
		{
			iKickCount = g_Players[iClient].Kick;
			return true;
		}

		if (g_Players[iClient].LoadState == KickCount_Pending)
			return false;
	}

	if (!g_cvarSQL.BoolValue)
	{
		iKickCount = GetLocalKickCount(iAccountId);
		return true;
	}

	if (!CanUseKickLimitSQL())
	{
		iKickCount = GetLocalKickCount(iAccountId);
		return true;
	}

	if (iClient > 0 && iClient <= MaxClients && g_Players[iClient].AccountID == iAccountId)
	{
		if (g_Players[iClient].LoadState == KickCount_Ready)
		{
			iKickCount = g_Players[iClient].Kick;
			return true;
		}

		if (g_Players[iClient].LoadState == KickCount_Pending)
			return false;
	}

	if (GetLocalKickCount(iAccountId) > 0)
	{
		iKickCount = GetLocalKickCount(iAccountId);
		return true;
	}

	return false;
}

int IncrementLocalKickCount(int iAccountId)
{
	int iKickCount = GetLocalKickCount(iAccountId) + 1;
	SetLocalKickCount(iAccountId, iKickCount);
	UpdateConnectedClientKickCount(iAccountId, iKickCount);
	return iKickCount;
}

void RefreshConnectedClientsFromSQL()
{
	if (!CanUseKickLimitSQL())
		return;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || g_Players[i].AccountID <= 0)
			continue;

		GetCountKick(i, g_Players[i].AccountID);
	}
}

void log(bool error, const char[] format, any ...)
{
	if (g_Log == null)
		return;

	char message[512];
	VFormat(message, sizeof(message), format, 3);

	if (error)
		LogError("%s", message);

	int debugMask = CVLogMask_Core;
	char category[16];
	strcopy(category, sizeof(category), "Core");

	if (strncmp(message, "[sqlinsert]", 11, false) == 0
		|| strncmp(message, "[CallBack_SQLInsert]", 20, false) == 0
		|| strncmp(message, "[GetCountKick]", 14, false) == 0
		|| strncmp(message, "[CallBack_GetCountKick]", 23, false) == 0
		|| strncmp(message, "[ConnectDB]", 11, false) == 0
		|| strncmp(message, "[ConnectCallback]", 17, false) == 0
		|| strncmp(message, "[CheckTableCallback]", 20, false) == 0)
	{
		debugMask = CVLogMask_SQL;
		category = "SQL";
	}
	else if (strncmp(message, "[CallVote_PreStartEx]", 21, false) == 0
		|| strncmp(message, "[CallVote_EndEx]", 17, false) == 0)
	{
		debugMask = CVLogMask_Session;
		category = "Session";
	}

	g_Log.Debug(debugMask, category, "%s", message);

	if (g_cvarDebug != null && g_cvarDebug.BoolValue)
		PrintToServer("[CallVote Kick Limit] %s", message);
}

void logErrorSQL(Database db, const char[] query, const char[] context)
{
	char sqlError[256];
	if (db != null)
		SQL_GetError(db, sqlError, sizeof(sqlError));
	else
		strcopy(sqlError, sizeof(sqlError), "Unknown database handle");

	log(false, "[%s] SQL error: %s", context, sqlError);
	log(true, "[%s] Query dump: %s", context, query);
}

void ConnectDB(const char[] configName, const char[] tableName)
{
	g_bSQLConnected = false;
	g_bSQLTableExists = false;

	if (!SQL_CheckConfig(configName))
	{
		log(false, "[ConnectDB] Missing database config: %s", configName);
		return;
	}

	log(false, "[ConnectDB] Connecting to database config %s for table %s", configName, tableName);
	Database.Connect(ConnectCallback, configName);
}

void ConnectCallback(Database database, const char[] error, any data)
{
	g_bSQLConnected = false;
	g_bSQLTableExists = false;

	if (database == null)
	{
		log(true, "[ConnectCallback] Could not connect to database: %s", error);
		return;
	}

	g_db = database;
	g_bSQLConnected = true;

	DBDriver driver = database.Driver;
	if (driver == null)
	{
		log(true, "[ConnectCallback] Could not resolve database driver.");
		g_bSQLConnected = false;
		delete g_db;
		g_db = null;
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
	{
		g_SQLDriver = SQL_SQLite;
	}
	else
	{
		log(true, "[ConnectCallback] Unsupported database driver: %s", driverName);
		g_bSQLConnected = false;
		delete g_db;
		g_db = null;
		return;
	}

	if (g_SQLDriver == SQL_SQLite)
		EnsureSQLiteSchema();

	CheckTableExists();
}

void CheckTableExists()
{
	if (!g_bSQLConnected || g_db == null)
	{
		g_bSQLTableExists = false;
		return;
	}

	char query[256];
	switch (g_SQLDriver)
	{
		case SQL_MySQL:
		{
			g_db.Format(query, sizeof(query),
				"SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = '%s' LIMIT 1",
				g_sTable);
		}
		case SQL_SQLite:
		{
			g_db.Format(query, sizeof(query),
				"SELECT 1 FROM sqlite_master WHERE type='table' AND name='%s' LIMIT 1",
				g_sTable);
		}
	}

	g_db.Query(CheckTableCallback, query);
}

void CheckTableCallback(Database database, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		log(true, "[CheckTableCallback] Error checking table existence: %s", error);
		g_bSQLTableExists = false;
		return;
	}

	g_bSQLTableExists = results.FetchRow();
	log(false, "[CheckTableCallback] Table %s exists: %s", g_sTable, g_bSQLTableExists ? "true" : "false");

	if (!g_bSQLTableExists && g_SQLDriver == SQL_MySQL)
		log(false, "[CheckTableCallback] MySQL table %s is missing; apply schema migrations", g_sTable);

	if (g_bSQLTableExists)
		RefreshConnectedClientsFromSQL();
}

// =======================================================================================
// Bibliography
// https://developer.valvesoftware.com/wiki/List_of_L4D2_Cvars
// https://wiki.alliedmods.net/Left_4_Voting_2
// https://forums.alliedmods.net/showthread.php?p=1582772
// https://github.com/SirPlease/L4D2-Competitive-Rework
// =======================================================================================
