#pragma newdecls required
#pragma semicolon 1

#include <sourcemod> 
#include <sdktools>

#define IS_VALID_CLIENT(%1) (%1 > 0 && %1 <= MaxClients)
#define IS_CONNECTED_INGAME(%1) (IsClientConnected(%1) && IsClientInGame(%1))
#define IS_SURVIVOR(%1) (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1) (GetClientTeam(%1) == 3)

#define IS_VALID_INGAME(%1) (IS_VALID_CLIENT(%1) && IS_CONNECTED_INGAME(%1))

#define IS_VALID_SURVIVOR(%1) (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1) (IS_VALID_INGAME(%1) && IS_INFECTED(%1))

#define IS_SURVIVOR_ALIVE(%1) (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1) (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))

public Plugin myinfo = { 
    name = "[L4D, L4D2] No Death Check Until Dead", 
    author = "chinagreenelvis (modified by dcx2 and Dragokas)", 
    description = "Prevents mission loss until all human players have died.", 
    version = "1.4.10", 
    url = "https://forums.alliedmods.net/showthread.php?t=142432" 
};

/*
	1.4.10
	 - Moved to new syntax and methodmaps

	1.4.9 (Dragokas)
	 - Added "allow_all_bot_survivor_team" ConVar presence check
*/

int L4D2Version=false;

ConVar g_hDeathCheckEnable;
bool g_bEnabled = false;
ConVar g_cvarDebug;
bool g_bDebug = false;
ConVar g_hDeathCheckBots;
bool g_bDeathCheckBots = false;
ConVar g_hDirectorNoDeathCheck;
bool g_bDirectorNoDeathCheck = false;
ConVar g_hCvarMPGameMode;
ConVar g_hCvarModes;
ConVar g_hAllowAllBot;
bool g_bLostFired = false;
bool g_bBlockDeathCheckDisable = false;

