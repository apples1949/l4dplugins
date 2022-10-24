/*
*	Spitter Acid Damage
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



#define PLUGIN_VERSION 		"1.13"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Spitter Acid Damage
*	Author	:	SilverShot
*	Descrp	:	Unlocks Spitter Acid to damage common and special infected. Also control damage to Survivors.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=319526
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.13 (20-Sep-2022)
	- Changed the way "l4d2_spitter_acid_grace" prevents damage, to also prevent the sound and movement slowdown.

1.12 (25-May-2022)
	- Changed the description of "l4d2_spitter_acid_damage" cvar and some default values due to the logic being inverted from the previous description. Thanks to "VYRNACH_GAMING" for reporting.

1.11 (14-Dec-2021)
	- Fixed infected hurt sounds when "l4d2_spitter_acid_dmg_special" or "l4d2_spitter_acid_dmg_self" was set to "0.0". Thanks to "KoMiKoZa" for reporting.

1.10a (19-Oct-2021)
	- Wildcarded the .txt GameData signature for compatibility with "Left4DHooks" plugin version 1.64+.

1.10 (26-Aug-2021)
	- Added cvar "l4d2_spitter_acid_grace" to prevent damaging enemies when spit acid detonates until after the grace period. Requested by "Lukey1028".
	- Potentially fixed hearing pain vocalizations when damage should be blocked. Thanks to "KoMiKoZa" for reporting.

1.9 (25-Jul-2021)
	- Fixed affecting Special Infected ghosts. Thanks to "ddd123" for reporting.

1.8 (24-Apr-2021)
	- Fixed invalid edict error. Thanks to "Krufftys Killers" for reporting.

1.7 (23-Feb-2021)
	- Added cvar "l4d2_spitter_acid_dmg_bots" to set the damage for survivor bots. Requested by "Gobi".

1.6 (09-Oct-2020)
	- Added cvar "l4d2_spitter_acid_explode" to control which explosives should ignite or explode (gascans can only ignite).
	- Fixed map spawn gascans not being affected and igniting. Thanks to "KoMiKoZa" for reporting.
	- Fixed not detecting Scavenge mode if the "_tog" cvar was not being used.

1.5 (04-Jun-2020)
	- Added cvar "l4d2_spitter_acid_explosives" to allow Spitter Acid to ignite/explode explosives.

1.4 (10-May-2020)
	- Added better error log message when gamedata file is missing.
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Various changes to tidy up code.

1.3 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.2 (18-Mar-2020)
	- Fixed crashing in Linux. GameData changed.
	- Fixed cvar "l4d2_spitter_acid_damage" not actually being used.
	- Added cvar "l4d2_spitter_acid_dmg_self" to control Spitter damage from their own spit.

1.1 (05-Nov-2019)
	- Optimized to unhook OnTakeDamage when no longer used.

1.0 (05-Nov-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>



// ALTERNATIVE METHOD: original before detour:
// Demonstrates getting flame positions from "inferno" style entities ("insect_swarm" / "fire_cracker_blast")
// Uses "Neon Beams" plugin to display traces.
/*
// DEBUG NEON - Shows beams where the fires are and where contact is made to enemies.
#define NEON_DEBUG			0
#if NEON_DEBUG
	#include <neon_beams>
#endif

// DEBUG BENCHMARK - Don't benchmark with NEON_DEBUG or you'll get bad results.
#define BENCHMARK			0
#if BENCHMARK
	#include <profiler>
	Handle g_Profiler;
#endif

#define MAX_RANGE			400	// Range to detect if near spit
#define MIN_RANGE			60	// Range to hurt when in spit

float g_fCvarTime, g_fCvarTimeout;
float g_fLastHurt[2048];
// */



