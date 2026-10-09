static Action Timer_DeferredForwardCallVoteStart(Handle timer, any data)
{
	int sessionId = data;
	ForwardCallVoteStart(sessionId);
	return Plugin_Stop;
}

static void DispatchCallVoteStartForward(int sessionId, bool defer)
{
	if (defer)
	{
		CreateTimer(0.0, Timer_DeferredForwardCallVoteStart, sessionId, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	ForwardCallVoteStart(sessionId);
}

static void FinalizeVoteStartFromSignal(const char[] source, const char[] issue, const char[] param1, const char[] param2, int team, int initiator, bool deferForward = false)
{
	if (!g_bCurrentVoteSessionValid)
		return;

	if (g_CurrentVoteSession.status == CallVoteSession_Started)
		return;

	if (g_CurrentVoteSession.status != CallVoteSession_Executing)
		return;

	strcopy(g_CurrentVoteSession.engineIssue, sizeof(g_CurrentVoteSession.engineIssue), issue);
	strcopy(g_CurrentVoteSession.engineParam1, sizeof(g_CurrentVoteSession.engineParam1), param1);
	strcopy(g_CurrentVoteSession.engineParam2, sizeof(g_CurrentVoteSession.engineParam2), param2);
	g_CurrentVoteSession.engineTeam = team;
	g_CurrentVoteSession.engineInitiatorClient = initiator;
	g_CurrentVoteSession.engineInitiatorAccountId = GetVoteClientAccountId(initiator);
	g_CurrentVoteSession.status = CallVoteSession_Started;
	BindCurrentVoteController();
	ReadCurrentVoteControllerTally();

	CVLog.Session("[%s] session=%d issue=%s param1=%s param2=%s team=%d initiator=%d",
		source,
		g_CurrentVoteSession.sessionId,
		g_CurrentVoteSession.engineIssue,
		g_CurrentVoteSession.engineParam1,
		g_CurrentVoteSession.engineParam2,
		g_CurrentVoteSession.engineTeam,
		g_CurrentVoteSession.engineInitiatorClient);

	if (g_CurrentVoteSession.voteType == Kick)
	{
		RegVote(g_CurrentVoteSession.voteType, g_CurrentVoteSession.callerClient, g_CurrentVoteSession.targetClient);
	}
	else
	{
		RegVote(g_CurrentVoteSession.voteType, g_CurrentVoteSession.callerClient);
	}

	DispatchCallVoteStartForward(g_CurrentVoteSession.sessionId, deferForward);
}

void Event_VoteStarted(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!IsCurrentSessionCompatibleWithVoteStarted(event))
		return;

	char issue[128];
	char param1[128];
	char param2[128];
	event.GetString("issue", issue, sizeof(issue));
	event.GetString("param1", param1, sizeof(param1));
	event.GetString("param2", param2, sizeof(param2));
	FinalizeVoteStartFromSignal("Event_VoteStarted", issue, param1, param2, NormalizeVoteTeam(event.GetInt("team", -1)), event.GetInt("initiator"));
}

public Action Message_VoteStart(UserMsg hMsgId, BfRead hBf, const int[] recipients, int recipientsNum, bool bReliable, bool bInit)
{
	// L4D2 can surface the vote start through VoteStart without emitting vote_started for some vote types.
	if (hBf.BytesLeft < 2)
		return Plugin_Continue;
	int team = NormalizeVoteTeam(BfReadByte(hBf));
	int initiator = BfReadByte(hBf);
	char issue[128];
	char param1[128];
	char unusedInitiatorName[128];
	if (hBf.ReadString(issue, sizeof(issue)) < 0 || hBf.BytesLeft < 1
		|| hBf.ReadString(param1, sizeof(param1)) < 0 || hBf.BytesLeft < 1
		|| hBf.ReadString(unusedInitiatorName, sizeof(unusedInitiatorName)) < 0)
		return Plugin_Continue;

	if (!IsCurrentSessionCompatibleWithVoteStartMessage(recipients, recipientsNum))
		return Plugin_Continue;

	if (initiator != g_CurrentVoteSession.callerClient)
		return Plugin_Continue;

	FinalizeVoteStartFromSignal("Message_VoteStart", issue, param1, "", team, initiator, true);
	return Plugin_Continue;
}

void Event_VoteEnded(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!IsCurrentSessionCompatibleWithVoteEnded(event))
		return;
	// L4D2 declares vote_ended without fields. Absence is not a failed vote.
	int success = event.GetInt("success", -1);
	if (success == 0 || success == 1)
		ObserveVoteEnd(success == 1 ? CallVoteEnd_Passed : CallVoteEnd_Failed, false);
}

