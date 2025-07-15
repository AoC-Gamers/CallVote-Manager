#if defined _cvb_commands_included
	#endinput
#endif
#define _cvb_commands_included

enum SteamID64_ContinuationType
{
	CONTINUE_BAN_OFFLINE = 0,
	CONTINUE_UNBAN_OFFLINE = 1,
	CONTINUE_CHECK_OFFLINE = 2,
	CONTINUE_SQLITE_VERIFY = 3,
	CONTINUE_SQLITE_CHECK = 4,
	CONTINUE_SQLITE_REMOVE = 5,
	CONTINUE_STRINGMAP_CHECK = 6,
	CONTINUE_STRINGMAP_REMOVE = 7
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
	 * Internally, this property accesses the "admin_user_id" key in the underlying StringMap.
	 *
	 * Getter:
	 *   - Retrieves the integer value of "admin_user_id" from the StringMap.
	 * Setter:
	 *   - Sets the integer value of "admin_user_id" in the StringMap.
	 */
	property int AdminUserId {
		public get() {
			int value;
			view_as<StringMap>(this).GetValue("admin_user_id", value);
			return value;
		}
		public set(int value) {
			view_as<StringMap>(this).SetValue("admin_user_id", value);
		}
	}
	

	/**
	 * Property: TargetAccountId
	 * 
	 * Gets or sets the target account ID associated with this object.
	 * Internally, this property accesses the "target_account_id" key in the underlying StringMap.
	 *
	 * Getter:
	 *   - Retrieves the integer value of "target_account_id" from the StringMap.
	 *   - Returns the account ID as an integer.
	 *
	 * Setter:
	 *   - Sets the integer value of "target_account_id" in the StringMap.
	 *   - Accepts an integer value to assign as the account ID.
	 */
	property int TargetAccountId {
		public get() {
			int value;
			view_as<StringMap>(this).GetValue("target_account_id", value);
			return value;
		}
		public set(int value) {
			view_as<StringMap>(this).SetValue("target_account_id", value);
		}
	}
	
	/**
	 * Property: ContinuationType
	 * 
	 * Gets or sets the continuation type associated with a SteamID64.
	 * 
	 * Getter:
	 *   - Retrieves the "continuation_type" value from the underlying StringMap and returns it as a SteamID64_ContinuationType.
	 * 
	 * Setter:
	 *   - Sets the "continuation_type" value in the underlying StringMap using the provided SteamID64_ContinuationType.
	 *
	 * @return SteamID64_ContinuationType The current continuation type.
	 * @param value SteamID64_ContinuationType The continuation type to set.
	 */
	property SteamID64_ContinuationType ContinuationType {
		public get() {
			int value;
			view_as<StringMap>(this).GetValue("continuation_type", value);
			return view_as<SteamID64_ContinuationType>(value);
		}
		public set(SteamID64_ContinuationType value) {
			view_as<StringMap>(this).SetValue("continuation_type", view_as<int>(value));
		}
	}
	
	/**
	 * Property: BanType
	 * 
	 * Gets or sets the ban type associated with this object.
	 * Internally, this property uses a StringMap to store and retrieve the "ban_type" value.
	 * 
	 * Getter:
	 *   - Retrieves the integer value of "ban_type" from the underlying StringMap.
	 * 
	 * Setter:
	 *   - Sets the integer value of "ban_type" in the underlying StringMap.
	 */
	property int BanType {
		public get() {
			int value;
			view_as<StringMap>(this).GetValue("ban_type", value);
			return value;
		}
		public set(int value) {
			view_as<StringMap>(this).SetValue("ban_type", value);
		}
	}
	
	/**
	 * Property: DurationMinutes
	 * 
	 * Gets or sets the duration in minutes for the current object.
	 * Internally, this property accesses the "duration_minutes" key in the underlying StringMap.
	 *
	 * Getter:
	 *   - Retrieves the integer value associated with "duration_minutes".
	 *
	 * Setter:
	 *   - Sets the integer value for "duration_minutes".
	 */
	property int DurationMinutes {
		public get() {
			int value;
			view_as<StringMap>(this).GetValue("duration_minutes", value);
			return value;
		}
		public set(int value) {
			view_as<StringMap>(this).SetValue("duration_minutes", value);
		}
	}
	
