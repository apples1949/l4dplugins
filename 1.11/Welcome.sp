#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <colors> //http://forums.alliedmods.net/showthread.php?t=96831
#include <geoip>
#include <dbi>
//其实这 3个是多余的. 只是给你们参考看而已
#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SURVIVOR 2
#define L4D_TEAM_SPECTATOR 1
#define CONVAR_FLAGS_PLUGIN FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY
#define DB_CONF_NAME "ip"
static bool:g_bCooldown[MAXPLAYERS + 1] = {false};
new String:g_text[1024];
new ipnum = 0;
new String:logFile[1024];
new Handle:Database = INVALID_HANDLE;
new Handle:SwitchTeamDEnabled  = INVALID_HANDLE;
new bool:g_ClientPutInServer[MAXPLAYERS+1] = {false};

public Plugin:myinfo =    
{   
	name = "玩家进入&玩家退出&玩家转换队伍提示&SteamID&IP显示&国家显示&城市SQL",   
	author = "fenghf",   
	description = "Left 4 Dead 1 & 2",   
	version = "2.4",   
	url = "http://bbs.3dmgame.com/thread-2098382-1-2.html"  
}   

public OnPluginStart()   
{   
	BuildPath(Path_SM, logFile, sizeof(logFile), "logs/Ip_Info.log");
	RegConsoleCmd("sm_ip", ipCommand,"查看自己信息",FCVAR_PLUGIN);
	
	SwitchTeamDEnabled = CreateConVar("l4d_switchteamdenabled", "1", "开启关闭转队提示", CONVAR_FLAGS_PLUGIN);
	
	HookEvent("player_team",Event_PlayerChangeTeam); 
	//SQL_TConnect(DBConnect, "ip");
	// Init MySQL connections
	if (!ConnectDB())
	{
		SetFailState("Connecting to database failed. Read error log for further details.");
		return;
	}
}

public DBConnect(Handle:owner, Handle:hndl, const String:error[], any:data) 
{
	if (hndl == INVALID_HANDLE)
	{
		LogToFile(logFile, "1 Query Failed DBConnect Could not connect to the Database: %s", error);
		return;
	}
	Database = hndl;
}
bool:ConnectDB()
{
	if (Database != INVALID_HANDLE)
		return true;

	if (SQL_CheckConfig(DB_CONF_NAME))
	{
		new String:Error[256];
		Database = SQL_Connect(DB_CONF_NAME, true, Error, sizeof(Error));

		if (Database == INVALID_HANDLE)
		{
			LogError("Failed to connect to database: %s", Error);
			return false;
		}
		else if (!SQL_FastQuery(Database, "SET NAMES 'utf8'"))
		{
			if (SQL_GetError(Database, Error, sizeof(Error)))
				LogToFile(logFile,"2 Failed to update encoding to UTF8: %s", Error);
			else
				LogToFile(logFile,"3 Failed to update encoding to UTF8: unknown");
		}
	}
	else
	{
		LogToFile(logFile,"Databases.cfg missing '%s' entry!", DB_CONF_NAME);
		return false;
	}
	
	return true;
}
bool:GetIpConsideration(String:src[16])
{
	decl String:ip4[4][4];
	new ipnums;
	if(ExplodeString(src, ".", ip4, 4, 4) == 4)
	{
		ipnum = (StringToInt(ip4[0])*256*256*256) + (StringToInt(ip4[1])*256*256) + (StringToInt(ip4[2])*256) + (StringToInt(ip4[3])-1);
		ipnums = ipnum;
		//ipnum = StringToInt(ip4[0])*65536 + StringToInt(ip4[1])*256 + StringToInt(ip4[2]);
		{
			//PrintToChatAll("\x04计算:\x05%d", ipnum);//测试用的
			IpSql(ipnums);
		}
		/*
		if((ipnum >= 655360 && ipnum < 655360+65535) || (ipnum >= 11276288 && ipnum < 11276288+4095) || (ipnum >= 12625920 && ipnum < 12625920+255))
		{
			
		}
		*/
	} 
	return false;
}

