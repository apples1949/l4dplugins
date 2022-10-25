/*
*	Tongue Damage
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

*	Name	:	[L4D & L4D2] Tongue Damage
*	Author	:	SilverShot
*	Descrp	:	Control the Smokers tongue damage when pulling a Survivor.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=318959
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.10 (01-Jul-2022)
	- Fixed the "choke_end" event throwing unhook event errors under certain conditions.

1.9 (20-Jun-2022)
	- Fixed the "choke_start" event throwing unhook event errors under certain conditions.

1.8 (01-May-2022)
	- Added cvar "l4d_tongue_damage_time_delay" to add a delay between being grabbed and when damage can start hurting players. Requested by "vikingo12".
	- Plugin now optionally uses the "Left4DHooks" plugin to prevent damaging Survivors with God Frames. Requested by "vikingo12".
	- Not sure if God Frames stuff is actually required.
	- Thanks to "vikingo12" for testing.

1.7 (29-Apr-2022)
	- Added cvar "l4d_tongue_damage_frames" to control if God Frames can protect a Survivor while being dragged (requires the "God Frames Patch" plugin).
	- Plugin now optionally uses the "God Frames Patch" plugin to prevent damaging Survivors with God Frames. Thanks to "vikingo12" for reporting.

1.6 (21-Jul-2021)
	- Better more optimized method to prevent timer errors happening.

1.5 (20-Jul-2021)
	- Fixed rare error when clients die during a tongue drag. Thanks to "asherkin" and "Dysphie" for finding the issue.

1.4 (15-May-2020)
	- Replaced "point_hurt" entity with "SDKHooks_TakeDamage" function.

1.3 (10-May-2020)
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Plugin now fixes game bug: Survivors who are pulled when not touching the ground would be stuck floating.
	- This fix is applied to all gamemodes even when the plugin has been turned off.

1.2 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.1 (29-Nov-2019)
	- Fixed invalid timer errors - Thanks to "BlackSabbarh" for reporting.

1.0 (02-Oct-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarDamage, g_hCvarFrames, g_hCvarTimeDelay, g_hCvarTimeDmg;
bool g_bCvarAllow, g_bMapStarted, g_bLeft4DHooks, g_bTongueDamage;
bool g_bChoking[MAXPLAYERS+1], g_bBlockReset[MAXPLAYERS+1];
float g_fDelay[MAXPLAYERS+1];
Handle g_hTimers[MAXPLAYERS+1];

// ==================================================
// 				LEFT 4 DHOOKS - OPTIONAL
// ==================================================
enum CountdownTimer
{
	CTimer_Null = 0 /**< Invalid Timer when lookup fails */
};

native float CTimer_GetRemainingTime(CountdownTimer timer);
native CountdownTimer L4D2Direct_GetInvulnerabilityTimer(int client);



// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Tongue Damage",
	author = "SilverShot",
	description = "Control the Smokers tongue damage when pulling a Survivor.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=318959"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	MarkNativeAsOptional("L4D2Direct_GetInvulnerabilityTimer");

	return APLRes_Success;
}

public void OnLibraryAdded(const char[] sName)
{
	if( strcmp(sName, "left4dhooks") == 0 )
		g_bLeft4DHooks = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if( strcmp(sName, "left4dhooks") == 0 )
		g_bLeft4DHooks = false;
}

