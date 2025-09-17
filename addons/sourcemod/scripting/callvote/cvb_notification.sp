#if defined _cvb_notification_included
	#endinput
#endif
#define _cvb_notification_included

/*****************************************************************
			M O D E R N   N O T I F I C A T I O N   S Y S T E M
*****************************************************************/

/**
 * Notification data structure for unified message handling
 * Contains all necessary information for ban notifications
 */
enum struct NotificationData
{
	int target;								// The player receiving the notification
	int admin;								// The admin who applied the ban (0 for console/offline)
	char adminIdentifier[MAX_NAME_LENGTH];	// Admin name or SteamID for display
	char banTypes[256];						// String representation of banned vote types
	char durationText[64];					// Formatted duration text
	int durationMinutes;					// Duration in minutes (0 = permanent)
	bool isOffline;							// Whether this is an offline ban notification
}

/**
 * Notification types for unified entry function
 * Provides flexibility in notification delivery
 */
enum NotificationType
{
	NotifyType_Full = 0,		// Chat + Console (default - complete notification)
	NotifyType_ChatOnly,		// Solo chat (quick notification)
	NotifyType_ConsoleOnly,		// Solo consola (detailed info only)
	NotifyType_Offline			// Para bans offline (chat + console with SteamID)
}

/**
 * Modern unified notification manager using methodmap pattern
 * 
 * This replaces the old scattered notification functions with a centralized,
 * optimized system that provides:
 * - Single validation point
 * - Consistent message formatting
 * - Memory optimization via StringPool
 * - Type-safe notification handling
 * - Easy extensibility for new notification types
 */
methodmap NotificationManager
{
	/**
	 * Sends complete ban notification (chat + console)
	 * This is the most common notification type for active bans
	 *
	 * @param data    NotificationData structure with all required information
	 */
	public static void SendFullNotification(NotificationData data)
	{
		if (!IsValidClient(data.target))
			return;
			
		NotificationManager.SendChatNotification(data.target);
		NotificationManager.SendConsoleNotification(data);
	}
	
	/**
	 * Sends generic ban notification to chat
	 * Lightweight notification for immediate user feedback
	 *
	 * @param target    The banned player
	 */
	public static void SendChatNotification(int target)
	{
		if (!IsValidClient(target))
			return;
			
		CPrintToChat(target, "%t %t", "Tag", "PlayerBanRestrictionApplied");
		CPrintToChat(target, "%t %t", "Tag", "CheckConsoleForDetails");
	}
	
	/**
	 * Sends detailed ban information to player's console
	 * Uses the prepared notification data for complete information
	 *
	 * @param data    NotificationData structure with all required information
	 */
	public static void SendConsoleNotification(NotificationData data)
	{
		if (!IsValidClient(data.target))
			return;
			
		NotificationManager.SendConsoleDetails(data.target, data.adminIdentifier, 
											  data.banTypes, data.durationText, data.durationMinutes);
	}
	
	/**
	 * Internal method for sending formatted console details
	 * Uses StringPool for memory optimization
	 *
	 * @param target            The player to send console message to
	 * @param adminIdentifier   Admin name or SteamID for display
	 * @param banTypes          String representation of banned vote types
	 * @param durationText      Formatted duration text
	 * @param durationMinutes   Duration in minutes (0 = permanent, >0 = temporary)
	 */
	public static void SendConsoleDetails(int target, const char[] adminIdentifier, const char[] banTypes, 
								  const char[] durationText, int durationMinutes)
	{
		if (!IsValidClient(target))
			return;
			
		// Print header
		PrintToConsole(target, "=====================================");
		PrintToConsole(target, "%T", "BanDetailsHeader", target);
		PrintToConsole(target, "=====================================");
		
		// Print core ban information
		PrintToConsole(target, "%T", "BanDetailsTypes", target, banTypes);
		PrintToConsole(target, "%T", "BanDetailsDuration", target, durationText);
		PrintToConsole(target, "%T", "BanDetailsAdmin", target, adminIdentifier);
		
		// Print expiration time for temporary bans using StringPool
		if (durationMinutes > 0)
		{
			int poolIndex = StringPool.GetPoolIndex();
			if (poolIndex != -1)
			{
				int expiresTimestamp = GetTime() + (durationMinutes * 60);
				FormatTime(g_StringPool[poolIndex], STRING_BUFFER_SIZE, "%Y-%m-%d %H:%M:%S", expiresTimestamp);
				PrintToConsole(target, "%T", "BanDetailsExpiration", target, g_StringPool[poolIndex]);
				StringPool.ReturnBufferByIndex(poolIndex);
			}
			else
			{
				// Fallback if pool is exhausted
				char sExpirationTime[64];
				int expiresTimestamp = GetTime() + (durationMinutes * 60);
				FormatTime(sExpirationTime, sizeof(sExpirationTime), "%Y-%m-%d %H:%M:%S", expiresTimestamp);
				PrintToConsole(target, "%T", "BanDetailsExpiration", target, sExpirationTime);
			}
		}
		
		// Print footer
		PrintToConsole(target, "=====================================");
	}
}

