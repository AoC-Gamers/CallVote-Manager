#pragma semicolon 1
#pragma newdecls required

#include <sourcemod> 
#include <colors>
#include <callvote_core>
#include <dbi>

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define PLUGIN_VERSION	"2.0"
#define TAG				"[{olive}CallVote Debug{default}]"
#define CVT_LOG_TAG "CVT"
#define CVT_LOG_FILE "callvote_testing.log"

ConVar
	g_cvarEnable,
	g_cvarLogMode,
	g_cvarDebugMask,
	g_cvarForwardManager,
	g_cvarVoteStarted,
	g_cvarVoteEnded,
	g_cvarVoteChanged,
	g_cvarVotePassed,
	g_cvarVoteFailed,
	g_cvarVoteCastYes,
	g_cvarVoteCastNo,
	g_cvarVoteStart,
	g_cvarVotePass,
	g_cvarVoteFail,
	g_cvarVoteRegistered,
	g_cvarCallVoteFailed,
	g_cvarListenerVote,
	g_cvarListenerCallVote,
	g_cvarForwardPreStart,
	g_cvarForwardBlocked,
	g_cvarForwardPreExecute
	;

bool
	g_bSQLConnected;

Database
	g_db;

enum SQLDriver
{
	SQL_MySQL = 0,
	SQL_SQLite
}

SQLDriver
	g_SQLDriver;

CallVoteLogger g_Log = null;

#define MAX_STEAM_ID_LENGTH 32

stock char sTypeVotes[TypeVotes_Size][] = {
	"ChangeDifficulty",
	"RestartGame",
	"Kick",
	"ChangeMission",
	"ReturnToLobby",
	"ChangeChapter",
	"ChangeAllTalk"
};

/*****************************************************************
			P L U G I N   I N F O
*****************************************************************/

/**
 * Plugin information properties. Plugins can declare a global variable with
 * their info. Example,
 * SourceMod will display this information when a user inspects plugins in the
 * console.
 */
public Plugin myinfo =
{
	name		= "Call Vote Testing",
	author		= "lechuga",
	description = "Performs callvote manager forward testing",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/lechuga16/callvote_manager"

}

/*****************************************************************
			F O R W A R D   P U B L I C S
*****************************************************************/

/**
 * Called when the plugin is fully initialized and all known external references
 * are resolved. This is only called once in the lifetime of the plugin, and is
 * paired with OnPluginEnd().
 *
 * If any run-time error is thrown during this callback, the plugin will be marked
 * as failed.
 */
