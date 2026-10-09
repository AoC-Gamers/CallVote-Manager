// Each recipient gets a Valve translation or a plugin-owned fallback.
void PrintLocalizedMissionName(const char[] missionCode, int caller)
{
	CVLog.Localization("[PrintLocalizedMissionName] Preparing per-recipient announcement");
	char campaign[8], key[64];
	Campaign_RemoveMapPrefix(missionCode, campaign, sizeof(campaign));
	Format(key, sizeof(key), "#L4D360UI_CampaignName_%s", campaign);
	for (int recipient = 1; recipient <= MaxClients; recipient++)
	{
		if (!IsClientInGame(recipient) || IsFakeClient(recipient))
			continue;
		char label[LC_MAX_TRANSLATION_LENGTH];
		if (!Lang_GetValveTranslation(recipient, key, label, sizeof(label), g_loc))
			strcopy(label, sizeof(label), missionCode);
		CPrintToChat(recipient, "%t %t", "Tag", "ChangeMission", caller, label);
	}
}

void PrintLocalizedChapterName(const char[] mapName, int caller)
{
	CVLog.Localization("[PrintLocalizedChapterName] Preparing per-recipient announcement");
	char mapCode[16];
	bool knownMap = Campaign_ExtractMapCode(mapName, mapCode, sizeof(mapCode));
	if (knownMap)
		StrUpper(mapCode);
	for (int recipient = 1; recipient <= MaxClients; recipient++)
	{
		if (!IsClientInGame(recipient) || IsFakeClient(recipient))
			continue;
		char chapter[LC_MAX_TRANSLATION_LENGTH], campaign[LC_MAX_TRANSLATION_LENGTH], label[256];
		strcopy(label, sizeof(label), mapName);
		if (knownMap && Chapter_GetLocalizedName(mapCode, recipient, chapter, sizeof(chapter), g_loc))
		{
			if (Campaign_GetLocalizedNameFromMapCode(mapCode, recipient, campaign, sizeof(campaign), g_loc))
				Format(label, sizeof(label), "%s - %s", campaign, chapter);
			else
				strcopy(label, sizeof(label), chapter);
		}
		CPrintToChat(recipient, "%t %t", "Tag", "ChangeChapter", caller, label);
	}
}

void PrintLocalizedAllTalk(int caller)
{
	CVLog.Localization("[PrintLocalizedAllTalk] Preparing per-recipient announcement");
	bool newState = !sv_alltalk.BoolValue;
	for (int recipient = 1; recipient <= MaxClients; recipient++)
	{
		if (!IsClientInGame(recipient) || IsFakeClient(recipient))
			continue;
		char label[LC_MAX_TRANSLATION_LENGTH], state[LC_MAX_TRANSLATION_LENGTH];
		if (!CallVoteLoc_GetVoteTypeLabel(ChangeAllTalk, recipient, g_loc, label, sizeof(label)))
			Format(label, sizeof(label), "%T", "AllTalkLabel", recipient);
		if (!CallVoteLoc_GetEnabledStateLabel(newState, recipient, g_loc, state, sizeof(state)))
			Format(state, sizeof(state), "%T", newState ? "StateEnabled" : "StateDisabled", recipient);
		CPrintToChat(recipient, "%t %t", "Tag", "ChangeAllTalk", caller, label, state);
	}
}

void PrintLocalizedDifficulty(const char[] argument, int caller)
{
	CVLog.Localization("[PrintLocalizedDifficulty] Preparing per-recipient announcement");
	for (int recipient = 1; recipient <= MaxClients; recipient++)
	{
		if (!IsClientInGame(recipient) || IsFakeClient(recipient))
			continue;
		char label[LC_MAX_TRANSLATION_LENGTH];
		if (!CallVoteLoc_GetDifficultyLabel(argument, recipient, g_loc, label, sizeof(label)))
			strcopy(label, sizeof(label), argument);
		CPrintToChat(recipient, "%t %t", "Tag", "ChangeDifficulty", caller, label);
	}
}

void PrintLocalizedKick(int caller, int target)
{
	CVLog.Localization("[PrintLocalizedKick] Preparing per-recipient announcement");
	for (int recipient = 1; recipient <= MaxClients; recipient++)
	{
		if (!IsClientInGame(recipient) || IsFakeClient(recipient))
			continue;
		CPrintToChat(recipient, "%t %t", "Tag", "KickVote", caller, target);
	}
}

void PrintLocalizedRestartGame(int caller)
{
	CVLog.Localization("[PrintLocalizedRestartGame] Preparing per-recipient announcement");
	int gameMode = L4D_GetGameModeType();
	char fallback[32];
	switch (gameMode)
	{
		case GAMEMODE_COOP: strcopy(fallback, sizeof(fallback), "RestartCampaignLabel");
		case GAMEMODE_SURVIVAL: strcopy(fallback, sizeof(fallback), "RestartRoundLabel");
		case GAMEMODE_VERSUS: strcopy(fallback, sizeof(fallback), "RestartChapterLabel");
		default: strcopy(fallback, sizeof(fallback), "RestartGameLabel");
	}
	for (int recipient = 1; recipient <= MaxClients; recipient++)
	{
		if (!IsClientInGame(recipient) || IsFakeClient(recipient))
			continue;
		char label[LC_MAX_TRANSLATION_LENGTH];
		if (!CallVoteLoc_GetRestartLabel(gameMode, recipient, g_loc, label, sizeof(label)))
			Format(label, sizeof(label), "%T", fallback, recipient);
		CPrintToChat(recipient, "%t %t", "Tag", "RestartVote", caller, label);
	}
}

void PrintLocalizedReturnToLobby(int caller)
{
	CVLog.Localization("[PrintLocalizedReturnToLobby] Preparing per-recipient announcement");
	for (int recipient = 1; recipient <= MaxClients; recipient++)
	{
		if (!IsClientInGame(recipient) || IsFakeClient(recipient))
			continue;
		CPrintToChat(recipient, "%t %t", "Tag", "LobbyVote", caller);
	}
}
