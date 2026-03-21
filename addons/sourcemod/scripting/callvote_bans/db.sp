#if defined _cvb_db_included
	#endinput
#endif
#define _cvb_db_included

#define TABLE_BANS "callvote_bans"

void InitDatabase()
{
	ConnectMySQL();
	ConnectSQLite();
}

SourceDB CVB_GetActiveDatabase()
{
	if (g_hMySQLDB != null)
		return SourceDB_MySQL;

	if (g_hSQLiteDB != null)
		return SourceDB_SQLite;

	return SourceDB_Unknown;
}

void ConnectMySQL()
{
	char sqlConfig[64];
	g_cvarSQLConfig.GetString(sqlConfig, sizeof(sqlConfig));

	if (sqlConfig[0] == '\0')
	{
		CVBLog.SQL("MySQL configuration name is empty, using SQLite only");
		return;
	}

	if (SQL_CheckConfig(sqlConfig))
	{
		CVBLog.SQL("Connecting MySQL backend using config '%s'", sqlConfig);
		SQL_TConnect(MySQL_ConnectCallback, sqlConfig);
	}
	else
	{
		CVBLog.SQL("MySQL configuration '%s' not found, using SQLite only", sqlConfig);
	}
}

public void MySQL_ConnectCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("Error connecting to MySQL: %s", error);
		return;
	}

	g_hMySQLDB = view_as<Database>(hndl);
	CVBLog.SQL("MySQL connection established");
}

void ConnectSQLite()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/callvote_bans.db");

	char sError[256];
	g_hSQLiteDB = SQLite_UseDatabase("callvote_bans", sError, sizeof(sError));

	if (g_hSQLiteDB == null)
	{
		LogError("Error connecting to SQLite: %s", sError);
		return;
	}

	CVBLog.SQL("SQLite connection established: %s", sPath);
	EnsureSQLiteSchema();
}

void CloseDatabase()
{
	if (g_hMySQLDB != null)
	{
		delete g_hMySQLDB;
		g_hMySQLDB = null;
	}

	if (g_hSQLiteDB != null)
	{
		delete g_hSQLiteDB;
		g_hSQLiteDB = null;
	}

	CVBLog.SQL("Database connections closed");
}

void EnsureSQLiteSchema()
{
	if (g_hSQLiteDB == null)
		return;

	char query[MAX_QUERY_LENGTH];
	int len = 0;

	len += Format(query[len], sizeof(query) - len, "CREATE TABLE IF NOT EXISTS `%s` (", TABLE_BANS);
	len += Format(query[len], sizeof(query) - len, "`id` INTEGER PRIMARY KEY AUTOINCREMENT, ");
	len += Format(query[len], sizeof(query) - len, "`account_id` INTEGER NOT NULL, ");
	len += Format(query[len], sizeof(query) - len, "`ban_type` INTEGER NOT NULL, ");
	len += Format(query[len], sizeof(query) - len, "`created_timestamp` INTEGER NOT NULL, ");
	len += Format(query[len], sizeof(query) - len, "`duration_minutes` INTEGER NOT NULL DEFAULT 0, ");
	len += Format(query[len], sizeof(query) - len, "`expires_timestamp` INTEGER NOT NULL DEFAULT 0, ");
	len += Format(query[len], sizeof(query) - len, "`admin_account_id` INTEGER DEFAULT NULL, ");
	len += Format(query[len], sizeof(query) - len, "`reason` TEXT DEFAULT NULL, ");
	len += Format(query[len], sizeof(query) - len, "`is_active` INTEGER NOT NULL DEFAULT 1");
	len += Format(query[len], sizeof(query) - len, ")");

	if (!SQL_FastQuery(g_hSQLiteDB, query))
	{
		char error[256];
		SQL_GetError(g_hSQLiteDB, error, sizeof(error));
		CVBLog.SQLite("Failed to create SQLite table `%s`: %s", TABLE_BANS, error);
		return;
	}

	Format(query, sizeof(query), "CREATE INDEX IF NOT EXISTS `idx_sqlite_account_active` ON `%s`(`account_id`, `is_active`, `expires_timestamp`)", TABLE_BANS);
	if (!SQL_FastQuery(g_hSQLiteDB, query))
	{
		char error[256];
		SQL_GetError(g_hSQLiteDB, error, sizeof(error));
		CVBLog.SQLite("Failed to create SQLite index idx_sqlite_account_active: %s", error);
	}

	Format(query, sizeof(query), "CREATE INDEX IF NOT EXISTS `idx_sqlite_expires` ON `%s`(`expires_timestamp`, `is_active`)", TABLE_BANS);
	if (!SQL_FastQuery(g_hSQLiteDB, query))
	{
		char error[256];
		SQL_GetError(g_hSQLiteDB, error, sizeof(error));
		CVBLog.SQLite("Failed to create SQLite index idx_sqlite_expires: %s", error);
	}

	Format(query, sizeof(query), "CREATE INDEX IF NOT EXISTS `idx_sqlite_admin` ON `%s`(`admin_account_id`)", TABLE_BANS);
	if (!SQL_FastQuery(g_hSQLiteDB, query))
	{
		char error[256];
		SQL_GetError(g_hSQLiteDB, error, sizeof(error));
		CVBLog.SQLite("Failed to create SQLite index idx_sqlite_admin: %s", error);
	}
}
