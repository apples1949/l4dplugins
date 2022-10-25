#include <sourcemod>
#include <geoip>

//每行代码结束需填写“;”
#pragma semicolon 1

//新语法
#pragma newdecls required

public void OnPluginStart()
{
	RegConsoleCmd("sm_ip", Command_IPAddress);
}

public Action Command_IPAddress(int client, int args)
{
	if(IsValidClient(client, false, true, true, false))
	{
		PrintClientIPAddress(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void PrintClientIPAddress(int client)
{
	if(IsValidClient(client, false, true, true, false))
	{
		char ClientIP[16], continent[32], country[32], region[32], city[32];

		GetClientIP(client, ClientIP, sizeof(ClientIP));

		GeoipContinent(ClientIP, continent, sizeof(continent), "en");

		GeoipCountry(ClientIP, country, sizeof(country), "en");

		GeoipRegion(ClientIP, region, sizeof(region), "en");

		GeoipCity(ClientIP, city, sizeof(city), "en");

		PrintToChat(client, "\x01玩家\x07%N\x01来自：\x04%s %s %s %s，IP地址为：%s", client, continent, country, region, city, ClientIP);
	}
}

//有效玩家实体检测
stock bool IsValidClient(int client, bool AllowBot = true, bool AllowDeath = true, bool AllowSpectator = true, bool AllowReplay = true)
{
	if(client < 1 || client > MaxClients)
	{
		return false;
	}
	if(!IsClientConnected(client) || !IsClientInGame(client))
	{
		return false;
	}
	if(!AllowBot)
	{
		if (IsFakeClient(client))
		{
			return false;
		}
	}
	if(!AllowDeath)
	{
		if (!IsPlayerAlive(client))
		{
			return false;
		}
	}
	if(!AllowSpectator)
	{
		if(GetClientTeam(client) == 3)
		{
			return false;
		}
	}
	if(!AllowReplay)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	return true;
}