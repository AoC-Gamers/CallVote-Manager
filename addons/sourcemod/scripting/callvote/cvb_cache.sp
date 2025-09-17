#if defined _cvb_cache_included
	#endinput
#endif
#define _cvb_cache_included

/**
 * Initializes the client cache system.
 */
void InitCache()
{
	if (g_smClientCache != null)
		delete g_smClientCache;
	
	g_smClientCache = new StringMap();
	for (int i = 1; i <= MaxClients; i++)
	{
		g_ClientStates[i].accountId = 0;
		g_ClientStates[i].isLoaded = false;
		g_ClientStates[i].isChecking = false;
	}
	
	CVBLog.StringMap("Unified cache system initialized");
}

/**
 * Retrieves ban information for a player from the cache string map.
 *
 * @param banInfo      Reference to a PlayerBanInfo structure to populate with cached data.
 * @return             True if the cache was successfully retrieved and banInfo populated, false otherwise.
 *
 * The function checks if the string map cache is enabled and available. If the cache exists,
 * it attempts to retrieve the ban information for the specified account ID. If retrieval fails,
 * banInfo is reset to default values.
 */
bool CVB_GetCacheStringMap(PlayerBanInfo banInfo)
{
	if (!g_cvarStringMapCache.BoolValue)
		return false;

	if (g_smClientCache == null)
	{
		CVBLog.StringMap("UpdateCacheStringMap: g_smClientCache is null");
		return false;
	}

	if (banInfo.AccountId <= 0)
	{
		CVBLog.StringMap("UpdateCacheStringMap: Invalid structure, AccountID <= 0");
		return false;
	}

	char sAccountId[16];
	IntToString(banInfo.AccountId, sAccountId, sizeof(sAccountId));
	
	PlayerBanInfo cachedInfo;
	if (g_smClientCache.GetValue(sAccountId, cachedInfo))
	{
		banInfo.BanType = cachedInfo.BanType;
		banInfo.CreatedTimestamp = cachedInfo.CreatedTimestamp;
		banInfo.DurationMinutes = cachedInfo.DurationMinutes;
		banInfo.ExpiresTimestamp = cachedInfo.ExpiresTimestamp;
		banInfo.AdminAccountId = cachedInfo.AdminAccountId;
		banInfo.DbSource = cachedInfo.DbSource;
		banInfo.CommandReplySource = cachedInfo.CommandReplySource;
		
		char tempReason[128];
		cachedInfo.GetReason(tempReason, sizeof(tempReason));
		banInfo.SetReason(tempReason);
		
		return true;
	}

	banInfo.Clear();
	return false;
}

/**
 * Updates the client cache StringMap with the provided PlayerBanInfo data.
 *
 * This function checks for valid input and updates the global client cache
 * with the ban information for a player, identified by their AccountID.
 * Logs are generated for invalid structures and for the result of the cache update.
 *
 * @param banInfo      The PlayerBanInfo structure containing ban details for a player.
 */
void CVB_UpdateCacheStringMap(PlayerBanInfo banInfo)
{
	if (g_smClientCache == null)
	{
		CVBLog.StringMap("UpdateCacheStringMap: g_smClientCache is null");
		return;
	}

	if (banInfo.AccountId <= 0)
	{
		CVBLog.StringMap("UpdateCacheStringMap: Estructura inválida, AccountID <= 0");
		return;
	}
	else if (banInfo.BanType < 0)
	{
		CVBLog.StringMap("UpdateCacheStringMap: Estructura inválida, banType < 0");
		return;
	}

	char sAccountId[16];
	IntToString(banInfo.AccountId, sAccountId, sizeof(sAccountId));

	PlayerBanInfo cacheInfo = new PlayerBanInfo(banInfo.AccountId);
	cacheInfo.BanType = banInfo.BanType;
	cacheInfo.CreatedTimestamp = banInfo.CreatedTimestamp;
	cacheInfo.DurationMinutes = banInfo.DurationMinutes;
	cacheInfo.ExpiresTimestamp = banInfo.ExpiresTimestamp;
	cacheInfo.AdminAccountId = banInfo.AdminAccountId;
	cacheInfo.DbSource = banInfo.DbSource;
	cacheInfo.CommandReplySource = banInfo.CommandReplySource;
	
	char tempReason[128];
	banInfo.GetReason(tempReason, sizeof(tempReason));
	cacheInfo.SetReason(tempReason);

	bool setResult = g_smClientCache.SetValue(sAccountId, cacheInfo);
	CVBLog.StringMap("UpdateCacheStringMap: AccountID=%d, banType=%d, expires=%d, setResult=%d", banInfo.AccountId, banInfo.BanType, banInfo.ExpiresTimestamp, setResult);
}

