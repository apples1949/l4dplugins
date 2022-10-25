/*
*	Respawn Rescue Closet
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



#define PLUGIN_VERSION 		"1.8"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Respawn Rescue Closet
*	Author	:	SilverShot
*	Descrp	:	Creates a rescue closet to respawn dead players, these can be temporary or saved for auto-spawning.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=223138
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.8 (15-Jan-2022)
	- Fixed cvar "l4d_closet_respawn" not allowing a single closet to respawn multiple times. Thanks to "maclarens" for reporting.
	- This will close the doors and re-create the rescue entity after 9  seconds. Players may get stuck if they don't move out before.
	- Bots usually auto teleport if stuck.
	- Should be able to close the door manually to allow more rescues, after to the cvar limit.

1.7 (15-Feb-2021)
	- Fixed "Invalid game event handle". Thanks to "maclarens" for reporting.

1.6 (10-May-2020)
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Various changes to tidy up code.

1.5 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.4 (24-Nov-2019)
	- Fixes for the outhouse closet type:
	- Changed angles of players inside the box to face the correct way.
	- Changed origin of players spawning to prevent getting stuck inside the model.

1.3 (23-Oct-2019)
	- Added cvar "l4d_closet_force" to force allow respawning in closets on any map.
	- This cvar only works in L4D2. This should allow respawning on maps that disabled the possibility.

1.2 (03-Jun-2019)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
	- Added support again for L4D1.
	- Added option to use Gun Cabinet model - Thanks to "Figa" for coding it in.
	- Added option to use invisible model - Thanks to "Shadowysn" for suggesting.
	- Changed cvar "l4d_closet_modes_tog" now supports L4D1.
	- Fixed PreCache errors - Thanks to "Accelerator74" for reporting.

1.1 (14-Jun-2015)
	- Changed to only support L4D2 because L4D does not have the rescue closet model.

1.0 (10-Aug-2013)
	- Initial release.

========================================================================================
	Thanks:

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	"Zuko & McFlurry" for "[L4D2] Weapon/Zombie Spawner" - Modified SetTeleportEndPoint function.
	https://forums.alliedmods.net/showthread.php?t=109659

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define CHAT_TAG			"\x04[\x05Rescue Closet\x04] \x01"
#define CONFIG_SPAWNS		"data/l4d_closet.cfg"
#define MAX_SPAWNS			32

#define	MODEL_PROP			"models/props_urban/outhouse002.mdl"
#define	MODEL_DOOR			"models/props_urban/outhouse_door001.mdl"
#define	MODEL_DOORM			"models/props_unique/guncabinet01_main.mdl"
#define	MODEL_DOORL			"models/props_unique/guncabinet01_ldoor.mdl"
#define	MODEL_DOORR			"models/props_unique/guncabinet01_rdoor.mdl"


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarForce, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarRandom, g_hCvarRespawn;
int g_iCvarRandom, g_iCvarRespawn, g_iPlayerSpawn, g_iRoundStart, g_iSpawnCount, g_iSpawns[MAX_SPAWNS][7];
bool g_bCvarAllow, g_bMapStarted, g_bLeft4Dead2, g_bLoaded, g_bCvarForce;
Menu g_hMenuPos;

enum
{
	INDEX_MODEL,
	INDEX_DOOR1,
	INDEX_DOOR2,
	INDEX_RESCUE,
	INDEX_INDEX,
	INDEX_TYPE,
	INDEX_COUNT
}



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Respawn Rescue Closet",
	author = "SilverShot, Figa",
	description = "Creates a rescue closet to respawn dead players, these can be temporary or saved for auto-spawning.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=223138"
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
	g_hCvarAllow =		CreateConVar(	"l4d_closet_allow",			"1",			" 0=关闭插件，1=打开插件", CVAR_FLAGS );
	if( g_bLeft4Dead2 )
		g_hCvarForce =	CreateConVar(	"l4d_closet_force",			"1",			"(L4D2 only). 0=关闭 1=强制允许玩家通过VScript导演设置在任何地图的壁橱中重生", CVAR_FLAGS );
	g_hCvarModes =		CreateConVar(	"l4d_closet_modes",			"",				"在这些游戏模式下打开插件，用逗号分隔（没有空格）（空=全部）", CVAR_FLAGS );
	g_hCvarModesOff =	CreateConVar(	"l4d_closet_modes_off",		"",				"在这些游戏模式下关闭插件，用逗号分隔（没有空格）（空=无）", CVAR_FLAGS );
	g_hCvarModesTog =	CreateConVar(	"l4d_closet_modes_tog",		"0",			"在这些游戏模式中打开插件。0=全部，1=战役，2=生还者，4=对抗，8=清道夫。将数字相加", CVAR_FLAGS );
	g_hCvarRandom =		CreateConVar(	"l4d_closet_random",		"-1",			"-1=全部，0=无。否则就从地图配置中随机选择这个数量的救援壁橱来生成", CVAR_FLAGS );
	g_hCvarRespawn =	CreateConVar(	"0=无限 玩家可从壁橱重生的次数", CVAR_FLAGS );
	CreateConVar(						"l4d_closet_version",		PLUGIN_VERSION, "Respawn Rescue Closet plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d_closet");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	if( g_bLeft4Dead2 )
		g_hCvarForce.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRandom.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRespawn.AddChangeHook(ConVarChanged_Cvars);

	RegAdminCmd("sm_closet",			CmdSpawnerTemp,		ADMFLAG_ROOT, 	"Spawns a temporary Rescue Closet at your crosshair. <Model: 0=Toilet, 1=Gun Cabinet. 2=Invisible model.>");
	RegAdminCmd("sm_closet_save",		CmdSpawnerSave,		ADMFLAG_ROOT, 	"Spawns a Rescue Closet at your crosshair and saves to config. <Model: 0=Toilet, 1=Gun Cabinet. 2=Invisible model.>");
	RegAdminCmd("sm_closet_del",		CmdSpawnerDel,		ADMFLAG_ROOT, 	"Removes the Rescue Closet you are pointing at and deletes from the config if saved. Must be near-by to delete invisible closets.");
	RegAdminCmd("sm_closet_clear",		CmdSpawnerClear,	ADMFLAG_ROOT, 	"Removes all Rescue Closets spawned by this plugin from the current map.");
	RegAdminCmd("sm_closet_reload",		CmdSpawnerReload,	ADMFLAG_ROOT, 	"Removes all Rescue Closets and reloads the data config.");
	RegAdminCmd("sm_closet_wipe",		CmdSpawnerWipe,		ADMFLAG_ROOT, 	"Removes all Rescue Closets from the current map and deletes them from the config.");
	if( g_bLeft4Dead2 )
		RegAdminCmd("sm_closet_glow",	CmdSpawnerGlow,		ADMFLAG_ROOT, 	"Toggle to enable glow on all Rescue Closets to see where they are placed. Does not edit invisible ones.");
	RegAdminCmd("sm_closet_list",		CmdSpawnerList,		ADMFLAG_ROOT, 	"Display a list Rescue Closet positions and the total number of.");
	RegAdminCmd("sm_closet_tele",		CmdSpawnerTele,		ADMFLAG_ROOT, 	"Teleport to a Rescue Closet (Usage: sm_closet_tele <index: 1 to MAX_SPAWNS (32)>).");
	RegAdminCmd("sm_closet_pos",		CmdSpawnerPos,		ADMFLAG_ROOT, 	"Displays a menu to adjust the Rescue Closet origin your crosshair is over. Does not edit invisible ones.");
}

public void OnPluginEnd()
{
	ResetPlugin();
}

public void OnMapStart()
{
	g_bMapStarted = true;
	PrecacheModel(MODEL_DOORM);
	PrecacheModel(MODEL_DOORL);
	PrecacheModel(MODEL_DOORR);
	PrecacheModel(MODEL_DOOR);
	PrecacheModel(MODEL_PROP);
	PrecacheModel("models/props_urban/outhouse_door001_dm01_01.mdl");
	PrecacheModel("models/props_urban/outhouse_door001_dm02_01.mdl");
	PrecacheModel("models/props_urban/outhouse_door001_dm03_01.mdl");
}

public void OnMapEnd()
{
	g_bMapStarted = false;
	ResetPlugin(false);
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

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	if( g_bLeft4Dead2 )
		g_bCvarForce = g_hCvarForce.BoolValue;
	g_iCvarRandom = g_hCvarRandom.IntValue;
	g_iCvarRespawn = g_hCvarRespawn.IntValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		LoadSpawns();
		g_bCvarAllow = true;
		HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
		HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		HookEvent("survivor_rescued",	Event_PlayerRescue,	EventHookMode_PostNoCopy);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		ResetPlugin();
		g_bCvarAllow = false;
		UnhookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
		UnhookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		UnhookEvent("survivor_rescued",	Event_PlayerRescue,	EventHookMode_PostNoCopy);
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
public void Event_PlayerRescue(Event event, const char[] name, bool dontBroadcast)
{
	// Strange that event is being returned as 0 sometimes... see post#40
	if( g_iCvarRespawn != 1 && event )
	{
		int client = GetClientOfUserId(GetEventInt(event, "victim"));

		if( client && IsClientInGame(client) && GetClientTeam(client) == 2 )
		{
			int entity;
			float vCli[3], vPos[3];
			GetClientAbsOrigin(client, vCli);

			for( int i = 0; i < MAX_SPAWNS; i++ )
			{
				entity = g_iSpawns[i][INDEX_RESCUE];
				if( IsValidEntRef(entity) )
				{
					GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
					if( GetVectorDistance(vPos, vCli) <= 100 )
					{
						int count = g_iSpawns[i][INDEX_COUNT];
						if( count >= g_iCvarRespawn && g_iCvarRespawn != 0 )
						{
							 RemoveEntity(entity);
						} else {
							CreateTimer(5.0, TimerRespawn, i);
							g_iSpawns[i][INDEX_COUNT]++;
						}

						break;
					}
				}
			}
		}
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin(false);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(1.0, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(1.0, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

public Action TimerStart(Handle timer)
{
	ResetPlugin();
	LoadSpawns();

	if( g_bCvarForce )
		DoVScript();

	return Plugin_Continue;
}

void DoVScript()
{
	int entity = CreateEntityByName("logic_script");
	DispatchSpawn(entity);

	// The \ at end of lines allows for multi-line strings in SourcePawn.
	// Probably requires challenge mode to be on.
	char sTemp[256];
	Format(sTemp, sizeof(sTemp), "DirectorOptions <-\
	{\
		cm_AllowSurvivorRescue = 1\
	}");

	SetVariantString(sTemp);
	AcceptEntityInput(entity, "RunScriptCode");
	RemoveEntity(entity);
}



// ====================================================================================================
//					RESPAWN CLOSET
// ====================================================================================================
public Action TimerRespawn(Handle timer, int index)
{
	int entity = g_iSpawns[index][INDEX_MODEL];

	if( IsValidEntRef(entity) )
	{
		entity = g_iSpawns[index][INDEX_DOOR1];
		if( IsValidEntRef(entity) )	AcceptEntityInput(entity, "Close");

		entity = g_iSpawns[index][INDEX_DOOR2];
		if( IsValidEntRef(entity) )	AcceptEntityInput(entity, "Close");

		entity = g_iSpawns[index][INDEX_RESCUE];

		g_iSpawns[index][INDEX_RESCUE] = 0;
		if( IsValidEntRef(entity) ) RemoveEntity(entity);

		CreateTimer(4.0, TimerRespawnRescue, index);

		// RemoveSpawn(index);

		// CreateSpawn(vPos, vAng, index, g_iSpawns[index][INDEX_COUNT]);
	}

	return Plugin_Continue;
}

public Action TimerRespawnRescue(Handle timer, int index)
{
	int entity_rescue = CreateEntityByName("info_survivor_rescue");

	DispatchKeyValue(entity_rescue, "solid", "0");
	DispatchKeyValue(entity_rescue, "model", "models/editor/playerstart.mdl");
	SetEntPropVector(entity_rescue, Prop_Send, "m_vecMins", view_as<float>({-55.0, -55.0, 0.0}));
	SetEntPropVector(entity_rescue, Prop_Send, "m_vecMaxs", view_as<float>({55.0, 55.0, 25.0}));
	DispatchSpawn(entity_rescue);
	AcceptEntityInput(entity_rescue, "TurnOn");

	int entity = g_iSpawns[index][INDEX_MODEL];

	if( IsValidEntRef(entity) )
	{
		float vPos[3], vAng[3];

		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(entity, Prop_Data, "m_angRotation", vAng);

		int type = g_iSpawns[index][INDEX_TYPE];

		if( type == 1 )
		{
			vAng[1] += 90.0;
		}

		TeleportEntity(entity_rescue, vPos, vAng, NULL_VECTOR);

		if( type == 0 )
		{
			GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
			vPos[0] = vPos[0] + (vAng[0] * 5.0);
			vPos[1] = vPos[1] + (vAng[1] * 5.0);
			vPos[2] = vPos[2] + (vAng[2] * 5.0) + 5.0;
			TeleportEntity(entity_rescue, vPos, NULL_VECTOR, NULL_VECTOR);
		}

		g_iSpawns[index][INDEX_RESCUE] = EntIndexToEntRef(entity_rescue);
	}

	return Plugin_Continue;
}



// ====================================================================================================
//					LOAD SPAWNS
// ====================================================================================================
void LoadSpawns()
{
	if( g_bLoaded || g_iCvarRandom == 0 ) return;
	g_bLoaded = true;

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	if( !FileExists(sPath) )
		return;

	// Load config
	KeyValues hFile = new KeyValues("spawns");
	if( !hFile.ImportFromFile(sPath) )
	{
		delete hFile;
		return;
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !hFile.JumpToKey(sMap) )
	{
		delete hFile;
		return;
	}

	// Retrieve how many Rescue Closets to display
	int iCount = hFile.GetNum("num", 0);
	if( iCount == 0 )
	{
		delete hFile;
		return;
	}

	// Spawn only a select few Rescue Closets?
	int iIndexes[MAX_SPAWNS+1];
	if( iCount > MAX_SPAWNS )
		iCount = MAX_SPAWNS;


	// Spawn saved Rescue Closets or create random
	int iRandom = g_iCvarRandom;
	if( iRandom == -1 || iRandom > iCount)
		iRandom = iCount;
	if( iRandom != -1 )
	{
		for( int i = 1; i <= iCount; i++ )
			iIndexes[i-1] = i;

		SortIntegers(iIndexes, iCount, Sort_Random);
		iCount = iRandom;
	}

	// Get the Rescue Closet origins and spawn
	char sTemp[4];
	float vPos[3], vAng[3];
	int index, type;

	for( int i = 1; i <= iCount; i++ )
	{
		if( iRandom != -1 ) index = iIndexes[i-1];
		else index = i;

		IntToString(index, sTemp, sizeof(sTemp));

		if( hFile.JumpToKey(sTemp) )
		{
			hFile.GetVector("ang", vAng);
			hFile.GetVector("pos", vPos);
			type = hFile.GetNum("type");

			if( vPos[0] == 0.0 && vPos[1] == 0.0 && vPos[2] == 0.0 ) // Should never happen...
				LogError("Error: 0,0,0 origin. Iteration=%d. Index=%d. Random=%d. Count=%d.", i, index, iRandom, iCount);
			else
				CreateSpawn(vPos, vAng, index, type);
			hFile.GoBack();
		}
	}

	delete hFile;
}



// ====================================================================================================
//					CREATE SPAWN
// ====================================================================================================
void CreateSpawn(const float vOrigin[3], float vAngles[3], int index, int type)
{
	if( g_iSpawnCount >= MAX_SPAWNS )
		return;

	int iSpawnIndex = -1;
	for( int i = 0; i < MAX_SPAWNS; i++ )
	{
		if( g_iSpawns[i][INDEX_RESCUE] == 0 )
		{
			iSpawnIndex = i;
			break;
		}
	}

	if( iSpawnIndex == -1 )
		return;

	int entity_door;
	int entity;

	if( type != 2 )
	{
		entity = CreateEntityByName("prop_dynamic_override");

		DispatchKeyValue(entity, "solid", "6");
		if( type == 1 )
		{
			SetEntityModel(entity, MODEL_DOORM);
			vAngles[1] += 180.0;
		}
		else
			SetEntityModel(entity, MODEL_PROP);

		TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);
		DispatchSpawn(entity);

		if( !g_bLeft4Dead2 )
		{
			SetEntProp(entity, Prop_Send, "m_CollisionGroup", 6);
			SetEntProp(entity, Prop_Send, "m_usSolidFlags", 2048);
			SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
		}

		if( type != 1 )
		{
			entity_door = CreateEntityByName("prop_door_rotating");
			DispatchKeyValue(entity_door, "solid", "6");
			DispatchKeyValue(entity_door, "disableshadows", "1");
			DispatchKeyValue(entity_door, "distance", "100");
			DispatchKeyValue(entity_door, "spawnpos", "0");
			DispatchKeyValue(entity_door, "opendir", "1");
			DispatchKeyValue(entity_door, "spawnflags", "8192");
			SetEntityModel(entity_door, MODEL_DOOR);
			TeleportEntity(entity_door, vOrigin, vAngles, NULL_VECTOR);
			DispatchSpawn(entity_door);
			SetVariantString("!activator");
			AcceptEntityInput(entity_door, "SetParent", entity);
			TeleportEntity(entity_door, view_as<float>({27.5, -17.0, 3.49}), NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(entity_door, "ClearParent", entity);
			HookSingleEntityOutput(entity_door, "OnOpen", OnOpen_Func, false);
		}
		else
		{
			entity_door = CreateEntityByName("prop_door_rotating");
			DispatchKeyValue(entity_door, "solid", "6");
			DispatchKeyValue(entity_door, "disableshadows", "1");
			DispatchKeyValue(entity_door, "distance", "100");
			DispatchKeyValue(entity_door, "spawnpos", "0");
			DispatchKeyValue(entity_door, "opendir", "1");
			DispatchKeyValue(entity_door, "spawnflags", "8192");
			SetEntityModel(entity_door, MODEL_DOORL);
			TeleportEntity(entity_door, vOrigin, vAngles, NULL_VECTOR);
			DispatchSpawn(entity_door);
			SetVariantString("!activator");
			AcceptEntityInput(entity_door, "SetParent", entity);
			TeleportEntity(entity_door, view_as<float>({11.5, -23.0, 0.0}), NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(entity_door, "ClearParent", entity);
			HookSingleEntityOutput(entity_door, "OnOpen", OnOpen_Func, false);

			int entity_door_2 = CreateEntityByName("prop_door_rotating");
			DispatchKeyValue(entity_door_2, "solid", "6");
			DispatchKeyValue(entity_door_2, "disableshadows", "1");
			DispatchKeyValue(entity_door_2, "distance", "100");
			DispatchKeyValue(entity_door_2, "spawnpos", "0");
			DispatchKeyValue(entity_door_2, "opendir", "1");
			DispatchKeyValue(entity_door_2, "spawnflags", "8192");
			SetEntityModel(entity_door_2, MODEL_DOORR);
			TeleportEntity(entity_door_2, vOrigin, vAngles, NULL_VECTOR);
			DispatchSpawn(entity_door_2);
			SetVariantString("!activator");
			AcceptEntityInput(entity_door_2, "SetParent", entity);
			TeleportEntity(entity_door_2, view_as<float>({11.5, 23.0, 0.0}), NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(entity_door_2, "ClearParent", entity);
			HookSingleEntityOutput(entity_door_2, "OnOpen", OnOpen_Func, false);

			g_iSpawns[iSpawnIndex][INDEX_DOOR2] = EntIndexToEntRef(entity_door_2);
		}
	}



	// Rescue entity
	int entity_rescue = CreateEntityByName("info_survivor_rescue");

	DispatchKeyValue(entity_rescue, "solid", "0");
	DispatchKeyValue(entity_rescue, "model", "models/editor/playerstart.mdl");
	SetEntPropVector(entity_rescue, Prop_Send, "m_vecMins", view_as<float>({-55.0, -55.0, 0.0}));
	SetEntPropVector(entity_rescue, Prop_Send, "m_vecMaxs", view_as<float>({55.0, 55.0, 25.0}));
	DispatchSpawn(entity_rescue);
	AcceptEntityInput(entity_rescue, "TurnOn");

	if( type == 1 )
	{
		vAngles[1] += 90.0;
	// } else {
		// vAngles[1] += 180.0;
	}
	TeleportEntity(entity_rescue, vOrigin, vAngles, NULL_VECTOR);

	if( type == 0 )
	{
		static float vDir[3];
		GetAngleVectors(vAngles, vDir, NULL_VECTOR, NULL_VECTOR);
		vDir[0] = vOrigin[0] + (vDir[0] * 5.0);
		vDir[1] = vOrigin[1] + (vDir[1] * 5.0);
		vDir[2] = vOrigin[2] + (vDir[2] * 5.0) + 5.0;
		TeleportEntity(entity_rescue, vDir, NULL_VECTOR, NULL_VECTOR);
	}



	// Store data
	g_iSpawns[iSpawnIndex][INDEX_MODEL] = entity ? EntIndexToEntRef(entity) : 0;
	g_iSpawns[iSpawnIndex][INDEX_DOOR1] = entity_door ? EntIndexToEntRef(entity_door) : 0;
	g_iSpawns[iSpawnIndex][INDEX_RESCUE] = EntIndexToEntRef(entity_rescue);
	g_iSpawns[iSpawnIndex][INDEX_TYPE] = type;
	g_iSpawns[iSpawnIndex][INDEX_INDEX] = index;

	g_iSpawnCount++;
}

public void OnOpen_Func(const char[] output, int caller, int activator, float delay)
{
	caller = EntIndexToEntRef(caller);
	int arrindex;
	for( int i = 0; i < MAX_SPAWNS; i++ )
	{
		if( g_iSpawns[i][INDEX_DOOR1] == caller || g_iSpawns[i][INDEX_DOOR2] == caller )
		{
			arrindex = i;
			break;
		}
	}

	int rescue = g_iSpawns[arrindex][INDEX_RESCUE];
	if( IsValidEntRef(rescue) )
	{
		AcceptEntityInput(rescue, "Rescue");
		// if( IsValidEntRef(entity) ) AcceptEntityInput(entity, "DisableCollision"); // Makes the doors shut again

		/*
		if( g_iCvarRespawn )
		{
			int entity = g_iSpawns[arrindex][INDEX_MODEL];
			if( IsValidEntRef(entity) )
			{
				int count = GetEntProp(entity, Prop_Data, "m_iHammerID");
				if( count >= g_iCvarRespawn )
				{
					RemoveEntity(rescue);
				}
			}
		}
		*/
	}

	// entity = g_iSpawns[arrindex][INDEX_DOOR1];
	// if( IsValidEntRef(entity) ) AcceptEntityInput(entity, "DisableCollision");

	// entity = g_iSpawns[arrindex][INDEX_DOOR2];
	// if( IsValidEntRef(entity) ) AcceptEntityInput(entity, "DisableCollision");
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
//					sm_closet_reload
// ====================================================================================================
public Action CmdSpawnerReload(int client, int args)
{
	g_bCvarAllow = false;
	ResetPlugin(true);
	IsAllowed();
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_closet
// ====================================================================================================
public Action CmdSpawnerTemp(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Rescue Closet] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}
	else if( g_iSpawnCount >= MAX_SPAWNS )
	{
		PrintToChat(client, "%sError: 无法添加更多的救援壁橱 用户: (\x05%d/%d\x01).", CHAT_TAG, g_iSpawnCount, MAX_SPAWNS);
		return Plugin_Handled;
	}
	else if( args == 0 )
	{
		PrintToChat(client, "%sUsage: sm_closet <模型: 0=厕所, 1=枪柜. 1代只能使用枪柜 2=不可见模型>", CHAT_TAG, g_iSpawnCount, MAX_SPAWNS);
		return Plugin_Handled;
	}

	float vPos[3], vAng[3];
	if( !SetTeleportEndPoint(client, vPos) )
	{
		PrintToChat(client, "%s无法放置救援壁橱 请再次尝试", CHAT_TAG);
		return Plugin_Handled;
	}

	// Type of model
	char sBuff[3];
	int type;
	if( args == 1 )
	{
		GetCmdArg(1, sBuff, sizeof(sBuff));
		type = StringToInt(sBuff);
		if( type < 0 || type > 2 ) type = 0;
	}

	if( type == 0 ) vAng[1] += 180.0;
	CreateSpawn(vPos, vAng, 0, type);

	return Plugin_Handled;
}

