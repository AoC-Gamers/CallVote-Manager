#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <callvote_core>

#define CVT_LOG_FILE "callvote_testing.log"
#define CVT_MISSING_INT 2147483647

ConVar g_cvEnabled, g_cvLogMode, g_cvDebugMask, g_cvChat;
ConVar g_cvEvents[7], g_cvMessages[5];
ConVar g_cvController, g_cvConVars, g_cvBallot;
ConVar g_cvListenerVote, g_cvListenerCallVote;
ConVar g_cvForwardStart, g_cvForwardPreStart, g_cvForwardPreExecute, g_cvForwardBlocked, g_cvForwardEnd;
char g_LogPath[PLATFORM_MAX_PATH];
bool g_bLogReady;
int g_Sequence;

static const char g_EventNames[][] = {
	"vote_started", "vote_ended", "vote_changed", "vote_passed", "vote_failed", "vote_cast_yes", "vote_cast_no"
};
static const char g_EventConVars[][] = {
	"sm_cvt_votestarted", "sm_cvt_voteended", "sm_cvt_votechanged", "sm_cvt_votepassed", "sm_cvt_votefailed", "sm_cvt_votecastyes", "sm_cvt_votecastno"
};
static const char g_MessageNames[][] = {
	"VoteStart", "VotePass", "VoteFail", "VoteRegistered", "CallVoteFailed"
};
static const char g_MessageConVars[][] = {
	"sm_cvt_votestart", "sm_cvt_votepass", "sm_cvt_votefail", "sm_cvt_voteregistered", "sm_cvt_callvotefailed"
};

public Plugin myinfo = {
	name = "Call Vote Testing",
	author = "lechuga",
	description = "Observes voting commands, engine signals and core forwards without changing votes",
	version = "3.0.0",
	url = "https://github.com/AoC-Gamers/CallVote-Manager"
};

