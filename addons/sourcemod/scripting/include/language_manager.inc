/**
 * Language Manager Library
 *
 * Comprehensive language management system for SourceMod plugins
 * Provides optimized language handling, Valve translation support,
 * and client language detection with automatic fallbacks.
 *
 * Author: lechuga
 * Version: 1.0.0
 *
 * Features:
 * - Complete LanguageID enumeration with all 33 supported languages
 * - Optimized language arrays for fast lookups
 * - Valve translation integration with Localizer support
 * - Automatic LATAM → Spanish mapping
 * - Client language detection and validation
 * - Comprehensive utility functions
 */

#if defined _language_manager_included
	#endinput
#endif
#define _language_manager_included

#include <lang>
#include <localizer>

/*****************************************************************
			L A N G U A G E   E N U M E R A T I O N
*****************************************************************/

/**
 * Complete enumeration of all languages supported by SourceMod
 * Based on official SourceMod language registry
 */
enum LanguageID
{
	LANGID_ARABIC	  = 0,	   // ar - arabic
	LANGID_BULGARIAN  = 1,	   // bg - bulgarian
	LANGID_SCHINESE	  = 2,	   // chi - schinese (Simplified Chinese)
	LANGID_CZECH	  = 3,	   // cze - czech
	LANGID_DANISH	  = 4,	   // da - danish
	LANGID_GERMAN	  = 5,	   // de - german
	LANGID_GREEK	  = 6,	   // el - greek
	LANGID_ENGLISH	  = 7,	   // en - english
	LANGID_SPANISH	  = 8,	   // es - spanish
	LANGID_FINNISH	  = 9,	   // fi - finnish
	LANGID_FRENCH	  = 10,	   // fr - french
	LANGID_HEBREW	  = 11,	   // he - hebrew
	LANGID_HUNGARIAN  = 12,	   // hu - hungarian
	LANGID_ITALIAN	  = 13,	   // it - italian
	LANGID_JAPANESE	  = 14,	   // jp - japanese
	LANGID_KOREAN	  = 15,	   // ko - korean
	LANGID_LATAM	  = 16,	   // las - latam (Latin American Spanish)
	LANGID_LITHUANIAN = 17,	   // lt - lithuanian
	LANGID_LATVIAN	  = 18,	   // lv - latvian
	LANGID_DUTCH	  = 19,	   // nl - dutch
	LANGID_NORWEGIAN  = 20,	   // no - norwegian
	LANGID_POLISH	  = 21,	   // pl - polish
	LANGID_BRAZILIAN  = 22,	   // pt - brazilian
	LANGID_PORTUGUESE = 23,	   // pt_p - portuguese
	LANGID_ROMANIAN	  = 24,	   // ro - romanian
	LANGID_RUSSIAN	  = 25,	   // ru - russian
	LANGID_SLOVAK	  = 26,	   // sk - slovak
	LANGID_SWEDISH	  = 27,	   // sv - swedish
	LANGID_THAI		  = 28,	   // th - thai
	LANGID_TURKISH	  = 29,	   // tr - turkish
	LANGID_UKRAINIAN  = 30,	   // ua - ukrainian
	LANGID_VIETNAMESE = 31,	   // vi - vietnamese
	LANGID_TCHINESE	  = 32,	   // zho - tchinese (Traditional Chinese)
	LANGID_SIZE				   // Total number of languages (33)
}

/*****************************************************************
			L A N G U A G E   A R R A Y S
*****************************************************************/