void Event_VoteResult(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsCurrentSessionCompatibleWithVoteEnded(event))
		return;
	ObserveVoteEnd(StrEqual(name, "vote_passed") ? CallVoteEnd_Passed : CallVoteEnd_Failed, false);
}

void Event_VoteChanged(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.status != CallVoteSession_Started)
		return;

	g_CurrentVoteSession.yesVotes = event.GetInt("yesVotes", g_CurrentVoteSession.yesVotes);
	g_CurrentVoteSession.noVotes = event.GetInt("noVotes", g_CurrentVoteSession.noVotes);
	g_CurrentVoteSession.potentialVotes = event.GetInt("potentialVotes", g_CurrentVoteSession.potentialVotes);

	CVLog.Session("[Event_VoteChanged] session=%d yes=%d no=%d potential=%d",
		g_CurrentVoteSession.sessionId,
		g_CurrentVoteSession.yesVotes,
		g_CurrentVoteSession.noVotes,
		g_CurrentVoteSession.potentialVotes);
}

public Action Message_CallVoteFailed(UserMsg hMsgId, BfRead hBf, const int[] iPlayers, int iPlayersNum, bool bReliable, bool bInit)
{
	if (!IsCurrentSessionCompatibleWithVoteFailed(iPlayers, iPlayersNum))
		return Plugin_Continue;

	if (hBf.BytesLeft < 1)
		return Plugin_Continue;
	int reason = hBf.ReadByte();
	int time = hBf.BytesLeft >= 2 ? hBf.ReadShort() : -1;

	g_CurrentVoteSession.status = CallVoteSession_Ended;
	g_CurrentVoteSession.endReason = CallVoteEnd_Cancelled;
	g_CurrentVoteSession.engineFailReason = reason;
	g_CurrentVoteSession.engineFailTime = time;

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

	CreateTimer(0.0, Timer_DeferredVoteEnd, g_CurrentVoteSession.sessionId, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

int NormalizeVoteTeam(int team)
{
	return team == 255 ? -1 : team;
}

void BindCurrentVoteController()
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "vote_controller")) != -1)
	{
		if (!HasEntProp(entity, Prop_Send, "m_activeIssueIndex") || !HasEntProp(entity, Prop_Send, "m_onlyTeamToVote"))
			continue;
		int issue = GetEntProp(entity, Prop_Send, "m_activeIssueIndex");
		int team = NormalizeVoteTeam(GetEntProp(entity, Prop_Send, "m_onlyTeamToVote"));
		if (issue < 0 || team != g_CurrentVoteSession.engineTeam)
			continue;
		g_CurrentVoteSession.controllerRef = EntIndexToEntRef(entity);
		g_CurrentVoteSession.controllerIssue = issue;
		return;
	}
	// Counts are unknown until a matching controller or vote_changed supplies them.
	g_CurrentVoteSession.yesVotes = -1;
	g_CurrentVoteSession.noVotes = -1;
	g_CurrentVoteSession.potentialVotes = -1;
}

