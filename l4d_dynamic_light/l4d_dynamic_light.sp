/*
*	Dynamic Light
*	Copyright (C) 2022 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.10"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Dynamic Light
*	Author	:	SilverShot
*	Descrp	:	Teleports a light_dynamic entity to where survivors are pointing with flashlights on.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=186558
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.10 (07-Feb-2022)
	- Fixed compile warnings. They did not show up before.

1.9 (06-Feb-2022)
	- Fixed the light potentially teleporting behind when too close to an object. Thanks to "KrutoyKolbas" for reporting.

1.8 (15-Feb-2021)
	- Fixed not excluding the Molotov when "l4d_dynamic_light_guns" cvar was set to 1. Thanks to "HarryPotter" for fixing.

1.7 (05-Oct-2020)
	- Added Traditional Chinese abd Simplified Chinese translations - Thanks to "HarryPotter".
	- Fixed cvar "l4d_dynamic_light_hints" displaying hints when it shouldn't. Thanks to "HarryPotter" for reporting.

1.6 (05-Oct-2020)
	- Added cvar "l4d_dynamic_light_guns" to control if the light works on weapons only or everything.

1.5 (30-Sep-2020)
	- Fixed compile errors on SM 1.11.
	- Fixed rare "OnPlayerRunCmd" throwing client "not connected" or "not in game" errors.

1.4 (10-May-2020)
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Fixed Cola Bottles not blocking the light.
	- Fixed not setting the default on/off state when a client connects.
	- Various changes to tidy up code.

1.3 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.2 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
	- Changed cvar "l4d_dynamic_light_hide" to use value 2 = Only show to the owner.
	- Changed cvar "l4d_dynamic_light_modes_tog" now supports L4D1.
	- Fixed light sometimes turning off when pounce has ended.
	- Removed instructor hints due to Valve: FCVAR_SERVER_CAN_EXECUTE prevented server running command: gameinstructor_enable.

1.1 (15-Jun-2012)
	- Added German translations - Thanks to "Don't Fear The Reaper".
	- Fixed the light not being teleported with the cvar "l4d_dynamic_light_fade" set to 0.

1.0 (01-Jun-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS				FCVAR_NOTIFY
#define CHAT_TAG				"\x05[Dynamic Light] \x01"


// Cvar Handles/Variables
ConVar g_hCvarAllow, g_hCvarAlpha, g_hCvarBots, g_hCvarColor, g_hCvarDefault, g_hCvarDist, g_hCvarFade, g_hCvarGuns, g_hCvarHide, g_hCvarHint, g_hCvarHints, g_hCvarHull, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarMPGameMode;
int g_iCvarAlpha, g_iCvarBots, g_iCvarColor, g_iCvarDefault, g_iCvarDist, g_iCvarFade, g_iCvarGuns, g_iCvarHide, g_iCvarHint, g_iCvarHints, g_iCvarHull;
bool g_bCvarAllow, g_bMapStarted;

// Plugin Variables
int g_iLightButton[MAXPLAYERS+1], g_iLightIndex[MAXPLAYERS+1], g_iLightState[MAXPLAYERS+1], g_iLightToggle[MAXPLAYERS+1], g_iLightWasUsed[MAXPLAYERS+1], g_iPlayerEnum[MAXPLAYERS+1], g_iTransmit[MAXPLAYERS+1], g_iWeaponIndex[MAXPLAYERS+1];
bool g_bLeft4Dead2;
float g_fTime[MAXPLAYERS+1];


enum
{
	ENUM_INCAPPED	= (1 << 0),
	ENUM_INSTART	= (1 << 1),
	ENUM_BLOCKED	= (1 << 2),
	ENUM_POUNCED	= (1 << 3),
	ENUM_ONLEDGE	= (1 << 4),
	ENUM_INREVIVE	= (1 << 5),
	ENUM_DISTANCE	= (1 << 6),
	ENUM_BLOCK		= (1 << 7)
}



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Dynamic Light",
	author = "SilverShot",
	description = "Teleports a light_dynamic entity to where survivors are pointing with flashlights on.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=186558"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("dynamic_light.phrases");

	g_hCvarAllow =		CreateConVar(	"l4d_dynamic_light_allow",			"1",			"0=关闭插件, 1=开启插件.", CVAR_FLAGS );
	g_hCvarBots =		CreateConVar(	"l4d_dynamic_light_bots",			"0",			"0=否，1=允许机器人拥有动态灯光。", CVAR_FLAGS );
	g_hCvarAlpha =		CreateConVar(	"l4d_dynamic_light_bright",			"255.0",		"灯光亮度.", CVAR_FLAGS );
	g_hCvarColor =		CreateConVar(	"l4d_dynamic_light_color",			"250 250 200",	"灯光颜色 三个数值在0-255之间的红绿蓝RGB值 用空格隔开.", CVAR_FLAGS );
	g_hCvarDefault =	CreateConVar(	"l4d_dynamic_light_default",		"0",			"0=关，1=开。玩家加入时灯光的默认状态", CVAR_FLAGS );
	g_hCvarDist =		CreateConVar(	"l4d_dynamic_light_distance",		"1000",			"灯光在不亮之前照射的距离", CVAR_FLAGS );
	g_hCvarFade =		CreateConVar(	"l4d_dynamic_light_fade",			"500",			0=光照到终点的距离。其他值从这个距离开始渐渐减弱灯光的亮度。", CVAR_FLAGS );
	g_hCvarGuns =		CreateConVar(	"l4d_dynamic_light_guns",			"0",			"0=所有武器和物品。1=只有枪械。灯光对哪些物品/武器有效", CVAR_FLAGS );
	g_hCvarHide =		CreateConVar(	"l4d_dynamic_light_hide",			"2",			"0=向所有玩家显示动态光。1=隐藏动态光，所以只有其他玩家可以看到它。2=只显示给主人", CVAR_FLAGS );
	g_hCvarHint =		CreateConVar(	"l4d_dynamic_light_hint",			"2",			"1=打印到聊天框，2=提示框", CVAR_FLAGS );
	g_hCvarHints =		CreateConVar(	"l4d_dynamic_light_hints",			"3",			"0=关闭。1=第一次使用手电筒时显示提示, 2=切换时显示状态, 3=同时显示.", CVAR_FLAGS );
	g_hCvarHull =		CreateConVar(	"l4d_dynamic_light_hull",			"1",			"0=直接追踪到他们的目标位置。1=追踪船体以探测附近的实体", CVAR_FLAGS );
	g_hCvarModes =		CreateConVar(	"l4d_dynamic_light_modes",			"",				"在这些游戏模式中打开该插件，用逗号分开（没有空格）(空=全部)", CVAR_FLAGS );
	g_hCvarModesOff =	CreateConVar(	"l4d_dynamic_light_modes_off",		"",				" 在这些游戏模式中关闭该插件，用逗号（没有空格）分开(空=无)", CVAR_FLAGS );
	g_hCvarModesTog = 	CreateConVar(	"l4d_dynamic_light_modes_tog",		"0",			"在这些游戏模式中打开该插件。0=全部, 1=战役, 2=生还者, 4=对抗, 8=清道夫。数字相加", CVAR_FLAGS );
	CreateConVar(						"l4d_dynamic_light_version",		PLUGIN_VERSION,	"Dynamic Light plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d_dynamic_light");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarBots.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarAlpha.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarColor.AddChangeHook(ConVarChanged_Color);
	g_hCvarDefault.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDist.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarFade.AddChangeHook(ConVarChanged_Fade);
	g_hCvarGuns.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHide.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHint.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHints.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHull.AddChangeHook(ConVarChanged_Cvars);
}

public void OnPluginEnd()
{
	for( int i = 1; i <= MaxClients; i++ )
		DeleteLight(i);
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	char sColor[16];
	g_hCvarColor.GetString(sColor, sizeof(sColor));
	g_iCvarColor = GetColor(sColor);
	g_iCvarAlpha = g_hCvarAlpha.IntValue;
	g_iCvarBots = g_hCvarBots.IntValue;
	g_iCvarDefault = g_hCvarDefault.IntValue;
	g_iCvarDist = g_hCvarDist.IntValue;
	g_iCvarFade = g_hCvarFade.IntValue;
	g_iCvarGuns = g_hCvarGuns.IntValue;
	g_iCvarHide = g_hCvarHide.IntValue;
	g_iCvarHint = g_hCvarHint.IntValue;
	g_iCvarHints = g_hCvarHints.IntValue;
	g_iCvarHull = g_hCvarHull.IntValue;
}

public void ConVarChanged_Color(Handle convar, const char[] oldValue, const char[] newValue)
{
	char sColor[16];
	g_hCvarColor.GetString(sColor, sizeof(sColor));

	for( int i = 0; i <= MaxClients; i++ )
	{
		if( IsValidEntRef(g_iLightIndex[i]) )
		{
			SetVariantString(sColor);
			AcceptEntityInput(g_iLightIndex[i], "color");
		}
	}
}

public void ConVarChanged_Fade(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_iCvarFade = g_hCvarFade.IntValue;

	if( g_iCvarFade == 0 )
	{
		for( int i = 0; i <= MaxClients; i++ )
		{
			if( IsValidEntRef(g_iLightIndex[i]) )
			{
				SetVariantInt(g_iCvarAlpha);
				AcceptEntityInput(g_iLightIndex[i], "distance");
			}
		}
	}
}

int GetColor(char[] sTemp)
{
	if( sTemp[0] == 0 )
		return 0;

	char sColors[3][4];
	int color = ExplodeString(sTemp, " ", sColors, sizeof(sColors), sizeof(sColors[]));

	if( color != 3 )
		return 0;

	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);

	return color;
}

void IsAllowed()
{
	bool bAllowCvar = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bAllowCvar == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvents();

		for( int i = 1; i <= MaxClients; i++ )
		{
			g_iLightToggle[i] = g_iCvarDefault;
		}
	}

	else if( g_bCvarAllow == true && (bAllowCvar == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvents();

		for( int i = 1; i <= MaxClients; i++ )
		{
			DeleteLight(i);
		}
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		if( g_bMapStarted == false )
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if( IsValidEntity(entity) )
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void OnClientConnected(int client)
{
	g_iLightToggle[client] = g_iCvarDefault;
}

void HookEvents()
{
	HookEvent("round_start",			Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_ledge_grab",		Event_LedgeGrab);
	HookEvent("player_spawn",			Event_PlayerSpawn);
	HookEvent("revive_begin",			Event_ReviveStart);
	HookEvent("revive_end",				Event_ReviveEnd);
	HookEvent("revive_success",			Event_ReviveSuccess);
	HookEvent("player_death",			Event_Unblock);
	HookEvent("lunge_pounce",			Event_BlockHunter);
	HookEvent("pounce_end",				Event_BlockEndHunt);
	HookEvent("tongue_grab",			Event_BlockStart);
	HookEvent("tongue_release",			Event_BlockEnd);

	if( g_bLeft4Dead2 )
	{
		HookEvent("charger_pummel_start",	Event_BlockStart);
		HookEvent("charger_carry_start",	Event_BlockStart);
		HookEvent("charger_carry_end",		Event_BlockEnd);
		HookEvent("charger_pummel_end",		Event_BlockEnd);
		HookEvent("jockey_ride",			Event_BlockStart);
		HookEvent("jockey_ride_end",		Event_BlockEnd);
	}
}

void UnhookEvents()
{
	UnhookEvent("round_start",			Event_RoundStart,	EventHookMode_PostNoCopy);
	UnhookEvent("player_ledge_grab",	Event_LedgeGrab);
	UnhookEvent("player_spawn",			Event_PlayerSpawn);
	UnhookEvent("revive_begin",			Event_ReviveStart);
	UnhookEvent("revive_end",			Event_ReviveEnd);
	UnhookEvent("revive_success",		Event_ReviveSuccess);
	UnhookEvent("player_death",			Event_Unblock);
	UnhookEvent("lunge_pounce",			Event_BlockHunter);
	UnhookEvent("pounce_end",			Event_BlockEndHunt);
	UnhookEvent("tongue_grab",			Event_BlockStart);
	UnhookEvent("tongue_release",		Event_BlockEnd);

	if( g_bLeft4Dead2 )
	{
		UnhookEvent("charger_pummel_start",		Event_BlockStart);
		UnhookEvent("charger_carry_start",		Event_BlockStart);
		UnhookEvent("charger_carry_end",		Event_BlockEnd);
		UnhookEvent("charger_pummel_end",		Event_BlockEnd);
		UnhookEvent("jockey_ride",				Event_BlockStart);
		UnhookEvent("jockey_ride_end",			Event_BlockEnd);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 1; i < MAXPLAYERS; i++ )
	{
		g_iLightWasUsed[i] = 0;
		g_iPlayerEnum[i] = 0;
	}
}

public void Event_BlockUserEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if( client > 0 )
		g_iPlayerEnum[client] &= ~ENUM_BLOCKED;
}

public void Event_BlockStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if( client > 0 )
		g_iPlayerEnum[client] |= ENUM_BLOCKED;
}

public void Event_BlockEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if( client > 0 )
		g_iPlayerEnum[client] &= ~ENUM_BLOCKED;
}

public void Event_BlockHunter(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if( client > 0 )
		g_iPlayerEnum[client] |= ENUM_POUNCED;
}

public void Event_BlockEndHunt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if( client > 0 )
	{
		g_fTime[client] = GetGameTime() - 1.0;
		g_iPlayerEnum[client] &= ~ENUM_POUNCED;
	}
}

public void Event_LedgeGrab(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client > 0 )
		g_iPlayerEnum[client] |= ENUM_ONLEDGE;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client > 0 )
	{
		g_iPlayerEnum[client] = 0;
	}
}

public void Event_ReviveStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if( client > 0 )
		g_iPlayerEnum[client] |= ENUM_INREVIVE;

	client = GetClientOfUserId(event.GetInt("userid"));
	if( client > 0 )
		g_iPlayerEnum[client] |= ENUM_INREVIVE;
}

public void Event_ReviveEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if( client > 0 )
		g_iPlayerEnum[client] &= ~ENUM_INREVIVE;

	client = GetClientOfUserId(event.GetInt("userid"));
	if( client > 0 )
		g_iPlayerEnum[client] &= ~ENUM_INREVIVE;
}

public void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if( client > 0 )
	{
		g_iPlayerEnum[client] &= ~ENUM_INREVIVE;
		g_iPlayerEnum[client] &= ~ENUM_ONLEDGE;
	}

	client = GetClientOfUserId(event.GetInt("userid"));
	if( client > 0 )
		g_iPlayerEnum[client] &= ~ENUM_INREVIVE;
}

public void Event_Unblock(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client > 0)
		g_iPlayerEnum[client] = 0;
}

void DisplayHint(int client, int type)
{
	int hint = g_iCvarHint;
	if( hint == 3 )			hint = 1; // Can no longer support instructor hints
	else if( hint == 4 )	hint = 2;

	switch ( hint )
	{
		case 1:		// Print To Chat
		{
			switch( type )
			{
				case 1:			PrintToChat(client, "%s%T", CHAT_TAG, "DynamicLight_Toggle", client);
				case 2:			PrintToChat(client, "%s%T", CHAT_TAG, "DynamicLight_TurnedOff", client);
				case 3:			PrintToChat(client, "%s%T", CHAT_TAG, "DynamicLight_TurnedOn", client);
			}
		}

		case 2:		// Print Hint Text
		{
			switch( type )
			{
				case 1:			PrintHintText(client, "%T", "DynamicLight_Toggle", client);
				case 2:			PrintHintText(client, "%T", "DynamicLight_TurnedOff", client);
				case 3:			PrintHintText(client, "%T", "DynamicLight_TurnedOn", client);
			}
		}
	}
}

// ====================================================================================================
//					DYNAMIC LIGHT ON/OFF
// ====================================================================================================
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if( g_bCvarAllow && IsClientInGame(client) )
	{
		if( g_iCvarBots == 0 && IsFakeClient(client) )
			return Plugin_Continue;


		int entity = g_iLightIndex[client];

		if( GetClientTeam(client) != 2 || !IsPlayerAlive(client) )
		{
			if( IsValidEntRef(entity) == true )
				DeleteLight(client);

			return Plugin_Continue;
		}


		// Missing light, create entity
		if( IsValidEntRef(entity) == false )
		{
			entity = CreateLight(client);
			g_iLightState[client] = 1;
		}


		// Check the players current weapon
		int index = g_iWeaponIndex[client];
		int active = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");

		if( index != active )
		{
			g_iWeaponIndex[client] = active;

			if( active == -1  )
			{
				g_iPlayerEnum[client] |= ENUM_BLOCK;
			}
			else
			{
				if( g_iCvarGuns == 1 )
				{
					static char sTemp[32];
					GetClientWeapon(client, sTemp, sizeof(sTemp));

					if( strcmp(sTemp[7], "melee") == 0 ||
						strcmp(sTemp[7], "chainsaw") == 0 ||
						strcmp(sTemp[7], "vomitjar") == 0 ||
						strcmp(sTemp[7], "pipe_bomb") == 0 ||
						strcmp(sTemp[7], "molotov") == 0 ||
						strcmp(sTemp[7], "defibrillator") == 0 ||
						strcmp(sTemp[7], "first_aid_kit") == 0 ||
						strcmp(sTemp[7], "upgradepack_explosive") == 0 ||
						strcmp(sTemp[7], "upgradepack_incendiary") == 0 ||
						strcmp(sTemp[7], "first_aid_kit") == 0 ||
						strcmp(sTemp[7], "pain_pills") == 0 ||
						strcmp(sTemp[7], "adrenaline") == 0 ||
						strcmp(sTemp[7], "cola_bottles") == 0 ||
						strcmp(sTemp[7], "fireworkcrate") == 0 ||
						strcmp(sTemp[7], "gascan") == 0 ||
						strcmp(sTemp[7], "gnome") == 0 ||
						strcmp(sTemp[7], "oxygentank") == 0 ||
						strcmp(sTemp[7], "propanetank") == 0
					)
						g_iPlayerEnum[client] |= ENUM_BLOCK;
					else
						g_iPlayerEnum[client] &= ~ENUM_BLOCK;
				}
				else
				{
					g_iPlayerEnum[client] &= ~ENUM_BLOCK;
				}
			}
		}


		// Player has light on or off?
		int playerenum = g_iPlayerEnum[client];


		// Get player light state
		if( playerenum == 0 && GetEntProp(client, Prop_Send, "m_fEffects") & (2<<1) )
		{
			// First use hint
			if( g_iCvarHints & 1 && g_iLightWasUsed[client] == 0 )
			{
				g_iLightWasUsed[client] = 1;
				DisplayHint(client, 1);
			}

			// Light toggle
			if( g_iLightButton[client] == 0 )
			{
				float time = GetGameTime();

				if( time - g_fTime[client] <= 0.5 )
				{
					g_iLightToggle[client] = !g_iLightToggle[client];

					if( g_iCvarHints & 2 )
						DisplayHint(client, g_iLightToggle[client] + 2);
				}

				g_iLightButton[client] = 1;
				g_fTime[client] = time;
			}

			// Turn off light
			if( g_iLightToggle[client] == 0 )
			{
				if( g_iLightState[client] == 1 )
				{
					AcceptEntityInput(entity, "TurnOff");
					g_iLightState[client] = 0;
				}
			}
			else
			{
				TeleportDynamicLight(client, entity);
			}
		}
		else
		{
			if( !(playerenum & ENUM_BLOCK) && g_iLightButton[client] == 1 )
			{
				float time = GetGameTime();

				g_iLightButton[client] = 0;
				g_fTime[client] = time;
			}

			if( g_iLightState[client] == 1 )
			{
				AcceptEntityInput(entity, "TurnOff");
				g_iLightState[client] = 0;
			}
		}
	}

	return Plugin_Continue;
}

void DeleteLight(int client)
{
	int entity = g_iLightIndex[client];
	g_iLightIndex[client] = 0;

	if( IsValidEntRef(entity) )
	{
		RemoveEntity(entity);

		if( g_iTransmit[client] == 1 )
		{
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmitLightA);
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmitLightB);
			g_iTransmit[client] = 0;
		}
	}
}

int CreateLight(int client)
{
	int entity = g_iLightIndex[client];
	if( IsValidEntRef(entity) )
		return 0;

	entity = CreateEntityByName("light_dynamic");
	if( entity == -1)
	{
		LogError("Failed to create 'light_dynamic'");
		return 0;
	}

	DispatchKeyValue(entity, "brightness", "1");
	DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
	DispatchKeyValueFloat(entity, "distance", float(g_iCvarAlpha));
	DispatchKeyValue(entity, "style", "0");
	SetEntProp(entity, Prop_Send, "m_clrRender", g_iCvarColor);
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "TurnOn");

	g_iTransmit[client] = 0;
	if( g_iCvarHide == 1 )
	{
		SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmitLightA);
		g_iTransmit[client] = 1;
	} else if( g_iCvarHide == 2 )
	{
		SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmitLightB);
		g_iTransmit[client] = 1;
	}

	g_iLightIndex[client] = EntIndexToEntRef(entity);
	return entity;
}

public Action Hook_SetTransmitLightA(int entity, int client)
{
	if( g_iLightIndex[client] == EntIndexToEntRef(entity) )
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action Hook_SetTransmitLightB(int entity, int client)
{
	if( g_iLightIndex[client] == EntIndexToEntRef(entity) )
		return Plugin_Continue;
	return Plugin_Handled;
}

void TeleportDynamicLight(int client, int entity)
{
	float vLoc[3], vPos[3], vAng[3];

	GetClientEyeAngles(client, vAng);
	GetClientEyePosition(client, vLoc);

	Handle trace;
	if( g_iCvarHull == 0 )
	{
		trace = TR_TraceRayFilterEx(vLoc, vAng, MASK_SHOT, RayType_Infinite, TraceFilter, client);
	}
	else
	{
		float vDir[3], vEnd[3];
		GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
		vEnd = vLoc;
		vEnd[0] += vDir[0] * 2000;
		vEnd[1] += vDir[1] * 2000;
		vEnd[2] += vDir[2] * 2000;
		trace = TR_TraceHullFilterEx(vLoc, vEnd, view_as<float>({ -10.0, -10.0, -10.0 }), view_as<float>({ 10.0, 10.0, 10.0 }), MASK_SHOT, TraceFilter, client);
	}

	if( TR_DidHit(trace) )
	{
		TR_GetEndPosition(vPos, trace);
		float fDist = GetVectorDistance(vLoc, vPos);

		if( g_iCvarFade == 0 )
		{
			if( g_iLightState[client] == 0 )
			{
				AcceptEntityInput(entity, "TurnOn");
				g_iLightState[client] = 1;
			}

			if( fDist <= g_iCvarDist + 50 )
			{
				GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
				vPos[0] -= vAng[0] * (fDist > 50.0 ? 50.0 : fDist);
				vPos[1] -= vAng[1] * (fDist > 50.0 ? 50.0 : fDist);
				vPos[2] -= vAng[2] * (fDist > 50.0 ? 50.0 : fDist);
				TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
			}
			else
			{
				GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
				vPos[0] = vLoc[0] + (vAng[0] * g_iCvarDist);
				vPos[1] = vLoc[1] + (vAng[1] * g_iCvarDist);
				vPos[2] = vLoc[2] + (vAng[2] * g_iCvarDist);
				TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
			}
		}
		else
		{
			if( fDist <= g_iCvarDist )
			{
				if( fDist > g_iCvarFade )
				{
					int percent = g_iCvarDist - g_iCvarFade;
					fDist = g_iCvarDist - fDist;
					percent = RoundToNearest(fDist) * 100 / percent;

					SetVariantEntity(entity);
					SetVariantInt(g_iCvarAlpha * percent / 100);
					AcceptEntityInput(entity, "distance");
				}
				else
				{
					SetVariantInt(g_iCvarAlpha);
					AcceptEntityInput(entity, "distance");
				}

				GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
				vPos[0] -= vAng[0] * (fDist > 50.0 ? 50.0 : fDist);
				vPos[1] -= vAng[1] * (fDist > 50.0 ? 50.0 : fDist);
				vPos[2] -= vAng[2] * (fDist > 50.0 ? 50.0 : fDist);
				TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

				if( g_iLightState[client] == 0 )
				{
					AcceptEntityInput(entity, "TurnOn");
					g_iLightState[client] = 1;
				}
			}
			else
			{
				if( g_iLightState[client] != 0 )
				{
					AcceptEntityInput(entity, "TurnOff");
					g_iLightState[client] = 0;
				}
			}
		}
	}

	delete trace;
}

public bool TraceFilter(int entity, int contentsMask, any client)
{
	if( entity == client )
		return false;
	return true;
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}