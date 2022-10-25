#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.5.0"
	
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

bool GameStarted;
Handle hDropMeleeUnsafe;

float PressTime[MAXPLAYERS+1];
 
int MODEL_DEFIB;
char WeaponNames[][] =
{
	"weapon_pumpshotgun",
	"weapon_autoshotgun",
	"weapon_rifle",
	"weapon_smg",
	"weapon_hunting_rifle",
	"weapon_sniper_scout",
	"weapon_sniper_military",
	"weapon_sniper_awp",
	"weapon_smg_silenced",
	"weapon_smg_mp5",
	"weapon_shotgun_spas",
	"weapon_shotgun_chrome",
	"weapon_rifle_sg552",
	"weapon_rifle_desert",
	"weapon_rifle_ak47",
	"weapon_grenade_launcher",
	"weapon_rifle_m60", //0-16
	"weapon_pistol",
	"weapon_pistol_magnum",
	"weapon_chainsaw",
	"weapon_melee", //17-20
	"weapon_pipe_bomb",
	"weapon_molotov",
	"weapon_vomitjar", //21-23
	"weapon_first_aid_kit",
	"weapon_defibrillator",
	"weapon_upgradepack_explosive",
	"weapon_upgradepack_incendiary", //24-27
	"weapon_pain_pills",
	"weapon_adrenaline", //28-29
	"weapon_gascan",
	"weapon_propanetank",
	"weapon_oxygentank",
	"weapon_gnome",
	"weapon_cola_bottles",
	"weapon_fireworkcrate" //30-35
};

public Plugin myinfo =
{
	name = "[L4D2] Weapon Drop",
	author = "Machine, dcx2, Electr000999",
	description = "Allows players to drop the weapon they are holding",
	version = PLUGIN_VERSION,
	url = "www.AlliedMods.net"
};

public void OnPluginStart()
{
	CreateConVar("sm_drop_version", PLUGIN_VERSION, "[L4D2] Weapon Drop Version", FCVAR_SPONLY|FCVAR_REPLICATED);
	hDropMeleeUnsafe = CreateConVar("sm_drop_melee_unsafe", "1", "Enable drop melee weapon out unsafe area.");
	
	HookEvent("mission_lost", Event_MissionLost);
	HookEvent("round_end", Event_MissionLost);
	HookEvent("map_transition", Event_MissionLost);

	LoadTranslations("common.phrases");
}

public void OnMapStart()
{
	GameStarted = false;
	MODEL_DEFIB = PrecacheModel("models/w_models/weapons/w_eq_defibrillator.mdl", true);
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	GameStarted = true;
}

public void Event_MissionLost(Handle event, char[] name, bool dontBroadcast)
{
	GameStarted = false;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impuls, float vel[3], float angles[3], int& weapon)
{
	if (impuls == 201) {
		if(GetClientTeam(client) == 2 && !IsFakeClient(client) && IsPlayerAlive(client))
		{
			float time = GetEngineTime();
			if(time - PressTime[client] < 0.3)
			{
				Command_Drop(client, 0);
				PressTime[client] = 0.0;
			}
			else PressTime[client]=time; 			 
		} 
	}
}

public Action Command_Drop(int client, int args)
{
	int slot;
	char weapon[32];
	GetClientWeapon(client, weapon, sizeof(weapon));
	for (int count = 0; count <= 35; count++)
	{
		switch(count)
		{
			case 17: slot = 1;
			case 21: slot = 2;
			case 24: slot = 3;
			case 28: slot = 4;
			case 30: slot = 5;
		}

		if (GameStarted) {
			if ( GetConVarBool(hDropMeleeUnsafe) ) {
				if (slot != 1) continue;
			}
			else continue;
		}

		if (StrEqual(weapon, WeaponNames[count]))
		{
			DropSlot(client, slot);
		}
	}
	return Plugin_Handled;
}

public void DropSlot(int client, int slot)
{
	if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
	{
		if (GetPlayerWeaponSlot(client, slot) > 0)
		{
			int weapon = GetPlayerWeaponSlot(client, slot);
			SDKCallWeaponDrop(client, weapon);
		}
	}
}

stock void SDKCallWeaponDrop(int client, int weapon)
{
	char classname[32];
	float vecAngles[3], vecTarget[3], vecVelocity[3];

	if (GetPlayerEye(client, vecTarget))
	{
		GetClientEyeAngles(client, vecAngles);
		GetAngleVectors(vecAngles, vecVelocity, NULL_VECTOR, NULL_VECTOR);
		vecVelocity[0] *= 300.0;
		vecVelocity[1] *= 300.0;
		vecVelocity[2] *= 300.0;

		SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);

		TeleportEntity(weapon, NULL_VECTOR, NULL_VECTOR, vecVelocity);
		GetEdictClassname(weapon, classname, sizeof(classname));
		if (StrEqual(classname,"weapon_defibrillator"))
		{
			SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", MODEL_DEFIB);
		}
	}
}
stock bool GetPlayerEye(int client, float vecTarget[3]) 
{
	float Origin[3], Angles[3];
	GetClientEyePosition(client, Origin);
	GetClientEyeAngles(client, Angles);

	Handle trace = TR_TraceRayFilterEx(Origin, Angles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	if (TR_DidHit(trace)) 
	{
		TR_GetEndPosition(vecTarget, trace);
		CloseHandle(trace);
		return true;
	}
	CloseHandle(trace);
	return false;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
}
