/*
*	Common Limiter
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



#define PLUGIN_VERSION 		"1.0"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Common Limiter
*	Author	:	SilverShot
*	Descrp	:	Limit number of common infected to the z_common_limit cvar value.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=338337
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.0 (27-Jun-2022)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

int g_iCommon[2048];
int g_iTotalCommon;
int g_iLimitCommon;
bool g_bMapStarted;
ConVar g_hCvarLimit;

public Plugin myinfo =
{
	name = "[L4D & L4D2] Common Limiter",
	author = "SilverShot",
	description = "Limit number of common infected to the z_common_limit cvar value.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=338337"
}

public void OnPluginStart()
{
	CreateConVar("l4d_common_limiter_version", PLUGIN_VERSION, "Common Limiter plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hCvarLimit = FindConVar("z_common_limit");
	g_hCvarLimit.AddChangeHook(ConVarChanged_Cvars);
	g_iLimitCommon = g_hCvarLimit.IntValue;

	HookEvent("round_end",		Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start",	Event_RoundStart, EventHookMode_PostNoCopy);

	LateLoad();

	RegAdminCmd("sm_common_limit", CmdLimit, ADMFLAG_ROOT);
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_iLimitCommon = g_hCvarLimit.IntValue;
}

public Action CmdLimit(int client, int args)
{
	ReplyToCommand(client, "Common Limiter: %d of %d", g_iTotalCommon, g_iLimitCommon);
	return Plugin_Handled;
}

public void OnMapStart()
{
	g_bMapStarted = true;
}

public void OnMapEnd()
{
	g_bMapStarted = false;

	ResetPlugin();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	LateLoad();

	g_bMapStarted = true;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bMapStarted = false;

	ResetPlugin();
}

void LateLoad()
{
	int entity = -1;
	while( (entity = FindEntityByClassname(entity, "infected")) != INVALID_ENT_REFERENCE )
	{
		g_iCommon[entity] = entity;
		g_iTotalCommon++;

		if( g_iTotalCommon > g_iLimitCommon )
		{
			RemoveEntity(entity);
		}
	}
}

void ResetPlugin()
{
	for( int i = 0; i < 2048; i++ )
	{
		g_iCommon[i] = 0;
	}

	g_iTotalCommon = 0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_bMapStarted && entity > 0 && entity < 2048 && strcmp(classname, "infected") == 0 )
	{
		g_iCommon[entity] = entity;
		g_iTotalCommon++;

		if( g_iTotalCommon > g_iLimitCommon )
		{
			SDKHook(entity, SDKHook_SpawnPost, OnSpawn);
		}
	}
}

public void OnEntityDestroyed(int entity)
{
	if( g_bMapStarted && entity > 0 && entity < 2048 && g_iCommon[entity] == entity )
	{
		g_iCommon[entity] = 0;
		g_iTotalCommon--;
	}
}

void OnSpawn(int entity)
{
	RemoveEntity(entity);
}