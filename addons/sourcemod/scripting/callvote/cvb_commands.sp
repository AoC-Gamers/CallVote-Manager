#if defined _cvb_commands_included
	#endinput
#endif
#define _cvb_commands_included

// AsyncContext StringMap keys constants
#define ASYNCCTX_ADMIN_USERID "admin_user_id"
#define ASYNCCTX_TARGET_ACCOUNTID "target_account_id"
#define ASYNCCTX_CONTINUATION_TYPE "continuation_type"
#define ASYNCCTX_BAN_TYPE "ban_type"
#define ASYNCCTX_DURATION_MINUTES "duration_minutes"
#define ASYNCCTX_TARGET_STEAMID "target_steamid"
#define ASYNCCTX_ORIGINAL_STEAMID "original_steamid"
#define ASYNCCTX_REASON "reason"

enum SteamID64_ContinuationType
{
	CONTINUE_BAN_OFFLINE = 0,
	CONTINUE_UNBAN_OFFLINE = 1,
	CONTINUE_CHECK_OFFLINE = 2,
	CONTINUE_SQLITE_VERIFY = 3,
	CONTINUE_SQLITE_CHECK = 4,
	CONTINUE_SQLITE_REMOVE = 5,
	CONTINUE_STRINGMAP_CHECK = 6,
	CONTINUE_STRINGMAP_REMOVE = 7,
	CONTINUE_REFRESH_CACHE = 8
};

