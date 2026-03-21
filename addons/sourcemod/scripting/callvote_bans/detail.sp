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

enum CVBLookupStatus
{
	CVBLookup_NotFound = 0,
	CVBLookup_Found,
	CVBLookup_Error
}

static void CVB_BuildActiveBanLookupQuery(char[] query, int maxLen, SourceDB source, int accountId)
{
	int iLen = 0;

	if (source == SourceDB_MySQL)
	{
		iLen += Format(query[iLen], maxLen - iLen, "SELECT `ban_type`, `created_timestamp`, `duration_minutes`, `expires_timestamp`, ");
		iLen += Format(query[iLen], maxLen - iLen, "COALESCE(`admin_account_id`, 0), COALESCE(`reason`, '') ");
		iLen += Format(query[iLen], maxLen - iLen, "FROM `%s` WHERE `account_id` = %d AND `is_active` = 1 ", TABLE_BANS, accountId);
		iLen += Format(query[iLen], maxLen - iLen, "AND `active_until_timestamp` > %d ", GetTime());
		iLen += Format(query[iLen], maxLen - iLen, "ORDER BY `created_timestamp` DESC LIMIT 1");
		return;
	}

	iLen += Format(query[iLen], maxLen - iLen, "SELECT ban_type, created_timestamp, duration_minutes, expires_timestamp, ");
	iLen += Format(query[iLen], maxLen - iLen, "COALESCE(admin_account_id, 0), COALESCE(reason, '') ");
	iLen += Format(query[iLen], maxLen - iLen, "FROM %s WHERE account_id = %d AND is_active = 1 ", TABLE_BANS, accountId);
	iLen += Format(query[iLen], maxLen - iLen, "AND (expires_timestamp = 0 OR expires_timestamp > %d) ", GetTime());
	iLen += Format(query[iLen], maxLen - iLen, "ORDER BY created_timestamp DESC LIMIT 1");
}

static void CVB_BuildFullRestrictionLookupQuery(char[] query, int maxLen, SourceDB source, int accountId)
{
	int iLen = 0;

	if (source == SourceDB_MySQL)
	{
		iLen += Format(query[iLen], maxLen - iLen, "SELECT `ban_type`, `expires_timestamp`, `created_timestamp`, `duration_minutes`, ");
		iLen += Format(query[iLen], maxLen - iLen, "COALESCE(`admin_account_id`, 0), COALESCE(`reason`, '') ");
		iLen += Format(query[iLen], maxLen - iLen, "FROM `%s` WHERE `account_id` = %d AND `is_active` = 1 ", TABLE_BANS, accountId);
		iLen += Format(query[iLen], maxLen - iLen, "AND `active_until_timestamp` > %d ", GetTime());
		iLen += Format(query[iLen], maxLen - iLen, "ORDER BY `created_timestamp` DESC LIMIT 1");
		return;
	}

	iLen += Format(query[iLen], maxLen - iLen, "SELECT ban_type, expires_timestamp, created_timestamp, duration_minutes, ");
	iLen += Format(query[iLen], maxLen - iLen, "COALESCE(admin_account_id, 0), COALESCE(reason, '') ");
	iLen += Format(query[iLen], maxLen - iLen, "FROM %s WHERE account_id = %d AND is_active = 1 ", TABLE_BANS, accountId);
	iLen += Format(query[iLen], maxLen - iLen, "AND (expires_timestamp = 0 OR expires_timestamp > %d) ", GetTime());
	iLen += Format(query[iLen], maxLen - iLen, "ORDER BY created_timestamp DESC LIMIT 1");
}

static bool CVB_FillActiveRestrictionInfoFromRow(DBResultSet results, SourceDB source, PlayerRestrictionInfo restrictionInfo)
{
	if (!results.FetchRow())
		return false;

	restrictionInfo.RestrictionMask = results.FetchInt(0);
	restrictionInfo.CreatedTimestamp = results.FetchInt(1);
	restrictionInfo.DurationMinutes = results.FetchInt(2);
	restrictionInfo.ExpiresTimestamp = results.FetchInt(3);
	restrictionInfo.AdminAccountId = results.FetchInt(4);

	char reason[128];
	results.FetchString(5, reason, sizeof(reason));
	restrictionInfo.SetReason(reason);
	restrictionInfo.DbSource = source;
	return true;
}

