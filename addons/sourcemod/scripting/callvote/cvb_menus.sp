#if defined _cvb_menus_included
	#endinput
#endif
#define _cvb_menus_included

void ShowMainBanPanel(int admin)
{
	if (!IsValidClient(admin))
		return;
	
	Menu hMenu = new Menu(MenuHandler_MainBan, MENU_ACTIONS_DEFAULT);
	
	char sTitle[128];
	Format(sTitle, sizeof(sTitle), "%T", "MenuBanManagementTitle", admin);
	hMenu.SetTitle(sTitle);
	hMenu.ExitButton = true;

	int playerCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			char sName[MAX_NAME_LENGTH];
			char sInfo[32];
			GetClientName(i, sName, sizeof(sName));

			Format(sInfo, sizeof(sInfo), "%d:%d", GetClientUserId(i), GetSteamAccountID(i));
			
			if (IsClientBannedWithInfo(i))
				Format(sName, sizeof(sName), "%T", "MenuBannedPlayerFormat", admin, sName, GetClientBanType(i));
			
			hMenu.AddItem(sInfo, sName);
			playerCount++;
		}
	}
	
	if (playerCount == 0)
	{
		char sNoPlayers[64];
		Format(sNoPlayers, sizeof(sNoPlayers), "%T", "MenuNoPlayersConnected", admin);
		hMenu.AddItem("", sNoPlayers, ITEMDRAW_DISABLED);
	}
	
	hMenu.AddItem("", "", ITEMDRAW_SPACER);
	
	char sOfflineOption[64];
	Format(sOfflineOption, sizeof(sOfflineOption), "%T", "MenuBanOfflineOption", admin);
	hMenu.AddItem("offline", sOfflineOption);
	
	char sCleanupOption[64];
	Format(sCleanupOption, sizeof(sCleanupOption), "%T", "MenuCleanupBansOption", admin);
	hMenu.AddItem("cleanup", sCleanupOption);
	
	hMenu.Display(admin, MENU_TIME_FOREVER);
}

public int MenuHandler_MainBan(Menu hMenu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			hMenu.GetItem(param2, sInfo, sizeof(sInfo));
			
			if (StrEqual(sInfo, "offline"))
				ShowOfflineBanInputPanel(client);
			else if (StrEqual(sInfo, "cleanup"))
			{
				int adminAccountId = GetSteamAccountID(client);
				CVB_CleanExpiredMysqlBans(adminAccountId, 100);
				char sMessage[64];
				Format(sMessage, sizeof(sMessage), "%T", "MenuCleanupExecuted", client);
				ReplyToCommand(client, sMessage);
				ShowMainBanPanel(client);
			}
			else if (!StrEqual(sInfo, ""))
			{
				char sParts[2][16];
				if (ExplodeString(sInfo, ":", sParts, sizeof(sParts), sizeof(sParts[])) == 2)
				{
					int userId = StringToInt(sParts[0]);
					int target = GetClientOfUserId(userId);
					
					if (target > 0 && IsValidClient(target))
						ShowBanTypePanel(client, target);
					else
					{
						char sMessage[64];
						Format(sMessage, sizeof(sMessage), "%T", "MenuPlayerDisconnected", client);
						ReplyToCommand(client, sMessage);
						ShowMainBanPanel(client);
					}
				}
			}
		}
		case MenuAction_End:
			delete hMenu;
	}
	
	return 0;
}

void ShowBanTypePanel(int admin, int target)
{
	Menu hMenu = new Menu(MenuHandler_BanType, MENU_ACTIONS_DEFAULT);
	
	char sTitle[128];
	char sTargetName[MAX_NAME_LENGTH];
	GetClientName(target, sTargetName, sizeof(sTargetName));
	Format(sTitle, sizeof(sTitle), "%T", "MenuBanPlayerTitle", admin, sTargetName);
	hMenu.SetTitle(sTitle);
	
	hMenu.ExitBackButton = true;
	char sTargetInfo[32];
	Format(sTargetInfo, sizeof(sTargetInfo), "%d", GetClientUserId(target));

	char
		sDifficulty[32],
		sRestart[32],
		sKick[32],
		sMission[32],
		sLobby[32],
		sChapter[32],
		sAllTalk[32],
		sAll[32],
		sCustom[64];

	Format(sDifficulty, sizeof(sDifficulty), "%T", "MenuBanTypeDifficulty", admin);
	Format(sRestart, sizeof(sRestart), "%T", "MenuBanTypeRestart", admin);
	Format(sKick, sizeof(sKick), "%T", "MenuBanTypeKick", admin);
	Format(sMission, sizeof(sMission), "%T", "MenuBanTypeMission", admin);
	Format(sLobby, sizeof(sLobby), "%T", "MenuBanTypeLobby", admin);
	Format(sChapter, sizeof(sChapter), "%T", "MenuBanTypeChapter", admin);
	Format(sAllTalk, sizeof(sAllTalk), "%T", "MenuBanTypeAllTalk", admin);
	Format(sAll, sizeof(sAll), "%T", "MenuBanTypeAll", admin);
	Format(sCustom, sizeof(sCustom), "%T", "MenuBanTypeCustom", admin);

	hMenu.AddItem("1", sDifficulty);
	hMenu.AddItem("2", sRestart); 
	hMenu.AddItem("4", sKick);
	hMenu.AddItem("8", sMission);
	hMenu.AddItem("16", sLobby);
	hMenu.AddItem("32", sChapter);
	hMenu.AddItem("64", sAllTalk);
	hMenu.AddItem("127", sAll);
	hMenu.AddItem("custom", sCustom);
	
	SetMenuTitle(hMenu, "%s\nTARGET:%s", sTitle, sTargetInfo);
	
	hMenu.Display(admin, MENU_TIME_FOREVER);
}

