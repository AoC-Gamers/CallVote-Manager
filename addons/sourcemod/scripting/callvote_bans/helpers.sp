#if defined _cvb_helpers_included
	#endinput
#endif
#define _cvb_helpers_included

enum SteamID64_ContinuationType
{
	CONTINUE_BAN_IDENTITY = 0,
	CONTINUE_UNBAN_IDENTITY,
	CONTINUE_CHECK_IDENTITY
};

enum SteamIDValidationResult
{
	STEAMID_VALIDATION_SUCCESS = 0,
	STEAMID_VALIDATION_ASYNC,
	STEAMID_VALIDATION_ERROR
};

static const SteamIDToolsProvider g_eCVBIdentityProviders[] =
{
	SteamIDToolsProvider_SteamWorks,
	SteamIDToolsProvider_System2
};

enum struct AsyncContext
{
	int AdminUserId;
	int TargetAccountId;
	SteamID64_ContinuationType ContinuationType;
	int BanType;
	int DurationMinutes;
	ReplySource CommandReplySource;
	char TargetSteamId[MAX_AUTHID_LENGTH];
	char OriginalSteamId[64];
	char Reason[256];

	void Reset()
	{
		this.AdminUserId = -1;
		this.TargetAccountId = 0;
		this.ContinuationType = view_as<SteamID64_ContinuationType>(-1);
		this.BanType = 0;
		this.DurationMinutes = 0;
		this.CommandReplySource = SM_REPLY_TO_CONSOLE;
		this.TargetSteamId[0] = '\0';
		this.OriginalSteamId[0] = '\0';
		this.Reason[0] = '\0';
	}

	bool IsInitialized()
	{
		return this.AdminUserId >= 0
			&& this.ContinuationType >= CONTINUE_BAN_IDENTITY
			&& this.ContinuationType <= CONTINUE_CHECK_IDENTITY;
	}

	bool SetTargetSteamId(const char[] steamid)
	{
		if (strlen(steamid) == 0)
		{
			LogError("AsyncContext: Empty SteamID provided");
			return false;
		}

		if (strlen(steamid) >= MAX_AUTHID_LENGTH)
		{
			LogError("AsyncContext: SteamID too long: %s", steamid);
			return false;
		}

		strcopy(this.TargetSteamId, sizeof(this.TargetSteamId), steamid);
		return true;
	}

	bool SetOriginalSteamId(const char[] steamid)
	{
		if (strlen(steamid) == 0)
		{
			LogError("AsyncContext: Empty original SteamID provided");
			return false;
		}

		strcopy(this.OriginalSteamId, sizeof(this.OriginalSteamId), steamid);
		return true;
	}

	bool SetReason(const char[] reason)
	{
		if (strlen(reason) >= 256)
		{
			LogError("AsyncContext: Reason too long, truncating");
			strcopy(this.Reason, sizeof(this.Reason), reason);
			return false;
		}

		strcopy(this.Reason, sizeof(this.Reason), reason);
		return true;
	}

	bool HasRequiredDataForBan()
	{
		return this.IsInitialized()
			&& this.AdminUserId >= 0
			&& this.TargetAccountId > 0
			&& this.BanType > 0
			&& this.ContinuationType == CONTINUE_BAN_IDENTITY;
	}

	bool HasRequiredDataForCheck()
	{
		return this.IsInitialized()
			&& this.AdminUserId >= 0
			&& this.TargetAccountId > 0
			&& this.ContinuationType == CONTINUE_CHECK_IDENTITY;
	}

	bool HasRequiredDataForUnban()
	{
		return this.IsInitialized()
			&& this.AdminUserId >= 0
			&& this.TargetAccountId > 0
			&& this.ContinuationType == CONTINUE_UNBAN_IDENTITY;
	}
}

int CVB_GetCommandIssuerUserId(int client)
{
	if (client == SERVER_INDEX)
		return 0;

	return GetClientUserId(client);
}

bool CVB_TryResolveCommandIssuer(int adminUserId, int &adminClient)
{
	adminClient = SERVER_INDEX;

	if (adminUserId == 0)
		return true;

	adminClient = GetClientOfUserId(adminUserId);
	return adminClient > 0;
}

bool TryGetConnectedAccountId(int client, int &accountId)
{
	accountId = 0;

	if (!IsValidClient(client))
		return false;

	accountId = GetClientAccountID(client);
	return accountId > 0;
}

void CVB_ReplyToCommandWithSource(int client, ReplySource replySource, const char[] format, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 4);

	ReplySource previousReplySource = GetCmdReplySource();
	SetCmdReplySource(replySource);
	CReplyToCommand(client, "%s", buffer);
	SetCmdReplySource(previousReplySource);
}

