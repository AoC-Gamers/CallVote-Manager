Action ProcessVoteCommon(int iClient, TypeVotes type, int iTarget = SERVER_INDEX, const char[] sArgument = "")
{
	if (g_ForwardDispatchDepth > 0)
		return Plugin_Handled;
	BeginVoteSession(iClient, type, iTarget, sArgument);
	int sessionId = g_CurrentVoteSession.sessionId;
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
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.sessionId != sessionId
		|| g_CurrentVoteSession.status != CallVoteSession_Pending)
		return Plugin_Handled;
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
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.sessionId != sessionId
		|| g_CurrentVoteSession.status != CallVoteSession_Pending)
		return Plugin_Handled;
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
	CreateTimer(CVC_START_CONFIRM_TIMEOUT, Timer_VoteStartDeadline, g_CurrentVoteSession.sessionId, TIMER_FLAG_NO_MAPCHANGE);
	CVLog.Forwards("[ProcessVoteCommon] session=%d continuing to engine execute status=%d", g_CurrentVoteSession.sessionId, view_as<int>(g_CurrentVoteSession.status));

	return Plugin_Continue;
}

static Action Timer_VoteStartDeadline(Handle timer, any sessionId)
{
	ExpireUnconfirmedVoteRequest(sessionId);
	return Plugin_Stop;
}

void ExpireUnconfirmedVoteRequest(int sessionId)
{
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.sessionId != sessionId
		|| g_CurrentVoteSession.status != CallVoteSession_Executing)
		return;
	// No start confirmation is not an authoritative rejection reason.
	CVLog.Session("[VoteStartDeadline] session=%d no_start_confirmation=1", sessionId);
	g_CurrentVoteSession.yesVotes = -1;
	g_CurrentVoteSession.noVotes = -1;
	g_CurrentVoteSession.potentialVotes = -1;
	FinalizeStaleCurrentVoteSession();
}
