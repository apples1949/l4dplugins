#include <sourcemod>

new any:tankClient;
new any:tankKiller;
new any:tankTotalHealth;
new bool:isTankAlive = false;

new ConVar:tankHealTypeCVar;
new ConVar:maxHealreturnCVar;
new ConVar:tankHealReturnCVar;

new any:tankHealType;
new any:maxHealreturn;
new any:tankHealReturn;

new damageList[33] = 0;

public Plugin:myinfo = 
{
	name = "TankKillerHeal",
	author = "我是派蒙啊",
	description = "杀克回血",
	version = "0.1.4",
	url = "http://www.paimeng.ltd/"
}

public void OnPluginStart()
{
	HookEvent("tank_spawn", OnTankSpawn, EventHookMode_Post);
	HookEvent("player_hurt", OnTankHurt, EventHookMode_Post);
	HookEvent("tank_killed", OnTankDead, EventHookMode_Post);
	
	tankHealReturnCVar = CreateConVar("tankheal_return", "50", "杀克回血量", 0, false, 0.0, false, 0.0);
	maxHealreturnCVar = CreateConVar("maxheal_return", "150", "杀克最大回血量", 0, false, 0.0, false, 0.0);
	tankHealTypeCVar = CreateConVar("tankheal_type", "2", "杀克回血类型，0为关闭回血，1为按杀克人回血，2为按输出比例回血，3为按最高输出人回血", 0, false, 0.0, false, 0.0);
	
	GetConVars();
	tankHealTypeCVar.AddChangeHook(OnConVarChanged);
	tankHealReturnCVar.AddChangeHook(OnConVarChanged);
}

///克生成事件
public void OnTankSpawn(Event:event, String:name[], bool:dont_broadcast)
{
	ResetDamageList();
	isTankAlive = true;
	tankClient = GetClientOfUserId(GetEventInt(event, "userid", 0))
	tankTotalHealth = GetClientHealth(tankClient);
}

///克受伤事件
public void OnTankHurt(Event:event, String:name[], bool:dont_broadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid", 0))
	int player = GetClientOfUserId(GetEventInt(event, "attacker", 0))
	if(!IsInfected(client) && client != tankClient && !IsPlayer(player)) return;
	if(IsTankDying() && isTankAlive) isTankAlive = false;
	else if(IsTankDying()) return;
	damageList[player] += GetEventInt(event, "dmg_health", 0);
}

///克死亡事件
public void OnTankDead(Event:event, String:name[], bool:dont_broadcast)
{
	tankKiller = GetClientOfUserId(GetEventInt(event, "attacker", 0));
	Prepare2GiveHeal();
	
	tankClient = 0;
	tankTotalHealth = 0;
}

///ConVar改变事件
public void OnConVarChanged(ConVar:convar, String:oldValue[], String:newValue[])
{
	GetConVars();
}

///获取新ConVar值
public void GetConVars()
{
	tankHealType = tankHealTypeCVar.IntValue;
	maxHealreturn = maxHealreturnCVar.IntValue;
	tankHealReturn = tankHealReturnCVar.IntValue;
}

///判断客户端是否是玩家
public bool:IsPlayer(any:client)
{
	return IsClientInTeam(client, 2);
}

///判断客户端是否是特感
public bool:IsInfected(any:client)
{
	return IsClientInTeam(client, 3);
}

///判断客户端所属队伍
public bool:IsClientInTeam(any:client, int team)
{
	return (IsValidClient(client) && GetClientTeam(client) == team);
}

///判断客户端是否有效
public bool:IsValidClient(any:client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

///判断克是否已经死亡
public bool:IsTankDying()
{
	if (!IsValidClient(tankClient))
		return true;
	
	int value = 0;
	int isIncapacitated = FindSendPropInfo("Tank", "m_isIncapacitated", PropFieldType:value, value, value);
	return GetEntData(tankClient, isIncapacitated, 4) > 0;
}

///重置伤害值
public void ResetDamageList()
{
	for(int i = 0; i <= MaxClients; i++)
		damageList[i] = 0;
}

///获取伤害百分比
public int GetDamageAsPercent(int damage)
{
	return damage * 100 / tankTotalHealth;
}

public void Prepare2GiveHeal()
{
	switch(tankHealType)
	{
		case 0:
		{
			return;
		}
		case 1:
		{
			GiveHealth(tankKiller, tankHealReturn);
		}
		case 2:
		{
			GiveHealthByAtk();
		}
		case 3:
		{
			GiveHealthByMaxAtk();
		}
	}
}

///给予玩家血量
public void GiveHealth(any:client, int heal)
{
	if(!IsPlayer(client)) return;
	
	int preheal = GetClientHealth(client);
	if(preheal >= maxHealreturn) return;
	
	SetEntityHealth(client, preheal + heal);
}

///按输出给予玩家血量
public void GiveHealthByAtk()
{
	for(int client = 0; client <= MaxClients; client++)
	{
		//PrintToChatAll("进入循环 %d", client);
		if(!IsPlayer(client)) continue;
		GiveHealth(client, GetDamageAsPercent(damageList[client]) * tankHealReturn / 100);
	}
}

///按最高输出玩家给予血量
public void GiveHealthByMaxAtk()
{
	int maxDmgClient = 0;
	for(int client = 0; client <= MaxClients; client++)
	{
		if(!IsPlayer(client)) continue;
		if(damageList[client] > damageList[maxDmgClient]) maxDmgClient = client;
	}
	
	GiveHealth(maxDmgClient, tankHealReturn);
}