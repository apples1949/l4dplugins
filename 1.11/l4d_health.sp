#define PLUGIN_VERSION		"1.2"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D] Health
*	Author	:	JOSHE GATITO SPARTANSKII >>>
*	Descr.	:	HP of survivor to set in the round. 
*	Link	:	https://github.com/JosheGatitoSpartankii09

========================================================================================
	Change Log:

1.2 (17-05-2022) - arclightarchery
	- Switching character won't reset health
	- Add health when revived, defibed
	
1.1 (13-01-2021) - eyeonus
	- Removed L4D1-only restriction
	- Added auto-generation of config file

1.0 (10-05-2019)
	- Initial release
	
========================================================================================
	Description:
	HP of survivor to set in the round. 

	Commands:
	Nothing.

	Settings (ConVars):
	"l4d_health_control" - HP of survivor to set
	
	Credits:
	My Friend Alex Dragokas for code
	
======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#define DEBUG 0

#include <sourcemod>

#define TEAM_SURVIVOR 2
#define CVAR_FLAGS			FCVAR_NOTIFY

ConVar g_ConVarHPSpawn;
ConVar g_ConVarHPRevive;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead && test != Engine_Left4Dead2) {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "[L4D] Health",
	author = "JOSHE GATITO SPARTANSKII, eyeonus",
	description = "HP of survivor to set in the round.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2651124"
}

public void OnPluginStart()
{
	CreateConVar("l4d_health_version", PLUGIN_VERSION, "Plugin version", FCVAR_DONTRECORD); 
	
	
	g_ConVarHPSpawn = CreateConVar("l4d_health_spawn", "200", "Spawn HP of survivor to set", CVAR_FLAGS);
	g_ConVarHPRevive = CreateConVar("l4d_health_revive", "150", "Revive HP of survivor to set", CVAR_FLAGS);
	
	
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_hurt", PlayerHurt);
	HookEvent("revive_success", ReviveSuccess);
	HookEvent("defibrillator_used", DefibUsed);
	
	AutoExecConfig(true, "l4d_health_config");
}

public Action PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{ 
	int UserId = event.GetInt("userid");
	int client = GetClientOfUserId(UserId);
	
	if (client != 0) {
	    if (GetClientTeam(client) == TEAM_SURVIVOR) { 
            SetEntProp(client, Prop_Send, "m_iMaxHealth", g_ConVarHPSpawn.IntValue);
            SetEntProp(client, Prop_Send, "m_iHealth", g_ConVarHPSpawn.IntValue);
		}
	}	
}

public Action PlayerHurt(Event event, const char[] name, bool dontBroadcast) 
{ 
	int UserId = event.GetInt("userid");
	int client = GetClientOfUserId(UserId);
	
	if (client != 0) {
	    if (GetClientTeam(client) == TEAM_SURVIVOR) {
            SetEntProp(client, Prop_Send, "m_iMaxHealth", g_ConVarHPSpawn.IntValue);
		}
	}	
}

public Action ReviveSuccess(Event event, const char[] name, bool dontBroadcast) 
{ 
	int Subject = event.GetInt("subject");
	int client = GetClientOfUserId(Subject);
	
	if (client != 0) {
	    if (GetClientTeam(client) == TEAM_SURVIVOR) {
            SetEntProp(client, Prop_Send, "m_iMaxHealth", g_ConVarHPSpawn.IntValue);
            SetEntProp(client, Prop_Send, "m_iHealth", g_ConVarHPRevive.IntValue-GetConVarInt(FindConVar("survivor_revive_health")));
		}
	}	
}

public Action DefibUsed(Event event, const char[] name, bool dontBroadcast) 
{ 
	int Subject = event.GetInt("subject");
	int client = GetClientOfUserId(Subject);
	
	if (client != 0) {
	    if (GetClientTeam(client) == TEAM_SURVIVOR) {
            SetEntProp(client, Prop_Send, "m_iHealth", g_ConVarHPRevive.IntValue);
		}
	}	
}