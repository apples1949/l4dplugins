/*
*	[L4D & L4D2] Fire Glow
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



#define PLUGIN_VERSION 		"1.8"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Fire Glow
*	Author	:	SilverShot
*	Descrp	:	Creates a dynamic light where Molotovs, Gascans and Firework Crates burn.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=186617
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.8 (25-Mar-2022)
	- Better fade in and out timing.

1.7 (22-Mar-2022)
	- Changed the method for fading lights in and out hopefully preventing random server crash.

1.6 (12-Jul-2020)
	- Added smoother fading of the light, thanks to "Lux" for coding in.

1.5 (10-May-2020)
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Various changes to tidy up code.

1.4 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.3 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
	- Changed cvar "l4d_fire_glow_modes_tog" now supports L4D1.

1.2 (30-Jun-2012)
	- Fixed the plugin not working in L4D1.

1.1 (20-Jun-2012)
	- Added cvars "l4d_fire_glow_modes", "l4d_fire_glow_modes_off" and "l4d_fire_glow_modes_tog" to control which modes turn on the plugin.

1.0 (02-Jun-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define MAX_LIGHTS			8


ConVar g_hCvarAllow, g_hCvarColor1, g_hCvarColor2, g_hCvarDist, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hInferno;
int g_iEntities[MAX_LIGHTS][2], g_iTick[MAX_LIGHTS];
bool g_bCvarAllow, g_bMapStarted, g_bLeft4Dead2, g_bFrameProcessing;
char g_sCvarCols1[12], g_sCvarCols2[12];
float g_fFaderTick[MAX_LIGHTS], g_fFaderStart[MAX_LIGHTS], g_fFaderEnd[MAX_LIGHTS], g_fCvarDist, g_fInferno;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Fire Glow",
	author = "SilverShot",
	description = "Creates a dynamic light where Molotovs, Gascans and Firework Crates burn.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=186617"
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
	g_hCvarAllow =			CreateConVar(	"l4d_fire_glow_allow",			"1",			"0=插件关闭，1=插件打开", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_fire_glow_modes",			"",				"在这些游戏模式下打开插件，用逗号分隔（没有空格）（空=全部）", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_fire_glow_modes_off",		"",				"在这些游戏模式下关闭插件，用逗号分隔（没有空格）（空=无）", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d_fire_glow_modes_tog",		"0",			"在这些游戏模式中打开插件。0=全部，1=战役，2=生还者，4=对抗，8=清道夫。将数字相加", CVAR_FLAGS );
	g_hCvarDist =			CreateConVar(	"l4d_fire_glow_distance",		"250.0",		"动态灯光照亮该区域的距离", CVAR_FLAGS );
	if( g_bLeft4Dead2 )
		g_hCvarColor1 =		CreateConVar(	"l4d_fire_glow_fireworks",		"255 100 0",	"燃烧瓶燃烧时的灯光颜色。三个数值在0-255之间，用空格分隔。RGB颜色255 - 红绿蓝", CVAR_FLAGS );
	g_hCvarColor2 =			CreateConVar(	"l4d_fire_glow_inferno",		"255 25 0",		"燃烧瓶扔出时的灯光颜色。三个数值在0-255之间，用空格分隔。RGB颜色255 - 红绿蓝", CVAR_FLAGS );
	CreateConVar(							"l4d_fire_glow_version",		PLUGIN_VERSION,	"Fire Glow plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_fire_glow");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hInferno = FindConVar("inferno_flame_lifetime");
	g_hInferno.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDist.AddChangeHook(ConVarChanged_Cvars);
	if( g_bLeft4Dead2 )
		g_hCvarColor1.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarColor2.AddChangeHook(ConVarChanged_Cvars);
}

public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
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
	g_fCvarDist = g_hCvarDist.FloatValue;
	if( g_bLeft4Dead2 )
		g_hCvarColor1.GetString(g_sCvarCols1, sizeof(g_sCvarCols1));
	g_hCvarColor2.GetString(g_sCvarCols2, sizeof(g_sCvarCols2));
	g_fInferno = g_hInferno.FloatValue;
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
//					LIGHTS
// ====================================================================================================
public void OnEntityDestroyed(int entity)
{
	if( g_bCvarAllow && g_bMapStarted && entity > MaxClients )
	{
		entity = EntIndexToEntRef(entity);

		for( int i = 0; i < MAX_LIGHTS; i++ )
		{
			if( entity == g_iEntities[i][1] )
			{
				if( IsValidEntRef(g_iEntities[i][0]) )
				{
					RemoveEntity(g_iEntities[i][0]);
				}

				g_iEntities[i][0] = 0;
				g_iEntities[i][1] = 0;
				break;
			}
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_bCvarAllow && g_bMapStarted )
	{
		if( strcmp(classname, "inferno") == 0 )
			CreateTimer(0.1, TimerCreate, EntIndexToEntRef(entity));
		else if( g_bLeft4Dead2 && strcmp(classname, "fire_cracker_blast") == 0 )
			CreateTimer(0.1, TimerCreate, EntIndexToEntRef(entity));
	}
}

public Action TimerCreate(Handle timer, any target)
{
	if( (target = EntRefToEntIndex(target)) != INVALID_ENT_REFERENCE )
	{
		// Find index
		int index = -1;

		for( int i = 0; i < MAX_LIGHTS; i++ )
		{
			if( IsValidEntRef(g_iEntities[i][0]) == false )
			{
				index = i;
				break;
			}
		}

		if( index == -1 )
			return Plugin_Continue;

		// Create light
		static char sTemp[32];

		int entity = CreateEntityByName("light_dynamic");
		if( entity == -1)
		{
			LogError("Failed to create 'light_dynamic'");
			return Plugin_Continue;
		}

		g_iEntities[index][0] = EntIndexToEntRef(entity);
		g_iEntities[index][1] = EntIndexToEntRef(target);

		float fInfernoTime = g_fInferno;

		GetEdictClassname(target, sTemp, 2);
		if( sTemp[0] == 'i' )
		{
			Format(sTemp, sizeof(sTemp), "%s 255", g_sCvarCols2);
		}
		else
		{
			fInfernoTime -= 1.5;
			Format(sTemp, sizeof(sTemp), "%s 255", g_sCvarCols1);
		}

		DispatchKeyValue(entity, "_light", sTemp);
		DispatchKeyValue(entity, "brightness", "3");
		DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
		DispatchKeyValueFloat(entity, "distance", 5.0);
		DispatchKeyValue(entity, "style", "6");
		DispatchSpawn(entity);

		float vPos[3], vAng[3];
		GetEntPropVector(target, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(target, Prop_Data, "m_angRotation", vAng);
		vPos[2] += 40.0;
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");

		float flTickInterval = GetTickInterval();
		int iTickRate = RoundFloat(1 / flTickInterval);

		// Fade
		if( !g_bFrameProcessing )
		{
			g_bFrameProcessing = true;
			RequestFrame(OnFrameFade);
		}

		g_iTick[index] = 7;
		g_fFaderEnd[index] = GetGameTime() + fInfernoTime - (flTickInterval * iTickRate);
		g_fFaderStart[index] = GetGameTime() + flTickInterval * iTickRate + 2.0;
		g_fFaderTick[index] = GetGameTime() - 1.0;

		/* Old method (causes rare crash with too many inputs)
		// Fade in
		for(int i = 1; i <= iTickRate; i++)
		{
			Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:%f:-1", (g_fCvarDist / iTickRate) * i, flTickInterval * i);
			SetVariantString(sTemp);
			AcceptEntityInput(entity, "AddOutput");
		}
		AcceptEntityInput(entity, "FireUser1");

		// Fade out
		for(int i = iTickRate; i > 1; --i)
		{
			Format(sTemp, sizeof(sTemp), "OnUser2 !self:distance:%f:%f:-1", (g_fCvarDist / iTickRate) * i, fInfernoTime - flTickInterval * i);
			SetVariantString(sTemp);
			AcceptEntityInput(entity, "AddOutput");
		}
		AcceptEntityInput(entity, "FireUser2");
		*/

		Format(sTemp, sizeof(sTemp), "OnUser3 !self:Kill::%f:-1", fInfernoTime + 1.0);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser3");
	}

	return Plugin_Continue;
}

