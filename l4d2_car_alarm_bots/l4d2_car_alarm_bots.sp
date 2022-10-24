/*
*	Car Alarm - Bots Trigger
*	Copyright (C) 2021 Silvers
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



#define PLUGIN_VERSION 		"1.9"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Car Alarm - Bots Trigger
*	Author	:	SilverShot
*	Descrp	:	Sets off the car alarm when bots shoot the vehicle or stand on it.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=319435
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.9 (15-Feb-2021) - by Marttt
	- Added team Infected support.
	- Added new cvars "l4d2_car_alarm_bots_infected" and "l4d2_car_alarm_bots_survivor_distance" for this feature.

1.8 (30-Sep-2020)
	- Fixed compile errors on SM 1.11.

1.7 (10-May-2020)
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Removed unused test command.
	- Various changes to tidy up code.

1.6 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.5 (25-Mar-2020)
	- Fixed not working on Linux. Thanks to "epzminion" for reporting the correct offset to patch.
	- GameData and plugin updated for Linux fix.

1.4 (29-Feb-2020)
	- Fixed accidentally enabling the plugin when cvars change. Thanks to "TommyCD1" for reporting.

1.3 (25-Jan-2020)
	- Fixed AI special infected from triggering alarms. Thanks to "jamalsheref2" for reporting.

1.2 (05-Nov-2019)
	- Fixed hooking entities when the plugin should be turned off.

1.1 (01-Nov-2019)
	- Renamed plugin and cvar config and restricted to L4D2 only since it's not required in L4D1.

1.0 (01-Nov-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d2_car_alarm_bots"
#define MAX_BYTES			33


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarType;
bool g_bCvarAllow, g_bMapStarted;
int g_iCvarType, g_ByteCount, g_ByteMatch;
int g_ByteSaved[MAX_BYTES];
Address g_Address;

enum
{
	TYPE_SHOOT = (1<<0),
	TYPE_STAND = (1<<1)
}

ConVar g_hCvarAllowInfected, g_hCvarSurvivorDistance;
bool g_bCvarSurvivorDistance;
int g_iCvarAllowInfected;
float g_fCvarSurvivorDistance;

enum
{
	TYPE_HUMANS = (1<<0),
	TYPE_BOTS = (1<<1)
}



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Car Alarm - Bots Trigger",
	author = "SilverShot",
	description = "Sets off the car alarm when bots shoot the vehicle or stand on it.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=319435"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	// ====================================================================================================
	// GAMEDATA
	// ====================================================================================================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_Address = GameConfGetAddress(hGameData, "CCarProp::InputSurvivorStandingOnCar");
	if( !g_Address ) SetFailState("Failed to load \"CCarProp::InputSurvivorStandingOnCar\" address.");

	int offset = GameConfGetOffset(hGameData, "InputSurvivorStandingOnCar_Offset");
	if( offset == -1 ) SetFailState("Failed to load \"InputSurvivorStandingOnCar_Offset\" offset.");

	g_ByteMatch = GameConfGetOffset(hGameData, "InputSurvivorStandingOnCar_Byte");
	if( g_ByteMatch == -1 ) SetFailState("Failed to load \"InputSurvivorStandingOnCar_Byte\" byte.");

	g_ByteCount = GameConfGetOffset(hGameData, "InputSurvivorStandingOnCar_Count");
	if( g_ByteCount == -1 ) SetFailState("Failed to load \"InputSurvivorStandingOnCar_Count\" count.");
	if( g_ByteCount > MAX_BYTES ) SetFailState("Error: byte count exceeds scripts defined value (%d/%d).", g_ByteCount, MAX_BYTES);

	g_Address += view_as<Address>(offset);

	for( int i = 0; i < g_ByteCount; i++ )
	{
		g_ByteSaved[i] = LoadFromAddress(g_Address + view_as<Address>(i), NumberType_Int8);
	}
	if( g_ByteSaved[0] != g_ByteMatch ) SetFailState("Failed to load, byte mis-match. %d (0x%02X != 0x%02X)", offset, g_ByteSaved[0], g_ByteMatch);

	delete hGameData;

	// ====================================================================================================
	// CVARS
	// ====================================================================================================
	g_hCvarAllow =			CreateConVar(	"l4d2_car_alarm_bots_allow",			"1",				"0=关闭插件, 1=开启插件", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d2_car_alarm_bots_modes",			"",					"在这些游戏模式下打开插件，用逗号分隔（没有空格）（空=全部）", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d2_car_alarm_bots_modes_off",		"",					"在这些游戏模式下关闭插件，用逗号分隔（没有空格）（空=无）", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d2_car_alarm_bots_modes_tog",		"0",				"在这些游戏模式中打开插件。0=全部，1=战役，2=生还者，4=对抗，8=清道夫。将数字相加", CVAR_FLAGS );
	g_hCvarType =			CreateConVar(	"l4d2_car_alarm_bots_type",				"3",				"1=当机器人射击汽车时触发警报。2=当机器人站在汽车上时触发警报。3=两者都可以", CVAR_FLAGS );
	g_hCvarAllowInfected =		CreateConVar(	"l4d2_car_alarm_bots_infected",			"0",				"允许SI来触发汽车警报。0=关闭。1=对SI人类玩家启用。2=对SI机器人启用。3=两者都可以", CVAR_FLAGS, true, 0.0, true, 3.0 );
	g_hCvarSurvivorDistance =	CreateConVar(	"l4d2_car_alarm_bots_survivor_distance","500",				"幸存者和特感最大间隔多长距离可以触发警报。0=不检查", CVAR_FLAGS, true, 0.0 );
	CreateConVar(							"l4d2_car_alarm_bots_version",			PLUGIN_VERSION,		"Car Alarm - Bots Trigger plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d2_car_alarm_bots");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarType.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarAllowInfected.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSurvivorDistance.AddChangeHook(ConVarChanged_Cvars);

	IsAllowed();
}

public void OnPluginEnd()
{
	PatchAddress(false);
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
	g_iCvarType = g_hCvarType.IntValue;
	g_iCvarAllowInfected = g_hCvarAllowInfected.IntValue;
	g_fCvarSurvivorDistance = g_hCvarSurvivorDistance.FloatValue;
	g_bCvarSurvivorDistance = (g_fCvarSurvivorDistance > 0.0);

	if( g_bCvarAllow )
	{
		PatchAddress(g_iCvarType & TYPE_STAND);
		HookEntities(g_iCvarType & TYPE_SHOOT);
	}
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		PatchAddress(g_iCvarType & TYPE_STAND);
		HookEntities(g_iCvarType & TYPE_SHOOT);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		PatchAddress(false);
		HookEntities(g_iCvarType & TYPE_SHOOT);
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
//					PATCH / HOOK
// ====================================================================================================
void PatchAddress(int patch)
{
	static bool patched;

	if( !patched && patch )
	{
		patched = true;
		for( int i = 0; i < g_ByteCount; i++ )
			StoreToAddress(g_Address + view_as<Address>(i), g_ByteMatch == 0x0F ? 0x90 : 0xEB, NumberType_Int8);
	}
	else if( patched && !patch )
	{
		patched = false;
		for( int i = 0; i < g_ByteCount; i++ )
			StoreToAddress(g_Address + view_as<Address>(i), g_ByteSaved[i], NumberType_Int8);
	}
}

void HookEntities(int hook)
{
	static bool hooked;

	if( !hooked && hook )
	{
		hooked = true;

		int entity = -1;
		while( (entity = FindEntityByClassname(entity, "prop_car_alarm")) != INVALID_ENT_REFERENCE )
		{
			SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
			SDKHook(entity, SDKHook_Touch, OnTouch);
		}
	}
	else if( hooked && !hook )
	{
		hooked = false;

		int entity = -1;
		while( (entity = FindEntityByClassname(entity, "prop_car_alarm")) != INVALID_ENT_REFERENCE )
		{
			SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
			SDKUnhook(entity, SDKHook_Touch, OnTouch);
		}
	}
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_bCvarAllow && g_iCvarType & TYPE_SHOOT && strcmp(classname, "prop_car_alarm") == 0 )
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKHook(entity, SDKHook_Touch, OnTouch);
	}
}

public Action OnTakeDamage(int entity/*victim*/, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	bool apply;

	if( attacker >= 1 && attacker <= MaxClients )
	{
		if( GetClientTeam(attacker) == 2 )
		{
			apply = IsFakeClient(attacker);
		}
		else if ( GetClientTeam(attacker) == 3 && !IsPlayerGhost(attacker) )
		{
			if ( g_bCvarSurvivorDistance && !HasAnySurvivorInRange(attacker) )
				return Plugin_Continue;

			if (IsFakeClient(attacker))
			{
				if (g_iCvarAllowInfected & TYPE_BOTS)
					apply = true;
			}
			else
			{
				if (g_iCvarAllowInfected & TYPE_HUMANS)
					apply = true;
			}
		}

		if (!apply)
			return Plugin_Continue;

		if( !(g_iCvarType & TYPE_STAND) ) PatchAddress(true);
		AcceptEntityInput(entity, "SurvivorStandingOnCar", attacker, attacker);
		if( !(g_iCvarType & TYPE_STAND) ) PatchAddress(false);

		SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKUnhook(entity, SDKHook_Touch, OnTouch);
	}

	return Plugin_Continue;
}

