#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#pragma newdecls required

static bool g_bIsBlockingMedkit[MAXPLAYERS + 1];
static bool g_bIsBlockingFire[MAXPLAYERS + 1];
static bool g_bIsBlockingUse[MAXPLAYERS + 1];
static bool g_bWasRecentlyOnLadder[MAXPLAYERS + 1];
static bool g_bHasOverrideAccess[MAXPLAYERS + 1];
static bool g_bIsBot[MAXPLAYERS + 1];
static bool g_bIsInGame[MAXPLAYERS + 1];
static float g_fStartHealingTime[MAXPLAYERS + 1];

ConVar l4d2_blockhealing_time;
ConVar l4d2_blockhealing_time_ladder;
ConVar l4d2_blockhealing_time_use;

public Plugin myinfo = 
{
	name = "L4D2 Block Healing",
	author = "Buster, Mr. Zero, Nielsen (modified version: dr_lex)",
	description = "Blocks Survivors from freezing other Survivors in place with their medkit",
	version = "1.1.4",
	url = "mrzerodk@gmail.com"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (!IsDedicatedServer())
	{
		strcopy(error, err_max, "Plugin only support dedicated servers");
		return APLRes_Failure; // Plugin does not support client listen servers, return
	}

	char buffer[128];
	GetGameFolderName(buffer, 128);
	if (!StrEqual(buffer, "left4dead2", false))
	{
		strcopy(error, err_max, "Plugin only support Left 4 Dead 2");
		return APLRes_Failure; // Plugin does not support this game, return
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	l4d2_blockhealing_time = CreateConVar("l4d2_blockhealing_time", "5.0", "How long the healing Survivor is prohibit from taking out their medkit after the receiving Survivor breaks free of the heal. 0 to disable prohibition", FCVAR_NONE);
	l4d2_blockhealing_time_ladder = CreateConVar("l4d2_blockhealing_time_ladder", "15.0", "How long the healing Survivor is prohibit from taking out their medkit after trying to heal a fellow Survivor on a ladder. 0 to disable prohibition", FCVAR_NONE);
	l4d2_blockhealing_time_use = CreateConVar("l4d2_blockhealing_time_use", "5.0", "How long the reviving Survivor is prohibit from using their use button after the incapacitated Survivor breaks free of the reviving. 0 to disable Survivors being able to break free of a revive", FCVAR_NONE);

	HookEvent("heal_end", OnHealEnd_Event);

	AutoExecConfig(true, "l4d2_blockhealing");
}

public void OnAllPluginsLoaded()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
		{
			continue;
		}

		g_bIsBlockingMedkit[client] = false;
		g_bIsBlockingFire[client] = false;
		g_bIsBlockingUse[client] = false;
		g_bWasRecentlyOnLadder[client] = false;
		g_bHasOverrideAccess[client] = false;
		g_fStartHealingTime[client] = 0.0;
		g_bIsBot[client] = IsFakeClient(client);
		g_bIsInGame[client] = true;
	}
}

public void OnClientPutInServer(int client)
{
	g_bIsBlockingMedkit[client] = false;
	g_bIsBlockingFire[client] = false;
	g_bIsBlockingUse[client] = false;
	g_bWasRecentlyOnLadder[client] = false;
	g_bHasOverrideAccess[client] = false;
	g_fStartHealingTime[client] = 0.0;
	g_bIsBot[client] = IsFakeClient(client);
	g_bIsInGame[client] = true;
}

public void OnClientDisconnect(int client)
{
	g_bIsInGame[client] = false;
}

