/*
*	Pipebomb Shove
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



#define PLUGIN_VERSION 		"1.15"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Pipebomb Shove
*	Author	:	SilverShot
*	Descrp	:	Attaches an activated pipebomb to infected when shoved by players holding pipebombs.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=188066
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.15 (25-Jan-2023)
	- Fixed the "l4d_pipebomb_shove_speed" cvar causing errors in L4D2. Thanks to "Ja-Forces" for reporting.

1.14 (25-Jan-2023)
	- L4D1: Added cvar "l4d_pipebomb_shove_speed" to control if player speed is affected by the Pipebomb being attached.
	- Fixed "MarkNativeAsOptional" being in the incorrect place. Thanks to "HarryPotter" for reporting.

1.13 (24-Jan-2023)
	- L4D1: Fixed Special Infected increased movement speed when the Pipebomb is attached. Compatible with the "Lagged Movement - Plugin Conflict Resolver" plugin.
	- Thanks to "Ja-Forces" for reporting and testing.

1.12 (01-Nov-2022)
	- Changed cvar "l4d_pipebomb_reload" to optionally require holding "R" when shoving. Requested by "Iciaria".

1.11 (14-Nov-2021)
	- Changes to fix warnings when compiling on SourceMod 1.11.
	- Updated GameData signatures to avoid breaking when detoured by the "Left4DHooks" plugin.

1.10 (10-May-2020)
	- Added better error log message when gamedata file is missing.
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Various changes to tidy up code.
	- Various optimizations and fixes.

1.9 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.8 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
	- Changed cvar "l4d_pipebomb_shove_modes_tog" now supports L4D1.

1.7.1 (24-Mar-2018)
	- Added a couple checks to prevent errors being logged - Thanks to "Crasher_3637" for reporting.

1.7 (02-Dec-2017)
	- Added cvar "l4d_pipebomb_reload" to make the "Reload" key attach the pipebomb. Thanks to "bazrael" for the idea and testing.
	- Added cvar "l4d_pipebomb_time" to set the fuse duration before detonation. Thanks to "Sunyata" for the idea and testing.

1.6 (21-Jun-2015)
	- Fixed "GetEntPropEnt" error - Thanks to "Danny_l4d" for reporting.

1.5 (07-Oct-2012)
	- Fixed tank attachment and tank related cvars in L4D1 - Thanks to "disawar1" for fixing.
	- Changed the Witch attachment point from her mouth to her eye!

1.4 (03-Jul-2012)
	- Fixed errors by adding some checks - Thanks to "gajo0650" for reporting.

1.3 (30-Jun-2012)
	- Fixed the plugin not working in L4D1.
	- Fixed sticking the pipebomb into common infected which have just died.

1.2 (23-Jun-2012)
	- Fixed the last update breaking the plugin.

1.1 (22-Jun-2012)
	- Added cvars "l4d_pipebomb_shove_damage" and "l4d_pipebomb_shove_distance".

1.0 (21-Jun-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY

#define GAMEDATA			"l4d_pipebomb_shove"
#define PARTICLE_FUSE		"weapon_pipebomb_fuse"
#define PARTICLE_LIGHT		"weapon_pipebomb_blinking_light"
#define MAX_GRENADES		32


Handle sdkActivatePipe;
ConVar g_hCvarAllow, g_hCvarDamage, g_hCvarDistance, g_hCvarInfected, g_hCvarL4DTime, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarReload, g_hCvarSpeed, g_hCvarTime;
int g_iClients[MAX_GRENADES], g_iCvarInfected, g_iCvarL4DTime, g_iCvarReload, g_iCvarTime, g_iGrenades[MAX_GRENADES], g_iClassTank;
bool g_bCvarAllow, g_bCvarSpeed, g_bMapStarted, g_bCvarSwitching, g_bLeft4Dead2, g_bLaggedMovement;
float g_fCvarDamage, g_fCvarDistance;

native any L4D_LaggedMovement(int client, float value, bool force = false);



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Pipebomb Shove",
	author = "SilverShot",
	description = "Attaches an activated pipebomb to infected when shoved by players holding pipebombs.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=188066"
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

	MarkNativeAsOptional("L4D_LaggedMovement");

	return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
	if( strcmp(name, "LaggedMovement") == 0 )
	{
		g_bLaggedMovement = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if( strcmp(name, "LaggedMovement") == 0 )
	{
		g_bLaggedMovement = false;
	}
}

public void OnPluginStart()
{
	// GameData
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Static);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CPipeBombProjectile_Create") == false )
		SetFailState("Could not load the \"CPipeBombProjectile_Create\" gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	sdkActivatePipe = EndPrepSDKCall();
	if( sdkActivatePipe == null )
		SetFailState("Could not prep the \"CPipeBombProjectile_Create\" function.");

	delete hGameData;

	// Cvars
	g_hCvarAllow = CreateConVar(	"l4d_pipebomb_shove_allow",			"1",			"0=关闭插件，1=打开插件", CVAR_FLAGS );
	g_hCvarDamage = CreateConVar(	"l4d_pipebomb_shove_damage",		"50",			"0=默认. 其他值将设置爆炸伤害", CVAR_FLAGS );
	g_hCvarDistance = CreateConVar(	"l4d_pipebomb_shove_distance",		"300",			"0=默认。其他值设置爆炸伤害范围", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(	"l4d_pipebomb_shove_modes",			"",				"在这些游戏模式下打开插件，用逗号分隔（没有空格）（空=全部）", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(	"l4d_pipebomb_shove_modes_off",		"",				"在这些游戏模式下关闭插件，用逗号分隔（没有空格）（空=无）", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(	"l4d_pipebomb_shove_modes_tog",		"0",			"在这些游戏模式中打开插件。0=全部，1=战役，2=生还者，4=对抗，8=清道夫。将数字相加", CVAR_FLAGS );
	g_hCvarInfected = CreateConVar(	"l4d_pipebomb_shove_infected",		"511",			"自制手雷爆炸将伤害到哪些感染者 1=小僵尸, 2=Witch, 4=Smoker, 8=Boomer, 16=Hunter, 32=Spitter, 64=Jockey, 128=Charger, 256=Tank, 511=全部", CVAR_FLAGS );
	g_hCvarReload = CreateConVar(	"l4d_pipebomb_reload",				"0",			"0=关闭, 1=可用换弹键切换到自制手雷, 2=只能用换弹键切换到自制手雷", CVAR_FLAGS );
	g_hCvarTime = CreateConVar(		"l4d_pipebomb_time",				"6",			"自制手雷多少秒爆炸，游戏默认6秒", CVAR_FLAGS );
	if( !g_bLeft4Dead2 )
		g_hCvarSpeed = CreateConVar("l4d_pipebomb_shove_speed",			"0",			"0=手雷连接到玩家(特感玩家?)时，阻止加速 1=允许加速", CVAR_FLAGS );
	CreateConVar(					"l4d_pipebomb_shove_version",		PLUGIN_VERSION,	"Pipebomb Shove plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,			"l4d_pipebomb_shove");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarDamage.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDistance.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarInfected.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarReload.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTime.AddChangeHook(ConVarChanged_Cvars);
	if( !g_bLeft4Dead2 )
		g_hCvarSpeed.AddChangeHook(ConVarChanged_Cvars);

	g_hCvarL4DTime = FindConVar("pipe_bomb_timer_duration");
	g_hCvarL4DTime.AddChangeHook(ConVarChanged_Pipe);
	FuseChanged();

	g_iClassTank = g_bLeft4Dead2 ? 9 : 6;
}

public void OnPluginEnd()
{
	if( !g_bLeft4Dead2 )
	{
		for( int i = 0; i < MAX_GRENADES; i++ )
		{
			if( g_iGrenades[i] && EntRefToEntIndex(g_iGrenades[i]) != INVALID_ENT_REFERENCE && g_iClients[i] && IsClientInGame(g_iClients[i]) )
			{
				SetEntPropFloat(g_iClients[i], Prop_Send, "m_flLaggedMovementValue", g_bLaggedMovement ? L4D_LaggedMovement(i, 1.0, true) : 1.0);
			}
		}
	}
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

void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void ConVarChanged_Pipe(Handle convar, const char[] oldValue, const char[] newValue)
{
	FuseChanged();
}

void FuseChanged()
{
	if( !g_bCvarSwitching ) g_iCvarL4DTime = g_hCvarL4DTime.IntValue;
}

void GetCvars()
{
	g_fCvarDamage = g_hCvarDamage.FloatValue;
	g_fCvarDistance = g_hCvarDistance.FloatValue;
	g_iCvarInfected = g_hCvarInfected.IntValue;
	g_iCvarReload = g_hCvarReload.IntValue;
	g_iCvarTime = g_hCvarTime.IntValue;
	if( !g_bLeft4Dead2 )
		g_bCvarSpeed = g_hCvarSpeed.BoolValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("player_death", Event_PlayerDeath);
		HookEvent("entity_shoved", Event_EntityShoved);
		HookEvent("player_shoved", Event_PlayerShoved);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvent("player_death", Event_PlayerDeath);
		UnhookEvent("entity_shoved", Event_EntityShoved);
		UnhookEvent("player_shoved", Event_PlayerShoved);
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
public void OnClientDisconnect(int client)
{
	MatchClients(client);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	if( userid )
	{
		int client = GetClientOfUserId(userid);
		if( client )
		{
			MatchClients(client);
		}
	}
	else
	{
		int common = event.GetInt("entityid");
		if( common )
		{
			MatchClients(common);
		}
	}
}

void MatchClients(int client)
{
	for( int i = 0; i < MAX_GRENADES; i++ )
	{
		if( g_iClients[i] == client )
		{
			if( client > 0 && client <= MaxClients )
			{
				SDKUnhook(client, SDKHook_PreThinkPost, PreThinkPost);
				SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_bLaggedMovement ? L4D_LaggedMovement(client, 1.0, true) : 1.0);
			}

			int entity = g_iGrenades[i];
			g_iClients[i] = 0;
			g_iGrenades[i] = 0;

			if( IsValidEntity(entity) )
			{
				SetEntityMoveType(entity, MOVETYPE_FLYGRAVITY);
				AcceptEntityInput(entity, "ClearParent");
			}
		}
	}
}

void Event_EntityShoved(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iCvarReload != 2 )
	{
		int infected = g_iCvarInfected & (1 << 0);
		int witch = g_iCvarInfected & (1 << 1);
		if( infected || witch )
		{
			int client = GetClientOfUserId(event.GetInt("attacker"));

			if( g_iCvarReload != 3 || GetClientButtons(client) & IN_RELOAD )
			{
				int weapon = CheckWeapon(client);
				if( weapon )
				{
					int target = event.GetInt("entityid");

					char sTemp[10];
					GetEntityClassname(target, sTemp, sizeof(sTemp));

					if( (infected && strcmp(sTemp, "infected") == 0 ) )
					{
						if( GetEntProp(target, Prop_Data, "m_iHealth") >= 1 )
						{
							AttachPipe(target, client, weapon, 0);
						}
					}
					else if( (witch && strcmp(sTemp, "witch") == 0) )
					{
						AttachPipe(target, client, weapon, -1);
					}
				}
			}
		}
	}
}

void Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iCvarInfected && g_iCvarReload != 2 )
	{
		int client = GetClientOfUserId(event.GetInt("attacker"));

		if( g_iCvarReload != 3 || GetClientButtons(client) & IN_RELOAD )
		{
			int target = GetClientOfUserId(event.GetInt("userid"));

			if( GetClientTeam(target) == 3 )
			{
				int weapon = CheckWeapon(client);
				if( weapon )
				{
					int class = GetEntProp(target, Prop_Send, "m_zombieClass") + 1;
					if( class == g_iClassTank ) class = 8;
					if( g_iCvarInfected & (1 << class) )
					{
						AttachPipe(target, client, weapon, class -1);
					}
				}
			}
		}
	}
}



// ====================================================================================================
//					SHOVE
// ====================================================================================================
static float g_fLastUse;
public Action OnPlayerRunCmd(int client, int &buttons)
{
	if( g_bCvarAllow && g_iCvarReload != 0 && g_iCvarReload != 3 && buttons & IN_RELOAD )
	{
		float fNow = GetEngineTime();
		if( fNow - g_fLastUse > 0.2 )
		{
			g_fLastUse = fNow;

			int target = GetClientAimTarget(client, false);
			if( target != -1)
			{
				DoKey(client, target);
			}
		}
	}

	return Plugin_Continue;
}

void DoKey(int client, int target)
{
	int weapon = CheckWeapon(client);
	if( weapon )
	{
		if( target > MaxClients )
		{
			int infected = g_iCvarInfected & (1 << 0);
			int witch = g_iCvarInfected & (1 << 1);
			if( infected || witch )
			{
				char sTemp[10];
				GetEntityClassname(target, sTemp, sizeof(sTemp));

				if( (infected && strcmp(sTemp, "infected") == 0 ) )
				{
					if( GetEntProp(target, Prop_Data, "m_iHealth") >= 1 )
					{
						AttachPipe(target, client, weapon, 0);
					}
				}
				else if( (witch && strcmp(sTemp, "witch") == 0) )
				{
					AttachPipe(target, client, weapon, -1);
				}
			}
		} else {
			if( GetClientTeam(target) == 3 )
			{
				int class = GetEntProp(target, Prop_Send, "m_zombieClass") + 1;
				if( class == g_iClassTank ) class = 8;
				if( g_iCvarInfected & (1 << class) )
				{
					AttachPipe(target, client, weapon, class -1);
				}
			}
		}
	}
}

int CheckWeapon(int client)
{
	if( client && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2 )
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if( weapon > 0 && IsValidEntity(weapon) )
		{
			static char sTemp[20];
			GetEntityClassname(weapon, sTemp, sizeof(sTemp));
			if( strcmp(sTemp[7], "pipe_bomb") == 0 )
				return weapon;
		}
	}
	return 0;
}



// ====================================================================================================
//					CREATE PIPE BOMB
// ====================================================================================================
void AttachPipe(int target, int client, int weapon, int special)
{
	int index = -1;

	for( int i = 0; i < MAX_GRENADES; i++ )
	{
		if( g_iClients[i] == 0 || g_iGrenades[i] == 0 || EntRefToEntIndex(g_iGrenades[i]) == INVALID_ENT_REFERENCE )
		{
			index = i;
			break;
		}
	}

	if( index == -1 ) return;

	g_bCvarSwitching = true;
	g_hCvarL4DTime.SetInt(g_iCvarTime);

	RemovePlayerItem(client, weapon);
	RemoveEntity(weapon);

	float vAng[3], vPos[3];
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", vPos);
	vPos[2] += 40.0;

	int entity = SDKCall(sdkActivatePipe, vPos, vAng, vAng, vAng, client, 2.0);

	g_iClients[index] = target;
	g_iGrenades[index] = EntIndexToEntRef(entity);

	CreateParticle(entity, 0);
	CreateParticle(entity, 1);

	if( g_fCvarDistance )	SetEntPropFloat(entity, Prop_Data, "m_DmgRadius", g_fCvarDistance);
	if( g_fCvarDamage )		SetEntPropFloat(entity, Prop_Data, "m_flDamage", g_fCvarDamage);

	SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
	SetEntityMoveType(entity, MOVETYPE_NONE);

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", target);

	if( special == -1 )
		SetVariantString("leye");
	else if( special == 1 )
		SetVariantString("smoker_mouth");
	else if( special == 3 || special == 5 || special == 6 )
		SetVariantString(GetRandomInt(0, 1) ? "rhand" : "lhand");
	else
		SetVariantString("mouth");

	AcceptEntityInput(entity, "SetParentAttachment", target);
	TeleportEntity(entity, NULL_VECTOR, view_as<float>({ 90.0, 0.0, 0.0 }), NULL_VECTOR);

	// Scale the Special Infected speed in L4D1 because for whatever reason when attaching the pipebomb they speed up
	if( !g_bLeft4Dead2 && !g_bCvarSpeed && target <= MaxClients )
	{
		SDKHook(target, SDKHook_PreThinkPost, PreThinkPost);
	}

	// Reset pipebomb detonate time
	g_hCvarL4DTime.SetInt(g_iCvarL4DTime);
	g_bCvarSwitching = false;
}



// ====================================================================================================
//					L4D1 - FIX MOVEMENT SPEED
// ====================================================================================================
void PreThinkPost(int client)
{
	for( int i = 0; i < MAX_GRENADES; i++ )
	{
		if( g_iClients[i] == client && g_iGrenades[i] && EntRefToEntIndex(g_iGrenades[i]) != INVALID_ENT_REFERENCE )
		{
			// =========================
			// Plugins should include this code within their PreThinkPost function when modifying the m_flLaggedMovementValue value to prevent bugs
			// Written by "Silvers"
			// =========================
			// Fix movement speed bug when jumping or staggering
			if( GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1 || GetEntPropFloat(client, Prop_Send, "m_staggerTimer", 1) > -1.0 )
			{
				// Fix jumping resetting velocity to default
				float value = GetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue");
				if( value != 1.0 )
				{
					float vVec[3];
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVec);
					float height = vVec[2];

					ScaleVector(vVec, value);
					vVec[2] = height; // Maintain default jump height

					TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVec);
				}

				SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_bLaggedMovement ? L4D_LaggedMovement(client, 1.0, true) : 1.0);
				return;
			}
			// =========================

			SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", g_bLaggedMovement ? L4D_LaggedMovement(client, 0.5, true) : 0.5);

			return;
		}
	}

	SDKUnhook(client, SDKHook_PreThinkPost, PreThinkPost);
}



// ====================================================================================================
//					PARTICLES
// ====================================================================================================
void CreateParticle(int target, int type)
{
	int entity = CreateEntityByName("info_particle_system");
	if( type == 0 )	DispatchKeyValue(entity, "effect_name", PARTICLE_FUSE);
	else			DispatchKeyValue(entity, "effect_name", PARTICLE_LIGHT);

	DispatchSpawn(entity);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "Start");

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", target);

	if( type == 0 )	SetVariantString("fuse");
	else			SetVariantString("pipebomb_light");
	AcceptEntityInput(entity, "SetParentAttachment", target);
}