#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d2_spitter_acid_damage"
#define PARTICLE_SPIT		"spitter_projectile_explode"


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarEffects, g_hCvarExplode, g_hCvarExplodes, g_hCvarGrace, g_hCvarDmgCommon, g_hCvarDmgSelf, g_hCvarDmgSpecial, g_hCvarDmgSurvivor, g_hCvarDmgSurvBots, g_hCvarDamage;
float g_fCvarCommon, g_fCvarGrace, g_fCvarSelf, g_fCvarSpecial, g_fCvarSurvivor, g_fCvarSurvBots;
int g_iCvarEffects, g_iCvarExplode, g_iCvarExplodes, g_iCvarDamage;
bool g_bCvarAllow, g_bMapStarted;
Handle g_hDetourHarm;
int g_iHooked[2048];
float g_fLastHit[2048];



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Spitter Acid Damage",
	author = "SilverShot",
	description = "Unlocks Spitter Acid to damage common and special infected. Also control damage to Survivors.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=319526"
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
	// DETOUR
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_hDetourHarm = DHookCreateFromConf(hGameData, "CInsectSwarm::CanHarm");
	delete hGameData;

	if( !g_hDetourHarm )
		SetFailState("Failed to find \"CInsectSwarm::CanHarm\" signature.");

	// CVARS
	g_hCvarAllow = CreateConVar(		"l4d2_spitter_acid_allow",			"1",			"0=禁用插件, 1=启用插件", CVAR_FLAGS);
	g_hCvarModes = CreateConVar(		"l4d2_spitter_acid_modes",			"",				"在这些游戏模式下打开插件，用逗号分隔（没有空格）（空=全部）", CVAR_FLAGS);
	g_hCvarModesOff = CreateConVar(		"l4d2_spitter_acid_modes_off",		"",				"在这些游戏模式下关闭插件，用逗号分隔（没有空格）（空=无）", CVAR_FLAGS);
	g_hCvarModesTog = CreateConVar(		"l4d2_spitter_acid_modes_tog",		"0",			"在这些游戏模式中打开插件。0=全部，1=战役，2=生还者，4=对抗，8=清道夫。将数字相加", CVAR_FLAGS);
	g_hCvarDmgCommon = CreateConVar(	"l4d2_spitter_acid_dmg_common",		"10.0",			"对小僵尸造成的伤害。可以通过改变'l4d2_spitter_acid_damage'使用百分比来改变原来的伤害", CVAR_FLAGS);
	g_hCvarDmgSelf = CreateConVar(		"l4d2_spitter_acid_dmg_self",		"10.0",			"对酸液所有者造成的伤害。可以通过改变'l4d2_spitter_acid_damage'使用百分比来改变原来的伤害", CVAR_FLAGS);
	g_hCvarDmgSpecial = CreateConVar(	"l4d2_spitter_acid_dmg_special",	"25.0",			"对特感造成的伤害。可以通过改变'l4d2_spitter_acid_damage'使用百分比来改变原来的伤害", CVAR_FLAGS);
	g_hCvarDmgSurvivor = CreateConVar(	"l4d2_spitter_acid_dmg_survivor",	"1.0",			"对幸存者造成的伤害（游戏默认为1.0，l4d2_spitter_acid_damage省略值为2）", CVAR_FLAGS);
	g_hCvarDmgSurvBots = CreateConVar(	"l4d2_spitter_acid_dmg_bots",		"1.0",			"对幸存者机器人造成的伤害（游戏默认为1.0，l4d2_spitter_acid_damage省略值为2）", CVAR_FLAGS);
	g_hCvarDamage = CreateConVar(		"l4d2_spitter_acid_damage",			"13",			"以下什么值设置后的伤害将会是实际的伤害，否则伤害值将以百分比处理游戏原来的伤害 1=小僵尸。2=幸存者（默认）。4=特殊。8=自己。15=全部。数字相加", CVAR_FLAGS);
	g_hCvarEffects = CreateConVar(		"l4d2_spitter_acid_effects",		"5",			"伤害时显示一个粒子。0=关闭，1=小僵尸，2=幸存者，4=特殊感染者，8=自己。15=全部", CVAR_FLAGS);
	g_hCvarExplode = CreateConVar(		"l4d2_spitter_acid_explosives",		"0",			"允许酸液点燃炸药。0=关闭, 1=汽油罐, 2=烟花盒, 4=氧气瓶, 8=煤气罐, 15=全部。数字相加。", CVAR_FLAGS);
	g_hCvarExplodes = CreateConVar(		"l4d2_spitter_acid_explode",		"0",			"口水可以直接使哪些物品爆炸，否则先引燃：0=全部点燃，1=烟花盒，2=氧气瓶，4=煤气瓶，7=全部爆炸。数字相加", CVAR_FLAGS);
	g_hCvarGrace = CreateConVar(		"l4d2_spitter_acid_grace",			"1.0",			" 酸液引爆后多长时间可以造成伤害", CVAR_FLAGS);
	// ALTERNATIVE METHOD
	// g_hCvarTimescan = CreateConVar(		"l4d2_spitter_acid_time",			"0.2",			"How often to check for enemies near or in Spitter acid.", CVAR_FLAGS);
	// g_hCvarTimeout = CreateConVar(		"l4d2_spitter_acid_timeout",		"0.5",			"How often to deal damage to the same common or special infected.", CVAR_FLAGS);
	CreateConVar(						"l4d2_spitter_acid_version",		PLUGIN_VERSION,	"Spitter Acid Damage plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d2_spitter_acid_damage");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarDmgSelf.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDmgCommon.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDmgSpecial.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDmgSurvivor.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDmgSurvBots.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDamage.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarEffects.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarExplode.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarExplodes.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarGrace.AddChangeHook(ConVarChanged_Cvars);
	// ALTERNATIVE METHOD
	// g_hCvarTimescan.AddChangeHook(ConVarChanged_Cvars);
	// g_hCvarTimeout.AddChangeHook(ConVarChanged_Cvars);
}

