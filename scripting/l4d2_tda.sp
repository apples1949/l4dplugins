#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <l4d2util>
#include <left4dhooks>

//#include "Selfinc/Map.sp" 
//#include "Selfinc/Infected.sp"

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZOMBIECLASS_TANK 8 // Zombie class of the tank, used to find tank after he have been passed to another player 

bool g_bEnabled = true;
bool g_bAnnounceTankDamage = false; // Whether or not tank damage should be announced
bool g_bIsTankInPlay = false; // Whether or not the tank is active
//bool TankSpwanOnlyOne = false;
int g_iOffset_Incapacitated = 0; // Used to check if tank is dying
int g_iTankClient = 0; // Which client is currently playing as tank
int g_iLastTankHealth[MAXPLAYERS + 1]; // Used to award the killing blow the exact right amount of damage
int g_iDamage[MAXPLAYERS + 1];

int TankMaxHealth = 0;
//int TankNum =0;

public Plugin myinfo = 
{
	name = "Tank Damage Announce L4D2",
	author = "Griffin and Blade", 
	description = "Announce damage dealt to tanks by survivors",
	version = "0.6.5d"
};
public void OnPluginStart() 
{
	g_bIsTankInPlay = false;
	g_bAnnounceTankDamage = false;
	g_iTankClient = 0;
	ClearTankDamage();
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("player_death", Event_PlayerKilled);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_hurt", Event_PlayerHurt);
	
	
	g_iOffset_Incapacitated = FindSendPropInfo("Tank", "m_isIncapacitated"); 
}
public void OnMapStart() 
{    
	ClearTankDamage(); 
} 
public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bIsTankInPlay) 
		return; // No tank in play; no damage to record

	int victim = GetClientOfUserId(GetEventInt(event, "userid"));

	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (attacker == 0 || !IsClientInGame(attacker) || GetClientTeam(attacker) != TEAM_SURVIVOR) 
		return;
	if(!IsTank(victim)) return;

	if (!IsTankDying(victim)) {
		g_iDamage[attacker] += GetEventInt(event, "dmg_health");
		g_iLastTankHealth[victim] = GetEventInt(event, "health"); 
	}
}
bool IsTankDying(int tank)
{
	return view_as<bool>(GetEntData(tank, g_iOffset_Incapacitated));
}
public void Event_PlayerKilled(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bIsTankInPlay) return; // No tank in play; no damage to record

	int victim = GetClientOfUserId(GetEventInt(event, "userid")); 

	if(victim == 0) return;
	if  (!IsTank(victim)) return;
	// Award the killing blow's damage to the attacker; we don't award
	// damage from player_hurt after the tank has died/is dying
	// If we don't do it this way, we get wonky/inaccurate damage values

	int attacker = GetClientOfUserId(GetEventInt(event, "attacker")); 

	if (attacker && IsClientInGame(attacker)) 
		g_iDamage[attacker] += g_iLastTankHealth[victim];

	//if (victim != g_iTankClient) return;
	CreateTimer(0.1, Timer_CheckTank, victim); // Use a delayed timer due to bugs where the tank passes to another player
}
public Action Timer_CheckTank(Handle timer, any oldtankclient)
{
	if (g_iTankClient != oldtankclient) return Plugin_Continue;// ?????????Tank????????????Tank,????????????
	int tankclient = FindTankClientSelf();//?????????Tank
	if (tankclient && tankclient != oldtankclient)//????????????Tank,????????????Tank???????????????Tank
	{
		g_iTankClient = tankclient;//?????????Tank??????

		return Plugin_Continue; // Found tank, done
	}

	PrintTankDamage();//????????????Tank?????????Tank????????????,??????
	ClearTankDamage();
	g_bIsTankInPlay = false; // No tank in play
	return Plugin_Continue;
}
/*
public void CheckTankNum(){
	if(L4D_IsMissionFinalMap() && NumTanksInPlay()> 2  && IsValidInfecteds(g_iTankClient) ){	
		ForcePlayerSuicide(g_iTankClient);
		PrintToChatAll("\x01[\x04Tank??????\x01]???????????????????????????\x03Tank\x01????????????\x052\x01???");
	}
	else if(!L4D_IsMissionFinalMap() && TankSpwanOnlyOne && IsValidInfecteds(g_iTankClient)){	
		ForcePlayerSuicide(g_iTankClient);
		PrintToChatAll("\x01[\x04Tank??????\x01]????????????\x03Tank\x01????????????\x051???");
	}else if(L4D_IsMissionFinalMap() && TankNum > 2 && IsValidInfecteds(g_iTankClient)){
		ForcePlayerSuicide(g_iTankClient);
		PrintToChatAll("\x01[\x04Tank??????\x01]?????????\x03Tank\x01????????????\x052???");
	}
	TankSpwanOnlyOne = true;
}
*/
public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_iTankClient = client;

	//if(!OfficalMap()){
		//TankNum ++;
		//RequestFrame(CheckTankNum);
	//}
	

	RequestFrame(OnNextFrame_TankHealth, event.GetInt("userid"));

	if (g_bIsTankInPlay) return; // Tank passed

	// New tank, damage has not been announced
	g_bAnnounceTankDamage = true;
	g_bIsTankInPlay = true;
	// Set health for damage print in case it doesn't get set by player_hurt (aka no one shoots the tank)

	
}
public void OnNextFrame_TankHealth(int userid)
{
	int client = GetClientOfUserId(userid);
	TankMaxHealth = TankMaxHealth + GetClientHealth(client);
	g_iLastTankHealth[client] = GetClientHealth(client);
	//PrintToChatAll("?????????1_1 Tank:%d",TankMaxHealth);
}
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcas)
{
	g_bIsTankInPlay = false;
	g_iTankClient = 0;
	//TankSpwanOnlyOne = false;
	//TankNum = 0;
	ClearTankDamage(); // Probably redundant
}

