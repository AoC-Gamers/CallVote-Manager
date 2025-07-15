#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <callvote_stock>

/*****************************************************************
    PRACTICAL EXAMPLE: VOTE TRACKING SYSTEM
    
    This plugin demonstrates how to implement a complete vote
    tracking system using only native event hooks.
*****************************************************************/

#define PLUGIN_VERSION "1.0.0"
#define TAG "[{green}VoteTracker{default}]"

/*****************************************************************
    VOTE TRACKING VARIABLES
*****************************************************************/

// Current vote information
int g_iCurrentVoteInitiator = 0;
int g_iCurrentVoteTeam = 0;
char g_sCurrentVoteType[64];
char g_sCurrentVoteParam1[128];
char g_sCurrentVoteParam2[128];
bool g_bVoteInProgress = false;
float g_fVoteStartTime = 0.0;

// Vote counters
int g_iYesVotes = 0;
int g_iNoVotes = 0;
int g_iPotentialVotes = 0;

// Player tracking
bool g_bPlayerVoted[MAXPLAYERS + 1];
bool g_bPlayerVoteChoice[MAXPLAYERS + 1]; // true = yes, false = no

// Session statistics
int g_iPlayerVotesYes[MAXPLAYERS + 1];
int g_iPlayerVotesNo[MAXPLAYERS + 1];
int g_iPlayerInitiatedVotes[MAXPLAYERS + 1];
int g_iTotalVotesStarted = 0;
int g_iTotalVotesPassed = 0;
int g_iTotalVotesFailed = 0;

// ConVars
ConVar g_cvarEnable;
ConVar g_cvarAnnounce;
ConVar g_cvarDetailedLog;
ConVar g_cvarShowProgress;

/*****************************************************************
    PLUGIN INFO
*****************************************************************/

public Plugin myinfo =
{
    name        = "Vote Tracker",
    author      = "lechuga",
    description = "Complete vote tracking system using only event hooks",
    version     = PLUGIN_VERSION,
    url         = ""
};

/*****************************************************************
    INITIALIZATION
*****************************************************************/

