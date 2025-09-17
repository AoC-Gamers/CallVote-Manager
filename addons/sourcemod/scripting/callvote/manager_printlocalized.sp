/*****************************************************************
			P R I N T   L O C A L I Z E D   F U N C T I O N S
*****************************************************************/

/**
 * Imprime el nombre localizado de una misión (campaign) para ChangeMission.
 *
 * @param sMissionCode    Ej: L4D2C2
 * @param iAnnouncer      Cliente que originó la votación
 * @noreturn
 */
void PrintLocalizedMissionName(const char[] sMissionCode, int iAnnouncer)
{
	if (!g_cvarAnnouncer.BoolValue)
		return;

	char sChapter[8];
	Campaign_RemoveMapPrefix(sMissionCode, sChapter, sizeof(sChapter));

	char sKey[64];
	Format(sKey, sizeof(sKey), "#L4D360UI_CampaignName_%s", sChapter);

	bool bFound = false;
	CVLog.Debug("[PrintLocalizedMissionName] Mission: %s | Chapter: %s | Key: %s", sMissionCode, sChapter, sKey);

	if (g_loc != null && g_loc.IsReady())
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			char sTranslation[LC_MAX_TRANSLATION_LENGTH];

			if (Lang_GetValveTranslation(i, sKey, sTranslation, sizeof(sTranslation), g_loc))
			{
				CPrintToChat(i, "%t %t", "Tag", "ChangeMission", iAnnouncer, sTranslation);
				bFound = true;
				CVLog.Debug("[PrintLocalizedMissionName] Sent localized message to %N: %s", i, sTranslation);
			}
			else
			{
				CVLog.Debug("[PrintLocalizedMissionName] No translation found for %s for client %N", sKey, i);
			}
		}
	}
	else
	{
		CVLog.Debug("[PrintLocalizedMissionName] Localizer not ready or null");
	}

	if (!bFound)
	{
		CVLog.Debug("[PrintLocalizedMissionName] Using fallback mission name: %s", sMissionCode);
		CPrintToChatAll("%t %t", "Tag", "ChangeMission", iAnnouncer, sMissionCode);
	}
}

/**
 * Imprime el nombre localizado de un capítulo/mapa para ChangeChapter.
 *
 * @param sMapName       Nombre del mapa, ej: "c1m1_hotel"
 * @param iAnnouncer     Cliente que originó la votación
 * @noreturn
 */
void PrintLocalizedChapterName(const char[] sMapName, int iAnnouncer)
{
	if (!g_cvarAnnouncer.BoolValue)
		return;

	char sMapCode[16];
	if (!Campaign_ExtractMapCode(sMapName, sMapCode, sizeof(sMapCode)))
	{
		CVLog.Debug("[PrintLocalizedChapterName] Could not extract map code from: %s", sMapName);
		CPrintToChatAll("%t %t", "Tag", "ChangeChapter", iAnnouncer, sMapName);
		return;
	}

	StrUpper(sMapCode);
	int	 gameMode = L4D_GetGameModeType();
	char sModeString[16];
	strcopy(sModeString, sizeof(sModeString), Campaign_GetGameModeString(gameMode));

	bool bFound = false;
	CVLog.Debug("[PrintLocalizedChapterName] Map: %s | Code: %s | Mode: %s (%d)", sMapName, sMapCode, sModeString, gameMode);

	if (g_loc != null && g_loc.IsReady())
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			char sChapterTranslation[LC_MAX_TRANSLATION_LENGTH];
			char sCampaignTranslation[LC_MAX_TRANSLATION_LENGTH];

			bool bFoundChapter	= Chapter_GetLocalizedName(sMapCode, i, sChapterTranslation, sizeof(sChapterTranslation), g_loc);
			bool bFoundCampaign = Campaign_GetLocalizedNameFromMapCode(sMapCode, i, sCampaignTranslation, sizeof(sCampaignTranslation), g_loc);

			if (bFoundChapter)
			{
				char sFullName[256];
				if (bFoundCampaign)
				{
					Format(sFullName, sizeof(sFullName), "%s - %s", sCampaignTranslation, sChapterTranslation);
				}
				else
				{
					strcopy(sFullName, sizeof(sFullName), sChapterTranslation);
				}

				CPrintToChat(i, "%t %t", "Tag", "ChangeChapter", iAnnouncer, sFullName);
				bFound = true;
				CVLog.Debug("[PrintLocalizedChapterName] Sent localized message to %N: %s", i, sFullName);
			}
			else
			{
				CVLog.Debug("[PrintLocalizedChapterName] No translation found for %s for client %N", sMapCode, i);
			}
		}
	}
	else
	{
		CVLog.Debug("[PrintLocalizedChapterName] Localizer not ready or null");
	}

	if (!bFound)
	{
		CVLog.Debug("[PrintLocalizedChapterName] Using fallback chapter name: %s", sMapName);
		CPrintToChatAll("%t %t", "Tag", "ChangeChapter", iAnnouncer, sMapName);
	}
}

