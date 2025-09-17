#pragma semicolon 1
#pragma newdecls required

#include <sourcemod> 
#include <colors>
#include <callvotemanager>
#include <dbi>

/*****************************************************************
			C O N F I G U R A C I O N
*****************************************************************/

// Activa/desactiva las pruebas de CallVote Bans para reducir ruido durante desarrollo
// Comenta esta línea para deshabilitar todas las pruebas relacionadas con CallVote Bans
// Esto incluye:
//   - Comandos de prueba de códigos de mensaje (sm_cvt_testmessage, etc.)
//   - Comandos de prueba de procedimientos almacenados (sm_cvt_testcheck, etc.)
//   - Variables ConVar específicas de CallVote Bans
//   - Funciones auxiliares para manejo de códigos de mensaje
#define CALLVOTE_BANS

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define PLUGIN_VERSION	"2.0"
#define TAG				"[{olive}CallVote Debug{default}]"

ConVar
	g_cvarDebug,
	g_cvarEnable,
	g_cvarLog,
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
	g_cvarForwardPreExecute,
	g_cvarNativesTest

#if defined CALLVOTE_BANS
	// ConVars para pruebas de códigos de mensaje
	,g_cvarTestMessageCodes,
	g_cvarTestStoredProcs,
	g_cvarTestTranslations
#endif
	;

char
	g_sLogPath[PLATFORM_MAX_PATH];

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
	CreateConVar("sm_cvt_version", PLUGIN_VERSION, "Plugin version", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	g_cvarDebug			   = CreateConVar("sm_cvt_debug", "1", "Enable debug", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarEnable		   = CreateConVar("sm_cvt_enable", "1", "Enable plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarLog			   = CreateConVar("sm_cvt_logs", "1", "Enable logging", FCVAR_NONE, true, 0.0, true, 1.0);
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
	g_cvarNativesTest      = CreateConVar("sm_cvt_nativestest", "1", "Enable natives testing", FCVAR_NONE, true, 0.0, true, 1.0);
	
#if defined CALLVOTE_BANS
	// ConVars para pruebas de códigos de mensaje
	g_cvarTestMessageCodes = CreateConVar("sm_cvt_testmessagecodes", "1", "Enable message codes testing", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarTestStoredProcs = CreateConVar("sm_cvt_teststoredprocs", "1", "Enable stored procedures testing", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvarTestTranslations = CreateConVar("sm_cvt_testtranslations", "1", "Enable translations testing", FCVAR_NONE, true, 0.0, true, 1.0);
#endif

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

	// Build log path
	BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), DIR_CALLVOTE);

	RegConsoleCmd("sm_cvt_connected", Cmd_Connected, "Check if the database is connected");
	RegConsoleCmd("sm_cvt_testconvar", Cmd_TestConVar, "Test ConVar vote allowance");
	RegConsoleCmd("sm_cvt_testgamemode", Cmd_TestGameMode, "Test GameMode vote allowance");
	
#if defined CALLVOTE_BANS
	// Comandos para pruebas de códigos de mensaje y procedimientos almacenados
	RegConsoleCmd("sm_cvt_testmessage", Cmd_TestMessageCode, "Test message code system");
	RegConsoleCmd("sm_cvt_testcheck", Cmd_TestCheckBan, "Test sp_CheckActiveBan stored procedure");
	RegConsoleCmd("sm_cvt_testinsert", Cmd_TestInsertBan, "Test sp_InsertBanWithValidation stored procedure");
	RegConsoleCmd("sm_cvt_testremove", Cmd_TestRemoveBan, "Test sp_RemoveBan stored procedure");
	RegConsoleCmd("sm_cvt_testclean", Cmd_TestCleanExpired, "Test sp_CleanExpiredBans stored procedure");
	RegConsoleCmd("sm_cvt_teststats", Cmd_TestBanStats, "Test sp_GetBanStatistics stored procedure");
	RegConsoleCmd("sm_cvt_testtranslation", Cmd_TestTranslation, "Test translation system with codes");
	RegConsoleCmd("sm_cvt_testbaninfo", Cmd_TestBanInfo, "Test ban info display with codes");
	
	// Cargar traducciones para pruebas
	LoadTranslations("callvote_database.phrases");
#endif

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

public void CallVote_Start(int iClient, TypeVotes votes, int iTarget)
{
	if (!g_cvarForwardManager.BoolValue)
		return;

	// Get the client's SteamID
	char sSteamID[MAX_STEAM_ID_LENGTH];
	GetClientAuthId(iClient, AuthId_Engine, sSteamID, MAX_STEAM_ID_LENGTH);

	char
		sMessage[255];

	if (votes == Kick)
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_Start] {green}%s{default}: {blue}%N{default} ({blue}%s{default}) ({blue}%N{default}) called the vote.", TAG, sTypeVotes[votes], iClient, sSteamID, iTarget);
		CPrintToChatAll(sMessage);
		CRemoveTags(sMessage, sizeof(sMessage));
		log(false, sMessage);
	}
	else
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_Start] {green}%s{default}: {blue}%N{default} ({blue}%s{default}) called the vote.", TAG, sTypeVotes[votes], iClient, sSteamID);
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
 *   - Short		Failure reason code
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
public Action CallVote_PreStart(int iClient, TypeVotes voteType, int iTarget)
{
	if (!g_cvarForwardPreStart.BoolValue)
		return Plugin_Continue;

	char sSteamID[MAX_STEAM_ID_LENGTH];
	GetClientAuthId(iClient, AuthId_Engine, sSteamID, MAX_STEAM_ID_LENGTH);

	char sMessage[255];
	if (voteType == Kick)
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_PreStart] {green}%s{default}: {blue}%N{default} ({blue}%s{default}) targeting {blue}%N{default}", TAG, sTypeVotes[voteType], iClient, sSteamID, iTarget);
	}
	else
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_PreStart] {green}%s{default}: {blue}%N{default} ({blue}%s{default})", TAG, sTypeVotes[voteType], iClient, sSteamID);
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
public Action CallVote_PreExecute(int iClient, TypeVotes voteType, int iTarget)
{
	if (!g_cvarForwardPreExecute.BoolValue)
		return Plugin_Continue;

	char sSteamID[MAX_STEAM_ID_LENGTH];
	GetClientAuthId(iClient, AuthId_Engine, sSteamID, MAX_STEAM_ID_LENGTH);

	char sMessage[255];
	if (voteType == Kick)
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_PreExecute] {green}%s{default}: {blue}%N{default} ({blue}%s{default}) targeting {blue}%N{default}", TAG, sTypeVotes[voteType], iClient, sSteamID, iTarget);
	}
	else
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_PreExecute] {green}%s{default}: {blue}%N{default} ({blue}%s{default})", TAG, sTypeVotes[voteType], iClient, sSteamID);
	}
	
	CPrintToChatAll(sMessage);
	CRemoveTags(sMessage, sizeof(sMessage));
	log(false, sMessage);
	
	return Plugin_Continue;
}

