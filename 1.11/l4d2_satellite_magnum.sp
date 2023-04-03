#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <l4d2_skills>
#include <left4dhooks>

#define SKILL_NAME "Sattelite Magnum"
#define MAX_LEVELS 4

#define SOUND_TRACING	"items/suitchargeok1.wav"
#define SOUND_IMPACT01	"animation/van_inside_hit_wall.wav"
#define SOUND_IMPACT02	"ambient/explosions/explode_3.wav"
#define SOUND_IMPACT03	"ambient/atmosphere/firewerks_burst_01.wav"
#define SOUND_FREEZE	"physics/glass/glass_pottery_break3.wav"
#define SOUND_DEFROST	"physics/glass/glass_sheet_break1.wav"

#define PARTICLE_FIRE01	"molotov_explosion"
#define PARTICLE_FIRE02	"molotov_explosion_child_burst"

public Plugin myinfo =
{
	name = "[L4D2] Satllite Magnum",
	author = "BHaType",
	description = "Adds new weapon to skills menu",
	version = "1.0",
	url = "https://github.com/Vinillia/l4d2_skills"
};

static const char g_szShootSounds[][] =
{ 
	"npc/soldier1/misc17.wav",
	"npc/soldier1/misc19.wav",
	"npc/soldier1/misc20.wav",
	"npc/soldier1/misc21.wav",
	"npc/soldier1/misc22.wav",
	"npc/soldier1/misc23.wav",
	"npc/soldier1/misc08.wav",
	"npc/soldier1/misc02.wav",
	"npc/soldier1/misc07.wav"
};

enum SATELITE_TYPE
{
	SATELITE_NONE,
	SATELITE_JUDGEMENT,
	SATELITE_INFERNO,
	SATELITE_FREEZE,
}

enum struct PlayerSatellite
{
	SATELITE_TYPE type;
	bool frozen;

	float last_inferno_use;
	float last_freeze_use;
	float last_judgement_use;
}

enum struct SatelliteExport
{
	BaseSkillExport base;

	float inferno_damage_specials;
	float inferno_damage_survivors;
	float inferno_radius;

	float freeze_radius;
	float freeze_duration;

	float judgement_damage_specials;
	float judgement_damage_survivors;
	float judgement_radius;

	float inferno_cooldown;
	float freeze_cooldown;
	float judgement_cooldown;
}

Menu g_hMenu;
SatelliteExport gExport;
bool g_bLate;
int g_iHaloMaterial, g_iLaserMaterial, g_iGlowMaterial;
int g_iID;

PlayerSatellite g_Sattelite[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hMenu = new Menu(MenuHandler);

	//g_hMenu.AddItem("", "None");
	g_hMenu.AddItem("", "无");
	//g_hMenu.AddItem("", "Judgement");
	g_hMenu.AddItem("", "审判");
	//g_hMenu.AddItem("", "Inferno");
	g_hMenu.AddItem("", "地狱");
	//g_hMenu.AddItem("", "Freeze");
	g_hMenu.AddItem("", "冻结");
	//g_hMenu.SetTitle("Choose satellite type:");
	g_hMenu.SetTitle("选择卫星类型:");

	RegConsoleCmd("sm_satellite_change", sm_satellite_change);
	RegConsoleCmd("sm_satellite_info", sm_satellite_info);

	HookEvent("weapon_fire", weapon_fire);
}

public void OnAllPluginsLoaded()
{
	g_iID = Skills_Register(SKILL_NAME, ST_INPUT, false);

	if (g_bLate)
	{
		Skills_RequestConfigReload();
	}
}