bool CVB_FindConnectedClientBySteamID64(const char[] steamId64, int &client, int &accountId, char[] targetDisplay, int targetDisplayMaxLen)
{
	client = 0;
	accountId = 0;

	if (targetDisplayMaxLen > 0)
		targetDisplay[0] = '\0';

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || IsFakeClient(iClient))
			continue;

		char clientSteamId64[32];
		if (!GetClientAuthId(iClient, AuthId_SteamID64, clientSteamId64, sizeof(clientSteamId64), true))
			continue;

		if (!StrEqual(clientSteamId64, steamId64, false))
			continue;

		client = iClient;
		accountId = GetClientAccountID(iClient);
		if (targetDisplayMaxLen > 0)
			GetClientName(iClient, targetDisplay, targetDisplayMaxLen);
		return (accountId > 0);
	}

	return false;
}

bool CVB_TryResolveOfflineAccountId(const char[] normalized, int &accountId, char[] targetDisplay, int targetDisplayMaxLen)
{
	accountId = 0;

	switch (DetectSteamIDFormat(normalized))
	{
		case STEAMID_FORMAT_ACCOUNTID:
		{
			accountId = StringToInt(normalized);
		}

		case STEAMID_FORMAT_STEAMID2:
		{
			accountId = SteamID2ToAccountID(normalized);
			strcopy(targetDisplay, targetDisplayMaxLen, normalized);
		}

		case STEAMID_FORMAT_STEAMID3:
		{
			accountId = SteamID3ToAccountID(normalized);
		}

		default:
		{
			return false;
		}
	}

	return (accountId > 0);
}

bool CVB_SetContextTargetFromAccountId(AsyncContext context, int accountId, int replyClient, const char[] invalidInput = "")
{
	if (accountId <= 0)
	{
		if (replyClient > 0)
			CReplyToCommand(replyClient, "%t %t", "Tag", "InvalidSteamIDFormat", invalidInput);
		return false;
	}

	char steamId2[MAX_AUTHID_LENGTH];
	if (!AccountIDToSteamID2(accountId, steamId2, sizeof(steamId2)))
	{
		if (replyClient > 0)
			CReplyToCommand(replyClient, "%t %t", "Tag", "InternalError", accountId);
		return false;
	}

	context.TargetAccountId = accountId;
	return context.SetTargetSteamId(steamId2);
}

void NormalizeBanReason(const char[] input, char[] output, int maxlen)
{
	output[0] = '\0';

	if (maxlen <= 0)
		return;

	strcopy(output, maxlen, input);
	TrimString(output);

	if (output[0] == '\0')
		strcopy(output, maxlen, "Admin decision");
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
	if (len > 0 && output[len - 1] == ' ')
		output[len - 1] = '\0';

	if (output[0] == '\0')
		strcopy(output, maxlen, "None");
}

void CVB_FormatDurationText(int client, int durationMinutes, char[] buffer, int maxlen)
{
	if (durationMinutes == 0)
	{
		Format(buffer, maxlen, "%T", "BanStatusPermanent", client);
		return;
	}

	Format(buffer, maxlen, "%d minutos", durationMinutes);
}

bool CVB_TryResolveInputAccountId(int admin, const char[] input, int &accountId, int &targetClient, char[] targetDisplay, int targetDisplayMaxLen)
{
	accountId = 0;
	targetClient = 0;
	targetDisplay[0] = '\0';

	char normalized[64];
	strcopy(normalized, sizeof(normalized), input);
	TrimString(normalized);
	StripQuotes(normalized);

	if (normalized[0] == '\0')
		return false;

	if (IsValidSteamID64(normalized))
	{
		return CVB_FindConnectedClientBySteamID64(normalized, targetClient, accountId, targetDisplay, targetDisplayMaxLen);
	}

	if (DetectSteamIDFormat(normalized) == STEAMID_FORMAT_STEAMID64)
		return CVB_FindConnectedClientBySteamID64(normalized, targetClient, accountId, targetDisplay, targetDisplayMaxLen);

	CVB_TryResolveOfflineAccountId(normalized, accountId, targetDisplay, targetDisplayMaxLen);

	if (accountId > 0)
	{
		int resolvedClient = FindClientByAccountID(accountId);
		if (resolvedClient > 0 && IsValidClient(resolvedClient))
		{
			targetClient = resolvedClient;
			GetClientName(resolvedClient, targetDisplay, targetDisplayMaxLen);
		}
		else if (targetDisplay[0] == '\0' && !AccountIDToSteamID2(accountId, targetDisplay, targetDisplayMaxLen))
		{
			strcopy(targetDisplay, targetDisplayMaxLen, normalized);
		}

		return true;
	}

	int target = FindTarget(admin, normalized, true, false);
	if (target <= 0)
		return false;

	targetClient = target;
	accountId = GetClientAccountID(target);
	GetClientName(target, targetDisplay, targetDisplayMaxLen);
	return (accountId > 0);
}

