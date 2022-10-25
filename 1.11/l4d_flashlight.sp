/*
*	Flashlight Package
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



#define PLUGIN_VERSION 		"2.18"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Flashlight Package
*	Author	:	SilverShot
*	Descrp	:	Attaches an extra flashlight to survivors and spectators.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=173257
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:
2.18 (04-Sep-2021)
	- by Harry

2.17 (04-Aug-2021)
	- Changed the plugin to allow bots to use the color cvar when _default cvar is enabled _random cvar was disabled.

2.16 (31-Jul-2021)
	- Added cvar "l4d_flashlight_default" to turn on the flashlight by default when spawning.
	- Added cvar "l4d_flashlight_random" to give random colors when spawning.

2.15 (11-Jul-2021)
	- Fixed the Special Infected light being visible to others. Thanks to "A1ekin" for reporting.

2.14 (11-Jul-2021)
	- Added cvar "l4d_flashlight_users" to control if Survivors and Special Infected can use the plugins light.
	- Fixed the Survivors spectator light attaching to their dead body and not themselves.

2.13 (01-Jul-2021)
	- Added a warning message to suggest installing the "Attachments API" and "Use Priority Patch" plugins if missing.

2.12 (28-Apr-2021)
	- Changed command "sm_light" to accept "off" param to turn off the light. Thanks to "Dragokas" for requesting.

2.11 (09-Oct-2020)
	- Changed "OnClientPostAdminCheck" to "OnClientPutInServer" - to fix any issues if Steam service is down.

2.10 (18-Sep-2020)
	- Added cookie preferences to save player flashlight color and state. Thanks to "GoGetSomeSleep" for requesting.
	- Added cvar "l4d_flashlight_save" to control if the server can save and load client preferences.

2.9 (10-May-2020)
	- Added Traditional Chinese and Simplified Chinese translations. Thanks to "fbef0102".
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Increased "l4d_flashlight_precach" cvar length, max usable length 485 (due to game limitations).
	- Various changes to tidy up code.

2.8 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.
	- Removed "colors.inc" dependency.
	- Updated these translation file encodings to UTF-8 (to display all characters correctly): Hungarian (hu).

2.7.1 (07-Jan-2020)
	- Fixed "sm_light" not working with color names because 2 args were the wrong way round. Thanks to "K4d4br4" for reporting.

2.7 (19-Dec-2019)
	- Added command "sm_lightmenu" to display a menu and select light color. No translations support.
	- Added cvar "l4d_flashlight_precach" to prevent displaying the model on specific maps. Or "0" for all.
	- Added to "sm_light" and "sm_lightclient" additional colors by name: "cyan" "pink" "lime" "maroon" "teal" "grey".

2.6.1 (21-Jul-2018)
	- Added Hungarian translations - Thanks to KasperH.
	- No other changes.

2.6.1 (18-Jun-2018)
	- Fixed errors, thanks to "ReCreator" for reporting and testing.

2.6 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
	- Changed cvar "l4d_flashlight_modes_tog" now supports L4D1.

2.5.1 (19-Nov-2015)
	- Fix to prevent garbage being passed into SetVariantString, as suggested by "KyleS".

2.5 (25-May-2012)
	- Added more checks to events, preventing errors being logged.

2.4 (22-May-2012)
	- Fixed cvar "l4d_flashlight_spec" enums mistake, thanks to "Dont Fear The Reaper".
	- Fixed errors being logged on player spawn event when clients were not in game.

2.3 (22-May-2012)
	- Changed cvar "l4d_flashlight_spec". The cvar is now a bit flag, add the numbers together.
	- Fixed cvar "l4d_flashlight_spec" blocking alive survivors from using the flashlight.

2.2 (20-May-2012)
	- Changed cvar "l4d_flashlight_spec". You can now specify which teams can use spectator lights.
	- Added German translations - Thanks to "Dont Fear The Reaper".

2.1 (30-Mar-2012)
	- Added Spanish translations - Thanks to "Januto".
	- Added cvar "l4d_flashlight_modes_off" to control which game modes the plugin works in.
	- Added cvar "l4d_flashlight_modes_tog" same as above, but only works for L4D2.
	- Added cvar "l4d_flashlight_hints" which displays the "intro" message to spectators if spectator lights are enabled.
	- Changed the way "l4d_flashlight_flags" validates clients by checking they have one of the flags specified.
	- Fixed the "sm_lightclient" command not affecting all clients.
	- Fixed the "sm_light" command not working for spectators.
	- Fixed ghost players still having flashlights.
	- Small changes and fixes.

2.0 (02-Dec-2011)
	- Plugin separated and taken from the "Flare and Light Package" plugin.
	- Added Russian translations - Thanks to "disawar1".
	- Added personal flashlights for spectators and dead players. The light is invisible to everyone else.
	- Added cvar "l4d_flashlight_spec" to control if spectators should have personal flashlights.
	- Added the following triggers to specify colors with sm_light: red, green, blue, purple, orange, yellow, white.
	- Saves players flashlight on/off state and colors on map change.

1.0 (29-Jan-2011)
	- Initial release.

======================================================================================*/

