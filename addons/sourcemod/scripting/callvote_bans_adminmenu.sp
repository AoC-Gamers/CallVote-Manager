#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <callvote_stock>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <callvote_bans>
#include <l4d2_commcore>
#define REQUIRE_PLUGIN

#define CALLVOTE_BANS_ADMINMENU_VERSION "1.0.0"
#define CALLVOTE_BANS_ADMINMENU_MAX_REASON_LENGTH 256
#define CVBAM_LOG_TAG "CVBAM"
#define CVBAM_LOG_FILE "callvote_bans_adminmenu.log"

TopMenu g_hCVBAdminTopMenu;
TopMenuObject g_oCVBAdminCategory = INVALID_TOPMENUOBJECT;
TopMenuObject g_oCVBAdminBan = INVALID_TOPMENUOBJECT;
TopMenuObject g_oCVBAdminUnban = INVALID_TOPMENUOBJECT;
TopMenuObject g_oCVBAdminCheck = INVALID_TOPMENUOBJECT;

ConVar g_cvarLogMode;
ConVar g_cvarDebugMask;
CallVoteLogger g_Log = null;

enum CVBAdminMenuPanelType
{
	CVBAdminMenuPanel_None = 0,
	CVBAdminMenuPanel_Ban,
	CVBAdminMenuPanel_Unban,
	CVBAdminMenuPanel_Check
}

enum CVBAdminMenuPromptStage
{
	CVBAdminMenuPrompt_None = 0,
	CVBAdminMenuPrompt_Reason
}

enum struct CVBAdminMenuState
{
	CVBAdminMenuPanelType panelType;
	CVBAdminMenuPromptStage promptStage;
	int targetUserId;
	int banType;
	int durationMinutes;
	char targetName[MAX_NAME_LENGTH];
}

CVBAdminMenuState g_eCVBAdminState[MAXPLAYERS + 1];

methodmap CVBAMLog
{
	public static void Debug(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[512];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_Core, "Core", "%s", sFormat);
	}

	public static void Commands(const char[] message, any...)
	{
		if (g_Log == null)
			return;

		static char sFormat[512];
		VFormat(sFormat, sizeof(sFormat), message, 2);
		g_Log.Debug(CVLogMask_Commands, "Commands", "%s", sFormat);
	}
}

public Plugin myinfo =
{
	name = "CallVote Bans Admin Menu",
	author = "lechuga",
	description = "External admin menu bridge for CallVote Bans.",
	version = CALLVOTE_BANS_ADMINMENU_VERSION,
	url = "https://github.com/AoC-Gamers/CallVote-Manager"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("callvote_bans.phrases");
	LoadTranslations("callvote_bans_adminmenu.phrases");

	g_cvarLogMode = CallVoteEnsureLogModeConVar();
	g_cvarDebugMask = CreateConVar("sm_cvbam_debug_mask", "0", "Debug mask for callvote_bans_adminmenu. Core=1 SQL=2 Cache=4 Commands=8 Identity=16 Forwards=32 Session=64 Localization=128 All=255.", FCVAR_NONE, true, 0.0, true, 255.0);
	g_Log = new CallVoteLogger(CVBAM_LOG_TAG, CVBAM_LOG_FILE, g_cvarLogMode, g_cvarDebugMask);

	RegAdminCmd("sm_cvb_ban_panel", Command_CVBAdminBanPanel, ADMFLAG_BAN, "Open the CallVote Bans admin panel.");
	RegAdminCmd("sm_cvb_unban_panel", Command_CVBAdminUnbanPanel, ADMFLAG_UNBAN, "Open the CallVote Bans unban panel.");
	RegAdminCmd("sm_cvb_check_panel", Command_CVBAdminCheckPanel, ADMFLAG_GENERIC, "Open the CallVote Bans check panel.");
RegAdminCmd("sm_cvb_panel_abort", Command_CVBAdminAbort, ADMFLAG_GENERIC, "Abort the current CallVote Bans panel prompt.");
RegAdminCmd("sm_cvb_panel_status", Command_CVBAdminStatus, ADMFLAG_GENERIC, "Show CallVote Bans admin menu runtime status.");
	RegAdminCmd("sm_cvb_reason", Command_CVBAdminReason, ADMFLAG_BAN, "Submit the active CallVote Bans reason prompt without public chat.");

	CallVoteAutoExecConfig(true, "callvote_bans_adminmenu");

	if (LibraryExists("adminmenu"))
	{
		TopMenu hTopMenu = GetAdminTopMenu();
		if (hTopMenu != null)
			OnAdminMenuReady(hTopMenu);
	}
}