/**
 * Imprime el nombre localizado para el voto de AllTalk.
 *
 * @param iAnnouncer     Cliente que originó la votación
 * @noreturn
 */
void PrintLocalizedAllTalk(int iAnnouncer)
{
	if (!g_cvarAnnouncer.BoolValue)
		return;

	ConVar cvAllTalk	   = FindConVar("sv_alltalk");
	bool   bCurrentAllTalk = false;
	if (cvAllTalk != null)
	{
		bCurrentAllTalk = cvAllTalk.BoolValue;
	}

	bool bNewState = !bCurrentAllTalk;

	bool bFound	   = false;
	CVLog.Debug("[PrintLocalizedAllTalk] Current AllTalk: %s | New State: %s",
			 bCurrentAllTalk ? "true" : "false", bNewState ? "true" : "false");

	if (g_loc != null && g_loc.IsReady())
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			char sAllTalkTranslation[LC_MAX_TRANSLATION_LENGTH];
			char sStateTranslation[LC_MAX_TRANSLATION_LENGTH];

			if (!Lang_GetValveTranslation(i, "#L4D360UI_ChangeAllTalk", sAllTalkTranslation, sizeof(sAllTalkTranslation), g_loc))
			{
				strcopy(sAllTalkTranslation, sizeof(sAllTalkTranslation), "change AllTalk");
			}

			char sStateKey[32];
			strcopy(sStateKey, sizeof(sStateKey), bNewState ? "#GameUI_Enabled" : "#GameUI_Disabled");

			if (!Lang_GetValveTranslation(i, sStateKey, sStateTranslation, sizeof(sStateTranslation), g_loc))
			{
				strcopy(sStateTranslation, sizeof(sStateTranslation), bNewState ? "Enabled" : "Disabled");
			}

			CPrintToChat(i, "%t %t", "Tag", "ChangeAllTalk", iAnnouncer, sAllTalkTranslation, sStateTranslation);
			bFound = true;

			char clientLang[32];
			Lang_GetSafeClientLanguage(i, clientLang, sizeof(clientLang));
			CVLog.Debug("[PrintLocalizedAllTalk] Sent localized message to %N (%s): %s -> %s",
					 i, clientLang, sAllTalkTranslation, sStateTranslation);
		}
	}
	else
	{
		CVLog.Debug("[PrintLocalizedAllTalk] Localizer not ready or null");
	}

	if (!bFound)
	{
		CVLog.Debug("[PrintLocalizedAllTalk] Using fallback AllTalk message");
		CPrintToChatAll("%t %t", "Tag", "ChangeAllTalk", iAnnouncer, "change AllTalk", bNewState ? "Enabled" : "Disabled");
	}
}

/**
 * Imprime el nombre localizado para el voto de cambio de dificultad.
 *
 * @param sDifficultyArg    Argumento de dificultad del voto (Easy, Normal, Hard, Impossible)
 * @param iAnnouncer        Cliente que originó la votación
 * @noreturn
 */
