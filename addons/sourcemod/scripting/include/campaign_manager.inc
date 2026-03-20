/**
 * Campaign Manager Library
 *
 * Dynamic campaign and chapter management system for Left 4 Dead 2
 * Provides localized campaign/chapter names, map code processing,
 * and Valve translation integration for missions and chapters.
 *
 * Author: lechuga
 * Version: 2.0.0
 *
 * Dependencies:
 * - language_manager.inc
 * - localizer.inc
 * - left4dhooks.inc
 *
 * Features:
 * - Dynamic campaign and chapter name resolution (no hardcoded data)
 * - Localized campaign/chapter name resolution via Valve translation keys
 * - Map code processing and validation with regex patterns
 * - Dynamic Valve translation key generation
 * - Game mode-aware chapter translation
 * - Automatic fallback for unknown campaigns/chapters
 * - Support for custom campaigns and community maps
 */

#if defined _campaign_manager_included
	#endinput
#endif
#define _campaign_manager_included

#include <language_manager>
#include <localizer>
#include <left4dhooks>

/*****************************************************************
			M A P   C O D E   P R O C E S S I N G
*****************************************************************/

/**
 * Map code processing constants
 */
#define MAX_MAP_CODE_LENGTH		32
#define MAX_CAMPAIGN_NAME_LENGTH 64
#define MAX_CHAPTER_NAME_LENGTH	128

/**
 * Common L4D2 map prefix that should be stripped
 */
#define MAP_PREFIX_L4D2 "L4D2"

/*****************************************************************
			S T O C K   F U N C T I O N S
*****************************************************************/

/**
 * Dynamically generates a campaign translation key from a campaign code
 *
 * @param campaignCode	Campaign code (e.g., "c1", "c5", "c10")
 * @param buffer		Output buffer for translation key
 * @param maxlength		Size of output buffer
 * @return				True if translation key was generated, false if invalid code
 */
stock bool Campaign_GenerateTranslationKey(const char[] campaignCode, char[] buffer, int maxlength)
{
	// Validate campaign code format (c + numbers)
	if (strlen(campaignCode) < 2 || (campaignCode[0] != 'c' && campaignCode[0] != 'C'))
	{
		buffer[0] = '\0';
		return false;
	}
	
	// Check if rest of string contains only numbers
	for (int i = 1; i < strlen(campaignCode); i++)
	{
		if (campaignCode[i] < '0' || campaignCode[i] > '9')
		{
			buffer[0] = '\0';
			return false;
		}
	}
	
	// Generate translation key in uppercase format
	char upperCode[16];
	strcopy(upperCode, sizeof(upperCode), campaignCode);
	StrUpper(upperCode);
	
	Format(buffer, maxlength, "#L4D360UI_CampaignName_%s", upperCode);
	return true;
}

/**
 * Gets a localized campaign name for a specific client using dynamic translation key generation
 *
 * @param campaignCode	Campaign code (e.g., "c1", "c5")
 * @param client		Client index for language detection
 * @param buffer		Output buffer for localized name
 * @param maxlength		Size of output buffer
 * @param localizer		Localizer instance for translations
 * @return				True if localized translation found, false if using fallback
 */
stock bool Campaign_GetLocalizedName(const char[] campaignCode, int client, char[] buffer, int maxlength, Localizer localizer = null)
{
	// Generate translation key dynamically
	char translationKey[64];
	if (!Campaign_GenerateTranslationKey(campaignCode, translationKey, sizeof(translationKey)))
	{
		// Invalid campaign code - use generic fallback
		strcopy(buffer, maxlength, "Unknown Campaign");
		return false;
	}
	
	// Try to get localized translation
	if (localizer != null && Lang_GetValveTranslation(client, translationKey, buffer, maxlength, localizer))
	{
		return true;
	}
	
	// Fallback to campaign code if no translation found
	strcopy(buffer, maxlength, campaignCode);
	return false;
}

/**
 * Removes common L4D2 prefixes from a map code
 * Examples: "L4D2C1" -> "C1", "l4d2c5m1" -> "c5m1"
 *
 * @param mapCode		Input map code
 * @param output		Output buffer for cleaned code
 * @param maxlength		Size of output buffer
 * @return				True if a prefix was removed, false otherwise
 */