public void OnPluginEnd()
{
	if (g_Log != null)
		delete g_Log;
}

public void OnClientDisconnect(int iClient)
{
	CVBAdminMenu_ResetState(iClient);
}

public Action OnClientSayCommand(int iClient, const char[] szCommand, const char[] szArgs)
{
	if (!CVBAdminMenu_HasActivePrompt(iClient))
		return Plugin_Continue;

	if (LibraryExists(L4D2_COMMCORE_LIBRARY) && L4D2Comm_IsCoreReady())
		return Plugin_Continue;

	return CVBAdminMenu_ConsumeReasonInput(iClient, szArgs) ? Plugin_Handled : Plugin_Handled;
}

public Action L4D2Comm_OnChatMessage(int client, L4D2CommChannel channel, const char[] text)
{
	if (!CVBAdminMenu_HasActivePrompt(client))
		return Plugin_Continue;

	if (!LibraryExists(L4D2_COMMCORE_LIBRARY) || !L4D2Comm_IsCoreReady())
		return Plugin_Continue;

	CVBAMLog.Commands("Captured prompt reason through l4d2_commcore from client %d channel=%d", client, view_as<int>(channel));
	return CVBAdminMenu_ConsumeReasonInput(client, text) ? Plugin_Handled : Plugin_Handled;
}

public void OnLibraryAdded(const char[] szName)
{
	if (StrEqual(szName, "adminmenu", false))
	{
		TopMenu hTopMenu = GetAdminTopMenu();
		if (hTopMenu != null)
			OnAdminMenuReady(hTopMenu);
	}
}

public void OnAdminMenuReady(Handle hTopMenuHandle)
{
	TopMenu hTopMenu = TopMenu.FromHandle(hTopMenuHandle);
	if (g_hCVBAdminTopMenu == hTopMenu)
		return;

	g_hCVBAdminTopMenu = hTopMenu;
	g_oCVBAdminCategory = INVALID_TOPMENUOBJECT;
	g_oCVBAdminBan = INVALID_TOPMENUOBJECT;
	g_oCVBAdminUnban = INVALID_TOPMENUOBJECT;
	g_oCVBAdminCheck = INVALID_TOPMENUOBJECT;

	g_oCVBAdminCategory = g_hCVBAdminTopMenu.AddCategory("callvote_bans_adminmenu", CVBAdminMenu_CategoryHandler);
	CVBAdminMenu_TryAddItems();
	CVBAMLog.Debug("Admin menu ready and category registered");
}

static void CVBAdminMenu_TryAddItems()
{
	if (g_hCVBAdminTopMenu == null || g_oCVBAdminCategory == INVALID_TOPMENUOBJECT)
		return;

	if (g_oCVBAdminBan == INVALID_TOPMENUOBJECT)
	{
		g_oCVBAdminBan = g_hCVBAdminTopMenu.AddItem("callvote_bans_ban_panel", CVBAdminMenu_BanHandler, g_oCVBAdminCategory, "sm_cvb_ban_panel", ADMFLAG_BAN);
	}

	if (g_oCVBAdminUnban == INVALID_TOPMENUOBJECT)
	{
		g_oCVBAdminUnban = g_hCVBAdminTopMenu.AddItem("callvote_bans_unban_panel", CVBAdminMenu_UnbanHandler, g_oCVBAdminCategory, "sm_cvb_unban_panel", ADMFLAG_UNBAN);
	}

	if (g_oCVBAdminCheck == INVALID_TOPMENUOBJECT)
	{
		g_oCVBAdminCheck = g_hCVBAdminTopMenu.AddItem("callvote_bans_check_panel", CVBAdminMenu_CheckHandler, g_oCVBAdminCategory, "sm_cvb_check_panel", ADMFLAG_GENERIC);
	}
}

public void CVBAdminMenu_CategoryHandler(TopMenu hTopMenu, TopMenuAction eAction, TopMenuObject oObject, int iClient, char[] szBuffer, int iMaxLength)
{
	if (eAction == TopMenuAction_DisplayTitle || eAction == TopMenuAction_DisplayOption)
		FormatEx(szBuffer, iMaxLength, "%T", "CVBAdminMenuCategory", iClient);
}

