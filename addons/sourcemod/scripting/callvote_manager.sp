#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <left4dhooks>
#include <callvote_core>
#include <language_manager>
#include <campaign_manager>

#undef REQUIRE_EXTENSIONS
#include <confogl>
#include <builtinvotes>
#define REQUIRE_EXTENSIONS

#define PLUGIN_VERSION "2.0.0"
#define CVM_LOG_TAG "CVM"
#define CVM_LOG_FILE "callvote_manager.log"

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
	sv_vote_creation_timer,
	sv_vote_issue_change_difficulty_allowed,
	sv_vote_issue_restart_game_allowed,
	sv_vote_issue_kick_allowed,
	sv_vote_issue_change_mission_allowed,
	z_difficulty;

Localizer g_loc;
CallVoteLogger g_Log = null;
int g_iFlagsAdmin;
int g_iClientFlagsCache[MAXPLAYERS + 1];
bool g_bClientFlagsCached[MAXPLAYERS + 1];
bool g_bBuiltinVotes = false;
float g_fLastVote;

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

public void OnPluginStart()
{
	g_loc = new Localizer();

	LoadTranslation("callvote_manager.phrases");
	LoadTranslation("callvote_common.phrases");

	g_cvarEnable = CreateConVar("sm_cvm_enable", "1", "Enable callvote_manager default policy and UX", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarLogMode = CallVoteEnsureLogModeConVar();
	g_cvarDebugMask = CreateConVar("sm_cvm_debug_mask", "0", "Debug mask for callvote_manager. Core=1 SQL=2 Cache=4 Commands=8 Identity=16 Forwards=32 Session=64 Localization=128 All=255.", FCVAR_NONE, true, 0.0, true, 255.0);
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
	z_difficulty = FindConVar("z_difficulty");

	char sTempAdmin[32];
	g_cvarAdminImmunity.AddChangeHook(ConVarChanged_AdminImmunity);
	g_cvarAdminImmunity.GetString(sTempAdmin, sizeof(sTempAdmin));
	g_iFlagsAdmin = ReadFlagString(sTempAdmin);

	HookEvent("vote_cast_yes", Event_VoteCastYes);
	HookEvent("vote_cast_no", Event_VoteCastNo);

	CallVoteAutoExecConfig(true, "callvote_manager");
	g_bBuiltinVotes = LibraryExists("BuiltinVotes");
	g_fLastVote = 0.0;
}

public void OnPluginEnd()
{
	if (g_Log != null)
		delete g_Log;
}

public void OnAllPluginsLoaded()
{
	g_bBuiltinVotes = LibraryExists("BuiltinVotes");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "BuiltinVotes"))
		g_bBuiltinVotes = false;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "BuiltinVotes"))
		g_bBuiltinVotes = true;
}

public void OnMapStart()
{
	g_fLastVote = 0.0;
}

public void ConVarChanged_AdminImmunity(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	char sTempAdmin[32];
	g_cvarAdminImmunity.GetString(sTempAdmin, sizeof(sTempAdmin));
	g_iFlagsAdmin = ReadFlagString(sTempAdmin);
	ClearAdminFlagsCache();
}

public Action CallVote_PreStart(int sessionId, int client, int callerAccountId, TypeVotes voteType, int target, int targetAccountId, const char[] argument)
{
	if (!g_cvarEnable.BoolValue)
		return Plugin_Continue;

	int cooldownSeconds;
	VoteRestrictionType earlyRestriction = ValidateCallerState(client, cooldownSeconds);
	if (earlyRestriction != VoteRestriction_None)
	{
		SendRestrictionFeedback(client, earlyRestriction, voteType, target, cooldownSeconds);
		CallVoteCore_SetPendingRestriction(earlyRestriction);
		return Plugin_Handled;
	}

	VoteRestrictionType restriction;
	if (voteType == Kick)
		restriction = ValidateVote(client, voteType, target);
	else if (argument[0] != '\0')
		restriction = ValidateVote(client, voteType, 0, argument);
	else
		restriction = ValidateVote(client, voteType);

	if (restriction == VoteRestriction_None)
		return Plugin_Continue;

	if (voteType == Kick)
		SendRestrictionFeedback(client, restriction, voteType, target);
	else
		SendRestrictionFeedback(client, restriction, voteType);

	CallVoteCore_SetPendingRestriction(restriction);
	return Plugin_Handled;
}

public void CallVote_Start(int sessionId)
{
	g_fLastVote = GetEngineTime();

	if (!g_cvarAnnouncer.BoolValue)
		return;

	int callerClient;
	int callerAccountId;
	TypeVotes voteType;
	int targetClient;
	int targetAccountId;
	char argument[64];

	if (!CallVoteCore_GetSessionInfo(sessionId, callerClient, callerAccountId, voteType, targetClient, targetAccountId, argument, sizeof(argument)))
		return;

	if (!IsClientInGame(callerClient))
		return;

	switch (voteType)
	{
		case ChangeDifficulty:
			PrintLocalizedDifficulty(argument, callerClient);

		case RestartGame:
			PrintLocalizedRestartGame(callerClient);

		case Kick:
		{
			if (IsClientInGame(targetClient))
				PrintLocalizedKick(callerClient, targetClient);
		}

		case ChangeMission:
			PrintLocalizedMissionName(argument, callerClient);

		case ReturnToLobby:
			PrintLocalizedReturnToLobby(callerClient);

		case ChangeChapter:
			PrintLocalizedChapterName(argument, callerClient);

		case ChangeAllTalk:
			PrintLocalizedAllTalk(callerClient);
	}
}

void Event_VoteCastYes(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarProgress.BoolValue)
		return;

	int iClient = event.GetInt("entityid");
	if (!IsValidClientIndex(iClient))
		return;

	L4DTeam Team = L4D_GetClientTeam(iClient);

	char sTeamTranslation[64];
	bool bAnonymous = g_cvarProgressAnonymous.BoolValue;

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

void Event_VoteCastNo(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarProgress.BoolValue)
		return;

	int iClient = event.GetInt("entityid");
	if (!IsValidClientIndex(iClient))
		return;

	L4DTeam Team = L4D_GetClientTeam(iClient);

	char sTeamTranslation[64];
	bool bAnonymous = g_cvarProgressAnonymous.BoolValue;

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
		clientFlags = GetUserFlagBits(client);
		g_iClientFlagsCache[client] = clientFlags;
		g_bClientFlagsCached[client] = true;
	}

	if (clientFlags & ADMFLAG_ROOT)
		return true;

	if (flags == 0)
		return (clientFlags != 0);

	return (clientFlags & flags) != 0;
}

bool IsAdmin(int client)
{
	CVLog.Debug("[IsAdmin] Checking %N for admin immunity flags: %d", client, g_iFlagsAdmin);
	return HasAdminFlags(client, g_iFlagsAdmin);
}

bool CanKick(int client)
{
	return HasAdminFlags(client, FlagToBit(Admin_Kick));
}

void ClearAdminFlagsCache()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bClientFlagsCached[i] = false;
		g_iClientFlagsCache[i] = 0;
	}
}

void ClearClientAdminFlagsCache(int client)
{
	if (client >= 1 && client <= MaxClients)
	{
		g_bClientFlagsCached[client] = false;
		g_iClientFlagsCache[client] = 0;
	}
}

public void OnClientDisconnect(int client)
{
	ClearClientAdminFlagsCache(client);
}