public void OnPluginStart()
{
	g_cvarEnable		   = CreateConVar("sm_cvt_enable", "1", "Enable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarLogMode		   = CallVoteEnsureLogModeConVar();
	g_cvarDebugMask		   = CreateConVar("sm_cvt_debug_mask", "0", "Debug mask for callvote_testing. Core=1 SQL=2 Cache=4 Commands=8 Identity=16 Forwards=32 Session=64 Localization=128 All=255.", FCVAR_NONE, true, 0.0, true, 255.0);
	g_Log				   = new CallVoteLogger(CVT_LOG_TAG, CVT_LOG_FILE, g_cvarLogMode, g_cvarDebugMask);
	g_cvarForwardManager   = CreateConVar("sm_cvt_forwardmanager", "1", "Enable manager forwards", FCVAR_NONE, true, 0.0, true, 1.0);

	g_cvarVoteStarted	   = CreateConVar("sm_cvt_votestarted", "1", "Enable vote_started event", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVoteEnded		   = CreateConVar("sm_cvt_voteended", "1", "Enable vote_ended event", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVoteChanged	   = CreateConVar("sm_cvt_votechanged", "1", "Enable vote_changed event", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVotePassed	   = CreateConVar("sm_cvt_votepassed", "1", "Enable vote_passed event", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVoteFailed	   = CreateConVar("sm_cvt_votefailed", "1", "Enable vote_failed event", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVoteCastYes	   = CreateConVar("sm_cvt_votecastyes", "1", "Enable vote_cast_yes event", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVoteCastNo	   = CreateConVar("sm_cvt_votecastno", "1", "Enable vote_cast_no event", FCVAR_NONE, true, 0.0, true, 1.0);

	g_cvarVoteStart		   = CreateConVar("sm_cvt_votestart", "1", "Enable VoteStart message", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVotePass		   = CreateConVar("sm_cvt_votepass", "1", "Enable VotePass message", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVoteFail		   = CreateConVar("sm_cvt_votefail", "1", "Enable VoteFail message", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarVoteRegistered   = CreateConVar("sm_cvt_voteregistered", "1", "Enable VoteRegistered message", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarCallVoteFailed   = CreateConVar("sm_cvt_callvotefailed", "1", "Enable CallVoteFailed message", FCVAR_NONE, true, 0.0, true, 1.0);

	g_cvarListenerVote	   = CreateConVar("sm_cvt_listenervote", "0", "Enable Vote listener", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarListenerCallVote = CreateConVar("sm_cvt_listenercallvote", "0", "Enable CallVote listener", FCVAR_NONE, true, 0.0, true, 1.0);

	g_cvarForwardPreStart  = CreateConVar("sm_cvt_forwardprestart", "1", "Enable CallVote_PreStart forward", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarForwardBlocked   = CreateConVar("sm_cvt_forwardblocked", "1", "Enable CallVote_Blocked forward", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarForwardPreExecute = CreateConVar("sm_cvt_forwardpreexecute", "1", "Enable CallVote_PreExecute forward", FCVAR_NONE, true, 0.0, true, 1.0);
	
	HookEvent("vote_started", Event_VoteStarted);
	HookEvent("vote_ended", Event_VoteEnded);
	HookEvent("vote_changed", Event_VoteChanged);
	HookEvent("vote_passed", Event_VotePassed);
	HookEvent("vote_failed", Event_VoteFailed);
	HookEvent("vote_cast_yes", Event_VoteCastYes);
	HookEvent("vote_cast_no", Event_VoteCastNo);

	HookUserMessage(GetUserMessageId("VoteStart"), Message_VoteStart);
	HookUserMessage(GetUserMessageId("VotePass"), Message_VotePass);
	HookUserMessage(GetUserMessageId("VoteFail"), Message_VoteFail);
	HookUserMessage(GetUserMessageId("VoteRegistered"), Message_VoteRegistered);
	HookUserMessage(GetUserMessageId("CallVoteFailed"), Message_CallVoteFailed);

	AddCommandListener(Listener_Vote, "Vote");
	AddCommandListener(Listener_CallVote, "callvote");

	RegConsoleCmd("sm_cvt_connected", Cmd_Connected, "Check if the database is connected");

}

Action Cmd_Connected(int iClient, int iArgs)
{
	if (!g_bSQLConnected)
	{
		CReplyToCommand(iClient, "%s {red}Could not{default} connect to database.", TAG);
		return Plugin_Handled;
	}
	else
		CReplyToCommand(iClient, "%s Database connected {green}successfully{default}.", TAG);

	CReplyToCommand(iClient, "%s Driver SQL: %s", TAG, g_SQLDriver == SQL_MySQL ? "MySQL" : "SQLite");

	char sTableLog[] = "callvote_log";

	if (isTableExists(sTableLog))
		CReplyToCommand(iClient, "%s Table %s exists.", TAG, sTableLog);
	else
		CReplyToCommand(iClient, "%s Table %s does not exist.", TAG, sTableLog);

	char sTableBans[] = "callvote_bans";

	if (isTableExists(sTableBans))
		CReplyToCommand(iClient, "%s Table %s exists.", TAG, sTableBans);
	else
		CReplyToCommand(iClient, "%s Table %s does not exist.", TAG, sTableBans);

	char sTableKick[] = "callvote_kicklimit";

	if (isTableExists(sTableKick))
		CReplyToCommand(iClient, "%s Table %s exists.", TAG, sTableKick);
	else
		CReplyToCommand(iClient, "%s Table %s does not exist.", TAG, sTableKick);

	return Plugin_Handled;
}

public void OnConfigsExecuted()
{
	if (!g_cvarEnable.BoolValue)
		return;

	if (g_db != null)
		return;

	ConnectDB("callvote");
}

public void CallVote_Start(int sessionId)
{
	if (!g_cvarForwardManager.BoolValue)
		return;

	int iClient;
	int iCallerAccountId;
	TypeVotes votes;
	int iTarget;
	int iTargetAccountId;
	char sArgument[64];
	if (!CallVoteCore_GetSessionInfo(sessionId, iClient, iCallerAccountId, votes, iTarget, iTargetAccountId, sArgument, sizeof(sArgument)))
		return;

	char sSteamID[MAX_STEAM_ID_LENGTH];
	CallVoteCore_GetClientSteamID2(iClient, sSteamID, sizeof(sSteamID));

	char
		sMessage[255];

	if (votes == Kick)
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_Start] session=%d {green}%s{default}: {blue}%N{default} ({blue}%s{default}) ({blue}%N{default}) called the vote.", TAG, sessionId, sTypeVotes[votes], iClient, sSteamID, iTarget);
		CPrintToChatAll(sMessage);
		CRemoveTags(sMessage, sizeof(sMessage));
		log(false, sMessage);
	}
	else
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_Start] session=%d {green}%s{default}: {blue}%N{default} ({blue}%s{default}) called the vote.", TAG, sessionId, sTypeVotes[votes], iClient, sSteamID);
		CPrintToChatAll(sMessage);
		CRemoveTags(sMessage, sizeof(sMessage));
		log(false, sMessage);
	}
}

/*
 * vote_started
 *
 *	"team"			"byte"		// ID del equipo (normalmente 0 = global)
 *	"initiator"		"long"		// entity id del cliente que inició la votación
 *	"issue"			"string"	// tipo de votación, ej. "Kick", "ChangeMission"
 *	"param1"		"string"	// parámetro adicional (ej. mapa, nombre del jugador)
 *	"param2"		"string"	// parámetro opcional, a veces vacío
 *
 */
public void Event_VoteStarted(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarVoteStarted.BoolValue)
		return;

	char sIssue[128];
	char sParam1[128];
	char sParam2[128];

	hEvent.GetString("issue", sIssue, sizeof(sIssue));
	hEvent.GetString("param1", sParam1, sizeof(sParam1));
	hEvent.GetString("param2", sParam2, sizeof(sParam2));
	int iTeam	   = hEvent.GetInt("team");
	int iInitiator = hEvent.GetInt("initiator");
	
	log(false, "[Event_VoteStarted] team: %d, initiator: %d, issue: %s, param1: %s, param2: %s", iTeam, iInitiator, sIssue, sParam1, sParam2);
	CPrintToChatAll("%s [Event_VoteStarted] team: %d, initiator: %d, issue: %s, param1: %s, param2: %s", TAG, iTeam, iInitiator, sIssue, sParam1, sParam2);
}

/*
 * vote_ended
 * 
 * Evento más importante - siempre se dispara cuando la votación termina
 *
 *	"team"			"byte"		// equipo que realizó la votación
 *	"success"		"byte/bool"	// 1 si la votación pasó, 0 si fracasó
 *	"vote_type"		"string"	// tipo de votación, ej. "Kick", "ChangeMission"
 *	"param1"		"string"	// parámetro (ej. mapa, nombre, id usuario)
 *	"param2"		"string"	// parámetro opcional, a menudo vacío
 *
 */
public void Event_VoteEnded(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarVoteEnded.BoolValue)
		return;

	char sVoteType[128];
	char sParam1[128];
	char sParam2[128];

	hEvent.GetString("vote_type", sVoteType, sizeof(sVoteType));
	hEvent.GetString("param1", sParam1, sizeof(sParam1));
	hEvent.GetString("param2", sParam2, sizeof(sParam2));
	int iTeam = hEvent.GetInt("team");
	int iSuccess = hEvent.GetInt("success");
	
	log(false, "[Event_VoteEnded] team: %d, success: %d, vote_type: %s, param1: %s, param2: %s", iTeam, iSuccess, sVoteType, sParam1, sParam2);
	CPrintToChatAll("%s [Event_VoteEnded] team: %d, success: %d (%s), vote_type: %s, param1: %s, param2: %s", TAG, iTeam, iSuccess, iSuccess ? "PASSED" : "FAILED", sVoteType, sParam1, sParam2);
}

/*
 * vote_changed"
 *
 *	"yesVotes"		"byte"
 *	"noVotes"		"byte"
 *	"potentialVotes"	"byte"
 *
 */
public void Event_VoteChanged(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarVoteChanged.BoolValue)
		return;

	int iYesVotes		= hEvent.GetInt("yesVotes");
	int iNoVotes		= hEvent.GetInt("noVotes");
	int iPotentialVotes = hEvent.GetInt("potentialVotes");
	log(false, "[Event_VoteChanged] yesVotes: %d, noVotes: %d, potentialVotes: %d", iYesVotes, iNoVotes, iPotentialVotes);
	CPrintToChatAll("%s [Event_VoteChanged] yesVotes: %d, noVotes: %d, potentialVotes: %d", TAG, iYesVotes, iNoVotes, iPotentialVotes);
}

/*
 * vote_passed
 * 
 * Se dispara después de vote_ended cuando la votación fue exitosa
 *
 *	"details"		"string"	// descripción breve del voto aprobado
 *	"param1"		"string"	// parámetro adicional (opcional)
 *	"team"			"byte"		// equipo (opcional)
 *
 */
public void Event_VotePassed(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarVotePassed.BoolValue)
		return;

	char sDetails[128];
	char sParam1[128];

	hEvent.GetString("details", sDetails, sizeof(sDetails));
	hEvent.GetString("param1", sParam1, sizeof(sParam1));
	int iTeam = hEvent.GetInt("team");
	
	log(false, "[Event_VotePassed] details: %s, param1: %s, team: %d", sDetails, sParam1, iTeam);
	CPrintToChatAll("%s [Event_VotePassed] details: %s, param1: %s, team: %d", TAG, sDetails, sParam1, iTeam);
}

/*
 * vote_failed
 * 
 * Se dispara después de vote_ended cuando la votación fracasó
 *
 *	"details"		"string"	// breve motivo o tipo de voto (a veces está vacío)
 *	"team"			"byte"		// equipo (opcional)
 *
 */
public void Event_VoteFailed(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarVoteFailed.BoolValue)
		return;

	char sDetails[128];
	hEvent.GetString("details", sDetails, sizeof(sDetails));
	int iTeam = hEvent.GetInt("team");
	
	log(false, "[Event_VoteFailed] details: %s, team: %d", sDetails, iTeam);
	CPrintToChatAll("%s [Event_VoteFailed] details: %s, team: %d", TAG, sDetails, iTeam);
}

/*
 * vote_cast_yes
 * 
 * Cuando un jugador vota sí (F1)
 *
 *	"team"			"byte"		// equipo del jugador
 *	"entityid"		"long"		// entity id del jugador que votó sí
 *
 */
public void Event_VoteCastYes(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarVoteCastYes.BoolValue)
		return;

	int iEntityid = hEvent.GetInt("entityid");
	int iTeam	  = hEvent.GetInt("team");

	if (!IsValidClientIndex(iEntityid))
		return;

	log(false, "[Event_VoteCastYes] team: %d, entityid: %d (%N)", iTeam, iEntityid, iEntityid);
	CPrintToChatAll("%s [Event_VoteCastYes] team: %d, entityid: %d (%N)", TAG, iTeam, iEntityid, iEntityid);
}

/*
 * vote_cast_no
 * 
 * Cuando un jugador vota no (F2)
 *
 *	"team"			"byte"		// equipo del jugador
 *	"entityid"		"long"		// entity id del jugador que votó no
 *
 */
public void Event_VoteCastNo(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_cvarVoteCastNo.BoolValue)
		return;

	int iEntityid = hEvent.GetInt("entityid");
	int iTeam	  = hEvent.GetInt("team");

	if (!IsValidClientIndex(iEntityid))
		return;

	log(false, "[Event_VoteCastNo] team: %d, entityid: %d (%N)", iTeam, iEntityid, iEntityid);
	CPrintToChatAll("%s [Event_VoteCastNo] team: %d, entityid: %d (%N)", TAG, iTeam, iEntityid, iEntityid);
}

/*
 * VoteStart Structure
 *	- Byte      Team index voting
 *	- Byte      Unknown, always 1 for Yes/No, always 99 for Multiple Choice
 *	- String    Vote issue id
 *	- String    Vote issue text
 *	- Bool      false for Yes/No, true for Multiple choice
 */
public Action Message_VoteStart(UserMsg hMsg_id, BfRead hBf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	if (!g_cvarVoteStart.BoolValue)
		return Plugin_Continue;

	char sIssue[128];
	char sParam1[128];
	char sInitiatorName[128];

	int	 iTeam		= BfReadByte(hBf);
	int	 iInitiator = BfReadByte(hBf);
	hBf.ReadString(sIssue, 128);
	hBf.ReadString(sParam1, 128);
	hBf.ReadString(sInitiatorName, 128);

	DataPack hdataPack;
	CreateDataTimer(0.1, Timer_CallVote_Start, hdataPack, TIMER_FLAG_NO_MAPCHANGE);
	hdataPack.WriteCell(iPlayersNum);
	hdataPack.WriteCell(iTeam);
	hdataPack.WriteCell(iInitiator);
	hdataPack.WriteString(sIssue);
	hdataPack.WriteString(sParam1);
	hdataPack.WriteString(sInitiatorName);

	log(false, "[Message_VoteStart] Sent to %d users: team: %d, initiator: %d, issue: %s, param1: %s, initiatorName: %s", iPlayersNum, iTeam, iInitiator, sIssue, sParam1, sInitiatorName);
	return Plugin_Continue;
}

Action Timer_CallVote_Start(Handle timer, DataPack datapack)
{
	datapack.Reset();
	int
		iPlayersNum = datapack.ReadCell(),
		iTeam		= datapack.ReadCell(),
		iInitiator	= datapack.ReadCell();
	char
		sIssue[128],
		sParam1[128],
		sInitiatorName[128];

	datapack.ReadString(sIssue, 128);
	datapack.ReadString(sParam1, 128);
	datapack.ReadString(sInitiatorName, 128);

	CPrintToChatAll("%s VoteStart(sent to %d users): team: %d, initiator: %d, issue: %s, param1: %s, initiatorName: %s", TAG, iPlayersNum, iTeam, iInitiator, sIssue, sParam1, sInitiatorName);
	return Plugin_Stop;
}

/*
 *	VotePass
 *	Note: Sent to all players after a vote passes.
 *
 *	Structure:
 *			byte	team	Team index or 255 for all
 *			string	details	Vote success translation string
 *			string	param1	Vote winner
 */
public Action Message_VotePass(UserMsg hMsg_id, BfRead hBf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	if (!g_cvarVotePass.BoolValue)
		return Plugin_Continue;

	char sIssue[128];
	char sParam1[128];
	int	 iTeam = hBf.ReadByte();
	hBf.ReadString(sIssue, 128);
	hBf.ReadString(sParam1, 128);

	DataPack hdataPack;
	CreateDataTimer(0.1, Timer_CallVote_Pass, hdataPack, TIMER_FLAG_NO_MAPCHANGE);
	hdataPack.WriteCell(iPlayersNum);
	hdataPack.WriteCell(iTeam);
	hdataPack.WriteString(sIssue);
	hdataPack.WriteString(sParam1);

	log(false, "[Message_VotePass] Sent to %d users: team: %d, issue: %s, param1: %s", iPlayersNum, iTeam, sIssue, sParam1);
	return Plugin_Continue;
}

Action Timer_CallVote_Pass(Handle timer, DataPack datapack)
{
	datapack.Reset();
	int
		iPlayersNum = datapack.ReadCell(),
		iTeam		= datapack.ReadCell();
	char
		sIssue[128],
		sParam1[128];

	datapack.ReadString(sIssue, 128);
	datapack.ReadString(sParam1, 128);

	CPrintToChatAll("%s VotePass(sent to %d users): team: %d, issue: %s, param1: %s", TAG, iPlayersNum, iTeam, sIssue, sParam1);
	return Plugin_Stop;
}
/*
 *	VoteFail
 *	Note: Sent to all players after a vote fails.
 *
 *	Structure:
 *			byte	team	Team index or 255 for all
 */
public Action Message_VoteFail(UserMsg hMsg_id, BfRead hBf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	if (!g_cvarVoteFail.BoolValue)
		return Plugin_Continue;

	char sIssue[128];
	char sParam1[128];
	int	 iTeam = hBf.ReadByte();
	hBf.ReadString(sIssue, 128);
	hBf.ReadString(sParam1, 128);

	DataPack hdataPack;
	CreateDataTimer(0.1, Timer_CallVote_Fail, hdataPack, TIMER_FLAG_NO_MAPCHANGE);
	hdataPack.WriteCell(iPlayersNum);
	hdataPack.WriteCell(iTeam);
	hdataPack.WriteString(sIssue);
	hdataPack.WriteString(sParam1);

	log(false, "[Message_VoteFail] Sent to %d users: team: %d, issue: %s, param1: %s", iPlayersNum, iTeam, sIssue, sParam1);
	return Plugin_Continue;
}

Action Timer_CallVote_Fail(Handle timer, DataPack datapack)
{
	datapack.Reset();
	int
		iPlayersNum = datapack.ReadCell(),
		iTeam		= datapack.ReadCell();
	char
		sIssue[128],
		sParam1[128];

	datapack.ReadString(sIssue, 128);
	datapack.ReadString(sParam1, 128);

	CPrintToChatAll("%s VoteFail(sent to %d users): team: %d, issue: %s, param1: %s", TAG, iPlayersNum, iTeam, sIssue, sParam1);
	return Plugin_Stop;
}

/*
 * CallVoteFailed
 *    - Byte		Team index voting
 *   - Short		Failure reason
 */
public Action Message_CallVoteFailed(UserMsg hMsg_id, BfRead hBf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	if (!g_cvarCallVoteFailed.BoolValue)
		return Plugin_Continue;

	int		 iReason	= BfReadByte(hBf);
	int		 iTime		= BfReadShort(hBf);
	int		 iBytesLeft = BfReadByte(hBf);

	DataPack hdataPack;
	CreateDataTimer(0.1, Timer_CallVoteFailed, hdataPack, TIMER_FLAG_NO_MAPCHANGE);
	hdataPack.WriteCell(iPlayersNum);
	hdataPack.WriteCell(iReason);
	hdataPack.WriteCell(iTime);
	hdataPack.WriteCell(iBytesLeft);

	log(false, "[Message_CallVoteFailed] Sent to %d users: reason: %d, time: %d, bytes: %d", iPlayersNum, iReason, iTime, iBytesLeft);
	return Plugin_Continue;
}

Action Timer_CallVoteFailed(Handle timer, DataPack datapack)
{
	datapack.Reset();
	int
		iPlayersNum = datapack.ReadCell(),
		iReason		= datapack.ReadCell(),
		iTime		= datapack.ReadCell(),
		iBytesLeft	= datapack.ReadCell();

	CPrintToChatAll("%s CallVoteFailed(sent to %d users): reason: %d, time: %d, bytes: %d", TAG, iPlayersNum, iReason, iTime, iBytesLeft);
	return Plugin_Stop;
}

/*
 * VoteRegistered
 *    - Byte		Item selected
 */
public Action Message_VoteRegistered(UserMsg hMsg_id, BfRead hBf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	if (!g_cvarVoteRegistered.BoolValue)
		return Plugin_Continue;

	int		 iItem = BfReadByte(hBf);

	DataPack hdataPack;
	CreateDataTimer(0.1, Timer_VoteRegistered, hdataPack, TIMER_FLAG_NO_MAPCHANGE);
	hdataPack.WriteCell(iPlayersNum);
	hdataPack.WriteCell(iItem);

	log(false, "[Message_VoteRegistered] Sent to %d users: item: %d", iPlayersNum, iItem);
	return Plugin_Continue;
}

Action Timer_VoteRegistered(Handle timer, DataPack datapack)
{
	datapack.Reset();
	int
		iPlayersNum = datapack.ReadCell(),
		iItem		= datapack.ReadCell();

	CPrintToChatAll("%s VoteRegistered(sent to %d users): item: %d", TAG, iPlayersNum, iItem);
	return Plugin_Stop;
}

/**
 * Listener_Vote - Called when a vote is casted by a player.
 *
 * @param iClient The client index of the player who casted the vote.
 * @param sCommand The command string that triggered the vote.
 * @param iArgc The number of arguments passed with the vote command.
 *
 * @return Plugin_Continue to allow other plugins to process the vote, Plugin_Handled to stop other plugins from processing the vote.
 */
public Action Listener_Vote(int iClient, const char[] sCommand, int iArgc)
{
	if (!g_cvarListenerVote.BoolValue)
		return Plugin_Continue;

	char sVote[255];
	GetCmdArg(1, sVote, 255);

	log(false, "[Listener_Vote] client: %N, vote: %s", iClient, sVote);
	CPrintToChatAll("%s [Listener_Vote] client: %N, vote: %s", TAG, iClient, sVote);
	return Plugin_Continue;
}

/**
 * Listener_CallVote - Called when a player calls a vote.
 *
 * @param iClient The client index of the player who called the vote.
 * @param sCommand The command string that was used to call the vote.
 * @param iArgc The number of arguments passed with the command.
 *
 * @return Plugin_Continue to allow other plugins to process the vote, or Plugin_Handled to stop processing.
 */
public Action Listener_CallVote(int iClient, const char[] sCommand, int iArgc)
{
	if (!g_cvarListenerCallVote.BoolValue)
		return Plugin_Continue;

	char sVoteType[32];
	char sVoteArgument[32];

	GetCmdArg(1, sVoteType, sizeof(sVoteType));
	GetCmdArg(2, sVoteArgument, sizeof(sVoteArgument));


	log(false, "[Listener_CallVote] client: %N, votetype: %s, sVoteArgument: %s", iClient, sVoteType, sVoteArgument);
	CPrintToChatAll("%s [Listener_CallVote] client: %N, votetype: %s, sVoteArgument: %s", TAG, iClient, sVoteType, sVoteArgument);
	return Plugin_Continue;
}

/**
 * Forward para CallVote_PreStart - permite bloquear votos antes de la validación
 */
public Action CallVote_PreStart(int sessionId, int iClient, int iCallerAccountId, TypeVotes voteType, int iTarget, int iTargetAccountId, const char[] sArgument)
{
	if (!g_cvarForwardPreStart.BoolValue)
		return Plugin_Continue;

	char sSteamID[MAX_STEAM_ID_LENGTH];
	CallVoteCore_GetClientSteamID2(iClient, sSteamID, sizeof(sSteamID));

	char sMessage[255];
	if (voteType == Kick)
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_PreStart] session=%d {green}%s{default}: {blue}%N{default} ({blue}%s{default}) targeting {blue}%N{default}", TAG, sessionId, sTypeVotes[voteType], iClient, sSteamID, iTarget);
	}
	else
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_PreStart] session=%d {green}%s{default}: {blue}%N{default} ({blue}%s{default}) arg={olive}%s{default}", TAG, sessionId, sTypeVotes[voteType], iClient, sSteamID, sArgument);
	}
	
	CPrintToChatAll(sMessage);
	CRemoveTags(sMessage, sizeof(sMessage));
	log(false, sMessage);
	
	// Retornar Plugin_Continue para permitir el voto, Plugin_Handled para bloquearlo
	return Plugin_Continue;
}

