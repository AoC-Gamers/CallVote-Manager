#if defined _cvb_commands_debug_included
	#endinput
#endif
#define _cvb_commands_debug_included

#define TEST_GABE_ACCOUNTID 22202

Action Command_DebugMySQL(int client, int args)
{
	if (g_hMySQLDB == null)
	{
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseConnectionNotAvailable");
		return Plugin_Handled;
	}

	CReplyToCommand(client, "%t Starting MySQL stored procedures test...", "Tag");
	CVBLog.Debug("Admin %N initiated MySQL stored procedures test", client);

	int testAccountId;
	
	if (args >= 1)
	{
		testAccountId = GetCmdArgInt(1);
		
		if (testAccountId <= 0)
		{
			CReplyToCommand(client, "%t Invalid AccountID provided. Using default test AccountID.", "Tag");
			testAccountId = TEST_GABE_ACCOUNTID;
		}
		else
			CReplyToCommand(client, "%t Using provided AccountID: %d", "Tag", testAccountId);
	}
	else
	{
		if (client == SERVER_INDEX)
		{
			testAccountId = TEST_GABE_ACCOUNTID;
			CReplyToCommand(client, "%t Console execution - Using default test AccountID: %d", "Tag", testAccountId);
		}
		else
		{
			testAccountId = TEST_GABE_ACCOUNTID;
			CReplyToCommand(client, "%t No AccountID provided - Using default test AccountID: %d", "Tag", testAccountId);
		}
	}
	
	CReplyToCommand(client, "%t Phase 1: Testing sp_CheckActiveBan (should be no ban)", "Tag");
	TestMySQLCheckActiveBan(client, testAccountId);
	
	return Plugin_Handled;
}

/**
 * Test MySQL sp_CheckActiveBan procedure
 */
void TestMySQLCheckActiveBan(int client, int accountId)
{
	char query[512];
	Format(query, sizeof(query), "CALL sp_CheckActiveBan(%d)", accountId);
	
	DataPack pack = new DataPack();
	pack.WriteCell((client == SERVER_INDEX) ? SERVER_INDEX : GetClientUserId(client));
	pack.WriteCell(accountId);
	pack.WriteCell(1);
	
	CVBLog.Debug("Executing MySQL query: %s", query);
	g_hMySQLDB.Query(MySQL_TestCallback, query, pack);
}

/**
 * Test MySQL sp_InsertBanWithValidation procedure
 */
void TestMySQLInsertBan(int client, int accountId, int adminAccountId)
{
	char query[1024];
	char reason[256] = "Test ban from debug command";
	
	Format(query, sizeof(query), "CALL sp_InsertBanWithValidation(%d, 4, 60, %d, '%s')", accountId, adminAccountId, reason);
	
	DataPack pack = new DataPack();
	pack.WriteCell((client == SERVER_INDEX) ? SERVER_INDEX : GetClientUserId(client));
	pack.WriteCell(accountId);
	pack.WriteCell(2);
	
	CVBLog.Debug("Executing MySQL query: %s", query);
	g_hMySQLDB.Query(MySQL_TestCallback, query, pack);
}

/**
 * Test MySQL sp_CheckFullBan procedure
 */
void TestMySQLCheckFullBan(int client, int accountId)
{
	char query[1024];
	Format(query, sizeof(query), "CALL sp_CheckFullBan(%d)", accountId);
	
	DataPack pack = new DataPack();
	pack.WriteCell((client == SERVER_INDEX) ? SERVER_INDEX : GetClientUserId(client));
	pack.WriteCell(accountId);
	pack.WriteCell(3);
	
	CVBLog.Debug("Executing MySQL query: %s", query);
	g_hMySQLDB.Query(MySQL_TestCallback, query, pack);
}

/**
 * Test MySQL sp_RemoveBan procedure
 */