/**
 * Forward para CallVote_Blocked - información sobre votos bloqueados
 */
public void CallVote_Blocked(int iClient, TypeVotes voteType, VoteRestrictionType restriction, int iTarget)
{
	if (!g_cvarForwardBlocked.BoolValue)
		return;

	char sSteamID[MAX_STEAM_ID_LENGTH];
	GetClientAuthId(iClient, AuthId_Engine, sSteamID, MAX_STEAM_ID_LENGTH);

	char sRestriction[64];
	GetRestrictionName(restriction, sRestriction, sizeof(sRestriction));

	char sMessage[255];
	if (voteType == Kick)
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_Blocked] {green}%s{default}: {blue}%N{default} ({blue}%s{default}) targeting {blue}%N{default} - Restriction: {red}%s{default}", TAG, sTypeVotes[voteType], iClient, sSteamID, iTarget, sRestriction);
	}
	else
	{
		Format(sMessage, sizeof(sMessage), "%s [CallVote_Blocked] {green}%s{default}: {blue}%N{default} ({blue}%s{default}) - Restriction: {red}%s{default}", TAG, sTypeVotes[voteType], iClient, sSteamID, sRestriction);
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
	if (!g_cvarLog.BoolValue)
		return;

	char message[512];
	VFormat(message, sizeof(message), format, 3);
	
	if (error)
		LogError("%s", message);
	
	LogToFileEx(g_sLogPath, "%s", message);
	
	// Debug adicional si está habilitado
	if (g_cvarDebug.BoolValue && error)
		PrintToServer("[CallVote Testing Debug] %s", message);
}

/**
 * Verificar si una tabla existe en la base de datos
 */
bool isTableExists(const char[] tableName)
{
	// Implementación simplificada para testing
	// En una implementación real se haría una consulta SQL
	LogToFileEx(g_sLogPath, "[isTableExists] Checking table: %s", tableName);
	return g_bSQLConnected;
}

/**
 * Conectar a la base de datos (stub para testing)
 */
void ConnectDB(const char[] name)
{
	LogToFileEx(g_sLogPath, "[ConnectDB] Connecting to database: %s", name);
	g_bSQLConnected = true;
	g_SQLDriver = SQL_SQLite;
}

#if defined CALLVOTE_BANS
/*****************************************************************
    FUNCIONES DE PRUEBA PARA CÓDIGOS DE MENSAJE
*****************************************************************/

/**
 * Comando para probar el sistema de códigos de mensaje
 * Uso: sm_cvt_testmessage [código]
 */
