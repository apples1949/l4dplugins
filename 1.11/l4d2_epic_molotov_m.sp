#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <l4d2_skills>
#include <left4dhooks>

#define SKILL_NAME "Epic Molotov"

public Plugin myinfo =
{
	name = "[L4D2] Epic Molotov",
	author = "BHaType",
	description = "Spawns additional molotovs after throwing",
	version = "1.2",
	url = "https://github.com/Vinillia/l4d2_skills"
};

enum struct EpicMolotovExport
{
	BaseSkillExport base;
	int initialCount;
	
	float power;
	float minScale;
	float maxScale;
	float cooldown;
}

enum struct EpicMolotov 
{
	BaseSkill base;
	bool hascooldown;
}

EpicMolotovExport gExport;
EpicMolotov g_skill[MAXPLAYERS + 1];
bool g_bBlockEndlessCycle, g_bLate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("molotov_thrown", molotov_thrown);
}

public void OnAllPluginsLoaded()
{
	Skills_Register(SKILL_NAME, ST_ACTIVATION, true);
	
	if (g_bLate)
		Skills_RequestConfigReload();
}

public void molotov_thrown( Event event, const char[] name, bool noReplicate )
{
	if ( g_bBlockEndlessCycle )
		return;
		
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if ( !IsHaveSkill(client) || g_skill[client].hascooldown )
		return;
	
	float vOrigin[3], vAngles[3], vVelocity[3];
	int entity, count;
	
	g_bBlockEndlessCycle = true;
	count = GetClientMolotovCount(client); 
	
	for( int i; i < count; i++ )
	{
		GetMolotovVectors(client, vOrigin, vVelocity);
		ScaleVector(vVelocity, gExport.power * GetRandomFloat(gExport.minScale, gExport.maxScale));
		entity = L4D_MolotovPrj(client, vOrigin, vAngles);
		TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vVelocity);
	}
	
	g_skill[client].hascooldown = true;
	CreateTimer(gExport.cooldown, timer_cooldown, client);
	g_bBlockEndlessCycle = false;
}

public Action timer_cooldown(Handle timer, int client)
{
	if (IsClientInGame(client))
		//Skills_PrintToChat(client, SKILL_NAME ... " can be used again");
		Skills_PrintToChat(client, SKILL_NAME ... "可以重新使用");

	g_skill[client].hascooldown = false;
	return Plugin_Continue;
}

void GetMolotovVectors( int client, float origin[3], float velocity[3] )
{
	float vOrigin[3], vAngles[3], vFwd[3];
	
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	vAngles[0] += GetRandomFloat(-1.0) * 12.0 ;
	vAngles[1] += GetRandomFloat(-1.0) * 12.0;
	
	GetAngleVectors(vAngles, vFwd, NULL_VECTOR, NULL_VECTOR);
	velocity = vFwd;
	ScaleVector(vFwd, 16.0);
	AddVectors(vOrigin, vFwd, origin);
	
	TR_TraceHull(vOrigin, origin, {-5.0, -5.0, -5.0}, {5.0, 5.0, 5.0}, MASK_SHOT);
	TR_GetEndPosition(origin);
}

int GetClientMolotovCount( int client )
{
	return Skills_BaseGetLevel(g_skill[client].base) + gExport.initialCount;
}

bool IsHaveSkill( int client )
{
	return Skills_BaseHasSkill(g_skill[client].base);
}

bool ResetClientSkill(int cl)
{
	Skills_BaseReset(g_skill[cl].base);
	return true;
}

public void Skills_OnGetSettings( KeyValues kv )
{
	EXPORT_SKILL_START(SKILL_NAME);

	EXPORT_SKILL_COST(gExport.base, 2500.0);
	EXPORT_SKILL_MAXLEVEL(gExport.base, 6);
	EXPORT_SKILL_UPGRADE_COSTS(gExport.base, { 500.0, 1500.0, 2500.0, 3000.0, 5000.0, 6000.0 });
	
	EXPORT_INT_DEFAULT("initial_count", gExport.initialCount, 1);
	EXPORT_FLOAT_DEFAULT("min_scale", gExport.minScale, 0.8);
	EXPORT_FLOAT_DEFAULT("max_scale", gExport.maxScale, 1.2);
	EXPORT_FLOAT_DEFAULT("power", gExport.power, 750.0);
	EXPORT_FLOAT_DEFAULT("cooldown", gExport.cooldown, 15.0);

	EXPORT_FINISH();
}

public void Skills_OnStateChangedPrivate( int client, int id, SkillState state )
{
	Skills_BaseUpgrade(g_skill[client].base);
}

public UpgradeImpl Skills_OnUpgradeMenuRequest( int client, int id, int &nextLevel, float &upgradeCost )
{
	return Skills_DefaultUpgradeImpl(g_skill[client].base, gExport.base, nextLevel, upgradeCost);
}

public bool Skills_OnCanClientUpgrade( int client, int id )
{
	return Skills_DefaultCanClientUpgrade(g_skill[client].base, gExport.base);
}

public Action Skills_OnStateReset()
{
	Skills_ForEveryClient(SFF_CLIENTS, ResetClientSkill);
	return Plugin_Continue;
}