void TestMySQLRemoveBan(int client, int accountId, int adminAccountId)
{
	char query[512];
	Format(query, sizeof(query), "CALL sp_RemoveBan(%d, %d)", accountId, adminAccountId);
	
	DataPack pack = new DataPack();
	pack.WriteCell((client == SERVER_INDEX) ? SERVER_INDEX : GetClientUserId(client));
	pack.WriteCell(accountId);
	pack.WriteCell(4);
	
	CVBLog.Debug("Executing MySQL query: %s", query);
	g_hMySQLDB.Query(MySQL_TestCallback, query, pack);
}

/**
 * Test MySQL sp_CleanExpiredBans procedure
 */
void TestMySQLCleanExpiredBans(int client)
{
	char query[512];
	Format(query, sizeof(query), "CALL sp_CleanExpiredBans(100)");
	
	DataPack pack = new DataPack();
	pack.WriteCell((client == SERVER_INDEX) ? SERVER_INDEX : GetClientUserId(client));
	pack.WriteCell(0);
	pack.WriteCell(5);
	
	CVBLog.Debug("Executing MySQL query: %s", query);
	g_hMySQLDB.Query(MySQL_TestCallback, query, pack);
}

/**
 * Test MySQL sp_GetBanStatistics procedure
 */
void TestMySQLGetStatistics(int client)
{
	char query[256];
	Format(query, sizeof(query), "CALL sp_GetBanStatistics(30)");
	
	DataPack pack = new DataPack();
	pack.WriteCell((client == SERVER_INDEX) ? SERVER_INDEX : GetClientUserId(client));
	pack.WriteCell(0);
	pack.WriteCell(6);
	
	CVBLog.Debug("Executing MySQL query: %s", query);
	g_hMySQLDB.Query(MySQL_TestCallback, query, pack);
}

/**
 * Callback for MySQL stored procedures testing
 */