void PrintLocalizedDifficulty(const char[] sDifficultyArg, int iAnnouncer)
{
	if (!g_cvarAnnouncer.BoolValue)
		return;

	char sKey[64];
	if (StrEqual(sDifficultyArg, "Easy", false))
		strcopy(sKey, sizeof(sKey), "#L4D_DifficultyEasy");
	else if (StrEqual(sDifficultyArg, "Normal", false))
		strcopy(sKey, sizeof(sKey), "#L4D_DifficultyNormal");
	else if (StrEqual(sDifficultyArg, "Hard", false))
		strcopy(sKey, sizeof(sKey), "#L4D_DifficultyHard");
	else if (StrEqual(sDifficultyArg, "Impossible", false))
		strcopy(sKey, sizeof(sKey), "#L4D_DifficultyImpossible");
	else
	{
		CVLog.Debug("[PrintLocalizedDifficulty] Unknown difficulty argument: %s", sDifficultyArg);
		return;
	}

	bool bFound = false;
	CVLog.Debug("[PrintLocalizedDifficulty] Difficulty: %s | Key: %s", sDifficultyArg, sKey);

	if (g_loc != null && g_loc.IsReady())
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			char sDifficultyTranslation[LC_MAX_TRANSLATION_LENGTH];

			if (!Lang_GetValveTranslation(i, sKey, sDifficultyTranslation, sizeof(sDifficultyTranslation), g_loc))
			{
				strcopy(sDifficultyTranslation, sizeof(sDifficultyTranslation), sDifficultyArg);
			}

			CPrintToChat(i, "%t %t", "Tag", "ChangeDifficulty", iAnnouncer, sDifficultyTranslation);
			bFound = true;

			char clientLang[32];
			Lang_GetSafeClientLanguage(i, clientLang, sizeof(clientLang));
			CVLog.Debug("[PrintLocalizedDifficulty] Sent localized message to %N (%s): %s",
					 i, clientLang, sDifficultyTranslation);
		}
	}
	else
	{
		CVLog.Debug("[PrintLocalizedDifficulty] Localizer not ready or null");
	}

	if (!bFound)
	{
		CVLog.Debug("[PrintLocalizedDifficulty] Using fallback difficulty message");
		CPrintToChatAll("%t %t", "Tag", "ChangeDifficulty", iAnnouncer, sDifficultyArg);
	}
}

/**
 * Imprime el nombre localizado para el voto de kick.
 *
 * @param iAnnouncer     Cliente que originó la votación
 * @param iTarget        Cliente objetivo del kick
 * @noreturn
 */
void PrintLocalizedKick(int iAnnouncer, int iTarget)
{
	if (!g_cvarAnnouncer.BoolValue)
		return;

	bool bFound = false;
	CVLog.Debug("[PrintLocalizedKick] Announcer: %N | Target: %N", iAnnouncer, iTarget);

	if (g_loc != null && g_loc.IsReady())
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			char sKickTranslation[LC_MAX_TRANSLATION_LENGTH];

			if (!Lang_GetValveTranslation(i, "#L4D360UI_Kick", sKickTranslation, sizeof(sKickTranslation), g_loc))
			{
				strcopy(sKickTranslation, sizeof(sKickTranslation), "kick");
			}

			CPrintToChat(i, "%t {green}%N{default} called vote to {olive}%s{default} {red}%N{default}",
						 "Tag", iAnnouncer, sKickTranslation, iTarget);
			bFound = true;

			char clientLang[32];
			Lang_GetSafeClientLanguage(i, clientLang, sizeof(clientLang));
			CVLog.Debug("[PrintLocalizedKick] Sent localized message to %N (%s): %s",
					 i, clientLang, sKickTranslation);
		}
	}
	else
	{
		CVLog.Debug("[PrintLocalizedKick] Localizer not ready or null");
	}

	if (!bFound)
	{
		CVLog.Debug("[PrintLocalizedKick] Using fallback kick message");
		CPrintToChatAll("%t {green}%N{default} called vote to {olive}kick{default} {red}%N{default}",
						"Tag", iAnnouncer, iTarget);
	}
}

/**
 * Imprime el nombre localizado para el voto de restart game.
 *
 * @param iAnnouncer     Cliente que originó la votación
 * @noreturn
 */