// ====================================================================================================
//					sm_closet_save
// ====================================================================================================
public Action CmdSpawnerSave(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Rescue Closet] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}
	else if( g_iSpawnCount >= MAX_SPAWNS )
	{
		PrintToChat(client, "%sError: 无法添加更多的救援壁橱 用户: (\x05%d/%d\x01).", CHAT_TAG, g_iSpawnCount, MAX_SPAWNS);
		return Plugin_Handled;
	}
	else if( args == 0 )
	{
		PrintToChat(client, "%sUsage: sm_closet <模型: 0=厕所, 1=枪柜. 1代只能使用枪柜 2=不可见模型>", CHAT_TAG, g_iSpawnCount, MAX_SPAWNS);
		return Plugin_Handled;
	}


	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		File hCfg = OpenFile(sPath, "w");
		hCfg.WriteLine("");
		delete hCfg;
	}

	// Load config
	KeyValues hFile = new KeyValues("spawns");
	if( !hFile.ImportFromFile(sPath) )
	{
		PrintToChat(client, "%sError: 无法读取配置文件, 可能文件不存在. 路径：(\x05%s\x01).", CHAT_TAG, sPath);
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	if( !hFile.JumpToKey(sMap, true) )
	{
		PrintToChat(client, "%sError: 未能将地图添加到配置文件中.", CHAT_TAG);
		delete hFile;
		return Plugin_Handled;
	}

	// Retrieve how many Rescue Closets are saved
	int iCount = hFile.GetNum("num", 0);
	if( iCount >= MAX_SPAWNS )
	{
		PrintToChat(client, "%sError: 无法添加更多的救援壁橱 用户: (\x05%d/%d\x01).", CHAT_TAG, iCount, MAX_SPAWNS);
		delete hFile;
		return Plugin_Handled;
	}

	// Save count
	iCount++;
	hFile.SetNum("num", iCount);

	char sTemp[4];
	IntToString(iCount, sTemp, sizeof(sTemp));

	if( hFile.JumpToKey(sTemp, true) )
	{
		// Set player position as Rescue Closet spawn location
		float vPos[3], vAng[3];
		if( !SetTeleportEndPoint(client, vPos) )
		{
			PrintToChat(client, "%s无法放置救援壁橱 请再次尝试", CHAT_TAG);
			delete hFile;
			return Plugin_Handled;
		}

		// Type of model
		char sBuff[3];
		int type;
		if( args == 1 )
		{
			GetCmdArg(1, sBuff, sizeof(sBuff));
			type = StringToInt(sBuff);
			if( type < 0 || type > 2 ) type = 0;
			hFile.SetNum("type", type);
		}

		// Save angle / origin
		if( type == 0 ) vAng[1] += 180.0;
		hFile.SetVector("ang", vAng);
		hFile.SetVector("pos", vPos);

		// Spawn
		if( type == 2 ) type = 3; // So the model spawns to allow adjusting position. Reload to make invisible.
		CreateSpawn(vPos, vAng, iCount, type);

		// Save cfg
		hFile.Rewind();
		hFile.ExportToFile(sPath);

		PrintToChat(client, "%s(\x05%d/%d\x01) - Saved at pos:[\x05%f %f %f\x01] ang:[\x05%f %f %f\x01]", CHAT_TAG, iCount, MAX_SPAWNS, vPos[0], vPos[1], vPos[2], vAng[0], vAng[1], vAng[2]);
	}
	else
		PrintToChat(client, "%s(\x05%d/%d\x01) - 保存救援壁橱失败", CHAT_TAG, iCount, MAX_SPAWNS);

	delete hFile;
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_closet_del
// ====================================================================================================
public Action CmdSpawnerDel(int client, int args)
{
	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[Rescue Closet] Plugin turned off.");
		return Plugin_Handled;
	}

	if( !client )
	{
		ReplyToCommand(client, "[Rescue Closet] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	int index = -1;
	int entity = GetClientAimTarget(client, false);
	if( entity != -1 )
	{
		// Search by crosshair
		entity = EntIndexToEntRef(entity);

		for( int i = 0; i < MAX_SPAWNS; i++ )
		{
			if( g_iSpawns[i][INDEX_MODEL] == entity || g_iSpawns[i][INDEX_DOOR1] == entity )
			{
				index = i;
				break;
			}
		}
	}

	if( index == -1 )
	{
		// Search by distance
		float vCli[3], vPos[3];
		GetClientAbsOrigin(client, vCli);

		for( int i = 0; i < MAX_SPAWNS; i++ )
		{
			entity = g_iSpawns[i][INDEX_RESCUE];
			if( IsValidEntRef(entity) )
			{
				GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vPos);
				if( GetVectorDistance(vPos, vCli) <= 100 )
				{
					index = i;
					break;
				}
			}
		}
	}

	if( index == -1 )
	{
		PrintToChat(client, "%s无法找到附近的或在准心下", CHAT_TAG);
		return Plugin_Handled;
	}

	int cfgindex = g_iSpawns[index][INDEX_INDEX];
	if( cfgindex == 0 )
	{
		RemoveSpawn(index);
		return Plugin_Handled;
	}

	for( int i = 0; i < MAX_SPAWNS; i++ )
	{
		if( g_iSpawns[i][INDEX_INDEX] > cfgindex )
			g_iSpawns[i][INDEX_INDEX]--;
	}

	g_iSpawnCount--;

	// Load config
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		PrintToChat(client, "%sError: 无法找到配置文件 路径：(\x05%s\x01).", CHAT_TAG, CONFIG_SPAWNS);
		return Plugin_Handled;
	}

	KeyValues hFile = new KeyValues("spawns");
	if( !hFile.ImportFromFile(sPath) )
	{
		PrintToChat(client, "%sError: 无法加载配置文件 路径：(\x05%s\x01).", CHAT_TAG, sPath);
		delete hFile;
		return Plugin_Handled;
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !hFile.JumpToKey(sMap) )
	{
		PrintToChat(client, "%sError: 此地图不在配置文件中", CHAT_TAG);
		delete hFile;
		return Plugin_Handled;
	}

	// Retrieve how many Rescue Closets
	int iCount = hFile.GetNum("num", 0);
	if( iCount == 0 )
	{
		delete hFile;
		return Plugin_Handled;
	}

	bool bMove;
	char sTemp[4];

	// Move the other entries down
	for( int i = cfgindex; i <= iCount; i++ )
	{
		IntToString(i, sTemp, sizeof(sTemp));

		if( hFile.JumpToKey(sTemp) )
		{
			if( !bMove )
			{
				bMove = true;
				hFile.DeleteThis();
				RemoveSpawn(index);
			}
			else
			{
				IntToString(i-1, sTemp, sizeof(sTemp));
				hFile.SetSectionName(sTemp);
			}
		}

		hFile.Rewind();
		hFile.JumpToKey(sMap);
	}

	if( bMove )
	{
		iCount--;
		hFile.SetNum("num", iCount);

		// Save to file
		hFile.Rewind();
		hFile.ExportToFile(sPath);

		PrintToChat(client, "%s(\x05%d/%d\x01) - 救援橱柜已移除出配置文件", CHAT_TAG, iCount, MAX_SPAWNS);
	}
	else
		PrintToChat(client, "%s(\x05%d/%d\x01) - 移除出配置文件失败", CHAT_TAG, iCount, MAX_SPAWNS);

	delete hFile;
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_closet_clear
// ====================================================================================================
public Action CmdSpawnerClear(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Rescue Closet] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	ResetPlugin();

	PrintToChat(client, "%s(0/%d) - 此地图全部的救援橱柜已移除", CHAT_TAG, MAX_SPAWNS);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_closet_wipe
// ====================================================================================================
public Action CmdSpawnerWipe(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Rescue Closet] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		PrintToChat(client, "%sError: 无法找到配置文件 路径：(\x05%s\x01).", CHAT_TAG, sPath);
		return Plugin_Handled;
	}

	// Load config
	KeyValues hFile = new KeyValues("spawns");
	if( !hFile.ImportFromFile(sPath) )
	{
		PrintToChat(client, "%sError: 无法加载配置文件 路径：(\x05%s\x01).", CHAT_TAG, sPath);
		delete hFile;
		return Plugin_Handled;
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !hFile.JumpToKey(sMap, false) )
	{
		PrintToChat(client, "%sError: 此地图不在配置文件中", CHAT_TAG);
		delete hFile;
		return Plugin_Handled;
	}

	hFile.DeleteThis();
	ResetPlugin();

	// Save to file
	hFile.Rewind();
	hFile.ExportToFile(sPath);
	delete hFile;

	PrintToChat(client, "%s(0/%d) - 已从配置中删除了所有救援壁橱，请用\x05sm_closet_save\x01指令", CHAT_TAG, MAX_SPAWNS);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_closet_glow