/**
 * Helper function to prepare notification data structure
 *
 * @param data              NotificationData structure to populate
 * @param target            The banned player
 * @param admin             The admin who applied the ban (0 for console/offline)
 * @param adminIdentifier   Admin name or SteamID (if provided, overrides admin lookup)
 * @param banTypes          String representation of banned vote types
 * @param durationText      Formatted duration text
 * @param durationMinutes   Duration in minutes (0 = permanent)
 * @param isOffline         Whether this is an offline ban notification
 */
void PrepareNotificationData(NotificationData data, int target, int admin, const char[] adminIdentifier = "",
							const char[] banTypes, const char[] durationText, int durationMinutes, bool isOffline = false)
{
	data.target = target;
	data.admin = admin;
	data.isOffline = isOffline;
	
	// Use provided adminIdentifier or resolve from admin client
	if (strlen(adminIdentifier) > 0)
	{
		strcopy(data.adminIdentifier, sizeof(data.adminIdentifier), adminIdentifier);
	}
	else if (admin == SERVER_INDEX)
	{
		strcopy(data.adminIdentifier, sizeof(data.adminIdentifier), "CONSOLE");
	}
	else if (IsValidClient(admin))
	{
		GetClientName(admin, data.adminIdentifier, sizeof(data.adminIdentifier));
	}
	else
	{
		strcopy(data.adminIdentifier, sizeof(data.adminIdentifier), "Unknown");
	}
	
	strcopy(data.banTypes, sizeof(data.banTypes), banTypes);
	strcopy(data.durationText, sizeof(data.durationText), durationText);
	data.durationMinutes = durationMinutes;
}

/**
 * UNIFIED ENTRY POINT - Modern notification system
 * 
 * This is the primary function for all ban notifications in the system.
 * It replaces all legacy notification functions with a single, optimized interface.
 * 
 * Features:
 * - Single validation point (no repeated IsValidClient checks)
 * - Memory-optimized string operations via StringPool
 * - Type-safe notification handling
 * - Flexible notification types for different scenarios
 * 
 * Examples:
 * // Standard ban notification (most common)
 * SendBanNotification(target, NotifyType_Full, admin, "", banTypes, durationText, durationMinutes);
 * 
 * // Quick chat-only notification
 * SendBanNotification(target, NotifyType_ChatOnly);
 * 
 * // Offline ban with admin SteamID
 * SendBanNotification(target, NotifyType_Offline, 0, adminSteamId, banTypes, durationText, durationMinutes);
 * 
 * // Console-only detailed information
 * SendBanNotification(target, NotifyType_ConsoleOnly, admin, "", banTypes, durationText, durationMinutes);
 *
 * @param target            The banned player
 * @param type              Type of notification to send (default: NotifyType_Full)
 * @param admin             The admin who applied the ban (0 for console/offline)
 * @param adminIdentifier   Admin name or SteamID (optional, overrides admin lookup)
 * @param banTypes          String representation of banned vote types
 * @param durationText      Formatted duration text
 * @param durationMinutes   Duration in minutes (0 = permanent)
 */
void SendBanNotification(int target, NotificationType type = NotifyType_Full, int admin = 0, 
						const char[] adminIdentifier = "", const char[] banTypes = "", 
						const char[] durationText = "", int durationMinutes = 0)
{
	// Single validation point - no repeated checks in nested functions
	if (!IsValidClient(target))
		return;
		
	// Prepare notification data once
	NotificationData data;
	bool isOffline = (type == NotifyType_Offline);
	PrepareNotificationData(data, target, admin, adminIdentifier, banTypes, durationText, durationMinutes, isOffline);
	
	// Send notification based on type
	switch (type)
	{
		case NotifyType_Full, NotifyType_Offline:
		{
			NotificationManager.SendFullNotification(data);
		}
		case NotifyType_ChatOnly:
		{
			NotificationManager.SendChatNotification(target);
		}
		case NotifyType_ConsoleOnly:
		{
			NotificationManager.SendConsoleNotification(data);
		}
	}
}

/**
 * Shows input panel for custom ban reason
 *
 * @param admin           The admin player
 * @param target          The target player to ban
 * @param banType         The type of ban
 * @param durationMinutes The duration in minutes
 */
void ShowBanReasonInputPanel(int admin, int target, int banType, int durationMinutes)
{
	if (!IsValidClient(admin) || !IsValidClient(target))
		return;
		
	char sTargetName[MAX_NAME_LENGTH];
	GetClientName(target, sTargetName, sizeof(sTargetName));
	
	char sPrompt[256];
	Format(sPrompt, sizeof(sPrompt), "%T", "MenuBanReasonInputPrompt", admin, sTargetName);
	
	char sData[64];
	Format(sData, sizeof(sData), "%d:%d:%d", GetClientUserId(target), banType, durationMinutes);
	
	g_PendingReasonInputs[admin] = true;
	strcopy(g_PendingReasonData[admin], sizeof(g_PendingReasonData[]), sData);
	
	CPrintToChat(admin, "%t %t", "Tag", "TypeReasonInChat", sPrompt);
}