#pragma semicolon 1

#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define CHAT_TAG			"\x04[\x05Flashlight\x04] \x01"

#define ATTACH_GRENADE		"grenade"
#define MODEL_LIGHT			"models/props_lighting/flashlight_dropped_01.mdl"


// Cvar Handles/Variables
ConVar g_hCvarAllow, g_hCvarAlpha, g_hCvarRandom, g_hCvarColor, g_hCvarDefault, g_hCvarFlags, g_hCvarHints, g_hCvarIntro, g_hCvarLock, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarSave, g_hCvarSpec, g_hCvarUsers;
bool g_bCvarAllow, g_bMapStarted, g_bCvarLock;
char g_sCvarCols[12];
float g_fCvarIntro;
int g_iCvarAlpha, g_iCvarColor, g_iCvarDefault, g_iCvarFlags, g_iCvarHints, g_iCvarRandom, g_iCvarSave, g_iCvarSpec, g_iCvarUsers;

// Plugin Variables
ConVar g_hCvarMPGameMode;
bool g_bRoundOver;
char g_sPlayerModel[MAXPLAYERS+1][42];
int g_iClientColor[MAXPLAYERS+1], g_iClientIndex[MAXPLAYERS+1], g_iClientLight[MAXPLAYERS+1], g_iLightIndex[MAXPLAYERS+1], g_iLights[MAXPLAYERS+1], g_iModelIndex[MAXPLAYERS+1];
Handle g_hCookieColor;
Handle g_hCookieState;
StringMap g_hColors;
StringMapSnapshot g_hSnapColors;
Menu g_hMenu;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Flashlight Package",
	author = "SilverShot",
	description = "Attaches an extra flashlight to survivors and spectators.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=173257"
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
/*
public void OnAllPluginsLoaded()
{
	// Attachments API
	if( FindConVar("attachments_api_version") == null && (FindConVar("l4d2_swap_characters_version") != null || FindConVar("l4d_csm_version") != null) )
	{
		LogMessage("\n==========\nWarning: You should install \"[ANY] Attachments API\" to fix model attachments when changing character models: https://forums.alliedmods.net/showthread.php?t=325651\n==========\n");
	}

	// Use Priority Patch
	if( FindConVar("l4d_use_priority_version") == null )
	{
		LogMessage("\n==========\nWarning: You should install \"[L4D & L4D2] Use Priority Patch\" to fix attached models blocking +USE action: https://forums.alliedmods.net/showthread.php?t=327511\n==========\n");
	}
}
*/
public void OnPluginStart()
{
	// Translations
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "translations/flashlight.phrases.txt");
	if( FileExists(sPath) )
		LoadTranslations("flashlight.phrases");
	else
		SetFailState("Missing required 'translations/flashlight.phrases.txt', please download and install.");

	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	g_hCvarAllow =			CreateConVar(	"l4d_flashlight_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarAlpha =			CreateConVar(	"l4d_flashlight_bright",		"255.0",		"Brightness of the light <10-255> (changes Distance value).", CVAR_FLAGS, true, 10.0, true, 1000.0 );
	g_hCvarColor =			CreateConVar(	"l4d_flashlight_colour",		"200 200 200",	"The default light color. Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", CVAR_FLAGS );
	g_hCvarDefault =		CreateConVar(	"l4d_flashlight_default",		"8",			"Turn on the light when players join. 0=Off. 1=Survivors. 2=Special Infected. 4=Survivor Bots. 8=Spectator. Add numbers together.", CVAR_FLAGS );
	g_hCvarFlags =			CreateConVar(	"l4d_flashlight_flags",			"",				"Players with these flags may use the sm_light command. (Empty = all).", CVAR_FLAGS );
	g_hCvarHints =			CreateConVar(	"l4d_flashlight_hints",			"0",			"0=Off, 1=Show intro message to players entering spectator.", CVAR_FLAGS );
	g_hCvarIntro =			CreateConVar(	"l4d_flashlight_intro",			"35.0",			"0=Off, Show intro message in chat this many seconds after joining.", CVAR_FLAGS, true, 0.0, true, 120.0);
	g_hCvarLock =			CreateConVar(	"l4d_flashlight_lock",			"0",			"0=Let players set their flashlight color, 1=Force to cvar specified.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_flashlight_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_flashlight_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d_flashlight_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarRandom =			CreateConVar(	"l4d_flashlight_random",		"0",			"Give random colors on spawn? 0=Use color cvar. 1=Give Survivor bots random colors if enabled by the _default cvar. 2=Give real players random colors (unless save enabled). 3=Both.", CVAR_FLAGS );
	g_hCvarSave =			CreateConVar(	"l4d_flashlight_save",			"1",			"0=Off, 1=Save client preferences for flashlight color and state.", CVAR_FLAGS );
	g_hCvarSpec =			CreateConVar(	"l4d_flashlight_spec",			"1",			"0=Off, 1=Spectators, 2=Survivors, 4=Infected, 7=All. Give personal flashlights when dead which only they can see.", CVAR_FLAGS );
	g_hCvarUsers =			CreateConVar(	"l4d_flashlight_users",			"0",			"1=Survivors, 2=Infected, 3=All. Allow these players when alive to use the flashlight.", CVAR_FLAGS );
	CreateConVar(							"l4d_flashlight_version",		PLUGIN_VERSION,	"Flashlight plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_flashlight");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAlpha.AddChangeHook(ConVarChanged_LightAlpha);
	g_hCvarRandom.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarColor.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDefault.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarFlags.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHints.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarIntro.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarLock.AddChangeHook(ConVarChanged_Cvars);\
	g_hCvarSave.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarSpec.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarUsers.AddChangeHook(ConVarChanged_Cvars);

	// Commands
	RegAdminCmd(	"sm_lightclient",	CmdLightClient,	ADMFLAG_ROOT,	"Create and toggle flashlight attachment on the specified target. Usage: sm_lightclient <#user id|name> [R G B|red|green|blue|purple|orange|yellow|white]");
	RegConsoleCmd(	"sm_light",			CmdLight,						"Toggle the attached flashlight.");
	RegConsoleCmd(	"sm_lightmenu",		CmdLightMenu,					"Opens the flashlight color menu.");

	CreateColors();

	g_hCookieColor = RegClientCookie("l4d_flashlight", "Flashlight Color", CookieAccess_Protected);
	g_hCookieState = RegClientCookie("l4d_flashlights", "Flashlight State", CookieAccess_Protected);
}

public void OnPluginEnd()
{
	for( int i = 1; i <= MaxClients; i++ )
		DeleteLight(i);
}

public void OnMapStart()
{
	g_bMapStarted = true;
	
	PrecacheModel(MODEL_LIGHT, true);
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}



// ====================================================================================================
//					COOKIES
// ====================================================================================================
public void OnClientDisconnect(int client)
{
	g_iClientColor[client] = 0;
	g_iClientLight[client] = 0;
}

public void OnClientCookiesCached(int client)
{
	if( !g_bCvarLock && g_iCvarSave && !IsFakeClient(client) )
	{
		char sCookie[10];

		GetClientCookie(client, g_hCookieColor, sCookie, sizeof(sCookie));
		if( sCookie[0] )
		{
			g_iClientColor[client] = StringToInt(sCookie);
		} else {
			g_iClientColor[client] = 0;
		}

		GetClientCookie(client, g_hCookieState, sCookie, sizeof(sCookie));
		if( sCookie[0] )
		{
			g_iClientLight[client] = StringToInt(sCookie);
		} else {
			g_iClientColor[client] = 0;
		}
	} else {
		g_iClientColor[client] = 0;
	}
}



// ====================================================================================================
//					MENU + COLORS
// ====================================================================================================
void CreateColors()
{
	// Menu
	g_hMenu = new Menu(Menu_Light);
	g_hMenu.SetTitle("Light Color:");
	g_hMenu.ExitButton = true;

	// Colors
	g_hColors = CreateTrie();

	AddColorItem("red",			"255 0 0");
	AddColorItem("green",		"0 255 0");
	AddColorItem("blue",		"0 0 255");
	AddColorItem("purple",		"155 0 255");
	AddColorItem("cyan",		"0 255 255");
	AddColorItem("orange",		"255 155 0");
	AddColorItem("white",		"-1 -1 -1");
	AddColorItem("pink",		"255 0 150");
	AddColorItem("lime",		"128 255 0");
	AddColorItem("maroon",		"128 0 0");
	AddColorItem("teal",		"0 128 128");
	AddColorItem("yellow",		"255 255 0");
	AddColorItem("grey",		"50 50 50");
	AddColorItem("gray",		"50 50 50");

	g_hSnapColors = g_hColors.Snapshot();
}

void AddColorItem(char[] sName, const char[] sColor)
{
	g_hColors.SetString(sName, sColor);

	sName[0] = CharToUpper(sName[0]);
	g_hMenu.AddItem(sColor, sName);
}

public Action CmdLightMenu(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	g_hMenu.Display(client, 0);
	return Plugin_Handled;
}

public int Menu_Light(Menu menu, MenuAction action, int client, int index)
{
	switch( action )
	{
		case MenuAction_Select:
		{
			char sColor[12];
			menu.GetItem(index, sColor, sizeof(sColor));
			CommandLight(client, 3, sColor);
			g_hMenu.Display(client, 0);
		}
	}
}



// ====================================================================================================
//					INTRO
// ====================================================================================================
public void OnClientPutInServer(int client)
{
	// Display intro / welcome message
	if( g_fCvarIntro && IsValidNow() && !IsFakeClient(client) )
		CreateTimer(g_fCvarIntro, TimerIntro, GetClientUserId(client));
}

public Action TimerIntro(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if( client && IsClientInGame(client) )
	{
		int team = GetClientTeam(client);
		if( team == 2 ) team = 1;
		else if( team == 3 ) team = 2;
		else team = 0;

		if( g_iCvarUsers & team )
		{
			CPrintToChat(client, "%s%T", CHAT_TAG, "Flashlight Intro", client);
		}
	}
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

public void ConVarChanged_LightAlpha(Handle convar, const char[] oldValue, const char[] newValue)
{
	int i, entity;
	g_iCvarAlpha = g_hCvarAlpha.IntValue;

	// Loop through players and change their brightness
	for( i = 1; i <= MaxClients; i++ )
	{
		entity = g_iLightIndex[i];
		if( IsValidEntRef(entity) )
		{
			SetVariantEntity(entity);
			SetVariantInt(g_iCvarAlpha);
			AcceptEntityInput(entity, "distance");
		}
	}
}

void GetCvars()
{
	char sTemp[16];

	g_iCvarAlpha = g_hCvarAlpha.IntValue;
	g_iCvarRandom = g_hCvarRandom.IntValue;
	g_hCvarColor.GetString(g_sCvarCols, sizeof(g_sCvarCols));
	g_iCvarDefault = g_hCvarDefault.IntValue;
	g_hCvarFlags.GetString(sTemp, sizeof(sTemp));
	g_iCvarFlags = ReadFlagString(sTemp);
	g_iCvarHints = g_hCvarHints.IntValue;
	g_fCvarIntro = g_hCvarIntro.FloatValue;
	g_bCvarLock = g_hCvarLock.BoolValue;
	g_iCvarSave = g_hCvarSave.IntValue;
	g_iCvarSpec = g_hCvarSpec.IntValue;
	g_iCvarUsers = g_hCvarUsers.IntValue;

	char sColors[3][4];
	g_iCvarColor = ExplodeString(g_sCvarCols, " ", sColors, sizeof(sColors), sizeof(sColors[]));
	if( g_iCvarColor == 3 )
	{
		g_iCvarColor = StringToInt(sColors[0]);
		g_iCvarColor += 256 * StringToInt(sColors[1]);
		g_iCvarColor += 65536 * StringToInt(sColors[2]);
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
		HookEvents();

		if( IsValidNow() )
		{
			for( int i = 1; i <= MaxClients; i++ )
			{
				if( IsClientInGame(i) )
				{
					OnClientCookiesCached(i);
				}

				if( IsValidClient(i) )
				{
					CreateLight(i);
				}
			}
		}
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvents();

		for( int i = 1; i <= MaxClients; i++ )
		{
			DeleteLight(i);
		}
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
void HookEvents()
{
	HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("player_death",		Event_PlayerDeath);
	HookEvent("item_pickup",		Event_ItemPickup);
	HookEvent("player_spawn",		Event_Spawn);
	HookEvent("player_team",		Event_Team);
}

void UnhookEvents()
{
	UnhookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
	UnhookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
	UnhookEvent("player_death",		Event_PlayerDeath);
	UnhookEvent("item_pickup",		Event_ItemPickup);
	UnhookEvent("player_spawn",		Event_Spawn);
	UnhookEvent("player_team",		Event_Team);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundOver = false;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundOver = true;

	for( int i = 1; i <= MaxClients; i++ )
		DeleteLight(i);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( !client )
		return;

	DeleteLight(client); // Delete attached flashlight
	CreateSpecLight(client);
}

public void Event_ItemPickup(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if( client && IsClientInGame(client) && GetClientTeam(client) == 3 )
		DeleteLight(client);
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int clientID = event.GetInt("userid");
	int client = GetClientOfUserId(clientID);
	DeleteLight(client);

	if( client && IsClientInGame(client) )
	{
		int team = GetClientTeam(client);
		if( team == 2 ) team = 1;
		else if( team == 3 ) team = 2;
		else team = 0;

		if( g_iCvarUsers & team)
		{
			CreateTimer(0.5, TimerDelayCreateLight, clientID); // Needed because round_start event occurs AFTER player_spawn, so IsValidNow() fails...
		}
	}
}

public void Event_Team(Event event, const char[] name, bool dontBroadcast)
{
	int clientID = event.GetInt("userid");
	int client = GetClientOfUserId(clientID);

	if( !client )
		return;

	DeleteLight(client);
	CreateTimer(0.1, TimerDelayCreateLight, clientID);
	//CreateSpecLight(client);
}

public Action TimerDelayCreateLight(Handle timer, any client)
{
	client = GetClientOfUserId(client);

	if( client && IsValidNow() && IsValidClient(client) ) // Re-create attached flashlight
	{
		if( g_iCvarDefault )
		{
			int team = GetClientTeam(client);
			bool fake = IsFakeClient(client);

			if( team == 2 && ((g_iCvarDefault & 1 && !fake) || (g_iCvarDefault & 3 && fake)) )
			{
				// Set light on
				g_iClientLight[client] = 1;

				// Give random light to clients if not saved or bots if allowed or spectator is allowed
				if( (g_iCvarRandom & 1 && fake) || (g_iCvarRandom & 2 && !fake && (!g_iCvarSave || g_iClientColor[client] == 0)) )
				{
					int size = g_hSnapColors.Length;

					char sTemp[32];
					g_hSnapColors.GetKey(GetRandomInt(0, size - 1), sTemp, sizeof(sTemp));
					if( g_hColors.GetString(sTemp, sTemp, sizeof(sTemp)) )
					{
						char sColors[3][4];
						int color;

						ExplodeString(sTemp, " ", sColors, sizeof(sColors), sizeof(sColors[]));
						color = StringToInt(sColors[0]);
						color += 256 * StringToInt(sColors[1]);
						color += 65536 * StringToInt(sColors[2]);
						g_iClientColor[client] = color;
					}
				} else if( fake ) {
					g_iClientColor[client] = g_iCvarColor;
				}
			}

			if( g_iCvarDefault & 2 && team == 3 && !fake )
			{
				g_iClientLight[client] = 1;
			}
			if( g_iCvarDefault & 8 && team == 1 && !fake )
			{
				// Set light on
				g_iClientLight[client] = 1;

				// Give light to spectator if not saved
				if( !g_iCvarSave || g_iClientColor[client] == 0 )
				{
					g_iClientColor[client] = g_iCvarColor;
				}
			}
		}

		CreateLight(client);
	}

	CreateSpecLight(client);
}

void CreateSpecLight(int client)
{
	if( g_iCvarSpec && client && IsClientInGame(client) && !IsFakeClient(client))
	{
		int team = GetClientTeam(client);
		if( team == 3 ) team = 4;
		else if( team == 4 ) team = 8;

		if( team != 1 && !IsPlayerAlive(client) ) return;

		if( g_iCvarSpec & team )
		{
			int entity = MakeLightDynamic(view_as<float>({ 0.0, 0.0, -10.0 }), view_as<float>({ 0.0, 0.0, 0.0 }), client);
			DispatchKeyValue(entity, "_light", "255 255 255 255");
			DispatchKeyValue(entity, "brightness", "2");
			g_iLights[client] = EntIndexToEntRef(entity);
			SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmitSpec);

			if( g_iCvarHints )
			{
				CPrintToChat(client, "%s%T", CHAT_TAG, "Flashlight Intro", client);
			}
		}
	}
}



// ====================================================================================================
//					COMMAND - sm_lightclient
// ====================================================================================================
// Attach flashlight onto specified client / change colors
public Action CmdLightClient(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	if( args == 0 )
	{
		ReplyToCommand(client, "[Flashlight] Usage: sm_lightclient <#user id|name> [R G B|red|green|blue|purple|orange|yellow|white]");
		return Plugin_Handled;
	}

	char sArg[32], target_name[MAX_TARGET_LENGTH];
	GetCmdArg(1, sArg, sizeof(sArg));

	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;

	if( (target_count = ProcessTargetString(
		sArg,
		client,
		target_list,
		MAXPLAYERS,
		COMMAND_FILTER_ALIVE, /* Only allow alive players */
		target_name,
		sizeof(target_name),
		tn_is_ml)) <= 0 )
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	if( args > 1 )
	{
		GetCmdArgString(sArg, sizeof(sArg));
		// Send the args without target name
		int pos = StrContains(sArg, " ");
		if( pos != -1 )
		{
			Format(sArg, sizeof(sArg), sArg[pos+1]);
			TrimString(sArg);
			args--;
		}
	}
	else
		args = 0;

	for( int i = 0; i < target_count; i++ )
	{
		if( IsValidClient(target_list[i]) )
			CommandForceLight(client, target_list[i], args, sArg);
	}
	return Plugin_Handled;
}

void CommandForceLight(int client, int target, int args, const char[] sArg)
{
	// Wrong number of arguments
	if( args != 0 && args != 1 && args != 3 )
	{
		// Display usage help if translation exists and hints turned on
		CPrintToChat(client, "%s%T", CHAT_TAG, "Flashlight Usage", client);
		return;
	}

	// Delete flashlight and re-make if the players model has changed, CSM plugin fix...
	char sTempStr[42];
	GetClientModel(target, sTempStr, sizeof(sTempStr));
	if( strcmp(g_sPlayerModel[target], sTempStr) != 0 )
	{
		DeleteLight(target);
		strcopy(g_sPlayerModel[target], sizeof(sTempStr), sTempStr);
	}

	// Check if they have a light, or try to create
	int entity = g_iLightIndex[target];
	if( !IsValidEntRef(entity) )
	{
		CreateLight(target);

		entity = g_iLightIndex[target];
		if( !IsValidEntRef(entity) )
			return;
	}

	// Toggle or set light color and turn on.
	if( args == 1 )
	{
		char sTempL[12];

		if( g_hColors.GetString(sArg, sTempL, sizeof(sTempL)) == false )
			sTempL = "-1 -1 -1";

		SetVariantEntity(entity);
		SetVariantString(sTempL);
		AcceptEntityInput(entity, "color");
	}
	else if( args == 3 )
	{
		// Specified colors
		char sTempL[12];
		char sSplit[3][4];
		ExplodeString(sArg, " ", sSplit, sizeof(sSplit), sizeof(sSplit[]));
		Format(sTempL, sizeof(sTempL), "%d %d %d", StringToInt(sSplit[0]), StringToInt(sSplit[1]), StringToInt(sSplit[2]));

		SetVariantEntity(entity);
		SetVariantString(sTempL);
		AcceptEntityInput(entity, "color");
	}

	AcceptEntityInput(entity, "toggle");

	int color = GetEntProp(entity, Prop_Send, "m_clrRender");
	if( color != g_iClientColor[target] )
	{
		if( g_iCvarSave && !IsFakeClient(target) )
		{
			char sNum[10];
			IntToString(color, sNum, sizeof(sNum));
			SetClientCookie(target, g_hCookieColor, sNum);
		}

		AcceptEntityInput(entity, "TurnOn");
	}

	g_iClientColor[target] = color;
	g_iClientLight[target] = !g_iClientLight[target];

	if( g_iCvarSave && !IsFakeClient(target) )
	{
		char sNum[10];
		IntToString(g_iClientLight[target], sNum, sizeof(sNum));
		SetClientCookie(target, g_hCookieState, sNum);
	}
}



// ====================================================================================================
//					COMMAND - sm_light
// ====================================================================================================
public Action CmdLight(int client, int args)
{
	char sArg[25];
	GetCmdArgString(sArg, sizeof(sArg));
	CommandLight(client, args, sArg);
	return Plugin_Handled;
}

void CommandLight(int client, int args, const char[] sArg)
{
	// Must be valid
	if( !client || !IsClientInGame(client) )
		return;

	if( !IsValidNow() )
	{
		CPrintToChat(client, "[SM] %T.", "No Access", client);
		return;
	}

	if( IsPlayerAlive(client) )
	{
		int team = GetClientTeam(client);
		if( team == 2 ) team = 1;
		else if( team == 3 ) team = 2;
		else team = 0;

		if( !(g_iCvarUsers & team) )
		{
			CPrintToChat(client, "[SM] %T.", "No Access", client);
			return;
		}
	}
	else
	{
		if( g_iCvarSpec == 0 )
		{
			CPrintToChat(client, "[SM] %T.", "No Access", client);
			return;
		}

		int team = GetClientTeam(client);
		if( team == 3 ) team = 4;
		else if( team == 4 ) team = 8;

		if( !(g_iCvarSpec & team) )
		{
			CPrintToChat(client, "[SM] %T.", "No Access", client);
			return;
		}
	}

	// Make sure the user has the correct permissions
	int flagc = GetUserFlagBits(client);

	if( g_iCvarFlags != 0 && !(flagc & g_iCvarFlags) && !(flagc & ADMFLAG_ROOT) )
	{
		CPrintToChat(client, "[SM] %T.", "No Access", client);
		return;
	}

	// Wrong number of arguments
	if( args != 0 && args != 1 && args != 3 )
	{
		// Display usage help if translation exists and hints turned on
		CPrintToChat(client, "%s%T", CHAT_TAG, "Flashlight Usage", client);
		return;
	}

	// Delete flashlight and re-make if the players model has changed, CSM plugin fix...
	char sTempStr[42];
	GetClientModel(client, sTempStr, sizeof(sTempStr));
	if( strcmp(g_sPlayerModel[client], sTempStr) != 0 )
	{
		DeleteLight(client);
		strcopy(g_sPlayerModel[client], sizeof(sTempStr), sTempStr);
	}

	// Off option
	if( args == 1 )
	{
		if( strcmp(sArg, "off", false) == 0 )
		{
			DeleteLight(client);
			return;
		}
	}

	// Check if they have a light, or try to create
	int entity = g_iLightIndex[client];
	if( !IsValidEntRef(entity) )
	{
		CreateLight(client);

		entity = g_iLightIndex[client];
		if( !IsValidEntRef(entity) )
			return;
	}

	// Specified colors
	if( g_bCvarLock && !(flagc & ADMFLAG_ROOT) )
		flagc = 0;
	else
		flagc = 1;

	// Toggle or set light color and turn on.
	if( flagc && args == 1 )
	{
		char sTempL[12];

		if( g_hColors.GetString(sArg, sTempL, sizeof(sTempL)) == false )
			sTempL = "-1 -1 -1";

		SetVariantEntity(entity);
		SetVariantString(sTempL);
		AcceptEntityInput(entity, "color");
	}
	else if( flagc && args == 3 )
	{
		// Specified colors
		char sTempL[12];
		char sSplit[3][4];
		ExplodeString(sArg, " ", sSplit, sizeof(sSplit), sizeof(sSplit[]));
		Format(sTempL, sizeof(sTempL), "%d %d %d", StringToInt(sSplit[0]), StringToInt(sSplit[1]), StringToInt(sSplit[2]));

		SetVariantEntity(entity);
		SetVariantString(sTempL);
		AcceptEntityInput(entity, "color");
	}

	int color = GetEntProp(entity, Prop_Send, "m_clrRender");
	if( color != g_iClientColor[client] )
	{
		if( g_iCvarSave && !IsFakeClient(client) )
		{
			char sNum[10];
			IntToString(color, sNum, sizeof(sNum));
			SetClientCookie(client, g_hCookieColor, sNum);
		}

		AcceptEntityInput(entity, "TurnOn");
		g_iClientLight[client] = 0;
	}
	else
	{
		AcceptEntityInput(entity, "toggle");
	}
	g_iClientLight[client] = !g_iClientLight[client];
	g_iClientColor[client] = color;

	if( g_iCvarSave && !IsFakeClient(client) )
	{
		char sNum[10];
		IntToString(g_iClientLight[client], sNum, sizeof(sNum));
		SetClientCookie(client, g_hCookieState, sNum);
	}
}

// Called to attach permanent light.
void CreateLight(int client)
{
	DeleteLight(client);

	// Declares
	int entity;
	float vOrigin[3], vAngles[3];

	// Flashlight model
	if( GetClientTeam(client) == 2 && IsPlayerAlive(client) )
	{
		entity = CreateEntityByName("prop_dynamic");
		if( entity == -1 )
		{
			LogError("Failed to create 'prop_dynamic'");
		}
		else
		{
			SetEntityModel(entity, MODEL_LIGHT);
			DispatchSpawn(entity);

			vOrigin = view_as<float>({ 0.0, 0.0, -2.0 });
			vAngles = view_as<float>({ 180.0, 9.0, 90.0 });

			// Attach to survivor
			SetVariantString("!activator");
			AcceptEntityInput(entity, "SetParent", client);
			SetVariantString(ATTACH_GRENADE);
			AcceptEntityInput(entity, "SetParentAttachment");

			TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);
			SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmitLight);
			g_iModelIndex[client] = EntIndexToEntRef(entity);
		}
	}

	// Position light
	vOrigin = view_as<float>({ 0.5, -1.5, -7.5 });
	vAngles = view_as<float>({ -45.0, -45.0, 90.0 });

	// Light_Dynamic
	entity = MakeLightDynamic(vOrigin, vAngles, client);
	g_iLightIndex[client] = EntIndexToEntRef(entity);

	if( g_iClientIndex[client] == GetClientUserId(client) )
	{
		SetEntProp(entity, Prop_Send, "m_clrRender", g_iClientColor[client]);
	}
	else
	{
		g_iClientIndex[client] = GetClientUserId(client);

		// if( !g_iClientColor[client] )
		if( g_iClientColor[client] )
		{
			// g_iClientColor[client] = GetEntProp(entity, Prop_Send, "m_clrRender");
		// }	
		// else
		// {
			SetEntProp(entity, Prop_Send, "m_clrRender", g_iClientColor[client]);
		}
	}

	if( g_iClientLight[client] == 1 )
		AcceptEntityInput(entity, "TurnOn");
	else
		AcceptEntityInput(entity, "TurnOff");

	// Special Infected only light
	if( GetClientTeam(client) == 3 )
	{
		g_iLights[client] = EntIndexToEntRef(entity);
		SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmitSpec);
	}

	// Spectator only light
	if( GetClientTeam(client) == 1 )
	{
		g_iLights[client] = EntIndexToEntRef(entity);
		SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmitSpec);
	}
}



