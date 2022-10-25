/*
*	Pause Messages Block
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



#define PLUGIN_VERSION 		"1.1"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Pause Messages Block
*	Author	:	SilverShot
*	Descrp	:	Blocks the player paused and unpaused message spam in client consoles.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=321343
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.1 (20-Jul-2021)
	- Added support for the "Pause plugin" by "CanadaRox, Sir, Forgetest". Thanks to "Tank Rush" for reporting.

1.0 (06-Feb-2020)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

bool g_bLeft4Dead2;
ConVar g_hCvarPause;



// ====================================================================================================
//					PLUGIN
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Pause Messages Block",
	author = "SilverShot",
	description = "Blocks the player paused and unpaused message spam in client consoles.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=321343"
}

public void OnPluginStart()
{
	CreateConVar("l4d_pause_message_version", PLUGIN_VERSION, "Pause Messages Block plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hCvarPause = FindConVar("sv_pausable");
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

// Doing this to detect if "Pause" plugin was added or removed on map changes. Otherwise it could block the plugin functioning correctly.
public void OnConfigsExecuted()
{
	static bool hooked;

	if( !g_bLeft4Dead2 || FindConVar("l4d2_pause_force_only") == null )
	{
		if( !hooked )
		{
			hooked = true;
			AddCommandListener(CommandBlock, "pause");
			AddCommandListener(CommandBlock, "setpause");
			AddCommandListener(CommandBlock, "unpause");
		}
	} else {
		if( hooked )
		{
			hooked = false;
			RemoveCommandListener(CommandBlock, "pause");
			RemoveCommandListener(CommandBlock, "setpause");
			RemoveCommandListener(CommandBlock, "unpause");
		}
	}
}

public Action CommandBlock(int client, const char[] command, int argc) 
{
	if( g_hCvarPause.IntValue == 0) // Check if games pausable and allow, otherwise block.
		return Plugin_Handled;
	return Plugin_Continue;
}