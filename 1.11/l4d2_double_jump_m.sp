#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#include <l4d2_skills>

#define SKILL_NAME "Jumper"

public Plugin myinfo =
{
	name = "[L4D2] Skills Jumper",
	author = "BHaType",
	description = "Adds additional jumps",
	version = "1.1",
	url = "https://github.com/Vinillia/l4d2_skills"
};

enum struct DoubleJumpExport
{
	BaseSkillExport base;
	int number_of_jumps_for_levels[MAX_SKILL_LEVELS];
	float power_of_jumps_for_levels[MAX_SKILL_LEVELS];
	float power_first_level;
	bool enable_no_fall_damage_on_max_level;
}

enum struct DoubleJumpSkill
{
	BaseSkill base;
	int lastButtons;
	int lastFlags;
	int jumps;
}

DoubleJumpExport gExport;
DoubleJumpSkill g_clData[MAXPLAYERS + 1];
bool g_bLate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	Skills_Register(SKILL_NAME, ST_INPUT, true);

	if (g_bLate)
	{
		Skills_RequestConfigReload();
		Skills_ForEveryClient(SFF_CLIENTS, HookClientOnTakeDamage);
	}
}

public void OnClientPutInServer(int client)
{
	HookClientOnTakeDamage(client);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!gExport.enable_no_fall_damage_on_max_level)
	{
		SDKUnhook(victim, SDKHook_OnTakeDamage, OnTakeDamage);
		return Plugin_Continue;
	}

	if (!HasSkill(victim))
		return Plugin_Continue;

	if (!victim || GetClientTeam(victim) != 2)
		return Plugin_Continue;

	if (Skills_BaseHasMaxLevel(g_clData[victim].base, gExport.base))
	{
		if (damagetype & DMG_FALL)
		{
			damage = 0.0;
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd( int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon )
{
	if ( HasSkill(client) )
	{
		Jump(client);
	}
	
	return Plugin_Continue;
}

stock void Jump(int client)
{
	int curFlags = GetEntityFlags(client);
	int curButtons = GetClientButtons(client);
	int lastFlags = g_clData[client].lastFlags;
	int lastButtons = g_clData[client].lastButtons;
	
	if ( lastFlags & FL_ONGROUND )
	{
		if (!(curFlags & FL_ONGROUND) && !(lastButtons & IN_JUMP) && curButtons & IN_JUMP)
		{
			OriginalJump(client);
		}
	}
	else if ( curFlags & FL_ONGROUND )
	{
		Landed(client);
	}
	else if ( !(lastButtons & IN_JUMP) && curButtons & IN_JUMP )
	{
		ReJump(client);
	}

	g_clData[client].lastFlags = curFlags;
	g_clData[client].lastButtons = curButtons;
}

stock void OriginalJump( int client )
{
	g_clData[client].jumps++;
}

stock void Landed( int client )
{
	g_clData[client].jumps = 0;
}

stock void ReJump( int client )
{
	int jumps = g_clData[client].jumps;
	
	if ( jumps >= 1 && jumps <= GetClientJumps(client) )
	{
		g_clData[client].jumps++;
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		
		vVel[2] = GetJumpPower(client);
		
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	}
}

bool HookClientOnTakeDamage(int cl)
{
	if (gExport.enable_no_fall_damage_on_max_level)
		SDKHook(cl, SDKHook_OnTakeDamage, OnTakeDamage);

	return true;
}

int GetClientJumps(int client)
{
	int level = Skills_BaseGetLevelAA(g_clData[client].base);

	if (!Skills_IsBaseUpgraded(g_clData[client].base))
		return 1;

	return gExport.number_of_jumps_for_levels[level];
}

float GetJumpPower(int client)
{
	int level = Skills_BaseGetLevel(g_clData[client].base);
	return gExport.power_first_level + gExport.power_of_jumps_for_levels[level]; 
}

bool HasSkill(int client)
{
	return Skills_BaseHasSkill(g_clData[client].base);
}

bool ResetClientSkill(int cl)
{
	Skills_BaseReset(g_clData[cl].base);
	return true;
}

public Action Skills_OnStateReset()
{
	Skills_ForEveryClient(SFF_CLIENTS, ResetClientSkill);
	return Plugin_Continue;
}

public void Skills_OnGetSettings( KeyValues kv )
{
	EXPORT_SKILL_START(SKILL_NAME);

	EXPORT_SKILL_COST(gExport.base, 2500.0);
	EXPORT_SKILL_MAXLEVEL(gExport.base, 3);
	EXPORT_SKILL_UPGRADE_COSTS(gExport.base, { 1500.0, 2500.0, 5000.0 });

	EXPORT_INT_ARRAY_DEFAULT("number_of_jumps_for_levels", gExport.number_of_jumps_for_levels, gExport.base.maxlevel, { 1, 2, 2 } );
	EXPORT_FLOAT_ARRAY_DEFAULT("power_of_jumps_for_levels", gExport.power_of_jumps_for_levels, gExport.base.maxlevel, { 35.0, 50.0, 70.0 } );
	EXPORT_FLOAT_DEFAULT("power_first_level", gExport.power_first_level, 20.0);
	EXPORT_BOOL_DEFAULT("enable_no_fall_damage_on_max_level", gExport.enable_no_fall_damage_on_max_level, true);
	
	EXPORT_SKILL_FINISH();
}

public void Skills_OnStateChangedPrivate( int client, int id, SkillState state )
{
	Skills_BaseUpgrade(g_clData[client].base);

	if (gExport.enable_no_fall_damage_on_max_level && Skills_BaseHasMaxLevel(g_clData[client].base, gExport.base))
	{
		//Skills_PrintToChat(client, "\x05You have reached \x03max \x05level of \x04" ... SKILL_NAME ... "\x01. \x05All fall damage will be \x03nullified\x01!");
		Skills_PrintToChat(client, "\x05你已经达到了\x04" ... SKILL_NAME ... "\x03最高\x05等级\x01! \x05你将免疫所有\x03坠落伤害\x01!");
	}
}

public UpgradeImpl Skills_OnUpgradeMenuRequest( int client, int id, int &nextLevel, float &upgradeCost )
{
	return Skills_DefaultUpgradeImpl(g_clData[client].base, gExport.base, nextLevel, upgradeCost);
}

public bool Skills_OnCanClientUpgrade( int client, int id )
{
	return Skills_DefaultCanClientUpgrade(g_clData[client].base, gExport.base);
}