public int MenuHandler_BanType(Menu hMenu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sTitle[256];
			hMenu.GetTitle(sTitle, sizeof(sTitle));
			
			char sTargetInfo[32];
			if (StrContains(sTitle, "TARGET:") != -1)
			{
				int pos = StrContains(sTitle, "TARGET:") + 7;
				strcopy(sTargetInfo, sizeof(sTargetInfo), sTitle[pos]);
			}
			
			int userId = StringToInt(sTargetInfo);
			int target = GetClientOfUserId(userId);
			
			if (target == SERVER_INDEX || !IsValidClient(target))
			{
				char sMessage[64];
				Format(sMessage, sizeof(sMessage), "%T", "MenuPlayerDisconnected", client);
				ReplyToCommand(client, sMessage);
				ShowMainBanPanel(client);
				return 0;
			}
			
			char sInfo[16];
			hMenu.GetItem(param2, sInfo, sizeof(sInfo));
			
			if (StrEqual(sInfo, "custom"))
				ShowCustomBanTypePanel(client, target);
			else
			{
				int banType = StringToInt(sInfo);
				ShowBanDurationPanel(client, target, banType);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ShowMainBanPanel(client);
		}
		case MenuAction_End:
			delete hMenu;
	}
	
	return 0;
}

void ShowBanDurationPanel(int admin, int target, int banType)
{
	Menu hMenu = new Menu(MenuHandler_BanDuration, MENU_ACTIONS_DEFAULT);
	
	char sTitle[128];
	char sTargetName[MAX_NAME_LENGTH];
	GetClientName(target, sTargetName, sizeof(sTargetName));
	
	char sBanTypeStr[64];
	GetBanTypeString(banType, sBanTypeStr, sizeof(sBanTypeStr));
	
	Format(sTitle, sizeof(sTitle), "%T", "MenuBanDurationTitle", admin, sTargetName, sBanTypeStr);
	hMenu.SetTitle(sTitle);
	
	hMenu.ExitBackButton = true;

	char sTargetInfo[64];
	Format(sTargetInfo, sizeof(sTargetInfo), "%d:%d", GetClientUserId(target), banType);
	SetMenuTitle(hMenu, "%s\nDATA:%s", sTitle, sTargetInfo);

	char
		sPermanent[32],
		s30Min[32],
		s1Hour[32],
		s3Hours[32],
		s6Hours[32],
		s12Hours[32],
		s1Day[32],
		s3Days[32],
		s1Week[32],
		sCustom[64];

	Format(sPermanent, sizeof(sPermanent), "%T", "MenuBanDurationPermanent", admin);
	Format(s30Min, sizeof(s30Min), "%T", "MenuBanDuration30Min", admin);
	Format(s1Hour, sizeof(s1Hour), "%T", "MenuBanDuration1Hour", admin);
	Format(s3Hours, sizeof(s3Hours), "%T", "MenuBanDuration3Hours", admin);
	Format(s6Hours, sizeof(s6Hours), "%T", "MenuBanDuration6Hours", admin);
	Format(s12Hours, sizeof(s12Hours), "%T", "MenuBanDuration12Hours", admin);
	Format(s1Day, sizeof(s1Day), "%T", "MenuBanDuration1Day", admin);
	Format(s3Days, sizeof(s3Days), "%T", "MenuBanDuration3Days", admin);
	Format(s1Week, sizeof(s1Week), "%T", "MenuBanDuration1Week", admin);
	Format(sCustom, sizeof(sCustom), "%T", "MenuBanDurationCustom", admin);

	hMenu.AddItem("0", sPermanent);
	hMenu.AddItem("30", s30Min);
	hMenu.AddItem("60", s1Hour);
	hMenu.AddItem("180", s3Hours);
	hMenu.AddItem("360", s6Hours);
	hMenu.AddItem("720", s12Hours);
	hMenu.AddItem("1440", s1Day);
	hMenu.AddItem("4320", s3Days);
	hMenu.AddItem("10080", s1Week);
	hMenu.AddItem("custom", sCustom);
	
	hMenu.Display(admin, MENU_TIME_FOREVER);
}

