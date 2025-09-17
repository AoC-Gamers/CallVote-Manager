#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <left4dhooks>
#include <callvote_stock>
#include <language_manager>
#include <campaign_manager>


#undef REQUIRE_EXTENSIONS
#include <confogl>
#include <builtinvotes>
#define REQUIRE_EXTENSIONS

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define PLUGIN_VERSION "2.0.0"

#define DEBUG			1	// General debug information
#define DEBUG_SQL		1	// SQL statements
#define DEBUG_SQL_QUERY	1	// SQL database queries

enum VoteRestrictionType
{
	VoteRestriction_None = 0,
	VoteRestriction_ConVar,
	VoteRestriction_GameMode,
	VoteRestriction_SameState,
	VoteRestriction_Immunity,
	VoteRestriction_Team,
	VoteRestriction_Target
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
	g_bConfogl = false,
	g_bLateLoad;

char
	g_sLogPath[PLATFORM_MAX_PATH];

float
	g_fLastVote;

int
	g_iFlagsAdmin,
	g_iClientFlagsCache[MAXPLAYERS + 1];	// Cache for client admin flags

bool
	g_bClientFlagsCached[MAXPLAYERS + 1];	 // Track which clients have cached flags

GlobalForward
	g_ForwardCallVotePreStart,
	g_ForwardCallVoteStart,
	g_ForwardCallVotePreExecute,
	g_ForwardCallVoteBlocked;

Localizer
	g_loc;

/**
 * Enumeration for different log categories
 */
enum CVLogCategory
{
	CVLog_Debug 	= 0,	// General debug information  
	CVLog_SQL   	= 1,	// SQL operations and database queries
	CVLog_SQL_Query = 2,	// Detailed SQL query information
}

/**
 * Modern logging system using methodmap
 * Maintains the same macro-based optimization philosophy
 */
methodmap CVLog
{
	/**
	 * Internal method to format and write log message
	 *
	 * @param category    Log category for prefix formatting
	 * @param message     Format string for the message
	 * @param args        Variable arguments for formatting
	 */
	public 	static void WriteLog(CVLogCategory category, const char[] message, any...)
	{
		static char sFormat[1024];
		static char sPrefix[32];

		VFormat(sFormat, sizeof(sFormat), message, 3);

		switch (category)
		{
			case CVLog_Debug: strcopy(sPrefix, sizeof(sPrefix), "[CV][Debug]");
			case CVLog_SQL: strcopy(sPrefix, sizeof(sPrefix), "[CV][SQL]");
			case CVLog_SQL_Query: strcopy(sPrefix, sizeof(sPrefix), "[CV][SQL-Query]");
			default: strcopy(sPrefix, sizeof(sPrefix), "[CV][Unknown]");
		}

		LogToFileEx(g_sLogPath, "%s %s", sPrefix, sFormat);
	}

	/**
	 * Logs debug information with timestamp
	 * Only compiled when DEBUG macro is enabled
	 *
	 * @param message    Format string for the debug message
	 * @param ...        Additional arguments for formatting
	 */
	#if DEBUG

		public 	static void Debug(const char[] message, any...)
		{
			static char sFormat[1024];
			VFormat(sFormat, sizeof(sFormat), message, 2);
			CVLog.WriteLog(CVLog_Debug, sFormat);
		}
	#else

	public 	static void Debug(const char[] message, any...) {}
	#endif

	/**
	 * Logs SQL-related information
	 * Only compiled when DEBUG_SQL macro is enabled
	 *
	 * @param message    Format string for the SQL message
	 * @param ...        Additional arguments for formatting
	 */
	#if DEBUG && DEBUG_SQL

		public 	static void SQL(const char[] message, any...)
		{
			static char sFormat[1024];
			VFormat(sFormat, sizeof(sFormat), message, 2);
			CVLog.WriteLog(CVLog_SQL, sFormat);
		}
	#else

	public 	static void SQL(const char[] message, any...) {
		#pragma unused message
	}
	#endif

	/**
	 * Logs database query information
	 * Only compiled when DEBUG_SQL_QUERY macro is enabled
	 *
	 * @param message    Format string for the query message
	 * @param ...        Additional arguments for formatting
	 */
	#if DEBUG && DEBUG_SQL_QUERY

		public 	static void Query(const char[] message, any...)
		{
			static char sFormat[1024];
			VFormat(sFormat, sizeof(sFormat), message, 2);
			CVLog.WriteLog(CVLog_SQL_Query, sFormat);
		}
	#else

	public 	static void Query(const char[] message, any...) {}
	#endif
}

/*****************************************************************
			L I B R A R Y   I N C L U D E S
*****************************************************************/

#include "callvote/manager_sql.sp"
#include "callvote/manager_printlocalized.sp"

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

	CreateNative("CallVoteManager_IsVoteAllowedByConVar", Native_IsVoteAllowedByConVar);
	CreateNative("CallVoteManager_IsVoteAllowedByGameMode", Native_IsVoteAllowedByGameMode);

