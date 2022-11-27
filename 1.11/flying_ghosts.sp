#include <sourcemod>

#define GROUND_CHECK_DELAY 0.25

public Plugin:myinfo =
{
	name = "Flying Ghosts",
	author = "CanadaRox",
	description = "Allows ghosts to fly but only spawn like normal",
	version = "1",
	url =
		"https://github.com/CanadaRox/sourcemod-plugins/tree/master/flying_ghosts"
};

new bool:bIsHoldingKey[MAXPLAYERS+1];
new bool:bBlockSpawn[MAXPLAYERS+1];
new Handle:hGroundCheckTimer[MAXPLAYERS+1];

public OnPluginStart()
{
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
}

public OnMapStart()
{
	for (new client = 1; client <= MAXPLAYERS; client++)
	{
		hGroundCheckTimer[client] = INVALID_HANDLE;
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3],
		Float:angles[3], &weapon)
{
	if (IsClientInGame(client) && !IsFakeClient(client) &&
			IsGhostInfected(client))
	{
		if (buttons & IN_RELOAD)
		{
			if (!bIsHoldingKey[client])
			{
				bIsHoldingKey[client] = true;
				if (GetEntityMoveType(client) == MOVETYPE_WALK)
				{
					SetEntityMoveType(client, MOVETYPE_NOCLIP);
					bBlockSpawn[client] = true;
					hGroundCheckTimer[client] = CreateTimer(GROUND_CHECK_DELAY,
							GroundCheck_Timer, GetClientUserId(client), TIMER_REPEAT |
							TIMER_FLAG_NO_MAPCHANGE);
				}
				else
					SetEntityMoveType(client, MOVETYPE_WALK);
			}
		}
		else
		{
			bIsHoldingKey[client] = false;
		}

		if (buttons & IN_ATTACK)
		{
			if (bBlockSpawn[client])
				buttons &= ~IN_ATTACK;
		}
	}
}

public Action:GroundCheck_Timer(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client == 0 || GetEntityFlags(client) & FL_ONGROUND)
	{
		bBlockSpawn[client] = false;
		hGroundCheckTimer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}


public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			bIsHoldingKey[client] = false;
			if (hGroundCheckTimer[client] != INVALID_HANDLE)
				CloseHandle(hGroundCheckTimer[client]);
			hGroundCheckTimer[client] = INVALID_HANDLE;
			bBlockSpawn[client] = false;
		}
	}
}

public OnClientDisconnect(client)
{
	bIsHoldingKey[client] = false;
	if (hGroundCheckTimer[client] != INVALID_HANDLE)
		CloseHandle(hGroundCheckTimer[client]);
	hGroundCheckTimer[client] = INVALID_HANDLE;
	bBlockSpawn[client] = false;
}

stock IsGhostInfected(client)
{
	return GetClientTeam(client) == 3 && IsPlayerAlive(client) &&
		GetEntProp(client, Prop_Send, "m_isGhost");
}