/**
 * Forward para CallVote_PreExecute - última oportunidad para bloquear antes de la ejecución
 */
public Action CallVote_PreExecute(int sessionId, int iClient, int iCallerAccountId, TypeVotes voteType, int iTarget, int iTargetAccountId, const char[] sArgument)
{
	if (!g_cvarForwardPreExecute.BoolValue)
		return Plugin_Continue;

	char sSteamID[MAX_STEAM_ID_LENGTH];
	CallVoteCore_GetClientSteamID2(iClient, sSteamID, sizeof(sSteamID));

	char sMessage[255];
	if (voteType == Kick)
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_PreExecute] session=%d {green}%s{default}: {blue}%N{default} ({blue}%s{default}) targeting {blue}%N{default}", TAG, sessionId, sTypeVotes[voteType], iClient, sSteamID, iTarget);
	}
	else
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_PreExecute] session=%d {green}%s{default}: {blue}%N{default} ({blue}%s{default}) arg={olive}%s{default}", TAG, sessionId, sTypeVotes[voteType], iClient, sSteamID, sArgument);
	}
	
	CPrintToChatAll(sMessage);
	CRemoveTags(sMessage, sizeof(sMessage));
	log(false, sMessage);
	
	return Plugin_Continue;
}

/**
 * Forward para CallVote_Blocked - información sobre votos bloqueados
 */
