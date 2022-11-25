#pragma newdecls required
/**/
#pragma semicolon 1
#include <sourcemod>
#include <colors>

#define PLUGIN_VERSION "1.3"
#define MAX_LINE_WIDTH 64
#define CheckInterval 3.0
ConVar	
	g_hPluginMode,
	g_hAllowMode,
	g_hDisAllowMode,
	g_hDifficulty,
	g_hServerDealWith,
	g_hLockDifficult,
	g_hDefDifficulty,
	g_hDefMode,
	g_hGameMode;
char
	//g_sLogPath[PLATFORM_MAX_PATH],
	g_sAllowGameMode[512],
	g_sDisAllowGameMode[512],
	g_sDefDifficulty[64],
	g_sDefMode[64],
	g_sCurrentGameMode[32];
bool 
	IsAllowMode = true;
int 
	g_iServerDealWith = 0,
	g_iLockDifficult = 0,
	g_iPluginMode = 0;
Handle
	g_hCheckHandle = null;
public Plugin myinfo =
{
	name = "Restricted game modes",
	author = "东",
	description = "限制服务器模式，锁定游戏难度，当游戏模式不为允许的模式时，锁定模式或重启服务器",
	version = PLUGIN_VERSION,
	url = "https://github.com/fantasylidong/"
}
/*
Changelog
2022.7.13 
1.0 初始版本发布
1.1 增加难度锁定功能
2022.7.14
1.2 自定义设置不允许模式切换为的模式[原自动为战役], 重新设置模式和重启服务器的模式的定时器由1.1的5s延长到了
10s，5s人多的对抗模式很大可能不会重新设置模式
1.3 定时器改为repeat模式，取消handle控制，运行完毕Return Plugin_stop结束计时器
*/
public void  OnPluginStart()
{
	g_hPluginMode = CreateConVar("server_restricted_mode", "1", "游戏模式限制插件使用模式 (0关闭插件, 1白名单模式, 2黑名单模式).", 0, true, 0.0, true, 2.0);
	g_hAllowMode = CreateConVar("server_allow_mode", "coop", "白名单模式.", 0, false, 0.0, false, 0.0);
	g_hDisAllowMode = CreateConVar("server_disallow_mode", "versus,scavenge,mutation2,mutation12,mutation13,mutation15,mutation18", "黑名单模式.", 0, false, 0.0, false, 0.0);
	g_hServerDealWith = CreateConVar("server_deal_with", "1", "服务器碰到不允许模式的处理方式 (1更改为设置好的模式, 2踢出玩家并重启服务器).", 0, true, 1.0, true, 2.0);
	g_hDefMode = CreateConVar("server_default_mode", "coop", "默认模式和不允许模式切换为的模式.", 0, false, 0.0, false, 0.0);
	g_hLockDifficult = CreateConVar("server_lock_difficult", "0", "服务器是否锁定难度.", 0, true, 0.0, true, 1.0);
	g_hDefDifficulty = CreateConVar("server_default_difficult", "Impossible", "服务器锁定难度.", 0, false, 0.0, false, 0.0);
	//BuildPath(Path_SM, g_sLogPath, sizeof(g_sLogPath), "logs/RestrictedGameModes.log");
	
	g_hGameMode = FindConVar("mp_gamemode");
	g_hDifficulty = FindConVar("z_difficulty");
	g_hDifficulty.AddChangeHook(GameDifficult_Changed);
	g_hDefMode.AddChangeHook(ConVarChanged_Cvars);
	g_hPluginMode.AddChangeHook(ConVarChanged_Cvars);
	g_hAllowMode.AddChangeHook(ConVarChanged_Cvars);
	g_hDisAllowMode.AddChangeHook(ConVarChanged_Cvars);
	g_hServerDealWith.AddChangeHook(ConVarChanged_Cvars);
	g_hGameMode.AddChangeHook(Gamemode_Changed);
	
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);

	IsAllowMode = true;
	GetCvars();
	AutoExecConfig(true, "RestrictedGameModes");
}

public Action RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
	CreateTimer(CheckInterval, CheckAllowGamemode, _, TIMER_REPEAT);
	return Plugin_Continue;
}

// *********************
//		获取Cvar值
// *********************
void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void CheckAllow()
{
	GetConVarString(g_hGameMode, g_sCurrentGameMode, sizeof(g_sCurrentGameMode));
	if(g_iPluginMode == 1)
	{
		if( StrContains(g_sAllowGameMode, g_sCurrentGameMode, false) != -1)
			IsAllowMode = true;
		else
			IsAllowMode = false;
		//LogToFileEx(g_sLogPath, "白名单模式:  %s %s是允许的模式", g_sCurrentGameMode, IsAllowMode?"":"不");
	}
	else if(g_iPluginMode == 2)
	{
		if( StrContains(g_sDisAllowGameMode, g_sCurrentGameMode, false) != -1)
			IsAllowMode = false;
		else
			IsAllowMode = true;
		//LogToFileEx(g_sLogPath, "黑名单模式:  %s %s是允许的模式", g_sCurrentGameMode, IsAllowMode?"":"不");
	}
}

