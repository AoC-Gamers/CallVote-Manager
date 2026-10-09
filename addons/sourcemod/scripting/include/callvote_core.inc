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

enum CallVoteSessionStatus
{
	CallVoteSession_None = 0,
	CallVoteSession_Pending,
	CallVoteSession_Executing,
	CallVoteSession_Started,
	CallVoteSession_Blocked,
	CallVoteSession_Ended
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
 * execution. These decision callbacks are evaluated individually for all
 * running consumers. Handled/Stop veto; Changed does not rewrite arguments.
 * A callback execution error vetoes with VoteRestriction_Plugin.
 * Synchronous nested callvote commands during any core callback are blocked;
 * schedule a later frame and revalidate context when a new request is needed.
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
 * Fired once when the engine confirms the vote has started, before BallotCast.
 * Delivery leaves the VoteStart usermessage hook before invoking consumers.
 *
 * @param sessionId         Unique session id assigned by the core
 */
forward void CallVote_Start(int sessionId);

/**
 * One observed engine ballot for the current session, including initial ballots.
 * client and accountId identify the voter at observation time. AccountID is
 * captured before invoking Start or ballot consumers; 0 means unavailable.
 * client is transient and can be 0 if disconnected before ballot delivery.
 * Fired synchronously from vote_cast_yes/no after CallVote_Start. No per-voter
 * history is kept by the core. Consumers own persistence and SteamID conversion.
 * Validate the live client against accountId before reading extra player data.
 * VoteRegistered is deliberately not a second source for the same ballot.
 * The team is the vote scope (normalized 255 to -1), not the player's team.
 */
forward void CallVote_BallotCast(int sessionId, int client, int accountId, bool votedYes, int team);

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
 * cancelled, blocked, and stale sessions. Requests with no engine confirmation
 * expire as Aborted without CallVote_Start; they are not played votes.
 *
 * Result usermessages are finalized outside their network hook. Duplicate
 * result signals do not emit a second completion. Counts are read from the
 * matching vote_controller or vote_changed, never inferred from recipients.
 *
 * @param sessionId         Unique session id assigned by the core
 * @param result            Final outcome of the vote session
 * @param yesCount          Final yes votes seen by the core, -1 if unavailable
 * @param noCount           Final no votes seen by the core, -1 if unavailable
 * @param potentialVotes    Final potential votes seen by the core, -1 if unavailable
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
 * Valid only synchronously inside the invoking plugin's PreStart/PreExecute
 * callback. None and invalid values raise a native error. The candidate belongs
 * to that consumer: it is ignored if the consumer allows the request. The first
 * veto retains its reason; later consumers cannot overwrite it. Handled/Stop
 * without a reason uses VoteRestriction_Plugin. All running consumers are
 * evaluated; their load order is not a policy priority mechanism.
 *
 * @param restriction   Restriction to bind to this consumer's pending veto
 */
native void CallVoteCore_SetPendingRestriction(VoteRestrictionType restriction);

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
 * Client indices are transient; AccountIDs remain captured proposal identities.
 * SteamID conversion belongs to consumers, not the core.
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
 * Reads lifecycle state and the canonical block reason from current/last session.
 * The reason is None until a veto is finalized. Clients are transient indices.
 */
native bool CallVoteCore_GetSessionState(int sessionId, CallVoteSessionStatus &status, VoteRestrictionType &restriction);

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
 * @param initiatorAccountId Receives its AccountID captured with the engine start signal, 0 if unavailable
 * @return                  True if the session exists
 */
native bool CallVoteCore_GetSessionIssueInfo(int sessionId, char[] issue, int issueMaxLen, char[] param1, int param1MaxLen, char[] param2, int param2MaxLen, int &team, int &initiatorClient, int &initiatorAccountId);

/**
 * Returns raw CallVoteFailed information captured for a session.
 *
 * These values are meaningful when the session ended with CallVoteEnd_Cancelled.
 *
 * @param sessionId         Session id to query
 * @param reason            Receives the CallVoteFailed reason code
 * @param time              Receives CallVoteFailed time, -1 when absent
 * @return                  True if the session exists
 */
native bool CallVoteCore_GetSessionFailureInfo(int sessionId, int &reason, int &time);

/**
 * Returns the last tally known by the core for a session.
 * Each count can be -1 when no authoritative value was observed.
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
	MarkNativeAsOptional("CallVoteCore_GetCurrentSession");
	MarkNativeAsOptional("CallVoteCore_GetSessionInfo");
	MarkNativeAsOptional("CallVoteCore_GetSessionState");
	MarkNativeAsOptional("CallVoteCore_GetSessionIssueInfo");
	MarkNativeAsOptional("CallVoteCore_GetSessionFailureInfo");
	MarkNativeAsOptional("CallVoteCore_GetSessionTally");
}
#endif
