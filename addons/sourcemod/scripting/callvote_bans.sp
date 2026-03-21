#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <callvote_stock>
#include <steamidtools_helpers>

#undef REQUIRE_PLUGIN
#include <callvotemanager>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION	 "2.0.0"
#define CVB_LOG_TAG "CVB"
#define CVB_LOG_FILE "callvote_bans.log"

#define MAX_QUERY_LENGTH 2048

ConVar
	g_cvarEnable,
	g_cvarMemoryCache,
	g_cvarAnnounceJoin,
	g_cvarLogMode,
	g_cvarDebugMask;

// Unified in-memory cache using AccountID as key
StringMap g_smClientCache;		  // Unified in-memory cache for ban information
ArrayList g_aPendingIdentityRequestIds;
ArrayList g_aPendingIdentityRequestContexts;

Database
	g_hSQLiteDB,	// Local SQLite bans backend
	g_hMySQLDB;		// Main database

bool
	g_bLateLoad,
	g_bCallVoteManagerLoaded,
	g_bSteamIDToolsLoaded;

CallVoteLogger g_Log = null;


/**
 * Client state structure for connected players only
 */
enum ClientBanLoadState
{
	ClientBanLoad_Uninitialized = 0,
	ClientBanLoad_Ready
}

enum struct ClientState
{
	int accountId;			  // Player's AccountID
	ClientBanLoadState loadState;
}

ClientState g_ClientStates[MAXPLAYERS + 1];

void ResetClientState(int client)
{
	if (!IsValidClientIndex(client))
		return;

	g_ClientStates[client].accountId = 0;
	g_ClientStates[client].loadState = ClientBanLoad_Uninitialized;
}

void SetClientLoadState(int client, int accountId, ClientBanLoadState loadState)
{
	if (!IsValidClientIndex(client))
		return;

	g_ClientStates[client].accountId = accountId;
	g_ClientStates[client].loadState = loadState;
}

methodmap CVBLog
{
	public static void Event(const char[] eventTag, const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Normal(eventTag, "%s", sFormat);
	}

	public 	static void Debug(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_Core, "Core", "%s", sFormat);
	}

	public 	static void SQL(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_SQL, "SQL", "%s", sFormat);
	}

	public 	static void MySQL(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_SQL, "MySQL", "%s", sFormat);
	}

	public 	static void SQLite(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_SQL, "SQLite", "%s", sFormat);
	}

	public 	static void Cache(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_Cache, "Cache", "%s", sFormat);
	}

	public static void Commands(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_Commands, "Commands", "%s", sFormat);
	}

	public static void Identity(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_Identity, "Identity", "%s", sFormat);
	}

	public static void Core(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_Core, "Core", "%s", sFormat);
	}
}

/*****************************************************************
			L I B R A R Y   I N C L U D E S
*****************************************************************/

#include "callvote_bans/api.sp"
#include "callvote_bans/helpers.sp"
#include "callvote_bans/db.sp"
#include "callvote_bans/model.sp"
#include "callvote_bans/detail.sp"
#include "callvote_bans/memory_cache.sp"
#include "callvote_bans/notification.sp"
#include "callvote_bans/mutations.sp"
#include "callvote_bans/commands.sp"

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/
public Plugin myinfo =
{
	name		= "Call Vote Bans",
	author		= "lechuga",
	description = "Basic callvote restriction plugin",
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
	g_bSteamIDToolsLoaded	 = LibraryExists(STEAMIDTOOLS_LIBRARY);
	g_bCallVoteManagerLoaded = LibraryExists(CALLVOTEMANAGER_LIBRARY);
	CVB_RequestIdentityHealthChecks();
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, STEAMIDTOOLS_LIBRARY))
		g_bSteamIDToolsLoaded = false;
	if (StrEqual(sName, CALLVOTEMANAGER_LIBRARY))
		g_bCallVoteManagerLoaded = false;
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, STEAMIDTOOLS_LIBRARY))
	{
		g_bSteamIDToolsLoaded = true;
		CVB_RequestIdentityHealthChecks();
	}
	if (StrEqual(sName, CALLVOTEMANAGER_LIBRARY))
		g_bCallVoteManagerLoaded = true;
}

public void OnPluginStart()
{
	LoadTranslations("callvote_bans.phrases");
	LoadTranslations("callvote_common.phrases");
	LoadTranslations("common.phrases");

	g_cvarEnable				 = CreateConVar("sm_cvb_enable", "1", "Enable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarMemoryCache			 = CreateConVar("sm_cvb_memory_cache", "1", "Enable in-memory cache for ban lookups", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarAnnounceJoin			 = CreateConVar("sm_cvb_announce_join", "1", "0=off, 1=admins, 2=everyone", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_cvarLogMode				 = CallVoteEnsureLogModeConVar();
	g_cvarDebugMask			 = CreateConVar("sm_cvb_debug_mask", "0", "Debug mask for callvote_bans. Core=1 SQL=2 Cache=4 Commands=8 Identity=16 All=255.", FCVAR_NONE, true, 0.0, true, 255.0);
	g_Log						 = new CallVoteLogger(CVB_LOG_TAG, CVB_LOG_FILE, g_cvarLogMode, g_cvarDebugMask);

	CallVoteAutoExecConfig(true, "callvote_bans");

	InitMemoryCache();
	RegisterCommands();

	if (!g_bLateLoad)
		return;

	g_bSteamIDToolsLoaded	 = LibraryExists(STEAMIDTOOLS_LIBRARY);
	g_bCallVoteManagerLoaded = LibraryExists(CALLVOTEMANAGER_LIBRARY);

	OnAllPluginsLoaded();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		OnClientMemoryCacheConnect(i);
	}
}

public void OnConfigsExecuted()
{
	if (!g_cvarEnable.BoolValue)
		return;

	InitDatabase();
	CVB_RequestIdentityHealthChecks();
}

public void OnPluginEnd()
{
	CloseDatabase();
	ClosePendingIdentityRequests();
	CloseMemoryCache();
	CloseForwards();

	if (g_Log != null)
		delete g_Log;
}

public void OnClientPostAdminCheck(int client)
{
	if (!g_cvarEnable.BoolValue || !IsValidClient(client))
		return;

	int accountId;
	if (!TryGetConnectedAccountId(client, accountId))
		return;

	PlayerBanInfo banInfo;
	banInfo.Reset(accountId);

	if (IsPlayerBanned(client, banInfo))
	{
		CVBLog.Debug("Player %N is banned (AccountID: %d)", client, banInfo.AccountId);
		AnnouncerJoin(client);
		return;
	}
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
	if (!g_cvarEnable.BoolValue)
		return;
	
	OnClientMemoryCacheDisconnect(client);
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

	PlayerBanInfo banInfo;
	banInfo.Reset(GetClientAccountID(client));
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
		CVBLog.Event("Block", "Blocked vote for AccountID %d (type=%d banType=%d target=%d)", banInfo.AccountId, voteType, banInfo.BanType, target);

		return Plugin_Handled;
	}

	CVBLog.Debug("Voto PERMITIDO para %N (AccountID: %d, tipo: %d)", client, banInfo.AccountId, voteType);
	return Plugin_Continue;
}
