#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <callvote_stock>

#undef REQUIRE_EXTENSIONS
#include <builtinvotes>
#define REQUIRE_EXTENSIONS

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define PLUGIN_VERSION "1.5.0"

#define DEBUG 		1
#define DEBUG_SQL 	1

enum CampaignCode
{
	l4d2c1			  = 0,
	l4d2c2			  = 1,
	l4d2c3			  = 2,
	l4d2c4			  = 3,
	l4d2c5			  = 4,
	l4d2c6			  = 5,
	l4d2c7			  = 6,
	l4d2c8			  = 7,
	l4d2c9			  = 8,
	l4d2c10			  = 9,
	l4d2c11			  = 10,
	l4d2c12			  = 11,
	l4d2c13			  = 12,

	CampaignCode_size = 13,
};

char sCampaignCode[CampaignCode_size][] = {
	"l4d2c1",
	"l4d2c2",
	"l4d2c3",
	"l4d2c4",
	"l4d2c5",
	"l4d2c6",
	"l4d2c7",
	"l4d2c8",
	"l4d2c9",
	"l4d2c10",
	"l4d2c11",
	"l4d2c12",
	"l4d2c13"
};

stock char sTypeVotes[TypeVotes_Size][] = {
	"ChangeDifficulty",
	"RestartGame",
	"Kick",
	"ChangeMission",
	"ReturnToLobby",
	"ChangeChapter",
	"ChangeAllTalk"
};

ConVar
	g_cvarRegLog,
	g_cvarEnable,

	g_cvarBuiltinVote,
	g_cvarAnnouncer,
	g_cvarProgress,
	g_cvarProgressAnony,

	g_cvarLobby,
	g_cvarChapter,
	g_cvarAllTalk,

	g_cvarAdminInmunity,
	g_cvarSTVInmunity,
	g_cvarSelfInmunity,
	g_cvarBotInmunity,

	sv_vote_issue_change_difficulty_allowed,
	sv_vote_issue_restart_game_allowed,
	sv_vote_issue_kick_allowed,
	sv_vote_issue_change_mission_allowed,
	sv_vote_creation_timer,
	z_difficulty;

bool
	g_bBuiltinVotes = false,
	g_bLateLoad;

char
	g_sReason[MAX_REASON_LENGTH + 1],
	g_sLogPath[PLATFORM_MAX_PATH];

float
	g_fLastVote;

int
	g_iFlagsAdmin,
	g_iVoteRejectClient = -1;

GlobalForward
	g_ForwardCallVote;

/*****************************************************************
			L I B R A R Y   I N C L U D E S
*****************************************************************/

#include "callvote/manager_sql.sp"

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/

