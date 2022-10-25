/*
*	Infected Glow
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



#define PLUGIN_VERSION 		"1.11"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Infected Glow
*	Author	:	SilverShot
*	Descrp	:	Creates a dynamic light on common/special infected who are burning.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=187933
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.11 (05-Jun-2022)
	- Fixed glow duration not following the burn duration. Thanks to "gongo" for reporting.

1.10 (10-Apr-2022)
	- Changed the method for fading lights in and out hopefully preventing random server crash.

1.9 (03-Aug-2020)
	- Added light fading out instead of abruptly disappearing.
	- Added smoother fading of the light, thanks to "Lux" for original coding from "Fire Glow" plugin.

1.8 (10-May-2020)
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Fixed cvar "l4d_infected_glow_infected" not working for the Tank in L4D1.

1.7 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.6 (03-Feb-2020)
	- Fixed errors "Invalid edict" by adding "IsValidEdict" - Thanks to "TiTz" for reporting.

1.5 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
	- Changed cvar "l4d_infected_glow_modes_tog" now supports L4D1.

1.4 (30-Jun-2012)
	- Fixed the plugin not working in L4D1.

1.3 (22-Jun-2012)
	- Fixed water not removing the glow - Thanks to "id5473" for reporting.

1.2 (20-Jun-2012)
	- Added some checks to prevent errors being logged - Thanks to "doritos250" for reporting.

1.1 (20-Jun-2012)
	- Fixed not removing the light from Special Infected ignited by incendiary ammo.

1.0 (20-Jun-2012)
	- Initial release.

======================================================================================*/

// Testing: l4d_dissolve_allow 0; l4d_burn_duration_allow 0

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define MAX_LIGHTS			8


ConVar g_hCvarAllow, g_hCvarColor, g_hCvarDist, g_hCvarInfected, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog;
int g_iCvarInfected, g_iEntities[MAX_LIGHTS][2], g_iTick[MAX_LIGHTS], g_iClassTank;
bool g_bCvarAllow, g_bMapStarted, g_bLeft4Dead2, g_bFrameProcessing, g_bWatch;
char g_sCvarCols[12];
float g_fFaderTick[MAX_LIGHTS], g_fFaderStart[MAX_LIGHTS], g_fFaderEnd[MAX_LIGHTS], g_fCvarDist;
Handle g_hTimer[MAX_LIGHTS];

enum
{
	INDEX_ENTITY = 0,
	INDEX_TARGET = 1
}



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Infected Glow",
	author = "SilverShot",
	description = "Creates a dynamic light on common/special infected who are burning.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=187933"
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
	g_hCvarAllow =			CreateConVar(	"l4d_infected_glow_allow",			"1",			" 0=关闭插件，1=打开插件", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_infected_glow_modes",			"",				"在这些游戏模式下打开插件，用逗号分隔（没有空格）（空=全部）", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_infected_glow_modes_off",		"",				"在这些游戏模式下关闭插件，用逗号分隔（没有空格）（空=无）", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d_infected_glow_modes_tog",		"0",			"在这些游戏模式中打开插件。0=全部，1=战役，2=生还者，4=对抗，8=清道夫。将数字相加", CVAR_FLAGS );
	g_hCvarColor =			CreateConVar(	"l4d_infected_glow_color",			"255 50 0",		" 动态光的颜色。三个数值在0-255之间，用空格隔开。RGB颜色255 - 红绿蓝", CVAR_FLAGS );
	g_hCvarDist =			CreateConVar(	"l4d_infected_glow_distance",		"200.0",		"动态光照亮该区域的距离", CVAR_FLAGS );
	g_hCvarInfected =		CreateConVar(	"l4d_infected_glow_infected",		"510",			"1=小僵尸, 2=Witch, 4=Smoker, 8=Boomer, 16=Hunter, 32=Spitter, 64=Jockey, 128=Charger, 256=Tank, 511=全部.", CVAR_FLAGS );
	CreateConVar(							"l4d_infected_glow_version",		PLUGIN_VERSION,	"Molotov and Gascan Glow plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_infected_glow");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarDist.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarColor.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarInfected.AddChangeHook(ConVarChanged_Cvars);

	g_iClassTank = g_bLeft4Dead2 ? 9 : 6;
}