public void CallVote_Blocked(int sessionId, int iClient, int iCallerAccountId, TypeVotes voteType, VoteRestrictionType restriction, int iTarget, int iTargetAccountId, const char[] sArgument)
{
	if (!g_cvarForwardBlocked.BoolValue)
		return;

	char sSteamID[MAX_STEAM_ID_LENGTH];
	CallVoteCore_GetClientSteamID2(iClient, sSteamID, sizeof(sSteamID));

	char sRestriction[64];
	GetRestrictionName(restriction, sRestriction, sizeof(sRestriction));

	char sMessage[255];
	if (voteType == Kick)
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_Blocked] session=%d {green}%s{default}: {blue}%N{default} ({blue}%s{default}) targeting {blue}%N{default} - Restriction: {red}%s{default}", TAG, sessionId, sTypeVotes[voteType], iClient, sSteamID, iTarget, sRestriction);
	}
	else
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_Blocked] session=%d {green}%s{default}: {blue}%N{default} ({blue}%s{default}) - Restriction: {red}%s{default}", TAG, sessionId, sTypeVotes[voteType], iClient, sSteamID, sRestriction);
	}
	
	CPrintToChatAll(sMessage);
	CRemoveTags(sMessage, sizeof(sMessage));
	log(false, sMessage);
}