void MySQL_TestCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int userId = pack.ReadCell();
	int accountId = pack.ReadCell();
	int phase = pack.ReadCell();
	delete pack;
	
	int client = GetClientOfUserId(userId);

	if (client < 0 || (client == SERVER_INDEX && userId != 0))
	{
		LogError("Client disconnected during MySQL test (userId: %d)", userId);
		return;
	}
	
	if (results == null)
	{
		CReplyToCommand(client, "%t MySQL test phase %d failed: %s", "Tag", phase, error);
		LogError("MySQL test phase %d failed: %s", phase, error);
		return;
	}
	
	if (error[0])
	{
		CVBLog.Debug("MySQL phase %d warning: %s", phase, error);
	}
	
	switch (phase)
	{
		case 1:
		{
			if (results.FetchRow())
			{
				int banType = results.FetchInt(0);
				CReplyToCommand(client, "%t Phase 1 completed - Ban Type: %d (0 = no ban)", "Tag", banType);
				CVBLog.Debug("Phase 1: sp_CheckActiveBan returned ban_type = %d", banType);
				
				int adminAccountId;
				if (client == SERVER_INDEX)
				{
					adminAccountId = 76561198000000001;
				}
				else
				{
					adminAccountId = GetSteamAccountID(client);
				}
				
				CReplyToCommand(client, "%t Phase 2: Testing sp_InsertBanWithValidation", "Tag");
				TestMySQLInsertBan(client, accountId, adminAccountId);
			}
			else
			{
				CReplyToCommand(client, "%t Phase 1: No result from ban type check", "Tag");
			}
		}
		case 2:
		{
			if (results.FetchRow())
			{
				int banId = results.FetchInt(0);
				int resultCode = results.FetchInt(1);
				char message[256];
				results.FetchString(2, message, sizeof(message));
				
				CReplyToCommand(client, "%t Phase 2 completed - Result: %d, Ban ID: %d", "Tag", resultCode, banId);
				CReplyToCommand(client, "%t Message: %s", "Tag", message);
				CVBLog.Debug("Phase 2: sp_InsertBanWithValidation - Code: %d, ID: %d, Message: %s", resultCode, banId, message);
				
				CReplyToCommand(client, "%t Phase 3: Testing sp_CheckFullBan", "Tag");
				TestMySQLCheckFullBan(client, accountId);
			}
			else
			{
				CReplyToCommand(client, "%t Phase 2: No result from insert ban", "Tag");
			}
		}
		case 3:
		{
			if (results.FetchRow())
			{
				int hasBan = results.FetchInt(0);
				int banType = results.FetchInt(1);
				int expires = results.FetchInt(2);
				int created = results.FetchInt(3);
				int duration = results.FetchInt(4);

				char reason[256];
				results.FetchString(6, reason, sizeof(reason));
				int banId = results.FetchInt(7);
				
				CReplyToCommand(client, "%t Phase 3 completed - Has Ban: %d, Type: %d, ID: %d", "Tag", hasBan, banType, banId);
				CReplyToCommand(client, "%t Duration: %d mins, Created: %d, Expires: %d", "Tag", duration, created, expires);
				CVBLog.Debug("Phase 3: sp_CheckFullBan - Has: %d, Type: %d, Duration: %d, Reason: %s", hasBan, banType, duration, reason);
				
				int adminAccountId;
				if (client == SERVER_INDEX)
				{
					adminAccountId = 76561198000000001;
				}
				else
				{
					adminAccountId = GetSteamAccountID(client);
				}
				
				CReplyToCommand(client, "%t Phase 4: Testing sp_RemoveBan", "Tag");
				TestMySQLRemoveBan(client, accountId, adminAccountId);
			}
			else
			{
				CReplyToCommand(client, "%t Phase 3: No result from check full ban", "Tag");
			}
		}
		case 4:
		{
			if (results.FetchRow())
			{
				int resultCode = results.FetchInt(0);
				char message[256];
				results.FetchString(1, message, sizeof(message));
				bool isNull = results.IsFieldNull(2);
				int removedBanId = 0;

				if (!isNull)
					removedBanId = results.FetchInt(2);
				
				CReplyToCommand(client, "%t Phase 4 completed - Result: %d, Removed Ban ID: %d", "Tag", resultCode, removedBanId);
				CReplyToCommand(client, "%t Message: %s", "Tag", message);
				CVBLog.Debug("Phase 4: sp_RemoveBan - Code: %d, Removed ID: %d, Message: %s", resultCode, removedBanId, message);
				
				CReplyToCommand(client, "%t Phase 5: Testing sp_CleanExpiredBans", "Tag");
				TestMySQLCleanExpiredBans(client);
			}
			else
				CReplyToCommand(client, "%t Phase 4: No result from remove ban", "Tag");
		}
		case 5:
		{
			if (results.FetchRow())
			{
				int cleanedCount = results.FetchInt(0);
				int resultCode = results.FetchInt(1);
				char message[256];
				results.FetchString(2, message, sizeof(message));
				
				CReplyToCommand(client, "%t Phase 5 completed - Cleaned: %d bans, Result: %d", "Tag", cleanedCount, resultCode);
				CReplyToCommand(client, "%t Message: %s", "Tag", message);
				CVBLog.Debug("Phase 5: sp_CleanExpiredBans - Cleaned: %d, Code: %d, Message: %s", cleanedCount, resultCode, message);
				
				CReplyToCommand(client, "%t Phase 6: Testing sp_GetBanStatistics", "Tag");
				TestMySQLGetStatistics(client);
			}
			else
				CReplyToCommand(client, "%t ❌ Phase 5: No result from clean expired bans", "Tag");
		}
		case 6:
		{
			if (results.FetchRow())
			{
				int activeBans = results.FetchInt(0);
				int expiredBans = results.FetchInt(1);
				int recentBans = results.FetchInt(2);
				int uniquePlayers = results.FetchInt(3);
				int uniqueAdmins = results.FetchInt(4);
				
				CReplyToCommand(client, "%t Phase 6 completed - Statistics retrieved:", "Tag");
				CReplyToCommand(client, "%t Active: %d | Expired: %d | Recent: %d | Players: %d | Admins: %d", "Tag", activeBans, expiredBans, recentBans, uniquePlayers, uniqueAdmins);
				CVBLog.Debug("Statistics: Active=%d, Expired=%d, Recent=%d, Players=%d, Admins=%d", activeBans, expiredBans, recentBans, uniquePlayers, uniqueAdmins);
			}
			
			CReplyToCommand(client, "%t 🎉 MySQL stored procedures test completed successfully!", "Tag");
			CVBLog.Debug("MySQL stored procedures test completed for admin %N", client);
		}
	}
}