/**
 * Checks if a player is banned based on their ban information.
 *
 * This function verifies the ban status of a player by checking multiple sources:
 *  - First, it checks a cached string map for ban info.
 *  - If not found, it checks the SQLite database for an active ban.
 *  - If still not found, it checks the MySQL database for an active ban.
 * If a ban is confirmed from any source, the player's state is updated and relevant caches are refreshed.
 * If no ban is found, the function logs the result and allows the vote.
 *
 * @param client    The client index of the player to check.
 * @param banInfo   The PlayerBanInfo structure containing ban details for the player.
 * @return          True if the player is banned, false otherwise.
 */
bool IsPlayerBanned(int client, PlayerBanInfo banInfo)
{
	if (CVB_GetCacheStringMap(banInfo))
	{
		g_ClientStates[client].accountId = banInfo.AccountId;
		g_ClientStates[client].isLoaded = true;
		g_ClientStates[client].isChecking = false;
		return true;
	}

	if (CVB_CheckSQLiteBan(banInfo))
	{
		g_ClientStates[client].accountId = banInfo.AccountId;
		g_ClientStates[client].isLoaded = true;
		g_ClientStates[client].isChecking = false;

		CVB_UpdateCacheStringMap(banInfo);
		return true;
	}

	if (CVB_CheckMysqlActiveBan(banInfo))
	{
		g_ClientStates[client].isLoaded = true;
		g_ClientStates[client].isChecking = false;

		CVB_UpdateCacheStringMap(banInfo);
		CVB_UpdateSQLiteBan(banInfo);
		return true;
	}

	CVBLog.StringMap("IsPlayerBanned: No confirmed ban info for AccountID=%d - allowing vote (innocent until proven guilty)", banInfo.AccountId);
	return false;
}

/**
 * Removes an expired cache entry for the specified account ID from the callvote bans cache table.
 *
 * This function executes a DELETE SQL query on the 'callvote_bans_cache' table to remove
 * the entry associated with the given accountId. If the operation is successful, a log entry
 * is created indicating the removal. If the operation fails, the error message is logged.
 *
 * @param accountId  The account ID whose expired cache entry should be removed.
 */
void RemoveExpiredCacheEntry(int accountId)
{
	if (g_hSQLiteDB == null)
		return;
		
	char sQuery[256];
	Format(sQuery, sizeof(sQuery), "DELETE FROM callvote_bans_cache WHERE account_id = %d", accountId);
	
	if (SQL_FastQuery(g_hSQLiteDB, sQuery))
		CVBLog.SQLite("Removed expired cache entry for AccountID %d", accountId);
	else
	{
		char sError[256];
		SQL_GetError(g_hSQLiteDB, sError, sizeof(sError));
		CVBLog.SQLite("Error removing expired entry: %s", sError);
	}
}

/**
 * Handles client connection to the cache system.
 *
 * @param client The client index connecting to the server.
 */
void OnClientCacheConnect(int client)
{	
	int accountId = GetSteamAccountID(client);
	if (accountId == 0)
		return;
	
	g_ClientStates[client].accountId = accountId;
	g_ClientStates[client].isLoaded = false;
	g_ClientStates[client].isChecking = false;

	PlayerBanInfo banInfo = new PlayerBanInfo(accountId);
	CVB_CheckMysqlActiveBan(banInfo);
	CVBLog.StringMap("Starting fresh ban check for %N (AccountID: %d) to ensure current data", client, accountId);

	if (CVB_GetCacheStringMap(banInfo))
		CVBLog.StringMap("Cache HIT for %N (AccountID: %d) - but refreshing with DB data", client, accountId);
	else
		CVBLog.StringMap("Cache MISS for %N (AccountID: %d) - awaiting DB response", client, accountId);
	
	delete banInfo;
}

