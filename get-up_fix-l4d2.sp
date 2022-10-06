#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <l4d2_direct>
//#include <left4dhooks>

public Plugin myinfo = 
{
    name = "[L4D2] Get-Up Fix",
    author = "Blade, ProdigySim, DieTeetasse, Stabby, Jahze",
    description = "Fixes Get-Up Animations.",
    version = "1.7",
    url = "http://bitbucket.org/ProdigySim/misc-sourcemod-plugins/"
};

#define ANIM_HUNTER_LENGTH 2.2
#define ANIM_CHARGER_STANDARD_LENGTH 2.9
#define ANIM_CHARGER_SLAMMED_WALL_LENGTH 3.9
#define ANIM_CHARGER_SLAMMED_GROUND_LENGTH 4.0

#define ANIM_EVENT_CHARGER_GETUP 78

#define GETUP_TIMER_INTERVAL 0.5

#define INDEX_HUNTER 1
#define INDEX_CHARGER 2
#define INDEX_CHARGER_WALL 3
#define INDEX_CHARGER_GROUND 4

int PropOff_nSequence;

public void OnPluginStart()
{
    HookEvent("pounce_end", OnPounceOrChargerPummelEnd);
    HookEvent("charger_pummel_end", OnPounceOrChargerPummelEnd);
    HookEvent("charger_killed", OnChargerKilled);

    PropOff_nSequence = FindSendPropInfo("CTerrorPlayer", "m_nSequence");
}

public Action OnPounceOrChargerPummelEnd(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("victim"));
    if (client <= 0 || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		return;

    CreateTimer(0.1, Timer_ProcessClient, client);
}

public Action Timer_ProcessClient(Handle timer, any client)
{
	ProcessClient(client);
	return Plugin_Stop;
}

void ProcessClient(int client)
{
	if (CollectGetUpAnimInfo(client, INDEX_HUNTER) == 0 && CollectGetUpAnimInfo(client, INDEX_CHARGER) == 0 && CollectGetUpAnimInfo(client, INDEX_CHARGER_WALL) == 0 && CollectGetUpAnimInfo(client, INDEX_CHARGER_GROUND) == 0 && CollectIncapAnimInfo(client, 1) == 0 && CollectIncapAnimInfo(client, 2) == 0)
		return;

	int sequence = GetEntData(client, PropOff_nSequence);
	if (sequence != CollectGetUpAnimInfo(client, INDEX_HUNTER) && sequence != CollectGetUpAnimInfo(client, INDEX_CHARGER) 
	&&  sequence != CollectGetUpAnimInfo(client, INDEX_CHARGER_WALL) && sequence != CollectGetUpAnimInfo(client, INDEX_CHARGER_GROUND))
	{
		if (sequence != CollectIncapAnimInfo(client, 1) && sequence != CollectIncapAnimInfo(client, 2))
		{
			L4D2Direct_DoAnimationEvent(client, ANIM_EVENT_CHARGER_GETUP);
		}

		return;
	}

	Handle tempStack = CreateStack(3);
	PushStackCell(tempStack, client);
	PushStackCell(tempStack, sequence);

	if (sequence == CollectGetUpAnimInfo(client, INDEX_HUNTER))
	{
		CreateTimer(ANIM_HUNTER_LENGTH, Timer_CheckClient, tempStack);
	}
	else if (sequence == CollectGetUpAnimInfo(client, INDEX_CHARGER))
	{
		CreateTimer(ANIM_CHARGER_STANDARD_LENGTH, Timer_CheckClient, tempStack);
	}
	else if (sequence == CollectGetUpAnimInfo(client, INDEX_CHARGER_WALL))
	{
		CreateTimer(ANIM_CHARGER_SLAMMED_WALL_LENGTH - 2.5 * GetEntPropFloat(client, Prop_Send, "m_flCycle"), Timer_CheckClient, tempStack);
	}
	else if (sequence == CollectGetUpAnimInfo(client, INDEX_CHARGER_GROUND))
	{
		CreateTimer(ANIM_CHARGER_SLAMMED_GROUND_LENGTH - 2.5 * GetEntPropFloat(client, Prop_Send, "m_flCycle"), Timer_CheckClient, tempStack);
	}
}

