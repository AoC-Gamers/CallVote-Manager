#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <left4dhooks>
#include <callvotemanager>
#include <language_manager>
#include <campaign_manager>
#include <steamidtools_helpers>


#undef REQUIRE_EXTENSIONS
#include <confogl>
#include <builtinvotes>
#define REQUIRE_EXTENSIONS

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define PLUGIN_VERSION "2.0.0"
#define CVM_LOG_TAG "CVM"
#define CVM_LOG_FILE "callvote_manager.log"

enum CallVoteSessionStatus
{
	CallVoteSession_None = 0,
	CallVoteSession_Pending,
	CallVoteSession_Started,
	CallVoteSession_Blocked,
	CallVoteSession_Ended
}

enum CallVoteSessionLookupResult
{
	CallVoteSessionLookup_None = 0,
	CallVoteSessionLookup_Current,
	CallVoteSessionLookup_Last
}

enum struct CVClientIdentity
{
	int Client;
	int UserId;
	int AccountId;
	char SteamID64[STEAMID64_EXACT_LENGTH + 1];
}

enum struct CVVoteSession
{
	int sessionId;
	CallVoteSessionStatus status;
	int createdAt;
	int callerClient;
	int callerUserId;
	int callerAccountId;
	TypeVotes voteType;
	int targetClient;
	int targetUserId;
	int targetAccountId;
	char callerSteamID64[STEAMID64_EXACT_LENGTH + 1];
	char targetSteamID64[STEAMID64_EXACT_LENGTH + 1];
	char argumentRaw[64];
	char engineIssue[128];
	char engineParam1[128];
	char engineParam2[128];
	int engineTeam;
	int engineInitiatorClient;
	VoteRestrictionType restriction;
	CallVoteEndReason endReason;
	int yesVotes;
	int noVotes;
	int potentialVotes;
}

stock char sTypeVotes[TypeVotes_Size][] = {
	"ChangeDifficulty",
	"RestartGame",
	"Kick",
	"ChangeMission",
	"ReturnToLobby",
	"ChangeChapter",
	"ChangeAllTalk"
};

StringMap g_mapVoteTypes;

ConVar
	g_cvarRegLog,
	g_cvarLogMode,
	g_cvarDebugMask,
	g_cvarEnable,

	g_cvarBuiltinVote,
	g_cvarAnnouncer,
	g_cvarProgress,
	g_cvarProgressAnonymous,

	g_cvarLobby,
	g_cvarChapter,
	g_cvarAllTalk,

	g_cvarAdminImmunity,
	g_cvarSTVImmunity,
	g_cvarSelfImmunity,
	g_cvarBotImmunity,

	sv_vote_issue_change_difficulty_allowed,
	sv_vote_issue_restart_game_allowed,
	sv_vote_issue_kick_allowed,
	sv_vote_issue_change_mission_allowed,
	sv_vote_creation_timer,
	z_difficulty;

bool
	g_bBuiltinVotes = false,
	g_bConfogl = false,
	g_bLateLoad,
	g_bCurrentVoteSessionValid = false,
	g_bLastVoteSessionValid = false;

float
	g_fLastVote;

int
	g_iNextVoteSessionId = 1,
	g_iFlagsAdmin,
	g_iClientFlagsCache[MAXPLAYERS + 1];	// Cache for client admin flags

CVVoteSession
	g_CurrentVoteSession,
	g_LastVoteSession;

bool
	g_bClientFlagsCached[MAXPLAYERS + 1];	 // Track which clients have cached flags

GlobalForward
	g_ForwardCallVotePreStart,
	g_ForwardCallVoteStart,
	g_ForwardCallVotePreExecute,
	g_ForwardCallVoteBlocked,
	g_ForwardCallVotePreStartEx,
	g_ForwardCallVoteStartEx,
	g_ForwardCallVotePreExecuteEx,
	g_ForwardCallVoteBlockedEx,
	g_ForwardCallVoteEndEx;

Localizer
	g_loc;
CallVoteLogger g_Log = null;

/**
 * Modern logging system using methodmap
 * Maintains the same macro-based optimization philosophy
 */
methodmap CVLog
{
	public static void Event(const char[] eventTag, const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Normal(eventTag, "%s", sFormat);
	}

	public static void Debug(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_Core, "Core", "%s", sFormat);
	}

	public static void SQL(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_SQL, "SQL", "%s", sFormat);
	}

	public static void Query(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_SQL, "SQL-Query", "%s", sFormat);
	}

	public static void Session(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_Session, "Session", "%s", sFormat);
	}

	public static void Forwards(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_Forwards, "Forwards", "%s", sFormat);
	}

	public static void Localization(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_Localization, "Localization", "%s", sFormat);
	}
}

void ResetVoteSession(CVVoteSession session)
{
	session.sessionId = 0;
	session.status = CallVoteSession_None;
	session.createdAt = 0;
	session.callerClient = 0;
	session.callerUserId = 0;
	session.callerAccountId = 0;
	session.voteType = ChangeDifficulty;
	session.targetClient = 0;
	session.targetUserId = 0;
	session.targetAccountId = 0;
	session.callerSteamID64[0] = '\0';
	session.targetSteamID64[0] = '\0';
	session.argumentRaw[0] = '\0';
	session.engineIssue[0] = '\0';
	session.engineParam1[0] = '\0';
	session.engineParam2[0] = '\0';
	session.engineTeam = -1;
	session.engineInitiatorClient = 0;
	session.restriction = VoteRestriction_None;
	session.endReason = CallVoteEnd_Aborted;
	session.yesVotes = 0;
	session.noVotes = 0;
	session.potentialVotes = 0;
}

void ArchiveCurrentVoteSession()
{
	if (!g_bCurrentVoteSessionValid)
		return;

	g_LastVoteSession = g_CurrentVoteSession;
	g_bLastVoteSessionValid = true;
	ResetVoteSession(g_CurrentVoteSession);
	g_bCurrentVoteSessionValid = false;
}

void ResolveClientIdentity(int client, CVClientIdentity identity, bool requireHumanForAccount = false)
{
	identity.Client = client;
	identity.UserId = IsValidClientIndex(client) ? GetClientUserId(client) : 0;
	identity.AccountId = 0;
	identity.SteamID64[0] = '\0';

	if (requireHumanForAccount)
	{
		if (IsHuman(client))
		{
			identity.AccountId = GetClientAccountID(client);
			GetClientAuthId(client, AuthId_SteamID64, identity.SteamID64, sizeof(identity.SteamID64));
		}
		return;
	}

	if (IsValidClient(client))
	{
		identity.AccountId = GetClientAccountID(client);
		GetClientAuthId(client, AuthId_SteamID64, identity.SteamID64, sizeof(identity.SteamID64));
	}
}

