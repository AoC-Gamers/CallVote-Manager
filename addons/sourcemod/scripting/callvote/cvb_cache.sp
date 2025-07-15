#if defined _cvb_cache_included
	#endinput
#endif
#define _cvb_cache_included

/**
 * Cache system initialization
 */
void InitCache()
{
	if (g_hCacheStringMap != null)
		delete g_hCacheStringMap;
	
	if (g_hPlayerBans != null)
		delete g_hPlayerBans;
	
	g_hCacheStringMap = new StringMap();
	g_hPlayerBans = new StringMap();
	
	CVBLog.StringMap("Cache system initialized");
}

bool CheckStringMapCache(int accountId)
{
	if (!g_cvarStringMapCache.BoolValue)
		return false;
	
	char sAccountId[16];
	IntToString(accountId, sAccountId, sizeof(sAccountId));
	
	int dummy;
	if (g_hCacheStringMap.GetValue(sAccountId, dummy))
	{
		CVBLog.StringMap("StringMap cache HIT for AccountID %d", accountId);
		return true;
	}
	
	CVBLog.StringMap("StringMap cache MISS for AccountID %d", accountId);
	return false;
}

void UpdateStringMapCache(int accountId, bool hasBan, int banType = 0)
{
	char sAccountId[16];
	IntToString(accountId, sAccountId, sizeof(sAccountId));
	
	if (hasBan)
	{
		g_hCacheStringMap.Remove(sAccountId);
		
		g_hPlayerBans.SetValue(sAccountId, banType);
		
		CVBLog.StringMap("AccountID %d added to banned cache (type: %d)", accountId, banType);
	}
	else
	{
		g_hCacheStringMap.SetValue(sAccountId, 1);
		
		g_hPlayerBans.Remove(sAccountId);
		
		CVBLog.StringMap("AccountID %d added to non-banned cache", accountId);
	}
}

int GetCachedBanType(int accountId)
{
	char sAccountId[16];
	IntToString(accountId, sAccountId, sizeof(sAccountId));
	
	int banType;
	if (g_hPlayerBans.GetValue(sAccountId, banType))
	{
		return banType;
	}
	
	return 0;
}


/**
 * Checks the SQLite cache for a ban entry associated with the given account ID.
 *
 * This function queries the SQLite cache table for a ban entry matching the specified account ID.
 * If a valid, non-expired cache entry is found, the ban type is returned via the reference parameter,
 * and the function returns true. If the cache entry is expired, it is removed and a re-check with MySQL
 * may be triggered. If no entry is found or an error occurs, the function returns false.
 *
 * @param accountId      The account ID to check in the cache.
 * @param banType        Reference to an integer where the ban type will be stored if a cache hit occurs.
 * @return               True if a valid cache entry is found, false otherwise.
 */
bool CheckSQLiteCache(int accountId, int &banType)
{
	if (!g_cvarSQLiteCache.BoolValue || g_hSQLiteDB == null)
		return false;
	
	char sQuery[512];
	int iLen = 0;
	
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "SELECT ban_type, cached_timestamp ");
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "FROM %s WHERE account_id = %d ", TABLE_CACHE_BANS, accountId);
	iLen += Format(sQuery[iLen], sizeof(sQuery) - iLen, "AND (ttl_expires = 0 OR ttl_expires > %d)", GetTime());

	CVBLog.SQLite("Executing SQLite cache query: %s", sQuery);
	DBResultSet results = SQL_Query(g_hSQLiteDB, sQuery);
	
	if (results == null)
	{
		char sError[256];
		SQL_GetError(g_hSQLiteDB, sError, sizeof(sError));
		CVBLog.SQLite("Error in SQLite cache query: %s", sError);
		return false;
	}
	
	if (results.FetchRow())
	{
		banType = results.FetchInt(0);
		int cachedTimestamp = results.FetchInt(1);
		
		delete results;
		
		int sqliteTTLSeconds = g_cvarSQLiteTTLMinutes.IntValue * 60;
		if (GetTime() - cachedTimestamp < sqliteTTLSeconds)
		{
			CVBLog.SQLite("SQLite cache HIT for AccountID %d (type: %d)", accountId, banType);
			return true;
		}
		else
		{
			CVBLog.SQLite("SQLite cache EXPIRED for AccountID %d - removing entry", accountId);
			RemoveExpiredCacheEntry(accountId);
			
			if (g_hMySQLDB != null)
			{
				int client = FindClientByAccountID(accountId);
				if (client > 0)
				{
					CVBLog.SQLite("Re-checking with MySQL for AccountID %d", accountId);
					CVB_CheckActiveBan(accountId, client);
				}
			}
			return false;
		}
	}
	
	delete results;
	CVBLog.SQLite("SQLite cache MISS for AccountID %d", accountId);
	return false;
}

