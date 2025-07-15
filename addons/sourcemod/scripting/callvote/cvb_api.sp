#if defined _cvb_api_included
	#endinput
#endif
#define _cvb_api_included

GlobalForward
	g_gfBlocked,
	g_gfOnBanReasonsLoaded,
	g_gfOnPlayerBanned;

void InitForwards()
{
	g_gfBlocked			   = CreateGlobalForward("CVB_OnVoteBlocked", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_gfOnBanReasonsLoaded = CreateGlobalForward("CVB_OnBanReasonsLoaded", ET_Ignore, Param_Cell);
	g_gfOnPlayerBanned	   = CreateGlobalForward("CVB_OnPlayerBanned", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_String);
}

void CloseForwards()
{
	if (g_gfBlocked != null)
	{
		delete g_gfBlocked;
		g_gfBlocked = null;
	}
	if (g_gfOnBanReasonsLoaded != null)
	{
		delete g_gfOnBanReasonsLoaded;
		g_gfOnBanReasonsLoaded = null;
	}
	if (g_gfOnPlayerBanned != null)
	{
		delete g_gfOnPlayerBanned;
		g_gfOnPlayerBanned = null;
	}
}

public Action CallVote_PreStart(int client, TypeVotes voteType, int target)
{
	if (!g_cvarEnable.BoolValue)
		return Plugin_Continue;

	if (!IsValidClient(client))
		return Plugin_Continue;

	int accountId = GetSteamAccountID(client);
	if (accountId == 0)
		return Plugin_Continue;

	if (IsPlayerBanned(accountId, voteType))
	{
		ShowVoteBlockedMessage(client, voteType);

		Call_StartForward(g_gfBlocked);
		Call_PushCell(client);
		Call_PushCell(view_as<int>(voteType));
		Call_PushCell(target);
		Call_PushCell(GetCachedBanType(accountId));
		Call_Finish();

		CVBLog.Debug("Voto bloqueado para %N (AccountID: %d, tipo: %d)", client, accountId, voteType);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void CallVote_PostStart(int client, TypeVotes voteType, int target)
{
	if (!g_cvarEnable.BoolValue)
		return;

	if (!IsValidClient(client))
		return;

	CVBLog.Debug("Voto permitido para %N (tipo: %d)", client, voteType);
}

public void CallVote_PostEnd(int client, TypeVotes voteType, int target, bool passed)
{
	if (!g_cvarEnable.BoolValue)
		return;

	if (!IsValidClient(client))
		return;

	CVBLog.Debug("Voto terminado para %N (tipo: %d, aprobado: %s)", client, voteType, passed ? "Sí" : "No");
}

void ShowVoteBlockedMessage(int client, TypeVotes voteType)
{
	char sVoteTypeName[64];
	GetVoteTypeName(voteType, sVoteTypeName, sizeof(sVoteTypeName));

	char sExpirationInfo[128];
	GetBanExpirationInfo(client, sExpirationInfo, sizeof(sExpirationInfo));

	switch (voteType)
	{
		case ChangeDifficulty:
		{
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedDifficulty", sExpirationInfo);
		}
		case RestartGame:
		{
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedRestart", sExpirationInfo);
		}
		case Kick:
		{
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedKick", sExpirationInfo);
		}
		case ChangeMission:
		{
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedMission", sExpirationInfo);
		}
		case ReturnToLobby:
		{
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedLobby", sExpirationInfo);
		}
		case ChangeChapter:
		{
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedChapter", sExpirationInfo);
		}
		case ChangeAllTalk:
		{
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedAllTalk", sExpirationInfo);
		}
		default:
		{
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedGeneric", sVoteTypeName, sExpirationInfo);
		}
	}
}

void GetVoteTypeName(TypeVotes voteType, char[] output, int maxlen)
{
	switch (voteType)
	{
		case ChangeDifficulty: Format(output, maxlen, "%T", "VoteTypeDifficulty", LANG_SERVER);
		case RestartGame: Format(output, maxlen, "%T", "VoteTypeRestart", LANG_SERVER);
		case Kick: Format(output, maxlen, "%T", "VoteTypeKick", LANG_SERVER);
		case ChangeMission: Format(output, maxlen, "%T", "VoteTypeMission", LANG_SERVER);
		case ReturnToLobby: Format(output, maxlen, "%T", "VoteTypeLobby", LANG_SERVER);
		case ChangeChapter: Format(output, maxlen, "%T", "VoteTypeChapter", LANG_SERVER);
		case ChangeAllTalk: Format(output, maxlen, "%T", "VoteTypeAllTalk", LANG_SERVER);
		default: Format(output, maxlen, "%T", "VoteTypeUnknown", LANG_SERVER, view_as<int>(voteType));
	}
}

void GetBanExpirationInfo(int client, char[] output, int maxlen)
{
	if (g_PlayerBans[client].isLoaded)
	{
		if (g_PlayerBans[client].expiresTimestamp == 0)
		{
			Format(output, maxlen, "%T", "BanPermanent", client);
		}
		else
		{
			int timeLeft = g_PlayerBans[client].expiresTimestamp - GetTime();
			if (timeLeft <= 0)
			{
				Format(output, maxlen, "%T", "BanExpired", client);
			}
			else
			{
				char sTimeLeft[64];
				FormatDuration(timeLeft, sTimeLeft, sizeof(sTimeLeft));
				Format(output, maxlen, "%T", "BanExpiresIn", client, sTimeLeft);
			}
		}
	}
	else
	{
		Format(output, maxlen, "%T", "BanCheckingStatus", client);
	}
}

void OnClientConnectForwards(int client)
{
	if (!g_cvarEnable.BoolValue)
		return;

	if (!IsValidClient(client))
		return;

	int accountId = GetSteamAccountID(client);
	if (accountId == 0)
		return;

	if (g_cvarAnnounceJoin.IntValue > 0)
	{
		CreateTimer(3.0, Timer_CheckAnnounceConnection, GetClientUserId(client));
	}
}

public Action Timer_CheckAnnounceConnection(Handle timer, int userId)
{
	int client = GetClientOfUserId(userId);
	if (client == 0 || !IsValidClient(client))
		return Plugin_Stop;

	if (g_PlayerBans[client].isLoaded && g_PlayerBans[client].banType > 0)
	{
		switch (g_cvarAnnounceJoin.IntValue)
		{
			case 1:
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i))
					{
						AdminId adminId = GetUserAdmin(i);
						if (adminId != INVALID_ADMIN_ID && (adminId.HasFlag(Admin_Generic) || adminId.HasFlag(Admin_Root)))
						{
							CPrintToChat(i, "%t %t", "Tag", "PlayerJoinedWithRestrictions", client);
						}
					}
				}
			}
			case 2:
			{
				CPrintToChatAll("%t %t", "Tag", "PlayerJoinedWithRestrictions", client);
			}
		}

		CVBLog.Debug("Anunciado jugador con restricciones: %N", client);
	}

	return Plugin_Stop;
}

