/*****************************************************************
			C V B   L O G G E R   S Y S T E M
*****************************************************************/

/**
 * Enumeration for different log categories
 */
enum CVBLogCategory
{
	CVBLog_Debug	 = 0,	 // General debug information
	CVBLog_SQL		 = 1,	 // Generic SQL operations
	CVBLog_MySQL	 = 2,	 // MySQL-specific operations
	CVBLog_SQLite	 = 3,	 // SQLite-specific operations
	CVBLog_StringMap = 4	 // StringMap cache operations
}

/**
 * Modern logging system using methodmap
 * Maintains the same macro-based optimization philosophy
 */
methodmap CVBLog
{
	/**
	 * Internal method to format and write log message
	 *
	 * @param category    Log category for prefix formatting
	 * @param message     Format string for the message
	 * @param args        Variable arguments for formatting
	 */
public 	static void WriteLog(CVBLogCategory category, const char[] message, any...)
	{
		static char sFormat[1024];
		static char sPrefix[32];

		VFormat(sFormat, sizeof(sFormat), message, 3);

		switch (category)
		{
			case CVBLog_Debug: strcopy(sPrefix, sizeof(sPrefix), "[CVB][Debug]");
			case CVBLog_SQL: strcopy(sPrefix, sizeof(sPrefix), "[CVB][SQL]");
			case CVBLog_MySQL: strcopy(sPrefix, sizeof(sPrefix), "[CVB][MySQL]");
			case CVBLog_SQLite: strcopy(sPrefix, sizeof(sPrefix), "[CVB][SQLite]");
			case CVBLog_StringMap: strcopy(sPrefix, sizeof(sPrefix), "[CVB][StringMap]");
			default: strcopy(sPrefix, sizeof(sPrefix), "[CVB][Unknown]");
		}

		LogToFileEx(g_sLogPath, "%s %s", sPrefix, sFormat);
	}

/**
 * Logs debug information with timestamp
 * Only compiled when DEBUG macro is enabled
 *
 * @param message    Format string for the debug message
 * @param ...        Additional arguments for formatting
 */
#if DEBUG

public 	static void Debug(const char[] message, any...)
	{
		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		CVBLog.WriteLog(CVBLog_Debug, sFormat);
	}
#else

public 	static void Debug(const char[] message, any...) {}
#endif

/**
 * Logs SQL-related information
 * Only compiled when DEBUG_SQL macro is enabled
 *
 * @param message    Format string for the SQL message
 * @param ...        Additional arguments for formatting
 */
#if DEBUG && DEBUG_SQL

public 	static void SQL(const char[] message, any...)
	{
		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		CVBLog.WriteLog(CVBLog_SQL, sFormat);
	}
#else

public 	static void SQL(const char[] message, any...) {}
#endif

/**
 * Logs MySQL-specific information
 * Only compiled when DEBUG_MYSQL macro is enabled
 *
 * @param message    Format string for the MySQL message
 * @param ...        Additional arguments for formatting
 */
#if DEBUG && DEBUG_MYSQL

public 	static void MySQL(const char[] message, any...)
	{
		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		CVBLog.WriteLog(CVBLog_MySQL, sFormat);
	}
#else

public 	static void MySQL(const char[] message, any...) {}
#endif

/**
 * Logs SQLite-specific information
 * Only compiled when DEBUG_SQLITE macro is enabled
 *
 * @param message    Format string for the SQLite message
 * @param ...        Additional arguments for formatting
 */
#if DEBUG && DEBUG_SQLITE

public 	static void SQLite(const char[] message, any...)
	{
		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		CVBLog.WriteLog(CVBLog_SQLite, sFormat);
	}
#else

public 	static void SQLite(const char[] message, any...) {}
#endif

/**
 * Logs StringMap cache-related information
 * Only compiled when DEBUG_STRINGMAP macro is enabled
 *
 * @param message    Format string for the StringMap message
 * @param ...        Additional arguments for formatting
 */
#if DEBUG && DEBUG_STRINGMAP

public 	static void StringMap(const char[] message, any...)
	{
		static char sFormat[1024];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		CVBLog.WriteLog(CVBLog_StringMap, sFormat);
	}
#else

public 	static void StringMap(const char[] message, any...) {}
#endif
}
