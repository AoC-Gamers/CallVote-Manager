void Event_VoteStarted(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!IsCurrentSessionCompatibleWithVoteStarted(event))
		return;

	event.GetString("issue", g_CurrentVoteSession.engineIssue, sizeof(g_CurrentVoteSession.engineIssue));
	event.GetString("param1", g_CurrentVoteSession.engineParam1, sizeof(g_CurrentVoteSession.engineParam1));
	event.GetString("param2", g_CurrentVoteSession.engineParam2, sizeof(g_CurrentVoteSession.engineParam2));
	g_CurrentVoteSession.engineTeam = event.GetInt("team");
	g_CurrentVoteSession.engineInitiatorClient = event.GetInt("initiator");
	g_CurrentVoteSession.status = CallVoteSession_Started;

	CVLog.Session("[Event_VoteStarted] session=%d issue=%s param1=%s param2=%s team=%d initiator=%d",
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

	ForwardCallVoteStart(g_CurrentVoteSession.sessionId);
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
