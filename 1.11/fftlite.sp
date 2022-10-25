#define TEAM_SPECTATOR		1
#define TEAM_SURVIVORS		2
#define TEAM_INFECTED		3

#define PLUGIN_VERSION		"0.2a"

#include <sourcemod>
#include <sdkhooks>

public Plugin:myinfo = {
	name = "Friendly-Fire Toolkit Lite",
	author = "Sky",
	description = "A lite friendly fire toolkit",
	version = PLUGIN_VERSION,
	url = "vousdusky@gmail.com"
}

new Handle:g_FriendlyFireBots;
new Handle:g_FriendlyFireAbsorb;
new Handle:g_FriendlyFireReflect;
new Handle:g_FriendlyFireKick;
new Handle:g_FriendlyFireIncap;
new friendlyFireAmount[MAXPLAYERS + 1];

public OnPluginStart()
{
	CreateConVar("fftlite_version", PLUGIN_VERSION, "current installed version of this plugin.");

	g_FriendlyFireAbsorb	= CreateConVar("fftlite_absorb","0","1=没有任何交火伤害");
	g_FriendlyFireReflect	= CreateConVar("fftlite_reflect","0","1=反射任何交火");
	g_FriendlyFireKick		= CreateConVar("fftlite_kick","100","对队友造成多少伤害会被踢,0=OFF");
	g_FriendlyFireIncap		= CreateConVar("fftlite_incap","1","1=友军炮火反映可以晕昏剂侵略者");
	g_FriendlyFireBots		= CreateConVar("fftlite_bots","1","1=机器人可以进行有伤害的交火");

	AutoExecConfig(true, "fftlite");
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (IsClientActual(victim) && IsClientActual(attacker) && IsSameTeam(victim, attacker) && victim != attacker)
	{
		if (!IsFakeClient(attacker)) friendlyFireAmount[attacker] += RoundToFloor(damage);
		if (GetConVarInt(g_FriendlyFireReflect) == 1)
		{
			if (!IsFakeClient(attacker) || (IsFakeClient(attacker) && GetConVarInt(g_FriendlyFireBots) == 1))
			{
				if (GetClientHealth(attacker) - RoundToFloor(damage) < 1)
				{
					if (GetConVarInt(g_FriendlyFireIncap) == 0) SetEntityHealth(attacker, 1);
					else SetEntProp(attacker, Prop_Send, "m_isIncapacitated", true, 1);
				}
				else SetEntityHealth(attacker, GetClientHealth(attacker) - RoundToFloor(damage));
			}
		}
		if (GetConVarInt(g_FriendlyFireAbsorb) == 1) damage = 0.0;
		if (GetConVarInt(g_FriendlyFireKick) > 0 && friendlyFireAmount[attacker] > GetConVarInt(g_FriendlyFireKick)) KickClient(attacker);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public OnConfigsExecuted()
{
	AutoExecConfig(true, "fftlite");
}

public bool:IsSameTeam(first, second)
{
	if (GetClientTeam(first) == GetClientTeam(second)) return true;
	return false;
}

public bool:IsClientActual(client)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client)) return false;
	return true;
}

public OnClientPostAdminCheck(client)
{
	if (IsClientActual(client))
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		friendlyFireAmount[client] = 0;
	}
}

public OnClientDisconnect(client)
{
	if (IsClientActual(client))
	{
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		friendlyFireAmount[client] = 0;
	}
}