Action Cmd_TestMessageCode(int client, int args)
{
    if (!g_cvarTestMessageCodes.BoolValue) {
        CReplyToCommand(client, "%s Message codes testing is disabled.", TAG);
        return Plugin_Handled;
    }
    
    if (args < 1) {
        CReplyToCommand(client, "%s Usage: sm_cvt_testmessage <message_code>", TAG);
        CReplyToCommand(client, "%s Examples:", TAG);
        CReplyToCommand(client, "%s   sm_cvt_testmessage #ISBANNED", TAG);
        CReplyToCommand(client, "%s   sm_cvt_testmessage #BAN_INSERTED_SUCCESS:123", TAG);
        CReplyToCommand(client, "%s   sm_cvt_testmessage #EXISTING_BAN_ACTIVE:456", TAG);
        return Plugin_Handled;
    }
    
    char messageCode[256];
    GetCmdArg(1, messageCode, sizeof(messageCode));
    
    // Simular procesamiento de código de mensaje
    TestProcessMessageCode(client, messageCode);
    
    return Plugin_Handled;
}

/**
 * Simula el procesamiento de un código de mensaje
 */
void TestProcessMessageCode(int client, const char[] messageCode)
{
    CReplyToCommand(client, "%s Testing message code: %s", TAG, messageCode);
    
    if (messageCode[0] != '#') {
        CReplyToCommand(client, "%s {red}Error{default}: Message code should start with #", TAG);
        return;
    }
    
    // Parsear código base y parámetros
    char codeBase[64], parameters[256];
    ParseTestMessageCode(messageCode, codeBase, sizeof(codeBase), parameters, sizeof(parameters));
    
    CReplyToCommand(client, "%s Code base: {green}%s{default}", TAG, codeBase);
    if (strlen(parameters) > 0) {
        CReplyToCommand(client, "%s Parameters: {blue}%s{default}", TAG, parameters);
    }
    
    // Probar traducción
    char translatedMessage[512];
    if (TestFormatMessage(client, codeBase, parameters, translatedMessage, sizeof(translatedMessage))) {
        CReplyToCommand(client, "%s {green}Translated{default}: %s", TAG, translatedMessage);
    } else {
        CReplyToCommand(client, "%s {red}Translation failed{default} for code: %s", TAG, codeBase);
    }
}

/**
 * Parsea un código de mensaje de prueba
 */
void ParseTestMessageCode(const char[] messageCode, char[] codeBase, int codeBaseSize, char[] parameters, int paramSize)
{
    codeBase[0] = '\0';
    parameters[0] = '\0';
    
    // Remover el # inicial
    char cleanCode[256];
    strcopy(cleanCode, sizeof(cleanCode), messageCode[1]);
    
    // Buscar separador ':'
    int colonPos = FindCharInString(cleanCode, ':');
    
    if (colonPos == -1) {
        strcopy(codeBase, codeBaseSize, cleanCode);
        return;
    }
    
    // Separar código base y parámetros
    strcopy(codeBase, (colonPos + 1 > codeBaseSize) ? codeBaseSize : colonPos + 1, cleanCode);
    strcopy(parameters, paramSize, cleanCode[colonPos + 1]);
}

/**
 * Prueba formateo de mensaje con traducción
 */
bool TestFormatMessage(int client, const char[] codeBase, const char[] parameters, char[] output, int maxlen)
{
    if (strlen(parameters) == 0) {
        Format(output, maxlen, "%T", codeBase, client);
    } else {
        char paramArray[4][64];
        int paramCount = ExplodeString(parameters, ":", paramArray, sizeof(paramArray), sizeof(paramArray[]));
        
        switch (paramCount) {
            case 1: Format(output, maxlen, "%T", codeBase, client, paramArray[0]);
            case 2: Format(output, maxlen, "%T", codeBase, client, paramArray[0], paramArray[1]);
            case 3: Format(output, maxlen, "%T", codeBase, client, paramArray[0], paramArray[1], paramArray[2]);
            default: Format(output, maxlen, "%T", codeBase, client);
        }
    }
    
    // Verificar si la traducción funcionó (no debería ser igual al código)
    return !StrEqual(output, codeBase);
}

/**
 * Comando para probar el procedimiento sp_CheckActiveBan
 */
Action Cmd_TestCheckBan(int client, int args)
{
    if (!g_cvarTestStoredProcs.BoolValue) {
        CReplyToCommand(client, "%s Stored procedures testing is disabled.", TAG);
        return Plugin_Handled;
    }
    
    if (!g_bSQLConnected || g_db == null) {
        CReplyToCommand(client, "%s {red}Database not connected{default}. Cannot test stored procedures.", TAG);
        return Plugin_Handled;
    }
    
    int targetAccountId;
    if (args >= 1) {
        char arg[32];
        GetCmdArg(1, arg, sizeof(arg));
        targetAccountId = StringToInt(arg);
    } else {
        targetAccountId = GetSteamAccountID(client);
    }
    
    if (targetAccountId <= 0) {
        CReplyToCommand(client, "%s {red}Invalid Account ID{default}. Usage: sm_cvt_testcheck [account_id]", TAG);
        return Plugin_Handled;
    }
    
    CReplyToCommand(client, "%s Testing sp_CheckActiveBan for Account ID: %d", TAG, targetAccountId);
    TestStoredProcCheckBan(client, targetAccountId);
    
    return Plugin_Handled;
}