methodmap AsyncContext < Handle {

	/**
	 * Creates and returns a new AsyncContext object.
	 * 
	 * This function initializes a new StringMap and casts it to AsyncContext.
	 * 
	 * @return AsyncContext  A newly created asynchronous context.
	 */
	public AsyncContext() {
		return view_as<AsyncContext>(new StringMap());
	}
	
	/**
	 * Property: AdminUserId
	 * 
	 * Gets or sets the admin user ID associated with this object.
	 * Includes validation to prevent invalid values.
	 */
	property int AdminUserId {
		public get() {
			if (!this.IsValid()) return 0;
			int value;
			view_as<StringMap>(this).GetValue(ASYNCCTX_ADMIN_USERID, value);
			return value;
		}
		public set(int value) {
			if (!this.IsValid()) return;
			if (value < 0) {
				LogError("AsyncContext: Invalid AdminUserId: %d", value);
				return;
			}
			view_as<StringMap>(this).SetValue(ASYNCCTX_ADMIN_USERID, value);
		}
	}
	

	/**
	 * Property: TargetAccountId
	 * 
	 * Gets or sets the target account ID associated with this object.
	 * Includes validation to prevent invalid values.
	 */
	property int TargetAccountId {
		public get() {
			if (!this.IsValid()) return 0;
			int value;
			view_as<StringMap>(this).GetValue(ASYNCCTX_TARGET_ACCOUNTID, value);
			return value;
		}
		public set(int value) {
			if (!this.IsValid()) return;
			if (value <= 0) {
				LogError("AsyncContext: Invalid TargetAccountId: %d", value);
				return;
			}
			view_as<StringMap>(this).SetValue(ASYNCCTX_TARGET_ACCOUNTID, value);
		}
	}
	
	/**
	 * Property: ContinuationType
	 * 
	 * Gets or sets the continuation type associated with a SteamID64.
	 * Includes validation for known continuation types.
	 */
	property SteamID64_ContinuationType ContinuationType {
		public get() {
			if (!this.IsValid()) return view_as<SteamID64_ContinuationType>(-1);
			int value;
			view_as<StringMap>(this).GetValue(ASYNCCTX_CONTINUATION_TYPE, value);
			return view_as<SteamID64_ContinuationType>(value);
		}
		public set(SteamID64_ContinuationType value) {
			if (!this.IsValid()) return;
			if (value < CONTINUE_BAN_OFFLINE || value > CONTINUE_REFRESH_CACHE) {
				LogError("AsyncContext: Invalid ContinuationType: %d", value);
				return;
			}
			view_as<StringMap>(this).SetValue(ASYNCCTX_CONTINUATION_TYPE, view_as<int>(value));
		}
	}
	
	/**
	 * Property: BanType
	 * 
	 * Gets or sets the ban type associated with this object.
	 * Includes validation for valid ban type ranges.
	 */
	property int BanType {
		public get() {
			if (!this.IsValid()) return 0;
			int value;
			view_as<StringMap>(this).GetValue(ASYNCCTX_BAN_TYPE, value);
			return value;
		}
		public set(int value) {
			if (!this.IsValid()) return;
			if (value < 0 || value > view_as<int>(VOTE_ALL)) {
				LogError("AsyncContext: Invalid BanType: %d (max: %d)", value, view_as<int>(VOTE_ALL));
				return;
			}
			view_as<StringMap>(this).SetValue(ASYNCCTX_BAN_TYPE, value);
		}
	}
	
	/**
	 * Property: DurationMinutes
	 * 
	 * Gets or sets the duration in minutes for the current object.
	 * Includes validation for non-negative values.
	 */
	property int DurationMinutes {
		public get() {
			if (!this.IsValid()) return 0;
			int value;
			view_as<StringMap>(this).GetValue(ASYNCCTX_DURATION_MINUTES, value);
			return value;
		}
		public set(int value) {
			if (!this.IsValid()) return;
			if (value < 0) {
				LogError("AsyncContext: Invalid DurationMinutes: %d", value);
				return;
			}
			view_as<StringMap>(this).SetValue(ASYNCCTX_DURATION_MINUTES, value);
		}
	}
	
	/**
	 * Retrieves the SteamID of the target and stores it in the provided buffer.
	 *
	 * @param buffer    The character array to store the retrieved SteamID.
	 * @param maxlen    The maximum length of the buffer.
	 * @return          True if successful, false if context is invalid.
	 */
	public bool GetTargetSteamId(char[] buffer, int maxlen) {
		if (!this.IsValid()) {
			buffer[0] = '\0';
			return false;
		}
		return view_as<StringMap>(this).GetString(ASYNCCTX_TARGET_STEAMID, buffer, maxlen);
	}
	
	/**
	 * Sets the target SteamID in the underlying StringMap.
	 * Includes validation for empty strings and length limits.
	 *
	 * @param steamid	The SteamID to set as the target.
	 * @return          True if successful, false if validation fails.
	 */
	public bool SetTargetSteamId(const char[] steamid) {
		if (!this.IsValid()) return false;
		
		if (strlen(steamid) == 0) {
			LogError("AsyncContext: Empty SteamID provided");
			return false;
		}
		
		if (strlen(steamid) >= MAX_AUTHID_LENGTH) {
			LogError("AsyncContext: SteamID too long: %s", steamid);
			return false;
		}
		
		view_as<StringMap>(this).SetString(ASYNCCTX_TARGET_STEAMID, steamid);
		return true;
	}
	
	/**
	 * Retrieves the original SteamID associated with this object.
	 *
	 * @param buffer    The buffer to store the retrieved SteamID.
	 * @param maxlen    The maximum length of the buffer.
	 * @return          True if successful, false if context is invalid.
	 */
	public bool GetOriginalSteamId(char[] buffer, int maxlen) {
		if (!this.IsValid()) {
			buffer[0] = '\0';
			return false;
		}
		return view_as<StringMap>(this).GetString(ASYNCCTX_ORIGINAL_STEAMID, buffer, maxlen);
	}
	
	/**
	 * Sets the original SteamID for this object.
	 * Includes validation for empty strings.
	 *
	 * @param steamid	The SteamID string to associate as the original SteamID.
	 * @return          True if successful, false if validation fails.
	 */
	public bool SetOriginalSteamId(const char[] steamid) {
		if (!this.IsValid()) return false;
		
		if (strlen(steamid) == 0) {
			LogError("AsyncContext: Empty original SteamID provided");
			return false;
		}
		
		view_as<StringMap>(this).SetString(ASYNCCTX_ORIGINAL_STEAMID, steamid);
		return true;
	}
	
	/**
	 * Retrieves the "reason" string from the underlying StringMap and stores it in the provided buffer.
	 *
	 * @param buffer	Buffer to store the retrieved reason string.
	 * @param maxlen	Maximum length of the buffer.
	 * @return          True if successful, false if context is invalid.
	 */
	public bool GetReason(char[] buffer, int maxlen) {
		if (!this.IsValid()) {
			buffer[0] = '\0';
			return false;
		}
		return view_as<StringMap>(this).GetString(ASYNCCTX_REASON, buffer, maxlen);
	}
	
	/**
	 * Sets the reason string in the underlying StringMap for this object.
	 * Includes validation and automatic truncation for oversized reasons.
	 *
	 * @param reason	The reason to be set, as a constant character array.
	 * @return          True if set without truncation, false if truncated or failed.
	 */
	public bool SetReason(const char[] reason) {
		if (!this.IsValid()) return false;
		
		if (strlen(reason) >= 256) {
			LogError("AsyncContext: Reason too long, truncating");
			char truncated[256];
			strcopy(truncated, sizeof(truncated), reason);
			view_as<StringMap>(this).SetString(ASYNCCTX_REASON, truncated);
			return false;
		}
		
		view_as<StringMap>(this).SetString(ASYNCCTX_REASON, reason);
		return true;
	}
	
	/**
	 * Validates that context has required data for ban operations.
	 * 
	 * @return True if context has all required data for ban operations.
	 */
	public bool HasRequiredDataForBan() {
		return this.IsValid() && 
			   this.AdminUserId > 0 && 
			   this.TargetAccountId > 0 &&
			   this.BanType > 0 &&
			   this.ContinuationType == CONTINUE_BAN_OFFLINE;
	}
	
	/**
	 * Validates that context has required data for check operations.
	 * 
	 * @return True if context has all required data for check operations.
	 */
	public bool HasRequiredDataForCheck() {
		return this.IsValid() && 
			   this.AdminUserId > 0 && 
			   this.TargetAccountId > 0 &&
			   (this.ContinuationType == CONTINUE_CHECK_OFFLINE ||
				this.ContinuationType == CONTINUE_SQLITE_CHECK ||
				this.ContinuationType == CONTINUE_STRINGMAP_CHECK);
	}
	
	/**
	 * Validates that context has required data for unban operations.
	 * 
	 * @return True if context has all required data for unban operations.
	 */
	public bool HasRequiredDataForUnban() {
		return this.IsValid() && 
			   this.AdminUserId > 0 && 
			   this.TargetAccountId > 0 &&
			   this.ContinuationType == CONTINUE_UNBAN_OFFLINE;
	}
	
	/**
	 * Resets the current object by clearing all entries in its underlying StringMap.
	 * This effectively removes all stored key-value pairs, returning the object to its initial state.
	 */
	public void Reset() {
		if (this.IsValid()) {
			view_as<StringMap>(this).Clear();
		}
	}
	
	/**
	 * Checks if the current object instance is valid.
	 *
	 * @return      True if the object is not null and can be safely viewed as a StringMap, false otherwise.
	 */
	public bool IsValid() {
		return this != null && view_as<StringMap>(this) != null;
	}
}

/**
 * Factory function: Creates AsyncContext for ban offline operations.
 * Sets up basic context without SteamID conversion (handled by ValidateAndConvertSteamIDAsync).
 * 
 * @param adminUserId   Admin's user ID
 * @param banType       Ban type flags
 * @param duration      Duration in minutes (0 = permanent)
 * @param reason        Ban reason (optional)
 * @return AsyncContext Configured context ready for validation
 */
AsyncContext CreateAsyncContextForBanOffline(int adminUserId, int banType, int duration, const char[] reason = "") {
	AsyncContext ctx = new AsyncContext();
	ctx.ContinuationType = CONTINUE_BAN_OFFLINE;
	ctx.AdminUserId = adminUserId;
	ctx.BanType = banType;
	ctx.DurationMinutes = duration;
	
	if (strlen(reason) > 0) {
		ctx.SetReason(reason);
	}
	
	return ctx;
}

/**
 * Factory function: Creates AsyncContext for check offline operations.
 * Sets up basic context without SteamID conversion (handled by ValidateAndConvertSteamIDAsync).
 * 
 * @param adminUserId   Admin's user ID
 * @return AsyncContext Configured context ready for validation
 */
