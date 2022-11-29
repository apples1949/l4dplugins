/**
 * ================================================================================ *
 *                      [L4D & L4D2] Survivor Utilities (API)                       *
 * -------------------------------------------------------------------------------- *
 *  Author      :   Eärendil                                                        *
 *  Descrp      :   Modify survivor speeds and add custom effects.                  *
 *  Version     :   1.4                                                             *
 *  Link        :   https://forums.alliedmods.net/showthread.php?t=335683           *
 * ================================================================================ *
 *                                                                                  *
 *  CopyRight (C) 2022 Eduardo "Eärendil" Chueca                                    *
 * -------------------------------------------------------------------------------- *
 *  This program is free software; you can redistribute it and/or modify it under   *
 *  the terms of the GNU General Public License, version 3.0, as published by the   *
 *  Free Software Foundation.                                                       *
 *                                                                                  *
 *  This program is distributed in the hope that it will be useful, but WITHOUT     *
 *  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS   *
 *  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more          *
 *  details.                                                                        *
 *                                                                                  *
 *  You should have received a copy of the GNU General Public License along with    *
 *  this program.  If not, see <http://www.gnu.org/licenses/>.                      *
 * ================================================================================ *
 *                                                                                  *
 *  Additional info:                                                                *
 *   - This speed method is not perfect, speed doesn't increase linearly.           *
 *   - Recommended values between 0.5 and 1.75 of player speed.                     *
 *   - Higher or lower values will lose linearly easily and players will notice     *
 *      weird speed changes while moving.                                           *
 *  Special thanks:                                                                 *
 *   - SilverShot for helping with the postprocess and fog_volume. Also for advices *
 *      using natives and GlobalForwards.                                           *
 * ================================================================================ *
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <left4dhooks>
#include <survivorutilities>
#include <profiler>

#define PLUGIN_VERSION	"1.4"
#define GAMEDATA		"l4d_survivor_utilities"

#define SND_BLEED1		"player/survivor/splat/blood_spurt1.wav"
#define SND_BLEED2		"player/survivor/splat/blood_spurt2.wav"
#define SND_BLEED3		"player/survivor/splat/blood_spurt3.wav"
#define SND_CHOKE		"player/survivor/voice/choke_5.wav"
#define SND_FREEZE		"physics/glass/glass_impact_bullet4.wav"
#define EXHAUST_TOKEN	150

enum
{
	STATUS_INCAP,
	STATUS_NORMAL,
	STATUS_LIMP,
	STATUS_CRITICAL,
	STATUS_ADRENALINE
};

static char g_sWeaponRecoils[][] = {	"shotgun",	"hunting",	"sniper",	"smg",	"magnum",	"pistol",	"ak47",	"desert",	"m60",	"rifle" };
static float g_fWeaponRecoils[]= {		18.5, 		14.5, 		14.5,		3.0,	7.5,		2.5,		4.2,	3.2,		4.5,	4.0 };

// Player Speeds
float g_fRunSpeed[MAXPLAYERS+1];		// Normal player speed (default = 220.0)
float g_fWaterSpeed[MAXPLAYERS+1];		// Player speed on water (default = 115.0)
float g_fLimpSpeed[MAXPLAYERS+1];		// Player speed while limping (default = 150.0)
float g_fCritSpeed[MAXPLAYERS+1];		// Player speed when 1 HP after 1 incapacitation (default = 85.0)
float g_fWalkSpeed[MAXPLAYERS+1];		// Player speed while walking (default = 85.0)
float g_fCrouchSpeed[MAXPLAYERS+1];		// Player speed while crouching (default = 75.0)
float g_fExhaustSpeed[MAXPLAYERS+1];	// Player speed while exhaust
float g_fScopeSpeed[MAXPLAYERS+1];		// Player speed while looking through a sniper scope
float g_fAdrenRunSpeed[MAXPLAYERS+1];	// Player speed when running under adrenaline effect
// Player conditions
bool g_bIsFrozen[MAXPLAYERS+1];			// Store if player is frozen
int g_iExhaustToken[MAXPLAYERS+1];		// Player exhaust tokens
int g_iToxicToken[MAXPLAYERS+1];		// Player intoxication tokens
int g_iBleedToken[MAXPLAYERS+1];		// Player bleeding tokens
float g_fFreezeTime[MAXPLAYERS+1];		// Player frozen lifetime (this value is needed to stack times)
float g_fRecoilStack[MAXPLAYERS+1];		// Stacked recoil
float g_fSaveFreeze[MAXPLAYERS+1];		// Save freeze time if player goes idle to try to skip it!
// Timer Handles
Handle g_hToxicTimer[MAXPLAYERS+1]; 	// Timer that causes damage and toxic effect to intoxicated clients
Handle g_hBleedTimer[MAXPLAYERS+1];		// Timer that causes damage and bleed effect to bleeding clients
Handle g_hFreezeTimer[MAXPLAYERS+1];	// Timer that resumes player movement and removes freeze effect
Handle g_hExhaustTimer[MAXPLAYERS+1];	// Timer that removes exhaust effect
Handle g_hRecoilTimer[MAXPLAYERS+1];	// Timer that removes stacked recoils on exhausted players

ConVar	g_hRunSpeed, g_hWaterSpeed, g_hLimpSpeed, g_hCritSpeed, g_hWalkSpeed, g_hCrouchSpeed, g_hExhaustSpeed, g_hTempDecay,
		g_hToxicDmg, g_hToxicDelay, g_hBleedDmg, g_hBleedDelay, g_hLimpHealth, g_hFreezeOverride,
		g_hToxicOverride, g_hBleedOverride, g_hExhaustOverride, g_hHealDuration, g_hReviveDuration,
		g_hDefibDuration, g_hAdrenSpeed, g_hMaxHealth, g_hRecoilScale, g_hScopeSpeed, g_hAdrenRunSpeed;

GlobalForward gf_Freeze;
GlobalForward gf_Bleed;
GlobalForward gf_Toxic;
GlobalForward gf_Exhaust;
GlobalForward gf_FreezeEnd;
GlobalForward gf_BleedEnd;
GlobalForward gf_ToxicEnd;
GlobalForward gf_ExhaustEnd;
GlobalForward gf_Defib;
GlobalForward gf_Revive;
GlobalForward gf_Heal;
GlobalForward gf_FreezePost;
GlobalForward gf_BleedPost;
GlobalForward gf_ToxicPost;
GlobalForward gf_ExhaustPost;
GlobalForward gf_DefibPost;
GlobalForward gf_RevivePost;
GlobalForward gf_HealPost;

bool g_bL4D2;

// I use here variables to store ConVars that can be requested every frame
float g_fTempDecay;
float g_fLimpHealth;
int g_iMaxHealth;
// Temporary stores original ConVar when is modified to change per-player heal and revive speeds
float g_fHealDuration;
float g_fDefibDuration;
float g_fReviveDuration;
bool g_bHealChanged, g_bReviveChanged; // To tell post hooks that the pre-hooks have changed the ConVar value and they have to reset it
		
int g_iPostProcess;		// env_postprocess entity reference
int g_iFogVolume;		// env_fog entity reference
bool g_iEntMustDie;		// Requested by SetTransmit to know if postprocess and fog_volume must be killed

public Plugin myinfo =
{
	name = "[L4D & L4D2] Survivor Utilities (API)",
	author = "Eärendil",
	description = "Modify survivor speeds and add custom effects.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=335683",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if( GetEngineVersion() == Engine_Left4Dead2 )
		g_bL4D2 = true;

	else if( GetEngineVersion() != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2");
		return APLRes_SilentFailure;
	}
	
	// Natives to call functions on players
	CreateNative("SU_AddFreeze",		Native_AddFreeze);
	CreateNative("SU_RemoveFreeze",		Native_RemoveFreeze);
	CreateNative("SU_AddBleed",			Native_AddBleed);
	CreateNative("SU_RemoveBleed",		Native_RemoveBleed);
	CreateNative("SU_AddToxic",			Native_AddToxic);
	CreateNative("SU_RemoveToxic",		Native_RemoveToxic);
	CreateNative("SU_SetSpeed",			Native_SetSpeed);
	CreateNative("SU_AddExhaust",		Native_AddExhaust);
	CreateNative("SU_RemoveExhaust",	Native_RemoveExhaust);
	// Natives to get player status
	CreateNative("SU_IsFrozen",			Native_GetFreeze);
	CreateNative("SU_IsBleeding",		Native_GetBleed);
	CreateNative("SU_IsToxic",			Native_GetToxic);
	CreateNative("SU_GetSpeed",			Native_GetSpeed);
	CreateNative("SU_IsExhausted",		Native_GetExhaust);

	// Forwards when survivor conditions are being set (can be modified)
	gf_Freeze =		new GlobalForward("SU_OnFreeze",			ET_Event, Param_Cell, Param_FloatByRef);
	gf_Bleed =		new GlobalForward("SU_OnBleed",				ET_Event, Param_Cell, Param_CellByRef);
	gf_Toxic =		new GlobalForward("SU_OnToxic",				ET_Event, Param_Cell, Param_CellByRef);
	gf_Exhaust =	new GlobalForward("SU_OnExhaust",			ET_Event, Param_Cell, Param_CellByRef);
	// POST forwards for conditions
	gf_FreezePost =	new GlobalForward("SU_OnFreeze_Post",		ET_Ignore, Param_Cell, Param_Float, Param_Cell);
	gf_BleedPost =	new GlobalForward("SU_OnBleed_Post",		ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	gf_ToxicPost =	new GlobalForward("SU_OnToxic_Post",		ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	gf_ExhaustPost = new GlobalForward("SU_OnExhaust_Post",		ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	// Forwards when survivor conditions end (can't be modified)
	gf_FreezeEnd =	new GlobalForward("SU_OnFreezeEnd",			ET_Ignore, Param_Cell);
	gf_BleedEnd	=	new GlobalForward("SU_OnBleedEnd",			ET_Ignore, Param_Cell);
	gf_ToxicEnd =	new GlobalForward("SU_OnToxicEnd",			ET_Ignore, Param_Cell);
	gf_ExhaustEnd =	new GlobalForward("SU_OnExhaustEnd",		ET_Ignore, Param_Cell);
	// Forwards for reviving/backpack actions
	gf_Defib =		new GlobalForward("SU_OnDefib",				ET_Event, Param_Cell, Param_Cell, Param_FloatByRef);
	gf_Revive =		new GlobalForward("SU_OnRevive",			ET_Event, Param_Cell, Param_Cell, Param_FloatByRef);
	gf_Heal =		new GlobalForward("SU_OnHeal",				ET_Event, Param_Cell, Param_Cell, Param_FloatByRef);
	// POST forwards for healing/reviving
	gf_DefibPost =	new GlobalForward("SU_OnDefib_Post",		ET_Ignore, Param_Cell, Param_Cell, Param_Float);
	gf_RevivePost =	new GlobalForward("SU_OnRevive_Post",		ET_Ignore, Param_Cell, Param_Cell, Param_Float);
	gf_HealPost =	new GlobalForward("SU_OnHeal_Post",			ET_Ignore, Param_Cell, Param_Cell, Param_Float);
	RegPluginLibrary("survivorutilities");

	return APLRes_Success;
}

public void OnPluginStart()
{	
	CreateConVar("survivor_utilities_version", PLUGIN_VERSION,	"L4D Survivor Utilities Version", 	FCVAR_NOTIFY|FCVAR_DONTRECORD);
	// Speed ConVars , the default values are the game original values
	g_hRunSpeed =			CreateConVar("sm_su_run_speed",				"220.0", 	"Default survivor run speed.",							FCVAR_NOTIFY, true, 110.0);	// When survivor should be running, dont go below 110.0 or players will feel weird movements
	g_hWaterSpeed =			CreateConVar("sm_su_water_speed",			"115.0",	"Survivor speed while in water.",						FCVAR_NOTIFY, true, 80.0);
	g_hLimpSpeed =			CreateConVar("sm_su_limp_speed",			"150.0",	"Survivor limping speed (HP below 40).",				FCVAR_NOTIFY, true, 65.0);	// Under 65 player speed is not linear and falls rapidly to 0 around 50 speed value
	g_hCritSpeed =			CreateConVar("sm_su_critical_speed",		"85.0",		"Survivor speed when 1 HP afer one incapacitation.",	FCVAR_NOTIFY, true, 65.0);
	g_hWalkSpeed =			CreateConVar("sm_su_walk_speed",			"85.0",		"Survivor walk speed.",									FCVAR_NOTIFY, true, 65.0);
	g_hCrouchSpeed =		CreateConVar("sm_su_crouch_speed",			"75.0",		"Survivor speed while crouching.",						FCVAR_NOTIFY, true, 65.0);
	g_hExhaustSpeed =		CreateConVar("sm_su_exhaust_speed",			"115.0",	"Survivor speed when exhausted by plugin.",				FCVAR_NOTIFY, true, 110.0);
	g_hScopeSpeed =			CreateConVar("sm_su_scope_speed",			"85.0",		"Survivor speed while looking through sniper scope.",	FCVAR_NOTIFY, true, 65.0);
	g_hAdrenRunSpeed =		CreateConVar("sm_su_adren_speed",			"260.0",	"Survivor run speed under adrenaline effect.",			FCVAR_NOTIFY, true, 110.0);
	// Intoxicate ConVars
	g_hToxicDmg =			CreateConVar("sm_su_toxic_damage",			"1.0",		"Amount of toxic damage dealed to survivors.",			FCVAR_NOTIFY, true, 1.0);
	g_hToxicDelay =			CreateConVar("sm_su_toxic_delay",			"5.0",		"Delay in seconds between toxic damages.",				FCVAR_NOTIFY, true, 0.1);
	g_hToxicOverride =		CreateConVar("sm_su_toxic_override",		"2",		"What should plugin do with toxic amount if a player is intoxicated again?\n0 = Don't override amount.\n1 = Override if new amount are higher. \n2 = Add new amount to the remaining amount.\n3 = Allways override amount.", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	// Bleeding ConVars
	g_hBleedDmg = 			CreateConVar("sm_su_bleed_damage",			"1.0",		"Amount of bleeding damage dealed to survivors.",		FCVAR_NOTIFY, true, 1.0);
	g_hBleedDelay =			CreateConVar("sm_su_bleed_delay",			"5.0",		"Delay in seconds between bleed damages.",				FCVAR_NOTIFY, true, 0.1);
	g_hBleedOverride =		CreateConVar("sm_su_bleed_override",		"2",		"What should plugin do with bleed amount if a player is bleeding again?\n0 = Don't override amount.\n1 = Override if new amount is higher. \n2 = Add new amount to the original one.\n3 = Allways override amount.", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	// Freeze ConVars
	g_hFreezeOverride =		CreateConVar("sm_su_freeze_override",		"2",		"What should plugin do with freeze time if a player is frozen again?\n0 = Don't override original freeze time.\n1 = Override original freeze time if new time is higher.\n2 = Add the new freeze time to the original time.\n3 = Override original time.", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	//Exhaust ConVars
	g_hExhaustOverride =	CreateConVar("sm_su_exhaust_override",		"2",		"What should plugin do with exhaust amount if a player is exhausted again=\n0 = Don't override amount.\n1 = Override if new amount is higher.\n2 = Add new amount to the original one.\n3 Allways override amount.", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	g_hRecoilScale =		CreateConVar("sm_su_exhaust_recoil_scale",	"1.0",		"Scale the default exhaust recoil by this amount.", FCVAR_NOTIFY, true, 0.0, true, 5.0);
	
	// Get server ConVars
	g_hTempDecay =	 	FindConVar("pain_pills_decay_rate");
	g_hLimpHealth =		FindConVar("survivor_limp_health");
	g_hHealDuration = 	FindConVar("first_aid_kit_use_duration");
	g_hReviveDuration =	FindConVar("survivor_revive_duration");
	g_hMaxHealth =		FindConVar("first_aid_kit_max_heal");
	if( g_bL4D2 )
	{
		g_hDefibDuration =	FindConVar("defibrillator_use_duration");
		g_hAdrenSpeed =		FindConVar("adrenaline_revive_speedup");
	}

	g_hRunSpeed.AddChangeHook(CVarChange_Speeds);
	g_hWaterSpeed.AddChangeHook(CVarChange_Speeds);
	g_hLimpSpeed.AddChangeHook(CVarChange_Speeds);
	g_hCritSpeed.AddChangeHook(CVarChange_Speeds);
	g_hWalkSpeed.AddChangeHook(CVarChange_Speeds);
	g_hCrouchSpeed.AddChangeHook(CVarChange_Speeds);
	g_hScopeSpeed.AddChangeHook(CVarChange_Speeds);
	g_hAdrenRunSpeed.AddChangeHook(CVarChange_Speeds);
	
	g_hTempDecay.AddChangeHook(CVarChange_Game);
	g_hLimpHealth.AddChangeHook(CVarChange_Game);
		
	HookEvent("pills_used",				Event_Pills_Used);
	HookEvent("heal_success",			Event_Heal);
	HookEvent("player_death",			Event_Player_Death);
	HookEvent("round_start",			Event_Round_Start, EventHookMode_PostNoCopy);
	HookEvent("weapon_fire",			Event_Weapon_Fire);
	HookEvent("player_bot_replace",		Event_Player_Replaced); // Bot replaced a player
	HookEvent("bot_player_replace",		Event_Bot_Replaced);	// Player gets back the control of the character
	if( g_bL4D2 )
		HookEvent("adrenaline_used",		Event_Adren_Used);
	
	AutoExecConfig(true, "l4d_survivor_utilities");
	
	// Detours
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	if( g_bL4D2 )
	{
		CreateDetour(hGameData, MedStartAct,			"CFirstAidKit::ShouldStartAction",	false);
		CreateDetour(hGameData, MedStartAct_Post,		"CFirstAidKit::ShouldStartAction",	true);
		CreateDetour(hGameData, DefStartAct,			"CItemDefibrillator::ShouldStartAction", false);
	}
	else
	{
		CreateDetour(hGameData, StartHealing,			"CTerrorPlayer::StartHealing",		false);
		CreateDetour(hGameData, StartHealing_Post,		"CTerrorPlayer::StartHealing",		true);
	}
	CreateDetour(hGameData, OnRevive,					"CTerrorPlayer::StartReviving",		false);
	CreateDetour(hGameData, OnRevive_Post,				"CTerrorPlayer::StartReviving",		true);

	delete hGameData;
}

public void OnMapStart()
{
	SoundPrecache();
	for( int i = 1; i <= MaxClients; i++ )
		SetClientData(i, true);
}

public void OnClientPutInServer(int client)
{
	SetClientData(client, true);
}

// Maybe this is redundant but to prevent conditions or speed transfer
public void OnClientDisconnect(int client)
{
	SetClientData(client, true);
}

public void OnConfigsExecuted()
{
	SetSpeeds();
	GameConVars();
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if( !IsAliveSurvivor(client) ) return Plugin_Continue;
	
	if( g_bIsFrozen[client] == true && buttons & IN_RELOAD )
	{
		buttons &= ~IN_RELOAD;
		return Plugin_Changed;
	}
	if( g_iExhaustToken[client] > 0 && buttons & IN_ATTACK2 )
		SetEntProp(client, Prop_Send, "m_iShovePenalty", 8);	// 8 seems to be the max fatigue that survivors can have
	
	return Plugin_Continue;
}

public void OnMapEnd()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		delete g_hToxicTimer[i];
		delete g_hBleedTimer[i];
		delete g_hFreezeTimer[i];
		delete g_hExhaustTimer[i];
		delete g_hRecoilTimer[i];
	}
}

//==========================================================================================
//									ConVar Logic
//==========================================================================================

public void CVarChange_Speeds(Handle convar, const char[] oldValue, const char[] newValue)
{
	SetSpeeds();
}

public void CVarChange_Game(Handle convar, const char[] oldValue, const char[] newValue)
{
	GameConVars();
}

void SetSpeeds()	// I need to change this to prevent override custom player speeds when convar changes
{	
	for( int i = 1; i <= MaxClients; i++ )
	{
		ScaleSpeed(g_fRunSpeed[i], g_hRunSpeed.FloatValue, g_fRunSpeed[0]);
		ScaleSpeed(g_fWaterSpeed[i], g_hWaterSpeed.FloatValue, g_fWaterSpeed[0]);
		ScaleSpeed(g_fLimpSpeed[i], g_hLimpSpeed.FloatValue, g_fLimpSpeed[0]);
		ScaleSpeed(g_fCritSpeed[i], g_hCritSpeed.FloatValue, g_fCritSpeed[0]);
		ScaleSpeed(g_fWalkSpeed[i], g_hWalkSpeed.FloatValue, g_fWalkSpeed[0]);
		ScaleSpeed(g_fCrouchSpeed[i], g_hCrouchSpeed.FloatValue, g_fCrouchSpeed[0]);
		ScaleSpeed(g_fScopeSpeed[i], g_hScopeSpeed.FloatValue, g_fScopeSpeed[0]);
		ScaleSpeed(g_fAdrenRunSpeed[i], g_hAdrenRunSpeed.FloatValue, g_fAdrenRunSpeed[0]);
	}
	g_fRunSpeed[0] = g_hRunSpeed.FloatValue;
	g_fWaterSpeed[0] = g_hWaterSpeed.FloatValue;
	g_fLimpSpeed[0] = g_hLimpSpeed.FloatValue;
	g_fCritSpeed[0] = g_hCritSpeed.FloatValue;
	g_fWalkSpeed[0] = g_hWalkSpeed.FloatValue;
	g_fCrouchSpeed[0] = g_hCrouchSpeed.FloatValue;
	g_fScopeSpeed[0] = g_hScopeSpeed.FloatValue;
	g_fAdrenRunSpeed[0] = g_hAdrenRunSpeed.FloatValue;
}

void ScaleSpeed(float& currSpeed, const float newSpeed, const float oldSpeed)
{
	// Array not loaded yet, plugin start
	if( oldSpeed == 0 )
		currSpeed = newSpeed;
		
	float cmp = currSpeed - newSpeed;
	if( cmp < 0.1 && cmp > -0.1 ) // Because floating point numbers have a small error, 
	{
		currSpeed = newSpeed;
		return;
	}
	currSpeed = currSpeed * newSpeed / oldSpeed;
}

void GameConVars()
{
	g_fTempDecay = g_hTempDecay.FloatValue;
	g_fLimpHealth = g_hLimpHealth.FloatValue;
	g_iMaxHealth = g_hMaxHealth.IntValue;
}

//==========================================================================================
//									Events
//==========================================================================================

void Event_Pills_Used(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( g_iToxicToken[client] > 0) SU_RemoveToxic(client);
}

void Event_Adren_Used(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( g_iExhaustToken[client] > 0 ) SU_RemoveExhaust(client);
	if( g_iToxicToken[client] > 0) SU_RemoveToxic(client);
}

void Event_Heal(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if( g_iBleedToken[client] > 0) SU_RemoveBleed(client);
}

void Event_Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	// !client because Common Infected trigger this event, wtf!
	if( !client || !IsValidClient(client) ) return;
		
	if( g_bIsFrozen[client] == true )	// In case client is frozen disable the weapon switch hook
	{
		SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
		BlockPlayerAttacks(client, false);
	}
		
	SetClientData(client, false); // Removes all effects without calling API events, keep player speeds
}

void Event_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) )
			SetClientData(i, true); // Reset ALL data, even speeds on round start
	}
}

void Event_Weapon_Fire(Event event, const char[] name, bool dontBroadcast)
{
	if( g_hRecoilScale.FloatValue == 0.0 ) return; // Ignore everything if recoil is disabled 
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( IsAliveSurvivor(client) && g_iExhaustToken[client] > 0 )
	{
		char sBuffer[32];
		event.GetString("weapon", sBuffer, sizeof(sBuffer));
		for( int i = 0; i < sizeof(g_sWeaponRecoils); i ++ )
		{
			if( StrContains(sBuffer, g_sWeaponRecoils[i]) != -1 )
			{
				g_fRecoilStack[client] -= g_fWeaponRecoils[i] * g_hRecoilScale.FloatValue; // Increase the stacked recoil
				break; // Stop loop because string is read in a way it could find another match with some weapon, so first match is always the desired weapon	
			}
		}
		if( g_fRecoilStack[client] == 0 )
			return;	// Because the loop didn't found a weapon, so is not listed, not a weapon and we don't need to do anything more
			
		if( g_fRecoilStack[client] < -50.0 ) g_fRecoilStack[client] = -50.0; // Clamp recoil to -50 value to prevent insane recoils
		
		// Call the push one frame after the shot, if we push player in this function we will decrease the accuracy of all shots
		RequestFrame(WeaponFire_Frame, client);
		if( g_hRecoilTimer[client] == null )
			g_hRecoilTimer[client] = CreateTimer(0.5, Recoil_Timer, client);
	}
	return;
}

// Player goes idle, if he has some condition stored, stop timers, preserve conditions (conditions will not be applied to the replacer bot)
void Event_Player_Replaced(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("player"));
	if( GetClientTeam(client) == 3 ) return;	// This should prevent throwing errors when a player moves to infected team
	// Delete timers but preserve status
	if( SU_IsFrozen(client) )
	{
		g_fSaveFreeze[client] = g_fFreezeTime[client] - GetGameTime();
		delete g_hFreezeTimer[client];
	}
	if( SU_IsBleeding(client) )		delete g_hBleedTimer[client]; 
	if( SU_IsToxic(client) )		delete g_hToxicTimer[client];
	if( SU_IsExhausted(client) )	delete g_hExhaustTimer[client];
}

// Survivor tries to get back the control of the character, return paused conditions
void Event_Bot_Replaced(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("player"));
	if( !IsPlayerAlive(client) || GetClientTeam(client) != 2 ) return; // Prevent errors on infected team
	
	if( SU_IsFrozen(client) ) 
	{
		delete g_hFreezeTimer[client]; // This may not be required, but its safer to delete the timer first just in case
		g_hFreezeTimer[client] = CreateTimer(g_fSaveFreeze[client], Freeze_Timer, client);
	}
	if( SU_IsBleeding(client) )
	{
		delete g_hBleedTimer[client];
		g_hBleedTimer[client] = CreateTimer(g_hBleedDelay.FloatValue, BleedDmg_Timer, client);
	}
	if( SU_IsToxic(client) )
	{
		delete g_hToxicTimer[client];
		g_hToxicTimer[client] = CreateTimer(g_hToxicDelay.FloatValue, ToxicDmg_Timer, client);
	}
	if( SU_IsExhausted(client) )
	{
		delete g_hExhaustTimer[client];
		g_hExhaustTimer[client] = CreateTimer(0.2, Exhaust_Timer, client);
	}
	
	g_fSaveFreeze[client] = 0.0;
}

//==========================================================================================
//										Detours
//==========================================================================================
void CreateDetour(Handle gameData, DHookCallback CallBack, const char[] sName, const bool post)
{
	Handle hDetour = DHookCreateFromConf(gameData, sName);
	if( !hDetour )
		SetFailState("Failed to find \"%s\" signature.", sName);
		
	if( !DHookEnableDetour(hDetour, post, CallBack) )
		SetFailState("Failed to detour \"%s\".", sName);
		
	delete hDetour;
}

MRESReturn OnRevive(int pThis, Handle hReturn, Handle hParams)
{
	// Player reviving <- pTHis
	int client = DHookGetParam(hParams, 1); // Player revived
	float duration;
	if( g_bL4D2 )
		duration = GetEntProp(client, Prop_Send, "m_bAdrenalineActive") == 0 ? g_hHealDuration.FloatValue : g_hHealDuration.FloatValue * g_hAdrenSpeed.FloatValue;

	else duration = g_hHealDuration.FloatValue;
	Action aResult;
	
	Call_StartForward(gf_Revive);
	Call_PushCell(pThis);
	Call_PushCell(client);
	Call_PushFloatRef(duration);
	Call_Finish(aResult);
	
	if( aResult == Plugin_Handled )
	{
		DHookSetReturn(hReturn, 0);
		return MRES_Supercede;
	}
	if( aResult == Plugin_Changed )
	{
		g_fReviveDuration = g_hReviveDuration.FloatValue;
		g_hReviveDuration.SetFloat(duration, true, false);
		g_bReviveChanged = true;
	}

	return MRES_Ignored;
}

MRESReturn OnRevive_Post(int pThis, Handle hReturn, Handle hParams)
{
	if( g_bReviveChanged )
	{		
		Call_StartForward(gf_RevivePost);
		Call_PushCell(pThis);	// User
		Call_PushCell(DHookGetParam(hParams, 1));	// Target
		Call_PushFloat(g_hReviveDuration.FloatValue);
		Call_Finish();
		
		g_hReviveDuration.SetFloat(g_fReviveDuration, true, false);
		g_fReviveDuration = -1.0;
	}
	
	return MRES_Ignored;
}

// pThis -> client
MRESReturn StartHealing(int pThis, Handle hReturn, Handle hParams)
{
	int target = DHookGetParam(hParams, 1);
	float duration = g_hHealDuration.FloatValue;
	Action aResult;
	
	Call_StartForward(gf_Heal);
	Call_PushCell(pThis);
	Call_PushCell(target);
	Call_PushFloatRef(duration);
	Call_Finish(aResult);
	
	if( aResult == Plugin_Handled ) 
	{
		DHookSetReturn(hReturn, 0);
		return MRES_Supercede;
	}	
	if( aResult == Plugin_Changed )
	{
		g_fHealDuration = g_hHealDuration.FloatValue;
		g_hHealDuration.SetFloat(duration, true, false);
		g_bHealChanged = true;
	}
	
	return MRES_Ignored;
}

MRESReturn StartHealing_Post(int pThis, Handle hReturn, Handle hParams)
{
	if( g_bHealChanged )
	{
		Call_StartForward(gf_HealPost);
		Call_PushCell(pThis);
		Call_PushCell(DHookGetParam(hParams, 1));
		Call_PushFloat(g_hHealDuration.FloatValue);
		Call_Finish();
	
		g_hHealDuration.SetFloat(g_fHealDuration, true, false);
		g_bHealChanged = false;
	}
	
	return MRES_Ignored;
}

MRESReturn MedStartAct(Handle hReturn, Handle hParams)
{
	int client = DHookGetParam(hParams, 2);
	int target = DHookGetParam(hParams, 3);
	if( target > MaxClients || GetClientTeam(target) != 2 )	// Because shoving common infected or specials triggers this function
		return MRES_Ignored;

	int maxHP = GetEntProp(client, Prop_Send, "m_iMaxHealth");
	int health = GetClientHealth(target) + 1;	// Because survivors can't heal if their HP is 1 point below limits
	
	if( health >= maxHP || health >= g_iMaxHealth )
		return MRES_Ignored;
	
	float duration = GetEntProp(client, Prop_Send, "m_bAdrenalineActive") == 0 ? g_hHealDuration.FloatValue : g_hHealDuration.FloatValue * g_hAdrenSpeed.FloatValue;
	Action aResult;
	
	Call_StartForward(gf_Heal);
	Call_PushCell(client);
	Call_PushCell(target);
	Call_PushFloatRef(duration);
	Call_Finish(aResult);
	
	if( aResult == Plugin_Handled )
	{
		DHookSetReturn(hReturn, 0);
		return MRES_Supercede;
	}
	if( aResult == Plugin_Changed )
	{
		g_fHealDuration = g_hHealDuration.FloatValue;
		g_hHealDuration.SetFloat(duration, true, false);
		g_bHealChanged = true;
	}
	
	return MRES_Ignored;
}

MRESReturn MedStartAct_Post(Handle hReturn, Handle hParams)
{
	if( g_bHealChanged )
	{
		Call_StartForward(gf_HealPost);
		Call_PushCell(DHookGetParam(hParams, 2));	// Client
		Call_PushCell(DHookGetParam(hParams, 3));	// Target
		Call_PushFloat(g_hHealDuration.FloatValue);
		Call_Finish();
		
		g_hHealDuration.SetFloat(g_fHealDuration, true, false);
		g_bHealChanged = false;
	}
	return MRES_Ignored;
}

MRESReturn DefStartAct(Handle hReturn, Handle hParams)
{
	int client = DHookGetParam(hParams, 2);
	int model = DHookGetParam(hParams, 3);
	float duration = GetEntProp(client, Prop_Send, "m_bAdrenalineActive") == 0 ? g_hDefibDuration.FloatValue : g_hDefibDuration.FloatValue * g_hAdrenSpeed.FloatValue;
	Action aResult;
	
	Call_StartForward(gf_Defib);
	Call_PushCell(client);
	Call_PushCell(model);
	Call_PushFloatRef(duration);
	Call_Finish(aResult);
		
	if( aResult == Plugin_Handled )
	{
		DHookSetReturn(hReturn, 0);
		return MRES_Supercede;
	}
	if( aResult == Plugin_Changed )
	{
		g_fDefibDuration = g_hDefibDuration.FloatValue;
		g_hDefibDuration.SetFloat(duration, true, false);
		
		DataPack hPack = new DataPack();
		RequestFrame(Defib_Frame, hPack);
		hPack.WriteCell(GetClientSerial(client));
		hPack.WriteCell(EntIndexToEntRef(model));
	}
	
	return MRES_Ignored;
}

/*
 * DefStartAct_Post doesn't work, it sets the ConVar to its original value too soon
 * and the time override has no effect, waiting a frame instead
 */
