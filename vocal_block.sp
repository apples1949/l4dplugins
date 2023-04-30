/*
 * vim: set ts=4 :
 * =============================================================================
 * Left 4 Dead Vocalize Guard
 * Guards against Player's Abusing the Vocalize System
 * Variation of the 'Left 4 Dead Vote Gaurd Plugin by CrimsonGT
 * SourceMod (C)2004-2007 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 */

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.1"

int g_VocalCalled[MAXPLAYERS+1];
float g_LastVocalTime[MAXPLAYERS+1];

/* CVARS */
ConVar cEnabled = null;
ConVar cAdminsImmune = null;
ConVar cVocalLimit = null;
ConVar cVocalDelay = null;
ConVar cBanTime = null;

public Plugin myinfo = 
{
	name = "L4D Vocalize Guard",
	author = "Crimson - TeddyRuxpin, Harry",
	description = "Left 4 Dead Vocalize Spam Blocker",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	
	
	if( !IsDedicatedServer() )
	{
		strcopy(error, err_max, "Get a dedicated server. This plugin does not work on Listen servers.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success; 
}

public void OnPluginStart()
{
	RegConsoleCmd("vocalize", Command_CallVocal);

	cEnabled = CreateConVar("sm_vocalize_guard_enabled", "1", "启用/禁用插件 [0 = 禁用, 1 = 启用]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cAdminsImmune = CreateConVar("sm_vocalize_guard_adminimmune", "1", "启用/禁用对管理员的豁免 [0 = 禁用, 1 = 启用]", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cVocalLimit = CreateConVar("sm_vocalize_guard_vlimit", "9999", "最多允许几次语音表单 [0 = 无限制]", FCVAR_NOTIFY, true, 0.0);
	cVocalDelay = CreateConVar("sm_vocalize_guard_vdelay", "5", "玩家使用语音表单频率 [0 = 关闭]", FCVAR_NOTIFY, true, 0.0);
	cBanTime = CreateConVar("sm_vocalize_guard_bantime", "0", "封禁玩家时间 [0 = 踢出玩家]", FCVAR_NOTIFY, true, 0.0);
	

	AutoExecConfig(true, "vocal_block");
	HookEvent("player_disconnect", Event_PlayerDisconnect);
}

public void OnMapStart()
{
	for(int i=1;i<=MaxClients;i++)
	{
		g_VocalCalled[i] = 0;
		g_LastVocalTime[i] = 0.0;
	}
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	g_VocalCalled[client] = 0;
	g_LastVocalTime[client] = 0.0;
}

public Action Command_CallVocal(int client, int args)
{
	if(client == 0 || !IsClientInGame(client)) return Plugin_Continue;

	int iMaxVotes = cVocalLimit.IntValue;
	int flTimeDelay = cVocalDelay.IntValue;
	
	/* If this player hasnt called any votes */
	if(g_VocalCalled[client] == 0)
	{
		g_LastVocalTime[client] = GetEngineTime();
		g_VocalCalled[client]++;
	}
	else if(g_LastVocalTime[client] < (GetEngineTime() - flTimeDelay))
	{
		g_LastVocalTime[client] = GetEngineTime();

		/* If the plugin is enabled */
		if(cEnabled.BoolValue)
		{
			/*If Client Has Exceeded Max Call Votes */
			if((g_VocalCalled[client] == iMaxVotes) && (iMaxVotes != 0))
			{
				/* If the players not an admin */
				if(!IsAdmin(client))
				{
					RemovePlayer(client);
				}
			}
			/*Warns Client upon reaching the Max Call Votes */
			else if(g_VocalCalled[client] == (iMaxVotes-1))
			{
				PrintToChat(client, "\x04[SM] \x01你已达到使用语音表单的最大数量");
				
				g_VocalCalled[client]++;
			}
			else
			{
				g_VocalCalled[client]++;
			}
		}
	}
	else
	{
		int iTimeLeft = RoundToNearest(flTimeDelay - (GetEngineTime() - g_LastVocalTime[client]));
		PrintToChat(client, "\x04[SM] \x01你必须等待 %d 秒后再次使用语音表单", iTimeLeft);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

/* Is Player Admin Check */
bool IsAdmin(int client)
{
	if(cAdminsImmune.BoolValue == false)
	{
		return false;
	}

	AdminId admin = GetUserAdmin(client);
	
	if(admin == INVALID_ADMIN_ID)
	{
		return false;
	}

	return true;
}

/* Kick OR Ban Player Based on CVAR Value */
void RemovePlayer(int client)
{
	int iBanTime = cBanTime.IntValue;

	if(IsClientConnected(client))
	{
		if(iBanTime == 0)
		{

			if(IsClientInGame(client))
			{
				char sName[MAX_NAME_LENGTH];
				GetClientName(client, sName, sizeof(sName));
				PrintToChatAll("\x04[SM] \x01%s 因过多使用语音表单而被踢出", sName);

				KickClient(client, "Kicked for Vocalize Abuse");
			}
		}
		else if(iBanTime > 0)
		{
			if(IsClientInGame(client))
			{
				char sName[MAX_NAME_LENGTH];
				GetClientName(client, sName, sizeof(sName));
				PrintToChatAll("\x04[SM] \x01%s 因过多使用语音表单而被封禁 %d 分钟", sName, iBanTime);

				BanClient(client, iBanTime, BANFLAG_AUTO, "Banned", "Banned", _, client);
			}
		}
	}
}