public int Native_IsPlayerBanned(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
		return false;
	}

	TypeVotes voteType	= view_as<TypeVotes>(GetNativeCell(2));
	int		  accountId = GetSteamAccountID(client);

	return IsPlayerBanned(accountId, voteType);
}

public int Native_GetPlayerBanType(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
		return 0;
	}

	if (g_PlayerBans[client].isLoaded)
	{
		return g_PlayerBans[client].banType;
	}

	return 0;
}

public int Native_GetPlayerBanExpiration(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
		return 0;
	}

	if (g_PlayerBans[client].isLoaded)
	{
		return g_PlayerBans[client].expiresTimestamp;
	}

	return 0;
}

public int Native_BanPlayer(Handle plugin, int numParams)
{
	int	 targetAccountId = GetNativeCell(1);
	char targetSteamId2[MAX_AUTHID_LENGTH];
	GetNativeString(2, targetSteamId2, sizeof(targetSteamId2));

	int	 banType		 = GetNativeCell(3);
	int	 durationMinutes = GetNativeCell(4);

	int	 adminAccountId	 = GetNativeCell(5);
	char adminSteamId2[MAX_AUTHID_LENGTH];
	GetNativeString(6, adminSteamId2, sizeof(adminSteamId2));

	char reason[256];
	GetNativeString(7, reason, sizeof(reason));

	int reasonCode = GetBanReasonFromString_Enhanced(reason);
	CVB_InsertBan(targetAccountId, banType, durationMinutes, adminAccountId, reasonCode);

	return 1;
}

