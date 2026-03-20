#if defined _cvb_commands_included
	#endinput
#endif
#define _cvb_commands_included

void RegisterCommands()
{
	RegAdminCmd("sm_cvb_ban", Command_Ban, ADMFLAG_BAN, "Ban players from voting: sm_cvb_ban <target|steamid|accountid> <bantype> [duration] [reason]");
	RegAdminCmd("sm_cvb_unban", Command_Unban, ADMFLAG_UNBAN, "Unban players from voting: sm_cvb_unban <target|steamid|accountid>");
	RegAdminCmd("sm_cvb_check", Command_Check, ADMFLAG_GENERIC, "Check player ban status: sm_cvb_check <target|steamid|accountid>");
}

bool CVB_IsIntegerArgument(const char[] value)
{
	if (value[0] == '\0')
		return false;

	if (value[0] == '-')
		return SteamIDTools_IsNumericString(value[1]);

	return SteamIDTools_IsNumericString(value);
}

bool CVB_EnsureCommandBackendReady(int client)
{
	if (CVB_GetActiveDatabase() != SourceDB_Unknown)
		return true;

	CReplyToCommand(client, "%t %t", "Tag", "DatabaseError");
	return false;
}

static void CVB_ReplyBanUsage(int client)
{
	CReplyToCommand(client, "%t %t: sm_cvb_ban <target|steamid|accountid> <bantype> [duration] [reason]", "Tag", "Usage");
	CReplyToCommand(client, "%t %t", "Tag", "SupportedSteamIDFormats");
	CReplyToCommand(client, "%t %t", "Tag", "BanTypes");
}

static void CVB_ReplyUnbanUsage(int client)
{
	CReplyToCommand(client, "%t %t: sm_cvb_unban <target|steamid|accountid>", "Tag", "Usage");
	CReplyToCommand(client, "%t %t", "Tag", "SupportedSteamIDFormats");
}

static void CVB_ReplyCheckUsage(int client)
{
	CReplyToCommand(client, "%t %t: sm_cvb_check <target|steamid|accountid>", "Tag", "Usage");
	CReplyToCommand(client, "%t %t", "Tag", "SupportedSteamIDFormats");
}

static void CVB_ReplyResolveFailure(int client, const char[] input)
{
	SteamIDFormat format = DetectSteamIDFormat(input);
	if (format == STEAMID_FORMAT_SPECIAL)
	{
		CReplyToCommand(client, "%t %t", "Tag", "CannotProcessSpecialCases", input);
		CReplyToCommand(client, "%t %t", "Tag", "SpecialCases");
		return;
	}

	if (format != STEAMID_FORMAT_UNKNOWN)
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidSteamIDFormat", input);
		CReplyToCommand(client, "%t %t", "Tag", "SupportedFormatsHeader");
		CReplyToCommand(client, "%t %t", "Tag", "SteamID2Format");
		CReplyToCommand(client, "%t %t", "Tag", "SteamID3Format");
		CReplyToCommand(client, "%t %t", "Tag", "SteamID64Format");
		CReplyToCommand(client, "%t %t", "Tag", "AccountIDFormat");
		return;
	}

	CReplyToCommand(client, "%t %t", "Tag", "InvalidPlayer");
}

public Action Command_Ban(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (!CVB_EnsureCommandBackendReady(client))
		return Plugin_Handled;

	if (args < 2)
	{
		CVB_ReplyBanUsage(client);
		return Plugin_Handled;
	}

	char input[64];
	char banTypeArg[16];
	char nextValue[32];
	char reason[256];
	char targetDisplay[MAX_NAME_LENGTH];
	int nextArg = 0;
	int targetAccountId = 0;
	int targetClient = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, args, input, sizeof(input), nextArg);
	SteamIDTools_GetCmdArgNormalized(nextArg, args, banTypeArg, sizeof(banTypeArg));

	int banType = StringToInt(banTypeArg);
	int durationMinutes = 0;
	int reasonStartArg = nextArg + 1;
	if (SteamIDTools_GetCmdArgNormalized(nextArg + 1, args, nextValue, sizeof(nextValue)) && CVB_IsIntegerArgument(nextValue))
	{
		durationMinutes = StringToInt(nextValue);
		reasonStartArg = nextArg + 2;
	}

	if (banType <= 0 || banType > view_as<int>(VOTE_ALL))
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidBanType", banType, view_as<int>(VOTE_ALL));
		CVB_ReplyBanUsage(client);
		return Plugin_Handled;
	}

	if (durationMinutes < 0)
	{
		CReplyToCommand(client, "%t %t", "Tag", "InvalidDuration", durationMinutes);
		CVB_ReplyBanUsage(client);
		return Plugin_Handled;
	}

	SteamIDTools_JoinCmdArgs(reasonStartArg, args, reason, sizeof(reason));

	if ((IsValidSteamID64(input) || DetectSteamIDFormat(input) == STEAMID_FORMAT_STEAMID64)
		&& !CVB_TryResolveInputAccountId(client, input, targetAccountId, targetClient, targetDisplay, sizeof(targetDisplay)))
	{
		CVB_QueueIdentityLookup(client, input, CONTINUE_BAN_IDENTITY, GetCmdReplySource(), banType, durationMinutes, reason);
		return Plugin_Handled;
	}

	if (!CVB_TryResolveInputAccountId(client, input, targetAccountId, targetClient, targetDisplay, sizeof(targetDisplay)))
	{
		CVB_ReplyResolveFailure(client, input);
		CVB_ReplyBanUsage(client);
		return Plugin_Handled;
	}

	CVB_QueueAddBan(client, targetAccountId, targetClient, banType, durationMinutes, targetDisplay, reason, GetCmdReplySource());
	return Plugin_Handled;
}