public void OnPluginStart()
{
    // ConVars
    CreateConVar("vt_version", PLUGIN_VERSION, "Plugin version", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
    g_cvarEnable = CreateConVar("vt_enable", "1", "Enable vote tracking", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvarAnnounce = CreateConVar("vt_announce", "1", "Announce vote progress to chat", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvarDetailedLog = CreateConVar("vt_detailed_log", "1", "Enable detailed console logging", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvarShowProgress = CreateConVar("vt_show_progress", "1", "Show vote progress updates", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    
    // Event hooks - ALL VOTE EVENTS
    HookEvent("vote_started", Event_VoteStarted);
    HookEvent("vote_ended", Event_VoteEnded);
    HookEvent("vote_changed", Event_VoteChanged);
    HookEvent("vote_cast_yes", Event_VoteCastYes);
    HookEvent("vote_cast_no", Event_VoteCastNo);
    HookEvent("vote_passed", Event_VotePassed);
    HookEvent("vote_failed", Event_VoteFailed);
    
    // Commands for statistics
    RegConsoleCmd("sm_votestats", Cmd_VoteStats, "Show vote statistics");
    RegConsoleCmd("sm_currentvote", Cmd_CurrentVote, "Show current vote information");
    
    AutoExecConfig(true, "vote_tracker");
}

public void OnMapStart()
{
    // Reset statistics when changing map
    ResetSessionStats();
}

public void OnClientDisconnect(int client)
{
    // Clear client data on disconnect
    g_bPlayerVoted[client] = false;
    g_bPlayerVoteChoice[client] = false;
}

/*****************************************************************
    EVENT HOOKS - MAIN TRACKING
*****************************************************************/

/**
 * EVENT: vote_started
 * Most important for initializing tracking
 */
public void Event_VoteStarted(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
    if (!g_cvarEnable.BoolValue) return;
    
    // Clear previous vote data
    ResetVoteTracking();
    
    // Capture new vote information
    g_iCurrentVoteTeam = hEvent.GetInt("team");
    g_iCurrentVoteInitiator = hEvent.GetInt("initiator");
    hEvent.GetString("issue", g_sCurrentVoteType, sizeof(g_sCurrentVoteType));
    hEvent.GetString("param1", g_sCurrentVoteParam1, sizeof(g_sCurrentVoteParam1));
    hEvent.GetString("param2", g_sCurrentVoteParam2, sizeof(g_sCurrentVoteParam2));
    
    g_bVoteInProgress = true;
    g_fVoteStartTime = GetEngineTime();
    g_iTotalVotesStarted++;
    
    if (IsValidClient(g_iCurrentVoteInitiator))
    {
        g_iPlayerInitiatedVotes[g_iCurrentVoteInitiator]++;
    }
    
    // Detailed logging
    if (g_cvarDetailedLog.BoolValue)
    {
        PrintToServer("🗳️ ========== VOTE STARTED ==========");
        PrintToServer("  Type: %s", g_sCurrentVoteType);
        PrintToServer("  Initiator: %N (ID: %d)", g_iCurrentVoteInitiator, g_iCurrentVoteInitiator);
        PrintToServer("  Team: %d", g_iCurrentVoteTeam);
        PrintToServer("  Parameter 1: %s", g_sCurrentVoteParam1);
        PrintToServer("  Parameter 2: %s", g_sCurrentVoteParam2);
        PrintToServer("=====================================");
    }
    
    // Custom announcements by vote type
    if (g_cvarAnnounce.BoolValue)
    {
        AnnounceVoteStart();
    }
}

/**
 * EVENT: vote_cast_yes
 * Tracking when someone votes YES (F1)
 */
public void Event_VoteCastYes(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
    if (!g_cvarEnable.BoolValue || !g_bVoteInProgress) return;
    
    int client = hEvent.GetInt("entityid");
    int team = hEvent.GetInt("team");
    
    if (IsValidClient(client))
    {
        g_bPlayerVoted[client] = true;
        g_bPlayerVoteChoice[client] = true;
        g_iPlayerVotesYes[client]++;
        
        if (g_cvarDetailedLog.BoolValue)
        {
            PrintToServer("✅ %N voted YES (Team: %d)", client, team);
        }
        
        if (g_cvarAnnounce.BoolValue)
        {
            CPrintToChatAll("%s ✅ {blue}%N{default} voted {green}in favor{default}", TAG, client);
        }
    }
}

/**
 * EVENT: vote_cast_no
 * Tracking when someone votes NO (F2)
 */
public void Event_VoteCastNo(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
    if (!g_cvarEnable.BoolValue || !g_bVoteInProgress) return;
    
    int client = hEvent.GetInt("entityid");
    int team = hEvent.GetInt("team");
    
    if (IsValidClient(client))
    {
        g_bPlayerVoted[client] = true;
        g_bPlayerVoteChoice[client] = false;
        g_iPlayerVotesNo[client]++;
        
        if (g_cvarDetailedLog.BoolValue)
        {
            PrintToServer("❌ %N voted NO (Team: %d)", client, team);
        }
        
        if (g_cvarAnnounce.BoolValue)
        {
            CPrintToChatAll("%s ❌ {blue}%N{default} voted {red}against{default}", TAG, client);
        }
    }
}

/**
 * EVENT: vote_changed
 * Vote progress update
 */
public void Event_VoteChanged(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
    if (!g_cvarEnable.BoolValue || !g_bVoteInProgress) return;
    
    g_iYesVotes = hEvent.GetInt("yesVotes");
    g_iNoVotes = hEvent.GetInt("noVotes");
    g_iPotentialVotes = hEvent.GetInt("potentialVotes");
    
    // Calculate percentage
    float percentage = 0.0;
    if (g_iPotentialVotes > 0)
    {
        percentage = (float(g_iYesVotes) / float(g_iPotentialVotes)) * 100.0;
    }
    
    if (g_cvarDetailedLog.BoolValue)
    {
        PrintToServer("📊 PROGRESS: %d YES | %d NO | %d Total (%.1f%%)", 
                      g_iYesVotes, g_iNoVotes, g_iPotentialVotes, percentage);
    }
    
    // Show progress in chat
    if (g_cvarShowProgress.BoolValue && g_cvarAnnounce.BoolValue)
    {
        CPrintToChatAll("%s 📊 Progress: {green}%d YES{default} - {red}%d NO{default} ({yellow}%.1f%%{default})", 
                       TAG, g_iYesVotes, g_iNoVotes, percentage);
        
        // Special alerts
        if (percentage >= 75.0)
        {
            CPrintToChatAll("%s 🔥 {green}Vote is very close to passing!{default}", TAG);
        }
        else if (percentage <= 25.0 && (g_iYesVotes + g_iNoVotes) >= 3)
        {
            CPrintToChatAll("%s 💧 {red}Vote has low chances of passing{default}", TAG);
        }
    }
}

/**
 * EVENT: vote_ended
 * Most reliable for final result
 */
public void Event_VoteEnded(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
    if (!g_cvarEnable.BoolValue || !g_bVoteInProgress) return;
    
    char voteType[128], param1[128], param2[128];
    int team = hEvent.GetInt("team");
    int success = hEvent.GetInt("success");
    
    hEvent.GetString("vote_type", voteType, sizeof(voteType));
    hEvent.GetString("param1", param1, sizeof(param1));
    hEvent.GetString("param2", param2, sizeof(param2));
    
    float voteDuration = GetEngineTime() - g_fVoteStartTime;
    
    // Update statistics
    if (success)
        g_iTotalVotesPassed++;
    else
        g_iTotalVotesFailed++;
    
    if (g_cvarDetailedLog.BoolValue)
    {
        PrintToServer("🏁 ========== VOTE FINISHED ==========");
        PrintToServer("  Result: %s", success ? "✅ PASSED" : "❌ FAILED");
        PrintToServer("  Type: %s", voteType);
        PrintToServer("  Duration: %.1f seconds", voteDuration);
        PrintToServer("  Final votes: %d YES - %d NO", g_iYesVotes, g_iNoVotes);
        PrintToServer("=====================================");
        
        // Generate detailed report
        GenerateVoteReport();
    }
    
    if (g_cvarAnnounce.BoolValue)
    {
        if (success)
        {
            CPrintToChatAll("%s 🎉 {green}Vote passed!{default} (%d-%d)", TAG, g_iYesVotes, g_iNoVotes);
        }
        else
        {
            CPrintToChatAll("%s 💔 {red}Vote failed{default} (%d-%d)", TAG, g_iYesVotes, g_iNoVotes);
        }
    }
    
    // Clear data
    g_bVoteInProgress = false;
}

/**
 * EVENT: vote_passed
 * Additional information when vote passes
 */
public void Event_VotePassed(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
    if (!g_cvarEnable.BoolValue) return;
    
    char details[128];
    hEvent.GetString("details", details, sizeof(details));
    
    if (g_cvarDetailedLog.BoolValue)
    {
        PrintToServer("✅ VOTE PASSED: %s", details);
    }
}

/**
 * EVENT: vote_failed
 * Additional information when vote fails
 */
public void Event_VoteFailed(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
    if (!g_cvarEnable.BoolValue) return;
    
    char details[128];
    hEvent.GetString("details", details, sizeof(details));
    
    if (g_cvarDetailedLog.BoolValue)
    {
        PrintToServer("❌ VOTE FAILED: %s", details);
    }
}

/*****************************************************************
    AUXILIARY FUNCTIONS
*****************************************************************/

void ResetVoteTracking()
{
    g_iCurrentVoteInitiator = 0;
    g_iCurrentVoteTeam = 0;
    g_sCurrentVoteType[0] = '\0';
    g_sCurrentVoteParam1[0] = '\0';
    g_sCurrentVoteParam2[0] = '\0';
    g_iYesVotes = 0;
    g_iNoVotes = 0;
    g_iPotentialVotes = 0;
    
    // Clear player arrays
    for (int i = 1; i <= MaxClients; i++)
    {
        g_bPlayerVoted[i] = false;
        g_bPlayerVoteChoice[i] = false;
    }
}

void ResetSessionStats()
{
    g_iTotalVotesStarted = 0;
    g_iTotalVotesPassed = 0;
    g_iTotalVotesFailed = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iPlayerVotesYes[i] = 0;
        g_iPlayerVotesNo[i] = 0;
        g_iPlayerInitiatedVotes[i] = 0;
    }
}

void GenerateVoteReport()
{
    PrintToServer("📝 ========== DETAILED REPORT ==========");
    PrintToServer("  Initiator: %N", g_iCurrentVoteInitiator);
    PrintToServer("  Type: %s | Param1: %s | Param2: %s", g_sCurrentVoteType, g_sCurrentVoteParam1, g_sCurrentVoteParam2);
    
    PrintToServer("  👥 VOTED YES:");
    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_bPlayerVoted[i] && g_bPlayerVoteChoice[i] && IsValidClient(i))
        {
            PrintToServer("    ✅ %N", i);
        }
    }
    
    PrintToServer("  👥 VOTED NO:");
    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_bPlayerVoted[i] && !g_bPlayerVoteChoice[i] && IsValidClient(i))
        {
            PrintToServer("    ❌ %N", i);
        }
    }
    
    PrintToServer("  👥 DID NOT VOTE:");
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!g_bPlayerVoted[i] && IsValidClient(i))
        {
            PrintToServer("    ⭕ %N", i);
        }
    }
    PrintToServer("======================================");
}