public void OnPluginEnd()
{
	ResetPlugin();
}

public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
	ResetPlugin();
}

void ResetPlugin()
{
	g_bWatch = false;

	for( int i = 0; i < MAX_LIGHTS; i++ )
	{
		delete g_hTimer[i] = null;

		if( IsValidEntRef(g_iEntities[i][INDEX_ENTITY]) == true )
		{
			RemoveEntity(g_iEntities[i][INDEX_ENTITY]);
		}

		g_iEntities[i][INDEX_ENTITY] = 0;
		g_iEntities[i][INDEX_TARGET] = 0;
	}
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fCvarDist = g_hCvarDist.FloatValue;
	g_hCvarColor.GetString(g_sCvarCols, sizeof(g_sCvarCols));
	g_iCvarInfected = g_hCvarInfected.IntValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		ResetPlugin();
		g_bCvarAllow = false;
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

void OnGamemode(const char[] output, int caller, int activator, float delay)
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
public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_bCvarAllow && g_bMapStarted )
	{
		if( strcmp(classname, "entityflame") == 0 )
		{
			CreateTimer(0.1, TimerCreate, EntIndexToEntRef(entity));
		}
	}
}

public void OnEntityDestroyed(int entity)
{
	if( g_bWatch && g_bCvarAllow && g_bMapStarted && entity > 0 )
	{
		entity = EntIndexToEntRef(entity);
		int valid;

		for( int i = 0; i < MAX_LIGHTS; i++ )
		{
			if( entity == g_iEntities[i][INDEX_TARGET] && IsValidEntRef(g_iEntities[i][INDEX_ENTITY]) )
			{
				int parent = GetEntPropEnt(entity, Prop_Data, "m_hMoveParent");
				if( parent > 0 && parent <= MaxClients && IsValidEntity(parent) )
				{
					float vVec[3];
					GetEntPropVector(parent, Prop_Data, "m_vecVelocity", vVec);

					AcceptEntityInput(g_iEntities[i][INDEX_ENTITY], "ClearParent");

					delete g_hTimer[i];
					g_hTimer[i] = CreateTimer(GetVectorLength(vVec) <= 250.0 ? 7.0 : 0.1, TimerDestroy, i);
				} else {
					CreateTimer(0.1, TimerDestroy, i);
				}
			}
			else if( IsValidEntRef(g_iEntities[i][INDEX_TARGET]) == true )
			{
				valid = 1;
			}
		}

		if( valid == 0 )
		{
			g_bWatch = false;
		}
	}
}