/**
 * Debug command to test all SQLite cache operations
 * Usage: sm_cvb_debug_sqlite [AccountID]
 * - AccountID: Optional. Account ID to test with. If not provided or invalid, uses TEST_GABE_ACCOUNTID
 */
Action Command_DebugSQLite(int client, int args)
{
	if (g_hSQLiteDB == null)
	{
		CReplyToCommand(client, "%t %t", "Tag", "SQLiteConnectionNotAvailable");
		return Plugin_Handled;
	}

	CReplyToCommand(client, "%t Starting SQLite operations test...", "Tag");
	CVBLog.Debug("Admin %N initiated SQLite operations test", client);

	int testAccountId;
	
	if (args >= 1)
	{
		char arg[32];
		GetCmdArg(1, arg, sizeof(arg));
		testAccountId = StringToInt(arg);
		
		if (testAccountId <= 0)
		{
			CReplyToCommand(client, "%t Invalid AccountID provided. Using default test AccountID.", "Tag");
			testAccountId = TEST_GABE_ACCOUNTID;
		}
		else
			CReplyToCommand(client, "%t Using provided AccountID: %d", "Tag", testAccountId);

	}
	else
	{
		testAccountId = TEST_GABE_ACCOUNTID;
		CReplyToCommand(client, "%t No AccountID provided - Using default test AccountID: %d", "Tag", testAccountId);
	}
	
	CReplyToCommand(client, "%t Phase 1: Testing SQLite cache lookup", "Tag");
	TestSQLiteCacheCheck(client, testAccountId);
	
	return Plugin_Handled;
}

/**
 * Test SQLite cache lookup
 */
void TestSQLiteCacheCheck(int client, int accountId)
{
	char query[512];
	int iLen = 0;
	
	iLen += Format(query[iLen], sizeof(query) - iLen, "SELECT account_id, ban_type, cached_timestamp, ttl_expires ");
	iLen += Format(query[iLen], sizeof(query) - iLen, "FROM callvote_bans_cache WHERE account_id = %d ", accountId);
	iLen += Format(query[iLen], sizeof(query) - iLen, "AND (ttl_expires = 0 OR ttl_expires > %d) LIMIT 1;", GetTime());
	
	DataPack pack = new DataPack();
	pack.WriteCell((client == SERVER_INDEX) ? SERVER_INDEX : GetClientUserId(client));
	pack.WriteCell(accountId);
	pack.WriteCell(1);
	
	CVBLog.Debug("Executing SQLite query: %s", query);
	g_hSQLiteDB.Query(SQLite_TestCallback, query, pack);
}

/**
 * Test SQLite cache insertion
 */
void TestSQLiteCacheInsert(int client, int accountId)
{
	char query[512];
	int iLen = 0;
	int currentTime = GetTime();
	int ttlExpires = currentTime + 86400;
	
	iLen += Format(query[iLen], sizeof(query) - iLen, "INSERT OR REPLACE INTO callvote_bans_cache ");
	iLen += Format(query[iLen], sizeof(query) - iLen, "(account_id, ban_type, cached_timestamp, ttl_expires) ");
	iLen += Format(query[iLen], sizeof(query) - iLen, "VALUES (%d, 4, %d, %d);", accountId, currentTime, ttlExpires);
	
	DataPack pack = new DataPack();
	pack.WriteCell((client == SERVER_INDEX) ? SERVER_INDEX : GetClientUserId(client));
	pack.WriteCell(accountId);
	pack.WriteCell(2);
	
	CVBLog.Debug("Executing SQLite query: %s", query);
	g_hSQLiteDB.Query(SQLite_TestCallback, query, pack);
}

/**
 * Test SQLite cache verification after insert
 */