AsyncContext CreateAsyncContextForCheckOffline(int adminUserId) {
	AsyncContext ctx = new AsyncContext();
	ctx.ContinuationType = CONTINUE_CHECK_OFFLINE;
	ctx.AdminUserId = adminUserId;
	
	return ctx;
}

/**
 * Factory function: Creates AsyncContext for unban offline operations.
 * Sets up basic context without SteamID conversion (handled by ValidateAndConvertSteamIDAsync).
 * 
 * @param adminUserId   Admin's user ID
 * @return AsyncContext Configured context ready for validation
 */
AsyncContext CreateAsyncContextForUnbanOffline(int adminUserId) {
	AsyncContext ctx = new AsyncContext();
	ctx.ContinuationType = CONTINUE_UNBAN_OFFLINE;
	ctx.AdminUserId = adminUserId;
	
	return ctx;
}

#include "cvb_commands/commands_sql.sp"
#include "cvb_commands/commands_mysql.sp"
#include "cvb_commands/commands_sqlite.sp"
#include "cvb_commands/commands_stringmap.sp"
#if DEBUG
#include "cvb_commands/commands_debug.sp"
#endif

void RegisterCommands()
{
	// commands_sql.sp
	RegAdminCmd("sm_cvb_install", Command_InstallDatabase, ADMFLAG_ROOT, "Install/recreate tables and stored procedures: mysql|sqlite|all (default: all)");
	RegAdminCmd("sm_cvb_reinstall", Command_ReinstallDatabase, ADMFLAG_ROOT, "DANGEROUS: Drop and recreate ALL tables/procedures: mysql|sqlite|all (default: all)");
	RegAdminCmd("sm_cvb_verify", Command_VerifyInstallation, ADMFLAG_ROOT, "Verify installation: mysql (stored procedures) | sqlite (database structure)");
	RegAdminCmd("sm_cvb_truncate", Command_Truncate, ADMFLAG_ROOT, "Clear bans database: mysql|sqlite|all [confirm] (default: all)");
	RegAdminCmd("sm_cvb_cleanup", Command_CleanupBans, ADMFLAG_ROOT, "Clean expired bans: mysql|cache|all (default: mysql)");
	RegAdminCmd("sm_cvb_stats", Command_Stats, ADMFLAG_ROOT, "View ban system statistics: mysql|cache|all (default: mysql)");

	// commands_mysql.sp
	RegAdminCmd("sm_cvb_ban", Command_Ban, ADMFLAG_BAN, "Ban players from voting: sm_cvb_ban <#userid|name> <bantype> [duration] [reason] (no args = panel)");
	RegAdminCmd("sm_cvb_banid", Command_BanOffline, ADMFLAG_BAN, "Ban offline player by SteamID (any format)");
	RegAdminCmd("sm_cvb_unban", Command_Unban, ADMFLAG_UNBAN, "Unban players from voting: sm_cvb_unban <#userid|name> (no args = panel)");
	RegAdminCmd("sm_cvb_unbanid", Command_UnbanOffline, ADMFLAG_UNBAN, "Unban offline player by SteamID (any format)");
	RegAdminCmd("sm_cvb_check", Command_Check, ADMFLAG_GENERIC, "Check player ban status: sm_cvb_check <#userid|name> (no args = panel)");
	RegAdminCmd("sm_cvb_checkid", Command_CheckOffline, ADMFLAG_GENERIC, "Check ban status by SteamID (any format)");

	// commands_sqlite.sp
	RegAdminCmd("sm_cvb_sqlite_check", Command_SQLiteCheck, ADMFLAG_GENERIC, "Check player ban status in SQLite cache");
	RegAdminCmd("sm_cvb_sqlite_checkid", Command_SQLiteCheckOffline, ADMFLAG_GENERIC, "Check ban status in SQLite cache by SteamID (any format)");
	RegAdminCmd("sm_cvb_sqlite_remove", Command_CacheRemove, ADMFLAG_UNBAN, "Remove player from SQLite cache (online player)");
	RegAdminCmd("sm_cvb_sqlite_removeid", Command_CacheRemoveOffline, ADMFLAG_UNBAN, "Remove player from SQLite cache by SteamID (any format)");

	// commands_stringmap.sp
	RegAdminCmd("sm_cvb_stringmap_check", Command_StringMapCheck, ADMFLAG_GENERIC, "Check player ban status in StringMap cache (online player)");
	RegAdminCmd("sm_cvb_stringmap_checkid", Command_StringMapCheckOffline, ADMFLAG_GENERIC, "Check ban status in StringMap cache by SteamID (any format)");
	RegAdminCmd("sm_cvb_stringmap_remove", Command_StringMapRemove, ADMFLAG_UNBAN, "Remove player from StringMap cache (online player)");
	RegAdminCmd("sm_cvb_stringmap_removeid", Command_StringMapRemoveOffline, ADMFLAG_UNBAN, "Remove player from StringMap cache by SteamID (any format)");
	RegAdminCmd("sm_cvb_refresh", Command_RefreshPlayer, ADMFLAG_UNBAN, "Force refresh cache for online player");
	RegAdminCmd("sm_cvb_refreshid", Command_RefreshPlayerOffline, ADMFLAG_UNBAN, "Force refresh cache by SteamID (any format)");
	
	// Performance and optimization commands
	RegAdminCmd("sm_cvb_stringpool", Command_StringPoolStats, ADMFLAG_GENERIC, "Show StringPool usage statistics");

#if DEBUG
	// commands_debug.sp
	RegAdminCmd("sm_cvb_test_mysql", Command_DebugMySQL, ADMFLAG_ROOT, "Test MySQL stored procedures with detailed logging");
	RegAdminCmd("sm_cvb_test_sqlite", Command_DebugSQLite, ADMFLAG_ROOT, "Test SQLite queries and cache operations");
	RegAdminCmd("sm_cvb_debug_checkfullban", Command_DebugCheckFullBan, ADMFLAG_ROOT, "Debug sp_CheckFullBan procedure for specific AccountID");
	RegAdminCmd("sm_cvb_debug_table", Command_DebugMySQLTable, ADMFLAG_ROOT, "Debug MySQL table data for specific AccountID");
#endif
}

