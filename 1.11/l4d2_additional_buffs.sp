#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#include <l4d2_skills>
#include <left4dhooks>

#define MAX_BUFFS 8
#define MAX_BUFFS_AT_ONCE 8
#define MAX_BUFF_NAME 64

#define THINK_INVERVAL 0.3

#define MYEXPORT "Additional Buffs"
#define DEFAULT_MODEL "models/items/l4d_gift.mdl"
#define DEFAULT_PICKUP_SOUND "ui/gift_pickup.wav"

public Plugin myinfo =
{
	name = "[L4D2] Additional Buffs",
	author = "BHaType",
	description = "Creates gift after killing specials",
	version = "1.1",
	url = "https://github.com/Vinillia/l4d2_skills"
};

typedef BuffAction = function void( int owner, int picker, Buff buff );

enum struct Buff
{
	char name[MAX_BUFF_NAME];
	char model[PLATFORM_MAX_PATH];
	char pickupSound[PLATFORM_MAX_PATH];

	float alivetime;
	float weight;
	
	bool canRepick;
	
	BuffAction action;
}

enum struct GameBuff
{
	int buffIndex;
	int owner;
	int picker;
	float spawntime;
}

enum struct BuffsSchedule
{
	GameBuff buff;
	int entity;
	float initialOrigin[3];
}

enum struct Globals 
{
	float nothing;
	float weight;
	float gift_glow_color_transfusion;
	float gift_fly_offset;
	float gift_speed;
	float gift_pickup_radius;
	float gift_rotation_speed;
	bool print;
	bool stealing;
}

enum struct SettingsManager
{
	StringMap settings;
	
	void SetValue(const char[] key, any value)
	{
		this.settings.SetValue(key, value);
	}
	
	any GetValue(const char[] key, any defaultValue = 0)
	{
		any value;
		
		if (!this.settings.GetValue(key, value))
			return defaultValue;
		
		return value;
	}

	void ExportInt(KeyValues kv, const char[] key, int defaultValue = 0)
	{
		int value;
		EXPORT_INT_DEFAULT(key, value, defaultValue);
		this.SetValue(key, value);
	}

	void ExportFloat(KeyValues kv, const char[] key, float defaultValue = 0.0)
	{
		float value;		
		EXPORT_FLOAT_DEFAULT(key, value, defaultValue);
		this.SetValue(key, value);
	}
}

BuffsSchedule g_Schedule[MAX_BUFFS_AT_ONCE];
Buff g_Buffs[MAX_BUFFS];

SettingsManager g_SettingsManager;
Globals globals;
int g_iBuffsCount, g_iCurrentBuffs;
Handle g_hThink;

public void OnPluginStart()
{
	g_SettingsManager.settings = new StringMap();
	HookEvent("player_death", player_death);

	RegAdminCmd("sm_additional_buffers_reload", sm_additional_buffers_reload, ADMFLAG_ROOT);
	RegAdminCmd("sm_additional_buffers_test", sm_additional_buffers_test, ADMFLAG_ROOT);
	RegAdminCmd("sm_additional_buffers_give", sm_additional_buffers_give, ADMFLAG_CHEATS);
}

public void OnAllPluginsLoaded()
{
	Skills_RequestConfigReload();
}

public void OnPluginEnd()
{
	RemoveGameBuffs(true);
}

public void OnMapStart()
{
	PrecacheBuffs();
}

public void OnMapEnd()
{
	RemoveGameBuffs(false);
	g_hThink = null;
}

public Action sm_additional_buffers_give(int client, int args)
{
	char buffName[MAX_BUFF_NAME];
	GetCmdArg(1, buffName, sizeof buffName);

	for(int i; i < g_iBuffsCount; i++)
	{
		if (StrContains(g_Buffs[i].name, buffName, false) != -1)
		{
			if (!DispatchSpawnBuff(0, client, i))
				//Skills_ReplyToCommand(client, "Failed to spawn buff");
				Skills_ReplyToCommand(client, "增益生成失败");

			return Plugin_Handled;
		}
	}

	//Skills_ReplyToCommand(client, "Buff %s doesn't exist", buffName);
	Skills_ReplyToCommand(client, "增益%s不存在", buffName);
	return Plugin_Handled;
}

