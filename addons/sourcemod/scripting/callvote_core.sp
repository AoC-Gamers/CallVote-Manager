#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4dhooks>
#include <callvote_core>

#include "callvote_core/model.sp"
#include "callvote_core/votetypes.sp"

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define PLUGIN_VERSION "3.0.0"
#define CVC_LOG_TAG "CVC"
#define CVC_LOG_FILE "callvote_core.log"
#define CVC_START_CONFIRM_TIMEOUT 3.0

ConVar
	g_cvarRegLog,
	g_cvarLogMode,
	g_cvarDebugMask,
	g_cvarEnable;

bool
	g_bLateLoad,
	g_bCurrentVoteSessionValid = false,
	g_bLastVoteSessionValid = false;

int
	g_iNextVoteSessionId = 1;

CVVoteSession
	g_CurrentVoteSession,
	g_LastVoteSession;

GlobalForward
	g_ForwardCallVoteStart,
	g_ForwardCallVoteBlocked,
	g_ForwardCallVoteEnd,
	g_ForwardCallVoteBallotCast;

CallVoteLogger g_Log = null;
// Candidate reason belongs exclusively to the consumer currently being invoked.
VoteRestrictionType g_PendingForwardRestriction = VoteRestriction_None;
Handle g_DecisionConsumer;
int g_DecisionSessionId;
int g_ForwardDispatchDepth;

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
		VFormat(sFormat, sizeof(sFormat), message, 3);
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

/*****************************************************************
			L I B R A R Y   I N C L U D E S
*****************************************************************/

#include "callvote_core/session.sp"
#include "callvote_core/decision.sp"
#include "callvote_core/forwards.sp"
#include "callvote_core/events.sp"
#include "callvote_core/natives.sp"
#include "callvote_core/lifecycle.sp"
#include "callvote_core/listener.sp"

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/
public Plugin myinfo =
{
	name		= "Call Vote Core",
	author		= "lechuga",
	description = "Core lifecycle and API for callvote",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/AoC-Gamers/CallVote-Manager"

}

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max)
{
	g_ForwardCallVoteStart = CreateGlobalForward("CallVote_Start", ET_Ignore, Param_Cell);
	g_ForwardCallVoteBlocked = CreateGlobalForward("CallVote_Blocked", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_ForwardCallVoteEnd = CreateGlobalForward("CallVote_End", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

	g_ForwardCallVoteBallotCast = CreateGlobalForward("CallVote_BallotCast", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

	CreateNative("CallVoteCore_SetPendingRestriction", Native_SetPendingRestriction);
	CreateNative("CallVoteCore_GetCurrentSession", Native_GetCurrentSession);
	CreateNative("CallVoteCore_GetSessionInfo", Native_GetSessionInfo);
	CreateNative("CallVoteCore_GetSessionState", Native_GetSessionState);
	CreateNative("CallVoteCore_GetSessionIssueInfo", Native_GetSessionIssueInfo);
	CreateNative("CallVoteCore_GetSessionFailureInfo", Native_GetSessionFailureInfo);
	CreateNative("CallVoteCore_GetSessionTally", Native_GetSessionTally);

	RegPluginLibrary(CALLVOTECORE_LIBRARY);
	g_bLateLoad = bLate;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslation("callvote_core.phrases");
	LoadTranslation("callvote_common.phrases");
	g_cvarLogMode							= CallVoteEnsureLogModeConVar();
	g_cvarDebugMask						= CreateConVar("sm_cvc_debug_mask", "0", "Debug mask for callvote_core. Core=1 Commands=8 Identity=16 Forwards=32 Session=64 Localization=128 All=249.", FCVAR_NONE, true, 0.0, true, 249.0);
	g_Log									= new CallVoteLogger(CVC_LOG_TAG, CVC_LOG_FILE, g_cvarLogMode, g_cvarDebugMask);
	g_cvarEnable							= CreateConVar("sm_cvc_enable", "1", "Enable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarRegLog							= CreateConVar("sm_cvc_log_flags", "0", "logging flags <difficulty:1, restartgame:2, kick:4, changemission:8, lobby:16, chapter:32, alltalk:64, ALL:127>", FCVAR_NOTIFY, true, 0.0, true, 127.0);

	AddCommandListener(Listener_CallVote, "callvote");
	HookEvent("vote_started", Event_VoteStarted);
	HookEvent("vote_ended", Event_VoteEnded);
	HookEvent("vote_changed", Event_VoteChanged);
	HookEvent("vote_cast_yes", Event_VoteCast);
	HookEvent("vote_cast_no", Event_VoteCast);
	HookEvent("vote_passed", Event_VoteResult);
	HookEvent("vote_failed", Event_VoteResult);
	HookUserMessage(GetUserMessageId("VoteStart"), Message_VoteStart);
	HookUserMessage(GetUserMessageId("CallVoteFailed"), Message_CallVoteFailed);
	HookUserMessage(GetUserMessageId("VotePass"), Message_VoteResult);
	HookUserMessage(GetUserMessageId("VoteFail"), Message_VoteResult);

	CallVoteAutoExecConfig(true, "callvote_core");
	InitializeVoteTypesMap();
	ResetVoteSession(g_CurrentVoteSession);
	ResetVoteSession(g_LastVoteSession);

	if (!g_bLateLoad)
		return;
}

public void OnPluginEnd()
{

	if (g_mapVoteTypes != null)
		delete g_mapVoteTypes;

	if (g_Log != null)
		delete g_Log;
}

public void OnConfigsExecuted()
{
	EnsureCallVoteDebugLogFolderForMode(g_cvarLogMode);

	if (!g_cvarEnable.BoolValue)
		return;

	char sDebugPath[PLATFORM_MAX_PATH];
	BuildCallVoteDebugLogPath(CVC_LOG_FILE, sDebugPath, sizeof(sDebugPath));

	CVLog.Debug("[OnConfigsExecuted] version=%s mode=%d mask=%d path=%s", PLUGIN_VERSION, g_cvarLogMode.IntValue, g_cvarDebugMask != null ? g_cvarDebugMask.IntValue : -1, sDebugPath);
}

public void OnMapEnd()
{
	FinalizeStaleCurrentVoteSession();
}

public void OnMapStart()
{
	ResetVoteSession(g_CurrentVoteSession);
	ResetVoteSession(g_LastVoteSession);
	g_bCurrentVoteSessionValid = false;
	g_bLastVoteSessionValid = false;
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

/** Optional operational diagnostics use AccountIDs, without SteamID conversions. */
void RegVote(TypeVotes type, int client, int target = SERVER_INDEX)
{
	if (!g_cvarRegLog.BoolValue || !(g_cvarRegLog.IntValue & view_as<int>(GetVoteFlag(type))))
		return;

	int callerAccountId = g_bCurrentVoteSessionValid ? g_CurrentVoteSession.callerAccountId : GetVoteClientAccountId(client);
	int targetAccountId = g_bCurrentVoteSessionValid ? g_CurrentVoteSession.targetAccountId : GetVoteClientAccountId(target);
	if (callerAccountId <= 0)
		return;

	if (type == Kick)
		CVLog.Event("Vote", "callerClient=%d callerAccountId=%d voteType=%s targetClient=%d targetAccountId=%d", client, callerAccountId, sTypeVotes[type], target, targetAccountId);
	else
		CVLog.Event("Vote", "callerClient=%d callerAccountId=%d voteType=%s", client, callerAccountId, sTypeVotes[type]);
}
