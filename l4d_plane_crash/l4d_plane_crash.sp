/*
*	Plane Crash
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



#define PLUGIN_VERSION		"1.11"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Plane Crash
*	Author	:	SilverShot
*	Descrp	:	Creates the Dead Air Plane Crash on any map.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=181517
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.11 (10-Jan-2023)
	- Changed the method of calling a panic event to support some 3rd party maps with random director names. Thanks to "Qoo_" for reporting.
	- Fixed Temp crashes also spawning the saved crash. Spawning a temporary crash will prevent the trigger box from spawning a saved crash.

1.10 (20-Sep-2022)
	- Added cvar "l4d_plane_crash_chance" to set the chance of a plane crash being created, either saved or using the random cvar. Requested by "Sam B".

1.9 (04-Dec-2021)
	- Changes to fix warnings when compiling on SourceMod 1.11.

1.8 (19-Oct-2021)
	- Small changes to set the damage cvar value to all of the plugins damage entites (some had their own value).

1.7a (18-Sep-2021)
	- L4D2: Data config edited. Changed the position of the "c3m1_plankcountry" crash site.

1.7 (10-May-2020)
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Various changes to tidy up code.

1.6 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.
	- Fixed not precaching "env_shake" which caused stutter on first explosion.

1.5 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
	- Changed cvar "l4d_plane_crash_modes_tog" now supports L4D1.

1.4 (30-Jun-2012)
	- Added cvar "l4d_plane_crash_clear" to remove the plane crash after it stops moving.
	- Command "sm_crash" changed to "sm_plane".
	- Command "sm_crash_clear" changed to "sm_plane_clear".
	- Command "sm_crash_time" changed to "sm_plane_time".
	- Fixed the plane crash not being created when the server starts.

1.3 (10-May-2012)
	- Added "Show Saved Crash" and "Clear Crash" to the menu.

1.2 (01-Apr-2012)
	- Really fixed cvar "l4d_plane_crash_damage" not working.

1.1 (01-Apr-2012)
	- Added command "sm_crash_clear" to clear crashes from the map (does not delete from the config).
	- Added cvar "l4d_plane_crash_angle" to control if the plane spawns in front or crashes in front.
	- Fixed cvar "l4d_plane_crash_damage" not working.

1.0 (30-Mar-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>



#define CVAR_FLAGS			FCVAR_NOTIFY
#define CHAT_TAG			"\x03[PlaneCrash] \x05"
#define CONFIG_SPAWNS		"data/l4d_plane_crash.cfg"
#define MAX_ENTITIES		25

#define MODEL_PLANE01		"models/hybridphysx/precrash_airliner.mdl"
#define MODEL_PLANE02		"models/hybridphysx/airliner_fuselage_secondary_1.mdl"
#define MODEL_PLANE03		"models/hybridphysx/airliner_fuselage_secondary_2.mdl"
#define MODEL_PLANE04		"models/hybridphysx/airliner_fuselage_secondary_3.mdl"
#define MODEL_PLANE05		"models/hybridphysx/airliner_fuselage_secondary_4.mdl"
#define MODEL_PLANE06		"models/hybridphysx/airliner_left_wing_secondary.mdl"
#define MODEL_PLANE07		"models/hybridphysx/airliner_right_wing_secondary_1.mdl"
#define MODEL_PLANE08		"models/hybridphysx/airliner_right_wing_secondary_2.mdl"
#define MODEL_PLANE09		"models/hybridphysx/airliner_tail_secondary.mdl"
#define MODEL_PLANE10		"models/hybridphysx/airliner_primary_debris_4.mdl"
#define MODEL_PLANE11		"models/hybridphysx/airliner_primary_debris_1.mdl"
#define MODEL_PLANE12		"models/hybridphysx/airliner_primary_debris_2.mdl"
#define MODEL_PLANE13		"models/hybridphysx/airliner_primary_debris_3.mdl"
#define MODEL_PLANE14		"models/hybridphysx/airliner_fire_emit1.mdl"
#define MODEL_PLANE15		"models/hybridphysx/airliner_fire_emit2.mdl"
#define MODEL_PLANE16		"models/hybridphysx/airliner_sparks_emit.mdl"
#define MODEL_PLANE17		"models/hybridphysx/airliner_endstate_vcollide_dummy.mdl"
#define MODEL_BOUNDING		"models/props/cs_militia/silo_01.mdl"
#define SOUND_CRASH			"animation/airport_rough_crash_seq.wav"


Handle g_hTimerBeam;
Menu g_hMenuPos, g_hMenuVMaxs, g_hMenuVMins;
ConVar g_hCvarAllow, g_hCvarAngle, g_hCvarClear, g_hCvarChance, g_hCvarDamage, g_hCvarHorde, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarTime;
int g_iCvarAngle, g_iCvarClear, g_iCvarChance, g_iCvarDamage, g_iCvarHorde, g_iEntities[MAX_ENTITIES], g_iHaloMaterial, g_iLaserMaterial, g_iPlayerSpawn, g_iRoundStart, g_iSaved, g_iTrigger;
bool g_bCvarAllow, g_bMapStarted, g_bLeft4Dead2;
float g_fCvarTime;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Plane Crash",
	author = "SilverShot",
	description = "Creates the Dead Air Plane Crash on any map.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=181517"
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
	g_hCvarAllow =			CreateConVar(	"l4d_plane_crash_allow",		"1",			"0=插件关闭, 1=插件开启", CVAR_FLAGS );
	g_hCvarAngle =			CreateConVar(	"l4d_plane_crash_angle",		"1",			"0=在你前面生成飞机（向左坠毁）, 1=生成飞机，使其在你前面坠毁", CVAR_FLAGS );
	g_hCvarChance =			CreateConVar(	"l4d_plane_crash_chance",		"100",			"从保存的配置中多少概率创建飞机坠毁", CVAR_FLAGS );
	g_hCvarClear =			CreateConVar(	"l4d_plane_crash_clear",		"0",			"0=关闭, 在飞机落地后多少秒内移除飞机坠毁", CVAR_FLAGS );
	g_hCvarDamage =			CreateConVar(	"l4d_plane_crash_damage",		"20",			"0=关闭, 如果玩家被一些碎片击中，会对他们造成多少伤害", CVAR_FLAGS );
	g_hCvarHorde =			CreateConVar(	"l4d_plane_crash_horde",		"24",			"0=关闭, 在飞机出现后多长时间触发尸潮", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_plane_crash_modes",		"",				"在这些游戏模式中打开该插件，用逗号分开（没有空格）(空=全部)", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_plane_crash_modes_off",	"",				"在这些游戏模式中关闭该插件，用逗号（没有空格）分开(空=无)", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d_plane_crash_modes_tog",	"0",			" 在这些游戏模式中打开该插件。0=全部, 1=战役, 2=生还者, 4=对抗, 8=清道夫。数字相加", CVAR_FLAGS );
	g_hCvarTime =			CreateConVar(	"l4d_plane_crash_time",			"0",			"0=关闭, 否则会在回合开始后的多少秒内产生崩溃（触发器和自定义地图时间覆盖此cvar）", CVAR_FLAGS );
	CreateConVar(							"l4d_plane_crash_version",		PLUGIN_VERSION, "Plane Crash plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_plane_crash");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAngle.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarChance.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarClear.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDamage.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHorde.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTime.AddChangeHook(ConVarChanged_Cvars);

	RegAdminCmd("sm_plane",			CmdPlaneMenu,	ADMFLAG_ROOT,	"Displays a menu with options to show/save a crash and triggers.");
	RegAdminCmd("sm_plane_clear",	CmdPlaneClear,	ADMFLAG_ROOT,	"Clears crashes from the map (does not delete from the config).");
	RegAdminCmd("sm_plane_time",	CmdPlaneTime,	ADMFLAG_ROOT,	"Sets the time after round start to show a saved crash. sm_plane_time 0 removes the time trigger.");

	g_hMenuVMaxs = new Menu(VMaxsMenuHandler);
	g_hMenuVMaxs.AddItem("", "10 x 10 x 100");
	g_hMenuVMaxs.AddItem("", "25 x 25 x 100");
	g_hMenuVMaxs.AddItem("", "50 x 50 x 100");
	g_hMenuVMaxs.AddItem("", "100 x 100 x 100");
	g_hMenuVMaxs.AddItem("", "150 x 150 x 100");
	g_hMenuVMaxs.AddItem("", "200 x 200 x 100");
	g_hMenuVMaxs.AddItem("", "250 x 250 x 100");
	g_hMenuVMaxs.SetTitle("PlaneCrash - Trigger VMaxs");
	g_hMenuVMaxs.ExitBackButton = true;

	g_hMenuVMins = new Menu(VMinsMenuHandler);
	g_hMenuVMins.AddItem("", "-10 x -10 x 0");
	g_hMenuVMins.AddItem("", "-25 x -25 x 0");
	g_hMenuVMins.AddItem("", "-50 x -50 x 0");
	g_hMenuVMins.AddItem("", "-100 x -100 x 0");
	g_hMenuVMins.AddItem("", "-150 x -150 x 0");
	g_hMenuVMins.AddItem("", "-200 x -200 x 0");
	g_hMenuVMins.AddItem("", "-250 x -250 x 0");
	g_hMenuVMins.SetTitle("PlaneCrash - Trigger VMins");
	g_hMenuVMins.ExitBackButton = true;

	g_hMenuPos = new Menu(PosMenuHandler);
	g_hMenuPos.AddItem("", "X + 1.0");
	g_hMenuPos.AddItem("", "Y + 1.0");
	g_hMenuPos.AddItem("", "Z + 1.0");
	g_hMenuPos.AddItem("", "X - 1.0");
	g_hMenuPos.AddItem("", "Y - 1.0");
	g_hMenuPos.AddItem("", "Z - 1.0");
	g_hMenuPos.AddItem("", "SAVE");
	g_hMenuPos.SetTitle("PlaneCrash - Set Origin");
	g_hMenuPos.ExitBackButton = true;
}

public void OnPluginEnd()
{
	ResetPlugin();
}

public void OnMapStart()
{
	g_bMapStarted = true;

	g_iLaserMaterial = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iHaloMaterial = PrecacheModel("materials/sprites/halo01.vmt");

	PrecacheModel(MODEL_PLANE01, true);
	PrecacheModel(MODEL_PLANE02, true);
	PrecacheModel(MODEL_PLANE03, true);
	PrecacheModel(MODEL_PLANE04, true);
	PrecacheModel(MODEL_PLANE05, true);
	PrecacheModel(MODEL_PLANE06, true);
	PrecacheModel(MODEL_PLANE07, true);
	PrecacheModel(MODEL_PLANE08, true);
	PrecacheModel(MODEL_PLANE09, true);
	PrecacheModel(MODEL_PLANE10, true);
	PrecacheModel(MODEL_PLANE11, true);
	PrecacheModel(MODEL_PLANE12, true);
	PrecacheModel(MODEL_PLANE13, true);
	PrecacheModel(MODEL_PLANE14, true);
	PrecacheModel(MODEL_PLANE15, true);
	PrecacheModel(MODEL_PLANE16, true);
	PrecacheModel(MODEL_PLANE17, true);
	PrecacheModel(MODEL_BOUNDING, true);

	PrecacheSound(SOUND_CRASH, true);



	// Pre-cache env_shake -_- WTF
	int shake  = CreateEntityByName("env_shake");
	if( shake != -1 )
	{
		DispatchKeyValue(shake, "spawnflags", "8");
		DispatchKeyValue(shake, "amplitude", "16.0");
		DispatchKeyValue(shake, "frequency", "1.5");
		DispatchKeyValue(shake, "duration", "0.9");
		DispatchKeyValue(shake, "radius", "50");
		TeleportEntity(shake, view_as<float>({ 0.0, 0.0, -1000.0 }), NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(shake);
		ActivateEntity(shake);
		AcceptEntityInput(shake, "Enable");
		AcceptEntityInput(shake, "StartShake");
		RemoveEdict(shake);
	}
}

public void OnMapEnd()
{
	g_bMapStarted = false;
	ResetPlugin();
}

void ResetPlugin()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;

	int entity = g_iEntities[0];
	g_iEntities[0] = 0;
	if( IsValidEntRef(entity) )
	{
		AcceptEntityInput(entity, "CancelPending");
		AcceptEntityInput(entity, "Disable");
		SetVariantString("OnUser1 !self:Kill::1.0:-1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
	}

	entity = g_iEntities[1];
	g_iEntities[1] = 0;
	if( IsValidEntRef(entity) )
	{
		SetVariantInt(0);
		AcceptEntityInput(entity, "Volume");
		RemoveEntity(entity);
	}

	for( int i = 1; i < MAX_ENTITIES; i++ )
	{
		if( IsValidEntRef(g_iEntities[i]) )
			RemoveEntity(g_iEntities[i]);
		g_iEntities[i] = 0;
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
	g_iCvarAngle = g_hCvarAngle.IntValue;
	g_iCvarChance = g_hCvarChance.IntValue;
	g_iCvarClear = g_hCvarClear.IntValue;
	g_iCvarDamage = g_hCvarDamage.IntValue;
	g_iCvarHorde = g_hCvarHorde.IntValue;
	g_fCvarTime = g_hCvarTime.FloatValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		HookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);

		CreateCrash(0);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		ResetPlugin();
		g_bCvarAllow = false;
		UnhookEvent("player_spawn",		Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		UnhookEvent("round_start",		Event_RoundStart,	EventHookMode_PostNoCopy);
		UnhookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	if( g_bMapStarted == false )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;

	g_iCurrentMode = 0;

	if( iCvarModesTog != 0 )
	{
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
void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ResetPlugin();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(1.0, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(1.0, TimerStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

Action TimerStart(Handle timer)
{
	ResetPlugin();

	// Saved position?
	CreateCrash(0);

	return Plugin_Continue;
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
Action CmdPlaneClear(int client, int args)
{
	ResetPlugin();
	if( client )
		PrintToChat(client, "%s已从此地图中清除", CHAT_TAG);
	else
		PrintToChat(client, "[PlaneCrash]已从此地图中清除");
	return Plugin_Handled;
}

Action CmdPlaneTime(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[PlaneCrash] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	if( args != 1 )
	{
		PrintToChat(client, "%sUsage: sm_plane_time <number of seconds, 0 removes time trigger>", CHAT_TAG);
		return Plugin_Handled;
	}

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);

	if( FileExists(sPath) )
	{
		KeyValues hFile = new KeyValues("crash");
		hFile.ImportFromFile(sPath);

		char sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		if( hFile.JumpToKey(sMap) )
		{
			char sTemp[8];
			GetCmdArg(1, sTemp, sizeof(sTemp));
			int value = StringToInt(sTemp);

			if( value == 0 )
			{
				hFile.DeleteKey("time");
				PrintToChat(client, "%s已删除时间触发器", CHAT_TAG);
			}
			else
			{
				hFile.SetNum("time", value);
				PrintToChat(client, "%s在飞机坠毁触发前节省的秒数", CHAT_TAG);
			}

			hFile.Rewind();
			hFile.ExportToFile(sPath);
		}
		else
		{
			PrintToChat(client, "%s没有保存到此地图", CHAT_TAG);
		}

		delete hFile;
	}

	return Plugin_Handled;
}

Action CmdPlaneMenu(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[PlaneCrash]命令只能用在%s", IsDedicatedServer() ? "游戏中的专用服务器上" : "倾听服务器上的聊天中");
		return Plugin_Handled;
	}

	ShowMenuMain(client);
	return Plugin_Handled;
}

void ShowMenuMain(int client)
{
	Menu hMenu = new Menu(MainMenuHandler);
	hMenu.AddItem("1", "临时创建坠机");

	if( g_iSaved )
		hMenu.AddItem("2", "删除坠机");
	else
		hMenu.AddItem("2", "保存坠机");

	hMenu.AddItem("3", "展示保存的坠机");
	hMenu.AddItem("4", "清除坠机");

	if( IsValidEntRef(g_iTrigger) )
	{
		hMenu.AddItem("5", "删除触发器");
		if( g_hTimerBeam == null )
			hMenu.AddItem("6", "展示触发器");
		else
			hMenu.AddItem("6", "隐藏触发器");
		hMenu.AddItem("7", "VMaxs触发器");
		hMenu.AddItem("8", "VMins触发器");
		hMenu.AddItem("9", "触发器原点");
	}
	else
	{
		hMenu.AddItem("5", "创建触发器");
	}
	hMenu.SetTitle("坠机动画菜单");

	hMenu.Pagination = MENU_NO_PAGINATION;
	hMenu.ExitButton = true;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

int MainMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_End )
	{
		delete menu;
	}
	else if( action == MenuAction_Select )
	{
		char sTemp[4];
		menu.GetItem(index, sTemp, sizeof(sTemp));
		index = StringToInt(sTemp);

		switch( index )
		{
			case 1:
			{
				CreateCrash(client);
				ShowMenuMain(client);
			}
			case 2:
			{
				SaveCrash(client);
				ShowMenuMain(client);
			}
			case 3:
			{
				ResetPlugin();

				if( IsValidEntRef(g_iEntities[0]) )
				{
					PrintToChat(client, "%s生成保存的坠机", CHAT_TAG);
					AcceptEntityInput(g_iEntities[0], "Trigger");
				}
				else
				{
					CreateCrash(0);
					if( IsValidEntRef(g_iEntities[0]) )
					{
						PrintToChat(client, "%s生成保存的坠机", CHAT_TAG);
						AcceptEntityInput(g_iEntities[0], "Trigger");
					}
					else
					{
						PrintToChat(client, "%s没有保存坠机", CHAT_TAG);
					}
				}
				ShowMenuMain(client);
			}
			case 4:
			{
				ResetPlugin();
				ShowMenuMain(client);
			}
			case 5:
			{
				CreateTrigger(client);
				ShowMenuMain(client);
			}
			case 6:
			{
				if( g_hTimerBeam == null )
				{
					g_hTimerBeam = CreateTimer(0.1, TimerBeam, _, TIMER_REPEAT);
				}
				else
				{
					delete g_hTimerBeam;
				}

				ShowMenuMain(client);
			}
			case 7:			g_hMenuVMaxs.Display(client, MENU_TIME_FOREVER);
			case 8:			g_hMenuVMins.Display(client, MENU_TIME_FOREVER);
			case 9:			g_hMenuPos.Display(client, MENU_TIME_FOREVER);
		}
	}

	return 0;
}

int VMaxsMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		switch( index )
		{
			case 0:		SaveMaxMin(1, view_as<float>({ 10.0, 10.0, 100.0 }));
			case 1:		SaveMaxMin(1, view_as<float>({ 25.0, 25.0, 100.0 }));
			case 2:		SaveMaxMin(1, view_as<float>({ 50.0, 50.0, 100.0 }));
			case 3:		SaveMaxMin(1, view_as<float>({ 100.0, 100.0, 100.0 }));
			case 4:		SaveMaxMin(1, view_as<float>({ 150.0, 150.0, 100.0 }));
			case 5:		SaveMaxMin(1, view_as<float>({ 200.0, 200.0, 100.0 }));
			case 6:		SaveMaxMin(1, view_as<float>({ 300.0, 300.0, 100.0 }));
		}

		ShowMenuMain(client);
	}

	return 0;
}

int VMinsMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		switch( index )
		{
			case 0:		SaveMaxMin(2, view_as<float>({ -10.0, -10.0, 0.0 }));
			case 1:		SaveMaxMin(2, view_as<float>({ -25.0, -25.0, 0.0 }));
			case 2:		SaveMaxMin(2, view_as<float>({ -50.0, -50.0, 0.0 }));
			case 3:		SaveMaxMin(2, view_as<float>({ -100.0, -100.0, 0.0 }));
			case 4:		SaveMaxMin(2, view_as<float>({ -150.0, -150.0, 0.0 }));
			case 5:		SaveMaxMin(2, view_as<float>({ -200.0, -200.0, 0.0 }));
			case 6:		SaveMaxMin(2, view_as<float>({ -300.0, -300.0, 0.0 }));
		}

		ShowMenuMain(client);
	}

	return 0;
}

int PosMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Cancel )
	{
		if( index == MenuCancel_ExitBack )
			ShowMenuMain(client);
	}
	else if( action == MenuAction_Select )
	{
		float vPos[3];
		GetEntPropVector(g_iTrigger, Prop_Send, "m_vecOrigin", vPos);

		switch( index )
		{
			case 0: vPos[0] += 1.0;
			case 1: vPos[1] += 1.0;
			case 2: vPos[2] += 1.0;
			case 3: vPos[0] -= 1.0;
			case 4: vPos[1] -= 1.0;
			case 5: vPos[2] -= 1.0;
		}

		if( index != 6 )
		{
			TeleportEntity(g_iTrigger, vPos, NULL_VECTOR, NULL_VECTOR);
		}
		else
		{
			char sPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
			if( !FileExists(sPath) )
				return 0;

			KeyValues hFile = new KeyValues("crash");
			hFile.ImportFromFile(sPath);

			char sMap[64];
			GetCurrentMap(sMap, sizeof(sMap));

			if( hFile.JumpToKey(sMap, true) )
			{
				hFile.SetVector("vpos", vPos);

				hFile.Rewind();
				hFile.ExportToFile(sPath);
				PrintToChat(client, "%s保存触发器原点", CHAT_TAG);
			}
			else
			{
				PrintToChat(client, "%s还未保存触发器原点", CHAT_TAG);
			}

			delete hFile;
		}

		g_hMenuPos.Display(client, MENU_TIME_FOREVER);
	}

	return 0;
}

void SaveCrash(int client)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);

	if( g_iSaved )
	{
		g_iSaved = 0;
		ResetPlugin();

		if( FileExists(sPath) )
		{
			KeyValues hFile = new KeyValues("crash");
			hFile.ImportFromFile(sPath);

			char sMap[64];
			GetCurrentMap(sMap, sizeof(sMap));

			if( hFile.JumpToKey(sMap) )
			{
				hFile.DeleteKey("ang");
				hFile.DeleteKey("pos");

				hFile.Rewind();
				hFile.ExportToFile(sPath);

				PrintToChat(client, "%s已经在这个地图移除", CHAT_TAG);
			}
			else
			{
				PrintToChat(client, "%s还未在这个地图保存", CHAT_TAG);
			}

			delete hFile;
		}
	}
	else
	{
		if( !FileExists(sPath) )
		{
			File hCfg = OpenFile(sPath, "w");
			hCfg.WriteLine("");
			delete hCfg;
		}

		KeyValues hFile = new KeyValues("crash");
		hFile.ImportFromFile(sPath);

		char sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		if( hFile.JumpToKey(sMap, true) )
		{
			g_iSaved = 1;

			float vAng[3], vPos[3];
			GetClientEyeAngles(client, vAng);
			GetClientAbsOrigin(client, vPos);

			hFile.SetFloat("ang", vAng[1]);
			hFile.SetVector("pos", vPos);
			hFile.SetNum("method", g_iCvarAngle);

			hFile.Rewind();
			hFile.ExportToFile(sPath);

			PrintToChat(client, "%s已保存在这个地图", CHAT_TAG);
		}
		else
		{
			PrintToChat(client, "%s还没有保存在这个地图", CHAT_TAG);
		}

		delete hFile;
	}
}

void CreateTrigger(int client)
{
	if( IsValidEntRef(g_iTrigger) == true )
	{
		RemoveEntity(g_iTrigger);
		g_iTrigger = 0;

		char sPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);

		if( FileExists(sPath) )
		{
			KeyValues hFile = new KeyValues("crash");
			hFile.ImportFromFile(sPath);

			char sMap[64];
			GetCurrentMap(sMap, sizeof(sMap));

			if( hFile.JumpToKey(sMap) )
			{
				hFile.DeleteKey("vmax");
				hFile.DeleteKey("vmin");
				hFile.DeleteKey("vpos");

				hFile.Rewind();
				hFile.ExportToFile(sPath);

				PrintToChat(client, "%s在这个地图删除了触发器", CHAT_TAG);
			}
			else
			{
				PrintToChat(client, "%s没有可删除的触发器", CHAT_TAG);
			}

			delete hFile;
		}

		return;
	}

	float vPos[3];
	GetClientAbsOrigin(client, vPos);
	CreateTriggerMultiple(vPos, view_as<float>({ 50.0, 50.0, 100.0}), view_as<float>({ 0.0, 0.0, 0.0 }));

	SaveMaxMin(1, view_as<float>({ 50.0, 50.0, 100.0 }));
	SaveMaxMin(2, view_as<float>({ 0.0, 0.0, 0.0 }));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);

	if( !FileExists(sPath) )
	{
		File hCfg = OpenFile(sPath, "w");
		hCfg.WriteLine("");
		delete hCfg;
	}

	KeyValues hFile = new KeyValues("crash");
	hFile.ImportFromFile(sPath);

	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( hFile.JumpToKey(sMap, true) )
	{
		hFile.SetVector("vpos", vPos);

		hFile.Rewind();
		hFile.ExportToFile(sPath);
		delete hFile;
	}

	if( g_hTimerBeam == null )
	{
		g_hTimerBeam = CreateTimer(0.1, TimerBeam, _, TIMER_REPEAT);
	}
}

void CreateTriggerMultiple(float vPos[3], float vMaxs[3], float vMins[3])
{
	g_iTrigger = CreateEntityByName("trigger_multiple");
	DispatchKeyValue(g_iTrigger, "StartDisabled", "1");
	DispatchKeyValue(g_iTrigger, "spawnflags", "1");
	DispatchKeyValue(g_iTrigger, "entireteam", "0");
	DispatchKeyValue(g_iTrigger, "allowincap", "0");
	DispatchKeyValue(g_iTrigger, "allowghost", "0");

	DispatchSpawn(g_iTrigger);
	SetEntityModel(g_iTrigger, MODEL_BOUNDING);

	SetEntPropVector(g_iTrigger, Prop_Send, "m_vecMaxs", vMaxs);
	SetEntPropVector(g_iTrigger, Prop_Send, "m_vecMins", vMins);
	SetEntProp(g_iTrigger, Prop_Send, "m_nSolidType", 2);

	TeleportEntity(g_iTrigger, vPos, NULL_VECTOR, NULL_VECTOR);

	SetVariantString("OnUser1 !self:Enable::5.0:-1");
	AcceptEntityInput(g_iTrigger, "AddOutput");
	AcceptEntityInput(g_iTrigger, "FireUser1");

	HookSingleEntityOutput(g_iTrigger, "OnStartTouch", OnStartTouch);
	g_iTrigger = EntIndexToEntRef(g_iTrigger);
}

void OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	if( IsClientInGame(activator) && GetClientTeam(activator) == 2 && IsValidEntRef(g_iEntities[0]) )
	{
		AcceptEntityInput(caller, "Disable");

		// Chance to spawn
		if( g_iCvarChance == 100 || GetRandomInt(1, 100) <= g_iCvarChance )
		{
			AcceptEntityInput(g_iEntities[0], "Trigger");
		}
	}
}

void SaveMaxMin(int type, float vVec[3])
{
	if( IsValidEntRef(g_iTrigger) )
	{
		if( type == 1 )
			SetEntPropVector(g_iTrigger, Prop_Send, "m_vecMaxs", vVec);
		else
			SetEntPropVector(g_iTrigger, Prop_Send, "m_vecMins", vVec);
	}

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);

	if( !FileExists(sPath) )
	{
		File hCfg = OpenFile(sPath, "w");
		hCfg.WriteLine("");
		delete hCfg;
	}

	KeyValues hFile = new KeyValues("crash");
	hFile.ImportFromFile(sPath);

	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( hFile.JumpToKey(sMap, true) )
	{
		if( type == 1 )
			hFile.SetVector("vmax", vVec);
		else
			hFile.SetVector("vmin", vVec);

		hFile.Rewind();
		hFile.ExportToFile(sPath);
	}
	delete hFile;
}

Action TimerBeam(Handle timer)
{
	if( IsValidEntRef(g_iTrigger) == false )
	{
		g_hTimerBeam = null;
		return Plugin_Stop;
	}

	float vMaxs[3], vMins[3], vPos[3];
	GetEntPropVector(g_iTrigger, Prop_Send, "m_vecMaxs", vMaxs);
	GetEntPropVector(g_iTrigger, Prop_Send, "m_vecMins", vMins);
	GetEntPropVector(g_iTrigger, Prop_Send, "m_vecOrigin", vPos);
	AddVectors(vPos, vMaxs, vMaxs);
	AddVectors(vPos, vMins, vMins);
	TE_SendBox(vMins, vMaxs);

	return Plugin_Continue;
}

void TE_SendBox(float vMins[3], float vMaxs[3])
{
	float vPos1[3], vPos2[3], vPos3[3], vPos4[3], vPos5[3], vPos6[3];
	vPos1 = vMaxs;
	vPos1[0] = vMins[0];
	vPos2 = vMaxs;
	vPos2[1] = vMins[1];
	vPos3 = vMaxs;
	vPos3[2] = vMins[2];
	vPos4 = vMins;
	vPos4[0] = vMaxs[0];
	vPos5 = vMins;
	vPos5[1] = vMaxs[1];
	vPos6 = vMins;
	vPos6[2] = vMaxs[2];
	TE_SendBeam(vMaxs, vPos1);
	TE_SendBeam(vMaxs, vPos2);
	TE_SendBeam(vMaxs, vPos3);
	TE_SendBeam(vPos6, vPos1);
	TE_SendBeam(vPos6, vPos2);
	TE_SendBeam(vPos6, vMins);
	TE_SendBeam(vPos4, vMins);
	TE_SendBeam(vPos5, vMins);
	TE_SendBeam(vPos5, vPos1);
	TE_SendBeam(vPos5, vPos3);
	TE_SendBeam(vPos4, vPos3);
	TE_SendBeam(vPos4, vPos2);
}

void TE_SendBeam(const float vMins[3], const float vMaxs[3])
{
	TE_SetupBeamPoints(vMins, vMaxs, g_iLaserMaterial, g_iHaloMaterial, 0, 0, 0.2, 1.0, 1.0, 1, 0.0, { 255, 0, 0, 255 }, 0);
	TE_SendToAll();
}

void CreateCrash(int client)
{
	float vPos[3], vAng[3];
	int time;
	int method;

	if( client > 0 )
	{
		// Manual spawned
		method = g_iCvarAngle;
		GetClientAbsOrigin(client, vPos);
		GetClientEyeAngles(client, vAng);

		ResetPlugin();
	}
	else
	{
		// Map config
		if( !client )
		{
			g_iSaved = 0;

			char sPath[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_SPAWNS);
			if( !FileExists(sPath) )
				return;

			KeyValues hFile = new KeyValues("crash");
			hFile.ImportFromFile(sPath);

			char sMap[64];
			GetCurrentMap(sMap, sizeof(sMap));

			if( !hFile.JumpToKey(sMap) )
			{
				delete hFile;
				return;
			}

			time = hFile.GetNum("time");
			method = hFile.GetNum("method");

			if( time == 0 )
			{
				float vVec[3];
				hFile.GetVector("vpos", vVec, view_as<float>({ 999.9, 999.9, 999.9 }));

				if( vVec[0] != 999.9 && vVec[1] != 999.9 )
				{
					float vMaxs[3], vMins[3];
					hFile.GetVector("vmax", vMaxs);
					hFile.GetVector("vmin", vMins);

					if( IsValidEntRef(g_iTrigger) )
					{
						RemoveEntity(g_iTrigger);
						g_iTrigger = 0;
					}

					CreateTriggerMultiple(vVec, vMaxs, vMins);
				}

				time = -1;
			}

			vAng[1] = hFile.GetFloat("ang");
			hFile.GetVector("pos", vPos, view_as<float>({ 999.9, 999.9, 999.9 }));

			if( vPos[0] == 999.9 && vPos[1] == 999.9 )
			{
				delete hFile;
				return;
			}

			delete hFile;
		}
	}


	CreatePlaneCrash(vPos, vAng, method);


	if( client )
	{
		AcceptEntityInput(g_iEntities[0], "Trigger");
	}
	else
	{
		g_iSaved = 1;

		if( time != -1 && (time || g_fCvarTime) )
		{
			char sTemp[64];

			if( time )
				Format(sTemp, sizeof(sTemp), "OnUser1 silver_planecrash_trigger:Trigger::%d:-1", time);
			else
				Format(sTemp, sizeof(sTemp), "OnUser1 silver_planecrash_trigger:Trigger::%0.1f:-1", g_fCvarTime);

			SetVariantString(sTemp);
			AcceptEntityInput(g_iEntities[0], "AddOutput");
			AcceptEntityInput(g_iEntities[0], "FireUser1");
		}
	}
}

void CreatePlaneCrash(float vPos[3], float vAng[3], int method)
{
	float vLoc[3];

	if( method == 0 )
	{
		vLoc = vPos;
		vLoc[0] += vAng[1] * 1200.0 / 180.0;
		vLoc[1] += vAng[1] * 1200.0 / 180.0;
		vLoc[2] -= 50.0;
		vAng[0] = 0.0;
		vAng[1] += 75.0;
		vAng[2] = 0.0;
	}
	else
	{
		vLoc = vPos;

		float p, x, y;

		if( vAng[1] <= -90.0 )
		{
			p = (vAng[1] * -1.0) * 100 / 90;
			x = -1500 * (200 - p) / 100;
			y = -1500 * (100 - p) / 100;
		}
		else if( vAng[1] <= 0.0 )
		{
			p = (vAng[1] * -1.0) * 100 / 90;
			x = -1500 * p / 100;
			y = -1500 * (100 - p) / 100;
		}
		else if( vAng[1] <= 90.0 )
		{
			p = vAng[1] * 100 / 90;
			x = 1500 * p / 100;
			y = -1500 * (100 - p) / 100;
		}
		else if( vAng[1] <= 180.0 )
		{
			p = vAng[1] * 100 / 90;
			x = 1500 * (200 - p) / 100;
			y = -1500 * (100 - p) / 100;
		}

		vLoc[0] += x;
		vLoc[1] += y;
		vLoc[2] -= 50.0;
		vAng[0] = 0.0;
		vAng[1] += 30;
		vAng[2] = 0.0;
	}

	vPos = vLoc;

	int count;
	int entity;

	entity = CreateEntityByName("logic_relay");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_trigger");
	DispatchKeyValue(entity, "spawnflags", "1");
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	g_iEntities[count++] = entity;

	if( g_iCvarHorde )
	{
		HookSingleEntityOutput(entity, "OnTrigger", OnTriggerCrash);

		/* Some maps have different director names, so using hook above with different methods
		char sTemp[64];
		Format(sTemp, sizeof(sTemp), "OnTrigger director:ForcePanicEvent::%d:-1", g_iCvarHorde);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnTrigger @director:ForcePanicEvent::%d:-1", g_iCvarHorde);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		*/
	}

	SetVariantString("OnTrigger silver_planecrash_collision:FireUser2::27:-1");
	AcceptEntityInput(entity, "AddOutput");

	SetVariantString("OnTrigger silver_plane_crash_sound:PlaySound::0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_crash_shake:StartShake::20.5:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_crash_shake:StartShake::23:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_crash_shake:StartShake::24:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_crash_shake:StartShake::26:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_crash_shake:Kill::30:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_precrash:SetAnimation:approach:0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_precrash:Kill::15:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_precrash:Kill::16:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_plane_precrash:TurnOn::0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash:SetAnimation:idleOuttaMap:0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash:SetAnimation:boom:14.95:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash:TurnOn::14:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_tailsection:SetAnimation:boom:14.95:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_tailsection:SetAnimation:idleOuttaMap:0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_tailsection:TurnOn::14:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_engine:SetAnimation:boom:14.95:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_engine:SetAnimation:idleOuttaMap:0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_engine:TurnOn::14:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_wing:SetAnimation:idleOuttaMap:0:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_wing:SetAnimation:boom:14.95:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_wing:TurnOn::14:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_hurt_tail:Enable::15:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_hurt_tail:Kill::27:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_hurt_engine:Enable::15:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_hurt_engine:Kill::27:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_hurt_wing:Enable::15:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_hurt_wing:Kill::27:-1");
	AcceptEntityInput(entity, "AddOutput");
	SetVariantString("OnTrigger silver_planecrash_emitters:SetAnimation:boom:14.95:-1");
	AcceptEntityInput(entity, "AddOutput");
	DispatchSpawn(entity);


	entity = CreateEntityByName("ambient_generic");
	DispatchKeyValue(entity, "targetname", "silver_plane_crash_sound");
	DispatchKeyValue(entity, "volume", "2");
	DispatchKeyValue(entity, "spawnflags", "49");
	DispatchKeyValue(entity, "radius", "3250");
	DispatchKeyValue(entity, "pitchstart", "100");
	DispatchKeyValue(entity, "pitch", "100");
	DispatchKeyValue(entity, "message", "airport.planecrash");
	DispatchSpawn(entity);
	ActivateEntity(entity);
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("env_shake");
	DispatchKeyValue(entity, "targetname", "silver_plane_crash_shake");
	DispatchKeyValue(entity, "spawnflags", "1");
	DispatchKeyValue(entity, "duration", "4");
	DispatchKeyValue(entity, "amplitude", "4");
	DispatchKeyValue(entity, "frequency", "100");
	DispatchKeyValue(entity, "radius", "3117");
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, NULL_VECTOR, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_plane_precrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE01);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE02);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE03);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE04);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE05);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE06);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE07);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE08);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE09);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE10);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_tailsection");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE11);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_engine");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE12);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_wing");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "disableshadows", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE13);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_emitters");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE14);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_emitters");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE15);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_emitters");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "0");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "model", MODEL_PLANE16);
	DispatchSpawn(entity);
	TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
	g_iEntities[count++] = EntIndexToEntRef(entity);


	vPos = vLoc;
	entity = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(entity, "targetname", "silver_planecrash_collision");
	DispatchKeyValue(entity, "spawnflags", "0");
	DispatchKeyValue(entity, "solid", "6");
	DispatchKeyValue(entity, "StartDisabled", "1");
	DispatchKeyValue(entity, "RandomAnimation", "0");
	DispatchKeyValue(entity, "model", MODEL_PLANE17);
	DispatchSpawn(entity);
	vPos[2] += 9999.9;
	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
	vPos[2] -= 9999.9;
	g_iEntities[count++] = EntIndexToEntRef(entity);
	HookSingleEntityOutput(entity, "OnUser2", OnUserCollision, true);


	if( g_iCvarDamage )
	{
		char sTemp[6];
		IntToString(g_iCvarDamage, sTemp, sizeof(sTemp));

		entity = CreateEntityByName("trigger_hurt");
		DispatchKeyValue(entity, "targetname", "silver_planecrash_hurt_tail");
		DispatchKeyValue(entity, "spawnflags", "3");
		DispatchKeyValue(entity, "damagetype", "1");
		DispatchKeyValue(entity, "damage", sTemp);
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Disable");

		SetEntityModel(entity, MODEL_BOUNDING);
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", view_as<float>({ 300.0, 300.0, 300.0 }));
		SetEntPropVector(entity, Prop_Send, "m_vecMins", view_as<float>({ -300.0, -300.0, -300.0 }));
		SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
		TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);

		SetVariantString("silver_planecrash_tailsection");
		AcceptEntityInput(entity, "SetParent");
		SetVariantString("HullDebris1");
		AcceptEntityInput(entity, "SetParentAttachment");
		g_iEntities[count++] = EntIndexToEntRef(entity);


		entity = CreateEntityByName("trigger_hurt");
		DispatchKeyValue(entity, "targetname", "silver_planecrash_hurt_engine");
		DispatchKeyValue(entity, "spawnflags", "3");
		DispatchKeyValue(entity, "damagetype", "1");
		DispatchKeyValue(entity, "damage", sTemp);
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Disable");

		SetEntityModel(entity, MODEL_BOUNDING);
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", view_as<float>({ 300.0, 300.0, 300.0 }));
		SetEntPropVector(entity, Prop_Send, "m_vecMins", view_as<float>({ -300.0, -300.0, -300.0 }));
		SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
		TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);

		SetVariantString("silver_planecrash_engine");
		AcceptEntityInput(entity, "SetParent");
		SetVariantString("particleEmitter2");
		AcceptEntityInput(entity, "SetParentAttachment");
		g_iEntities[count++] = EntIndexToEntRef(entity);


		entity = CreateEntityByName("trigger_hurt");
		DispatchKeyValue(entity, "targetname", "silver_planecrash_hurt_wing");
		DispatchKeyValue(entity, "spawnflags", "3");
		DispatchKeyValue(entity, "damagetype", "1");
		DispatchKeyValue(entity, "damage", sTemp);
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Disable");

		SetEntityModel(entity, MODEL_BOUNDING);
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", view_as<float>({ 300.0, 300.0, 300.0 }));
		SetEntPropVector(entity, Prop_Send, "m_vecMins", view_as<float>({ -300.0, -300.0, -300.0 }));
		SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
		TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);

		SetVariantString("silver_planecrash_wing");
		AcceptEntityInput(entity, "SetParent");
		SetVariantString("new_spark_joint_1");
		AcceptEntityInput(entity, "SetParentAttachment");
		g_iEntities[count++] = EntIndexToEntRef(entity);
	}
}

