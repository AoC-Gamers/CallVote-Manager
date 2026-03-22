VoteRestrictionType ValidateCallerState(int client, int &cooldownSeconds)
{
	cooldownSeconds = 0;

	if (L4D_GetClientTeam(client) == L4DTeam_Spectator)
		return VoteRestriction_ClientState;

	if (g_bBuiltinVotes && g_cvarBuiltinVote.BoolValue && !IsNewBuiltinVoteAllowed)
	{
		cooldownSeconds = CheckBuiltinVoteDelay();
		if (cooldownSeconds < 1)
			cooldownSeconds = 1;
		return VoteRestriction_Cooldown;
	}

	float sinceLastVote = GetEngineTime() - g_fLastVote;
	if (sinceLastVote <= 5.5)
	{
		cooldownSeconds = RoundFloat(5.5 - sinceLastVote);
		if (cooldownSeconds < 1)
			cooldownSeconds = 1;
		return VoteRestriction_Cooldown;
	}

	if (sv_vote_creation_timer != null && sinceLastVote <= sv_vote_creation_timer.FloatValue)
	{
		cooldownSeconds = RoundFloat(sv_vote_creation_timer.FloatValue - sinceLastVote);
		if (cooldownSeconds < 1)
			cooldownSeconds = 1;
		return VoteRestriction_Cooldown;
	}

	return VoteRestriction_None;
}

bool IsVoteAllowedByGameMode(TypeVotes voteType)
{
	int gameMode = L4D_GetGameModeType();

	switch (gameMode)
	{
		case GAMEMODE_COOP:
		{
			if (voteType == ChangeAllTalk || voteType == ChangeChapter)
				return false;
		}
		case GAMEMODE_VERSUS:
		{
			if (voteType == ChangeDifficulty || voteType == ChangeChapter)
				return false;
		}
		case GAMEMODE_SURVIVAL:
		{
			if (voteType == ChangeAllTalk || voteType == ChangeDifficulty || voteType == ChangeMission)
				return false;
		}
		case GAMEMODE_SCAVENGE:
		{
			if (voteType == ChangeDifficulty || voteType == ChangeMission || voteType == RestartGame)
				return false;
		}
	}

	return true;
}

bool IsVoteAllowedByConVar(TypeVotes voteType)
{
	switch (voteType)
	{
		case ChangeDifficulty:
			return sv_vote_issue_change_difficulty_allowed.BoolValue;

		case RestartGame:
			return sv_vote_issue_restart_game_allowed.BoolValue;

		case Kick:
			return sv_vote_issue_kick_allowed.BoolValue;

		case ChangeMission:
			return sv_vote_issue_change_mission_allowed.BoolValue;

		case ReturnToLobby:
			return g_cvarLobby.BoolValue;

		case ChangeChapter:
			return g_cvarChapter.BoolValue;

		case ChangeAllTalk:
			return g_cvarAllTalk.BoolValue;
	}

	return false;
}

VoteRestrictionType ValidateVote(int client, TypeVotes voteType, int target = 0, const char[] argument = "")
{
	if (!IsVoteAllowedByConVar(voteType))
	{
		return VoteRestriction_ConVar;
	}

	if (!IsVoteAllowedByGameMode(voteType))
	{
		return VoteRestriction_GameMode;
	}

	switch (voteType)
	{
		case ChangeDifficulty:
		{
			if (strlen(argument) > 0)
			{
				char sCVarDifficulty[32];
				z_difficulty.GetString(sCVarDifficulty, sizeof(sCVarDifficulty));

				if (StrEqual(argument, sCVarDifficulty, false))
				{
					return VoteRestriction_SameState;
				}
			}
		}

		case Kick:
		{
			if (target <= NO_INDEX)
				return VoteRestriction_Target;

			if (g_cvarSTVImmunity.BoolValue && IsClientConnected(target) && IsClientSourceTV(target))
			{
				return VoteRestriction_Immunity;
			}

			if (g_cvarBotImmunity.BoolValue && IsClientConnected(target) && IsFakeClient(target))
			{
				return VoteRestriction_Immunity;
			}

			if (g_cvarSelfImmunity.BoolValue && target == client)
			{
				return VoteRestriction_Immunity;
			}

			L4DTeam clientTeam = L4D_GetClientTeam(client);
			L4DTeam targetTeam = L4D_GetClientTeam(target);

			if (clientTeam != targetTeam)
			{
				return VoteRestriction_Team;
			}

			if (!CanKick(client) && IsAdmin(target))
			{
				return VoteRestriction_Immunity;
			}
		}
	}

	return VoteRestriction_None;
}

void SendRestrictionFeedback(int client, VoteRestrictionType restrictionType, TypeVotes voteType, int target = 0, int cooldownSeconds = 0)
{
	switch (restrictionType)
	{
		case VoteRestriction_ClientState:
		{
			CPrintToChat(client, "%t %t", "Tag", "SpecVote");
		}

		case VoteRestriction_Cooldown:
		{
			if (cooldownSeconds < 1)
				cooldownSeconds = 1;

			CPrintToChat(client, "%t %t", "Tag", "TryAgain", cooldownSeconds);
		}

		case VoteRestriction_ConVar:
		{
			char sTranslation[LC_MAX_TRANSLATION_LENGTH];

			if (Lang_GetValveTranslation(client, "#L4D_vote_server_disabled_issue", sTranslation, sizeof(sTranslation), g_loc))
			{
				CPrintToChat(client, "%t %s", "Tag", sTranslation);
				return;
			}

			CPrintToChat(client, "%t %t", "Tag", "VoteDisabled");
		}

		case VoteRestriction_GameMode:
		{
			CPrintToChat(client, "%t %t", "Tag", "VoteNotAllowedInGameMode");
		}

		case VoteRestriction_SameState:
		{
			switch (voteType)
			{
				case ChangeDifficulty:
					CPrintToChat(client, "%t %t", "Tag", "SameDifficulty");
			}
		}

		case VoteRestriction_Immunity:
		{
			switch (voteType)
			{
				case Kick:
				{
					if (target > 0)
					{
						if (IsClientSourceTV(target))
							CPrintToChat(client, "%t %t", "Tag", "SourceTVKick");
						else if (IsFakeClient(target))
							CPrintToChat(client, "%t %t", "Tag", "BotKick");
						else if (target == client)
							CPrintToChat(client, "%t %t", "Tag", "KickSelf");
						else if (IsAdmin(target))
						{
							CPrintToChat(client, "%t %t", "Tag", "Immunity");
							CPrintToChat(target, "%t %t", "Tag", "ImmunityTarget", client);
						}
					}
				}
			}
		}

		case VoteRestriction_Team:
		{
			if (voteType == Kick)
				CPrintToChat(client, "%t %t", "Tag", "KickDifferentTeam");
		}

		case VoteRestriction_Target:
		{
			if (voteType == Kick)
				CPrintToChat(client, "%t %t", "Tag", "InvalidTarget");
		}
	}
}
