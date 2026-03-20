#if defined _cvb_api_included
	#endinput
#endif
#define _cvb_api_included

GlobalForward
	g_gfBlocked,
	g_gfOnPlayerBanned;

/**
 * Registers global forwards for the CallVote-Manager plugin.
 */
void RegisterForwards()
{
	g_gfBlocked			   = CreateGlobalForward("CVB_OnVoteBlocked", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_gfOnPlayerBanned = CreateGlobalForward("CVB_OnPlayerBanned", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String);
}

/**
 * Closes and cleans up all registered forwards by deleting their handles and setting them to null.
 *
 * This function ensures that any global forward handles used for event notifications
 * (such as vote blocking and player banned events) are properly deleted
 * to prevent memory leaks or dangling references.
 */
void CloseForwards()
{
	if (g_gfBlocked != null)
	{
		delete g_gfBlocked;
		g_gfBlocked = null;
	}

	if (g_gfOnPlayerBanned != null)
	{
		delete g_gfOnPlayerBanned;
		g_gfOnPlayerBanned = null;
	}
}

/**
 * Registers all native functions provided by the CallVote-Manager API.
 */
void RegisterNatives()
{
	CreateNative("CVB_IsPlayerBanned", Native_IsPlayerBanned);
	CreateNative("CVB_GetPlayerBanType", Native_GetPlayerBanType);
	CreateNative("CVB_BanPlayer", Native_BanPlayer);
	CreateNative("CVB_UnbanPlayer", Native_UnbanPlayer);
	CreateNative("CVB_GetBanInfo", Native_GetBanInfo);
}

static bool CVB_TryLoadActiveBanInfoForClient(int client, PlayerBanInfo banInfo)
{
	banInfo.Reset(GetClientAccountID(client));

	if (CVB_GetMemoryCache(banInfo) && banInfo.IsBanned())
		return true;

	if (CVB_CheckActiveBan(banInfo) && banInfo.IsBanned())
	{
		CVB_UpdateMemoryCache(banInfo);
		return true;
	}

	banInfo.Clear();
	CVB_UpdateMemoryCache(banInfo);
	return false;
}

public int Native_IsPlayerBanned(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
		return false;
	}

	PlayerBanInfo banInfo;
	return IsPlayerBanned(client, banInfo);
}

public int Native_GetPlayerBanType(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
		return 0;
	}

	PlayerBanInfo banInfo;
	return CVB_TryLoadActiveBanInfoForClient(client, banInfo) ? banInfo.BanType : 0;
}

public int Native_BanPlayer(Handle plugin, int numParams)
{
	int targetClient = GetNativeCell(1);
	int banType = GetNativeCell(2);
	int durationMinutes = GetNativeCell(3);
	int adminClient = GetNativeCell(4);

	char reason[256];
	GetNativeString(5, reason, sizeof(reason));

	if (!IsValidClient(targetClient))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid target client index %d", targetClient);
		return false;
	}

	if (banType <= 0 || banType > view_as<int>(VOTE_ALL))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid ban type %d", banType);
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
	return ApplyBanToPlayer(adminClient, targetClient, banType, durationMinutes, normalizedReason);
}

public int Native_UnbanPlayer(Handle plugin, int numParams)
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

public int Native_GetBanInfo(Handle plugin, int numParams)
{
	int target = GetNativeCell(1);

	if (!IsValidClient(target))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid target client index %d", target);
		return false;
	}

	PlayerBanInfo banInfo;
	if (!CVB_TryLoadActiveBanInfoForClient(target, banInfo))
	{
		return false;
	}

	char reason[256];
	char adminSteamId[MAX_AUTHID_LENGTH];
	adminSteamId[0] = '\0';
	banInfo.GetReason(reason, sizeof(reason));
	if (banInfo.AdminAccountId > 0)
		AccountIDToSteamID2(banInfo.AdminAccountId, adminSteamId, sizeof(adminSteamId));

	SetNativeCellRef(2, banInfo.BanType);
	SetNativeCellRef(3, banInfo.ExpiresTimestamp);
	SetNativeCellRef(4, banInfo.CreatedTimestamp);
	SetNativeString(5, reason, GetNativeCell(6), true);
	SetNativeString(7, adminSteamId, GetNativeCell(8), true);

	return true;

}

/**
 * Fires the "OnPlayerBanned" forward if it is registered.
 *
 * @param target           The client index of the player being banned.
 * @param banType          The type of ban being applied (e.g., temporary, permanent).
 * @param duration         The duration of the ban in minutes.
 * @param admin            The client index of the admin issuing the ban.
 * @param reason           The reason for the ban.
 */
void FireOnPlayerBanned(int target, int banType, int duration, int admin, const char[] reason)
{
	if (g_gfOnPlayerBanned == null)
		return;

	Call_StartForward(g_gfOnPlayerBanned);
	Call_PushCell(target);
	Call_PushCell(banType);
	Call_PushCell(duration);
	Call_PushCell(admin);
	Call_PushString(reason);
	Call_Finish();
}
