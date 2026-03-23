Action ForwardCallVotePreStart()
{
	if (!g_bCurrentVoteSessionValid)
		return Plugin_Continue;

	Action result = Plugin_Continue;

	Call_StartForward(g_ForwardCallVotePreStart);
	Call_PushCell(g_CurrentVoteSession.sessionId);
	Call_PushCell(g_CurrentVoteSession.callerClient);
	Call_PushCell(g_CurrentVoteSession.callerAccountId);
	Call_PushCell(g_CurrentVoteSession.voteType);
	Call_PushCell(g_CurrentVoteSession.targetClient);
	Call_PushCell(g_CurrentVoteSession.targetAccountId);
	Call_PushString(g_CurrentVoteSession.argumentRaw);
	Call_Finish(result);

	CVLog.Forwards("[ForwardCallVotePreStart] session=%d result=%d",
		g_CurrentVoteSession.sessionId,
		view_as<int>(result));

	return result;
}

void ForwardCallVoteStart(int sessionId)
{
	Call_StartForward(g_ForwardCallVoteStart);
	Call_PushCell(sessionId);
	Call_Finish();

	CVLog.Forwards("[ForwardCallVoteStart] session=%d", sessionId);
}

Action ForwardCallVotePreExecute()
{
	if (!g_bCurrentVoteSessionValid)
		return Plugin_Continue;

	Action result = Plugin_Continue;

	Call_StartForward(g_ForwardCallVotePreExecute);
	Call_PushCell(g_CurrentVoteSession.sessionId);
	Call_PushCell(g_CurrentVoteSession.callerClient);
	Call_PushCell(g_CurrentVoteSession.callerAccountId);
	Call_PushCell(g_CurrentVoteSession.voteType);
	Call_PushCell(g_CurrentVoteSession.targetClient);
	Call_PushCell(g_CurrentVoteSession.targetAccountId);
	Call_PushString(g_CurrentVoteSession.argumentRaw);
	Call_Finish(result);

	CVLog.Forwards("[ForwardCallVotePreExecute] session=%d result=%d",
		g_CurrentVoteSession.sessionId,
		view_as<int>(result));

	return result;
}

void ForwardCallVoteBlocked(VoteRestrictionType restriction)
{
	if (!g_bCurrentVoteSessionValid)
		return;

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

	CVLog.Forwards("[ForwardCallVoteBlocked] session=%d restriction=%d",
		g_CurrentVoteSession.sessionId,
		view_as<int>(restriction));
}

void ForwardCallVoteEnd(CallVoteEndReason endReason)
{
	if (!g_bCurrentVoteSessionValid)
		return;

	Call_StartForward(g_ForwardCallVoteEnd);
	Call_PushCell(g_CurrentVoteSession.sessionId);
	Call_PushCell(endReason);
	Call_PushCell(g_CurrentVoteSession.yesVotes);
	Call_PushCell(g_CurrentVoteSession.noVotes);
	Call_PushCell(g_CurrentVoteSession.potentialVotes);
	Call_Finish();

	CVLog.Forwards("[ForwardCallVoteEnd] session=%d result=%d yes=%d no=%d potential=%d",
		g_CurrentVoteSession.sessionId,
		view_as<int>(endReason),
		g_CurrentVoteSession.yesVotes,
		g_CurrentVoteSession.noVotes,
		g_CurrentVoteSession.potentialVotes);
}