void OnFrameFade()
{
	g_bFrameProcessing = false;

	float fDist;
	float fTime = GetGameTime();
	float flTickInterval = GetTickInterval();
	int iTickRate = RoundFloat(1 / flTickInterval);

	// Loop through valid ents
	for( int i = 0; i < MAX_LIGHTS; i++ )
	{
		if( IsValidEntRef(g_iEntities[i][0]) )
		{
			g_bFrameProcessing = true;

			// Ready for fade on this tick
			if( fTime > g_fFaderTick[i] )
			{
				// Fade in
				if( fTime < g_fFaderStart[i] )
				{
					fDist = (g_fCvarDist / iTickRate) * g_iTick[i];
					if( fDist < g_fCvarDist )
					{
						SetVariantFloat(fDist);
						AcceptEntityInput(g_iEntities[i][0], "Distance");
					}

					g_iTick[i]++;
					g_fFaderTick[i] = fTime + flTickInterval;
				}
				// Fade out
				else if( fTime > g_fFaderEnd[i] )
				{
					fDist = (g_fCvarDist / iTickRate) * (iTickRate - g_iTick[i]);
					if( fDist < g_fCvarDist )
					{
						SetVariantFloat(fDist);
						AcceptEntityInput(g_iEntities[i][0], "Distance");
					}

					g_iTick[i]++;
					g_fFaderTick[i] = fTime + flTickInterval;
				}
				else
				{
					g_iTick[i] = 0;
				}
			}
		}
	}

	if( g_bFrameProcessing )
	{
		RequestFrame(OnFrameFade);
	}
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}