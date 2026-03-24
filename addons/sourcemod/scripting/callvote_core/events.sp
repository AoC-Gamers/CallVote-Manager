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
	g_CurrentVoteSession.status = CallVoteSession_Started;

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
		RegSQLVote(g_CurrentVoteSession.voteType, g_CurrentVoteSession.callerClient, g_CurrentVoteSession.targetClient);
	}
	else
	{
		RegVote(g_CurrentVoteSession.voteType, g_CurrentVoteSession.callerClient);
		RegSQLVote(g_CurrentVoteSession.voteType, g_CurrentVoteSession.callerClient);
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
	FinalizeVoteStartFromSignal("Event_VoteStarted", issue, param1, param2, event.GetInt("team"), event.GetInt("initiator"));
}

public Action Message_VoteStart(UserMsg hMsgId, BfRead hBf, const int[] recipients, int recipientsNum, bool bReliable, bool bInit)
{
	// L4D2 can surface the vote start through VoteStart without emitting vote_started for some vote types.
	int team = BfReadByte(hBf);
	int initiator = BfReadByte(hBf);
	char issue[128];
	char param1[128];
	char unusedInitiatorName[128];
	hBf.ReadString(issue, sizeof(issue));
	hBf.ReadString(param1, sizeof(param1));
	hBf.ReadString(unusedInitiatorName, sizeof(unusedInitiatorName));

	if (!IsCurrentSessionCompatibleWithVoteStartMessage(recipients, recipientsNum))
		return Plugin_Continue;

	FinalizeVoteStartFromSignal("Message_VoteStart", issue, param1, "", team, initiator, true);
	return Plugin_Continue;
}

void Event_VoteEnded(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!IsCurrentSessionCompatibleWithVoteEnded(event))
		return;

	int success = event.GetInt("success");
	g_CurrentVoteSession.engineTeam = event.GetInt("team");
	g_CurrentVoteSession.status = CallVoteSession_Ended;
	g_CurrentVoteSession.endReason = success ? CallVoteEnd_Passed : CallVoteEnd_Failed;

	CVLog.Session("[Event_VoteEnded] session=%d success=%d yes=%d no=%d potential=%d",
		g_CurrentVoteSession.sessionId,
		success,
		g_CurrentVoteSession.yesVotes,
		g_CurrentVoteSession.noVotes,
		g_CurrentVoteSession.potentialVotes);
	CVLog.Event("VoteResult", "session=%d callerAccountId=%d voteType=%d result=%d yes=%d no=%d potential=%d target=%d argument=%s",
		g_CurrentVoteSession.sessionId,
		g_CurrentVoteSession.callerAccountId,
		g_CurrentVoteSession.voteType,
		g_CurrentVoteSession.endReason,
		g_CurrentVoteSession.yesVotes,
		g_CurrentVoteSession.noVotes,
		g_CurrentVoteSession.potentialVotes,
		g_CurrentVoteSession.targetAccountId,
		g_CurrentVoteSession.argumentRaw);

	ForwardCallVoteEnd(g_CurrentVoteSession.endReason);
	ArchiveCurrentVoteSession();
}

void Event_VoteChanged(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!g_bCurrentVoteSessionValid)
		return;

	g_CurrentVoteSession.yesVotes = event.GetInt("yesVotes");
	g_CurrentVoteSession.noVotes = event.GetInt("noVotes");
	g_CurrentVoteSession.potentialVotes = event.GetInt("potentialVotes");

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

	int reason = hBf.ReadByte();
	int time = hBf.ReadShort();

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

	ForwardCallVoteEnd(g_CurrentVoteSession.endReason);
	ArchiveCurrentVoteSession();
	return Plugin_Continue;
}