stock bool Campaign_RemoveMapPrefix(const char[] mapCode, char[] output, int maxlength)
{
	strcopy(output, maxlength, mapCode);
	
	int len = strlen(mapCode);
	if (len < 3)
		return false;
	
	// Check for L4D2 prefix (case insensitive)
	int prefixLen = strlen(MAP_PREFIX_L4D2);
	if (len > prefixLen && strncmp(mapCode, MAP_PREFIX_L4D2, prefixLen, false) == 0)
	{
		strcopy(output, maxlength, mapCode[prefixLen]);
		return true;
	}
	
	return false;
}

/**
 * Extracts the campaign code from a full map code
 * Examples: "c1m1_hotel" -> "c1", "C5M4_quarter" -> "c5"
 *
 * @param mapCode		Input map code
 * @param campaignCode	Output buffer for campaign code
 * @param maxlength		Size of output buffer
 * @return				True if campaign code was extracted, false otherwise
 */
stock bool Campaign_ExtractCampaignCode(const char[] mapCode, char[] campaignCode, int maxlength)
{
	// First remove any L4D2 prefix
	char cleanCode[MAX_MAP_CODE_LENGTH];
	Campaign_RemoveMapPrefix(mapCode, cleanCode, sizeof(cleanCode));
	
	// Look for pattern: c[number]
	int len = strlen(cleanCode);
	if (len < 2)
		return false;
	
	// Must start with 'c' or 'C'
	if (cleanCode[0] != 'c' && cleanCode[0] != 'C')
		return false;
	
	// Find where the campaign number ends
	int endPos = 1;
	while (endPos < len && cleanCode[endPos] >= '0' && cleanCode[endPos] <= '9')
	{
		endPos++;
	}
	
	if (endPos == 1) // No number found after 'c'
		return false;
	
	// Extract campaign code
	strcopy(campaignCode, maxlength, cleanCode);
	campaignCode[endPos] = '\0';
	
	// Convert to lowercase for consistency
	for (int i = 0; i < endPos; i++)
	{
		if (campaignCode[i] >= 'A' && campaignCode[i] <= 'Z')
			campaignCode[i] = campaignCode[i] + ('a' - 'A');
	}
	
	return true;
}

/**
 * Extracts the full map code from a map name
 * Examples: "c1m1_hotel" -> "c1m1", "C5M4_quarter" -> "c5m4"
 *
 * @param mapName		Input map name
 * @param mapCode		Output buffer for map code
 * @param maxlength		Size of output buffer
 * @return				True if map code was extracted, false otherwise
 */
stock bool Campaign_ExtractMapCode(const char[] mapName, char[] mapCode, int maxlength)
{
	// First remove any L4D2 prefix
	char cleanName[MAX_MAP_CODE_LENGTH];
	Campaign_RemoveMapPrefix(mapName, cleanName, sizeof(cleanName));
	
	// Look for pattern: c[number]m[number]
	int len = strlen(cleanName);
	if (len < 4) // Minimum: c1m1
		return false;
	
	// Must start with 'c' or 'C'
	if (cleanName[0] != 'c' && cleanName[0] != 'C')
		return false;
	
	// Find where the map code ends
	int endPos = 1;
	bool foundM = false;
	
	// Skip campaign number
	while (endPos < len && cleanName[endPos] >= '0' && cleanName[endPos] <= '9')
	{
		endPos++;
	}
	
	// Check for 'm' or 'M'
	if (endPos < len && (cleanName[endPos] == 'm' || cleanName[endPos] == 'M'))
	{
		foundM = true;
		endPos++;
		
		// Skip map number
		while (endPos < len && cleanName[endPos] >= '0' && cleanName[endPos] <= '9')
		{
			endPos++;
		}
	}
	
	if (!foundM || endPos < 4) // Must have found 'm' and be at least 4 chars
		return false;
	
	// Extract map code
	strcopy(mapCode, maxlength, cleanName);
	mapCode[endPos] = '\0';
	
	// Convert to lowercase for consistency
	for (int i = 0; i < endPos; i++)
	{
		if (mapCode[i] >= 'A' && mapCode[i] <= 'Z')
			mapCode[i] = mapCode[i] + ('a' - 'A');
	}
	
	return true;
}

