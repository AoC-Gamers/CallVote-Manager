/*
	callvote_stocks.inc
	Copyright (C) 2023 Lechuga

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#if defined _callvote_stocks_included
	#endinput
#endif
#define _callvote_stocks_included

#include <steamidtools>

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define DIR_CALLVOTE		  "logs/callvote.log"

/**
 * @section Bitwise values definitions for vote types.
 * Unified enumeration for vote restrictions and type identification.
 */
enum VoteType
{
	VOTE_NONE           = 0,        // No restrictions
	VOTE_CHANGEDIFFICULTY = (1<<0), // 1 - Change difficulty
	VOTE_RESTARTGAME    = (1<<1),   // 2 - Restart game
	VOTE_KICK           = (1<<2),   // 4 - Kick players
	VOTE_CHANGEMISSION  = (1<<3),   // 8 - Change mission
	VOTE_RETURNTOLOBBY  = (1<<4),   // 16 - Return to lobby
	VOTE_CHANGECHAPTER  = (1<<5),   // 32 - Change chapter
	VOTE_CHANGEALLTALK  = (1<<6),   // 64 - Change alltalk
	VOTE_ALL            = 127       // All vote types
};


enum TypeVotes
{
	ChangeDifficulty = 0,
	RestartGame		 = 1,
	Kick			 = 2,
	ChangeMission	 = 3,
	ReturnToLobby	 = 4,
	ChangeChapter	 = 5,
	ChangeAllTalk	 = 6,

	TypeVotes_Size	 = 7
};

/**
 * Check if the translation file exists
 *
 * @param translation	Translation name.
 * @noreturn
 */
stock void LoadTranslation(const char[] translation)
{
	char
		sPath[PLATFORM_MAX_PATH],
		sName[64];

	Format(sName, sizeof(sName), "translations/%s.txt", translation);
	BuildPath(Path_SM, sPath, sizeof(sPath), sName);
	if (!FileExists(sPath))
		SetFailState("Missing translation file %s.txt", translation);

	LoadTranslations(translation);
}

/**
 * Returns a valid client indexed.
 * 
 * OPTIMIZED: Now uses steamidtools.inc IsValidClientIndex() for consistency
 * and improved validation logic.
 *
 * @param iClient		Player's index.
 * @return				true if the client is valid, false if not.
 */
stock bool IsValidClient(int iClient)
{
	return (IsValidClientIndex(iClient) && IsClientInGame(iClient) && !IsFakeClient(iClient));
}

/**
 * Formatea duración en minutos a string legible
 */
stock void FormatDuration(int minutes, char[] buffer, int maxlen)
{
	if (minutes == 0)
	{
		strcopy(buffer, maxlen, "Permanent");
		return;
	}
	
	if (minutes < 60)
	{
		Format(buffer, maxlen, "%d minutes", minutes);
	}
	else if (minutes < 1440) // Menos de 24 horas
	{
		int hours = minutes / 60;
		int remainingMinutes = minutes % 60;
		
		if (remainingMinutes == 0)
		{
			Format(buffer, maxlen, "%d hours", hours);
		}
		else
		{
			Format(buffer, maxlen, "%d hours %d minutes", hours, remainingMinutes);
		}
	}
	else // Días
	{
		int days = minutes / 1440;
		int remainingHours = (minutes % 1440) / 60;
		
		if (remainingHours == 0)
		{
			Format(buffer, maxlen, "%d days", days);
		}
		else
		{
			Format(buffer, maxlen, "%d days %d hours", days, remainingHours);
		}
	}
}