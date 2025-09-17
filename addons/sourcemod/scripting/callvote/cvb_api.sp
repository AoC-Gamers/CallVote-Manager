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
 * (such as blocking, ban reasons loaded, and player banned events) are properly deleted
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

public int Native_IsPlayerBanned(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
		return false;
	}

	PlayerBanInfo banInfo = new PlayerBanInfo(GetSteamAccountID(client));
	bool result = IsPlayerBanned(client, banInfo);
	delete banInfo;
	return result;
}

public int Native_GetPlayerBanType(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
		return 0;
	}

	PlayerBanInfo banInfo = new PlayerBanInfo(GetClientAccountID(client));
	int banType = CVB_GetCacheStringMap(banInfo) ? banInfo.BanType : 0;
	delete banInfo;
	return banType;
}

public int Native_BanPlayer(Handle plugin, int numParams)
{
	int	 targetClient	 = GetNativeCell(1);
	int	 banType		 = GetNativeCell(2);
	int	 durationMinutes = GetNativeCell(3);
	int	 adminClient	 = GetNativeCell(4);

	char reason[256];
	GetNativeString(5, reason, sizeof(reason));

	if (!IsValidClient(targetClient))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid target client index %d", targetClient);
		return false;
	}

	int	 targetAccountId = GetSteamAccountID(targetClient);
	char targetSteamId2[MAX_AUTHID_LENGTH];
	GetClientAuthId(targetClient, AuthId_Steam2, targetSteamId2, sizeof(targetSteamId2));

	int	 adminAccountId					  = 0;
	char adminSteamId2[MAX_AUTHID_LENGTH] = "CONSOLE";

	if (IsValidClient(adminClient))
	{
		adminAccountId = GetSteamAccountID(adminClient);
		GetClientAuthId(adminClient, AuthId_Steam2, adminSteamId2, sizeof(adminSteamId2));
	}

	char reasonCode[256];
	CVB_GetBanReason(reason, reasonCode, sizeof(reasonCode));

	CVB_InsertMysqlBan(targetAccountId, banType, durationMinutes, adminAccountId, reasonCode);
	FireOnPlayerBanned(targetClient, banType, durationMinutes, adminClient, reason);
	return true;
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

	int targetAccountId = GetSteamAccountID(target);
	int adminAccountId = (IsValidClient(admin)) ? GetSteamAccountID(admin) : SERVER_INDEX;
	CVB_RemoveMysqlBan(targetAccountId, adminAccountId);
	return true;
}

public int Native_GetBanInfo(Handle plugin, int numParams)
{
	int target      = GetNativeCell(1);
	int banType     = GetNativeCell(2);
	int duration= GetNativeCell(3);
	int admin       = GetNativeCell(4);

	char reason[256];
	GetNativeString(5, reason, sizeof(reason));

	if (!IsValidClient(target))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid target client index %d", target);
		return false;
	}

	int targetAccountId = GetSteamAccountID(target);
	int adminAccountId  = (IsValidClient(admin)) ? GetSteamAccountID(admin) : SERVER_INDEX;

	char reasonCode[256];
	CVB_GetBanReason(reason, reasonCode, sizeof(reasonCode));

	CVB_InsertMysqlBan(targetAccountId, banType, duration, adminAccountId, reasonCode);
	FireOnPlayerBanned(target, banType, duration, admin, reason);
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