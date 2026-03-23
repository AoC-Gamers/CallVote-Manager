stock char sTypeVotes[TypeVotes_Size][] = {
	"ChangeDifficulty",
	"RestartGame",
	"Kick",
	"ChangeMission",
	"ReturnToLobby",
	"ChangeChapter",
	"ChangeAllTalk"
};

StringMap g_mapVoteTypes;

void InitializeVoteTypesMap()
{
	g_mapVoteTypes = new StringMap();

	g_mapVoteTypes.SetValue("changedifficulty", ChangeDifficulty);
	g_mapVoteTypes.SetValue("restartgame", RestartGame);
	g_mapVoteTypes.SetValue("kick", Kick);
	g_mapVoteTypes.SetValue("changemission", ChangeMission);
	g_mapVoteTypes.SetValue("returntolobby", ReturnToLobby);
	g_mapVoteTypes.SetValue("changechapter", ChangeChapter);
	g_mapVoteTypes.SetValue("changealltalk", ChangeAllTalk);
}

bool GetVoteTypeFromString(const char[] sVoteType, TypeVotes &voteType)
{
	char sLowerVoteType[32];
	strcopy(sLowerVoteType, sizeof(sLowerVoteType), sVoteType);

	for (int i = 0; sLowerVoteType[i] != '\0'; i++)
	{
		sLowerVoteType[i] = CharToLower(sLowerVoteType[i]);
	}

	int value;
	if (g_mapVoteTypes.GetValue(sLowerVoteType, value))
	{
		voteType = view_as<TypeVotes>(value);
		return true;
	}

	return false;
}
