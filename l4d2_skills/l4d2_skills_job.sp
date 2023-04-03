#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <l4d2_skills>
#include <left4dhooks>

public Plugin myinfo =
{
	name = "[L4D2] Skills Job",
	author = "BHaType",
	description = "Gives player money for killing specials",
	version = "1.1",
	url = "https://github.com/Vinillia/l4d2_skills"
};

#define ZC_CLASSES 9

enum struct ExportedInfo
{
	float bossesRewards[ZC_CLASSES];
	float witchOneshotReward;
	float team_reward_factor;
	float money_damage_factor;
	float infected_money_reward;
	
	int infected_kills_interval;

	bool money_damage_enable;
	bool print_special_rewards;
	bool print_infected_rewards;
}

enum struct DamageRecord
{
	int serial;
	float damage[MAXPLAYERS + 1];

	void init(int client)
	{
		DamageRecord nullrecord;
		this = nullrecord;
		this.serial = GetClientSerial(client);
	}

	void hurt(int owner, float dmg)
	{
		this.damage[owner] += dmg; 
	}

	bool valid()
	{
		return this.serial && GetClientFromSerial(this.serial) != 0;
	}

	bool owner(int client)
	{
		if (!this.valid())
			return false;

		return GetClientSerial(client) == this.serial; 
	}
}

ExportedInfo g_Export;
DamageRecord g_dmgRecord[MAXPLAYERS + 1];

public void OnAllPluginsLoaded()
{	
	Skills_RequestConfigReload();
	
	HookEvent("player_death", player_death);
	HookEvent("player_hurt", player_hurt);
	HookEvent("witch_killed", witch_killed);
	
	RegConsoleCmd("sm_skills_job_info", sm_skills_job_info);
}

public Action sm_skills_job_info( int client, int args )
{
	//Skills_PrintToChat(client, "Reward for \x04witch \x01oneshot: \x03%.0f", g_Export.witchOneshotReward);
	Skills_PrintToChat(client, "\x01一枪击杀\x04女巫\x01奖励: \x03%.0f", g_Export.witchOneshotReward);
	/*Skills_PrintToChat(client, "Boss rewards:\n" ...											\
	"\x04Smoker: \x03%.0f\x01, \x04Booomer: \x03%.0f\x01, \x04Hunter: \x03%.0f\x01, \n" ...		\
	"\x04Spitter: \x03%.0f\x01, \x04Jockey: \x03%.0f\x01, \x04Charger: \x03%.0f\x01, \n" ...	\
	"\x04Witch: \x03%.0f\x01, \x04Tank: \x03%.0f",												\
	g_Export.bossesRewards[1], g_Export.bossesRewards[2], g_Export.bossesRewards[3],			\
	g_Export.bossesRewards[4], g_Export.bossesRewards[5], g_Export.bossesRewards[6],			\
	g_Export.bossesRewards[7], g_Export.bossesRewards[8]);*/
	Skills_PrintToChat(client, "特感奖励:\n \x04舌头: \x03%.0f\x01, \x04胖子: \x03%.0f\x01, \x04猎人: \x03%.0f\x01, \n\x04口水: \x03%.0f\x01, \x04猴子: \x03%.0f\x01, \x04牛牛: \x03%.0f\x01, \n\x04女巫: \x03%.0f\x01, \x04坦克: \x03%.0f", g_Export.bossesRewards[1], g_Export.bossesRewards[2], g_Export.bossesRewards[3],g_Export.bossesRewards[4], g_Export.bossesRewards[5], g_Export.bossesRewards[6],g_Export.bossesRewards[7], g_Export.bossesRewards[8]);
	return Plugin_Handled;
}

public void witch_killed( Event event, const char[] name, bool noReplicate )
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if ( !client || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2 )
		return;
	
	float reward = event.GetBool("oneshot") ? g_Export.witchOneshotReward : g_Export.bossesRewards[L4D2ZombieClass_Witch];
	GainMoney(client, reward, g_Export.print_special_rewards);
}