public void Skills_OnGetSettings( KeyValues kv )
{
	EXPORT_START(SKILL_NAME);

	EXPORT_SKILL_COST(gExport.base, 50000.0);

	EXPORT_FLOAT_DEFAULT("inferno_damage_specials", gExport.inferno_damage_specials, 150.0);
	EXPORT_FLOAT_DEFAULT("inferno_damage_survivors", gExport.inferno_damage_survivors, 25.0);
	EXPORT_FLOAT_DEFAULT("inferno_radius", gExport.inferno_radius, 500.0);
	EXPORT_FLOAT_DEFAULT("inferno_cooldown", gExport.inferno_cooldown, 5.0);

	EXPORT_FLOAT_DEFAULT("freeze_radius", gExport.freeze_radius, 150.0);
	EXPORT_FLOAT_DEFAULT("freeze_duration", gExport.freeze_duration, 5.0);
	EXPORT_FLOAT_DEFAULT("freeze_cooldown", gExport.freeze_cooldown, 30.0);
	
	EXPORT_FLOAT_DEFAULT("judgement_damage_specials", gExport.judgement_damage_specials, 150.0);
	EXPORT_FLOAT_DEFAULT("judgement_damage_survivors", gExport.judgement_damage_survivors, 25.0);
	EXPORT_FLOAT_DEFAULT("judgement_radius", gExport.judgement_radius, 500.0);
	EXPORT_FLOAT_DEFAULT("judgement_cooldown", gExport.judgement_cooldown, 15.0);

	EXPORT_FINISH();
}

public void OnMapStart()
{
	for( int i; i < sizeof g_szShootSounds; i++ )
	{
		PrecacheSound(g_szShootSounds[i], true);
	}

	PrecacheSound(SOUND_TRACING, true);
	PrecacheSound(SOUND_IMPACT01, true);
	PrecacheSound(SOUND_IMPACT02, true);
	PrecacheSound(SOUND_IMPACT03, true);
	PrecacheSound(SOUND_FREEZE, true);
	PrecacheSound(SOUND_DEFROST, true);

	Precache_Particle_System(PARTICLE_FIRE01);
	Precache_Particle_System(PARTICLE_FIRE02);

	g_iLaserMaterial = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iHaloMaterial = PrecacheModel("materials/sprites/halo01.vmt");
	g_iGlowMaterial = PrecacheModel("materials/sprites/glow01.vmt");
}

public Action sm_satellite_info(int client, int args)
{
	//Skills_ReplyToCommand(client, "\x04Satellite Freeze\x01: \x04cooldown \x01- \x05%.0f\x01, \x04radius \x01- \x05%.0f\x01, \x04duration \x01 - \x05%.0f", gExport.freeze_cooldown, gExport.freeze_radius, gExport.freeze_duration);
	//Skills_ReplyToCommand(client, "\x04Satellite Judgement\x01: \x04cooldown \x01- \x05%.0f\x01, \x04radius \x01- \x05%.0f\x01, \x04damage \x01- \x05%.0f", gExport.judgement_cooldown, gExport.judgement_radius, gExport.judgement_damage_specials);
	//Skills_ReplyToCommand(client, "\x04Satellite Freeze\x01: \x04cooldown \x01- \x05%.0f\x01, \x04radius \x01- \x05%.0f\x01, \x04damage \x01- \x05%.0f", gExport.inferno_cooldown, gExport.inferno_radius, gExport.inferno_damage_specials);
	Skills_ReplyToCommand(client, "\x04卫星冻结\x01: \x04冷却时间 \x01- \x05%.0f\x01, \x04半径 \x01- \x05%.0f\x01, \x04持续时间 \x01 - \x05%.0f", gExport.freeze_cooldown, gExport.freeze_radius, gExport.freeze_duration);
	Skills_ReplyToCommand(client, "\x04卫星审判\x01: \x04冷却时间 \x01- \x05%.0f\x01, \x04半径 \x01- \x05%.0f\x01, \x04伤害 \x01- \x05%.0f", gExport.judgement_cooldown, gExport.judgement_radius, gExport.judgement_damage_specials);
	Skills_ReplyToCommand(client, "\x04卫星冻结\x01: \x04冷却时间 \x01- \x05%.0f\x01, \x04半径 \x01- \x05%.0f\x01, \x04伤害 \x01- \x05%.0f", gExport.inferno_cooldown, gExport.inferno_radius, gExport.inferno_damage_specials);
	return Plugin_Handled;
}