public Action Timer_CheckClient(Handle timer, any tempStack)
{
	int client, oldSequence;
	float duration;
	PopStackCell(tempStack, oldSequence);
	PopStackCell(tempStack, client);

	int newSequence = GetEntData(client, PropOff_nSequence);
	if (newSequence == oldSequence)
		return Plugin_Stop;

	if (newSequence == CollectGetUpAnimInfo(client, INDEX_HUNTER))
		duration = ANIM_HUNTER_LENGTH;
	else if (newSequence == CollectGetUpAnimInfo(client, INDEX_CHARGER))
		duration = ANIM_CHARGER_STANDARD_LENGTH;
	else if (newSequence == CollectGetUpAnimInfo(client, INDEX_CHARGER_WALL))
		duration = ANIM_CHARGER_SLAMMED_WALL_LENGTH;
	else if (newSequence == CollectGetUpAnimInfo(client, INDEX_CHARGER_GROUND))
		duration = ANIM_CHARGER_SLAMMED_GROUND_LENGTH;
	else
		return Plugin_Stop;

	SetEntPropFloat(client, Prop_Send, "m_flCycle", duration);
	return Plugin_Stop;
}

public Action OnChargerKilled(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
        return;

    CreateTimer(GETUP_TIMER_INTERVAL, GetupTimer, attacker);
}

bool bAlreadyChecked[MAXPLAYERS + 1];

public Action ResetAlreadyCheckedBool(Handle timer, any client)
{
	bAlreadyChecked[client] = false;
	return Plugin_Stop;
}

public Action GetupTimer(Handle timer, any attacker)
{
	for (int n = 1; n <= MaxClients; n++)
	{
		if (IsClientInGame(n) && GetClientTeam(n) == 2 && !bAlreadyChecked[n])
		{
			int seq = GetEntProp(n, Prop_Send, "m_nSequence");
			if (seq == CollectGetUpAnimInfo(n, INDEX_CHARGER_WALL))
			{
				if (n == attacker)
					SetEntPropFloat(attacker, Prop_Send, "m_flCycle", ANIM_CHARGER_SLAMMED_WALL_LENGTH);
				else
				{
					bAlreadyChecked[n] = true;
					CreateTimer(ANIM_CHARGER_SLAMMED_WALL_LENGTH, ResetAlreadyCheckedBool, n);
					ProcessClient(n);
				}

				break;
			}
			else if (seq == CollectGetUpAnimInfo(n, INDEX_CHARGER_GROUND))
			{
				if (n == attacker)
					SetEntPropFloat(attacker, Prop_Send, "m_flCycle", ANIM_CHARGER_SLAMMED_GROUND_LENGTH);
				else
				{
					bAlreadyChecked[n] = true;
					CreateTimer(ANIM_CHARGER_SLAMMED_GROUND_LENGTH, ResetAlreadyCheckedBool, n);
					ProcessClient(n);
				}

				break;
			}
		}
	}

	return Plugin_Stop;
}

