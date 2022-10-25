#define PLUGIN_VERSION "1.2.2"

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

ConVar PluginCvarMode, PluginCvarDuration, PluginCvarModesOn, PluginCvarModesOff, PluginCvarGlow, PluginCvarGlowMode, PluginCvarGlowFadeInterval, PluginCvarNotify;
Handle GameMode = INVALID_HANDLE, ExtendedSightTimer = INVALID_HANDLE, ExtendedSightRemoveTimer = INVALID_HANDLE;

int GlowColor, GlowColor_Fade1, GlowColor_Fade2, GlowColor_Fade3, GlowColor_Fade4, GlowColor_Fade5, PropGhost;
bool ExtendedSightActive = false, ExtendedSightExtended = false, ExtendedSightForever = false, isAllowed = false;
char GameName[64] = "";

public Plugin myinfo = 
{
	name = "[L4D2] Extended Survivor Sight",
	author = "Jack'lul",
	description = "Gives Survivors ability to see Special Infected through walls for a configurable time after killing Tank or Witch.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2085325"
}

public void OnPluginStart()
{
	GetGameFolderName(GameName, sizeof(GameName));
	if (!StrEqual(GameName, "left4dead2", false))
	{
		SetFailState("Plugin only supports Left 4 Dead 2!");
		return;
	}
	
	LoadTranslations("l4d2_extendedsight.phrases");
	
	CreateConVar("l4d2_extendedsight_version", PLUGIN_VERSION, "Extended Survivor Sight Version", FCVAR_NONE|FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	
	PluginCvarMode = CreateConVar("l4d2_extendedsight_mode", "3", "什么时候才会奖励扩展视野? 1-当坦克被击杀,2-当witch被击杀, 3-当坦克和witch被击杀, 4-一直开启,0-关闭", FCVAR_NONE|FCVAR_NOTIFY, true, 0.0, true, 4.0);
	PluginCvarNotify = CreateConVar("l4d2_extendedsight_notify", "1", "如何通知扩展视野? 0-关闭,1-提示框,2-聊天框", FCVAR_NONE|FCVAR_NOTIFY, true, 0.0, true, 2.0);
	PluginCvarDuration = CreateConVar("l4d2_extendedsight_duration", "30", "扩展视野持续时长（秒）?", FCVAR_NONE|FCVAR_NOTIFY, true, 10.0);
	PluginCvarGlow = CreateConVar("l4d2_extendedsight_glowcolor", "255 75 75", "扩展视野颜色，RGB值", FCVAR_NONE|FCVAR_NOTIFY);
	PluginCvarGlowMode = CreateConVar("l4d2_extendedsight_glowmode", "1", "扩展视野发光模式. 0-持续发光, 1-逐渐褪色", FCVAR_NONE|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	PluginCvarGlowFadeInterval = CreateConVar("l4d2_extendedsight_glowfadeinterval", "3", "扩展视野褪色之间的间隔", FCVAR_NONE|FCVAR_NOTIFY, true, 1.5, true, 10.0);
	PluginCvarModesOn =	CreateConVar("l4d2_extendedsight_modes_on", "", "这些游戏模式将启用插件. 空=全部", FCVAR_NONE|FCVAR_NOTIFY);
	PluginCvarModesOff = CreateConVar("l4d2_extendedsight_modes_off", "versus,teamversus,scavenge,teamscavenge,mutation12,teamrealismversus,mutation11,mutation13,mutation15,mutation18,mutation19,community3,community6,l4d1vs", "在这些游戏模式下，插件将被禁用. 空=无", FCVAR_NONE|FCVAR_NOTIFY);
	
	RegAdminCmd("sm_extendedsight", Command_ExtendedSight, ADMFLAG_BAN, "Extended Survivor Sight On/Off");
	
	AutoExecConfig(true, "l4d2_extendedsight");
	
	PropGhost = FindSendPropInfo("CTerrorPlayer", "m_isGhost");
	
	HookConVarChange(PluginCvarGlow, Changed_PluginCvarGlow);
}

public void OnConfigsExecuted()
{
	bool CheckAllowed = IsAllowedGameMode();
	
	SetGlowColor();
	
	if(isAllowed == false && GetConVarInt(PluginCvarMode) != 0 && CheckAllowed == true)
	{
		isAllowed = true;
		HookEvent("tank_killed", Event_TankKilled);
		HookEvent("witch_killed", Event_WitchKilled);
		HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	}
	else if(isAllowed == true && (GetConVarInt(PluginCvarMode) == 0 || CheckAllowed == false))
	{
		isAllowed = false;
		UnhookEvent("tank_killed", Event_TankKilled);
		UnhookEvent("witch_killed", Event_WitchKilled);
		UnhookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	}
}

public void OnPluginEnd()
{
	DisableGlow();
}

//---------------------------------------------------------------------------------------------------------------

public void OnMapStart()
{
	if(GetConVarInt(PluginCvarMode) != 0)
	{
		GameMode = FindConVar("mp_gamemode");
		ExtendedSightActive = false;
		ExtendedSightExtended = false;
		ExtendedSightForever = false;
	}
	
	if(GetConVarInt(PluginCvarMode) == 4)
		AddExtendedSight(0.0);
}

public void Event_TankKilled(Event event, const char[] name, bool dontBroadcast)
{	
	if(GetConVarInt(PluginCvarMode) == 1 || GetConVarInt(PluginCvarMode) == 3 && !ExtendedSightForever) 
		AddExtendedSight(GetConVarFloat(PluginCvarDuration));
}

public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	if(GetConVarInt(PluginCvarMode) == 2 || GetConVarInt(PluginCvarMode) == 3 && !ExtendedSightForever) 
		AddExtendedSight(GetConVarFloat(PluginCvarDuration));
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(GetConVarInt(PluginCvarMode) != 4)
		RemoveExtendedSight();
	else
		DisableGlow();
}

public Action Command_ExtendedSight(int client, int args) 
{	
	char arg[5];
	GetCmdArg(1, arg, sizeof(arg));
		
	if(StrEqual(arg, "on", false) || StringToInt(arg) == 1 && args != 0)
	{
		if(!ExtendedSightActive)
		{
			ReplyToCommand(client, "%t", "ACTIVATEDPERMANENTLY");
			AddExtendedSight(0.0);
		}
		else
			ReplyToCommand(client, "%t", "ALREADYACTIVE");
	}
	else if(StrEqual(arg, "off", false) || StringToInt(arg) == 0 && args != 0)
	{
		if(ExtendedSightActive)
		{
			ReplyToCommand(client, "%t", "DEACTIVATED");
			RemoveExtendedSight();
		}
		else
			ReplyToCommand(client, "%t", "NOTACTIVE");
	}
	else
		ReplyToCommand(client, "%t", "COMMANDUSAGE");
	
	return Plugin_Handled;
}

public void Changed_PluginCvarGlow(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetGlowColor();
}

public Action TimerRemoveSight(Handle timer)
{
	RemoveExtendedSight();
	
	if(GetConVarInt(PluginCvarNotify) != 0)
		NotifyPlayers();
}

public Action TimerChangeGlow(Handle timer, any color)
{
	if(ExtendedSightActive)
		SetGlow(color);
	else if (ExtendedSightTimer != INVALID_HANDLE)
	{
		KillTimer(ExtendedSightTimer);
		ExtendedSightTimer = INVALID_HANDLE;
	}
}

public Action TimerGlowFading(Handle timer)
{
	if(ExtendedSightActive)
	{
		CreateTimer(0.1, TimerChangeGlow, GlowColor, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(0.5, TimerChangeGlow, GlowColor_Fade1, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(0.7, TimerChangeGlow, GlowColor_Fade2, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(0.9, TimerChangeGlow, GlowColor_Fade3, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(1.1, TimerChangeGlow, GlowColor_Fade4, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(1.3, TimerChangeGlow, GlowColor_Fade5, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(1.4, TimerChangeGlow, 0, TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (ExtendedSightTimer != INVALID_HANDLE)
	{
		KillTimer(ExtendedSightTimer);
		ExtendedSightTimer = INVALID_HANDLE;
	}
}

//---------------------------------------------------------------------------------------------------------------

void AddExtendedSight(float time)
{
	if(ExtendedSightActive)
	{		
		if (ExtendedSightRemoveTimer != INVALID_HANDLE)
		{
			KillTimer(ExtendedSightRemoveTimer);
			ExtendedSightRemoveTimer = INVALID_HANDLE;	
		}
		ExtendedSightExtended = true;
	}
	
	ExtendedSightActive = true;
	
	if(time == 0.0)
		ExtendedSightForever = true;
	
	if(GetConVarInt(PluginCvarGlowMode) == 1 && !ExtendedSightExtended)
		ExtendedSightTimer = CreateTimer(GetConVarFloat(PluginCvarGlowFadeInterval), TimerGlowFading, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	else if(!ExtendedSightExtended)
		ExtendedSightTimer = CreateTimer(0.1, TimerChangeGlow, GlowColor, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);	
	
	if(time > 0.0 && GetConVarInt(PluginCvarGlowMode) == 1)
		ExtendedSightRemoveTimer = CreateTimer(time, TimerRemoveSight, TIMER_FLAG_NO_MAPCHANGE);
	else if(time > 0.0)
		ExtendedSightRemoveTimer = CreateTimer(time+GetConVarFloat(PluginCvarGlowFadeInterval), TimerRemoveSight, TIMER_FLAG_NO_MAPCHANGE);
		
	if(time > 0.0 && GetConVarInt(PluginCvarNotify) != 0)
		NotifyPlayers();
}

void RemoveExtendedSight()
{
	if(ExtendedSightActive)
	{
		ExtendedSightActive = false;
		ExtendedSightExtended = false;
		ExtendedSightForever = false;
		
		DisableGlow();
	}
}

void SetGlow(any color)
{
	for(int iClient = 1; iClient <= GetMaxClients(); iClient++)
	{
		if(IsClientInGame(iClient) && IsPlayerAlive(iClient) && GetClientTeam(iClient) == 3 && ExtendedSightActive && color != 0 && GetEntData(iClient, PropGhost, 1)!=1)
		{
			SetEntProp(iClient, Prop_Send, "m_iGlowType", 3);
			SetEntProp(iClient, Prop_Send, "m_glowColorOverride", color);
		}
		else if(IsClientInGame(iClient))
		{
			SetEntProp(iClient, Prop_Send, "m_iGlowType", 0);
			SetEntProp(iClient, Prop_Send, "m_glowColorOverride", 0);	
		}
	}
}

void DisableGlow()
{
	for(int iClient = 1; iClient <= GetMaxClients(); iClient++)
	{
		if(IsClientInGame(iClient))
		{
			SetEntProp(iClient, Prop_Send, "m_iGlowType", 0);
			SetEntProp(iClient, Prop_Send, "m_glowColorOverride", 0);	
		}
	}
}

void NotifyPlayers()
{
	for(int iClient = 1; iClient <= GetMaxClients(); iClient++)
	{
		if(IsClientInGame(iClient))
		{
			if(GetClientTeam(iClient) == 2 && GetConVarInt(PluginCvarMode) != 4)
			{
				if(ExtendedSightActive && !ExtendedSightExtended)
				{
					if(GetConVarInt(PluginCvarNotify)==1)
						PrintHintText(iClient, "%t", "ACTIVATED");
					else
						PrintToChat(iClient, "%t", "ACTIVATED");
				}
				else if(ExtendedSightExtended)
				{
					if(GetConVarInt(PluginCvarNotify)==1)
						PrintHintText(iClient, "%t", "DURATIONEXTENDED");
					else
						PrintToChat(iClient, "%t", "DURATIONEXTENDED");
				}
				else
				{	
					if(GetConVarInt(PluginCvarNotify)==1)
						PrintHintText(iClient, "%t", "DEACTIVATED");
					else
						PrintToChat(iClient, "%t", "DEACTIVATED");
				}
			}
		}
	}
}

void SetGlowColor()
{
	char split[3][3];
	char sPluginCvarGlow[64];
	
	GetConVarString(PluginCvarGlow, sPluginCvarGlow, sizeof(sPluginCvarGlow));
	ExplodeString(sPluginCvarGlow, " ", split, 3, 4);
	
	int rgb[3];
	rgb[0] = StringToInt(split[0]);
	rgb[1] = StringToInt(split[1]);
	rgb[2] = StringToInt(split[2]);
	
	GlowColor = rgb[0]+256*rgb[1]+256*256*rgb[2];
	
	GlowColor_Fade1 = (RoundFloat(rgb[0] / 1.5)) + 256 * (RoundFloat(rgb[1] / 1.5)) + 256 * 256 * (RoundFloat(rgb[2] / 1.5));
	GlowColor_Fade2 = (RoundFloat(rgb[0] / 2.0)) + 256 * (RoundFloat(rgb[1] / 2.0)) + 256 * 256 * (RoundFloat(rgb[2] / 2.0));
	GlowColor_Fade3 = (RoundFloat(rgb[0] / 2.5)) + 256 * (RoundFloat(rgb[1] / 2.5)) + 256 * 256 * (RoundFloat(rgb[2] / 2.5));
	GlowColor_Fade4 = (RoundFloat(rgb[0] / 3.0)) + 256 * (RoundFloat(rgb[1] / 3.0)) + 256 * 256 * (RoundFloat(rgb[2] / 3.0));
	GlowColor_Fade5 = (RoundFloat(rgb[0] / 3.5)) + 256 * (RoundFloat(rgb[1] / 3.5)) + 256 * 256 * (RoundFloat(rgb[2] / 3.5));
}

// credits for this code and code in OnConfigsExecuted() goes to Silvers - https://forums.alliedmods.net/member.php?u=85778
bool IsAllowedGameMode()
{
	if( GameMode == INVALID_HANDLE )
		return false;
	
	char sGameModes[64], sGameMode[64];
	GetConVarString(GameMode, sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);
	
	GetConVarString(PluginCvarModesOn, sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}
	
	GetConVarString(PluginCvarModesOff, sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}
	
	return true;
}