public int MenuHandler_BanDuration(Menu hMenu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sTitle[256];
			hMenu.GetTitle(sTitle, sizeof(sTitle));
			
			char sTargetInfo[64];
			if (StrContains(sTitle, "DATA:") != -1)
			{
				int pos = StrContains(sTitle, "DATA:") + 5;
				strcopy(sTargetInfo, sizeof(sTargetInfo), sTitle[pos]);
			}
			
			char sParts[2][16];
			if (ExplodeString(sTargetInfo, ":", sParts, sizeof(sParts), sizeof(sParts[])) != 2)
			{
				char sMessage[64];
				Format(sMessage, sizeof(sMessage), "%T", "MenuTargetDataError", client);
				ReplyToCommand(client, sMessage);
				return 0;
			}
			
			int userId = StringToInt(sParts[0]);
			int banType = StringToInt(sParts[1]);
			int target = GetClientOfUserId(userId);
			
			if (target == SERVER_INDEX || !IsValidClient(target))
			{
				char sMessage[64];
				Format(sMessage, sizeof(sMessage), "%T", "MenuPlayerDisconnected", client);
				ReplyToCommand(client, sMessage);
				ShowMainBanPanel(client);
				return 0;
			}
			
			char sInfo[16];
			hMenu.GetItem(param2, sInfo, sizeof(sInfo));
			
			if (StrEqual(sInfo, "custom"))
				ShowCustomDurationInputPanel(client, target, banType);
			else
			{
				int durationMinutes = StringToInt(sInfo);
				ShowBanReasonPanel(client, target, banType, durationMinutes);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				char sTitle[256];
				hMenu.GetTitle(sTitle, sizeof(sTitle));
				
				char sTargetInfo[64];
				if (StrContains(sTitle, "DATA:") != -1)
				{
					int pos = StrContains(sTitle, "DATA:") + 5;
					strcopy(sTargetInfo, sizeof(sTargetInfo), sTitle[pos]);
				}
				
				int userId = StringToInt(sTargetInfo);
				int target = GetClientOfUserId(userId);
				
				if (target > 0)
					ShowBanTypePanel(client, target);
				else
					ShowMainBanPanel(client);
			}
		}
		case MenuAction_End:
			delete hMenu;
	}
	
	return 0;
}

void ShowBanReasonPanel(int admin, int target, int banType, int durationMinutes)
{
	Menu hMenu = new Menu(MenuHandler_BanReason, MENU_ACTIONS_DEFAULT);
	
	char sTargetName[MAX_NAME_LENGTH];
	GetClientName(target, sTargetName, sizeof(sTargetName));
	
	char sBanTypeStr[64];
	GetBanTypeString(banType, sBanTypeStr, sizeof(sBanTypeStr));
	
	char sDurationStr[32];
	if (durationMinutes == 0)
		Format(sDurationStr, sizeof(sDurationStr), "%T", "MenuBanDurationPermanent", admin);
	else
		Format(sDurationStr, sizeof(sDurationStr), "%T", "MinutesUnit", admin, durationMinutes);
	
	char sTitle[256];
	Format(sTitle, sizeof(sTitle), "%T", "MenuBanReasonTitle", admin, sTargetName, sBanTypeStr, sDurationStr);
	hMenu.SetTitle(sTitle);
	
	hMenu.ExitBackButton = true;
	
	char sTargetInfo[128];
	Format(sTargetInfo, sizeof(sTargetInfo), "%d:%d:%d", GetClientUserId(target), banType, durationMinutes);
	SetMenuTitle(hMenu, "%s\nDATA:%s", sTitle, sTargetInfo);
	
	char sAdminDecision[64], sToxicBehavior[64], sVoteSpam[64], sSystemAbuse[64];
	char sDisruptive[64], sInappropriate[64], sCustomReason[64];
	
	Format(sAdminDecision, sizeof(sAdminDecision), "%T", "MenuReasonAdminDecision", admin);
	Format(sToxicBehavior, sizeof(sToxicBehavior), "%T", "MenuReasonToxicBehavior", admin);
	Format(sVoteSpam, sizeof(sVoteSpam), "%T", "MenuReasonVoteSpam", admin);
	Format(sSystemAbuse, sizeof(sSystemAbuse), "%T", "MenuReasonSystemAbuse", admin);
	Format(sDisruptive, sizeof(sDisruptive), "%T", "MenuReasonDisruptive", admin);
	Format(sInappropriate, sizeof(sInappropriate), "%T", "MenuReasonInappropriate", admin);
	Format(sCustomReason, sizeof(sCustomReason), "%T", "MenuBanWithCustomReason", admin);
	
	hMenu.AddItem("admin decision", sAdminDecision);
	hMenu.AddItem("toxic behavior", sToxicBehavior);
	hMenu.AddItem("vote spam", sVoteSpam);
	hMenu.AddItem("system abuse", sSystemAbuse);
	hMenu.AddItem("disruptive", sDisruptive);
	hMenu.AddItem("inappropriate", sInappropriate);
	hMenu.AddItem("", "", ITEMDRAW_SPACER);
	hMenu.AddItem("custom", sCustomReason);
	
	hMenu.Display(admin, MENU_TIME_FOREVER);
}