void Defib_Frame(DataPack hPack)
{
	hPack.Reset();
	int client = GetClientFromSerial(hPack.ReadCell());
	int model = EntRefToEntIndex(hPack.ReadCell());
	delete hPack;
	
	if( client && model != -1 )
	{
		Call_StartForward(gf_DefibPost);
		Call_PushCell(client);
		Call_PushCell(model);
		Call_PushFloat(g_hDefibDuration.FloatValue);
		Call_Finish();
	}
	g_hDefibDuration.SetFloat(g_fDefibDuration, true, false);
}

//==========================================================================================
//									DHooks & SDKHooks
//==========================================================================================

public Action L4D_OnGetRunTopSpeed(int client, float &retVal)
{
	if( !IsAliveSurvivor(client) ) return Plugin_Continue; // Ignore infected and dead survivors
	
	int iStatus = GetSurvivorStatus(client);	
	float fBaseSpeed = GetPlayerSpeed(client, iStatus, g_fRunSpeed[client], true);
	
	if( fBaseSpeed < 0.0 ) return Plugin_Continue; // Ignore negative speeds
	
	if( g_iExhaustToken[client] > 0 && g_fExhaustSpeed[client] < fBaseSpeed && iStatus != STATUS_ADRENALINE ) // In case survivor is exhausted and exhaust speed is lower than current speed...
		fBaseSpeed = g_fExhaustSpeed[client];
	
	
	retVal = fBaseSpeed;
	return Plugin_Handled;
}