public Action sm_satellite_change(int client, int args)
{
	if (!IsHaveSkill(client))
	{
		Skills_ReplyToCommand(client, "\x05你\x04必须拥有\x03%s\x04才能使用这个指令", SKILL_NAME);
		return Plugin_Handled;
	}

	g_hMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MenuHandler( Menu menu, MenuAction action, int client, int index )
{
	switch( action )
	{
		case MenuAction_Select:
		{
			SATELITE_TYPE type = view_as<SATELITE_TYPE>(index);
			g_Sattelite[client].type = type;
			//Skills_PrintToChat(client, "\x05You \x03have choosen \x04%s \x03type", GetSatelliteFormat(type));
			Skills_PrintToChat(client, "\x05你\x03选择的是\x04%s\x03类型", GetSatelliteFormat(type));
		}
	}
	
	return 0;
}

public void weapon_fire( Event event, const char[] name, bool noReplicate )
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if ( !client || !IsClientInGame(client) || !IsHaveSkill(client) || IsInCooldown(client) || GetClientTeam(client) != 2 || IsFakeClient(client) || g_Sattelite[client].frozen )
		return;

	if (g_Sattelite[client].type == SATELITE_NONE)
		return;

	char classname[32];
	int weapon;

	weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	GetEntityClassname(weapon, classname, sizeof classname);

	if (weapon == -1 || strcmp(classname, "weapon_pistol_magnum") != 0)
		return;

	float vOrigin[3], vAngles[3], vEnd[3];

	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	TR_TraceRayFilter(vOrigin, vAngles, CONTENTS_SOLID | CONTENTS_MOVEABLE, RayType_Infinite, TraceFilter, client);
	
	if( !TR_DidHit() )
		return;
	
	TR_GetEndPosition(vEnd);

	int sound = GetRandomInt(0, 8);
	EmitSoundToAll(g_szShootSounds[sound], client);	

	EmitAmbientSound(SOUND_TRACING, vEnd);
	CreateLaserEffect(vOrigin, vEnd, {255, 255, 255, 255}, 0.2, 1.0, 0.5);
	CreateSparkEffect(vEnd, 1200, 5);

	DataPack pack;

	CreateDataTimer(0.2, timer_magnum_satelite, pack, TIMER_DATA_HNDL_CLOSE);

	pack.WriteCell(GetClientUserId(client));
	pack.WriteCellArray(vEnd, sizeof vEnd);

	SetEntProp(weapon, Prop_Send, "m_iClip1", 0);
	StartCooldown(client);
}

public Action timer_magnum_satelite( Handle timer, DataPack pack )
{
	pack.Reset();
	
	int client = pack.ReadCell();
	if ( (client = GetClientOfUserId(client)) == 0 )
	{
		return Plugin_Continue;
	}

	DataPack newPack;
	float vOrigin[3];

	pack.ReadCellArray(vOrigin, sizeof vOrigin);
	CreateRingEffect(vOrigin, {150, 150, 230, 230});
	CreateDataTimer(1.0, timer_satellite_implement, newPack, TIMER_DATA_HNDL_CLOSE);

	newPack.WriteCell(GetClientUserId(client));
	newPack.WriteCellArray(vOrigin, sizeof vOrigin);
	return Plugin_Continue;
}

public Action timer_satellite_implement(Handle timer, DataPack pack)
{
	pack.Reset();
	
	int client = pack.ReadCell();
	if ( (client = GetClientOfUserId(client)) == 0 )
		return Plugin_Continue;

	float vOrigin[3];
	pack.ReadCellArray(vOrigin, sizeof vOrigin);

	Satellite(client, vOrigin);
	return Plugin_Continue;
}

