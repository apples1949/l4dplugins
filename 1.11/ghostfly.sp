#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define MOVETYPE_WALK 2
#define MOVETYPE_FLYGRAVITY 5
#define MOVECOLLIDE_DEFAULT 0
#define MOVECOLLIDE_FLY_BOUNCE 1

#define TEAM_INFECTED 3

#define CVAR_FLAGS FCVAR_PLUGIN

#define IS_VALID_CLIENT(%1) (%1 > 0 && %1 <= MaxClients)
#define IS_CONNECTED_INGAME(%1) (IsClientConnected(%1) && IsClientInGame(%1))
#define IS_SURVIVOR(%1) (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1) (GetClientTeam(%1) == 3)

#define IS_VALID_INGAME(%1) (IS_VALID_CLIENT(%1) && IS_CONNECTED_INGAME(%1))

#define IS_VALID_SURVIVOR(%1) (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1) (IS_VALID_INGAME(%1) && IS_INFECTED(%1))

#define IS_SURVIVOR_ALIVE(%1) (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1) (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))

new Handle:GhostFly;
new bool:g_bEnabled = false;
new bool:g_bMustTouchGround = true;
new Handle:FlySpeed;
new Float:g_fFlySpeed = 50.0;
new Handle:MaxSpeed;
new Float:g_fMaxSpeed = 500.0;

new bool:Flying[MAXPLAYERS+1] = false;
new bool:BlockSpawn[MAXPLAYERS+1] = false;

#define PLUGIN_VERSION "1.1.1a"

public Plugin:myinfo =
{
	name = "L4D Ghost Fly",
	author = "Madcap (modified by dcx2)",
	description = "Fly as a ghost.",
	version = PLUGIN_VERSION,
	url = "http://maats.org"
}


public OnPluginStart()
{
	GhostFly = CreateConVar("l4d_ghost_fly", "1", "打开/关闭灵魂飞行的能力，2则无法在飞行时活出来.",CVAR_FLAGS,true,0.0,true,2.0);
	FlySpeed = CreateConVar("l4d_ghost_fly_speed", "50", "飞行速度.",CVAR_FLAGS,true,0.0);
	MaxSpeed = CreateConVar("l4d_ghost_max_speed", "500", "飞行最大速度", CVAR_FLAGS, true, 300.0);

	HookConVarChange(GhostFly, OnGhostFlyChanged);
	HookConVarChange(FlySpeed, OnFlySpeedChanged);
	HookConVarChange(MaxSpeed, OnMaxSpeedChanged);
	
	AutoExecConfig(true, "sm_plugin_ghost_fly");
	
	g_bEnabled = GetConVarInt(GhostFly) > 0;
	g_bMustTouchGround = GetConVarInt(GhostFly) < 2;
	g_fFlySpeed = GetConVarFloat(FlySpeed);
	g_fMaxSpeed = GetConVarFloat(MaxSpeed);
	
	CreateConVar("l4d_ghost_fly_version", PLUGIN_VERSION, " Ghost Fly Plugin Version ", FCVAR_REPLICATED|FCVAR_NOTIFY);

	HookEvent("ghost_spawn_time", EventGhostNotify2);
	HookEvent("player_first_spawn", EventGhostNotify1);
}

public OnGhostFlyChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_bEnabled = StringToInt(newVal) > 0;
	g_bMustTouchGround = StringToInt(newVal) == 1;
}

public OnFlySpeedChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
	g_fFlySpeed = StringToFloat(newVal);

public OnMaxSpeedChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
	g_fMaxSpeed = StringToFloat(newVal);

public OnClientConnected(client)
{
	Flying[client] = false;
	BlockSpawn[client] = false;
}

// moving this outside of to save initialization,
new bool:elig;

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (g_bEnabled)
	{
		elig = IS_VALID_INFECTED(client) && IsPlayerGhost(client);
		
		// If we are spawn blocking, and we are either not eligible or we're on the ground, unblock spawn
		if (BlockSpawn[client] && (!elig || GetEntProp(client, Prop_Send, "m_fFlags") & FL_ONGROUND))
		{
			BlockSpawn[client] = false;
		}
		
		if (g_bMustTouchGround && elig && BlockSpawn[client])
		{
			buttons &= ~IN_ATTACK;
		}
		
		if (elig && buttons & IN_RELOAD)
		{
			if (Flying[client]) KeepFlying(client);
			else StartFlying(client);
		}
		else if (Flying[client]) StopFlying(client);
	}
}

stock bool:IsPlayerGhost(client)
{
	return (GetEntProp(client, Prop_Send, "m_isGhost", 1) > 0);
}

public Action:StartFlying(client)
{
	Flying[client]=true;
	if (g_bMustTouchGround && !GetAdminFlag(GetUserAdmin(client), Admin_Root)) BlockSpawn[client] = true;
	SetMoveType(client, MOVETYPE_FLYGRAVITY, MOVECOLLIDE_FLY_BOUNCE);
	AddVelocity(client, g_fFlySpeed);
	return Plugin_Continue;
}

public Action:KeepFlying(client)
{
	AddVelocity(client, g_fFlySpeed);
	return Plugin_Continue;
}

public Action:StopFlying(client)
{
	Flying[client]=false;
	SetMoveType(client, MOVETYPE_WALK, MOVECOLLIDE_DEFAULT);
	return Plugin_Continue;
}

AddVelocity(client, Float:speed)
{
	new Float:vecVelocity[3];
	GetEntityVelocity(client, vecVelocity);
	vecVelocity[2] += speed;
	if ((vecVelocity[2]) > g_fMaxSpeed) vecVelocity[2] = g_fMaxSpeed;

	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vecVelocity);
}

stock GetEntityVelocity(entity, Float:fVelocity[3])
{
    GetEntPropVector(entity, Prop_Data, "m_vecVelocity", fVelocity);
}  

SetMoveType(client, movetype, movecollide)
{
	SetEntProp(client, Prop_Send, "movecollide", movecollide);
	SetEntProp(client, Prop_Send, "movetype", movetype);
}

public Action:EventGhostNotify1(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	Notify(client,0);
}

public Action:EventGhostNotify2(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	Notify(client,GetEventInt(event, "spawntime"));
}

public Notify(client,time)
{
	CreateTimer((3.0+time), NotifyClient, client);
}

public Action:NotifyClient(Handle:timer, any:client)
{
	if (IS_VALID_INFECTED(client) && IsPlayerGhost(client)){
		PrintToChat(client, "灵魂状态下你可以按住换弹键飞行");
	}

}