public void OnPluginStart()
{
	g_hCvarAllow =			CreateConVar(	"l4d_tongue_damage_allow",			"1",				"0=关闭插件，1=开启插件.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_tongue_damage_modes",			"",					"在这些游戏模式下打开插件，用逗号分隔（没有空格）（空=全部）", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_tongue_damage_modes_off",		"",					"在这些游戏模式下关闭插件，用逗号分隔（没有空格）（空=无）", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d_tongue_damage_modes_tog",		"3",				"在这些游戏模式中打开插件。0=全部，1=战役，2=生还者，4=对抗，8=清道夫。将数字相加", CVAR_FLAGS );
	g_hCvarDamage =			CreateConVar(	"l4d_tongue_damage_damage",			"2.0",				"拖拽会造成多少伤害", CVAR_FLAGS );
	g_hCvarFrames =			CreateConVar(	"l4d_tongue_damage_frames",			"1",				"=脱控的无敌状态下激活时对生存者造成伤害。1=允许无敌状态保护生存者。(需要 'Left4DHooks'或'God Frames Patch'插件）", CVAR_FLAGS );
	g_hCvarTimeDmg =		CreateConVar(	"l4d_tongue_damage_time",			"0.5",				"拖拉的过程中多久伤害一次幸存者", CVAR_FLAGS );
	g_hCvarTimeDelay =		CreateConVar(	"l4d_tongue_damage_time_delay",		"0.0",				" 抓住一个幸存者后多长时间可以进行伤害", CVAR_FLAGS );
	CreateConVar(							"l4d_tongue_damage_version",		PLUGIN_VERSION,		"Tongue Damage plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_tongue_damage");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);

	HookEvent("tongue_grab", Event_GrabStart);
	HookEvent("choke_start", Event_ChokeStart);
	HookEvent("choke_end", Event_ChokeStop);
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

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("round_end",			Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("tongue_release",		Event_GrabStop);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvent("round_end",		Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("tongue_release",	Event_GrabStop);
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
		if( entity != -1 )
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
//					FUNCTION
// ====================================================================================================
void ResetPlugin()
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		delete g_hTimers[i];
		g_bBlockReset[i] = false;
		g_fDelay[i] = 0.0;
	}
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

public void OnClientDisconnect(int client)
{
	delete g_hTimers[client];
	g_bBlockReset[client] = false;
	g_fDelay[client] = 0.0;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

void Event_ChokeStart(Event event, const char[] name, bool dontBroadcast)
{
	if( g_bCvarAllow )
	{
		int client = GetClientOfUserId(event.GetInt("victim"));
		g_bChoking[client] = true;
	}
}

void Event_ChokeStop(Event event, const char[] name, bool dontBroadcast)
{
	if( g_bCvarAllow )
	{
		int client = GetClientOfUserId(event.GetInt("victim"));
		g_bChoking[client] = false;
	}
}

void Event_GrabStart(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("victim");
	int client = GetClientOfUserId(userid);
	if( client && IsClientInGame(client) )
	{
		// Fix floating bug
		if( GetEntityFlags(client) & FL_ONGROUND == 0 )
			SetEntityMoveType(client, MOVETYPE_WALK);

		// Apply damage
		if( g_bCvarAllow )
		{
			delete g_hTimers[client];
			g_fDelay[client] = GetGameTime() + g_hCvarTimeDelay.FloatValue;
			g_hTimers[client] = CreateTimer(g_hCvarTimeDmg.FloatValue, TimerDamage, userid, TIMER_REPEAT);
		}
	}
}

void Event_GrabStop(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("victim");
	int client = GetClientOfUserId(userid);
	if( client && IsClientInGame(client) )
	{
		// Don't kill timer if events called from timer
		if( g_bBlockReset[client] )
		{
			g_bBlockReset[client] = false;
		} else {
			delete g_hTimers[client];
		}
	}
}

Action TimerDamage(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) && IsPlayerAlive(client) )
	{
		if( g_bChoking[client] || (g_hCvarTimeDelay.FloatValue && g_fDelay[client] >= GetGameTime()) )
			return Plugin_Continue;

		if( GetEntProp(client, Prop_Send, "m_isHangingFromTongue") != 1 )
		{
			int attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
			if( attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) )
			{
				// Prevent errors when clients die from HurtEntity during timer callback triggering the "tongue_release" event and delete timer.
				// Thanks to "asherkin" and "Dysphie" for finding the issue.

				// Error log:
				// Plugin "l4d_tongue_damage.smx" encountered error 23: Native detected error
				// Invalid timer handle e745136f (error 1) during timer end, displayed function is timer callback, not the stack trace
				// Unable to call function "TimerDamage" due to above error(s).

				if( g_hCvarFrames.BoolValue && g_bLeft4DHooks )
				{
					CountdownTimer cTimer = L4D2Direct_GetInvulnerabilityTimer(client); // left4dhooks
					if( cTimer != CTimer_Null && CTimer_GetRemainingTime(cTimer) > 0.0 )
					{
						// Don't cause damage if invulnerable God Frames allowed
						return Plugin_Continue;
					}
				}

				g_bBlockReset[client] = true;
				HurtEntity(client, attacker, g_hCvarDamage.FloatValue);
				g_bBlockReset[client] = false;
				return Plugin_Continue;
			}
		}
	}

	g_hTimers[client] = null;
	return Plugin_Stop;
}

void HurtEntity(int victim, int client, float damage)
{
	g_bTongueDamage = true;
	SDKHooks_TakeDamage(victim, client, client, damage, DMG_SLASH);
	g_bTongueDamage = false;
}

public Action OnTakeDamage_Invulnerable(int client, int attacker, float &damage, float &damagetype)
{
	if( g_bTongueDamage && g_hCvarFrames.BoolValue )
	{
		damage = 0.0;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}