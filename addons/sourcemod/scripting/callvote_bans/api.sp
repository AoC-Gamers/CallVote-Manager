#if defined _cvb_api_included
	#endinput
#endif
#define _cvb_api_included

GlobalForward
	g_gfBlocked,
	g_gfOnPlayerRestricted;

/**
 * Registers global forwards for the CallVote-Manager plugin.
 */
void RegisterForwards()
{
	g_gfBlocked			   = CreateGlobalForward("CVB_OnVoteBlocked", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_gfOnPlayerRestricted = CreateGlobalForward("CVB_OnPlayerRestricted", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
}

/**
 * Closes and cleans up all registered forwards by deleting their handles and setting them to null.
 *
 * This function ensures that any global forward handles used for event notifications
 * (such as vote blocking and player restriction events) are properly deleted
 * to prevent memory leaks or dangling references.
 */
void CloseForwards()
{
	if (g_gfBlocked != null)
	{
		delete g_gfBlocked;
		g_gfBlocked = null;
	}

	if (g_gfOnPlayerRestricted != null)
	{
		delete g_gfOnPlayerRestricted;
		g_gfOnPlayerRestricted = null;
	}
}

/**
 * Registers all native functions provided by the CallVote-Manager API.
 */
void RegisterNatives()
{
	CreateNative("CVB_HasActiveRestriction", Native_HasActiveRestriction);
	CreateNative("CVB_GetPlayerRestrictionMask", Native_GetPlayerRestrictionMask);
	CreateNative("CVB_RestrictPlayer", Native_RestrictPlayer);
	CreateNative("CVB_RemoveRestriction", Native_RemoveRestriction);
	CreateNative("CVB_GetRestrictionInfo", Native_GetRestrictionInfo);
}

static bool CVB_TryLoadActiveRestrictionInfoForClient(int client, PlayerRestrictionInfo restrictionInfo)
{
	restrictionInfo.Reset(GetClientAccountID(client));

	if (CVB_GetMemoryCache(restrictionInfo) && restrictionInfo.IsBanned())
		return true;

	if (CVB_CheckActiveRestriction(restrictionInfo) == CVBLookup_Found && restrictionInfo.IsBanned())
	{
		CVB_UpdateMemoryCache(restrictionInfo);
		return true;
	}

	restrictionInfo.Clear();
	CVB_UpdateMemoryCache(restrictionInfo);
	return false;
}

public int Native_HasActiveRestriction(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
		return false;
	}

	PlayerRestrictionInfo restrictionInfo;
	return HasActiveRestriction(client, restrictionInfo);
}

public int Native_GetPlayerRestrictionMask(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
		return 0;
	}

	PlayerRestrictionInfo restrictionInfo;
	return CVB_TryLoadActiveRestrictionInfoForClient(client, restrictionInfo) ? restrictionInfo.RestrictionMask : 0;
}

public int Native_RestrictPlayer(Handle plugin, int numParams)
{
	int targetClient = GetNativeCell(1);
	int restrictionMask = GetNativeCell(2);
	int durationMinutes = GetNativeCell(3);
	int adminClient = GetNativeCell(4);

	char reason[256];
	GetNativeString(5, reason, sizeof(reason));

	if (!IsValidClient(targetClient))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid target client index %d", targetClient);
		return false;
	}

	if (restrictionMask <= 0 || restrictionMask > view_as<int>(VOTE_ALL))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid restriction mask %d", restrictionMask);
		return false;
	}

	if (durationMinutes < 0)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid duration %d", durationMinutes);
		return false;
	}

	if (adminClient != SERVER_INDEX && !IsValidClient(adminClient))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid admin client index %d", adminClient);
		return false;
	}

	if (CVB_GetActiveDatabase() == SourceDB_Unknown)
		return false;

	char normalizedReason[256];
	NormalizeBanReason(reason, normalizedReason, sizeof(normalizedReason));
	return ApplyBanToPlayer(adminClient, targetClient, restrictionMask, durationMinutes, normalizedReason);
}

public int Native_RemoveRestriction(Handle plugin, int numParams)
{
	int target = GetNativeCell(1);
	int admin = GetNativeCell(2);

	if (!IsValidClient(target))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid target client index %d", target);
		return false;
	}

	if (admin != SERVER_INDEX && !IsValidClient(admin))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid admin client index %d", admin);
		return false;
	}

	if (CVB_GetActiveDatabase() == SourceDB_Unknown)
		return false;

	return ApplyUnbanToPlayer(admin, target);
}

public int Native_GetRestrictionInfo(Handle plugin, int numParams)
{
	int target = GetNativeCell(1);

	if (!IsValidClient(target))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid target client index %d", target);
		return false;
	}

	PlayerRestrictionInfo restrictionInfo;
	if (!CVB_TryLoadActiveRestrictionInfoForClient(target, restrictionInfo))
	{
		return false;
	}

	char reason[256];
	char adminSteamId[MAX_AUTHID_LENGTH];
	adminSteamId[0] = '\0';
	restrictionInfo.GetReason(reason, sizeof(reason));
	if (restrictionInfo.AdminAccountId > 0)
		AccountIDToSteamID2(restrictionInfo.AdminAccountId, adminSteamId, sizeof(adminSteamId));

	SetNativeCellRef(2, restrictionInfo.RestrictionMask);
	SetNativeCellRef(3, restrictionInfo.ExpiresTimestamp);
	SetNativeCellRef(4, restrictionInfo.CreatedTimestamp);
	SetNativeString(5, reason, GetNativeCell(6), true);
	SetNativeString(7, adminSteamId, GetNativeCell(8), true);

	return true;

}

/**
 * Fires the "OnPlayerRestricted" forward if it is registered.
 *
 * @param target           The client index of the player receiving the restriction.
 * @param restrictionMask  The restriction mask being applied.
 * @param duration         The duration of the restriction in minutes.
 * @param admin            The client index of the admin issuing the restriction.
 * @param reason           The reason for the restriction.
 */
void FireOnPlayerRestricted(int target, int restrictionMask, int duration, int admin, const char[] reason)
{
	if (g_gfOnPlayerRestricted == null)
		return;

	Call_StartForward(g_gfOnPlayerRestricted);
	Call_PushCell(target);
	Call_PushCell(restrictionMask);
	Call_PushCell(duration);
	Call_PushCell(admin);
	Call_PushString(reason);
	Call_Finish();
}
