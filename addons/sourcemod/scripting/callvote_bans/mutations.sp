#if defined _cvb_mutations_included
	#endinput
#endif
#define _cvb_mutations_included

static const int CVB_ACTIVE_UNTIL_PERMANENT = 2147483647;

enum struct CVBAddBanContext
{
	int AdminUserId;
	ReplySource ReplySource;
	int TargetAccountId;
	int RequestedTargetClient;
	int BanType;
	int DurationMinutes;
	char TargetDisplay[MAX_NAME_LENGTH];
	char Reason[256];
}

enum struct CVBRemoveBanContext
{
	int AdminUserId;
	ReplySource ReplySource;
	int TargetAccountId;
	int RequestedTargetClient;
	char TargetDisplay[MAX_NAME_LENGTH];
}

static DataPack CVB_CreateAddBanContextPack(
	int adminUserId,
	ReplySource replySource,
	int targetAccountId,
	int requestedTargetClient,
	int banType,
	int durationMinutes,
	const char[] targetDisplay,
	const char[] reason
)
{
	DataPack pack = new DataPack();
	pack.WriteCell(adminUserId);
	pack.WriteCell(view_as<int>(replySource));
	pack.WriteCell(targetAccountId);
	pack.WriteCell(requestedTargetClient);
	pack.WriteCell(banType);
	pack.WriteCell(durationMinutes);
	pack.WriteString(targetDisplay);
	pack.WriteString(reason);
	return pack;
}

static void CVB_ReadAddBanContext(DataPack pack, CVBAddBanContext context)
{
	pack.Reset();
	context.AdminUserId = pack.ReadCell();
	context.ReplySource = view_as<ReplySource>(pack.ReadCell());
	context.TargetAccountId = pack.ReadCell();
	context.RequestedTargetClient = pack.ReadCell();
	context.BanType = pack.ReadCell();
	context.DurationMinutes = pack.ReadCell();
	pack.ReadString(context.TargetDisplay, sizeof(context.TargetDisplay));
	pack.ReadString(context.Reason, sizeof(context.Reason));
}

static DataPack CVB_CreateRemoveBanContextPack(
	int adminUserId,
	ReplySource replySource,
	int targetAccountId,
	int requestedTargetClient,
	const char[] targetDisplay
)
{
	DataPack pack = new DataPack();
	pack.WriteCell(adminUserId);
	pack.WriteCell(view_as<int>(replySource));
	pack.WriteCell(targetAccountId);
	pack.WriteCell(requestedTargetClient);
	pack.WriteString(targetDisplay);
	return pack;
}

static void CVB_ReadRemoveBanContext(DataPack pack, CVBRemoveBanContext context)
{
	pack.Reset();
	context.AdminUserId = pack.ReadCell();
	context.ReplySource = view_as<ReplySource>(pack.ReadCell());
	context.TargetAccountId = pack.ReadCell();
	context.RequestedTargetClient = pack.ReadCell();
	pack.ReadString(context.TargetDisplay, sizeof(context.TargetDisplay));
}

static bool CVB_TryResolveLiveTarget(int requestedTargetClient, int targetAccountId, int &liveTarget)
{
	liveTarget = NO_INDEX;

	if (requestedTargetClient > 0 && IsValidClient(requestedTargetClient) && GetSteamAccountID(requestedTargetClient) == targetAccountId)
	{
		liveTarget = requestedTargetClient;
		return true;
	}

	int resolvedTarget = FindClientByAccountID(targetAccountId);
	if (resolvedTarget > 0 && IsValidClient(resolvedTarget))
	{
		liveTarget = resolvedTarget;
		return true;
	}

	return false;
}

static void CVB_ReplyDatabaseErrorWithSource(int admin, ReplySource replySource)
{
	CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "DatabaseError");
}

