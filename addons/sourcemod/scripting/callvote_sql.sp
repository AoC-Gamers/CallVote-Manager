#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <callvote_core>
#include <steamidtools_stock>

#define PLUGIN_VERSION "1.0.1"

ConVar g_cvLogMode, g_cvDebugMask;
enum struct SQLRuntimeLog
{
	char path[PLATFORM_MAX_PATH];
	bool ready;

	void Init()
	{
		char folder[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, folder, sizeof(folder), "logs/callvote");
		if (!DirExists(folder) && !CreateDirectory(folder, 511))
		{
			LogError("[CallVote SQL] event=log_init_failed stage=directory");
			return;
		}
		BuildPath(Path_SM, this.path, sizeof(this.path), "logs/callvote/sql.log");
		File file = OpenFile(this.path, "a");
		if (file == null)
		{
			LogError("[CallVote SQL] event=log_init_failed stage=file");
			return;
		}
		delete file;
		this.ready = true;
	}

	bool DebugEnabled(int mask)
	{
		return this.ready && g_cvLogMode.IntValue == 2 && (g_cvDebugMask.IntValue & mask) != 0;
	}

	void Write(const char[] category, const char[] text)
	{
		if (this.ready)
			LogToFileEx(this.path, "[%s] %s", category, text);
	}
}

SQLRuntimeLog g_Log;

methodmap CVSQLLog
{
	public static void Debug(const char[] message, any ...)
	{
		if (!g_Log.DebugEnabled(1))
			return;
		char text[1024];
		VFormat(text, sizeof(text), message, 2);
		g_Log.Write("Storage", text);
	}
	public static void Query(const char[] message, any ...)
	{
		if (!g_Log.DebugEnabled(2))
			return;
		char text[1024];
		VFormat(text, sizeof(text), message, 2);
		g_Log.Write("SQL", text);
	}
	public static void Event(const char[] category, const char[] message, any ...)
	{
		if (!g_Log.ready || g_cvLogMode.IntValue == 0)
			return;
		char text[1024];
		VFormat(text, sizeof(text), message, 3);
		g_Log.Write(category, text);
	}

}

#include "callvote_sql/storage.sp"

public Plugin myinfo =
{
	name = "Call Vote SQL",
	author = "lechuga",
	description = "Optional SQL persistence and administration for confirmed core votes",
	version = PLUGIN_VERSION,
	url = "https://github.com/AoC-Gamers/CallVote-Manager"
};

public void OnPluginStart()
{
	LoadTranslation("callvote_sql.phrases");
	LoadTranslation("callvote_common.phrases");
	g_cvLogMode = CreateConVar("sm_cvs_log_mode", "0", "SQL satellite log mode: 0=off, 1=normal, 2=debug.", FCVAR_NONE, true, 0.0, true, 2.0);
	g_cvDebugMask = CreateConVar("sm_cvs_debug_mask", "0", "SQL satellite debug: Storage=1 SQL=2 All=3.", FCVAR_NONE, true, 0.0, true, 3.0);
	g_Log.Init();
	OnPluginStart_SQL();
	CallVoteAutoExecConfig(true, "callvote_sql");
}

public void OnConfigsExecuted()
{
	OnConfigsExecuted_SQL();
}

public void OnPluginEnd()
{
	OnPluginEnd_SQL();
}

public void CallVote_Start(int sessionId)
{
	RecordSQLVote(sessionId);
}
