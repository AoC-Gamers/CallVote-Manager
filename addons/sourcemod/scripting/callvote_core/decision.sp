/** Evaluate each consumer separately so an allowing plugin cannot supply a veto reason. */
Action DispatchVoteDecision(const char[] callback)
{
	if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.status != CallVoteSession_Pending)
		return Plugin_Handled;

	CVVoteSession proposed;
	proposed = g_CurrentVoteSession;
	VoteRestrictionType selected = VoteRestriction_None;
	Action decision = Plugin_Continue;
	Handle plugins = GetPluginIterator();
	g_ForwardDispatchDepth++;
	while (MorePlugins(plugins))
	{
		Handle consumer = ReadPlugin(plugins);
		if (GetPluginStatus(consumer) != Plugin_Running || consumer == GetMyHandle())
			continue;
		Function callbackFunction = GetFunctionByName(consumer, callback);
		if (callbackFunction == INVALID_FUNCTION)
			continue;

		g_DecisionConsumer = consumer;
		g_DecisionSessionId = proposed.sessionId;
		g_PendingForwardRestriction = VoteRestriction_None;
		Action result = Plugin_Continue;
		Call_StartFunction(consumer, callbackFunction);
		Call_PushCell(proposed.sessionId);
		Call_PushCell(proposed.callerClient);
		Call_PushCell(proposed.callerAccountId);
		Call_PushCell(proposed.voteType);
		Call_PushCell(proposed.targetClient);
		Call_PushCell(proposed.targetAccountId);
		Call_PushString(proposed.argumentRaw);
		int error = Call_Finish(result);
		VoteRestrictionType candidate = g_PendingForwardRestriction;
		g_DecisionConsumer = null;
		g_DecisionSessionId = 0;
		g_PendingForwardRestriction = VoteRestriction_None;

		if (error != SP_ERROR_NONE)
		{
			char filename[PLATFORM_MAX_PATH];
			GetPluginFilename(consumer, filename, sizeof(filename));
			LogError("[CallVote Core] event=decision_failed hook=%s plugin=%s error=%d", callback, filename, error);
			result = Plugin_Handled;
			candidate = VoteRestriction_Plugin;
		}
		if (result >= Plugin_Handled)
		{
			if (decision == Plugin_Continue)
				selected = candidate != VoteRestriction_None ? candidate : VoteRestriction_Plugin;
			decision = Plugin_Handled;
		}
		if (!g_bCurrentVoteSessionValid || g_CurrentVoteSession.sessionId != proposed.sessionId
			|| g_CurrentVoteSession.status != CallVoteSession_Pending)
		{
			decision = Plugin_Handled;
			break;
		}
	}
	g_ForwardDispatchDepth--;
	delete plugins;
	g_PendingForwardRestriction = selected;
	CVLog.Forwards("[Decision] hook=%s session=%d result=%d restriction=%d", callback, proposed.sessionId, decision, selected);
	return decision;
}

/** A reason is local to the active consumer and has no effect without its veto. */
int Native_SetPendingRestriction(Handle plugin, int numParams)
{
	VoteRestrictionType restriction = view_as<VoteRestrictionType>(GetNativeCell(1));
	if (restriction <= VoteRestriction_None || restriction > VoteRestriction_Plugin)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid vote restriction (%d)", restriction);
	if (g_DecisionConsumer != plugin || g_DecisionSessionId == 0
		|| !g_bCurrentVoteSessionValid || g_CurrentVoteSession.sessionId != g_DecisionSessionId
		|| g_CurrentVoteSession.status != CallVoteSession_Pending)
		return ThrowNativeError(SP_ERROR_NATIVE, "Restriction may only be set by the active PreStart/PreExecute consumer");

	g_PendingForwardRestriction = restriction;
	return 0;
}