void GetBanTypeString(int banType, char[] output, int maxlen)
{
	strcopy(output, maxlen, "");
	
	if (banType & view_as<int>(VOTE_CHANGEDIFFICULTY))
		StrCat(output, maxlen, "Difficulty ");
	
	if (banType & view_as<int>(VOTE_RESTARTGAME))
		StrCat(output, maxlen, "Restart ");
	
	if (banType & view_as<int>(VOTE_KICK))
		StrCat(output, maxlen, "Kick ");
	
	if (banType & view_as<int>(VOTE_CHANGEMISSION))
		StrCat(output, maxlen, "Mission ");
	
	if (banType & view_as<int>(VOTE_RETURNTOLOBBY))
		StrCat(output, maxlen, "Lobby ");
	
	if (banType & view_as<int>(VOTE_CHANGECHAPTER))
		StrCat(output, maxlen, "Chapter ");
	
	if (banType & view_as<int>(VOTE_CHANGEALLTALK))
		StrCat(output, maxlen, "AllTalk ");

	int len = strlen(output);
	if (len > 0 && output[len-1] == ' ')
	{
		output[len-1] = '\0';
	}
	
	if (strlen(output) == 0)
	{
		strcopy(output, maxlen, "None");
	}
}

// Result enum for SteamID validation
enum SteamIDValidationResult
{
	STEAMID_VALIDATION_SUCCESS,      // Validation successful, continue synchronously
	STEAMID_VALIDATION_ASYNC,        // Validation requires async processing, callback will handle continuation
	STEAMID_VALIDATION_ERROR         // Validation failed, context has been cleaned up
};

// Modern AsyncContext-based validation function
SteamIDValidationResult ValidateAndConvertSteamIDAsync(int client, const char[] steamId, AsyncContext context)
{
	if (client == SERVER_INDEX)
	{
		context.TargetAccountId = 0;
		context.SetTargetSteamId("CONSOLE");
		return STEAMID_VALIDATION_SUCCESS;
	}

	context.SetOriginalSteamId(steamId);
	context.AdminUserId = GetClientUserId(client);

	SteamIDFormat SIDFormat = DetectSteamIDFormat(steamId);

	switch (SIDFormat)
	{
		case STEAMID_FORMAT_SPECIAL:
		{
			CReplyToCommand(client, "%t %t", "Tag", "CannotProcessSpecialCases", steamId);
			CReplyToCommand(client, "%t %t", "Tag", "SpecialCases");
			delete context;
			return STEAMID_VALIDATION_ERROR;
		}
		case STEAMID_FORMAT_STEAMID2:
		{
			int accountId = SteamID2ToAccountID(steamId);

			if (accountId <= 0)
			{
				CReplyToCommand(client, "%t %t", "Tag", "InvalidSteamIDFormat", steamId);
				delete context;
				return STEAMID_VALIDATION_ERROR;
			}

			context.TargetAccountId = accountId;
			context.SetTargetSteamId(steamId);
			return STEAMID_VALIDATION_SUCCESS;
		}
		case STEAMID_FORMAT_STEAMID3:
		{
			int accountId = SteamID3ToAccountID(steamId);
			if (accountId <= 0)
			{
				CReplyToCommand(client, "%t %t", "Tag", "InvalidSteamIDFormat", steamId);
				delete context;
				return STEAMID_VALIDATION_ERROR;
			}

			context.TargetAccountId = accountId;
			
			char steamId2[MAX_AUTHID_LENGTH];

			if (!AccountIDToSteamID2(accountId, steamId2, sizeof(steamId2)))
			{
				CReplyToCommand(client, "%t %t", "Tag", "InternalError", accountId);
				delete context;
				return STEAMID_VALIDATION_ERROR;
			}

			context.SetTargetSteamId(steamId2);
			return STEAMID_VALIDATION_SUCCESS;
		}
		case STEAMID_FORMAT_STEAMID64:
		{
			// For SteamID64, we need async conversion
			if (g_bSteamWorksLoaded && g_cvarSteamIDToolsHTTP.IntValue == 1)
				Steamworks_RequestSteamID64ToAID_Async(steamId, context);
			else if (g_bSystem2Loaded && g_cvarSteamIDToolsHTTP.IntValue == 2)
				System2_RequestSteamID64ToAID_Async(steamId, context);
			else
			{
				CReplyToCommand(client, "%t %t", "Tag", "SteamWorksOrSystem2Required");
				CReplyToCommand(client, "%t %t", "Tag", "PleaseUseOtherFormats");
				delete context;
				return STEAMID_VALIDATION_ERROR;
			}
			return STEAMID_VALIDATION_ASYNC; // Async operation, will continue in callback
		}
		case STEAMID_FORMAT_ACCOUNTID:
		{
			int accountId = StringToInt(steamId);
			if (accountId <= 0)
			{
				CReplyToCommand(client, "%t %t", "Tag", "InvalidSteamIDFormat", steamId);
				delete context;
				return STEAMID_VALIDATION_ERROR;
			}

			context.TargetAccountId = accountId;
			
			char steamId2[MAX_AUTHID_LENGTH];
			if (!AccountIDToSteamID2(accountId, steamId2, sizeof(steamId2)))
			{
				CReplyToCommand(client, "%t %t", "Tag", "InternalError", accountId);
				delete context;
				return STEAMID_VALIDATION_ERROR;
			}

			context.SetTargetSteamId(steamId2);
			return STEAMID_VALIDATION_SUCCESS;
		}
		case STEAMID_FORMAT_UNKNOWN:
		{
			CReplyToCommand(client, "%t %t", "Tag", "InvalidSteamIDFormat", steamId);
			CReplyToCommand(client, "%t %t", "Tag", "SupportedFormatsHeader");
			CReplyToCommand(client, "%t %t", "Tag", "SteamID2Format");
			CReplyToCommand(client, "%t %t", "Tag", "SteamID3Format");
			CReplyToCommand(client, "%t %t", "Tag", "SteamID64Format");
			CReplyToCommand(client, "%t %t", "Tag", "AccountIDFormat");
			delete context;
			return STEAMID_VALIDATION_ERROR;
		}
	}
	
	// This should never be reached, but clean up just in case
	delete context;
	return STEAMID_VALIDATION_ERROR;
}

