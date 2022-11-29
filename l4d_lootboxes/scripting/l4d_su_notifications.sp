/*============================================================================================
							[L4D & L4D2] Survivor utilities: Notifications
----------------------------------------------------------------------------------------------
*	Author	:	Eärendil
*	Descrp	:	Adds chat notifications to players when they have a change in their condition
*	Version :	1.0.3
*	Link	:	https://forums.alliedmods.net/showthread.php?t=335683
----------------------------------------------------------------------------------------------
==============================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <survivorutilities>

#define PLUGIN_VERSION "1.0.3"
#define TIME_EXTEND 2
#define CHAT_TAG	"\x04[\x05SU\x04] \x01"

ConVar g_hAllow;
ConVar g_hEnd;

bool g_bL4D2;

public Plugin myinfo =
{
	name = "[L4D & L4D2] Surivor utilities: Notifications",	// Title pending of changes, I haven't found an appropiate name for this
	author = "Eärendil",
	description = "Adds chat notifications to players when they have a change in their condition",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=335683",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if( GetEngineVersion() == Engine_Left4Dead2 )
		g_bL4D2 = true;

	else if( GetEngineVersion() != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	// Not adding a convar for version, this is a basic extension of the main plugin
	g_hAllow =		CreateConVar("sm_su_notifications_enable",		"1",		"0 = Plugin Off. 1 = Plugin On.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hEnd =		CreateConVar("sm_su_notification_end",			"1",		"Notify when condition ends. 1 = On, 0 = Off.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	AutoExecConfig(true, "l4d_su_notifications");
}

public void SU_OnFreeze_Post(int client, float time, const bool overload)
{
	if( !g_hAllow.BoolValue || overload ) return;	
	
	PrintToChat(client, "%sYou have been frozen.", CHAT_TAG);
}

public void SU_OnToxic_Post(int client, int amount, const bool overload)
{
	if( !g_hAllow.BoolValue || overload ) return;	
	
	PrintToChat(client, "%sYou have been intoxicated.", CHAT_TAG);
		
	char pillsMsg[32];
	if( g_bL4D2 ) pillsMsg = "pain pills or adrenaline";
	else pillsMsg = "pain pills";

	PrintToChat(client, "%sUse %s to stop the intoxication.", CHAT_TAG, pillsMsg);
}

public void SU_OnBleed_Post(int client, int amount, const bool overload)
{
	if( !g_hAllow.BoolValue || overload ) return;
	
	PrintToChat(client, "%sYou are bleeding.", CHAT_TAG);
	PrintToChat(client, "%sUse a medkit to stop the bleeding.", CHAT_TAG);
}

public void SU_OnExhaust_Post(int client, int amount, const bool overload)
{
	if( !g_hAllow.BoolValue || overload ) return;
	
	PrintToChat(client, "%sYou are exhausted.", CHAT_TAG);
	if( g_bL4D2 )
		PrintToChat(client, "%sUse adrenaline to stop the exhaustion.", CHAT_TAG);
}

public void SU_OnFreezeEnd(int client)
{
	if( !g_hAllow.BoolValue || !g_hEnd.BoolValue ) return;
	
	PrintToChat(client, "%sFreeze effect ended.", CHAT_TAG);
}

public void SU_OnToxicEnd(int client)
{
	if( !g_hAllow.BoolValue || !g_hEnd.BoolValue ) return;
	
	PrintToChat(client, "%sIntoxication ended.", CHAT_TAG);
}

public void SU_OnBleedEnd(int client)
{
	if( !g_hAllow.BoolValue || !g_hEnd.BoolValue ) return;
	
	PrintToChat(client, "%sBleeding ended.", CHAT_TAG);
}

public void SU_OnExhaustEnd(int client)
{
	if( !g_hAllow.BoolValue || !g_hEnd.BoolValue ) return;
	
	PrintToChat(client, "%sExhaustion ended.", CHAT_TAG);
}

/*============================================================================================
									Changelog
----------------------------------------------------------------------------------------------
* 1.1	(23-Sep-2022)
		- Plugin now uses POST forwards to generate messages
		- Fixed exhaustion notification gramatical errors.
		- Correctly display messages for each L4D version.
* 1.0.2 (30-Dec-2021)
		- Fixed exhaustion notification not being showed properly.
* 1.0.1	(25-Dec-2021)
		- Fixed missing config file.
* 1.0	(25-Dec-2021)
		- Initial release.
*/