/**
 * Handles cleanup of client state when a client disconnects.
 *
 * This function only cleans the client state but preserves the StringMap cache
 * to persist across map changes. The StringMap cache is designed to persist
 * between maps to avoid unnecessary SQL queries.
 *
 * Note: The cache entry in g_smClientCache is intentionally NOT removed to
 * maintain cache persistence across map changes.
 *
 * @param client	The client index to process for state cleanup.
 */
void OnClientCacheDisconnect(int client)
{
	if (!IsValidClientIndex(client) || IsFakeClient(client))
		return;
	
	int accountId = g_ClientStates[client].accountId;
	
	g_ClientStates[client].accountId = 0;
	g_ClientStates[client].isLoaded = false;
	g_ClientStates[client].isChecking = false;
	
	CVBLog.StringMap("Client state cleaned for disconnect (AccountID: %d) - StringMap cache preserved", accountId);
}

/**
 * Force refresh of cache data for a specific AccountID
 * This removes the cached entry and forces a new database lookup
 * Use this when you need to ensure fresh data (e.g., after ban modifications)
 *
 * @param accountId	The AccountID to refresh
 */
void ForceRefreshCacheEntry(int accountId)
{
	if (g_smClientCache == null || accountId == 0)
		return;
		
	char accountKey[16];
	IntToString(accountId, accountKey, sizeof(accountKey));
	
	bool wasRemoved = g_smClientCache.Remove(accountKey);
	CVBLog.StringMap("Force refresh for AccountID %d - entry %s", accountId, wasRemoved ? "removed" : "not found");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetSteamAccountID(i) == accountId)
		{
			g_ClientStates[i].isLoaded = false;
			g_ClientStates[i].isChecking = false;

			PlayerBanInfo banInfo = new PlayerBanInfo(accountId);
			CVB_CheckMysqlActiveBan(banInfo);
			CVBLog.StringMap("Triggered fresh check for client %N (AccountID: %d)", i, banInfo.AccountId);
			delete banInfo;
			break;
		}
	}
}

/**
 * Retrieves statistics about the cache, specifically the number of entries in the string map and player ban lists.
 *
 * @param stringMapEntries Reference to an integer that will be set to the number of entries in the string map cache.
 * @param playerBanEntries Reference to an integer that will be set to the number of player ban entries in the cache.
 */
void GetCacheStats(int &stringMapEntries, int &playerBanEntries)
{
	stringMapEntries = 0;
	playerBanEntries = 0;
	
	if (g_smClientCache != null)
	{
		stringMapEntries = g_smClientCache.Size;
		playerBanEntries = g_smClientCache.Size;
	}
}

/**
 * Closes and cleans up the unified client cache system.
 */
void CloseCache()
{
	if (g_smClientCache != null)
	{
		delete g_smClientCache;
		g_smClientCache = null;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		g_ClientStates[i].accountId = 0;
		g_ClientStates[i].isLoaded = false;
		g_ClientStates[i].isChecking = false;
	}
	
	CVBLog.StringMap("Unified cache system closed");
}

/**
 * Clears the ban cache for all clients.
 */
void ClearBanCache()
{
	if (g_smClientCache != null)
		g_smClientCache.Clear();
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClientIndex(i))
			continue;

		g_ClientStates[i].accountId = 0;
		g_ClientStates[i].isLoaded = false;
		g_ClientStates[i].isChecking = false;
	}
	
	CVBLog.StringMap("Unified cache completely cleared");
}

/**
 * Cleans up expired entries from the SQLite.
 *
 * This function deletes all rows where the 'ttl_expires' timestamp is less than or equal to the current time.
 * It logs the number of entries removed, if any, and returns the total number of deleted rows.
 *
 * @return int  The number of cache entries removed from the database.
 */