bool GetAdminInfo(int client, int &adminAccountId, char[] adminSteamId2, int maxlen)
{
	if (client == SERVER_INDEX)
	{
		adminAccountId = 0;
		strcopy(adminSteamId2, maxlen, "CONSOLE");
		return true;
	}
	
	if (!IsValidClient(client))
	{
		return false;
	}
	
	adminAccountId = GetSteamAccountID(client);
	return GetClientAuthId(client, AuthId_Steam2, adminSteamId2, maxlen);
}

// Modern Async HTTP Request functions using AsyncContext

void Steamworks_RequestSteamID64ToAID_Async(const char[] steamid64, AsyncContext context)
{
	char url[256];
	char port[8];
	char ip[32];
	g_cvarSteamIDToolsIP.GetString(ip, sizeof(ip));
	g_cvarSteamIDToolsPort.GetString(port, sizeof(port));
	Format(url, sizeof(url), "%s:%s/SID64toAID?steamid=%s&nullterm=1", ip, port, steamid64);

	CVBLog.Debug("[SteamWorks] Sending request: %s", url);

	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
	if (hRequest == INVALID_HANDLE)
	{
		int admin = GetClientOfUserId(context.AdminUserId);

		CReplyToCommand(admin, "%t %t", "Tag", "SteamWorksHTTPRequestFailed");
		LogError("Failed to create SteamWorks HTTP request for URL: %s", url);
		delete context;
		return;
	}
	
	SteamWorks_SetHTTPRequestContextValue(hRequest, context);
	SteamWorks_SetHTTPCallbacks(hRequest, SteamWorks_OnSteamID64ToAIDResponse_Async);
	SteamWorks_SendHTTPRequest(hRequest);
}

public void SteamWorks_OnSteamID64ToAIDResponse_Async(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1)
{
	AsyncContext context = view_as<AsyncContext>(data1);
	if (!context.IsValid()) {
		LogError("Invalid context received in SteamWorks callback");
		return;
	}

	int admin = GetClientOfUserId(context.AdminUserId);

	if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		CReplyToCommand(admin, "%t %t", "Tag", "SteamWorksHTTPRequestFailed");
		delete context;
		return;
	}

	int bodySize = 0;
	if (!SteamWorks_GetHTTPResponseBodySize(hRequest, bodySize) || bodySize <= 0)
	{
		char originalSteamId[64];
		context.GetOriginalSteamId(originalSteamId, sizeof(originalSteamId));
		CReplyToCommand(admin, "%t %t", "Tag", "InvalidSteamIDFormat", originalSteamId);
		delete context;
		return;
	}
	
	char[] response = new char[bodySize + 1];
	// Initialize buffer with nulls
	for (int i = 0; i <= bodySize; i++)
	{
		response[i] = '\0';
	}

	SteamWorks_GetHTTPResponseBodyData(hRequest, response, bodySize);
	response[bodySize] = '\0';
	TrimString(response);
	
	int accountId = StringToInt(response);
	if (accountId <= SERVER_INDEX)
	{
		char originalSteamId[64];
		context.GetOriginalSteamId(originalSteamId, sizeof(originalSteamId));
		CReplyToCommand(admin, "%t %t", "Tag", "InvalidSteamIDFormat", originalSteamId);
		delete context;
		return;
	}

	// Update context with converted AccountID
	context.TargetAccountId = accountId;

	// Continue with the operation based on continuation type
	switch (context.ContinuationType)
	{
		case CONTINUE_BAN_OFFLINE:
			Continue_BanOffline_Async(context);
		case CONTINUE_UNBAN_OFFLINE:
			Continue_UnbanOffline_Async(context);
		case CONTINUE_CHECK_OFFLINE:
			Continue_CheckOffline_Async(context);
		case CONTINUE_SQLITE_VERIFY:
			Continue_SQLiteVerify_Async(context)
		case CONTINUE_SQLITE_CHECK:
			Continue_SQLiteCheckOffline_Async(context);
		case CONTINUE_SQLITE_REMOVE:
			Continue_CacheRemoveOffline_Async(context);
		case CONTINUE_STRINGMAP_CHECK:
			Continue_StringMapCheckOffline_Async(context);
		case CONTINUE_STRINGMAP_REMOVE:
			Continue_StringMapRemoveOffline_Async(context);
		case CONTINUE_REFRESH_CACHE:
			Continue_RefreshPlayerOffline_Async(context);
		default:
		{
			LogError("Unknown continuation type: %d", context.ContinuationType);
			delete context;
		}
	}
}

void System2_RequestSteamID64ToAID_Async(const char[] steamid64, AsyncContext context)
{
	char url[256];
	char port[8];
	char ip[32];
	g_cvarSteamIDToolsIP.GetString(ip, sizeof(ip));
	g_cvarSteamIDToolsPort.GetString(port, sizeof(port));
	Format(url, sizeof(url), "%s:%s/SID64toAID?steamid=%s", ip, port, steamid64);

	CVBLog.Debug("[System2] Sending request: %s", url);

	System2HTTPRequest req = new System2HTTPRequest(System2_OnSteamID64ToAIDResponse_Async, url);
	req.Any = context;
	req.GET();
}