public Action L4D_OnGetWalkTopSpeed(int client, float &retVal)
{
	if( !IsAliveSurvivor(client) ) return Plugin_Continue;
		
	float fBaseSpeed = GetPlayerSpeed(client, GetSurvivorStatus(client), g_fWalkSpeed[client]);
	if( fBaseSpeed < 0.0 ) return Plugin_Continue;
	
	if( g_iExhaustToken[client] > 0 && g_fExhaustSpeed[client] < fBaseSpeed )
		fBaseSpeed = g_fExhaustSpeed[client];

	retVal = fBaseSpeed;
	return Plugin_Handled;
}	

public Action L4D_OnGetCrouchTopSpeed(int client, float &retVal)
{
	if( !IsAliveSurvivor(client) ) return Plugin_Continue;
	
	float fBaseSpeed = GetPlayerSpeed(client, GetSurvivorStatus(client), g_fCrouchSpeed[client]);
	if( fBaseSpeed < 0.0 ) return Plugin_Continue;
	
	if( g_iExhaustToken[client] > 0 && g_fExhaustSpeed[client] < fBaseSpeed )
		fBaseSpeed = g_fExhaustSpeed[client];

	retVal = fBaseSpeed;
	return Plugin_Handled;
}

// If an exhaust postprocess is active, display only to exhausted players
Action PostProcess_STransmit(int entity, int client)
{
	// Kill entity on SetTransmit and wait a frame to respawn if needed (this prevents bugs)
	if( g_iEntMustDie )
	{
		g_iEntMustDie = false;
		KillPostProcess();
		RequestFrame(Exhaust_PostCheck);
		return Plugin_Continue;
	}
	if( GetEdictFlags(entity) & FL_EDICT_ALWAYS )
		SetEdictFlags(entity, GetEdictFlags(entity) &~ FL_EDICT_ALWAYS);
		
	if( !IsAliveSurvivor(client) )
		return Plugin_Handled;	
	
	if( g_iExhaustToken[client] < 1 )
		return Plugin_Handled;

	return Plugin_Continue;
}

