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

#if defined REQUIRE_PLUGIN
	#undef REQUIRE_PLUGIN
	#define _callvote_restore_require_plugin
#endif
#include <steamidtools>
#if defined _callvote_restore_require_plugin
	#define REQUIRE_PLUGIN
	#undef _callvote_restore_require_plugin
#endif

/*****************************************************************
			G L O B A L   V A R S
*****************************************************************/

#define DIR_CALLVOTE		  "logs/callvote.log"
#define CALLVOTE_AUTOEXEC_FOLDER		  "sourcemod/callvote"
#define CALLVOTE_AUTOEXEC_FOLDER_PATH	  "../../cfg/sourcemod/callvote"
#define CALLVOTE_LOG_FOLDER		  "logs/callvote"
#define CALLVOTE_LOG_FOLDER_PATH	  CALLVOTE_LOG_FOLDER
#define CALLVOTE_NORMAL_LOG_FILE	  DIR_CALLVOTE

enum CVLogMode
{
	CVLogMode_Off = 0,
	CVLogMode_Normal,
	CVLogMode_Debug
};

enum CVLogDebugMask
{
	CVLogMask_None         = 0,
	CVLogMask_Core         = (1 << 0),
	CVLogMask_SQL          = (1 << 1),
	CVLogMask_Cache        = (1 << 2),
	CVLogMask_Commands     = (1 << 3),
	CVLogMask_Identity     = (1 << 4),
	CVLogMask_Forwards     = (1 << 5),
	CVLogMask_Session      = (1 << 6),
	CVLogMask_Localization = (1 << 7),

	CVLogMask_All          = 255
};

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

enum CallVoteEndReason
{
	CallVoteEnd_Passed = 0,
	CallVoteEnd_Failed,
	CallVoteEnd_Cancelled,
	CallVoteEnd_Aborted
};

enum SourceDB
{
	SourceDB_Unknown = 0,	// Desconocido
	SourceDB_SQLite  = 1,	// SQLite
	SourceDB_MySQL   = 2	// MySQL
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
 * Ensures the shared CallVote autoexec folder exists under cfg/sourcemod/callvote.
 *
 * @noreturn
 */
stock void EnsureCallVoteAutoExecFolder()
{
	static bool s_bEnsured;
	if (s_bEnsured)
		return;

	char sFolderPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFolderPath, sizeof(sFolderPath), CALLVOTE_AUTOEXEC_FOLDER_PATH);
	if (!DirExists(sFolderPath))
		CreateDirectory(sFolderPath, 511);

	s_bEnsured = DirExists(sFolderPath);
}

/**
 * Creates or executes an autoexec config in the shared CallVote subdirectory.
 *
 * @param autoCreate	Whether to auto-create the cfg file.
 * @param name			Config file name without extension.
 * @noreturn
 */
stock void CallVoteAutoExecConfig(bool autoCreate, const char[] name)
{
	EnsureCallVoteAutoExecFolder();
	AutoExecConfig(autoCreate, name, CALLVOTE_AUTOEXEC_FOLDER);
}

stock ConVar CallVoteEnsureLogModeConVar()
{
	ConVar cvLogMode = CreateConVar("sm_cv_log_mode", "0", "CallVote suite log mode. 0=off, 1=normal, 2=debug.", FCVAR_NONE, true, 0.0, true, 2.0);
	if (cvLogMode == null)
		cvLogMode = FindConVar("sm_cv_log_mode");

	if (cvLogMode != null)
		cvLogMode.AddChangeHook(CallVote_OnLogModeChanged_EnsureDebugLogFolder);

	return cvLogMode;
}

stock bool CallVoteIsNormalLogMode(ConVar cvLogMode)
{
	return (cvLogMode != null && cvLogMode.IntValue == view_as<int>(CVLogMode_Normal));
}

stock bool CallVoteIsDebugLogMode(ConVar cvLogMode)
{
	return (cvLogMode != null && cvLogMode.IntValue == view_as<int>(CVLogMode_Debug));
}

stock void EnsureCallVoteDebugLogFolderForMode(ConVar cvLogMode)
{
	if (!CallVoteIsDebugLogMode(cvLogMode))
		return;

	EnsureCallVoteDebugLogFolder();
}

