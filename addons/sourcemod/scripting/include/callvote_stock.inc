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

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define DIR_CALLVOTE		  "logs/callvote.log"
#define MAX_REASON_LENGTH	  512

/**
 * @section Bitwise values definitions for type vote.
 */
#define VOTE_CHANGEDIFFICULTY (1 << 0)	  // 1
#define VOTE_RESTARTGAME	  (1 << 1)	  // 2
#define VOTE_KICK			  (1 << 2)	  // 4
#define VOTE_CHANGEMISSION	  (1 << 3)	  // 8
#define VOTE_RETURNTOLOBBY	  (1 << 4)	  // 16
#define VOTE_CHANGECHAPTER	  (1 << 5)	  // 32
#define VOTE_CHANGEALLTALK	  (1 << 6)	  // 64


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

/*****************************************************************
			L 4 D H O O K S
*****************************************************************/

#if !defined _l4d_stocks_included

enum L4DTeam
{
	L4DTeam_Unassigned				= 0,
	L4DTeam_Spectator				= 1,
	L4DTeam_Survivor				= 2,
	L4DTeam_Infected				= 3
}

/**
 * Returns the clients team using L4DTeam.
 *
 * @param client		Player's index.
 * @return				Current L4DTeam of player.
 * @error				Invalid client index.
 */
stock L4DTeam L4D_GetClientTeam(int client)
{
	int team = GetClientTeam(client);
	return view_as<L4DTeam>(team);
}

/**
 * Returns a valid client indexed.
 *
 * @param client		Player's index.
 * @return				true if the client is valid, false if not.
 */
stock bool IsValidClient(int iClient)
{
	return (IsValidClientIndex(iClient) && IsClientInGame(iClient) && !IsFakeClient(iClient));
}

/**
 * Client indexed.
 *
 * @param client		Player's index.
 * @return				true if the client is valid, false if not.
 */
stock bool IsValidClientIndex(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients);
}

#endif

