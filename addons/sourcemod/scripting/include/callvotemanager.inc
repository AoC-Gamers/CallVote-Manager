/**
 * vim: set ts=4 sw=4 tw=99 noet :
 * =============================================================================
 * SourceMod (C)2004-2014 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This file is part of the SourceMod/SourcePawn SDK.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#if defined _callvotemanager_included
	#endinput
#endif
#define _callvotemanager_included

#include <callvote_stock>

#define CALLVOTEMANAGER_LIBRARY "callvotemanager"
#define CALLVOTEMANAGER_PLUGIN "callvotemanager.smx"

/**
 * Enumeration for vote restriction types
 */
enum VoteRestrictionType
{
	VoteRestriction_None = 0,
	VoteRestriction_ConVar,
	VoteRestriction_GameMode,
	VoteRestriction_SameState,
	VoteRestriction_Immunity,
	VoteRestriction_Team,
	VoteRestriction_Target,
	VoteRestriction_Plugin
}

/**
 * Called when a vote call is about to begin (before validation).
 * 
 * This forward is triggered before any vote validation is performed,
 * allowing other plugins to block votes before they are processed.
 *
 * @param client    Client index who initiated the vote (1-MaxClients)
 * @param voteType  Type of vote being called (see TypeVotes enum)
 * @param target    Target client index for kick votes, 0 for other vote types
 * @return          Plugin_Continue to allow the vote, Plugin_Handled to block it
 *
 * @note This forward is called before vote validation and restrictions are applied
 * @note The target parameter is only valid for Kick votes (voteType == Kick)
 * @note To block a vote, return Plugin_Handled from this forward
 */
forward Action CallVote_PreStart(int client, TypeVotes voteType, int target);

/**
 * Called when a vote call begins.
 * 
 * This forward is triggered after validation passes and the vote has started,
 * allowing other plugins to react to successful vote initiations.
 *
 * @param client    Client index who initiated the vote (1-MaxClients)
 * @param voteType  Type of vote being called (see TypeVotes enum)
 * @param target    Target client index for kick votes, 0 for other vote types
 *
 * @note This forward is informational only and cannot block the vote
 * @note The target parameter is only valid for Kick votes (voteType == Kick)
 * @note The vote has already been validated and started when this is called
 */
forward void CallVote_Start(int client, TypeVotes voteType, int target);

/**
 * Called after a vote is validated but before it's executed by the game.
 * 
 * This forward is triggered after all validation checks pass but before
 * the vote is actually sent to players, allowing final modifications.
 *
 * @param client    Client index who initiated the vote (1-MaxClients)
 * @param voteType  Type of vote being called (see TypeVotes enum)
 * @param target    Target client index for kick votes, 0 for other vote types
 * @return          Plugin_Continue to allow execution, Plugin_Handled to block
 *
 * @note This forward is called after validation but before vote execution
 * @note Use this for last-minute vote modifications or logging
 */
forward Action CallVote_PreExecute(int client, TypeVotes voteType, int target);

/**
 * Called when a vote is blocked due to restrictions.
 * 
 * This forward is triggered whenever a vote attempt is blocked by the
 * validation system, providing detailed information about the restriction.
 *
 * @param client        Client index who attempted the vote (1-MaxClients)
 * @param voteType      Type of vote that was blocked (see TypeVotes enum)
 * @param restriction   Type of restriction that blocked the vote
 * @param target        Target client index for kick votes, 0 for other vote types
 *
 * @note This forward is informational only and cannot change the blocking
 * @note Use this for custom logging, statistics, or user feedback
 */
forward void CallVote_Blocked(int client, TypeVotes voteType, VoteRestrictionType restriction, int target);

/**
 * Called when a vote call is about to begin (extended contract).
 *
 * This forward provides the current session id plus canonical AccountID-based
 * identity data before validation has completed.
 *
 * @param sessionId         Unique session id assigned by the core
 * @param client            Client index who initiated the vote
 * @param callerAccountId   Steam AccountID of the caller
 * @param voteType          Type of vote being called
 * @param target            Target client index for kick votes, 0 for other vote types
 * @param targetAccountId   Steam AccountID of the target, 0 if not applicable
 * @param argument          Raw vote argument captured from callvote
 * @return                  Plugin_Continue to allow the vote, Plugin_Handled to block it
 */
