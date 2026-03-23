#if defined _callvote_localizer_included
    #endinput
#endif
#define _callvote_localizer_included

#include <callvote_stock>
#include <language_manager>
#include <left4dhooks>

stock bool CallVoteLoc_GetVoteTypeValveKey(TypeVotes voteType, char[] key, int maxlen)
{
    switch (voteType)
    {
        case ChangeDifficulty:
        {
            strcopy(key, maxlen, "#GameUI_Difficulty");
            return true;
        }
        case Kick:
        {
            strcopy(key, maxlen, "#L4D360UI_Kick");
            return true;
        }
        case ReturnToLobby:
        {
            strcopy(key, maxlen, "#L4D360UI_ReturnToLobby");
            return true;
        }
        case ChangeChapter:
        {
            strcopy(key, maxlen, "#Valve_Chapter");
            return true;
        }
        case ChangeAllTalk:
        {
            strcopy(key, maxlen, "#L4D360UI_ChangeAllTalk");
            return true;
        }
    }

    key[0] = '\0';
    return false;
}

stock bool CallVoteLoc_GetVoteTypeLabel(TypeVotes voteType, int client, Localizer localizer, char[] output, int maxlen)
{
    if (localizer == null || !localizer.IsReady())
    {
        return false;
    }

    char key[64];
    if (!CallVoteLoc_GetVoteTypeValveKey(voteType, key, sizeof(key)))
    {
        return false;
    }

    return Lang_GetValveTranslation(client, key, output, maxlen, localizer);
}

stock bool CallVoteLoc_GetDifficultyKey(const char[] difficultyArg, char[] key, int maxlen)
{
    if (StrEqual(difficultyArg, "Easy", false))
    {
        strcopy(key, maxlen, "#L4D_DifficultyEasy");
        return true;
    }
    if (StrEqual(difficultyArg, "Normal", false))
    {
        strcopy(key, maxlen, "#L4D_DifficultyNormal");
        return true;
    }
    if (StrEqual(difficultyArg, "Hard", false))
    {
        strcopy(key, maxlen, "#L4D_DifficultyHard");
        return true;
    }
    if (StrEqual(difficultyArg, "Impossible", false))
    {
        strcopy(key, maxlen, "#L4D_DifficultyImpossible");
        return true;
    }

    key[0] = '\0';
    return false;
}

stock bool CallVoteLoc_GetDifficultyLabel(const char[] difficultyArg, int client, Localizer localizer, char[] output, int maxlen)
{
    if (localizer == null || !localizer.IsReady())
    {
        return false;
    }

    char key[64];
    if (!CallVoteLoc_GetDifficultyKey(difficultyArg, key, sizeof(key)))
    {
        return false;
    }

    return Lang_GetValveTranslation(client, key, output, maxlen, localizer);
}

stock bool CallVoteLoc_GetEnabledStateLabel(bool enabled, int client, Localizer localizer, char[] output, int maxlen)
{
    if (localizer == null || !localizer.IsReady())
    {
        return false;
    }

    char key[32];
    strcopy(key, sizeof(key), enabled ? "#GameUI_Enabled" : "#GameUI_Disabled");
    return Lang_GetValveTranslation(client, key, output, maxlen, localizer);
}

stock void CallVoteLoc_GetRestartKey(int gameMode, char[] key, int maxlen)
{
    switch (gameMode)
    {
        case GAMEMODE_COOP:
        {
            strcopy(key, maxlen, "#L4D360UI_RestartScenario");
        }
        case GAMEMODE_SURVIVAL:
        {
            strcopy(key, maxlen, "#L4D360UI_RestartChapter");
        }
        case GAMEMODE_VERSUS:
        {
            strcopy(key, maxlen, "#L4D360UI_VersusRestartLevel");
        }
        default:
        {
            strcopy(key, maxlen, "#L4D360UI_RestartScenario");
        }
    }
}

stock bool CallVoteLoc_GetRestartLabel(int gameMode, int client, Localizer localizer, char[] output, int maxlen)
{
    if (localizer == null || !localizer.IsReady())
    {
        return false;
    }

    char key[64];
    CallVoteLoc_GetRestartKey(gameMode, key, sizeof(key));
    return Lang_GetValveTranslation(client, key, output, maxlen, localizer);
}