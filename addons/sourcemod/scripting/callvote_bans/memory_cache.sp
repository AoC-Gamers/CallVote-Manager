#if defined _cvb_memory_cache_included
	#endinput
#endif
#define _cvb_memory_cache_included

/**
 * Initializes the in-memory cache system.
 */
void InitMemoryCache()
{
	if (g_smClientCache != null)
		delete g_smClientCache;
	
	g_smClientCache = new StringMap();
	for (int i = 1; i <= MaxClients; i++)
		ResetClientState(i);
	
	CVBLog.Cache("Unified memory cache initialized");
}

/**
 * Retrieves restriction information for a player from the in-memory cache.
 *
 * @param banInfo      Reference to a PlayerBanInfo structure to populate with cached data.
 * @return             True if the cache was successfully retrieved and banInfo populated, false otherwise.
 *
 * The function checks if the in-memory cache is enabled and available. If the cache exists,
 * it attempts to retrieve the restriction information for the specified account ID. If retrieval fails,
 * banInfo is reset to default values.
 */
bool CVB_GetMemoryCache(PlayerBanInfo banInfo)
{
	if (!g_cvarMemoryCache.BoolValue)
		return false;

	if (g_smClientCache == null)
	{
		CVBLog.Cache("GetMemoryCache: g_smClientCache is null");
		return false;
	}

	if (banInfo.AccountId <= 0)
	{
		CVBLog.Cache("GetMemoryCache: Invalid structure, AccountID <= 0");
		return false;
	}

	char sAccountId[16];
	IntToString(banInfo.AccountId, sAccountId, sizeof(sAccountId));
	
	PlayerBanInfo cachedInfo;
	if (g_smClientCache.GetArray(sAccountId, cachedInfo, sizeof(PlayerBanInfo)))
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

		if (banInfo.BanType > 0 && banInfo.IsExpired())
		{
			g_smClientCache.Remove(sAccountId);
			banInfo.Clear();
			CVBLog.Cache("GetMemoryCache: removed expired entry for AccountID=%d", banInfo.AccountId);
			return false;
		}
		
		return true;
	}

	banInfo.Clear();
	return false;
}

/**
 * Updates the in-memory cache with the provided PlayerBanInfo data.
 *
 * This function checks for valid input and updates the global in-memory cache
 * with the restriction information for a player, identified by their AccountID.
 * Logs are generated for invalid structures and for the result of the cache update.
 *
 * @param banInfo      The PlayerBanInfo structure containing ban details for a player.
 */
void CVB_UpdateMemoryCache(PlayerBanInfo banInfo)
{
	if (g_smClientCache == null)
	{
		CVBLog.Cache("UpdateMemoryCache: g_smClientCache is null");
		return;
	}

	if (banInfo.AccountId <= 0)
	{
		CVBLog.Cache("UpdateMemoryCache: Invalid structure, AccountID <= 0");
		return;
	}
	else if (banInfo.BanType < 0)
	{
		CVBLog.Cache("UpdateMemoryCache: Invalid structure, banType < 0");
		return;
	}

	char sAccountId[16];
	IntToString(banInfo.AccountId, sAccountId, sizeof(sAccountId));

	PlayerBanInfo cacheInfo;
	cacheInfo.Reset(banInfo.AccountId);
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

	bool setResult = g_smClientCache.SetArray(sAccountId, cacheInfo, sizeof(PlayerBanInfo));
	CVBLog.Cache("UpdateMemoryCache: AccountID=%d, banType=%d, expires=%d, setResult=%d", banInfo.AccountId, banInfo.BanType, banInfo.ExpiresTimestamp, setResult);
}

CVBLookupStatus CVB_LoadBanInfo(PlayerBanInfo banInfo, bool forceDatabase)
{
	if (!forceDatabase && CVB_GetMemoryCache(banInfo))
		return banInfo.IsBanned() ? CVBLookup_Found : CVBLookup_NotFound;

	CVBLookupStatus status = CVB_CheckActiveBan(banInfo);
	if (status == CVBLookup_Found)
	{
		CVB_UpdateMemoryCache(banInfo);
		return CVBLookup_Found;
	}

	if (status == CVBLookup_Error)
		return CVBLookup_Error;

	banInfo.Clear();
	CVB_UpdateMemoryCache(banInfo);
	return CVBLookup_NotFound;
}

static void CVB_PrimeClientBanState(int client, int accountId, bool forceDatabase = false)
{
	if (!IsValidClientIndex(client) || accountId <= 0)
		return;

	PlayerBanInfo banInfo;
	banInfo.Reset(accountId);
	CVBLookupStatus status = CVB_LoadBanInfo(banInfo, forceDatabase);
	SetClientLoadState(client, accountId, ClientBanLoad_Ready);

	CVBLog.Cache(
		"Primed client state for %N (AccountID: %d, forceDatabase=%d, status=%d)",
		client,
		accountId,
		forceDatabase ? 1 : 0,
		view_as<int>(status)
	);

}

/**
 * Checks if a player has active vote restrictions based on their restriction information.
 *
 * This function verifies the restriction status of a player by checking multiple sources:
 *  - First, it checks the in-memory cache for restriction info.
 *  - If not found, it checks the SQLite database for an active restriction.
 *  - If still not found, it checks the MySQL database for an active restriction.
 * If a restriction is confirmed from any source, the player's state is updated and relevant caches are refreshed.
 * If backend validation fails, this function fails closed and denies the vote.
 * If no restriction is found, the function logs the result and allows the vote.
 *
 * @param client    The client index of the player to check.
 * @param banInfo   The PlayerBanInfo structure containing ban details for the player.
 * @return          True if the player has active restrictions or backend validation failed, false otherwise.
 */
