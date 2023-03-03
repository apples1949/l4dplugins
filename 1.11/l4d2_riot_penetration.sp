/*
*	Riot Uncommon Penetration
*	Copyright (C) 2023 Silvers
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



#define PLUGIN_VERSION 		"1.1"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Riot Uncommon Penetration
*	Author	:	SilverShot
*	Descrp	:	Allows bullets to penetrate Riot uncommon infected.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=341750
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.1 (10-Feb-2023)
	- Updated plugin and config to support Mounted Machine Guns and Mini Guns. Thanks to "Iizuka07" for reporting.

1.0 (10-Feb-2023)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define CONFIG_DATA			"data/l4d2_riot_penetration.cfg"


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarDamage;
bool g_bCvarAllow;
float g_fCvarDamage;
float g_fDamage[2048];
StringMap g_hWeapons;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Riot Uncommon Penetration",
	author = "SilverShot",
	description = "Allows bullets to penetrate Riot uncommon infected.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=341750"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	// ====================
	// CVARS
	// ====================
	g_hCvarAllow =		CreateConVar(	"l4d2_riot_penetration_allow",			"1",				"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes =		CreateConVar(	"l4d2_riot_penetration_modes",			"",					"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =	CreateConVar(	"l4d2_riot_penetration_modes_off",		"",					"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =	CreateConVar(	"l4d2_riot_penetration_modes_tog",		"0",				"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarDamage =		CreateConVar(	"l4d2_riot_penetration_damage",			"1.0",				"Percentage of invulnerable damage received to apply on Riot Uncommon common (1.0 = 100%), or scales data config value.", CVAR_FLAGS );
	CreateConVar(						"l4d2_riot_penetration_version",		PLUGIN_VERSION,		"Riot Uncommon Penetration plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d2_riot_penetration");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarDamage.AddChangeHook(ConVarChanged_Cvars);
}

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
	g_fCvarDamage = g_hCvarDamage.FloatValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;

		int entity = -1;
		while( (entity = FindEntityByClassname(entity, "infected")) != INVALID_ENT_REFERENCE )
		{
			if( IsValidCommon(entity) )
			{
				SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
				SDKHook(entity, SDKHook_OnTakeDamageAlive, OnTakeAlive);
				SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
			}
		}
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;

		int entity = -1;
		while( (entity = FindEntityByClassname(entity, "infected")) != INVALID_ENT_REFERENCE )
		{
			if( IsValidCommon(entity) )
			{
				SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
				SDKUnhook(entity, SDKHook_OnTakeDamageAlive, OnTakeAlive);
				SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
			}
		}
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;

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

	if( iCvarModesTog != 0 )
	{
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
// CONFIG
// ====================================================================================================
public void OnMapStart()
{
	LoadConfig();
}

void LoadConfig()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_DATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	KeyValues hFile = new KeyValues("weapons");
	if( !hFile.ImportFromFile(sPath) )
	{
		SetFailState("Error loading file: \"%s\". Try replacing the file with the original.", sPath);
	}

	// ====================
	// FILL ARRAY
	// ====================
	delete g_hWeapons;
	g_hWeapons = new StringMap();

	g_hWeapons.SetValue("weapon_melee", 3.14);

	char sClass[64];
	hFile.GotoFirstSubKey();
	do
	{
		hFile.GetSectionName(sClass, sizeof(sClass));
		g_hWeapons.SetValue(sClass, hFile.GetFloat("damage"));
	} while (hFile.GotoNextKey());

	delete hFile;
}



// ====================================================================================================
// EVENTS
// ====================================================================================================
public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_bCvarAllow && strcmp(classname, "infected") == 0 )
	{
		SDKHook(entity, SDKHook_SpawnPost, OnSpawn);
	}
}

void OnSpawn(int entity)
{
	if( IsValidCommon(entity) )
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKHook(entity, SDKHook_OnTakeDamageAlive, OnTakeAlive);
		SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	}
}

bool IsValidCommon(int entity)
{
	static char sTemp[35];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sTemp, sizeof(sTemp));

	if( strncmp(sTemp, "models/infected/common_male_riot", 32) == 0 )
	{
		return true;
	}

	return false;
}

// Called 1st
Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	// PrintToChatAll("A %d %d %d %f %d %d", victim, attacker, inflictor, damage, damagetype, weapon);

	g_fDamage[victim] = damage;
	return Plugin_Continue;
}

// Called 2nd, if damage is applied, otherwise it's skipped and they are invulnerable to damage
Action OnTakeAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	// PrintToChatAll("B %d %d %d %f %d", victim, attacker, inflictor, damage, damagetype);

	g_fDamage[victim] = 0.0;
	return Plugin_Continue;
}

// Called 3rd
void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3])
{
	// PrintToChatAll("C %d %d %d %f %d %d", victim, attacker, inflictor, damage, damagetype, weapon);

	if( g_fDamage[victim] )
	{
		damage = g_fDamage[victim];

		if( weapon == -1 && inflictor > MaxClients )
			weapon = inflictor;

		// Get weapon
		if( weapon > 0 )
		{
			static char sTemp[64];
			GetEdictClassname(weapon, sTemp, sizeof(sTemp));
			float dmg;

			// Get damage for weapon
			if( g_hWeapons.GetValue(sTemp, dmg) )
			{
				// Get melee weapon damage
				if( dmg == 3.14 )
				{
					GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", sTemp, sizeof(sTemp));
					if( g_hWeapons.GetValue(sTemp, dmg) )
					{
						damage = dmg;
					}
				}
				else
				{
					damage = dmg;
				}
			}
		}

		damage *= g_fCvarDamage;
		g_fDamage[victim] = 0.0;

		if( inflictor == -1 ) inflictor = 0;

		SDKHooks_TakeDamage(victim, inflictor, attacker, damage, damagetype|DMG_GENERIC);
	}
}