public int Native_UnbanPlayer(Handle plugin, int numParams)
{
	int	 targetAccountId = GetNativeCell(1);
	// Parámetro 2 (targetSteamId2) ya no se usa - se mantiene por compatibilidad
	char targetSteamId2[MAX_AUTHID_LENGTH];
	GetNativeString(2, targetSteamId2, sizeof(targetSteamId2));

	int	 adminAccountId = GetNativeCell(3);
	// Parámetro 4 (adminSteamId2) ya no se usa - se mantiene por compatibilidad
	char adminSteamId2[MAX_AUTHID_LENGTH];
	GetNativeString(4, adminSteamId2, sizeof(adminSteamId2));

	CVB_RemoveBan(targetAccountId, adminAccountId);

	return 1;
}

public int Native_GetBanInfo(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
		return false;
	}

	if (!g_PlayerBans[client].isLoaded)
	{
		SetNativeCellRef(2, 0);						 // banType
		SetNativeCellRef(3, 0);						 // expiration
		SetNativeCellRef(4, 0);						 // createdTime
		SetNativeString(5, "", GetNativeCell(6));	 // reason
		SetNativeString(7, "", GetNativeCell(8));	 // adminSteamId
		return false;
	}

	SetNativeCellRef(2, g_PlayerBans[client].banType);
	SetNativeCellRef(3, g_PlayerBans[client].expiresTimestamp);
	SetNativeCellRef(4, g_PlayerBans[client].createdTimestamp);

	char banActiveText[64];
	Format(banActiveText, sizeof(banActiveText), "%T", "BanActive", client);
	SetNativeString(5, banActiveText, GetNativeCell(6));
	
	char steamId2[MAX_AUTHID_LENGTH];
	AccountIDToSteamID2(g_PlayerBans[client].accountId, steamId2, sizeof(steamId2));
	SetNativeString(7, steamId2, GetNativeCell(8));

	return true;
}

public int Native_IsClientLoaded(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
		return false;
	}

	return g_PlayerBans[client].isLoaded;
}

public int Native_BanPlayerByClient(Handle plugin, int numParams)
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

	int reasonCode = GetBanReasonFromString_Enhanced(reason);
	CVB_InsertBan(targetAccountId, banType, durationMinutes, adminAccountId, reasonCode);

	FireOnPlayerBanned(targetAccountId, targetSteamId2, banType, durationMinutes, adminAccountId, adminSteamId2, reason);
	return true;
}

