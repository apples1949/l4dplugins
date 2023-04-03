#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#include <l4d2_skills>

#define SKILL_NAME "Assistant"

public Plugin myinfo =
{
	name = "[L4D2] Assistant",
	author = "BHaType",
	description = "Speed ups revie and healing process",
	version = "1.1",
	url = "https://github.com/Vinillia/l4d2_skills"
};

BaseSkillExport gExport;

ConVar survivor_revive_duration;
float survivor_revive_duration_base, g_flPower;
int m_isDualWielding, g_iID;
bool g_bLate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	m_isDualWielding = FindSendPropInfo("CBaseRifle", "m_isDualWielding") + 4;
	
	survivor_revive_duration = FindConVar("survivor_revive_duration");
	survivor_revive_duration_base = survivor_revive_duration.FloatValue;
	
	HookEvent("revive_begin", revive_begin);
	HookEvent("heal_begin", heal_begin);
}

public void OnAllPluginsLoaded()
{
	g_iID = Skills_Register(SKILL_NAME, ST_ACTIVATION);

	if (g_bLate)
	{
		Skills_RequestConfigReload();
	}
}

public void revive_begin( Event event, const char[] name, bool dontBroadcast )
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	float duration = survivor_revive_duration_base;
	
	if ( IsHaveSkill(client) )
		duration *= g_flPower;
	
	survivor_revive_duration.FloatValue = duration;
}

public void heal_begin( Event event, const char[] name, bool dontBroadcast )
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	
	if ( !IsHaveSkill(client) )
		return;
	
	int kit = GetPlayerWeaponSlot(client, 3);
	float duration;
	
	if ( kit == -1 )
		return;
	
	duration = GetEntDataFloat(kit, m_isDualWielding) * g_flPower;
	
	SetEntPropFloat(client, Prop_Send, "m_flProgressBarDuration", duration);
	SetEntPropFloat(subject, Prop_Send, "m_flProgressBarDuration", duration);
	
	SetEntDataFloat(kit, m_isDualWielding, duration); 
	SetEntDataFloat(kit, m_isDualWielding + 4, GetGameTime() + duration); 
}

bool IsHaveSkill( int client )
{
	return Skills_ClientHaveByID(client, g_iID);
}

public void Skills_OnGetSettings( KeyValues kv )
{
	EXPORT_START(SKILL_NAME);
	
	EXPORT_SKILL_COST(gExport, 2500.0);
	EXPORT_FLOAT_DEFAULT("power", g_flPower, 0.5);

	EXPORT_FINISH();
}