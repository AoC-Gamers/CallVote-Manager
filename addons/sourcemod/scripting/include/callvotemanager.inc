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
	VoteRestriction_Target
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

public SharedPlugin __pl_callvotemanager = {
	name = "callvotemanager",
	file = "callvotemanager.smx",
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
	MarkNativeAsOptional("CallVoteManager_IsVoteAllowedByConVar");
	MarkNativeAsOptional("CallVoteManager_IsVoteAllowedByGameMode");
}
#endif