#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <l4d2_direct>
//#include <left4dhooks>

public Plugin myinfo =
{
    name = "[L4D2] Double Get-Up Fix",
    author = "Darkid",
    description = "Fixes Get-Ups Being Doubled.",
    version = "3.6",
    url = "https://github.com/jbzdarkid/Double-Getup"
};

ConVar rockPunchFix;

enum PlayerState
{
    UPRIGHT = 0,
    INCAPPED,
    SMOKED,
    JOCKEYED,
    HUNTER_GETUP,
    INSTACHARGED,
    CHARGED,
    CHARGER_GETUP,
    MULTI_CHARGED,
    TANK_ROCK_GETUP,
    TANK_PUNCH_FLY,
    TANK_PUNCH_GETUP,
    TANK_PUNCH_FIX,
    TANK_PUNCH_JOCKEY_FIX,
};

int pendingGetups[MAXPLAYERS + 1] = 0, currentSequence[MAXPLAYERS + 1] = 0;
bool interrupt[MAXPLAYERS+1] = false;
PlayerState playerState[MAXPLAYERS + 1] = view_as<PlayerState>(UPRIGHT);

public void OnPluginStart()
{
    rockPunchFix = CreateConVar("double_get-up_fix-l4d2_rockpunch", "1", "Enable/Disable Rock Punch Fix", FCVAR_NOTIFY);

    HookEvent("round_start", OnRoundStart);
    HookEvent("tongue_grab", OnTongueGrab);
    HookEvent("jockey_ride", OnJockeyRide);
    HookEvent("jockey_ride_end", OnJockeyRideEnd);
    HookEvent("tongue_release", OnTongueRelease);
    HookEvent("pounce_stopped", OnPounceStopped);
    HookEvent("charger_impact", OnChargerImpact);
    HookEvent("charger_carry_end", OnChargerCarryEnd);
    HookEvent("charger_pummel_start", OnChargerPummelStart);
    HookEvent("charger_pummel_end", OnChargerPummelEnd);
    HookEvent("player_incapacitated", OnPlayerIncapacitated);
    HookEvent("revive_success", OnReviveSuccess);
    HookEvent("player_hurt", OnPlayerHurt);
}

public bool isGettingUp(any survivor)
{
	switch (playerState[survivor])
	{
		case (view_as<PlayerState>(HUNTER_GETUP)): return true;
		case (view_as<PlayerState>(CHARGER_GETUP)): return true;
		case (view_as<PlayerState>(MULTI_CHARGED)): return true;
		case (view_as<PlayerState>(TANK_PUNCH_GETUP)): return true;
		case (view_as<PlayerState>(TANK_ROCK_GETUP)): return true;
	}

	return false;
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
			playerState[i] = view_as<PlayerState>(UPRIGHT);
	}
}

public Action OnTongueGrab(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if (playerState[client] == view_as<PlayerState>(HUNTER_GETUP))
		interrupt[client] = true;
}

public Action OnJockeyRide(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	playerState[client] = view_as<PlayerState>(JOCKEYED);
}

public Action OnJockeyRideEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if (playerState[client] == view_as<PlayerState>(JOCKEYED))
		playerState[client] = view_as<PlayerState>(UPRIGHT);
}

public Action OnTongueRelease(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if (playerState[client] == view_as<PlayerState>(INCAPPED))
		return;

	playerState[client] = view_as<PlayerState>(UPRIGHT);
	_CancelGetup(client);
}

public Action OnPounceStopped(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if (playerState[client] == view_as<PlayerState>(INCAPPED))
		return;

	if (isGettingUp(client))
	{
		pendingGetups[client]++;
		return;
	}

	playerState[client] = view_as<PlayerState>(HUNTER_GETUP);
	_GetupTimer(client);
}

public Action OnChargerImpact(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if (playerState[client] == view_as<PlayerState>(INCAPPED))
		return;

	playerState[client] = view_as<PlayerState>(MULTI_CHARGED);
}

public Action OnChargerCarryEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if (playerState[client] == view_as<PlayerState>(INCAPPED))
		pendingGetups[client]++;

	playerState[client] = view_as<PlayerState>(INSTACHARGED);
}

public Action OnChargerPummelStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if (playerState[client] == view_as<PlayerState>(INCAPPED))
		return;

	playerState[client] = view_as<PlayerState>(CHARGED);
}

public Action OnChargerPummelEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if (playerState[client] == view_as<PlayerState>(INCAPPED))
		return;

	playerState[client] = view_as<PlayerState>(CHARGER_GETUP);
	_GetupTimer(client);
}

public Action OnPlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	if (playerState[client] == view_as<PlayerState>(INSTACHARGED))
		pendingGetups[client]++;

	playerState[client] = view_as<PlayerState>(INCAPPED);
}

public Action OnReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	playerState[client] = view_as<PlayerState>(UPRIGHT);
	_CancelGetup(client);
}