// When survivors wipe or juke tank, announce damage
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcas)
{
	// But only if a tank that hasn't been killed exists
	if (g_bAnnounceTankDamage)
	{
		PrintRemainingHealth();
		PrintTankDamage();
	}
	ClearTankDamage();
}
void PrintRemainingHealth()
{
		
	for (int i = 1; i <= MaxClients; i++)
	{ 
		if(IsTank(i))
		PrintToChatAll("\x05%N\x03????????? \x04%d \x03???",i,g_iLastTankHealth[i]);
	}
}
void PrintTankDamage()
{
	if (!g_bEnabled) return;
	int client;
	int survivor_index;
	int survivor_clients[32]; // Array to store survivor client indexes in, for the display iteration
	int damage,damage_total;
	int percent_damage,percent_total;

	for (client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsClientConnected(client)) continue;

		survivor_clients[survivor_index] = client;
		damage = g_iDamage[client];
		damage_total += damage;	
		percent_damage = GetDamageAsPercent(damage);
		percent_total += percent_damage;	

		survivor_index++;
	}
	SortCustom1D(survivor_clients, survivor_index, SortByDamageDesc);

	int percent_adjustment;
	if( percent_total < 100 && (float(damage_total) > (TankMaxHealth - TankMaxHealth/200.0)) )
		percent_adjustment = 100 - percent_total;
	
	int last_percent = 100;//?????????????????????????????????????????????????????????????????????????????????????????????????????????
	int adjusted_percent_damage;

	PrintToChatAll("\x05[Tank]\x03????????????:");
	for (int i; i < survivor_index; i++)
	{ 
		client = survivor_clients[i];
		damage = g_iDamage[client];
		percent_damage = GetDamageAsPercent(damage);
		if (percent_adjustment != 0 && damage > 0 && !IsExactPercent(damage))
		{
			adjusted_percent_damage = percent_damage + percent_adjustment;
			if (adjusted_percent_damage <= last_percent) // Make sure adjusted percent is not higher than previous percent, order must be maintained
			{
				percent_damage = adjusted_percent_damage;
				percent_adjustment = 0;
			}
		}
		last_percent = percent_damage;		
		PrintToChatAll("\x05??? \x04%d \x01[\x05%i\x01%%] \x03%N",damage,percent_damage,client);
	}
}
int GetDamageAsPercent(int damage)
{
	//PrintToChatAll("?????????2 ??????:%d,??????:%d",damage,TankMaxHealth );
	//PrintToChatAll("?????????3 %.f",float(damage)/float(TankMaxHealth)*100);
	//PrintToChatAll("?????????2 ????????????????????????:%d", RoundToNearest( (damage/float(TankMaxHealth))*100 ));
	return RoundToNearest((damage/float(TankMaxHealth)) *100.0);	
}
bool IsExactPercent(int damage)
{
	float fDamageAsPercent = (damage/float(TankMaxHealth)) * 100.0;
	float fDifference = float(GetDamageAsPercent(damage)) - fDamageAsPercent;
	return (FloatAbs(fDifference) < 0.001) ? true : false;
}
void ClearTankDamage()
{
	
	TankMaxHealth = 0;
	for (int i = 1; i <= MaxClients; i++)
	{ 
		g_iDamage[i] = 0;
		g_iLastTankHealth[i] = 0;
	}
	g_bAnnounceTankDamage = false; 
}

int FindTankClientSelf()
{ 
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED ||!IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != ZOMBIECLASS_TANK)
		continue;

		return client; // Found tank, return
	}
	return 0;
}
public int SortByDamageDesc(int elem1, int elem2, const int[] array, Handle hndl)
{
	// By damage, then by client index, descending
	if (g_iDamage[elem1] > g_iDamage[elem2]) return -1;
	else if (g_iDamage[elem2] > g_iDamage[elem1]) return 1;
	else if (elem1 > elem2) return -1;
	else if (elem2 > elem1) return 1;
	return 0;
} 
 