int Native_GetClientAccountID(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsValidClientIndex(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}

	return GetClientAccountID(client);
}

int Native_GetClientSteamID2(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int maxlen = GetNativeCell(3);
	char steamId2[MAX_AUTHID_LENGTH];
	steamId2[0] = '\0';

	if (!IsValidClientIndex(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	}

	bool result = AccountIDToSteamID2(GetClientAccountID(client), steamId2, sizeof(steamId2));
	SetNativeString(2, steamId2, maxlen, true);
	return result;
}

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

int Native_GetSessionSteamID64Info(Handle plugin, int numParams)
{
	int sessionId = GetNativeCell(1);
	char callerSteamID64[STEAMID64_EXACT_LENGTH + 1];
	char targetSteamID64[STEAMID64_EXACT_LENGTH + 1];

	if (sessionId <= 0)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid session id (%d)", sessionId);
	}

	if (!TryGetSessionSteamID64Info(sessionId, callerSteamID64, sizeof(callerSteamID64), targetSteamID64, sizeof(targetSteamID64)))
		return false;

	SetNativeString(2, callerSteamID64, GetNativeCell(3), true);
	SetNativeString(4, targetSteamID64, GetNativeCell(5), true);
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
