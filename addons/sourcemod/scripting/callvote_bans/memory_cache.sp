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
 * @param restrictionInfo Reference to a PlayerRestrictionInfo structure to populate with cached data.
 * @return             True if the cache was successfully retrieved and restrictionInfo populated, false otherwise.
 *
 * The function checks if the in-memory cache is enabled and available. If the cache exists,
 * it attempts to retrieve the restriction information for the specified account ID. If retrieval fails,
 * restrictionInfo is reset to default values.
 */
bool CVB_GetMemoryCache(PlayerRestrictionInfo restrictionInfo)
{
	if (!g_cvarMemoryCache.BoolValue)
		return false;

	if (g_smClientCache == null)
	{
		CVBLog.Cache("GetMemoryCache: g_smClientCache is null");
		return false;
	}

	if (restrictionInfo.AccountId <= 0)
	{
		CVBLog.Cache("GetMemoryCache: Invalid structure, AccountID <= 0");
		return false;
	}

	char sAccountId[16];
	IntToString(restrictionInfo.AccountId, sAccountId, sizeof(sAccountId));
	
	PlayerRestrictionInfo cachedInfo;
	if (g_smClientCache.GetArray(sAccountId, cachedInfo, sizeof(PlayerRestrictionInfo)))
	{
		restrictionInfo.RestrictionMask = cachedInfo.RestrictionMask;
		restrictionInfo.CreatedTimestamp = cachedInfo.CreatedTimestamp;
		restrictionInfo.DurationMinutes = cachedInfo.DurationMinutes;
		restrictionInfo.ExpiresTimestamp = cachedInfo.ExpiresTimestamp;
		restrictionInfo.AdminAccountId = cachedInfo.AdminAccountId;
		restrictionInfo.DbSource = cachedInfo.DbSource;
		restrictionInfo.CommandReplySource = cachedInfo.CommandReplySource;
		
		char tempReason[128];
		cachedInfo.GetReason(tempReason, sizeof(tempReason));
		restrictionInfo.SetReason(tempReason);

		if (restrictionInfo.RestrictionMask > 0 && restrictionInfo.IsExpired())
		{
			g_smClientCache.Remove(sAccountId);
			restrictionInfo.Clear();
			CVBLog.Cache("GetMemoryCache: removed expired entry for AccountID=%d", restrictionInfo.AccountId);
			return false;
		}
		
		return true;
	}

	restrictionInfo.Clear();
	return false;
}

/**
 * Updates the in-memory cache with the provided PlayerRestrictionInfo data.
 *
 * This function checks for valid input and updates the global in-memory cache
 * with the restriction information for a player, identified by their AccountID.
 * Logs are generated for invalid structures and for the result of the cache update.
 *
 * @param restrictionInfo The PlayerRestrictionInfo structure containing restriction details for a player.
 */
void CVB_UpdateMemoryCache(PlayerRestrictionInfo restrictionInfo)
{
	if (g_smClientCache == null)
	{
		CVBLog.Cache("UpdateMemoryCache: g_smClientCache is null");
		return;
	}

	if (restrictionInfo.AccountId <= 0)
	{
		CVBLog.Cache("UpdateMemoryCache: Invalid structure, AccountID <= 0");
		return;
	}
	else if (restrictionInfo.RestrictionMask < 0)
	{
		CVBLog.Cache("UpdateMemoryCache: Invalid structure, restrictionMask < 0");
		return;
	}

	char sAccountId[16];
	IntToString(restrictionInfo.AccountId, sAccountId, sizeof(sAccountId));

	PlayerRestrictionInfo cacheInfo;
	cacheInfo.Reset(restrictionInfo.AccountId);
	cacheInfo.RestrictionMask = restrictionInfo.RestrictionMask;
	cacheInfo.CreatedTimestamp = restrictionInfo.CreatedTimestamp;
	cacheInfo.DurationMinutes = restrictionInfo.DurationMinutes;
	cacheInfo.ExpiresTimestamp = restrictionInfo.ExpiresTimestamp;
	cacheInfo.AdminAccountId = restrictionInfo.AdminAccountId;
	cacheInfo.DbSource = restrictionInfo.DbSource;
	cacheInfo.CommandReplySource = restrictionInfo.CommandReplySource;
	
	char tempReason[128];
	restrictionInfo.GetReason(tempReason, sizeof(tempReason));
	cacheInfo.SetReason(tempReason);

	bool setResult = g_smClientCache.SetArray(sAccountId, cacheInfo, sizeof(PlayerRestrictionInfo));
	CVBLog.Cache("UpdateMemoryCache: AccountID=%d, restrictionMask=%d, expires=%d, setResult=%d", restrictionInfo.AccountId, restrictionInfo.RestrictionMask, restrictionInfo.ExpiresTimestamp, setResult);
}