/**
 * Prueba el procedimiento almacenado sp_CheckActiveBan
 */
void TestStoredProcCheckBan(int client, int accountId)
{
    char sQuery[512];
    DataPack dp = new DataPack();
    dp.WriteCell(GetClientUserId(client));
    dp.WriteCell(accountId);
    dp.WriteCell(GetTime());
    
    Format(sQuery, sizeof(sQuery),
        "CALL sp_CheckActiveBan(%d, @has_ban, @ban_type, @expires_timestamp, @created_timestamp, @duration_minutes, @admin_account_id, @reason, @steam_id2, @ban_id)",
        accountId);
    
    CReplyToCommand(client, "%s Executing: %s", TAG, sQuery);
    SQL_TQuery(g_db, TestCheckBan_Callback, sQuery, dp);
}

public void TestCheckBan_Callback(Handle owner, Handle hndl, const char[] error, DataPack dp)
{
    dp.Reset();
    int userId = dp.ReadCell();
    int accountId = dp.ReadCell();
    dp.ReadCell();
    delete dp;
    
    int client = GetClientOfUserId(userId);
    if (client == SERVER_INDEX) return;
    
    if (hndl == null) {
        CReplyToCommand(client, "%s {red}Error{default} in sp_CheckActiveBan: %s", TAG, error);
        return;
    }
    
    // Obtener variables de salida
    char sQuery[256];
    DataPack dp2 = new DataPack();
    dp2.WriteCell(userId);
    dp2.WriteCell(accountId);
    
    Format(sQuery, sizeof(sQuery),
        "SELECT @has_ban, @ban_type, @expires_timestamp, @created_timestamp, @duration_minutes, @admin_account_id, @reason, @steam_id2, @ban_id");
    
    SQL_TQuery(g_db, TestCheckBan_Results, sQuery, dp2);
}

public void TestCheckBan_Results(Handle owner, Handle hndl, const char[] error, DataPack dp)
{
    dp.Reset();
    int userId = dp.ReadCell();
    int accountId = dp.ReadCell();
    delete dp;
    
    int client = GetClientOfUserId(userId);
    if (client == SERVER_INDEX) return;

    if (hndl == null || !SQL_FetchRow(hndl)) {
        CReplyToCommand(client, "%s {red}Error{default} getting results: %s", TAG, error);
        return;
    }
    
    bool hasBan = SQL_FetchBool(hndl, 0);
    
    CReplyToCommand(client, "%s {green}sp_CheckActiveBan Results{default} for Account ID %d:", TAG, accountId);
    CReplyToCommand(client, "%s Has Ban: {blue}%s{default}", TAG, hasBan ? "YES" : "NO");
    
    if (hasBan) {
        int banType = SQL_FetchInt(hndl, 1);
        int expiresTimestamp = SQL_FetchInt(hndl, 2);
        int createdTimestamp = SQL_FetchInt(hndl, 3);
        int durationMinutes = SQL_FetchInt(hndl, 4);
        int adminAccountId = SQL_FetchInt(hndl, 5);
        
        char reason[256], steamId2[32];
        SQL_FetchString(hndl, 6, reason, sizeof(reason));
        SQL_FetchString(hndl, 7, steamId2, sizeof(steamId2));
        int banId = SQL_FetchInt(hndl, 8);
        
        CReplyToCommand(client, "%s Ban ID: {blue}%d{default}, Type: {blue}%d{default}", TAG, banId, banType);
        CReplyToCommand(client, "%s Duration: {blue}%d{default} minutes", TAG, durationMinutes);
        CReplyToCommand(client, "%s Expires: {blue}%d{default} (%s)", TAG, expiresTimestamp, expiresTimestamp == 0 ? "PERMANENT" : "TEMPORARY");
        CReplyToCommand(client, "%s Admin: {blue}%s{default} (ID: %d)", TAG, steamId2, adminAccountId);
        CReplyToCommand(client, "%s Reason: {blue}%s{default}", TAG, strlen(reason) > 0 ? reason : "No reason");
        
        // Probar códigos de mensaje relacionados
        TestProcessMessageCode(client, "#ISBANNED");
        if (expiresTimestamp == 0) {
            TestProcessMessageCode(client, "#BAN_PERMANENT");
        }
    } else {
        TestProcessMessageCode(client, "#BAN_NOT_FOUND");
    }
}

/**
 * Comando para probar inserción de ban de prueba
 */
