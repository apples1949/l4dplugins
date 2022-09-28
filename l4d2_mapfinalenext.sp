#pragma semicolon 1
#include <sourcemod>
#pragma newdecls required

char sg_l4d2Map[48];
char sg_mode[24];
int iPluginS;
int ig_coop;
int ig_rs;

public Plugin myinfo =
{
	name = "[L4D2] mapfinalenext",
	author = "MAKS",
	description = "L4D2 Coop Map Finale Next",
	version = "1.6",
	url = "forums.alliedmods.net/showthread.php?p=2436146"
};

public void OnPluginStart()
{
	ig_rs = 0;
	iPluginS = 1;

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("finale_win",  Event_FinalWin,   EventHookMode_PostNoCopy);
}

public void OnMapStart()
{
	ig_coop = 0;
	GetCurrentMap(sg_l4d2Map, sizeof(sg_l4d2Map)-1);
	if (sg_l4d2Map[0] == 'C') // fix
	{
		sg_l4d2Map[0] = 'c';
	}

	GetConVarString(FindConVar("mp_gamemode"), sg_mode, sizeof(sg_mode)-1);

	if (!strcmp(sg_mode, "coop", true))
	{
		ig_coop = 1;
	}
	if (!strcmp(sg_mode, "realism", true))
	{
		ig_coop = 1;
	}

	ig_rs = 0;
	if (iPluginS)
	{
		ig_rs = 3;
		iPluginS = 0;
	}
}

public Action HxTimerNextMap(Handle timer)
{
	ig_rs = 0;
	if (StrContains(sg_l4d2Map, "c1m", true) != -1)
	{
		ServerCommand("changelevel c6m1_riverbank");
		return Plugin_Stop;
	}
	if (StrContains(sg_l4d2Map, "c6m", true) != -1)
	{
		ServerCommand("changelevel c2m1_highway");
		return Plugin_Stop;
	}
	if (StrContains(sg_l4d2Map, "c2m", true) != -1)
	{
		ServerCommand("changelevel c3m1_plankcountry");
		return Plugin_Stop;
	}
	if (StrContains(sg_l4d2Map, "c3m", true) != -1)
	{
		ServerCommand("changelevel c4m1_milltown_a");
		return Plugin_Stop;
	}
	if (StrContains(sg_l4d2Map, "c4m", true) != -1)
	{
		ServerCommand("changelevel c5m1_waterfront");
		return Plugin_Stop;
	}
	if (StrContains(sg_l4d2Map, "c5m", true) != -1)
	{
		ServerCommand("changelevel c13m1_alpinecreek");
		return Plugin_Stop;
	}
	if (StrContains(sg_l4d2Map, "c13m", true) != -1)
	{
		ServerCommand("changelevel c8m1_apartment");
		return Plugin_Stop;
	}
	if (StrContains(sg_l4d2Map, "c8m", true) != -1)
	{
		ServerCommand("changelevel c9m1_alleys");
		return Plugin_Stop;
	}
	if (StrContains(sg_l4d2Map, "c9m", true) != -1)
	{
		ServerCommand("changelevel c10m1_caves");
		return Plugin_Stop;
	}
	if (StrContains(sg_l4d2Map, "c10m", true) != -1)
	{
		ServerCommand("changelevel c11m1_greenhouse");
		return Plugin_Stop;
	}
	if (StrContains(sg_l4d2Map, "c11m", true) != -1)
	{
		ServerCommand("changelevel c12m1_hilltop");
		return Plugin_Stop;
	}
	if (StrContains(sg_l4d2Map, "c12m", true) != -1)
	{
		ServerCommand("changelevel c7m1_docks");
		return Plugin_Stop;
	}
	if (StrContains(sg_l4d2Map, "c7m", true) != -1)
	{
		ServerCommand("changelevel c14m1_junkyard");
		return Plugin_Stop;
	}

	ServerCommand("changelevel c1m1_hotel");
	return Plugin_Stop;
}

public void Event_RoundStart(Event event, const char [] name, bool dontBroadcast)
{
	if (ig_coop)
	{
		ig_rs += 1;
		if (ig_rs > 4)
		{
			int i = 1;
			while (i <= MaxClients)
			{
				if (IsClientInGame(i))
				{
					PrintToChat(i, "\x05Change Level");
				}
				i += 1;
			}
			CreateTimer(8.0, HxTimerNextMap, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public void Event_FinalWin(Event event, const char [] name, bool dontBroadcast)
{
	if (ig_coop)
	{
		CreateTimer(7.0, HxTimerNextMap, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnMapEnd()
{
	ig_rs = 0;
}