bool IsPlayerBanned(int accountId, TypeVotes voteType)
{
	if (CheckStringMapCache(accountId))
	{
		return false;
	}
	
	int cachedBanType = GetCachedBanType(accountId);
	if (cachedBanType > 0)
	{
		return IsVoteTypeBanned(cachedBanType, voteType);
	}
	
	int sqliteBanType;
	if (CheckSQLiteCache(accountId, sqliteBanType))
	{
		UpdateStringMapCache(accountId, true, sqliteBanType);
		return IsVoteTypeBanned(sqliteBanType, voteType);
	}
	
	int client = FindClientByAccountID(accountId);
	if (client > SERVER_INDEX && IsValidClientIndex(client))
	{
		if (g_PlayerBans[client].isLoaded)
		{
			if (g_PlayerBans[client].banType > 0)
			{
				return IsVoteTypeBanned(g_PlayerBans[client].banType, voteType);
			}
			else
			{
				UpdateStringMapCache(accountId, false, 0);
				return false;
			}
		}
		
		if (!g_PlayerBans[client].isChecking)
		{
			g_PlayerBans[client].isChecking = true;
			CVB_CheckActiveBan(accountId, client);
		}
	}
	
	return false;
}

void RemoveExpiredCacheEntry(int accountId)
{
	if (g_hSQLiteDB == null)
		return;
		
	char sQuery[256];
	Format(sQuery, sizeof(sQuery), "DELETE FROM callvote_bans_cache WHERE account_id = %d", accountId);
	
	if (SQL_FastQuery(g_hSQLiteDB, sQuery))
	{
		CVBLog.SQLite("Removed expired cache entry for AccountID %d", accountId);
	}
	else
	{
		char sError[256];
		SQL_GetError(g_hSQLiteDB, sError, sizeof(sError));
		CVBLog.SQLite("Error removing expired entry: %s", sError);
	}
}

void OnClientCacheConnect(int client)
{
	if (!IsValidClient(client))
		return;
	
	int accountId = GetSteamAccountID(client);
	if (accountId == 0)
		return;
	
	g_PlayerBans[client].accountId = accountId;
	g_PlayerBans[client].banType = 0;
	g_PlayerBans[client].isLoaded = false;
	g_PlayerBans[client].isChecking = false;

	CVB_CheckActiveBan(accountId, client);
	
	CVBLog.StringMap("Starting ban check for %N (AccountID: %d)", client, accountId);
}

void OnClientCacheDisconnect(int client)
{
	if (!IsValidClientIndex(client) || IsFakeClient(client))
		return;
	
	int accountId = g_PlayerBans[client].accountId;
	
	g_PlayerBans[client].accountId = 0;
	g_PlayerBans[client].banType = 0;
	g_PlayerBans[client].isLoaded = false;
	g_PlayerBans[client].isChecking = false;
	
	CVBLog.StringMap("Cache cleaned for disconnected client (AccountID: %d)", accountId);
}

void GetCacheStats(int &stringMapEntries, int &playerBanEntries)
{
	stringMapEntries = 0;
	playerBanEntries = 0;
	
	if (g_hCacheStringMap != null)
	{
		stringMapEntries = g_hCacheStringMap.Size;
	}
	
	if (g_hPlayerBans != null)
	{
		playerBanEntries = g_hPlayerBans.Size;
	}
}

void CloseCache()
{
	if (g_hCacheStringMap != null)
	{
		delete g_hCacheStringMap;
		g_hCacheStringMap = null;
	}
	
	if (g_hPlayerBans != null)
	{
		delete g_hPlayerBans;
		g_hPlayerBans = null;
	}
	
	CVBLog.StringMap("Cache system closed");
}

void ClearBanCache()
{
	if (g_hCacheStringMap != null)
	{
		g_hCacheStringMap.Clear();
	}
	
	if (g_hPlayerBans != null)
	{
		g_hPlayerBans.Clear();
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClientIndex(i))
		{
			g_PlayerBans[i].accountId = 0;
			g_PlayerBans[i].banType = 0;
			g_PlayerBans[i].isLoaded = false;
			g_PlayerBans[i].isChecking = false;
		}
	}
	
	CVBLog.StringMap("Ban cache completely cleared");
}

int CleanupExpiredSQLiteCache()
{
	if (g_hSQLiteDB == null)
		return 0;
	
	int cleanupCount = 0;
	int currentTime = GetTime();
	
	// Para la nueva estructura simplificada, solo limpiamos por TTL
	char sCacheQuery[512];
	Format(sCacheQuery, sizeof(sCacheQuery),
		"DELETE FROM callvote_bans_cache WHERE ttl_expires <= %d",
		currentTime);
	
	if (SQL_FastQuery(g_hSQLiteDB, sCacheQuery))
	{
		int cacheRows = SQL_GetAffectedRows(g_hSQLiteDB);
		cleanupCount += cacheRows;
		
		if (cacheRows > 0)
		{
			CVBLog.SQLite("Manual cleanup: %d TTL-expired cache entries removed", cacheRows);
		}
	}
	
	if (cleanupCount > 0)
	{
		CVBLog.StringMap("Manual SQLite cache cleanup completed: %d total entries removed", cleanupCount);
	}
	
	return cleanupCount;
}

int GetBanCacheSize()
{
	int totalSize = 0;
	
	if (g_hCacheStringMap != null)
	{
		totalSize += g_hCacheStringMap.Size;
	}
	
	if (g_hPlayerBans != null)
	{
		totalSize += g_hPlayerBans.Size;
	}
	
	return totalSize;
}