public Action sm_additional_buffers_test(int client, int args)
{
	int []buffsCounter = new int[g_iBuffsCount];
	int count = GetCmdArgInt(1), nothing;
	Buff buff;

	if ( !count || count > 500 )
		count = 500;
	
	Skills_ReplyToCommand(client, "开始测试%i迭代, 增益数量%i", count, g_iBuffsCount);

	for(int i; i < count; i++)
	{
		if ( GetRandomFloat(1.0, 100.0) >= globals.nothing )
		{
			nothing++;
			continue;
		}

		int a = GetRandomBuff();
		buffsCounter[a]++;
	}

	Skills_ReplyToCommand(client, "nothing: %i", nothing);

	for(int i; i < g_iBuffsCount; i++)
	{
		buff = g_Buffs[i];

		Skills_ReplyToCommand(client, "%s: %i", buff.name, buffsCounter[i]);
	}

	return Plugin_Handled;
}

public Action sm_additional_buffers_reload(int client, int args)
{
	Skills_RequestConfigReload();
	return Plugin_Handled;
}

public void player_death( Event event, const char[] name, bool noReplicate )
{
	if ( GetRandomFloat(1.0, 100.0) >= globals.nothing )
		return;
		
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if ( !client || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 3 )
		return;
		
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if ( !attacker || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2 )
		return;
	
	if ( DispatchSpawnBuff(attacker, client, GetRandomBuff()) )
	{
		// hehe
	}
}

void StartThink()
{
	if (g_hThink)
		return;

	g_hThink = CreateTimer(THINK_INVERVAL, timer_think_buffs, .flags = TIMER_REPEAT);
}

public Action timer_think_buffs(Handle timer)
{
	if (g_iCurrentBuffs == 0)
	{
		g_hThink = null;
		return Plugin_Stop;
	}

	int owner, picker;
	Buff buff;

	for(int i; i < g_iCurrentBuffs; i++)
	{
		if (!IsValidEntRef(g_Schedule[i].entity))
		{
			RemoveGameBuff(i);
			i--;
			continue;
		}

		if (CheckPlayersAround(i))
		{
			owner = g_Schedule[i].buff.owner;
			picker = g_Schedule[i].buff.picker;

			if (owner != picker && !globals.stealing)
				continue;

			buff = g_Buffs[g_Schedule[i].buff.buffIndex];

			if (globals.print)
			{
				if (owner != picker)
				{
					//Skills_PrintToChatAll("\x05%N \x04got \x03%s \x04of the \x05%N", picker, buff.name, owner);
					Skills_PrintToChatAll("\x05%N\x04捡到了\x05%N\x04的礼盒得到了\x03%s", picker, owner, buff.name);
				}
				else
				{
					//Skills_PrintToChatAll("\x05%N \x04got \x03%s", picker, buff.name);
					Skills_PrintToChatAll("\x05%N\x04捡了自己的礼盒得到了\x03%s", picker, buff.name);
				} 
			}
			
			if (buff.pickupSound[0] != '\0')
				EmitSoundToAll(buff.pickupSound);
			
			Call_StartFunction(null, buff.action);
			Call_PushCell(owner);
			Call_PushCell(picker);
			Call_PushArray(buff, sizeof(Buff));
			Call_Finish();

			RemoveGameBuff(i);
		}
	}

	return Plugin_Continue;
}

public void OnGameFrame()
{
	if (g_iCurrentBuffs == 0)
		return;

	float vOrigin[3], vAngles[3];
	float offset = GetFlyOffset();
	int color = GetGlowColor(), buffIndex;

	for(int i; i < g_iCurrentBuffs; i++)
	{
		buffIndex = g_Schedule[i].buff.buffIndex;
		if (!IsValidEntRef(g_Schedule[i].entity) || GetGameTime() - g_Schedule[i].buff.spawntime > g_Buffs[buffIndex].alivetime)
		{
			RemoveGameBuff(i--);
			continue;
		}

		int entity = EntRefToEntIndex(g_Schedule[i].entity);

		GetEntPropVector(entity, Prop_Data, "m_angRotation", vAngles); 

		vAngles[1] += globals.gift_rotation_speed;
		vOrigin = g_Schedule[i].initialOrigin; 
		vOrigin[2] += offset;

		TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);
		SetEntProp(entity, Prop_Send, "m_glowColorOverride", color);
	}
}

