#pragma newdecls required	
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <l4d2_skills>
#include <left4dhooks>

#define SKILL_NAME "Speed Boost"

public Plugin myinfo =
{
	name = "[L4D2] Speed Boost",
	author = "BHaType",
	description = "Increases survivor speed",
	version = "1.1",
	url = "https://github.com/Vinillia/l4d2_skills"
};

enum struct SpeedBostExport
{
	BaseSkillExport base;
	float initial_speed;
	float speed_for_levels[MAX_SKILL_LEVELS];
}

SpeedBostExport gExport;
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

public Action L4D_OnGetCrouchTopSpeed( int target, float &retVal )
{
	return GetClientSpeed(target, retVal, 3.0);
}

public Action L4D_OnGetRunTopSpeed( int target, float &retVal )
{
	return GetClientSpeed(target, retVal, 1.0);
}

public Action L4D_OnGetWalkTopSpeed( int target, float &retVal )
{
	return GetClientSpeed(target, retVal, 2.0);
}

Action GetClientSpeed( int client, float &speed, float factor )
{
	if ( !Skills_BaseHasSkill(g_skill[client]) )
		return Plugin_Continue;
		
	if ( !Skills_IsBaseUpgraded(g_skill[client]) )
	{
		speed = gExport.initial_speed / factor;
		return Plugin_Handled;
	}

	int level = Skills_BaseGetLevelAA(g_skill[client]);
	speed = gExport.speed_for_levels[level] / factor;
	return Plugin_Handled;
}

public void Skills_OnStateChangedPrivate( int client, int id, SkillState state )
{
	Skills_BaseUpgrade(g_skill[client]);
}

public bool Skills_OnCanClientUpgrade( int client, int id )
{
	return Skills_DefaultCanClientUpgrade(g_skill[client], gExport.base);
}

public UpgradeImpl Skills_OnUpgradeMenuRequest( int client, int id, int &nextLevel, float &upgradeCost )
{
	return Skills_DefaultUpgradeImpl(g_skill[client], gExport.base, nextLevel, upgradeCost);
}

public void Skills_OnGetSettings( KeyValues kv )
{
	EXPORT_START(SKILL_NAME);
	
	EXPORT_SKILL_COST(gExport.base, 2500.0);
	EXPORT_SKILL_MAXLEVEL(gExport.base, 3);
	EXPORT_SKILL_UPGRADE_COSTS(gExport.base, { 1500.0, 2500.0, 500.0 });

	EXPORT_FLOAT_DEFAULT("initial_speed", gExport.initial_speed, 230.0);
	EXPORT_FLOAT_ARRAY_DEFAULT("speed_for_levels", gExport.speed_for_levels, gExport.base.maxlevel, { 250.0, 260.0, 270.0 });

	EXPORT_FINISH();
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