public int MenuHandler_BanReason(Menu hMenu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sTitle[512];
			hMenu.GetTitle(sTitle, sizeof(sTitle));
			
			char sTargetInfo[128];
			if (StrContains(sTitle, "DATA:") != -1)
			{
				int pos = StrContains(sTitle, "DATA:") + 5;
				strcopy(sTargetInfo, sizeof(sTargetInfo), sTitle[pos]);
			}
			
			char sParts[3][16];
			if (ExplodeString(sTargetInfo, ":", sParts, sizeof(sParts), sizeof(sParts[])) != 3)
			{
				char sMessage[64];
				Format(sMessage, sizeof(sMessage), "%T", "MenuTargetDataError", client);
				ReplyToCommand(client, sMessage);
				return 0;
			}
			
			int userId = StringToInt(sParts[0]);
			int banType = StringToInt(sParts[1]);
			int durationMinutes = StringToInt(sParts[2]);
			int target = GetClientOfUserId(userId);
			
			if (target == SERVER_INDEX || !IsValidClient(target))
			{
				char sMessage[64];
				Format(sMessage, sizeof(sMessage), "%T", "MenuPlayerDisconnected", client);
				ReplyToCommand(client, sMessage);
				ShowMainBanPanel(client);
				return 0;
			}
			
			char sInfo[64];
			hMenu.GetItem(param2, sInfo, sizeof(sInfo));
			
			if (StrEqual(sInfo, "custom"))
			{
				ShowBanReasonInputPanel(client, target, banType, durationMinutes);
				return 0;
			}
			else if (!StrEqual(sInfo, ""))
				ShowBanConfirmationPanelWithReason(client, target, banType, durationMinutes, sInfo);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				char sTitle[512];
				hMenu.GetTitle(sTitle, sizeof(sTitle));
				
				char sTargetInfo[128];
				if (StrContains(sTitle, "DATA:") != -1)
				{
					int pos = StrContains(sTitle, "DATA:") + 5;
					strcopy(sTargetInfo, sizeof(sTargetInfo), sTitle[pos]);
				}
				
				char sParts[3][16];
				if (ExplodeString(sTargetInfo, ":", sParts, sizeof(sParts), sizeof(sParts[])) == 3)
				{
					int userId = StringToInt(sParts[0]);
					int banType = StringToInt(sParts[1]);
					int target = GetClientOfUserId(userId);
					
					if (target > 0)
						ShowBanDurationPanel(client, target, banType);
					else
						ShowMainBanPanel(client);
				}
			}
		}
		case MenuAction_End:
			delete hMenu;
	}
	
	return 0;
}

void ShowBanConfirmationPanelWithReason(int admin, int target, int banType, int durationMinutes, const char[] reason)
{
	Menu hMenu = new Menu(MenuHandler_BanConfirmationWithReason, MENU_ACTIONS_DEFAULT);
	
	char sTargetName[MAX_NAME_LENGTH];
	char sTargetSteamId[MAX_AUTHID_LENGTH];
	GetClientName(target, sTargetName, sizeof(sTargetName));
	GetClientAuthId(target, AuthId_Steam2, sTargetSteamId, sizeof(sTargetSteamId));
	
	char sBanTypeStr[64];
	GetBanTypeString(banType, sBanTypeStr, sizeof(sBanTypeStr));
	
	char sDurationStr[32];
	if (durationMinutes == 0)
		Format(sDurationStr, sizeof(sDurationStr), "%T", "MenuBanDurationPermanent", admin);
	else
		Format(sDurationStr, sizeof(sDurationStr), "%T", "MinutesUnit", admin, durationMinutes);
	
	char sReasonDisplay[64];
	GetReasonDisplayName(reason, sReasonDisplay, sizeof(sReasonDisplay), admin);
	
	char sTitle[512];
	Format(sTitle, sizeof(sTitle), "%T", "MenuBanConfirmationWithReasonTitle", admin, sTargetName, sTargetSteamId, sBanTypeStr, sDurationStr, sReasonDisplay);
	
	hMenu.SetTitle(sTitle);
	hMenu.ExitBackButton = true;
	
	char sData[256];
	Format(sData, sizeof(sData), "%d:%d:%d:%s", GetClientUserId(target), banType, durationMinutes, reason);
	SetMenuTitle(hMenu, "%s\nDATA:%s", sTitle, sData);
	
	char sConfirmYes[32], sConfirmCancel[32];
	Format(sConfirmYes, sizeof(sConfirmYes), "%T", "MenuBanConfirmYes", admin);
	Format(sConfirmCancel, sizeof(sConfirmCancel), "%T", "MenuBanConfirmCancel", admin);
	
	hMenu.AddItem("confirm", sConfirmYes);
	hMenu.AddItem("cancel", sConfirmCancel);
	
	hMenu.Display(admin, MENU_TIME_FOREVER);
}

/**
 * Gets display name for a ban reason
 */
void GetReasonDisplayName(const char[] reason, char[] output, int maxlen, int client)
{
	if (StrEqual(reason, "admin decision"))
		Format(output, maxlen, "%T", "MenuReasonAdminDecision", client);
	else if (StrContains(reason, "toxic") != -1)
		Format(output, maxlen, "%T", "MenuReasonToxicBehavior", client);
	else if (StrContains(reason, "spam") != -1)
		Format(output, maxlen, "%T", "MenuReasonVoteSpam", client);
	else if (StrContains(reason, "abuse") != -1)
		Format(output, maxlen, "%T", "MenuReasonSystemAbuse", client);
	else if (StrContains(reason, "disruptive") != -1)
		Format(output, maxlen, "%T", "MenuReasonDisruptive", client);
	else if (StrContains(reason, "inappropriate") != -1)
		Format(output, maxlen, "%T", "MenuReasonInappropriate", client);
	else
		strcopy(output, maxlen, reason);
}