public void System2_OnSteamID64ToAIDResponse_Async(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	AsyncContext context = view_as<AsyncContext>(request.Any);
	if (!context.IsValid())
	{
		LogError("Invalid context received in System2 callback");
		return;
	}

	int admin = GetClientOfUserId(context.AdminUserId);

	if (!success || response == null)
	{
		LogError("System2 HTTP request failed. Success: %s, Error: %s", success ? "true" : "false", error);
		CReplyToCommand(admin, "%t %t", "Tag", "System2HTTPRequestFailed");
		delete context;
		return;
	}

	char szResponse[64];
	response.GetContent(szResponse, sizeof(szResponse));
	TrimString(szResponse);
	int accountId = StringToInt(szResponse);
	if (accountId <= SERVER_INDEX)
	{
		char originalSteamId[64];
		context.GetOriginalSteamId(originalSteamId, sizeof(originalSteamId));
		CReplyToCommand(admin, "%t %t", "Tag", "InvalidSteamIDFormat", originalSteamId);
		delete context;
		return;
	}

	context.TargetAccountId = accountId;

	switch (context.ContinuationType)
	{
		case CONTINUE_BAN_OFFLINE:
			Continue_BanOffline_Async(context);
		case CONTINUE_UNBAN_OFFLINE:
			Continue_UnbanOffline_Async(context);
		case CONTINUE_CHECK_OFFLINE:
			Continue_CheckOffline_Async(context);
		case CONTINUE_SQLITE_VERIFY:
			Continue_SQLiteVerify_Async(context);
		case CONTINUE_SQLITE_CHECK:
			Continue_SQLiteCheckOffline_Async(context);
		case CONTINUE_SQLITE_REMOVE:
			Continue_CacheRemoveOffline_Async(context);
		case CONTINUE_STRINGMAP_CHECK:
			Continue_StringMapCheckOffline_Async(context);
		case CONTINUE_STRINGMAP_REMOVE:
			Continue_StringMapRemoveOffline_Async(context);
		case CONTINUE_REFRESH_CACHE:
			Continue_RefreshPlayerOffline_Async(context);
		default:
		{
			LogError("Unknown continuation type: %d", context.ContinuationType);
			delete context;
		}
	}
}

void Continue_BanOffline_Async(AsyncContext context)
{
	int admin = GetClientOfUserId(context.AdminUserId);
	if (admin <= 0) {
		LogError("Admin disconnected during ban operation");
		delete context;
		return;
	}

	int adminAccountId;
	char sAdminSteamId2[MAX_AUTHID_LENGTH];
	if (!GetAdminInfo(admin, adminAccountId, sAdminSteamId2, sizeof(sAdminSteamId2)))
	{
		CReplyToCommand(admin, "%t %t", "Tag", "ErrorGettingAdminInfo");
		delete context;
		return;
	}

	int targetAccountId = context.TargetAccountId;
	int banType = context.BanType;
	int durationMinutes = context.DurationMinutes;
	
	char reason[256], targetSteamId[MAX_AUTHID_LENGTH];
	context.GetReason(reason, sizeof(reason));
	context.GetTargetSteamId(targetSteamId, sizeof(targetSteamId));

	char reasonCode[256];
	CVB_GetBanReason(reason, reasonCode, sizeof(reasonCode));
	CVB_InsertMysqlBan(targetAccountId, banType, durationMinutes, adminAccountId, reasonCode);
	
	char sBanTypes[64];
	GetBanTypeString(banType, sBanTypes, sizeof(sBanTypes));
	
	char sDurationText[64];
	if (durationMinutes == 0)
	{
		Format(sDurationText, sizeof(sDurationText), "%T", "BanStatusPermanent", admin);
	}
	else
	{
		Format(sDurationText, sizeof(sDurationText), "%d minutos", durationMinutes);
	}

	CReplyToCommand(admin, "%t %t", "Tag", "BanApplied", targetSteamId, banType, sDurationText);
	CVBLog.Debug("Admin %N[%s] baneó a %s (tipo: %d, duración: %s, razón: %s)", 
			 admin, sAdminSteamId2, targetSteamId, banType, sDurationText, reason);
	
	// Check if target player is online and send console notification
	int target = FindClientByAccountID(targetAccountId);
	if (target > 0 && IsValidClient(target))
	{
		// Update cache for online player
		int expiresTimestamp = (durationMinutes == 0) ? 0 : GetTime() + (durationMinutes * 60);
		SetClientBanInfo(target, banType, durationMinutes, expiresTimestamp);
		CVBLog.Debug("Cache updated for online player AccountID %d after offline ban", targetAccountId);
		
		SendBanNotification(target, NotifyType_Offline, 0, sAdminSteamId2, sBanTypes, sDurationText, durationMinutes);
	}
	else
	{
		// For offline players, force refresh cache entry to ensure consistency
		ForceRefreshCacheEntry(targetAccountId);
		CVBLog.Debug("Cache entry refreshed for offline AccountID %d after ban", targetAccountId);
	}
	
	delete context;
}

void Continue_UnbanOffline_Async(AsyncContext context)
{
	int admin = GetClientOfUserId(context.AdminUserId);
	if (admin <= 0) {
		LogError("Admin disconnected during unban operation");
		delete context;
		return;
	}

	int adminAccountId;
	char sAdminSteamId2[MAX_AUTHID_LENGTH];
	if (!GetAdminInfo(admin, adminAccountId, sAdminSteamId2, sizeof(sAdminSteamId2)))
	{
		CReplyToCommand(admin, "%t %t", "Tag", "ErrorGettingAdminInfo");
		delete context;
		return;
	}

	int targetAccountId = context.TargetAccountId;
	char targetSteamId[MAX_AUTHID_LENGTH];
	context.GetTargetSteamId(targetSteamId, sizeof(targetSteamId));

	CVB_RemoveMysqlBan(targetAccountId, adminAccountId);
	
	// Check if target player is online and update their cache
	int target = FindClientByAccountID(targetAccountId);
	if (target > 0 && IsValidClient(target))
	{
		SetClientBanInfo(target, 0, 0, 0);
		CVBLog.Debug("Cache updated for online player AccountID %d after offline unban", targetAccountId);
	}
	else
	{
		// For offline players, force refresh cache entry to ensure consistency
		ForceRefreshCacheEntry(targetAccountId);
		CVBLog.Debug("Cache entry refreshed for offline AccountID %d after unban", targetAccountId);
	}
	
	CVBLog.Debug("Admin %N[%s] desbaneó a %s", admin, sAdminSteamId2, targetSteamId);
	delete context;
}