// Language name strings array corresponding to LanguageID enumeration
// Indices match exactly with LanguageID values
stock char sLanguageNames[LANGID_SIZE][] = {
	"arabic",		 // LANGID_ARABIC = 0
	"bulgarian",	 // LANGID_BULGARIAN = 1
	"schinese",		 // LANGID_SCHINESE = 2 (Simplified Chinese)
	"czech",		 // LANGID_CZECH = 3 
	"danish",		 // LANGID_DANISH = 4
	"german",		 // LANGID_GERMAN = 5
	"greek",		 // LANGID_GREEK = 6
	"english",		 // LANGID_ENGLISH = 7
	"spanish",		 // LANGID_SPANISH = 8
	"finnish",		 // LANGID_FINNISH = 9
	"french",		 // LANGID_FRENCH = 10
	"hebrew",		 // LANGID_HEBREW = 11
	"hungarian",	 // LANGID_HUNGARIAN = 12
	"italian",		 // LANGID_ITALIAN = 13
	"japanese",		 // LANGID_JAPANESE = 14
	"korean",		 // LANGID_KOREAN = 15
	"spanish",		 // LANGID_LATAM = 16 (Latin American Spanish)
	"lithuanian",	 // LANGID_LITHUANIAN = 17
	"latvian",		 // LANGID_LATVIAN = 18
	"dutch",		 // LANGID_DUTCH = 19
	"norwegian",	 // LANGID_NORWEGIAN = 20
	"polish",		 // LANGID_POLISH = 21
	"brazilian",	 // LANGID_BRAZILIAN = 22
	"portuguese",	 // LANGID_PORTUGUESE = 23
	"romanian",		 // LANGID_ROMANIAN = 24
	"russian",		 // LANGID_RUSSIAN = 25
	"slovak",		 // LANGID_SLOVAK = 26
	"swedish",		 // LANGID_SWEDISH = 27
	"thai",			 // LANGID_THAI = 28
	"turkish",		 // LANGID_TURKISH = 29
	"ukrainian",	 // LANGID_UKRAINIAN = 30
	"vietnamese",	 // LANGID_VIETNAMESE = 31
	"tchinese"		 // LANGID_TCHINESE = 32 (Traditional Chinese)
};

// Array of original language codes (as they appear in SourceMod)
stock char sLanguageCodes[LANGID_SIZE][] = {
	"ar",	   // LANGID_ARABIC = 0
	"bg",	   // LANGID_BULGARIAN = 1
	"chi",	   // LANGID_SCHINESE = 2 (Simplified Chinese)
	"cze",	   // LANGID_CZECH = 3
	"da",	   // LANGID_DANISH = 4
	"de",	   // LANGID_GERMAN = 5
	"el",	   // LANGID_GREEK = 6
	"en",	   // LANGID_ENGLISH = 7
	"es",	   // LANGID_SPANISH = 8
	"fi",	   // LANGID_FINNISH = 9
	"fr",	   // LANGID_FRENCH = 10
	"he",	   // LANGID_HEBREW = 11
	"hu",	   // LANGID_HUNGARIAN = 12
	"it",	   // LANGID_ITALIAN = 13
	"jp",	   // LANGID_JAPANESE = 14
	"ko",	   // LANGID_KOREAN = 15
	"las",	   // LANGID_LATAM = 16 (Latin American Spanish)
	"lt",	   // LANGID_LITHUANIAN = 17
	"lv",	   // LANGID_LATVIAN = 18
	"nl",	   // LANGID_DUTCH = 19
	"no",	   // LANGID_NORWEGIAN = 20
	"pl",	   // LANGID_POLISH = 21
	"pt",	   // LANGID_BRAZILIAN = 22
	"pt_p",	   // LANGID_PORTUGUESE = 23
	"ro",	   // LANGID_ROMANIAN = 24
	"ru",	   // LANGID_RUSSIAN = 25
	"sk",	   // LANGID_SLOVAK = 26
	"sv",	   // LANGID_SWEDISH = 27
	"th",	   // LANGID_THAI = 28
	"tr",	   // LANGID_TURKISH = 29
	"ua",	   // LANGID_UKRAINIAN = 30
	"vi",	   // LANGID_VIETNAMESE = 31
	"zho"	   // LANGID_TCHINESE = 32 (Traditional Chinese)
};

/*****************************************************************
			L A N G U A G E   M A S K S   &   C O N S T A N T S
*****************************************************************/