static bool CVB_ExecuteSQLiteAddBan(int targetAccountId, int banType, int durationMinutes, int adminAccountId, const char[] reasonText)
{
	if (g_hSQLiteDB == null)
		return false;

	int currentTime = GetTime();
	int expiresTimestamp = CVB_GetExpirationTimestamp(durationMinutes);

	char escapedReason[512];
	g_hSQLiteDB.Escape(reasonText, escapedReason, sizeof(escapedReason));

	char deactivateQuery[256];
	FormatEx(
		deactivateQuery,
		sizeof(deactivateQuery),
		"UPDATE %s SET is_active = 0 WHERE account_id = %d AND is_active = 1",
		TABLE_BANS,
		targetAccountId
	);

	char insertQuery[MAX_QUERY_LENGTH];
	FormatEx(
		insertQuery,
		sizeof(insertQuery),
		"INSERT INTO %s (account_id, ban_type, created_timestamp, duration_minutes, expires_timestamp, admin_account_id, reason, is_active) "
		... "VALUES (%d, %d, %d, %d, %d, %d, '%s', 1)",
		TABLE_BANS,
		targetAccountId,
		banType,
		currentTime,
		durationMinutes,
		expiresTimestamp,
		adminAccountId,
		escapedReason
	);

	if (!SQL_FastQuery(g_hSQLiteDB, "BEGIN IMMEDIATE TRANSACTION"))
	{
		char error[256];
		SQL_GetError(g_hSQLiteDB, error, sizeof(error));
		CVBLog.SQLite("Error starting SQLite transaction for AccountID %d: %s", targetAccountId, error);
		return false;
	}

	bool hasError = false;
	char error[256];

	if (!SQL_FastQuery(g_hSQLiteDB, deactivateQuery))
	{
		SQL_GetError(g_hSQLiteDB, error, sizeof(error));
		CVBLog.SQLite("Error deactivating previous SQLite bans for AccountID %d: %s", targetAccountId, error);
		hasError = true;
	}

	if (!hasError && !SQL_FastQuery(g_hSQLiteDB, insertQuery))
	{
		SQL_GetError(g_hSQLiteDB, error, sizeof(error));
		CVBLog.SQLite("Error inserting SQLite ban for AccountID %d: %s", targetAccountId, error);
		hasError = true;
	}

	if (hasError)
	{
		if (!SQL_FastQuery(g_hSQLiteDB, "ROLLBACK TRANSACTION"))
		{
			char rollbackError[256];
			SQL_GetError(g_hSQLiteDB, rollbackError, sizeof(rollbackError));
			CVBLog.SQLite("Error rolling back SQLite transaction for AccountID %d: %s", targetAccountId, rollbackError);
		}

		return false;
	}

	if (!SQL_FastQuery(g_hSQLiteDB, "COMMIT TRANSACTION"))
	{
		SQL_GetError(g_hSQLiteDB, error, sizeof(error));
		CVBLog.SQLite("Error committing SQLite transaction for AccountID %d: %s", targetAccountId, error);

		if (!SQL_FastQuery(g_hSQLiteDB, "ROLLBACK TRANSACTION"))
		{
			char rollbackError[256];
			SQL_GetError(g_hSQLiteDB, rollbackError, sizeof(rollbackError));
			CVBLog.SQLite("Error rolling back failed SQLite commit for AccountID %d: %s", targetAccountId, rollbackError);
		}

		return false;
	}

	CVBLog.SQLite("Inserted SQLite ban for AccountID %d (type=%d duration=%d)", targetAccountId, banType, durationMinutes);
	return true;
}

static bool CVB_ExecuteSQLiteRemoveBan(int targetAccountId, int &affectedRows)
{
	affectedRows = 0;

	if (g_hSQLiteDB == null)
		return false;

	char query[512];
	FormatEx(
		query,
		sizeof(query),
		"UPDATE %s SET is_active = 0 WHERE account_id = %d AND is_active = 1 AND (expires_timestamp = 0 OR expires_timestamp > %d)",
		TABLE_BANS,
		targetAccountId,
		GetTime()
	);

	if (!SQL_FastQuery(g_hSQLiteDB, query))
	{
		char error[256];
		SQL_GetError(g_hSQLiteDB, error, sizeof(error));
		CVBLog.SQLite("Error removing SQLite ban for AccountID %d: %s", targetAccountId, error);
		return false;
	}

	affectedRows = SQL_GetAffectedRows(g_hSQLiteDB);
	return true;
}

