#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <callvote_stock>
#include <callvote_localizer>
#include <language_manager>
#include <steamidtools_helpers>

#undef REQUIRE_PLUGIN
#include <callvote_core>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION	 "2.0.0"
#define CVB_LOG_TAG		 "CVB"
#define CVB_LOG_FILE	 "callvote_bans.log"

#define MAX_QUERY_LENGTH 2048

ConVar
	g_cvarEnable,
	g_cvarMemoryCache,
	g_cvarAnnounceJoin,
	g_cvarSQLConfig,
	g_cvarLogMode,
	g_cvarDebugMask;

// Unified in-memory cache using AccountID as key
StringMap g_smClientCache;	  // Unified in-memory cache for restriction information
ArrayList g_aPendingIdentityRequestIds;
ArrayList g_aPendingIdentityRequestContexts;

Database
	g_hSQLiteDB,	// Local SQLite bans backend
	g_hMySQLDB;		// Main database

bool
	g_bLateLoad,
	g_bCallVoteCoreLoaded,
	g_bMySQLConnecting,
	g_bSteamIDToolsLoaded;

CallVoteLogger g_Log = null;
Localizer g_loc = null;

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
	int				   accountId;	 // Player's AccountID
	ClientBanLoadState loadState;
}

ClientState g_ClientStates[MAXPLAYERS + 1];

void		ResetClientState(int client)
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

	public 	static void Event(const char[] eventTag, const char[] message, any...)
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

	public 	static void Commands(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_Commands, "Commands", "%s", sFormat);
	}

	public 	static void Identity(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_Identity, "Identity", "%s", sFormat);
	}

	public 	static void Core(const char[] message, any...)
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

public APLRes
	AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max)
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
	g_bCallVoteCoreLoaded = LibraryExists(CALLVOTECORE_LIBRARY);
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, STEAMIDTOOLS_LIBRARY))
		g_bSteamIDToolsLoaded = false;
	if (StrEqual(sName, CALLVOTECORE_LIBRARY))
		g_bCallVoteCoreLoaded = false;
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, STEAMIDTOOLS_LIBRARY))
		g_bSteamIDToolsLoaded = true;
	if (StrEqual(sName, CALLVOTECORE_LIBRARY))
		g_bCallVoteCoreLoaded = true;
}

public void OnPluginStart()
{
	g_loc = new Localizer();

	LoadTranslations("callvote_bans.phrases");
	LoadTranslations("callvote_common.phrases");
	LoadTranslations("common.phrases");
	HookEvent("player_team", Event_PlayerTeam);

	g_cvarEnable	   = CreateConVar("sm_cvb_enable", "1", "Enable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarMemoryCache  = CreateConVar("sm_cvb_memory_cache", "1", "Enable in-memory cache for ban lookups", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarAnnounceJoin = CreateConVar("sm_cvb_announce_join", "1", "0=off, 1=admins, 2=everyone", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	g_cvarSQLConfig	   = CreateConVar("sm_cvb_sql_config", "callvote", "Database config name from databases.cfg for the MySQL backend", FCVAR_NOTIFY);
	g_cvarLogMode	   = CallVoteEnsureLogModeConVar();
	g_cvarDebugMask	   = CreateConVar("sm_cvb_debug_mask", "0", "Debug mask for callvote_bans. Core=1 SQL=2 Cache=4 Commands=8 Identity=16 All=255.", FCVAR_NONE, true, 0.0, true, 255.0);
	g_Log			   = new CallVoteLogger(CVB_LOG_TAG, CVB_LOG_FILE, g_cvarLogMode, g_cvarDebugMask);

	CallVoteAutoExecConfig(true, "callvote_bans");

	InitMemoryCache();
	RegisterCommands();

	if (!g_bLateLoad)
		return;

	g_bSteamIDToolsLoaded	 = LibraryExists(STEAMIDTOOLS_LIBRARY);
	g_bCallVoteCoreLoaded = LibraryExists(CALLVOTECORE_LIBRARY);

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
}

public void OnPluginEnd()
{
	if (g_loc != null)
	{
		g_loc.Close();
		g_loc = null;
	}

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

	PlayerRestrictionInfo restrictionInfo;
	restrictionInfo.Reset(accountId);

	CVBLookupStatus status = CVB_LoadRestrictionInfo(restrictionInfo, false);
	SetClientLoadState(client, accountId, ClientBanLoad_Ready);

	if (status == CVBLookup_Found)
	{
		CVBLog.Debug("Player %N has active vote restrictions (AccountID: %d restrictionMask=%d)", client, restrictionInfo.AccountId, restrictionInfo.RestrictionMask);
		AnnouncerJoin(client);
		return;
	}

	if (status == CVBLookup_Error)
	{
		CVBLog.SQL("Failed to validate restriction state for %N (AccountID: %d) during post admin check", client, restrictionInfo.AccountId);
	}
}

void AnnouncerJoin(int client)
{
	if (!g_cvarEnable.BoolValue || !g_bCallVoteCoreLoaded || g_cvarAnnounceJoin.IntValue == 0 || !IsValidClient(client))
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

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvarEnable.BoolValue)
		return;

	if (!event.GetBool("disconnect", false))
		return;

	int userId = event.GetInt("userid", 0);
	int client = GetClientOfUserId(userId);
	if (!IsValidClientIndex(client) || IsFakeClient(client))
		return;

	int accountId = g_ClientStates[client].accountId;
	if (accountId <= 0)
		accountId = GetClientAccountID(client);

	if (accountId > 0)
	{
		CVB_RemoveMemoryCacheEntry(accountId);
		CVBLog.Cache("player_team disconnect detected for client %d; purged memory cache for AccountID %d", client, accountId);
	}

	OnClientMemoryCacheDisconnect(client);
}

