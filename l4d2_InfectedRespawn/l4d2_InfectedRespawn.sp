#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "0.7.1a"

new Handle:hBecomeGhost = INVALID_HANDLE;
new Handle:hBecomeGhostAt = INVALID_HANDLE;
new Handle:hGameConf = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "[L4D2] Infected Character Select",
	author = "Crimson_Fox & Ivailosp",
	description = "Allows infected players to change characters while in ghost mode.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=1016671"
}

public OnPluginStart()
{
	CreateConVar("ics_version", PLUGIN_VERSION, "Infected Character Select version.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD)
	//Check to see if L4DToolZ is loaded, and make sure sv_force_normal_respawn is set if it is.
	if (FindConVar("sv_force_normal_respawn")!=INVALID_HANDLE) SetConVarInt(FindConVar("sv_force_normal_respawn"), 1)

	//At the start of a versus or scavenge round, notify infected players they can respawn.
	HookEvent("versus_round_start", Event_RoundStart)
	HookEvent("scavenge_round_start", Event_RoundStart)

	hGameConf = LoadGameConfigFile("l4d2_infevtedrespawn");
	if (hGameConf != INVALID_HANDLE)
	{	
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "BecomeGhost");
		PrepSDKCall_AddParameter(SDKType_PlainOldData , SDKPass_Plain);
		hBecomeGhost = EndPrepSDKCall();

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "BecomeGhostAt");
		PrepSDKCall_AddParameter(SDKType_PlainOldData , SDKPass_Plain);
		hBecomeGhostAt = EndPrepSDKCall();
	}
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i) && GetClientTeam(i)==3)
		{
			PrintToChat(i, "你可以右键切换特感")	
		}
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	//If the player is a ghost and it's not a finale,
	if (GetEntProp(client, Prop_Send, "m_isGhost"))
	{
		//and is pressing MELEE,
		if (buttons & IN_ATTACK2)
		{
			SDKCall(hBecomeGhost, client, 1);
			SDKCall(hBecomeGhostAt, client, 0);
		}
	}
	return Plugin_Continue
}