// ====================================================================================================
//					LIGHTS
// ====================================================================================================
int MakeLightDynamic(const float vOrigin[3], const float vAngles[3], int client)
{
	int entity = CreateEntityByName("light_dynamic");
	if( entity == -1)
	{
		LogError("Failed to create 'light_dynamic'");
		return 0;
	}

	char sTemp[16];
	Format(sTemp, sizeof(sTemp), "%s 255", g_sCvarCols);
	DispatchKeyValue(entity, "_light", sTemp);
	DispatchKeyValue(entity, "brightness", "1");
	DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
	DispatchKeyValueFloat(entity, "distance", float(g_iCvarAlpha));
	DispatchKeyValue(entity, "style", "0");
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "TurnOn");

	// Attach to survivor
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", client);

	if( GetClientTeam(client) == 2 && IsPlayerAlive(client) )
	{
		SetVariantString(ATTACH_GRENADE);
		AcceptEntityInput(entity, "SetParentAttachment");
	}

	TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);
	return entity;
}



// ====================================================================================================
//					DELETE ENTITIES
// ====================================================================================================
void DeleteLight(int client)
{
	int entity = g_iLightIndex[client];
	g_iLightIndex[client] = 0;
	DeleteEntity(entity);

	entity = g_iModelIndex[client];
	g_iModelIndex[client] = 0;
	DeleteEntity(entity);

	entity = g_iLights[client];
	g_iLights[client] = 0;
	DeleteEntity(entity);
}

