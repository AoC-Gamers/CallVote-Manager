Action ForwardCallVotePreStart()
{
	return DispatchVoteDecision("CallVote_PreStart");
}

void ForwardCallVoteStart(int sessionId)
{
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.sessionId != sessionId
		|| g_CurrentVoteSession.startForwarded
		|| (g_CurrentVoteSession.status != CallVoteSession_Started && g_CurrentVoteSession.status != CallVoteSession_Ended))
		return;
	g_CurrentVoteSession.startForwarded = true;
	g_ForwardDispatchDepth++;
	Call_StartForward(g_ForwardCallVoteStart);
	Call_PushCell(sessionId);
	Call_Finish();
	g_ForwardDispatchDepth--;

	CVLog.Forwards("[ForwardCallVoteStart] session=%d", sessionId);
}

Action ForwardCallVotePreExecute()
{
	return DispatchVoteDecision("CallVote_PreExecute");
}

void ForwardCallVoteBlocked(VoteRestrictionType restriction)
{
	if (!g_bCurrentVoteSessionValid)
		return;

	g_ForwardDispatchDepth++;
	Call_StartForward(g_ForwardCallVoteBlocked);
	Call_PushCell(g_CurrentVoteSession.sessionId);
	Call_PushCell(g_CurrentVoteSession.callerClient);
	Call_PushCell(g_CurrentVoteSession.callerAccountId);
	Call_PushCell(g_CurrentVoteSession.voteType);
	Call_PushCell(restriction);
	Call_PushCell(g_CurrentVoteSession.targetClient);
	Call_PushCell(g_CurrentVoteSession.targetAccountId);
	Call_PushString(g_CurrentVoteSession.argumentRaw);
	Call_Finish();
	g_ForwardDispatchDepth--;

	CVLog.Forwards("[ForwardCallVoteBlocked] session=%d restriction=%d",
		g_CurrentVoteSession.sessionId,
		view_as<int>(restriction));
}

void ForwardCallVoteEnd(CallVoteEndReason endReason)
{
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.endForwarded)
		return;
	g_CurrentVoteSession.endForwarded = true;

	g_ForwardDispatchDepth++;
	Call_StartForward(g_ForwardCallVoteEnd);
	Call_PushCell(g_CurrentVoteSession.sessionId);
	Call_PushCell(endReason);
	Call_PushCell(g_CurrentVoteSession.yesVotes);
	Call_PushCell(g_CurrentVoteSession.noVotes);
	Call_PushCell(g_CurrentVoteSession.potentialVotes);
	Call_Finish();
	g_ForwardDispatchDepth--;

	CVLog.Forwards("[ForwardCallVoteEnd] session=%d result=%d yes=%d no=%d potential=%d",
		g_CurrentVoteSession.sessionId,
		view_as<int>(endReason),
		g_CurrentVoteSession.yesVotes,
		g_CurrentVoteSession.noVotes,
		g_CurrentVoteSession.potentialVotes);
}

void ForwardCallVoteBallotCast(int client, int accountId, bool votedYes, int team)
{
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.status != CallVoteSession_Started)
		return;
	g_ForwardDispatchDepth++;
	Call_StartForward(g_ForwardCallVoteBallotCast);
	Call_PushCell(g_CurrentVoteSession.sessionId);
	Call_PushCell(client);
	Call_PushCell(accountId);
	Call_PushCell(votedYes);
	Call_PushCell(team);
	Call_Finish();
	g_ForwardDispatchDepth--;
}