// ====================================================================================================
public Action CmdSpawnerGlow(int client, int args)
{
	static bool glow;
	glow = !glow;
	PrintToChat(client, "%s是否启用发光轮毂%s", CHAT_TAG, glow ? "启用" : "禁用");

	VendorGlow(glow);
	return Plugin_Handled;
}

void VendorGlow(int glow)
{
	int ent;

	for( int i = 0; i < MAX_SPAWNS; i++ )
	{
		ent = g_iSpawns[i][INDEX_MODEL];
		if( IsValidEntRef(ent) )
		{
			SetEntProp(ent, Prop_Send, "m_iGlowType", glow ? 3 : 0);
			if( glow )
			{
				SetEntProp(ent, Prop_Send, "m_glowColorOverride", 255);
				SetEntProp(ent, Prop_Send, "m_nGlowRange", glow ? 0 : 50);
			}
		}
	}
}

// ====================================================================================================
//					sm_closet_list
// ====================================================================================================
public Action CmdSpawnerList(int client, int args)
{
	char sModel[64];
	float vPos[3];
	int count, type, ent;

	for( int i = 0; i < MAX_SPAWNS; i++ )
	{
		type = -1;

		ent = g_iSpawns[i][INDEX_MODEL];
		if( IsValidEntRef(ent) )
		{
			type = 0;

			GetEntPropString(ent, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
			if( strcmp(sModel, MODEL_DOORM) == 0 )
				type = 1;
		}
		else
		{
			ent = g_iSpawns[i][INDEX_RESCUE];
			if( IsValidEntRef(ent) )
				type = 2;
		}

		if( type != -1 )
		{
			count++;
			GetEntPropVector(ent, Prop_Data, "m_vecOrigin", vPos);
			PrintToChat(client, "%s%d) Type: %d. Pos: %f %f %f", CHAT_TAG, i+1, type-1, vPos[0], vPos[1], vPos[2]);
		}
	}
	PrintToChat(client, "%sTotal: %d.", CHAT_TAG, count);
	return Plugin_Handled;
}

// ====================================================================================================
//					sm_closet_tele
// ====================================================================================================
public Action CmdSpawnerTele(int client, int args)
{
	if( args == 1 )
	{
		char arg[16];
		GetCmdArg(1, arg, sizeof(arg));
		int index = StringToInt(arg) - 1;
		if( index > -1 && index < MAX_SPAWNS && IsValidEntRef(g_iSpawns[index][INDEX_RESCUE]) )
		{
			float vPos[3];
			GetEntPropVector(g_iSpawns[index][INDEX_RESCUE], Prop_Data, "m_vecOrigin", vPos);
			vPos[2] += 20.0;
			TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
			PrintToChat(client, "%s传送至%d.", CHAT_TAG, index + 1);
			return Plugin_Handled;
		}

		PrintToChat(client, "%s无法找到传送的索引", CHAT_TAG);
	}
	else
		PrintToChat(client, "%sUsage: sm_closet_tele <index 1-%d>.", CHAT_TAG, MAX_SPAWNS);
	return Plugin_Handled;
}

// ====================================================================================================
//					MENU ORIGIN
// ====================================================================================================
public Action CmdSpawnerPos(int client, int args)
{
	ShowMenuPos(client);
	return Plugin_Handled;
}

void ShowMenuPos(int client)
{
	CreateMenus();
	g_hMenuPos.Display(client, MENU_TIME_FOREVER);
}

public int PosMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Select )
	{
		if( index == 8 )
			SaveData(client);
		else
			SetOrigin(client, index);
		ShowMenuPos(client);
	}

	return 0;
}

