static Action BlockInvalidCallerVote(TypeVotes voteType, int target = SERVER_INDEX, const char[] argument = "")
{
	BeginVoteSession(SERVER_INDEX, voteType, target, argument);

	CVLog.Event("VoteBlocked", "session=%d callerAccountId=%d voteType=%d stage=Listener restriction=%d target=%d argument=%s",
		g_CurrentVoteSession.sessionId,
		g_CurrentVoteSession.callerAccountId,
		g_CurrentVoteSession.voteType,
		VoteRestriction_InvalidCaller,
		g_CurrentVoteSession.targetAccountId,
		g_CurrentVoteSession.argumentRaw);

	FinalizeBlockedCurrentVoteSession(VoteRestriction_InvalidCaller);
	CReplyToCommand(SERVER_INDEX, "%t %t", "Tag", "ValidClientOnly");
	return Plugin_Handled;
}

Action Listener_CallVote(int iClient, const char[] sCommand, int iArgs)
{
	if (!g_cvarEnable.BoolValue)
		return Plugin_Continue;

	char sFullArgs[128];
	GetCmdArgString(sFullArgs, sizeof(sFullArgs));
	CVLog.Debug("[Listener_CallVote] Full argument string: %s", sFullArgs);

	if (GetCmdArgs() == 0)
	{
		return Plugin_Continue;
	}

	char sVoteType[32];
	char sVoteArgument[32];

	GetCmdArg(1, sVoteType, sizeof(sVoteType));
	GetCmdArg(2, sVoteArgument, sizeof(sVoteArgument));

	TypeVotes voteType;
	if (!GetVoteTypeFromString(sVoteType, voteType))
	{
		return Plugin_Continue;
	}

	switch (voteType)
	{
		case ChangeDifficulty:
		{
			if (iArgs != 2)
				return Plugin_Continue;

			if (iClient == SERVER_INDEX)
				return BlockInvalidCallerVote(ChangeDifficulty, SERVER_INDEX, sVoteArgument);

			Action result = ProcessVoteCommon(iClient, ChangeDifficulty, SERVER_INDEX, sVoteArgument);
			if (result == Plugin_Handled)
				return Plugin_Handled;
		}
		case RestartGame:
		{
			if (iArgs != 1)
				return Plugin_Continue;

			if (iClient == SERVER_INDEX)
				return BlockInvalidCallerVote(RestartGame);

			Action result = ProcessVoteCommon(iClient, RestartGame);
			CVLog.Forwards("[Listener_CallVote] RestartGame result=%d for client=%d accountId=%d", view_as<int>(result), iClient, GetClientAccountID(iClient));
			if (result == Plugin_Handled)
				return Plugin_Handled;
		}
		case Kick:
		{
			int iTarget = GetClientOfUserId(GetCmdArgInt(2));

			if (iTarget == SERVER_INDEX)
				return Plugin_Handled;

			if (iClient == SERVER_INDEX)
				return BlockInvalidCallerVote(Kick, iTarget);

			Action result = ProcessVoteCommon(iClient, Kick, iTarget);
			CVLog.Forwards("[Listener_CallVote] Kick result=%d for client=%d accountId=%d target=%d targetAccountId=%d", view_as<int>(result), iClient, GetClientAccountID(iClient), iTarget, IsValidClient(iTarget) ? GetClientAccountID(iTarget) : 0);
			if (result == Plugin_Handled)
				return Plugin_Handled;
		}
		case ChangeMission:
		{
			if (iArgs != 2)
				return Plugin_Continue;

			if (iClient == SERVER_INDEX)
				return BlockInvalidCallerVote(ChangeMission, SERVER_INDEX, sVoteArgument);

			Action result = ProcessVoteCommon(iClient, ChangeMission, SERVER_INDEX, sVoteArgument);
			CVLog.Forwards("[Listener_CallVote] ChangeMission result=%d for client=%d accountId=%d argument='%s'", view_as<int>(result), iClient, GetClientAccountID(iClient), sVoteArgument);
			if (result == Plugin_Handled)
				return Plugin_Handled;
		}
		case ReturnToLobby:
		{
			if (iArgs != 1)
				return Plugin_Continue;

			if (iClient == SERVER_INDEX)
				return BlockInvalidCallerVote(ReturnToLobby);

			Action result = ProcessVoteCommon(iClient, ReturnToLobby);
			CVLog.Forwards("[Listener_CallVote] ReturnToLobby result=%d for client=%d accountId=%d", view_as<int>(result), iClient, GetClientAccountID(iClient));
			if (result == Plugin_Handled)
				return Plugin_Handled;
		}
		case ChangeChapter:
		{
			if (iArgs != 2)
				return Plugin_Continue;

			if (iClient == SERVER_INDEX)
				return BlockInvalidCallerVote(ChangeChapter, SERVER_INDEX, sVoteArgument);

			Action result = ProcessVoteCommon(iClient, ChangeChapter, SERVER_INDEX, sVoteArgument);
			CVLog.Forwards("[Listener_CallVote] ChangeChapter result=%d for client=%d accountId=%d argument='%s'", view_as<int>(result), iClient, GetClientAccountID(iClient), sVoteArgument);
			if (result == Plugin_Handled)
				return Plugin_Handled;
		}
		case ChangeAllTalk:
		{
			if (iArgs != 1)
				return Plugin_Continue;

			if (iClient == SERVER_INDEX)
				return BlockInvalidCallerVote(ChangeAllTalk);

			Action result = ProcessVoteCommon(iClient, ChangeAllTalk);
			CVLog.Forwards("[Listener_CallVote] ChangeAllTalk result=%d for client=%d accountId=%d", view_as<int>(result), iClient, GetClientAccountID(iClient));
			if (result == Plugin_Handled)
				return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}
