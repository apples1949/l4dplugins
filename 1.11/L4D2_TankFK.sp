#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

new Handle:sm_fktime;
new Handle:sm_fkdistance;
new Handle:g_fkEnable;
new Float:playerPos[3];
new bool:g_fkJump = true;

public Plugin:myinfo =
{
	name = "[L4D2]坦克防卡",
	description = "---",
	author = "人生如梦 & 藤野深月(反编译修复)",
	version = "1.0",
	url = "--"
};

public OnPluginStart()
{
	/* Hook */
	HookEvent("tank_spawn", Event_Tank_Spawn);
	/* CFG参数 */
	g_fkEnable 		= CreateConVar("sm_doublejump_enabled", "1",			"是否开启坦克防卡.");
	sm_fktime 		= CreateConVar("sm_fktime", 						"8.0", 	"坦克卡住多少时间后才会随机瞬移到某一个幸存者身边(有误差，一般为X秒到2X秒之间!");
	sm_fkdistance = CreateConVar("sm_fkdistance", 				"25.0", 	"坦克在多大的范围内活动才算卡住!(填0就是原地踏步!)");
	/* 调用参数 */
	HookConVarChange(g_fkEnable, convar_Change);
	g_fkJump = GetConVarBool(g_fkEnable);
	/* 创建Config */
	AutoExecConfig(true, "L4D2_TankFK");
}

public convar_Change(Handle:convar, String:oldVal[], String:newVal[])
{
	if (g_fkEnable == convar)
	{
		if (StringToInt(newVal) >= 1)
		{
			g_fkJump = true;
		}
		g_fkJump = false;
	}
}

public Action:Event_Tank_Spawn(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidEdict(client) && IsValidPlayer(client))
	{
		if (GetClientTeam(client) == 3)
		{
			new iClass = GetEntProp(client, Prop_Send, "m_zombieClass");
			if (iClass == 8)
			{
				if (g_fkJump)
				{
					aTimer(client);
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action:aTimer(client)
{
	if (IsValidEdict(client) && IsValidPlayer(client))
	{
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", playerPos);
		CreateTimer(GetConVarFloat(sm_fktime), TeleportTimer, client);
		new Float:velo[3];
		if (velo[2] != 0.0)
		{
			return Plugin_Handled;
		}
		new Float:vec[3];
		vec[0] = velo[0];
		vec[1] = velo[1];
		vec[2] = velo[2] + 300.0;
	}
	return Plugin_Handled;
}

public Action:TeleportTimer(Handle:timer, any:client)
{
	new Float:entpos[3];
	new Float:clientpos[3];
	new Float:distance = 0.0;
	new Float:fkdistance = GetConVarFloat(sm_fkdistance);
	
	if (IsValidEdict(client) && IsValidPlayer(client))
	{
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", entpos);
		distance = GetVectorDistance(playerPos, entpos);
		if (distance <= fkdistance)
		{
			new target = GetRandomSurvivor();
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", clientpos);
			TeleportEntity(client, clientpos, NULL_VECTOR, NULL_VECTOR);
			PrintHintTextToAll("[提示] 检测到Tank被卡住, 将自动瞬移随机幸存者旁边!");
			aTimer(client);
		}
		else
		{
			aTimer(client);
		}
		new Float:velo[3];
		if (velo[2] != 0.0)
		{
			return Plugin_Handled;
		}
		new Float:vec[3];
		vec[0] = velo[0];
		vec[1] = velo[1];
		vec[2] = velo[2] + 300.0;
	}
	return Plugin_Handled;
}

public GetRandomSurvivor()
{
	new Handle:array;
	array = CreateArray(1, 0);
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsValidPlayer(i) || !IsValidEntity(i) || !IsPlayerAlive(i) || GetClientTeam(i) != 2)
			continue;
		PushArrayCell(array, i);
	}
	if (GetArraySize(array) <= 0)
	{
		ClearArray(array);
		for(new i = 1; i <= MaxClients; i++)
		{
			if(!IsValidPlayer(i) || !IsValidEntity(i) || !IsPlayerAlive(i) || GetClientTeam(i) != 2)
				continue;
			PushArrayCell(array, i);
		}	
	}
	if (GetArraySize(array) <= 0)
		return 0;
	
	new maxsize = GetArraySize(array) - 1;
	new clientNum = GetArrayCell(array, GetRandomInt(0, maxsize));
	return clientNum;
}

stock bool:IsValidPlayer(Client, bool:AllowBot = true, bool:AllowDeath = true)
{
	if (Client < 1 || Client > MaxClients)
		return false;
	if (!IsClientConnected(Client) || !IsClientInGame(Client))
		return false;
	if (!AllowBot)
	{
		if (IsFakeClient(Client))
			return false;
	}
	if (!AllowDeath)
	{
		if (!IsPlayerAlive(Client))
			return false;
	}	
	return true;
}