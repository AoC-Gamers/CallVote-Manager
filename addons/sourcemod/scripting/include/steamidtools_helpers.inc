/*
	steamidtools_helpers.inc
	Copyright (C) 2026 AoC-Gamers
	Version: 1.0.0
*/

#if defined _steamidtools_helpers_included
	#endinput
#endif
#define _steamidtools_helpers_included

#include <steamidtools>

#define STEAMIDTOOLS_HELPERS_INCLUDE_VERSION "1.0.0"

#define STEAMID64_BASE_STRING "76561197960265728"

/**
 * Returns a command argument trimmed and without surrounding quotes.
 *
 * @param iArg          1-based argument index.
 * @param iArgs         Total command arguments.
 * @param szBuffer      Output buffer.
 * @param iMaxLength    Output buffer length.
 * @return              true when the argument exists, false otherwise.
 */
stock bool SteamIDTools_GetCmdArgNormalized(int iArg, int iArgs, char[] szBuffer, int iMaxLength)
{
	if (iArg < 1 || iArg > iArgs)
	{
		szBuffer[0] = '\0';
		return false;
	}

	GetCmdArg(iArg, szBuffer, iMaxLength);
	TrimString(szBuffer);
	StripQuotes(szBuffer);
	return true;
}

/**
 * Returns true if the string contains only decimal digits.
 */
stock bool SteamIDTools_IsNumericString(const char[] szValue)
{
	if (szValue[0] == '\0')
		return false;

	for (int i = 0; szValue[i] != '\0'; i++)
	{
		if (!IsCharNumeric(szValue[i]))
			return false;
	}

	return true;
}

/**
 * Converts an AccountID to SteamID64 using decimal string arithmetic.
 *
 * This avoids relying on 64-bit integer support in SourcePawn while still
 * returning a canonical SteamID64 representation suitable for persistence.
 */
stock bool SteamIDTools_AccountIDToSteamID64(int iAccountId, char[] szBuffer, int iMaxLength)
{
	if (iAccountId <= 0 || iMaxLength <= STEAMID64_EXACT_LENGTH)
	{
		if (iMaxLength > 0)
			szBuffer[0] = '\0';
		return false;
	}

	char szAccountId[ACCOUNTID_LENGTH];
	IntToString(iAccountId, szAccountId, sizeof(szAccountId));

	int iBaseIndex = strlen(STEAMID64_BASE_STRING) - 1;
	int iAccountIndex = strlen(szAccountId) - 1;
	int iCarry = 0;
	int iReverseLength = 0;

	char szReverseResult[STEAMID64_EXACT_LENGTH + 2];

	while (iBaseIndex >= 0 || iAccountIndex >= 0 || iCarry > 0)
	{
		int iSum = iCarry;

		if (iBaseIndex >= 0)
		{
			iSum += STEAMID64_BASE_STRING[iBaseIndex] - '0';
			iBaseIndex--;
		}

		if (iAccountIndex >= 0)
		{
			iSum += szAccountId[iAccountIndex] - '0';
			iAccountIndex--;
		}

		szReverseResult[iReverseLength++] = view_as<char>((iSum % 10) + '0');
		iCarry = iSum / 10;
	}

	if (iReverseLength <= 0 || iReverseLength >= iMaxLength)
	{
		szBuffer[0] = '\0';
		return false;
	}

	for (int i = 0; i < iReverseLength; i++)
	{
		szBuffer[i] = szReverseResult[iReverseLength - 1 - i];
	}

	szBuffer[iReverseLength] = '\0';
	return true;
}

/**
 * Joins normalized command arguments using a delimiter.
 */
stock void SteamIDTools_JoinCmdArgs(int iStartArg, int iArgs, char[] szBuffer, int iMaxLength, const char[] szDelimiter = " ")
{
	szBuffer[0] = '\0';

	char szPart[128];
	for (int i = iStartArg; i <= iArgs; i++)
	{
		if (!SteamIDTools_GetCmdArgNormalized(i, iArgs, szPart, sizeof(szPart)))
			continue;

		if (szPart[0] == '\0')
			continue;

		if (szBuffer[0] != '\0')
			StrCat(szBuffer, iMaxLength, szDelimiter);

		StrCat(szBuffer, iMaxLength, szPart);
	}
}

/**
 * Attempts to reconstruct an identity from one or more command arguments.
 *
 * This is useful for Source console input such as `STEAM_1:1:123`, which may
 * arrive split across multiple arguments when colons are not quoted.
 *
 * @param iStartArg         First argument index to inspect.
 * @param iArgs             Total command arguments.
 * @param szIdentity        Output buffer for the reconstructed identity.
 * @param iMaxLength        Output buffer length.
 * @param iNextArg          Receives the next argument index after the identity.
 * @param iMaxIdentityArgs  Maximum amount of arguments consumed while rebuilding.
 * @return                  true when a known identity format was reconstructed,
 *                          false when it falls back to the first normalized arg.
 */
stock bool SteamIDTools_TryGetIdentityFromCmdArgs(int iStartArg, int iArgs, char[] szIdentity, int iMaxLength, int &iNextArg, int iMaxIdentityArgs = 5)
{
	szIdentity[0] = '\0';
	iNextArg = iStartArg + 1;

	if (iStartArg < 1 || iStartArg > iArgs)
	{
		return false;
	}

	char szCandidate[128];
	char szPart[64];
	int iLastArg = iStartArg + iMaxIdentityArgs - 1;
	if (iLastArg > iArgs)
		iLastArg = iArgs;

	for (int i = iStartArg; i <= iLastArg; i++)
	{
		if (!SteamIDTools_GetCmdArgNormalized(i, iArgs, szPart, sizeof(szPart)))
			break;

		if (i == iStartArg)
			strcopy(szCandidate, sizeof(szCandidate), szPart);
		else
			StrCat(szCandidate, sizeof(szCandidate), szPart);

		SteamIDFormat eFormat = DetectSteamIDFormat(szCandidate);
		if (eFormat == STEAMID_FORMAT_UNKNOWN || eFormat == STEAMID_FORMAT_SPECIAL)
			continue;

		strcopy(szIdentity, iMaxLength, szCandidate);
		iNextArg = i + 1;
		return true;
	}

	SteamIDTools_GetCmdArgNormalized(iStartArg, iArgs, szIdentity, iMaxLength);
	iNextArg = iStartArg + 1;
	return false;
}