/**
 * Gets a localized campaign name from a map code for a specific client
 *
 * @param mapCode		Map code (e.g., "L4D2C1", "c5m1_hotel")
 * @param client		Client index for language detection
 * @param buffer		Output buffer for localized name
 * @param maxlength		Size of output buffer
 * @param localizer		Localizer instance for translations
 * @return				True if localized translation found, false if using fallback
 */
stock bool Campaign_GetLocalizedNameFromMapCode(const char[] mapCode, int client, char[] buffer, int maxlength, Localizer localizer = null)
{
	// Extract campaign code
	char campaignCode[8];
	if (!Campaign_ExtractCampaignCode(mapCode, campaignCode, sizeof(campaignCode)))
	{
		strcopy(buffer, maxlength, "Unknown Campaign");
		return false;
	}
	
	// Get localized name using dynamic translation key generation
	return Campaign_GetLocalizedName(campaignCode, client, buffer, maxlength, localizer);
}

/*****************************************************************
			C H A P T E R   M A N A G E M E N T
*****************************************************************/

/**
 * Chapter information structure for dynamic chapter handling
 */
enum struct ChapterInfo
{
	char mapCode[MAX_MAP_CODE_LENGTH];		// Full map code (e.g., "c1m1_hotel")
	char displayName[MAX_CHAPTER_NAME_LENGTH];	// Display name fallback
	char translationKey[64];				// Valve translation key
}

/**
 * Gets a localized chapter name from a map code
 *
 * @param mapCode		Full map code (e.g., "c1m1_hotel", "c5m4_quarter")
 * @param client		Client index for language detection
 * @param buffer		Output buffer for localized chapter name
 * @param maxlength		Size of output buffer
 * @param localizer		Localizer instance for translations
 * @return				True if localized translation found, false if using fallback
 */
stock bool Chapter_GetLocalizedName(const char[] mapCode, int client, char[] buffer, int maxlength, Localizer localizer = null)
{
	// Clean the map code first
	char cleanCode[MAX_MAP_CODE_LENGTH];
	Campaign_RemoveMapPrefix(mapCode, cleanCode, sizeof(cleanCode));
	
	// Get current game mode type as string
	char gameMode[32];
	strcopy(gameMode, sizeof(gameMode), Campaign_GetGameModeString(L4D_GetGameModeType()));
	
	// Build translation key for chapter with game mode
	char translationKey[64];
	Format(translationKey, sizeof(translationKey), "#L4D360UI_LevelName_%s_%s", gameMode, cleanCode);
	
	// Try to get localized translation
	if (localizer != null && Lang_GetValveTranslation(client, translationKey, buffer, maxlength, localizer))
	{
		return true;
	}
	
	// Fallback to map code as display name
	strcopy(buffer, maxlength, cleanCode);
	return false;
}

/**
 * Gets both campaign and chapter names for a complete map description
 *
 * @param mapCode		Full map code (e.g., "c1m1_hotel")
 * @param client		Client index for language detection
 * @param campaignOut	Output buffer for campaign name
 * @param campaignLen	Size of campaign buffer
 * @param chapterOut	Output buffer for chapter name
 * @param chapterLen	Size of chapter buffer
 * @param localizer		Localizer instance for translations
 * @return				True if both names were successfully retrieved
 */
stock bool Chapter_GetFullLocalizedName(const char[] mapCode, int client, 
										char[] campaignOut, int campaignLen,
										char[] chapterOut, int chapterLen,
										Localizer localizer = null)
{
	bool campaignSuccess = Campaign_GetLocalizedNameFromMapCode(mapCode, client, campaignOut, campaignLen, localizer);
	bool chapterSuccess = Chapter_GetLocalizedName(mapCode, client, chapterOut, chapterLen, localizer);
	
	return campaignSuccess && chapterSuccess;
}

