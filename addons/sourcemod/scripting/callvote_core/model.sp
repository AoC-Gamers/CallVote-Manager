enum CallVoteSessionStatus
{
	CallVoteSession_None = 0,
	CallVoteSession_Pending,
	CallVoteSession_Executing,
	CallVoteSession_Started,
	CallVoteSession_Blocked,
	CallVoteSession_Ended
}

enum CallVoteSessionLookupResult
{
	CallVoteSessionLookup_None = 0,
	CallVoteSessionLookup_Current,
	CallVoteSessionLookup_Last
}

enum struct CVClientIdentity
{
	int Client;
	int UserId;
	int AccountId;
	char SteamID64[STEAMID64_EXACT_LENGTH + 1];
}

enum struct CVVoteSession
{
	int sessionId;
	CallVoteSessionStatus status;
	int createdAt;
	float dispatchedAt;
	int callerClient;
	int callerUserId;
	int callerAccountId;
	TypeVotes voteType;
	int targetClient;
	int targetUserId;
	int targetAccountId;
	char callerSteamID64[STEAMID64_EXACT_LENGTH + 1];
	char targetSteamID64[STEAMID64_EXACT_LENGTH + 1];
	char argumentRaw[64];
	char engineIssue[128];
	char engineParam1[128];
	char engineParam2[128];
	int engineFailReason;
	int engineFailTime;
	int engineTeam;
	int engineInitiatorClient;
	VoteRestrictionType restriction;
	CallVoteEndReason endReason;
	int yesVotes;
	int noVotes;
	int potentialVotes;
}