// Hook weapon switch to block attack and shoot correctly
Action OnWeaponSwitch(int client, int weapon)
{
	if( !IsValidEntity(weapon) )
		return Plugin_Continue;
		
	BlockPlayerAttacks(client, true);
	return Plugin_Continue;
}

//==========================================================================================
//									Functions
//==========================================================================================

int GetSurvivorStatus(int client)
{
	if( GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1 ) return STATUS_INCAP;

	if( g_bL4D2 && GetEntProp(client, Prop_Send, "m_bAdrenalineActive") != 0 ) return STATUS_ADRENALINE;
	float fAbsHealth = GetAbsHealth(client);
	if( fAbsHealth >= 1.0 && fAbsHealth < g_fLimpHealth )
	{
		if( fAbsHealth == 1.0 && GetEntProp(client, Prop_Send, "m_currentReviveCount") > 0 ) return STATUS_CRITICAL;
			
		else return STATUS_LIMP;
	}
	else return STATUS_NORMAL;
}

// Function from drug effect, modified
void ScreenColor(int client, int color[4], int flags)
{
	if( !client || IsFakeClient(client) ) return;
	UserMsg FadeUserMsgId = GetUserMessageId("Fade");
	int clients[2];
	clients[0] = client;

	int duration = 196;
	int holdtime = 512;
//	int flags = (0x0002 | 0x0008);

	Handle message = StartMessageEx(FadeUserMsgId, clients, 1);
	if( GetUserMessageType() == UM_Protobuf )
	{
		Protobuf pb = UserMessageToProtobuf(message);
		pb.SetInt("duration", duration);
		pb.SetInt("hold_time", holdtime);
		pb.SetInt("flags", flags);
		pb.SetColor("clr", color);
	}
	else 
	{
		BfWrite bf = UserMessageToBfWrite(message);
		bf.WriteShort(duration);
		bf.WriteShort(holdtime);
		bf.WriteShort(flags);
		bf.WriteByte(color[0]);
		bf.WriteByte(color[1]);
		bf.WriteByte(color[2]);
		bf.WriteByte(color[3]);
	}

	EndMessage();
}

