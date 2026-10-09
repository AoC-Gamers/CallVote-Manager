int Native_GetCurrentSession(Handle plugin, int numParams)
{
	if (!g_bCurrentVoteSessionValid)
		return 0;

	return g_CurrentVoteSession.sessionId;
}

int Native_GetSessionInfo(Handle plugin, int numParams)
{
	int sessionId = GetNativeCell(1);
	CVVoteSession session;

	if (!TryGetNativeVoteSession(sessionId, session))
		return false;

	TypeVotes voteType = session.voteType;
	SetNativeCellRef(2, session.callerClient);
	SetNativeCellRef(3, session.callerAccountId);
	SetNativeCellRef(4, voteType);
	SetNativeCellRef(5, session.targetClient);
	SetNativeCellRef(6, session.targetAccountId);
	SetNativeString(7, session.argumentRaw, GetNativeCell(8), true);
	return true;
}

int Native_GetSessionIssueInfo(Handle plugin, int numParams)
{
	int sessionId = GetNativeCell(1);
	CVVoteSession session;

	if (!TryGetNativeVoteSession(sessionId, session))
		return false;

	SetNativeString(2, session.engineIssue, GetNativeCell(3), true);
	SetNativeString(4, session.engineParam1, GetNativeCell(5), true);
	SetNativeString(6, session.engineParam2, GetNativeCell(7), true);
	SetNativeCellRef(8, session.engineTeam);
	SetNativeCellRef(9, session.engineInitiatorClient);
	SetNativeCellRef(10, session.engineInitiatorAccountId);
	return true;
}

int Native_GetSessionFailureInfo(Handle plugin, int numParams)
{
	int sessionId = GetNativeCell(1);
	CVVoteSession session;

	if (!TryGetNativeVoteSession(sessionId, session))
		return false;

	SetNativeCellRef(2, session.engineFailReason);
	SetNativeCellRef(3, session.engineFailTime);
	return true;
}

int Native_GetSessionTally(Handle plugin, int numParams)
{
	int sessionId = GetNativeCell(1);
	CVVoteSession session;

	if (!TryGetNativeVoteSession(sessionId, session))
		return false;

	CallVoteEndReason endReason = session.endReason;
	SetNativeCellRef(2, session.yesVotes);
	SetNativeCellRef(3, session.noVotes);
	SetNativeCellRef(4, session.potentialVotes);
	SetNativeCellRef(5, endReason);
	return true;
}

int Native_GetSessionState(Handle plugin, int numParams)
{
	CVVoteSession session;
	if (!TryGetNativeVoteSession(GetNativeCell(1), session))
		return false;
	SetNativeCellRef(2, session.status);
	SetNativeCellRef(3, session.restriction);
	return true;
}
