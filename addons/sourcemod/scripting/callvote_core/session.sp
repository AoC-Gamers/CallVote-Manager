void ResetVoteSession(CVVoteSession session)
{
	session.sessionId = 0;
	session.status = CallVoteSession_None;
	session.createdAt = 0;
	session.dispatchedAt = 0.0;
	session.callerClient = 0;
	session.callerUserId = 0;
	session.callerAccountId = 0;
	session.voteType = ChangeDifficulty;
	session.targetClient = 0;
	session.targetUserId = 0;
	session.targetAccountId = 0;
	session.callerSteamID64[0] = '\0';
	session.targetSteamID64[0] = '\0';
	session.argumentRaw[0] = '\0';
	session.engineIssue[0] = '\0';
	session.engineParam1[0] = '\0';
	session.engineParam2[0] = '\0';
	session.engineFailReason = 0;
	session.engineFailTime = 0;
	session.engineTeam = -1;
	session.engineInitiatorClient = 0;
	session.restriction = VoteRestriction_None;
	session.endReason = CallVoteEnd_Aborted;
	session.yesVotes = 0;
	session.noVotes = 0;
	session.potentialVotes = 0;
}

void ArchiveCurrentVoteSession()
{
	if (!g_bCurrentVoteSessionValid)
		return;

	g_LastVoteSession = g_CurrentVoteSession;
	g_bLastVoteSessionValid = true;
	ResetVoteSession(g_CurrentVoteSession);
	g_bCurrentVoteSessionValid = false;
}

void FinalizeBlockedCurrentVoteSession(VoteRestrictionType restriction)
{
	if (!g_bCurrentVoteSessionValid)
		return;

	g_CurrentVoteSession.status = CallVoteSession_Blocked;
	g_CurrentVoteSession.restriction = restriction;
	g_CurrentVoteSession.endReason = CallVoteEnd_Aborted;

	ForwardCallVoteBlocked(restriction);
	ForwardCallVoteEnd(g_CurrentVoteSession.endReason);
	ArchiveCurrentVoteSession();
}