public void OnPluginStart()
{  
	g_hDeathCheckEnable = CreateConVar("deathcheck_enable", "1", "0:禁用插件,1:启用插件", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_cvarDebug = CreateConVar("deathcheck_debug", "0", "启用调试日志", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_hDeathCheckBots = CreateConVar("deathcheck_bots", "0", "0: 机器人和空闲玩家被视为人类非空闲玩家，1: 如果仍有幸存的机器人/空闲玩家但没有活着的非空闲人类，任务就会失败", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_hCvarModes = CreateConVar("deathcheck_modes", "","在这些游戏模式上启用插件，用逗号分开(没有空格)(空=全部)", FCVAR_NOTIFY);
	g_hDirectorNoDeathCheck = FindConVar("director_no_death_check");
	g_hCvarMPGameMode =	FindConVar("mp_gamemode");
	g_hAllowAllBot = FindConVar("allow_all_bot_survivor_team");
	
	g_hDeathCheckEnable.AddChangeHook(OnDeathCheckEnableChanged);
	g_cvarDebug.AddChangeHook(OnDeathCheckDebugChanged);
	g_hDeathCheckBots.AddChangeHook(OnDeathCheckBotsChanged);
	g_hDirectorNoDeathCheck.AddChangeHook(OnDirectorNoDeathCheckChanged);
	g_hCvarMPGameMode.AddChangeHook(CvarChange_Allow);
	g_hCvarModes.AddChangeHook(CvarChange_Allow);
	
	AutoExecConfig(true, "l4d2_deathcheck");
	
	g_bEnabled = g_hDeathCheckEnable.BoolValue;
	g_bDebug = g_cvarDebug.BoolValue;
	g_bDeathCheckBots = g_hDeathCheckBots.BoolValue;
	g_bDirectorNoDeathCheck = g_hDirectorNoDeathCheck.BoolValue;
	
	IsAllowed();
	
	if (g_bDebug) HookEvent("mission_lost", Event_MissionLost);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("round_start_post_nav", Event_RoundStart, EventHookMode_Post);
	HookEvent("player_bot_replace", Event_DeadCheck);
	HookEvent("bot_player_replace", Event_DeadCheck);
	HookEvent("player_team", Event_DeadCheck);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	HookEvent("player_death", Event_DeadCheck, EventHookMode_Pre);
	HookEvent("player_incapacitated", Event_DeadCheck); 
	HookEvent("player_ledge_grab", Event_DeadCheck);
	HookEvent("lunge_pounce", Event_DeadCheck);
	HookEvent("tongue_grab", Event_DeadCheck);
	HookEvent("door_close", Event_DoorClose);
	if(L4D2Version)
	{
		HookEvent("jockey_ride", Event_DeadCheck);
		HookEvent("charger_pummel_start", Event_DeadCheck);
	}
}

public void OnDeathCheckEnableChanged(Handle cvar, const char[] oldVal, const char[] newVal)
{
	g_bEnabled = StringToInt(newVal) == 1;
	if (!g_bEnabled && g_bDirectorNoDeathCheck) g_hDirectorNoDeathCheck.SetInt(0);
	IsAllowed();
	DeadCheck();
}

public void OnDeathCheckDebugChanged(Handle cvar, const char[] oldVal, const char[] newVal)
{
	g_bDebug = StringToInt(newVal) == 1;
	
	// When debugging, it's sometimes useful to know whether MissionLost fired
	if (g_bDebug) HookEvent("mission_lost", Event_MissionLost);
	else UnhookEvent("mission_lost", Event_MissionLost);		
}

public void OnDeathCheckBotsChanged(Handle cvar, const char[] oldVal, const char[] newVal)
{
	g_bDeathCheckBots = StringToInt(newVal) == 1;
	DeadCheck();
}

public void OnDirectorNoDeathCheckChanged(Handle cvar, const char[] oldVal, const char[] newVal)
{
	g_bDirectorNoDeathCheck = StringToInt(newVal) == 1;
}

public void OnMapStart()
{
	if (g_bDebug)	PrintToChatAll("OnMapStart");
	IsAllowed();
	DeadCheck();
}

public void OnClientConnected()
{
	if (g_bDebug)	PrintToChatAll("OnClientConnected");
	DeadCheck();
}

public void OnClientPutInServer()
{
	if (g_bDebug)	PrintToChatAll("OnClientPutInServer");
	DeadCheck();
}

public void OnClientDisconnect(int client)
{
	if (g_bDebug)	PrintToChatAll("OnClientDisconnect");
	DeadCheck();
}

// Whenever the round starts, we should clear director_no_death_check
// otherwise the round may not end when all survivors are dead ("all dead glitch")
// Furthermore, it must stay cleared for some amount of time
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{ 
	if (g_bDebug)
	{
		char eventName[32];
		event.GetName(eventName, sizeof(eventName));
		PrintToChatAll("%s", eventName);
	}
	
	g_hDirectorNoDeathCheck.SetInt(0);

	if (!g_bBlockDeathCheckDisable) 
	{
		g_bBlockDeathCheckDisable = true;
		CreateTimer(1.5, BlockDeathCheckEnable, 0);
	}
} 

public Action BlockDeathCheckEnable(Handle timer, int value)
{
	g_bBlockDeathCheckDisable = false;
}

// if the all dead glitch happened and a human Survivor spawns,
// director_no_death_check must be cleared again or no one else can die either
// So we do clear the death check as a precautionary measure
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{ 
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	// Must not reset death check unless it's a human survivor, otherwise game might accidentally end
	if (GetClientTeam(client) != 2 || IsFakeClient(client)) return;
	
	Event_RoundStart(event, name, dontBroadcast);
} 

public void Event_DeadCheck(Event event, const char[] name, bool dontBroadcast) 
{
	if (g_bDebug)
	{
		char eventName[32];
		event.GetName(eventName, sizeof(eventName));
		PrintToChatAll("%s", eventName);
	}
	DeadCheck();
}

// Enables death check only when all survivors are dead
void DeadCheck()
{
	if (!g_bEnabled)
	{
		return;
	}

	int survivors = 0; 
	for (int i = 1; i <= MaxClients; i++) 
	{ 
		if (IS_SURVIVOR_ALIVE(i) && GetClientHealth(i) > 0 && (!g_bDeathCheckBots || !IsFakeClient(i))) 
		{
			survivors++;
			if (!g_bDebug) break;			// quit after we have at least one valid survivor
		}
	}
	
	if (g_bDebug)	PrintToChatAll("%d survivors", survivors);
	
	// cvar must be 0 for at least 1 second
	// So if the block death check disable flag is set, we can't enable the cvar yet
	if (survivors > 0 && !g_bDirectorNoDeathCheck && !g_bBlockDeathCheckDisable)
	{
		if (g_bDebug)	PrintToChatAll("preventing deathcheck");
		g_hDirectorNoDeathCheck.SetInt(1);
	}
	else if (survivors == 0 && g_bDirectorNoDeathCheck)
	{
		if (g_bDebug)
		{
			PrintToChatAll("enabling deathcheck");
			g_bLostFired = false;					// listen for whether mission lost has fired
			CreateTimer(1.5, CheckLostFired, 0);
		}
		g_hDirectorNoDeathCheck.SetInt(0);
	}
}

// When everyone is dead in coop, the Mission Lost event should fire
// If it doesn't, the all dead glitch happened
public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast) 
{ 
	g_bLostFired = true;
}

public Action CheckLostFired(Handle timer, int value)
{
	if (!g_bLostFired) PrintToChatAll("mission_lost did not fire");
	g_bLostFired = false;
}

// If the last human survivor slays themselves after closing the door but before it seals
// the game will stay in limbo until a human takes control of a Survivor in the safe room
// To prevent this, we wait until after the door seals (about 1 second, so 2 second timer)
// And then if there are no humans, we momentarily allow an all bot survivor team
public void Event_DoorClose(Event event, const char[] name, bool dontBroadcast) 
{ 
	int checkpoint = event.GetBool("checkpoint");
	if (checkpoint)
	{
		CreateTimer(2.0, DoorCloseDelay, 0);
	}
}

public Action DoorCloseDelay(Handle timer, int value)
{
	bool FoundHumanSurvivor = false;
	for (int i=1; i<MaxClients; i++)
	{
		if (IS_SURVIVOR_ALIVE(i) && !IsFakeClient(i)) FoundHumanSurvivor = true;
	}
	
	// Don't bother doing this if the cvar is already false
	if (g_hAllowAllBot != null)
	{
		if (!FoundHumanSurvivor && !g_hAllowAllBot.BoolValue)
		{
			if (g_bDebug) PrintToChatAll("Momentarily activating allow_all_bot_survivor_team");
			g_hAllowAllBot.SetBool(true);
			CreateTimer(1.0, DeactivateAllowBotCVARDelay, 0);
		}
	}
}

public Action DeactivateAllowBotCVARDelay(Handle timer, int value)
{
	g_hAllowAllBot.SetBool(false);
}

// Allowed game modes thanks to SilverShot
public void OnConfigsExecuted()
{
	IsAllowed();
}

public void CvarChange_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == INVALID_HANDLE )
		return false;

	char sGameMode[32];
	char sGameModes[64];
	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( strlen(sGameModes) == 0 )
		return true;

	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);
	return (StrContains(sGameModes, sGameMode, false) != -1);
}

void IsAllowed()
{
	bool bAllow = g_hDeathCheckEnable.BoolValue;
	bool bAllowMode = IsAllowedGameMode();

	if (g_bEnabled == false && bAllow == true && bAllowMode == true)
	{
		g_bEnabled = true;
	}
	else if (g_bEnabled == true && (bAllow == false || bAllowMode == false))
	{
		g_bEnabled = false;
	}
}
// /allowed game modes thanks to SilverShot