	RegPluginLibrary("callvotemanager");
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
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), DIR_CALLVOTE);
	g_loc = new Localizer();

	LoadTranslation("callvote_manager.phrases");
	CreateConVar("sm_cvm_version", PLUGIN_VERSION, "Plugin version", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	g_cvarEnable							= CreateConVar("sm_cvm_enable", "1", "Enable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarRegLog							= CreateConVar("sm_cvm_log", "0", "logging flags <dificulty:1, restartgame:2, kick:4, changemission:8, lobby:16, chapter:32, alltalk:64, ALL:127>", FCVAR_NOTIFY, true, 0.0, true, 127.0);
	g_cvarBuiltinVote						= CreateConVar("sm_cvm_builtinvote", "1", "<builtinvotes> support", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarAnnouncer							= CreateConVar("sm_cvm_announcer", "1", "Announce voting calls", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarProgress							= CreateConVar("sm_cvm_progress", "1", "Show voting progress", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarProgressAnony						= CreateConVar("sm_cvm_progressanony", "0", "Show voting progress anonymously", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_cvarLobby								= CreateConVar("sm_cvm_lobby", "1", "Enable vote ReturnToLobby", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarChapter							= CreateConVar("sm_cvm_chapter", "1", "Enable vote ChangeChapter", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarAllTalk							= CreateConVar("sm_cvm_alltalk", "1", "Enable vote ChangeAllTalk", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_cvarAdminInmunity						= CreateConVar("sm_cvm_admininmunity", "", "Admins are immune to kick votes. Specify admin flags or blank.", FCVAR_NOTIFY);
	g_cvarSTVInmunity						= CreateConVar("sm_cvm_stvinmunity", "1", "SourceTV is immune to votekick", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarSelfInmunity						= CreateConVar("sm_cvm_selfinmunity", "1", "Immunity to self-kick", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarBotInmunity						= CreateConVar("sm_cvm_botinmunity", "1", "Immunity to bots", FCVAR_NOTIFY, true, 0.0, true, 1.0);

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

	g_cvarAdminInmunity.AddChangeHook(ConVarChanged_AdminInmunity);

	AutoExecConfig(false, "callvote_manager");
	InitializeVoteTypesMap();

	if (!g_bLateLoad)
		return;

	g_bBuiltinVotes = LibraryExists("BuiltinVotes");
	g_bConfogl = LibraryExists("confogl");
}

public void ConVarChanged_AdminInmunity(Handle hConVar, const char[] sOldValue, const char[] sNewValue)
{
	char sTempAdmin[32];
	g_cvarAdminInmunity.GetString(sTempAdmin, sizeof(sTempAdmin));
	g_iFlagsAdmin = ReadFlagString(sTempAdmin);

	ClearAdminFlagsCache();
}

public void OnPluginEnd()
{
	OnPluginEnd_SQL();

	if (g_mapVoteTypes != null)
		delete g_mapVoteTypes;
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
	Action preStartResult;
	if (type == Kick)
		preStartResult = ForwardCallVotePreStart(iClient, type, iTarget);
	else
		preStartResult = ForwardCallVotePreStart(iClient, type);

	if (preStartResult >= Plugin_Handled)
	{
		CVLog.Debug("[ProcessVoteCommon] Vote blocked by PreStart forward for client %d", iClient);
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
		return Plugin_Handled;
	}

	Action preExecuteResult;
	if (type == Kick)
		preExecuteResult = ForwardCallVotePreExecute(iClient, type, iTarget);
	else
		preExecuteResult = ForwardCallVotePreExecute(iClient, type);

	if (preExecuteResult >= Plugin_Handled)
	{
		CVLog.Debug("[ProcessVoteCommon] Vote blocked by PreExecute forward for client %d", iClient);
		return Plugin_Handled;
	}

	if (type == Kick)
	{
		ForwardCallVoteStart(iClient, type, iTarget);
		RegVote(type, iClient, iTarget);
		RegSQLVote(type, iClient, iTarget);
	}
	else
	{
		ForwardCallVoteStart(iClient, type);
		RegVote(type, iClient);
		RegSQLVote(type, iClient);
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

			if (g_cvarSTVInmunity.BoolValue && IsClientConnected(target) && IsClientSourceTV(target))
			{
				return VoteRestriction_Immunity;
			}

			if (g_cvarBotInmunity.BoolValue && IsClientConnected(target) && IsFakeClient(target))
			{
				return VoteRestriction_Immunity;
			}

			if (g_cvarSelfInmunity.BoolValue && target == client)
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
	bool	bAnonymous = g_cvarProgressAnony.BoolValue;

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
	bool	bAnonymous = g_cvarProgressAnony.BoolValue;

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
			CVLog.Debug("[RegVote] Failed to get AuthID for target %d", iTarget);
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
	
	CVLog.Debug("[ForwardCallVotePreStart] Forward called for client %d, vote type %d, target %d. Result: %d", 
		iClient, view_as<int>(voteType), target, view_as<int>(result));
	
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
	
	CVLog.Debug("[ForwardCallVoteStart] Vote started by client %d, vote type %d, target %d", 
		iClient, view_as<int>(voteType), target);
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
	
	CVLog.Debug("[ForwardCallVotePreExecute] Forward called for client %d, vote type %d, target %d. Result: %d", 
		iClient, view_as<int>(voteType), target, view_as<int>(result));
	
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
	
	CVLog.Debug("[ForwardCallVoteBlocked] Vote blocked for client %d, vote type %d, restriction %d, target %d", 
		iClient, view_as<int>(voteType), view_as<int>(restriction), target);
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