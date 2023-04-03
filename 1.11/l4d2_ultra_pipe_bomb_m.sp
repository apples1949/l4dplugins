#pragma newdecls required	
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <l4d2_skills>
#include <left4dhooks>

#define SKILL_NAME "Ultra Pipe Bomb"

public Plugin myinfo =
{
	name = "[L4D2] Ultra Pipe Bomb",
	author = "BHaType",
	description = "Spawns additional pipe bombs after throwing",
	version = "1.1",
	url = "https://github.com/Vinillia/l4d2_skills"
};

enum struct UltraPipeBombExport
{
	BaseSkillExport base;

	int initialCount;
	int glowRange;
	
	float color[3];
	float buyCost;
	float cooldown;
	float power;
	
	int GetColor()
	{
		int r = RoundToNearest(this.color[0]);
		int g = RoundToNearest(this.color[1]);
		int b = RoundToNearest(this.color[2]);
		return r + g * 256 + b * 65536;
	}
}

enum struct UltraPipeBomb
{
	BaseSkill base;
	int active_pipebombs;
}

UltraPipeBombExport gExport;
UltraPipeBomb g_skill[MAXPLAYERS + 1];
bool g_bLate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("grenade_bounce", grenade_bounce);
}

public void OnAllPluginsLoaded()
{
	Skills_Register(SKILL_NAME, ST_ACTIVATION, true);
	
	if (g_bLate)
		Skills_RequestConfigReload();
}

public void grenade_bounce( Event event, const char[] name, bool noReplicate )
{
	int client, entity, hammerid;
	
	client = GetClientOfUserId(event.GetInt("userid"));
	
	if ( !IsHaveSkill(client) || IsClientReachedLimit(client) )
		return;
	
	while ((entity = FindEntityByClassname(entity, "pipe_bomb_projectile")) > MaxClients && GetEntPropEnt(entity, Prop_Send, "m_hThrower") == client)
		break;
	
	hammerid = GetPlayerWeaponSlot(client, 2);
	
	if ( hammerid != -1) 
	{ 
		hammerid = GetEntProp(hammerid, Prop_Data, "m_iHammerID"); 

		if ( hammerid > 1 ) 
			return; 
	} 
	
	if ( entity <= MaxClients )
		return;
		
	float vVelocity[3], vOrigin[3];
	float power;
	
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);
	power = gExport.power;
	
	vVelocity[0] = GetRandomFloat(-1.0) * power;
	vVelocity[1] = GetRandomFloat(-1.0) * power;
	vVelocity[2] = GetRandomFloat() * power;
	
	entity = L4D_PipeBombPrj(client, vOrigin, {0.0, 0.0, 0.0});
	TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, vVelocity);
	
	SetEntProp(entity, Prop_Send, "m_nSolidType", 1);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
	
	if ( gExport.glowRange > 0 )
	{
		SetEntProp(entity, Prop_Send, "m_nGlowRange", gExport.glowRange);
		SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
		SetEntProp(entity, Prop_Send, "m_glowColorOverride", gExport.GetColor());
	}
	
	g_skill[client].active_pipebombs++;
	
	if ( IsClientReachedLimit(client) )
		CreateTimer(gExport.cooldown, timer_cooldown, GetClientUserId(client));
}

public Action timer_cooldown( Handle timer, int client )
{
	if ( (client = GetClientOfUserId(client)) == 0 )
		return Plugin_Continue;
		
	g_skill[client].active_pipebombs = 0;
	//Skills_PrintToChat(client, "\x05%s \x04can be used \x03again", SKILL_NAME);
	Skills_PrintToChat(client, "\x04可以\x03继续\x04使用\x05%s了", SKILL_NAME);
	return Plugin_Continue;
}

bool IsClientReachedLimit( int client )
{
	return g_skill[client].active_pipebombs >= Skills_BaseGetLevel(g_skill[client].base) + gExport.initialCount;
}

bool IsHaveSkill( int client )
{
	return Skills_BaseHasSkill(g_skill[client].base);
}

public void Skills_OnStateChangedPrivate( int client, int id, SkillState state )
{
	Skills_BaseUpgrade(g_skill[client].base);
}

public bool Skills_OnCanClientUpgrade( int client, int id )
{
	return Skills_DefaultCanClientUpgrade(g_skill[client].base, gExport.base);
}

public UpgradeImpl Skills_OnUpgradeMenuRequest( int client, int id, int &nextLevel, float &upgradeCost )
{
	return Skills_DefaultUpgradeImpl(g_skill[client].base, gExport.base, nextLevel, upgradeCost);
}

public void Skills_OnGetSettings( KeyValues kv )
{
	EXPORT_START(SKILL_NAME);
	
	EXPORT_SKILL_COST(gExport.base, 2500.0);
	EXPORT_SKILL_MAXLEVEL(gExport.base, 3);
	EXPORT_SKILL_UPGRADE_COSTS(gExport.base, { 1500.0, 2500.0, 3000.0 });

	EXPORT_FLOAT_DEFAULT("cooldown", gExport.cooldown, 15.0);
	EXPORT_FLOAT_DEFAULT("power", gExport.power, 150.0);
	EXPORT_INT_DEFAULT("initial_bombs_count", gExport.initialCount, 4);
	EXPORT_INT_DEFAULT("glow_range", gExport.glowRange, 500);
	EXPORT_VECTOR_DEFAULT("glow_color", gExport.color, { 255.0, 255.0, 255.0 });
	
	EXPORT_FINISH();
}