public int MenuHandler_BanConfirmationWithReason(Menu hMenu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[16];
			hMenu.GetItem(param2, sInfo, sizeof(sInfo));
			
			if (StrEqual(sInfo, "confirm"))
			{
				char sTitle[512];
				hMenu.GetTitle(sTitle, sizeof(sTitle));
				
				char sData[256];
				if (StrContains(sTitle, "DATA:") != -1)
				{
					int pos = StrContains(sTitle, "DATA:") + 5;
					strcopy(sData, sizeof(sData), sTitle[pos]);
				}
				
				char sParts[4][64];
				if (ExplodeString(sData, ":", sParts, sizeof(sParts), sizeof(sParts[])) >= 4)
				{
					int userId = StringToInt(sParts[0]);
					int banType = StringToInt(sParts[1]);
					int durationMinutes = StringToInt(sParts[2]);
					char reason[256];
					strcopy(reason, sizeof(reason), sParts[3]);
					
					for (int i = 4; i < sizeof(sParts); i++)
					{
						if (strlen(sParts[i]) > 0)
						{
							StrCat(reason, sizeof(reason), ":");
							StrCat(reason, sizeof(reason), sParts[i]);
						}
					}
					
					int target = GetClientOfUserId(userId);
					
					if (target > 0 && IsValidClient(target))
					{
						char processedReason[256];
						CVB_GetBanReason(reason, processedReason, sizeof(processedReason));
						ProcessBan(client, target, banType, durationMinutes, processedReason);
					}
					else
					{
						char sMessage[64];
						Format(sMessage, sizeof(sMessage), "%T", "MenuPlayerDisconnected", client);
						ReplyToCommand(client, sMessage);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				char sTitle[512];
				hMenu.GetTitle(sTitle, sizeof(sTitle));
				
				char sData[256];
				if (StrContains(sTitle, "DATA:") != -1)
				{
					int pos = StrContains(sTitle, "DATA:") + 5;
					strcopy(sData, sizeof(sData), sTitle[pos]);
				}
				
				char sParts[4][64];
				if (ExplodeString(sData, ":", sParts, sizeof(sParts), sizeof(sParts[])) >= 3)
				{
					int userId = StringToInt(sParts[0]);
					int banType = StringToInt(sParts[1]);
					int durationMinutes = StringToInt(sParts[2]);
					int target = GetClientOfUserId(userId);
					
					if (target > SERVER_INDEX)
						ShowBanReasonPanel(client, target, banType, durationMinutes);
					else
						ShowMainBanPanel(client);
				}
			}
		}
		case MenuAction_End:
			delete hMenu;
	}
	
	return 0;
}

void ShowMainUnbanPanel(int admin)
{
	Menu hMenu = new Menu(MenuHandler_MainUnban, MENU_ACTIONS_DEFAULT);
	
	char sTitle[128];
	Format(sTitle, sizeof(sTitle), "%T", "MenuUnbanManagementTitle", admin);
	hMenu.SetTitle(sTitle);
	hMenu.ExitButton = true;
	
	int bannedCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsClientBannedWithInfo(i))
		{
			char sName[MAX_NAME_LENGTH];
			char sInfo[32];
			GetClientName(i, sName, sizeof(sName));
			
			int playerBanType = GetClientBanType(i);
			int accountId = GetSteamAccountID(i);
			CVBLog.Debug("ShowMainUnbanPanel: Player %N (AccountID: %d) -> banType from GetClientBanType: %d", i, accountId, playerBanType);
			
			Format(sInfo, sizeof(sInfo), "%d", GetClientUserId(i));
			Format(sName, sizeof(sName), "%T", "MenuUnbanPlayerFormat", admin, sName, playerBanType);
			
			hMenu.AddItem(sInfo, sName);
			bannedCount++;
		}
	}
	
	if (bannedCount == 0)
	{
		char sNoBanned[64];
		Format(sNoBanned, sizeof(sNoBanned), "%T", "MenuNoBannedPlayers", admin);
		hMenu.AddItem("", sNoBanned, ITEMDRAW_DISABLED);
	}
	
	hMenu.AddItem("", "", ITEMDRAW_SPACER);
	
	char sOfflineOption[64];
	Format(sOfflineOption, sizeof(sOfflineOption), "%T", "MenuUnbanOfflineOption", admin);
	hMenu.AddItem("offline", sOfflineOption);
	
	hMenu.Display(admin, MENU_TIME_FOREVER);
}

public int MenuHandler_MainUnban(Menu hMenu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			hMenu.GetItem(param2, sInfo, sizeof(sInfo));
			
			if (StrEqual(sInfo, "offline"))
				ShowOfflineUnbanInputPanel(client);
			else if (!StrEqual(sInfo, ""))
			{
				int userId = StringToInt(sInfo);
				int target = GetClientOfUserId(userId);
				
				if (target > SERVER_INDEX && IsValidClient(target))
					ShowUnbanConfirmationPanel(client, target);
				else
				{
					char sMessage[64];
					Format(sMessage, sizeof(sMessage), "%T", "MenuPlayerDisconnected", client);
					ReplyToCommand(client, sMessage);
					ShowMainUnbanPanel(client);
				}
			}
		}
		case MenuAction_End:
		{
			delete hMenu;
		}
	}
	
	return 0;
}

/**
 * Processes a ban action for a target player, applying the ban and notifying relevant parties.
 *
 * @param admin            The client index of the admin issuing the ban, or 0 for console.
 * @param target           The client index of the player to be banned.
 * @param banType          The type of ban to apply (e.g., temporary, permanent).
 * @param durationMinutes  The duration of the ban in minutes (0 for permanent).
 * @param reason           The reason for the ban as a string.
 *
 * Retrieves Steam IDs and names for both admin and target, determines ban reason code,
 * inserts the ban into the MySQL database, sets client ban info, and sends notifications
 * to both admin and target player.
 */