void Satellite(int client, float vOrigin[3])
{
	float vStart[3], vVec[3];
	GetClientEyePosition(client, vStart);

	EmitAmbientSound(SOUND_IMPACT01, vOrigin);

	vVec = vOrigin; vVec[2] += 1500.0;
	CreateLaserEffect(vOrigin, vVec, {230, 230, 80, 230}, 0.9, 1.0, 1.0);

	if(g_Sattelite[client].type == SATELITE_JUDGEMENT)
		Judgement(client, vOrigin);
	else if(g_Sattelite[client].type == SATELITE_FREEZE)
		Blizzard(vStart, vOrigin);
	else
		Inferno(client, vOrigin);
}

void Judgement(int client, float vOrigin[3])
{
	float vPos[3];
	for(int i = 1; i <= MaxClients; i++)
	{
		if( i == client || !IsClientInGame(i) || !IsPlayerAlive(i) )
			continue;

		GetClientAbsOrigin(i, vPos);
		if(GetVectorDistance(vPos, vOrigin) <= gExport.judgement_radius)
		{
			if (gExport.judgement_damage_specials && GetClientTeam(i) == 3)
			{
				SDKHooks_TakeDamage(i, client, client, gExport.judgement_damage_specials, DMG_GENERIC);
			}
			else if (gExport.judgement_damage_survivors)
			{
				SDKHooks_TakeDamage(i, client, client, gExport.judgement_damage_survivors, DMG_GENERIC);
			}
		}
	}

	vOrigin[2] += 5.0;
	
	int molotov = L4D_MolotovPrj(0, vOrigin, {0.0, 0.0, 0.0}); 
	SetEntPropEnt(molotov, Prop_Send, "m_hThrower", client); // to bypass epic molotov skill

	PushAway(vOrigin, 500.0, 500.0, 0.5);
}

void Blizzard(float vStart[3], float vOrigin[3])
{
	float vPos[3];
	EmitAmbientSound(SOUND_IMPACT02, vOrigin);

	TE_SetupBeamRingPoint(vOrigin, 10.0, 300.0, g_iLaserMaterial, g_iHaloMaterial, 0, 10, 0.3, 10.0, 0.5, {40, 40, 230, 230}, 400, 0);
	TE_SendToAll();
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if( !IsClientInGame(i) || !IsPlayerAlive(i) || g_Sattelite[i].frozen )
			continue;

		GetClientAbsOrigin(i, vPos);
		if(GetVectorDistance(vPos, vOrigin) <= gExport.freeze_radius)
		{
			if( L4D2_GetPlayerZombieClass(i) != L4D2ZombieClass_Tank )
				FreezePlayer(i, vStart, gExport.freeze_duration);
		}
	}

	PushAway(vOrigin, 500.0, 500.0, 0.5);
}

void Inferno(int client, float vOrigin[3])
{
	float vPos[3];
	
	EmitAmbientSound(SOUND_IMPACT01, vOrigin);
	EmitAmbientSound(SOUND_IMPACT03, vOrigin);

	CreateAttachParticle(vOrigin, PARTICLE_FIRE01);
	CreateAttachParticle(vOrigin, PARTICLE_FIRE02);
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( !IsClientInGame(i) || !IsPlayerAlive(i) )
			continue;

		GetClientEyePosition(i, vPos);
		if( GetVectorDistance(vPos, vOrigin) <= gExport.inferno_radius )
		{
			int team = GetClientTeam(i);

			if( team == 2 )
			{
				ScreenFade(i, 200, 0, 0, 150, 80, 1);
				SDKHooks_TakeDamage(i, client, client, gExport.inferno_damage_survivors, DMG_BURN);
			}
			else if( team == 3 )
			{
				SDKHooks_TakeDamage(i, client, client, gExport.inferno_damage_specials, DMG_BURN);
			}
		}
	}
	
	int entity = -1;

	while( (entity = FindEntityByClassname(entity, "infected")) != -1 )
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
		if ( GetVectorDistance(vOrigin, vPos) <= gExport.inferno_radius )
		{
			SDKHooks_TakeDamage(entity, client, client, 1.0, DMG_BURN);
		}
	}

	PushAway(vOrigin, 500.0, 500.0, 0.5);
}