bool ReadCurrentVoteControllerTally()
{
	if (!g_bCurrentVoteSessionValid)
		return false;
	int entity = EntRefToEntIndex(g_CurrentVoteSession.controllerRef);
	if (entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity)
		|| !HasEntProp(entity, Prop_Send, "m_activeIssueIndex")
		|| !HasEntProp(entity, Prop_Send, "m_onlyTeamToVote")
		|| GetEntProp(entity, Prop_Send, "m_activeIssueIndex") != g_CurrentVoteSession.controllerIssue
		|| NormalizeVoteTeam(GetEntProp(entity, Prop_Send, "m_onlyTeamToVote")) != g_CurrentVoteSession.engineTeam)
		return false;
	if (HasEntProp(entity, Prop_Send, "m_votesYes"))
		g_CurrentVoteSession.yesVotes = GetEntProp(entity, Prop_Send, "m_votesYes");
	if (HasEntProp(entity, Prop_Send, "m_votesNo"))
		g_CurrentVoteSession.noVotes = GetEntProp(entity, Prop_Send, "m_votesNo");
	if (HasEntProp(entity, Prop_Send, "m_potentialVotes"))
		g_CurrentVoteSession.potentialVotes = GetEntProp(entity, Prop_Send, "m_potentialVotes");
	return true;
}

void Event_VoteCast(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.status != CallVoteSession_Started)
		return;
	int team = NormalizeVoteTeam(event.GetInt("team", -1));
	if (team != g_CurrentVoteSession.engineTeam)
		return;
	int client = event.GetInt("entityid");
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return;
	// Freeze identity before Start consumers can disconnect or replace the slot.
	int accountId = GetVoteClientAccountId(client);
	int userId = GetClientUserId(client);
	// The first engine ballot can precede the zero-delay start timer.
	// Dispatch outside VoteStart's usermessage hook, before exposing the ballot.
	DispatchCallVoteStartForward(g_CurrentVoteSession.sessionId, false);
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.status != CallVoteSession_Started)
		return;
	ForwardCallVoteBallotCast(GetClientOfUserId(userId), accountId, StrEqual(name, "vote_cast_yes"), team);
	// vote_cast_* can precede the controller increment. Do not add counts here.
}

public Action Message_VoteResult(UserMsg id, BfRead reader, const int[] recipients, int count, bool reliable, bool init)
{
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.status != CallVoteSession_Started || reader.BytesLeft < 1)
		return Plugin_Continue;
	int team = NormalizeVoteTeam(reader.ReadByte());
	if (team != g_CurrentVoteSession.engineTeam)
		return Plugin_Continue;
	ObserveVoteEnd(id == GetUserMessageId("VotePass") ? CallVoteEnd_Passed : CallVoteEnd_Failed, true);
	return Plugin_Continue;
}

void ObserveVoteEnd(CallVoteEndReason reason, bool defer)
{
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.status != CallVoteSession_Started)
		return;
	ReadCurrentVoteControllerTally();
	g_CurrentVoteSession.status = CallVoteSession_Ended;
	g_CurrentVoteSession.endReason = reason;
	if (defer)
		CreateTimer(0.0, Timer_DeferredVoteEnd, g_CurrentVoteSession.sessionId, TIMER_FLAG_NO_MAPCHANGE);
	else
		CompleteObservedVoteEnd(g_CurrentVoteSession.sessionId);
}

static Action Timer_DeferredVoteEnd(Handle timer, any sessionId)
{
	CompleteObservedVoteEnd(sessionId);
	return Plugin_Stop;
}

void CompleteObservedVoteEnd(int sessionId)
{
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.sessionId != sessionId || g_CurrentVoteSession.status != CallVoteSession_Ended)
		return;
	if (g_CurrentVoteSession.endReason != CallVoteEnd_Cancelled)
		DispatchCallVoteStartForward(sessionId, false);
	CVLog.Event("VoteResult", "session=%d result=%d yes=%d no=%d potential=%d",
		sessionId, g_CurrentVoteSession.endReason, g_CurrentVoteSession.yesVotes, g_CurrentVoteSession.noVotes, g_CurrentVoteSession.potentialVotes);
	ForwardCallVoteEnd(g_CurrentVoteSession.endReason);
	// A forward consumer can synchronously cause another request.
	if (g_bCurrentVoteSessionValid && g_CurrentVoteSession.sessionId == sessionId)
		ArchiveCurrentVoteSession();
}
