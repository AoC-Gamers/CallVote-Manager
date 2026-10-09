#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <left4dhooks>
#include <callvote_core>
#include <callvote_localizer>
#include <language_manager>
#include <campaign_manager>

#undef REQUIRE_PLUGIN
#include <builtinvotes>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "2.2.1"
#define CVM_LOG_TAG "CVM"
#define CVM_LOG_FILE "callvote_manager.log"
#define CALLVOTE_BUILTINVOTES_LIBRARY "BuiltinVotes"

ConVar
	g_cvarEnable,
	g_cvarLogMode,
	g_cvarDebugMask,
	g_cvarAnnouncer,
	g_cvarProgress,
	g_cvarProgressAnonymous,
	g_cvarBuiltinVote,
	g_cvarLobby,
	g_cvarChapter,
	g_cvarAllTalk,
	g_cvarAdminImmunity,
	g_cvarSTVImmunity,
	g_cvarSelfImmunity,
	g_cvarBotImmunity,
	sv_alltalk,
	sv_vote_creation_timer,
	sv_vote_issue_change_difficulty_allowed,
	sv_vote_issue_restart_game_allowed,
	sv_vote_issue_kick_allowed,
	sv_vote_issue_change_mission_allowed,
	z_difficulty;

Localizer g_loc;
CallVoteLogger g_Log = null;
int g_iFlagsAdmin;
enum struct ManagerRuntimeState
{
	bool lateLoad;
	bool hasBuiltinVotes;

	void Reset()
	{
		this.lateLoad = false;
		this.hasBuiltinVotes = false;
	}

	void DetectLibraries()
	{
		this.hasBuiltinVotes = LibraryExists(CALLVOTE_BUILTINVOTES_LIBRARY);
	}

	void SetLibraryAvailability(const char[] name, bool available)
	{
		if (!StrEqual(name, CALLVOTE_BUILTINVOTES_LIBRARY))
			return;
		this.hasBuiltinVotes = available;
	}
}

ManagerRuntimeState g_Runtime;
float g_fLastVote = -1.0;
int g_iActiveSession;
int g_iInitialYesCallerSerial;
int g_iRejectedSession;
int g_iRejectedCallerSerial;
int g_iRejectedTargetSerial;
int g_iRejectedCooldown;
VoteRestrictionType g_RejectedRestriction;

bool CVM_IsLiveClient(int client)
{
	return client >= 1 && client <= MaxClients && IsClientInGame(client);
}

bool CVM_MatchesSnapshotClient(int client, int accountId)
{
	if (!CVM_IsLiveClient(client))
		return false;
	if (IsFakeClient(client))
		return accountId == 0;
	return accountId > 0 && GetSteamAccountID(client) == accountId;
}

void CVM_ClearRejection()
{
	g_iRejectedSession = 0;
	g_iRejectedCallerSerial = 0;
	g_iRejectedTargetSerial = 0;
	g_iRejectedCooldown = 0;
	g_RejectedRestriction = VoteRestriction_None;
}

void CVM_ClearVoteState()
{
	g_iActiveSession = 0;
	g_iInitialYesCallerSerial = 0;
	CVM_ClearRejection();
}