void SetOrigin(int client, int index)
{
	int entity = GetClientAimTarget(client, false);
	if( entity == -1 )
		return;

	entity = EntIndexToEntRef(entity);

	int arrindex;
	for( int i = 0; i < MAX_SPAWNS; i++ )
	{
		if( g_iSpawns[i][INDEX_MODEL] == entity || g_iSpawns[i][INDEX_DOOR1] == entity )
		{
			entity = g_iSpawns[i][INDEX_MODEL];
			arrindex = i;
			break;
		}
	}

	float vAng[3], vPos[3];
	int entity_door = g_iSpawns[arrindex][INDEX_DOOR1];

	if( IsValidEntRef(entity_door) )
	{
		SetVariantString("!activator");
		AcceptEntityInput(entity_door, "SetParent", entity);

		if( index == 6 || index == 7 )
			GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
		else
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);

		switch( index )
		{
			case 0: vPos[0] += 0.5;
			case 1: vPos[1] += 0.5;
			case 2: vPos[2] += 0.5;
			case 3: vPos[0] -= 0.5;
			case 4: vPos[1] -= 0.5;
			case 5: vPos[2] -= 0.5;
			case 6: vAng[1] -= 90.0;
			case 7: vAng[1] += 90.0;
		}

		if( index == 6 || index == 7 )
		{
			TeleportEntity(entity, NULL_VECTOR, vAng, NULL_VECTOR);
			PrintToChat(client, "%sNew angle: %f %f %f", CHAT_TAG, vAng[0], vAng[1], vAng[2]);
		} else {
			TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
			PrintToChat(client, "%sNew origin: %f %f %f", CHAT_TAG, vPos[0], vPos[1], vPos[2]);
		}

		AcceptEntityInput(entity_door, "ClearParent");
	}
}