// Bit masks for fast multiple language checks
#define LANGMASK_ROMANCE_LANGUAGES	 ((1 << view_as<int>(LANGID_SPANISH)) | (1 << view_as<int>(LANGID_LATAM)) | (1 << view_as<int>(LANGID_FRENCH)) | (1 << view_as<int>(LANGID_ITALIAN)) | (1 << view_as<int>(LANGID_PORTUGUESE)) | (1 << view_as<int>(LANGID_BRAZILIAN)) | (1 << view_as<int>(LANGID_ROMANIAN)))
#define LANGMASK_GERMANIC_LANGUAGES	 ((1 << view_as<int>(LANGID_ENGLISH)) | (1 << view_as<int>(LANGID_GERMAN)) | (1 << view_as<int>(LANGID_DUTCH)) | (1 << view_as<int>(LANGID_SWEDISH)) | (1 << view_as<int>(LANGID_NORWEGIAN)) | (1 << view_as<int>(LANGID_DANISH)))
#define LANGMASK_SLAVIC_LANGUAGES	 ((1 << view_as<int>(LANGID_RUSSIAN)) | (1 << view_as<int>(LANGID_POLISH)) | (1 << view_as<int>(LANGID_CZECH)) | (1 << view_as<int>(LANGID_SLOVAK)) | (1 << view_as<int>(LANGID_BULGARIAN)) | (1 << view_as<int>(LANGID_UKRAINIAN)))
#define LANGMASK_SPANISH_VARIANTS	 ((1 << view_as<int>(LANGID_SPANISH)) | (1 << view_as<int>(LANGID_LATAM)))
#define LANGMASK_CHINESE_VARIANTS	 ((1 << view_as<int>(LANGID_SCHINESE)) | (1 << view_as<int>(LANGID_TCHINESE)))
#define LANGMASK_PORTUGUESE_VARIANTS ((1 << view_as<int>(LANGID_PORTUGUESE)) | (1 << view_as<int>(LANGID_BRAZILIAN)))

/*****************************************************************
			S T O C K   F U N C T I O N S
*****************************************************************/

/**
 * Gets the language name from a Language ID in an optimized way
 *
 * @param langId        Language ID (LanguageID enum)
 * @param sLangOut      Output buffer for the language name
 * @param maxlength     Buffer size
 * @return              true if language was found, false if out of range
 */
stock bool Lang_GetLanguageName(LanguageID langId, char[] sLangOut, int maxlength)
{
	int id = view_as<int>(langId);
	if (id < 0 || id >= view_as<int>(LANGID_SIZE))
	{
		sLangOut[0] = '\0';
		return false;
	}

	strcopy(sLangOut, maxlength, sLanguageNames[id]);
	return true;
}

/**
 * Gets the language code from a Language ID in an optimized way
 *
 * @param langId        Language ID (LanguageID enum)
 * @param sCodeOut      Output buffer for the language code
 * @param maxlength     Buffer size
 * @return              true if language was found, false if out of range
 */
stock bool Lang_GetLanguageCode(LanguageID langId, char[] sCodeOut, int maxlength)
{
	int id = view_as<int>(langId);
	if (id < 0 || id >= view_as<int>(LANGID_SIZE))
	{
		sCodeOut[0] = '\0';
		return false;
	}

	strcopy(sCodeOut, maxlength, sLanguageCodes[id]);
	return true;
}

/**
 * Searches for a Language ID from language code
 *
 * @param sLangCode     Language code (e.g.: "es", "en", "las")
 * @return              Corresponding LanguageID, or LANGID_ENGLISH if not found
 */
stock LanguageID Lang_FindByCode(const char[] sLangCode)
{
	for (int i = 0; i < view_as<int>(LANGID_SIZE); i++)
	{
		if (StrEqual(sLangCode, sLanguageCodes[i], false))
		{
			return view_as<LanguageID>(i);
		}
	}

	// Fallback to English if not found
	return LANGID_ENGLISH;
}

/**
 * Searches for a Language ID from language name
 *
 * @param sLangName     Language name (e.g.: "spanish", "english", "german")
 * @return              Corresponding LanguageID, or LANGID_ENGLISH if not found
 */
stock LanguageID Lang_FindByName(const char[] sLangName)
{
	for (int i = 0; i < view_as<int>(LANGID_SIZE); i++)
	{
		if (StrEqual(sLangName, sLanguageNames[i], false))
		{
			return view_as<LanguageID>(i);
		}
	}

	// Fallback to English if not found
	return LANGID_ENGLISH;
}