/*****************************************************************
			C A L L V O T E   M A N A G E R   F O R W A R D S
*****************************************************************/

/**
 * Forward del CallVoteManager - Intercepta intentos de voto antes de validación
 */
public Action CallVote_PreStart(int sessionId, int client, int callerAccountId, TypeVotes voteType, int target, int targetAccountId, const char[] argument)
{
	if (!g_cvarEnable.BoolValue)
		return Plugin_Continue;

	if (!IsValidClient(client))
		return Plugin_Continue;

	int resolvedCallerAccountId = callerAccountId;
	if (resolvedCallerAccountId <= 0)
		TryGetConnectedAccountId(client, resolvedCallerAccountId);

	PlayerRestrictionInfo restrictionInfo;
	restrictionInfo.Reset(resolvedCallerAccountId);
	VoteType voteFlag = GetVoteFlag(voteType);
	CVBLog.Debug("CallVote_PreStart: session=%d client=%N callerAccountId=%d resolvedCallerAccountId=%d voteType=%d targetAccountId=%d argument=%s", sessionId, client, callerAccountId, resolvedCallerAccountId, voteType, targetAccountId, argument);

	if (voteFlag == VOTE_NONE)
		return Plugin_Continue;

	if (restrictionInfo.AccountId <= 0)
	{
		CallVoteCore_SetPendingRestriction(VoteRestriction_Plugin);
		ShowVoteBlockedValidationMessage(client);

		CVBLog.Debug("Voto BLOQUEADO por AccountID no resuelto para %N (callerAccountId=%d, tipo=%d)", client, callerAccountId, voteType);
		CVBLog.Event("BlockValidation", "Blocked vote for unresolved AccountID (client=%d callerAccountId=%d type=%d target=%d)", client, callerAccountId, voteType, target);
		return Plugin_Handled;
	}

	CVBLookupStatus status = CVB_LoadRestrictionInfo(restrictionInfo, false);
	SetClientLoadState(client, restrictionInfo.AccountId, ClientBanLoad_Ready);

	int effectiveRestrictionMask = restrictionInfo.RestrictionMask;
	if (effectiveRestrictionMask <= 0)
	{
		effectiveRestrictionMask = GetClientRestrictionMask(client);
		if (effectiveRestrictionMask > 0)
		{
			restrictionInfo.RestrictionMask = effectiveRestrictionMask;
			status = CVBLookup_Found;
		}
	}

	if (effectiveRestrictionMask <= 0 && restrictionInfo.AccountId > 0)
	{
		PlayerRestrictionInfo backendRestrictionInfo;
		backendRestrictionInfo.Reset(restrictionInfo.AccountId);
		CVBLookupStatus backendStatus = CVB_CheckActiveRestriction(backendRestrictionInfo);
		if (backendStatus == CVBLookup_Found && backendRestrictionInfo.IsBanned())
		{
			restrictionInfo = backendRestrictionInfo;
			effectiveRestrictionMask = backendRestrictionInfo.RestrictionMask;
			status = CVBLookup_Found;
			CVB_UpdateMemoryCache(restrictionInfo);
		}
		else if (backendStatus == CVBLookup_Error)
		{
			status = CVBLookup_Error;
		}
	}

	CVBLog.Cache(
		"CallVote_PreStart lookup result: session=%d accountId=%d status=%d voteFlag=%d restrictionMask=%d",
		sessionId,
		restrictionInfo.AccountId,
		view_as<int>(status),
		view_as<int>(voteFlag),
		effectiveRestrictionMask
	);

	if (status == CVBLookup_Error)
	{
		CallVoteCore_SetPendingRestriction(VoteRestriction_Plugin);
		ShowVoteBlockedValidationMessage(client);

		Call_StartForward(g_gfBlocked);
		Call_PushCell(client);
		Call_PushCell(view_as<int>(voteType));
		Call_PushCell(target);
		Call_PushCell(0);
		Call_Finish();

		CVBLog.Debug("Voto BLOQUEADO por error de validación para %N (AccountID: %d, tipo: %d)", client, restrictionInfo.AccountId, voteType);
		CVBLog.Event("BlockValidation", "Blocked vote for AccountID %d (type=%d target=%d reason=backend_validation_failed)", restrictionInfo.AccountId, voteType, target);
		return Plugin_Handled;
	}

	if (status == CVBLookup_Found && (effectiveRestrictionMask & view_as<int>(voteFlag)))
	{
		CallVoteCore_SetPendingRestriction(VoteRestriction_Plugin);
		ShowVoteBlockedMessage(client, voteType);

		Call_StartForward(g_gfBlocked);
		Call_PushCell(client);
		Call_PushCell(view_as<int>(voteType));
		Call_PushCell(target);
		Call_PushCell(effectiveRestrictionMask);
		Call_Finish();

		CVBLog.Debug("Voto BLOQUEADO para %N (AccountID: %d, tipo: %d, restrictionMask: %d)", client, restrictionInfo.AccountId, voteType, effectiveRestrictionMask);
		CVBLog.Event("Block", "Blocked vote for AccountID %d (type=%d restrictionMask=%d target=%d)", restrictionInfo.AccountId, voteType, effectiveRestrictionMask, target);

		return Plugin_Handled;
	}

	CVBLog.Debug("Voto PERMITIDO para %N (AccountID: %d, tipo: %d)", client, restrictionInfo.AccountId, voteType);
	return Plugin_Continue;
}