bool IsPlayerBanned(int client, PlayerBanInfo banInfo)
{
	CVBLookupStatus status = CVB_LoadBanInfo(banInfo, false);
	SetClientLoadState(client, banInfo.AccountId, ClientBanLoad_Ready);

	if (status == CVBLookup_Found)
		return true;

	if (status == CVBLookup_Error)
	{
		CVBLog.Cache("IsPlayerBanned: Backend lookup failed for AccountID=%d - denying vote", banInfo.AccountId);
		return true;
	}

	CVBLog.Cache("IsPlayerBanned: No active restriction found for AccountID=%d - allowing vote", banInfo.AccountId);
	return false;
}

/**
 * Handles client connection to the in-memory cache system.
 *
 * @param client The client index connecting to the server.
 */
void OnClientMemoryCacheConnect(int client)
{	
	int accountId;
	if (!TryGetConnectedAccountId(client, accountId))
		return;

	CVB_PrimeClientBanState(client, accountId);
}

/**
 * Handles cleanup of client state when a client disconnects.
 *
 * This function only cleans the client state but preserves the in-memory cache
 * to persist across map changes. The in-memory cache is designed to persist
 * between maps to avoid unnecessary SQL queries.
 *
 * Note: The cache entry in g_smClientCache is intentionally NOT removed to
 * maintain in-memory cache persistence across map changes.
 *
 * @param client	The client index to process for state cleanup.
 */
void OnClientMemoryCacheDisconnect(int client)
{
	if (!IsValidClientIndex(client) || IsFakeClient(client))
		return;
	
	int accountId = g_ClientStates[client].accountId;
	
	ResetClientState(client);
	
	CVBLog.Cache("Client state cleaned for disconnect (AccountID: %d) - in-memory cache preserved", accountId);
}

/**
 * Force refresh of in-memory cache data for a specific AccountID
 * This removes the cached entry and forces a new database lookup
 * Use this when you need to ensure fresh data (e.g., after ban modifications)
 *
 * @param accountId	The AccountID to refresh
 */
void ForceRefreshMemoryCacheEntry(int accountId)
{
	if (g_smClientCache == null || accountId == 0)
		return;
		
	char accountKey[16];
	IntToString(accountId, accountKey, sizeof(accountKey));
	
	bool wasRemoved = g_smClientCache.Remove(accountKey);
	CVBLog.Cache("Force refresh for AccountID %d - entry %s", accountId, wasRemoved ? "removed" : "not found");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetSteamAccountID(i) == accountId)
		{
			CVB_PrimeClientBanState(i, accountId, true);
			break;
		}
	}
}

/**
 * Closes and cleans up the unified in-memory cache system.
 */
void CloseMemoryCache()
{
	if (g_smClientCache != null)
	{
		delete g_smClientCache;
		g_smClientCache = null;
	}
	
	for (int i = 1; i <= MaxClients; i++)
		ResetClientState(i);
	
	CVBLog.Cache("Unified memory cache system closed");
}

/**
 * Enhanced version that checks if client has active restriction info from any source.
 * @param client    Client index
 * @return          True if client has active restriction info available
 */
bool IsClientBannedWithInfo(int client)
{
	if (!IsValidClientIndex(client))
		return false;
	
	PlayerBanInfo banInfo;
	banInfo.Reset(GetClientAccountID(client));
	return (CVB_LoadBanInfo(banInfo, false) == CVBLookup_Found);
}

/**
 * Get restriction mask for a connected client.
 * @param client    Client index
 * @return          Restriction mask (0 = no active restriction)
 */
int GetClientBanType(int client)
{
	PlayerBanInfo banInfo;
	banInfo.Reset(GetClientAccountID(client));
	if (CVB_GetMemoryCache(banInfo))
	{
		return banInfo.BanType;
	}
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

	PlayerBanInfo banInfo;
	banInfo.Reset(GetClientAccountID(client));

	if (CVB_GetMemoryCache(banInfo))
	{
		return banInfo.ExpiresTimestamp;
	}
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

	PlayerBanInfo banInfo;
	banInfo.Reset(GetClientAccountID(client));
	
	if (CVB_GetMemoryCache(banInfo))
	{
		return banInfo.CreatedTimestamp;
	}
	return 0;
}

/**
 * Set restriction information for a connected client.
 * @param client           Client index
 * @param banType          Ban type
 * @param durationMinutes  Duration in minutes
 * @param expiresTimestamp Expiration timestamp
 */
void SetClientBanInfo(int client, int banType, int durationMinutes, int expiresTimestamp, int createdTimestamp = 0, int adminAccountId = 0, const char[] reason = "")
{
	if (!IsValidClientIndex(client))
		return;
		
	int accountId = g_ClientStates[client].accountId;
	if (accountId == 0)
		return;

	PlayerBanInfo banInfo;
	banInfo.Reset(accountId);
	banInfo.BanType = banType;
	banInfo.CreatedTimestamp = (createdTimestamp > 0) ? createdTimestamp : GetTime();
	banInfo.DurationMinutes = durationMinutes;
	banInfo.ExpiresTimestamp = expiresTimestamp;
	banInfo.AdminAccountId = adminAccountId;
	banInfo.SetReason(reason);

	CVB_UpdateMemoryCache(banInfo);
}