void AnnounceVoteStart()
{
    if (StrEqual(g_sCurrentVoteType, "Kick"))
    {
        int targetId = StringToInt(g_sCurrentVoteParam1);
        if (IsValidClient(targetId))
        {
            CPrintToChatAll("%s 🚨 {blue}%N{default} wants to kick {red}%N{default}", TAG, g_iCurrentVoteInitiator, targetId);
        }
    }
    else if (StrEqual(g_sCurrentVoteType, "ChangeMission"))
    {
        CPrintToChatAll("%s 🗺️ {blue}%N{default} wants to change to map: {yellow}%s{default}", TAG, g_iCurrentVoteInitiator, g_sCurrentVoteParam1);
    }
    else if (StrEqual(g_sCurrentVoteType, "RestartGame"))
    {
        CPrintToChatAll("%s 🔄 {blue}%N{default} wants to restart the game", TAG, g_iCurrentVoteInitiator);
    }
    else if (StrEqual(g_sCurrentVoteType, "ReturnToLobby"))
    {
        CPrintToChatAll("%s 🏠 {blue}%N{default} wants to return to lobby", TAG, g_iCurrentVoteInitiator);
    }
    else
    {
        CPrintToChatAll("%s 🗳️ {blue}%N{default} started a vote: {yellow}%s{default}", TAG, g_iCurrentVoteInitiator, g_sCurrentVoteType);
    }
}