methodmap CVMLog
{
	public static void Debug(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_Core, "Core", "%s", sFormat);
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

#define CVLog CVMLog

#include "callvote_manager/printlocalized.sp"
#include "callvote_manager/policy.sp"

public Plugin myinfo =
{
	name = "Call Vote Manager",
	author = "lechuga",
	description = "Default UX satellite for callvote_core",
	version = PLUGIN_VERSION,
	url = "https://github.com/AoC-Gamers/CallVote-Manager"
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max)
{
	g_Runtime.Reset();
	g_Runtime.lateLoad = bLate;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_loc = new Localizer();

	LoadTranslation("callvote_manager.phrases");
	LoadTranslation("callvote_common.phrases");

	g_cvarEnable = CreateConVar("sm_cvm_enable", "1", "Enable callvote_manager default policy and UX", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarLogMode = CallVoteEnsureLogModeConVar();
	g_cvarDebugMask = CreateConVar("sm_cvm_debug_mask", "0", "Debug mask for callvote_manager. Core=1 Localization=128 All=129.", FCVAR_NONE, true, 0.0, true, 129.0);
	g_Log = new CallVoteLogger(CVM_LOG_TAG, CVM_LOG_FILE, g_cvarLogMode, g_cvarDebugMask);

	g_cvarAnnouncer = CreateConVar("sm_cvm_announcer", "1", "Announce voting calls", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarProgress = CreateConVar("sm_cvm_progress", "1", "Show voting progress", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarProgressAnonymous = CreateConVar("sm_cvm_progress_anonymous", "0", "Show voting progress anonymously", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarBuiltinVote = CreateConVar("sm_cvm_builtin_vote", "1", "<builtinvotes> support in default manager policy", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarLobby = CreateConVar("sm_cvm_lobby", "1", "Enable vote ReturnToLobby", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarChapter = CreateConVar("sm_cvm_chapter", "1", "Enable vote ChangeChapter", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarAllTalk = CreateConVar("sm_cvm_all_talk", "1", "Enable vote ChangeAllTalk", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarAdminImmunity = CreateConVar("sm_cvm_admin_immunity", "", "Admins are immune to kick votes. Specify admin flags or blank.", FCVAR_NOTIFY);
	g_cvarSTVImmunity = CreateConVar("sm_cvm_stv_immunity", "1", "SourceTV is immune to votekick", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarSelfImmunity = CreateConVar("sm_cvm_self_immunity", "1", "Immunity to self-kick", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarBotImmunity = CreateConVar("sm_cvm_bot_immunity", "1", "Immunity to bots", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	sv_vote_issue_change_difficulty_allowed = FindConVar("sv_vote_issue_change_difficulty_allowed");
	sv_vote_issue_restart_game_allowed = FindConVar("sv_vote_issue_restart_game_allowed");
	sv_vote_issue_kick_allowed = FindConVar("sv_vote_issue_kick_allowed");
	sv_vote_issue_change_mission_allowed = FindConVar("sv_vote_issue_change_mission_allowed");
	sv_vote_creation_timer = FindConVar("sv_vote_creation_timer");
	sv_alltalk = FindConVar("sv_alltalk");
	z_difficulty = FindConVar("z_difficulty");

	char sTempAdmin[32];
	g_cvarAdminImmunity.AddChangeHook(ConVarChanged_AdminImmunity);
	g_cvarAdminImmunity.GetString(sTempAdmin, sizeof(sTempAdmin));
	g_iFlagsAdmin = ReadFlagString(sTempAdmin);

	g_cvarEnable.AddChangeHook(ConVarChanged_Enable);

	CallVoteAutoExecConfig(true, "callvote_manager");
	g_fLastVote = -1.0;
	CVM_ClearVoteState();
}

public void OnPluginEnd()
{
	if (g_loc != null)
		delete g_loc;

	if (g_Log != null)
		delete g_Log;
}

public void OnAllPluginsLoaded()
{
	g_Runtime.DetectLibraries();
}

public void OnLibraryRemoved(const char[] name)
{
	g_Runtime.SetLibraryAvailability(name, false);
}

public void OnLibraryAdded(const char[] name)
{
	g_Runtime.SetLibraryAvailability(name, true);
}

public void OnMapStart()
{
	g_fLastVote = -1.0;
	CVM_ClearVoteState();
}

public void OnMapEnd()
{
	CVM_ClearVoteState();
}

public void ConVarChanged_Enable(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CVM_ClearVoteState();
}

public void OnConfigsExecuted()
{
	EnsureCallVoteDebugLogFolderForMode(g_cvarLogMode);

	char sDebugPath[PLATFORM_MAX_PATH];
	BuildCallVoteDebugLogPath(CVM_LOG_FILE, sDebugPath, sizeof(sDebugPath));

	CVLog.Debug(
		"[OnConfigsExecuted] mode=%d mask=%d announcer=%d path=%s",
		g_cvarLogMode != null ? g_cvarLogMode.IntValue : -1,
		g_cvarDebugMask != null ? g_cvarDebugMask.IntValue : -1,
		g_cvarAnnouncer != null && g_cvarAnnouncer.BoolValue ? 1 : 0,
		sDebugPath
	);
}

public void ConVarChanged_AdminImmunity(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	char sTempAdmin[32];
	g_cvarAdminImmunity.GetString(sTempAdmin, sizeof(sTempAdmin));
	g_iFlagsAdmin = ReadFlagString(sTempAdmin);
}

public Action CallVote_PreStart(int sessionId, int client, int callerAccountId, TypeVotes voteType, int target, int targetAccountId, const char[] argument)
{
	CVM_ClearRejection();
	if (!g_cvarEnable.BoolValue)
		return Plugin_Continue;

	int cooldownSeconds;
	VoteRestrictionType restriction = CVM_MatchesSnapshotClient(client, callerAccountId)
		? ValidateCallerState(client, cooldownSeconds) : VoteRestriction_InvalidCaller;
	if (restriction == VoteRestriction_None)
		restriction = voteType == Kick && !CVM_MatchesSnapshotClient(target, targetAccountId)
			? VoteRestriction_Target : ValidateVote(client, voteType, target, argument);
	if (restriction == VoteRestriction_None)
		return Plugin_Continue;

	g_iRejectedSession = sessionId;
	g_iRejectedCallerSerial = CVM_IsLiveClient(client) ? GetClientSerial(client) : 0;
	g_iRejectedTargetSerial = CVM_IsLiveClient(target) ? GetClientSerial(target) : 0;
	g_iRejectedCooldown = cooldownSeconds;
	g_RejectedRestriction = restriction;
	CallVoteCore_SetPendingRestriction(restriction);
	return Plugin_Handled;
}

public void CallVote_Blocked(int sessionId, int client, int callerAccountId, TypeVotes voteType, VoteRestrictionType restriction, int target, int targetAccountId, const char[] argument)
{
	// Only present our own rule when it matches the core's canonical rejection.
	if (g_cvarEnable.BoolValue && g_iRejectedSession == sessionId
		&& g_RejectedRestriction == restriction && g_iRejectedCallerSerial != 0
		&& GetClientFromSerial(g_iRejectedCallerSerial) == client && CVM_MatchesSnapshotClient(client, callerAccountId))
	{
		int feedbackTarget = g_iRejectedTargetSerial != 0 ? GetClientFromSerial(g_iRejectedTargetSerial) : 0;
		if (!CVM_MatchesSnapshotClient(feedbackTarget, targetAccountId))
			feedbackTarget = 0;
		SendRestrictionFeedback(client, restriction, voteType, feedbackTarget, g_iRejectedCooldown);
	}
	if (g_iRejectedSession == sessionId)
		CVM_ClearRejection();
}

public void CallVote_Start(int sessionId)
{
	if (!g_cvarEnable.BoolValue)
		return;

	int callerClient, callerAccountId, targetClient, targetAccountId;
	TypeVotes voteType;
	char argument[64];
	if (!CallVoteCore_GetSessionInfo(sessionId, callerClient, callerAccountId, voteType, targetClient, targetAccountId, argument, sizeof(argument)))
		return;

	g_fLastVote = GetEngineTime();
	g_iActiveSession = sessionId;
	g_iInitialYesCallerSerial = CVM_MatchesSnapshotClient(callerClient, callerAccountId) ? GetClientSerial(callerClient) : 0;
	CVM_ClearRejection();

	if (!g_cvarAnnouncer.BoolValue || !CVM_MatchesSnapshotClient(callerClient, callerAccountId))
		return;

	switch (voteType)
	{
		case ChangeDifficulty: PrintLocalizedDifficulty(argument, callerClient);
		case RestartGame: PrintLocalizedRestartGame(callerClient);
		case Kick:
		{
			if (CVM_MatchesSnapshotClient(targetClient, targetAccountId))
				PrintLocalizedKick(callerClient, targetClient);
		}
		case ChangeMission: PrintLocalizedMissionName(argument, callerClient);
		case ReturnToLobby: PrintLocalizedReturnToLobby(callerClient);
		case ChangeChapter: PrintLocalizedChapterName(argument, callerClient);
		case ChangeAllTalk: PrintLocalizedAllTalk(callerClient);
	}
}

public void CallVote_BallotCast(int sessionId, int client, int accountId, bool votedYes, int team)
{
	if (!g_cvarEnable.BoolValue || g_iActiveSession != sessionId || !CVM_MatchesSnapshotClient(client, accountId))
		return;

	// The engine initially votes Yes for the caller; the announcement covers it.
	// Consume it even with progress disabled, so a later toggle cannot hide a ballot.
	if (votedYes && g_iInitialYesCallerSerial != 0 && GetClientSerial(client) == g_iInitialYesCallerSerial)
	{
		g_iInitialYesCallerSerial = 0;
		return;
	}
	if (!g_cvarProgress.BoolValue)
		return;

	// Forward team is vote scope; the displayed team belongs to the live voter.
	L4DTeam voterTeam = L4D_GetClientTeam(client);
	char teamName[64];
	bool anonymous = g_cvarProgressAnonymous.BoolValue;
	for (int recipient = 1; recipient <= MaxClients; recipient++)
	{
		if (!IsClientInGame(recipient) || IsFakeClient(recipient))
			continue;
		if (!Lang_GetLocalizedTeamName(voterTeam, recipient, teamName, sizeof(teamName), g_loc))
		{
			char phrase[32];
			switch (voterTeam)
			{
				case L4DTeam_Survivor: strcopy(phrase, sizeof(phrase), "TeamSurvivor");
				case L4DTeam_Infected: strcopy(phrase, sizeof(phrase), "TeamInfected");
				default: strcopy(phrase, sizeof(phrase), "TeamSpectator");
			}
			Format(teamName, sizeof(teamName), "%T", phrase, recipient);
		}
		if (anonymous)
			CPrintToChat(recipient, "%t %t", "Tag", "VoteCastAnon", teamName, votedYes ? "{olive}F1{default}" : "{green}F2{default}");
		else
			CPrintToChat(recipient, "%t %t", "Tag", "VoteCast", client, teamName, votedYes ? "{olive}F1{default}" : "{green}F2{default}");
	}
}

public void CallVote_End(int sessionId, CallVoteEndReason result, int yesCount, int noCount, int potentialVotes)
{
	if (g_iActiveSession == sessionId)
	{
		g_iActiveSession = 0;
		g_iInitialYesCallerSerial = 0;
	}
	if (g_iRejectedSession == sessionId)
		CVM_ClearRejection();
}

bool HasAdminFlags(int client, int flags = 0)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return false;

	int clientFlags = GetUserFlagBits(client);
	if (clientFlags & ADMFLAG_ROOT)
		return true;

	if (flags == 0)
		return (clientFlags != 0);

	return (clientFlags & flags) != 0;
}

bool IsAdmin(int client)
{
	CVLog.Debug("[IsAdmin] Checking client=%d for admin immunity flags: %d", client, g_iFlagsAdmin);
	return HasAdminFlags(client, g_iFlagsAdmin);
}

bool CanKick(int client)
{
	return HasAdminFlags(client, FlagToBit(Admin_Kick));
}

public void OnClientDisconnect(int client)
{
	if (g_iInitialYesCallerSerial != 0 && GetClientFromSerial(g_iInitialYesCallerSerial) == client)
		g_iInitialYesCallerSerial = 0;
}