public int Native_ClearCache(Handle plugin, int numParams)
{
	int accountId = GetNativeCell(1);

	if (accountId == 0)
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
			if (IsClientInGame(i))
			{
				g_PlayerBans[i].accountId	= 0;
				g_PlayerBans[i].banType		= 0;
				g_PlayerBans[i].isLoaded	= false;
				g_PlayerBans[i].isChecking	= false;
			}
		}

		if (g_hSQLiteDB != null)
		{
			char query[256];
			Format(query, sizeof(query), "DELETE FROM cvb_cache");
			g_hSQLiteDB.Query(Callback_ClearCache, query);
		}

		CVBLog.Debug("Complete cache cleared");
		return true;
	}
	else
	{
		char accountKey[16];
		IntToString(accountId, accountKey, sizeof(accountKey));

		if (g_hCacheStringMap != null)
		{
			g_hCacheStringMap.Remove(accountKey);
		}

		if (g_hPlayerBans != null)
		{
			g_hPlayerBans.Remove(accountKey);
		}

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetSteamAccountID(i) == accountId)
			{
				g_PlayerBans[i].accountId	= 0;
				g_PlayerBans[i].banType		= 0;
				g_PlayerBans[i].isLoaded	= false;
				g_PlayerBans[i].isChecking	= false;
				break;
			}
		}

		if (g_hSQLiteDB != null)
		{
			char query[256];
			Format(query, sizeof(query), "DELETE FROM cvb_cache WHERE account_id = %d", accountId);
			g_hSQLiteDB.Query(Callback_ClearCache, query);
		}

		CVBLog.Debug("Cache cleared for AccountID: %d", accountId);
		return true;
	}
}

public int Native_GetBanReasonString(Handle plugin, int numParams)
{
	int	 reasonCode = GetNativeCell(1);
	int	 client		= GetNativeCell(2);
	int	 maxlen		= GetNativeCell(4);

	char buffer[256];
	GetBanReasonString_FromConfig(reasonCode, client, buffer, sizeof(buffer));

	SetNativeString(3, buffer, maxlen);

	BanReasonInfo reason;
	return GetBanReasonByCode(reasonCode, reason);
}

public int Native_GetReasonIdFromText(Handle plugin, int numParams)
{
	int	 maxlen = 256;
	char reasonText[256];
	GetNativeString(1, reasonText, maxlen);

	return GetReasonIdFromConfig(reasonText);
}

public int Native_IsValidReasonCode(Handle plugin, int numParams)
{
	int			  code = GetNativeCell(1);
	BanReasonInfo reason;
	return GetBanReasonByCode(code, reason) ? 1 : 0;
}

void RegisterNatives()
{
	CreateNative("CVB_IsPlayerBanned", Native_IsPlayerBanned);
	CreateNative("CVB_GetPlayerBanType", Native_GetPlayerBanType);
	CreateNative("CVB_GetPlayerBanExpiration", Native_GetPlayerBanExpiration);
	CreateNative("CVB_BanPlayer", Native_BanPlayer);
	CreateNative("CVB_UnbanPlayer", Native_UnbanPlayer);

	CreateNative("CVB_GetBanInfo", Native_GetBanInfo);
	CreateNative("CVB_IsClientLoaded", Native_IsClientLoaded);
	CreateNative("CVB_BanPlayerByClient", Native_BanPlayerByClient);
	CreateNative("CVB_ClearCache", Native_ClearCache);

	CreateNative("CVB_GetBanReasonString", Native_GetBanReasonString);
	CreateNative("CVB_GetReasonIdFromText", Native_GetReasonIdFromText);
	CreateNative("CVB_IsValidReasonCode", Native_IsValidReasonCode);

	RegPluginLibrary("callvote_bans");
}

void FireOnBanReasonsLoaded(int reasonCount)
{
	if (g_gfOnBanReasonsLoaded == null)
		return;

	Call_StartForward(g_gfOnBanReasonsLoaded);
	Call_PushCell(reasonCount);
	Call_Finish();
}

void FireOnPlayerBanned(int targetAccountId, const char[] targetSteamId2, int banType,
						int durationMinutes, int adminAccountId, const char[] adminSteamId2,
						const char[] reason)
{
	if (g_gfOnPlayerBanned == null)
		return;

	Call_StartForward(g_gfOnPlayerBanned);
	Call_PushCell(targetAccountId);
	Call_PushString(targetSteamId2);
	Call_PushCell(banType);
	Call_PushCell(durationMinutes);
	Call_PushCell(adminAccountId);
	Call_PushString(adminSteamId2);
	Call_PushString(reason);
	Call_Finish();
}

public void Callback_ClearCache(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("Error clearing cache: %s", error);
		return;
	}

	CVBLog.Debug("Cache limpiado exitosamente");
}
