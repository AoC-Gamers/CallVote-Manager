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

#if defined _callvote_core_included
	#endinput
#endif
#define _callvote_core_included

#include <callvote_stock>

#define CALLVOTECORE_LIBRARY "callvote_core"
#define CALLVOTECORE_PLUGIN "callvote_core.smx"

/**
 * Enumeration for vote restriction types
 */
enum VoteRestrictionType
{
	VoteRestriction_None = 0,
	VoteRestriction_InvalidCaller,
	VoteRestriction_ClientState,
	VoteRestriction_Cooldown,
	VoteRestriction_ConVar,
	VoteRestriction_GameMode,
	VoteRestriction_SameState,
	VoteRestriction_Immunity,
	VoteRestriction_Team,
	VoteRestriction_Target,
	VoteRestriction_Plugin
}

/**
 * Pre-hook fired when a vote call is about to begin.
 *
 * The core creates a normalized session first, then exposes this forward so
 * consumer plugins can apply policy. The core itself does not impose default
 * immunity, mode, or vote-rule policy.
 *
 * Typical usage for validators:
 * 1. inspect the proposed vote
 * 2. if it must be blocked, call `CallVoteCore_SetPendingRestriction(...)`
 * 3. return `Plugin_Handled`
 *
 * If every consumer returns `Plugin_Continue`, the core proceeds to engine
 * execution.
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
forward Action CallVote_PreStart(int sessionId, int client, int callerAccountId, TypeVotes voteType, int target, int targetAccountId, const char[] argument);

/**
 * Post-hook fired when the engine confirms the vote has started.
 *
 * @param sessionId         Unique session id assigned by the core
 */
forward void CallVote_Start(int sessionId);

/**
 * Pre-hook fired after PreStart passes but before the command is handed to the engine.
 *
 * This is intended for advanced consumers that need a second decision point
 * after the session has already passed the first validation stage.
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
forward Action CallVote_PreExecute(int sessionId, int client, int callerAccountId, TypeVotes voteType, int target, int targetAccountId, const char[] argument);

/**
 * Post-hook fired when a vote session is blocked.
 *
 * This covers blocks originating from PreStart, PreExecute, and core-level
 * abort paths. Consumers should treat it as the canonical rejection callback.
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
forward void CallVote_Blocked(int sessionId, int client, int callerAccountId, TypeVotes voteType, VoteRestrictionType restriction, int target, int targetAccountId, const char[] argument);

/**
 * Final post-hook fired when the current vote session ends.
 *
 * This is the canonical lifecycle completion callback for accepted, failed,
 * cancelled, blocked, and stale sessions.
 *
 * @param sessionId         Unique session id assigned by the core
 * @param result            Final outcome of the vote session
 * @param yesCount          Final yes votes seen by the core
 * @param noCount           Final no votes seen by the core
 * @param potentialVotes    Final potential votes seen by the core
 */
forward void CallVote_End(int sessionId, CallVoteEndReason result, int yesCount, int noCount, int potentialVotes);

/**
 * Sets the restriction that should be associated with the current pending
 * block when a PreStart/PreExecute consumer decides to reject the vote.
 *
 * Typical usage:
 * 1. detect policy violation inside `CallVote_PreStart`
 * 2. call `CallVoteCore_SetPendingRestriction(...)`
 * 3. return `Plugin_Handled`
 *
 * @param restriction   Restriction to bind to the pending block
 */
native void CallVoteCore_SetPendingRestriction(VoteRestrictionType restriction);

/**
 * Returns the Steam AccountID for a connected client.
 *
 * @param client    Client index
 * @return          AccountID for a human client, 0 otherwise
 */
native int CallVoteCore_GetClientAccountID(int client);

/**
 * Formats a connected client's identity as SteamID2.
 *
 * @param client        Client index
 * @param steamId2      Buffer that receives the SteamID2 string
 * @param maxlen        Maximum buffer length
 * @return              True if the conversion succeeded, false otherwise
 */
native bool CallVoteCore_GetClientSteamID2(int client, char[] steamId2, int maxlen);

/**
 * Returns the current active vote session id.
 *
 * @return              Current session id, or 0 if no session is active
 */
native int CallVoteCore_GetCurrentSession();

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
native bool CallVoteCore_GetSessionInfo(int sessionId, int &callerClient, int &callerAccountId, TypeVotes &voteType, int &targetClient, int &targetAccountId, char[] argument, int argMaxLen);

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
native bool CallVoteCore_GetSessionSteamID64Info(int sessionId, char[] callerSteamID64, int callerMaxLen, char[] targetSteamID64, int targetMaxLen);

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
native bool CallVoteCore_GetSessionIssueInfo(int sessionId, char[] issue, int issueMaxLen, char[] param1, int param1MaxLen, char[] param2, int param2MaxLen, int &team, int &initiatorClient);

/**
 * Returns raw CallVoteFailed information captured for a session.
 *
 * These values are meaningful when the session ended with CallVoteEnd_Cancelled.
 *
 * @param sessionId         Session id to query
 * @param reason            Receives the CallVoteFailed reason code
 * @param time              Receives the CallVoteFailed time value
 * @return                  True if the session exists
 */
native bool CallVoteCore_GetSessionFailureInfo(int sessionId, int &reason, int &time);

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
native bool CallVoteCore_GetSessionTally(int sessionId, int &yesVotes, int &noVotes, int &potentialVotes, CallVoteEndReason &endReason);

public SharedPlugin __pl_callvote_core = {
	name = CALLVOTECORE_LIBRARY,
	file = CALLVOTECORE_PLUGIN,
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN

public void __pl_callvote_core_SetNTVOptional()
{
	MarkNativeAsOptional("CallVoteCore_SetPendingRestriction");
	MarkNativeAsOptional("CallVoteCore_GetClientAccountID");
	MarkNativeAsOptional("CallVoteCore_GetClientSteamID2");
	MarkNativeAsOptional("CallVoteCore_GetCurrentSession");
	MarkNativeAsOptional("CallVoteCore_GetSessionInfo");
	MarkNativeAsOptional("CallVoteCore_GetSessionSteamID64Info");
	MarkNativeAsOptional("CallVoteCore_GetSessionIssueInfo");
	MarkNativeAsOptional("CallVoteCore_GetSessionFailureInfo");
	MarkNativeAsOptional("CallVoteCore_GetSessionTally");
}
#endif
