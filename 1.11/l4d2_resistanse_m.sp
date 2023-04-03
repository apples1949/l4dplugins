#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <l4d2_skills>

#define SKILL_NAME "Resistance"

public Plugin myinfo =
{
	name = "[L4D2] Resistance",
	author = "BHaType",
	description = "Absorbs damage",
	version = "1.1",
	url = "https://github.com/Vinillia/l4d2_skills"
};

enum struct ResistanceExport
{
	BaseSkillExport base;
	bool reflect_damage_to_attacker_on_max_level;
	float reflect_damage_percent;
	float percent_resistance_initial;
	float percent_resistance_for_levels[MAX_SKILL_LEVELS];
}

ResistanceExport gExport;
BaseSkill g_skill[MAXPLAYERS + 1];
bool g_bLate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	Skills_Register(SKILL_NAME, ST_PASSIVE, true);

	if (g_bLate)
	{
		Skills_ForEveryClient(SFF_CLIENTS, HookClientOnTakeDamage);
		Skills_RequestConfigReload();
	}
}

public void OnClientPutInServer(int client)
{
	HookClientOnTakeDamage(client);
}

public Action OnTakeDamage( int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon,
		float damageForce[3], float damagePosition[3], int damagecustom ) 
{
	if (damagetype & DMG_FALL)
		return Plugin_Continue;

	if ( GetClientTeam(victim) != 2 || !attacker )
		return Plugin_Continue;

	if (gExport.reflect_damage_to_attacker_on_max_level && Skills_BaseHasMaxLevel(g_skill[victim], gExport.base))
	{
		float reflect = damage / 100.0 * gExport.reflect_damage_percent;
		SDKHooks_TakeDamage(attacker, victim, victim, reflect, damagetype, weapon, damageForce, damagePosition, true);
	}

	ApplyResistance(victim, damage);
	return Plugin_Changed;
}

void ApplyResistance(int client, float& damage)
{
	int level = Skills_BaseGetLevelAA(g_skill[client]);
	float absorb_value = gExport.percent_resistance_initial;

	if (Skills_IsBaseUpgraded(g_skill[client]))
	{
		absorb_value = gExport.percent_resistance_for_levels[level];
	}
	
	damage -= damage / 100.0 * absorb_value;
}

public void Skills_OnStateChangedPrivate( int client, int id, SkillState state )
{
	if (state == SS_PURCHASED)
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	Skills_BaseUpgrade(g_skill[client]);
	
	if (Skills_BaseHasMaxLevel(g_skill[client], gExport.base))
	{
		//Skills_PrintToChat(client, "\x05You \x01have reached max level of \x03" ... SKILL_NAME ... "\x01. \x05You \x01will \x04reflect \x01damage back to \x04attacker\x01!");
		Skills_PrintToChat(client, "\x05你已经达到了\x04" ... SKILL_NAME ... "\x03最高\x05等级\x01! \x05你将\x03免疫并反射友伤\x01!");
	}
}

public UpgradeImpl Skills_OnUpgradeMenuRequest( int client, int id, int &nextLevel, float &upgradeCost )
{
	return Skills_DefaultUpgradeImpl(g_skill[client], gExport.base, nextLevel, upgradeCost);
}

public bool Skills_OnCanClientUpgrade( int client, int id )
{
	return Skills_DefaultCanClientUpgrade(g_skill[client], gExport.base);
}

public void Skills_OnGetSettings( KeyValues kv )
{
	EXPORT_START(SKILL_NAME);
	
	EXPORT_SKILL_COST(gExport.base, 2500.0);
	EXPORT_SKILL_MAXLEVEL(gExport.base, 3);
	EXPORT_SKILL_UPGRADE_COSTS(gExport.base, { 500.0, 2500.0, 5000.0 });
	
	EXPORT_BOOL_DEFAULT("reflect_damage_to_attacker_on_max_level", gExport.reflect_damage_to_attacker_on_max_level, false);
	EXPORT_FLOAT_DEFAULT("reflect_damage_percent", gExport.reflect_damage_percent, 50.0);
	EXPORT_FLOAT_DEFAULT("percent_resistance_initial", gExport.percent_resistance_initial, 5.0);
	EXPORT_FLOAT_ARRAY_DEFAULT("percent_resistance_for_levels", gExport.percent_resistance_for_levels, gExport.base.maxlevel, { 10.0, 25.0, 50.0 });

	EXPORT_FINISH();
}

bool IsHaveSkill( int client )
{
	return Skills_BaseHasSkill(g_skill[client]);
}

bool ResetClientSkill(int cl)
{
	Skills_BaseReset(g_skill[cl]);
	return true;
}

bool HookClientOnTakeDamage(int client)
{
	if (IsHaveSkill(client))
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	
	return true;
}

public Action Skills_OnStateReset()
{
	Skills_ForEveryClient(SFF_CLIENTS, ResetClientSkill);
	return Plugin_Continue;
}

