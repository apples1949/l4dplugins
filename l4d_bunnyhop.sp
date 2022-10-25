#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.1"
#define CUESOUND "level/popup.wav"

new Handle:hMode = INVALID_HANDLE;
new Handle:hMultiplier = INVALID_HANDLE;
new Handle:hLimit = INVALID_HANDLE;
new Handle:hOffset = INVALID_HANDLE;

new bool:bCueAllowed[MAXPLAYERS+1] = false;
new bool:bBunnyhopOff[MAXPLAYERS+1] = false;
new iOffset = 0;
new iDirectionCache[MAXPLAYERS+1] = 0;

public Plugin:myinfo=
{
	name="bunnyhop+",
	author="coleo",
	description="A fully featured bunnyhop plugin for Left",
	version=PLUGIN_VERSION,
	url=""
}

public OnPluginStart()
{
	CreateConVar("l4d_bunnyhop_version", PLUGIN_VERSION, "version of bunnyhop+", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	hMode = CreateConVar("l4d_bunnyhop_mode",
		"1.0",
		"Plugin mode: (0)禁用插件 (1)自动连跳 (2)连跳训练",
		FCVAR_PLUGIN,true,0.0,true,2.0);

	hMultiplier = CreateConVar("l4d_bunnyhop_multiplier",
		"22.0",
		"设置每次成功连跳时乘以横向速度增益的数值",
		FCVAR_PLUGIN,true,0.0,true,200.0);

	hLimit = CreateConVar("l4d_bunnyhop_limit",
		"500.0",
		"设定玩家的速度值，在这个速度值上，横向速度不再乘以横向速度",
		FCVAR_PLUGIN,true,0.0,true,500.0);

	hOffset = CreateConVar("l4d_bunnyhop_delay",
		"0",
		"提示音偏移：对于连跳训练模式，设置整数值以确定多早听到提示音。更高的值意味着更早的提示。",
		FCVAR_PLUGIN,true,0.0,true,5.0);


	HookConVarChange(hOffset, ConVar_Delay);
	HookEvent("player_jump_apex", Event_PlayerJumpApex);
	RegConsoleCmd("sm_bp", Command_Autobhop);
	RegConsoleCmd("sm_hop", Command_Autobhop);
	RegConsoleCmd("sm_bhop", Command_Autobhop);
	RegConsoleCmd("sm_bunny", Command_Autobhop);
	RegConsoleCmd("sm_bunnyhop", Command_Autobhop);

	AutoExecConfig(false, "bunnyhop");
}

public ConVar_Delay(Handle:convar, const String:oldValue[], const String:newValue[])
{
	iOffset = StringToInt(newValue);
}

public OnMapStart()
{
	PrecacheSound(CUESOUND, true);
	iOffset = GetConVarInt(hOffset);
}

public Action:Command_Autobhop(client, args)
{	
	if (GetConVarInt(hMode) == 1
		&& client > 0
		&& IsClientInGame(client)
		&& IsPlayerAlive(client))
	{
		if (bBunnyhopOff[client] == true)
		{
			bBunnyhopOff[client] = false;
			PrintHintText(client, "连跳插件\n已启用");
		}
		else
		{
			bBunnyhopOff[client] = true;
			PrintHintText(client, "连跳插件\n已禁用");
		}
	}
	return Plugin_Handled;
}

public Action:OnPlayerRunCmd(client, &buttons)
{
	if (GetConVarInt(hMode) == 1
		&& !bBunnyhopOff[client]
		&& IsClientInGame(client)
		&& IsPlayerAlive(client))
	{
		if (buttons & IN_JUMP)
		{
			if (!(GetEntityFlags(client) & FL_ONGROUND) && !(GetEntityMoveType(client) & MOVETYPE_LADDER))
			{
				if (GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2) buttons &= ~IN_JUMP;
			}
		}
	}
	return Plugin_Continue;
}

public OnGameFrame()
{
	if (!IsServerProcessing()
		|| GetConVarInt(hMode) != 2)
		return;
	for (new i=1 ; i<=MaxClients ; i++)
	{
		if (!bBunnyhopOff[i]
			&& IsClientInGame(i)
			&& IsPlayerAlive(i)
			&& bCueAllowed[i]
			&& GetEntProp(i, Prop_Data, "m_nWaterLevel") < 1 + iOffset)
		{
			bCueAllowed[i] = false;
			EmitSoundToClient(i, CUESOUND);
		}	
	}
}

public Event_PlayerJumpApex(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iMode = GetConVarInt(hMode);
	if (iMode == 0) return;
	new client=GetClientOfUserId(GetEventInt(event,"userid"));
	if (!IsClientInGame(client)
		|| GetClientTeam(client)!= 2
		|| !IsPlayerAlive(client)
		|| bBunnyhopOff[client])
		return;
	
	if (iMode == 2) bCueAllowed[client] = true;
	
	if ((GetClientButtons(client) & IN_MOVELEFT)
		|| (GetClientButtons(client) & IN_MOVERIGHT))
	{	
		if (GetClientButtons(client) & IN_MOVELEFT) 
		{
			if (iDirectionCache[client] > -1)
			{
				iDirectionCache[client] = -1;
				return;
			}
			else iDirectionCache[client] = -1;
		}
		else if (GetClientButtons(client) & IN_MOVERIGHT)
		{
			if (iDirectionCache[client] < 1)
			{
				iDirectionCache[client] = 1;
				return;
			}
			else iDirectionCache[client] = 1;
		}
		new Float:fAngles[3];
		new Float:fLateralVector[3];
		new Float:fForwardVector[3];
		new Float:fNewVel[3];
		
		GetEntPropVector(client, Prop_Send, "m_angRotation", fAngles);
		GetAngleVectors(fAngles, NULL_VECTOR, fLateralVector, NULL_VECTOR);
		NormalizeVector(fLateralVector, fLateralVector);
		
		if (GetClientButtons(client) & IN_MOVELEFT) NegateVector(fLateralVector);

		GetEntPropVector(client, Prop_Data, "m_vecVelocity", fForwardVector);
		if (RoundToNearest(GetVectorLength(fForwardVector)) > GetConVarFloat(hLimit)) return;
		else ScaleVector(fLateralVector, GetVectorLength(fLateralVector) * GetConVarFloat(hMultiplier));
		
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fNewVel);
		for(new i=0;i<3;i++) fNewVel[i] += fLateralVector[i];

		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR,fNewVel);
	}
}