#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <left4dhooks>
#include <callvote_core>
#include <steamidtools_helpers>

#include "callvote_core/model.sp"
#include "callvote_core/votetypes.sp"

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define PLUGIN_VERSION "2.0.0"
#define CVC_LOG_TAG "CVC"
#define CVC_LOG_FILE "callvote_core.log"

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
	g_ForwardCallVotePreStart,
	g_ForwardCallVoteStart,
	g_ForwardCallVotePreExecute,
	g_ForwardCallVoteBlocked,
	g_ForwardCallVoteEnd;

CallVoteLogger g_Log = null;
VoteRestrictionType g_PendingForwardRestriction = VoteRestriction_None;

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

/*****************************************************************
			L I B R A R Y   I N C L U D E S
*****************************************************************/

#include "callvote_core/session.sp"
#include "callvote_core/forwards.sp"
#include "callvote_core/events.sp"
#include "callvote_core/natives.sp"
#include "callvote_core/lifecycle.sp"
#include "callvote_core/listener.sp"
#include "callvote_core/sql.sp"

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
	g_ForwardCallVotePreStart = CreateGlobalForward("CallVote_PreStart", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_ForwardCallVoteStart = CreateGlobalForward("CallVote_Start", ET_Ignore, Param_Cell);
	g_ForwardCallVotePreExecute = CreateGlobalForward("CallVote_PreExecute", ET_Hook, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_ForwardCallVoteBlocked = CreateGlobalForward("CallVote_Blocked", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
	g_ForwardCallVoteEnd = CreateGlobalForward("CallVote_End", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

	CreateNative("CallVoteCore_SetPendingRestriction", Native_SetPendingRestriction);
	CreateNative("CallVoteCore_GetClientAccountID", Native_GetClientAccountID);
	CreateNative("CallVoteCore_GetClientSteamID2", Native_GetClientSteamID2);
	CreateNative("CallVoteCore_GetCurrentSession", Native_GetCurrentSession);
	CreateNative("CallVoteCore_GetSessionInfo", Native_GetSessionInfo);
	CreateNative("CallVoteCore_GetSessionSteamID64Info", Native_GetSessionSteamID64Info);
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
	g_cvarDebugMask						= CreateConVar("sm_cvc_debug_mask", "0", "Debug mask for callvote_core. Core=1 SQL=2 Cache=4 Commands=8 Identity=16 Forwards=32 Session=64 Localization=128 All=255.", FCVAR_NONE, true, 0.0, true, 255.0);
	g_Log									= new CallVoteLogger(CVC_LOG_TAG, CVC_LOG_FILE, g_cvarLogMode, g_cvarDebugMask);
	g_cvarEnable							= CreateConVar("sm_cvc_enable", "1", "Enable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarRegLog							= CreateConVar("sm_cvc_log_flags", "0", "logging flags <difficulty:1, restartgame:2, kick:4, changemission:8, lobby:16, chapter:32, alltalk:64, ALL:127>", FCVAR_NOTIFY, true, 0.0, true, 127.0);

	OnPluginStart_SQL();

	AddCommandListener(Listener_CallVote, "callvote");
	HookEvent("vote_started", Event_VoteStarted);
	HookEvent("vote_ended", Event_VoteEnded);
	HookEvent("vote_changed", Event_VoteChanged);
	HookUserMessage(GetUserMessageId("CallVoteFailed"), Message_CallVoteFailed);

	CallVoteAutoExecConfig(true, "callvote_core");
	InitializeVoteTypesMap();
	ResetVoteSession(g_CurrentVoteSession);
	ResetVoteSession(g_LastVoteSession);

	if (!g_bLateLoad)
		return;
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
	ResetVoteSession(g_CurrentVoteSession);
	ResetVoteSession(g_LastVoteSession);
	g_bCurrentVoteSessionValid = false;
	g_bLastVoteSessionValid = false;
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
int Native_SetPendingRestriction(Handle plugin, int numParams)
{
	VoteRestrictionType restriction = view_as<VoteRestrictionType>(GetNativeCell(1));
	g_PendingForwardRestriction = restriction;
	return 0;
}
