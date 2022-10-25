#define PLUGIN_VERSION 		"1.1"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Bacteria Sounds
*	Author	:	SilverShot
*	Descrp	:	Restores the games bacteria sounds for all gamemodes.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=320030
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.1 (10-May-2020)
	- Added better error log message when gamedata file is missing.

1.0 (01-Dec-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d2_bacteria"

ConVar g_hCvarAllow;
bool g_bCvarAllow;
int g_ByteCount, g_ByteMatch;
ArrayList g_ByteSaved;
Address g_Address;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Bacteria Sounds",
	author = "SilverShot",
	description = "Restores the games bacteria sounds for all gamemodes.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=320030"
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
	// ====================================================================================================
	// GAMEDATA
	// ====================================================================================================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_Address = GameConfGetAddress(hGameData, "Music::OnPZAlert");
	if( !g_Address ) SetFailState("Failed to load \"Music::OnPZAlert\" address.");

	int offset = GameConfGetOffset(hGameData, "OnPZAlert_Offset");
	if( offset == -1 ) SetFailState("Failed to load \"OnPZAlert_Offset\" offset.");

	g_ByteMatch = GameConfGetOffset(hGameData, "OnPZAlert_Byte");
	if( g_ByteMatch == -1 ) SetFailState("Failed to load \"OnPZAlert_Byte\" byte.");

	g_ByteCount = GameConfGetOffset(hGameData, "OnPZAlert_Count");
	if( g_ByteCount == -1 ) SetFailState("Failed to load \"OnPZAlert_Count\" count.");

	g_Address += view_as<Address>(offset);
	g_ByteSaved = new ArrayList();

	for( int i = 0; i < g_ByteCount; i++ )
	{
		g_ByteSaved.Push(LoadFromAddress(g_Address + view_as<Address>(i), NumberType_Int8));
	}
	if( g_ByteSaved.Get(0) != g_ByteMatch ) SetFailState("Failed to load, byte mis-match @ %d (0x%02X != 0x%02X)", offset, g_ByteSaved.Get(0), g_ByteMatch);

	delete hGameData;



	// ====================================================================================================
	// CVARS
	// ====================================================================================================
	g_hCvarAllow =			CreateConVar(	"l4d2_bacteria_allow",		"1",				"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	CreateConVar(							"l4d2_bacteria_ver",		PLUGIN_VERSION,		"Bacteria Sounds plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d2_bacteria");

	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);

	IsAllowed();
}

public void OnPluginEnd()
{
	PatchAddress(false);
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

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;

	if( g_bCvarAllow == false && bCvarAllow == true )
	{
		g_bCvarAllow = true;
		PatchAddress(true);
	}

	else if( g_bCvarAllow == true && bCvarAllow == false )
	{
		g_bCvarAllow = false;
		PatchAddress(false);
	}
}



// ====================================================================================================
//					PATCH
// ====================================================================================================
void PatchAddress(int patch)
{
	static bool patched;

	if( !patched && patch )
	{
		patched = true;
		for( int i = 0; i < g_ByteSaved.Length; i++ )
			StoreToAddress(g_Address + view_as<Address>(i), 0x90, NumberType_Int8);
	}
	else if( patched && !patch )
	{
		patched = false;
		for( int i = 0; i < g_ByteSaved.Length; i++ )
			StoreToAddress(g_Address + view_as<Address>(i), g_ByteSaved.Get(i), NumberType_Int8);
	}
}