forward Action CallVote_PreStartEx(int sessionId, int client, int callerAccountId, TypeVotes voteType, int target, int targetAccountId, const char[] argument);

/**
 * Called when the engine confirms the vote has started.
 *
 * @param sessionId         Unique session id assigned by the core
 */
forward void CallVote_StartEx(int sessionId);

/**
 * Called after validation passes but before the command is handed back to the engine.
 *
 * @param sessionId         Unique session id assigned by the core
 * @param client            Client index who initiated the vote
 * @param callerAccountId   Steam AccountID of the caller
 * @param voteType          Type of vote being called
 * @param target            Target client index for kick votes, 0 for other vote types
 * @param targetAccountId   Steam AccountID of the target, 0 if not applicable
 * @param argument          Raw vote argument captured from callvote
 * @return                  Plugin_Continue to allow execution, Plugin_Handled to block it
 */
forward Action CallVote_PreExecuteEx(int sessionId, int client, int callerAccountId, TypeVotes voteType, int target, int targetAccountId, const char[] argument);

/**
 * Called when a vote session is blocked.
 *
 * This forward covers both validation blocks and plugin-originated blocks in the
 * extended lifecycle.
 *
 * @param sessionId         Unique session id assigned by the core
 * @param client            Client index who attempted the vote
 * @param callerAccountId   Steam AccountID of the caller
 * @param voteType          Type of vote that was blocked
 * @param restriction       Restriction or block reason
 * @param target            Target client index for kick votes, 0 for other vote types
 * @param targetAccountId   Steam AccountID of the target, 0 if not applicable
 * @param argument          Raw vote argument captured from callvote
 */
forward void CallVote_BlockedEx(int sessionId, int client, int callerAccountId, TypeVotes voteType, VoteRestrictionType restriction, int target, int targetAccountId, const char[] argument);

/**
 * Called when the current vote session ends.
 *
 * @param sessionId         Unique session id assigned by the core
 * @param result            Final outcome of the vote session
 * @param yesCount          Final yes votes seen by the core
 * @param noCount           Final no votes seen by the core
 * @param potentialVotes    Final potential votes seen by the core
 */
forward void CallVote_EndEx(int sessionId, CallVoteEndReason result, int yesCount, int noCount, int potentialVotes);

/**
 * Verifies if a vote type is allowed by ConVar settings.
 * 
 * This native checks if the specified vote type is enabled through
 * server ConVars (both Valve and plugin-specific settings).
 *
 * @param voteType  Type of vote to validate (see TypeVotes enum)
 * @return          True if allowed by ConVars, false otherwise
 * 
 * @note This only checks ConVar permissions, not game mode or other restrictions
 * @note Useful for pre-checking vote availability before attempting
 */
native bool CallVoteManager_IsVoteAllowedByConVar(TypeVotes voteType);

/**
 * Verifies if a vote type is allowed by the current game mode.
 * 
 * This native checks if the specified vote type is permitted in
 * the current L4D2 game mode (Coop, Versus, Survival, Scavenge).
 *
 * @param voteType  Type of vote to validate (see TypeVotes enum)
 * @return          True if allowed by game mode, false otherwise
 * 
 * @note Different game modes have different vote restrictions
 * @note This check is independent of ConVar settings
 */
native bool CallVoteManager_IsVoteAllowedByGameMode(TypeVotes voteType);

/**
 * Returns the Steam AccountID for a connected client.
 *
 * @param client    Client index
 * @return          AccountID for a human client, 0 otherwise
 */
native int CallVoteManager_GetClientAccountID(int client);

/**
 * Formats a connected client's identity as SteamID2.
 *
 * @param client        Client index
 * @param steamId2      Buffer that receives the SteamID2 string
 * @param maxlen        Maximum buffer length
 * @return              True if the conversion succeeded, false otherwise
 */
native bool CallVoteManager_GetClientSteamID2(int client, char[] steamId2, int maxlen);

/**
 * Returns the current active vote session id.
 *
 * @return              Current session id, or 0 if no session is active
 */
native int CallVoteManager_GetCurrentSession();