void SaveData(int client)
{
	int entity;
	entity = GetClientAimTarget(client, false);
	if( entity == -1 )
		return;

	entity = EntIndexToEntRef(entity);

	int cfgindex, index = -1;
	for( int i = 0; i < MAX_SPAWNS; i++ )
	{
		if( g_iSpawns[i][INDEX_MODEL] == entity || g_iSpawns[i][INDEX_DOOR1] == entity )
		{
			index = i;
			entity = g_iSpawns[i][INDEX_MODEL];
			cfgindex = g_iSpawns[i][INDEX_INDEX];
			break;
		}
	}

	if( index == -1 )
		return;

	// Load config
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
	if( !FileExists(sPath) )
	{
		PrintToChat(client, "%sError: 无法找到配置文件 路径：(\x05%s\x01).", CHAT_TAG, CONFIG_SPAWNS);
		return;
	}

	KeyValues hFile = new KeyValues("spawns");
	if( !hFile.ImportFromFile(sPath) )
	{
		PrintToChat(client, "%sError: 无法加载配置文件 路径：(\x05%s\x01).", CHAT_TAG, sPath);
		delete hFile;
		return;
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !hFile.JumpToKey(sMap) )
	{
		PrintToChat(client, "%sError: 此地图不在配置文件中", CHAT_TAG);
		delete hFile;
		return;
	}

	float vAng[3], vPos[3];
	char sTemp[4];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);

	IntToString(cfgindex, sTemp, sizeof(sTemp));
	if( hFile.JumpToKey(sTemp) )
	{
		hFile.SetVector("ang", vAng);
		hFile.SetVector("pos", vPos);

		// Save cfg
		hFile.Rewind();
		hFile.ExportToFile(sPath);

		PrintToChat(client, "%s坐标和角度已保存到配置文件中, CHAT_TAG);
	}
}