static void CVB_FinalizeQueuedBanSuccess(
	int adminUserId,
	ReplySource replySource,
	int targetAccountId,
	int requestedTargetClient,
	int banType,
	int durationMinutes,
	const char[] targetDisplay,
	const char[] reason
)
{
	int admin;
	bool canReply = CVB_TryResolveCommandIssuer(adminUserId, admin);

	int adminAccountId;
	char adminSteamId2[MAX_AUTHID_LENGTH];
	GetAdminInfo(admin, adminAccountId, adminSteamId2, sizeof(adminSteamId2));

	int liveTarget;
	bool targetOnline = CVB_TryResolveLiveTarget(requestedTargetClient, targetAccountId, liveTarget);
	int expiresTimestamp = CVB_GetExpirationTimestamp(durationMinutes);
	if (targetOnline)
	{
		SetClientBanInfo(liveTarget, banType, durationMinutes, expiresTimestamp);
	}
	else
	{
		ForceRefreshMemoryCacheEntry(targetAccountId);
	}

	char liveTargetDisplay[MAX_NAME_LENGTH];
	strcopy(liveTargetDisplay, sizeof(liveTargetDisplay), targetDisplay);
	if (targetOnline)
		GetClientName(liveTarget, liveTargetDisplay, sizeof(liveTargetDisplay));

	char banTypes[64];
	char durationText[64];
	GetBanTypeString(banType, banTypes, sizeof(banTypes));
	CVB_FormatDurationText(admin, durationMinutes, durationText, sizeof(durationText));

	if (canReply)
		CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "BanApplied", liveTargetDisplay, banTypes, durationText);

	CVBLog.Event(
		"Ban",
		"Applied vote restriction to AccountID %d (type=%d duration=%d adminAccountID=%d target=%s)",
		targetAccountId,
		banType,
		durationMinutes,
		adminAccountId,
		liveTargetDisplay
	);

	if (targetOnline)
	{
		if (admin > 0 && IsValidClient(admin))
			NotifyPlayerBanApplied(liveTarget, admin, "", banTypes, durationText, durationMinutes);
		else
			NotifyPlayerBanApplied(liveTarget, SERVER_INDEX, adminSteamId2, banTypes, durationText, durationMinutes);

		FireOnPlayerBanned(liveTarget, banType, durationMinutes, admin, reason);
	}

	CVBLog.Debug(
		"Ban persisted for AccountID %d (type=%d duration=%d adminUserId=%d liveTarget=%d)",
		targetAccountId,
		banType,
		durationMinutes,
		adminUserId,
		targetOnline ? liveTarget : 0
	);
}

static void CVB_FinalizeQueuedBanFailure(
	int adminUserId,
	ReplySource replySource,
	int targetAccountId,
	int banType,
	int durationMinutes,
	const char[] error
)
{
	int admin;
	if (CVB_TryResolveCommandIssuer(adminUserId, admin))
		CVB_ReplyDatabaseErrorWithSource(admin, replySource);

	CVBLog.Event(
		"BanFailed",
		"Failed to apply vote restriction to AccountID %d (type=%d duration=%d adminUserId=%d error=%s)",
		targetAccountId,
		banType,
		durationMinutes,
		adminUserId,
		error
	);
	CVBLog.MySQL(
		"Ban persist failed for AccountID %d (type=%d duration=%d adminUserId=%d): %s",
		targetAccountId,
		banType,
		durationMinutes,
		adminUserId,
		error
	);
}