void PrintLocalizedRestartGame(int iAnnouncer)
{
	if (!g_cvarAnnouncer.BoolValue)
		return;

	int	 gameMode = L4D_GetGameModeType();
	char sKey[64];
	char sFallbackText[64];

	switch (gameMode)
	{
		case GAMEMODE_COOP:
		{
			strcopy(sKey, sizeof(sKey), "#L4D360UI_RestartScenario");
			strcopy(sFallbackText, sizeof(sFallbackText), "restart campaign");
		}
		case GAMEMODE_SURVIVAL:
		{
			strcopy(sKey, sizeof(sKey), "#L4D360UI_RestartChapter");
			strcopy(sFallbackText, sizeof(sFallbackText), "restart round");
		}
		case GAMEMODE_VERSUS:
		{
			strcopy(sKey, sizeof(sKey), "#L4D360UI_VersusRestartLevel");
			strcopy(sFallbackText, sizeof(sFallbackText), "restart chapter");
		}
		default:
		{
			strcopy(sKey, sizeof(sKey), "#L4D360UI_RestartScenario");
			strcopy(sFallbackText, sizeof(sFallbackText), "restart game");
		}
	}

	bool bFound = false;
	CVLog.Debug("[PrintLocalizedRestartGame] Announcer: %N | GameMode: %d | Key: %s",
			 iAnnouncer, gameMode, sKey);

	if (g_loc != null && g_loc.IsReady())
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			char sRestartTranslation[LC_MAX_TRANSLATION_LENGTH];

			if (!Lang_GetValveTranslation(i, sKey, sRestartTranslation, sizeof(sRestartTranslation), g_loc))
			{
				strcopy(sRestartTranslation, sizeof(sRestartTranslation), sFallbackText);
			}

			CPrintToChat(i, "%t {green}%N{default} called vote for {olive}%s{default}",
						 "Tag", iAnnouncer, sRestartTranslation);
			bFound = true;

			char clientLang[32];
			Lang_GetSafeClientLanguage(i, clientLang, sizeof(clientLang));
			CVLog.Debug("[PrintLocalizedRestartGame] Sent localized message to %N (%s): %s",
					 i, clientLang, sRestartTranslation);
		}
	}
	else
	{
		CVLog.Debug("[PrintLocalizedRestartGame] Localizer not ready or null");
	}

	if (!bFound)
	{
		CVLog.Debug("[PrintLocalizedRestartGame] Using fallback restart message");
		CPrintToChatAll("%t {green}%N{default} called vote for {olive}%s{default}",
						"Tag", iAnnouncer, sFallbackText);
	}
}

/**
 * Imprime el nombre localizado para el voto de ReturnToLobby.
 *
 * @param iAnnouncer     Cliente que originó la votación
 * @noreturn
 */
void PrintLocalizedReturnToLobby(int iAnnouncer)
{
	if (!g_cvarAnnouncer.BoolValue)
		return;

	bool bFound = false;
	CVLog.Debug("[PrintLocalizedReturnToLobby] Announcer: %N", iAnnouncer);

	if (g_loc != null && g_loc.IsReady())
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			char sLobbyTranslation[LC_MAX_TRANSLATION_LENGTH];

			if (!Lang_GetValveTranslation(i, "#L4D360UI_ReturnToLobby", sLobbyTranslation, sizeof(sLobbyTranslation), g_loc))
			{
				strcopy(sLobbyTranslation, sizeof(sLobbyTranslation), "return to lobby");
			}

			CPrintToChat(i, "%t {green}%N{default} called vote to {olive}%s{default}",
						 "Tag", iAnnouncer, sLobbyTranslation);
			bFound = true;

			char clientLang[32];
			Lang_GetSafeClientLanguage(i, clientLang, sizeof(clientLang));
			CVLog.Debug("[PrintLocalizedReturnToLobby] Sent localized message to %N (%s): %s",
					 i, clientLang, sLobbyTranslation);
		}
	}
	else
	{
		CVLog.Debug("[PrintLocalizedReturnToLobby] Localizer not ready or null");
	}

	if (!bFound)
	{
		CVLog.Debug("[PrintLocalizedReturnToLobby] Using fallback lobby message");
		CPrintToChatAll("%t {green}%N{default} called vote to {olive}return to lobby{default}",
						"Tag", iAnnouncer);
	}
}
