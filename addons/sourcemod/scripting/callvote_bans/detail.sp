#if defined _cvb_detail_included
	#endinput
#endif
#define _cvb_detail_included

enum struct CVBFullLookupContext
{
	int AdminUserId;
	ReplySource ReplySource;
	int TargetAccountId;
	int RequestedTargetClient;
	char TargetDisplay[MAX_NAME_LENGTH];
}

static void CVB_BuildActiveBanLookupQuery(char[] query, int maxLen, SourceDB source, int accountId)
{
	if (source == SourceDB_MySQL)
	{
		FormatEx(
			query,
			maxLen,
			"SELECT `ban_type`, `created_timestamp`, `duration_minutes`, `expires_timestamp`, COALESCE(`admin_account_id`, 0), COALESCE(`reason`, '') "
			... "FROM `%s` WHERE `account_id` = %d AND `is_active` = 1 "
			... "AND `active_until_timestamp` > %d "
			... "ORDER BY `created_timestamp` DESC LIMIT 1",
			TABLE_BANS,
			accountId,
			GetTime()
		);
		return;
	}

	FormatEx(
		query,
		maxLen,
		"SELECT ban_type, created_timestamp, duration_minutes, expires_timestamp, COALESCE(admin_account_id, 0), COALESCE(reason, '') "
		... "FROM %s WHERE account_id = %d AND is_active = 1 "
		... "AND (expires_timestamp = 0 OR expires_timestamp > %d) "
		... "ORDER BY created_timestamp DESC LIMIT 1",
		TABLE_BANS,
		accountId,
		GetTime()
	);
}

static void CVB_BuildFullBanLookupQuery(char[] query, int maxLen, SourceDB source, int accountId)
{
	if (source == SourceDB_MySQL)
	{
		FormatEx(
			query,
			maxLen,
			"SELECT `ban_type`, `expires_timestamp`, `created_timestamp`, `duration_minutes`, COALESCE(`admin_account_id`, 0), COALESCE(`reason`, '') "
			... "FROM `%s` WHERE `account_id` = %d AND `is_active` = 1 AND `active_until_timestamp` > %d "
			... "ORDER BY `created_timestamp` DESC LIMIT 1",
			TABLE_BANS,
			accountId,
			GetTime()
		);
		return;
	}

	FormatEx(
		query,
		maxLen,
		"SELECT ban_type, expires_timestamp, created_timestamp, duration_minutes, COALESCE(admin_account_id, 0), COALESCE(reason, '') "
		... "FROM %s WHERE account_id = %d AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > %d) "
		... "ORDER BY created_timestamp DESC LIMIT 1",
		TABLE_BANS,
		accountId,
		GetTime()
	);
}

static bool CVB_FillActiveBanInfoFromRow(DBResultSet results, SourceDB source, PlayerBanInfo banInfo)
{
	if (!results.FetchRow())
		return false;

	banInfo.BanType = results.FetchInt(0);
	banInfo.CreatedTimestamp = results.FetchInt(1);
	banInfo.DurationMinutes = results.FetchInt(2);
	banInfo.ExpiresTimestamp = results.FetchInt(3);
	banInfo.AdminAccountId = results.FetchInt(4);

	char reason[128];
	results.FetchString(5, reason, sizeof(reason));
	banInfo.SetReason(reason);
	banInfo.DbSource = source;
	return true;
}

static bool CVB_FillFullBanInfoFromRow(DBResultSet results, SourceDB source, PlayerBanInfo banInfo)
{
	if (!results.FetchRow())
		return false;

	banInfo.BanType = results.FetchInt(0);
	banInfo.ExpiresTimestamp = results.FetchInt(1);
	banInfo.CreatedTimestamp = results.FetchInt(2);
	banInfo.DurationMinutes = results.FetchInt(3);
	banInfo.AdminAccountId = results.FetchInt(4);

	char reason[128];
	results.FetchString(5, reason, sizeof(reason));
	banInfo.SetReason(reason);
	banInfo.DbSource = source;
	return true;
}

bool CVB_CheckMysqlActiveBan(PlayerBanInfo banInfo)
{
	if (g_hMySQLDB == null)
		return false;

	char query[512];
	CVB_BuildActiveBanLookupQuery(query, sizeof(query), SourceDB_MySQL, banInfo.AccountId);

	DBResultSet results = SQL_Query(g_hMySQLDB, query);
	if (results == null)
	{
		char error[256];
		SQL_GetError(g_hMySQLDB, error, sizeof(error));
		CVBLog.MySQL("Error checking MySQL active ban: %s", error);
		return false;
	}

	if (!CVB_FillActiveBanInfoFromRow(results, SourceDB_MySQL, banInfo))
	{
		delete results;
		return false;
	}

	delete results;
	return true;
}