static void CVB_FinalizeQueuedRemoveSuccess(
	int adminUserId,
	ReplySource replySource,
	int targetAccountId,
	int requestedTargetClient,
	const char[] targetDisplay,
	bool hadBan
)
{
	int admin;
	bool canReply = CVB_TryResolveCommandIssuer(adminUserId, admin);

	if (!hadBan)
	{
		if (canReply)
			CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "NoBanFound");

		CVBLog.SQL("No active ban found for AccountID %d", targetAccountId);
		return;
	}

	int liveTarget;
	bool targetOnline = CVB_TryResolveLiveTarget(requestedTargetClient, targetAccountId, liveTarget);
	if (targetOnline)
	{
		SetClientBanInfo(liveTarget, 0, 0, 0);
		CPrintToChat(liveTarget, "%t %t", "Tag", "YourBanRemoved");
	}
	else
	{
		ForceRefreshMemoryCacheEntry(targetAccountId);
	}

	char liveTargetDisplay[MAX_NAME_LENGTH];
	strcopy(liveTargetDisplay, sizeof(liveTargetDisplay), targetDisplay);
	if (targetOnline)
		GetClientName(liveTarget, liveTargetDisplay, sizeof(liveTargetDisplay));

	if (canReply)
		CVB_ReplyToCommandWithSource(admin, replySource, "%t %t", "Tag", "BanRemovedSuccess", liveTargetDisplay);

	CVBLog.Event(
		"Unban",
		"Removed vote restriction for AccountID %d (target=%s)",
		targetAccountId,
		liveTargetDisplay
	);

	CVBLog.SQL("Ban removed successfully for AccountID %d", targetAccountId);
}

static void CVB_FinalizeQueuedRemoveFailure(
	int adminUserId,
	ReplySource replySource,
	int targetAccountId,
	const char[] error
)
{
	int admin;
	if (CVB_TryResolveCommandIssuer(adminUserId, admin))
		CVB_ReplyDatabaseErrorWithSource(admin, replySource);

	CVBLog.Event(
		"UnbanFailed",
		"Failed to remove vote restriction for AccountID %d (adminUserId=%d error=%s)",
		targetAccountId,
		adminUserId,
		error
	);
	CVBLog.MySQL("Remove ban failed for AccountID %d: %s", targetAccountId, error);
}