public void CVBAdminMenu_BanHandler(TopMenu hTopMenu, TopMenuAction eAction, TopMenuObject oObject, int iClient, char[] szBuffer, int iMaxLength)
{
	CVBAdminMenu_HandleTopMenuItem(eAction, iClient, szBuffer, iMaxLength, "CVBAdminMenuBan", "sm_cvb_ban_panel");
}

public void CVBAdminMenu_UnbanHandler(TopMenu hTopMenu, TopMenuAction eAction, TopMenuObject oObject, int iClient, char[] szBuffer, int iMaxLength)
{
	CVBAdminMenu_HandleTopMenuItem(eAction, iClient, szBuffer, iMaxLength, "CVBAdminMenuUnban", "sm_cvb_unban_panel");
}

public void CVBAdminMenu_CheckHandler(TopMenu hTopMenu, TopMenuAction eAction, TopMenuObject oObject, int iClient, char[] szBuffer, int iMaxLength)
{
	CVBAdminMenu_HandleTopMenuItem(eAction, iClient, szBuffer, iMaxLength, "CVBAdminMenuCheck", "sm_cvb_check_panel");
}

static void CVBAdminMenu_HandleTopMenuItem(TopMenuAction eAction, int iClient, char[] szBuffer, int iMaxLength, const char[] szPhrase, const char[] szCommand)
{
	switch (eAction)
	{
		case TopMenuAction_DisplayOption:
		{
			FormatEx(szBuffer, iMaxLength, "%T", szPhrase, iClient);
		}

		case TopMenuAction_SelectOption:
		{
			if (!LibraryExists(CALLVOTE_BANS_LIBRARY))
			{
				CPrintToChat(iClient, "%t %t", "Tag", "CVBAdminMenuModuleUnavailable");
				return;
			}

			FakeClientCommand(iClient, szCommand);
		}
	}
}

Action Command_CVBAdminBanPanel(int iClient, int iArgs)
{
	if (!CVBAdminMenu_CanOpen(iClient))
		return Plugin_Handled;

	CVBAdminMenu_ShowBanTargetPanel(iClient);
	return Plugin_Handled;
}

Action Command_CVBAdminUnbanPanel(int iClient, int iArgs)
{
	if (!CVBAdminMenu_CanOpen(iClient))
		return Plugin_Handled;

	CVBAdminMenu_ShowUnbanTargetPanel(iClient);
	return Plugin_Handled;
}

Action Command_CVBAdminCheckPanel(int iClient, int iArgs)
{
	if (!CVBAdminMenu_CanOpen(iClient))
		return Plugin_Handled;

	CVBAdminMenu_ShowCheckTargetPanel(iClient);
	return Plugin_Handled;
}

Action Command_CVBAdminAbort(int iClient, int iArgs)
{
	if (!CVBAdminMenu_HasActivePrompt(iClient))
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "CVBAdminMenuNoActivePrompt");
		return Plugin_Handled;
	}

	CVBAdminMenu_ResetState(iClient);
	CReplyToCommand(iClient, "%t %t", "Tag", "CVBAdminMenuCancelled");
	return Plugin_Handled;
}

Action Command_CVBAdminReason(int iClient, int iArgs)
{
	if (!CVBAdminMenu_HasActivePrompt(iClient))
	{
		CReplyToCommand(iClient, "%t %t", "Tag", "CVBAdminMenuNoActivePrompt");
		return Plugin_Handled;
	}

	if (iArgs < 1)
	{
		CReplyToCommand(iClient, "%t %t sm_cvb_reason <text>", "Tag", "Usage");
		return Plugin_Handled;
	}

	char reason[CALLVOTE_BANS_ADMINMENU_MAX_REASON_LENGTH];
	GetCmdArgString(reason, sizeof(reason));
	TrimString(reason);
	StripQuotes(reason);

	CVBAMLog.Commands("Received prompt reason through sm_cvb_reason from client %d", iClient);
	CVBAdminMenu_ConsumeReasonInput(iClient, reason);
	return Plugin_Handled;
}