public Plugin myinfo =
{
	name		= "Call Vote Manager",
	author		= "lechuga",
	description = "Manage call vote system",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/lechuga16/callvote_manager"
}

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max)
{

	MarkNativeAsOptional("IsBuiltinVoteInProgress");
	MarkNativeAsOptional("CheckBuiltinVoteDelay");

	g_ForwardCallVote = CreateGlobalForward("CallVote_Start", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	CreateNative("CallVote_Reject", Native_CallVote_Reject);

	RegPluginLibrary("callvotemanager");
	g_bLateLoad = bLate;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bBuiltinVotes = LibraryExists("BuiltinVotes");
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "BuiltinVotes"))
		g_bBuiltinVotes = false;
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "BuiltinVotes"))
		g_bBuiltinVotes = true;
}

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), DIR_CALLVOTE);

	LoadTranslation("callvote_manager.phrases");
	CreateConVar("sm_cvm_version", PLUGIN_VERSION, "Plugin version", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	g_cvarEnable		= CreateConVar("sm_cvm_enable", "1", "Enable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarRegLog		= CreateConVar("sm_cvm_log", "0", "logging flags <dificulty:1, restartgame:2, kick:4, changemission:8, lobby:16, chapter:32, alltalk:64, ALL:127>", FCVAR_NOTIFY, true, 0.0, true, 127.0);
	g_cvarBuiltinVote	= CreateConVar("sm_cvm_builtinvote", "1", "<builtinvotes> support", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarAnnouncer		= CreateConVar("sm_cvm_announcer", "1", "Announce voting calls", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarProgress		= CreateConVar("sm_cvm_progress", "1", "Show voting progress", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarProgressAnony = CreateConVar("sm_cvm_progressanony", "0", "Show voting progress anonymously", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_cvarLobby			= CreateConVar("sm_cvm_lobby", "1", "Enable vote ReturnToLobby", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarChapter		= CreateConVar("sm_cvm_chapter", "1", "Enable vote ChangeChapter", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarAllTalk		= CreateConVar("sm_cvm_alltalk", "1", "Enable vote ChangeAllTalk", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_cvarAdminInmunity = CreateConVar("sm_cvm_admininmunity", "", "Admins are immune to kick votes. Specify admin flags or blank.", FCVAR_NOTIFY);
	g_cvarSTVInmunity	= CreateConVar("sm_cvm_stvinmunity", "1", "SourceTV is immune to votekick", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarSelfInmunity	= CreateConVar("sm_cvm_selfinmunity", "1", "Immunity to self-kick", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarBotInmunity	= CreateConVar("sm_cvm_botinmunity", "1", "Immunity to bots", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	sv_vote_issue_change_difficulty_allowed = FindConVar("sv_vote_issue_change_difficulty_allowed");
	sv_vote_issue_restart_game_allowed		= FindConVar("sv_vote_issue_restart_game_allowed");
	sv_vote_issue_change_mission_allowed	= FindConVar("sv_vote_issue_change_mission_allowed");
	sv_vote_issue_kick_allowed				= FindConVar("sv_vote_issue_kick_allowed");
	sv_vote_creation_timer					= FindConVar("sv_vote_creation_timer");
	z_difficulty							= FindConVar("z_difficulty");

	char sTempAdmin[32];

	g_cvarAdminInmunity.AddChangeHook(ConVarChanged_AdminInmunity);
	g_cvarAdminInmunity.GetString(sTempAdmin, sizeof(sTempAdmin));
	g_iFlagsAdmin = ReadFlagString(sTempAdmin);

	OnPluginStart_SQL();

	AddCommandListener(Listener_CallVote, "callvote");
	HookEvent("vote_cast_yes", Event_VoteCastYes);
	HookEvent("vote_cast_no", Event_VoteCastNo);

	AutoExecConfig(false, "callvote_manager");

	if (!g_bLateLoad)
		return;

	g_bBuiltinVotes = LibraryExists("BuiltinVotes");
}

public void ConVarChanged_AdminInmunity(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	char sTempAdmin[32];
	g_cvarAdminInmunity.GetString(sTempAdmin, sizeof(sTempAdmin));
	g_iFlagsAdmin = ReadFlagString(sTempAdmin);
}

public void OnPluginEnd()
{
	OnPluginEnd_SQL();
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

	// Verificar si el comando no tiene argumentos
	if (GetCmdArgs() == 0)
	{
		return Plugin_Continue;
	}

	if (iClient == SERVER_INDEX)
	{
		CReplyToCommand(iClient, "%t Votes can only be issued from a valid client.", "Tag");
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

	// ------------------------------------------------------------
	// Change Difficulty <Impossible|Expert|Hard|Normal>
	// ------------------------------------------------------------
	if (strcmp(sVoteType, sTypeVotes[ChangeDifficulty], false) == 0)
	{
		if (!sv_vote_issue_change_difficulty_allowed.BoolValue)
		{
			CPrintToChat(iClient, "%t %t", "Tag", "VoteDisabled");
			return Plugin_Continue;
		}

		if (iArgs != 2)
			return Plugin_Continue;

		char sCVarDifficulty[32];
		z_difficulty.GetString(sCVarDifficulty, sizeof(sCVarDifficulty));

		if (strcmp(sVoteArgument, sCVarDifficulty, false) == 0)
		{
			CPrintToChat(iClient, "%t %t", "Tag", "SameDifficulty");
			return Plugin_Handled;
		}

		ForwardCallVote(iClient, ChangeDifficulty);

		if (g_iVoteRejectClient != -1 && g_iVoteRejectClient == iClient)
		{
			CPrintToChat(iClient, "%t %s", "Tag", g_sReason);
			CleanVoteReject();
			return Plugin_Handled;
		}

		// We translate the difficulty
		char sDifficulty[32];
		Format(sDifficulty, sizeof(sDifficulty), "%t", sVoteArgument);

		RegVote(ChangeDifficulty, iClient);
		RegSQLVote(ChangeDifficulty, iClient);

		announcer("%t", "ChangeDifficulty", iClient, sDifficulty);
	}
	// ------------------------------------------------------------
	// Restart Game
	// ------------------------------------------------------------
	else if (strcmp(sVoteType, sTypeVotes[RestartGame], false) == 0)
	{
		if (!sv_vote_issue_restart_game_allowed.BoolValue)
		{
			CPrintToChat(iClient, "%t %t", "Tag", "VoteDisabled");
			return Plugin_Continue;	   // it is disabled by sv_vote_issue_restart_game_allowed
		}

		if (iArgs != 1)
			return Plugin_Continue;

		ForwardCallVote(iClient, RestartGame);

		if (g_iVoteRejectClient != -1 && g_iVoteRejectClient == iClient)
		{
			CPrintToChat(iClient, "%t %s", "Tag", g_sReason);
			CleanVoteReject();
			return Plugin_Handled;
		}

		RegVote(RestartGame, iClient);
		RegSQLVote(RestartGame, iClient);

		announcer("%t", "RestartGame", iClient);
	}
	// ------------------------------------------------------------
	// Kick <userID>
	// ------------------------------------------------------------
	else if (strcmp(sVoteType, sTypeVotes[Kick], false) == 0)
	{
		if (!sv_vote_issue_kick_allowed.BoolValue)
		{
			CPrintToChat(iClient, "%t %t", "Tag", "VoteDisabled");
			return Plugin_Continue;	   // it is disabled by sv_vote_issue_kick_allowed
		}

		int iTarget = GetClientOfUserId(GetCmdArgInt(2));

		if (iTarget == 0)
			return Plugin_Handled;

		if (g_cvarSTVInmunity.BoolValue && IsClientConnected(iClient) && IsClientSourceTV(iTarget))
		{
			CPrintToChat(iClient, "%t %t", "Tag", "SourceTVKick");
			return Plugin_Handled;
		}

		if (g_cvarBotInmunity.BoolValue && IsClientConnected(iClient) && IsFakeClient(iTarget))
		{
			CPrintToChat(iClient, "%t %t", "Tag", "BotKick");
			return Plugin_Handled;
		}

		if (g_cvarSelfInmunity.BoolValue && iTarget == iClient)
		{
			CPrintToChat(iClient, "%t %t", "Tag", "KickSelf");
			return Plugin_Handled;
		}

		L4DTeam clientTeam = L4D_GetClientTeam(iClient);
		L4DTeam targetTeam = L4D_GetClientTeam(iTarget);
		
		if (clientTeam != targetTeam)
		{
			CPrintToChat(iClient, "%t %t", "Tag", "KickDifferentTeam");
			return Plugin_Handled;
		}

		if (!IsFlagC(iClient) && IsAdmin(iTarget))
		{
			CPrintToChat(iClient, "%t %t", "Tag", "Inmunity");
			CPrintToChat(iTarget, "%t %t", "Tag", "InmunityTarget", iClient);
			return Plugin_Handled;
		}

		Call_StartForward(g_ForwardCallVote);
		Call_PushCell(iClient);
		Call_PushCell(Kick);
		Call_PushCell(iTarget);
		Call_Finish();

		if (g_iVoteRejectClient != -1 && g_iVoteRejectClient == iClient)
		{
			CPrintToChat(iClient, "%t %s", "Tag", g_sReason);
			CleanVoteReject();
			return Plugin_Handled;
		}

		RegVote(Kick, iClient, iTarget);
		RegSQLVote(Kick, iClient, iTarget);

		announcer("%t", "Kick", iClient, iTarget);
	}
	// ------------------------------------------------------------
	// Change Map <MapName>
	// ------------------------------------------------------------
	else if (strcmp(sVoteType, sTypeVotes[ChangeMission], false) == 0)
	{
		if (!sv_vote_issue_change_mission_allowed.BoolValue)
		{
			CPrintToChat(iClient, "%t %t", "Tag", "VoteDisabled");
			return Plugin_Continue;	   // it is disabled by sv_vote_issue_change_mission_allowed
		}

		if (iArgs != 2)
			return Plugin_Continue;

		ForwardCallVote(iClient, ChangeMission);

		if (g_iVoteRejectClient != -1 && g_iVoteRejectClient == iClient)
		{
			CPrintToChat(iClient, "%t %s", "Tag", g_sReason);
			CleanVoteReject();
			return Plugin_Handled;
		}

		int	 iCode = Campaign_Code(sVoteArgument);
		char sCampaign[32];
		if (iCode == -1)
			Format(sCampaign, sizeof(sCampaign), "%s", sVoteArgument);
		else
			Format(sCampaign, sizeof(sCampaign), "%t", sCampaignCode[iCode]);



		RegVote(ChangeMission, iClient);
		RegSQLVote(ChangeMission, iClient);

		announcer("%t", "ChangeMission", iClient, sCampaign);
	}
	// ------------------------------------------------------------
	// Return to Lobby
	// ------------------------------------------------------------
	else if (strcmp(sVoteType, sTypeVotes[ReturnToLobby], false) == 0)
	{
		if (!g_cvarLobby.BoolValue)
		{
			CPrintToChat(iClient, "%t %t", "Tag", "VoteDisabled");
			return Plugin_Handled;
		}

		if (iArgs != 1)
			return Plugin_Continue;

		ForwardCallVote(iClient, ReturnToLobby);

		// Check if the vote was rejected
		if (g_iVoteRejectClient != -1 && g_iVoteRejectClient == iClient)
		{
			CPrintToChat(iClient, "%t %s", "Tag", g_sReason);
			CleanVoteReject();
			return Plugin_Handled;
		}

		RegVote(ReturnToLobby, iClient);
		RegSQLVote(ReturnToLobby, iClient);
		
		announcer("%t", "ReturnToLobby", iClient);
	}
	// ------------------------------------------------------------
	// Change Chapter <MapCode>
	// ------------------------------------------------------------
	else if (strcmp(sVoteType, sTypeVotes[ChangeChapter], false) == 0)
	{
		if (!g_cvarChapter.BoolValue)
		{
			CPrintToChat(iClient, "%t %t", "Tag", "VoteDisabled");
			return Plugin_Handled;
		}

		if (iArgs != 2)
			return Plugin_Continue;

		ForwardCallVote(iClient, ChangeChapter);

		// Check if the vote was rejected
		if (g_iVoteRejectClient != -1 && g_iVoteRejectClient == iClient)
		{
			CPrintToChat(iClient, "%t %s", "Tag", g_sReason);
			CleanVoteReject();
			return Plugin_Handled;
		}

		RegVote(ChangeChapter, iClient);
		RegSQLVote(ChangeChapter, iClient);

		announcer("%t", "ChangeChapter", iClient, sVoteArgument);
	}
	// ------------------------------------------------------------
	// Change All Talk
	// ------------------------------------------------------------
	else if (strcmp(sVoteType, sTypeVotes[ChangeAllTalk], false) == 0)
	{
		if (!g_cvarAllTalk.BoolValue)
			return Plugin_Handled;

		if (iArgs != 1)
			return Plugin_Continue;

		ForwardCallVote(iClient, ChangeAllTalk);

		// Check if the vote was rejected
		if (g_iVoteRejectClient != -1 && g_iVoteRejectClient == iClient)
		{
			CPrintToChat(iClient, "%t %s", "Tag", g_sReason);
			CleanVoteReject();
			return Plugin_Handled;
		}

		RegVote(ChangeAllTalk, iClient);
		RegSQLVote(ChangeAllTalk, iClient);

		announcer("%t", "ChangeAllTalk", iClient);
	}

	g_fLastVote = GetEngineTime();
	return Plugin_Continue;
}

/*****************************************************************
			N A T I V E S
*****************************************************************/

/**
 * Rejects a vote in process, before being issued.
 *
 * @param client The client who started the vote.
 * @param reason The reason for the rejection.
 * @error Invalid client index
 * @error Invalid length reason
 * @error Invalid numParams
 */
int Native_CallVote_Reject(Handle plugin, int numParams)
{
	if (numParams <= 1 && 3 <= numParams)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid numParams (%d/2)", numParams);

	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d!", client);
	g_iVoteRejectClient = client;

	int iLen;
	GetNativeStringLength(2, iLen);
	if (iLen > MAX_REASON_LENGTH)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid length reason (%d/%d)", iLen, MAX_REASON_LENGTH);

	GetNativeString(2, g_sReason, iLen + 1);
	return 1;
}

/****************************************************************
			C A L L B A C K   F U N C T I O N S
****************************************************************/

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

	if (g_cvarProgressAnony.BoolValue)
		CPrintToChatAll("%t %t", "Tag", "VoteCastAnon", TeamTranslation(Team), "{blue}F1{default}");
	else
		CPrintToChatAll("%t %t", "Tag", "VoteCast", iClient, TeamTranslation(Team), "{blue}F1{default}");
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

	if (g_cvarProgressAnony.BoolValue)
		CPrintToChatAll("%t %t", "Tag", "VoteCastAnon", TeamTranslation(Team), "{red}F2{default}");
	else
		CPrintToChatAll("%t %t", "Tag", "VoteCast", iClient, TeamTranslation(Team), "{red}F2{default}");
}

/*****************************************************************
			P L U G I N   F U N C T I O N S
*****************************************************************/

void RegVote(TypeVotes type, int iClient, int iTarget = SERVER_INDEX)
{
	if (!g_cvarRegLog.BoolValue)
		return;
	
	int iVoteFlag = 0;
	switch (type)
	{
		case ChangeDifficulty: iVoteFlag = VOTE_CHANGEDIFFICULTY;
		case RestartGame: iVoteFlag = VOTE_RESTARTGAME;
		case Kick: iVoteFlag = VOTE_KICK;
		case ChangeMission: iVoteFlag = VOTE_CHANGEMISSION;
		case ReturnToLobby: iVoteFlag = VOTE_RETURNTOLOBBY;
		case ChangeChapter: iVoteFlag = VOTE_CHANGECHAPTER;
		case ChangeAllTalk: iVoteFlag = VOTE_CHANGEALLTALK;
		default: return;
	}
	
	if (!(g_cvarRegLog.IntValue & iVoteFlag))
		return;
	
	char sAuthID_Client[MAX_AUTHID_LENGTH];
	if (!GetClientAuthId(iClient, AuthId_Steam2, sAuthID_Client, sizeof(sAuthID_Client)))
	{
		LogError("[RegVote] Failed to get AuthID for client %N", iClient);
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
		if (!GetClientAuthId(iTarget, AuthId_Steam2, sAuthID_Target, sizeof(sAuthID_Target)))
		{
			LogDebug("[RegVote] Failed to get AuthID for target %d", iTarget);
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
	
	LogToFileEx(g_sLogPath, "[RegVote] %s", sLogMessage);
}


bool IsHuman(int iClient)
{
	if (iClient < 1 || iClient > MaxClients)
		return false;

	if (!IsClientConnected(iClient) || IsFakeClient(iClient))
		return false;

	return true;
}

void announcer(const char[] sMessage, any...)
{
	if (!g_cvarAnnouncer.BoolValue)
		return;

	static char sFormat[512];
	VFormat(sFormat, sizeof(sFormat), sMessage, 2);
	CPrintToChatAll("%t %s", "Tag", sFormat);
}

/**
 * @brief Return if a user has admin or root flag
 * @param client			Client index
 * @return					True if it has an admin flag or is root, False if it has no flags.
 */
bool IsAdmin(const int iClient)
{
	if (g_iFlagsAdmin == 0)
		return false;

	int iClientFlags = GetUserFlagBits(iClient);
	LogDebug("[IsAdmin] Checking %N flags: %d | Admin: %d", iClient, iClientFlags, g_iFlagsAdmin);
	return (iClientFlags & g_iFlagsAdmin) ? true : false;
}

/**
 * @brief Return if a user has kick flag or root
 * @param client			Client index
 * @return					True if it has an kick flag or root, False if it has no flags.
 */
bool IsFlagC(const int iClient)
{
	int iClientFlags = GetUserFlagBits(iClient);
	return view_as<bool>(iClientFlags & FlagToBit(Admin_Kick) || (iClientFlags & ADMFLAG_ROOT));
}

/**
 * @brief Clean the variables used by rejecting a vote
 * @noreturn
 */
void CleanVoteReject()
{
	g_sReason[0]		= '\0';
	g_iVoteRejectClient = -1;
}

void ForwardCallVote(int iClient, TypeVotes vote)
{
	Call_StartForward(g_ForwardCallVote);
	Call_PushCell(iClient);
	Call_PushCell(vote);
	Call_PushCell(0);
	Call_Finish();
}

/**
 * Searches for a campaign code in the array of campaign codes.
 *
 * @param sCode The campaign code to search for.
 * @return The index of the campaign code if found, or -1 if not found.
 */
int Campaign_Code(const char[] sCode)
{
	for (int i = 0; i < view_as<int>(CampaignCode_size); i++)
	{
		if (strcmp(sCampaignCode[i], sCode, false) == 0)
			return i;
	}
	return -1;
}

/**
 * Translates a Left 4 Dead 2 team ID to its corresponding team name.
 *
 * @param Team The team ID to translate.
 * @return The translated team name as a string.
 */
char[] TeamTranslation(L4DTeam Team)
{
	char sBuffer[16];
	switch (Team)
	{
		case L4DTeam_Survivor: Format(sBuffer, sizeof(sBuffer), "%t", "L4DTeam_Survivor");
		case L4DTeam_Infected: Format(sBuffer, sizeof(sBuffer), "%t", "L4DTeam_Infected");
		case L4DTeam_Spectator: Format(sBuffer, sizeof(sBuffer), "%t", "L4DTeam_Spectator");
		default: Format(sBuffer, sizeof(sBuffer), "%t", "L4DTeam_Unassigned");
	}
	return sBuffer;
}

#if DEBUG

	/**
	 * Logs a debug message to a specified log file.
	 *
	 * @param sMessage   The format string for the debug message.
	 * @param ...        Additional arguments to format into the message.
	 */
	void LogDebug(const char[] sMessage, any...)
	{
		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), sMessage, 2);
		LogToFileEx(g_sLogPath, "[Manager][Debug] %s", sFormat);
	}

	#if DEBUG_SQL
		/**
		 * Logs a formatted SQL-related message to a log file.
		 *
		 * @param sMessage   The format string for the message to log.
		 * @param ...        Additional arguments to format into the message.
		 */
		void LogSQL(const char[] sMessage, any...)
		{
			static char sFormat[1024];
			VFormat(sFormat, sizeof(sFormat), sMessage, 2);
			LogToFileEx(g_sLogPath, "[Manager][SQL] %s", sFormat);
		}
	#else
		public void LogSQL(const char[] sMessage, any...) {}
	#endif

#else
	public void LogDebug(const char[] sMessage, any...) {}
	public void LogSQL(const char[] sMessage, any...) {}
#endif

// =======================================================================================
// Bibliography
// https://developer.valvesoftware.com/wiki/List_of_L4D2_Cvars
// https://wiki.alliedmods.net/Left_4_Voting_2
// https://forums.alliedmods.net/showthread.php?p=1582772
// https://github.com/SirPlease/L4D2-Competitive-Rework
// =======================================================================================