stock int CollectGetUpAnimInfo(int client, int index_no)
{
	int playedGetUpAnim = 0;

	char clientModel[PLATFORM_MAX_PATH];
	GetClientModel(client, clientModel, sizeof(clientModel));
	if(StrEqual(clientModel, "models/survivors/survivor_coach.mdl", false))
	{
		switch (index_no)
		{
			case INDEX_HUNTER: playedGetUpAnim = 621;
			case INDEX_CHARGER: playedGetUpAnim = 656;
			case INDEX_CHARGER_WALL: playedGetUpAnim = 660;
			case INDEX_CHARGER_GROUND: playedGetUpAnim = 661;
		}
	}
	else if(StrEqual(clientModel, "models/survivors/survivor_gambler.mdl", false))
	{
		switch (index_no)
		{
			case INDEX_HUNTER: playedGetUpAnim = 620;
			case INDEX_CHARGER: playedGetUpAnim = 667;
			case INDEX_CHARGER_WALL: playedGetUpAnim = 671;
			case INDEX_CHARGER_GROUND: playedGetUpAnim = 672;
		}
	}
	else if(StrEqual(clientModel, "models/survivors/survivor_producer.mdl", false))
	{
		switch (index_no)
		{
			case INDEX_HUNTER: playedGetUpAnim = 629;
			case INDEX_CHARGER: playedGetUpAnim = 674;
			case INDEX_CHARGER_WALL: playedGetUpAnim = 678;
			case INDEX_CHARGER_GROUND: playedGetUpAnim = 679;
		}
	}
	else if(StrEqual(clientModel, "models/survivors/survivor_mechanic.mdl", false))
	{
		switch (index_no)
		{
			case INDEX_HUNTER: playedGetUpAnim = 625;
			case INDEX_CHARGER: playedGetUpAnim = 671;
			case INDEX_CHARGER_WALL: playedGetUpAnim = 675;
			case INDEX_CHARGER_GROUND: playedGetUpAnim = 676;
		}
	}
	else if(StrEqual(clientModel, "models/survivors/survivor_manager.mdl", false))
	{
		switch (index_no)
		{
			case INDEX_HUNTER: playedGetUpAnim = 528;
			case INDEX_CHARGER: playedGetUpAnim = 759;
			case INDEX_CHARGER_WALL: playedGetUpAnim = 763;
			case INDEX_CHARGER_GROUND: playedGetUpAnim = 764;
		}
	}
	else if(StrEqual(clientModel, "models/survivors/survivor_teenangst.mdl", false))
	{
		switch (index_no)
		{
			case INDEX_HUNTER: playedGetUpAnim = 537;
			case INDEX_CHARGER: playedGetUpAnim = 819;
			case INDEX_CHARGER_WALL: playedGetUpAnim = 823;
			case INDEX_CHARGER_GROUND: playedGetUpAnim = 824;
		}
	}
	else if(StrEqual(clientModel, "models/survivors/survivor_namvet.mdl", false))
	{
		switch (index_no)
		{
			case INDEX_HUNTER: playedGetUpAnim = 528;
			case INDEX_CHARGER: playedGetUpAnim = 759;
			case INDEX_CHARGER_WALL: playedGetUpAnim = 763;
			case INDEX_CHARGER_GROUND: playedGetUpAnim = 764;
		}
	}
	else if(StrEqual(clientModel, "models/survivors/survivor_biker.mdl", false))
	{
		switch (index_no)
		{
			case INDEX_HUNTER: playedGetUpAnim = 531;
			case INDEX_CHARGER: playedGetUpAnim = 762;
			case INDEX_CHARGER_WALL: playedGetUpAnim = 766;
			case INDEX_CHARGER_GROUND: playedGetUpAnim = 767;
		}
	}
	
	return playedGetUpAnim;
}

stock int CollectIncapAnimInfo(int client, int incap_type)
{
	int playedIncapAnim = 0;

	char modelClient[PLATFORM_MAX_PATH];
	GetClientModel(client, modelClient, sizeof(modelClient));
	if(StrEqual(modelClient, "models/survivors/survivor_coach.mdl", false))
	{
		switch (incap_type)
		{
			case 1: playedIncapAnim = 613;
			case 2: playedIncapAnim = 614;
		}
	}
	else if(StrEqual(modelClient, "models/survivors/survivor_gambler.mdl", false))
	{
		switch (incap_type)
		{
			case 1: playedIncapAnim = 612;
			case 2: playedIncapAnim = 613;
		}
	}
	else if(StrEqual(modelClient, "models/survivors/survivor_producer.mdl", false))
	{
		switch (incap_type)
		{
			case 1: playedIncapAnim = 621;
			case 2: playedIncapAnim = 622;
		}
	}
	else if(StrEqual(modelClient, "models/survivors/survivor_mechanic.mdl", false))
	{
		switch (incap_type)
		{
			case 1: playedIncapAnim = 617;
			case 2: playedIncapAnim = 618;
		}
	}
	else if(StrEqual(modelClient, "models/survivors/survivor_manager.mdl", false))
	{
		switch (incap_type)
		{
			case 1: playedIncapAnim = 520;
			case 2: playedIncapAnim = 521;
		}
	}
	else if(StrEqual(modelClient, "models/survivors/survivor_teenangst.mdl", false))
	{
		switch (incap_type)
		{
			case 1: playedIncapAnim = 525;
			case 2: playedIncapAnim = 526;
		}
	}
	else if(StrEqual(modelClient, "models/survivors/survivor_namvet.mdl", false))
	{
		switch (incap_type)
		{
			case 1: playedIncapAnim = 520;
			case 2: playedIncapAnim = 521;
		}
	}
	else if(StrEqual(modelClient, "models/survivors/survivor_biker.mdl", false))
	{
		switch (incap_type)
		{
			case 1: playedIncapAnim = 523;
			case 2: playedIncapAnim = 524;
		}
	}

	return playedIncapAnim;
}
