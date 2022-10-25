/*
*	Incapped Shove
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

*	Name	:	[L4D & L4D2] Incapped Shove
*	Author	:	SilverShot
*	Descrp	:	Allows Survivors to shove common and special infected while incapacitated.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=318729
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.11 (24-Apr-2022)
	- GameData file updated: Wildcarded signatures to be compatible with the "Left4DHooks" plugin version 1.98 and newer.
	- Changed the swing SDKCall to the correct method.

1.10 (04-Dec-2021)
	- Changes to fix warnings when compiling on SourceMod 1.11.

1.9 (15-May-2020)
	- Fixed not damaging Special Infected.
	- Replaced "point_hurt" entity with "SDKHooks_TakeDamage" function.

1.8 (10-May-2020)
	- Added better error log message when gamedata file is missing.
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Various changes to tidy up code.
	- Various optimizations and fixes.

1.7 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.6 (20-Jan-2020)
	- Added cvar "l4d_incapped_shove_hurt" to damage the player each time they shove.

1.5 (19-Jan-2020)
	- Added cvar "l4d_incapped_shove_pounced" to control if shoving while pinned is allowed.

1.4 (06-Jan-2020)
	- Fixed invalid entity errors. Thanks to "xZk" for reporting.

1.3 (01-Nov-2019)
	- Fixed being able to shove while hanging from a ledge.

1.2 (10-Oct-2019)
	- Can now push and stumble Common Infected in L4D1. Thanks to "Dragokas" for reporting.

1.1 (10-Oct-2019)
	- L4D1 Linux: Gamedata updated to fix crashing. Thanks to "Dragokas" for reporting.
	- Added cvar "l4d_incapped_shove_penalty" to set a shove penalty.
	- Added cvar "l4d_incapped_shove_swing" to set next shove time.
	- Changed "l4d_incapped_shove_types" by adding 8=Tank as an option.

1.0 (17-Sep-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d_incapped_shove"
#define MAX_DEGREE			90.0	// Degrees to spread traces over.
#define MAX_TRACES			11		// How many TraceHull traces per hit. Odd number so 1 trace shoots down the center.


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarCooldown, g_hCvarDamage, g_hCvarHurt, g_hCvarPenalty, g_hCvarPounce, g_hCvarRange, g_hCvarTypes;
Handle g_hSDK_OnSwingStart, g_hSDK_StaggerClient;
bool g_bCvarAllow, g_bMapStarted, g_bLeft4Dead2;
float g_fTimeout[MAXPLAYERS + 1];
int g_iIgnore[MAX_TRACES + 1];
int g_iClassTank;

int g_iCvarDamage, g_iCvarHurt, g_iCvarPounce, g_iCvarRange, g_iCvarTypes;
float g_fCvarCooldown, g_fCvarPenalty;



// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Incapped Shove",
	author = "SilverShot",
	description = "Allows Survivors to shove common and special infected while incapacitated.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=318729"
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
	// CVARS
	g_hCvarAllow = CreateConVar(	"l4d_incapped_shove_allow",			"1",					"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarDamage = CreateConVar(	"l4d_incapped_shove_damage",		"5",					"The amount of damage each hit does.", CVAR_FLAGS );
	g_hCvarHurt =	CreateConVar(	"l4d_incapped_shove_hurt",			"0",					"Each time the player shoves they will be damaged by this much.", CVAR_FLAGS);
	g_hCvarPenalty = CreateConVar(	"l4d_incapped_shove_penalty",		"0.1",					"Penalty delay to add per shove. Delays each consecutive swing by this amount.", CVAR_FLAGS );
	g_hCvarPounce = CreateConVar(	"l4d_incapped_shove_pounced",		"0",					"0=Off. Allow shoving while incapped and pinned by 1=Smoker, 2=Hunter, 4=Charger. 7=All. Add numbers together.", CVAR_FLAGS );
	g_hCvarRange = CreateConVar(	"l4d_incapped_shove_range",			"85",					"How close to survivors, common or special infected to stumble them.", CVAR_FLAGS );
	g_hCvarCooldown = CreateConVar(	"l4d_incapped_shove_swing",			"0.8",					"How quickly can a survivor shove. Time to wait till next swing.", CVAR_FLAGS );
	g_hCvarTypes = CreateConVar(	"l4d_incapped_shove_types",			"5",					"Who to affect: 1=Common Infected, 2=Survivors, 4=Special Infected, 8=Tank. Add numbers together.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(	"l4d_incapped_shove_modes",			"",						"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(	"l4d_incapped_shove_modes_off",		"",						"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(	"l4d_incapped_shove_modes_tog",		"0",					"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	CreateConVar(					"l4d_incapped_shove_version",		PLUGIN_VERSION,			"Incapped Shove plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,			"l4d_incapped_shove");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarDamage.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHurt.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarPenalty.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarPounce.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRange.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCooldown.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTypes.AddChangeHook(ConVarChanged_Cvars);



	// GAMEDATA
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Player);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::OnStaggered") == false )
		SetFailState("Could not load the 'CTerrorPlayer::OnStaggered' gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	g_hSDK_StaggerClient = EndPrepSDKCall();
	if( g_hSDK_StaggerClient == null )
		SetFailState("Could not prep the 'CTerrorPlayer::OnStaggered' function.");

	StartPrepSDKCall(SDKCall_Entity);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorWeapon::OnSwingStart") == false )
		SetFailState("Could not load the 'CTerrorWeapon::OnSwingStart' gamedata signature.");
	g_hSDK_OnSwingStart = EndPrepSDKCall();
	if( g_hSDK_OnSwingStart == null )
		SetFailState("Could not prep the 'CTerrorWeapon::OnSwingStart' function.");

	delete hGameData;



	// EVENTS
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	g_iClassTank = g_bLeft4Dead2 ? 8 : 5;
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
	g_iCvarDamage		= g_hCvarDamage.IntValue;
	g_iCvarHurt			= g_hCvarHurt.IntValue;
	g_fCvarPenalty		= g_hCvarPenalty.FloatValue;
	g_iCvarPounce		= g_hCvarPounce.IntValue;
	g_iCvarRange		= g_hCvarRange.IntValue;
	g_fCvarCooldown		= g_hCvarCooldown.FloatValue;
	g_iCvarTypes		= g_hCvarTypes.IntValue;
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
//					EVENTS
// ====================================================================================================
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 0; i <= MaxClients; i++ )
	{
		g_fTimeout[i] = 0.0;
	}
}
	
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
// public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	// Validate
	if(
		g_bCvarAllow &&																			// Plugin on
		buttons & IN_ATTACK2 &&																	// Shove button
		!(buttons & IN_FORWARD) &&																// Not moving
		GetClientTeam(client) == 2 &&															// Survivor
		!IsFakeClient(client) &&																// Human
		GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) &&								// Incapped
		GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) == 0 &&						// Not on ledge
		GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_flNextShoveTime") > 0				// Can shove
	)
	{
		// Verify pinned
		if(
			g_iCvarPounce && (
			(g_iCvarPounce & (1<<0) == 0 && GetEntProp(client, Prop_Send, "m_tongueOwner") > 0) ||
			(g_iCvarPounce & (1<<1) == 0 && GetEntProp(client, Prop_Send, "m_pounceAttacker") > 0) ||
			(g_bLeft4Dead2 && g_iCvarPounce & (1<<2) == 0 && GetEntProp(client, Prop_Send, "m_pummelAttacker") > 0)
			)
		) return Plugin_Continue;

		// Swing
		int entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if( entity <= MaxClients || IsValidEntity(entity) == false ) return Plugin_Continue;

		SDKCall(g_hSDK_OnSwingStart, entity);

		// Hurt
		if( g_iCvarHurt )
		{
			int iHealth = GetClientHealth(client) - g_iCvarHurt;
			if( iHealth > 0 )
				SetEntityHealth(client, iHealth);
		}

		// Penalty
		int penalty;
		if( g_fCvarPenalty )
		{
			penalty = GetEntProp(client, Prop_Send, "m_iShovePenalty");
			if( penalty > 0 )
			{
				// Last swing more than 1 second ago
				int last = RoundToFloor(GetGameTime() - g_fTimeout[client]);
				if( last > 1 )
				{
					// Remove penalty by number of seconds since last swing.
					penalty -= last;
					if( penalty < 0 ) penalty = 0;
				}
			}

			SetEntProp(client, Prop_Send, "m_iShovePenalty", penalty + 1);
			g_fTimeout[client] = GetGameTime();
		}

		// Set next shove
		SetEntPropFloat(client, Prop_Send, "m_flNextShoveTime", GetGameTime() + g_fCvarCooldown + (penalty * g_fCvarPenalty));

		// Hit
		// float fStart = GetEngineTime(); // Benchmark
		DoTraceHit(client);
		// PrintToServer("DoTraceHit took: %f", GetEngineTime() - fStart);
	}

	return Plugin_Continue;
}

void DoTraceHit(int client)
{
	g_iIgnore[0] = client;

	// Try to hit several
	float vPos[3], vAng[3], vLoc[3];
	GetClientEyePosition(client, vPos);
	GetClientEyeAngles(client, vAng);

	char sTemp[16];
	Handle trace;
	int target;

	// Divide degree by traces
	vAng[1] += (MAX_DEGREE / 2);
	vAng[0] = 0.0; // Point horizontal
	// vAng[0] = -15.0; // Point up
	// vPos[2] -= 5;
	vPos[2] += 15;

	// Loop number of traces
	for( int i = 1; i <= MAX_TRACES; i++ )
	{
		g_iIgnore[i] = 0;

		vAng[1] -= (MAX_DEGREE / (MAX_TRACES + 1));
		trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, FilterExcludeSelf);

		if( TR_DidHit(trace) == false )
		{
			delete trace;
			continue;
		}

		/* // Test to show traces:
		#include <neon_beams> // Put outside of function
		float vEnd[3];
		TR_GetEndPosition(vEnd, trace);
		NeonBeams_TempMap(0, vPos, vEnd, 5.0);
		// */

		// Validate entity hit
		target = TR_GetEntityIndex(trace);
		delete trace;

		if( target <= 0 || IsValidEntity(target) == false )
			continue;

		// Unique hit
		for( int x = 0; x < i; x++ )
			if( g_iIgnore[x] == target )
				target = 0;

		if( target == 0 )
			continue;

		g_iIgnore[i] = target;

		// Push survivor/special infected
		if( target <= MaxClients )
		{
			if( g_iCvarTypes > 1 && IsClientInGame(target) && IsPlayerAlive(target) )
			{
				// Type check
				int team = GetClientTeam(target);
				if(
					team == 2 && g_iCvarTypes & (1<<1) ||
					team == 3 && g_iCvarTypes & (1<<2) ||
					team == 3 && g_iCvarTypes & (1<<3)
				)
				{
					// Tank allowed?
					if( team == 3 && !(g_iCvarTypes & (1<<3)) && GetEntProp(target, Prop_Send, "m_zombieClass") == g_iClassTank )
						continue;

					// Specials allowed?
					if( team == 3 && !(g_iCvarTypes & (1<<2)) && GetEntProp(target, Prop_Send, "m_zombieClass") != g_iClassTank )
						continue;

					// Damage
					SDKHooks_TakeDamage(target, client, client, float(g_iCvarDamage), DMG_GENERIC);

					// Range check
					GetClientEyePosition(target, vLoc);
					if( GetVectorDistance(vPos, vLoc) < g_iCvarRange )
						SDKCall(g_hSDK_StaggerClient, target, client, vPos); // Stagger: SDKCall method
				}
			}
		}
		// Push common infected
		else if( g_iCvarTypes & (1<<0) )
		{
			// Check class
			GetEdictClassname(target, sTemp, sizeof(sTemp));
			if( strcmp(sTemp, "infected") == 0 )
			{
				// Range check
				GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", vLoc);
				if( GetVectorDistance(vPos, vLoc) < g_iCvarRange )
				{
					// Push common
					PushCommonInfected(client, target, vPos);
				}
			}
		}
	}
}

void PushCommonInfected(int client, int target, float vPos[3])
{
	SDKHooks_TakeDamage(target, client, client, float(g_iCvarDamage), g_bLeft4Dead2 ? DMG_AIRBOAT : DMG_BUCKSHOT, -1, NULL_VECTOR, vPos); // Common L4D2 / L4D1
}

public bool FilterExcludeSelf(int entity, int contentsMask, any client)
{
	if( entity == client )
		return false;
	return true;
}