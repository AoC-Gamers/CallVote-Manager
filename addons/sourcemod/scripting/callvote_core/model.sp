enum CallVoteSessionLookupResult
{
	CallVoteSessionLookup_None = 0,
	CallVoteSessionLookup_Current,
	CallVoteSessionLookup_Last
}

enum struct CVVoteSession
{
	int sessionId;
	bool startForwarded;
	bool endForwarded;
	int controllerRef;
	int controllerIssue;
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
	char argumentRaw[64];
	char engineIssue[128];
	char engineParam1[128];
	char engineParam2[128];
	int engineFailReason;
	int engineFailTime;
	int engineTeam;
	int engineInitiatorClient;
	int engineInitiatorAccountId;
	VoteRestrictionType restriction;
	CallVoteEndReason endReason;
	int yesVotes;
	int noVotes;
	int potentialVotes;
}