public void OnMapStart()
{
	g_bMapStarted = true;
	PrecacheParticle(PARTICLE_SPIT);
}

public void OnMapEnd()
{
	g_bMapStarted = false;

	for( int i = 0; i < 2048; i++ )
	{
		g_fLastHit[i] = 0.0;
		g_iHooked[i] = 0;
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
	g_iCvarEffects = g_hCvarEffects.IntValue;
	g_iCvarExplode = g_hCvarExplode.IntValue;
	g_iCvarExplodes = g_hCvarExplodes.IntValue;
	g_fCvarGrace = g_hCvarGrace.FloatValue;
	g_fCvarCommon = g_hCvarDmgCommon.FloatValue;
	g_fCvarSelf = g_hCvarDmgSelf.FloatValue;
	g_fCvarSpecial = g_hCvarDmgSpecial.FloatValue;
	g_fCvarSurvivor = g_hCvarDmgSurvivor.FloatValue;
	g_fCvarSurvBots = g_hCvarDmgSurvBots.FloatValue;
	g_iCvarDamage = g_hCvarDamage.IntValue;
	// g_fCvarTime = g_hCvarTimeScan.FloatValue; // ALTERNATIVE METHOD
	// g_fCvarTimeout = g_hCvarTimeout.FloatValue; // ALTERNATIVE METHOD
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;

		if( !DHookEnableDetour(g_hDetourHarm, true, CanHarm) )
			SetFailState("Failed to enable detour \"CInsectSwarm::CanHarm\".");

		// HookEvent("round_start", Event_RoundStart); // ALTERNATIVE METHOD
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;

		if( !DHookDisableDetour(g_hDetourHarm, true, CanHarm) )
			SetFailState("Failed to disable detour \"CInsectSwarm::CanHarm\".");

		// UnhookEvent("round_start", Event_RoundStart); // ALTERNATIVE METHOD
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

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

	int iCvarModesTog = g_hCvarModesTog.IntValue;
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
//					DETOUR
// ====================================================================================================
MRESReturn CanHarm(Handle hReturn, Handle hParams)
{
	int entity = DHookGetParam(hParams, 1);

	if( entity >= 1 && entity <= MaxClients )
	{
		int team = GetClientTeam(entity);
		if( team == 2 && g_fCvarSurvivor || team == 3 && g_fCvarSpecial )
		{
			if( GetClientUserId(entity) != g_iHooked[entity] )
			{
				g_iHooked[entity] = GetClientUserId(entity);
				g_fLastHit[entity] = GetGameTime();
				SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
			}

			DHookSetReturn(hReturn, 1);
			return MRES_Override;
		} else {
			DHookSetReturn(hReturn, 0);
			return MRES_Override;
		}
	}
	else if( (g_fCvarCommon || g_iCvarExplode) && entity > MaxClients && GetGameTime() - g_fLastHit[entity] > 5.0 && IsValidEdict(entity) && IsValidEntity(entity) )
	{
		g_fLastHit[entity] = GetGameTime();

		static char temp[26];
		GetEdictClassname(entity, temp, sizeof(temp));

		// Infected
		if( g_fCvarCommon && strcmp(temp, "infected") == 0 )
		{
			if( EntIndexToEntRef(entity) != g_iHooked[entity] )
			{
				g_iHooked[entity] = EntIndexToEntRef(entity);
				SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
			}

			DHookSetReturn(hReturn, 1);
			return MRES_Override;
		}
		// Explosives
		else if( g_iCvarExplode )
		{
			// GasCan: Not Scavenge mode, or skin is normal (avoid affecting Scavenge mode gascans since they already blow up).
			if( g_iCvarExplode & 1 && strcmp(temp, "weapon_gascan") == 0 && (g_iCurrentMode != 8 || GetEntProp(entity, Prop_Data, "m_nSkin") != 1) )
			{
				AcceptEntityInput(entity, "Ignite");
			}
			else if( strcmp(temp, "prop_physics") == 0 )
			{
				GetEntPropString(entity, Prop_Data, "m_ModelName", temp, sizeof(temp));

				// models/props_junk/gascan001a.mdl
				if( g_iCvarExplode & 1 && temp[18] == 'g' && temp[19] == 'a' && (g_iCurrentMode != 8 || GetEntProp(entity, Prop_Data, "m_nSkin") != 1) ) // Gascan
				{
					AcceptEntityInput(entity, "Ignite");
				}
				// models/props_junk/explosive_box001.mdl
				else if( g_iCvarExplode & 2 && temp[18] == 'e' ) // Firework crate
				{
					if( g_iCvarExplodes & 1 )
						AcceptEntityInput(entity, "Break");
					else
						AcceptEntityInput(entity, "Ignite");
				}
				// models/props_equipment/oxygentank01.mdl
				else if( g_iCvarExplode & 4 && temp[18] == 'm' && temp[23] == 'o' && temp[24] == 'x' ) // Oxygen
				{
					if( g_iCvarExplodes & 2 )
						AcceptEntityInput(entity, "Break");
					else
						AcceptEntityInput(entity, "Ignite");
				}
				// models/props_junk/propanecanister001a.mdl
				else if( g_iCvarExplode & 8 && temp[18] == 'p' && temp[19] == 'r' && temp[20] == 'o' ) // Propane
				{
					if( g_iCvarExplodes & 4 )
						AcceptEntityInput(entity, "Break");
					else
						AcceptEntityInput(entity, "Ignite");
				}
			}
		}
	}

	return MRES_Ignored;
}

Action OnTakeDamage(int entity, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	// if( damagetype == (DMG_ENERGYBEAM | DMG_RADIATION) || damagetype == (DMG_ENERGYBEAM | DMG_RADIATION | DMG_PREVENT_PHYSICS_FORCE) )
	// 1024 (1<<10) DMG_ENERGYBEAM
	// 2048 (1<<11) DMG_PREVENT_PHYSICS_FORCE
	// 262144 (1<<18) DMG_RADIATION

	if( damagetype == 263168 || damagetype == 265216 ) // 265216 at end of entity life when fading out
	{
		// Grace period
		if( inflictor >= 0 && inflictor < 2048 && GetGameTime() < g_fLastHit[inflictor] )
		{
			damagetype = 0;
			damage = 0.0;
			return Plugin_Changed;
		}

		// Damage logic
		g_fLastHit[entity] = GetGameTime();

		if( entity > MaxClients )
		{
			// 1=Common Infected, 2=Survivors, 4=Special Infected
			 // Common
			if( g_iCvarDamage & (1<<0) )
				damage = g_fCvarCommon;
			else
				damage *= g_fCvarCommon;

			if( g_iCvarEffects & (1<<0) )		DisplayParticle(entity, PARTICLE_SPIT);

			if( damage <= 0.0 )
				return Plugin_Handled;

			return Plugin_Changed;
		} else {
			int team = GetClientTeam(entity);
			if( team == 2 || team == 4 )
			{
				// Survivors
				if( IsFakeClient(entity) )
				{
					if( g_iCvarDamage & (1<<1) )
						damage = g_fCvarSurvBots;
					else
						damage *= g_fCvarSurvBots;
				} else {
					if( g_iCvarDamage & (1<<1) )
						damage = g_fCvarSurvivor;
					else
						damage *= g_fCvarSurvivor;
				}

				if( g_iCvarEffects & (1<<1) )	DisplayParticle(entity, PARTICLE_SPIT);

				if( damage <= 0.0 )
					return Plugin_Handled;

				return Plugin_Changed;
			} else {
				// Prevent affecting ghosts
				if( GetEntProp(entity, Prop_Send, "m_isGhost") == 1 )
					return Plugin_Continue;
	
				// Special Infected
				if( entity != attacker )
				{
					// Special
					if( g_iCvarDamage & (1<<2) )
						damage = g_fCvarSpecial;
					else
						damage *= g_fCvarSpecial;

					if( g_iCvarEffects & (1<<2) )	DisplayParticle(entity, PARTICLE_SPIT);
				}
				else
				{
					// Self
					if( g_iCvarDamage & (1<<3) )
						damage = g_fCvarSelf;
					else
						damage *= g_fCvarSelf;

					if( g_iCvarEffects & (1<<3) )	DisplayParticle(entity, PARTICLE_SPIT);
				}

				if( damage <= 0.0 )
				{
					return Plugin_Handled;
				}

				return Plugin_Changed;
			}
		}
	} else {
		if( GetGameTime() - g_fLastHit[entity] > 15.0 )
		{
			g_iHooked[entity] = 0;
			SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}

	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if( strcmp(classname, "insect_swarm") == 0 )
	{
		g_fLastHit[entity] = GetGameTime() + g_fCvarGrace;
	}
}



// ====================================================================================================
//					EFFECTS
// ====================================================================================================
void DisplayParticle(int target, const char[] sParticle)
{
	int entity = CreateEntityByName("info_particle_system");
	if( entity == -1)
	{
		LogError("Failed to create 'info_particle_system'");
		return;
	}

	DispatchKeyValue(entity, "effect_name", sParticle);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "start");

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", target);

	float vPos[3];
	vPos[2] += 10;
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

	SetVariantString("OnUser4 !self:Kill::0.8:-1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser4");
}

void PrecacheParticle(const char[] sEffectName)
{
	static int table = INVALID_STRING_TABLE;
	if( table == INVALID_STRING_TABLE )
	{
		table = FindStringTable("ParticleEffectNames");
	}

	if( FindStringIndex(table, sEffectName) == INVALID_STRING_INDEX )
	{
		bool save = LockStringTables(false);
		AddToStringTable(table, sEffectName);
		LockStringTables(save);
	}
}



// ====================================================================================================
//					ALTERNATIVE METHOD
// ====================================================================================================
/*
void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 0; i < 2048; i++ )
		g_fLastHurt[i] = 0.0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if( strcmp(classname, "insect_swarm") == 0 )
	{
		CreateTimer(g_fCvarTime, TimerThink, EntIndexToEntRef(entity), TIMER_REPEAT);
	}
}

Action TimerThink(Handle timer, any entity)
{
	#if BENCHMARK
	StartProfiling(g_Profiler);
	#endif

	if( (entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE )
	{
		int i,x,y,z,c;

		static ArrayList aHand;
		aHand = new ArrayList(ByteCountToCells(12)); // (vector float * 4 bytes)

		static float vPos[3], vNew[3], vEnd[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);

		// Display vertical beams to show where each flame is.
		#if NEON_DEBUG
		vEnd[0] = vPos[0];
		vEnd[1] = vPos[1];
		vEnd[2] = vPos[2] + 500.0;
		NeonBeams_TempMap(255, vPos, vEnd, g_fCvarTime);
		#endif

		// Fire positions
		c = GetEntProp(entity, Prop_Send, "m_fireCount");
		for( i = 0; i < c; i++ )
		{
			x = GetEntProp(entity, Prop_Send, "m_fireXDelta", 4, i);
			y = GetEntProp(entity, Prop_Send, "m_fireYDelta", 4, i);
			z = GetEntProp(entity, Prop_Send, "m_fireZDelta", 4, i);

			if( x || y || z )
			{
				vNew[0] = vPos[0] + x;
				vNew[1] = vPos[1] + y;
				vNew[2] = vPos[2] + z;
				aHand.PushArray(vNew);

				// Display vertical beams to show where each flame is.
				#if NEON_DEBUG
				vEnd[0] = vNew[0];
				vEnd[1] = vNew[1];
				vEnd[2] = vNew[2] + 500.0;
				NeonBeams_TempMap(255255, vNew, vEnd, g_fCvarTime);
				#endif
			}
		}



		int target = -1;
		if( c && aHand.Length )
		{
			// Loop Common
			float dist;
			float time = GetGameTime();
			int client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

			if( g_iCvarCommon )
			{
				while( (target = FindEntityByClassname(target, "infected")) != INVALID_ENT_REFERENCE )
				{
					if( time - g_fLastHurt[target] > g_fCvarTimeout )
					{
						GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", vEnd);

						dist = GetVectorDistance(vEnd, vPos);
						if( dist < MIN_RANGE )
						{
							#if NEON_DEBUG
							PrintToServer("HURT %d @ %f", target, dist);
							vEnd[2] += 50.0;
							NeonBeams_TempMap(255, vEnd, vPos, g_fCvarTime); // Display a line from triggering flame to target
							vEnd[2] -= 50.0;
							#endif

							g_fLastHurt[target] = time;
							HurtEntity(target, client, true);
						}
						else if( dist < MAX_RANGE )
						{
							for( int index = 0; index < aHand.Length; index++ )
							{
								aHand.GetArray(index, vNew);
								if( GetVectorDistance(vEnd, vNew) < MIN_RANGE )
								{
									#if NEON_DEBUG
									PrintToServer("HURT %d @ %f", target, GetVectorDistance(vEnd, vNew));
									vEnd[2] += 50.0;
									NeonBeams_TempMap(255, vEnd, vNew, g_fCvarTime); // Display a line from triggering flame to target
									vEnd[2] -= 50.0;
									#endif

									g_fLastHurt[target] = time;
									HurtEntity(target, client, true);
									break;
								}
							}
						}
					}
				}
			}



			// Loop Specials
			if( g_iCvarSpecial )
			{
				for( target = 1; target <= MaxClients; target++ )
				{
					if( time - g_fLastHurt[target] > g_fCvarTime && IsClientInGame(target) && GetClientTeam(target) == 3 && IsPlayerAlive(target) )
					{
						GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", vEnd);

						dist = GetVectorDistance(vEnd, vPos);
						if( dist < MIN_RANGE )
						{
							#if NEON_DEBUG
							PrintToServer("HURT %N @ %f", target, dist);
							vEnd[2] += 50.0;
							NeonBeams_TempMap(255, vEnd, vPos, g_fCvarTime); // Display a line from triggering flame to target
							vEnd[2] -= 50.0;
							#endif

							g_fLastHurt[target] = time;
							HurtEntity(target, client, true);
						}
						else if( dist < MAX_RANGE )
						{
							for( int index = 0; index < aHand.Length; index++ )
							{
								aHand.GetArray(index, vNew);
								if( GetVectorDistance(vEnd, vNew) < MIN_RANGE )
								{
									#if NEON_DEBUG
									PrintToServer("HURT %N @ %f", target, GetVectorDistance(vEnd, vNew));
									vEnd[2] += 50.0;
									NeonBeams_TempMap(255, vEnd, vNew, g_fCvarTime); // Display a line from triggering flame to target
									vEnd[2] -= 50.0;
									#endif

									g_fLastHurt[target] = time;
									HurtEntity(target, client, true);
									break;
								}
							}
						}
					}
				}
			}
		}



		delete aHand;

		#if BENCHMARK
		StopProfiling(g_Profiler);
		PrintToServer("SPIT:TimerThink: %f.", GetProfilerTime(g_Profiler));
		#endif

		return Plugin_Continue;
	}

	#if BENCHMARK
	StopProfiling(g_Profiler);
	PrintToServer("SPIT:TimerThink End: %f.", GetProfilerTime(g_Profiler));
	#endif

	return Plugin_Stop;
}
// */