void Continue_CheckOffline_Async(AsyncContext context)
{
	int admin = GetClientOfUserId(context.AdminUserId);
	if (admin <= 0) {
		LogError("Admin disconnected during offline check operation");
		delete context;
		return;
	}

	int targetAccountId = context.TargetAccountId;
	char targetSteamId[MAX_AUTHID_LENGTH];
	context.GetTargetSteamId(targetSteamId, sizeof(targetSteamId));

	if (targetAccountId <= 0)
	{
		char originalSteamId[64];
		context.GetOriginalSteamId(originalSteamId, sizeof(originalSteamId));
		CReplyToCommand(admin, "%t %t", "Tag", "InvalidSteamIDFormat", originalSteamId);
		delete context;
		return;
	}

	PlayerBanInfo playerInfo = new PlayerBanInfo(targetAccountId);
	
	CVB_GetCacheStringMap(playerInfo);
	playerInfo.AdminAccountId = GetSteamAccountID(admin);
	playerInfo.DbSource = SourceDB_MySQL;
	playerInfo.CommandReplySource = GetCmdReplySource();
	CVB_UpdateCacheStringMap(playerInfo);

	CReplyToCommand(admin, "%t %t", "Tag", "BanStatusVerifying", targetSteamId);
	CVBLog.Debug("Admin %N checking offline player %s (AccountID: %d)", admin, targetSteamId, targetAccountId);
	
	CVB_CheckMysqlFullBan(playerInfo);
	delete playerInfo;
	delete context;
}

void Continue_SQLiteVerify_Async(AsyncContext context)
{
	int admin = GetClientOfUserId(context.AdminUserId);
	if (admin <= 0) {
		LogError("Admin disconnected during SQLite verify operation");
		delete context;
		return;
	}

	if (g_hSQLiteDB == null)
	{
		CReplyToCommand(admin, "%t %t", "Tag", "SQLiteNotAvailable");
		delete context;
		return;
	}

	int targetAccountId = context.TargetAccountId;
	char targetSteamId[MAX_AUTHID_LENGTH], originalSteamId[64];
	context.GetTargetSteamId(targetSteamId, sizeof(targetSteamId));
	context.GetOriginalSteamId(originalSteamId, sizeof(originalSteamId));

	CReplyToCommand(admin, "%t %t", "Tag", "BanStatusVerifying", targetSteamId);

	char query[256];
	FormatEx(query, sizeof(query), "SELECT reason, expires, admin_name FROM cvb_bans WHERE accountid = %d", targetAccountId);
	
	SQL_TQuery(g_hSQLiteDB, SQLiteVerify_Callback_Async, query, context);
}

void SQLiteVerify_Callback_Async(Database db, DBResultSet results, const char[] error, AsyncContext context)
{
	if (!context.IsValid()) {
		LogError("Invalid context received in SQLiteVerify callback");
		return;
	}

	int admin = GetClientOfUserId(context.AdminUserId);
	if (admin <= 0) {
		CVBLog.Debug("Admin disconnected during SQLite verify operation");
		delete context;
		return;
	}

	char targetSteamId[MAX_AUTHID_LENGTH], originalSteamId[64];
	context.GetTargetSteamId(targetSteamId, sizeof(targetSteamId));
	context.GetOriginalSteamId(originalSteamId, sizeof(originalSteamId));
    
	if (results == null)
	{
		CReplyToCommand(admin, "%t %t", "Tag", "SQLiteVerifyError", error);
		delete context;
		return;
	}
	
	if (!results.FetchRow())
	{
		CReplyToCommand(admin, "%t %t", "Tag", "SQLiteVerifyNotFound", targetSteamId);
		delete context;
		return;
	}
	
	char reason[128], adminName[64];
	results.FetchString(0, reason, sizeof(reason));
	int expires = results.FetchInt(1);
	results.FetchString(2, adminName, sizeof(adminName));
	
	CReplyToCommand(admin, "%t %t", "Tag", "SQLiteVerifyFound", targetSteamId);
	CReplyToCommand(admin, "%t %t", "Tag", "BanReason", reason);
	CReplyToCommand(admin, "%t %t", "Tag", "BanAdmin", adminName);
	
	if (expires == 0)
	{
		CReplyToCommand(admin, "%t %t", "Tag", "BanDurationPermanent");
	}
	else
	{
		char timeStr[64];
		FormatTime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S", expires);
		CReplyToCommand(admin, "%t %t", "Tag", "BanExpires", timeStr);
	}
	
	delete context;
}

// Cache removal commands

/**
 * Command to remove a player from cache (online player)
 */
public Action Command_CacheRemove(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t: sm_cvb_cache_remove <player>", "Tag", "Usage");
		return Plugin_Handled;
	}

	char targetName[MAX_NAME_LENGTH];
	GetCmdArg(1, targetName, sizeof(targetName));

	int target = FindTarget(client, targetName, true, false);
	if (target == NO_INDEX)
	{
		return Plugin_Handled;
	}

	if (!IsValidClient(target))
	{
		CReplyToCommand(client, "%t %t", "Tag", "PlayerNotValid");
		return Plugin_Handled;
	}

	int accountId = GetSteamAccountID(target);
	char steamId2[MAX_AUTHID_LENGTH];
	GetClientAuthId(target, AuthId_Steam2, steamId2, sizeof(steamId2));

	// Remove from unified cache
	char sAccountId[16];
	IntToString(accountId, sAccountId, sizeof(sAccountId));
	if (g_smClientCache != null)
	{
		g_smClientCache.Remove(sAccountId);
	}

	// Remove from SQLite cache if available
	if (g_hSQLiteDB != null)
	{
		RemoveExpiredCacheEntry(accountId);
	}

	char targetNameSafe[MAX_NAME_LENGTH];
	GetClientName(target, targetNameSafe, sizeof(targetNameSafe));

	CReplyToCommand(client, "%t Cache cleared for player %s [%s] (AccountID: %d)", 
		"Tag", targetNameSafe, steamId2, accountId);
	
	CVBLog.Debug("Admin %N cleared cache for player %N [%s] (AccountID: %d)", 
		client, target, steamId2, accountId);

	return Plugin_Handled;
}

/**
 * Command to remove a player from cache by SteamID (offline player)
 */
public Action Command_CacheRemoveOffline(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "%t %t: sm_cvb_cache_remove_id <steamid>", "Tag", "Usage");
		return Plugin_Handled;
	}

	char steamId[64];
	GetCmdArg(1, steamId, sizeof(steamId));

	AsyncContext context = new AsyncContext();
	context.ContinuationType = CONTINUE_SQLITE_REMOVE;

	SteamIDValidationResult validationResult = ValidateAndConvertSteamIDAsync(client, steamId, context);
	if (validationResult == STEAMID_VALIDATION_ERROR)
	{
		// Context has already been cleaned up by ValidateAndConvertSteamIDAsync
		return Plugin_Handled;
	}
	else if (validationResult == STEAMID_VALIDATION_SUCCESS)
	{
		// Validation was successful, continue immediately
		Continue_CacheRemoveOffline_Async(context);
	}
	// For STEAMID_VALIDATION_ASYNC, the callback will handle continuation

	return Plugin_Handled;
}

