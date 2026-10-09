#if defined _cvb_policy_included
	#endinput
#endif
#define _cvb_policy_included

// Only the pending veto belongs here; the Core owns the voting lifecycle.
enum struct CVBVoteBlockState
{
	int sessionId;
	int callerSerial;
	int callerAccountId;
	int targetSerial;
	VoteRestrictionType reason;
	bool validationFailed;
}

CVBVoteBlockState g_VoteBlock;
PlayerRestrictionInfo g_VoteBlockInfo;

void CVB_ClearVoteBlock()
{
	g_VoteBlock.sessionId = 0;
	g_VoteBlock.callerSerial = 0;
	g_VoteBlock.callerAccountId = 0;
	g_VoteBlock.targetSerial = 0;
	g_VoteBlock.reason = VoteRestriction_None;
	g_VoteBlock.validationFailed = false;
	g_VoteBlockInfo.Reset();
}

static bool CVB_MatchesClientIdentity(int client, int accountId)
{
	return IsValidClient(client) && GetSteamAccountID(client) == accountId;
}

static Action CVB_VetoVote(int sessionId, int client, int callerAccountId, int target, int targetAccountId,
	VoteRestrictionType reason, bool validationFailed, PlayerRestrictionInfo info)
{
	g_VoteBlock.sessionId = sessionId;
	g_VoteBlock.callerSerial = CVB_MatchesClientIdentity(client, callerAccountId) ? GetClientSerial(client) : 0;
	g_VoteBlock.callerAccountId = callerAccountId;
	g_VoteBlock.targetSerial = CVB_MatchesClientIdentity(target, targetAccountId) ? GetClientSerial(target) : 0;
	g_VoteBlock.reason = reason;
	g_VoteBlock.validationFailed = validationFailed;
	g_VoteBlockInfo = info;
	CallVoteCore_SetPendingRestriction(reason);
	return Plugin_Handled;
}

public Action CallVote_PreStart(int sessionId, int client, int callerAccountId, TypeVotes voteType,
	int target, int targetAccountId, const char[] argument)
{
	CVB_ClearVoteBlock();
	if (!g_cvarEnable.BoolValue || !g_bCallVoteCoreLibrary)
		return Plugin_Continue;

	VoteType voteFlag = GetVoteFlag(voteType);
	if (voteFlag == VOTE_NONE)
		return Plugin_Continue;

	PlayerRestrictionInfo info;
	info.Reset(callerAccountId);
	if (callerAccountId <= 0 || !CVB_MatchesClientIdentity(client, callerAccountId))
		return CVB_VetoVote(sessionId, client, callerAccountId, target, targetAccountId,
			VoteRestriction_ClientState, true, info);

	// Reuse active restrictions; otherwise validate once against the active backend.
	CVBLookupStatus status;
	if (CVB_GetActiveDatabase() == SourceDB_Unknown)
		status = CVBLookup_Error;
	else if (CVB_GetMemoryCache(info) && info.IsBanned())
		status = CVBLookup_Found;
	else
		status = CVB_LoadRestrictionInfo(info, true);
	SetClientLoadState(client, callerAccountId,
		status == CVBLookup_Error ? ClientBanLoad_Uninitialized : ClientBanLoad_Ready);
	CVBLog.Debug("PreStart session=%d callerAccountId=%d type=%d status=%d mask=%d argument=%s",
		sessionId, callerAccountId, voteType, status, info.RestrictionMask, argument);

	if (status == CVBLookup_Error)
		return CVB_VetoVote(sessionId, client, callerAccountId, target, targetAccountId,
			VoteRestriction_Plugin, true, info);
	if (status == CVBLookup_Found && info.IsBanned() && (info.RestrictionMask & view_as<int>(voteFlag)))
		return CVB_VetoVote(sessionId, client, callerAccountId, target, targetAccountId,
			VoteRestriction_Plugin, false, info);
	return Plugin_Continue;
}

public void CallVote_Blocked(int sessionId, int client, int callerAccountId, TypeVotes voteType,
	VoteRestrictionType restriction, int target, int targetAccountId, const char[] argument)
{
	if (g_VoteBlock.sessionId != sessionId || g_VoteBlock.callerAccountId != callerAccountId)
		return;

	CVBVoteBlockState pending;
	pending = g_VoteBlock;
	PlayerRestrictionInfo info;
	info = g_VoteBlockInfo;
	CVB_ClearVoteBlock();
	if (!g_cvarEnable.BoolValue || pending.reason != restriction)
		return;

	int liveCaller = GetClientFromSerial(pending.callerSerial);
	int liveTarget = GetClientFromSerial(pending.targetSerial);
	if (!CVB_MatchesClientIdentity(liveTarget, targetAccountId))
		liveTarget = 0;
	if (!CVB_MatchesClientIdentity(liveCaller, callerAccountId))
		liveCaller = 0;

	if (liveCaller > 0)
	{
		if (pending.validationFailed)
			ShowVoteBlockedValidationMessage(liveCaller);
		else
			ShowVoteBlockedMessage(liveCaller, voteType, info);
	}
	CVBLog.Event("VoteBlocked", "session=%d callerAccountId=%d targetAccountId=%d type=%d validationFailed=%d mask=%d argument=%s",
		sessionId, callerAccountId, targetAccountId, voteType, pending.validationFailed, info.RestrictionMask, argument);
	if (g_gfBlocked != null)
	{
		Call_StartForward(g_gfBlocked);
		Call_PushCell(liveCaller);
		Call_PushCell(view_as<int>(voteType));
		Call_PushCell(liveTarget);
		Call_PushCell(pending.validationFailed ? 0 : info.RestrictionMask);
		Call_Finish();
	}
}

public void CallVote_End(int sessionId, CallVoteEndReason result, int yesCount, int noCount, int potentialCount)
{
	if (g_VoteBlock.sessionId == sessionId)
		CVB_ClearVoteBlock();
}

public void OnMapEnd()
{
	CVB_ClearVoteBlock();
}

void CVB_OnEnableChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	#pragma unused convar
	#pragma unused oldValue
	#pragma unused newValue
	CVB_ClearVoteBlock();
}