Action Cmd_TestInsertBan(int client, int args)
{
    if (!g_cvarTestStoredProcs.BoolValue) {
        CReplyToCommand(client, "%s Stored procedures testing is disabled.", TAG);
        return Plugin_Handled;
    }
    
    if (!g_bSQLConnected || g_db == null) {
        CReplyToCommand(client, "%s {red}Database not connected{default}. Cannot test stored procedures.", TAG);
        return Plugin_Handled;
    }
    
    // Usar datos de prueba
    int testAccountId = 123456789;  // Account ID de prueba
    char testSteamId2[32] = "STEAM_1:0:61728394";
    int banType = 1;
    int durationMinutes = 60;  // 1 hora de prueba
    char reason[256] = "Test ban from callvote_testing";
    
    if (args >= 1) {
        char arg[32];
        GetCmdArg(1, arg, sizeof(arg));
        testAccountId = StringToInt(arg);
    }
    
    CReplyToCommand(client, "%s Testing sp_InsertBanWithValidation with test data:", TAG);
    CReplyToCommand(client, "%s Account ID: {blue}%d{default}", TAG, testAccountId);
    CReplyToCommand(client, "%s Steam ID2: {blue}%s{default}", TAG, testSteamId2);
    CReplyToCommand(client, "%s Ban Type: {blue}%d{default}, Duration: {blue}%d{default} minutes", TAG, banType, durationMinutes);
    
    TestStoredProcInsertBan(client, testAccountId, testSteamId2, banType, durationMinutes, reason);
    
    return Plugin_Handled;
}

/**
 * Prueba el procedimiento almacenado sp_InsertBanWithValidation
 */
void TestStoredProcInsertBan(int client, int targetAccountId, const char[] targetSteamId2, 
                            int banType, int durationMinutes, const char[] reason)
{
    int adminAccountId = GetSteamAccountID(client);
    char adminSteamId2[32], escapedReason[512], sServerIP[16] = "127.0.0.1";
    
    GetClientAuthId(client, AuthId_Steam2, adminSteamId2, sizeof(adminSteamId2));
    g_db.Escape(reason, escapedReason, sizeof(escapedReason));
    
    char sQuery[1024];
    DataPack dp = new DataPack();
    dp.WriteCell(GetClientUserId(client));
    dp.WriteCell(targetAccountId);
    dp.WriteString(targetSteamId2);
    dp.WriteCell(banType);
    dp.WriteCell(durationMinutes);
    dp.WriteString(reason);
    
    Format(sQuery, sizeof(sQuery),
        "CALL sp_InsertBanWithValidation(%d, '%s', %d, %d, %d, '%s', '%s', '%s', @ban_id, @result_code, @message)",
        targetAccountId, targetSteamId2, banType, durationMinutes,
        adminAccountId, adminSteamId2, escapedReason, sServerIP);
    
    CReplyToCommand(client, "%s Executing insert test...", TAG);
    SQL_TQuery(g_db, TestInsertBan_Callback, sQuery, dp);
}

public void TestInsertBan_Callback(Handle owner, Handle hndl, const char[] error, DataPack dp)
{
    dp.Reset();
    int userId = dp.ReadCell();
    int targetAccountId = dp.ReadCell();
    char targetSteamId2[32];
    dp.ReadString(targetSteamId2, sizeof(targetSteamId2));
    int banType = dp.ReadCell();
    int durationMinutes = dp.ReadCell();
    char reason[256];
    dp.ReadString(reason, sizeof(reason));
    delete dp;
    
    int client = GetClientOfUserId(userId);
    if (client == SERVER_INDEX) return;

    if (hndl == null) {
        CReplyToCommand(client, "%s {red}Error{default} in sp_InsertBanWithValidation: %s", TAG, error);
        return;
    }
    
    // Obtener resultados
    char sQuery[256];
    DataPack dp2 = new DataPack();
    dp2.WriteCell(userId);
    dp2.WriteCell(targetAccountId);
    
    Format(sQuery, sizeof(sQuery), "SELECT @ban_id, @result_code, @message");
    SQL_TQuery(g_db, TestInsertBan_Results, sQuery, dp2);
}

public void TestInsertBan_Results(Handle owner, Handle hndl, const char[] error, DataPack dp)
{
    dp.Reset();
    int userId = dp.ReadCell();
    int targetAccountId = dp.ReadCell();
    delete dp;
    
    int client = GetClientOfUserId(userId);
    if (client == SERVER_INDEX) return;

    if (hndl == null || !SQL_FetchRow(hndl)) {
        CReplyToCommand(client, "%s {red}Error{default} getting insert results: %s", TAG, error);
        return;
    }
    
    int banId = SQL_FetchInt(hndl, 0);
    int resultCode = SQL_FetchInt(hndl, 1);
    char message[256];
    SQL_FetchString(hndl, 2, message, sizeof(message));
    
    CReplyToCommand(client, "%s {green}sp_InsertBanWithValidation Results{default}:", TAG);
    CReplyToCommand(client, "%s Ban ID: {blue}%d{default}", TAG, banId);
    CReplyToCommand(client, "%s Result Code: {blue}%d{default}", TAG, resultCode);
    CReplyToCommand(client, "%s Message: {blue}%s{default}", TAG, message);
    
    // Probar códigos de mensaje según el resultado
    if (IsMessageCode(message)) {
        CReplyToCommand(client, "%s Testing message code from procedure:", TAG);
        TestProcessMessageCode(client, message);
    }
    
    // Interpretar resultado
    switch (resultCode) {
        case 0: CReplyToCommand(client, "%s {green}SUCCESS{default}: Ban inserted successfully!", TAG);
        case 1: CReplyToCommand(client, "%s {yellow}REJECTED{default}: Player already has an active ban", TAG);
        case -1: CReplyToCommand(client, "%s {red}SQL ERROR{default}: Database error occurred", TAG);
        case -2: CReplyToCommand(client, "%s {red}VALIDATION ERROR{default}: Invalid Account ID", TAG);
        case -3: CReplyToCommand(client, "%s {red}VALIDATION ERROR{default}: Invalid ban type", TAG);
        default: CReplyToCommand(client, "%s {red}UNKNOWN RESULT{default}: Code %d", TAG, resultCode);
    }
}

