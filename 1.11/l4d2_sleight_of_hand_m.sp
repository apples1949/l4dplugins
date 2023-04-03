#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#include <l4d2_skills>
#include <weaponhandling>

#define SKILL_NAME "Sleight of hand"

public Plugin myinfo =
{
	name = "[L4D2] Sleight of hand",
	author = "BHaType",
	description = "Increases weapon reload and deploy speed",
	version = "1.1",
	url = "https://github.com/Vinillia/l4d2_skills"
};

enum struct SleightOfHandExport
{
	BaseSkillExport base;
	float power;
	float power_for_levels[MAX_SKILL_LEVELS];
}

SleightOfHandExport gExport;
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
		Skills_RequestConfigReload();
}

public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier += GetClientSpeed(client) / 100.0;
}

float GetClientSpeed( int client )
{
	if (!Skills_IsBaseUpgraded(g_skill[client]))
		return gExport.power;

	int level = Skills_BaseGetLevelAA(g_skill[client]);
	return gExport.power_for_levels[level];
}

bool ResetClientSkill(int cl)
{
	Skills_BaseReset(g_skill[cl]);
	return true;
}

public Action Skills_OnStateReset()
{
	Skills_ForEveryClient(SFF_CLIENTS, ResetClientSkill);
	return Plugin_Continue;
}

public void Skills_OnStateChangedPrivate( int client, int id, SkillState state )
{
	Skills_BaseUpgrade(g_skill[client]);
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
	EXPORT_SKILL_UPGRADE_COSTS(gExport.base, { 500.0, 1500.0, 3000.0 });
	
	EXPORT_FLOAT_DEFAULT("initial_power", gExport.power, 5.0);
	EXPORT_FLOAT_ARRAY_DEFAULT("power_for_levels", gExport.power_for_levels, gExport.base.maxlevel, { 15.0, 25.0, 40.0 });

	EXPORT_FINISH();
}