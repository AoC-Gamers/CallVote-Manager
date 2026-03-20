#if defined _cvb_notification_included
	#endinput
#endif
#define _cvb_notification_included

static void CVB_ResolveNotificationAdminIdentifier(int admin, const char[] adminIdentifier, char[] buffer, int maxlen)
{
	if (adminIdentifier[0] != '\0')
	{
		strcopy(buffer, maxlen, adminIdentifier);
		return;
	}

	if (admin == SERVER_INDEX)
	{
		strcopy(buffer, maxlen, "CONSOLE");
		return;
	}

	if (IsValidClient(admin))
	{
		GetClientName(admin, buffer, maxlen);
		return;
	}

	strcopy(buffer, maxlen, "Unknown");
}

static void CVB_PrintBanApplicationDetails(int target, const char[] adminIdentifier, const char[] banTypes, const char[] durationText, int durationMinutes)
{
	if (!IsValidClient(target))
		return;

	PrintToConsole(target, "=====================================");
	PrintToConsole(target, "%T", "BanDetailsHeader", target);
	PrintToConsole(target, "=====================================");
	PrintToConsole(target, "%T", "BanDetailsTypes", target, banTypes);
	PrintToConsole(target, "%T", "BanDetailsDuration", target, durationText);
	PrintToConsole(target, "%T", "BanDetailsAdmin", target, adminIdentifier);

	if (durationMinutes > 0)
	{
		char expirationTime[64];
		int expiresTimestamp = GetTime() + (durationMinutes * 60);
		FormatTime(expirationTime, sizeof(expirationTime), "%Y-%m-%d %H:%M:%S", expiresTimestamp);
		PrintToConsole(target, "%T", "BanDetailsExpiration", target, expirationTime);
	}

	PrintToConsole(target, "=====================================");
}

void NotifyPlayerBanApplied(int target, int admin, const char[] adminIdentifier, const char[] banTypes, const char[] durationText, int durationMinutes)
{
	if (!IsValidClient(target))
		return;

	char resolvedAdminIdentifier[MAX_NAME_LENGTH];
	CVB_ResolveNotificationAdminIdentifier(admin, adminIdentifier, resolvedAdminIdentifier, sizeof(resolvedAdminIdentifier));

	CPrintToChat(target, "%t %t", "Tag", "PlayerBanRestrictionApplied");
	CPrintToChat(target, "%t %t", "Tag", "CheckConsoleForDetails");
	CVB_PrintBanApplicationDetails(target, resolvedAdminIdentifier, banTypes, durationText, durationMinutes);
}

void ShowVoteBlockedMessage(int client, TypeVotes voteType)
{
	if (!IsValidClient(client))
		return;

	char voteTypeName[64];
	GetVoteTypeName(voteType, voteTypeName, sizeof(voteTypeName));

	char consoleMessage[32];
	Format(consoleMessage, sizeof(consoleMessage), "%T", "CheckConsoleForDetails", client);
	bool hasLoadedBanState = (g_ClientStates[client].loadState == ClientBanLoad_Ready);

	switch (voteType)
	{
		case ChangeDifficulty:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedDifficulty", hasLoadedBanState ? consoleMessage : "");
		case RestartGame:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedRestart", hasLoadedBanState ? consoleMessage : "");
		case Kick:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedKick", hasLoadedBanState ? consoleMessage : "");
		case ChangeMission:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedMission", hasLoadedBanState ? consoleMessage : "");
		case ReturnToLobby:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedLobby", hasLoadedBanState ? consoleMessage : "");
		case ChangeChapter:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedChapter", hasLoadedBanState ? consoleMessage : "");
		case ChangeAllTalk:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedAllTalk", hasLoadedBanState ? consoleMessage : "");
		default:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedGeneric", voteTypeName, hasLoadedBanState ? consoleMessage : "");
	}

	if (hasLoadedBanState)
		ShowVoteBlockedDetailsInConsole(client);
}