void StartCooldown(int client)
{
	float duration;
	DataPack pack;

	if (g_Sattelite[client].type == SATELITE_INFERNO)
	{
		duration = gExport.inferno_cooldown;
		g_Sattelite[client].last_inferno_use = GetGameTime();
	}
	else if (g_Sattelite[client].type == SATELITE_FREEZE)
	{
		duration = gExport.freeze_cooldown;
		g_Sattelite[client].last_freeze_use = GetGameTime();
	}
	else
	{
		duration = gExport.judgement_cooldown;
		g_Sattelite[client].last_judgement_use = GetGameTime();
	}

	if (!duration)
		return;

	CreateDataTimer(duration, timer_satellite_cooldown, pack, TIMER_DATA_HNDL_CLOSE);

	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(g_Sattelite[client].type);
}

public Action timer_satellite_cooldown(Handle timer, DataPack pack)
{
	pack.Reset();
	
	int client = pack.ReadCell();
	if ( (client = GetClientOfUserId(client)) == 0 )
		return Plugin_Continue;

	SATELITE_TYPE type = pack.ReadCell();

	//Skills_PrintToChat(client, "\x04%s \x05cooldown has ended", GetSatelliteFormat(type));
	Skills_PrintToChat(client, "\x04%s\x05的冷却时间已结束", GetSatelliteFormat(type));
	return Plugin_Continue;
}

char[] GetSatelliteFormat(SATELITE_TYPE type)
{
	char szType[32];

	switch(type)
	{
		case SATELITE_FREEZE: szType = "Freeze";
		case SATELITE_INFERNO: szType = "Inferno";
		case SATELITE_JUDGEMENT: szType = "Judgement";
		case SATELITE_NONE: szType = "default";
	}

	return szType;
}

bool IsInCooldown(int client)
{
	SATELITE_TYPE type = g_Sattelite[client].type;

	if (type == SATELITE_FREEZE)
		return GetGameTime() - g_Sattelite[client].last_freeze_use <= gExport.freeze_cooldown;
	else if (type == SATELITE_INFERNO)
		return GetGameTime() - g_Sattelite[client].last_inferno_use <= gExport.inferno_cooldown;
	
	return GetGameTime() - g_Sattelite[client].last_judgement_use <= gExport.judgement_cooldown;
}

void CreateRingEffect(const float vOrigin[3], int color[4], float startRadius = 300.0, float endRadius = 10.0, float width = 4.0, float duration = 1.2, float amplitude = 0.5)
{
	TE_SetupBeamRingPoint(vOrigin, startRadius, endRadius, g_iLaserMaterial,
						g_iLaserMaterial, 0, 10, duration, width, amplitude,
						color, 80, 0);
	TE_SendToAll();
}

void CreateSparkEffect(const float vOrigin[3], int size, int length)
{
	float velocity[3];
	
	for(int i; i < 3; i++)
		velocity[i] = GetRandomFloat();
	
	TE_SetupSparks(vOrigin, velocity, size, length);
	TE_SendToAll();
}

void CreateLaserEffect(const float vStart[3], const float vEnd[3], const int color[4], float duration, float amplitude, float width)
{
	TE_SendBeam(vStart, vEnd, duration, amplitude, width, color);

	TE_SetupGlowSprite(vStart, g_iLaserMaterial, 1.5, 2.8, 230);
	TE_SendToAll();
}

public bool TraceFilter( int entity, int mask, int data )
{
	return entity > MaxClients || !entity;
}

void FreezePlayer(int client, float vOrigin[3], float time)
{
	g_Sattelite[client].frozen = true;
	SetEntityMoveType(client, MOVETYPE_NONE);
	SetEntityRenderColor(client, 0, 128, 255, 135);
	ScreenFade(client, 0, 128, 255, 192, 2000, 1);
	EmitAmbientSound(SOUND_FREEZE, vOrigin, client, SNDLEVEL_RAIDSIREN);
	TE_SetupGlowSprite(vOrigin, g_iGlowMaterial, time, 0.5, 130);
	TE_SendToAll();
	CreateTimer(time, timer_unfreeze_client, GetClientUserId(client));
}