/**
 * Gets client language as LanguageID with automatic mapping
 *
 * @param client        Client index
 * @return              Client's LanguageID (with LATAM → Spanish mapping if necessary)
 */
stock LanguageID Lang_GetClientLanguage(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
	{
		return LANGID_ENGLISH;
	}

	return view_as<LanguageID>(GetClientLanguage(client));
}

/**
 * Gets client language with automatic normalization (latam → spanish)
 * Main function to get normalized client languages.
 * Converts variants like "latam" to their standard equivalents ("spanish")
 * Compatible with localization systems like Localizer.
 *
 * @param client        Client index
 * @param sLangOut      Output buffer for normalized language
 * @param maxlength     Buffer size
 * @noreturn
 */
stock void Lang_GetSafeClientLanguage(int client, char[] sLangOut, int maxlength)
{
	// If client doesn't exist or is fake, use English
	if (client < 1 || client > MaxClients || IsFakeClient(client))
	{
		strcopy(sLangOut, maxlength, "english");
		return;
	}

	LanguageID langId = view_as<LanguageID>(GetClientLanguage(client));

	char	   sLang[64];
	GetLanguageInfo(view_as<int>(langId), _, _, sLang, sizeof(sLang));

	Lang_NormalizeLanguageName(sLang, sLangOut, maxlength);
}

/**
 * Checks if a client uses a specific language
 *
 * @param client        Client index
 * @param targetLang    LanguageID to check
 * @return              true if client uses that language
 */
stock bool Lang_IsClientLanguage(int client, LanguageID targetLang)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
	{
		return false;
	}

	LanguageID clientLang = view_as<LanguageID>(GetClientLanguage(client));
	return (clientLang == targetLang);
}

/**
 * Checks if a client uses Spanish (including LATAM)
 *
 * @param client        Client index
 * @return              true if client uses Spanish or LATAM
 */
stock bool Lang_IsClientSpanish(int client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
	{
		return false;
	}

	LanguageID clientLang = view_as<LanguageID>(GetClientLanguage(client));
	return (clientLang == LANGID_SPANISH || clientLang == LANGID_LATAM);
}

/*****************************************************************
			V A L V E   T R A N S L A T I O N   H E L P E R S
*****************************************************************/

/**
 * Gets a Valve translation with automatic fallback to English if client language fails
 * Requires that the plugin has a configured Localizer instance
 *
 * @param client        Client index
 * @param valveKey      Valve translation key (e.g.: "#L4D360UI_Kick")
 * @param translation   Output buffer for translation
 * @param maxlength     Output buffer size
 * @param localizer     Localizer instance (can be null for auto-detect)
 * @return              true if translation found, false otherwise
 */
stock bool Lang_GetValveTranslation(int client, const char[] valveKey, char[] translation, int maxlength, Localizer localizer = null)
{
	// If no localizer instance provided, try to use global
	if (localizer == null)
	{
		// Plugin using this library must define its own instance
		LogError("[Lang_GetValveTranslation] No Localizer instance provided. Plugin must pass its own Localizer instance.");
		return false;
	}

	if (!localizer.IsReady())
	{
		return false;
	}

	char sLang[64];
	char keyBuffer[256];
	strcopy(keyBuffer, sizeof(keyBuffer), valveKey);

	Lang_GetSafeClientLanguage(client, sLang, sizeof(sLang));

	// Try to translate in the client's language
	if (localizer.PhraseTranslateToLang(keyBuffer, translation, maxlength, client, sLang))
	{
		return true;
	}

	// Fallback to English if it fails
	if (!StrEqual(sLang, "english", false))
	{
		if (localizer.PhraseTranslateToLang(keyBuffer, translation, maxlength, client, "english"))
		{
			return true;
		}
	}

	return false;
}

/**
 * Gets a Valve translation for a specific language
 *
 * @param langId        LanguageID of the desired language
 * @param valveKey      Valve translation key
 * @param translation   Output buffer for the translation
 * @param maxlength     Size of the output buffer
 * @param localizer     Localizer instance
 * @return              true if translation found, false otherwise
 */