void FinalizeStaleCurrentVoteSession()
{
	if (!g_bCurrentVoteSessionValid)
		return;

	if (g_CurrentVoteSession.status == CallVoteSession_Ended || g_CurrentVoteSession.status == CallVoteSession_Blocked)
	{
		ArchiveCurrentVoteSession();
		return;
	}

	g_CurrentVoteSession.status = CallVoteSession_Ended;
	g_CurrentVoteSession.endReason = CallVoteEnd_Aborted;

	CVLog.Session("[FinalizeStaleCurrentVoteSession] session=%d status=%d callerAccountId=%d voteType=%d target=%d argument='%s'",
		g_CurrentVoteSession.sessionId,
		view_as<int>(g_CurrentVoteSession.status),
		g_CurrentVoteSession.callerAccountId,
		view_as<int>(g_CurrentVoteSession.voteType),
		g_CurrentVoteSession.targetAccountId,
		g_CurrentVoteSession.argumentRaw);
	CVLog.Event("VoteResult", "session=%d callerAccountId=%d voteType=%d result=%d stale=1 yes=%d no=%d potential=%d target=%d argument=%s",
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

void ResolveClientIdentity(int client, CVClientIdentity identity, bool requireHumanForAccount = false)
{
	identity.Client = client;
	identity.UserId = IsValidClientIndex(client) ? GetClientUserId(client) : 0;
	identity.AccountId = 0;
	identity.SteamID64[0] = '\0';

	if (requireHumanForAccount)
	{
		if (IsHuman(client))
		{
			identity.AccountId = GetClientAccountID(client);
			GetClientAuthId(client, AuthId_SteamID64, identity.SteamID64, sizeof(identity.SteamID64));
		}
		return;
	}

	if (IsValidClient(client))
	{
		identity.AccountId = GetClientAccountID(client);
		GetClientAuthId(client, AuthId_SteamID64, identity.SteamID64, sizeof(identity.SteamID64));
	}
}

void BeginVoteSession(int client, TypeVotes voteType, int target = 0, const char[] argument = "")
{
	if (g_bCurrentVoteSessionValid)
	{
		CVLog.Session("[BeginVoteSession] Replacing stale active session %d", g_CurrentVoteSession.sessionId);
		FinalizeStaleCurrentVoteSession();
	}

	CVClientIdentity callerIdentity;
	CVClientIdentity targetIdentity;
	ResolveClientIdentity(client, callerIdentity);
	ResolveClientIdentity(target, targetIdentity, true);

	ResetVoteSession(g_CurrentVoteSession);
	g_CurrentVoteSession.sessionId = g_iNextVoteSessionId++;
	g_CurrentVoteSession.status = CallVoteSession_Pending;
	g_CurrentVoteSession.createdAt = GetTime();
	g_CurrentVoteSession.callerClient = callerIdentity.Client;
	g_CurrentVoteSession.callerUserId = callerIdentity.UserId;
	g_CurrentVoteSession.callerAccountId = callerIdentity.AccountId;
	g_CurrentVoteSession.voteType = voteType;
	g_CurrentVoteSession.targetClient = targetIdentity.Client;
	g_CurrentVoteSession.targetUserId = targetIdentity.UserId;
	g_CurrentVoteSession.targetAccountId = targetIdentity.AccountId;
	strcopy(g_CurrentVoteSession.callerSteamID64, sizeof(g_CurrentVoteSession.callerSteamID64), callerIdentity.SteamID64);
	strcopy(g_CurrentVoteSession.targetSteamID64, sizeof(g_CurrentVoteSession.targetSteamID64), targetIdentity.SteamID64);
	strcopy(g_CurrentVoteSession.argumentRaw, sizeof(g_CurrentVoteSession.argumentRaw), argument);
	g_bCurrentVoteSessionValid = true;

	CVLog.Session("[BeginVoteSession] session=%d caller=%d account=%d voteType=%d target=%d targetAccount=%d argument='%s'",
		g_CurrentVoteSession.sessionId,
		g_CurrentVoteSession.callerClient,
		g_CurrentVoteSession.callerAccountId,
		view_as<int>(g_CurrentVoteSession.voteType),
		g_CurrentVoteSession.targetClient,
		g_CurrentVoteSession.targetAccountId,
		g_CurrentVoteSession.argumentRaw);
}

bool TryGetVoteSessionById(int sessionId, CVVoteSession session, CallVoteSessionLookupResult &lookupResult)
{
	lookupResult = CallVoteSessionLookup_None;

	if (sessionId <= 0)
		return false;

	if (g_bCurrentVoteSessionValid && g_CurrentVoteSession.sessionId == sessionId)
	{
		session = g_CurrentVoteSession;
		lookupResult = CallVoteSessionLookup_Current;
		return true;
	}

	if (g_bLastVoteSessionValid && g_LastVoteSession.sessionId == sessionId)
	{
		session = g_LastVoteSession;
		lookupResult = CallVoteSessionLookup_Last;
		return true;
	}

	return false;
}

bool TryGetNativeVoteSession(int sessionId, CVVoteSession session)
{
	CallVoteSessionLookupResult lookupResult;

	if (sessionId <= 0)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid session id (%d)", sessionId);
		return false;
	}

	if (!TryGetVoteSessionById(sessionId, session, lookupResult))
		return false;

	return true;
}

bool TryGetSessionSteamID64Info(int sessionId, char[] callerSteamID64, int callerMaxLen, char[] targetSteamID64, int targetMaxLen)
{
	CVVoteSession session;
	CallVoteSessionLookupResult lookupResult;

	callerSteamID64[0] = '\0';
	targetSteamID64[0] = '\0';

	if (sessionId <= 0)
		return false;

	if (!TryGetVoteSessionById(sessionId, session, lookupResult))
		return false;

	strcopy(callerSteamID64, callerMaxLen, session.callerSteamID64);
	strcopy(targetSteamID64, targetMaxLen, session.targetSteamID64);
	return true;
}

bool IsClientInRecipients(int client, const int[] recipients, int recipientsNum)
{
	if (!IsValidClientIndex(client))
		return false;

	for (int i = 0; i < recipientsNum; i++)
	{
		if (recipients[i] == client)
			return true;
	}

	return false;
}

bool IsCurrentSessionCompatibleWithVoteStarted(Event event)
{
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.status != CallVoteSession_Executing)
		return false;

	int initiator = event.GetInt("initiator");
	if (initiator > 0 && g_CurrentVoteSession.callerClient > 0 && initiator != g_CurrentVoteSession.callerClient)
		return false;

	int eventTeam = event.GetInt("team");
	if (eventTeam > 0 && g_CurrentVoteSession.callerClient > 0)
	{
		L4DTeam callerTeam = L4D_GetClientTeam(g_CurrentVoteSession.callerClient);
		if (view_as<int>(callerTeam) > 0 && view_as<int>(callerTeam) != eventTeam)
			return false;
	}

	return true;
}

bool IsCurrentSessionCompatibleWithVoteFailed(const int[] recipients, int recipientsNum)
{
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.status != CallVoteSession_Executing)
		return false;

	if (!IsClientInRecipients(g_CurrentVoteSession.callerClient, recipients, recipientsNum))
		return false;

	if (g_CurrentVoteSession.dispatchedAt <= 0.0)
		return false;

	return (GetEngineTime() - g_CurrentVoteSession.dispatchedAt) <= 3.0;
}

bool IsCurrentSessionCompatibleWithVoteEnded(Event event)
{
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.status != CallVoteSession_Started)
		return false;

	int eventTeam = event.GetInt("team");
	if (eventTeam >= 0 && g_CurrentVoteSession.engineTeam >= 0 && eventTeam != g_CurrentVoteSession.engineTeam)
		return false;

	char eventVoteType[128];
	event.GetString("vote_type", eventVoteType, sizeof(eventVoteType));
	if (eventVoteType[0] != '\0')
	{
		TypeVotes eventType;
		if (GetVoteTypeFromString(eventVoteType, eventType) && eventType != g_CurrentVoteSession.voteType)
			return false;
	}

	return true;
}