CVBLookupStatus CVB_LoadRestrictionInfo(PlayerRestrictionInfo restrictionInfo, bool forceDatabase)
{
	if (!forceDatabase && CVB_GetMemoryCache(restrictionInfo))
		return restrictionInfo.IsBanned() ? CVBLookup_Found : CVBLookup_NotFound;

	CVBLookupStatus status = CVB_CheckActiveRestriction(restrictionInfo);
	if (status == CVBLookup_Found)
	{
		CVB_UpdateMemoryCache(restrictionInfo);
		return CVBLookup_Found;
	}

	if (status == CVBLookup_Error)
		return CVBLookup_Error;

	restrictionInfo.Clear();
	CVB_UpdateMemoryCache(restrictionInfo);
	return CVBLookup_NotFound;
}

static void CVB_PrimeClientBanState(int client, int accountId, bool forceDatabase = false)
{
	if (!IsValidClientIndex(client) || accountId <= 0)
		return;

	PlayerRestrictionInfo restrictionInfo;
	restrictionInfo.Reset(accountId);
	CVBLookupStatus status = CVB_LoadRestrictionInfo(restrictionInfo, forceDatabase);
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
 * @param restrictionInfo The PlayerRestrictionInfo structure containing restriction details for the player.
 * @return          True if the player has active restrictions or backend validation failed, false otherwise.
 */
bool HasActiveRestriction(int client, PlayerRestrictionInfo restrictionInfo)
{
	CVBLookupStatus status = CVB_LoadRestrictionInfo(restrictionInfo, false);
	SetClientLoadState(client, restrictionInfo.AccountId, ClientBanLoad_Ready);

	if (status == CVBLookup_Found)
		return true;

	if (status == CVBLookup_Error)
	{
		CVBLog.Cache("HasActiveRestriction: Backend lookup failed for AccountID=%d - denying vote", restrictionInfo.AccountId);
		return true;
	}

	CVBLog.Cache("HasActiveRestriction: No active restriction found for AccountID=%d - allowing vote", restrictionInfo.AccountId);
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
	
	PlayerRestrictionInfo restrictionInfo;
	restrictionInfo.Reset(GetClientAccountID(client));
	return (CVB_LoadRestrictionInfo(restrictionInfo, false) == CVBLookup_Found);
}

/**
 * Get restriction mask for a connected client.
 * @param client    Client index
 * @return          Restriction mask (0 = no active restriction)
 */
int GetClientRestrictionMask(int client)
{
	PlayerRestrictionInfo restrictionInfo;
	restrictionInfo.Reset(GetClientAccountID(client));
	if (CVB_GetMemoryCache(restrictionInfo))
	{
		return restrictionInfo.RestrictionMask;
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

	PlayerRestrictionInfo restrictionInfo;
	restrictionInfo.Reset(GetClientAccountID(client));

	if (CVB_GetMemoryCache(restrictionInfo))
	{
		return restrictionInfo.ExpiresTimestamp;
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

	PlayerRestrictionInfo restrictionInfo;
	restrictionInfo.Reset(GetClientAccountID(client));
	
	if (CVB_GetMemoryCache(restrictionInfo))
	{
		return restrictionInfo.CreatedTimestamp;
	}
	return 0;
}

/**
 * Set restriction information for a connected client.
 * @param client           Client index
 * @param restrictionMask  Restriction mask
 * @param durationMinutes  Duration in minutes
 * @param expiresTimestamp Expiration timestamp
 */
void SetClientRestrictionInfo(int client, int restrictionMask, int durationMinutes, int expiresTimestamp, int createdTimestamp = 0, int adminAccountId = 0, const char[] reason = "")
{
	if (!IsValidClientIndex(client))
		return;
		
	int accountId = g_ClientStates[client].accountId;
	if (accountId == 0)
		return;

	PlayerRestrictionInfo restrictionInfo;
	restrictionInfo.Reset(accountId);
	restrictionInfo.RestrictionMask = restrictionMask;
	restrictionInfo.CreatedTimestamp = (createdTimestamp > 0) ? createdTimestamp : GetTime();
	restrictionInfo.DurationMinutes = durationMinutes;
	restrictionInfo.ExpiresTimestamp = expiresTimestamp;
	restrictionInfo.AdminAccountId = adminAccountId;
	restrictionInfo.SetReason(reason);

	CVB_UpdateMemoryCache(restrictionInfo);
}
