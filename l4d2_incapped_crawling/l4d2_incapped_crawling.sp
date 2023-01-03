/*
*	Incapped Crawling with Animation
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



#define PLUGIN_VERSION 		"2.9"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Incapped Crawling with Animation
*	Author	:	SilverShot
*	Descrp	:	Allows incapped survivors to crawl and sets crawling animation.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=137381
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

2.9 (11-Dec-2022)
	- Changes to fix compile warnings on SourceMod 1.11.

2.8 (04-Mar-2021)
	- Increased a model string variable to support custom models with longer names. Thanks to "Sappykun" for fixing.

2.7a (24-Feb-2021)
	- Added Simplified Chinese and Traditional Chinese translations. Thanks to "HarryPotter" for providing. 

2.7 (27-Sep-2020)
	- Changed cvar "l4d2_crawling_view" to accept value "2" to enable crawling in 1st person without showing your own crawling animation.
	- Feature by "Shadowysn".

2.6 (10-May-2020)
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Various changes to tidy up code.
	- Various optimizations and fixes.

2.5 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.
	- Updated these translation file encodings to UTF-8 (to display all characters correctly): Danish (da), French (fr), German (de).

2.4 (19-Dec-2019)
	- Update by "Lux": Compatibility with the latest LMC version and Coach anim.

2.3 (25-Nov-2019)
	- Fixed "Exception reported: Client 7 is fake and cannot be targeted" errors - Thanks to "Jerry_21" for reporting.

2.2 (24-Nov-2019)
	- Fixed not resetting damage hurt time from version 2.1 changes.

2.1 (24-Nov-2019)
	Changes requested and suggested by "Lux":
	- Added cvar "l4d2_crawling_crazy" option for the crazy face.
	- Now only applies damage once per second when players spam W.
	- Potential fix for client prediction issues when crawling is blocked by spit etc.

2.0 (24-Nov-2019)
	- Coach crawling animation now added! Thanks to "Lux" for the bone merge idea.
	- Crazy faces are now removed. Thanks to "Shadowysn" for the new method.
	- Optimizations and fixes. Stopped using events to track incapacitated information.

1.42 (08-Aug-2018)
	- Fixed the tank death animation being frozen in place, due to "survivor_allow_crawling" bug - Thanks to "Uncle Jessie" for the initial find.

1.41 (24-Jul-2018)
	- Fixed error with LMC - "Lux's Model Changer - Thanks to "MasterMind420".

1.40 (21-Jul-2018)
	- Added Hungarian translations - Thanks to "KasperH".
	- No other changes.

1.40 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
	- Removed instructor hints due to Valve: FCVAR_SERVER_CAN_EXECUTE prevented server running command: gameinstructor_enable.

1.33 (06-Jun-2017)
	- Update by "Lux":
	- Added LMC - "Lux's Model Changer" support for overlay models.
	- Thanks "MasterMind420" for helping test.

1.32 (10-May-2012)
	- Reloading or turning on the plugin now allows incapped players to crawl, instead of requiring the player_incapacitated event to fire first.

1.31 (30-Mar-2012)
	- Added Russian translations - Thanks to "disawar1".
	- Added cvar "l4d2_crawling_modes" to control which game modes the plugin works in.
	- Added cvar "l4d2_crawling_modes_off" same as above.
	- Added cvar "l4d2_crawling_modes_tog" same as above.

1.30 (19-Feb-2012)
	- Added French translations - Thanks to "John2022".
	- Added Spanish translations - Thanks to "Januto".
	- Removes clones when the plugin is unloaded.
	- Removed logging errors when invalid model.

1.29 (18-Oct-2011)
	- Re-added team check to stop error log filling up.

1.28 (14-Oct-2011)
	- Fixed animation number due to Valve update.
	- Added reset on round_start and removed previous update.

1.27 (14-Oct-2011)
	- Added team check to stop error log filling up.

1.26 (22-May-2011)
	- Added cvar "l4d2_crawling_hint_num". How many times to display hints or instructor hint timeout.
	- Fixed duplicate hint messages being displayed (2 events fire for player_incapacitated ?!)
	- Fixed players gun disappearing when being revived and trying to crawl.
	- Fixed Coach not receiving damage when crawling.
	- Optimized some code.

1.25 (17-May-2011)
	- Fixed bugs created by previous update.

1.24 (15-May-2011)
	- Fixed cvars not changing the crawl speed.

1.23 (16-Apr-2011)
	- Changed the Hint Box notification to only appear once per round.
	- Fixed crawling not working for all players?

1.22 (02-Jan-2011)
	- Changed thirdperson view because of Valve patching some client commands.
	- Positioned the model better and removed the timer creating the model.

1.21 (26-Nov-2010)
	- Fixed Instructor Hint not using translation.

1.20 (25-Nov-2010)
	- Fixed invalid convar handles.

1.19 (19-Nov-2010)
	- Added Instructor Hints - Thanks to "McFlurry".

1.18 (18-Nov-2010)
	- Added hints, "l4d2_crawling_hint" and translation file.

1.17 (18-Nov-2010)
	- Cleaned up some code.
	- Enables "survivor_allow_crawling" on plugin start.
	- Fixed not setting "survivor_crawl_speed" on round start.
	- Increased delay on player_incapacitated before allowing crawling from 1.0s to 1.5s.

1.16 (04-Nov-2010)
	- Sets "survivor_allow_crawling" to 0 when plugin unloaded.

1.15 (04-Nov-2010)
	- Added cvar "l4d_crawling_speed" to change "survivor_crawl_speed" cvar (default 15).
	- Added cvar "l4d_crawling_rate" to set the animation playback speed (default 15).

1.14 (12-Oct-2010)
	- Fixed "GetClientHealth" reported: Client is not in game.

1.13 (10-Oct-2010)
	- Removed.

1.12 (07-Oct-2010)
	- Removed.

1.11 (06-Oct-2010)
	- Fixed animation numbers due to The Sacrifice update.

1.10 (05-Oct-2010)
	- Added Bill's animation number for L4D2.

1.09 (01-Oct-2010)
	- Added 1 second delay on player_incapacitated before allowing crawling.

1.08 (22-Sep-2010)
	- Added charger carry event.
	- Fixed version cvar.

1.07 (15-Sep-2010)
	- Animation playback rate now set according to survivor_crawl_speed.
	- Added player_spawn hook to unblock animation, just incase.

1.06 (14-Sep-2010)
	- Added UnhookEvents.
	- Optimized some code.
	- Added version cvar.

1.05 (13-Sep-2010)
	- Added cvar to enable/disable crawling in spitter acid.
	- Added cvar to damage players every second of crawling.
	- Hooked ledge hang to stop animation playing.
	- Hooked charger and smoker grab to stop animation playing.

1.04 (11-Sep-2010)
	- Added "McFlurry"'s code to stop crawling whilst pounced.
	- Fixed crawling breaking on round restart.

1.03 (10-Sep-2010)
	- Added cvar to enable thirdperson view on crawling.
	- Stopped crawling on round end.

1.02 (10-Sep-2010)
	- Fixed silly mistake.

1.01 (10-Sep-2010)
	- Positioned the clone better.
	- Added a cvar to enable/disable glow on crawling.
	- Delayed the animation by 0.1 to correct angles.

1.0 (05-Sep-2010)
	- Initial release.

========================================================================================

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	Thanks to "javalia" for the first and thirdperson view stocks
	https://forums.alliedmods.net/showthread.php?t=122946

*	Thanks to this thread for invisibility
	https://forums.alliedmods.net/showthread.php?t=87626

*	Thanks to "McFlurry" for "[L4D & L4D2] Survivor Crawl Pounce Fix"
	https://forums.alliedmods.net/showthread.php?t=137969

*	Thanks to "Master Xykon" for bone merge stuff.
	https://github.com/dvarnai/store-plugin/blob/master/addons/sourcemod/scripting/include/bonemerge.inc

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS				FCVAR_NOTIFY

#define MODEL_COACH				"models/survivors/survivor_coach.mdl"
#define MODEL_NICK				"models/survivors/survivor_gambler.mdl"
#define EF_BONEMERGE            (1 << 0)
#define EF_NOSHADOW             (1 << 4)
#define EF_BONEMERGE_FASTCULL   (1 << 7)
#define EF_PARENT_ANIMATES      (1 << 9)


//LMC
native int LMC_GetClientOverlayModel(int iClient);
//LMC

Handle g_hTimerHurt;
ConVar g_hCvarAllow, g_hCvarCrawl, g_hCvarCrazy, g_hCvarGlow, g_hCvarHint, g_hCvarHintS, g_hCvarHurt, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarRate, g_hCvarSpeed, g_hCvarSpeeds, g_hCvarSpit, g_hCvarView;
int g_iClone[MAXPLAYERS+1], g_iDisplayed[MAXPLAYERS+1], g_iHint, g_iHints, g_iHurt, g_iRate, g_iSpeed, g_iView;
bool g_bCvarAllow, g_bMapStarted, g_bCrazy, g_bGlow, g_bRoundOver, g_bSpit, g_bTranslation;
float g_fClientWait[MAXPLAYERS+1], g_fClientHurt[MAXPLAYERS+1];



// ====================================================================================================
//					PLUGIN LOAD
// ====================================================================================================
//LMC
bool bLMC_Available = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	MarkNativeAsOptional("LMC_GetClientOverlayModel");
	return APLRes_Success;
}

public void OnLibraryAdded(const char[] sName)
{
	if( strcmp(sName, "LMCCore") == 0 )
		bLMC_Available = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if( strcmp(sName, "LMCCore") == 0 )
		bLMC_Available = false;
}
//LMC



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Incapped Crawling with Animation",
	author = "SilverShot, mod by Lux",
	description = "Allows incapped survivors to crawl and sets crawling animation.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=137381"
}

public void OnPluginStart()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "translations/incappedcrawling.phrases.txt");

	if( !FileExists(sPath) )
		g_bTranslation = false;
	else
	{
		LoadTranslations("incappedcrawling.phrases");
		g_bTranslation = true;
	}

	g_hCvarAllow =		CreateConVar(	"l4d2_crawling",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS);
	g_hCvarCrazy =		CreateConVar(	"l4d2_crawling_crazy",		"0",			"0=Off. 1=Use crazy faces (original before version 2.0).", CVAR_FLAGS);
	g_hCvarGlow =		CreateConVar(	"l4d2_crawling_glow",		"0",			"0=Disables survivor glow on crawling, 1=Enables glow if not realism.", CVAR_FLAGS);
	g_hCvarHint =		CreateConVar(	"l4d2_crawling_hint",		"2",			"0=Dislables, 1=Chat text, 2=Hint box.", CVAR_FLAGS);
	g_hCvarHintS =		CreateConVar(	"l4d2_crawling_hint_num",	"2",			"How many times to display hints.", CVAR_FLAGS);
	g_hCvarHurt =		CreateConVar(	"l4d2_crawling_hurt",		"2",			"Damage to apply every second of crawling, 0=No damage when crawling.", CVAR_FLAGS);
	g_hCvarModes =		CreateConVar(	"l4d2_crawling_modes",		"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =	CreateConVar(	"l4d2_crawling_modes_off",	"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =	CreateConVar(	"l4d2_crawling_modes_tog",	"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarRate =		CreateConVar(	"l4d2_crawling_rate",		"15",			"Sets the playback speed of the crawling animation.", CVAR_FLAGS);
	g_hCvarSpeeds =		CreateConVar(	"l4d2_crawling_speed",		"15",			"Changes 'survivor_crawl_speed' cvar.", CVAR_FLAGS);
	g_hCvarSpit =		CreateConVar(	"l4d2_crawling_spit",		"1",			"0=Disables crawling in spitter acid, 1=Enables crawling in spit.", CVAR_FLAGS);
	g_hCvarView =		CreateConVar(	"l4d2_crawling_view",		"1",			"0=Firstperson view when crawling, 1=Thirdperson view when crawling. 2=Firstperson view when crawling and hides own animation.", CVAR_FLAGS);
	CreateConVar(						"l4d2_crawling_version",	PLUGIN_VERSION, "Incapped Crawling plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d2_incapped_crawling");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarCrazy.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarGlow.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHint.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHintS.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHurt.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSpit.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarView.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRate.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSpeeds.AddChangeHook(ConVarChanged_Speed);

	g_hCvarCrawl = FindConVar("survivor_allow_crawling");
	g_hCvarSpeed = FindConVar("survivor_crawl_speed");
}

public void OnPluginEnd()
{
	g_hCvarCrawl.IntValue = 0;

	for( int i = 1; i <= MaxClients; i++ )
	if( IsClientInGame(i) && GetClientTeam(i) == 2 )
		RemoveClone(i);
}

public void OnClientPutInServer(int client)
{
	g_iDisplayed[client] = 0;
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

void ConVarChanged_Speed(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_iSpeed = g_hCvarSpeeds.IntValue;
	g_hCvarSpeed.IntValue = g_iSpeed;
}

void GetCvars()
{
	g_bCrazy = g_hCvarCrazy.BoolValue;
	g_bGlow = g_hCvarGlow.BoolValue;
	g_iHint = g_hCvarHint.IntValue;
	g_iHints = g_hCvarHintS.IntValue;
	g_iHurt = g_hCvarHurt.IntValue;
	g_iRate = g_hCvarRate.IntValue;
	g_iSpeed = g_hCvarSpeeds.IntValue;
	g_bSpit = g_hCvarSpit.BoolValue;
	g_iView = g_hCvarView.IntValue;

	if( g_iHint > 2 ) g_iHint = 1; // Can no longer support instructor hints
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvents();
		g_hCvarCrawl.IntValue = 1;
		g_hCvarSpeed.IntValue = g_iSpeed;
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvents();
		g_hCvarCrawl.IntValue = 0;
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
void HookEvents()
{
	HookEvent("player_incapacitated",		Event_Incapped);		// Delay crawling by 1 second
	HookEvent("round_start",				Event_RoundStart,		EventHookMode_PostNoCopy);
	HookEvent("round_end",					Event_RoundEnd,			EventHookMode_PostNoCopy);
	HookEvent("player_hurt",				Event_PlayerHurt);		// Apply damage in spit
}

void UnhookEvents()
{
	UnhookEvent("player_incapacitated",		Event_Incapped);
	UnhookEvent("round_start",				Event_RoundStart,		EventHookMode_PostNoCopy);
	UnhookEvent("round_end",				Event_RoundEnd,			EventHookMode_PostNoCopy);
	UnhookEvent("player_hurt",				Event_PlayerHurt);
}



// ====================================================================================================
//					EVENT - ROUND START / END
// ====================================================================================================
void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundOver = false;
	CreateTimer(0.1, TimerRoundStart);
}

Action TimerRoundStart(Handle timer)
{
	if( g_bCvarAllow )
	{
		g_hCvarCrawl.IntValue = 1;
		g_hCvarSpeed.IntValue = g_iSpeed;
	}

	for( int i = 0; i < MAXPLAYERS; i++ )
	{
		g_fClientHurt[i] = 0.0;
		g_iClone[i] = 0;
	}

	return Plugin_Continue;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundOver = true;
	g_hCvarCrawl.IntValue = 0;
}



// ====================================================================================================
//					EVENT - PLAYER HURT
// ====================================================================================================
void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if( !g_bSpit && event.GetInt("type") == 263168 )	// Crawling in spit not allowed & acid damage type
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		g_fClientWait[client] = GetGameTime() + 0.5;
	}
}



// ====================================================================================================
//					EVENT - INCAPACITATED
// ====================================================================================================
void Event_Incapped(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( !IsFakeClient(client) && GetClientTeam(client) == 2 )
	{
		g_fClientWait[client] = GetGameTime() + 1.5;
		if( g_iHint && (g_iHint >= 3 || g_iDisplayed[client] < g_iHints) )
			CreateTimer(1.5, TimerResetStart, GetClientUserId(client));
	}
	else if( GetClientTeam(client) == 3 ) // Tank bug with crawling
	{
		SetEntityMoveType(client, MOVETYPE_VPHYSICS);
	}
}

// Display hint message, allow crawling
Action TimerResetStart(Handle timer, any client)
{
	client = GetClientOfUserId(client);

	if( g_bRoundOver || !g_iHint || (g_iHint < 3 && g_iDisplayed[client] >= g_iHints) || !IsValidClient(client) )
		return Plugin_Continue;

	g_iDisplayed[client]++;
	static char sBuffer[128];

	switch ( g_iHint )
	{
		case 1:		// Print to chat
		{
			if( g_bTranslation )
				Format(sBuffer, sizeof(sBuffer), "\x04[\x01Incapped Crawling\x04]\x01 %T", "Crawl", client);
			else
				Format(sBuffer, sizeof(sBuffer), "\x04[\x01Incapped Crawling\x04]\x01 Press FORWARD to crawl while incapped");

			PrintToChat(client, sBuffer);
		}

		case 2:		// Display hint
		{
			if( g_bTranslation )
				Format(sBuffer, sizeof(sBuffer), "[Incapped Crawling] %T", "Crawl", client);
			else
				Format(sBuffer, sizeof(sBuffer), "[Incapped Crawling] - Press FORWARD to crawl while incapped");

			PrintHintText(client, sBuffer);
		}
	}

	return Plugin_Continue;
}



// ====================================================================================================
//					ON PLAYER RUN CMD
// ====================================================================================================
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	// Plugin enabled
	if( !g_bCvarAllow )
		return Plugin_Continue;

	// Incapped
	if(
		buttons & IN_FORWARD &&
		GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) &&
		GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) == 0
	)
	{
		if(
			!g_bRoundOver &&
			GetGameTime() - g_fClientWait[client] >= 0.0 &&
			GetClientTeam(client) == 2 &&
			IsFakeClient(client) == false &&
			IsPlayerAlive(client) == true &&
			GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") <= 0 &&
			GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") <= 0 &&
			GetEntPropEnt(client, Prop_Send, "m_tongueOwner") <= 0 &&
			GetEntPropEnt(client, Prop_Send, "m_reviveOwner") <= 0
		)
		{
			// No clone, create
			if( g_iClone[client] == 0 )
			{
				PlayAnim(client);
			}
		} else {
			buttons &= ~IN_FORWARD; // Stop pressing forward!
			RemoveClone(client);
		}
	}
	else // Not holding forward/not incapped
	{
		RemoveClone(client);
	}

	return Plugin_Continue;
}



// ====================================================================================================
//					ANIMATION
// ====================================================================================================
Action PlayAnim(int client)
{
	// Prediction
	SendConVarValue(client, g_hCvarCrawl, "1");

	static char sModel[PLATFORM_MAX_PATH];
	GetEntPropString(client, Prop_Data, "m_ModelName", sModel, sizeof(sModel));

	bool coach = sModel[29] == 'c'; // Coach

	// Create survivor clone
	int clone = CreateEntityByName(g_bCrazy ? "prop_dynamic" : "commentary_dummy");
	if( clone == -1 )
	{
		LogError("Failed to create %s '%s' (%N)", g_bCrazy ? "prop_dynamic" : "commentary_dummy", sModel, client);
		return Plugin_Continue;
	}

	if( coach )		SetEntityModel(clone, MODEL_NICK);
	else			SetEntityModel(clone, sModel);

	g_iClone[client] = EntIndexToEntRef(clone); // Global clone ID

	// Attach to survivor
	SetVariantString("!activator");
	AcceptEntityInput(clone, "SetParent", client);
	SetVariantString("bleedout");
	AcceptEntityInput(clone, "SetParentAttachment");

	// Correct angles and origin
	float vPos[3], vAng[3];
	vPos[0] = -2.0;
	vPos[1] = -15.0;
	vPos[2] = -10.0;
	vAng[0] = -330.0;
	vAng[1] = -100.0;
	vAng[2] = 70.0;

	// Set angles and origin
	TeleportEntity(clone, vPos, vAng, NULL_VECTOR);

	// Set animation and playback rate
	SetEntPropFloat(clone, Prop_Send, "m_flPlaybackRate", float(g_iRate) / 15); // Default speed = 15, normal rate = 1.0

	// SetAnim
	SetVariantString("incap_crawl"); // "ACT_TERROR_INCAP_CRAWL" also works
	AcceptEntityInput(clone, "SetAnimation");

	//LMC
	int iEntity;
	if( bLMC_Available )
	{
		iEntity = LMC_GetClientOverlayModel(client);
		if( iEntity > MaxClients && IsValidEntity(iEntity) )
		{
			SetEntityRenderMode(clone, RENDER_NONE);
			SetAttached(iEntity, clone);
		}
	}
	//LMC

	// Coach anim - Bone merge - Ignore if LMC handling.
	if( iEntity < 1 )
	{
		int cloneCoach = CreateEntityByName(g_bCrazy ? "prop_dynamic" : "commentary_dummy");
		if( cloneCoach == -1 )
		{
			LogError("Failed to create clone coach.");
			return Plugin_Continue;
		}

		SetEntityRenderMode(clone, RENDER_NONE); // Hide original clone.
		SetEntityModel(cloneCoach, sModel);
		SetEntProp(cloneCoach, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_NOSHADOW|EF_PARENT_ANIMATES);

		// Attach to survivor
		SetVariantString("!activator");
		AcceptEntityInput(cloneCoach, "SetParent", clone);
	}

	// Make Survivor Invisible
	SetEntityRenderMode(client, RENDER_NONE);

	// Start hurting player
	if( g_iHurt > 0 )
	{
		HurtPlayer(client);

		if( g_hTimerHurt == null )
			g_hTimerHurt = CreateTimer(1.0, TimerHurt, _, TIMER_REPEAT);
	}

	// Disable Glow
	if( !g_bGlow )
		SetEntProp(client, Prop_Send, "m_bSurvivorGlowEnabled", 0);

	// Thirdperson view
	if( g_iView == 1 )
		GotoThirdPerson(client);
	else if( g_iView == 2 )
		SDKHook(clone, SDKHook_SetTransmit, OnTransmit);

	return Plugin_Continue;
}

Action OnTransmit(int entity, int client)
{
	if( g_iClone[client]
		&& EntRefToEntIndex(g_iClone[client]) == entity
		&& GetEntProp(client, Prop_Send, "m_iObserverMode") == 0
		&& GetGameTime() > GetEntPropFloat(client, Prop_Send, "m_TimeForceExternalView")
	) return Plugin_Handled;

	return Plugin_Continue;
}



// ====================================================================================================
//					DAMAGE PLAYER
// ====================================================================================================
Action TimerHurt(Handle timer)
{
	bool bIsCrawling;

	// Loop through players
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsValidClient(i) )
		{
			// They are crawling
			if( g_iClone[i] != 0 )
			{
				bIsCrawling = true;
				HurtPlayer(i);		// Hurt them
			}
		}
	}

	// Looped through all potential clones, no one crawling
	if( !bIsCrawling )
	{
		// No damage to deal, kill timer
		g_hTimerHurt = null;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

void HurtPlayer(int client)
{
	if( GetGameTime() - g_fClientHurt[client] >= 1.0 )
		g_fClientHurt[client] = GetGameTime();
	else
		return;

	int iHealth = GetClientHealth(client) - g_iHurt;
	if( iHealth > 0 )
		SetEntityHealth(client, iHealth);
}

void GotoThirdPerson(int client)
{
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
}

void GotoFirstPerson(int client)
{
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
}

bool IsValidClient(int client)
{
	if( client && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2 )
		return true;
	return false;
}



// ====================================================================================================
//					DELETE CLONE
// ====================================================================================================
void RemoveClone(int client)
{
	int clone = g_iClone[client];
	g_iClone[client] = 0;

	if( clone && EntRefToEntIndex(clone) != INVALID_ENT_REFERENCE )
	{
		// Prediction
		if( IsFakeClient(client) == false ) SendConVarValue(client, g_hCvarCrawl, "0");

		//LMC
		if( bLMC_Available )
		{
			int iEntity;
			iEntity = LMC_GetClientOverlayModel(client);
			if( iEntity > MaxClients && IsValidEntity(iEntity) )
			{
				SetAttached(iEntity, client);
			}
			else
			{
				SetEntityRenderMode(client, RENDER_NORMAL);
			}
		}
		else
		{
			SetEntityRenderMode(client, RENDER_NORMAL);
		}
		//LMC

		RemoveEntity(clone);

		if( IsPlayerAlive(client) )
		{
			if( g_iView == 1 )				// Firstperson view
				GotoFirstPerson(client);

			if( !g_bGlow )					// Enable Glow
				SetEntProp(client, Prop_Send, "m_bSurvivorGlowEnabled", 1);
		}
	}
}

// LMC
// Lux: As a note this should only be used for dummy entity other entities need to remove EF_BONEMERGE_FASTCULL flag.
/*
*	Recreated "SetAttached" entity input from "prop_dynamic_ornament"
*/
stock void SetAttached(int iEntToAttach, int iEntToAttachTo)
{
	SetVariantString("!activator");
	AcceptEntityInput(iEntToAttach, "SetParent", iEntToAttachTo);

	SetEntityMoveType(iEntToAttach, MOVETYPE_NONE);

	SetEntProp(iEntToAttach, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL|EF_PARENT_ANIMATES);

	// Thanks smlib for flag understanding
	int iFlags = GetEntProp(iEntToAttach, Prop_Data, "m_usSolidFlags", 2);
	iFlags = iFlags |= 0x0004;
	SetEntProp(iEntToAttach, Prop_Data, "m_usSolidFlags", iFlags, 2);

	TeleportEntity(iEntToAttach, view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), NULL_VECTOR);
}