IpSql(ipnums)
{
	//decl String:utfquery[32];
	decl String:query[1024];
	//new client;
	Format(query, sizeof(query), "SELECT * FROM ipdata WHERE ipstart <= %d AND %d <= ipend", ipnums, ipnums);
	new Handle:hResult = SQL_Query(Database, query);
	if (hResult != INVALID_HANDLE) 
	{
		while (SQL_FetchRow(hResult)) 
		{
			new field; 
			SQL_FieldNameToNum(hResult, "ipinfo", field); 
			SQL_FetchString(hResult, field, query, sizeof(query)); 
			g_text = query;
            //C_PrintToChatAll("{blue}[信息]:{olive}%s", query);
		}
		CloseHandle(hResult); 
	} 
}
	//另一种方法
/*	SQL_TQuery(Database, GetIpDB, query, client, DBPrio_High);//436207616 452984831 美国 弗吉尼亚州 
}
public GetIpDB( Handle:owner, Handle:hndl, const String:error[], any:client)
{
	//decl String:ipinfoss[255];
	new ipstartss, ipendss;
	if (hndl != INVALID_HANDLE)
	{
		while (SQL_FetchRow(hndl))
		{
			ipstartss = SQL_FetchInt(hndl, 0);
			ipendss = SQL_FetchInt(hndl, 1);
			SQL_FetchString(hndl, 2, g_text, 1024);
			
			//PrintToChatAll("\x04来自:\x05%s", g_text);//测试用的
			//PrintToChatAll("\x04计算:\x05%i", ipnum);//测试用的
			PrintToConsole(client, "[IP] 在数据库中发现: %s, %i, %i, 计算:%i", g_text, ipstartss, ipendss, ipnum);
			
		}
		CloseHandle(hndl);
	}
	else
	{
		PrintToConsole(client,"4 [IP] - ParseIP: DB Query failed! %s", error);
	}
}
*/
public OnClientPutInServer(client)
{
	if (IsFakeClient(client))
		return;
	g_ClientPutInServer[client] = true;
	ipCommand(client, 0);
}

//public OnClientAuthorized(client,const String:SteamId[])
public OnClientConnected(client)   
{   
	g_ClientPutInServer[client] = true;
	if (!IsFakeClient(client) && g_ClientPutInServer[client])
	{
		decl String:ClientIP[16];
		GetClientIP(client, ClientIP, sizeof(ClientIP));
		decl String:Name[128];
		GetClientName(client, Name, sizeof(Name));
		new String:SteamId[128];
		GetClientAuthString(client, SteamId, sizeof(SteamId), true);
		decl String:country[46];
		new bool:Getipinfo;
		Getipinfo = GetIpConsideration(ClientIP);
		if (Getipinfo)
		{
			//不用编辑
		}
		if(GeoipCountry(ClientIP, country, 45) && !IsFakeClient(client))
		{   
			C_PrintToChatAll("{olive} %N {blue}加入游戏了{default}! {default}%s .\n {default}IP: {olive}%s  {default}来自:{olive}%s %s", client, SteamId, ClientIP, country, g_text);
			PrintToServer(" %N 加入游戏了! %s  IP: %s  来自:%s %s %i", client, SteamId, ClientIP, country, g_text, ipnum);
		}
		else if(!IsFakeClient(client))
		{
			C_PrintToChatAll("{olive} %N {blue}加入游戏了{default}! {default}%s .\n {default}IP: {olive}%s  {default}来自:{olive}",  client, SteamId, ClientIP);
			PrintToServer(" %N 加入游戏了! %s  IP: %s  来自:局域网", client, SteamId, ClientIP);
		}
		CreateTimer(0.5, Cooldown_Timer, client);
	}
}