AsyncContext CVB_CreateAsyncContext(SteamID64_ContinuationType continuationType, int adminUserId, int banType = 0, int duration = 0, const char[] reason = "")
{
	AsyncContext ctx;
	ctx.Reset();
	ctx.ContinuationType = continuationType;
	ctx.AdminUserId = adminUserId;
	ctx.BanType = banType;
	ctx.DurationMinutes = duration;

	if (reason[0] != '\0')
		ctx.SetReason(reason);

	return ctx;
}

bool CVB_QueueIdentityLookup(int client, const char[] steamIdInput, SteamID64_ContinuationType continuationType, ReplySource replySource, int banType = 0, int durationMinutes = 0, const char[] reason = "")
{
	AsyncContext context;
	context = CVB_CreateAsyncContext(
		continuationType,
		CVB_GetCommandIssuerUserId(client),
		banType,
		durationMinutes,
		reason
	);

	context.CommandReplySource = replySource;

	SteamIDValidationResult validationResult = ValidateAndConvertSteamIDAsync(client, steamIdInput, context);
	if (validationResult == STEAMID_VALIDATION_SUCCESS)
	{
		ContinueResolvedIdentityRequest(context);
		return true;
	}

	return (validationResult == STEAMID_VALIDATION_ASYNC);
}

void InitPendingIdentityRequests()
{
	if (g_aPendingIdentityRequestIds == null)
		g_aPendingIdentityRequestIds = new ArrayList();

	if (g_aPendingIdentityRequestContexts == null)
		g_aPendingIdentityRequestContexts = new ArrayList(sizeof(AsyncContext));
}

void ClosePendingIdentityRequests()
{
	if (g_aPendingIdentityRequestContexts != null)
	{
		delete g_aPendingIdentityRequestContexts;
		g_aPendingIdentityRequestContexts = null;
	}

	if (g_aPendingIdentityRequestIds != null)
	{
		delete g_aPendingIdentityRequestIds;
		g_aPendingIdentityRequestIds = null;
	}
}

void TrackPendingIdentityRequest(int requestId, AsyncContext context)
{
	InitPendingIdentityRequests();
	g_aPendingIdentityRequestIds.Push(requestId);
	g_aPendingIdentityRequestContexts.PushArray(context, sizeof(AsyncContext));
}