stock void CallVote_OnLogModeChanged_EnsureDebugLogFolder(ConVar cvLogMode, const char[] sOldValue, const char[] sNewValue)
{
	EnsureCallVoteDebugLogFolderForMode(cvLogMode);
}

stock bool CallVoteDebugMaskEnabled(ConVar cvLogMode, ConVar cvDebugMask, int mask)
{
	if (!CallVoteIsDebugLogMode(cvLogMode) || cvDebugMask == null)
		return false;

	return ((cvDebugMask.IntValue & mask) != 0);
}

stock void EnsureCallVoteSMLogsFolder()
{
	static bool s_bEnsured;
	if (s_bEnsured)
		return;

	char sLogsPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sLogsPath, sizeof(sLogsPath), "logs");
	if (!DirExists(sLogsPath))
		CreateDirectory(sLogsPath, 511);

	s_bEnsured = DirExists(sLogsPath);
}

stock void EnsureCallVoteDebugLogFolder()
{
	static bool s_bEnsured;
	if (s_bEnsured)
		return;

	EnsureCallVoteSMLogsFolder();

	char sFolderPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFolderPath, sizeof(sFolderPath), CALLVOTE_LOG_FOLDER_PATH);
	if (!DirExists(sFolderPath))
		CreateDirectory(sFolderPath, 511);

	s_bEnsured = DirExists(sFolderPath);
}

stock void BuildCallVoteNormalLogPath(char[] sLogPath, int maxLen)
{
	EnsureCallVoteSMLogsFolder();
	BuildPath(Path_SM, sLogPath, maxLen, CALLVOTE_NORMAL_LOG_FILE);
}

stock void BuildCallVoteDebugLogPath(const char[] debugFileName, char[] sLogPath, int maxLen)
{
	char sRelativePath[PLATFORM_MAX_PATH];
	FormatEx(sRelativePath, sizeof(sRelativePath), "%s/%s", CALLVOTE_LOG_FOLDER, debugFileName);
	BuildPath(Path_SM, sLogPath, maxLen, sRelativePath);
}

stock bool EnsureCallVoteParentFolderForFile(const char[] sFilePath)
{
	char sFolderPath[PLATFORM_MAX_PATH];
	strcopy(sFolderPath, sizeof(sFolderPath), sFilePath);

	int lastSlash = -1;
	for (int i = 0; sFolderPath[i] != '\0'; i++)
	{
		if (sFolderPath[i] == '/' || sFolderPath[i] == '\\')
			lastSlash = i;
	}

	if (lastSlash <= 0)
		return false;

	sFolderPath[lastSlash] = '\0';
	if (!DirExists(sFolderPath))
		CreateDirectory(sFolderPath, 511);

	return DirExists(sFolderPath);
}