void DeleteEntity(int entity)
{
	if( IsValidEntRef(entity) )
		RemoveEntity(entity);
}

public Action TimerDeleteEntity(Handle timer, any entity)
{
	if( IsValidEntRef(entity) )
		RemoveEntity(entity);
}



// ====================================================================================================
//					BOOLEANS
// ====================================================================================================
bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

bool IsValidClient(int client)
{
	if( !client || !IsClientInGame(client) )
		return false;

	int team = GetClientTeam(client);

	if( team == 1 ) return true;

	if( !IsPlayerAlive(client) ) return false;

	if( team == 2 ) team = 1;
	else if( team == 3 ) team = 2;
	else team = 0;

	if( !(g_iCvarUsers & team) )
		return false;

	return true;
}

bool IsValidNow()
{
	if( g_bRoundOver || !g_bCvarAllow )
		return false;
	return true;
}



// ====================================================================================================
//					SDKHOOKS TRANSMIT
// ====================================================================================================
public Action Hook_SetTransmitLight(int entity, int client)
{
	if( g_iModelIndex[client] == EntIndexToEntRef(entity) )
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action Hook_SetTransmitSpec(int entity, int client)
{
	if( g_iLights[client] == EntIndexToEntRef(entity) )
		return Plugin_Continue;
	return Plugin_Handled;
}



// ====================================================================================================
//					COLORS.INC REPLACEMENT
// ====================================================================================================
void CPrintToChat(int client, char[] message, any ...)
{
	static char buffer[256];
	VFormat(buffer, sizeof(buffer), message, 3);

	ReplaceString(buffer, sizeof(buffer), "{default}",		"\x01");
	ReplaceString(buffer, sizeof(buffer), "{white}",		"\x01");
	ReplaceString(buffer, sizeof(buffer), "{cyan}",			"\x03");
	ReplaceString(buffer, sizeof(buffer), "{lightgreen}",	"\x03");
	ReplaceString(buffer, sizeof(buffer), "{orange}",		"\x04");
	ReplaceString(buffer, sizeof(buffer), "{green}",		"\x04"); // Actually orange in L4D2, but replicating colors.inc behaviour
	ReplaceString(buffer, sizeof(buffer), "{olive}",		"\x05");
	PrintToChat(client, buffer);
}