int CleanupExpiredSQLiteCache()
{
	if (g_hSQLiteDB == null)
		return 0;
	
	int cleanupCount = 0;
	int currentTime = GetTime();

	char sCacheQuery[512];
	Format(sCacheQuery, sizeof(sCacheQuery), "DELETE FROM callvote_bans_cache WHERE ttl_expires <= %d", currentTime);
	
	if (SQL_FastQuery(g_hSQLiteDB, sCacheQuery))
	{
		int cacheRows = SQL_GetAffectedRows(g_hSQLiteDB);
		cleanupCount += cacheRows;
		
		if (cacheRows > 0)
			CVBLog.SQLite("Manual cleanup: %d TTL-expired cache entries removed", cacheRows);
	}
	
	if (cleanupCount > 0)
		CVBLog.StringMap("Manual SQLite cache cleanup completed: %d total entries removed", cleanupCount);
	
	return cleanupCount;
}

/**
 * Enhanced version that checks if client is banned with info from any source
 * @param client    Client index
 * @return          True if client has ban info available and is banned
 */
bool IsClientBannedWithInfo(int client)
{
	if (!IsValidClientIndex(client))
		return false;
	
	PlayerBanInfo banInfo = new PlayerBanInfo(GetSteamAccountID(client));

	if (CVB_GetCacheStringMap(banInfo))
	{
		bool isBanned = banInfo.IsBanned();
		delete banInfo;
		return isBanned;
	}

	if (CVB_CheckSQLiteBan(banInfo))
	{
		CVB_UpdateCacheStringMap(banInfo);
		bool isBanned = banInfo.IsBanned();
		delete banInfo;
		return isBanned;
	}
	
	delete banInfo;
	return false;
}

/**
 * Get ban type for a connected client
 * @param client    Client index
 * @return          Ban type (0 = no ban, >0 = banned)
 */
int GetClientBanType(int client)
{
	PlayerBanInfo banInfo = new PlayerBanInfo(GetClientAccountID(client));
	if (CVB_GetCacheStringMap(banInfo))
	{
		int banType = banInfo.BanType;
		delete banInfo;
		return banType;
	}

	delete banInfo;
	return 0;
}

/**
 * Get ban expiration timestamp for a connected client
 * @param client    Client index
 * @return          Expiration timestamp (0 = permanent)
 */
int GetClientBanExpiration(int client)
{
	if (!IsValidClientIndex(client))
		return 0;

	PlayerBanInfo banInfo = new PlayerBanInfo(GetClientAccountID(client));

	if (CVB_GetCacheStringMap(banInfo))
	{
		int expiration = banInfo.ExpiresTimestamp;
		delete banInfo;
		return expiration;
	}
	
	delete banInfo;
	return 0;
}

/**
 * Get ban creation timestamp for a connected client
 * @param client    Client index
 * @return          Creation timestamp
 */
int GetClientBanCreationTime(int client)
{
	if (!IsValidClientIndex(client))
		return 0;

	PlayerBanInfo banInfo = new PlayerBanInfo(GetClientAccountID(client));
	
	if (CVB_GetCacheStringMap(banInfo))
	{
		int creationTime = banInfo.CreatedTimestamp;
		delete banInfo;
		return creationTime;
	}
	
	delete banInfo;
	return 0;
}

/**
 * Set ban information for a connected client (for menu operations)
 * @param client           Client index
 * @param banType          Ban type
 * @param durationMinutes  Duration in minutes
 * @param expiresTimestamp Expiration timestamp
 */
void SetClientBanInfo(int client, int banType, int durationMinutes, int expiresTimestamp)
{
	if (!IsValidClientIndex(client))
		return;
		
	int accountId = g_ClientStates[client].accountId;
	if (accountId == 0)
		return;

	PlayerBanInfo banInfo = new PlayerBanInfo(accountId);
	banInfo.BanType = banType;
	banInfo.CreatedTimestamp = GetTime();
	banInfo.DurationMinutes = durationMinutes;
	banInfo.ExpiresTimestamp = expiresTimestamp;

	CVB_UpdateCacheStringMap(banInfo);
	delete banInfo;
}