/**
 * Continuation function for cache removal by SteamID
 */
void Continue_CacheRemoveOffline_Async(AsyncContext context)
{
	int admin = GetClientOfUserId(context.AdminUserId);
	if (admin <= 0)
	{
		LogError("Admin disconnected during cache remove operation");
		delete context;
		return;
	}

	int accountId = context.TargetAccountId;
	char steamId2[MAX_AUTHID_LENGTH];
	context.GetTargetSteamId(steamId2, sizeof(steamId2));

	// Remove from unified cache
	char sAccountId[16];
	IntToString(accountId, sAccountId, sizeof(sAccountId));
	if (g_smClientCache != null)
	{
		g_smClientCache.Remove(sAccountId);
	}

	// Remove from SQLite cache if available
	if (g_hSQLiteDB != null)
	{
		RemoveExpiredCacheEntry(accountId);
	}

	CReplyToCommand(admin, "%t Cache cleared for SteamID %s (AccountID: %d)", 
		"Tag", steamId2, accountId);
	
	CVBLog.Debug("Admin %N cleared cache for SteamID %s (AccountID: %d)", 
		admin, steamId2, accountId);

	delete context;
}

/**
 * Command: sm_cvb_refresh
 * Force refresh cache for online player
 */
public Action Command_RefreshPlayer(int admin, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(admin, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CReplyToCommand(admin, "%t Usage: sm_cvb_refresh <player>", "Tag");
		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int target = FindTarget(admin, sTarget, true, false);
	if (target == NO_INDEX)
	{
		return Plugin_Handled;
	}

	int accountId = GetSteamAccountID(target);
	if (accountId == 0)
	{
		CReplyToCommand(admin, "%t Player has invalid AccountID", "Tag");
		return Plugin_Handled;
	}

	char sTargetName[MAX_NAME_LENGTH];
	GetClientName(target, sTargetName, sizeof(sTargetName));

	ForceRefreshCacheEntry(accountId);

	CReplyToCommand(admin, "%t Cache refreshed for player %s (AccountID: %d)", 
		"Tag", sTargetName, accountId);
	
	CVBLog.Debug("Admin %N forced cache refresh for player %N (AccountID: %d)", 
		admin, target, accountId);

	return Plugin_Handled;
}

/**
 * Command: sm_cvb_refreshid
 * Force refresh cache by SteamID (any format)
 */
public Action Command_RefreshPlayerOffline(int admin, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(admin, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CReplyToCommand(admin, "%t Usage: sm_cvb_refreshid <steamid>", "Tag");
		return Plugin_Handled;
	}

	char sSteamId[MAX_AUTHID_LENGTH];
	GetCmdArg(1, sSteamId, sizeof(sSteamId));

	// Create context for refresh operation (reuse check context as they're similar)
	AsyncContext context = CreateAsyncContextForCheckOffline(admin);
	if (context == null)
	{
		return Plugin_Handled;
	}
	
	// Set the continuation type for refresh
	context.ContinuationType = CONTINUE_REFRESH_CACHE;
	
	SteamIDValidationResult validationResult = ValidateAndConvertSteamIDAsync(admin, sSteamId, context);
	if (validationResult == STEAMID_VALIDATION_ERROR)
	{
		// Context has already been cleaned up by ValidateAndConvertSteamIDAsync
		return Plugin_Handled;
	}
	else if (validationResult == STEAMID_VALIDATION_SUCCESS)
	{
		// Validation was successful, continue immediately
		Continue_RefreshPlayerOffline_Async(context);
	}
	// For STEAMID_VALIDATION_ASYNC, the callback will handle continuation

	return Plugin_Handled;
}

/**
 * Continuation function for cache refresh by SteamID
 */
void Continue_RefreshPlayerOffline_Async(AsyncContext context)
{
	int admin = GetClientOfUserId(context.AdminUserId);
	if (admin <= 0)
	{
		LogError("Admin disconnected during cache refresh operation");
		delete context;
		return;
	}

	int accountId = context.TargetAccountId;
	char steamId2[MAX_AUTHID_LENGTH];
	context.GetTargetSteamId(steamId2, sizeof(steamId2));

	ForceRefreshCacheEntry(accountId);

	CReplyToCommand(admin, "%t Cache refreshed for SteamID %s (AccountID: %d)", 
		"Tag", steamId2, accountId);
	
	CVBLog.Debug("Admin %N forced cache refresh for SteamID %s (AccountID: %d)", 
		admin, steamId2, accountId);
}

/**
 * Command to show StringPool usage statistics
 * Useful for debugging memory optimization
 */
public Action Command_StringPoolStats(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	int used, total;
	StringPool.GetStats(used, total);
	
	float usagePercent = total > 0 ? (float(used) / float(total)) * 100.0 : 0.0;
	
	CReplyToCommand(client, "%t === StringPool Statistics ===", "Tag");
	CReplyToCommand(client, "%t Buffers in use: %d/%d (%.1f%%)", "Tag", used, total, usagePercent);
	CReplyToCommand(client, "%t Buffer size: %d bytes each", "Tag", STRING_BUFFER_SIZE);
	CReplyToCommand(client, "%t Total pool memory: %d bytes", "Tag", total * STRING_BUFFER_SIZE);
	CReplyToCommand(client, "%t Used pool memory: %d bytes", "Tag", used * STRING_BUFFER_SIZE);
	
	if (usagePercent > 75.0)
	{
		CReplyToCommand(client, "%t Warning: Pool usage is high (%.1f%%). Consider increasing STRING_POOL_SIZE.", "Tag", usagePercent);
	}
	
	CVBLog.Debug("Admin %N checked StringPool stats: %d/%d buffers used (%.1f%%)", client, used, total, usagePercent);
	
	return Plugin_Handled;
}