public Action timer_unfreeze_client(Handle timer, int client)
{
	if ( (client = GetClientOfUserId(client)) == 0 )
		return Plugin_Continue;

	g_Sattelite[client].frozen = false;
	float vOrigin[3];
	GetClientAbsOrigin(client, vOrigin);

	EmitAmbientSound(SOUND_DEFROST, vOrigin, client, SNDLEVEL_RAIDSIREN);
	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntityRenderColor(client, 255, 255, 255, 255);
	ScreenFade(client, 0, 0, 0, 0, 0, 1);
	return Plugin_Continue;
}

void PushAway(float vOrigin[3], float force, float radius, float duration)
{
	int point_push = CreateEntityByName("point_push");
	
	DispatchKeyValue(point_push, "spawnflags", "24");
	DispatchKeyValueFloat(point_push, "magnitude", force);
	DispatchKeyValueFloat(point_push, "radius", radius);
	TeleportEntity(point_push, vOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(point_push);
	AcceptEntityInput(point_push, "Enable", -1, -1);

	RemoveEntityTimed(point_push, duration);
}

void CreateAttachParticle(float vOrigin[3], const char[] name, int iEntity = -1, float vAngles[3] = {0.0, 0.0, 0.0})
{
	int entity = CreateEntityByName("info_particle_system");
	
	if (entity == -1)
	{
		LogError("Inalid entity %i", entity);
		return;
	}
	
	DispatchKeyValue(entity, "effect_name", name);
	
	if (iEntity != -1)
	{
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", iEntity);
	}
	
	DispatchSpawn(entity);
	ActivateEntity(entity);
	
	if (iEntity == -1) 
		TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);
	else
		TeleportEntity(entity, view_as<float>({0.0, 0.0, 0.0}), vAngles, NULL_VECTOR);
		
	AcceptEntityInput(entity, "start");
	
	RemoveEntityTimed(entity, 9.0);
}

void RemoveEntityTimed( int entity, float time = 0.0 )
{
	if ( time == 0.0 )
	{
		RemoveEntity(entity);
		return;
	}
	
	char output[36];
	Format(output, sizeof(output), "OnUser1 !self:KillHierarchy::%f:1", time);
	SetVariantString(output);
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
}

void TE_SendBeam( const float vStart[3], const float vEnd[3], float aliveTime, float amplitude, float width, const int color[4] )
{
	TE_SetupBeamPoints(vStart, vEnd, g_iLaserMaterial, g_iHaloMaterial, 0, 0, aliveTime, amplitude, width, 1, 0.0, color, 0);
	TE_SendToAll();
}

void ScreenFade(int target, int red, int green, int blue, int alpha, int duration, int type)
{
	Handle msg = StartMessageOne("Fade", target);
	BfWriteShort(msg, 500);
	BfWriteShort(msg, duration);
	if (type == 0)
		BfWriteShort(msg, (0x0002 | 0x0008));
	else
		BfWriteShort(msg, (0x0001 | 0x0010));
	BfWriteByte(msg, red);
	BfWriteByte(msg, green);
	BfWriteByte(msg, blue);
	BfWriteByte(msg, alpha);
	EndMessage();
}

public void Skills_OnStateChangedPrivate(int client, int id, SkillState state)
{
	if (state == SS_PURCHASED)
	{
		int weapon = GetPlayerWeaponSlot(client, 1);

		if (weapon == -1 || !ClassMatchesComplex(weapon, "weapon_pistol_magnum"))
			GivePlayerItem(client, "weapon_pistol_magnum");

		//Skills_PrintToChat(client, "Use !satellite_change to change satellite type");
		Skills_PrintToChat(client, "在聊天框输入!satellite_change更改卫星类型");
	}
}

bool IsHaveSkill( int client )
{
	return Skills_ClientHaveByID(client, g_iID);
}