public Event_PlayerChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userID = GetClientOfUserId(GetEventInt(event, "userid"));
	new userTeam = GetEventInt(event, "team");
	if (userID == 0) 
		return;
	g_ClientPutInServer[userID] = true;
	new String:SteamId[128];
	GetClientAuthString(userID, SteamId, sizeof(SteamId), false);
	if (StrEqual(SteamId, "BOT"))
		return;
	if (GetConVarInt(SwitchTeamDEnabled) == 0)
		return;
	decl String:ClientIP[16];
	GetClientIP(userID, ClientIP, sizeof(ClientIP));
	
	decl String:country[46];
	new bool:Getipinfo;
	Getipinfo = GetIpConsideration(ClientIP);
	
	/*if(userID==0)
		return ;
	*/
	if (Getipinfo)
	{
		//不用编辑
	}
	if (g_ClientPutInServer[userID])
	{
		if(userTeam==L4D_TEAM_SPECTATOR && GeoipCountry(ClientIP, country, 45) && !IsFakeClient(userID))
		{
			C_PrintToChatAll("{olive} %N {default}加入旁观{default}! {olive}%s .\n {default}IP: {olive}%s  {default}来自:{olive}%s %s", userID, SteamId, ClientIP, country, g_text);
			PrintToServer(" %N 加入旁观! %s  IP: %s  来自:%s %s %i", userID, SteamId, ClientIP, country, g_text, ipnum);
		}
		else if(userTeam==L4D_TEAM_SPECTATOR && !IsFakeClient(userID))
		{
			PrintToChatAll("\x04 %N \x01 加入旁观\x01 \x05%s .\n \x04IP: \x05%s  \x04来自:\x05局域网",  userID, SteamId, ClientIP);
		}
		if(userTeam==L4D_TEAM_SURVIVOR && GeoipCountry(ClientIP, country, 45) && !IsFakeClient(userID))
		{
			C_PrintToChatAll("{olive} %N {blue}加入幸存者{default}! {olive}%s \n {default}IP: {olive}%s  {default}来自:{olive}%s %s", userID, SteamId, ClientIP, country, g_text);
			PrintToServer(" %N 加入幸存者! %s  IP: %s  来自:%s %s %i", userID, SteamId, ClientIP, country, g_text, ipnum);
		}
		else if(userTeam==L4D_TEAM_SURVIVOR && !IsFakeClient(userID))
		{
			PrintToChatAll("\x04 %N \x01 加入幸存者\x01 \x05%s .\n \x04IP: \x05%s  \x04来自:\x05局域网",  userID, SteamId, ClientIP);
		}
		if(userTeam==L4D_TEAM_INFECTED && GeoipCountry(ClientIP, country, 45) && !IsFakeClient(userID))
		{
			C_PrintToChatAll("{olive} %N {red}加入感染者{default}! {olive}%s .\n {default}IP: {olive}%s  {default}来自:{olive}%s %s", userID, SteamId, ClientIP, country, g_text);
			PrintToServer(" %N 加入感染者! %s  IP: %s  来自:%s %s %i", userID, SteamId, ClientIP, country, g_text, ipnum);
		}
		else if(userTeam==L4D_TEAM_INFECTED && !IsFakeClient(userID))
		{
			PrintToChatAll("\x04 %N \x01 加入感染者\x01 \x05%s \n \x04IP: \x05%s  \x04来自:\x05局域网", userID, SteamId, ClientIP);
		}
	}
}
public OnClientDisconnect(client)
{   
	if(!IsFakeClient(client))
	{   
		PrintToChatAll("\x04 %N \x01 退出游戏\x01 \x04 (づˉ*ˉ)づ\x03!",client);  
	}
}
public Action:ipCommand(client, args)
{
	if (g_bCooldown[client]) return Plugin_Handled;
	g_bCooldown[client] = true;
	
	decl String:ClientIP[16];
	GetClientIP(client, ClientIP, sizeof(ClientIP));
	
	new String:SteamId[128];
	GetClientAuthString(client, SteamId, sizeof(SteamId), false);
	
	decl String:country[46];
	
	new bool:Getipinfo;
	Getipinfo = GetIpConsideration(ClientIP);
	
	if (Getipinfo)
	{
		//不用编辑
	}
	new const maxLen = 512;
	decl String:result[maxLen];

	Format(result, maxLen, "\n================================================\n");

	Format(result, maxLen, "%s 玩家信息\n", result);

	Format(result, maxLen, "%s 名字: %N \n", result, client);
	Format(result, maxLen, "%s steamID: %s \n", result, SteamId);
	Format(result, maxLen, "%s IP: %s \n", result, ClientIP);
	Format(result, maxLen, "%s 来自: %s  %s \n", result, country, g_text);
	Format(result, maxLen, "%s\n", result);

	Format(result, maxLen, "%s=================================================\n", result);

	PrintToConsole(client, result);

	ipnum = 0;
	C_PrintToChat(client,"{olive} 输入 {red}!ip{default}在控制台查看自己信息");
	CreateTimer(0.5, Cooldown_Timer, client);
	return Plugin_Handled;
}
public Action:Cooldown_Timer(Handle:timer, any:client)
{
	g_bCooldown[client] = false;
	g_ClientPutInServer[client] = false;
	return Plugin_Stop;
}