/*****************************************************************
			U T I L I T Y   F U N C T I O N S
*****************************************************************/

/**
 * Converts game mode type from L4D_GetGameModeType() to string.
 *
 * @param modeType      Mode type returned by L4D_GetGameModeType()
 * @return              Game mode string for use in translation keys
 */
stock char[] Campaign_GetGameModeString(int modeType)
{
	char sMode[16];
	switch (modeType)
	{
		case GAMEMODE_COOP:     strcopy(sMode, sizeof(sMode), "COOP");
		case GAMEMODE_VERSUS:   strcopy(sMode, sizeof(sMode), "VERSUS");
		case GAMEMODE_SURVIVAL: strcopy(sMode, sizeof(sMode), "SURVIVAL");
		case GAMEMODE_SCAVENGE: strcopy(sMode, sizeof(sMode), "SCAVENGE");
		default:                strcopy(sMode, sizeof(sMode), "COOP");
	}
	return sMode;
}

/*****************************************************************
			D E B U G   F U N C T I O N S
*****************************************************************/

/**
 * Prints debug information about a map code for testing purposes
 *
 * @param mapCode		Map code to analyze
 * @param client		Client to test language detection with
 * @param localizer		Localizer instance for testing translations
 * @noreturn
 */
stock void Campaign_DebugMapCode(const char[] mapCode, int client = 0, Localizer localizer = null)
{
	PrintToServer("[Campaign_Debug] Analyzing map code: %s", mapCode);
	
	// Test prefix removal
	char cleanCode[MAX_MAP_CODE_LENGTH];
	bool prefixRemoved = Campaign_RemoveMapPrefix(mapCode, cleanCode, sizeof(cleanCode));
	PrintToServer("[Campaign_Debug] Clean code: %s (prefix removed: %s)", cleanCode, prefixRemoved ? "yes" : "no");
	
	// Test campaign extraction
	char campaignCode[8];
	bool campaignExtracted = Campaign_ExtractCampaignCode(mapCode, campaignCode, sizeof(campaignCode));
	PrintToServer("[Campaign_Debug] Campaign code: %s (extracted: %s)", campaignCode, campaignExtracted ? "yes" : "no");
	
	if (campaignExtracted)
	{
		// Generate and test translation key
		char translationKey[64];
		if (Campaign_GenerateTranslationKey(campaignCode, translationKey, sizeof(translationKey)))
		{
			PrintToServer("[Campaign_Debug] Translation key: %s", translationKey);
		}
	}
	
	// Test chapter translation
	char chapterTranslationKey[64];
	Format(chapterTranslationKey, sizeof(chapterTranslationKey), "#L4D360UI_LevelName_COOP_%s", cleanCode);
	PrintToServer("[Campaign_Debug] Chapter translation key: %s", chapterTranslationKey);
	
	// Test with client if provided
	if (client > 0 && IsClientInGame(client) && localizer != null)
	{
		char clientLang[32];
		Lang_GetSafeClientLanguage(client, clientLang, sizeof(clientLang));
		PrintToServer("[Campaign_Debug] Testing with client %N (language: %s)", client, clientLang);
		
		char localizedCampaign[MAX_CAMPAIGN_NAME_LENGTH];
		char localizedChapter[MAX_CHAPTER_NAME_LENGTH];
		
		bool success = Chapter_GetFullLocalizedName(mapCode, client, 
													localizedCampaign, sizeof(localizedCampaign),
													localizedChapter, sizeof(localizedChapter),
													localizer);
		
		PrintToServer("[Campaign_Debug] Localized result (success: %s):", success ? "yes" : "no");
		PrintToServer("[Campaign_Debug] - Campaign: %s", localizedCampaign);
		PrintToServer("[Campaign_Debug] - Chapter: %s", localizedChapter);
	}
}

/**
 * Converts all characters in a string to uppercase
 *
 * @param str		The string to convert (modified in-place)
 * @noreturn
 */
stock void StrUpper(char[] str)
{
	for (int i = 0; str[i] != '\0'; i++)
	{
		if (str[i] >= 'a' && str[i] <= 'z')
			str[i] = str[i] - ('a' - 'A');
	}
}