void OnTriggerCrash(const char[] output, int caller, int activator, float delay)
{
	if( g_iCvarHorde )
	{
		if( caller > 0 ) caller = EntIndexToEntRef(caller);

		if( caller == g_iEntities[0] )
		{
			CreateTimer(float(g_iCvarHorde), TimerHorde, g_iEntities[2], TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

Action TimerHorde(Handle timer, int entity)
{
	if( EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
	{
		if( g_bLeft4Dead2 )
		{
			static int director = INVALID_ENT_REFERENCE;

			if( director == INVALID_ENT_REFERENCE || EntRefToEntIndex(director) == INVALID_ENT_REFERENCE )
			{
				director = FindEntityByClassname(-1, "info_director");
				if( director != INVALID_ENT_REFERENCE )
				{
					director = EntIndexToEntRef(director);
				}
			}

			if( director != INVALID_ENT_REFERENCE )
			{
				AcceptEntityInput(director, "ForcePanicEvent");
				return Plugin_Continue;
			}
		}

		int flags = GetCommandFlags("director_force_panic_event");
		SetCommandFlags("director_force_panic_event", flags & ~FCVAR_CHEAT);
		ServerCommand("director_force_panic_event");
		SetCommandFlags("director_force_panic_event", flags);
	}

	return Plugin_Continue;
}

void OnUserCollision(const char[] output, int caller, int activator, float delay)
{
	if( g_iCvarClear )
		CreateTimer(float(g_iCvarClear), TimerReset);

	float vPos[3];
	GetEntPropVector(caller, Prop_Send, "m_vecOrigin", vPos);
	vPos[2] -= 9999.9;
	TeleportEntity(caller, vPos, NULL_VECTOR, NULL_VECTOR);
}

Action TimerReset(Handle timer)
{
	ResetPlugin();
	return Plugin_Continue;
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}