bool TakePendingIdentityRequest(int requestId, AsyncContext context)
{
	context.Reset();

	if (g_aPendingIdentityRequestIds == null || g_aPendingIdentityRequestContexts == null)
		return false;

	for (int i = 0; i < g_aPendingIdentityRequestIds.Length; i++)
	{
		if (g_aPendingIdentityRequestIds.Get(i) != requestId)
			continue;

		g_aPendingIdentityRequestContexts.GetArray(i, context, sizeof(AsyncContext));
		g_aPendingIdentityRequestIds.Erase(i);
		g_aPendingIdentityRequestContexts.Erase(i);
		return true;
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
		return false;

	adminAccountId = GetSteamAccountID(client);
	return GetClientAuthId(client, AuthId_Steam2, adminSteamId2, maxlen);
}

SteamIDToolsProvider CVB_GetHealthyIdentityProvider()
{
	if (!g_bSteamIDToolsLoaded)
		return SteamIDToolsProvider_Unknown;

	for (int i = 0; i < sizeof(g_eCVBIdentityProviders); i++)
	{
		SteamIDToolsProvider provider = g_eCVBIdentityProviders[i];
		if (SteamIDTools_IsProviderReady(provider))
			return provider;
	}

	return SteamIDToolsProvider_Unknown;
}

void CVB_GetIdentityProviderName(SteamIDToolsProvider provider, char[] buffer, int maxlen)
{
	switch (provider)
	{
		case SteamIDToolsProvider_SteamWorks: strcopy(buffer, maxlen, "SteamWorks");
		case SteamIDToolsProvider_System2: strcopy(buffer, maxlen, "System2");
		default: strcopy(buffer, maxlen, "Unknown");
	}
}

bool CVB_HasAnyIdentityProviderAvailable()
{
	if (!g_bSteamIDToolsLoaded)
		return false;

	for (int i = 0; i < sizeof(g_eCVBIdentityProviders); i++)
	{
		if (SteamIDTools_IsProviderAvailable(g_eCVBIdentityProviders[i]))
			return true;
	}

	return false;
}

void CVB_RequestIdentityHealthChecks()
{
	if (!g_cvarEnable.BoolValue || !g_bSteamIDToolsLoaded)
		return;

	for (int i = 0; i < sizeof(g_eCVBIdentityProviders); i++)
	{
		SteamIDToolsProvider provider = g_eCVBIdentityProviders[i];
		if (!SteamIDTools_IsProviderAvailable(provider))
			continue;

		if (!SteamIDTools_RequestHealthCheck(provider))
		{
			char providerName[32];
			CVB_GetIdentityProviderName(provider, providerName, sizeof(providerName));
			CVBLog.Identity("Failed to queue SteamIDTools health check for provider %s", providerName);
		}
	}
}

void CVB_GetIdentityBackendSummary(char[] buffer, int maxlen)
{
	buffer[0] = '\0';

	char providerName[32];
	char statusMessage[128];
	for (int i = 0; i < sizeof(g_eCVBIdentityProviders); i++)
	{
		SteamIDToolsProvider provider = g_eCVBIdentityProviders[i];
		CVB_GetIdentityProviderName(provider, providerName, sizeof(providerName));

		if (!SteamIDTools_IsProviderAvailable(provider))
		{
			Format(statusMessage, sizeof(statusMessage), "%s unavailable", providerName);
		}
		else if (!SteamIDTools_GetBackendStatusMessage(provider, statusMessage, sizeof(statusMessage)) || statusMessage[0] == '\0')
		{
			strcopy(statusMessage, sizeof(statusMessage), "backend unavailable");
		}

		if (buffer[0] != '\0')
			StrCat(buffer, maxlen, " | ");

		StrCat(buffer, maxlen, providerName);
		StrCat(buffer, maxlen, ": ");
		StrCat(buffer, maxlen, statusMessage);
	}
}

bool QueueSteamID64ToAccountIDRequest(int client, const char[] steamid64, AsyncContext context)
{
	if (!g_bSteamIDToolsLoaded || !SteamIDTools_IsLibraryAvailable())
	{
		CReplyToCommand(client, "%t %t", "Tag", "SteamIDToolsRequired");
		CReplyToCommand(client, "%t %t", "Tag", "PleaseUseOtherFormats");
		return false;
	}

	if (!CVB_HasAnyIdentityProviderAvailable())
	{
		CReplyToCommand(client, "%t %t", "Tag", "SteamIDToolsProviderUnavailable");
		CReplyToCommand(client, "%t %t", "Tag", "PleaseUseOtherFormats");
		return false;
	}

	SteamIDToolsProvider provider = CVB_GetHealthyIdentityProvider();
	if (provider == SteamIDToolsProvider_Unknown)
	{
		char statusMessage[256];
		CVB_RequestIdentityHealthChecks();
		CVB_GetIdentityBackendSummary(statusMessage, sizeof(statusMessage));
		CReplyToCommand(client, "%t %t", "Tag", "SteamIDToolsBackendNotReady", statusMessage);
		CReplyToCommand(client, "%t %t", "Tag", "PleaseUseOtherFormats");
		return false;
	}

	int requestId = SteamIDTools_RequestConversion(provider, API_SID64toAID, steamid64, "cvb");
	if (requestId <= 0)
	{
		CReplyToCommand(client, "%t %t", "Tag", "SteamIDToolsRequestFailed", "request queue failed");
		return false;
	}

	TrackPendingIdentityRequest(requestId, context);
	return true;
}

bool SetResolvedTargetIdentity(AsyncContext context, int accountId)
{
	if (!context.IsInitialized() || accountId <= SERVER_INDEX)
		return false;

	return CVB_SetContextTargetFromAccountId(context, accountId, 0);
}

SteamIDValidationResult ValidateAndConvertSteamIDAsync(int client, const char[] steamId, AsyncContext context)
{
	context.SetOriginalSteamId(steamId);
	context.AdminUserId = CVB_GetCommandIssuerUserId(client);

	SteamIDFormat SIDFormat = DetectSteamIDFormat(steamId);
	switch (SIDFormat)
	{
		case STEAMID_FORMAT_SPECIAL:
		{
			CReplyToCommand(client, "%t %t", "Tag", "CannotProcessSpecialCases", steamId);
			CReplyToCommand(client, "%t %t", "Tag", "SpecialCases");
			return STEAMID_VALIDATION_ERROR;
		}

		case STEAMID_FORMAT_STEAMID2:
		{
			int accountId = SteamID2ToAccountID(steamId);
			if (accountId > 0)
			{
				context.TargetAccountId = accountId;
				context.SetTargetSteamId(steamId);
				return STEAMID_VALIDATION_SUCCESS;
			}

			CReplyToCommand(client, "%t %t", "Tag", "InvalidSteamIDFormat", steamId);
			return STEAMID_VALIDATION_ERROR;
		}

		case STEAMID_FORMAT_STEAMID3:
		{
			int accountId = SteamID3ToAccountID(steamId);
			if (CVB_SetContextTargetFromAccountId(context, accountId, client, steamId))
				return STEAMID_VALIDATION_SUCCESS;
			return STEAMID_VALIDATION_ERROR;
		}

		case STEAMID_FORMAT_STEAMID64:
		{
			if (!QueueSteamID64ToAccountIDRequest(client, steamId, context))
				return STEAMID_VALIDATION_ERROR;

			return STEAMID_VALIDATION_ASYNC;
		}

		case STEAMID_FORMAT_ACCOUNTID:
		{
			int accountId = StringToInt(steamId);
			if (CVB_SetContextTargetFromAccountId(context, accountId, client, steamId))
				return STEAMID_VALIDATION_SUCCESS;
			return STEAMID_VALIDATION_ERROR;
		}

		case STEAMID_FORMAT_UNKNOWN:
		{
			CReplyToCommand(client, "%t %t", "Tag", "InvalidSteamIDFormat", steamId);
			CReplyToCommand(client, "%t %t", "Tag", "SupportedFormatsHeader");
			CReplyToCommand(client, "%t %t", "Tag", "SteamID2Format");
			CReplyToCommand(client, "%t %t", "Tag", "SteamID3Format");
			CReplyToCommand(client, "%t %t", "Tag", "SteamID64Format");
			CReplyToCommand(client, "%t %t", "Tag", "AccountIDFormat");
			return STEAMID_VALIDATION_ERROR;
		}
	}

	return STEAMID_VALIDATION_ERROR;
}

void ContinueResolvedIdentityRequest(AsyncContext context)
{
	switch (context.ContinuationType)
	{
		case CONTINUE_BAN_IDENTITY:
			Continue_BanIdentity_Async(context);
		case CONTINUE_UNBAN_IDENTITY:
			Continue_UnbanIdentity_Async(context);
		case CONTINUE_CHECK_IDENTITY:
			Continue_CheckIdentity_Async(context);
		default:
		{
			LogError("Unknown continuation type: %d", context.ContinuationType);
		}
	}
}

public void SteamIDTools_OnRequestFinished(int iRequestId, SteamIDToolsProvider provider, bool bSuccess, bool bBatch, const char[] szEndpoint, const char[] szInput, const char[] szResult, const char[] szTag)
{
	AsyncContext context;
	context.Reset();
	if (!TakePendingIdentityRequest(iRequestId, context))
		return;

	if (!context.IsInitialized())
	{
		LogError("Invalid context received in SteamIDTools callback for request %d", iRequestId);
		return;
	}

	int admin;
	bool canReply = CVB_TryResolveCommandIssuer(context.AdminUserId, admin);
	if (!bSuccess)
	{
		if (canReply)
			CReplyToCommand(admin, "%t %t", "Tag", "SteamIDToolsRequestFailed", szResult);

		return;
	}

	if (bBatch || !StrEqual(szEndpoint, API_SID64toAID, false))
		return;

	char response[64];
	strcopy(response, sizeof(response), szResult);
	TrimString(response);

	int accountId = StringToInt(response);
	if (!SetResolvedTargetIdentity(context, accountId))
	{
		if (canReply)
		{
			char originalSteamId[64];
			strcopy(originalSteamId, sizeof(originalSteamId), context.OriginalSteamId);
			CReplyToCommand(admin, "%t %t", "Tag", "InvalidSteamIDFormat", originalSteamId);
		}

		return;
	}

	ContinueResolvedIdentityRequest(context);
}

public void SteamIDTools_OnBackendStatusChanged(SteamIDToolsProvider provider, SteamIDToolsBackendStatus status, const char[] szMessage)
{
	char providerName[32];
	CVB_GetIdentityProviderName(provider, providerName, sizeof(providerName));
	CVBLog.Identity("SteamIDTools backend status changed: provider=%s status=%d message=%s", providerName, view_as<int>(status), szMessage);
}