// Compare speeds and get the lowest speed in the player situation
float GetPlayerSpeed(int client, int playerStatus, float fSpeed, bool isRunning = false)
{
	if( GetEntityFlags(client) & FL_INWATER ) // This is the only way to check properly if a survivor is on water
	{
		if( fSpeed > g_fWaterSpeed[client] )
			fSpeed = g_fWaterSpeed[client];
	}
	
	// Attempt to nerf survivor moving speed if scoping, this is like survivor is walking and thats why blocks adrenaline powerup
	if( GetEntPropEnt(client, Prop_Send, "m_hZoomOwner") != -1 )
	{
		fSpeed = fSpeed < g_fScopeSpeed[client] ? fSpeed : g_fScopeSpeed[client];
		isRunning = false;
	}
	// Default game behaviour, when survivor injects adren, hes able to rush in any situation
	else if( playerStatus == STATUS_ADRENALINE && isRunning )
		return g_fAdrenRunSpeed[client];
	
	switch( playerStatus )
	{
		case STATUS_INCAP: return -1.0; // If this function returns a negative value, the DHook will do nothing, which is logical if survivor is incapped
		case STATUS_NORMAL: return fSpeed;
		case STATUS_LIMP: return fSpeed < g_fLimpSpeed[client] ? fSpeed : g_fLimpSpeed[client];
		case STATUS_CRITICAL: return fSpeed < g_fCritSpeed[client] ? fSpeed : g_fCritSpeed[client];
	}
	
	return -1.0;
}

bool IsValidAliveSurvivor(int client)
{
	if( !IsValidClient(client) ) return false;
	return IsAliveSurvivor(client);
}

bool IsAliveSurvivor(int client)
{
	if( GetClientTeam(client) != 2 ) return false;
	return IsPlayerAlive(client);
}

bool IsValidClient(int client)
{
	if( client < 1 || client > MaxClients ) return false;
	return IsClientInGame(client);
}

// Resets all the client related variables on death/round restart/map change
void SetClientData(int client, bool fullReset) // FullReset is only called when player connects or map changes (prevents speed heritage from other player)
{
	// Delete timer handles
	delete g_hToxicTimer[client];
	delete g_hBleedTimer[client];
	delete g_hFreezeTimer[client];
	
	// Set client related variables to its default value
	g_bIsFrozen[client] = false;
	g_iExhaustToken[client] = 0;
	g_iBleedToken[client] = 0;
	g_iToxicToken[client] = 0;
	g_fSaveFreeze[client] = 0.0;
	
	// Set client speeds to default (only after join/disconnect, round restart or map change)
	if( fullReset )
	{
		g_fRunSpeed[client] = g_hRunSpeed.FloatValue;
		g_fCrouchSpeed[client] = g_hCrouchSpeed.FloatValue;
		g_fWalkSpeed[client] = g_hWalkSpeed.FloatValue;
		g_fCritSpeed[client] = g_hCritSpeed.FloatValue;
		g_fWaterSpeed[client] = g_hWaterSpeed.FloatValue;
		g_fExhaustSpeed[client] = g_hExhaustSpeed.FloatValue;
	}
	// Disable all screen effects
	else ScreenColor(client, { 0, 0, 0, 0 }, (0x0001 | 0x0010));
}

void SoundPrecache()
{
	PrecacheSound(SND_BLEED1, false);
	PrecacheSound(SND_BLEED2, false);
	PrecacheSound(SND_BLEED3, false);
	PrecacheSound(SND_CHOKE, false);
	PrecacheSound(SND_FREEZE, false);
}

void KillPostProcess()
{
	if( IsValidEntRef(g_iPostProcess) )
		AcceptEntityInput(g_iPostProcess, "Kill");

	g_iPostProcess = 0;

	if( IsValidEntRef(g_iFogVolume) )
		AcceptEntityInput(g_iFogVolume, "Kill");

	g_iFogVolume = 0;
}

// Function by Silvers
float GetAbsHealth(int client)
{
	float fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * g_fTempDecay;
	fHealth = fHealth < 0.0 ? 0.0 : fHealth;
	return float(GetClientHealth(client)) + fHealth;
}

void BlockPlayerAttacks(int client, const bool isBlock)
{
	float fTime;
	int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	fTime = isBlock ? 9999.0 : 0.25;

	SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", fTime);
	SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", fTime);	
}

//==========================================================================================
//									Timers & Request Frames
//==========================================================================================

// Those timers will call themselves instead of using TIMER_REPEAT flag. This will allow to change damage tick speed if server ConVar changes
Action ToxicDmg_Timer(Handle timer, int client)
{
	g_hToxicTimer[client] = null;
	if( !IsValidAliveSurvivor(client) ) // In case survivor disconnects or changes teams, remove the effect
	{
		g_iToxicToken[client] = 0;
		return Plugin_Continue;
	}
	
	g_iToxicToken[client]--;
	ScreenColor(client, { 255, 127, 0, 130 }, 0x0001);
	SDKHooks_TakeDamage(client, client, client, g_hToxicDmg.FloatValue, 0);
	EmitSoundToClient(client, SND_CHOKE);

	if( g_iToxicToken[client] > 0 )
		g_hToxicTimer[client] = CreateTimer(g_hToxicDelay.FloatValue, ToxicDmg_Timer, client);
	
	else SU_RemoveToxic(client);
	
	return Plugin_Continue;
}