bool CheckPlayersAround(int buff)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
			continue;

		if (IsClientWithinRadius(i, g_Schedule[buff].initialOrigin))
		{
			g_Schedule[buff].buff.picker = i;
			return true;
		}
	}

	return false;
}

bool IsClientWithinRadius( int client, const float source[3] )
{
	float vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	return GetVectorDistance(vOrigin, source) <= globals.gift_pickup_radius;
}

int GetGlowColor()
{
	static int color[3];

	float curtime = GetGameTime() * globals.gift_glow_color_transfusion;
	color[0] = RoundToNearest(Cosine(curtime + 90) * 100 + 100);
	color[1] = RoundToNearest(Cosine(curtime + 180) * 100 + 100);
	color[2] = RoundToNearest(Cosine(curtime + 270) * 100 + 100);

	return color[0] + color[1] * 256 + color[2] * 65536;
}

float GetFlyOffset()
{
	static float offs;
	static bool down;

	offs = !down ? offs + globals.gift_speed : offs - globals.gift_speed;

	float factor = (globals.gift_fly_offset - FloatAbs(offs)) / globals.gift_fly_offset; 
	factor++;

	if (offs >= globals.gift_fly_offset)
		down = true;
	else if(offs <= -globals.gift_fly_offset)
		down = false;

	return offs * factor;
}

bool DispatchSpawnBuff(int client, int initiator, int buffIndex)
{
	if (g_iCurrentBuffs == MAX_BUFFS_AT_ONCE)
		return false;

	float vOrigin[3];
	GetClientAbsOrigin(initiator, vOrigin);

	vOrigin[2] += 30.0;

	int entity = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(entity, "targetname", "skills_buff");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "model", g_Buffs[buffIndex].model);
	TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);

	int i = g_iCurrentBuffs++;

	g_Schedule[i].buff.buffIndex = buffIndex;
	g_Schedule[i].buff.owner = client;
	g_Schedule[i].buff.spawntime = GetGameTime();
	g_Schedule[i].entity = EntIndexToEntRef(entity);
	g_Schedule[i].initialOrigin = vOrigin;
	
	SetEntProp(entity, Prop_Send, "m_nGlowRange", 500);
	SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
	
	StartThink();
	return true;
}

void RemoveGameBuff(int schedule, bool removeEntity = true)
{
	if (removeEntity)
	{
		int entity = g_Schedule[schedule].entity;
	
		if (IsValidEntRef(entity))
		{
			RemoveEntity(EntRefToEntIndex(entity));
		}
	}

	BuffsSchedule nullschedule;
	int i = g_iCurrentBuffs - 1;

	if (schedule != i)
	{
		for(int k = schedule; k < i; k++)
		{
			g_Schedule[k] = g_Schedule[k + 1];
		}
	}

	g_Schedule[i] = nullschedule;
	g_iCurrentBuffs--;
}

void RemoveGameBuffs(bool removeEntity = true)
{
	for(int i; i < g_iCurrentBuffs; i++)
	{
		RemoveGameBuff(i, removeEntity);
		i--;
	}
}

public void OnRegeneration(int owner, int picker, Buff buff)
{
	int regen_maxhealth, regen_add;
	float regen_interval, regen_duration;
	DataPack pack;

	regen_duration = g_SettingsManager.GetValue("regen_duration");
	regen_interval = g_SettingsManager.GetValue("regen_interval");
	regen_maxhealth = g_SettingsManager.GetValue("regen_maxhealth");
	regen_add = g_SettingsManager.GetValue("regen_add");

	CreateDataTimer(regen_interval, timer_regeneration, pack, TIMER_REPEAT | TIMER_DATA_HNDL_CLOSE);

	pack.WriteCell(GetClientUserId(picker));
	pack.WriteCell(regen_maxhealth);
	pack.WriteCell(regen_add);
	pack.WriteFloat(GetGameTime());
	pack.WriteFloat(regen_duration);
}

public Action timer_regeneration(Handle timer, DataPack pack)
{
	int client, maxhealth, add;
	float pickupTime, duration;

	pack.Reset();
	client = GetClientOfUserId(pack.ReadCell());
	maxhealth = pack.ReadCell();
	add = pack.ReadCell();
	pickupTime = pack.ReadFloat();
	duration = pack.ReadFloat();

	if (client == 0 || GetGameTime() - pickupTime > duration)
		return Plugin_Stop;

	int newHealth = GetClientHealth(client) + add;

	if (newHealth > maxhealth)
	{
		SetEntityHealth(client, maxhealth);
		return Plugin_Stop;
	}

	SetEntityHealth(client, newHealth);
	return Plugin_Continue;
}