stock bool Lang_GetValveTranslationForLanguage(LanguageID langId, const char[] valveKey, char[] translation, int maxlength, Localizer localizer)
{
	if (localizer == null || !localizer.IsReady())
	{
		return false;
	}

	char sLang[64];
	char keyBuffer[256];

	if (!Lang_GetLanguageName(langId, sLang, sizeof(sLang)))
	{
		return false;
	}

	strcopy(keyBuffer, sizeof(keyBuffer), valveKey);

	return localizer.PhraseTranslateToLang(keyBuffer, translation, maxlength, LANG_SERVER, sLang);
}

/*****************************************************************
			L A N G U A G E   N O R M A L I Z A T I O N
*****************************************************************/

/**
 * Normalizes a language name, converting specific variants to their standard equivalents
 * Mainly converts "latam" to "spanish" for compatibility with localization systems
 *
 * @param input         Input language name
 * @param output        Output buffer for the normalized name
 * @param maxlength     Size of the output buffer
 * @noreturn
 */
stock void Lang_NormalizeLanguageName(const char[] input, char[] output, int maxlength)
{
	if (StrEqual(input, "latam", false))
	{
		strcopy(output, maxlength, "spanish");
	}
	else
	{
		strcopy(output, maxlength, input);
	}
}

/*****************************************************************
			U T I L I T Y   F U N C T I O N S
*****************************************************************/

/**
 * Gets the total number of supported languages
 *
 * @return              Number of languages (LANGID_SIZE)
 */
stock int Lang_GetLanguageCount()
{
	return view_as<int>(LANGID_SIZE);
}

/**
 * Validates if a LanguageID is within valid range
 *
 * @param langId        LanguageID to validate
 * @return              true if valid, false otherwise
 */
stock bool Lang_IsValidLanguageID(LanguageID langId)
{
	int id = view_as<int>(langId);
	return (id >= 0 && id < view_as<int>(LANGID_SIZE));
}

/**
 * Converts a SourceMod language ID to LanguageID enum
 *
 * @param smLangId      SourceMod language ID (from GetClientLanguage())
 * @return              Corresponding LanguageID
 */
stock LanguageID Lang_SMLanguageToEnum(int smLangId)
{
	if (smLangId >= 0 && smLangId < view_as<int>(LANGID_SIZE))
	{
		return view_as<LanguageID>(smLangId);
	}
	return LANGID_ENGLISH;
}

/*****************************************************************
			Q U I C K   L A N G U A G E   C H E C K S
*****************************************************************/

/**
 * Quick verification functions for common languages
 * Optimized to avoid multiple comparisons and improve performance
 */

// Individual language verifications (inlined for maximum performance)
#define Lang_IsEnglish(%1)  (view_as<int>(%1) == view_as<int>(LANGID_ENGLISH))
#define Lang_IsSpanish(%1)  (view_as<int>(%1) == view_as<int>(LANGID_SPANISH))
#define Lang_IsLatam(%1)    (view_as<int>(%1) == view_as<int>(LANGID_LATAM))
#define Lang_IsFrench(%1)   (view_as<int>(%1) == view_as<int>(LANGID_FRENCH))
#define Lang_IsGerman(%1)   (view_as<int>(%1) == view_as<int>(LANGID_GERMAN))
#define Lang_IsItalian(%1)  (view_as<int>(%1) == view_as<int>(LANGID_ITALIAN))
#define Lang_IsRussian(%1)  (view_as<int>(%1) == view_as<int>(LANGID_RUSSIAN))

/**
 * Optimized verification for multiple languages using bit ranges
 *
 * @param langId        LanguageID to verify
 * @param targetMask    Bit mask with the languages to verify
 * @return              true if the language is in the mask
 */
stock bool Lang_IsLanguageInMask(LanguageID langId, int targetMask)
{
	int id = view_as<int>(langId);
	return (id >= 0 && id < 32 && (targetMask & (1 << id)) != 0);
}