bool CVB_QueueAddBan(int admin, int targetAccountId, int requestedTargetClient, int banType, int durationMinutes, const char[] targetDisplay, const char[] reasonText, ReplySource replySource)
{
	SourceDB activeDb = CVB_GetActiveDatabase();
	if (activeDb == SourceDB_Unknown)
	{
		CVB_ReplyDatabaseErrorWithSource(admin, replySource);
		return false;
	}

	int adminAccountId;
	char adminSteamId2[MAX_AUTHID_LENGTH];
	if (!GetAdminInfo(admin, adminAccountId, adminSteamId2, sizeof(adminSteamId2)))
	{
		CReplyToCommand(admin, "%t %t", "Tag", "ErrorGettingAdminInfo");
		return false;
	}

	char normalizedReason[256];
	NormalizeBanReason(reasonText, normalizedReason, sizeof(normalizedReason));

	if (activeDb == SourceDB_SQLite)
	{
		if (!CVB_ExecuteSQLiteAddBan(targetAccountId, banType, durationMinutes, adminAccountId, normalizedReason))
		{
			CVB_ReplyDatabaseErrorWithSource(admin, replySource);
			return false;
		}

		CVB_FinalizeQueuedBanSuccess(CVB_GetCommandIssuerUserId(admin), replySource, targetAccountId, requestedTargetClient, banType, durationMinutes, targetDisplay, normalizedReason);
		return true;
	}

	if (g_hMySQLDB == null)
	{
		CVB_ReplyDatabaseErrorWithSource(admin, replySource);
		return false;
	}

	int currentTime = GetTime();
	int expiresTimestamp = CVB_GetExpirationTimestamp(durationMinutes);
	int activeUntilTimestamp = (expiresTimestamp == 0) ? CVB_ACTIVE_UNTIL_PERMANENT : expiresTimestamp;

	char escapedReason[512];
	char targetSteamID64[STEAMID64_EXACT_LENGTH + 1];
	char adminSteamID64[STEAMID64_EXACT_LENGTH + 1];
	g_hMySQLDB.Escape(normalizedReason, escapedReason, sizeof(escapedReason));

	if (!SteamIDTools_AccountIDToSteamID64(targetAccountId, targetSteamID64, sizeof(targetSteamID64)))
	{
		LogError("Failed to derive target SteamID64 for AccountID %d", targetAccountId);
		CVB_ReplyDatabaseErrorWithSource(admin, replySource);
		return false;
	}

	bool hasAdminSteamID64 = false;
	if (adminAccountId > 0)
		hasAdminSteamID64 = SteamIDTools_AccountIDToSteamID64(adminAccountId, adminSteamID64, sizeof(adminSteamID64));

	char deactivateQuery[256];
	FormatEx(
		deactivateQuery,
		sizeof(deactivateQuery),
		"UPDATE `%s` SET `is_active` = 0 WHERE `account_id` = %d AND `is_active` = 1",
		TABLE_BANS,
		targetAccountId
	);

	char insertQuery[MAX_QUERY_LENGTH];
	if (hasAdminSteamID64)
	{
		FormatEx(
			insertQuery,
			sizeof(insertQuery),
			"INSERT INTO `%s` (`account_id`, `steamid64`, `ban_type`, `created_timestamp`, `duration_minutes`, `expires_timestamp`, `active_until_timestamp`, `admin_account_id`, `admin_steamid64`, `reason`, `is_active`) "
			... "VALUES (%d, '%s', %d, %d, %d, %d, %d, %d, '%s', '%s', 1)",
			TABLE_BANS,
			targetAccountId,
			targetSteamID64,
			banType,
			currentTime,
			durationMinutes,
			expiresTimestamp,
			activeUntilTimestamp,
			adminAccountId,
			adminSteamID64,
			escapedReason
		);
	}
	else
	{
		FormatEx(
			insertQuery,
			sizeof(insertQuery),
			"INSERT INTO `%s` (`account_id`, `steamid64`, `ban_type`, `created_timestamp`, `duration_minutes`, `expires_timestamp`, `active_until_timestamp`, `admin_account_id`, `admin_steamid64`, `reason`, `is_active`) "
			... "VALUES (%d, '%s', %d, %d, %d, %d, %d, %d, NULL, '%s', 1)",
			TABLE_BANS,
			targetAccountId,
			targetSteamID64,
			banType,
			currentTime,
			durationMinutes,
			expiresTimestamp,
			activeUntilTimestamp,
			adminAccountId,
			escapedReason
		);
	}

	DataPack context = CVB_CreateAddBanContextPack(
		CVB_GetCommandIssuerUserId(admin),
		replySource,
		targetAccountId,
		requestedTargetClient,
		banType,
		durationMinutes,
		targetDisplay,
		normalizedReason
	);

	Transaction txn = SQL_CreateTransaction();
	txn.AddQuery(deactivateQuery);
	txn.AddQuery(insertQuery);

	CVBLog.MySQL("Queue add ban deactivate query: %s", deactivateQuery);
	CVBLog.MySQL("Queue add ban insert query: %s", insertQuery);
	SQL_ExecuteTransaction(g_hMySQLDB, txn, CVB_OnAddBanTxnSuccess, CVB_OnAddBanTxnFailure, context, DBPrio_High);
	return true;
}