void ProcessBan(int admin, int target, int banType, int durationMinutes, const char[] reason)
{
	char  sTargetName[MAX_NAME_LENGTH];
	int targetAccountId = GetSteamAccountID(target);
	GetClientName(target, sTargetName, sizeof(sTargetName));

	int adminAccountId = (admin == SERVER_INDEX) ? SERVER_INDEX : GetSteamAccountID(admin);

	// Use the already processed reason directly (no need to process again)
	CVB_InsertMysqlBan(targetAccountId, banType, durationMinutes, adminAccountId, reason);
	
	// Fire the OnPlayerBanned event for consistency with API
	FireOnPlayerBanned(target, banType, durationMinutes, admin, reason);
	
	int expiresTimestamp = (durationMinutes == 0) ? 0 : GetTime() + (durationMinutes * 60);
	SetClientBanInfo(target, banType, durationMinutes, expiresTimestamp);
	
	char sBanTypes[64];
	GetBanTypeString(banType, sBanTypes, sizeof(sBanTypes));
	
	char sDurationText[32];
	if (durationMinutes == 0)
		strcopy(sDurationText, sizeof(sDurationText), "permanente");
	else
		Format(sDurationText, sizeof(sDurationText), "%T", "MinutesUnit", admin, durationMinutes);
	
	CReplyToCommand(admin, "%t %T", "Tag", "BanAppliedToPlayer", admin, sTargetName, sBanTypes, sDurationText);
	
	if (IsValidClient(target))
		SendBanNotification(target, NotifyType_Full, admin, "", sBanTypes, sDurationText, durationMinutes);
}

void ShowUnbanConfirmationPanel(int admin, int target)
{
	Menu hMenu = new Menu(MenuHandler_UnbanConfirmation, MENU_ACTIONS_DEFAULT);
	
	char sTargetName[MAX_NAME_LENGTH];
	char sTargetSteamId[MAX_AUTHID_LENGTH];
	GetClientName(target, sTargetName, sizeof(sTargetName));
	GetClientAuthId(target, AuthId_Steam2, sTargetSteamId, sizeof(sTargetSteamId));
	
	char sBanTypes[64];
	GetBanTypeString(GetClientBanType(target), sBanTypes, sizeof(sBanTypes));
	
	char sTitle[256];
	Format(sTitle, sizeof(sTitle), "%T", "MenuUnbanConfirmationTitle", admin, sTargetName, sTargetSteamId, sBanTypes);
	
	hMenu.SetTitle(sTitle);
	hMenu.ExitBackButton = true;
	
	char sTargetInfo[32];
	Format(sTargetInfo, sizeof(sTargetInfo), "%d", GetClientUserId(target));
	SetMenuTitle(hMenu, "%s\nTARGET:%s", sTitle, sTargetInfo);
	
	char sConfirmYes[32], sConfirmCancel[32];
	Format(sConfirmYes, sizeof(sConfirmYes), "%T", "MenuUnbanConfirmYes", admin);
	Format(sConfirmCancel, sizeof(sConfirmCancel), "%T", "MenuBanConfirmCancel", admin);
	
	hMenu.AddItem("confirm", sConfirmYes);
	hMenu.AddItem("cancel", sConfirmCancel);
	
	hMenu.Display(admin, MENU_TIME_FOREVER);
}

public int MenuHandler_UnbanConfirmation(Menu hMenu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[16];
			hMenu.GetItem(param2, sInfo, sizeof(sInfo));
			
			if (StrEqual(sInfo, "confirm"))
			{
				char sTitle[256];
				hMenu.GetTitle(sTitle, sizeof(sTitle));
				
				char sTargetInfo[32];
				if (StrContains(sTitle, "TARGET:") != -1)
				{
					int pos = StrContains(sTitle, "TARGET:") + 7;
					strcopy(sTargetInfo, sizeof(sTargetInfo), sTitle[pos]);
				}
				
				int userId = StringToInt(sTargetInfo);
				int target = GetClientOfUserId(userId);

				if (target > SERVER_INDEX && IsValidClient(target))
					ApplyUnbanToPlayer(client, target);
				else
				{
					char sMessage[64];
					Format(sMessage, sizeof(sMessage), "%T", "MenuPlayerDisconnected", client);
					ReplyToCommand(client, sMessage);
				}
			}
			
			// Menu closes automatically after unban is processed
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ShowMainUnbanPanel(client);
		}
		case MenuAction_End:
			delete hMenu;
	}
	
	return 0;
}
void ApplyUnbanToPlayer(int admin, int target)
{
	int targetAccountId = GetSteamAccountID(target);
	char sTargetSteamId2[MAX_AUTHID_LENGTH];
	char sTargetName[MAX_NAME_LENGTH];
	GetClientAuthId(target, AuthId_Steam2, sTargetSteamId2, sizeof(sTargetSteamId2));
	GetClientName(target, sTargetName, sizeof(sTargetName));
	
	int adminAccountId = (admin == SERVER_INDEX) ? SERVER_INDEX : GetSteamAccountID(admin);
	char sAdminSteamId2[MAX_AUTHID_LENGTH];
	
	if (admin == SERVER_INDEX)
		strcopy(sAdminSteamId2, sizeof(sAdminSteamId2), "CONSOLE");
	else
		GetClientAuthId(admin, AuthId_Steam2, sAdminSteamId2, sizeof(sAdminSteamId2));
	
	CVB_RemoveMysqlBan(targetAccountId, adminAccountId);
	
	SetClientBanInfo(target, 0, 0, 0);
	CVBLog.Debug("Cache updated for AccountID %d after unban (banType set to 0)", targetAccountId);
}