/**
 * Comando para probar traducción directa
 */
Action Cmd_TestTranslation(int client, int args)
{
    if (!g_cvarTestTranslations.BoolValue) {
        CReplyToCommand(client, "%s Translation testing is disabled.", TAG);
        return Plugin_Handled;
    }
    
    CReplyToCommand(client, "%s {green}Testing Translation System{default}", TAG);
    
    // Probar diferentes códigos de traducción
    char testCodes[][] = {
        "ISBANNED",
        "BAN_REASON",
        "BAN_PERMANENT", 
        "INVALID_ACCOUNT_ID",
        "INVALID_BAN_TYPE",
        "BAN_INSERTED_SUCCESS",
        "BAN_NOT_FOUND",
        "DATABASE_ERROR",
        "BAN_TYPE_1",
        "BAN_TYPE_2",
        "BAN_TYPE_3"
    };
    
    for (int i = 0; i < sizeof(testCodes); i++) {
        char translated[256];
        Format(translated, sizeof(translated), "%T", testCodes[i], client);
        
        if (StrEqual(translated, testCodes[i])) {
            CReplyToCommand(client, "%s {red}MISSING{default}: %s", TAG, testCodes[i]);
        } else {
            CReplyToCommand(client, "%s {green}OK{default}: %s -> %s", TAG, testCodes[i], translated);
        }
    }
    
    // Probar códigos con parámetros
    CReplyToCommand(client, "%s Testing parameterized translations:", TAG);
    
    char paramTest[256];
    Format(paramTest, sizeof(paramTest), "%T", "BAN_INSERTED_SUCCESS", client, "123");
    CReplyToCommand(client, "%s BAN_INSERTED_SUCCESS(123): %s", TAG, paramTest);
    
    Format(paramTest, sizeof(paramTest), "%T", "EXISTING_BAN_ACTIVE", client, "456");
    CReplyToCommand(client, "%s EXISTING_BAN_ACTIVE(456): %s", TAG, paramTest);
    
    return Plugin_Handled;
}

/**
 * Comando para probar limpieza de bans expirados
 */
Action Cmd_TestCleanExpired(int client, int args)
{
    if (!g_cvarTestStoredProcs.BoolValue) {
        CReplyToCommand(client, "%s Stored procedures testing is disabled.", TAG);
        return Plugin_Handled;
    }
    
    if (!g_bSQLConnected || g_db == null) {
        CReplyToCommand(client, "%s {red}Database not connected{default}. Cannot test stored procedures.", TAG);
        return Plugin_Handled;
    }
    
    int batchSize = 50;  // Tamaño de lote pequeño para pruebas
    if (args >= 1) {
        char arg[16];
        GetCmdArg(1, arg, sizeof(arg));
        batchSize = StringToInt(arg);
        if (batchSize <= 0) batchSize = 50;
    }
    
    CReplyToCommand(client, "%s Testing sp_CleanExpiredBans with batch size: %d", TAG, batchSize);
    TestStoredProcCleanExpired(client, batchSize);
    
    return Plugin_Handled;
}

/**
 * Prueba el procedimiento de limpieza
 */
void TestStoredProcCleanExpired(int client, int batchSize)
{
    char sQuery[256];
    DataPack dp = new DataPack();
    dp.WriteCell(GetClientUserId(client));
    dp.WriteCell(batchSize);
    
    Format(sQuery, sizeof(sQuery),
        "CALL sp_CleanExpiredBans(%d, @cleaned_count, @result_code, @message)",
        batchSize);
    
    SQL_TQuery(g_db, TestCleanExpired_Callback, sQuery, dp);
}

