#include <sourcemod>
#define IS_CLIENT(%1) (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1) (GetClientTeam(%1) == 2)
#define IS_CONNECTED_INGAME(%1) (IsClientConnected(%1) && IsClientInGame(%1))
#define IS_VALID_CLIENT(%1) (IS_CLIENT(%1) && IS_CONNECTED_INGAME(%1))
#define IS_VALID_SURVIVOR(%1) (IS_VALID_CLIENT(%1) && IS_SURVIVOR(%1))

ConVar hCountMvpDelay;

int killif[MAXPLAYERS+1];
int killifs[MAXPLAYERS+1];
int damageff[MAXPLAYERS+1];
int pdamageff[MAXPLAYERS+1];
float CountMvpDelay;
Handle Broadcast;

public Plugin myinfo =
{
	name = "[L4D2]击杀排名",
	author = "-",
	description = "显示玩家击杀的特感、小僵尸排名，以及友伤，判断黑枪王",
	version = "1.0",
	url = "none"
};

public OnPluginStart()
{
	hCountMvpDelay = CreateConVar("kill_mvp_display_delay", "60", "击杀排名多久显示一次(秒).", 0, true, 10.0, true, 9999.0);
	HookConVarChange(hCountMvpDelay, ConVarMvpDelays);
	HookEvent("player_death", Event_kill_infected, EventHookMode_Pre);
	HookEvent("player_hurt", PlayerHurt, EventHookMode_Pre);
	HookEvent("infected_death", kill_SS, EventHookMode_Pre);
	HookEvent("map_transition", MapTransition, EventHookMode_Pre);
	HookEvent("round_start", RoundStart, EventHookMode_Pre);
	RegConsoleCmd("sm_mvp", Command_kill);
	kill_infected();
	AutoExecConfig(true, "l4d2_kill_mvp");
}

public void OnConfigsExecuted()
{
	CountMvpDelay = GetConVarFloat(hCountMvpDelay);
}

public void OnClientDisconnect(int client)
{
	killif[client] = 0;
	killifs[client] = 0;
	damageff[client] = 0;
	pdamageff[client] = 0;
}

public ConVarMvpDelays(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CountMvpDelay = GetConVarFloat(hCountMvpDelay);
}

public Action MapTransition(Event event, const char[] name, bool dontBroadcast)
{
	if (Broadcast != INVALID_HANDLE)
	{
		KillTimer(Broadcast);
		Broadcast = INVALID_HANDLE;
	}
	displaykillinfected();
	return Plugin_Continue;
}

public Action RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	kill_infected();
	PrintToServer("round_start");
	return Plugin_Continue;
}

public Action Command_kill(client, args)
{
	displaykillinfected(client);
	return Plugin_Handled;
}

public Action kill_SS(Event event, const char[] name, bool dontBroadcast)
{
	int killer = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (IS_VALID_SURVIVOR(killer))
	{
		killifs[killer] += 1;
		if (Broadcast == INVALID_HANDLE)
		{
			displaykillinfected();
			Broadcast = CreateTimer(CountMvpDelay, killinfected_dis, _, TIMER_REPEAT);
		}
	}
	return Plugin_Continue;
}


public Action Event_kill_infected(Event event, const char[] name, bool dontBroadcast)
{
	int killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IS_VALID_SURVIVOR(killer))
	{
		if (IS_VALID_CLIENT(client) && GetClientTeam(client) == 3)
		{
			killif[killer] += 1;
			if (Broadcast == INVALID_HANDLE)
			{
				displaykillinfected();
				Broadcast = CreateTimer(CountMvpDelay, killinfected_dis, _, TIMER_REPEAT);
			}
		}
	}
	return Plugin_Continue;
}

public Action PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int damageDone = GetEventInt(event, "dmg_health");

	if (IS_VALID_SURVIVOR(victim) && IS_VALID_SURVIVOR(attacker) && victim != attacker)
	{
		damageff[attacker] += damageDone;
		pdamageff[victim] += damageDone;
	}
	return Plugin_Continue;
}

public Action killinfected_dis(Handle timer)
{
	displaykillinfected();
}

displaykillinfected(int Client=0)
{
	int players = 0;
	int players_clients[MAXPLAYERS+1];

	for (int i = 0; i <= MaxClients; i++)
	{   
		if (IS_VALID_SURVIVOR(i))
		{
			players_clients[players] = i;
			players++;
		}
	}

	if (players > 0)
	{
		PrintToChatSurvivor(Client, "\x05[\x04MVP\x05] \x03击杀排名:");
		SortCustom1D(players_clients, players, SortByDamageDesc);
		for (int n; n < players; n++)
		{
			int client = players_clients[n];
			int killss = killif[client];
			int killsss = killifs[client];
			int damageffss = damageff[client];
			PrintToChatSurvivor(Client, "\x05[\x04排名 \x04%d\x05] \x01%N - \x03特感: \x04%d\x03, 丧尸: \x04%d\x03, 友伤: \x04%d", n + 1, client, killss, killsss, damageffss);
		}

		SortCustom1D(players_clients, players, SortByPffDamageDesc);
		int pdamageffss = pdamageff[players_clients[0]];
		PrintToChatSurvivor(Client, "\x04<挨打王> \x01%N \x03- 承受友伤: \x04%d", players_clients[0], pdamageffss);

		SortCustom1D(players_clients, players, SortByffDamageDesc);
		int damageffss = damageff[players_clients[0]];
		PrintToChatSurvivor(Client, "\x04<黑枪王> \x01%N \x03- 造成友伤: \x04%d", players_clients[0], damageffss);
	}
}

PrintToChatSurvivor(int client, char[] str, any ...)
{
	char buffer[254];
	if (IS_VALID_CLIENT(client))
	{
		SetGlobalTransTarget(client);
		VFormat(buffer, sizeof(buffer), str, 3);
		PrintToChat(client, "%s", buffer);
	}
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IS_VALID_CLIENT(i) && !IsFakeClient(i))
			{
				SetGlobalTransTarget(i);
				VFormat(buffer, sizeof(buffer), str, 3);
				PrintToChat(i, "%s", buffer);
			}
		}
	}	
}

SortByDamageDesc(elem1, elem2, array[], Handle hndl)
{
	if (killif[elem2] < killif[elem1])
	{
		return -1;
	}
	else if (killif[elem2] == killif[elem1])
	{
		if (killifs[elem2] < killifs[elem1])
		{
			return -1;
		}
		return killifs[elem1] < killifs[elem2];
	}
	return killif[elem1] < killif[elem2];
}

SortByffDamageDesc(elem1, elem2, array[], Handle hndl)
{
	if (damageff[elem2] < damageff[elem1])
	{
		return -1;
	}
	return damageff[elem1] < damageff[elem2];
}

SortByPffDamageDesc(elem1, elem2, array[], Handle hndl)
{
	if (pdamageff[elem2] < pdamageff[elem1])
	{
		return -1;
	}
	return pdamageff[elem1] < pdamageff[elem2];
}

kill_infected()
{
	for (int i; i <= MAXPLAYERS; i++)
	{
		killif[i] = 0;
		killifs[i] = 0;
		damageff[i] = 0;
		pdamageff[i] = 0;
	}
	if (Broadcast != INVALID_HANDLE)
	{
		KillTimer(Broadcast);
	}
	Broadcast = INVALID_HANDLE;
}