void ShowOfflineBanInputPanel(int admin)
{
	ReplyToCommand(admin, "%T", "OfflineBanUsage", admin);
	ReplyToCommand(admin, "%T", "BanTypes", admin);
}

void ShowOfflineUnbanInputPanel(int admin)
{
	char sMessage[64];
	Format(sMessage, sizeof(sMessage), "%T", "MenuUnbanOfflineUsage", admin);
	ReplyToCommand(admin, sMessage);
}

void ShowCustomBanTypePanel(int admin, int target)
{
	char sMessage[64];
	Format(sMessage, sizeof(sMessage), "%T", "MenuCustomBanTypeNotImplemented", admin);
	ReplyToCommand(admin, sMessage);
	ShowBanTypePanel(admin, target);
}

void ShowCustomDurationInputPanel(int admin, int target, int banType)
{
	char sMessage[64];
	Format(sMessage, sizeof(sMessage), "%T", "MenuCustomDurationNotImplemented", admin);
	ReplyToCommand(admin, sMessage);
	ShowBanDurationPanel(admin, target, banType);
}

void ShowMainCheckPanel(int admin)
{
	if (!IsValidClient(admin))
		return;
	
	Menu hMenu = new Menu(MenuHandler_MainCheck, MENU_ACTIONS_DEFAULT);
	
	char sTitle[128];
	Format(sTitle, sizeof(sTitle), "%T", "MenuCheckBanStatusTitle", admin);
	hMenu.SetTitle(sTitle);
	hMenu.ExitButton = true;

	int playerCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			char sName[MAX_NAME_LENGTH];
			char sInfo[32];
			GetClientName(i, sName, sizeof(sName));

			Format(sInfo, sizeof(sInfo), "%d", GetClientUserId(i));
			
			if (IsClientBannedWithInfo(i))
				Format(sName, sizeof(sName), "%T", "MenuBannedPlayerFormat", admin, sName, GetClientBanType(i));
			
			hMenu.AddItem(sInfo, sName);
			playerCount++;
		}
	}
	
	if (playerCount == 0)
	{
		char sNoPlayers[64];
		Format(sNoPlayers, sizeof(sNoPlayers), "%T", "MenuNoPlayersConnected", admin);
		hMenu.AddItem("", sNoPlayers, ITEMDRAW_DISABLED);
	}
	
	hMenu.AddItem("", "", ITEMDRAW_SPACER);
	
	char sOfflineOption[64];
	Format(sOfflineOption, sizeof(sOfflineOption), "%T", "MenuCheckOfflineOption", admin);
	hMenu.AddItem("offline", sOfflineOption);
	
	hMenu.Display(admin, MENU_TIME_FOREVER);
}

public int MenuHandler_MainCheck(Menu hMenu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[32];
			hMenu.GetItem(param2, sInfo, sizeof(sInfo));
			
			if (StrEqual(sInfo, "offline"))
				ShowOfflineCheckInputPanel(client);
			else if (!StrEqual(sInfo, ""))
			{
				int userId = StringToInt(sInfo);
				int target = GetClientOfUserId(userId);
				
				if (target > SERVER_INDEX && IsValidClient(target))
				{
					PlayerBanInfo playerInfo = new PlayerBanInfo(GetSteamAccountID(target));

					CVB_GetCacheStringMap(playerInfo);
					playerInfo.AdminAccountId = GetSteamAccountID(client);
					playerInfo.DbSource = SourceDB_MySQL;
					playerInfo.CommandReplySource = SM_REPLY_TO_CHAT;
					CVB_UpdateCacheStringMap(playerInfo);

					CReplyToCommand(client, "%t %t", "Tag", "BanStatusCheckingPlayer", target);
					CVB_CheckMysqlFullBan(playerInfo);
					delete playerInfo;
				}
				else
				{
					char sMessage[64];
					Format(sMessage, sizeof(sMessage), "%T", "MenuPlayerDisconnected", client);
					ReplyToCommand(client, sMessage);
					ShowMainCheckPanel(client);
				}
			}
		}
		case MenuAction_End:
			delete hMenu;
	}
	
	return 0;
}

void ShowOfflineCheckInputPanel(int admin)
{
	char sMessage[64];
	Format(sMessage, sizeof(sMessage), "%T", "MenuCheckOfflineUsage", admin);
	ReplyToCommand(admin, sMessage);
}