public void OnTouch(int entity, int other)
{
	bool apply;

	if( other >= 1 && other <= MaxClients )
	{
		if( GetClientTeam(other) == 2 )
		{
			apply = IsFakeClient(other);
		}
		else if ( GetClientTeam(other) == 3 && !IsPlayerGhost(other) )
		{
			if ( g_bCvarSurvivorDistance && !HasAnySurvivorInRange(other) )
				return;

			if ( IsFakeClient(other) )
			{
				if ( g_iCvarAllowInfected & TYPE_BOTS )
					apply = true;
			}
			else
			{
				if ( g_iCvarAllowInfected & TYPE_HUMANS )
					apply = true;
			}
		}

		if (!apply)
			return;

		if( !(g_iCvarType & TYPE_STAND) ) PatchAddress(true);
		AcceptEntityInput(entity, "SurvivorStandingOnCar", other, other);
		if( !(g_iCvarType & TYPE_STAND) ) PatchAddress(false);

		SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKUnhook(entity, SDKHook_Touch, OnTouch);
	}
}

bool IsPlayerGhost(int client)
{
    return (GetEntProp(client, Prop_Send, "m_isGhost") == 1);
}

public bool HasAnySurvivorInRange(int infected)
{
	float fInfectedOrigin[3];
	GetClientAbsOrigin(infected, fInfectedOrigin);

	float fSurvivorOrigin[3];
	for (int client = 1; client <= MaxClients; client++)
	{
		if ( IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) )
		{
			GetClientAbsOrigin(client, fSurvivorOrigin);

			if (GetVectorDistance(fInfectedOrigin, fSurvivorOrigin) <= g_fCvarSurvivorDistance)
				return true;
		}
	}

	return false;
}