bool CVB_QueueRemoveBan(int admin, int targetAccountId, int requestedTargetClient, const char[] targetDisplay, ReplySource replySource)
{
	SourceDB activeDb = CVB_GetActiveDatabase();
	if (activeDb == SourceDB_Unknown)
	{
		CVB_ReplyDatabaseErrorWithSource(admin, replySource);
		return false;
	}

	if (activeDb == SourceDB_SQLite)
	{
		int affectedRows;
		if (!CVB_ExecuteSQLiteRemoveBan(targetAccountId, affectedRows))
		{
			CVB_ReplyDatabaseErrorWithSource(admin, replySource);
			return false;
		}

		CVB_FinalizeQueuedRemoveSuccess(CVB_GetCommandIssuerUserId(admin), replySource, targetAccountId, requestedTargetClient, targetDisplay, affectedRows > 0);
		return true;
	}

	if (g_hMySQLDB == null)
	{
		CVB_ReplyDatabaseErrorWithSource(admin, replySource);
		return false;
	}

	char query[MAX_QUERY_LENGTH];
	FormatEx(
		query,
		sizeof(query),
		"UPDATE `%s` SET `is_active` = 0 WHERE `account_id` = %d AND `is_active` = 1 AND `active_until_timestamp` > %d",
		TABLE_BANS,
		targetAccountId,
		GetTime()
	);

	DataPack context = CVB_CreateRemoveBanContextPack(
		CVB_GetCommandIssuerUserId(admin),
		replySource,
		targetAccountId,
		requestedTargetClient,
		targetDisplay
	);

	CVBLog.MySQL("Queue remove ban query: %s", query);
	SQL_TQuery(g_hMySQLDB, CVB_OnRemoveBanCompleted, query, context, DBPrio_High);
	return true;
}

public void CVB_OnAddBanTxnSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	DataPack context = view_as<DataPack>(data);

	CVBAddBanContext addContext;
	CVB_ReadAddBanContext(context, addContext);
	delete context;

	CVBLog.SQL(
		"Ban inserted successfully for AccountID %d (type=%d duration=%d queries=%d)",
		addContext.TargetAccountId,
		addContext.BanType,
		addContext.DurationMinutes,
		numQueries
	);

	CVB_FinalizeQueuedBanSuccess(
		addContext.AdminUserId,
		addContext.ReplySource,
		addContext.TargetAccountId,
		addContext.RequestedTargetClient,
		addContext.BanType,
		addContext.DurationMinutes,
		addContext.TargetDisplay,
		addContext.Reason
	);
}

public void CVB_OnAddBanTxnFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	DataPack context = view_as<DataPack>(data);

	CVBAddBanContext addContext;
	CVB_ReadAddBanContext(context, addContext);
	delete context;

	CVBLog.MySQL(
		"Insert ban transaction failed for AccountID %d (type=%d duration=%d failIndex=%d numQueries=%d): %s",
		addContext.TargetAccountId,
		addContext.BanType,
		addContext.DurationMinutes,
		failIndex,
		numQueries,
		error
	);

	CVB_FinalizeQueuedBanFailure(
		addContext.AdminUserId,
		addContext.ReplySource,
		addContext.TargetAccountId,
		addContext.BanType,
		addContext.DurationMinutes,
		error
	);
}

public void CVB_OnRemoveBanCompleted(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack context = view_as<DataPack>(data);

	CVBRemoveBanContext removeContext;
	CVB_ReadRemoveBanContext(context, removeContext);
	delete context;

	if (results == null)
	{
		CVB_FinalizeQueuedRemoveFailure(removeContext.AdminUserId, removeContext.ReplySource, removeContext.TargetAccountId, error);
		return;
	}

	CVB_FinalizeQueuedRemoveSuccess(
		removeContext.AdminUserId,
		removeContext.ReplySource,
		removeContext.TargetAccountId,
		removeContext.RequestedTargetClient,
		removeContext.TargetDisplay,
		results.AffectedRows > 0
	);
}

bool ApplyBanToPlayer(int admin, int target, int banType, int durationMinutes, const char[] reason)
{
	char normalizedReason[256];
	NormalizeBanReason(reason, normalizedReason, sizeof(normalizedReason));

	char targetName[MAX_NAME_LENGTH];
	GetClientName(target, targetName, sizeof(targetName));

	return CVB_QueueAddBan(admin, GetSteamAccountID(target), target, banType, durationMinutes, targetName, normalizedReason, GetCmdReplySource());
}

bool ApplyUnbanToPlayer(int admin, int target)
{
	char targetName[MAX_NAME_LENGTH];
	GetClientName(target, targetName, sizeof(targetName));

	return CVB_QueueRemoveBan(admin, GetSteamAccountID(target), target, targetName, GetCmdReplySource());
}
