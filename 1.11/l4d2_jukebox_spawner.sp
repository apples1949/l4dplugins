/*
*	Jukebox Spawner
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



#define PLUGIN_VERSION 		"1.11"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Jukebox Spawner
*	Author	:	SilverShot (idea by 8bit)
*	Descrp	:	Auto-spawn jukeboxes on round start.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=149084
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.11 (11-Jul-2021)
	- Moved the button forward slightly. This allows using the button which the last update prevented.

1.10 (06-Jul-2021)
	- Fixed getting stuck on the Jukebox. Thanks to "Shadowysn" for reporting. Maybe caused by the "2.2.1.3" game update.

1.9 (10-May-2020)
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Various changes to tidy up code.

1.8 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.7 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.

1.6 (21-Jul-2013)
	- Removed Sort_Random work-around. This was fixed in SourceMod 1.4.7, all should update or spawning issues will occur.

1.5 (10-May-2012)
	- Added cvar "l4d2_jukebox_allow" to turn the plugin on and off.
	- Added cvar "l4d2_jukebox_modes" to control which game modes the plugin works in.
	- Added cvar "l4d2_jukebox_modes_tog" same as above.
	- Removed max entity check and related error logging.
	- Small changes and fixes.

1.4 (01-Dec-2011)
	- Added Jukeboxes to these maps: Crash Course, Dead Air, Death Toll, Blood Harvest, Cold Stream.
	- Added command "sm_juketracks" to list tracks read from the config and which will play.
	- Changed command "sm_jukelist" to list all Jukebox positions on the current map.
	- Creates Jukeboxes when the plugin is loaded and removes when unloaded.
	- Fixed "l4d2_jukebox_modes_disallow" cvar not working all the time.

1.3 (19-May-2011)
	- Fixed sm_jukestop not working.

1.2 (19-May-2011)
	- Fixed no tracks loading if a "random" section was not specified. Valve default tracks will be loaded into the "main" section.
	- Fixed PrintToChatAll() error.

1.1 (19-May-2011)
	- Added a "main" section to the keyvalue config which sets a specific track to a specific number for all maps.
	- Added a "random" section to the keyvalue config. Tracks will be randomly be selected from here.
	- Added cvar "l4d2_jukebox_horde_notify" to display a hint when the jukebox triggers a horde.
	- Added command "sm_jukelist" to display a list of randomly selected tracks as well as the override, random and main tracks loaded.
	- Added a check to avoid spawning footlockers when there are too many entities.
	- Added Jukeboxes to saferooms in the the Cold Stream campaign.
	- Changed sm_juke and sm_jukebox to spawn jukeboxes with specified tracks from the "main" and "random" sections and uses overrides for that map if available.
	- Limited sm_jukenext and sm_jukestop to survivor team and admins with 'z' flag only.

1.0 (01-Dec-2011)
	- Initial release.

========================================================================================

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	Thanks to "Zuko & McFlurry" for "[L4D2] Weapon/Zombie Spawner" - Modified the SetTeleportEndPoint()
	https://forums.alliedmods.net/showthread.php?t=109659

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define CHAT_TAG			"\x05[\x04Jukebox Spawner\x05] \x01"
#define CONFIG_SPAWNS		"data/l4d2_jukebox_spawns.cfg"
#define MAX_JUKEBOXES		10
#define MAX_ENT_STORE		18

#define MODEL_BODY			"models/props_unique/jukebox01_body.mdl"
#define MODEL_JUKE			"models/props_unique/jukebox01.mdl"
#define MODEL_MENU			"models/props_unique/jukebox01_menu.mdl"


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hHordeMode, g_hHordeNotify, g_hHordeTime, g_hHordeTrig;
int g_iJukeboxes[MAX_JUKEBOXES][MAX_ENT_STORE], iJukeboxCount;
bool g_bCvarAllow, g_bMapStarted, g_bSpawned;
float g_fMenuPos[3];

char g_sTracksOverride[7][64];		// Map specific tracks
char g_sTracksMain[7][64];			// List of tracks for specific track number
char g_sTracksRand[32][64];			// List of random tracks to select from
int g_iTracksCount, g_iPlayerSpawn, g_iRoundStart;

static const char g_sTracks[7][64]=
{
	"Jukebox.BadMan1",
	"Jukebox.Ridin1",
	"Jukebox.saints_will_never_come",
	"Jukebox.re_your_brains",
	"Jukebox.SaveMeSomeSugar",
	"Jukebox.still_alive",
	"Jukebox.AllIWantForXmas"
};



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Jukebox Spawner",
	author = "SilverShot",
	description = "Auto-spawn jukeboxes on round start.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=149084"
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
	g_fMenuPos = view_as<float>({ 0.0, -12.0, 12.0 });

	g_hCvarAllow = CreateConVar(	"l4d2_jukebox_allow",			"1",			"0=关闭插件，1=打开插件", CVAR_FLAGS );
	g_hHordeMode = CreateConVar(	"l4d2_jukebox_horde_modes",		"",				"在这些游戏模式中，当播放#4时，召唤尸潮。用逗号隔开 没有空格 无内容=全部。", CVAR_FLAGS );
	g_hHordeNotify = CreateConVar(	"l4d2_jukebox_horde_notify",	"1",			"触发尸潮时是否显示一条提示", CVAR_FLAGS );
	g_hHordeTime = CreateConVar(	"l4d2_jukebox_horde_time",		"42",			"播放#4多长时间后触发尸潮", CVAR_FLAGS, true, 0.0, true, 60.0 );
	g_hHordeTrig = CreateConVar(	"l4d2_jukebox_horde_trigger",	"-1",			"-1=无限，0=关闭。播放#4后可以发生多少次恐慌事件", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(	"l4d2_jukebox_modes",			"",				"在这些游戏模式下打开插件，用逗号分隔（没有空格）（空=全部）", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(	"l4d2_jukebox_modes_disallow",	"",				"在这些游戏模式下关闭插件，用逗号分隔（没有空格）（空=无）", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(	"l4d2_jukebox_modes_tog",		"0",			"在这些游戏模式中打开插件。0=全部，1=战役，2=生还者，4=对抗，8=清道夫。将数字相加", CVAR_FLAGS );
	CreateConVar(					"l4d2_jukebox_version",			PLUGIN_VERSION,	"Jukebox Spawner plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,			"l4d2_jukebox");

	RegConsoleCmd(	"sm_jukenext",		CmdJukeNext, 	"Changes the jukebox track.");
	RegConsoleCmd(	"sm_jukestop",		CmdJukeStop, 	"Stops the jukeox playing.");
	RegAdminCmd(	"sm_juke",			CmdJuke,		ADMFLAG_ROOT, 	"Spawns a jukebox where your crosshair is pointing (attempts to align with walls and floor).");
	RegAdminCmd(	"sm_jukebox",		CmdJukeBox,		ADMFLAG_ROOT, 	"Same as above, but saves the origin and angle to the jukebox spawns config.");
	RegAdminCmd(	"sm_jukedel",		CmdJukeDelete,	ADMFLAG_ROOT, 	"Deletes the jukebox you are pointing at (point near the top above the menu).");
	RegAdminCmd(	"sm_jukelist",		CmdJukeList,	ADMFLAG_ROOT, 	"Lists all the Jukeboxes on the current map and their locations.");
	RegAdminCmd(	"sm_juketracks",	CmdJukeTracks,	ADMFLAG_ROOT, 	"Lists all the tracks read from the config and shows which will be playing.");
	RegAdminCmd(	"sm_jukewipe",		CmdJukeWipe,	ADMFLAG_ROOT, 	"Removes all the jukeboxes in game and deletes the current map from the config.");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);

	// Load "main" and "random" tracks from cfg.
	KeyValues hFile = OpenConfig(false);
	if( hFile != null )
	{
		char sTemp[64];
		g_iTracksCount = 7;

		// Load the "main" keyvalues
		if( hFile.JumpToKey("main") )
		{
			for( int i = 0; i < sizeof(g_sTracksMain); i++)
			{
				Format(sTemp, sizeof(sTemp), "track%d", i+1);
				hFile.GetString(sTemp, g_sTracksMain[i], sizeof(g_sTracksMain[]));
			}
			hFile.Rewind();
		}

		// Load the "random" keyvalues
		if( hFile.JumpToKey("random") )
		{
			for( int i = 0; i < sizeof(g_sTracksRand); i++)
			{
				Format(sTemp, sizeof(sTemp), "track%d", i+1);

				if( i < 7 )
					hFile.GetString(sTemp, g_sTracksRand[i], sizeof(g_sTracksRand[]), g_sTracks[i]);
				else
				{
					hFile.GetString(sTemp, g_sTracksRand[i], sizeof(g_sTracksRand[]));
					if( strlen(g_sTracksRand[i]) == 0 )
						break;
					g_iTracksCount++;
				}
			}
			hFile.Rewind();
		}
		else
		{
			for( int i = 0; i < sizeof(g_sTracksMain); i++)
			{
				if( strlen(g_sTracksMain[i]) == 0 )
					strcopy(g_sTracksMain[i], sizeof(g_sTracksMain[]), g_sTracks[i]);
			}
		}

		delete hFile;
	}
}

KeyValues OpenConfig(bool create = true)
{
	// Create config if it does not exist
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		if( create == false )
			return null;

		File hCfg = OpenFile(sPath, "w");
		hCfg.WriteLine("");
		delete hCfg;
	}

	// Open the jukebox config
	KeyValues hFile = new KeyValues("jukeboxes");
	if( !hFile.ImportFromFile(sPath) )
	{
		delete hFile;
		return null;
	}

	return hFile;
}

public void OnPluginEnd()
{
	ResetPlugin();
}

public void OnMapStart()
{
	g_bMapStarted = true;

	PrecacheModel(MODEL_BODY, true);
	PrecacheModel(MODEL_JUKE, true);
	PrecacheModel(MODEL_MENU, true);

	// Load the map specific override keyvalues
	KeyValues hFile = OpenConfig(false);

	if( hFile == null )
	{
		for( int i = 0; i < sizeof(g_sTracksMain); i++ )
			strcopy(g_sTracksMain[i], sizeof(g_sTracksMain[]), g_sTracks[i]);
	}
	else
	{
		char sTemp[64];

		// Map specific overrides
		GetCurrentMap(sTemp, sizeof(sTemp));
		if( hFile.JumpToKey(sTemp) )
		{
			for( int i = 0; i < sizeof(g_sTracksOverride); i++)
			{
				Format(sTemp, sizeof(sTemp), "track%d", i+1);
				hFile.GetString(sTemp, g_sTracksOverride[i], sizeof(g_sTracksOverride[]));
			}
		}

		delete hFile;
	}
}

public void OnMapEnd()
{
	g_bMapStarted = false;
	ResetPlugin();
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

// Loop through the logic_relay and enable/disable if the horde timer is allowed.
public void ConVarChanged_HordeMode(Handle convar, const char[] oldValue, const char[] newValue)
{
	bool bCvarAllow = IsAllowedHordeMode();

	int i, entity;
	for( i = 0; i < MAX_JUKEBOXES; i++ )
	{
		entity = g_iJukeboxes[i][15];
		if( IsValidEntRef(entity) )
		{
			if( bCvarAllow )
				AcceptEntityInput(entity, "Enable");
			else
				AcceptEntityInput(entity, "Disable");
		}
	}
}

bool IsAllowedHordeMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	// Get game mode cvars, if empty allow.
	char sGameModes[64], sGameMode[64];
	g_hHordeMode.GetString(sGameModes, sizeof(sGameModes));

	if( sGameModes[0] == 0 )
		return true;

	// Better game mode check: ",versus," instead of "versus", which would return true for "teamversus" for example.
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	return (StrContains(sGameModes, sGameMode, false) != -1);
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		if( g_bMapStarted )
			LoadJukeboxes();

		HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
		HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		ResetPlugin();

		UnhookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
		UnhookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
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
//					COMMANDS - JUKEBOX
// ====================================================================================================
public Action CmdJukeList(int client, int args)
{
	float vPos[3];
	int i, ent;

	for( i = 0; i < MAX_JUKEBOXES; i++ )
	{
		ent = g_iJukeboxes[i][12];
		if( IsValidEntRef(ent) )
		{
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", vPos);

			if( client == 0 )
				ReplyToCommand(client, "[Jukebox] %d) %f %f %f", i+1, vPos[0], vPos[1], vPos[2]);
			else
				PrintToChat(client, "%s%d) %f %f %f", CHAT_TAG, i+1, vPos[0], vPos[1], vPos[2]);
		}
	}

	if( client == 0 )
		ReplyToCommand(client, "[Jukebox] Total: %d/%d.", iJukeboxCount, MAX_JUKEBOXES);
	else
		PrintToChat(client, "%sTotal: %d/%d.", CHAT_TAG, iJukeboxCount, MAX_JUKEBOXES);

	return Plugin_Handled;
}

public Action CmdJukeTracks(int client, int args)
{
	char sTracks[7][64];

	GetTracks(sTracks);

	if( client == 0 )
		ReplyToCommand(client, "---------- Randomly Selected Tracks ----------");
	else
		PrintToChat(client, "---------- 随机选择曲目 ----------");

	for( int i = 0; i < sizeof(sTracks); i++ )
		ReplyToCommand(client, "%d. %s", i+1, sTracks[i]);

	if( client == 0 )
		ReplyToCommand(client, "---------- All Random Tracks ----------");
	else
		PrintToChat(client, "---------- 所有随机曲目 ----------");

	for( int i = 0; i < sizeof(g_sTracksRand); i++ )
		if( strlen(g_sTracksRand[i]) != 0 )
			ReplyToCommand(client, "%d. %s", i+1, g_sTracksRand[i]);

	if( client == 0 )
		ReplyToCommand(client, "---------- All Main Tracks ----------");
	else
		PrintToChat(client, "---------- 所有主要曲目 ----------");

	for( int i = 0; i < sizeof(g_sTracksMain); i++ )
		if( strlen(g_sTracksMain[i]) != 0 )
			ReplyToCommand(client, "%d. %s", i+1, g_sTracksMain[i]);

	if( client == 0 )
		ReplyToCommand(client, "---------- Map Override Tracks ----------");
	else
		PrintToChat(client, "---------- 地图覆盖轨迹 ----------");

	for( int i = 0; i < sizeof(g_sTracksOverride); i++ )
	{
		if( strlen(g_sTracksOverride[i]) != 0 )
		{
			if( client == 0 )
				ReplyToCommand(client, "%d. %s", i+1, g_sTracksOverride[i]);
			else
				PrintToChat(client, "%d. %s", i+1, g_sTracksOverride[i]);
		}
	}

	return Plugin_Handled;
}

public Action CmdJuke(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Jukebox] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}
	else if( iJukeboxCount >= MAX_JUKEBOXES )
	{
		PrintToChat(client, "%sError: 无法添加更多的音乐盒 用户: (%d/%d).", CHAT_TAG, MAX_JUKEBOXES, MAX_JUKEBOXES);
		return Plugin_Handled;
	}

	// Set player position as jukebox spawn location
	float vPos[3], vAng[3];
	if( !SetTeleportEndPoint(client, vPos, vAng) )
	{
		PrintToChat(client, "%s无法放置音乐盒 请再次尝试", CHAT_TAG);
		return Plugin_Handled;
	}
	else if( iJukeboxCount >= MAX_JUKEBOXES )
	{
		PrintToChat(client, "%sError: 无法继续添加音乐盒 用户: (%d/%d).", CHAT_TAG, MAX_JUKEBOXES, MAX_JUKEBOXES);
		return Plugin_Handled;
	}

	char sTracks[7][64];
	GetTracks(sTracks);
	MakeJukebox(vPos, vAng, sTracks);
	return Plugin_Handled;
}

public Action CmdJukeBox(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Jukebox] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}
	else if( iJukeboxCount >= MAX_JUKEBOXES )
	{
		PrintToChat(client, "%sError: 无法继续添加音乐盒 用户: (%d/%d).", CHAT_TAG, MAX_JUKEBOXES, MAX_JUKEBOXES);
		return Plugin_Handled;
	}

	// Load config
	KeyValues hFile = OpenConfig();
	if( hFile == null )
	{
		PrintToChat(client, "%sError: 无法加载配置文件 (%s).", CHAT_TAG, CONFIG_SPAWNS);
		return Plugin_Handled;
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	if( !hFile.JumpToKey(sMap, true) )	// Create key
	{
		PrintToChat(client, "%sError: 无法向配置文件添加此图", CHAT_TAG);
		delete hFile;
		return Plugin_Handled;
	}

	// Retrieve how many jukeboxes are saved
	int iCount = hFile.GetNum("num", 0);
	if( iCount >= MAX_JUKEBOXES )
	{
		PrintToChat(client, "%sError: 无法添加更多的音乐盒 用户: (%d/%d).", CHAT_TAG, iCount, MAX_JUKEBOXES);
		delete hFile;
		return Plugin_Handled;
	}

	// Get position for jukebox spawn location
	float vPos[3], vAng[3];
	if( !SetTeleportEndPoint(client, vPos, vAng) )
	{
		PrintToChat(client, "%s无法放置音乐盒 请再次尝试", CHAT_TAG);
		delete hFile;
		return Plugin_Handled;
	}

	// Save count
	iCount++;
	hFile.SetNum("num", iCount);

	// Save angle / origin
	char sTemp[10];
	Format(sTemp, sizeof(sTemp), "angle%d", iCount);
	hFile.SetVector(sTemp, vAng);
	Format(sTemp, sizeof(sTemp), "origin%d", iCount);
	hFile.SetVector(sTemp, vPos);

	// Save cfg
	hFile.Rewind();
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	hFile.ExportToFile(sPath);
	delete hFile;

	// Create jukebox
	char sTracks[7][64];
	GetTracks(sTracks);
	MakeJukebox(vPos, vAng, sTracks);
	PrintToChat(client, "%s(%d/%d) - Created at pos:[%f %f %f] ang:[%f %f %f]", CHAT_TAG, iCount, MAX_JUKEBOXES, vPos[0], vPos[1], vPos[2], vAng[0], vAng[1], vAng[2]);
	return Plugin_Handled;
}

void GetTracks(char sTracks[7][64])
{
	// Randomly sort an array of track indexes.
	int[] iRandom = new int[g_iTracksCount];
	for( int i = 1; i <= g_iTracksCount; i++ )
		iRandom[i-1] = i-1;
	SortIntegers(iRandom, g_iTracksCount, Sort_Random);

	int iRand;
	for( int i = 0; i < sizeof(sTracks); i ++ )
	{
		if( strlen(g_sTracksOverride[i]) > 0 )
			strcopy(sTracks[i], sizeof(sTracks[]), g_sTracksOverride[i]);
		else
		{
			if( strlen(g_sTracksMain[i]) > 0 )
				strcopy(sTracks[i], sizeof(sTracks[]), g_sTracksMain[i]);
			else
			{
				iRand = iRandom[i+1];
				strcopy(sTracks[i], sizeof(sTracks[]), g_sTracksRand[iRand]);
			}
		}
	}
}


// Taken from "[L4D2] Weapon/Zombie Spawner"
// By "Zuko & McFlurry"
bool SetTeleportEndPoint(int client, float vPos[3], float vAng[3])
{
	float vAngles[3], vOrigin[3], vBuffer[3], vStart[3], vNorm[3], Distance;

	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

    //get endpoint for teleport
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

	if( TR_DidHit(trace) )
	{
		TR_GetEndPosition(vStart, trace);
		Distance = -15.0;
		GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
		vPos[0] = vStart[0] + (vBuffer[0]*Distance);
		vPos[1] = vStart[1] + (vBuffer[1]*Distance);
		vPos[2] = vStart[2] + (vBuffer[2]*Distance);
		vPos[2] = GetGroundHeight(vPos);
		if( vPos[2] == 0.0 )
		{
			delete trace;
			return false;
		}
		vPos[2] += 32.0;

		TR_GetPlaneNormal(trace, vNorm);

		// Rotate jukebox to the correct angle.
		if( vNorm[2] >= -0.1 && vNorm[2] <= 0.9 )
		{
			GetVectorAngles(vNorm, vAng);
			vAng[1] += 90.0;
		}
	}
	else
	{
		delete trace;
		return false;
	}

	delete trace;
	return true;
}

float GetGroundHeight(float vPos[3])
{
	float vAng[3]; Handle trace = TR_TraceRayFilterEx(vPos, view_as<float>({ 90.0, 0.0, 0.0 }), MASK_ALL, RayType_Infinite, TraceEntityFilterPlayer);
	if( TR_DidHit(trace) )
		TR_GetEndPosition(vAng, trace);

	delete trace;
	return vAng[2];
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
}



// ====================================================================================================
//					COMMANDS - DELETE, WIPE, NEXT, STOP
// ====================================================================================================
int IsEntStored(int entity)
{
	int i, u;
	for( i = 0; i < MAX_JUKEBOXES; i++ )
	{
		for( u = 9; u <= 11; u++ )
			if( g_iJukeboxes[i][u] == entity )
				return i;
	}
	return -1;
}

public Action CmdJukeDelete(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Jukebox] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	// Load config
	KeyValues hFile = OpenConfig(false);
	if( hFile == null )
	{
		PrintToChat(client, "%sError: 无法加载配置文件 (%s).", CHAT_TAG, CONFIG_SPAWNS);
		return Plugin_Handled;
	}

	// Check they are aiming at a jukebox we made
	int iD, entity = GetClientAimTarget(client, false);
	if( entity <= MaxClients || (iD = IsEntStored(EntIndexToEntRef(entity))) == -1 )
	{
		PrintToChat(client, "%s无效目标", CHAT_TAG);
		return Plugin_Handled;
	}

	RemoveJuke(iD);
	iJukeboxCount--;

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !hFile.JumpToKey(sMap) )
	{
		PrintToChat(client, "%s无法找到地图", CHAT_TAG);
		delete hFile;
		return Plugin_Handled;
	}

	// Retrieve how many jukeboxes
	int iCount = hFile.GetNum("num", 0);
	if( iCount == 0 )
	{
		delete hFile;
		return Plugin_Handled;
	}

	bool bMove;
	float fTempPos[3], vPos[3], vAng[3];
	char sTemp[10], sTempB[10];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fTempPos);

	// Move the other entries down
	for( int i = 1; i <= iCount; i++ )
	{
		Format(sTemp, sizeof(sTemp), "angle%d", i);
		Format(sTempB, sizeof(sTempB), "origin%d", i);

		hFile.GetVector(sTemp, vAng);
		hFile.GetVector(sTempB, vPos);

		if( !bMove )
		{
			if( GetVectorDistance(fTempPos, vPos) <= 1.0 )
			{
				hFile.DeleteKey(sTemp);
				hFile.DeleteKey(sTempB);
				bMove = true;
			}
			else if( i == iCount ) // Not found any jukeboxes... exit
			{
				delete hFile;
				return Plugin_Handled;
			}
		}
		else
		{
			// Delete above key
			hFile.DeleteKey(sTemp);
			hFile.DeleteKey(sTempB);

			// Replace with new
			Format(sTemp, sizeof(sTemp), "angle%d", i-1);
			hFile.SetVector(sTemp, vAng);
			Format(sTempB, sizeof(sTempB), "origin%d", i-1);
			hFile.SetVector(sTempB, vPos);
		}
	}

	iCount--;
	hFile.SetNum("num", iCount);

	// Save to file
	hFile.Rewind();
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	hFile.ExportToFile(sPath);
	delete hFile;

	PrintToChat(client, "%s(%d/%d) - 已从配置文件移除音乐盒, 请用sm_jukebox创建新的音乐盒", CHAT_TAG, iCount, MAX_JUKEBOXES);
	return Plugin_Handled;
}

public Action CmdJukeWipe(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Jukebox] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	// Load config
	KeyValues hFile = OpenConfig(false);
	if( hFile == null )
	{
		PrintToChat(client, "%sError: 无法加载配置文件(%s).", CHAT_TAG, CONFIG_SPAWNS);
		return Plugin_Handled;
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !hFile.JumpToKey(sMap, false) )
	{
		PrintToChat(client, "%s无法在配置文件中找到此图", CHAT_TAG);
		delete hFile;
		return Plugin_Handled;
	}

	hFile.DeleteThis();
	ResetPlugin();

	// Save to file
	hFile.Rewind();
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	hFile.ExportToFile(sPath);
	delete hFile;

	PrintToChat(client, "%s(0/%d) - 已从配置文件移除所有的音乐盒，请用sm_jukebox添加", CHAT_TAG, MAX_JUKEBOXES);
	return Plugin_Handled;
}

public Action CmdJukeNext(int client, int args)
{
	if( !client || (GetClientTeam(client) != 2 && !(GetUserFlagBits(client) & (ADMFLAG_ROOT))) )
		return Plugin_Handled;

	int i; int entity; float vPos[3]; float vJukePos[3]; float vDistance; float fNearest = 2000.0; int iJuke;
	GetClientAbsOrigin(client, vPos);

	for( i = 0; i < MAX_JUKEBOXES; i++ )
	{
		entity = g_iJukeboxes[i][12];
		if( IsValidEntRef(entity) )
		{
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vJukePos);
			vDistance = GetVectorDistance(vPos, vJukePos);
			if( vDistance < fNearest )
			{
				fNearest = vDistance;
				iJuke = entity;
			}
		}
	}

	if( iJuke )
	{
		PrintToChatAll("%s\x05%N \x01改变了轨道", CHAT_TAG, client);
		AcceptEntityInput(iJuke, "Press");
	}
	else
	{
		PrintToChat(client, "%你还没有靠近音乐盒", CHAT_TAG);
	}
	return Plugin_Handled;
}

public Action CmdJukeStop(int client, int args)
{
	if( !client || (GetClientTeam(client) != 2 && !(GetUserFlagBits(client) & (ADMFLAG_ROOT))) )
		return Plugin_Handled;

	PrintToChatAll("%s\x05%N \x01停止播放了音乐盒", CHAT_TAG, client);
	StopAllSound();
	return Plugin_Handled;
}



// ====================================================================================================
//					STUFF / CLEAN UP
// ====================================================================================================
void ResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	iJukeboxCount = 0;
	g_bSpawned = false;

	for( int i = 0; i < MAX_JUKEBOXES; i ++ )
		RemoveJuke(i);
}

void RemoveJuke(int index)
{
	int i, entity;
	for( i = 0; i < MAX_ENT_STORE; i ++ )
	{
		entity = g_iJukeboxes[index][i];
		g_iJukeboxes[index][i] = 0;

		if( IsValidEntRef(entity) )
		{
			if( index >= 2 && index <= 8 )
				AcceptEntityInput(entity, "StopSound");
			AcceptEntityInput(entity, "kill");
		}
	}
}

void StopAllSound()
{
	int i, entity;
	for( i = 0; i < MAX_JUKEBOXES; i++ )
	{
		for( int u = 2; u <= 8; u++ )
		{
			entity = g_iJukeboxes[i][u];
			if( IsValidEntRef(entity) )
				AcceptEntityInput(entity, "StopSound");
		}
	}
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}


// ====================================================================================================
//					LOAD JUKEBOXES
// ====================================================================================================
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(1.0, TimerMake, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(1.0, TimerMake, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

public Action TimerMake(Handle timer)
{
	ResetPlugin();
	LoadJukeboxes();
}

void LoadJukeboxes()
{
	if( g_bSpawned )
		return;

	// Load config
	KeyValues hFile = OpenConfig(false);
	if( hFile == null )
		return;

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !hFile.JumpToKey(sMap) )
	{
		delete hFile;
		return;
	}

	// Retrieve how many jukeboxes to display
	int iCount = hFile.GetNum("num", 0);
	if( iCount == 0 )
	{
		delete hFile;
		return;
	}

	if( iCount > MAX_JUKEBOXES )
		iCount = MAX_JUKEBOXES;

	// Get jukebox vectors and tracks
	float vPos[3], vAng[3];
	char sTemp[10], sTracks[7][64];
	hFile.GetString("track1", sTracks[0], sizeof(sTracks[]), g_sTracks[0]);
	hFile.GetString("track2", sTracks[1], sizeof(sTracks[]), g_sTracks[1]);
	hFile.GetString("track3", sTracks[2], sizeof(sTracks[]), g_sTracks[2]);
	hFile.GetString("track4", sTracks[3], sizeof(sTracks[]), g_sTracks[3]);
	hFile.GetString("track5", sTracks[4], sizeof(sTracks[]), g_sTracks[4]);
	hFile.GetString("track6", sTracks[5], sizeof(sTracks[]), g_sTracks[5]);
	hFile.GetString("track7", sTracks[6], sizeof(sTracks[]), g_sTracks[6]);
	GetTracks(sTracks);

	for( int i = 1; i <= iCount; i++ )
	{
		Format(sTemp, sizeof(sTemp), "angle%d", i);
		hFile.GetVector(sTemp, vAng);
		Format(sTemp, sizeof(sTemp), "origin%d", i);
		hFile.GetVector(sTemp, vPos);
		MakeJukebox(vPos, vAng, sTracks);
	}

	delete hFile;
	g_bSpawned = true;
}



// ====================================================================================================
//					CREATE JUKEBOX
// ====================================================================================================
int GetJukeboxID()
{
	for( int i = 0; i < MAX_JUKEBOXES; i++ )
		if( g_iJukeboxes[i][9] == 0 )
			return i;
	return -1;
}

void SetPositionInfront(float vPos[3], const float vAng[3], float fDist)
{
	float vAngles[3], vOrigin[3], vBuffer[3];

	vOrigin = vPos;
	vAngles = vAng;
	vAngles[1] += 90.0;

	GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);

	vPos[0] += ( vBuffer[0] * fDist);
	vPos[1] += ( vBuffer[1] * fDist);
	vPos[2] += 32.0;
}

void MakeJukebox(const float vOrigin[3], const float vAngles[3], const char sTracks[7][64])
{
	char sTemp[64];
	float vPos[3], vAng[3];
	int entity, iDJukebox = GetJukeboxID();

	if( iDJukebox == -1 ) // This should never happen
		return;

	vPos = vOrigin;
	vAng = vAngles;

	// Sounds
	entity = CreateEntityByName("ambient_music");		// Valve use: ambient_generic
	if( entity != -1 )
	{
		Format(sTemp, sizeof(sTemp), "jb%d-record_starting_sound", iDJukebox);
		DispatchKeyValue(entity, "targetname", sTemp);
		DispatchKeyValue(entity, "message", "Jukebox.RecordStart");
		// DispatchKeyValue(entity, "spawnflags", "48");	// For use with: ambient_generic
		DispatchSpawn(entity);
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		g_iJukeboxes[iDJukebox][0] = EntIndexToEntRef(entity);
	}

	entity = CreateEntityByName("ambient_music");		// Valve use: ambient_generic
	if( entity != -1 )
	{
		Format(sTemp, sizeof(sTemp), "jb%d-needle_scratch_sound", iDJukebox);
		DispatchKeyValue(entity, "targetname", sTemp);
		DispatchKeyValue(entity, "message", "Jukebox.NeedleScratch");
		DispatchSpawn(entity);
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		g_iJukeboxes[iDJukebox][1] = EntIndexToEntRef(entity);
	}


	// Music
	int iLoop;
	for( iLoop = 0; iLoop < sizeof(sTracks); iLoop++ ) // Loop through 7 tracks
	{
		entity = CreateEntityByName("ambient_music");
		if( entity != -1 )
		{
			if( iLoop <= 4 )
				Format(sTemp, sizeof(sTemp), "jb%d-jukebox_song_%d", iDJukebox, iLoop+1);
			else
				Format(sTemp, sizeof(sTemp), "jb%d-jukebox_rare_song_%d", iDJukebox, iLoop-4);
			DispatchKeyValue(entity, "targetname", sTemp);
			DispatchKeyValue(entity, "message", sTracks[iLoop]);
			DispatchSpawn(entity);
			TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
			g_iJukeboxes[iDJukebox][iLoop+2] = EntIndexToEntRef(entity);
		}
	}


	// Prop - Jukebox player
	int player;
	entity = CreateEntityByName("prop_dynamic");
	if( entity != -1 )
	{
		SetEntityModel(entity, MODEL_JUKE);
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_body_model", iDJukebox);
		DispatchKeyValue(entity, "targetname", sTemp);
		DispatchKeyValue(entity, "spawnflags", "0");
		DispatchKeyValue(entity, "solid", "2");
		DispatchKeyValue(entity, "disableshadows", "1");
		DispatchKeyValue(entity, "DefaultAnim", "idle");
		DispatchKeyValue(entity, "fademaxdist", "850");
		DispatchKeyValue(entity, "fademindist", "700");

		Format(sTemp, sizeof(sTemp), "OnUser1 jb%d-jukebox_script:runscriptcode:PlaySong():0:-1", iDJukebox);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 jb%d-jukebox_button:Unlock::0.2:-1", iDJukebox);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");

		DispatchSpawn(entity);
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		g_iJukeboxes[iDJukebox][9] = EntIndexToEntRef(entity);
		player = entity;
	}


	// Prop - Jukebox body (prop_static)
	entity = CreateEntityByName("prop_dynamic");
	if( entity != -1 )
	{
		SetEntityModel(entity, MODEL_BODY);
		DispatchKeyValue(entity, "solid", "2");
		DispatchSpawn(entity);
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

		// Attach menu to jukebox
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", player);

		g_iJukeboxes[iDJukebox][10] = EntIndexToEntRef(entity);
	}


	// Prop - Jukebox menu
	entity = CreateEntityByName("prop_dynamic");
	if( entity != -1 )
	{
		SetEntityModel(entity, MODEL_MENU);
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_menu_model", iDJukebox);
		DispatchKeyValue(entity, "targetname", sTemp);
		DispatchKeyValue(entity, "spawnflags", "0");
		DispatchKeyValue(entity, "solid", "2");
		DispatchKeyValue(entity, "disableshadows", "1");
		DispatchSpawn(entity);

		// Attach menu to jukebox
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", player);

		TeleportEntity(entity, g_fMenuPos, view_as<float>({ 0.0, 0.0, 0.0 }), NULL_VECTOR);
		g_iJukeboxes[iDJukebox][11] = EntIndexToEntRef(entity);
	}


	// Func_Button to trigger music
	entity = CreateEntityByName("func_button");
	if( entity != -1 )
	{
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_button", iDJukebox);
		DispatchKeyValue(entity, "targetname", sTemp);
		DispatchKeyValue(entity, "solid", "0");
		DispatchKeyValue(entity, "spawnflags", "1057");
		DispatchKeyValue(entity, "wait", "-1");
		DispatchKeyValue(entity, "speed", "0");
		DispatchKeyValue(entity, "movedir", "0");

		Format(sTemp, sizeof(sTemp), "OnPressed jb%d-jukebox_script:runscriptcode:SwitchRecords():0:-1", iDJukebox);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		SetVariantString("OnPressed !self:Lock::0:-1");
		AcceptEntityInput(entity, "AddOutput");

		SetPositionInfront(vPos, vAng, -25.0);
		vPos[2] -= 10.0;
		vAng[1] += 90.0;
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		vPos = vOrigin;
		vAng = vAngles;
		g_iJukeboxes[iDJukebox][12] = EntIndexToEntRef(entity);
		DispatchSpawn(entity);
	}


	// Create Light_Dynamic
	entity = CreateEntityByName("light_dynamic");
	if( entity != -1)
	{
		DispatchKeyValue(entity, "_light", "241 207 143 100");
		DispatchKeyValue(entity, "brightness", "0");
		DispatchKeyValueFloat(entity, "spotlight_radius", 72.0);
		DispatchKeyValueFloat(entity, "distance", 128.0);
		DispatchKeyValue(entity, "_cone", "75");
		DispatchKeyValue(entity, "_inner_cone", "75");
		DispatchKeyValue(entity, "pitch", "0");
		DispatchKeyValue(entity, "style", "0");
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "TurnOn");

		SetPositionInfront(vPos, vAng, -20.0);
		vAng[1] -= 90.0; // Correct rotation
		vAng[0] = 85.0; // Point down
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		vPos = vOrigin;
		vAng = vAngles;
		g_iJukeboxes[iDJukebox][13] = EntIndexToEntRef(entity);
	}


	// Game event
	entity = CreateEntityByName("logic_game_event");
	if( entity != -1 )
	{
		DispatchKeyValue(entity, "spawnflags", "0");
		Format(sTemp, sizeof(sTemp), "jb%d-song_game_event", iDJukebox);
		DispatchKeyValue(entity, "targetname", sTemp);
		DispatchKeyValue(entity, "eventName", "song_played");
		DispatchSpawn(entity);
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		g_iJukeboxes[iDJukebox][14] = entity;
	}


	// Logic Relay
	int iHordeTrig = g_hHordeTrig.IntValue;
	if( iHordeTrig && IsAllowedHordeMode() )
	{
		entity = CreateEntityByName("logic_relay");
		if( entity != -1 )
		{
			Format(sTemp, sizeof(sTemp), "jb%d-director_panic_relay", iDJukebox);
			DispatchKeyValue(entity, "targetname", sTemp);

			Format(sTemp, sizeof(sTemp), "OnTrigger director:ForcePanicEvent::0:%d", iHordeTrig);
			SetVariantString(sTemp);
			AcceptEntityInput(entity, "AddOutput");
			Format(sTemp, sizeof(sTemp), "OnTrigger @director:ForcePanicEvent::0:%d", iHordeTrig);
			SetVariantString(sTemp);
			AcceptEntityInput(entity, "AddOutput");

			DispatchSpawn(entity);
			TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
			g_iJukeboxes[iDJukebox][15] = entity;
		}
	}


	// Logic Timer
	entity = CreateEntityByName("logic_timer");
	if( entity != -1 )
	{
		Format(sTemp, sizeof(sTemp), "jb%d-song_horde_timer", iDJukebox);
		DispatchKeyValue(entity, "targetname", sTemp);
		DispatchKeyValue(entity, "spawnflags", "0");
		DispatchKeyValue(entity, "StartDisabled", "1");
		g_hHordeTime.GetString(sTemp, sizeof(sTemp));
		DispatchKeyValue(entity, "RefireTime", sTemp);

		Format(sTemp, sizeof(sTemp), "OnTimer jb%d-director_panic_relay:Trigger:0:%d", iDJukebox, iHordeTrig);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		SetVariantString("OnTimer !self:Disable::0.1:-1");
		AcceptEntityInput(entity, "AddOutput");

		DispatchSpawn(entity);
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		g_iJukeboxes[iDJukebox][16] = entity;
		if( iHordeTrig && g_hHordeNotify.BoolValue )
			HookSingleEntityOutput(entity, "OnTimer", OnHordeTimer);
	}


	// Script to play music
	entity = CreateEntityByName("logic_script");
	if( entity != -1 )
	{
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_script", iDJukebox);
		DispatchKeyValue(entity, "targetname", sTemp);
		DispatchKeyValue(entity, "vscripts", "jukebox_dlc1"); // "jukebox_main" Does not have all rare songs :P
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_song_1", iDJukebox);
		DispatchKeyValue(entity, "Group01", sTemp);
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_song_2", iDJukebox);
		DispatchKeyValue(entity, "Group02", sTemp);
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_song_3", iDJukebox);
		DispatchKeyValue(entity, "Group03", sTemp);
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_song_4", iDJukebox);
		DispatchKeyValue(entity, "Group04", sTemp);
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_song_5", iDJukebox);
		DispatchKeyValue(entity, "Group05", sTemp);
		Format(sTemp, sizeof(sTemp), "jb%d-song_horde_timer", iDJukebox);
		DispatchKeyValue(entity, "Group06", sTemp);
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_body_model", iDJukebox);
		DispatchKeyValue(entity, "Group07", sTemp);
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_menu_model", iDJukebox);
		DispatchKeyValue(entity, "Group08", sTemp);
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_rare_song_1", iDJukebox);
		DispatchKeyValue(entity, "Group10", sTemp);
		Format(sTemp, sizeof(sTemp), "jb%d-jukebox_rare_song_2", iDJukebox);
		DispatchKeyValue(entity, "Group11", sTemp);
		Format(sTemp, sizeof(sTemp), "jb%d-record_starting_sound", iDJukebox);
		DispatchKeyValue(entity, "Group13", sTemp);
		Format(sTemp, sizeof(sTemp), "jb%d-needle_scratch_sound", iDJukebox);
		DispatchKeyValue(entity, "Group14", sTemp);
		Format(sTemp, sizeof(sTemp), "jb%d-song_game_event", iDJukebox);
		DispatchKeyValue(entity, "Group15", sTemp);

		DispatchSpawn(entity);
		TeleportEntity(entity, g_fMenuPos, NULL_VECTOR, NULL_VECTOR);
		g_iJukeboxes[iDJukebox][17] = EntIndexToEntRef(entity);
	}


	iJukeboxCount++;
}

public void OnHordeTimer(const char[] output, int caller, int activator, float delay)
{
	PrintToChatAll("%s\x01僵尸被音乐盒吸引过来了！", CHAT_TAG);
}