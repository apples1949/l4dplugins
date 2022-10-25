#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <geoip>
#include <colors>
#include <l4d2util>

#define VERSION "1.6b"


public Plugin myinfo =
{
	name = "Connect Announce",
	author = "Arg!, Yukari190",
	description = "Replacement of default player connection message, allows for custom connection messages",
	version = VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=77306"
};

public void OnPluginStart()
{
	HookEvent("player_disconnect", Event_PlayerDisconnectPre, EventHookMode_Pre);
}

public void OnClientPostAdminCheck(int client)
{
	if (IsValidAndInGame(client) && !IsFakeClient(client) && GetClientCount(true) < MaxClients)
	{
		char rawmsg[301];
		PrintFormattedMessageToAll(rawmsg, client);
		Format(rawmsg, sizeof(rawmsg), "%c%s @ 加入游戏.", 1, rawmsg);
		C_PrintToChatAll("%s", rawmsg);
	}
}

void Event_PlayerDisconnectPre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidAndInGame(client) && !IsFakeClient(client))
	{
		char rawmsg[301], reason[65];
		event.GetString("reason", reason, sizeof(reason));
		ReplaceString(reason, sizeof(reason), "\n", " ");
		PrintFormattedMessageToAll(rawmsg, client);
		Format(rawmsg, sizeof(rawmsg), "%c%s @ 断开连接. {orange}原因: %s", 1, rawmsg, reason);
		C_PrintToChatAll("%s", rawmsg);
	}
}

void PrintFormattedMessageToAll(char rawmsg[301], int client)
{
	char steamid[256], ip[16], country[46];
	bool bIsLanIp;
	
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	GetClientIP(client, ip, sizeof(ip)); 
	bIsLanIp = IsLanIP(ip);
	if (!GeoipCountry(ip, country, sizeof(country)))
	{
		if (bIsLanIp) Format(country, sizeof(country), "%s", "局域网", LANG_SERVER);
		else Format(country, sizeof(country), "%s", "未知的国家", LANG_SERVER);
	}
	if (StrEqual(country, "")) Format(country, sizeof(country), "%s", "未知的国家", LANG_SERVER);
	if (StrContains(country, "United", false) != -1 || StrContains(country, "Republic", false) != -1 || 
	StrContains(country, "Federation", false) != -1 || StrContains(country, "Island", false) != -1 || 
	StrContains(country, "Netherlands", false) != -1 || StrContains(country, "Isle", false) != -1 || 
	StrContains(country, "Bahamas", false) != -1 || StrContains(country, "Maldives", false) != -1 || 
	StrContains(country, "Philippines", false) != -1 || 
	StrContains(country, "Vatican", false) != -1) Format(country, sizeof(country), "The %s", country);
	
	Format(rawmsg, sizeof(rawmsg), "%s {orange}%N {grey}%s {orange}(%s), ", IsClientAdmin(client) ? "管理员" : "玩家", 
	client, steamid, country);
}

bool IsLanIP(char[] src)
{
	char ip4[4][4];
	int ipnum;
	if (ExplodeString(src, ".", ip4, 4, 4) == 4)
	{
		ipnum = StringToInt(ip4[0])*65536 + StringToInt(ip4[1])*256 + StringToInt(ip4[2]);
		if (
			(ipnum >= 655360 && ipnum < 655360+65535) || 
			(ipnum >= 11276288 && ipnum < 11276288+4095) || 
			(ipnum >= 12625920 && ipnum < 12625920+255)
		)
		{
			return true;
		}
	}
	return false;
}

bool IsClientAdmin(int client)
{
	AdminId id = GetUserAdmin(client);
	if (id == INVALID_ADMIN_ID) return false;
	if (
		GetAdminFlag(id, Admin_Reservation) || 
		GetAdminFlag(id, Admin_Root) || 
		GetAdminFlag(id, Admin_Kick) || 
		GetAdminFlag(id, Admin_Generic)
	) return true;
	return false;
}

bool IsValidAndInGame(int client)
{
	if (client && client <= MaxClients && IsClientInGame(client))
	{
		return true;
	}
	else
	{
		return false;
	}
}