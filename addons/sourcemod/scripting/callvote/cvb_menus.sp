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
			if (g_PlayerBans[i].isLoaded && g_PlayerBans[i].banType > 0)
			{
				Format(sName, sizeof(sName), "%T", "MenuBannedPlayerFormat", admin, sName, g_PlayerBans[i].banType);
			}
			
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
			{
				ShowOfflineBanInputPanel(client);
			}
			else if (StrEqual(sInfo, "cleanup"))
			{
				int adminAccountId = GetSteamAccountID(client);
				CVB_CleanExpiredBans(adminAccountId, 100);
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
					{
						ShowBanTypePanel(client, target);
					}
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
		{
			delete hMenu;
		}
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
			
			if (target == 0 || !IsValidClient(target))
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
			{
				ShowCustomBanTypePanel(client, target);
			}
			else
			{
				int banType = StringToInt(sInfo);
				ShowBanDurationPanel(client, target, banType);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				ShowMainBanPanel(client);
			}
		}
		case MenuAction_End:
		{
			delete hMenu;
		}
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
			
			if (target == 0 || !IsValidClient(target))
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
			{
				ShowCustomDurationInputPanel(client, target, banType);
			}
			else
			{
				int durationMinutes = StringToInt(sInfo);
				ShowBanConfirmationPanel(client, target, banType, durationMinutes);
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
				{
					ShowBanTypePanel(client, target);
				}
				else
				{
					ShowMainBanPanel(client);
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

void ShowBanConfirmationPanel(int admin, int target, int banType, int durationMinutes)
{
	Menu hMenu = new Menu(MenuHandler_BanConfirmation, MENU_ACTIONS_DEFAULT);
	
	char sTargetName[MAX_NAME_LENGTH];
	char sTargetSteamId[MAX_AUTHID_LENGTH];
	GetClientName(target, sTargetName, sizeof(sTargetName));
	GetClientAuthId(target, AuthId_Steam2, sTargetSteamId, sizeof(sTargetSteamId));
	
	char sBanTypeStr[64];
	GetBanTypeString(banType, sBanTypeStr, sizeof(sBanTypeStr));
	
	char sDurationStr[32];
	if (durationMinutes == 0)
	{
		Format(sDurationStr, sizeof(sDurationStr), "%T", "MenuBanDurationPermanent", admin);
	}
	else
	{
		Format(sDurationStr, sizeof(sDurationStr), "%T", "MinutesUnit", admin, durationMinutes);
	}
	
	char sTitle[256];
	Format(sTitle, sizeof(sTitle), "%T", "MenuBanConfirmationTitle", admin, sTargetName, sTargetSteamId, sBanTypeStr, sDurationStr);
	
	hMenu.SetTitle(sTitle);
	hMenu.ExitBackButton = true;
	
	char sData[128];
	Format(sData, sizeof(sData), "%d:%d:%d", GetClientUserId(target), banType, durationMinutes);
	SetMenuTitle(hMenu, "%s\nDATA:%s", sTitle, sData);
	
	char sConfirmYes[32], sConfirmCancel[32];
	Format(sConfirmYes, sizeof(sConfirmYes), "%T", "MenuBanConfirmYes", admin);
	Format(sConfirmCancel, sizeof(sConfirmCancel), "%T", "MenuBanConfirmCancel", admin);
	
	hMenu.AddItem("confirm", sConfirmYes);
	hMenu.AddItem("cancel", sConfirmCancel);
	
	hMenu.Display(admin, MENU_TIME_FOREVER);
}

public int MenuHandler_BanConfirmation(Menu hMenu, MenuAction action, int client, int param2)
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
				
				char sData[128];
				if (StrContains(sTitle, "DATA:") != -1)
				{
					int pos = StrContains(sTitle, "DATA:") + 5;
					strcopy(sData, sizeof(sData), sTitle[pos]);
				}
				
				char sParts[3][16];
				if (ExplodeString(sData, ":", sParts, sizeof(sParts), sizeof(sParts[])) == 3)
				{
					int userId = StringToInt(sParts[0]);
					int banType = StringToInt(sParts[1]);
					int durationMinutes = StringToInt(sParts[2]);
					int target = GetClientOfUserId(userId);
					
					if (target > 0 && IsValidClient(target))
					{
						ApplyBanToPlayer(client, target, banType, durationMinutes, "Admin ban via menu");
					}
					else
					{
						char sMessage[64];
						Format(sMessage, sizeof(sMessage), "%T", "MenuPlayerDisconnected", client);
						ReplyToCommand(client, sMessage);
					}
				}
			}
			
			ShowMainBanPanel(client);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				ShowMainBanPanel(client);
			}
		}
		case MenuAction_End:
		{
			delete hMenu;
		}
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
		if (IsValidClient(i) && g_PlayerBans[i].isLoaded && g_PlayerBans[i].banType > 0)
		{
			char sName[MAX_NAME_LENGTH];
			char sInfo[32];
			GetClientName(i, sName, sizeof(sName));
			
			Format(sInfo, sizeof(sInfo), "%d", GetClientUserId(i));
			Format(sName, sizeof(sName), "%T", "MenuUnbanPlayerFormat", admin, sName, g_PlayerBans[i].banType);
			
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
			{
				ShowOfflineUnbanInputPanel(client);
			}
			else if (!StrEqual(sInfo, ""))
			{
				int userId = StringToInt(sInfo);
				int target = GetClientOfUserId(userId);
				
				if (target > 0 && IsValidClient(target))
				{
					ShowUnbanConfirmationPanel(client, target);
				}
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

void ApplyBanToPlayer(int admin, int target, int banType, int durationMinutes, const char[] reason)
{
	int targetAccountId = GetSteamAccountID(target);
	char sTargetSteamId2[MAX_AUTHID_LENGTH];
	char sTargetName[MAX_NAME_LENGTH];
	GetClientAuthId(target, AuthId_Steam2, sTargetSteamId2, sizeof(sTargetSteamId2));
	GetClientName(target, sTargetName, sizeof(sTargetName));
	
	int adminAccountId = (admin == 0) ? 0 : GetSteamAccountID(admin);
	char sAdminSteamId2[MAX_AUTHID_LENGTH];
	if (admin == 0)
	{
		strcopy(sAdminSteamId2, sizeof(sAdminSteamId2), "CONSOLE");
	}
	else
	{
		GetClientAuthId(admin, AuthId_Steam2, sAdminSteamId2, sizeof(sAdminSteamId2));
	}
	
	int reasonCode = GetBanReasonFromString_Enhanced(reason);
	CVB_InsertBan(targetAccountId, banType, durationMinutes, adminAccountId, reasonCode);
	
	g_PlayerBans[target].banType = banType;
	g_PlayerBans[target].durationMinutes = durationMinutes;
	g_PlayerBans[target].expiresTimestamp = (durationMinutes == 0) ? 0 : GetTime() + (durationMinutes * 60);
	
	char sBanTypes[64];
	GetBanTypeString(banType, sBanTypes, sizeof(sBanTypes));
	
	char sDurationText[32];
	if (durationMinutes == 0)
	{
		strcopy(sDurationText, sizeof(sDurationText), "permanente");
	}
	else
	{
		Format(sDurationText, sizeof(sDurationText), "%T", "MinutesUnit", admin, durationMinutes);
	}
	
	ReplyToCommand(admin, "%T", "BanAppliedToPlayer", admin, sTargetName, sBanTypes, sDurationText);
	
	CPrintToChat(target, "%t %t", "Tag", "PlayerBanRestrictionNotice", sDurationText);
}

void ShowUnbanConfirmationPanel(int admin, int target)
{
	Menu hMenu = new Menu(MenuHandler_UnbanConfirmation, MENU_ACTIONS_DEFAULT);
	
	char sTargetName[MAX_NAME_LENGTH];
	char sTargetSteamId[MAX_AUTHID_LENGTH];
	GetClientName(target, sTargetName, sizeof(sTargetName));
	GetClientAuthId(target, AuthId_Steam2, sTargetSteamId, sizeof(sTargetSteamId));
	
	char sBanTypes[64];
	GetBanTypeString(g_PlayerBans[target].banType, sBanTypes, sizeof(sBanTypes));
	
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
				
				if (target > 0 && IsValidClient(target))
				{
					ApplyUnbanToPlayer(client, target);
				}
				else
				{
					char sMessage[64];
					Format(sMessage, sizeof(sMessage), "%T", "MenuPlayerDisconnected", client);
					ReplyToCommand(client, sMessage);
				}
			}
			
			ShowMainUnbanPanel(client);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				ShowMainUnbanPanel(client);
			}
		}
		case MenuAction_End:
		{
			delete hMenu;
		}
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
	
	int adminAccountId = (admin == 0) ? 0 : GetSteamAccountID(admin);
	char sAdminSteamId2[MAX_AUTHID_LENGTH];
	if (admin == 0)
	{
		strcopy(sAdminSteamId2, sizeof(sAdminSteamId2), "CONSOLE");
	}
	else
	{
		GetClientAuthId(admin, AuthId_Steam2, sAdminSteamId2, sizeof(sAdminSteamId2));
	}
	
	CVB_RemoveBan(targetAccountId, adminAccountId);
	
	ReplyToCommand(admin, "%T", "BanRemovedForPlayer", admin, sTargetName);
	CPrintToChat(target, "%t %t", "Tag", "BanRestrictionsRemoved");
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
			
			// Indicar si el jugador está baneado
			if (g_PlayerBans[i].isLoaded && g_PlayerBans[i].banType > 0)
			{
				Format(sName, sizeof(sName), "%T", "MenuBannedPlayerFormat", admin, sName, g_PlayerBans[i].banType);
			}
			
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
			{
				ShowOfflineCheckInputPanel(client);
			}
			else if (!StrEqual(sInfo, ""))
			{
				int userId = StringToInt(sInfo);
				int target = GetClientOfUserId(userId);
				
				if (target > 0 && IsValidClient(target))
				{
					ShowPlayerBanInfo(client, target);
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
		{
			delete hMenu;
		}
	}
	
	return 0;
}

void ShowOfflineCheckInputPanel(int admin)
{
	char sMessage[64];
	Format(sMessage, sizeof(sMessage), "%T", "MenuCheckOfflineUsage", admin);
	ReplyToCommand(admin, sMessage);
}