void TestSQLiteCacheVerify(int client, int accountId)
{
	char query[512];
	int iLen = 0;
	
	iLen += Format(query[iLen], sizeof(query) - iLen, "SELECT account_id, ban_type, cached_timestamp, ttl_expires ");
	iLen += Format(query[iLen], sizeof(query) - iLen, "FROM callvote_bans_cache WHERE account_id = %d ", accountId);
	iLen += Format(query[iLen], sizeof(query) - iLen, "AND (ttl_expires = 0 OR ttl_expires > %d) LIMIT 1;", GetTime());
	
	DataPack pack = new DataPack();
	pack.WriteCell((client == SERVER_INDEX) ? SERVER_INDEX : GetClientUserId(client));
	pack.WriteCell(accountId);
	pack.WriteCell(3);
	
	CVBLog.Debug("Executing SQLite query: %s", query);
	g_hSQLiteDB.Query(SQLite_TestCallback, query, pack);
}

/**
 * Test SQLite cache removal
 */
void TestSQLiteCacheRemove(int client, int accountId)
{
	char query[256];
	int iLen = 0;
	
	iLen += Format(query[iLen], sizeof(query) - iLen, "DELETE FROM callvote_bans_cache ");
	iLen += Format(query[iLen], sizeof(query) - iLen, "WHERE account_id = %d;", accountId);
	
	DataPack pack = new DataPack();
	pack.WriteCell((client == SERVER_INDEX) ? SERVER_INDEX : GetClientUserId(client));
	pack.WriteCell(accountId);
	pack.WriteCell(4); // Phase 4
	
	CVBLog.Debug("Executing SQLite query: %s", query);
	g_hSQLiteDB.Query(SQLite_TestCallback, query, pack);
}

/**
 * Test SQLite statistics query
 */
void TestSQLiteStatistics(int client)
{
	char query[512];
	int iLen = 0;
	int currentTime = GetTime();
	
	iLen += Format(query[iLen], sizeof(query) - iLen, "SELECT ");
	iLen += Format(query[iLen], sizeof(query) - iLen, "COUNT(CASE WHEN ttl_expires = 0 OR ttl_expires > %d THEN 1 END) as active_cache, ", currentTime);
	iLen += Format(query[iLen], sizeof(query) - iLen, "COUNT(CASE WHEN ttl_expires > 0 AND ttl_expires <= %d THEN 1 END) as expired_cache, ", currentTime);
	iLen += Format(query[iLen], sizeof(query) - iLen, "COUNT(DISTINCT account_id) as unique_players, ");
	iLen += Format(query[iLen], sizeof(query) - iLen, "COUNT(*) as total_records ");
	iLen += Format(query[iLen], sizeof(query) - iLen, "FROM callvote_bans_cache;");
	
	DataPack pack = new DataPack();
	pack.WriteCell((client == SERVER_INDEX) ? SERVER_INDEX : GetClientUserId(client));
	pack.WriteCell(0);
	pack.WriteCell(5);
	
	CVBLog.Debug("Executing SQLite query: %s", query);
	g_hSQLiteDB.Query(SQLite_TestCallback, query, pack);
}

/**
 * Test SQLite TTL cleanup (Phase 6)
 */
void TestSQLiteTTLCleanup(int client)
{
	char query[256];
	int iLen = 0;
	
	iLen += Format(query[iLen], sizeof(query) - iLen, "DELETE FROM callvote_bans_cache ");
	iLen += Format(query[iLen], sizeof(query) - iLen, "WHERE ttl_expires > 0 AND ttl_expires <= %d;", GetTime());
	
	DataPack pack = new DataPack();
	pack.WriteCell((client == SERVER_INDEX) ? SERVER_INDEX : GetClientUserId(client));
	pack.WriteCell(0);
	pack.WriteCell(6);
	
	CVBLog.Debug("Executing SQLite query: %s", query);
	g_hSQLiteDB.Query(SQLite_TestCallback, query, pack);
}

/**
 * Callback for SQLite operations testing
 */
