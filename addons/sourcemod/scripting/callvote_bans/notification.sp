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
	PrintToConsole(target, "%T", "RestrictionDetailsHeader", target);
	PrintToConsole(target, "=====================================");
	PrintToConsole(target, "%T", "RestrictionDetailsTypes", target, banTypes);
	PrintToConsole(target, "%T", "RestrictionDetailsDuration", target, durationText);
	PrintToConsole(target, "%T", "RestrictionDetailsAdmin", target, adminIdentifier);

	if (durationMinutes > 0)
	{
		char expirationTime[64];
		int expiresTimestamp = GetTime() + (durationMinutes * 60);
		FormatTime(expirationTime, sizeof(expirationTime), "%Y-%m-%d %H:%M:%S", expiresTimestamp);
		PrintToConsole(target, "%T", "RestrictionDetailsExpiration", target, expirationTime);
	}

	PrintToConsole(target, "=====================================");
}

void NotifyPlayerRestrictionApplied(int target, int admin, const char[] adminIdentifier, const char[] banTypes, const char[] durationText, int durationMinutes)
{
	if (!IsValidClient(target))
		return;

	char resolvedAdminIdentifier[MAX_NAME_LENGTH];
	CVB_ResolveNotificationAdminIdentifier(admin, adminIdentifier, resolvedAdminIdentifier, sizeof(resolvedAdminIdentifier));

	CPrintToChat(target, "%t %t", "Tag", "PlayerRestrictionApplied");
	CPrintToChat(target, "%t %t", "Tag", "CheckConsoleForDetails");
	CVB_PrintBanApplicationDetails(target, resolvedAdminIdentifier, banTypes, durationText, durationMinutes);
}

static bool CVB_TryGetLocalizedVoteTypeName(TypeVotes voteType, int client, char[] output, int maxlen)
{
	return CallVoteLoc_GetVoteTypeLabel(voteType, client, g_loc, output, maxlen);
}

static bool CVB_ShouldUseSpanishFallback(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
	{
		return false;
	}

	return Lang_IsClientSpanish(client);
}

static void CVB_GetFallbackVoteTypeName(TypeVotes voteType, int client, char[] output, int maxlen)
{
	bool useSpanish = CVB_ShouldUseSpanishFallback(client);

	switch (voteType)
	{
		case ChangeDifficulty: strcopy(output, maxlen, useSpanish ? "Dificultad" : "Difficulty");
		case RestartGame: Format(output, maxlen, "%T", "VoteTypeRestart", client);
		case Kick: strcopy(output, maxlen, useSpanish ? "Expulsion" : "Kick");
		case ChangeMission: Format(output, maxlen, "%T", "VoteTypeMission", client);
		case ReturnToLobby: strcopy(output, maxlen, useSpanish ? "Volver al lobby" : "Return to Lobby");
		case ChangeChapter: strcopy(output, maxlen, useSpanish ? "Capitulo" : "Chapter");
		case ChangeAllTalk: strcopy(output, maxlen, "AllTalk");
		default: Format(output, maxlen, "%T", "VoteTypeUnknown", client, view_as<int>(voteType));
	}
}

static void CVB_GetVoteTypeName(TypeVotes voteType, int client, char[] output, int maxlen)
{
	if (CVB_TryGetLocalizedVoteTypeName(voteType, client, output, maxlen))
	{
		return;
	}

	CVB_GetFallbackVoteTypeName(voteType, client, output, maxlen);
}

static void CVB_AppendRestrictedVoteType(char[] output, int maxlen, TypeVotes voteType, int client)
{
	char voteTypeName[64];
	CVB_GetVoteTypeName(voteType, client, voteTypeName, sizeof(voteTypeName));

	if (output[0] != '\0')
	{
		StrCat(output, maxlen, ", ");
	}

	StrCat(output, maxlen, voteTypeName);
}

void ShowVoteBlockedMessage(int client, TypeVotes voteType)
{
	if (!IsValidClient(client))
		return;

	char voteTypeName[64];
	CVB_GetVoteTypeName(voteType, client, voteTypeName, sizeof(voteTypeName));

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

void ShowVoteBlockedValidationMessage(int client)
{
	if (!IsValidClient(client))
		return;

	CPrintToChat(client, "%t %t", "Tag", "VoteBlockedValidation");
	PrintToConsole(client, "========================================");
	PrintToConsole(client, "%T", "ConsoleVoteBlockedValidation", client);
	PrintToConsole(client, "========================================");
}

void ShowVoteBlockedDetailsInConsole(int client)
{
	if (g_ClientStates[client].loadState != ClientBanLoad_Ready)
		return;

	int banType = GetClientRestrictionMask(client);
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
	output[0] = '\0';

	if (banType & (1 << 0))
	{
		CVB_AppendRestrictedVoteType(output, maxlen, ChangeDifficulty, client);
	}

	if (banType & (1 << 1))
	{
		CVB_AppendRestrictedVoteType(output, maxlen, RestartGame, client);
	}

	if (banType & (1 << 2))
	{
		CVB_AppendRestrictedVoteType(output, maxlen, Kick, client);
	}

	if (banType & (1 << 3))
	{
		CVB_AppendRestrictedVoteType(output, maxlen, ChangeMission, client);
	}

	if (banType & (1 << 4))
	{
		CVB_AppendRestrictedVoteType(output, maxlen, ReturnToLobby, client);
	}

	if (banType & (1 << 5))
	{
		CVB_AppendRestrictedVoteType(output, maxlen, ChangeChapter, client);
	}

	if (banType & (1 << 6))
	{
		CVB_AppendRestrictedVoteType(output, maxlen, ChangeAllTalk, client);
	}
}