public void OnTeleport(int owner, int picker, Buff buff)
{
	int []players = new int[MaxClients];
	int count;
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if ( i != picker && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) )
		{
			players[count++] = i;
		}
	}

	if (!count)
		return;

	int survivor = players[GetRandomInt(0, count -1)];
	float dest[3];

	if (g_SettingsManager.GetValue("teleport_allow_backward") && GetRandomFloat() <= 0.5)
	{
		int temp = survivor;
		survivor = picker;
		picker = temp;
	}

	GetClientAbsOrigin(survivor, dest);
	TeleportEntity(picker, dest, NULL_VECTOR, NULL_VECTOR);
	Skills_PrintToChat(picker, "你被传送到%N旁边", survivor);
	Skills_PrintToChat(survivor, "%N传送到你旁边", picker);
}

public void OnAmmo(int owner, int picker, Buff buff)
{
	ExecuteCheatCommand(picker, "give", "ammo");
}

public void OnMoneyMultiplier(int owner, int picker, Buff buff)
{
	float min = g_SettingsManager.GetValue("money_min_multiplier");
	float max = g_SettingsManager.GetValue("money_max_multiplier");
	Skills_SetClientMoneyMultiplier(picker, GetRandomFloat(min, max));
}

public void OnMoneyBonus(int owner, int picker, Buff buff)
{
	float min = g_SettingsManager.GetValue("money_min_bonus");
	float max = g_SettingsManager.GetValue("money_max_bonus");
	Skills_AddClientMoney(picker, GetRandomFloat(min, max), false, true);
}

public void OnWitchBox(int owner, int picker, Buff buff)
{
	float vOrigin[3];
	int min = g_SettingsManager.GetValue("witch_min_count");
	int max = g_SettingsManager.GetValue("witch_max_count");
	int count = GetRandomInt(min, max);

	for(int i; i < count; i++)
	{
		if (L4D_GetRandomPZSpawnPosition(picker, 7, 5, vOrigin))
		{
			L4D2_SpawnWitch(vOrigin, {0.0, 0.0, 0.0});
		}
	}
}

public void OnSpecialBox(int owner, int picker, Buff buff)
{
	float vOrigin[3];
	int min = g_SettingsManager.GetValue("specials_min_count");
	int max = g_SettingsManager.GetValue("specials_max_count");
	int count = GetRandomInt(min, max);
	
	for(int i; i < count; i++)
	{
		int class = GetRandomInt(1, 6);
		if (L4D_GetRandomPZSpawnPosition(picker, class, 5, vOrigin))
		{
			L4D2_SpawnSpecial(class, vOrigin, {0.0, 0.0, 0.0});
		}
	}
}

public void OnTankBox(int owner, int picker, Buff buff)
{
	float vOrigin[3];
	if (L4D_GetRandomPZSpawnPosition(picker, 8, 5, vOrigin))
	{
		L4D2_SpawnTank(vOrigin, {0.0, 0.0, 0.0});
	}
}