bool CVB_CheckSQLiteActiveBan(PlayerBanInfo banInfo)
{
	if (g_hSQLiteDB == null)
		return false;

	char query[512];
	CVB_BuildActiveBanLookupQuery(query, sizeof(query), SourceDB_SQLite, banInfo.AccountId);

	DBResultSet results = SQL_Query(g_hSQLiteDB, query);
	if (results == null)
	{
		char error[256];
		SQL_GetError(g_hSQLiteDB, error, sizeof(error));
		CVBLog.SQLite("Error checking SQLite active ban: %s", error);
		return false;
	}

	if (!CVB_FillActiveBanInfoFromRow(results, SourceDB_SQLite, banInfo))
	{
		delete results;
		return false;
	}

	delete results;
	return true;
}

bool CVB_CheckActiveBan(PlayerBanInfo banInfo)
{
	switch (CVB_GetActiveDatabase())
	{
		case SourceDB_MySQL:
		{
			return CVB_CheckMysqlActiveBan(banInfo);
		}
		case SourceDB_SQLite:
		{
			return CVB_CheckSQLiteActiveBan(banInfo);
		}
	}

	return false;
}

static DataPack CVB_CreateFullLookupContextPack(int adminUserId, ReplySource replySource, int targetAccountId, int requestedTargetClient, const char[] targetDisplay)
{
	DataPack pack = new DataPack();
	pack.WriteCell(adminUserId);
	pack.WriteCell(view_as<int>(replySource));
	pack.WriteCell(targetAccountId);
	pack.WriteCell(requestedTargetClient);
	pack.WriteString(targetDisplay);
	return pack;
}

static void CVB_ReadFullLookupContext(DataPack pack, CVBFullLookupContext context)
{
	pack.Reset();
	context.AdminUserId = pack.ReadCell();
	context.ReplySource = view_as<ReplySource>(pack.ReadCell());
	context.TargetAccountId = pack.ReadCell();
	context.RequestedTargetClient = pack.ReadCell();
	pack.ReadString(context.TargetDisplay, sizeof(context.TargetDisplay));
}

static void CVB_ReplyFullLookupDatabaseError(int admin, ReplySource replySource, const char[] detail = "")
{
	CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "DatabaseError");

	if (detail[0] != '\0')
		CVB_ReplyToCommandWithSource(admin, replySource, "%s", detail);
}

static void CVB_SendFullBanStatusReply(PlayerBanInfo banInfo, int admin, ReplySource replySource, int targetClient, const char[] targetDisplay, bool hasBan)
{
	if (admin == NO_INDEX)
		return;

	char resolvedTargetDisplay[MAX_NAME_LENGTH];
	strcopy(resolvedTargetDisplay, sizeof(resolvedTargetDisplay), targetDisplay);
	if (resolvedTargetDisplay[0] == '\0')
		strcopy(resolvedTargetDisplay, sizeof(resolvedTargetDisplay), "Unknown Player");

	if (targetClient != NO_INDEX && IsValidClientIndex(targetClient))
		GetClientName(targetClient, resolvedTargetDisplay, sizeof(resolvedTargetDisplay));

	CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "BanStatusHeader", resolvedTargetDisplay);
	CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "BanStatusAccountID", banInfo.AccountId);

	if (!hasBan)
	{
		CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "BanStatusUnbanned");
		return;
	}

	char banTypes[128];
	char expiration[64];
	banInfo.GetBanTypeString(banTypes, sizeof(banTypes));

	if (banInfo.ExpiresTimestamp == 0)
		Format(expiration, sizeof(expiration), "%T", "BanStatusPermanent", admin);
	else
		FormatTime(expiration, sizeof(expiration), "%Y-%m-%d %H:%M:%S", banInfo.ExpiresTimestamp);

	CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "BanStatusBanned");
	CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "BanStatusRestrictedTypes", banTypes);
	CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "BanStatusExpiration", expiration);
}