static bool CVB_FillFullRestrictionInfoFromRow(DBResultSet results, SourceDB source, PlayerRestrictionInfo restrictionInfo)
{
	if (!results.FetchRow())
		return false;

	restrictionInfo.RestrictionMask = results.FetchInt(0);
	restrictionInfo.ExpiresTimestamp = results.FetchInt(1);
	restrictionInfo.CreatedTimestamp = results.FetchInt(2);
	restrictionInfo.DurationMinutes = results.FetchInt(3);
	restrictionInfo.AdminAccountId = results.FetchInt(4);

	char reason[128];
	results.FetchString(5, reason, sizeof(reason));
	restrictionInfo.SetReason(reason);
	restrictionInfo.DbSource = source;
	return true;
}

CVBLookupStatus CVB_CheckMysqlActiveRestriction(PlayerRestrictionInfo restrictionInfo)
{
	if (g_hMySQLDB == null)
		return CVBLookup_Error;

	char query[512];
	CVB_BuildActiveBanLookupQuery(query, sizeof(query), SourceDB_MySQL, restrictionInfo.AccountId);

	DBResultSet results = SQL_Query(g_hMySQLDB, query);
	if (results == null)
	{
		char error[256];
		SQL_GetError(g_hMySQLDB, error, sizeof(error));
		CVBLog.MySQL("Error checking MySQL active restriction: %s", error);
		return CVBLookup_Error;
	}

	if (!CVB_FillActiveRestrictionInfoFromRow(results, SourceDB_MySQL, restrictionInfo))
	{
		delete results;
		return CVBLookup_NotFound;
	}

	delete results;
	return CVBLookup_Found;
}

CVBLookupStatus CVB_CheckSQLiteActiveRestriction(PlayerRestrictionInfo restrictionInfo)
{
	if (g_hSQLiteDB == null)
		return CVBLookup_Error;

	char query[512];
	CVB_BuildActiveBanLookupQuery(query, sizeof(query), SourceDB_SQLite, restrictionInfo.AccountId);

	DBResultSet results = SQL_Query(g_hSQLiteDB, query);
	if (results == null)
	{
		char error[256];
		SQL_GetError(g_hSQLiteDB, error, sizeof(error));
		CVBLog.SQLite("Error checking SQLite active restriction: %s", error);
		return CVBLookup_Error;
	}

	if (!CVB_FillActiveRestrictionInfoFromRow(results, SourceDB_SQLite, restrictionInfo))
	{
		delete results;
		return CVBLookup_NotFound;
	}

	delete results;
	return CVBLookup_Found;
}

CVBLookupStatus CVB_CheckActiveRestriction(PlayerRestrictionInfo restrictionInfo)
{
	switch (CVB_GetActiveDatabase())
	{
		case SourceDB_MySQL:
		{
			return CVB_CheckMysqlActiveRestriction(restrictionInfo);
		}
		case SourceDB_SQLite:
		{
			return CVB_CheckSQLiteActiveRestriction(restrictionInfo);
		}
	}

	return CVBLookup_Error;
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

static void CVB_SendFullRestrictionStatusReply(PlayerRestrictionInfo restrictionInfo, int admin, ReplySource replySource, int targetClient, const char[] targetDisplay, bool hasRestriction)
{
	if (admin == NO_INDEX)
		return;

	char resolvedTargetDisplay[MAX_NAME_LENGTH];
	strcopy(resolvedTargetDisplay, sizeof(resolvedTargetDisplay), targetDisplay);
	if (resolvedTargetDisplay[0] == '\0')
		strcopy(resolvedTargetDisplay, sizeof(resolvedTargetDisplay), "Unknown Player");

	if (targetClient != NO_INDEX && IsValidClientIndex(targetClient))
		GetClientName(targetClient, resolvedTargetDisplay, sizeof(resolvedTargetDisplay));

	CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "RestrictionStatusHeader", resolvedTargetDisplay);
	CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "RestrictionStatusAccountID", restrictionInfo.AccountId);

	if (!hasRestriction)
	{
		CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "RestrictionStatusClear");
		return;
	}

	char banTypes[128];
	char expiration[64];
	restrictionInfo.GetBanTypeString(banTypes, sizeof(banTypes));

	if (restrictionInfo.ExpiresTimestamp == 0)
		Format(expiration, sizeof(expiration), "%T", "RestrictionStatusPermanent", admin);
	else
		FormatTime(expiration, sizeof(expiration), "%Y-%m-%d %H:%M:%S", restrictionInfo.ExpiresTimestamp);

	CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "RestrictionStatusActive");
	CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "RestrictionStatusTypes", banTypes);
	CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "RestrictionStatusExpiration", expiration);
}