	/**
	 * Retrieves the SteamID of the target and stores it in the provided buffer.
	 *
	 * @param buffer    The character array to store the retrieved SteamID.
	 * @param maxlen    The maximum length of the buffer.
	 */
	public void GetTargetSteamId(char[] buffer, int maxlen) {
		view_as<StringMap>(this).GetString("target_steamid", buffer, maxlen);
	}
	
	/**
	 * Sets the target SteamID in the underlying StringMap.
	 *
	 * @param steamid	The SteamID to set as the target.
	 */
	public void SetTargetSteamId(const char[] steamid) {
		view_as<StringMap>(this).SetString("target_steamid", steamid);
	}
	
	/**
	 * Retrieves the original SteamID associated with this object.
	 *
	 * @param buffer    The buffer to store the retrieved SteamID.
	 * @param maxlen    The maximum length of the buffer.
	 */
	public void GetOriginalSteamId(char[] buffer, int maxlen) {
		view_as<StringMap>(this).GetString("original_steamid", buffer, maxlen);
	}
	
	/**
	 * Sets the original SteamID for this object.
	 *
	 * @param steamid	The SteamID string to associate as the original SteamID.
	 */
	public void SetOriginalSteamId(const char[] steamid) {
		view_as<StringMap>(this).SetString("original_steamid", steamid);
	}
	
	/**
	 * Retrieves the "reason" string from the underlying StringMap and stores it in the provided buffer.
	 *
	 * @param buffer	Buffer to store the retrieved reason string.
	 * @param maxlen	Maximum length of the buffer.
	 */
	public void GetReason(char[] buffer, int maxlen) {
		view_as<StringMap>(this).GetString("reason", buffer, maxlen);
	}
	
	/**
	 * Sets the reason string in the underlying StringMap for this object.
	 *
	 * @param reason	The reason to be set, as a constant character array.
	 */
	public void SetReason(const char[] reason) {
		view_as<StringMap>(this).SetString("reason", reason);
	}
	