static void CVB_FinalizeFullBanLookup(
	int adminUserId,
	ReplySource replySource,
	int requestedTargetClient,
	const char[] targetDisplay,
	PlayerBanInfo banInfo,
	bool hasBan
)
{
	int admin;
	if (!CVB_TryResolveCommandIssuer(adminUserId, admin))
		return;

	if (hasBan)
	{
		CVB_UpdateMemoryCache(banInfo);
	}
	else
	{
		banInfo.Clear();
		CVB_UpdateMemoryCache(banInfo);
	}

	int liveTarget = NO_INDEX;
	if (requestedTargetClient > 0 && IsValidClient(requestedTargetClient) && GetSteamAccountID(requestedTargetClient) == banInfo.AccountId)
	{
		liveTarget = requestedTargetClient;
	}
	else
	{
		liveTarget = FindClientByAccountID(banInfo.AccountId);
	}

	if (liveTarget != NO_INDEX && IsValidClientIndex(liveTarget))
		SetClientLoadState(liveTarget, banInfo.AccountId, ClientBanLoad_Ready);

	CVB_SendFullBanStatusReply(banInfo, admin, replySource, liveTarget, targetDisplay, hasBan);
}

static void CVB_ProcessSQLiteFullBanLookup(
	int admin,
	ReplySource replySource,
	int targetAccountId,
	int requestedTargetClient,
	const char[] targetDisplay
)
{
	if (g_hSQLiteDB == null)
		return;

	char query[MAX_QUERY_LENGTH];
	CVB_BuildFullBanLookupQuery(query, sizeof(query), SourceDB_SQLite, targetAccountId);

	DBResultSet results = SQL_Query(g_hSQLiteDB, query);
	if (results == null)
	{
		char error[256];
		SQL_GetError(g_hSQLiteDB, error, sizeof(error));
		CVBLog.SQLite("SQLite full lookup failed for AccountID %d: %s", targetAccountId, error);
		CVB_ReplyFullLookupDatabaseError(admin, replySource, error);
		return;
	}

	PlayerBanInfo banInfo;
	banInfo.Reset(targetAccountId);
	banInfo.DbSource = SourceDB_SQLite;

	if (CVB_FillFullBanInfoFromRow(results, SourceDB_SQLite, banInfo))
	{
		CVB_FinalizeFullBanLookup(CVB_GetCommandIssuerUserId(admin), replySource, requestedTargetClient, targetDisplay, banInfo, true);
	}
	else
	{
		CVB_FinalizeFullBanLookup(CVB_GetCommandIssuerUserId(admin), replySource, requestedTargetClient, targetDisplay, banInfo, false);
	}

	delete results;
}

void CVB_QueueFullBanLookup(int admin, int targetAccountId, int requestedTargetClient, const char[] targetDisplay, ReplySource replySource)
{
	SourceDB activeDb = CVB_GetActiveDatabase();
	if (activeDb == SourceDB_Unknown)
	{
		CVB_ReplyFullLookupDatabaseError(admin, replySource);
		return;
	}

	if (activeDb == SourceDB_SQLite)
	{
		CVB_ProcessSQLiteFullBanLookup(admin, replySource, targetAccountId, requestedTargetClient, targetDisplay);
		return;
	}

	if (g_hMySQLDB == null)
	{
		CVB_ReplyFullLookupDatabaseError(admin, replySource, "MySQL connection is not available");
		return;
	}

	char query[MAX_QUERY_LENGTH];
	CVB_BuildFullBanLookupQuery(query, sizeof(query), SourceDB_MySQL, targetAccountId);

	DataPack context = CVB_CreateFullLookupContextPack(CVB_GetCommandIssuerUserId(admin), replySource, targetAccountId, requestedTargetClient, targetDisplay);

	SQL_TQuery(g_hMySQLDB, CVB_OnFullBanLookupCompleted, query, context, DBPrio_Normal);
}

public void CVB_OnFullBanLookupCompleted(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack context = view_as<DataPack>(data);

	CVBFullLookupContext lookupContext;
	CVB_ReadFullLookupContext(context, lookupContext);
	delete context;

	int admin;
	if (!CVB_TryResolveCommandIssuer(lookupContext.AdminUserId, admin))
		return;

	if (results == null)
	{
		CVBLog.MySQL("MySQL full lookup failed for AccountID %d: %s", lookupContext.TargetAccountId, error);
		CVB_ReplyFullLookupDatabaseError(admin, lookupContext.ReplySource, error);
		return;
	}

	PlayerBanInfo banInfo;
	banInfo.Reset(lookupContext.TargetAccountId);
	banInfo.DbSource = SourceDB_MySQL;

	if (CVB_FillFullBanInfoFromRow(results, SourceDB_MySQL, banInfo))
	{
		CVB_FinalizeFullBanLookup(lookupContext.AdminUserId, lookupContext.ReplySource, lookupContext.RequestedTargetClient, lookupContext.TargetDisplay, banInfo, true);
	}
	else
	{
		CVB_FinalizeFullBanLookup(lookupContext.AdminUserId, lookupContext.ReplySource, lookupContext.RequestedTargetClient, lookupContext.TargetDisplay, banInfo, false);
	}
}