/*****************************************************************
			F U N C I O N E S   A U X I L I A R E S
*****************************************************************/

/**
 * Convierte el tipo de restricción a una cadena legible
 */
void GetRestrictionName(VoteRestrictionType restriction, char[] buffer, int maxlen)
{
	switch (restriction)
	{
		case VoteRestriction_None: strcopy(buffer, maxlen, "None");
		case VoteRestriction_InvalidCaller: strcopy(buffer, maxlen, "InvalidCaller");
		case VoteRestriction_ClientState: strcopy(buffer, maxlen, "ClientState");
		case VoteRestriction_Cooldown: strcopy(buffer, maxlen, "Cooldown");
		case VoteRestriction_ConVar: strcopy(buffer, maxlen, "ConVar");
		case VoteRestriction_GameMode: strcopy(buffer, maxlen, "GameMode");
		case VoteRestriction_SameState: strcopy(buffer, maxlen, "SameState");
		case VoteRestriction_Immunity: strcopy(buffer, maxlen, "Immunity");
		case VoteRestriction_Team: strcopy(buffer, maxlen, "Team");
		case VoteRestriction_Target: strcopy(buffer, maxlen, "Target");
		default: strcopy(buffer, maxlen, "Unknown");
	}
}

/**
 * Función de logging simplificada
 */
void log(bool error, const char[] format, any ...)
{
	if (g_Log == null)
		return;
	
	char message[512];
	VFormat(message, sizeof(message), format, 3);
	
	if (error)
		LogError("%s", message);
	
	g_Log.Debug(CVLogMask_Core, "Core", "%s", message);
	
}

/**
 * Verificar si una tabla existe en la base de datos
 */
bool isTableExists(const char[] tableName)
{
	// Implementación simplificada para testing
	// En una implementación real se haría una consulta SQL
	log(false, "[isTableExists] Checking table: %s", tableName);
	return g_bSQLConnected;
}

/**
 * Conectar a la base de datos (stub para testing)
 */
void ConnectDB(const char[] name)
{
	log(false, "[ConnectDB] Connecting to database: %s", name);
	g_bSQLConnected = true;
	g_SQLDriver = SQL_SQLite;
}

public void OnPluginEnd()
{
	if (g_Log != null)
		delete g_Log;
}