public void player_hurt( Event event, const char[] name, bool noReplicate )
{
	if (!g_Export.money_damage_enable)
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (!victim || victim > MaxClients || !IsClientInGame(victim) || GetClientTeam(victim) != 3)
		return;

	if (!attacker || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return;

	int damage = event.GetInt("dmg_health"); 
	HurtRecord(victim, attacker, float(damage));
}

public void player_death( Event event, const char[] name, bool noReplicate )
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if ( !attacker || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2 )
		return;

	if (HandleInfectedDeath(event, attacker))
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if ( !client || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 3 )
		return;
	
	float reward;

	if (g_Export.money_damage_enable)
	{
		reward = GetRecordDamageForClient(client, attacker);
		reward *= g_Export.money_damage_factor;
	}
	else
	{
		L4D2ZombieClassType class = L4D2_GetPlayerZombieClass(client);
		reward = g_Export.bossesRewards[class];
	}

	if (reward == 0.0)
		return;

	GainMoney(attacker, reward, g_Export.print_special_rewards);
}

bool HandleInfectedDeath(Event event, int attacker)
{
	static int nKills[MAXPLAYERS + 1];

	int victim = event.GetInt("entityid");
	
	if (victim <= MaxClients || !IsValidEntity(victim) || !ClassMatchesComplex(victim, "infected"))
		return false;
	
	if (++nKills[attacker] % g_Export.infected_kills_interval == 0)
	{
		//if (g_Export.print_infected_rewards)
			//Skills_PrintToChat(attacker, "\x04You \x03have got \x05%.0f\x03 money for killing \x03%i commons!", g_Export.print_infected_rewards, nKills[attacker]);
		
		GainMoney(attacker, g_Export.infected_money_reward, g_Export.print_infected_rewards);
		nKills[attacker] = 0;
	}

	return true;
}

public void L4D_OnSpawnSpecial_Post(int client, int zombieClass, const float vecPos[3], const float vecAng[3])
{
	HurtRecord(client, client, 0.0);
}

public void L4D_OnSpawnTank_Post(int client, const float vecPos[3], const float vecAng[3])
{
	HurtRecord(client, client, 0.0);
}

void HurtRecord(int victim, int attacker, float damage)
{
	if (!g_dmgRecord[victim].owner(victim) || !g_dmgRecord[victim].valid())
	{
		g_dmgRecord[victim].init(victim);
	}

	g_dmgRecord[victim].hurt(attacker, damage);
}

float GetRecordDamageForClient(int victim, int attacker)
{
	return g_dmgRecord[victim].damage[attacker];
}

void GainMoney( int client, float reward, bool print )
{
	Skills_AddClientMoney(client, reward, false, print);
	Skills_AddTeamMoney(reward);
}

public void Skills_OnGetSettings( KeyValues kv )
{
	EXPORT_START(SKILLS_GLOBALS);
	
	EXPORT_FLOAT_DEFAULT("smoker_reward", g_Export.bossesRewards[L4D2ZombieClass_Smoker], 60.0);
	EXPORT_FLOAT_DEFAULT("boomer_reward", g_Export.bossesRewards[L4D2ZombieClass_Boomer], 35.0);
	EXPORT_FLOAT_DEFAULT("hunter_reward", g_Export.bossesRewards[L4D2ZombieClass_Hunter], 45.0);
	EXPORT_FLOAT_DEFAULT("spitter_reward", g_Export.bossesRewards[L4D2ZombieClass_Spitter], 35.0);
	EXPORT_FLOAT_DEFAULT("jockey_reward", g_Export.bossesRewards[L4D2ZombieClass_Jockey], 100.0);
	EXPORT_FLOAT_DEFAULT("charger_reward", g_Export.bossesRewards[L4D2ZombieClass_Charger], 150.0);
	EXPORT_FLOAT_DEFAULT("witch_reward", g_Export.bossesRewards[L4D2ZombieClass_Witch], 500.0);
	EXPORT_FLOAT_DEFAULT("tank_reward", g_Export.bossesRewards[L4D2ZombieClass_Tank], 1500.0);
	
	EXPORT_FLOAT_DEFAULT("money_damage_factor", g_Export.money_damage_factor, 1.5);
	EXPORT_FLOAT_DEFAULT("witch_one_shot_reward", g_Export.witchOneshotReward, 1000.0);
	EXPORT_FLOAT_DEFAULT("infected_money_reward", g_Export.infected_money_reward, 250.0);

	EXPORT_INT_DEFAULT("infected_kills_interval", g_Export.infected_kills_interval, 25);
	
	EXPORT_BOOL_DEFAULT("money_damage_enable", g_Export.money_damage_enable, true);
	EXPORT_BOOL_DEFAULT("print_specials_reward", g_Export.print_special_rewards, true);
	EXPORT_BOOL_DEFAULT("print_infected_reward", g_Export.print_infected_rewards, true);
	
	EXPORT_FINISH();
}