// ====================================================================================================
//					LIGHTS
// ====================================================================================================
Action TimerCreate(Handle timer, any target)
{
	if( (target = EntRefToEntIndex(target)) != INVALID_ENT_REFERENCE )
	{
		int client = GetEntPropEnt(target, Prop_Data, "m_hEntAttached");
		if( client < 1 )
			return Plugin_Continue;

		static char sTemp[64];

		// Validate target
		if( client > MaxClients )
		{
			int infected = g_iCvarInfected & (1<<0);
			int witch = g_iCvarInfected & (1<<1);

			if( infected || witch )
			{
				if( IsValidEntity(client) == false || IsValidEdict(client) == false )
					return Plugin_Continue;

				GetEdictClassname(client, sTemp, sizeof(sTemp));

				if( (infected && strcmp(sTemp, "infected") != 0) && (witch && strcmp(sTemp, "witch") != 0) )
					return Plugin_Continue;
			} else {
				return Plugin_Continue;
			}
		}
		else
		{
			if( IsClientInGame(client) == false || GetClientTeam(client) != 3 )
				return Plugin_Continue;

			int class = GetEntProp(client, Prop_Send, "m_zombieClass") + 1;
			if( class == g_iClassTank ) class = 8;
			if( !(g_iCvarInfected & (1 << class)) )
				return Plugin_Continue;
		}

		// Find empty index
		int index = -1;

		for( int i = 0; i < MAX_LIGHTS; i++ )
		{
			if( IsValidEntRef(g_iEntities[i][INDEX_ENTITY]) == false )
			{
				index = i;
				break;
			}
		}

		if( index == -1 )
			return Plugin_Continue;

		// Create light
		int entity = CreateEntityByName("light_dynamic");
		if( entity == -1)
		{
			LogError("Failed to create 'light_dynamic'");
			return Plugin_Continue;
		}

		g_bWatch = true;
		g_iEntities[index][INDEX_ENTITY] = EntIndexToEntRef(entity);
		g_iEntities[index][INDEX_TARGET] = EntIndexToEntRef(target);

		Format(sTemp, sizeof(sTemp), "%s 255", g_sCvarCols);

		DispatchKeyValue(entity, "_light", sTemp);
		DispatchKeyValue(entity, "brightness", "2");
		DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
		DispatchKeyValueFloat(entity, "distance", 5.0);
		DispatchKeyValue(entity, "style", "6");
		DispatchSpawn(entity);

		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", target);

		float vPos[3];
		vPos[2] = 50.0;
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

		AcceptEntityInput(entity, "TurnOn");

		float flTickInterval = GetTickInterval();
		int iTickRate = RoundFloat(1 / flTickInterval);

		// Fade
		if( !g_bFrameProcessing )
		{
			g_bFrameProcessing = true;
			RequestFrame(OnFrameFadeIn);
		}

		g_iTick[index] = 8;
		g_fFaderEnd[index] = GetGameTime() + 9999.9;
		g_fFaderStart[index] = GetGameTime() + flTickInterval * iTickRate + 2.0;
		g_fFaderTick[index] = GetGameTime();
	}

	return Plugin_Continue;
}

void OnFrameFadeIn()
{
	g_bFrameProcessing = false;

	float fDist;
	float fTime = GetGameTime();
	float flTickInterval = GetTickInterval();
	int iTickRate = RoundFloat(1 / flTickInterval);

	// Loop through valid ents
	for( int i = 0; i < MAX_LIGHTS; i++ )
	{
		if( IsValidEntRef(g_iEntities[i][INDEX_ENTITY]) )
		{
			// Fade in
			if( fTime < g_fFaderStart[i] )
			{
				fDist = (g_fCvarDist / iTickRate) * g_iTick[i];
				if( fDist < g_fCvarDist )
				{
					g_bFrameProcessing = true;

					SetVariantFloat(fDist);
					AcceptEntityInput(g_iEntities[i][INDEX_ENTITY], "Distance");

					g_iTick[i]++;
				}
			}
		}
	}

	if( g_bFrameProcessing )
	{
		RequestFrame(OnFrameFadeIn);
	}
}

Action TimerDestroy(Handle timer, any index)
{
	g_hTimer[index] = null;

	if( IsValidEntRef(g_iEntities[index][INDEX_ENTITY]) )
	{
		g_iTick[index] = 0;
		RequestFrame(OnFrameFadeOut, index);
	}
}

void OnFrameFadeOut(int index)
{
	if( !IsValidEntRef(g_iEntities[index][INDEX_ENTITY]) )
	{
		g_iEntities[index][INDEX_ENTITY] = 0;
		g_iEntities[index][INDEX_TARGET] = 0;
		delete g_hTimer[index];

		return;
	}

	float fDist;
	float flTickInterval = GetTickInterval();
	int iTickRate = RoundFloat(1 / flTickInterval);

	fDist = (g_fCvarDist / iTickRate) * (iTickRate - g_iTick[index]);
	g_iTick[index]++;

	if( fDist > 0.0 )
	{
		if( fDist < g_fCvarDist )
		{
			SetVariantFloat(fDist);
			AcceptEntityInput(g_iEntities[index][INDEX_ENTITY], "Distance");
		}

		RequestFrame(OnFrameFadeOut, index);
	} else {
		RemoveEntity(g_iEntities[index][INDEX_ENTITY]);

		g_iTick[index] = 0;
		g_iEntities[index][INDEX_ENTITY] = 0;
		g_iEntities[index][INDEX_TARGET] = 0;
		delete g_hTimer[index];
	}
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}