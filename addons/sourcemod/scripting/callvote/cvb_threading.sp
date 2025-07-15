#if defined _cvb_threading_included
	#endinput
#endif
#define _cvb_threading_included

#define MAX_THREAD_QUEUE 50
#define THREAD_PROCESS_INTERVAL 0.1

ArrayList g_hAsyncQueue;
bool g_bProcessingQueue;

DataPack CreateBanCheckDataPack(int client, int accountId, const char[] steamId2)
{
	DataPack dp = new DataPack();
	dp.WriteCell(GetClientUserId(client));
	dp.WriteCell(accountId);
	dp.WriteString(steamId2);
	dp.WriteCell(GetTime());
	return dp;
}

bool ReadBanCheckDataPack(DataPack dp, int &userId, int &accountId, char[] steamId2, int steamIdLen, int &timestamp)
{
	if (dp == null)
		return false;
	
	dp.Reset();
	userId = dp.ReadCell();
	accountId = dp.ReadCell();
	dp.ReadString(steamId2, steamIdLen);
	timestamp = dp.ReadCell();
	
	return true;
}

bool ReadBanActionDataPack(DataPack dp, int &adminUserId, int &targetAccountId, char[] targetSteamId2, int steamIdLen, int &banType, int &duration, char[] reason, int reasonLen, int &timestamp)
{
	if (dp == null)
		return false;
	
	dp.Reset();
	adminUserId = dp.ReadCell();
	targetAccountId = dp.ReadCell();
	dp.ReadString(targetSteamId2, steamIdLen);
	banType = dp.ReadCell();
	duration = dp.ReadCell();
	dp.ReadString(reason, reasonLen);
	timestamp = dp.ReadCell();
	
	return true;
}

void AsyncCheckPlayerBan(int client, int accountId, const char[] steamId2)
{
	if (!IsValidClient(client))
		return;
	
	DataPack dp = CreateBanCheckDataPack(client, accountId, steamId2);

	g_PlayerBans[client].isChecking = true;
	RequestFrame(Frame_CheckPlayerBan, dp);
}

public void Frame_CheckPlayerBan(DataPack dp)
{
	int userId, accountId, timestamp;
	char sSteamId2[MAX_AUTHID_LENGTH];
	
	if (!ReadBanCheckDataPack(dp, userId, accountId, sSteamId2, sizeof(sSteamId2), timestamp))
	{
		delete dp;
		return;
	}
	
	int client = GetClientOfUserId(userId);
	if (client == 0)
	{
		delete dp;
		return;
	}
	
	CVB_CheckActiveBan(accountId, client);
	delete dp;
}

void InitThreadingQueue()
{
	if (g_hAsyncQueue != null)
		delete g_hAsyncQueue;
	
	g_hAsyncQueue = new ArrayList();
	g_bProcessingQueue = false;
	
	CreateTimer(THREAD_PROCESS_INTERVAL, Timer_ProcessAsyncQueue, _, TIMER_REPEAT);
	CVBLog.Debug("Sistema de queue de threading inicializado");
}

public Action Timer_ProcessAsyncQueue(Handle timer)
{
	if (g_hAsyncQueue == null || g_hAsyncQueue.Length == 0 || g_bProcessingQueue)
		return Plugin_Continue;
	
	g_bProcessingQueue = true;
	
	int queueItemIndex = g_hAsyncQueue.Get(0);
	DataPack queueItem = view_as<DataPack>(queueItemIndex);
	
	g_hAsyncQueue.Erase(0);
	
	if (queueItem != null)
	{
		queueItem.Reset();
		
		char sOperation[32];
		queueItem.ReadString(sOperation, sizeof(sOperation));
		
		int dataIndex = queueItem.ReadCell();
		DataPack data = view_as<DataPack>(dataIndex);
		
		ProcessQueuedOperation(sOperation, data);
		
		delete queueItem;
	}
	
	g_bProcessingQueue = false;
	return Plugin_Continue;
}

void ProcessQueuedOperation(const char[] operation, DataPack data)
{
	if (StrEqual(operation, "ban_check"))
	{
		ProcessQueuedBanCheck(data);
	}
	else if (StrEqual(operation, "ban_insert"))
	{
		ProcessQueuedBanInsert(data);
	}
	else if (StrEqual(operation, "ban_remove"))
	{
		ProcessQueuedBanRemove(data);
	}
	else
	{
		LogError("Operación de queue desconocida: %s", operation);
		delete data;
	}
}