public Action Command_Unban(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (!CVB_EnsureCommandBackendReady(client))
		return Plugin_Handled;

	if (args < 1)
	{
		CVB_ReplyUnbanUsage(client);
		return Plugin_Handled;
	}

	char input[64];
	char targetDisplay[MAX_NAME_LENGTH];
	int nextArg = 0;
	int targetAccountId = 0;
	int targetClient = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, args, input, sizeof(input), nextArg);

	if ((IsValidSteamID64(input) || DetectSteamIDFormat(input) == STEAMID_FORMAT_STEAMID64)
		&& !CVB_TryResolveInputAccountId(client, input, targetAccountId, targetClient, targetDisplay, sizeof(targetDisplay)))
	{
		CVB_QueueIdentityLookup(client, input, CONTINUE_UNBAN_IDENTITY, GetCmdReplySource());
		return Plugin_Handled;
	}

	if (!CVB_TryResolveInputAccountId(client, input, targetAccountId, targetClient, targetDisplay, sizeof(targetDisplay)))
	{
		CVB_ReplyResolveFailure(client, input);
		CVB_ReplyUnbanUsage(client);
		return Plugin_Handled;
	}

	CVB_QueueRemoveBan(client, targetAccountId, targetClient, targetDisplay, GetCmdReplySource());
	return Plugin_Handled;
}

public Action Command_Check(int client, int args)
{
	if (!g_cvarEnable.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "Tag", "PluginDisabled");
		return Plugin_Handled;
	}

	if (!CVB_EnsureCommandBackendReady(client))
		return Plugin_Handled;

	if (args < 1)
	{
		CVB_ReplyCheckUsage(client);
		return Plugin_Handled;
	}

	char input[64];
	char targetDisplay[MAX_NAME_LENGTH];
	int nextArg = 0;
	int targetAccountId = 0;
	int targetClient = 0;
	SteamIDTools_TryGetIdentityFromCmdArgs(1, args, input, sizeof(input), nextArg);

	if ((IsValidSteamID64(input) || DetectSteamIDFormat(input) == STEAMID_FORMAT_STEAMID64)
		&& !CVB_TryResolveInputAccountId(client, input, targetAccountId, targetClient, targetDisplay, sizeof(targetDisplay)))
	{
		CVB_QueueIdentityLookup(client, input, CONTINUE_CHECK_IDENTITY, GetCmdReplySource());
		return Plugin_Handled;
	}

	if (!CVB_TryResolveInputAccountId(client, input, targetAccountId, targetClient, targetDisplay, sizeof(targetDisplay)))
	{
		CVB_ReplyResolveFailure(client, input);
		CVB_ReplyCheckUsage(client);
		return Plugin_Handled;
	}

	if (targetClient > 0 && IsValidClient(targetClient))
		CReplyToCommand(client, "%t %t", "Tag", "BanStatusCheckingPlayer", targetClient);
	else
		CReplyToCommand(client, "%t %t", "Tag", "BanStatusVerifying", targetDisplay);

	CVB_QueueFullBanLookup(client, targetAccountId, targetClient, targetDisplay, GetCmdReplySource());
	return Plugin_Handled;
}

void Continue_BanIdentity_Async(AsyncContext context)
{
	if (!context.HasRequiredDataForBan())
	{
		LogError("Invalid async ban context");
		return;
	}

	int admin;
	if (!CVB_TryResolveCommandIssuer(context.AdminUserId, admin))
	{
		LogError("Admin disconnected during ban operation");
		return;
	}

	int targetAccountId = context.TargetAccountId;
	int banType = context.BanType;
	int durationMinutes = context.DurationMinutes;

	char reason[256];
	strcopy(reason, sizeof(reason), context.Reason);

	int targetClient = FindClientByAccountID(targetAccountId);
	CVB_QueueAddBan(admin, targetAccountId, targetClient, banType, durationMinutes, context.TargetSteamId, reason, context.CommandReplySource);
}

void Continue_UnbanIdentity_Async(AsyncContext context)
{
	if (!context.HasRequiredDataForUnban())
	{
		LogError("Invalid async unban context");
		return;
	}

	int admin;
	if (!CVB_TryResolveCommandIssuer(context.AdminUserId, admin))
	{
		LogError("Admin disconnected during unban operation");
		return;
	}

	int targetAccountId = context.TargetAccountId;

	int targetClient = FindClientByAccountID(targetAccountId);
	CVB_QueueRemoveBan(admin, targetAccountId, targetClient, context.TargetSteamId, context.CommandReplySource);
}

void Continue_CheckIdentity_Async(AsyncContext context)
{
	if (!context.HasRequiredDataForCheck())
	{
		LogError("Invalid async check context");
		return;
	}

	int admin;
	if (!CVB_TryResolveCommandIssuer(context.AdminUserId, admin))
	{
		LogError("Admin disconnected during offline check operation");
		return;
	}

	int targetAccountId = context.TargetAccountId;

	CReplyToCommand(admin, "%t %t", "Tag", "BanStatusVerifying", context.TargetSteamId);
	CVBLog.Commands("Admin %N checking player identity %s (AccountID: %d)", admin, context.TargetSteamId, targetAccountId);

	CVB_QueueFullBanLookup(admin, targetAccountId, FindClientByAccountID(targetAccountId), context.TargetSteamId, context.CommandReplySource);
}