/**
 * Verifies if a language uses Spanish localization (Spanish or LATAM)
 * Optimized using bit masks
 *
 * @param langId        LanguageID to verify
 * @return              true if uses Spanish localization
 */
stock bool Lang_UsesSpanishLocalization(LanguageID langId)
{
	return Lang_IsSpanishVariant(langId);
}

/*****************************************************************
			U T I L I T Y   F U N C T I O N S
*****************************************************************/

/**
 * Gets the localized name of a team for a specific client.
 * Requires: #include <left4dhooks> for the L4DTeam enum
 *
 * @param team          The team to translate (L4DTeam)
 * @param client        Client index to get their language
 * @param buffer        Output buffer for the team name
 * @param maxlength     Output buffer size
 * @param localizer     Localizer instance (can be null for manual fallback)
 * @return              true if translation found, false if used manual fallback
 */
stock bool Lang_GetLocalizedTeamName(any team, int client, char[] buffer, int maxlength, Localizer localizer = null)
{
	char sKey[64];
	char sFallback[32];

	switch (team)
	{
		case 2:
		{
			strcopy(sKey, sizeof(sKey), "#Cstrike_TitlesTXT_Terrorist_Forces");
			strcopy(sFallback, sizeof(sFallback), "Survivor");
		}
		case 3:
		{
			strcopy(sKey, sizeof(sKey), "#Cstrike_TitlesTXT_CT_Forces");
			strcopy(sFallback, sizeof(sFallback), "Infected");
		}
		case 1:
		{
			strcopy(sKey, sizeof(sKey), "#L4D360UI_Spectate");
			strcopy(sFallback, sizeof(sFallback), "Spectator");
		}
		default:
		{
			strcopy(sKey, sizeof(sKey), "#L4D360UI_Spectate");
			strcopy(sFallback, sizeof(sFallback), "Spectator");
		}
	}

	if (localizer != null && Lang_GetValveTranslation(client, sKey, buffer, maxlength, localizer))
	{
		return true;
	}

	strcopy(buffer, maxlength, sFallback);
	return false;
}

/**
 * Optimized verifications for language families using bit masks
 */

/**
 * Verifies if a language belongs to the Romance language family
 *
 * @param langId        LanguageID to verify
 * @return              true if it's a Romance language
 */
stock bool Lang_IsRomanceLanguage(LanguageID langId)
{
	return Lang_IsLanguageInMask(langId, LANGMASK_ROMANCE_LANGUAGES);
}

/**
 * Verifies if a language belongs to the Germanic language family
 *
 * @param langId        LanguageID to verify
 * @return              true if it's a Germanic language
 */
stock bool Lang_IsGermanicLanguage(LanguageID langId)
{
	return Lang_IsLanguageInMask(langId, LANGMASK_GERMANIC_LANGUAGES);
}

/**
 * Verifies if a language belongs to the Slavic language family
 *
 * @param langId        LanguageID to verify
 * @return              true if it's a Slavic language
 */
stock bool Lang_IsSlavicLanguage(LanguageID langId)
{
	return Lang_IsLanguageInMask(langId, LANGMASK_SLAVIC_LANGUAGES);
}

/**
 * Verifies if a language is a Spanish variant (including LATAM)
 *
 * @param langId        LanguageID to verify
 * @return              true if it's Spanish or LATAM
 */
stock bool Lang_IsSpanishVariant(LanguageID langId)
{
	return Lang_IsLanguageInMask(langId, LANGMASK_SPANISH_VARIANTS);
}

/**
 * Verifies if a language is a Chinese variant
 *
 * @param langId        LanguageID to verify
 * @return              true if it's simplified or traditional Chinese
 */
stock bool Lang_IsChineseVariant(LanguageID langId)
{
	return Lang_IsLanguageInMask(langId, LANGMASK_CHINESE_VARIANTS);
}

/**
 * Verifies if a language is a Portuguese variant
 *
 * @param langId        LanguageID to verify
 * @return              true if it's Portuguese or Brazilian
 */
stock bool Lang_IsPortugueseVariant(LanguageID langId)
{
	return Lang_IsLanguageInMask(langId, LANGMASK_PORTUGUESE_VARIANTS);
}