public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (victim <= 0 || victim > MaxClients || !IsClientInGame(victim) || GetClientTeam(victim) != 2 || !IsPlayerAlive(victim))
		return Plugin_Continue;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (IsTank(attacker))
	{
		char pWeapon[32];
		event.GetString("weapon", pWeapon, 32);
		if (StrEqual(pWeapon, "tank_claw", true))
		{
			if (playerState[victim] == view_as<PlayerState>(CHARGER_GETUP))
				interrupt[victim] = true;
			else if (playerState[victim] == view_as<PlayerState>(MULTI_CHARGED))
				pendingGetups[victim]++;

			if (playerState[victim] == view_as<PlayerState>(TANK_ROCK_GETUP) && GetConVarBool(rockPunchFix))
				playerState[victim] = view_as<PlayerState>(TANK_PUNCH_FIX);
			else if (playerState[victim] == view_as<PlayerState>(JOCKEYED))
			{
			    playerState[victim] = view_as<PlayerState>(TANK_PUNCH_JOCKEY_FIX);
			    _TankLandTimer(victim);
			}
			else
			{
			    playerState[victim] = view_as<PlayerState>(TANK_PUNCH_FLY);
			    _TankLandTimer(victim);
		    }
		}
		else if (StrEqual(pWeapon, "tank_rock", true))
		{
			if (playerState[victim] == view_as<PlayerState>(CHARGER_GETUP))
				interrupt[victim] = true;
			else if (playerState[victim] == view_as<PlayerState>(MULTI_CHARGED))
				pendingGetups[victim]++;

			playerState[victim] = view_as<PlayerState>(TANK_ROCK_GETUP);
			_GetupTimer(victim);
		}
	}

	return Plugin_Continue;
}

void _TankLandTimer(int client)
{
	CreateTimer(0.04, TankLandTimer, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action TankLandTimer(Handle timer, any client)
{
	int tankFlyAnim = RetrieveAnimData(client);
	if (tankFlyAnim == 0)
		return Plugin_Stop;

	if (GetEntProp(client, Prop_Send, "m_nSequence") == tankFlyAnim || GetEntProp(client, Prop_Send, "m_nSequence") == tankFlyAnim + 1)
		return Plugin_Continue;

	if (playerState[client] == view_as<PlayerState>(TANK_PUNCH_JOCKEY_FIX))
	{
		if (GetEntProp(client, Prop_Send, "m_nSequence") == tankFlyAnim + 2)
			return Plugin_Continue;

		L4D2Direct_DoAnimationEvent(client, 96);
	}

	if (playerState[client] == view_as<PlayerState>(TANK_PUNCH_FLY))
		playerState[client] = view_as<PlayerState>(TANK_PUNCH_GETUP);

	_GetupTimer(client);
	return Plugin_Stop;
}

void _GetupTimer(int client)
{
	CreateTimer(0.04, GetupTimer, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action GetupTimer(Handle timer, any client)
{
	if (currentSequence[client] == 0)
	{
		currentSequence[client] = GetEntProp(client, Prop_Send, "m_nSequence");
		pendingGetups[client]++;
		return Plugin_Continue;
	}
	else if (interrupt[client])
	{
		interrupt[client] = false;
		return Plugin_Stop;
	}

	if (currentSequence[client] == GetEntProp(client, Prop_Send, "m_nSequence"))
		return Plugin_Continue;
	else if (playerState[client] == view_as<PlayerState>(TANK_PUNCH_FIX))
	{
		L4D2Direct_DoAnimationEvent(client, 96);
		playerState[client] = view_as<PlayerState>(TANK_PUNCH_GETUP);
		currentSequence[client] = 0;
		_TankLandTimer(client);
		return Plugin_Stop;
	}
	else
	{
		playerState[client] = view_as<PlayerState>(UPRIGHT);
		pendingGetups[client]--;

		_CancelGetup(client);
		return Plugin_Stop;
	}
}

void _CancelGetup(int client)
{
	CreateTimer(0.04, CancelGetup, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action CancelGetup(Handle timer, any client)
{
	if (pendingGetups[client] <= 0)
	{
		pendingGetups[client] = 0;
		currentSequence[client] = 0;
		return Plugin_Stop;
	}

	pendingGetups[client]--;
	SetEntPropFloat(client, Prop_Send, "m_flCycle", 1000.0);

	return Plugin_Continue;
}

stock int RetrieveAnimData(int client)
{
	int animPlayed = 0;

	char currentModel[64];
	GetEntPropString(client, Prop_Data, "m_ModelName", currentModel, 64);
	if (strcmp(currentModel, "models/survivors/survivor_coach.mdl") == 0 || strcmp(currentModel, "models/survivors/survivor_gambler.mdl") == 0)
		animPlayed = 628;
	else if (strcmp(currentModel, "models/survivors/survivor_producer.mdl") == 0)
		animPlayed = 636;
	else if (strcmp(currentModel, "models/survivors/survivor_mechanic.mdl") == 0)
		animPlayed = 633;
	else if (strcmp(currentModel, "models/survivors/survivor_manager.mdl") == 0 || strcmp(currentModel, "models/survivors/survivor_namvet.mdl") == 0)
		animPlayed = 536;
	else if (strcmp(currentModel, "models/survivors/survivor_teenangst.mdl") == 0)
		animPlayed = 545;
	else if(strcmp(currentModel, "models/survivors/survivor_biker.mdl") == 0)
		animPlayed = 539;

	return animPlayed;
}

bool IsTank(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && IsPlayerAlive(client));
}