void ShowVoteBlockedMessage(int client, TypeVotes voteType)
{
	if (!IsValidClient(client))
		return;
		
	char sVoteTypeName[64];
	GetVoteTypeName(voteType, sVoteTypeName, sizeof(sVoteTypeName));

	char consoleMessage[32];
	Format(consoleMessage, sizeof(consoleMessage), "%T", "CheckConsoleForDetails", client);
	
	switch (voteType)
	{
		case ChangeDifficulty:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedDifficulty", g_ClientStates[client].isLoaded ? consoleMessage : "");
		case RestartGame:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedRestart", g_ClientStates[client].isLoaded ? consoleMessage : "");
		case Kick:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedKick", g_ClientStates[client].isLoaded ? consoleMessage : "");
		case ChangeMission:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedMission", g_ClientStates[client].isLoaded ? consoleMessage : "");
		case ReturnToLobby:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedLobby", g_ClientStates[client].isLoaded ? consoleMessage : "");
		case ChangeChapter:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedChapter", g_ClientStates[client].isLoaded ? consoleMessage : "");
		case ChangeAllTalk:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedAllTalk", g_ClientStates[client].isLoaded ? consoleMessage : "");
		default:
			CPrintToChat(client, "%t %t", "Tag", "VoteBlockedGeneric", sVoteTypeName, g_ClientStates[client].isLoaded ? consoleMessage : "");
	}
	
	if (g_ClientStates[client].isLoaded)
		ShowVoteBlockedDetailsInConsole(client);
}

void ShowVoteBlockedDetailsInConsole(int client)
{
	if (!g_ClientStates[client].isLoaded)
		return;
		
	int banType = GetClientBanType(client);
	int expiresTimestamp = GetClientBanExpiration(client);
	int createdTimestamp = GetClientBanCreationTime(client);
	
	PrintToConsole(client, "========================================");
	PrintToConsole(client, "%T", "ConsoleVoteBlockedTitle", client);
	PrintToConsole(client, "========================================");
	
	PrintToConsole(client, "%T", "ConsoleVoteBlockedExplanation", client);
	PrintToConsole(client, "");
	
	char restrictedVotes[256];
	GetRestrictedVoteTypes(banType, restrictedVotes, sizeof(restrictedVotes), client);
	PrintToConsole(client, "%T", "ConsoleBanRestrictedVotes", client, restrictedVotes);
	
	if (expiresTimestamp == 0)
		PrintToConsole(client, "%T", "ConsoleBanDuration", client, "Permanent");
	else
	{
		int timeLeft = expiresTimestamp - GetTime();

		if (timeLeft <= 0)
			PrintToConsole(client, "%T", "ConsoleBanExpired", client);
		else
		{
			char sTimeLeft[64];
			FormatDuration(timeLeft, sTimeLeft, sizeof(sTimeLeft));
			PrintToConsole(client, "%T", "ConsoleBanTimeLeft", client, sTimeLeft);
		}
	}
	
	char dateCreated[64];
	FormatTime(dateCreated, sizeof(dateCreated), "%Y-%m-%d %H:%M:%S", createdTimestamp);
	PrintToConsole(client, "%T", "ConsoleBanCreated", client, dateCreated);
	
	PrintToConsole(client, "========================================");
}

void GetRestrictedVoteTypes(int banType, char[] output, int maxlen, int client)
{
	char temp[512];
	temp[0] = '\0';
	
	if (banType & (1 << 0)) // ChangeDifficulty
	{
		if (temp[0] != '\0') StrCat(temp, sizeof(temp), ", ");
		char voteTypeName[32];
		Format(voteTypeName, sizeof(voteTypeName), "%T", "VoteTypeDifficulty", client);
		StrCat(temp, sizeof(temp), voteTypeName);
	}
	if (banType & (1 << 1)) // RestartGame
	{
		if (temp[0] != '\0') StrCat(temp, sizeof(temp), ", ");
		char voteTypeName[32];
		Format(voteTypeName, sizeof(voteTypeName), "%T", "VoteTypeRestart", client);
		StrCat(temp, sizeof(temp), voteTypeName);
	}
	if (banType & (1 << 2)) // Kick
	{
		if (temp[0] != '\0') StrCat(temp, sizeof(temp), ", ");
		char voteTypeName[32];
		Format(voteTypeName, sizeof(voteTypeName), "%T", "VoteTypeKick", client);
		StrCat(temp, sizeof(temp), voteTypeName);
	}
	if (banType & (1 << 3)) // ChangeMission
	{
		if (temp[0] != '\0') StrCat(temp, sizeof(temp), ", ");
		char voteTypeName[32];
		Format(voteTypeName, sizeof(voteTypeName), "%T", "VoteTypeMission", client);
		StrCat(temp, sizeof(temp), voteTypeName);
	}
	if (banType & (1 << 4)) // ReturnToLobby
	{
		if (temp[0] != '\0') StrCat(temp, sizeof(temp), ", ");
		char voteTypeName[32];
		Format(voteTypeName, sizeof(voteTypeName), "%T", "VoteTypeLobby", client);
		StrCat(temp, sizeof(temp), voteTypeName);
	}
	if (banType & (1 << 5)) // ChangeChapter
	{
		if (temp[0] != '\0') StrCat(temp, sizeof(temp), ", ");
		char voteTypeName[32];
		Format(voteTypeName, sizeof(voteTypeName), "%T", "VoteTypeChapter", client);
		StrCat(temp, sizeof(temp), voteTypeName);
	}
	if (banType & (1 << 6)) // ChangeAllTalk
	{
		if (temp[0] != '\0') StrCat(temp, sizeof(temp), ", ");
		char voteTypeName[32];
		Format(voteTypeName, sizeof(voteTypeName), "%T", "VoteTypeAllTalk", client);
		StrCat(temp, sizeof(temp), voteTypeName);
	}
	
	strcopy(output, maxlen, temp);
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