// IsValidClient function moved to callvote_stock.inc for consistency

/*****************************************************************
    COMMANDS
*****************************************************************/

Action Cmd_VoteStats(int client, int args)
{
    if (!g_cvarEnable.BoolValue)
    {
        CReplyToCommand(client, "%s Plugin is disabled.", TAG);
        return Plugin_Handled;
    }
    
    CReplyToCommand(client, "%s {green}=== VOTE STATISTICS ==={default}", TAG);
    CReplyToCommand(client, "%s Total started: {yellow}%d{default}", TAG, g_iTotalVotesStarted);
    CReplyToCommand(client, "%s Passed: {green}%d{default} | Failed: {red}%d{default}", TAG, g_iTotalVotesPassed, g_iTotalVotesFailed);
    
    if (g_iTotalVotesStarted > 0)
    {
        float successRate = (float(g_iTotalVotesPassed) / float(g_iTotalVotesStarted)) * 100.0;
        CReplyToCommand(client, "%s Success rate: {yellow}%.1f%%{default}", TAG, successRate);
    }
    
    // Personal statistics
    if (IsValidClient(client))
    {
        CReplyToCommand(client, "%s {blue}Your statistics:{default}", TAG);
        CReplyToCommand(client, "%s Votes initiated: {yellow}%d{default}", TAG, g_iPlayerInitiatedVotes[client]);
        CReplyToCommand(client, "%s YES votes: {green}%d{default} | NO votes: {red}%d{default}", TAG, g_iPlayerVotesYes[client], g_iPlayerVotesNo[client]);
    }
    
    return Plugin_Handled;
}

Action Cmd_CurrentVote(int client, int args)
{
    if (!g_cvarEnable.BoolValue)
    {
        CReplyToCommand(client, "%s Plugin is disabled.", TAG);
        return Plugin_Handled;
    }
    
    if (!g_bVoteInProgress)
    {
        CReplyToCommand(client, "%s No vote in progress.", TAG);
        return Plugin_Handled;
    }
    
    CReplyToCommand(client, "%s {green}=== CURRENT VOTE ==={default}", TAG);
    CReplyToCommand(client, "%s Type: {yellow}%s{default}", TAG, g_sCurrentVoteType);
    CReplyToCommand(client, "%s Started by: {blue}%N{default}", TAG, g_iCurrentVoteInitiator);
    CReplyToCommand(client, "%s Progress: {green}%d YES{default} - {red}%d NO{default}", TAG, g_iYesVotes, g_iNoVotes);
    
    float elapsed = GetEngineTime() - g_fVoteStartTime;
    CReplyToCommand(client, "%s Time elapsed: {yellow}%.1f{default} seconds", TAG, elapsed);
    
    return Plugin_Handled;
}
