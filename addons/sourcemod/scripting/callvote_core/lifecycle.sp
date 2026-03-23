Action ProcessVoteCommon(int iClient, TypeVotes type, int iTarget = SERVER_INDEX, const char[] sArgument = "")
{
	BeginVoteSession(iClient, type, iTarget, sArgument);
	CVLog.Forwards("[ProcessVoteCommon] session=%d begin caller=%d callerAccountId=%d type=%d target=%d targetAccountId=%d argument='%s'",
		g_CurrentVoteSession.sessionId,
		g_CurrentVoteSession.callerClient,
		g_CurrentVoteSession.callerAccountId,
		view_as<int>(g_CurrentVoteSession.voteType),
		g_CurrentVoteSession.targetClient,
		g_CurrentVoteSession.targetAccountId,
		g_CurrentVoteSession.argumentRaw);

	g_PendingForwardRestriction = VoteRestriction_None;
	CVLog.Forwards("[ProcessVoteCommon] session=%d prestart pending reset to %d", g_CurrentVoteSession.sessionId, view_as<int>(g_PendingForwardRestriction));
	Action preStartResult = ForwardCallVotePreStart();
	CVLog.Forwards("[ProcessVoteCommon] session=%d prestart result=%d pending=%d", g_CurrentVoteSession.sessionId, view_as<int>(preStartResult), view_as<int>(g_PendingForwardRestriction));
	if (preStartResult >= Plugin_Handled)
	{
		VoteRestrictionType restriction = g_PendingForwardRestriction != VoteRestriction_None ? g_PendingForwardRestriction : VoteRestriction_Plugin;
		CVLog.Forwards("[ProcessVoteCommon] Vote blocked by PreStart forward for client %d with restriction=%d", iClient, view_as<int>(restriction));
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
	CVLog.Forwards("[ProcessVoteCommon] session=%d preexecute pending reset to %d", g_CurrentVoteSession.sessionId, view_as<int>(g_PendingForwardRestriction));
	Action preExecuteResult = ForwardCallVotePreExecute();
	CVLog.Forwards("[ProcessVoteCommon] session=%d preexecute result=%d pending=%d", g_CurrentVoteSession.sessionId, view_as<int>(preExecuteResult), view_as<int>(g_PendingForwardRestriction));
	if (preExecuteResult >= Plugin_Handled)
	{
		VoteRestrictionType restriction = g_PendingForwardRestriction != VoteRestriction_None ? g_PendingForwardRestriction : VoteRestriction_Plugin;
		CVLog.Forwards("[ProcessVoteCommon] Vote blocked by PreExecute forward for client %d with restriction=%d", iClient, view_as<int>(restriction));
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
	CVLog.Forwards("[ProcessVoteCommon] session=%d continuing to engine execute status=%d", g_CurrentVoteSession.sessionId, view_as<int>(g_CurrentVoteSession.status));

	return Plugin_Continue;
}
