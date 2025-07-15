#if defined _cvb_reason_config_included
	#endinput
#endif
#define _cvb_reason_config_included

enum struct BanReasonInfo
{
    int code;                    // Numeric code
    char name[64];              // Internal name (ex: REASON_SPAM_VOTES)
    char translation[64];       // Translation key
    char keywords[256];         // Keywords separated by ;
    int severity;               // Severity level (1-8)
    char description[128];      // Description in English
}

ArrayList g_BanReasons;          // List of loaded reasons
KeyValues g_ReasonConfig;        // KeyValues from configuration file
int g_DefaultReasonCode = 8;     // Default reason

bool LoadBanReasonsConfig()
{
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/callvote_ban_reasons.cfg");
    
    if (!FileExists(configPath))
    {
        LogError("Configuration file not found: %s", configPath);
        CreateDefaultConfig(configPath);
        return false;
    }
    
    g_ReasonConfig = new KeyValues("BanReasons");
    
    if (!g_ReasonConfig.ImportFromFile(configPath))
    {
        LogError("Failed to load ban reasons configuration from: %s", configPath);
        delete g_ReasonConfig;
        return false;
    }
    
    g_ReasonConfig.JumpToKey("settings", false);
    g_DefaultReasonCode = g_ReasonConfig.GetNum("default_reason", 8);

    g_ReasonConfig.GoBack();
    
    LoadBanReasons();
    CVBLog.Debug("Loaded %d ban reasons from configuration", g_BanReasons.Length);
    return true;
}

bool InitializeMessageCodeSystem()
{
    LoadTranslations("callvote_bans_reason.phrases");
    
    int reasonCount = 0;
    if (!LoadBanReasonsConfig())
    {
        LogError("Error loading ban reasons configuration");
        return false;
    }
    else
    {
        reasonCount = GetBanReasonCount();
    }
    
    Call_StartForward(g_gfOnBanReasonsLoaded);
    Call_PushCell(reasonCount);
    Call_Finish();
    
    LogMessage("Message code system initialized successfully with %d ban reasons", reasonCount);
    return true;
}

void LoadBanReasons()
{
    if (g_BanReasons != null)
    {
        delete g_BanReasons;
    }
    
    g_BanReasons = new ArrayList(sizeof(BanReasonInfo));
    
    if (!g_ReasonConfig.JumpToKey("reasons", false))
    {
        LogError("No 'reasons' section found in ban reasons configuration");
        return;
    }
    
    if (!g_ReasonConfig.GotoFirstSubKey(false))
    {
        LogError("No reason entries found in configuration");
        g_ReasonConfig.GoBack();
        return;
    }
    
    do
    {
        BanReasonInfo reason;
        char keyName[8];
        g_ReasonConfig.GetSectionName(keyName, sizeof(keyName));
        reason.code = StringToInt(keyName);

        g_ReasonConfig.GetString("name", reason.name, sizeof(reason.name));
        g_ReasonConfig.GetString("translation", reason.translation, sizeof(reason.translation));
        g_ReasonConfig.GetString("keywords", reason.keywords, sizeof(reason.keywords));
        g_ReasonConfig.GetString("description", reason.description, sizeof(reason.description));
        reason.severity = g_ReasonConfig.GetNum("severity", 1);
        
        g_BanReasons.PushArray(reason);
        
    } while (g_ReasonConfig.GotoNextKey(false));
    
    g_ReasonConfig.GoBack();
    g_ReasonConfig.GoBack();
    
    FireOnBanReasonsLoaded(g_BanReasons.Length);
}

void CreateDefaultConfig(const char[] configPath)
{
    CVBLog.Debug("Creating default ban reasons configuration at: %s", configPath);
}

bool GetBanReasonByCode(int code, BanReasonInfo reason)
{
    for (int i = 0; i < g_BanReasons.Length; i++)
    {
        BanReasonInfo temp;
        g_BanReasons.GetArray(i, temp);
        
        if (temp.code == code)
        {
            reason = temp;
            return true;
        }
    }
    
    return false;
}