public void OnHealEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client <= 0 || client > MaxClients)
	{
		return;
	}

	g_fStartHealingTime[client] = 0.0;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsClientInGame(client)) //если что удалить
	{
		if (g_bIsBlockingFire[client] && buttons & IN_ATTACK)
		{
			buttons ^= IN_ATTACK;
			return Plugin_Continue;
		}

		if (g_bIsBlockingUse[client] && buttons & IN_USE)
		{
			buttons ^= IN_USE;
			return Plugin_Continue;
		}

		if (g_bIsBlockingMedkit[client] && weapon > 0 && IsValidEdict(weapon))
		{
			char classname[64];
			GetEdictClassname(weapon, classname, 64);
			if (StrEqual(classname, "weapon_first_aid_kit"))
			{
				weapon = GetPlayerMainWeapon(client);
			}
			return Plugin_Continue;
		}

		if (GetEntityMoveType(client) == MOVETYPE_LADDER && !g_bWasRecentlyOnLadder[client])
		{
			g_bWasRecentlyOnLadder[client] = true;
			CreateTimer(5.0, ResetRecentlyOnLadder_Timer, client);
		}

		if (HxGetPlayerUseAction(client) == 1)
		{
			int subject = HxGetPlayerUseActionTarget(client);
			if (subject <= 0 || subject > MaxClients || subject == client || !g_bIsInGame[subject] || g_bIsBot[subject])
			{
				return Plugin_Continue;
			}

			if (g_fStartHealingTime[client] == 0.0)
			{
				g_fStartHealingTime[client] = GetEngineTime();
			}

			if (g_bHasOverrideAccess[client])
			{
				return Plugin_Continue;
			}

			if (GetClientButtons(subject) & IN_JUMP)
			{
				if (GetEngineTime() - g_fStartHealingTime[client] < 1.5)
				{
					return Plugin_Continue;
				}

				float blockTime = l4d2_blockhealing_time.FloatValue;
				if (blockTime > 0.0)
				{
					g_bIsBlockingMedkit[client] = true;
					CreateTimer(blockTime, BlockMedkit_Timer, client, TIMER_FLAG_NO_MAPCHANGE);

					g_bIsBlockingFire[client] = true;
					CreateTimer(5.0, BlockFire_Timer, client);
					weapon = GetPlayerMainWeapon(client);
					return Plugin_Continue;
				}
			}
			else if (g_bWasRecentlyOnLadder[subject])
			{
				float blockTime = l4d2_blockhealing_time_ladder.FloatValue;
				if (blockTime > 0.0)
				{
					g_bIsBlockingMedkit[client] = true;
					CreateTimer(blockTime, BlockMedkit_Timer, client, TIMER_FLAG_NO_MAPCHANGE);

					g_bIsBlockingFire[client] = true;
					CreateTimer(5.0, BlockFire_Timer, client);
					weapon = GetPlayerMainWeapon(client);
					return Plugin_Continue;
				}
			}
		}

		if (buttons & IN_JUMP && !g_bIsBot[client] && HxIsPlayerIncapacitated(client))
		{
			int owner = GetEntPropEnt(client, Prop_Send, "m_reviveOwner");
			if (owner <= 0 || owner > MaxClients || owner == client || !g_bIsInGame[owner])
			{
				return Plugin_Continue;
			}

			if (g_bHasOverrideAccess[owner])
			{
				return Plugin_Continue;
			}

			float blockTime = l4d2_blockhealing_time_use.FloatValue;
			if (blockTime > 0.0)
			{
				g_bIsBlockingUse[owner] = true;
				CreateTimer(blockTime, BlockUse_Timer, owner, TIMER_FLAG_NO_MAPCHANGE);
			}
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

stock int HxGetPlayerUseAction(int client)
{
	return view_as<int>(GetEntProp(client, Prop_Send, "m_iCurrentUseAction"));
}

stock int HxGetPlayerUseActionTarget(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_useActionTarget");
}

stock bool HxIsPlayerIncapacitated(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1));
}

public Action BlockUse_Timer(Handle timer, any client)
{
	g_bIsBlockingUse[client] = false;
	return Plugin_Stop;
}

public Action BlockFire_Timer(Handle timer, any client)
{
	g_bIsBlockingFire[client] = false;
	return Plugin_Stop;
}

public Action BlockMedkit_Timer(Handle timer, any client)
{
	g_bIsBlockingMedkit[client] = false;
	return Plugin_Stop;
}

public Action ResetRecentlyOnLadder_Timer(Handle timer, any client)
{
	g_bWasRecentlyOnLadder[client] = false;
	return Plugin_Stop;
}

static int GetPlayerMainWeapon(int client)
{
	int weapon = GetPlayerWeaponSlot(client, 0);
	if (weapon <= 0 || !IsValidEdict(weapon))
	{
		weapon = GetPlayerWeaponSlot(client, 1);
		if (weapon <= 0 || !IsValidEdict(weapon))
		{
			weapon = 0;
		}
	}
	return weapon;
}