methodmap CallVoteLogger < StringMap
{
	public CallVoteLogger(const char[] pluginTag, const char[] debugFileName, ConVar cvLogMode, ConVar cvDebugMask = null)
	{
		StringMap state = new StringMap();
		state.SetString("tag", pluginTag);
		state.SetString("file", debugFileName);
		state.SetValue("mode", view_as<int>(cvLogMode));
		state.SetValue("mask", view_as<int>(cvDebugMask));
		return view_as<CallVoteLogger>(state);
	}

	public void SetModeConVar(ConVar cvLogMode)
	{
		this.SetValue("mode", view_as<int>(cvLogMode));
	}

	public void SetDebugMaskConVar(ConVar cvDebugMask)
	{
		this.SetValue("mask", view_as<int>(cvDebugMask));
	}

	public void Normal(const char[] eventTag, const char[] message, any ...)
	{
		ConVar cvLogMode = this.GetModeConVar();
		if (!CallVoteIsNormalLogMode(cvLogMode))
			return;

		char sLogPath[PLATFORM_MAX_PATH];
		BuildCallVoteNormalLogPath(sLogPath, sizeof(sLogPath));
		if (!EnsureCallVoteParentFolderForFile(sLogPath))
			return;

		char sPluginTag[32];
		this.GetString("tag", sPluginTag, sizeof(sPluginTag));

		static char sBuffer[1024];
		VFormat(sBuffer, sizeof(sBuffer), message, 4);

		if (eventTag[0] != '\0')
			LogToFileEx(sLogPath, "[%s][%s] %s", sPluginTag, eventTag, sBuffer);
		else
			LogToFileEx(sLogPath, "[%s] %s", sPluginTag, sBuffer);
	}

	public void Debug(int debugMask, const char[] category, const char[] message, any ...)
	{
		ConVar cvLogMode = this.GetModeConVar();
		ConVar cvDebugMask = this.GetDebugMaskConVar();
		if (!CallVoteDebugMaskEnabled(cvLogMode, cvDebugMask, debugMask))
			return;

		char sDebugFile[PLATFORM_MAX_PATH];
		this.GetString("file", sDebugFile, sizeof(sDebugFile));

		char sLogPath[PLATFORM_MAX_PATH];
		BuildCallVoteDebugLogPath(sDebugFile, sLogPath, sizeof(sLogPath));
		if (!EnsureCallVoteParentFolderForFile(sLogPath))
			return;

		char sPluginTag[32];
		this.GetString("tag", sPluginTag, sizeof(sPluginTag));

		static char sBuffer[1024];
		VFormat(sBuffer, sizeof(sBuffer), message, 5);

		if (category[0] != '\0')
			LogToFileEx(sLogPath, "[%s][%s] %s", sPluginTag, category, sBuffer);
		else
			LogToFileEx(sLogPath, "[%s] %s", sPluginTag, sBuffer);
	}

	public ConVar GetModeConVar()
	{
		int value;
		if (!this.GetValue("mode", value))
			return null;

		return view_as<ConVar>(value);
	}

	public ConVar GetDebugMaskConVar()
	{
		int value;
		if (!this.GetValue("mask", value))
			return null;

		return view_as<ConVar>(value);
	}
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

/**
 * Formats a duration using translation keys from callvote_common.phrases.
 *
 * @param client        Translation target client.
 * @param minutes       Duration in minutes. 0 means permanent.
 * @param buffer        Output buffer.
 * @param maxlen        Output buffer length.
 * @noreturn
 */
stock void FormatDurationLocalized(int client, int minutes, char[] buffer, int maxlen)
{
	if (minutes == 0)
	{
		Format(buffer, maxlen, "%T", "CallVoteDurationPermanent", client);
		return;
	}

	if (minutes < 60)
	{
		Format(buffer, maxlen, "%T", "CallVoteDurationMinutes", client, minutes);
		return;
	}

	if (minutes < 1440)
	{
		int hours = minutes / 60;
		int remainingMinutes = minutes % 60;

		if (remainingMinutes == 0)
		{
			Format(buffer, maxlen, "%T", "CallVoteDurationHours", client, hours);
		}
		else
		{
			Format(buffer, maxlen, "%T", "CallVoteDurationHoursMinutes", client, hours, remainingMinutes);
		}
		return;
	}

	int days = minutes / 1440;
	int remainingHours = (minutes % 1440) / 60;

	if (remainingHours == 0)
	{
		Format(buffer, maxlen, "%T", "CallVoteDurationDays", client, days);
	}
	else
	{
		Format(buffer, maxlen, "%T", "CallVoteDurationDaysHours", client, days, remainingHours);
	}
}

/**
 * Converts a vote enum to its bitmask flag representation.
 *
 * @param voteType      Vote enum value.
 * @return              Matching VoteType bitmask, or VOTE_NONE when unsupported.
 */
stock VoteType GetVoteFlag(TypeVotes voteType)
{
	switch (voteType)
	{
		case ChangeDifficulty: return VOTE_CHANGEDIFFICULTY;
		case RestartGame: return VOTE_RESTARTGAME;
		case Kick: return VOTE_KICK;
		case ChangeMission: return VOTE_CHANGEMISSION;
		case ReturnToLobby: return VOTE_RETURNTOLOBBY;
		case ChangeChapter: return VOTE_CHANGECHAPTER;
		case ChangeAllTalk: return VOTE_CHANGEALLTALK;
	}

	return VOTE_NONE;
}
