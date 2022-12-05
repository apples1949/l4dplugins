#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <l4d2_GetWitchNumber>

#define iArray	4
#define CVAR_FLAGS	FCVAR_NOTIFY

int g_iMultiplesCount;
float g_fMultiples[iArray];
char g_sDifficultyName[iArray][32] = {"简单", "普通", "高级", "专家"};
char g_sDifficultyCode[iArray][32] = {"Easy", "Normal", "Hard", "Impossible"};

bool TankSpawnFinaleVehicleLeaving;
ConVar g_hMultiples;
int    g_iTankSwitch, g_iTankPrompt, g_iTankHealth, g_iWitchSwitch, g_iWitchMaximum, g_iWitchMinimum;
ConVar g_hTankSwitch, g_hTankPrompt, g_hTankHealth, g_hWitchSwitch, g_hWitchMaximum, g_hWitchMinimum;

public Plugin myinfo = 
{
	name = "L4D2 Tank Announcer",
	author = "Visor, 豆瓣酱な, apples194",
	description = "Announce in chat and via a sound when a Tank has spawned",
	version = "1.3.3",
	url = "https://github.com/Attano"
};

public void OnPluginStart()
{
	g_hTankSwitch		= CreateConVar("l4d2_tank_Switch", 		"1", 	"启用坦克出现时血量跟随存活的幸存者人数而增加? 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hTankPrompt		= CreateConVar("l4d2_tank_prompt", 		"2", 	"设置坦克出现时的提示类型. 0=禁用, 1=聊天窗, 2=屏幕中下+聊天窗, 3=屏幕中下.", CVAR_FLAGS);
	g_hMultiples		= CreateConVar("l4d2_tank_Multiples", 	"0.8;1.0;1.5;2.0", "设置游戏难度对应的倍数(留空=使用默认值:1.0).", CVAR_FLAGS);
	g_hTankHealth		= CreateConVar("l4d2_tank_health", 		"2500", "设置每一个活着的幸存者坦克所增加的血量.", CVAR_FLAGS);
	g_hWitchSwitch		= CreateConVar("l4d2_witch_Switch", 	"1", 	"启用女巫出现时血量随机(女巫的默认血量为:1000). 0=禁用, 1=启用随机, 2=设置为最高血量.", CVAR_FLAGS);
	g_hWitchMaximum		= CreateConVar("l4d2_witch_maximum", 	"1500",	"女巫出现时随机的最高血量.", CVAR_FLAGS);
	g_hWitchMinimum		= CreateConVar("l4d2_witch_minimum", 	"800", 	"女巫出现时随机的最低血量.", CVAR_FLAGS);

	g_hTankSwitch.AddChangeHook(iHealthConVarChanged);
	g_hTankPrompt.AddChangeHook(iHealthConVarChanged);
	g_hMultiples.AddChangeHook(iHealthConVarChanged);
	g_hTankHealth.AddChangeHook(iHealthConVarChanged);
	g_hWitchSwitch.AddChangeHook(iHealthConVarChanged);
	g_hWitchMaximum.AddChangeHook(iHealthConVarChanged);
	g_hWitchMinimum.AddChangeHook(iHealthConVarChanged);
	
	HookEvent("round_start", Event_RoundStart);//回合开始.
	HookEvent("round_end", Event_RoundEnd);//回合结束.
	HookEvent("witch_spawn", Event_WitchSpawn, EventHookMode_Pre);
	HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_Pre);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving, EventHookMode_Pre);//救援离开.
	
	AutoExecConfig(true, "l4d2_tank_add_health");//生成指定文件名的CFG.
}

public void OnMapStart()
{
	iHealthCvars();
	TankSpawnFinaleVehicleLeaving = false;
}

public void iHealthConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iHealthCvars();
}

void iHealthCvars()
{
	g_iTankSwitch	= g_hTankSwitch.IntValue;
	g_iTankPrompt	= g_hTankPrompt.IntValue;
	g_iTankHealth	= g_hTankHealth.IntValue;
	g_iWitchSwitch	= g_hWitchSwitch.IntValue;
	g_iWitchMaximum	= g_hWitchMaximum.IntValue;
	g_iWitchMinimum	= g_hWitchMinimum.IntValue;

	char sCmds[512], g_sMultiples[iArray][32];
	g_hMultiples.GetString(sCmds, sizeof(sCmds));
	g_iMultiplesCount = ReplaceString(sCmds, sizeof(sCmds), ";", ";", false);
	ExplodeString(sCmds, ";", g_sMultiples, g_iMultiplesCount + 1, 32);
	
	for (int i = 0; i < iArray; i++)
		g_fMultiples[i] = sCmds[0] == '\0' || IsCharSpace(sCmds[0]) || g_sMultiples[i][0] == '\0' || IsCharSpace(g_sMultiples[i][0]) || !IsCharNumeric(g_sMultiples[i][0]) ? 1.0 : StringToFloat(g_sMultiples[i]);
}
//地图结束.
public void OnMapEnd()
{
	TankSpawnFinaleVehicleLeaving = true;
}

