#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define TEAM_INFECTED	3
#define Normal_Speed	1.0

static Handle: hCvarAIladderboost;
static Handle: hCvarPzladderboost;
static Handle: hCvarBoostMultiper;

static bool: bAiSiLadderbooster;
static bool: bPzSiLadderbooster;
static Float: fBoostMultiper;

public Plugin myinfo = 
{
	name = "SI LADDER BOOSTER",
	author = "AiMee,l4d1 port by Harry",
	description = "",
	version = "8.7.7",
	url = "https://github.com/fbef0102/Rotoblin-AZMod/blob/master/SourceCode/scripting-az/l4d2_si_ladder_booster.sp"
};

public void OnPluginStart()
{
	hCvarAIladderboost = CreateConVar("l4d2_ai_ladder_boost", "1", "特感爬梯加速开关(0关，1开)", FCVAR_SPONLY, true, 0.0, true, 1.0);
	hCvarPzladderboost = CreateConVar("l4d2_pz_ladder_boost", "1", "小僵尸爬梯加速开关(0关，1开)", FCVAR_SPONLY, true, 0.0, true, 1.0);
	hCvarBoostMultiper = CreateConVar("l4d2_boost_multiplier", "2.5", "爬梯加速的倍数(小数)", FCVAR_SPONLY, true, 0.0, true, 10.0);
	AutoExecConfig(true, "l4d2_si_ladder_booster");
	HookConVarChange(hCvarAIladderboost, Cvar_OneChanged);
	HookConVarChange(hCvarPzladderboost, Cvar_OneChanged);
	HookConVarChange(hCvarBoostMultiper, Cvar_OneChanged);
	
	Cvar_Changed();
}

public Cvar_OneChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{ 
	Cvar_Changed();
}

public Cvar_Changed()
{
	bAiSiLadderbooster = GetConVarBool(hCvarAIladderboost);
	bPzSiLadderbooster = GetConVarBool(hCvarPzladderboost);
	fBoostMultiper	   = GetConVarFloat(hCvarBoostMultiper);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED && IsPlayerAlive(client))
	{
		if(GetEntityMoveType(client) != MOVETYPE_LADDER)
		{
			// To make sure the SI is boosted only by this plugin.
			if(GetClientSpeed(client) == fBoostMultiper){ SetClientSpeed(client, Normal_Speed); }
			return Plugin_Continue;
		}
		
		if(bAiSiLadderbooster && IsFakeClient(client))
		{		
			SetClientSpeed(client, fBoostMultiper);
			return Plugin_Continue;
		}
		
		if(bPzSiLadderbooster && !IsFakeClient(client) && !IsInfectedGhost(client))
		{
			SetClientSpeed(client, fBoostMultiper);
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

/**
 * Return true if the infected is in ghost (spawn) mode.
 *
 * @param client client ID
 * @return bool
 */
stock bool:IsInfectedGhost(client) {
    return bool:GetEntProp(client, Prop_Send, "m_isGhost");
}

stock SetClientSpeed(client, Float:value)
{
	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", value);
}

stock Float:GetClientSpeed(client)
{
	return Float:GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue");
}