public void TestCleanExpired_Callback(Handle owner, Handle hndl, const char[] error, DataPack dp)
{
    dp.Reset();
    int userId = dp.ReadCell();
    int batchSize = dp.ReadCell();
    delete dp;
    
    int client = GetClientOfUserId(userId);
    if (client == SERVER_INDEX) return;

    if (hndl == null) {
        CReplyToCommand(client, "%s {red}Error{default} in sp_CleanExpiredBans: %s", TAG, error);
        return;
    }
    
    // Obtener resultados
    char sQuery[256];
    DataPack dp2 = new DataPack();
    dp2.WriteCell(userId);
    
    Format(sQuery, sizeof(sQuery), "SELECT @cleaned_count, @result_code, @message");
    SQL_TQuery(g_db, TestCleanExpired_Results, sQuery, dp2);
}

public void TestCleanExpired_Results(Handle owner, Handle hndl, const char[] error, DataPack dp)
{
    dp.Reset();
    int userId = dp.ReadCell();
    delete dp;
    
    int client = GetClientOfUserId(userId);
    if (client == SERVER_INDEX) return;

    if (hndl == null || !SQL_FetchRow(hndl)) {
        CReplyToCommand(client, "%s {red}Error{default} getting cleanup results: %s", TAG, error);
        return;
    }
    
    int cleanedCount = SQL_FetchInt(hndl, 0);
    int resultCode = SQL_FetchInt(hndl, 1);
    char message[256];
    SQL_FetchString(hndl, 2, message, sizeof(message));
    
    CReplyToCommand(client, "%s {green}sp_CleanExpiredBans Results{default}:", TAG);
    CReplyToCommand(client, "%s Cleaned Count: {blue}%d{default}", TAG, cleanedCount);
    CReplyToCommand(client, "%s Result Code: {blue}%d{default}", TAG, resultCode);
    CReplyToCommand(client, "%s Message: {blue}%s{default}", TAG, message);
    
    if (IsMessageCode(message)) {
        TestProcessMessageCode(client, message);
    }
}

/**
 * Comando para probar estadísticas de ban
 */
Action Cmd_TestBanStats(int client, int args)
{
    if (!g_cvarTestStoredProcs.BoolValue) {
        CReplyToCommand(client, "%s Stored procedures testing is disabled.", TAG);
        return Plugin_Handled;
    }
    
    if (!g_bSQLConnected || g_db == null) {
        CReplyToCommand(client, "%s {red}Database not connected{default}. Cannot test stored procedures.", TAG);
        return Plugin_Handled;
    }
    
    int daysBack = 30;
    if (args >= 1) {
        char arg[16];
        GetCmdArg(1, arg, sizeof(arg));
        daysBack = StringToInt(arg);
        if (daysBack <= 0) daysBack = 30;
    }
    
    CReplyToCommand(client, "%s Testing sp_GetBanStatistics for last %d days", TAG, daysBack);
    TestStoredProcBanStats(client, daysBack);
    
    return Plugin_Handled;
}

/**
 * Prueba el procedimiento de estadísticas
 */
void TestStoredProcBanStats(int client, int daysBack)
{
    char sQuery[256];
    DataPack dp = new DataPack();
    dp.WriteCell(GetClientUserId(client));
    dp.WriteCell(daysBack);
    
    Format(sQuery, sizeof(sQuery),
        "CALL sp_GetBanStatistics(%d, @total_active_bans, @total_expired_bans, @total_recent_bans, @most_active_admin_id, @most_common_ban_type)",
        daysBack);
    
    SQL_TQuery(g_db, TestBanStats_Callback, sQuery, dp);
}

public void TestBanStats_Callback(Handle owner, Handle hndl, const char[] error, DataPack dp)
{
    dp.Reset();
    int userId = dp.ReadCell();
    int daysBack = dp.ReadCell();
    delete dp;
    
    int client = GetClientOfUserId(userId);
    if (client == SERVER_INDEX) return;

    if (hndl == null) {
        CReplyToCommand(client, "%s {red}Error{default} in sp_GetBanStatistics: %s", TAG, error);
        return;
    }
    
    // Obtener resultados
    char sQuery[256];
    DataPack dp2 = new DataPack();
    dp2.WriteCell(userId);
    dp2.WriteCell(daysBack);
    
    Format(sQuery, sizeof(sQuery),
        "SELECT @total_active_bans, @total_expired_bans, @total_recent_bans, @most_active_admin_id, @most_common_ban_type");
    SQL_TQuery(g_db, TestBanStats_Results, sQuery, dp2);
}

