#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <l4d2_skills>

#define SKILL_NAME "Sticky Pipe Bombs"
#define TIME_BEFORE_STICK 0.1

public Plugin myinfo =
{
	name = "[L4D2] Sticky Pipe Bombs",
	author = "BHaType",
	description = "Makes pipe boms stick to world geometry",
	version = "1.1",
	url = "https://github.com/Vinillia/l4d2_skills"
};

BaseSkillExport gExport;
bool g_bLate;
int g_iID;

float g_flSpawntime[2048 + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_iID = Skills_Register(SKILL_NAME, ST_PASSIVE);

	if (g_bLate)
	{
		Skills_RequestConfigReload();
	}
}

public void OnEntityCreated( int entity, const char[] name )
{
	if ( strcmp(name, "pipe_bomb_projectile") == 0 )
		SDKHook(entity, SDKHook_Spawn, OnEntitySpawned);
}

public void OnEntitySpawned( int entity )
{
	RequestFrame(NextFrame, EntIndexToEntRef(entity)); 
}

public void NextFrame( int entity )
{
	if ( (entity = EntRefToEntIndex(entity)) <= MaxClients )
		return;
		
	int client = GetEntPropEnt(entity, Prop_Data, "m_hThrower");
	
	if ( client <= 0 || client > MaxClients || !IsHaveSkill(client) )
		return;
	
	g_flSpawntime[entity] = GetEngineTime();
	SDKHook(entity, SDKHook_Touch, OnTouch);
}

public void OnTouch( int entity, int other )
{
	if (GetEngineTime() - g_flSpawntime[entity] < TIME_BEFORE_STICK)
		return;

	if ( other > 0 )
	{
		SetVariantString("!activator");
		AcceptEntityInput(other, "SetParent", other);
	}
	else
	{
		SetEntityMoveType(entity, MOVETYPE_NONE);
	}
}

bool IsHaveSkill( int client )
{
	return Skills_ClientHaveByID(client, g_iID);
}

public void Skills_OnGetSettings( KeyValues kv )
{
	EXPORT_START(SKILL_NAME);
	
	EXPORT_SKILL_COST(gExport, 2500.0);

	EXPORT_FINISH();
}