public void Skills_OnGetSettings( KeyValues kv )
{
	g_iBuffsCount = 0;
	
	EXPORT_START(MYEXPORT);

	EXPORT_SECTION_START("生命恢复")
	{
		g_SettingsManager.ExportInt(kv, "regen_maxhealth", 100);
		g_SettingsManager.ExportInt(kv, "regen_add", 1);
		g_SettingsManager.ExportFloat(kv, "regen_interval", 0.25);
		g_SettingsManager.ExportFloat(kv, "regen_duration", 3.25);
		CreateBuffFromKV(kv, "生命恢复", OnRegeneration);
		EXPORT_SECTION_END();
	}

	EXPORT_SECTION_START("传送")
	{
		g_SettingsManager.ExportInt(kv, "teleport_allow_backward", 1);
		CreateBuffFromKV(kv, "传送", OnTeleport);
		EXPORT_SECTION_END();
	}

	EXPORT_SECTION_START("弹药补给")
	{
		CreateBuffFromKV(kv, "弹药补给", OnAmmo);
		EXPORT_SECTION_END();
	}

	EXPORT_SECTION_START("积分翻倍")
	{
		g_SettingsManager.ExportFloat(kv, "money_min_multiplier", 1.05);
		g_SettingsManager.ExportFloat(kv, "money_max_multiplier", 3.00);
		CreateBuffFromKV(kv, "积分翻倍", OnMoneyMultiplier);
		EXPORT_SECTION_END();
	}

	EXPORT_SECTION_START("积分奖励")
	{
		g_SettingsManager.ExportFloat(kv, "money_min_bonus", 150.0);
		g_SettingsManager.ExportFloat(kv, "money_max_bonus", 400.0);
		CreateBuffFromKV(kv, "积分奖励", OnMoneyBonus);
		EXPORT_SECTION_END();
	}

	EXPORT_SECTION_START("Witch生成")
	{
		CreateBuffFromKV(kv, "Witch生成", OnWitchBox);
		g_SettingsManager.ExportInt(kv, "witch_min_count", 1);
		g_SettingsManager.ExportInt(kv, "witch_max_count", 5);
		EXPORT_SECTION_END();
	}

	EXPORT_SECTION_START("Tank生成")
	{
		CreateBuffFromKV(kv, "Tank生成", OnTankBox);
		EXPORT_SECTION_END();
	}

	EXPORT_SECTION_START("Special")
	{
		CreateBuffFromKV(kv, "Special", OnSpecialBox);
		g_SettingsManager.ExportInt(kv, "specials_min_count", 1);
		g_SettingsManager.ExportInt(kv, "specials_max_count", 3);
		EXPORT_SECTION_END();
	}

	EXPORT_INT_DEFAULT("print", globals.print, 1);
	EXPORT_INT_DEFAULT("stealing", globals.stealing, 1);
	EXPORT_FLOAT_DEFAULT("gift_glow_color_transfusion", globals.gift_glow_color_transfusion, 1.0);
	EXPORT_FLOAT_DEFAULT("gift_fly_offset", globals.gift_fly_offset, 15.0);
	EXPORT_FLOAT_DEFAULT("gift_speed", globals.gift_speed, 0.5);
	EXPORT_FLOAT_DEFAULT("gift_pickup_radius", globals.gift_pickup_radius, 70.0);
	EXPORT_FLOAT_DEFAULT("gift_rotation_speed", globals.gift_rotation_speed, 0.5);
	EXPORT_FLOAT_DEFAULT("gift_chance", globals.nothing, 25.0);
	
	EXPORT_FINISH();

	GetBuffsWeight();
}

int GetRandomBuff()
{
	float random = GetRandomFloat() * globals.weight;
		
	for( int i; i < g_iBuffsCount; i++ )
	{
		random -= g_Buffs[i].weight;
		
		if ( random < 0.0 )
			return i;
	}
	
	return GetRandomInt(0, g_iBuffsCount);
}

void GetBuffsWeight()
{
	globals.weight = 0.0;
	
	for( int i; i < g_iBuffsCount; i++ )
	{
		globals.weight += g_Buffs[i].weight;
	}
}

Buff CreateBuffFromKV( KeyValues kv, const char[] defaultName, BuffAction action )
{
	Buff buff;
	buff.action = action;

	EXPORT_STRING_DEFAULT("name", buff.name, sizeof Buff::name, defaultName);
	EXPORT_STRING_DEFAULT("model", buff.model, sizeof Buff::model, DEFAULT_MODEL);
	EXPORT_STRING_DEFAULT("sound", buff.pickupSound, sizeof Buff::pickupSound, DEFAULT_PICKUP_SOUND);
	
	EXPORT_FLOAT_DEFAULT("alivetime", buff.alivetime, 15.0);
	EXPORT_FLOAT_DEFAULT("weight", buff.weight, 100.0);
	
	EXPORT_INT_DEFAULT("repick", buff.canRepick, 1);
	
	RegisterBuff(buff);
	return buff;
}

void RegisterBuff( Buff newBuff )
{
	int i = g_iBuffsCount++;
	
	if ( i == MAX_BUFFS )
	{
		ERROR("Too many registered buffs, increase define");
		return;
	}
		
	g_Buffs[i] = newBuff;
}

void PrecacheBuffs()
{
	for(int i; i < g_iBuffsCount; i++)
	{
		PrecacheModel(g_Buffs[i].model, true);
		PrecacheSound(g_Buffs[i].pickupSound, true);
	}
}