void ShowVoteBlockedDetailsInConsole(int client)
{
	if (g_ClientStates[client].loadState != ClientBanLoad_Ready)
		return;

	int banType = GetClientBanType(client);
	int expiresTimestamp = GetClientBanExpiration(client);
	int createdTimestamp = GetClientBanCreationTime(client);

	PrintToConsole(client, "========================================");
	PrintToConsole(client, "%T", "ConsoleVoteBlockedTitle", client);
	PrintToConsole(client, "========================================");
	PrintToConsole(client, "%T", "ConsoleVoteBlockedExplanation", client);
	PrintToConsole(client, "");

	char restrictedVotes[256];
	GetRestrictedVoteTypes(banType, restrictedVotes, sizeof(restrictedVotes), client);
	PrintToConsole(client, "%T", "ConsoleBanRestrictedVotes", client, restrictedVotes);

	if (expiresTimestamp == 0)
	{
		char permanentText[64];
		FormatDurationLocalized(client, 0, permanentText, sizeof(permanentText));
		PrintToConsole(client, "%T", "ConsoleBanDuration", client, permanentText);
	}
	else
	{
		int timeLeft = expiresTimestamp - GetTime();
		if (timeLeft <= 0)
		{
			PrintToConsole(client, "%T", "ConsoleBanExpired", client);
		}
		else
		{
 			char timeLeftText[64];
			FormatDurationLocalized(client, timeLeft, timeLeftText, sizeof(timeLeftText));
 			PrintToConsole(client, "%T", "ConsoleBanTimeLeft", client, timeLeftText);
 		}
	}

	char dateCreated[64];
	FormatTime(dateCreated, sizeof(dateCreated), "%Y-%m-%d %H:%M:%S", createdTimestamp);
	PrintToConsole(client, "%T", "ConsoleBanCreated", client, dateCreated);
	PrintToConsole(client, "========================================");
}

void GetRestrictedVoteTypes(int banType, char[] output, int maxlen, int client)
{
	char temp[512];
	temp[0] = '\0';

	if (banType & (1 << 0))
	{
		if (temp[0] != '\0')
			StrCat(temp, sizeof(temp), ", ");
		char voteTypeName[32];
		Format(voteTypeName, sizeof(voteTypeName), "%T", "VoteTypeDifficulty", client);
		StrCat(temp, sizeof(temp), voteTypeName);
	}

	if (banType & (1 << 1))
	{
		if (temp[0] != '\0')
			StrCat(temp, sizeof(temp), ", ");
		char voteTypeName[32];
		Format(voteTypeName, sizeof(voteTypeName), "%T", "VoteTypeRestart", client);
		StrCat(temp, sizeof(temp), voteTypeName);
	}

	if (banType & (1 << 2))
	{
		if (temp[0] != '\0')
			StrCat(temp, sizeof(temp), ", ");
		char voteTypeName[32];
		Format(voteTypeName, sizeof(voteTypeName), "%T", "VoteTypeKick", client);
		StrCat(temp, sizeof(temp), voteTypeName);
	}

	if (banType & (1 << 3))
	{
		if (temp[0] != '\0')
			StrCat(temp, sizeof(temp), ", ");
		char voteTypeName[32];
		Format(voteTypeName, sizeof(voteTypeName), "%T", "VoteTypeMission", client);
		StrCat(temp, sizeof(temp), voteTypeName);
	}

	if (banType & (1 << 4))
	{
		if (temp[0] != '\0')
			StrCat(temp, sizeof(temp), ", ");
		char voteTypeName[32];
		Format(voteTypeName, sizeof(voteTypeName), "%T", "VoteTypeLobby", client);
		StrCat(temp, sizeof(temp), voteTypeName);
	}

	if (banType & (1 << 5))
	{
		if (temp[0] != '\0')
			StrCat(temp, sizeof(temp), ", ");
		char voteTypeName[32];
		Format(voteTypeName, sizeof(voteTypeName), "%T", "VoteTypeChapter", client);
		StrCat(temp, sizeof(temp), voteTypeName);
	}

	if (banType & (1 << 6))
	{
		if (temp[0] != '\0')
			StrCat(temp, sizeof(temp), ", ");
		char voteTypeName[32];
		Format(voteTypeName, sizeof(voteTypeName), "%T", "VoteTypeAllTalk", client);
		StrCat(temp, sizeof(temp), voteTypeName);
	}

	strcopy(output, maxlen, temp);
}

void GetVoteTypeName(TypeVotes voteType, char[] output, int maxlen)
{
	switch (voteType)
	{
		case ChangeDifficulty: Format(output, maxlen, "%T", "VoteTypeDifficulty", LANG_SERVER);
		case RestartGame: Format(output, maxlen, "%T", "VoteTypeRestart", LANG_SERVER);
		case Kick: Format(output, maxlen, "%T", "VoteTypeKick", LANG_SERVER);
		case ChangeMission: Format(output, maxlen, "%T", "VoteTypeMission", LANG_SERVER);
		case ReturnToLobby: Format(output, maxlen, "%T", "VoteTypeLobby", LANG_SERVER);
		case ChangeChapter: Format(output, maxlen, "%T", "VoteTypeChapter", LANG_SERVER);
		case ChangeAllTalk: Format(output, maxlen, "%T", "VoteTypeAllTalk", LANG_SERVER);
		default: Format(output, maxlen, "%T", "VoteTypeUnknown", LANG_SERVER, view_as<int>(voteType));
	}
}