void BeginVoteSession(int client, TypeVotes voteType, int target = 0, const char[] argument = "")
{
	if (g_bCurrentVoteSessionValid)
	{
		CVLog.Session("[BeginVoteSession] Replacing stale active session %d", g_CurrentVoteSession.sessionId);
		ArchiveCurrentVoteSession();
	}

	CVClientIdentity callerIdentity;
	CVClientIdentity targetIdentity;
	ResolveClientIdentity(client, callerIdentity);
	ResolveClientIdentity(target, targetIdentity, true);

	ResetVoteSession(g_CurrentVoteSession);
	g_CurrentVoteSession.sessionId = g_iNextVoteSessionId++;
	g_CurrentVoteSession.status = CallVoteSession_Pending;
	g_CurrentVoteSession.createdAt = GetTime();
	g_CurrentVoteSession.callerClient = callerIdentity.Client;
	g_CurrentVoteSession.callerUserId = callerIdentity.UserId;
	g_CurrentVoteSession.callerAccountId = callerIdentity.AccountId;
	g_CurrentVoteSession.voteType = voteType;
	g_CurrentVoteSession.targetClient = targetIdentity.Client;
	g_CurrentVoteSession.targetUserId = targetIdentity.UserId;
	g_CurrentVoteSession.targetAccountId = targetIdentity.AccountId;
	strcopy(g_CurrentVoteSession.callerSteamID64, sizeof(g_CurrentVoteSession.callerSteamID64), callerIdentity.SteamID64);
	strcopy(g_CurrentVoteSession.targetSteamID64, sizeof(g_CurrentVoteSession.targetSteamID64), targetIdentity.SteamID64);
	strcopy(g_CurrentVoteSession.argumentRaw, sizeof(g_CurrentVoteSession.argumentRaw), argument);
	g_bCurrentVoteSessionValid = true;

	CVLog.Session("[BeginVoteSession] session=%d caller=%d account=%d voteType=%d target=%d targetAccount=%d argument='%s'",
		g_CurrentVoteSession.sessionId,
		g_CurrentVoteSession.callerClient,
		g_CurrentVoteSession.callerAccountId,
		view_as<int>(g_CurrentVoteSession.voteType),
		g_CurrentVoteSession.targetClient,
		g_CurrentVoteSession.targetAccountId,
		g_CurrentVoteSession.argumentRaw);
}

bool TryGetVoteSessionById(int sessionId, CVVoteSession session, CallVoteSessionLookupResult &lookupResult)
{
	lookupResult = CallVoteSessionLookup_None;

	if (sessionId <= 0)
		return false;

	if (g_bCurrentVoteSessionValid && g_CurrentVoteSession.sessionId == sessionId)
	{
		session = g_CurrentVoteSession;
		lookupResult = CallVoteSessionLookup_Current;
		return true;
	}

	if (g_bLastVoteSessionValid && g_LastVoteSession.sessionId == sessionId)
	{
		session = g_LastVoteSession;
		lookupResult = CallVoteSessionLookup_Last;
		return true;
	}

	return false;
}

bool TryGetNativeVoteSession(int sessionId, CVVoteSession session)
{
	CallVoteSessionLookupResult lookupResult;

	if (sessionId <= 0)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid session id (%d)", sessionId);
		return false;
	}

	if (!TryGetVoteSessionById(sessionId, session, lookupResult))
		return false;

	return true;
}

bool TryGetSessionSteamID64Info(int sessionId, char[] callerSteamID64, int callerMaxLen, char[] targetSteamID64, int targetMaxLen)
{
	CVVoteSession session;
	CallVoteSessionLookupResult lookupResult;

	callerSteamID64[0] = '\0';
	targetSteamID64[0] = '\0';

	if (sessionId <= 0)
		return false;

	if (!TryGetVoteSessionById(sessionId, session, lookupResult))
		return false;

	strcopy(callerSteamID64, callerMaxLen, session.callerSteamID64);
	strcopy(targetSteamID64, targetMaxLen, session.targetSteamID64);
	return true;
}

bool IsClientInRecipients(int client, const int[] recipients, int recipientsNum)
{
	if (!IsValidClientIndex(client))
		return false;

	for (int i = 0; i < recipientsNum; i++)
	{
		if (recipients[i] == client)
			return true;
	}

	return false;
}

/*****************************************************************
			L I B R A R Y   I N C L U D E S
*****************************************************************/

