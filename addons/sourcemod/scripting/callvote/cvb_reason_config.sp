#if defined _cvb_reason_config_included
	#endinput
#endif
#define _cvb_reason_config_included

enum struct BanReasonInfo
{
    int id;                     // Numeric ID (0-10)
    char code[64];              // Reason code (ex: REASON_SPAM_VOTES)
    char keywords[256];         // Keywords separated by ;
}

ArrayList g_BanReasons;          // List of loaded reasons
KeyValues g_ReasonConfig;        // KeyValues from configuration file

bool LoadBanReasonsConfig()
{
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/callvote_ban_reasons.cfg");
    
    CVBLog.Debug("LoadBanReasonsConfig called - config path: %s", configPath);
    
    if (!FileExists(configPath))
    {
        LogError("Configuration file not found: %s", configPath);
        CreateDefaultConfig(configPath);
        return false;
    }
    
    CVBLog.Debug("Configuration file exists, creating KeyValues...");
    
    g_ReasonConfig = new KeyValues("BanReasons");
    
    if (!g_ReasonConfig.ImportFromFile(configPath))
    {
        LogError("Failed to load ban reasons configuration from: %s", configPath);
        delete g_ReasonConfig;
        return false;
    }
    
    CVBLog.Debug("KeyValues imported successfully");
    
    // Leer ReasonsSize si existe
    int reasonsSize = g_ReasonConfig.GetNum("ReasonsSize", 0);
    if (reasonsSize > 0)
    {
        CVBLog.Debug("Configuration specifies %d reasons", reasonsSize);
    }
    
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
    
    if (!g_ReasonConfig.JumpToKey("Reasons", false))
    {
        LogError("No 'Reasons' section found in ban reasons configuration");
        return;
    }
    
    CVBLog.Debug("Successfully navigated to 'Reasons' section");
    
    if (!g_ReasonConfig.GotoFirstSubKey(false))
    {
        LogError("No reason entries found in configuration");
        g_ReasonConfig.GoBack();
        return;
    }
    
    CVBLog.Debug("Found reason entries, starting to load...");
    
    do
    {
        BanReasonInfo reason;
        char keyName[8];
        g_ReasonConfig.GetSectionName(keyName, sizeof(keyName));
        reason.id = StringToInt(keyName);
        
        CVBLog.Debug("Processing reason section '%s' (id: %d)", keyName, reason.id);

        g_ReasonConfig.GetString("code", reason.code, sizeof(reason.code));
        g_ReasonConfig.GetString("keywords", reason.keywords, sizeof(reason.keywords));
        
        CVBLog.Debug("Loaded reason %d: code='%s', keywords='%s'", reason.id, reason.code, reason.keywords);
        
        g_BanReasons.PushArray(reason);
        
    } while (g_ReasonConfig.GotoNextKey(false));
    
    g_ReasonConfig.GoBack();
    g_ReasonConfig.GoBack();
}

void CreateDefaultConfig(const char[] configPath)
{
    CVBLog.Debug("Creating default ban reasons configuration at: %s", configPath);
}

bool FindReasonCodeByKeywords(const char[] searchText, char[] output, int maxlen)
{
    CVBLog.Debug("FindReasonCodeByKeywords called with: '%s'", searchText);
    
    char searchLower[256];
    strcopy(searchLower, sizeof(searchLower), searchText);
    StringToLower(searchLower);
    CVBLog.Debug("Converted to lowercase: '%s'", searchLower);
    
    if (g_BanReasons == null)
    {
        CVBLog.Debug("g_BanReasons is null, using default");
        Format(output, maxlen, "#REASON_ADMIN_DECISION");
        return false;
    }
    
    CVBLog.Debug("Searching through %d ban reasons...", g_BanReasons.Length);
    
    for (int i = 0; i < g_BanReasons.Length; i++)
    {
        BanReasonInfo reason;
        g_BanReasons.GetArray(i, reason);
        
        char keywords[256];
        strcopy(keywords, sizeof(keywords), reason.keywords);
        StringToLower(keywords);
        
        CVBLog.Debug("Checking reason %d: code='%s', keywords='%s'", i, reason.code, keywords);
        
        char keywordList[16][32];
        int keywordCount = ExplodeString(keywords, ";", keywordList, sizeof(keywordList), sizeof(keywordList[]));
        
        for (int j = 0; j < keywordCount; j++)
        {
            CVBLog.Debug("  Checking keyword %d: '%s' in '%s'", j, keywordList[j], searchLower);
            if (StrContains(searchLower, keywordList[j]) != -1)
            {
                Format(output, maxlen, "#%s", reason.code);
                CVBLog.Debug("Found match! Returning: '%s'", output);
                return true;
            }
        }
    }
    
    // Default reason
    CVBLog.Debug("No match found, using default reason");
    Format(output, maxlen, "#REASON_ADMIN_DECISION");
    return false;
}

void StringToLower(char[] str)
{
    for (int i = 0; i < strlen(str); i++)
    {
        str[i] = CharToLower(str[i]);
    }
}

void CVB_GetBanReason(const char[] reasonString, char[] output, int maxlen)
{
    CVBLog.Debug("CVB_GetBanReason called with: '%s'", reasonString);
    FindReasonCodeByKeywords(reasonString, output, maxlen);
    CVBLog.Debug("CVB_GetBanReason result: '%s'", output);
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