void SQLite_TestCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	int userId = pack.ReadCell();
	int accountId = pack.ReadCell();
	int phase = pack.ReadCell();
	delete pack;
	
	int client = GetClientOfUserId(userId);
	
	if (client < 0 || (client == SERVER_INDEX && userId != 0))
	{
		LogError("Client disconnected during SQLite test (userId: %d)", userId);
		return;
	}
	
	if (results == null || error[0])
	{
		CReplyToCommand(client, "%t SQLite test phase %d failed: %s", "Tag", phase, error);
		LogError("SQLite test phase %d failed: %s", phase, error);
		return;
	}
	
	switch (phase)
	{
		case 1:
		{
			if (results.FetchRow())
			{
				int foundAccountId = results.FetchInt(0);
				int banType = results.FetchInt(1);
				int cachedTime = results.FetchInt(2);
				int ttlExpires = results.FetchInt(3);
				
				CReplyToCommand(client, "%t Phase 1: Found existing cache - Account: %d, Type: %d", 
					"Tag", foundAccountId, banType);
				CReplyToCommand(client, "%t  Cached: %d, TTL Expires: %d", "Tag", cachedTime, ttlExpires);
				CVBLog.Debug("Phase 1: Found cache - Account: %d, Type: %d, TTL: %d", foundAccountId, banType, ttlExpires);
			}
			else
				CReplyToCommand(client, "%t Phase 1: No existing cache found (expected)", "Tag");
			
			CReplyToCommand(client, "%t Phase 2: Testing SQLite cache insertion", "Tag");
			TestSQLiteCacheInsert(client, accountId);
		}
		case 2:
		{
			CReplyToCommand(client, "%t Phase 2: Test cache entry inserted successfully", "Tag");
			CVBLog.Debug("Phase 2: SQLite test cache entry inserted for account %d", accountId);
			
			CReplyToCommand(client, "%t Phase 3: Testing SQLite cache verification", "Tag");
			TestSQLiteCacheVerify(client, accountId);
		}
		case 3:
		{
			if (results.FetchRow())
			{
				int foundAccountId = results.FetchInt(0);
				int banType = results.FetchInt(1);
				int cachedTime = results.FetchInt(2);
				int ttlExpires = results.FetchInt(3);
				
				CReplyToCommand(client, "%t Phase 3: Cache verified - Account: %d, Type: %d", "Tag", foundAccountId, banType);
				CReplyToCommand(client, "%t  Cached: %d, TTL Expires: %d", "Tag", cachedTime, ttlExpires);
				CVBLog.Debug("Phase 3: SQLite cache verified - Account: %d, Type: %d, TTL: %d", foundAccountId, banType, ttlExpires);
			}
			else
				CReplyToCommand(client, "%t Phase 3: Cache not found after insertion (unexpected)", "Tag");
			
			CReplyToCommand(client, "%t Phase 4: Testing SQLite cache removal", "Tag");
			TestSQLiteCacheRemove(client, accountId);
		}
		case 4:
		{
			CReplyToCommand(client, "%t Phase 4: Test cache entry removed successfully", "Tag");
			CVBLog.Debug("Phase 4: SQLite test cache entry removed for account %d", accountId);

			CReplyToCommand(client, "%t Phase 5: Testing SQLite statistics query", "Tag");
			TestSQLiteStatistics(client);
		}
		case 5:
		{
			if (results.FetchRow())
			{
				int activeCache = results.FetchInt(0);
				int expiredCache = results.FetchInt(1);
				int uniquePlayers = results.FetchInt(2);
				int totalRecords = results.FetchInt(3);
				
				CReplyToCommand(client, "%t Phase 5: SQLite cache statistics retrieved:", "Tag");
				CReplyToCommand(client, "%t Active Cache: %d | Expired Cache: %d | Players: %d | Total: %d", "Tag", activeCache, expiredCache, uniquePlayers, totalRecords);
				CVBLog.Debug("SQLite Cache Statistics: Active=%d, Expired=%d, Players=%d, Total=%d", activeCache, expiredCache, uniquePlayers, totalRecords);
			}
			
			CReplyToCommand(client, "%t Phase 6: Testing SQLite TTL cleanup", "Tag");
			TestSQLiteTTLCleanup(client);
		}
		case 6:
		{
			CReplyToCommand(client, "%t Phase 6: TTL cleanup completed", "Tag");
			CVBLog.Debug("Phase 6: SQLite TTL cleanup completed");
			
			CReplyToCommand(client, "%t SQLite cache operations test completed successfully!", "Tag");
			CVBLog.Debug("SQLite cache operations test completed for admin %N", client);
		}
	}
}

