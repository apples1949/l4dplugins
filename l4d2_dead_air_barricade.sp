/*
*	Dead Air Barricade
*	Copyright (C) 2020 Silvers
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



#define PLUGIN_VERSION		"1.3"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Dead Air Barricade
*	Author	:	SilverShot
*	Descrp	:	Removes the fire barricade from Dead Air finale.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=181516
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.3 (05-Oct-2020)
	- Fixed the plugin not working on first map load. Thanks to "aiyoaiui" for reporting.

1.2 (10-May-2020)
	- Various optimizations and fixes.

1.1 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.

1.0 (30-Mar-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

int g_iMap;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Dead Air Barricade",
	author = "SilverShot",
	description = "Removes the fire barricade from Dead Air finale.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=181516"
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
	CreateConVar("l4d2_dead_air_barricade", PLUGIN_VERSION, "Dead Air Barricade plugin version", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	HookEvent("round_start",	Event_RoundStart,	EventHookMode_PostNoCopy);
}

public void OnMapStart()
{
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( strcmp(sMap, "c11m5_runway") == 0 )
	{
		CreateTimer(5.0, TimerDel, _, TIMER_FLAG_NO_MAPCHANGE);
		g_iMap = 1;
	}
}

public void OnMapEnd()
{
	g_iMap = 0;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if( g_iMap == 1 )
	{
		CreateTimer(5.0, TimerDel, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action TimerDel(Handle timer)
{
	char sName[20];
	int entity;

	while( (entity = FindEntityByClassname(entity, "logic_relay")) != INVALID_ENT_REFERENCE )
	{
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		if( strcmp(sName, "ribbon_fire_relay") == 0 )
		{
			AcceptEntityInput(entity, "Kill");
			return;
		}
	}
}