	/**
	 * Resets the current object by clearing all entries in its underlying StringMap.
	 * This effectively removes all stored key-value pairs, returning the object to its initial state.
	 */
	public void Reset() {
		view_as<StringMap>(this).Clear();
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
	RegConsoleCmd("sm_mybans", Command_MyBans, "View your own vote ban status with cache update");

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

// Modern AsyncContext-based validation function
bool ValidateAndConvertSteamIDAsync(int client, const char[] steamId, AsyncContext context)
{
	if (client == SERVER_INDEX)
	{
		context.TargetAccountId = 0;
		context.SetTargetSteamId("CONSOLE");
		return true;
	}

	// Store original SteamID for reference
	context.SetOriginalSteamId(steamId);
	context.AdminUserId = GetClientUserId(client);

	SteamIDFormat SIDFormat = DetectSteamIDFormat(steamId);

	switch (SIDFormat)
	{
		case STEAMID_FORMAT_SPECIAL:
		{
			CReplyToCommand(client, "%t %t", "Tag", "CannotProcessSpecialCases", steamId);
			CReplyToCommand(client, "%t %t", "Tag", "SpecialCases");
			return false;
		}
		case STEAMID_FORMAT_STEAMID2:
		{
			int accountId = SteamID2ToAccountID(steamId);
			if (accountId <= 0) {
				CReplyToCommand(client, "%t %t", "Tag", "InvalidSteamIDFormat", steamId);
				return false;
			}
			context.TargetAccountId = accountId;
			context.SetTargetSteamId(steamId);
			return true;
		}
		case STEAMID_FORMAT_STEAMID3:
		{
			int accountId = SteamID3ToAccountID(steamId);
			if (accountId <= 0) {
				CReplyToCommand(client, "%t %t", "Tag", "InvalidSteamIDFormat", steamId);
				return false;
			}
			context.TargetAccountId = accountId;
			
			char steamId2[MAX_AUTHID_LENGTH];
			if (!AccountIDToSteamID2(accountId, steamId2, sizeof(steamId2))) {
				CReplyToCommand(client, "%t %t", "Tag", "InternalError", accountId);
				return false;
			}
			context.SetTargetSteamId(steamId2);
			return true;
		}
		case STEAMID_FORMAT_STEAMID64:
		{
			// For SteamID64, we need async conversion
			if (g_bSteamWorksLoaded && g_cvarSteamIDToolsHTTP.IntValue == 1)
			{
				Steamworks_RequestSteamID64ToAID_Async(steamId, context);
			}
			else if (g_bSystem2Loaded && g_cvarSteamIDToolsHTTP.IntValue == 2)
			{
				System2_RequestSteamID64ToAID_Async(steamId, context);
			}
			else
			{
				CReplyToCommand(client, "%t %t", "Tag", "SteamWorksOrSystem2Required");
				CReplyToCommand(client, "%t %t", "Tag", "PleaseUseOtherFormats");
				return false;
			}
			return false; // Async operation, will continue in callback
		}
		case STEAMID_FORMAT_ACCOUNTID:
		{
			int accountId = StringToInt(steamId);
			if (accountId <= 0) {
				CReplyToCommand(client, "%t %t", "Tag", "InvalidSteamIDFormat", steamId);
				return false;
			}
			context.TargetAccountId = accountId;
			
			char steamId2[MAX_AUTHID_LENGTH];
			if (!AccountIDToSteamID2(accountId, steamId2, sizeof(steamId2))) {
				CReplyToCommand(client, "%t %t", "Tag", "InternalError", accountId);
				return false;
			}
			context.SetTargetSteamId(steamId2);
			return true;
		}
		case STEAMID_FORMAT_UNKNOWN:
		{
			CReplyToCommand(client, "%t %t", "Tag", "InvalidSteamIDFormat", steamId);
			CReplyToCommand(client, "%t %t", "Tag", "SupportedFormatsHeader");
			CReplyToCommand(client, "%t %t", "Tag", "SteamID2Format");
			CReplyToCommand(client, "%t %t", "Tag", "SteamID3Format");
			CReplyToCommand(client, "%t %t", "Tag", "SteamID64Format");
			CReplyToCommand(client, "%t %t", "Tag", "AccountIDFormat");
			return false;
		}
	}
	
	return false;
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
		if (admin > 0) {
			CReplyToCommand(admin, "%t %t", "Tag", "SteamWorksHTTPRequestFailed");
		}
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
	if (admin <= 0) {
		CVBLog.Debug("Admin disconnected during async SteamID conversion");
		delete context;
		return;
	}

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
	for (int i = 0; i <= bodySize; i++) {
		response[i] = '\0';
	}
	SteamWorks_GetHTTPResponseBodyData(hRequest, response, bodySize);
	response[bodySize] = '\0';
	TrimString(response);
	
	int accountId = StringToInt(response);
	if (accountId <= 0)
	{
		char originalSteamId[64];
		context.GetOriginalSteamId(originalSteamId, sizeof(originalSteamId));
		CReplyToCommand(admin, "%t %t", "Tag", "InvalidSteamIDFormat", originalSteamId);
		delete context;
		return;
	}

	// Update context with converted AccountID
	context.TargetAccountId = accountId;
	
	// Convert to SteamID2 format
	char steamId2[MAX_AUTHID_LENGTH];
	if (!AccountIDToSteamID2(accountId, steamId2, sizeof(steamId2))) {
		CReplyToCommand(admin, "%t %t", "Tag", "InternalError", accountId);
		delete context;
		return;
	}
	context.SetTargetSteamId(steamId2);

	// Continue with the operation based on continuation type
	switch (context.ContinuationType)
	{
		case CONTINUE_BAN_OFFLINE: {
			Continue_BanOffline_Async(context);
		}
		case CONTINUE_UNBAN_OFFLINE: {
			Continue_UnbanOffline_Async(context);
		}
		case CONTINUE_CHECK_OFFLINE: {
			Continue_CheckOffline_Async(context);
		}
		case CONTINUE_SQLITE_VERIFY: {
			Continue_SQLiteVerify_Async(context);
		}
		case CONTINUE_SQLITE_CHECK: {
			Continue_SQLiteCheckOffline_Async(context);
		}
		case CONTINUE_SQLITE_REMOVE: {
			Continue_CacheRemoveOffline_Async(context);
		}
		case CONTINUE_STRINGMAP_CHECK: {
			Continue_StringMapCheckOffline_Async(context);
		}
		case CONTINUE_STRINGMAP_REMOVE: {
			Continue_StringMapRemoveOffline_Async(context);
		}
		default: {
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
	if (!context.IsValid()) {
		LogError("Invalid context received in System2 callback");
		return;
	}

	int admin = GetClientOfUserId(context.AdminUserId);
	if (admin <= 0) {
		CVBLog.Debug("Admin disconnected during async SteamID conversion");
		delete context;
		return;
	}

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
	if (accountId <= 0)
	{
		char originalSteamId[64];
		context.GetOriginalSteamId(originalSteamId, sizeof(originalSteamId));
		CReplyToCommand(admin, "%t %t", "Tag", "InvalidSteamIDFormat", originalSteamId);
		delete context;
		return;
	}

	context.TargetAccountId = accountId;
	
	char steamId2[MAX_AUTHID_LENGTH];
	if (!AccountIDToSteamID2(accountId, steamId2, sizeof(steamId2))) {
		CReplyToCommand(admin, "%t %t", "Tag", "InternalError", accountId);
		delete context;
		return;
	}
	context.SetTargetSteamId(steamId2);

	switch (context.ContinuationType)
	{
		case CONTINUE_BAN_OFFLINE: {
			Continue_BanOffline_Async(context);
		}
		case CONTINUE_UNBAN_OFFLINE: {
			Continue_UnbanOffline_Async(context);
		}
		case CONTINUE_CHECK_OFFLINE: {
			Continue_CheckOffline_Async(context);
		}
		case CONTINUE_SQLITE_VERIFY: {
			Continue_SQLiteVerify_Async(context);
		}
		case CONTINUE_SQLITE_CHECK: {
			Continue_SQLiteCheckOffline_Async(context);
		}
		case CONTINUE_SQLITE_REMOVE: {
			Continue_CacheRemoveOffline_Async(context);
		}
		case CONTINUE_STRINGMAP_CHECK: {
			Continue_StringMapCheckOffline_Async(context);
		}
		case CONTINUE_STRINGMAP_REMOVE: {
			Continue_StringMapRemoveOffline_Async(context);
		}
		default: {
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

	int reasonCode = GetBanReasonFromString_Enhanced(reason);
	CVB_InsertBan(targetAccountId, banType, durationMinutes, adminAccountId, reasonCode);
	
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

	CVB_RemoveBan(targetAccountId, adminAccountId);
	CReplyToCommand(admin, "%t %t", "Tag", "BanRemoved", targetSteamId);
	CVBLog.Debug("Admin %N[%s] desbaneó a %s", admin, sAdminSteamId2, targetSteamId);
	
	delete context;
}

void Continue_CheckOffline_Async(AsyncContext context)
{
	int admin = GetClientOfUserId(context.AdminUserId);
	if (admin <= 0) {
		LogError("Admin disconnected during check operation");
		delete context;
		return;
	}

	int targetAccountId = context.TargetAccountId;
	char targetSteamId[MAX_AUTHID_LENGTH];
	context.GetTargetSteamId(targetSteamId, sizeof(targetSteamId));

	CheckOfflinePlayerBan(admin, targetAccountId, targetSteamId);
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
		CReplyToCommand(client, "%t %t", "Tag", "UsageCacheRemove");
		return Plugin_Handled;
	}

	char targetName[MAX_NAME_LENGTH];
	GetCmdArg(1, targetName, sizeof(targetName));

	int target = FindTarget(client, targetName, true, false);
	if (target == -1)
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

	// Remove from StringMap cache
	char sAccountId[16];
	IntToString(accountId, sAccountId, sizeof(sAccountId));
	g_hCacheStringMap.Remove(sAccountId);
	g_hPlayerBans.Remove(sAccountId);

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
		CReplyToCommand(client, "%t %t", "Tag", "UsageCacheRemoveID");
		return Plugin_Handled;
	}

	char steamId[64];
	GetCmdArg(1, steamId, sizeof(steamId));

	AsyncContext context = new AsyncContext();
	context.ContinuationType = CONTINUE_SQLITE_REMOVE;

	if (!ValidateAndConvertSteamIDAsync(client, steamId, context))
	{
		// If validation fails immediately, clean up
		if (context.IsValid())
		{
			delete context;
		}
		return Plugin_Handled;
	}

	// If we reach here, validation was successful and we can proceed immediately
	Continue_CacheRemoveOffline_Async(context);
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

	// Remove from StringMap cache
	char sAccountId[16];
	IntToString(accountId, sAccountId, sizeof(sAccountId));
	g_hCacheStringMap.Remove(sAccountId);
	g_hPlayerBans.Remove(sAccountId);

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