Action BleedDmg_Timer(Handle timer, int client)
{
	g_hBleedTimer[client] = null;
	if( !IsValidAliveSurvivor(client) )
	{
		g_iBleedToken[client] = 0;
		return Plugin_Continue;
	}
	
	g_iBleedToken[client]--;
	ScreenColor(client, { 255, 22, 0, 140 }, 0x0001);
	SDKHooks_TakeDamage(client, client, client, g_hBleedDmg.FloatValue, 0);
	
	switch( GetRandomInt(1,3) )
	{
		case 1: EmitSoundToClient(client, SND_BLEED1);
		case 2: EmitSoundToClient(client, SND_BLEED2);
		case 3: EmitSoundToClient(client, SND_BLEED3);
	}
	 // I don't like to use TIMER_REPEAT, it causes bugs, I prefer to do this manually to have more control and less errors
	if( g_iBleedToken[client] > 0)
		g_hBleedTimer[client] = CreateTimer(g_hBleedDelay.FloatValue, BleedDmg_Timer, client);
	
	else
	{
		Call_StartForward(gf_BleedEnd);
		Call_PushCell(client);
		Call_Finish();
	}
	return Plugin_Continue;
}

Action Recoil_Timer(Handle timer, int client)
{
	g_hRecoilTimer[client] = null;
	if( g_fRecoilStack[client] <= -8.0 )
	{
		g_fRecoilStack[client] += 8.0;
		g_hRecoilTimer[client] = CreateTimer(0.5, Recoil_Timer, client);
		return Plugin_Continue;
	}
	g_fRecoilStack[client] = 0.0;
	return Plugin_Continue;
}

// Removes exhaust tokens over time (removes faster if the player isn't moving)
Action Exhaust_Timer(Handle timer, int client)
{
	g_hExhaustTimer[client] = null;
	if( !IsValidAliveSurvivor(client) )
	{
		g_iExhaustToken[client] = 0;
		g_iEntMustDie = true;
		return Plugin_Continue;
	}

	if( g_iExhaustToken[client] < 1 )
	{
		SU_RemoveExhaust(client);
		return Plugin_Continue;
	}

	int iButton = GetEntProp(client, Prop_Data, "m_nButtons");
	if( iButton & IN_FORWARD || iButton & IN_LEFT || iButton & IN_RIGHT || iButton & IN_BACK )
		g_iExhaustToken[client]--;
		
	else g_iExhaustToken[client] -= 2;
	
	g_hExhaustTimer[client] = CreateTimer(0.2, Exhaust_Timer, client);
	return Plugin_Continue;
}

Action Freeze_Timer(Handle timer, int client)
{
	g_hFreezeTimer[client] = null;
	if( !IsValidAliveSurvivor(client) ) return Plugin_Continue;

	SU_RemoveFreeze(client);
	return Plugin_Continue;
}

// Check if another player is on exhaust mode and set again the post process and fog
void Exhaust_PostCheck()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsValidAliveSurvivor(i) && g_iExhaustToken[i] > 0 )
		{
			CreatePostProcess();
			break; // Don't create multiple instances!
		}
	}
}

void WeaponFire_Frame(int client)
{
	float vForce[3];
	vForce[0] = g_fRecoilStack[client], vForce[1] = GetRandomFloat(15.0, -15.0) * g_fRecoilStack[client] / 50.0;
	SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", vForce);
}

// ====================================================================================================
//										POST PROCESS By Silvers
// ====================================================================================================

void CreatePostProcess()
{
//	float vPos[3];
	int client;

	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && IsPlayerAlive(i) )
		{
			client = i;
			break;
		}
	}

	if( client == 0 )
		return;

//	GetClientAbsOrigin(client, vPos);	// No need to teleport entities to players in this scenario

	g_iPostProcess = CreateEntityByName("postprocess_controller");
	if( g_iPostProcess == -1 )
	{
		LogError("Failed to create 'postprocess_controller'");
		return;
	}
	else
	{
		DispatchKeyValue(g_iPostProcess, "targetname", "silver_fx_settings_storm");
		DispatchKeyValue(g_iPostProcess, "vignettestart", "0.15");
		DispatchKeyValue(g_iPostProcess, "vignetteend", "0.8");
		DispatchKeyValue(g_iPostProcess, "vignetteblurstrength", "0.75");
		DispatchKeyValue(g_iPostProcess, "topvignettestrength", "1");
		DispatchKeyValue(g_iPostProcess, "spawnflags", "1");
		DispatchKeyValue(g_iPostProcess, "localcontraststrength", "3.5");
		DispatchKeyValue(g_iPostProcess, "localcontrastedgestrength", "0");
		DispatchKeyValue(g_iPostProcess, "grainstrength", "1");
		DispatchKeyValue(g_iPostProcess, "fadetime", "3");

		DispatchSpawn(g_iPostProcess);
		ActivateEntity(g_iPostProcess);
//		TeleportEntity(g_iPostProcess, vPos, NULL_VECTOR, NULL_VECTOR);	// Don't need to teleport that type of entity
		g_iPostProcess = EntIndexToEntRef(g_iPostProcess);
		SDKHook(g_iPostProcess, SDKHook_SetTransmit, PostProcess_STransmit);
	}

	ToggleFogVolume(false);

	g_iFogVolume = CreateEntityByName("fog_volume");
	if( g_iFogVolume == -1 )
	{
		LogError("Failed to create 'fog_volume'");
	}
	else
	{
		DispatchKeyValue(g_iFogVolume, "PostProcessName", "silver_fx_settings_storm");
		DispatchKeyValue(g_iFogVolume, "spawnflags", "0");

		DispatchSpawn(g_iFogVolume);
		ActivateEntity(g_iFogVolume);

		float vMins[3]; vMins = view_as<float>({ -16384.0, -16384.0, -16384.0 });	// I will use the Hammer limits to make sure no one gets out of the volume
		float vMaxs[3]; vMaxs = view_as<float>({ 16384.0, 16384.0, 16384.0 });
		SetEntPropVector(g_iFogVolume, Prop_Send, "m_vecMins", vMins);
		SetEntPropVector(g_iFogVolume, Prop_Send, "m_vecMaxs", vMaxs);
//		TeleportEntity(g_iFogVolume, vPos, NULL_VECTOR, NULL_VECTOR);	// Don't teleport, let fog_volume stay at center since it covers all the map
	}

	ToggleFogVolume(true);
}