public void OnPluginStart()
{
	g_cvEnabled = CreateConVar("sm_cvt_enable", "1", "Enable vote diagnostics", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvLogMode = CreateConVar("sm_cvt_log_mode", "2", "Tester file logging, independent of sm_cv_log_mode: 0=off, 1=normal, 2=debug (mask applies)", FCVAR_NONE, true, 0.0, true, 2.0);
	g_cvDebugMask = CreateConVar("sm_cvt_debug_mask", "1", "Diagnostic mask: Core=1 (vote trace)", FCVAR_NONE, true, 0.0, true, 255.0);
	g_cvChat = CreateConVar("sm_cvt_chat", "0", "Also display traces in chat (deferred, for private tests)", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvBallot = CreateConVar("sm_cvt_forwardballot", "1", "Observe CallVote_BallotCast", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvController = CreateConVar("sm_cvt_controller", "1", "Capture vote_controller immediately and after voting signals", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvConVars = CreateConVar("sm_cvt_convars", "1", "Capture voting ConVars on requests, starts, failures and manual snapshots", FCVAR_NONE, true, 0.0, true, 1.0);
	BuildCallVoteDebugLogPath(CVT_LOG_FILE, g_LogPath, sizeof(g_LogPath));
	if (EnsureCallVoteParentFolderForFile(g_LogPath))
	{
		File file = OpenFile(g_LogPath, "a");
		g_bLogReady = file != null;
		delete file;
	}
	if (!g_bLogReady)
		LogError("[CVT] log_init_failed path=%s; console capture remains available", g_LogPath);

	for (int i = 0; i < sizeof(g_EventNames); i++)
	{
		g_cvEvents[i] = CreateConVar(g_EventConVars[i], "1", "Observe voting event", FCVAR_NONE, true, 0.0, true, 1.0);
		if (!HookEventEx(g_EventNames[i], Event_VoteSignal, EventHookMode_Post))
			LogError("[CVT] event_unavailable name=%s", g_EventNames[i]);
	}
	for (int i = 0; i < sizeof(g_MessageNames); i++)
	{
		g_cvMessages[i] = CreateConVar(g_MessageConVars[i], "1", "Observe voting usermessage", FCVAR_NONE, true, 0.0, true, 1.0);
		UserMsg id = GetUserMessageId(g_MessageNames[i]);
		if (id == INVALID_MESSAGE_ID)
			LogError("[CVT] message_unavailable name=%s", g_MessageNames[i]);
		else
			HookUserMessage(id, Message_VoteSignal);
	}
	g_cvListenerVote = CreateConVar("sm_cvt_listenervote", "1", "Observe Vote command attempts", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvListenerCallVote = CreateConVar("sm_cvt_listenercallvote", "1", "Observe callvote command attempts", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvForwardStart = CreateConVar("sm_cvt_forwardmanager", "1", "Observe CallVote_Start", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvForwardPreStart = CreateConVar("sm_cvt_forwardprestart", "1", "Observe CallVote_PreStart", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvForwardPreExecute = CreateConVar("sm_cvt_forwardpreexecute", "1", "Observe CallVote_PreExecute", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvForwardBlocked = CreateConVar("sm_cvt_forwardblocked", "1", "Observe CallVote_Blocked", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cvForwardEnd = CreateConVar("sm_cvt_forwardend", "1", "Observe CallVote_End", FCVAR_NONE, true, 0.0, true, 1.0);
	AddCommandListener(Listener_Vote, "Vote");
	AddCommandListener(Listener_CallVote, "callvote");
	RegAdminCmd("sm_cvt_status", Command_Status, ADMFLAG_ROOT, "Show diagnostic configuration and trace path");
	RegAdminCmd("sm_cvt_snapshot", Command_Snapshot, ADMFLAG_ROOT, "Read voting ConVars and vote_controller without starting a vote");
}

// Only the tester stores this ordering counter; no vote history is added to the core.
void Trace(const char[] source, const char[] format, any ...)
{
	if (!g_cvEnabled.BoolValue)
		return;
	char payload[768], line[1024], map[128];
	VFormat(payload, sizeof(payload), format, 3);
	ReplaceString(payload, sizeof(payload), "\n", "\\n");
	ReplaceString(payload, sizeof(payload), "\r", "\\r");
	GetCurrentMap(map, sizeof(map));
	FormatEx(line, sizeof(line), "seq=%d tick=%d engine=%.6f unix=%d session=%d map=%s source=%s %s", ++g_Sequence, GetGameTickCount(), GetEngineTime(), GetTime(), StrEqual(source, "OnPluginEnd") ? -1 : CallVoteCore_GetCurrentSession(), map, source, payload);
	PrintToServer("[CVT] %s", line);
	// Test capture must not stop when a game-mode config changes the suite log mode.
	if (g_bLogReady && (g_cvLogMode.IntValue == 1 || CallVoteDebugMaskEnabled(g_cvLogMode, g_cvDebugMask, CVLogMask_Core)))
		LogToFileEx(g_LogPath, "[CVT][Core] %s", line);
	if (g_cvChat.BoolValue && !StrEqual(source, "vote_controller") && !StrEqual(source, "vote_roster") && !StrEqual(source, "vote_convar"))
	{
		DataPack pack;
		CreateDataTimer(0.0, Timer_ChatTrace, pack, TIMER_FLAG_NO_MAPCHANGE);
		pack.WriteString(line);
	}
}

public Action Timer_ChatTrace(Handle timer, DataPack pack)
{
	if (!g_cvEnabled.BoolValue || !g_cvChat.BoolValue)
		return Plugin_Stop;
	char line[1024];
	pack.Reset();
	pack.ReadString(line, sizeof(line));
	PrintToChatAll("[CVT] %s", line);
	return Plugin_Stop;
}

// Snapshots belong to the tester. They never write to the controller or ConVars.
void AppendControllerInt(int entity, const char[] key, char[] buffer, int maxlen)
{
	PropType type = Prop_Send;
	bool found = HasEntProp(entity, type, key);
	if (!found)
	{
		type = Prop_Data;
		found = HasEntProp(entity, type, key);
	}
	if (!found)
	{
		Format(buffer, maxlen, "%s %s=<absent>", buffer, key);
		return;
	}
	int value = GetEntProp(entity, type, key);
	Format(buffer, maxlen, "%s %s=%d(%s)", buffer, key, value, type == Prop_Send ? "send" : "data");
	if (StrEqual(key, "m_onlyTeamToVote"))
		Format(buffer, maxlen, "%s team_normalized=%d", buffer, value == 255 ? -1 : value);
}

void SnapshotController(const char[] signal, const char[] phase, int originSeq, int originTick, int originSession)
{
	if (!g_cvEnabled.BoolValue || !g_cvController.BoolValue)
		return;
	int entity = -1, controllers;
	static const char properties[][] = {
		"m_activeIssueIndex", "m_votesYes", "m_votesNo", "m_potentialVotes", "m_onlyTeamToVote"
	};
	while ((entity = FindEntityByClassname(entity, "vote_controller")) != -1)
	{
		char fields[512];
		for (int i = 0; i < sizeof(properties); i++)
			AppendControllerInt(entity, properties[i], fields, sizeof(fields));
		Trace("vote_controller", "signal=%s phase=%s origin_seq=%d origin_tick=%d origin_session=%d entity=%d%s", signal, phase, originSeq, originTick, originSession, entity, fields);
		controllers++;
	}
	if (!controllers)
		Trace("vote_controller", "signal=%s phase=%s origin_seq=%d origin_tick=%d origin_session=%d entity=<absent>", signal, phase, originSeq, originTick, originSession);

	int humans, spectators, survivors, infected, other, bots, sourceTV;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		if (IsClientSourceTV(client))
			sourceTV++;
		else if (IsFakeClient(client))
			bots++;
		else
		{
			humans++;
			switch (GetClientTeam(client))
			{
				case 1: spectators++;
				case 2: survivors++;
				case 3: infected++;
				default: other++;
			}
		}
	}
	Trace("vote_roster", "signal=%s phase=%s origin_seq=%d origin_tick=%d origin_session=%d humans=%d spectators=%d survivors=%d infected=%d other=%d bots=%d sourcetv=%d electorate_not_inferred=1", signal, phase, originSeq, originTick, originSession, humans, spectators, survivors, infected, other, bots, sourceTV);
}

void ObserveController(const char[] signal)
{
	if (!g_cvEnabled.BoolValue || !g_cvController.BoolValue)
		return;
	int originSeq = g_Sequence, originTick = GetGameTickCount(), originSession = CallVoteCore_GetCurrentSession();
	SnapshotController(signal, "immediate", originSeq, originTick, originSession);
	// One-shot samples only; the engine or another plugin may update the entity later.
	for (int i = 0; i < 2; i++)
	{
		DataPack pack;
		CreateDataTimer(i == 0 ? 0.0 : 0.1, Timer_ControllerSnapshot, pack, TIMER_FLAG_NO_MAPCHANGE);
		pack.WriteString(signal);
		pack.WriteString(i == 0 ? "deferred" : "after_100ms");
		pack.WriteCell(originSeq);
		pack.WriteCell(originTick);
		pack.WriteCell(originSession);
	}
}

public Action Timer_ControllerSnapshot(Handle timer, DataPack pack)
{
	char signal[64], phase[32];
	pack.Reset();
	pack.ReadString(signal, sizeof(signal));
	pack.ReadString(phase, sizeof(phase));
	int originSeq = pack.ReadCell(), originTick = pack.ReadCell(), originSession = pack.ReadCell();
	SnapshotController(signal, phase, originSeq, originTick, originSession);
	return Plugin_Stop;
}

void SnapshotConVars(const char[] signal)
{
	if (!g_cvEnabled.BoolValue || !g_cvConVars.BoolValue)
		return;
	// These ConVars are owned by the L4D2 engine and are present in this game.
	// Read them directly; only plugin-owned entries below can be absent.
	static const char engineNames[][] = {
		"sv_allow_votes", "sv_vote_command_delay", "sv_vote_creation_timer", "sv_vote_failure_timer",
		"sv_vote_issue_change_difficulty_allowed", "sv_vote_issue_change_map_later_allowed",
		"sv_vote_issue_change_map_now_allowed", "sv_vote_issue_change_mission_allowed",
		"sv_vote_issue_kick_allowed", "sv_vote_issue_restart_game_allowed", "sv_vote_kick_ban_duration",
		"sv_vote_plr_map_limit", "sv_vote_show_caller", "sv_vote_timer_duration",
		"sv_pz_endgame_vote_period", "sv_pz_endgame_vote_post_period", "versus_level_restart_delay",
		"mp_gamemode", "sv_alltalk"
	};
	static const char pluginNames[][] = {
		"sm_cvc_enable", "sm_cvm_enable", "sm_cvm_all_talk",
		"sm_cvm_builtin_vote", "sm_cvkl_enable", "sm_cvkl_kicklimit", "l4d_votepoll_fix_version"
	};
	for (int i = 0; i < sizeof(engineNames); i++)
		TraceConVar(signal, engineNames[i], false);
	for (int i = 0; i < sizeof(pluginNames); i++)
		TraceConVar(signal, pluginNames[i], true);
}

void TraceConVar(const char[] signal, const char[] name, bool optional)
{
	ConVar variable = FindConVar(name);
	if (optional && variable == null)
	{
		Trace("vote_convar", "signal=%s name=%s value=<absent>", signal, name);
		return;
	}
	char value[128];
	variable.GetString(value, sizeof(value));
	Trace("vote_convar", "signal=%s name=%s value=\"%s\"", signal, name, value);
}

void DescribeClient(int client, char[] buffer, int maxlen)
{
	if (client < 1 || client > MaxClients || !IsClientConnected(client))
	{
		FormatEx(buffer, maxlen, "client=%d connected=0", client);
		return;
	}
	char steam64[32];
	if (!GetClientAuthId(client, AuthId_SteamID64, steam64, sizeof(steam64)))
		strcopy(steam64, sizeof(steam64), "<unavailable>");
	bool inGame = IsClientInGame(client);
	int team = inGame ? GetClientTeam(client) : -1;
	FormatEx(buffer, maxlen, "client=%d userid=%d accountid=%d steamid64=%s ingame=%d fake=%d team=%d", client, GetClientUserId(client), GetSteamAccountID(client), steam64, inGame, IsFakeClient(client), team);
}

void AppendEventInt(Event event, const char[] key, char[] buffer, int maxlen)
{
	int value = event.GetInt(key, CVT_MISSING_INT);
	if (value == CVT_MISSING_INT)
		Format(buffer, maxlen, "%s %s=<absent>", buffer, key);
	else
		Format(buffer, maxlen, "%s %s=%d", buffer, key, value);
}

void AppendEventString(Event event, const char[] key, char[] buffer, int maxlen)
{
	char value[256];
	event.GetString(key, value, sizeof(value), "<absent>");
	Format(buffer, maxlen, "%s %s=\"%s\"", buffer, key, value);
}

public void Event_VoteSignal(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i < sizeof(g_EventNames); i++)
	{
		if (StrEqual(name, g_EventNames[i]) && !g_cvEvents[i].BoolValue)
			return;
	}
	if (!g_cvEnabled.BoolValue)
		return;
	char fields[512], clientInfo[256];
	FormatEx(fields, sizeof(fields), "dont_broadcast=%d", dontBroadcast);
	// Probe known and previously assumed fields, marking absence instead of treating it as zero.
	static const char intKeys[][] = { "team", "initiator", "entityid", "yesVotes", "noVotes", "potentialVotes", "success" };
	static const char stringKeys[][] = { "issue", "param1", "param2", "votedata", "vote_type", "details" };
	for (int i = 0; i < sizeof(intKeys); i++)
		AppendEventInt(event, intKeys[i], fields, sizeof(fields));
	Trace(name, "%s", fields);
	for (int i = 0; i < sizeof(stringKeys); i++)
	{
		fields[0] = '\0';
		AppendEventString(event, stringKeys[i], fields, sizeof(fields));
		Trace(name, "%s", fields);
	}
	int client = event.GetInt("entityid", event.GetInt("initiator", 0));
	DescribeClient(client, clientInfo, sizeof(clientInfo));
	Trace(name, "subject={%s}", clientInfo);
	ObserveController(name);
}

public Action Message_VoteSignal(UserMsg id, BfRead reader, const int[] recipients, int count, bool reliable, bool init)
{
	char name[64];
	GetUserMessageName(id, name, sizeof(name));
	for (int i = 0; i < sizeof(g_MessageNames); i++)
	{
		if (StrEqual(name, g_MessageNames[i]) && !g_cvMessages[i].BoolValue)
			return Plugin_Continue;
	}
	if (!g_cvEnabled.BoolValue)
		return Plugin_Continue;
	int bytes = reader.BytesLeft;
	Trace(name, "bytes=%d recipients=%d reliable=%d init=%d", bytes, count, reliable, init);
	ObserveController(name);
	if (StrEqual(name, "VoteStart") || StrEqual(name, "CallVoteFailed"))
		SnapshotConVars(name);
	// Preserve recipient identity at observation time, before any deferred chat output.
	for (int i = 0; i < count; i++)
	{
		char clientInfo[256];
		DescribeClient(recipients[i], clientInfo, sizeof(clientInfo));
		Trace(name, "recipient_index=%d {%s}", i, clientInfo);
	}
	if (bytes < 1)
	{
		Trace(name, "malformed=1 missing=first_byte");
		return Plugin_Continue;
	}
	int first = reader.ReadByte();
	if (StrEqual(name, "VoteRegistered"))
		Trace(name, "vote_raw=%d decision=%s bytes_left=%d", first, first == 1 ? "yes" : (first == 0 ? "no" : "unknown"), reader.BytesLeft);
	else if (StrEqual(name, "CallVoteFailed"))
	{
		if (reader.BytesLeft >= 2)
		{
			int time = reader.ReadShort();
			Trace(name, "reason=%d time_raw=%d bytes_left=%d", first, time, reader.BytesLeft);
		}
		else
			Trace(name, "reason=%d time_raw=<absent> bytes_left=%d", first, reader.BytesLeft);
	}
	else
	{
		Trace(name, "team_raw=%d team_normalized=%d", first, first == 255 ? -1 : first);
		if (StrEqual(name, "VoteStart"))
		{
			if (reader.BytesLeft < 1)
			{
				Trace(name, "malformed=1 missing=initiator");
				return Plugin_Continue;
			}
			int initiator = reader.ReadByte();
			Trace(name, "initiator_raw=%d", initiator);
			TraceMessageString(reader, name, "issue");
			TraceMessageString(reader, name, "param1");
			TraceMessageString(reader, name, "initiatorName");
		}
		else if (StrEqual(name, "VotePass"))
		{
			TraceMessageString(reader, name, "details");
			TraceMessageString(reader, name, "param1");
		}
		// VoteFail has only the team byte; do not read invented strings.
		Trace(name, "bytes_left=%d", reader.BytesLeft);
	}
	TraceRemainingBytes(reader, name);
	return Plugin_Continue;
}

void TraceRemainingBytes(BfRead reader, const char[] source)
{
	int remaining = reader.BytesLeft;
	if (remaining < 1)
		return;
	char hex[196];
	int limit = remaining > 64 ? 64 : remaining;
	for (int i = 0; i < limit; i++)
		Format(hex, sizeof(hex), "%s%02X ", hex, reader.ReadByte());
	Trace(source, "extra_bytes=%d hex=\"%s\" omitted_bytes=%d", remaining, hex, remaining - limit);
}

void TraceMessageString(BfRead reader, const char[] source, const char[] key)
{
	if (reader.BytesLeft < 1)
	{
		Trace(source, "%s=<absent>", key);
		return;
	}
	char value[256];
	int read = reader.ReadString(value, sizeof(value));
	Trace(source, "%s=\"%s\" read=%d malformed=%d at_buffer_limit=%d bytes_left=%d", key, value, read, read < 0, strlen(value) == sizeof(value) - 1, reader.BytesLeft);
}

public Action Listener_Vote(int client, const char[] command, int argc)
{
	if (g_cvListenerVote.BoolValue)
		TraceCommand(client, command, argc);
	return Plugin_Continue;
}

public Action Listener_CallVote(int client, const char[] command, int argc)
{
	if (g_cvListenerCallVote.BoolValue)
		TraceCommand(client, command, argc);
	return Plugin_Continue;
}

// -1 means unavailable, 0 idle, 1 an active engine issue. Do not infer it from
// a core session: another plugin may have initiated an engine vote.
int GetEngineVoteActivity()
{
	int entity = -1;
	bool found;
	while ((entity = FindEntityByClassname(entity, "vote_controller")) != -1)
	{
		if (!HasEntProp(entity, Prop_Send, "m_activeIssueIndex"))
			continue;
		found = true;
		if (GetEntProp(entity, Prop_Send, "m_activeIssueIndex") >= 0)
			return 1;
	}
	return found ? 0 : -1;
}

void TraceCommand(int client, const char[] command, int argc)
{
	if (!g_cvEnabled.BoolValue)
		return;
	char arguments[256], clientInfo[256];
	GetCmdArgString(arguments, sizeof(arguments));
	DescribeClient(client, clientInfo, sizeof(clientInfo));
	int activity = GetEngineVoteActivity();
	Trace(command, "argc=%d args=\"%s\" {%s} attempt_only=1 engine_vote_active=%d", argc, arguments, clientInfo, activity);
	// Idle F1/F2 is a command attempt, not a ballot; no deferred snapshots.
	if (StrEqual(command, "Vote", false) && activity == 0)
		return;
	ObserveController(command);
	if (StrEqual(command, "callvote", false))
		SnapshotConVars(command);
}

void TraceSessionState(const char[] source, int sessionId)
{
	CallVoteSessionStatus status;
	VoteRestrictionType restriction;
	if (CallVoteCore_GetSessionState(sessionId, status, restriction))
		Trace(source, "forward_session=%d state=%d restriction=%d", sessionId, status, restriction);
}

void TraceForwardContext(const char[] source, int sessionId, int client, int accountId, TypeVotes type, int target, int targetAccountId, const char[] argument)
{
	char callerInfo[256], targetInfo[256];
	DescribeClient(client, callerInfo, sizeof(callerInfo));
	DescribeClient(target, targetInfo, sizeof(targetInfo));
	Trace(source, "forward_session=%d type=%d caller_accountid=%d target_accountid=%d arg=\"%s\" caller={%s} target={%s}", sessionId, type, accountId, targetAccountId, argument, callerInfo, targetInfo);
}

public Action CallVote_PreStart(int sessionId, int client, int accountId, TypeVotes type, int target, int targetAccountId, const char[] argument)
{
	if (g_cvForwardPreStart.BoolValue)
		TraceForwardContext("CallVote_PreStart", sessionId, client, accountId, type, target, targetAccountId, argument);
	return Plugin_Continue;
}

public Action CallVote_PreExecute(int sessionId, int client, int accountId, TypeVotes type, int target, int targetAccountId, const char[] argument)
{
	if (g_cvForwardPreExecute.BoolValue)
		TraceForwardContext("CallVote_PreExecute", sessionId, client, accountId, type, target, targetAccountId, argument);
	return Plugin_Continue;
}

public void CallVote_Blocked(int sessionId, int client, int accountId, TypeVotes type, VoteRestrictionType restriction, int target, int targetAccountId, const char[] argument)
{
	if (!g_cvForwardBlocked.BoolValue)
		return;
	TraceForwardContext("CallVote_Blocked", sessionId, client, accountId, type, target, targetAccountId, argument);
	Trace("CallVote_Blocked", "forward_session=%d restriction=%d", sessionId, restriction);
	TraceSessionState("CallVote_Blocked", sessionId);
}

public void CallVote_Start(int sessionId)
{
	if (g_cvForwardStart.BoolValue)
	{
		Trace("CallVote_Start", "forward_session=%d", sessionId);
		TraceSessionState("CallVote_Start", sessionId);
		ObserveController("CallVote_Start");
	}
}

public void CallVote_BallotCast(int sessionId, int client, int accountId, bool votedYes, int team)
{
	if (!g_cvBallot.BoolValue)
		return;
	char identity[256];
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && GetSteamAccountID(client) == accountId)
		DescribeClient(client, identity, sizeof(identity));
	else
		FormatEx(identity, sizeof(identity), "client=%d live_identity_unavailable_or_changed=1", client);
	Trace("CallVote_BallotCast", "forward_session=%d voter_accountid=%d yes=%d team=%d voter={%s}", sessionId, accountId, votedYes, team, identity);
}

public void CallVote_End(int sessionId, CallVoteEndReason result, int yesCount, int noCount, int potentialVotes)
{
	if (g_cvForwardEnd.BoolValue)
	{
		Trace("CallVote_End", "forward_session=%d core_result=%d yes=%d no=%d potential=%d", sessionId, result, yesCount, noCount, potentialVotes);
		TraceSessionState("CallVote_End", sessionId);
		ObserveController("CallVote_End");
	}
}

public void OnMapStart()
{
	Trace("OnMapStart", "boundary=1");
}

public void OnMapEnd()
{
	Trace("OnMapEnd", "boundary=1");
}

public Action Command_Status(int client, int args)
{
	char path[PLATFORM_MAX_PATH];
	BuildCallVoteDebugLogPath(CVT_LOG_FILE, path, sizeof(path));
	ReplyToCommand(client, "[CVT] enabled=%d tester_log_mode=%d mask=%d chat=%d file_ready=%d file=%s", g_cvEnabled.BoolValue, g_cvLogMode.IntValue, g_cvDebugMask.IntValue, g_cvChat.BoolValue, g_bLogReady, path);
	Trace("sm_cvt_status", "tester_log_mode=%d file_ready=%d controller=%d convars=%d", g_cvLogMode.IntValue, g_bLogReady, g_cvController.BoolValue, g_cvConVars.BoolValue);
	return Plugin_Handled;
}

public Action Command_Snapshot(int client, int args)
{
	Trace("sm_cvt_snapshot", "manual=1");
	ObserveController("sm_cvt_snapshot");
	SnapshotConVars("sm_cvt_snapshot");
	ReplyToCommand(client, "[CVT] Read-only snapshot requested; check the trace log.");
	return Plugin_Handled;
}

public void OnPluginEnd()
{
	Trace("OnPluginEnd", "boundary=1");
}
