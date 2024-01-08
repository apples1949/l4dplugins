#pragma semicolon 1
#include <sourcemod>
#include <colors>

public Plugin:myinfo=
{
	name = "damage display",
	author = "",
	description = "United RPG",
	version = "1.0.0",
	url = ""
};

#define IsValidClient(%1)	(1 <= %1 <= MaxClients && IsClientInGame(%1))

enum DeadType {ALIVE = 0, NORMALDEAD, HEADSHOT};
#define DamageDisplayBuffer	5
#define DamageDisplayLength	64
static LastDamage[MAXPLAYERS+1];
static DamageToTank[MAXPLAYERS+1][MAXPLAYERS+1];
static Handle:DamageDisplayCleanTimer[MAXPLAYERS+1];
static String:DamageDisplayString[MAXPLAYERS+1][DamageDisplayBuffer][DamageDisplayLength];
static const String:DamagePrintBuffer[][]={"","(击杀)","(爆头)"};
//static const String:CLASSNAME[][]={"","Smoker","Boomer","Hunter","Spitter","Jockey","Charger"};
#define MSG_TANK_HEALTH_REMAIN	"Tank (%N) 血量: %d HP (伤害值: %d HP)"

public OnPluginStart()
{
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("tank_frustrated", Event_TankFrustrated);
	HookEvent("infected_hurt", Event_InfectedHurt, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath);
}

public Action:Event_RoundEnd(Handle:event, String:event_name[], bool:dontBroadcast)
{
	if (GetClientCount() > 0)
		for (new i = 1; i <= MaxClients; i++)
			for (new j = 1; j <= MaxClients; j++)
				DamageToTank[i][j] = 0;
}

public Action:Event_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new tank = GetClientOfUserId(GetEventInt(event, "userid"));
	for (new i = 1; i <= MaxClients; i++)
		DamageToTank[i][tank] = 0;
}

public Action:Event_TankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	new tank = GetClientOfUserId(GetEventInt(event, "userid"));
	for(new i = 1; i <= MaxClients; i++)
		DamageToTank[i][tank] = 0;
}

public Action:Event_InfectedHurt(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new victim = GetEventInt(event, "entityid");
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new dmg = GetEventInt(event, "amount");
	new eventhealth = GetEntProp(victim, Prop_Data, "m_iHealth");
	new Float:AddDamage = 0.0;
	new bool:IsVictimDead = false;

	if (RoundToNearest(eventhealth - dmg - AddDamage) <= 0)
		IsVictimDead = true;

	if (IsValidClient(attacker) && !IsFakeClient(attacker))
	{
		if (!IsVictimDead)
		{
			DisplayDamage(RoundToNearest(dmg + AddDamage), ALIVE, attacker);
			if(IsValidClient(victim) && GetClientTeam(victim) == 3 && GetEntProp(victim, Prop_Send, "m_zombieClass") == 8)
			{
				DamageToTank[attacker][victim] += RoundToNearest(dmg + AddDamage);
				PrintHintText(attacker, MSG_TANK_HEALTH_REMAIN, victim, GetEventInt(event, "health"), DamageToTank[attacker][victim]);
			}
		}
		else LastDamage[attacker] = RoundToNearest(dmg + AddDamage);
	}
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (IsValidClient(victim) && GetClientTeam(victim) == 3 &&
		IsValidClient(attacker) && GetClientTeam(attacker) == 2 && !IsFakeClient(attacker))
	{
		for (new c=0; c<=6; c++)
			if (GetEntProp(victim, Prop_Send, "m_zombieClass") == c)
				
	
		if (GetEntProp(victim, Prop_Send, "m_zombieClass") == 8)
			for(new i = 1; i <= MaxClients; i++)
				if(IsClientInGame(i) && GetClientTeam(i) == 2 && !IsFakeClient(i))
					DamageToTank[i][victim] = 0;
	}

	if (IsValidClient(attacker) && !IsFakeClient(attacker))
		DisplayDamage(LastDamage[attacker], GetEventBool(event, "headshot") ? HEADSHOT : NORMALDEAD, attacker);
}

stock DisplayDamage(const dmg, const DeadType:type, const attacker)
{
	for(new i = DamageDisplayBuffer-1; i >= 1; i--)
		strcopy(DamageDisplayString[attacker][i], DamageDisplayLength, DamageDisplayString[attacker][i-1]);
		
	Format(DamageDisplayString[attacker][0], DamageDisplayLength, "- %d HP %s", dmg, DamagePrintBuffer[type]);
	PrintCenterText(attacker, "%s\n%s\n%s\n%s\n%s", DamageDisplayString[attacker][4], DamageDisplayString[attacker][3], DamageDisplayString[attacker][2], DamageDisplayString[attacker][1], DamageDisplayString[attacker][0]);
	
	if (DamageDisplayCleanTimer[attacker] != INVALID_HANDLE)
		KillTimer(DamageDisplayCleanTimer[attacker]);
		
	DamageDisplayCleanTimer[attacker] = CreateTimer(2.5, DamageDisplayCleanTimerFunction, attacker);
}

public Action:DamageDisplayCleanTimerFunction(Handle:timer, any:client)
{
	KillTimer(timer);
	DamageDisplayCleanTimer[client] = INVALID_HANDLE;
	if (IsValidClient(client) && !IsFakeClient(client))
		for(new j = 0; j < DamageDisplayBuffer; j++)
			strcopy(DamageDisplayString[client][j], DamageDisplayLength, "");
}