//回合结束.
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	TankSpawnFinaleVehicleLeaving = true;
}

//回合开始.
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	TankSpawnFinaleVehicleLeaving = false;
}

//救援离开时.
public void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
	TankSpawnFinaleVehicleLeaving = true;
}

public void Event_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int Witchid = event.GetInt("witchid");
	
	switch (g_iWitchSwitch)
	{
		case 1:
			IsSetWitchHealth(Witchid, g_iWitchMinimum >= g_iWitchMaximum ? g_iWitchMinimum : GetRandomInt(g_iWitchMinimum, g_iWitchMaximum), "随机");
		case 2:
			IsSetWitchHealth(Witchid, g_iWitchMaximum, "设置");
	}
}

void IsSetWitchHealth(int Witchid, int iHealth, char[] sContent)
{
	IsSetClientHealth(Witchid, iHealth);
	if (!TankSpawnFinaleVehicleLeaving)
		PrintToChatAll("\x04[提示]\x03%s\x05出现,血量%s为\x04:\x03%d", GetWitchName(Witchid), sContent, iHealth);//聊天窗提示.
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iTankSwitch == 0)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsValidClient(client))
	{
		for (int i = 0; i < iArray; i++)
			if (StrEqual(GetGameDifficulty(), g_sDifficultyCode[i], false))
				IsSetTankHealth(client, g_fMultiples[i] == 0 ? 1.0 : g_fMultiples[i], g_sDifficultyName[i]);
	}
}

void IsSetTankHealth(int client, float Multiples, char[] sDiffName)
{
	int iHealth = RoundFloat(Multiples * (IsCountPlayersTeam() * g_iTankHealth));
	IsSetClientHealth(client, iHealth);
	
	if(g_iTankPrompt != 0)
	{
		if (!TankSpawnFinaleVehicleLeaving)
		{
			if(g_iTankPrompt == 1 || g_iTankPrompt == 2)
				PrintToChatAll("\x04[提示]\x03坦克%s\x05出现\x04,\x05难度\x04:\x03%s\x04,\x05存活\x03%d\x05名幸存者,血量调整为\x04:\x03%d", GetSurvivorName(client, true), sDiffName, IsCountPlayersTeam(), GetClientHealth(client));//聊天窗提示.
			if(g_iTankPrompt == 2 || g_iTankPrompt == 3)
				PrintHintTextToAll("坦克%s出现,难度:%s ,存活%d名幸存者,血量调整为:%i", GetSurvivorName(client, false), sDiffName, IsCountPlayersTeam(), GetClientHealth(client));//屏幕中下提示.
		}
	}
}

void IsSetClientHealth(int client, int iHealth)
{
	SetEntProp(client, Prop_Data, "m_iHealth", iHealth);
	SetEntProp(client, Prop_Data, "m_iMaxHealth", iHealth);
}

char[] GetWitchName(int iWitchid)
{
	char clName[32];
	if(GetWitchNumber(iWitchid) == 0) 
		strcopy(clName, sizeof(clName), "女巫");
	else
		FormatEx(clName, sizeof(clName), "女巫(%d)", GetWitchNumber(iWitchid));
	
	return clName;
}

char[] GetSurvivorName(int client, bool bPromptType)
{
	char sName[32];
	GetClientName(client, sName, sizeof(sName));
	if (!IsFakeClient(client))
		FormatEx(sName, sizeof(sName), "%s%N", !bPromptType ? "" : "\x04", sName);
	else
		SplitString(sName, "Tank", sName, sizeof(sName));
	return sName;
}

char[] GetGameDifficulty()
{
	char sGameDifficulty[32];
	GetConVarString(FindConVar("z_difficulty"), sGameDifficulty, sizeof(sGameDifficulty));
	return sGameDifficulty;
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

int IsCountPlayersTeam()
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2)
			iCount++;
	}
	return iCount;
}