void ProcessQueuedBanCheck(DataPack data)
{
	int userId, accountId, timestamp;
	char sSteamId2[MAX_AUTHID_LENGTH];
	
	if (!ReadBanCheckDataPack(data, userId, accountId, sSteamId2, sizeof(sSteamId2), timestamp))
	{
		delete data;
		return;
	}
	
	int client = GetClientOfUserId(userId);
	if (client == 0)
	{
		delete data;
		return;
	}
	
	if (GetTime() - timestamp > 60)
	{
		CVBLog.Debug("Verificación de ban timeout para AccountID %d", accountId);
		g_PlayerBans[client].isChecking = false;
		delete data;
		return;
	}
	

	CVB_CheckActiveBan(accountId, client);
	delete data;
}

void ProcessQueuedBanInsert(DataPack data)
{
	int adminUserId, targetAccountId, banType, duration, timestamp;
	char sTargetSteamId2[MAX_AUTHID_LENGTH];
	char sReason[256];
	
	if (!ReadBanActionDataPack(data, adminUserId, targetAccountId, sTargetSteamId2, sizeof(sTargetSteamId2), banType, duration, sReason, sizeof(sReason), timestamp))
	{
		delete data;
		return;
	}
	
	if (GetTime() - timestamp > 300)
	{
		CVBLog.Debug("Inserción de ban timeout para AccountID %d", targetAccountId);
		delete data;
		return;
	}
	
	int admin = GetClientOfUserId(adminUserId);
	int adminAccountId = 0;
	char sAdminSteamId2[MAX_AUTHID_LENGTH];
	
	if (admin == 0 || !IsValidClient(admin))
	{
		strcopy(sAdminSteamId2, sizeof(sAdminSteamId2), "CONSOLE");
	}
	else
	{
		adminAccountId = GetSteamAccountID(admin);
		GetClientAuthId(admin, AuthId_Steam2, sAdminSteamId2, sizeof(sAdminSteamId2));
	}

	int reasonCode = GetBanReasonFromString_Enhanced(sReason);
	CVB_InsertBan(targetAccountId, banType, duration, adminAccountId, reasonCode);
	
	delete data;
}

void ProcessQueuedBanRemove(DataPack data)
{
	int adminUserId, targetAccountId, banType, duration, timestamp;
	char sTargetSteamId2[MAX_AUTHID_LENGTH];
	char sReason[256];
	
	if (!ReadBanActionDataPack(data, adminUserId, targetAccountId, sTargetSteamId2, sizeof(sTargetSteamId2), banType, duration, sReason, sizeof(sReason), timestamp))
	{
		delete data;
		return;
	}
	
	if (GetTime() - timestamp > 300)
	{
		CVBLog.Debug("Remoción de ban timeout para AccountID %d", targetAccountId);
		delete data;
		return;
	}
	
	int admin = GetClientOfUserId(adminUserId);
	int adminAccountId = 0;
	char sAdminSteamId2[MAX_AUTHID_LENGTH];
	
	if (admin == 0 || !IsValidClient(admin))
	{
		strcopy(sAdminSteamId2, sizeof(sAdminSteamId2), "CONSOLE");
	}
	else
	{
		adminAccountId = GetSteamAccountID(admin);
		GetClientAuthId(admin, AuthId_Steam2, sAdminSteamId2, sizeof(sAdminSteamId2));
	}

	CVB_RemoveBan(targetAccountId, adminAccountId);
	delete data;
}

public Action Timer_DelayedPlayerCheck(Handle timer, DataPack dp)
{
	int userId, accountId, timestamp;
	char sSteamId2[MAX_AUTHID_LENGTH];
	
	if (!ReadBanCheckDataPack(dp, userId, accountId, sSteamId2, sizeof(sSteamId2), timestamp))
	{
		return Plugin_Stop;
	}
	
	int client = GetClientOfUserId(userId);
	if (client == 0)
	{
		return Plugin_Stop;
	}
	
	if (!g_PlayerBans[client].isLoaded && !g_PlayerBans[client].isChecking)
	{
		AsyncCheckPlayerBan(client, accountId, sSteamId2);
	}
	
	return Plugin_Stop;
}

void CloseThreading()
{
	if (g_hAsyncQueue != null)
	{
		for (int i = 0; i < g_hAsyncQueue.Length; i++)
		{
			int queueItemIndex = g_hAsyncQueue.Get(i);
			DataPack queueItem = view_as<DataPack>(queueItemIndex);
			
			if (queueItem != null)
			{
				queueItem.Reset();
				
				char sOperation[32];
				queueItem.ReadString(sOperation, sizeof(sOperation));
				
				int dataIndex = queueItem.ReadCell();
				DataPack data = view_as<DataPack>(dataIndex);
				
				delete data;
				delete queueItem;
			}
		}
		
		delete g_hAsyncQueue;
		g_hAsyncQueue = null;
	}
	
	g_bProcessingQueue = false;
	
	CVBLog.Debug("Sistema de threading cerrado");
}
