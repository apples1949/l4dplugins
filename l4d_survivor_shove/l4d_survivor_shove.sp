/*
*	Survivor Shove
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



#define PLUGIN_VERSION 		"1.15"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Survivor Shove
*	Author	:	SilverShot
*	Descrp	:	Allows shoving to stagger survivors. Stumbles a survivor when shoved by another survivor.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=318694
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.15 (04-Aug-2022)
	- Added cvar "l4d_survivor_shove_vocal_type" to control the type of vocalization. Thanks to "Shadowysn" for adding.

1.14 (14-Jul-2022)
	- Added cvar "l4d_survivor_shove_keys" to control the keybind used for shoving. Requested by "yabi".

1.13 (23-Apr-2022)
	- Fixed an error when the "Gear Transfer" plugin is not used.

1.12 (01-Mar-2022)
	- Added cvar "l4d_survivor_shove_bots" to target who can be shoved. Requested by "TrueDarkness".

1.11 (18-Sep-2021)
	- Now blocks shoving when holding a "First Aid Kit", "Pain Pills" or "Adrenaline". Requested by "Eocene".
	- May sometimes still be shoved when transferring "Pain Pills" or "Adrenaline" since the game delays the event based on distance.
	- The only solution would be adding a delay into the plugin, and this would be very noticeable visually.

	- Now blocks shoving when holding a Grenade, Upgrade Ammo or a Defibrillator when allowed to transfer in "Gear Transfer" plugins "l4d_gear_transfer_types_real" cvar list.

	- When using "Gear Transfer" plugin recommend updating to 2.17 or newer to fix compatibility issues.

1.10 (25-Jul-2021)
	- Now automatically detects "Gear Transfer" plugin and prevents shoving if using an item that can be transferred. Requested by "AI0702".
	- Plugin compatibility with "Gear Transfer" plugin (version 1.14 or newer).

1.9 (12-May-2021)
	- Added cvar "l4d_survivor_shove_start" to set shoving on/off by default when joining the server.

1.8 (06-Mar-2021)
	- Fixed compile error. Thanks to "Krufftys Killers" for reporting.

1.7 (04-Mar-2021)
	- Added cvar "l4d_survivor_shove_vocalize" to vocalize when being shoved. Requested by "Striker black".

1.6 (15-Feb-2021)
	- Added cvar "l4d_survivor_shove_delay" to set a timeout for when someone can shove again. Requested by "RDiver".
	- Fixed the feature from not working when the plugin was late loaded.

1.5 (10-May-2020)
	- Added better error log message when gamedata file is missing.
	- Extra checks to prevent "IsAllowedGameMode" throwing errors.
	- Various changes to tidy up code.

1.4 (01-Apr-2020)
	- Fixed "IsAllowedGameMode" from throwing errors when the "_tog" cvar was changed before MapStart.

1.3b (07-Jan-2020)
	- Gamedata change only.
	- Fixed crashing in Linux L4D1 due to a wrong signature. Thanks to "Dragokas" for reporting.

1.3 (03-Dec-2019)
	- Added command "sm_sshove" to turn on/off the feature for individual clients. Requested by "Tonblader".
	- Potentially fixed shove not working with no flags specified.

1.2 (20-Sep-2019)
	- Changed flags cvar, now requires clients to only have 1 of the specified flags.

1.1 (17-Sep-2019)
	- Added cvar "l4d_survivor_shove_flags" to control who has access to the feature.

1.0 (15-Sep-2019)
	- Initial release.

========================================================================================

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	Thanks to "AtomicStryker" for "L4D2 Vocalize ANYTHING"
	https://forums.alliedmods.net/showthread.php?t=122270

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d_survivor_shove"


ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarBots, g_hCvarDelay, g_hCvarFlags, g_hCvarKey, g_hCvarStart, g_hCvarVoca, g_hCvarVocaType, g_hGearTransferReal;
bool g_bCvarAllow, g_bMapStarted, g_bLateLoad, g_bLeft4Dead2, g_bGearTransfer, g_bCanShove[MAXPLAYERS + 1] = {true, ...};
float g_fTimeout[MAXPLAYERS + 1];
Handle g_hConfStagger;
StringMap g_smBlocked;

// From Gear Transfer
int g_iGearTypes;
enum
{
	TYPE_ADREN	= (1<<0),
	TYPE_PILLS	= (1<<1),
	TYPE_MOLO	= (1<<2),
	TYPE_PIPE	= (1<<3),
	TYPE_VOMIT	= (1<<4),
	TYPE_FIRST	= (1<<5),
	TYPE_EXPLO	= (1<<6),
	TYPE_INCEN	= (1<<7),
	TYPE_DEFIB	= (1<<8)
}



// Vocalize for Left 4 Dead2
static const char g_Coach[][] =
{
	"scenes/coach/deathscream07.vcd", "scenes/coach/deathscream08.vcd", "scenes/coach/deathscream09.vcd"
};
static const char g_Ellis[][] =
{
	"scenes/mechanic/deathscream04.vcd", "scenes/mechanic/deathscream05.vcd",
};
static const char g_Nick[][] =
{
	"scenes/gambler/deathscream03.vcd", "scenes/gambler/deathscream05.vcd"
};
static const char g_Rochelle[][] =
{
	"scenes/producer/deathscream01.vcd", "scenes/producer/hurtcritical03.vcd", "scenes/producer/hurtcritical04.vcd"
};

// Vocalize for Left 4 Dead
static const char g_Bill[][] =
{
	"scenes/NamVet/FallShort03.vcd", "scenes/NamVet/FallShort02.vcd", "scenes/NamVet/FallShort01.vcd"
};
static const char g_Francis[][] =
{
	"scenes/Biker/FallShort03.vcd", "scenes/Biker/FallShort02.vcd", "scenes/Biker/FallShort01.vcd"
};
static const char g_Louis[][] =
{
	"scenes/Manager/FallShort03.vcd", "scenes/Manager/FallShort04.vcd", "scenes/Manager/FallShort01.vcd"
};
static const char g_Zoey[][] =
{
	"scenes/TeenGirl/FallShort01.vcd", "scenes/TeenGirl/FallShort02.vcd", "scenes/TeenGirl/FallShort03.vcd"
};



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Survivor Shove",
	author = "SilverShot",
	description = "Allows shoving to stagger survivors. Stumbles a survivor when shoved by another survivor.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=318694"
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

	g_bLateLoad = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	// GAMEDATA
	if( !g_bLeft4Dead2 )
	{
		// Stagger: SDKCall method
		char sPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
		if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

		GameData hGameData = new GameData(GAMEDATA);
		if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

		StartPrepSDKCall(SDKCall_Entity);
		if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::OnStaggered") == false )
			SetFailState("Could not load the 'CTerrorPlayer::OnStaggered' gamedata signature.");

		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		g_hConfStagger = EndPrepSDKCall();
		if( g_hConfStagger == null )
			SetFailState("Could not prep the 'CTerrorPlayer::OnStaggered' function.");

		delete hGameData;
	}

	// CVARS
	g_hCvarAllow = CreateConVar(	"l4d_survivor_shove_allow",			"1",			"0=关闭插件，1=打开插件", CVAR_FLAGS );
	g_hCvarBots = CreateConVar(		"l4d_survivor_shove_bots",			"0",			"谁可以被推动。0=所有人。1=仅机器人。2=仅生还者", CVAR_FLAGS );
	g_hCvarDelay = CreateConVar(	"l4d_survivor_shove_delay",			"0",			"0=随意推动 多少秒后才会有人再次推动", CVAR_FLAGS, true, 0.0 );
	g_hCvarFlags = CreateConVar(	"l4d_survivor_shove_flags",			"",			"空 =全部玩家。拥有这些标志的玩家可以使用推动功能", CVAR_FLAGS );
	g_hCvarKey = CreateConVar(		"l4d_survivor_shove_keys",			"1",			"1=推键 2=推键+使用键 如何推动玩家", CVAR_FLAGS );
	g_hCvarStart = CreateConVar(	"l4d_survivor_shove_start",			"1",			"0=关闭 1=开启 当玩家加入时，推动功能应该被打开还是关闭", CVAR_FLAGS );
	g_hCvarVoca = CreateConVar(		"l4d_survivor_shove_vocalize",		"50",			"0=Off. 0=关闭。被推动的幸存者发出尖叫的概率", CVAR_FLAGS );
	g_hCvarVocaType = CreateConVar(	"l4d_survivor_shove_vocal_type",	"1",			"0=D死亡尖叫声 1=痛苦尖叫声。幸存者将进行的发声类型", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(	"l4d_survivor_shove_modes",			"",				"在这些游戏模式下打开插件，用逗号分隔（没有空格）（空=全部）", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(	"l4d_survivor_shove_modes_off",		"",				"在这些游戏模式下关闭插件，用逗号分隔（没有空格）（空=无）", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(	"l4d_survivor_shove_modes_tog",		"0",			"T在这些游戏模式中打开插件。0=全部，1=战役，2=生还者，4=对抗，8=清道夫。将数字相加", CVAR_FLAGS );
	CreateConVar(					"l4d_survivor_shove_version",		PLUGIN_VERSION,	"Survivor Shove plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,			"l4d_survivor_shove");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);

	// CMDS
	RegAdminCmd("sm_sshove", CmdShove, ADMFLAG_ROOT, "Turn on/off ability to shove. No args = toggle. Usage: sm_sshove [optional 0=Off. 1=On.]");

	if( g_bLateLoad )
	{
		for( int i = 0; i <= MAXPLAYERS; i++ )
		{
			g_bCanShove[i] = g_hCvarStart.BoolValue;
		}
	}
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
Action CmdShove(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Shove] Command can only be used %s", IsDedicatedServer() ? "in game on a Dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	if( args == 0 )
		g_bCanShove[client] = !g_bCanShove[client];
	else
	{
		char temp[4];
		GetCmdArg(1, temp, sizeof(temp));
		g_bCanShove[client] = view_as<bool>(StringToInt(temp));
	}

	ReplyToCommand(client, "[Shove] Turned %s.", g_bCanShove[client] ? "On" : "Off");
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	g_bCanShove[client] = g_hCvarStart.BoolValue;
	g_fTimeout[client] = 0.0;
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnMapStart()
{
	g_bMapStarted = true;

	// Precache sounds
	char temp[PLATFORM_MAX_PATH];

	for( int i = 0; i < sizeof(g_Coach); i++ )
	{
		strcopy(temp, sizeof(temp), g_Coach[i]);
		ReplaceStringEx(temp, sizeof(temp), ".vcd", ".wav");
		ReplaceStringEx(temp, sizeof(temp), "scenes/", "player/survivor/voice/");
		PrecacheSound(temp);
	}

	for( int i = 0; i < sizeof(g_Nick); i++ )
	{
		strcopy(temp, sizeof(temp), g_Nick[i]);
		ReplaceStringEx(temp, sizeof(temp), ".vcd", ".wav");
		ReplaceStringEx(temp, sizeof(temp), "scenes/", "player/survivor/voice/");
		PrecacheSound(temp);
	}

	for( int i = 0; i < sizeof(g_Ellis); i++ )
	{
		strcopy(temp, sizeof(temp), g_Ellis[i]);
		ReplaceStringEx(temp, sizeof(temp), ".vcd", ".wav");
		ReplaceStringEx(temp, sizeof(temp), "scenes/", "player/survivor/voice/");
		PrecacheSound(temp);
	}

	for( int i = 0; i < sizeof(g_Rochelle); i++ )
	{
		strcopy(temp, sizeof(temp), g_Rochelle[i]);
		ReplaceStringEx(temp, sizeof(temp), ".vcd", ".wav");
		ReplaceStringEx(temp, sizeof(temp), "scenes/", "player/survivor/voice/");
		PrecacheSound(temp);
	}

	for( int i = 0; i < sizeof(g_Bill); i++ )
	{
		strcopy(temp, sizeof(temp), g_Bill[i]);
		ReplaceStringEx(temp, sizeof(temp), ".vcd", ".wav");
		ReplaceStringEx(temp, sizeof(temp), "scenes/", "player/survivor/voice/");
		PrecacheSound(temp);
	}

	for( int i = 0; i < sizeof(g_Francis); i++ )
	{
		strcopy(temp, sizeof(temp), g_Francis[i]);
		ReplaceStringEx(temp, sizeof(temp), ".vcd", ".wav");
		ReplaceStringEx(temp, sizeof(temp), "scenes/", "player/survivor/voice/");
		PrecacheSound(temp);
	}

	for( int i = 0; i < sizeof(g_Louis); i++ )
	{
		strcopy(temp, sizeof(temp), g_Louis[i]);
		ReplaceStringEx(temp, sizeof(temp), ".vcd", ".wav");
		ReplaceStringEx(temp, sizeof(temp), "scenes/", "player/survivor/voice/");
		PrecacheSound(temp);
	}

	for( int i = 0; i < sizeof(g_Zoey); i++ )
	{
		strcopy(temp, sizeof(temp), g_Zoey[i]);
		ReplaceStringEx(temp, sizeof(temp), ".vcd", ".wav");
		ReplaceStringEx(temp, sizeof(temp), "scenes/", "player/survivor/voice/");
		PrecacheSound(temp);
	}
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

public void OnConfigsExecuted()
{
	// Detected Gear Transfer plugin.
	if( g_bGearTransfer == false )
	{
		g_bGearTransfer = FindConVar("l4d_gear_transfer_version") != null;
	}

	// Get Gear Transfer types allowed
	if( g_hGearTransferReal == null )
	{
		g_hGearTransferReal = FindConVar("l4d_gear_transfer_types_real");
		if( g_hGearTransferReal != null ) g_hGearTransferReal.AddChangeHook(ConVarChanged_Gear);
	}

	IsAllowed();
	GetGearTransferCvar();
}

void ConVarChanged_Gear(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetGearTransferCvar();
}

void GetGearTransferCvar()
{
	delete g_smBlocked;
	g_smBlocked = new StringMap();

	// Always block these
	if( g_bLeft4Dead2 )
		g_smBlocked.SetValue("weapon_adrenaline", true);
	g_smBlocked.SetValue("weapon_pain_pills", true);
	g_smBlocked.SetValue("weapon_first_aid_kit", true);

	// Block items Gear Transfer allows to transfer
	if( g_hGearTransferReal != null )
	{
		g_iGearTypes = GetEnum(g_hGearTransferReal);

		if( g_iGearTypes )
		{
			if( g_iGearTypes & TYPE_MOLO )			g_smBlocked.SetValue("weapon_molotov", true);
			if( g_iGearTypes & TYPE_PIPE )			g_smBlocked.SetValue("weapon_pipe_bomb", true);

			if( g_bLeft4Dead2 )
			{
				if( g_iGearTypes & TYPE_VOMIT )		g_smBlocked.SetValue("weapon_vomitjar", true);
				if( g_iGearTypes & TYPE_EXPLO )		g_smBlocked.SetValue("weapon_upgradepack_explosive", true);
				if( g_iGearTypes & TYPE_INCEN )		g_smBlocked.SetValue("weapon_upgradepack_incendiary", true);
				if( g_iGearTypes & TYPE_DEFIB )		g_smBlocked.SetValue("weapon_defibrillator", true);
			}
		}
	}
}

int GetEnum(ConVar cvar)
{
	int val;
	static char num[2], temp[10];
	cvar.GetString(temp, sizeof(temp));

	for( int i = 0; i < strlen(temp); i++ )
	{
		num[0] = temp[i];
		if( StringToInt(num) != 0 )
			val += (1<<StringToInt(num)-1);
	}

	return val;
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
		HookEvent("player_shoved",		Event_PlayerShoved);

		if( g_bLeft4Dead2 )
		{
			HookEvent("weapon_drop",	Event_WeaponDrop); // L4D2 only event
		} else {
			HookEvent("weapon_given",	Event_WeaponGiven); // L4D1 event
		}
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvent("player_shoved",	Event_PlayerShoved);

		if( g_bLeft4Dead2 )
		{
			UnhookEvent("weapon_drop",	Event_WeaponDrop); // L4D2 only event
		} else {
			UnhookEvent("weapon_given",	Event_WeaponGiven); // L4D1 event
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
//					FORWARDS - From "Gear Transfer" plugin
// ====================================================================================================
public void GearTransfer_OnWeaponGive(int client, int target, int item)
{
	g_fTimeout[client] = GetGameTime() + 0.5;
}

public void GearTransfer_OnWeaponGrab(int client, int target, int item)
{
	g_fTimeout[client] = GetGameTime() + 0.5;
}

public void GearTransfer_OnWeaponSwap(int client, int target, int itemGiven, int itemTaken)
{
	g_fTimeout[client] = GetGameTime() + 0.5;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
// L4D1: Block shove when transfer of pills
void Event_WeaponGiven(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("giver"));
	if( client )
	{
		g_fTimeout[client] = GetGameTime() + 0.5;
	}
}

// L4D2: Block shove when transfer of pills/adrenaline
void Event_WeaponDrop(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client )
	{
		static char sTemp[8];
		event.GetString("item", sTemp, sizeof(sTemp));
		if( strncmp(sTemp, "pain", 4) == 0 || strncmp(sTemp, "adre", 4) == 0 )
		{
			g_fTimeout[client] = GetGameTime() + 0.5;
		}
	}
}

void Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");

	int bots = g_hCvarBots.IntValue;
	if( bots )
	{
		int target = GetClientOfUserId(userid);
		if( IsFakeClient(target) )
		{
			if( bots == 2 ) return; // Humans only
		} else {
			if( bots == 1 ) return; // Bots only
		}
	}

	int client = event.GetInt("attacker");
	if( g_hCvarKey.IntValue == 2 )
	{
		int buttons = GetClientButtons(GetClientOfUserId(client));
		if( buttons & IN_USE != IN_USE )
		{
			return;
		}
	}

	DataPack hPack = new DataPack();
	hPack.WriteCell(client);
	hPack.WriteCell(userid);

	RequestFrame(OnFramShove, hPack);
}

void OnFramShove(DataPack hPack)
{
	hPack.Reset();

	int client = hPack.ReadCell();
	int userid = hPack.ReadCell();

	delete hPack;

	client = GetClientOfUserId(client);
	int target = GetClientOfUserId(userid);

	if( !client || !target || !IsClientInGame(client) || !IsClientInGame(target) )
		return;

	// Turned off.
	if( !g_bCanShove[client] ) return;

	// Timeout
	if( g_fTimeout[client] > GetGameTime() )
		return;

	g_fTimeout[client] = 0.0;

	// Flags
	bool access;
	int flags;
	static char sTemp[32];
	g_hCvarFlags.GetString(sTemp, sizeof(sTemp));

	if( sTemp[0] == 0 )
		access = true;
	else
	{
		char sVal[2];
		for( int i = 0; i < strlen(sTemp); i++ )
		{
			sVal[0] = sTemp[i];
			flags = ReadFlagString(sVal);

			if( CheckCommandAccess(client, "", flags, true) == true )
			{
				access = true;
				break;
			}
		}
	}

	if( access == false )
		return;

	// Block shoving for transferable items or allowed Gear Transfer items.
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if( weapon != -1 )
	{
		GetEdictClassname(weapon, sTemp, sizeof(sTemp));

		int aNull;
		if( g_smBlocked.GetValue(sTemp, aNull) )
		{
			return;
		}
	}

	// Event
	if( GetClientTeam(client) == 2 && GetClientTeam(target) == 2 )
	{
		g_fTimeout[client] = GetGameTime() + g_hCvarDelay.FloatValue;

		float vPos[3];
		GetClientAbsOrigin(client, vPos);

		if( g_bLeft4Dead2 )
			StaggerClient(userid, vPos);
		else
			SDKCall(g_hConfStagger, target, target, vPos); // Stagger: SDKCall method

		// Vocalize
		int chance = g_hCvarVoca.IntValue;
		if( chance && GetRandomInt(1, 100) <= chance )
		{
			switch ( g_hCvarVocaType.IntValue )
			{
				case 1:
				{
					int health = GetClientHealth(target);
					if( health < 40 )
					{
						SetVariantString("PainLevel:Major:0.1");
					}
					else
					{
						SetVariantString("PainLevel:Minor:0.1");
					}

					AcceptEntityInput(target, "AddContext");

					SetVariantString("Pain");
					AcceptEntityInput(target, "SpeakResponseConcept");
				}
				default:
				{
					static char model[40];

					// Get survivor model
					GetEntPropString(target, Prop_Data, "m_ModelName", model, sizeof(model));

					switch( model[29] )
					{
						case 'c': VocalizeScene(target, g_Coach[GetRandomInt(0, sizeof(g_Coach) - 1)]);
						case 'b': VocalizeScene(target, g_Nick[GetRandomInt(0, sizeof(g_Nick) - 1)]);
						case 'h': VocalizeScene(target, g_Ellis[GetRandomInt(0, sizeof(g_Ellis) - 1)]);
						case 'd': VocalizeScene(target, g_Rochelle[GetRandomInt(0, sizeof(g_Rochelle) - 1)]);
						case 'v': VocalizeScene(target, g_Bill[GetRandomInt(0, sizeof(g_Bill) - 1)]);
						case 'e': VocalizeScene(target, g_Francis[GetRandomInt(0, sizeof(g_Francis) - 1)]);
						case 'a': VocalizeScene(target, g_Louis[GetRandomInt(0, sizeof(g_Louis) - 1)]);
						case 'n': VocalizeScene(target, g_Zoey[GetRandomInt(0, sizeof(g_Zoey) - 1)]);
					}
				}
			}
		}
	}
}

// Credit to Timocop on VScript function
void StaggerClient(int userid, const float vPos[3])
{
	static int iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
			LogError("Could not create 'logic_script");

		DispatchSpawn(iScriptLogic);
	}

	char sBuffer[96];
	Format(sBuffer, sizeof(sBuffer), "GetPlayerFromUserID(%d).Stagger(Vector(%d,%d,%d))", userid, RoundFloat(vPos[0]), RoundFloat(vPos[1]), RoundFloat(vPos[2]));
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
	RemoveEntity(iScriptLogic);
}

// Taken from:
// [Tech Demo] L4D2 Vocalize ANYTHING
// https://forums.alliedmods.net/showthread.php?t=122270
// author = "AtomicStryker"
// ====================================================================================================
//					VOCALIZE SCENE
// ====================================================================================================
void VocalizeScene(int client, const char[] scenefile)
{
	int entity = CreateEntityByName("instanced_scripted_scene");
	DispatchKeyValue(entity, "SceneFile", scenefile);
	DispatchSpawn(entity);
	SetEntPropEnt(entity, Prop_Data, "m_hOwner", client);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "Start", client, client);
}