int FindReasonByKeywords(const char[] searchText)
{
    char searchLower[256];
    strcopy(searchLower, sizeof(searchLower), searchText);
    StringToLower(searchLower);
    
    for (int i = 0; i < g_BanReasons.Length; i++)
    {
        BanReasonInfo reason;
        g_BanReasons.GetArray(i, reason);
        
        char keywords[256];
        strcopy(keywords, sizeof(keywords), reason.keywords);
        StringToLower(keywords);
        
        char keywordList[16][32];
        int keywordCount = ExplodeString(keywords, ";", keywordList, sizeof(keywordList), sizeof(keywordList[]));
        
        for (int j = 0; j < keywordCount; j++)
        {
            if (StrContains(searchLower, keywordList[j]) != -1)
            {
                return reason.code;
            }
        }
    }
    
    return g_DefaultReasonCode;
}

void GetBanReasonString_FromConfig(int reasonCode, int client, char[] output, int maxlen)
{
    BanReasonInfo reason;
    if (GetBanReasonByCode(reasonCode, reason))
    {
        Format(output, maxlen, "%T", reason.translation, client);
    }
    else
    {
        Format(output, maxlen, "%T", "REASON_UNKNOWN", client);
    }
}

void StringToLower(char[] str)
{
    for (int i = 0; i < strlen(str); i++)
    {
        str[i] = CharToLower(str[i]);
    }
}

int GetBanReasonFromString_Enhanced(const char[] reasonString)
{
    return FindReasonByKeywords(reasonString);
}

int GetReasonIdFromConfig(const char[] reasonText)
{
    if (reasonText[0] == '\0')
    {
        return g_DefaultReasonCode;
    }
    
    char searchLower[256];
    strcopy(searchLower, sizeof(searchLower), reasonText);
    StringToLower(searchLower);
    
    for (int i = 0; i < g_BanReasons.Length; i++)
    {
        BanReasonInfo reason;
        g_BanReasons.GetArray(i, reason);
        
        char nameLower[64];
        strcopy(nameLower, sizeof(nameLower), reason.name);
        StringToLower(nameLower);
        
        if (StrEqual(searchLower, nameLower))
        {
            return reason.code;
        }
    }
    
    int keywordMatch = FindReasonByKeywords(reasonText);
    if (keywordMatch != g_DefaultReasonCode)
    {
        return keywordMatch;
    }
    
    for (int i = 0; i < g_BanReasons.Length; i++)
    {
        BanReasonInfo reason;
        g_BanReasons.GetArray(i, reason);
        
        char descLower[128];
        strcopy(descLower, sizeof(descLower), reason.description);
        StringToLower(descLower);
        
        if (StrContains(descLower, searchLower) != -1)
        {
            return reason.code;
        }
    }
    
    return g_DefaultReasonCode;
}

/**
 * Retrieves the description text for a given reason code.
 *
 * @param reasonCode    The integer code representing the reason.
 * @param output        The buffer to store the resulting reason description.
 * @param maxlen        The maximum length of the output buffer.
 *
 * If the reason code is found, the corresponding description is copied to the output buffer.
 * If not found, "Unknown reason" is copied instead.
 */
void GetReasonTextByCode(int reasonCode, char[] output, int maxlen)
{
    BanReasonInfo reason;
    if (GetBanReasonByCode(reasonCode, reason))
    {
        strcopy(output, maxlen, reason.description);
    }
    else
    {
        strcopy(output, maxlen, "Unknown reason");
    }
}

void CleanupBanReasons()
{
    if (g_BanReasons != null)
    {
        delete g_BanReasons;
        g_BanReasons = null;
    }
    
    if (g_ReasonConfig != null)
    {
        delete g_ReasonConfig;
        g_ReasonConfig = null;
    }
}

int GetBanReasonCount()
{
    return (g_BanReasons != null) ? g_BanReasons.Length : 0;
}

bool IsVoteTypeBanned(int banType, TypeVotes voteType)
{
	if (banType == 0)
	{
		return false;
	}

	int voteFlag;
	switch (voteType)
	{
		case ChangeDifficulty: voteFlag = view_as<int>(VOTE_CHANGEDIFFICULTY);
		case RestartGame: voteFlag = view_as<int>(VOTE_RESTARTGAME);
		case Kick: voteFlag = view_as<int>(VOTE_KICK);
		case ChangeMission: voteFlag = view_as<int>(VOTE_CHANGEMISSION);
		case ReturnToLobby: voteFlag = view_as<int>(VOTE_RETURNTOLOBBY);
		case ChangeChapter: voteFlag = view_as<int>(VOTE_CHANGECHAPTER);
		case ChangeAllTalk: voteFlag = view_as<int>(VOTE_CHANGEALLTALK);
		default: return false;
	}

	return (banType & voteFlag) != 0;
}