/**
 * Comando para verificar directamente el procedimiento sp_CheckFullBan
 */
Action Command_DebugCheckFullBan(int client, int args)
{
	if (g_hMySQLDB == null)
	{
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseConnectionNotAvailable");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CReplyToCommand(client, "%t Usage: sm_cvb_debug_checkfullban <AccountID>", "Tag");
		return Plugin_Handled;
	}

	int accountId = GetCmdArgInt(1);
	if (accountId <= 0)
	{
		CReplyToCommand(client, "%t Invalid AccountID provided", "Tag");
		return Plugin_Handled;
	}

	CReplyToCommand(client, "%t Verificando procedimiento sp_CheckFullBan para AccountID: %d", "Tag", accountId);
	
	char query[512];
	FormatEx(query, sizeof(query), "CALL %s(%d)", PROCEDURE_CHECK_FULL_BAN, accountId);
	
	CVBLog.Debug("Admin %N executing debug query: %s", client, query);
	
	DataPack dp = new DataPack();
	dp.WriteCell(GetClientUserId(client));
	dp.WriteCell(accountId);
	
	SQL_TQuery(g_hMySQLDB, DebugCheckFullBan_Callback, query, dp);
	
	return Plugin_Handled;
}

/**
 * Callback para mostrar los resultados del procedimiento sp_CheckFullBan
 */
void DebugCheckFullBan_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();
	int adminUserId = dp.ReadCell();
	int accountId = dp.ReadCell();
	delete dp;
	
	int admin = GetClientOfUserId(adminUserId);
	if (admin <= 0)
	{
		CVBLog.Debug("Admin disconnected during debug query");
		return;
	}
	
	if (results == null)
	{
		CReplyToCommand(admin, "%t ERROR en sp_CheckFullBan: %s", "Tag", error);
		CVBLog.Debug("Error in sp_CheckFullBan debug: %s", error);
		return;
	}
	
	if (!results.FetchRow())
	{
		CReplyToCommand(admin, "%t sp_CheckFullBan: No hay ban activo para AccountID %d", "Tag", accountId);
		CVBLog.Debug("sp_CheckFullBan: No active ban for AccountID %d", accountId);
		return;
	}

	int fieldCount = results.FieldCount;
	CReplyToCommand(admin, "%t === RESULTADOS sp_CheckFullBan ===", "Tag");
	CReplyToCommand(admin, "%t AccountID: %d", "Tag", accountId);
	CReplyToCommand(admin, "%t Campos devueltos: %d", "Tag", fieldCount);
	
	for (int i = 0; i < fieldCount; i++)
	{
		char fieldName[64];
		results.FieldNumToName(i, fieldName, sizeof(fieldName));
		
		if (results.IsFieldNull(i))
			CReplyToCommand(admin, "%t Campo %d (%s): NULL", "Tag", i, fieldName);
		else
		{
			int intValue = results.FetchInt(i);
			CReplyToCommand(admin, "%t Campo %d (%s): %d", "Tag", i, fieldName, intValue);
		}
	}
	
	CReplyToCommand(admin, "%t === FIN RESULTADOS ===", "Tag");
}

/**
 * Comando para verificar directamente los datos en la tabla MySQL
 */