public void TestBanStats_Results(Handle owner, Handle hndl, const char[] error, DataPack dp)
{
    dp.Reset();
    int userId = dp.ReadCell();
    int daysBack = dp.ReadCell();
    delete dp;
    
    int client = GetClientOfUserId(userId);
    if (client == SERVER_INDEX) return;

    if (hndl == null || !SQL_FetchRow(hndl)) {
        CReplyToCommand(client, "%s {red}Error{default} getting statistics: %s", TAG, error);
        return;
    }
    
    int activeBans = SQL_FetchInt(hndl, 0);
    int expiredBans = SQL_FetchInt(hndl, 1);
    int recentBans = SQL_FetchInt(hndl, 2);
    int topAdminId = SQL_FetchInt(hndl, 3);
    int commonBanType = SQL_FetchInt(hndl, 4);
    
    CReplyToCommand(client, "%s {green}sp_GetBanStatistics Results{default} (Last %d days):", TAG, daysBack);
    CReplyToCommand(client, "%s Active Bans: {blue}%d{default}", TAG, activeBans);
    CReplyToCommand(client, "%s Expired Bans: {blue}%d{default}", TAG, expiredBans);
    CReplyToCommand(client, "%s Recent Bans: {blue}%d{default}", TAG, recentBans);
    CReplyToCommand(client, "%s Most Active Admin ID: {blue}%d{default}", TAG, topAdminId);
    CReplyToCommand(client, "%s Most Common Ban Type: {blue}%d{default}", TAG, commonBanType);
    
    // Probar códigos de estadísticas
    char statsCode[128];
    Format(statsCode, sizeof(statsCode), "#STATS_ACTIVE_BANS:%d", activeBans);
    TestProcessMessageCode(client, statsCode);
    
    Format(statsCode, sizeof(statsCode), "#STATS_RECENT_BANS:%d:%d", daysBack, recentBans);
    TestProcessMessageCode(client, statsCode);
}

/**
 * Comando para probar visualización de información de ban
 */
Action Cmd_TestBanInfo(int client, int args)
{
    if (!g_cvarTestTranslations.BoolValue) {
        CReplyToCommand(client, "%s Translation testing is disabled.", TAG);
        return Plugin_Handled;
    }
    
    CReplyToCommand(client, "%s {green}Testing Ban Info Display{default}", TAG);
    
    // Crear datos de ban de prueba
    int banType = 3;
    int expiresTimestamp = GetTime() + 3600; // Expira en 1 hora
    int createdTimestamp = GetTime() - 300;  // Creado hace 5 minutos
    int adminAccountId = 123456;
    char reason[] = "Test ban reason from callvote_testing";
    char adminSteamId2[] = "STEAM_1:0:123456";
    
    TestDisplayBanInfo(client, banType, expiresTimestamp, createdTimestamp, adminAccountId, reason, adminSteamId2);
    
    // Probar también con ban permanente
    CReplyToCommand(client, "%s Testing permanent ban display:", TAG);
    TestDisplayBanInfo(client, banType, 0, createdTimestamp, adminAccountId, reason, adminSteamId2);
    
    return Plugin_Handled;
}

/**
 * Prueba la visualización de información de ban
 */
void TestDisplayBanInfo(int client, int banType, int expiresTimestamp, int createdTimestamp, int adminAccountId, const char[] reason, const char[] steamId2)
{
    CReplyToCommand(client, "%s {red}=== BAN INFORMATION ==={default}", TAG);
    
    // Mostrar código ISBANNED
    char translatedBanned[256];
    Format(translatedBanned, sizeof(translatedBanned), "%T", "ISBANNED", client);
    CReplyToCommand(client, "%s {red}%s{default}", TAG, translatedBanned);
    
    // Mostrar tipo de ban
    char banTypeCode[32];
    Format(banTypeCode, sizeof(banTypeCode), "BAN_TYPE_%d", banType);
    char translatedType[256];
    Format(translatedType, sizeof(translatedType), "%T", banTypeCode, client);
    CReplyToCommand(client, "%s Type: {blue}%s{default}", TAG, translatedType);
    
    // Mostrar razón
    char translatedReason[256];
    Format(translatedReason, sizeof(translatedReason), "%T", "BAN_REASON", client, reason);
    CReplyToCommand(client, "%s {yellow}%s{default}", TAG, translatedReason);
    
    // Mostrar admin
    char translatedAdmin[256];
    Format(translatedAdmin, sizeof(translatedAdmin), "%T", "BAN_ADMIN", client, steamId2);
    CReplyToCommand(client, "%s {orange}%s{default}", TAG, translatedAdmin);
    
    // Mostrar expiración
    if (expiresTimestamp == 0) {
        char translatedPermanent[256];
        Format(translatedPermanent, sizeof(translatedPermanent), "%T", "BAN_PERMANENT", client);
        CReplyToCommand(client, "%s {red}%s{default}", TAG, translatedPermanent);
    } else {
        char timeStr[64];
        FormatTime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S", expiresTimestamp);
        char translatedExpires[256];
        Format(translatedExpires, sizeof(translatedExpires), "%T", "BAN_EXPIRES", client, timeStr);
        CReplyToCommand(client, "%s {cyan}%s{default}", TAG, translatedExpires);
    }
    
    CReplyToCommand(client, "%s {red}===================={default}", TAG);
}

/*****************************************************************
    FUNCIONES AUXILIARES PARA PRUEBAS
*****************************************************************/

/**
 * Verifica si un mensaje es un código (comienza con #)
 */
bool IsMessageCode(const char[] message)
{
    return (strlen(message) > 1 && message[0] == '#');
}

#endif // CALLVOTE_BANS