static void CVB_FinalizeFullRestrictionLookup(
	int adminUserId,
	ReplySource replySource,
	int requestedTargetClient,
	const char[] targetDisplay,
	PlayerRestrictionInfo restrictionInfo,
	bool hasRestriction
)
{
	int admin;
	if (!CVB_TryResolveCommandIssuer(adminUserId, admin))
		return;

	if (hasRestriction)
	{
		CVB_UpdateMemoryCache(restrictionInfo);
	}
	else
	{
		restrictionInfo.Clear();
		CVB_UpdateMemoryCache(restrictionInfo);
	}

	int liveTarget = NO_INDEX;
	if (requestedTargetClient > 0 && IsValidClient(requestedTargetClient) && GetSteamAccountID(requestedTargetClient) == restrictionInfo.AccountId)
	{
		liveTarget = requestedTargetClient;
	}
	else
	{
		liveTarget = FindClientByAccountID(restrictionInfo.AccountId);
	}

	if (liveTarget != NO_INDEX && IsValidClientIndex(liveTarget))
		SetClientLoadState(liveTarget, restrictionInfo.AccountId, ClientBanLoad_Ready);

	CVB_SendFullRestrictionStatusReply(restrictionInfo, admin, replySource, liveTarget, targetDisplay, hasRestriction);
}

static void CVB_ProcessSQLiteFullRestrictionLookup(
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
	CVB_BuildFullRestrictionLookupQuery(query, sizeof(query), SourceDB_SQLite, targetAccountId);

	DBResultSet results = SQL_Query(g_hSQLiteDB, query);
	if (results == null)
	{
		char error[256];
		SQL_GetError(g_hSQLiteDB, error, sizeof(error));
		CVBLog.SQLite("SQLite full lookup failed for AccountID %d: %s", targetAccountId, error);
		CVB_ReplyFullLookupDatabaseError(admin, replySource, error);
		return;
	}

	PlayerRestrictionInfo restrictionInfo;
	restrictionInfo.Reset(targetAccountId);
	restrictionInfo.DbSource = SourceDB_SQLite;

	if (CVB_FillFullRestrictionInfoFromRow(results, SourceDB_SQLite, restrictionInfo))
	{
		CVB_FinalizeFullRestrictionLookup(CVB_GetCommandIssuerUserId(admin), replySource, requestedTargetClient, targetDisplay, restrictionInfo, true);
	}
	else
	{
		CVB_FinalizeFullRestrictionLookup(CVB_GetCommandIssuerUserId(admin), replySource, requestedTargetClient, targetDisplay, restrictionInfo, false);
	}

	delete results;
}

void CVB_QueueFullRestrictionLookup(int admin, int targetAccountId, int requestedTargetClient, const char[] targetDisplay, ReplySource replySource)
{
	SourceDB activeDb = CVB_GetActiveDatabase();
	if (activeDb == SourceDB_Unknown)
	{
		CVB_ReplyFullLookupDatabaseError(admin, replySource);
		return;
	}

	if (activeDb == SourceDB_SQLite)
	{
		CVB_ProcessSQLiteFullRestrictionLookup(admin, replySource, targetAccountId, requestedTargetClient, targetDisplay);
		return;
	}

	if (g_hMySQLDB == null)
	{
		CVB_ReplyFullLookupDatabaseError(admin, replySource, "MySQL connection is not available");
		return;
	}

	char query[MAX_QUERY_LENGTH];
	CVB_BuildFullRestrictionLookupQuery(query, sizeof(query), SourceDB_MySQL, targetAccountId);

	DataPack context = CVB_CreateFullLookupContextPack(CVB_GetCommandIssuerUserId(admin), replySource, targetAccountId, requestedTargetClient, targetDisplay);

	SQL_TQuery(g_hMySQLDB, CVB_OnFullRestrictionLookupCompleted, query, context, DBPrio_Normal);
}

public void CVB_OnFullRestrictionLookupCompleted(Database db, DBResultSet results, const char[] error, any data)
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

	PlayerRestrictionInfo restrictionInfo;
	restrictionInfo.Reset(lookupContext.TargetAccountId);
	restrictionInfo.DbSource = SourceDB_MySQL;

	if (CVB_FillFullRestrictionInfoFromRow(results, SourceDB_MySQL, restrictionInfo))
	{
		CVB_FinalizeFullRestrictionLookup(lookupContext.AdminUserId, lookupContext.ReplySource, lookupContext.RequestedTargetClient, lookupContext.TargetDisplay, restrictionInfo, true);
	}
	else
	{
		CVB_FinalizeFullRestrictionLookup(lookupContext.AdminUserId, lookupContext.ReplySource, lookupContext.RequestedTargetClient, lookupContext.TargetDisplay, restrictionInfo, false);
	}
}
