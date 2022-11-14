// Thanks DJ Tsunami 

/*
 *	Version Notes:
 *	2.0:	Changed to more generic system based upon gamemode and difficulty settings.
 *			Idea from AtomicStrykers even more basic code (compared to v1.6).
 *	2.0.1:	What happened to the _ ?.. fixed it.
 *
 * Current valid filenames (for reference only):
 *		GameMode - coop, realism, survival, scavenge, teamscavenge, versus, teamversus, 
 *					mutation3 (Bleed Out), mutation9 (VIP Gnome), mutation12 (Realism Versus), mutation13 (Linear Scavenge)
 *					+ eventually mutationX (1,2,3...)
 *		Difficulty - Easy, Normal, Hard, Impossible
 *
 *		Combined examples (with String:Temp3 and String:Temp2): coop.cfg, mutation12.cfg, realism_Impossible.cfg
 *
 *	If you don't have the file, it wont change anything.
 *	Difficulty based filenames are not required, but are checked for first (they override generic configs).
 *	eg: coop.cfg would run for all coop games, while coop_Easy.cfg would only run for coop games on Easy.
 *	eg: a versus game with no versus.cfg would use whatever settings are currently active on the server.
 */

#include <sourcemod>

#define CVAR_FLAGS FCVAR_PLUGIN
#define PLUGIN_VERSION "2.0.1"

// path that exec command looks for:
// REQUIRES the double back-slash to output a single back-slash
new String:Temp1[] = "cfg\\";

// file extension for config files:
new String:Temp2[] = ".cfg";

// seperator for difficulty filenames (eg: coop_Impossible):
new String:Temp3[] = "_";
	
public Plugin:myinfo = 
{
	name = "Game Mode Config Loader",
	author = "Dirka_Dirka",
	description = "Executes a config file based on the current mp_gamemode and z_difficulty",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=93212"
}

new Handle:g_hGameMode			=	INVALID_HANDLE;
new Handle:g_hDifficulty		=	INVALID_HANDLE;

public OnPluginStart()
{
	CreateConVar("gamemode_cfg_ver", PLUGIN_VERSION, "Version of the game mode config loader plugin.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY);

	g_hGameMode = FindConVar("mp_gamemode");		//coop, versus, survival
	g_hDifficulty = FindConVar("z_difficulty");		//Easy, Normal, Hard, Impossible
	
	HookConVarChange(g_hGameMode, ConVarChange_GameMode);
	HookConVarChange(g_hDifficulty, ConVarChange_Difficulty);
}

public OnMapStart()
{
	ExecuteGameModeConfig();
}

public ConVarChange_GameMode(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (strcmp(oldValue, newValue) != 0)
	{
		ExecuteGameModeConfig();
	}
}

public ConVarChange_Difficulty(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (strcmp(oldValue, newValue) != 0)
	{
		ExecuteGameModeConfig();
	}
}

ExecuteGameModeConfig()
{
	decl String:sConfigName[PLATFORM_MAX_PATH] = "";
	decl String:sConfigNameD[PLATFORM_MAX_PATH] = "";
	
	decl String:sGameMode[16] = "";
	GetConVarString(g_hGameMode, sGameMode, sizeof(sGameMode));
	
	decl String:sGameDifficulty[16] = "";
	GetConVarString(g_hDifficulty, sGameDifficulty, sizeof(sGameDifficulty));
	
	StrCat(String:sConfigName, sizeof(sConfigName), sGameMode);
	TrimString(sConfigName);
	
	StrCat(String:sConfigNameD, sizeof(sConfigName), sGameMode);
	StrCat(String:sConfigNameD, sizeof(sConfigName), Temp3);
	StrCat(String:sConfigNameD, sizeof(sConfigName), sGameDifficulty);
	TrimString(sConfigNameD);
	
	// the location of the config folder that exec looks for
	decl String:filePath[PLATFORM_MAX_PATH] = "";
	decl String:filePathD[PLATFORM_MAX_PATH] = "";
	
	StrCat(String:filePath, sizeof(filePath), String:Temp1);
	StrCat(String:filePath, sizeof(filePath), sConfigName);
	StrCat(String:filePath, sizeof(filePath), String:Temp2);
	TrimString(filePath);
	StrCat(String:filePathD, sizeof(filePathD), String:Temp1);
	StrCat(String:filePathD, sizeof(filePathD), sConfigNameD);
	StrCat(String:filePathD, sizeof(filePathD), String:Temp2);
	TrimString(filePathD);
	
	if (FileExists(filePathD))
	{
		ServerCommand("exec %s", sConfigNameD);
	}
	else if (FileExists(filePath))
	{
		ServerCommand("exec %s", sConfigName);
	}
	else
	{
		return;		// no config file - will expand later
	}
}