public Action CheckAllowGamemode(Handle timer){
	CheckAllow();
	if(!IsAllowMode)
	{
		//LogToFileEx(g_sLogPath, "不允许的模式，重置模式");
		if(g_hCheckHandle == null)
			g_hCheckHandle = CreateTimer(CheckInterval, DealWithGameModeChange, _, TIMER_REPEAT);
		return Plugin_Continue;
	}else{
		return Plugin_Stop;
	}
	
}

//检测是否为允许模式
void Gamemode_Changed(ConVar convar, const char[] oldValue, const char[] newValue){
	GetCvars();
	CreateTimer(CheckInterval, CheckAllowGamemode, _, TIMER_REPEAT);
}

//锁定游戏难度
void GameDifficult_Changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(g_iLockDifficult)
	{
		g_hDifficulty.SetString(g_sDefDifficulty);
		//LogToFileEx(g_sLogPath, "难度锁定: %s -> %s", oldValue, newValue);
	}	
}


void GetCvars()
{
	g_iPluginMode = GetConVarInt(g_hPluginMode);
	g_iServerDealWith = GetConVarInt(g_hServerDealWith);
	g_iLockDifficult = GetConVarInt(g_hLockDifficult);
	GetConVarString(g_hGameMode, g_sCurrentGameMode, sizeof(g_sCurrentGameMode));
	GetConVarString(g_hAllowMode, g_sAllowGameMode, sizeof(g_sAllowGameMode));
	GetConVarString(g_hDisAllowMode, g_sDisAllowGameMode, sizeof(g_sDisAllowGameMode));
	GetConVarString(g_hDefDifficulty, g_sDefDifficulty, sizeof(g_sDefDifficulty));
	GetConVarString(g_hDefMode, g_sDefMode, sizeof(g_sDefMode));
}

Action DealWithGameModeChange(Handle timer)
{
	if(g_iServerDealWith)
	{
		switch(g_iServerDealWith)
		{
			case 1:
			{
				//LogToFileEx(g_sLogPath, "不允许的模式%s，切换为%s模式", g_sCurrentGameMode, g_sDefMode);
				//PrintToChatAll("不允许的模式%s，切换为%s模式", g_sCurrentGameMode, g_sDefMode);
				ServerCommand("sm_cvar mp_gamemode %s", g_sDefMode);
				ServerCommand("mp_gamemode %s", g_sDefMode);
				RestartMap();
				g_hCheckHandle = null;
				return Plugin_Stop;
			}
			case 2:
			{
				//LogToFileEx(g_sLogPath, "不允许的模式%s，重启服务器", g_sCurrentGameMode);
				KickAllPlayer();
				RestartServer();
				g_hCheckHandle = null;
				return Plugin_Stop;
			}
		}
	}
	return Plugin_Continue;
}

//重启地图，进入正常战役模式
void RestartMap()
{
	char mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));
	ServerCommand("changelevel %s", mapname);
}

//踢出所有玩家
public void KickAllPlayer()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && !IsFakeClient(i))
			KickClient(i, "该服务器不允许你游玩%s模式", g_sCurrentGameMode);
	}
}

//thanks fdxx https://github.com/fdxx
void RestartServer()
{
	UnloadAccelerator();
	SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
	ServerCommand("crash");
}

void UnloadAccelerator()
{
	int Id = GetAcceleratorId();
	if (Id != -1)
	{
		ServerCommand("sm exts unload %i 0", Id);
		ServerExecute();
	}
}

//by sorallll
int GetAcceleratorId()
{
	char sBuffer[512];
	ServerCommandEx(sBuffer, sizeof(sBuffer), "sm exts list");
	int index = SplitString(sBuffer, "] Accelerator (", sBuffer, sizeof(sBuffer));
	if(index == -1)
		return -1;

	for(int i = strlen(sBuffer); i >= 0; i--)
	{
		if(sBuffer[i] == '[')
			return StringToInt(sBuffer[i + 1]);
	}

	return -1;
}

// 判断是否有效玩家 id，有效返回 true，无效返回 false
stock bool IsValidClient(int client)
{
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
	{
		return true;
	}
	else
	{
		return false;
	}
}