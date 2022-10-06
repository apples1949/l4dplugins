#define PLUGIN_VERSION		"1.5"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Lift Music
*	Author	:	SilverShot
*	Descrp	:	Plays music when players are travelling inside an elevator.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=157267
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.5 (10-May-2020)
	- Various changes to tidy up code.

1.4 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.

1.3 (10-May-2012)
	- Small changes and fixes.

1.2 (20-May-2011)
	- Added elevator from c6m3_port.

1.1 (20-May-2011)
	- Added "l4d_vs_hospital04_interior" as Visual77 suggested.

1.0 (18-May-2011)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define MAX_TRACKS			32

bool g_bLeft4Dead2;
char g_sTracks[MAX_TRACKS][64];
int g_iElevator, g_iMapType, g_iPlaying, g_iTracks;

enum
{
	C1M1 = 1,
	C1M4,
	C4M2,
	C4M3,
	C6M3,
	C8M4,
	L4D_C8M4
}



public Plugin myinfo =
{
	name = "[L4D & L4D2] Lift Music",
	author = "SilverShot",
	description = "Plays music when players are travelling inside an elevator.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=157267"
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
	CreateConVar("l4d_lift_music_version", PLUGIN_VERSION, "Lift Music plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	// Load tracks
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "data/l4d_lift_music.cfg");

	if( FileExists(sPath) )
	{
		File hFile = OpenFile(sPath, "r");
		if( hFile != null )
		{
			while( g_iTracks < MAX_TRACKS && !hFile.EndOfFile() && hFile.ReadLine(g_sTracks[g_iTracks], sizeof(g_sTracks[])) )
			{
				TrimString(g_sTracks[g_iTracks]);
				if( strlen(g_sTracks[g_iTracks]) > 0 )
					g_iTracks++;
			}
		}
		delete hFile;
	}

	HookEvent("round_start", Event_RoundStart);
}

public void OnMapStart()
{
	char sMap[32];
	GetCurrentMap(sMap, sizeof(sMap));

	g_iMapType = 0;
	if( g_bLeft4Dead2 )
	{
		if( strcmp(sMap, "c1m1_hotel") == 0 ) g_iMapType = C1M1;
		else if( strcmp(sMap, "c1m4_atrium") == 0 ) g_iMapType = C1M4;
		else if( strcmp(sMap, "c4m2_sugarmill_a") == 0 ) g_iMapType = C4M2;
		else if( strcmp(sMap, "c4m3_sugarmill_b") == 0 ) g_iMapType = C4M3;
		else if( strcmp(sMap, "c6m3_port") == 0 ) g_iMapType = C6M3;
		else if( strcmp(sMap, "c8m4_interior") == 0 ) g_iMapType = C8M4;
	}
	else
	{
		if( strcmp(sMap, "l4d_hospital04_interior") == 0 || strcmp(sMap, "l4d_vs_hospital04_interior") == 0 ) g_iMapType = L4D_C8M4;
	}

	if( g_iMapType )
		for( int i = 0; i < g_iTracks; i++ )
			PrecacheSound(g_sTracks[i]);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(5.0, tmrStart, _,  TIMER_FLAG_NO_MAPCHANGE);
}

public Action tmrStart(Handle timer)
{
	if( g_iTracks == 0 ) return;
	int ent = -1;

	if( g_bLeft4Dead2 )
	{
		if( g_iMapType == C1M1 && (ent = FindByClassTargetName("logic_relay", "relay_stop1")) != -1 )
			HookSingleEntityOutput(ent, "OnTrigger", OnOutputStartSound, true);
		else if( g_iMapType == C1M4 && (ent = FindByClassTargetName("func_button", "button_elev_3rdfloor")) != -1 )
			HookSingleEntityOutput(ent, "OnPressed", OnOutputStartSound, true);
		else if( g_iMapType == C4M2 && (ent = FindByClassTargetName("logic_relay", "relay_elevator_down")) != -1 )
			HookSingleEntityOutput(ent, "OnTrigger", OnOutputStartSound, true);
		else if( g_iMapType == C4M3 && (ent = FindByClassTargetName("logic_relay", "relay_elevator_up")) != -1 )
			HookSingleEntityOutput(ent, "OnTrigger", OnOutputStartSound, true);
		else if( g_iMapType == C6M3 && (ent = FindByClassTargetName("func_button", "generator_elevator_button")) != -1 )
			HookSingleEntityOutput(ent, "OnPressed", OnOutputStartSound, true);
		else if( g_iMapType == C8M4 && (ent = FindByClassTargetName("func_button", "elevator_button")) != -1 )
			HookSingleEntityOutput(ent, "OnPressed", OnOutputStartSound, true);
	}
	else
	{
		if( g_iMapType == L4D_C8M4 && (ent = FindByClassTargetName("func_button", "elevator_button")) != -1 )
			HookSingleEntityOutput(ent, "OnPressed", OnOutputStartSound, true);
	}

	// Hook lift arriving on floor to stop sound.
	if( ent != INVALID_ENT_REFERENCE && (g_iElevator = FindEntityByClassname(-1, "func_elevator")) != INVALID_ENT_REFERENCE )
	{
		HookSingleEntityOutput(g_iElevator, "OnReachedTop", OnOuputStopSound, true);
		HookSingleEntityOutput(g_iElevator, "OnReachedBottom", OnOuputStopSound, true);
		g_iElevator = EntIndexToEntRef(g_iElevator);
	}
}

public void OnOutputStartSound(const char[] output, int caller, int activator, float delay)
{
	if( EntRefToEntIndex(g_iElevator) != INVALID_ENT_REFERENCE )
	{
		g_iPlaying = GetRandomInt(0, g_iTracks-1);
		EmitSoundToAll(g_sTracks[g_iPlaying], EntRefToEntIndex(g_iElevator), SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0 );
	}
}

public void OnOuputStopSound(const char[] output, int caller, int activator, float delay)
{
	if( EntRefToEntIndex(g_iElevator) != INVALID_ENT_REFERENCE )
		StopSound(EntRefToEntIndex(g_iElevator), SNDCHAN_AUTO, g_sTracks[g_iPlaying]);
}

int FindByClassTargetName(const char[] sClass, const char[] sTarget)
{
	char sName[64];
	int ent = -1;
	while( (ent = FindEntityByClassname(ent, sClass)) != INVALID_ENT_REFERENCE )
	{
		GetEntPropString(ent, Prop_Data, "m_iName", sName, sizeof(sName));
		if( strcmp(sTarget, sName) == 0 ) return ent;
	}
	return -1;
}