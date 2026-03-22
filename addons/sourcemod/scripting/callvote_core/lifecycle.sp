Action ProcessVoteCommon(int iClient, TypeVotes type, int iTarget = SERVER_INDEX, const char[] sArgument = "")
{
	BeginVoteSession(iClient, type, iTarget, sArgument);

	g_PendingForwardRestriction = VoteRestriction_None;
	Action preStartResult = ForwardCallVotePreStart();
	if (preStartResult >= Plugin_Handled)
	{
		VoteRestrictionType restriction = g_PendingForwardRestriction != VoteRestriction_None ? g_PendingForwardRestriction : VoteRestriction_Plugin;
		CVLog.Forwards("[ProcessVoteCommon] Vote blocked by PreStart forward for client %d", iClient);
		CVLog.Event("VoteBlocked", "session=%d callerAccountId=%d voteType=%d stage=PreStart restriction=%d target=%d argument=%s",
			g_CurrentVoteSession.sessionId,
			g_CurrentVoteSession.callerAccountId,
			g_CurrentVoteSession.voteType,
			restriction,
			g_CurrentVoteSession.targetAccountId,
			g_CurrentVoteSession.argumentRaw);
		FinalizeBlockedCurrentVoteSession(restriction);
		return Plugin_Handled;
	}

	g_PendingForwardRestriction = VoteRestriction_None;
	Action preExecuteResult = ForwardCallVotePreExecute();
	if (preExecuteResult >= Plugin_Handled)
	{
		VoteRestrictionType restriction = g_PendingForwardRestriction != VoteRestriction_None ? g_PendingForwardRestriction : VoteRestriction_Plugin;
		CVLog.Forwards("[ProcessVoteCommon] Vote blocked by PreExecute forward for client %d", iClient);
		CVLog.Event("VoteBlocked", "session=%d callerAccountId=%d voteType=%d stage=PreExecute restriction=%d target=%d argument=%s",
			g_CurrentVoteSession.sessionId,
			g_CurrentVoteSession.callerAccountId,
			g_CurrentVoteSession.voteType,
			restriction,
			g_CurrentVoteSession.targetAccountId,
			g_CurrentVoteSession.argumentRaw);
		FinalizeBlockedCurrentVoteSession(restriction);
		return Plugin_Handled;
	}

	g_CurrentVoteSession.status = CallVoteSession_Executing;
	g_CurrentVoteSession.dispatchedAt = GetEngineTime();

	return Plugin_Continue;
}
