#if defined _callvote_bans_included
    #endinput
#endif
#define _callvote_bans_included

#include <callvote_stock>

#define CALLVOTE_BANS_LIBRARY "callvote_bans"
#define CALLVOTE_BANS_PLUGIN "callvote_bans.smx"

/*****************************************************************
                    F O R W A R D S
*****************************************************************/

/**
 * Fired when a vote is blocked by callvote_bans.
 *
 * @param client        Client index that attempted to start the vote
 * @param voteType      Vote type that was blocked
 * @param target        Vote target client index, if any
 * @param banType       Active restriction mask that caused the block.
 *                      This is 0 when the vote was blocked because the
 *                      backend restriction state could not be validated.
 * @noreturn
 */
forward void CVB_OnVoteBlocked(int client, int voteType, int target, int banType);

/**
 * Fired after a ban has been persisted and applied.
 *
 * @param target            Target client index
 * @param banType           Applied ban mask
 * @param durationMinutes   Duration in minutes (0 = permanent)
 * @param admin             Admin client index (0 = console)
 * @param reason            Stored reason text
 * @noreturn
 */
forward void CVB_OnPlayerBanned(int target, int banType, int durationMinutes, int admin, const char[] reason);

/*****************************************************************
                    N A T I V E S
*****************************************************************/

/**
 * Checks whether a connected player currently has any active vote restriction.
 *
 * @param client        Client index
 * @return              true if an active restriction exists.
 *                      This native is fail-closed and may also return true
 *                      when the backend state could not be validated.
 * @error               Invalid client index
 */
native bool CVB_IsPlayerBanned(int client);

/**
 * Returns the active restriction mask for a connected player.
 *
 * @param client        Client index
 * @return              Active restriction mask, or 0 when no active restriction exists
 * @error               Invalid client index
 */
native int CVB_GetPlayerBanType(int client);

/**
 * Queues a ban for a connected player.
 *
 * This native confirms that the request was accepted by the plugin.
 * Persistence may complete synchronously on SQLite or asynchronously on MySQL.
 *
 * @param target            Target client index
 * @param banType           Ban mask to apply
 * @param duration          Duration in minutes (0 = permanent)
 * @param admin             Admin client index (0 = console)
 * @param reason            Reason text
 * @return                  true if the request was accepted/queued
 * @error                   Invalid target client index
 */
native bool CVB_BanPlayer(int target, int banType, int duration, int admin, const char[] reason);

/**
 * Queues removal of the active restriction for a connected player.
 *
 * This native confirms that the request was accepted by the plugin.
 * Persistence may complete synchronously on SQLite or asynchronously on MySQL.
 *
 * @param target            Target client index
 * @param admin             Admin client index (0 = console)
 * @return                  true if the request was accepted/queued
 */
native bool CVB_UnbanPlayer(int target, int admin);

/**
 * Loads information about the active restriction of a connected player.
 *
 * @param client            Client index
 * @param banType           Receives the active restriction mask
 * @param expiration        Receives the expiration timestamp
 * @param createdTime       Receives the creation timestamp
 * @param reason            Receives the stored reason text
 * @param reasonMaxLen      Size of the reason buffer
 * @param adminSteamId      Receives the admin SteamID2 string when available
 * @param adminMaxLen       Size of the admin SteamID2 buffer
 * @return                  true only when an active restriction exists and was loaded
 * @error                   Invalid client index
 */
native bool CVB_GetBanInfo(int client, int &banType, int &expiration, int &createdTime, char[] reason, int reasonMaxLen, char[] adminSteamId, int adminMaxLen);

public SharedPlugin __pl_callvote_bans =
{
    name = CALLVOTE_BANS_LIBRARY,
    file = CALLVOTE_BANS_PLUGIN,
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_callvote_bans_SetNTVOptional()
{
    MarkNativeAsOptional("CVB_IsPlayerBanned");
    MarkNativeAsOptional("CVB_GetPlayerBanType");
    MarkNativeAsOptional("CVB_BanPlayer");
    MarkNativeAsOptional("CVB_UnbanPlayer");
    MarkNativeAsOptional("CVB_GetBanInfo");
}
#endif