void CreateMenus()
{
	if( g_hMenuPos == null )
	{
		g_hMenuPos = new Menu(PosMenuHandler);
		g_hMenuPos.AddItem("", "X + 0.5");
		g_hMenuPos.AddItem("", "Y + 0.5");
		g_hMenuPos.AddItem("", "Z + 0.5");
		g_hMenuPos.AddItem("", "X - 0.5");
		g_hMenuPos.AddItem("", "Y - 0.5");
		g_hMenuPos.AddItem("", "Z - 0.5");
		g_hMenuPos.AddItem("", "Rotate Left");
		g_hMenuPos.AddItem("", "Rotate Right");
		g_hMenuPos.AddItem("", "SAVE");
		g_hMenuPos.SetTitle("Set Position");
		g_hMenuPos.Pagination = MENU_NO_PAGINATION;
	}
}



// ====================================================================================================
//					STUFF
// ====================================================================================================
bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

void ResetPlugin(bool all = true)
{
	g_bLoaded = false;
	g_iSpawnCount = 0;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;

	if( all )
		for( int i = 0; i < MAX_SPAWNS; i++ )
			RemoveSpawn(i);
}

void RemoveSpawn(int index)
{
	int entity;

	entity = g_iSpawns[index][INDEX_MODEL];
	g_iSpawns[index][INDEX_MODEL] = 0;
	if( IsValidEntRef(entity) )	RemoveEntity(entity);

	entity = g_iSpawns[index][INDEX_DOOR1];
	g_iSpawns[index][INDEX_DOOR1] = 0;
	if( IsValidEntRef(entity) )	RemoveEntity(entity);

	entity = g_iSpawns[index][INDEX_DOOR2];
	g_iSpawns[index][INDEX_DOOR2] = 0;
	if( IsValidEntRef(entity) )	RemoveEntity(entity);

	entity = g_iSpawns[index][INDEX_RESCUE];
	g_iSpawns[index][INDEX_RESCUE] = 0;
	if( IsValidEntRef(entity) )	RemoveEntity(entity);

	g_iSpawns[index][INDEX_INDEX] = 0;
}



// ====================================================================================================
//					POSITION
// ====================================================================================================
float GetGroundHeight(float vPos[3])
{
	float vAng[3];
	Handle trace = TR_TraceRayFilterEx(vPos, view_as<float>({ 90.0, 0.0, 0.0 }), MASK_ALL, RayType_Infinite, _TraceFilter);
	if( TR_DidHit(trace) )
		TR_GetEndPosition(vAng, trace);

	delete trace;
	return vAng[2];
}

// Taken from "[L4D2] Weapon/Zombie Spawner"
// By "Zuko & McFlurry"
bool SetTeleportEndPoint(int client, float vPos[3])
{
	float vAng[3];
	GetClientEyePosition(client, vPos);
	GetClientEyeAngles(client, vAng);

	Handle trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, _TraceFilter);

	if( TR_DidHit(trace) )
	{
		TR_GetEndPosition(vPos, trace);
		GetGroundHeight(vPos);
	}
	else
	{
		delete trace;
		return false;
	}

	delete trace;
	return true;
}

public bool _TraceFilter(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
}