Action Command_CVBAdminStatus(int iClient, int iArgs)
{
	bool hasAdminMenu = LibraryExists("adminmenu");
	bool hasBans = LibraryExists(CALLVOTE_BANS_LIBRARY);
	bool hasCommCore = LibraryExists(L4D2_COMMCORE_LIBRARY);
	bool hasPrompt = CVBAdminMenu_HasActivePrompt(iClient);

	CReplyToCommand(iClient, "[CVBAM] adminmenu=%s callvote_bans=%s commcore=%s topmenu=%s prompt=%s targetUserId=%d panelType=%d promptStage=%d",
		hasAdminMenu ? "yes" : "no",
		hasBans ? "yes" : "no",
		hasCommCore ? "yes" : "no",
		g_hCVBAdminTopMenu != null ? "ready" : "null",
		hasPrompt ? "yes" : "no",
		(iClient > 0 && iClient <= MaxClients) ? g_eCVBAdminState[iClient].targetUserId : 0,
		(iClient > 0 && iClient <= MaxClients) ? view_as<int>(g_eCVBAdminState[iClient].panelType) : 0,
		(iClient > 0 && iClient <= MaxClients) ? view_as<int>(g_eCVBAdminState[iClient].promptStage) : 0);

	CVBAMLog.Commands("Status requested by client %d (adminmenu=%d callvote_bans=%d commcore=%d topmenu=%d prompt=%d)",
		iClient,
		hasAdminMenu,
		hasBans,
		hasCommCore,
		g_hCVBAdminTopMenu != null,
		hasPrompt);
	return Plugin_Handled;
}

bool CVBAdminMenu_CanOpen(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return false;

	if (!LibraryExists(CALLVOTE_BANS_LIBRARY))
	{
		CPrintToChat(iClient, "%t %t", "Tag", "CVBAdminMenuModuleUnavailable");
		return false;
	}

	CVBAdminMenu_ResetState(iClient);
	CVBAMLog.Commands("Opening admin menu flow for client %d", iClient);
	return true;
}

bool CVBAdminMenu_HasActivePrompt(int iClient)
{
	return iClient > 0
		&& iClient <= MaxClients
		&& IsClientInGame(iClient)
		&& g_eCVBAdminState[iClient].promptStage == CVBAdminMenuPrompt_Reason;
}

void CVBAdminMenu_ResetState(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients)
		return;

	g_eCVBAdminState[iClient].panelType = CVBAdminMenuPanel_None;
	g_eCVBAdminState[iClient].promptStage = CVBAdminMenuPrompt_None;
	g_eCVBAdminState[iClient].targetUserId = 0;
	g_eCVBAdminState[iClient].banType = 0;
	g_eCVBAdminState[iClient].durationMinutes = 0;
	g_eCVBAdminState[iClient].targetName[0] = '\0';
}

bool CVBAdminMenu_IsValidTarget(int iClient)
{
	return iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && !IsFakeClient(iClient);
}

void CVBAdminMenu_SetTargetState(int iClient, CVBAdminMenuPanelType ePanelType, int iTarget)
{
	g_eCVBAdminState[iClient].panelType = ePanelType;
	g_eCVBAdminState[iClient].targetUserId = GetClientUserId(iTarget);
	GetClientName(iTarget, g_eCVBAdminState[iClient].targetName, sizeof(g_eCVBAdminState[].targetName));
}