// We have to disable fog_volume when we create ours, so it has priority. Thankfully this works.
// Also saves the enabled/disabled state of fog_volume's we change to prevent visual corruption!
void ToggleFogVolume(bool enable)
{
	if( enable == true )
	{
		if( IsValidEntRef(g_iFogVolume) )
		{
			AcceptEntityInput(g_iFogVolume, "Disable");
			AcceptEntityInput(g_iFogVolume, "Enable");
		}
	}

	int m_bDisabled, entity = -1;

	while( (entity = FindEntityByClassname(entity, "fog_volume")) != INVALID_ENT_REFERENCE )
	{
		if( g_iFogVolume == entity )
		{
			break;
		}

		if( enable == true )
		{
			m_bDisabled = GetEntProp(entity, Prop_Data, "m_bDisabled");
			if( m_bDisabled == 0 )
				AcceptEntityInput(entity, "Enable");
		}
		else if( enable == false )
		{
			m_bDisabled = GetEntProp(entity, Prop_Data, "m_bDisabled");
			SetEntProp(entity, Prop_Data, "m_iHammerID", m_bDisabled);
			AcceptEntityInput(entity, "Disable");
		}
	}
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

//==========================================================================================
//									Natives & Forwards
//==========================================================================================

int Native_AddFreeze(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddFreeze Error: Client %i is invalid.", client); // Call native only to valid clients
	if( !IsPlayerAlive(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddFreeze Error: Client %i is not alive.", client); // Prevent call native on dead players
	if( GetClientTeam(client) != 2 ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddFreeze Error: Client %i is not a survivor.", client); // Call native only on survivors
	
	float fTime = GetNativeCell(2);
	if( fTime < 0.1 ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddFreeze Error: Invalid time value: %f", fTime); 	// Return error if invalid values

	bool active;			// Sends info to POST forwards about if the client was already under the effect when native was called
	float fCurrTime = 0.0;	// This stores the remaining freeze time of survivor if needed, its taken apart to preserve it from changing it via hook
	float fHookTime = fTime;

	// First check if the player is frozen to stop silently the function (avoid unnecesary calls if nothing has to happen!)
	if( g_bIsFrozen[client] == true ) 
	{
		// If ConVar forbids increase or change freeze time while placer is frozen
		if( g_hFreezeOverride.IntValue == 0) return 0;
		// If ConVar allows replace freeze time only if the new time is higher than current freeze time
		else if( g_hFreezeOverride.IntValue == 1 && fTime + GetGameTime() <= g_fFreezeTime[client] ) return 0;
		// If ConVar allows to stack freeze time
		else if( g_hFreezeOverride.IntValue == 2 ) fCurrTime =  g_fFreezeTime[client] - GetGameTime();

		active = true;
	}
	
	// Hook function
	Action aResult = Plugin_Continue;
	Call_StartForward(gf_Freeze);
	Call_PushCell(client);
	Call_PushFloatRef(fHookTime);
	Call_Finish(aResult);
	
	if( aResult == Plugin_Changed && fHookTime >= 0.1) fTime = fHookTime; // If someone puts a bad time through a hook, ignore it, continue.
	
	else if( aResult == Plugin_Handled ) return 0;
		
	if( g_bIsFrozen[client] == false ) // Not frozen client, play sound, change state, freeze player, screen color.
	{
		g_bIsFrozen[client] = true;
		EmitSoundToClient(client, SND_FREEZE);
		ScreenColor(client, { 0, 61, 255, 67 }, (0x0002 | 0x0008 | 0x0010));
		SetEntityMoveType(client, MOVETYPE_NONE);
		SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
		BlockPlayerAttacks(client, true);
	}

	delete g_hFreezeTimer[client];
	g_fFreezeTime[client] = fTime + fCurrTime + GetGameTime();
	g_hFreezeTimer[client] = CreateTimer(fTime + fCurrTime, Freeze_Timer, client);
	
	// Call the Post forward to only read results of the native
	Call_StartForward(gf_FreezePost);
	Call_PushCell(client);
	Call_PushFloat(fTime);
	Call_PushCell(active);
	Call_Finish();
	return 0;
}

int Native_RemoveFreeze(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveFreeze Error: Client %i is invalid.", client);
	if( !IsPlayerAlive(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveFreeze Error: Client %i is not alive.", client);
	if( GetClientTeam(client) != 2 )	ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveFreeze Error: Client %i is not a survivor.", client);
	
	delete g_hFreezeTimer[client];
	
	g_bIsFrozen[client] = false;
	ScreenColor(client, { 0, 61, 255, 67}, (0x0001 | 0x0010));
	SetEntityMoveType(client, MOVETYPE_WALK);
	SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
	BlockPlayerAttacks(client, false);
	
	Call_StartForward(gf_FreezeEnd);
	Call_PushCell(client);
	Call_Finish();
	
	return 0;
}

int Native_AddBleed(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_AddBleed Error: Client %i is invalid.", client);
	if( !IsPlayerAlive(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_AddBleed Error: Client %i not alive.", client);
	if( GetClientTeam(client) != 2 )	ThrowNativeError(SP_ERROR_PARAM, "SU_AddBleed Error: Client %i is not a survivor.", client);
	
	bool active;
	int hits = GetNativeCell(2);
	int currHits = 0;
	if( hits <= 0 ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddBleed error: Invalid amount: %i", hits);
	int hookHits = hits;
	Action aResult = Plugin_Continue;
		
	if( g_iBleedToken[client] > 0 )
	{
		switch( g_hBleedOverride.IntValue )
		{
			case 0: return 0;
			case 1: if( hits < g_iBleedToken[client] ) return 0;
			case 2: currHits = g_iBleedToken[client];
		}
		active = true;
	}
	
	Call_StartForward(gf_Bleed);
	Call_PushCell(client);
	Call_PushCellRef(hookHits);
	Call_Finish(aResult);	

	if( aResult == Plugin_Changed && hookHits > 0 ) hits = hookHits;
	if( aResult == Plugin_Handled ) return 0;

	g_iBleedToken[client] = hits + currHits;
	
	delete g_hBleedTimer[client];
	g_hBleedTimer[client] = CreateTimer(g_hBleedDelay.FloatValue, BleedDmg_Timer, client);

	Call_StartForward(gf_BleedPost);
	Call_PushCell(client);
	Call_PushCell(hits);
	Call_PushCell(active);
	Call_Finish();
	
	return 0;
}

int Native_RemoveBleed(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveBleed Error: Client %i is invalid.", client);
	if( !IsPlayerAlive(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveBleed Error: Client %i si not alive.", client);
	if( GetClientTeam(client) != 2 )	ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveBleed Error: Client %i is not a survivor.", client);
	
	delete g_hBleedTimer[client];
		
	g_iBleedToken[client] = 0;
	
	Call_StartForward(gf_BleedEnd);
	Call_PushCell(client);
	Call_Finish();
	
	return 0;
}

int Native_AddToxic(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_AddToxic Error: Client %i is invalid.", client);
	if( !IsPlayerAlive(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_AddToxic Error: Client %i is not alive.", client);
	if( GetClientTeam(client) != 2 )	ThrowNativeError(SP_ERROR_PARAM, "SU_AddToxic Error: Client %i is not a survivor.", client);
	
	bool active;
	int hits = GetNativeCell(2);
	if( hits <= 0 ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddToxic Error: Invalid amount: %i", hits);
	int currHits = 0;
	int hookHits = hits;
	Action aResult = Plugin_Continue;
			
	if( g_iToxicToken[client] > 0 )	// Player is already intoxicated
	{
		switch( g_hToxicOverride.IntValue )
		{
			case 0: return 0;	// Stop native call
			case 1: if( hits < g_iToxicToken[client] ) return 0;	// Stop native call if new amount is lower than old amount
			case 2: currHits = g_iToxicToken[client]; // Store remaining toxic hits to add them to the native value
		}
		active = true;
	}

	Call_StartForward(gf_Toxic);
	Call_PushCell(client);
	Call_PushCellRef(hookHits);
	Call_Finish(aResult);
	
	if( aResult == Plugin_Changed && hookHits > 0 ) hits = hookHits;
	if( aResult == Plugin_Handled ) return 0;
	
	g_iToxicToken[client] = hits + currHits;
	delete g_hToxicTimer[client];
	g_hToxicTimer[client] = CreateTimer(g_hToxicDelay.FloatValue, ToxicDmg_Timer, client);
	
	Call_StartForward(gf_ToxicPost);
	Call_PushCell(client);
	Call_PushCell(hits);
	Call_PushCell(active);
	Call_Finish();
	
	return 0;
}

int Native_RemoveToxic(Handle plugin, int numParams) 
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveToxic Error: Client %i is invalid.", client);
	if( !IsPlayerAlive(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveToxic Error: Client %i is not alive.", client);
	if( GetClientTeam(client) != 2 )	ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveToxic Error: Client %i is not a survivor.", client);
	
	if( g_hToxicTimer[client] != INVALID_HANDLE ) // Need to check first if timer handle has been closed...
		delete g_hToxicTimer[client];
		
	g_iToxicToken[client] = 0;
	
	Call_StartForward(gf_ToxicEnd);
	Call_PushCell(client);
	Call_Finish();
	return 0;
}

int Native_SetSpeed(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_SetSpeed Error: Client %i is invalid.", client);
	if( GetClientTeam(client) != 2 )	ThrowNativeError(SP_ERROR_PARAM, "SU_SetSpeed Error: Client %i is not a survivor.", client);
	
	int iSpeedType = GetNativeCell(2);
	float fSpeed = GetNativeCell(3);

	switch( iSpeedType )
	{
		case SPEED_RUN:{
			if( fSpeed < 110.0 ) fSpeed = 110.0;
			g_fRunSpeed[client] = fSpeed;
		}
		case SPEED_WALK:{
			if( fSpeed < 65.0 ) fSpeed = 65.0;
			g_fWalkSpeed[client] = fSpeed;
		}
		case SPEED_CROUCH:{
			if( fSpeed < 65.0 ) fSpeed = 65.0;
			g_fCrouchSpeed[client] = fSpeed;
		}
		case SPEED_LIMP:{
			if( fSpeed < 65.0 ) fSpeed = 65.0;
			g_fLimpSpeed[client] = fSpeed;
		}
		case SPEED_CRITICAL:{
			if( fSpeed < 65.0 ) fSpeed = 65.0;
			g_fCritSpeed[client] = fSpeed;
		}
		case SPEED_WATER:{
			if( fSpeed < 65.0 ) fSpeed = 65.0;
			g_fWaterSpeed[client] = fSpeed;
		}
		case SPEED_EXHAUST:{
			if( fSpeed < 110.0 ) fSpeed = 110.0;
			g_fExhaustSpeed[client] = fSpeed;
		}
		case SPEED_ADRENALINE:{
			if( fSpeed < 110.0 ) fSpeed = 110.0;
			g_fAdrenRunSpeed[client] = fSpeed;
		}
		case SPEED_SCOPE:{
			if( fSpeed < 65.0 ) fSpeed = 65.0;
			g_fScopeSpeed[client] = fSpeed;
		}
		default: ThrowNativeError(SP_ERROR_PARAM, "SU_SetSpeed Error: Invalid speed type.");
	}
	return 0;
}

int Native_AddExhaust(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_AddExhaust Error: Client %i is invalid.", client);
	if( !IsPlayerAlive(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_AddExhaust Error: Client %i is not alive.", client);
	if( GetClientTeam(client) != 2 )	ThrowNativeError(SP_ERROR_PARAM, "SU_AddExhaust Error: Client %i is not a survivor.", client);
	// Because adrenaline would override some exhaustion effects and superpose others, throw an error to prevent any other plugin to call this under adrenaline
	if( GetEntProp(client, Prop_Send, "m_bAdrenalineActive") != 0 )
		ThrowNativeError(SP_ERROR_NATIVE, "SU_AddExhaust Error: Can't implement exhaustion on Client %i because is under adrenaline effect.", client);

	bool active;
	int iTokens = numParams == 1 ? EXHAUST_TOKEN : GetNativeCell(2); // Old version used numParams = 1, and exhaust amount was constant
	if( iTokens <= 0 ) ThrowNativeError(SP_ERROR_PARAM, "SU_AddExhaust Error: Amount %i is invalid.", iTokens);
	int iHookTokens = iTokens;
	int iCurrTokens = 0;
	if( g_iExhaustToken[client] > 0 )
	{
		switch( g_hExhaustOverride.IntValue )
		{
			case 0: return 0;
			case 1: if( iTokens < g_iExhaustToken[client] ) return 0;
			case 2: iCurrTokens = g_iExhaustToken[client];
		}
		active = true;
	}
	
	Action aResult = Plugin_Continue;
	Call_StartForward(gf_Exhaust);
	Call_PushCell(client);
	Call_PushCellRef(iHookTokens);
	Call_Finish(aResult);
	
	if( aResult == Plugin_Changed && iHookTokens > 0 ) iTokens = iHookTokens;
	if( aResult == Plugin_Handled ) return 0;
	
	if( !IsValidEntRef(g_iPostProcess) ) CreatePostProcess();
	g_iExhaustToken[client] = iTokens + iCurrTokens;
	delete g_hExhaustTimer[client];
	g_hExhaustTimer[client] = CreateTimer(0.2, Exhaust_Timer, client);
	
	Call_StartForward(gf_ExhaustPost);
	Call_PushCell(client);
	Call_PushCell(iTokens);
	Call_PushCell(active);
	Call_Finish();
	
	return 0;
}

int Native_RemoveExhaust(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveExhaust Error: Client %i is invalid.", client);
	if( !IsPlayerAlive(client) )		ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveExhaust Error: Client %i is not alive.", client);
	if( GetClientTeam(client) != 2 )	ThrowNativeError(SP_ERROR_PARAM, "SU_RemoveExhaust Error: Client %i is not a survivor.", client);
	
	delete g_hExhaustTimer[client];

	g_iExhaustToken[client] = 0;
	g_iEntMustDie = true;
	
	Call_StartForward(gf_ExhaustEnd);
	Call_PushCell(client);
	Call_Finish();
	return 0;
}

int Native_GetFreeze(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_IsFrozen Error: Client %i is invalid.", client);
	// Here is not needed to throw an error with dead survivor, since you only try to get the player stats, this will report that the player is not freeze BECAUSE IT'S DEAD
	// But throw a Native Error if client is not a survivor, this will tell the programmer it's trying to get info from wrong client
	if( GetClientTeam(client) != 2 ) ThrowNativeError(SP_ERROR_PARAM, "SU_GetSpeed Error: Client %i is not survivor.", client);

	return g_bIsFrozen[client];
}

any Native_GetSpeed(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_GetSpeed Error: Client %i is not in game.", client);
	// Basically if someone is doing something wrong and trying to get an infected speed this will be printed
	if( GetClientTeam(client) != 2 ) ThrowNativeError(SP_ERROR_PARAM, "SU_GetSpeed Error: Client %i is not survivor.", client);	

	switch( GetNativeCell(2) )
	{
		case SPEED_RUN:			return g_fRunSpeed[client];
		case SPEED_WALK:		return g_fWalkSpeed[client];
		case SPEED_CROUCH:		return g_fCrouchSpeed[client];
		case SPEED_LIMP:		return g_fLimpSpeed[client];
		case SPEED_CRITICAL:	return g_fCritSpeed[client];
		case SPEED_WATER:		return g_fWaterSpeed[client];
		case SPEED_EXHAUST:		return g_fExhaustSpeed[client];
		case SPEED_ADRENALINE:	return g_fAdrenRunSpeed[client];
		case SPEED_SCOPE:		return g_fScopeSpeed[client];
	}
	
	ThrowNativeError(SP_ERROR_PARAM, "SU_GetSurvivorGetSpeed Error: Invalid speed type.");
	return 0.0;
}

int Native_GetBleed(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_IsBleeding Error: Client %i is invalid.", client);
	if( GetClientTeam(client) != 2 ) ThrowNativeError(SP_ERROR_PARAM, "SU_GetSpeed Error: Client %i is not survivor.", client);	
		
	return g_iBleedToken[client] > 0 ? true : false;
}

int Native_GetToxic(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_IsToxic Error: Client %i is invalid.", client);
	if( GetClientTeam(client) != 2 ) ThrowNativeError(SP_ERROR_PARAM, "SU_GetSpeed Error: Client %i is not survivor.", client);	

	return g_iToxicToken[client] > 0 ? true : false;
}

int Native_GetExhaust(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if( !IsValidClient(client) ) ThrowNativeError(SP_ERROR_PARAM, "SU_IsExhausted Error: Client %i is invalid.", client);
	if( GetClientTeam(client) != 2 ) ThrowNativeError(SP_ERROR_PARAM, "SU_GetSpeed Error: Client %i is not survivor.", client);	
		
	return g_iExhaustToken[client] > 0 ? true : false;
}

/*============================================================================================
									Changelog
----------------------------------------------------------------------------------------------
* 1.4    (23-Sep-2022)
	- Added Post forwards for plugin events.
	- Fixed missing natives in L4D.
* 1.3.5  (08-Sep-2022)
	- Fixed error when attempting to check adrenaline in L4D games (thanks to Dominatez for reporting).
* 1.3.4  (28-Jun-2022)
    - Fixed errors when zombie control transferred between bots and players in infected team.
* 1.3.3  (22-Jun-2022)
    - Fixed a bug where adrenaline speed overrided crouch, walk and scope speeds.
* 1.3.2  (19-Jun-2022)
    - Fixed water speed not getting settings from the right ConVar.
    - Minor optimizations.
* 1.3.1  (16-Jun-2022)
    - Fixed some possible bugs with timers.
    - Removed public function declarations where the weren't needed.
    - In L4D2, medkit ConVar is reset with a post DHook instead of using a RequestFrame.
* 1.3    (01-Feb-2022)
    - Fixed adrenaline and scoping movement speed being overrided by run or limping speed.
    - Both adrenaline and scoping movement speed are controlled by CVar and accessed by Natives.
    - SU_AddExhaust now throws an error if client is under adrenaline effect. This prevents API consistency errors.
    - If speed ConVars are changed ingame, survivor custom speeds will scale proportionally instead of being overrided.
* 1.2.2  (23-Jan-2022)
    - Exhaustion extra recoil added to survivors now can be scaled or disabled by ConVar(thanks to Shao for the request).
* 1.2.1  (19-Jan-2022)
    - Fixed errors when shoving a common infected with first aid kit in L4D2 (thanks to Sev for reporting).
    - Fixed fakely triggering of SU_OnHeal when a survivor shoves an special infected with first aid kit in L4D2.
* 1.2    (18-Jan-2022)
    - Added detouring for game functions:
        * Healing.
        * Reviving survivors.
        * Defib survivors (L4D2)
    - Detours allow to modify backpack usage, healing and revive duration, and block events.
    - Minor optimizations.
* 1.1.2  (09-Jan-2022)
    - Blocked plugin error messages when a survivor joins infected team (thanks to Sev for reporting).
* 1.1.1  (01-Jan-2022)
    - Fixed timer Handle errors.
* 1.1    (30-Dec-2021)
    - Fixed bug where survivor limp speed was not being applied.
    - Survivor speeds are correctly reset on round restart.
    - Improved native error trhow messages.
    - Survivor status now is paused if the survivor goes idle, it will be resumed after survivor joins back.
    - SU_AddExhaust now requires a second parameter, token amount (read survivorutilities.inc for more info).
    - SU_AddExhaust now allows to stack exhaust tokens or override, like the other effects.
* 1.0.3  (25-Dec-2021)
    - Removed debugging messages.
* 1.0.2  (25-Dec-2021)
    - Changed default override values from 1 to 2.
    - Fixed ConVar descriptions.
* 1.0.1  (25-Dec-2021)
    - Fixed missing config file.
* 1.0    (25-Dec-2021)
    - Initial release.
============================================================================================*/