/**
 * Returns normalized session information for the requested session id.
 *
 * The native can resolve both the currently active session and the last archived
 * session handled by the core.
 *
 * @param sessionId         Session id to query
 * @param callerClient      Receives caller client index
 * @param callerAccountId   Receives caller AccountID
 * @param voteType          Receives vote type
 * @param targetClient      Receives target client index
 * @param targetAccountId   Receives target AccountID
 * @param argument          Receives raw callvote argument
 * @param argMaxLen         Maximum argument buffer length
 * @return                  True if the session exists
 */
native bool CallVoteManager_GetSessionInfo(int sessionId, int &callerClient, int &callerAccountId, TypeVotes &voteType, int &targetClient, int &targetAccountId, char[] argument, int argMaxLen);

/**
 * Returns the SteamID64 values captured by the core when the session started.
 *
 * These values remain available even if the caller or target disconnect before
 * the vote finishes.
 *
 * @param sessionId         Session id to query
 * @param callerSteamID64   Receives caller SteamID64, or an empty string if unavailable
 * @param callerMaxLen      Maximum caller buffer length
 * @param targetSteamID64   Receives target SteamID64, or an empty string if unavailable
 * @param targetMaxLen      Maximum target buffer length
 * @return                  True if the session exists
 */
native bool CallVoteManager_GetSessionSteamID64Info(int sessionId, char[] callerSteamID64, int callerMaxLen, char[] targetSteamID64, int targetMaxLen);

/**
 * Returns raw engine-facing session information collected from vote events.
 *
 * @param sessionId         Session id to query
 * @param issue             Receives raw issue string
 * @param issueMaxLen       Maximum issue buffer length
 * @param param1            Receives raw param1 string
 * @param param1MaxLen      Maximum param1 buffer length
 * @param param2            Receives raw param2 string
 * @param param2MaxLen      Maximum param2 buffer length
 * @param team              Receives vote team value
 * @param initiatorClient   Receives engine initiator client index
 * @return                  True if the session exists
 */
native bool CallVoteManager_GetSessionIssueInfo(int sessionId, char[] issue, int issueMaxLen, char[] param1, int param1MaxLen, char[] param2, int param2MaxLen, int &team, int &initiatorClient);

/**
 * Returns the last tally known by the core for a session.
 *
 * @param sessionId         Session id to query
 * @param yesVotes          Receives yes votes
 * @param noVotes           Receives no votes
 * @param potentialVotes    Receives potential votes
 * @param endReason         Receives final end reason, or current provisional state if not ended
 * @return                  True if the session exists
 */
native bool CallVoteManager_GetSessionTally(int sessionId, int &yesVotes, int &noVotes, int &potentialVotes, CallVoteEndReason &endReason);

public SharedPlugin __pl_callvotemanager = {
	name = CALLVOTEMANAGER_LIBRARY,
	file = CALLVOTEMANAGER_PLUGIN,
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN

public void __pl_callvotemanager_SetNTVOptional()
{
	MarkNativeAsOptional("CallVote_PreStart");
	MarkNativeAsOptional("CallVote_Start");
	MarkNativeAsOptional("CallVote_PreExecute");
	MarkNativeAsOptional("CallVote_Blocked");
	MarkNativeAsOptional("CallVote_PreStartEx");
	MarkNativeAsOptional("CallVote_StartEx");
	MarkNativeAsOptional("CallVote_PreExecuteEx");
	MarkNativeAsOptional("CallVote_BlockedEx");
	MarkNativeAsOptional("CallVote_EndEx");
	MarkNativeAsOptional("CallVoteManager_IsVoteAllowedByConVar");
	MarkNativeAsOptional("CallVoteManager_IsVoteAllowedByGameMode");
	MarkNativeAsOptional("CallVoteManager_GetClientAccountID");
	MarkNativeAsOptional("CallVoteManager_GetClientSteamID2");
	MarkNativeAsOptional("CallVoteManager_GetCurrentSession");
	MarkNativeAsOptional("CallVoteManager_GetSessionInfo");
	MarkNativeAsOptional("CallVoteManager_GetSessionSteamID64Info");
	MarkNativeAsOptional("CallVoteManager_GetSessionIssueInfo");
	MarkNativeAsOptional("CallVoteManager_GetSessionTally");
}
#endif