void CVBAdminMenu_ShowBanTargetPanel(int iClient)
{
	Menu hMenu = new Menu(CVBAdminMenu_MenuHandlerBanTarget, MENU_ACTIONS_DEFAULT);

	char szTitle[128];
	Format(szTitle, sizeof(szTitle), "%T", "MenuBanManagementTitle", iClient);
	hMenu.SetTitle(szTitle);
	hMenu.ExitButton = true;

	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!CVBAdminMenu_IsValidTarget(i))
			continue;

		char szInfo[16];
		IntToString(GetClientUserId(i), szInfo, sizeof(szInfo));

		char szName[MAX_NAME_LENGTH];
		GetClientName(i, szName, sizeof(szName));
		if (CVB_IsPlayerBanned(i))
		{
			char szBanType[64];
			CVBAdminMenu_GetBanTypeString(CVB_GetPlayerBanType(i), szBanType, sizeof(szBanType));
			Format(szName, sizeof(szName), "%T", "MenuBannedPlayerFormat", iClient, szName, szBanType);
		}

		hMenu.AddItem(szInfo, szName);
		iCount++;
	}

	if (!iCount)
	{
		char szNoPlayers[64];
		Format(szNoPlayers, sizeof(szNoPlayers), "%T", "MenuNoPlayersConnected", iClient);
		hMenu.AddItem("", szNoPlayers, ITEMDRAW_DISABLED);
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int CVBAdminMenu_MenuHandlerBanTarget(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	switch (eAction)
	{
		case MenuAction_Select:
		{
			char szInfo[16];
			hMenu.GetItem(iItem, szInfo, sizeof(szInfo));
			int iTarget = GetClientOfUserId(StringToInt(szInfo));
			if (!CVBAdminMenu_IsValidTarget(iTarget))
			{
				CPrintToChat(iClient, "%t %t", "Tag", "MenuPlayerDisconnected");
				CVBAdminMenu_ShowBanTargetPanel(iClient);
				return 0;
			}

			CVBAdminMenu_SetTargetState(iClient, CVBAdminMenuPanel_Ban, iTarget);
			CVBAdminMenu_ShowBanTypePanel(iClient);
		}

		case MenuAction_End:
			delete hMenu;
	}

	return 0;
}

void CVBAdminMenu_ShowBanTypePanel(int iClient)
{
	Menu hMenu = new Menu(CVBAdminMenu_MenuHandlerBanType, MENU_ACTIONS_DEFAULT);

	char szTitle[128];
	Format(szTitle, sizeof(szTitle), "%T", "MenuBanPlayerTitle", iClient, g_eCVBAdminState[iClient].targetName);
	hMenu.SetTitle(szTitle);
	hMenu.ExitBackButton = true;

	char szDifficulty[32], szRestart[32], szKick[32], szMission[32], szLobby[32], szChapter[32], szAllTalk[32], szAll[32];
	Format(szDifficulty, sizeof(szDifficulty), "%T", "MenuBanTypeDifficulty", iClient);
	Format(szRestart, sizeof(szRestart), "%T", "MenuBanTypeRestart", iClient);
	Format(szKick, sizeof(szKick), "%T", "MenuBanTypeKick", iClient);
	Format(szMission, sizeof(szMission), "%T", "MenuBanTypeMission", iClient);
	Format(szLobby, sizeof(szLobby), "%T", "MenuBanTypeLobby", iClient);
	Format(szChapter, sizeof(szChapter), "%T", "MenuBanTypeChapter", iClient);
	Format(szAllTalk, sizeof(szAllTalk), "%T", "MenuBanTypeAllTalk", iClient);
	Format(szAll, sizeof(szAll), "%T", "MenuBanTypeAll", iClient);

	hMenu.AddItem("1", szDifficulty);
	hMenu.AddItem("2", szRestart);
	hMenu.AddItem("4", szKick);
	hMenu.AddItem("8", szMission);
	hMenu.AddItem("16", szLobby);
	hMenu.AddItem("32", szChapter);
	hMenu.AddItem("64", szAllTalk);
	hMenu.AddItem("127", szAll);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int CVBAdminMenu_MenuHandlerBanType(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	switch (eAction)
	{
		case MenuAction_Select:
		{
			char szInfo[8];
			hMenu.GetItem(iItem, szInfo, sizeof(szInfo));
			g_eCVBAdminState[iClient].banType = StringToInt(szInfo);
			CVBAdminMenu_ShowBanDurationPanel(iClient);
		}

		case MenuAction_Cancel:
		{
			if (iItem == MenuCancel_ExitBack)
				CVBAdminMenu_ShowBanTargetPanel(iClient);
		}

		case MenuAction_End:
			delete hMenu;
	}

	return 0;
}

void CVBAdminMenu_ShowBanDurationPanel(int iClient)
{
	Menu hMenu = new Menu(CVBAdminMenu_MenuHandlerBanDuration, MENU_ACTIONS_DEFAULT);

	char szBanType[64];
	CVBAdminMenu_GetBanTypeString(g_eCVBAdminState[iClient].banType, szBanType, sizeof(szBanType));

	char szTitle[128];
	Format(szTitle, sizeof(szTitle), "%T", "MenuBanDurationTitle", iClient, g_eCVBAdminState[iClient].targetName, szBanType);
	hMenu.SetTitle(szTitle);
	hMenu.ExitBackButton = true;

	char szPermanent[32], sz30Min[32], sz1Hour[32], sz3Hours[32], sz6Hours[32], sz12Hours[32], sz1Day[32], sz3Days[32], sz1Week[32];
	Format(szPermanent, sizeof(szPermanent), "%T", "MenuBanDurationPermanent", iClient);
	Format(sz30Min, sizeof(sz30Min), "%T", "MenuBanDuration30Min", iClient);
	Format(sz1Hour, sizeof(sz1Hour), "%T", "MenuBanDuration1Hour", iClient);
	Format(sz3Hours, sizeof(sz3Hours), "%T", "MenuBanDuration3Hours", iClient);
	Format(sz6Hours, sizeof(sz6Hours), "%T", "MenuBanDuration6Hours", iClient);
	Format(sz12Hours, sizeof(sz12Hours), "%T", "MenuBanDuration12Hours", iClient);
	Format(sz1Day, sizeof(sz1Day), "%T", "MenuBanDuration1Day", iClient);
	Format(sz3Days, sizeof(sz3Days), "%T", "MenuBanDuration3Days", iClient);
	Format(sz1Week, sizeof(sz1Week), "%T", "MenuBanDuration1Week", iClient);

	hMenu.AddItem("0", szPermanent);
	hMenu.AddItem("30", sz30Min);
	hMenu.AddItem("60", sz1Hour);
	hMenu.AddItem("180", sz3Hours);
	hMenu.AddItem("360", sz6Hours);
	hMenu.AddItem("720", sz12Hours);
	hMenu.AddItem("1440", sz1Day);
	hMenu.AddItem("4320", sz3Days);
	hMenu.AddItem("10080", sz1Week);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int CVBAdminMenu_MenuHandlerBanDuration(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	switch (eAction)
	{
		case MenuAction_Select:
		{
			char szInfo[16];
			hMenu.GetItem(iItem, szInfo, sizeof(szInfo));
			g_eCVBAdminState[iClient].durationMinutes = StringToInt(szInfo);
			g_eCVBAdminState[iClient].promptStage = CVBAdminMenuPrompt_Reason;
			CVBAdminMenu_ShowReasonPrompt(iClient);
		}

		case MenuAction_Cancel:
		{
			if (iItem == MenuCancel_ExitBack)
				CVBAdminMenu_ShowBanTypePanel(iClient);
		}

		case MenuAction_End:
			delete hMenu;
	}

	return 0;
}

void CVBAdminMenu_ShowReasonPrompt(int iClient)
{
	CPrintToChat(iClient, "%t %t", "Tag", "CVBAdminMenuReasonPrompt", g_eCVBAdminState[iClient].targetName);
}

static bool CVBAdminMenu_ConsumeReasonInput(int iClient, const char[] input)
{
	char szReason[CALLVOTE_BANS_ADMINMENU_MAX_REASON_LENGTH];
	strcopy(szReason, sizeof(szReason), input);
	TrimString(szReason);
	StripQuotes(szReason);

	if (szReason[0] == '\0')
	{
		CPrintToChat(iClient, "%t %t", "Tag", "CVBAdminMenuReasonRequired");
		CVBAdminMenu_ShowReasonPrompt(iClient);
		return false;
	}

	if (StrEqual(szReason, "cancel", false) || StrEqual(szReason, "!cancel", false))
	{
		CVBAdminMenu_ResetState(iClient);
		CPrintToChat(iClient, "%t %t", "Tag", "CVBAdminMenuCancelled");
		return true;
	}

	if (!LibraryExists(CALLVOTE_BANS_LIBRARY))
	{
		CVBAdminMenu_ResetState(iClient);
		CPrintToChat(iClient, "%t %t", "Tag", "CVBAdminMenuModuleUnavailable");
		return false;
	}

	int iTarget = GetClientOfUserId(g_eCVBAdminState[iClient].targetUserId);
	if (!CVBAdminMenu_IsValidTarget(iTarget))
	{
		CVBAdminMenu_ResetState(iClient);
		CPrintToChat(iClient, "%t %t", "Tag", "MenuPlayerDisconnected");
		return false;
	}

	if (!CVB_BanPlayer(iTarget, g_eCVBAdminState[iClient].banType, g_eCVBAdminState[iClient].durationMinutes, iClient, szReason))
	{
		CVBAdminMenu_ResetState(iClient);
		CPrintToChat(iClient, "%t %t", "Tag", "CVBAdminMenuActionFailed");
		return false;
	}

	CPrintToChat(iClient, "%t %t", "Tag", "CVBAdminMenuBanApplied", g_eCVBAdminState[iClient].targetName);
	CVBAdminMenu_ResetState(iClient);
	return true;
}

void CVBAdminMenu_ShowUnbanTargetPanel(int iClient)
{
	Menu hMenu = new Menu(CVBAdminMenu_MenuHandlerUnbanTarget, MENU_ACTIONS_DEFAULT);

	char szTitle[128];
	Format(szTitle, sizeof(szTitle), "%T", "MenuUnbanManagementTitle", iClient);
	hMenu.SetTitle(szTitle);
	hMenu.ExitButton = true;

	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!CVBAdminMenu_IsValidTarget(i) || !CVB_IsPlayerBanned(i))
			continue;

		char szInfo[16];
		IntToString(GetClientUserId(i), szInfo, sizeof(szInfo));

		char szName[MAX_NAME_LENGTH];
		GetClientName(i, szName, sizeof(szName));
		char szBanType[64];
		CVBAdminMenu_GetBanTypeString(CVB_GetPlayerBanType(i), szBanType, sizeof(szBanType));
		Format(szName, sizeof(szName), "%T", "MenuUnbanPlayerFormat", iClient, szName, szBanType);
		hMenu.AddItem(szInfo, szName);
		iCount++;
	}

	if (!iCount)
	{
		char szNoPlayers[64];
		Format(szNoPlayers, sizeof(szNoPlayers), "%T", "MenuNoBannedPlayers", iClient);
		hMenu.AddItem("", szNoPlayers, ITEMDRAW_DISABLED);
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int CVBAdminMenu_MenuHandlerUnbanTarget(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	switch (eAction)
	{
		case MenuAction_Select:
		{
			char szInfo[16];
			hMenu.GetItem(iItem, szInfo, sizeof(szInfo));
			int iTarget = GetClientOfUserId(StringToInt(szInfo));
			if (!CVBAdminMenu_IsValidTarget(iTarget))
			{
				CPrintToChat(iClient, "%t %t", "Tag", "MenuPlayerDisconnected");
				CVBAdminMenu_ShowUnbanTargetPanel(iClient);
				return 0;
			}

			CVBAdminMenu_SetTargetState(iClient, CVBAdminMenuPanel_Unban, iTarget);
			CVBAdminMenu_ShowUnbanConfirmPanel(iClient, iTarget);
		}

		case MenuAction_End:
			delete hMenu;
	}

	return 0;
}

void CVBAdminMenu_ShowUnbanConfirmPanel(int iClient, int iTarget)
{
	Menu hMenu = new Menu(CVBAdminMenu_MenuHandlerUnbanConfirm, MENU_ACTIONS_DEFAULT);

	char szTargetName[MAX_NAME_LENGTH];
	char szSteamId2[MAX_AUTHID_LENGTH];
	GetClientName(iTarget, szTargetName, sizeof(szTargetName));
	GetClientAuthId(iTarget, AuthId_Steam2, szSteamId2, sizeof(szSteamId2));

	char szBanTypes[64];
	CVBAdminMenu_GetBanTypeString(CVB_GetPlayerBanType(iTarget), szBanTypes, sizeof(szBanTypes));

	char szTitle[256];
	Format(szTitle, sizeof(szTitle), "%T", "MenuUnbanConfirmationTitle", iClient, szTargetName, szSteamId2, szBanTypes);
	hMenu.SetTitle(szTitle);
	hMenu.ExitBackButton = true;

	char szConfirmYes[32], szConfirmCancel[32];
	Format(szConfirmYes, sizeof(szConfirmYes), "%T", "MenuUnbanConfirmYes", iClient);
	Format(szConfirmCancel, sizeof(szConfirmCancel), "%T", "MenuBanConfirmCancel", iClient);
	hMenu.AddItem("confirm", szConfirmYes);
	hMenu.AddItem("cancel", szConfirmCancel);

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int CVBAdminMenu_MenuHandlerUnbanConfirm(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	switch (eAction)
	{
		case MenuAction_Select:
		{
			char szInfo[16];
			hMenu.GetItem(iItem, szInfo, sizeof(szInfo));
			if (!StrEqual(szInfo, "confirm"))
				return 0;

			int iTarget = GetClientOfUserId(g_eCVBAdminState[iClient].targetUserId);
			if (!CVBAdminMenu_IsValidTarget(iTarget))
			{
				CPrintToChat(iClient, "%t %t", "Tag", "MenuPlayerDisconnected");
				CVBAdminMenu_ResetState(iClient);
				return 0;
			}

			if (!CVB_UnbanPlayer(iTarget, iClient))
			{
				CPrintToChat(iClient, "%t %t", "Tag", "CVBAdminMenuActionFailed");
				CVBAdminMenu_ResetState(iClient);
				return 0;
			}

			CPrintToChat(iClient, "%t %t", "Tag", "CVBAdminMenuUnbanApplied", g_eCVBAdminState[iClient].targetName);
			CVBAdminMenu_ResetState(iClient);
		}

		case MenuAction_Cancel:
		{
			if (iItem == MenuCancel_ExitBack)
				CVBAdminMenu_ShowUnbanTargetPanel(iClient);
		}

		case MenuAction_End:
			delete hMenu;
	}

	return 0;
}

void CVBAdminMenu_ShowCheckTargetPanel(int iClient)
{
	Menu hMenu = new Menu(CVBAdminMenu_MenuHandlerCheckTarget, MENU_ACTIONS_DEFAULT);

	char szTitle[128];
	Format(szTitle, sizeof(szTitle), "%T", "MenuCheckBanStatusTitle", iClient);
	hMenu.SetTitle(szTitle);
	hMenu.ExitButton = true;

	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!CVBAdminMenu_IsValidTarget(i))
			continue;

		char szInfo[16];
		IntToString(GetClientUserId(i), szInfo, sizeof(szInfo));

		char szName[MAX_NAME_LENGTH];
		GetClientName(i, szName, sizeof(szName));
		if (CVB_IsPlayerBanned(i))
		{
			char szBanType[64];
			CVBAdminMenu_GetBanTypeString(CVB_GetPlayerBanType(i), szBanType, sizeof(szBanType));
			Format(szName, sizeof(szName), "%T", "MenuBannedPlayerFormat", iClient, szName, szBanType);
		}

		hMenu.AddItem(szInfo, szName);
		iCount++;
	}

	if (!iCount)
	{
		char szNoPlayers[64];
		Format(szNoPlayers, sizeof(szNoPlayers), "%T", "MenuNoPlayersConnected", iClient);
		hMenu.AddItem("", szNoPlayers, ITEMDRAW_DISABLED);
	}

	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int CVBAdminMenu_MenuHandlerCheckTarget(Menu hMenu, MenuAction eAction, int iClient, int iItem)
{
	switch (eAction)
	{
		case MenuAction_Select:
		{
			char szInfo[16];
			hMenu.GetItem(iItem, szInfo, sizeof(szInfo));
			int iUserId = StringToInt(szInfo);
			int iTarget = GetClientOfUserId(iUserId);
			if (!CVBAdminMenu_IsValidTarget(iTarget))
			{
				CPrintToChat(iClient, "%t %t", "Tag", "MenuPlayerDisconnected");
				CVBAdminMenu_ShowCheckTargetPanel(iClient);
				return 0;
			}

			FakeClientCommand(iClient, "sm_cvb_check #%d", iUserId);
		}

		case MenuAction_End:
			delete hMenu;
	}

	return 0;
}

void CVBAdminMenu_GetBanTypeString(int iBanType, char[] szBuffer, int iMaxLength)
{
	strcopy(szBuffer, iMaxLength, "");

	if (iBanType & view_as<int>(VOTE_CHANGEDIFFICULTY))
		StrCat(szBuffer, iMaxLength, "Difficulty ");
	if (iBanType & view_as<int>(VOTE_RESTARTGAME))
		StrCat(szBuffer, iMaxLength, "Restart ");
	if (iBanType & view_as<int>(VOTE_KICK))
		StrCat(szBuffer, iMaxLength, "Kick ");
	if (iBanType & view_as<int>(VOTE_CHANGEMISSION))
		StrCat(szBuffer, iMaxLength, "Mission ");
	if (iBanType & view_as<int>(VOTE_RETURNTOLOBBY))
		StrCat(szBuffer, iMaxLength, "Lobby ");
	if (iBanType & view_as<int>(VOTE_CHANGECHAPTER))
		StrCat(szBuffer, iMaxLength, "Chapter ");
	if (iBanType & view_as<int>(VOTE_CHANGEALLTALK))
		StrCat(szBuffer, iMaxLength, "AllTalk ");

	int iLen = strlen(szBuffer);
	if (iLen > 0 && szBuffer[iLen - 1] == ' ')
		szBuffer[iLen - 1] = '\0';

	if (szBuffer[0] == '\0')
		strcopy(szBuffer, iMaxLength, "None");
}