Action Command_DebugMySQLTable(int client, int args)
{
	if (g_hMySQLDB == null)
	{
		CReplyToCommand(client, "%t %t", "Tag", "DatabaseConnectionNotAvailable");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CReplyToCommand(client, "%t Usage: sm_cvb_debug_table <AccountID>", "Tag");
		return Plugin_Handled;
	}

	int accountId = GetCmdArgInt(1);
	if (accountId <= 0)
	{
		CReplyToCommand(client, "%t Invalid AccountID provided", "Tag");
		return Plugin_Handled;
	}

	CReplyToCommand(client, "%t Verificando tabla MySQL para AccountID: %d", "Tag", accountId);
	
	char query[512];
	FormatEx(query, sizeof(query), "SELECT id, ban_type, created_timestamp, duration_minutes, expires_timestamp, is_active, admin_account_id, reason FROM callvote_bans WHERE account_id = %d ORDER BY created_timestamp DESC LIMIT 5", accountId);
	
	CVBLog.Debug("Admin %N executing table debug query: %s", client, query);
	
	DataPack dp = new DataPack();
	dp.WriteCell(GetClientUserId(client));
	dp.WriteCell(accountId);
	
	SQL_TQuery(g_hMySQLDB, DebugMySQLTable_Callback, query, dp);
	
	return Plugin_Handled;
}

/**
 * Callback para mostrar los resultados de la tabla MySQL
 */
void DebugMySQLTable_Callback(Database db, DBResultSet results, const char[] error, DataPack dp)
{
	dp.Reset();
	int adminUserId = dp.ReadCell();
	int accountId = dp.ReadCell();
	delete dp;
	
	int admin = GetClientOfUserId(adminUserId);
	if (admin <= 0)
	{
		CVBLog.Debug("Admin disconnected during table debug query");
		return;
	}
	
	if (results == null)
	{
		CReplyToCommand(admin, "%t ERROR en consulta MySQL: %s", "Tag", error);
		CVBLog.Debug("Error in MySQL table debug: %s", error);
		return;
	}
	
	CReplyToCommand(admin, "%t === DATOS TABLA callvote_bans ===", "Tag");
	CReplyToCommand(admin, "%t AccountID: %d", "Tag", accountId);
	
	int rowCount = 0;
	while (results.FetchRow())
	{
		rowCount++;
		int banId = results.FetchInt(0);
		int banType = results.FetchInt(1);
		int createdTimestamp = results.FetchInt(2);
		int durationMinutes = results.FetchInt(3);
		int expiresTimestamp = results.FetchInt(4);
		int isActive = results.FetchInt(5);
		int adminAccountId = results.FetchInt(6);
		
		char reason[256];
		results.FetchString(7, reason, sizeof(reason));
		
		char banTypeStr[256];
		GetBanTypeString(banType, banTypeStr, sizeof(banTypeStr));
		
		char createdTime[64], expiresTime[64];
		FormatTime(createdTime, sizeof(createdTime), "%Y-%m-%d %H:%M:%S", createdTimestamp);

		if (expiresTimestamp > 0)
			FormatTime(expiresTime, sizeof(expiresTime), "%Y-%m-%d %H:%M:%S", expiresTimestamp);
		else
			strcopy(expiresTime, sizeof(expiresTime), "Permanente");
		
		CReplyToCommand(admin, "%t --- Ban #%d ---", "Tag", rowCount);
		CReplyToCommand(admin, "%t BanID: %d | BanType: %d (%s)", "Tag", banId, banType, banTypeStr);
		CReplyToCommand(admin, "%t Activo: %s | Creado: %s", "Tag", isActive ? "SI" : "NO", createdTime);
		CReplyToCommand(admin, "%t Expira: %s | Admin: %d", "Tag", expiresTime, adminAccountId);
		CReplyToCommand(admin, "%t Duración: %d min | Razón: %s", "Tag", durationMinutes, reason);
	}
	
	if (rowCount == 0)
		CReplyToCommand(admin, "%t No se encontraron bans para este AccountID", "Tag");
	else
		CReplyToCommand(admin, "%t Total de bans encontrados: %d", "Tag", rowCount);
	
	CReplyToCommand(admin, "%t === FIN DATOS TABLA ===", "Tag");
}