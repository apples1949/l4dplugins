#include <sourcemod>
#include <sdktools>
#include <colors>

#include <l4d2_skill_detect>

#define DEBUG 0

new bool:g_bIsTankAlive;
new bool:IsRoundEnd;
new bool:DoorClosed;

new String:botchat[256];

public Plugin:myinfo = 
{
	name = "L4D2 Bot Troll & Tank Sound",
	author = "Blazers Team",
	description = "Bot is now taunt?",
	version = "1.0",
	url = ""
};

public OnMapStart()
{
	PrecacheSound("ui/pickup_secret01.wav");
}

public OnPluginStart()
{
	HookEvent("survivor_rescued", SurvivorRescued);
	HookEvent("player_incapacitated", PlayerIncap);
	HookEvent("door_close", DoorClose);
	HookEvent("lunge_pounce", HunterCapped);
	HookEvent("player_entered_checkpoint", OnReachSafe);
	HookEvent("door_open",DoorOpen);
	HookEvent("tank_spawn", EventHook:OnTankSpawn, EventHookMode_PostNoCopy);
	HookEvent("round_start", EventHook:OnRoundStart, EventHookMode_PostNoCopy);
}

public OnRoundStart()
{
	IsRoundEnd = false;
	g_bIsTankAlive = false;
	DoorClosed = false;
}

public OnTankSpawn()
{
	if (!g_bIsTankAlive)
	{
		g_bIsTankAlive = true;
		EmitSoundToAll("ui/pickup_secret01.wav");
	}
}

public OnReachSafe(Handle:event, const String:name[], bool:dontBroadcast)
{
	IsRoundEnd = true;
}

public PlayerIncap(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidPlayer(client) && GetClientTeam(client) == 2 && !IsFakeClient(client))
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsValidPlayer(i))
			{
				if (IsFakeClient(i) && GetClientTeam(i) == 2)
				{
					switch (GetRandomInt(1, 7))
					{
						case 1:
						{
							Format(botchat,sizeof(botchat),"go delete yo game %N",client);
						}
						case 2:
						{
							Format(botchat,sizeof(botchat),"muahahaha look at this noob");
						}
						case 3:
						{
							Format(botchat,sizeof(botchat),"fucking noob");
						}
						case 4:
						{
							Format(botchat,sizeof(botchat),"lol retarded");
						}
						case 5:
						{
							Format(botchat,sizeof(botchat),"go play campaign %N",client);
						}
						case 6:
						{
							Format(botchat,sizeof(botchat),"%N damn fucking noob",client);
						}
						case 7:
						{
							Format(botchat,sizeof(botchat),"vote kick %N?",client);
						}
					}
					CPrintToChatAll("{blue}%N{default} :  %s", i, botchat);
				}
			}
		}
	}
}

public DoorOpen(Handle:event, const String:name[], bool:dontBroadcast)
{
	new bool:safedoor = GetEventBool(event, "checkpoint");
	if (safedoor)
	{
		if (!DoorClosed) DoorClosed = false;
	}
}

public DoorClose(Handle:event, const String:name[], bool:dontBroadcast)
{
	new bool:safedoor = GetEventBool(event, "checkpoint");
	if (safedoor && IsRoundEnd && !DoorClosed)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsClientConnected(i) || !IsValidPlayer(i)) return;
			if (IsFakeClient(i) && GetClientTeam(i) == 2)
			{
				switch (GetRandomInt(1, 6))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"lol ez win");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"muahahaha damn noob infected");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"so ez try harder next time");
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"ez pz");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"ez game ez life");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"those noob cant kill me");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", i, botchat);
			}
		}
		DoorClosed = true;
	}
}

public OnBoomerPop( attacker, victim, shoveCount, Float:timeAlive )
{
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(victim))
	{
		if (IsFakeClient(attacker))
		{
			switch (GetRandomInt(1, 4))
			{
				case 1:
				{
					Format(botchat,sizeof(botchat),"useless boomer");
				}
				case 2:
				{
					Format(botchat,sizeof(botchat),"lol noob boomer %N",victim);
				}
				case 3:
				{
					Format(botchat,sizeof(botchat),"try harder %N",victim);
				}
				case 4:
				{
					Format(botchat,sizeof(botchat),"i popped noob boomer muhahaha");
				}
			}
			CPrintToChatAll("{blue}%N{default} :  %s", attacker, botchat);
		}
	}
}

public OnBoomerVomitLanded( boomer, amount )
{
	if (IsValidPlayer(boomer) && IsClientInGame(boomer))
	{
		if (IsFakeClient(boomer))
		{
			if (amount > 0)
				CPrintToChatAll("{red}Boomer{default} :  Big Target Hard 2 Hit");
		}
	}
}
public OnTankRockEaten( attacker, victim )
{
	if (IsValidPlayer(attacker) && IsValidPlayer(victim) && !IsFakeClient(victim))
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsClientConnected(i) || !IsValidPlayer(i)) return;
			if (IsFakeClient(i) && GetClientTeam(i) == 2)
			{
				switch (GetRandomInt(1, 5))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"hide noob");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"stop eating rocks");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"u fucking noob %N",victim);
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"damn noob rockeater");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"hey dont eat rocks ok?");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", i, botchat);
			}
		}
	}
}

public HunterCapped(Handle:event, const String:name[], bool:dontBroadcast)
{
	new hunter = GetClientOfUserId(GetEventInt(event, "userid"));
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	
	if (IsValidPlayer(hunter) && IsValidPlayer(victim) && !IsFakeClient(victim))
	{
		if (IsFakeClient(hunter))
		{
			CPrintToChatAll("{red}Hunter{default} :  why u failed to skeet it?");
		}
	}	
}

public SurvivorRescued(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsValidPlayer(i))
		{
			if (IsFakeClient(i) && GetClientTeam(i) == 2)
			{
				switch (GetRandomInt(1, 6))
				{
					case 1:
					{
						Format(botchat,sizeof(botchat),"lol ez win");
					}
					case 2:
					{
						Format(botchat,sizeof(botchat),"muahahaha damn noob infected");
					}
					case 3:
					{
						Format(botchat,sizeof(botchat),"so ez try harder next time");
					}
					case 4:
					{
						Format(botchat,sizeof(botchat),"ez pz");
					}
					case 5:
					{
						Format(botchat,sizeof(botchat),"ez game ez life");
					}
					case 6:
					{
						Format(botchat,sizeof(botchat),"those noob cant kill me");
					}
				}
				CPrintToChatAll("{blue}%N{default} :  %s", i, botchat);
			}
		}
	}
}
static bool:IsValidPlayer(client)
{
	if (0 < client <= MaxClients)
		return true;
	return false;
}