#include "callvote_manager/sql.sp"
#include "callvote_manager/printlocalized.sp"

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/
public Plugin myinfo =
{
	name		= "Call Vote Manager",
	author		= "lechuga",
	description = "Manage call vote system",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/AoC-Gamers/CallVote-Manager"

}

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max)
{
	g_ForwardCallVotePreStart = CreateGlobalForward("CallVote_PreStart", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	g_ForwardCallVoteStart = CreateGlobalForward("CallVote_Start", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_ForwardCallVotePreExecute = CreateGlobalForward("CallVote_PreExecute", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	g_ForwardCallVoteBlocked = CreateGlobalForward("CallVote_Blocked", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_ForwardCallVotePreStartEx = CreateGlobalForward("CallVote_PreStartEx", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_ForwardCallVoteStartEx = CreateGlobalForward("CallVote_StartEx", ET_Ignore, Param_Cell);
	g_ForwardCallVotePreExecuteEx = CreateGlobalForward("CallVote_PreExecuteEx", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_ForwardCallVoteBlockedEx = CreateGlobalForward("CallVote_BlockedEx", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_ForwardCallVoteEndEx = CreateGlobalForward("CallVote_EndEx", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

	CreateNative("CallVoteManager_IsVoteAllowedByConVar", Native_IsVoteAllowedByConVar);
	CreateNative("CallVoteManager_IsVoteAllowedByGameMode", Native_IsVoteAllowedByGameMode);
	CreateNative("CallVoteManager_GetClientAccountID", Native_GetClientAccountID);
	CreateNative("CallVoteManager_GetClientSteamID2", Native_GetClientSteamID2);
	CreateNative("CallVoteManager_GetCurrentSession", Native_GetCurrentSession);
	CreateNative("CallVoteManager_GetSessionInfo", Native_GetSessionInfo);
	CreateNative("CallVoteManager_GetSessionSteamID64Info", Native_GetSessionSteamID64Info);
	CreateNative("CallVoteManager_GetSessionIssueInfo", Native_GetSessionIssueInfo);
	CreateNative("CallVoteManager_GetSessionTally", Native_GetSessionTally);

	RegPluginLibrary(CALLVOTEMANAGER_LIBRARY);
	g_bLateLoad = bLate;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bBuiltinVotes = LibraryExists("BuiltinVotes");
	g_bConfogl = LibraryExists("confogl");
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "BuiltinVotes"))
		g_bBuiltinVotes = false;
	else if (StrEqual(sName, "confogl"))
		g_bConfogl = false;
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "BuiltinVotes"))
		g_bBuiltinVotes = true;
	else if (StrEqual(sName, "confogl"))
		g_bConfogl = true;
}

public void OnPluginStart()
{
	g_loc = new Localizer();

	LoadTranslation("callvote_manager.phrases");
	LoadTranslation("callvote_common.phrases");
	g_cvarLogMode							= CallVoteEnsureLogModeConVar();
	g_cvarDebugMask						= CreateConVar("sm_cvm_debug_mask", "0", "Debug mask for callvote_manager. Core=1 SQL=2 Cache=4 Commands=8 Identity=16 Forwards=32 Session=64 Localization=128 All=255.", FCVAR_NONE, true, 0.0, true, 255.0);
	g_Log									= new CallVoteLogger(CVM_LOG_TAG, CVM_LOG_FILE, g_cvarLogMode, g_cvarDebugMask);
	g_cvarEnable							= CreateConVar("sm_cvm_enable", "1", "Enable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarRegLog							= CreateConVar("sm_cvm_log_flags", "0", "logging flags <dificulty:1, restartgame:2, kick:4, changemission:8, lobby:16, chapter:32, alltalk:64, ALL:127>", FCVAR_NOTIFY, true, 0.0, true, 127.0);
	g_cvarBuiltinVote						= CreateConVar("sm_cvm_builtin_vote", "1", "<builtinvotes> support", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarAnnouncer							= CreateConVar("sm_cvm_announcer", "1", "Announce voting calls", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarProgress							= CreateConVar("sm_cvm_progress", "1", "Show voting progress", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarProgressAnonymous					= CreateConVar("sm_cvm_progress_anonymous", "0", "Show voting progress anonymously", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_cvarLobby								= CreateConVar("sm_cvm_lobby", "1", "Enable vote ReturnToLobby", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarChapter							= CreateConVar("sm_cvm_chapter", "1", "Enable vote ChangeChapter", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarAllTalk							= CreateConVar("sm_cvm_all_talk", "1", "Enable vote ChangeAllTalk", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_cvarAdminImmunity						= CreateConVar("sm_cvm_admin_immunity", "", "Admins are immune to kick votes. Specify admin flags or blank.", FCVAR_NOTIFY);
	g_cvarSTVImmunity						= CreateConVar("sm_cvm_stv_immunity", "1", "SourceTV is immune to votekick", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarSelfImmunity						= CreateConVar("sm_cvm_self_immunity", "1", "Immunity to self-kick", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarBotImmunity						= CreateConVar("sm_cvm_bot_immunity", "1", "Immunity to bots", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	sv_vote_issue_change_difficulty_allowed = FindConVar("sv_vote_issue_change_difficulty_allowed");
	sv_vote_issue_restart_game_allowed		= FindConVar("sv_vote_issue_restart_game_allowed");
	sv_vote_issue_change_mission_allowed	= FindConVar("sv_vote_issue_change_mission_allowed");
	sv_vote_issue_kick_allowed				= FindConVar("sv_vote_issue_kick_allowed");
	sv_vote_creation_timer					= FindConVar("sv_vote_creation_timer");
	z_difficulty							= FindConVar("z_difficulty");

	char sTempAdmin[32];

	g_cvarAdminImmunity.AddChangeHook(ConVarChanged_AdminImmunity);
	g_cvarAdminImmunity.GetString(sTempAdmin, sizeof(sTempAdmin));
	g_iFlagsAdmin = ReadFlagString(sTempAdmin);

	OnPluginStart_SQL();

	AddCommandListener(Listener_CallVote, "callvote");
	HookEvent("vote_started", Event_VoteStarted);
	HookEvent("vote_ended", Event_VoteEnded);
	HookEvent("vote_changed", Event_VoteChanged);
	HookEvent("vote_cast_yes", Event_VoteCastYes);
	HookEvent("vote_cast_no", Event_VoteCastNo);
	HookUserMessage(GetUserMessageId("CallVoteFailed"), Message_CallVoteFailed);

	CallVoteAutoExecConfig(true, "callvote_manager");
	InitializeVoteTypesMap();
	ResetVoteSession(g_CurrentVoteSession);
	ResetVoteSession(g_LastVoteSession);

	if (!g_bLateLoad)
		return;

	g_bBuiltinVotes = LibraryExists("BuiltinVotes");
	g_bConfogl = LibraryExists("confogl");
}

public void ConVarChanged_AdminImmunity(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	char sTempAdmin[32];
	g_cvarAdminImmunity.GetString(sTempAdmin, sizeof(sTempAdmin));
	g_iFlagsAdmin = ReadFlagString(sTempAdmin);

	ClearAdminFlagsCache();
}

public void OnPluginEnd()
{
	OnPluginEnd_SQL();

	if (g_mapVoteTypes != null)
		delete g_mapVoteTypes;

	if (g_Log != null)
		delete g_Log;
}

public void OnConfigsExecuted()
{
	if (!g_cvarEnable.BoolValue)
		return;

	OnConfigsExecuted_SQL();
}

public void OnMapStart()
{
	g_fLastVote = 0.0;
	ResetVoteSession(g_CurrentVoteSession);
	ResetVoteSession(g_LastVoteSession);
	g_bCurrentVoteSessionValid = false;
	g_bLastVoteSessionValid = false;
}

/**
 * Process a vote by validating restrictions, forwarding, and handling rejection.
 * Consolidates the repetitive logic used in Listener_CallVote.
 *
 * @param iClient        Client initiating the vote
 * @param type          Type of vote
 * @param iTarget       Target client (for kick votes, SERVER_INDEX for others)
 * @param sArgument     Vote argument (for votes that require one)
 * @return              Plugin_Handled if vote was processed/rejected, Plugin_Continue otherwise
 */
Action ProcessVoteCommon(int iClient, TypeVotes type, int iTarget = SERVER_INDEX, const char[] sArgument = "")
{
	BeginVoteSession(iClient, type, iTarget, sArgument);

	Action preStartResult;
	if (type == Kick)
		preStartResult = ForwardCallVotePreStart(iClient, type, iTarget);
	else
		preStartResult = ForwardCallVotePreStart(iClient, type);

	Action preStartExResult = ForwardCallVotePreStartEx();
	if (preStartResult >= Plugin_Handled)
	{
		CVLog.Forwards("[ProcessVoteCommon] Vote blocked by PreStart forward for client %d", iClient);
		g_CurrentVoteSession.status = CallVoteSession_Blocked;
		g_CurrentVoteSession.restriction = VoteRestriction_Plugin;
		CVLog.Event("VoteBlocked", "session=%d callerAccountId=%d voteType=%d stage=PreStart restriction=%d target=%d argument=%s",
			g_CurrentVoteSession.sessionId,
			g_CurrentVoteSession.callerAccountId,
			g_CurrentVoteSession.voteType,
			VoteRestriction_Plugin,
			g_CurrentVoteSession.targetAccountId,
			g_CurrentVoteSession.argumentRaw);
		ForwardCallVoteBlockedEx(VoteRestriction_Plugin);
		ArchiveCurrentVoteSession();
		return Plugin_Handled;
	}

	if (preStartExResult >= Plugin_Handled)
	{
		CVLog.Forwards("[ProcessVoteCommon] Vote blocked by PreStartEx forward for client %d", iClient);
		g_CurrentVoteSession.status = CallVoteSession_Blocked;
		g_CurrentVoteSession.restriction = VoteRestriction_Plugin;
		CVLog.Event("VoteBlocked", "session=%d callerAccountId=%d voteType=%d stage=PreStartEx restriction=%d target=%d argument=%s",
			g_CurrentVoteSession.sessionId,
			g_CurrentVoteSession.callerAccountId,
			g_CurrentVoteSession.voteType,
			VoteRestriction_Plugin,
			g_CurrentVoteSession.targetAccountId,
			g_CurrentVoteSession.argumentRaw);
		ForwardCallVoteBlockedEx(VoteRestriction_Plugin);
		ArchiveCurrentVoteSession();
		return Plugin_Handled;
	}

	VoteRestrictionType restriction;
	if (type == Kick)
		restriction = ValidateVote(iClient, type, iTarget);
	else if (sArgument[0] != '\0')
		restriction = ValidateVote(iClient, type, 0, sArgument);
	else
		restriction = ValidateVote(iClient, type);

	if (restriction != VoteRestriction_None)
	{
		g_CurrentVoteSession.status = CallVoteSession_Blocked;
		g_CurrentVoteSession.restriction = restriction;
		CVLog.Event("VoteBlocked", "session=%d callerAccountId=%d voteType=%d stage=Validation restriction=%d target=%d argument=%s",
			g_CurrentVoteSession.sessionId,
			g_CurrentVoteSession.callerAccountId,
			g_CurrentVoteSession.voteType,
			restriction,
			g_CurrentVoteSession.targetAccountId,
			g_CurrentVoteSession.argumentRaw);
		if (type == Kick)
		{
			ForwardCallVoteBlocked(iClient, type, restriction, iTarget);
			SendRestrictionFeedback(iClient, restriction, type, iTarget);
		}
		else
		{
			ForwardCallVoteBlocked(iClient, type, restriction);
			SendRestrictionFeedback(iClient, restriction, type);
		}
		ForwardCallVoteBlockedEx(restriction);
		ArchiveCurrentVoteSession();
		return Plugin_Handled;
	}

	Action preExecuteResult;
	if (type == Kick)
		preExecuteResult = ForwardCallVotePreExecute(iClient, type, iTarget);
	else
		preExecuteResult = ForwardCallVotePreExecute(iClient, type);

	Action preExecuteExResult = ForwardCallVotePreExecuteEx();
	if (preExecuteResult >= Plugin_Handled)
	{
		CVLog.Forwards("[ProcessVoteCommon] Vote blocked by PreExecute forward for client %d", iClient);
		g_CurrentVoteSession.status = CallVoteSession_Blocked;
		g_CurrentVoteSession.restriction = VoteRestriction_Plugin;
		CVLog.Event("VoteBlocked", "session=%d callerAccountId=%d voteType=%d stage=PreExecute restriction=%d target=%d argument=%s",
			g_CurrentVoteSession.sessionId,
			g_CurrentVoteSession.callerAccountId,
			g_CurrentVoteSession.voteType,
			VoteRestriction_Plugin,
			g_CurrentVoteSession.targetAccountId,
			g_CurrentVoteSession.argumentRaw);
		ForwardCallVoteBlockedEx(VoteRestriction_Plugin);
		ArchiveCurrentVoteSession();
		return Plugin_Handled;
	}

	if (preExecuteExResult >= Plugin_Handled)
	{
		CVLog.Forwards("[ProcessVoteCommon] Vote blocked by PreExecuteEx forward for client %d", iClient);
		g_CurrentVoteSession.status = CallVoteSession_Blocked;
		g_CurrentVoteSession.restriction = VoteRestriction_Plugin;
		CVLog.Event("VoteBlocked", "session=%d callerAccountId=%d voteType=%d stage=PreExecuteEx restriction=%d target=%d argument=%s",
			g_CurrentVoteSession.sessionId,
			g_CurrentVoteSession.callerAccountId,
			g_CurrentVoteSession.voteType,
			VoteRestriction_Plugin,
			g_CurrentVoteSession.targetAccountId,
			g_CurrentVoteSession.argumentRaw);
		ForwardCallVoteBlockedEx(VoteRestriction_Plugin);
		ArchiveCurrentVoteSession();
		return Plugin_Handled;
	}

	if (type == Kick)
	{
		ForwardCallVoteStart(iClient, type, iTarget);
	}
	else
	{
		ForwardCallVoteStart(iClient, type);
	}

	return Plugin_Continue;
}

/**
 * Initialize the vote types StringMap for fast O(1) lookups
 */
void InitializeVoteTypesMap()
{
	g_mapVoteTypes = new StringMap();

	g_mapVoteTypes.SetValue("changedifficulty", ChangeDifficulty);
	g_mapVoteTypes.SetValue("restartgame", RestartGame);
	g_mapVoteTypes.SetValue("kick", Kick);
	g_mapVoteTypes.SetValue("changemission", ChangeMission);
	g_mapVoteTypes.SetValue("returntolobby", ReturnToLobby);
	g_mapVoteTypes.SetValue("changechapter", ChangeChapter);
	g_mapVoteTypes.SetValue("changealltalk", ChangeAllTalk);
}

/**
 * Get vote type enum from string using fast StringMap lookup
 * @param sVoteType Vote type string
 * @param voteType Output vote type enum
 * @return True if vote type was found, false otherwise
 */
bool GetVoteTypeFromString(const char[] sVoteType, TypeVotes &voteType)
{
	char sLowerVoteType[32];
	strcopy(sLowerVoteType, sizeof(sLowerVoteType), sVoteType);

	for (int i = 0; sLowerVoteType[i] != '\0'; i++)
	{
		sLowerVoteType[i] = CharToLower(sLowerVoteType[i]);
	}

	int value;
	if (g_mapVoteTypes.GetValue(sLowerVoteType, value))
	{
		voteType = view_as<TypeVotes>(value);
		return true;
	}

	return false;
}

/**
 * Intercept the voting call
 * @param client Client index
 * @param command Command name
 * @param args Arguments
 * @return Plugin_Continue if the vote is allowed, Plugin_Handled otherwise
 */
Action Listener_CallVote(int iClient, const char[] sCommand, int iArgs)
{
	if (!g_cvarEnable.BoolValue)
		return Plugin_Continue;

	char sFullArgs[128];
	GetCmdArgString(sFullArgs, sizeof(sFullArgs));
	CVLog.Debug("[Listener_CallVote] Full argument string: %s", sFullArgs);

	if (GetCmdArgs() == 0)
	{
		return Plugin_Continue;
	}

	if (iClient == SERVER_INDEX)
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "ValidClientOnly");
		return Plugin_Handled;
	}

	if (L4D_GetClientTeam(iClient) == L4DTeam_Spectator)
	{
		CPrintToChat(iClient, "%t %t", "Tag", "SpecVote");
		return Plugin_Handled;
	}

	if (g_bBuiltinVotes && g_cvarBuiltinVote.BoolValue && !IsNewBuiltinVoteAllowed)
	{
		CPrintToChat(iClient, "%t %t", "Tag", "TryAgain", CheckBuiltinVoteDelay());
		return Plugin_Handled;
	}

	float fDifLastVote = GetEngineTime() - g_fLastVote;
	if (fDifLastVote <= 5.5)
	{
		CPrintToChat(iClient, "%t %t", "Tag", "TryAgain", RoundFloat(5.5 - fDifLastVote));
		return Plugin_Handled;
	}
	else if (fDifLastVote <= sv_vote_creation_timer.FloatValue)
	{
		CPrintToChat(iClient, "%t %t", "Tag", "TryAgain", RoundFloat(sv_vote_creation_timer.FloatValue - fDifLastVote));
		return Plugin_Handled;
	}

	char sVoteType[32];
	char sVoteArgument[32];

	GetCmdArg(1, sVoteType, sizeof(sVoteType));
	GetCmdArg(2, sVoteArgument, sizeof(sVoteArgument));

	TypeVotes voteType;
	if (!GetVoteTypeFromString(sVoteType, voteType))
	{
		return Plugin_Continue;
	}

	switch (voteType)
	{
		case ChangeDifficulty:
		{
			if (iArgs != 2)
				return Plugin_Continue;

			Action result = ProcessVoteCommon(iClient, ChangeDifficulty, SERVER_INDEX, sVoteArgument);
			if (result == Plugin_Handled)
				return Plugin_Handled;

			PrintLocalizedDifficulty(sVoteArgument, iClient);
		}
		case RestartGame:
		{
			if (iArgs != 1)
				return Plugin_Continue;

			Action result = ProcessVoteCommon(iClient, RestartGame);
			if (result == Plugin_Handled)
				return Plugin_Handled;

			PrintLocalizedRestartGame(iClient);
		}
		case Kick:
		{
			int iTarget = GetClientOfUserId(GetCmdArgInt(2));

			if (iTarget == SERVER_INDEX)
				return Plugin_Handled;

			Action result = ProcessVoteCommon(iClient, Kick, iTarget);
			if (result == Plugin_Handled)
				return Plugin_Handled;

			PrintLocalizedKick(iClient, iTarget);
		}
		case ChangeMission:
		{
			if (iArgs != 2)
				return Plugin_Continue;

			Action result = ProcessVoteCommon(iClient, ChangeMission, SERVER_INDEX, sVoteArgument);
			if (result == Plugin_Handled)
				return Plugin_Handled;

			CVLog.Debug("[Listener_CallVote] Forwarded ChangeMission vote for client %N [%s]", iClient, sVoteArgument);
			PrintLocalizedMissionName(sVoteArgument, iClient);
		}
		case ReturnToLobby:
		{
			if (iArgs != 1)
				return Plugin_Continue;

			Action result = ProcessVoteCommon(iClient, ReturnToLobby);
			if (result == Plugin_Handled)
				return Plugin_Handled;

			PrintLocalizedReturnToLobby(iClient);
		}
		case ChangeChapter:
		{
			if (iArgs != 2)
				return Plugin_Continue;

			Action result = ProcessVoteCommon(iClient, ChangeChapter, SERVER_INDEX, sVoteArgument);
			if (result == Plugin_Handled)
				return Plugin_Handled;

			CVLog.Debug("[Listener_CallVote] Forwarded ChangeChapter vote for client %N [%s]", iClient, sVoteArgument);
			PrintLocalizedChapterName(sVoteArgument, iClient);
		}
		case ChangeAllTalk:
		{
			if (iArgs != 1)
				return Plugin_Continue;

			Action result = ProcessVoteCommon(iClient, ChangeAllTalk);
			if (result == Plugin_Handled)
				return Plugin_Handled;

			PrintLocalizedAllTalk(iClient);
		}
	}

	g_fLastVote = GetEngineTime();
	return Plugin_Continue;
}

/*****************************************************************
			V A L I D A T I O N   S Y S T E M
*****************************************************************/

/**
 * Validates whether a vote type is allowed by game mode restrictions
 *
 * @param voteType The type of vote to validate
 * @return True if allowed by game mode, false otherwise
 */
bool IsVoteAllowedByGameMode(TypeVotes voteType)
{
	int gameMode = L4D_GetGameModeType();

	switch (gameMode)
	{
		case GAMEMODE_COOP:
		{
			if (voteType == ChangeAllTalk || voteType == ChangeChapter)
				return false;
		}
		case GAMEMODE_VERSUS:
		{
			if (voteType == ChangeDifficulty || voteType == ChangeChapter)
				return false;
		}
		case GAMEMODE_SURVIVAL:
		{
			if (voteType == ChangeAllTalk || voteType == ChangeDifficulty || voteType == ChangeMission)
				return false;
		}
		case GAMEMODE_SCAVENGE:
		{
			if (voteType == ChangeDifficulty || voteType == ChangeMission || voteType == RestartGame)
				return false;
		}
	}

	return true;
}

/**
 * Validates whether a vote type is allowed by ConVar settings
 *
 * @param voteType The type of vote to validate
 * @return True if allowed by ConVar, false otherwise
 */
bool IsVoteAllowedByConVar(TypeVotes voteType)
{
	switch (voteType)
	{
		case ChangeDifficulty:
			return sv_vote_issue_change_difficulty_allowed.BoolValue;

		case RestartGame:
			return sv_vote_issue_restart_game_allowed.BoolValue;

		case Kick:
			return sv_vote_issue_kick_allowed.BoolValue;

		case ChangeMission:
			return sv_vote_issue_change_mission_allowed.BoolValue;

		case ReturnToLobby:
			return g_cvarLobby.BoolValue;

		case ChangeChapter:
			return g_cvarChapter.BoolValue;

		case ChangeAllTalk:
			return g_cvarAllTalk.BoolValue;
	}

	return false;
}

/**
 * Validates whether a vote is allowed for a specific client and target
 *
 * @param client The client who initiated the vote
 * @param voteType The type of vote
 * @param target The target of the vote (for kick votes, 0 for others)
 * @param argument The vote argument (difficulty, map name, etc.)
 * @return VoteRestrictionType indicating the type of restriction, or VoteRestriction_None if allowed
 */
VoteRestrictionType ValidateVote(int client, TypeVotes voteType, int target = 0, const char[] argument = "")
{
	if (!IsVoteAllowedByConVar(voteType))
	{
		return VoteRestriction_ConVar;
	}

	if (!IsVoteAllowedByGameMode(voteType))
	{
		return VoteRestriction_GameMode;
	}

	switch (voteType)
	{
		case ChangeDifficulty:
		{
			if (strlen(argument) > 0)
			{
				char sCVarDifficulty[32];
				z_difficulty.GetString(sCVarDifficulty, sizeof(sCVarDifficulty));

				if (StrEqual(argument, sCVarDifficulty, false))
				{
					return VoteRestriction_SameState;
				}
			}
		}

		case Kick:
		{
			if (target <= NO_INDEX)
				return VoteRestriction_Target;

			if (g_cvarSTVImmunity.BoolValue && IsClientConnected(target) && IsClientSourceTV(target))
			{
				return VoteRestriction_Immunity;
			}

			if (g_cvarBotImmunity.BoolValue && IsClientConnected(target) && IsFakeClient(target))
			{
				return VoteRestriction_Immunity;
			}

			if (g_cvarSelfImmunity.BoolValue && target == client)
			{
				return VoteRestriction_Immunity;
			}

			L4DTeam clientTeam = L4D_GetClientTeam(client);
			L4DTeam targetTeam = L4D_GetClientTeam(target);

			if (clientTeam != targetTeam)
			{
				return VoteRestriction_Team;
			}

			if (!CanKick(client) && IsAdmin(target))
			{
				return VoteRestriction_Immunity;
			}
		}
	}

	return VoteRestriction_None;
}

/**
 * Sends appropriate feedback message to client based on restriction type
 *
 * @param client The client to send the message to
 * @param restrictionType The type of restriction encountered
 * @param voteType The type of vote that was restricted
 * @param target The target of the vote (for kick votes)
 */
void SendRestrictionFeedback(int client, VoteRestrictionType restrictionType, TypeVotes voteType, int target = 0)
{
	switch (restrictionType)
	{
		case VoteRestriction_ConVar:
		{
			char sTranslation[LC_MAX_TRANSLATION_LENGTH];

			if (Lang_GetValveTranslation(client, "#L4D_vote_server_disabled_issue", sTranslation, sizeof(sTranslation), g_loc))
			{
				CPrintToChat(client, "%t %s", "Tag", sTranslation);
				return;
			}

			CPrintToChat(client, "%t %t", "Tag", "VoteDisabled");
		}

		case VoteRestriction_GameMode:
		{
			CPrintToChat(client, "%t %t", "Tag", "VoteNotAllowedInGameMode");
		}

		case VoteRestriction_SameState:
		{
			switch (voteType)
			{
				case ChangeDifficulty:
					CPrintToChat(client, "%t %t", "Tag", "SameDifficulty");
			}
		}

		case VoteRestriction_Immunity:
		{
			switch (voteType)
			{
				case Kick:
				{
					if (target > 0)
					{
						if (IsClientSourceTV(target))
							CPrintToChat(client, "%t %t", "Tag", "SourceTVKick");
						else if (IsFakeClient(target))
							CPrintToChat(client, "%t %t", "Tag", "BotKick");
						else if (target == client)
							CPrintToChat(client, "%t %t", "Tag", "KickSelf");
						else if (IsAdmin(target))
						{
							CPrintToChat(client, "%t %t", "Tag", "Inmunity");
							CPrintToChat(target, "%t %t", "Tag", "InmunityTarget", client);
						}
					}
				}
			}
		}

		case VoteRestriction_Team:
		{
			if (voteType == Kick)
				CPrintToChat(client, "%t %t", "Tag", "KickDifferentTeam");
		}

		case VoteRestriction_Target:
		{
			if (voteType == Kick)
				CPrintToChat(client, "%t %t", "Tag", "InvalidTarget");
		}
	}
}

/*****************************************************************
			C A L L B A C K S
*****************************************************************/

void Event_VoteStarted(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bCurrentVoteSessionValid)
		return;

	event.GetString("issue", g_CurrentVoteSession.engineIssue, sizeof(g_CurrentVoteSession.engineIssue));
	event.GetString("param1", g_CurrentVoteSession.engineParam1, sizeof(g_CurrentVoteSession.engineParam1));
	event.GetString("param2", g_CurrentVoteSession.engineParam2, sizeof(g_CurrentVoteSession.engineParam2));
	g_CurrentVoteSession.engineTeam = event.GetInt("team");
	g_CurrentVoteSession.engineInitiatorClient = event.GetInt("initiator");
	g_CurrentVoteSession.status = CallVoteSession_Started;

	CVLog.Session("[Event_VoteStarted] session=%d issue=%s param1=%s param2=%s team=%d initiator=%d",
		g_CurrentVoteSession.sessionId,
		g_CurrentVoteSession.engineIssue,
		g_CurrentVoteSession.engineParam1,
		g_CurrentVoteSession.engineParam2,
		g_CurrentVoteSession.engineTeam,
		g_CurrentVoteSession.engineInitiatorClient);

	if (g_CurrentVoteSession.voteType == Kick)
	{
		RegVote(g_CurrentVoteSession.voteType, g_CurrentVoteSession.callerClient, g_CurrentVoteSession.targetClient);
		RegSQLVote(g_CurrentVoteSession.voteType, g_CurrentVoteSession.callerClient, g_CurrentVoteSession.targetClient);
	}
	else
	{
		RegVote(g_CurrentVoteSession.voteType, g_CurrentVoteSession.callerClient);
		RegSQLVote(g_CurrentVoteSession.voteType, g_CurrentVoteSession.callerClient);
	}

	ForwardCallVoteStartEx(g_CurrentVoteSession.sessionId);
}

void Event_VoteEnded(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bCurrentVoteSessionValid)
		return;

	int success = event.GetInt("success");
	g_CurrentVoteSession.engineTeam = event.GetInt("team");
	g_CurrentVoteSession.status = CallVoteSession_Ended;
	g_CurrentVoteSession.endReason = success ? CallVoteEnd_Passed : CallVoteEnd_Failed;

	CVLog.Session("[Event_VoteEnded] session=%d success=%d yes=%d no=%d potential=%d",
		g_CurrentVoteSession.sessionId,
		success,
		g_CurrentVoteSession.yesVotes,
		g_CurrentVoteSession.noVotes,
		g_CurrentVoteSession.potentialVotes);
	CVLog.Event("VoteResult", "session=%d callerAccountId=%d voteType=%d result=%d yes=%d no=%d potential=%d target=%d argument=%s",
		g_CurrentVoteSession.sessionId,
		g_CurrentVoteSession.callerAccountId,
		g_CurrentVoteSession.voteType,
		g_CurrentVoteSession.endReason,
		g_CurrentVoteSession.yesVotes,
		g_CurrentVoteSession.noVotes,
		g_CurrentVoteSession.potentialVotes,
		g_CurrentVoteSession.targetAccountId,
		g_CurrentVoteSession.argumentRaw);

	ForwardCallVoteEndEx(g_CurrentVoteSession.endReason);
	ArchiveCurrentVoteSession();
}

void Event_VoteChanged(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bCurrentVoteSessionValid)
		return;

	g_CurrentVoteSession.yesVotes = event.GetInt("yesVotes");
	g_CurrentVoteSession.noVotes = event.GetInt("noVotes");
	g_CurrentVoteSession.potentialVotes = event.GetInt("potentialVotes");

	CVLog.Session("[Event_VoteChanged] session=%d yes=%d no=%d potential=%d",
		g_CurrentVoteSession.sessionId,
		g_CurrentVoteSession.yesVotes,
		g_CurrentVoteSession.noVotes,
		g_CurrentVoteSession.potentialVotes);
}

public Action Message_CallVoteFailed(UserMsg hMsgId, BfRead hBf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	if (!g_bCurrentVoteSessionValid)
		return Plugin_Continue;

	if (!IsClientInRecipients(g_CurrentVoteSession.callerClient, iPlayers, iPlayersNum))
		return Plugin_Continue;

	int reason = hBf.ReadByte();
	int time = hBf.ReadShort();

	g_CurrentVoteSession.status = CallVoteSession_Ended;
	g_CurrentVoteSession.endReason = CallVoteEnd_Aborted;

	CVLog.Session("[Message_CallVoteFailed] session=%d caller=%d reason=%d time=%d",
		g_CurrentVoteSession.sessionId,
		g_CurrentVoteSession.callerClient,
		reason,
		time);
	CVLog.Event("VoteResult", "session=%d callerAccountId=%d voteType=%d result=%d reason=%d time=%d target=%d argument=%s",
		g_CurrentVoteSession.sessionId,
		g_CurrentVoteSession.callerAccountId,
		g_CurrentVoteSession.voteType,
		g_CurrentVoteSession.endReason,
		reason,
		time,
		g_CurrentVoteSession.targetAccountId,
		g_CurrentVoteSession.argumentRaw);

	ForwardCallVoteEndEx(g_CurrentVoteSession.endReason);
	ArchiveCurrentVoteSession();
	return Plugin_Continue;
}

/*
 * vote_cast_yes
 *
 *	"team"			"byte"
 *	"entityid"		"long"	// entity id of the voter
 *
 */
void Event_VoteCastYes(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarProgress.BoolValue)
		return;

	int iClient = event.GetInt("entityid");
	if (!IsValidClientIndex(iClient))
		return;

	L4DTeam Team = L4D_GetClientTeam(iClient);

	char	sTeamTranslation[64];
bool	bAnonymous = g_cvarProgressAnonymous.BoolValue;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		Lang_GetLocalizedTeamName(Team, i, sTeamTranslation, sizeof(sTeamTranslation), g_loc);

		if (bAnonymous)
			CPrintToChat(i, "%t %t", "Tag", "VoteCastAnon", sTeamTranslation, "{blue}F1{default}");
		else
			CPrintToChat(i, "%t %t", "Tag", "VoteCast", iClient, sTeamTranslation, "{blue}F1{default}");
	}
}

/*
 * vote_cast_no
 *
 * "team"			"byte"
 * "entityid"		"long"	// entity id of the voter
 *
 */
void Event_VoteCastNo(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarProgress.BoolValue)
		return;

	int iClient = event.GetInt("entityid");
	if (!IsValidClientIndex(iClient))
		return;

	L4DTeam Team = L4D_GetClientTeam(iClient);

	char	sTeamTranslation[64];
bool	bAnonymous = g_cvarProgressAnonymous.BoolValue;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		Lang_GetLocalizedTeamName(Team, i, sTeamTranslation, sizeof(sTeamTranslation), g_loc);

		if (bAnonymous)
			CPrintToChat(i, "%t %t", "Tag", "VoteCastAnon", sTeamTranslation, "{red}F2{default}");
		else
			CPrintToChat(i, "%t %t", "Tag", "VoteCast", iClient, sTeamTranslation, "{red}F2{default}");
	}
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

/**
 * Registers and logs a vote action initiated by a client.
 *
 * This function checks if vote logging is enabled and if the specific vote type should be logged.
 * It retrieves the client's authentication ID and name, formats the current time, and logs the vote action.
 * If the vote type is Kick and the target is a human, it also retrieves and logs the target's information.
 *
 * @param type      The type of vote being registered (TypeVotes enum).
 * @param iClient   The client index of the player who initiated the vote.
 * @param iTarget   (Optional) The client index of the target player. Defaults to SERVER_INDEX.
 *
 * Logs detailed information about the vote to the configured log file.
 */
void RegVote(TypeVotes type, int iClient, int iTarget = SERVER_INDEX)
{
	if (!g_cvarRegLog.BoolValue)
		return;

	VoteType iVoteFlag = VOTE_NONE;
	iVoteFlag = GetVoteFlag(type);
	if (iVoteFlag == VOTE_NONE)
		return;

	if (!(g_cvarRegLog.IntValue & view_as<int>(iVoteFlag)))
		return;

	char sAuthID_Client[MAX_AUTHID_LENGTH];
	int iCallerAccountId = 0;
	if (g_bCurrentVoteSessionValid && g_CurrentVoteSession.callerClient == iClient)
		iCallerAccountId = g_CurrentVoteSession.callerAccountId;

	if (iCallerAccountId <= 0)
		iCallerAccountId = GetClientAccountID(iClient);

	if (iCallerAccountId <= 0 || !AccountIDToSteamID2(iCallerAccountId, sAuthID_Client, sizeof(sAuthID_Client)))
	{
		CVLog.Debug("[RegVote] Skipping vote log because caller identity is unavailable for client %N", iClient);
		return;
	}

	char sClientName[MAX_NAME_LENGTH];
	GetClientName(iClient, sClientName, sizeof(sClientName));

	char sTime[32];
	FormatTime(sTime, sizeof(sTime), "%Y-%m-%d %H:%M:%S", GetTime());

	char sLogMessage[512];
	if (type == Kick && IsHuman(iTarget))
	{
		char sAuthID_Target[MAX_AUTHID_LENGTH];
		int iTargetAccountId = 0;
		if (g_bCurrentVoteSessionValid && g_CurrentVoteSession.targetClient == iTarget)
			iTargetAccountId = g_CurrentVoteSession.targetAccountId;

		if (iTargetAccountId <= 0)
			iTargetAccountId = GetClientAccountID(iTarget);

		if (iTargetAccountId <= 0 || !AccountIDToSteamID2(iTargetAccountId, sAuthID_Target, sizeof(sAuthID_Target)))
		{
			CVLog.Debug("[RegVote] Skipping vote log because target identity is unavailable for client %d", iTarget);
			return;
		}

		char sTargetName[MAX_NAME_LENGTH];
		GetClientName(iTarget, sTargetName, sizeof(sTargetName));

		Format(sLogMessage, sizeof(sLogMessage),
			   "[%s] %s (%s) called vote %s against %s (%s)",
			   sTime, sClientName, sAuthID_Client, sTypeVotes[type], sTargetName, sAuthID_Target);
	}
	else
	{
		Format(sLogMessage, sizeof(sLogMessage),
			   "[%s] %s (%s) called vote %s",
			   sTime, sClientName, sAuthID_Client, sTypeVotes[type]);
	}

	CVLog.Event("Vote", "%s", sLogMessage);
}

/**
 * Checks if the specified client index corresponds to a connected human player.
 *
 * @param iClient  The client index to check.
 * @return         True if the client is a connected human player, false otherwise.
 */
bool IsHuman(int iClient)
{
	if (iClient < 1 || iClient > MaxClients)
		return false;

	if (!IsClientConnected(iClient) || IsFakeClient(iClient))
		return false;

	return true;
}

/**
 * @brief Check if a client has specific admin flags or root access
 * @param client		Client index
 * @param flags			Admin flags to check (0 = no flags required, just check root)
 * @return				True if client has the required flags or root access
 */
bool HasAdminFlags(int client, int flags = 0)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return false;

	int clientFlags;
	if (g_bClientFlagsCached[client])
	{
		clientFlags = g_iClientFlagsCache[client];
	}
	else
	{
		clientFlags					 = GetUserFlagBits(client);
		g_iClientFlagsCache[client]	 = clientFlags;
		g_bClientFlagsCached[client] = true;
	}

	if (clientFlags & ADMFLAG_ROOT)
		return true;

	if (flags == 0)
		return (clientFlags != 0);

	return (clientFlags & flags) != 0;
}

/**
 * @brief Check if a client has admin immunity flags
 * @param client		Client index
 * @return				True if client has admin immunity or root access
 */
bool IsAdmin(int client)
{
	CVLog.Debug("[IsAdmin] Checking %N for admin immunity flags: %d", client, g_iFlagsAdmin);
	return HasAdminFlags(client, g_iFlagsAdmin);
}

/**
 * @brief Check if a client has kick permissions
 * @param client		Client index
 * @return				True if client can kick other players
 */
bool CanKick(int client)
{
	return HasAdminFlags(client, FlagToBit(Admin_Kick));
}

public void OnClientDisconnect(int client)
{
	ClearClientAdminFlagsCache(client);
}

/*****************************************************************
			N A T I V E S   A N D   F O R W A R D S
*****************************************************************/

/**
 * Forward for CallVote_PreStart - allows blocking votes before validation
 */
Action ForwardCallVotePreStart(int iClient, TypeVotes voteType, int target = 0)
{
	Action result = Plugin_Continue;
	
	Call_StartForward(g_ForwardCallVotePreStart);
	Call_PushCell(iClient);
	Call_PushCell(voteType);
	Call_PushCell(target);
	Call_Finish(result);
	
	CVLog.Forwards("[ForwardCallVotePreStart] Forward called for client %d, vote type %d, target %d. Result: %d", 
		iClient, view_as<int>(voteType), target, view_as<int>(result));
	
	return result;
}

Action ForwardCallVotePreStartEx()
{
	if (!g_bCurrentVoteSessionValid)
		return Plugin_Continue;

	Action result = Plugin_Continue;

	Call_StartForward(g_ForwardCallVotePreStartEx);
	Call_PushCell(g_CurrentVoteSession.sessionId);
	Call_PushCell(g_CurrentVoteSession.callerClient);
	Call_PushCell(g_CurrentVoteSession.callerAccountId);
	Call_PushCell(g_CurrentVoteSession.voteType);
	Call_PushCell(g_CurrentVoteSession.targetClient);
	Call_PushCell(g_CurrentVoteSession.targetAccountId);
	Call_PushString(g_CurrentVoteSession.argumentRaw);
	Call_Finish(result);

	CVLog.Forwards("[ForwardCallVotePreStartEx] session=%d result=%d",
		g_CurrentVoteSession.sessionId,
		view_as<int>(result));

	return result;
}

/**
 * Forward for CallVote_Start - informational, announces vote start
 */
void ForwardCallVoteStart(int iClient, TypeVotes voteType, int target = 0)
{
	Call_StartForward(g_ForwardCallVoteStart);
	Call_PushCell(iClient);
	Call_PushCell(voteType);
	Call_PushCell(target);
	Call_Finish();
	
	CVLog.Forwards("[ForwardCallVoteStart] Vote started by client %d, vote type %d, target %d", 
		iClient, view_as<int>(voteType), target);
}

void ForwardCallVoteStartEx(int sessionId)
{
	Call_StartForward(g_ForwardCallVoteStartEx);
	Call_PushCell(sessionId);
	Call_Finish();

	CVLog.Forwards("[ForwardCallVoteStartEx] session=%d", sessionId);
}

/**
 * Forward for CallVote_PreExecute - allows blocking votes after validation but before execution
 */
Action ForwardCallVotePreExecute(int iClient, TypeVotes voteType, int target = 0)
{
	Action result = Plugin_Continue;
	
	Call_StartForward(g_ForwardCallVotePreExecute);
	Call_PushCell(iClient);
	Call_PushCell(voteType);
	Call_PushCell(target);
	Call_Finish(result);
	
	CVLog.Forwards("[ForwardCallVotePreExecute] Forward called for client %d, vote type %d, target %d. Result: %d", 
		iClient, view_as<int>(voteType), target, view_as<int>(result));
	
	return result;
}

Action ForwardCallVotePreExecuteEx()
{
	if (!g_bCurrentVoteSessionValid)
		return Plugin_Continue;

	Action result = Plugin_Continue;

	Call_StartForward(g_ForwardCallVotePreExecuteEx);
	Call_PushCell(g_CurrentVoteSession.sessionId);
	Call_PushCell(g_CurrentVoteSession.callerClient);
	Call_PushCell(g_CurrentVoteSession.callerAccountId);
	Call_PushCell(g_CurrentVoteSession.voteType);
	Call_PushCell(g_CurrentVoteSession.targetClient);
	Call_PushCell(g_CurrentVoteSession.targetAccountId);
	Call_PushString(g_CurrentVoteSession.argumentRaw);
	Call_Finish(result);

	CVLog.Forwards("[ForwardCallVotePreExecuteEx] session=%d result=%d",
		g_CurrentVoteSession.sessionId,
		view_as<int>(result));

	return result;
}

/**
 * Forward for CallVote_Blocked - informational when vote is blocked
 */
void ForwardCallVoteBlocked(int iClient, TypeVotes voteType, VoteRestrictionType restriction, int target = 0)
{
	Call_StartForward(g_ForwardCallVoteBlocked);
	Call_PushCell(iClient);
	Call_PushCell(voteType);
	Call_PushCell(restriction);
	Call_PushCell(target);
	Call_Finish();
	
	CVLog.Forwards("[ForwardCallVoteBlocked] Vote blocked for client %d, vote type %d, restriction %d, target %d", 
		iClient, view_as<int>(voteType), view_as<int>(restriction), target);
}

void ForwardCallVoteBlockedEx(VoteRestrictionType restriction)
{
	if (!g_bCurrentVoteSessionValid)
		return;

	Call_StartForward(g_ForwardCallVoteBlockedEx);
	Call_PushCell(g_CurrentVoteSession.sessionId);
	Call_PushCell(g_CurrentVoteSession.callerClient);
	Call_PushCell(g_CurrentVoteSession.callerAccountId);
	Call_PushCell(g_CurrentVoteSession.voteType);
	Call_PushCell(restriction);
	Call_PushCell(g_CurrentVoteSession.targetClient);
	Call_PushCell(g_CurrentVoteSession.targetAccountId);
	Call_PushString(g_CurrentVoteSession.argumentRaw);
	Call_Finish();

	CVLog.Forwards("[ForwardCallVoteBlockedEx] session=%d restriction=%d",
		g_CurrentVoteSession.sessionId,
		view_as<int>(restriction));
}

void ForwardCallVoteEndEx(CallVoteEndReason endReason)
{
	if (!g_bCurrentVoteSessionValid)
		return;

	Call_StartForward(g_ForwardCallVoteEndEx);
	Call_PushCell(g_CurrentVoteSession.sessionId);
	Call_PushCell(endReason);
	Call_PushCell(g_CurrentVoteSession.yesVotes);
	Call_PushCell(g_CurrentVoteSession.noVotes);
	Call_PushCell(g_CurrentVoteSession.potentialVotes);
	Call_Finish();

	CVLog.Forwards("[ForwardCallVoteEndEx] session=%d result=%d yes=%d no=%d potential=%d",
		g_CurrentVoteSession.sessionId,
		view_as<int>(endReason),
		g_CurrentVoteSession.yesVotes,
		g_CurrentVoteSession.noVotes,
		g_CurrentVoteSession.potentialVotes);
}

/**
 * Native: CallVoteManager_IsVoteAllowedByConVar
 */
int Native_IsVoteAllowedByConVar(Handle plugin, int numParams)
{
	TypeVotes voteType = view_as<TypeVotes>(GetNativeCell(1));
	
	if (voteType < ChangeDifficulty || voteType >= TypeVotes_Size)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid vote type (%d)", view_as<int>(voteType));
	}
	
	return IsVoteAllowedByConVar(voteType);
}

/**
 * Native: CallVoteManager_IsVoteAllowedByGameMode
 */
int Native_IsVoteAllowedByGameMode(Handle plugin, int numParams)
{
	TypeVotes voteType = view_as<TypeVotes>(GetNativeCell(1));
	
	if (voteType < ChangeDifficulty || voteType >= TypeVotes_Size)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid vote type (%d)", view_as<int>(voteType));
	}
	
	return IsVoteAllowedByGameMode(voteType);
}

int Native_GetClientAccountID(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsValidClientIndex(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}

	return GetClientAccountID(client);
}

int Native_GetClientSteamID2(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int maxlen = GetNativeCell(3);
	char steamId2[MAX_AUTHID_LENGTH];
	steamId2[0] = '\0';

	if (!IsValidClientIndex(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}

	bool result = AccountIDToSteamID2(GetClientAccountID(client), steamId2, sizeof(steamId2));
	SetNativeString(2, steamId2, maxlen, true);
	return result;
}

int Native_GetCurrentSession(Handle plugin, int numParams)
{
	if (!g_bCurrentVoteSessionValid)
		return 0;

	return g_CurrentVoteSession.sessionId;
}

int Native_GetSessionInfo(Handle plugin, int numParams)
{
	int sessionId = GetNativeCell(1);
	CVVoteSession session;

	if (!TryGetNativeVoteSession(sessionId, session))
		return false;

	TypeVotes voteType = session.voteType;
	SetNativeCellRef(2, session.callerClient);
	SetNativeCellRef(3, session.callerAccountId);
	SetNativeCellRef(4, voteType);
	SetNativeCellRef(5, session.targetClient);
	SetNativeCellRef(6, session.targetAccountId);
	SetNativeString(7, session.argumentRaw, GetNativeCell(8), true);
	return true;
}

int Native_GetSessionSteamID64Info(Handle plugin, int numParams)
{
	int sessionId = GetNativeCell(1);
	char callerSteamID64[STEAMID64_EXACT_LENGTH + 1];
	char targetSteamID64[STEAMID64_EXACT_LENGTH + 1];

	if (sessionId <= 0)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid session id (%d)", sessionId);
	}

	if (!TryGetSessionSteamID64Info(sessionId, callerSteamID64, sizeof(callerSteamID64), targetSteamID64, sizeof(targetSteamID64)))
		return false;

	SetNativeString(2, callerSteamID64, GetNativeCell(3), true);
	SetNativeString(4, targetSteamID64, GetNativeCell(5), true);
	return true;
}

int Native_GetSessionIssueInfo(Handle plugin, int numParams)
{
	int sessionId = GetNativeCell(1);
	CVVoteSession session;

	if (!TryGetNativeVoteSession(sessionId, session))
		return false;

	SetNativeString(2, session.engineIssue, GetNativeCell(3), true);
	SetNativeString(4, session.engineParam1, GetNativeCell(5), true);
	SetNativeString(6, session.engineParam2, GetNativeCell(7), true);
	SetNativeCellRef(8, session.engineTeam);
	SetNativeCellRef(9, session.engineInitiatorClient);
	return true;
}

int Native_GetSessionTally(Handle plugin, int numParams)
{
	int sessionId = GetNativeCell(1);
	CVVoteSession session;

	if (!TryGetNativeVoteSession(sessionId, session))
		return false;

	CallVoteEndReason endReason = session.endReason;
	SetNativeCellRef(2, session.yesVotes);
	SetNativeCellRef(3, session.noVotes);
	SetNativeCellRef(4, session.potentialVotes);
	SetNativeCellRef(5, endReason);
	return true;
}

/**
 * Clear the admin flags cache for all clients
 */
void ClearAdminFlagsCache()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bClientFlagsCached[i] = false;
		g_iClientFlagsCache[i] = 0;
	}
}

/**
 * Clear the admin flags cache for a specific client
 */
void ClearClientAdminFlagsCache(int client)
{
	if (IsValidClientIndex(client))
	{
		g_bClientFlagsCached[client] = false;
		g_iClientFlagsCache[client] = 0;
	}
}
