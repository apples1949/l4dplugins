/**
 * ======================================================================================== *
 *                               [L4D & L4D2] Loot Boxes                                    *
 * ---------------------------------------------------------------------------------------- *
 *  Author      :   Eärendil                                                                *
 *  Descrp      :   Zombies drop boxes with good or bad results                             *
 *  Version     :   1.1.1                                                                   *
 *  Link        :   https://forums.alliedmods.net/showthread.php?p=2781646#post2781646      *
 * ======================================================================================== *
 *                                                                                          *
 *  CopyRight (C) 2022 Eduardo "Eärendil" Chueca                                            *
 * ---------------------------------------------------------------------------------------- *
 *  This program is free software; you can redistribute it and/or modify it under the       *
 *  terms of the GNU General Public License, version 3.0, as published by the Free          *
 *  Software Foundation.                                                                    *
 *                                                                                          *
 *  This program is distributed in the hope that it will be useful, but WITHOUT ANY         *
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A         *
 *  PARTICULAR PURPOSE. See the GNU General Public License for more details.                *
 *                                                                                          *
 *  You should have received a copy of the GNU General Public License along with            *
 *  this program. If not, see <http://www.gnu.org/licenses/>.                               *
 * ======================================================================================== *
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <survivorutilities>
#include <weaponhandling>

#define PLUGIN_VERSION		"1.1.1"
#define FCVAR_FLAGS			FCVAR_NOTIFY
// Limit entities to prevent server crashes due to entity limit
#define MAX_LBOXES			64
#define MAX_TOXCLOUD		8
#define MAX_WEAPONS			96
#define CHAT_TAG			"\x04[\x05LB\x04] \x01"

#define MODEL_BOX			"models/props_junk/cardboard_box07.mdl"
#define MODEL_BARREL		"models/props_industrial/barrel_fuel.mdl"
#define MODEL_BARRELA		"models/props_industrial/barrel_fuel_parta.mdl"
#define MODEL_BARRELB		"models/props_industrial/barrel_fuel_partb.mdl"
#define MODEL_FIREWORK		"models/props_junk/explosive_box001.mdl"
#define MODEL_GASCAN		"models/props_junk/gascan001a.mdl"
#define MODEL_PROPANETANK	"models/props_junk/propanecanister001a.mdl"
#define MODEL_OXYGENTANK	"models/props_equipment/oxygentank01.mdl"

//#define TN_BOX				"Lootbox.Entity.Crate"	// Box entity targetname
#define PARTICLE_BOOMER		"boomer_explode"
#define PARTICLE_EMBERS		"embers_small_01"
#define PARTICLE_SMOKE		"apc_wheel_smoke1"
#define PARTICLE_FIRE		"fire_small_01"
#define PARTICLE_TOXIC		"smoke_traintunnel"
#define PARTICLE_BARREL_FLY	"barrel_fly"

#define SND_BOOMER_EXPL		"player/boomer/explode/explo_medium_09.wav"
#define SND_GOOD_OPEN		"level/gnomeftw.wav"
#define SND_BAD_OPEN		"ui/pickup_scifi37.wav"
#define SND_BOOST_START		"ui/survival_playerrec.wav"
#define SND_BOOST_END		"ui/beep22.wav"
#define SND_REGEN			"player/heartbeatloop.wav"
#define SND_FIRE			"music/tank/onebadtank.wav"
#define SND_THANOS			"ui/survival_medal.wav"
#define SND_CHOKE			"player/survivor/voice/choke_5.wav"
#define SND_DENY			"player/suit_denydevice.wav"
#define SND_SHIELD			"ui/gascan_spawn.wav"
#define SND_EXPL1			"weapons/flaregun/gunfire/flaregun_explode_1.wav"
#define SND_EXPL2			"weapons/flaregun/gunfire/flaregun_fire_1.wav"
#define SND_EXPL3			"animation/plane_engine_explode.wav"
#define SND_BEARTRAP		"weapons/machete/machete_impact_flesh1.wav"
// Just some sounds for Left 4 Dead, because this game is missing some sounds
#define SND_GOOD_OPEN_1		"ui/bigreward.wav"
#define SND_BOOST_START_1	"ui/holdout_playerrec.wav"
#define SND_FIRE_1			"music/zombat/horde_01.wav"
#define SND_THANOS_1		"ui/holdout_medal.wav"
#define SND_SHIELD_1		"physics/metal/metal_barrel_impact_soft1.wav"
#define SND_BEARTRAP_1		"doors/door_metal_thin_close2.wav"


#define POS_WEIGHTS			"35,100,15,30,60,10,45,65,35,10,5,5,5,5,5,5,5"			// 17 values in total
#define NEG_WEIGHTS			"100,60,100,50,50,20,15,85,40,15,50,60,15,25,40,55,100"	// 17 values in total
#define SI_CHANCES			"18.0,18.0,18.0,18.0,18.0,18.0"			// 6 values, one for each special
#define BOOST_TIMES			"30.0,25.0,20.0,30.0,25.0,15.0"		// 6 values
#define NERF_TIMES			"60.0,25.0,50.0"					// 3 values
// Because L4D has less special infected and box options
#define POS_WEIGHTS_1		"35,100,30,60,10,45,65,5,5,5,5,5,5,5"
#define NEG_WEIGHTS_1		"100,60,100,50,20,15,40,15,50,60,15,25,40,100"
#define SI_CHANCES_1		"18.0,18.0,18.0"


// I Only use jockey and tank for spawns, but I will preserve it, just in case
// #define ZC_SMOKER			1
// #define ZC_BOOMER			2
// #define ZC_HUNTER			3
// #define ZC_SPITTER			4
#define ZC_JOCKEY			5
// #define ZC_CHARGER			6 
#define ZC_TANK				8
#define ZC_TANK_1			5	// In left 4 dead tank index is 5 instead of 8

enum 
{
	POS_T1,
	POS_T2,
	POS_T3,
	POS_SECNDARY,
	POS_DRUGS,
	POS_MEDS,
	POS_THROW,
	POS_ITEM,
	POS_UPGRADE,
	POS_LASER,
	POS_SPEED,
	POS_INVUL,
	POS_REGEN,
	POS_FIRE,
	POS_IAMMO,
	POS_EXPL,
	POS_THANOS,
	POS_SIZE
};

enum
{
	NEG_MOB,
	NEG_PANIC,
	NEG_VOMIT,
	NEG_SPIT,
	NEG_WITCH,
	NEG_TANK,
	NEG_TOXIC,
	NEG_JOCKEY,
	NEG_BARREL,
	NEG_BLACKWHITE,
	NEG_FROZEN,
	NEG_REVERSE,
	NEG_FRAGILE,
	NEG_BEARTRAP,
	NEG_ANGLES,
	NEG_FIREWORK,
	NEG_FULLSI,
	NEG_SIZE
};
//	L4D box opens
enum
{
	POS_T1_1,
	POS_T2_1,
	POS_SECNDARY_1,
	POS_DRUGS_1,
	POS_MEDS_1,
	POS_THROW_1,
	POS_ITEM_1,
	POS_SPEED_1,
	POS_INVUL_1,
	POS_REGEN_1,
	POS_FIRE_1,
	POS_IAMMO_1,
	POS_EXPL_1,
	POS_THANOS_1,
	POS_SIZE_1
}

enum
{
	NEG_MOB_1,
	NEG_PANIC_1,
	NEG_VOMIT_1,
	NEG_WITCH_1,
	NEG_TANK_1,
	NEG_TOXIC_1,
	NEG_BARREL_1,
	NEG_BLACKWHITE_1,
	NEG_FROZEN_1,
	NEG_REVERSE_1,
	NEG_FRAGILE_1,
	NEG_BEARTRAP_1,
	NEG_ANGLES_1,
	NEG_FULLSI_1,
	NEG_SIZE_1
};

// Store player boost and nerfs as bits in only one integer, instead of separated values
enum ( <<= 1 )
{
	PB_NONE = 0,
	PB_SPEED = 1,
	PB_INVUL,
	PB_REGEN,
	PB_FIRE,
	PB_IAMMO,
	PB_EXPL,
	PN_REVERSE,
	PN_FRAGILE,
	PN_ANGLES
};

// Melee weapon list for melee spawn
static char g_sMeleeList[][] = { "fireaxe", "golfclub", "machete", "katana", "baseball_bat", "cricket_bat", "tonfa" };
// 3 different vectors with a separation of 120 degrees, aproximated and hardcoded to prevent making useless calculations
// Z-axis ommited because is generated in the spitter function
static float g_fTriSpitForces[3][2] = { { 150.0, 0.0}, { -75.0, 129.9 }, { -75.0, -129.9 } };

// Plugin Start ConVars and variables
ConVar g_hAllow;
ConVar g_hGameModes;
ConVar g_hCurrGamemode;
bool g_bAllowedGamemode;
bool g_bPluginOn;

// Variables for storing entity references
int g_iLootBoxEnt[MAX_LBOXES];
int g_iToxCloudEnt[MAX_TOXCLOUD];
int g_iWeaponEnt[MAX_WEAPONS];
int g_iToxCloudCounter[MAX_TOXCLOUD];
// Entity timers
Handle g_hLootBoxTimer[MAX_LBOXES];
Handle g_hToxCloudTimer[MAX_TOXCLOUD];
Handle g_hWeaponUnlockTimer[MAX_WEAPONS];
Handle g_hWeaponDeleteTimer[MAX_WEAPONS];

// ConVar variables
int g_iPosWeights[POS_SIZE], g_iPosWeightSum; // For positive rolls
int g_iNegWeights[NEG_SIZE], g_iNegWeightSum; // For negative rolls
float g_fSpecialDrops[6];
float g_fBoostTimes[6];
float g_fNerfTimes[3];
int g_iTankDrops[2];
int g_iWitchDrops[2];

// Plugin ConVars
ConVar g_hBoxLifeTime;
ConVar g_hPosProb;
ConVar g_hPosWeight;
ConVar g_hNegRes;
ConVar g_hBoostTimes;
ConVar g_hNerfTimes;
ConVar g_hSpecialDrops;
ConVar g_hTankDrops;
ConVar g_hWitchDrops;
ConVar g_hWeaponLife;
ConVar g_hWeaponLock;
ConVar g_hMobSize;
ConVar g_hMegaMobSize;
ConVar g_hToxCloudLife;
ConVar g_hIntoxChance;
ConVar g_hToxicHits;
ConVar g_hBleedHits;
ConVar g_hFreezeTime;
ConVar g_hFragilityMult;

// Player variables & handles
bool g_bPlayerAdvert[MAXPLAYERS + 1];
bool g_bPlayerExpl[MAXPLAYERS + 1];
float g_fPlayerUse[MAXPLAYERS + 1];
float g_fPlayerAngleTime[MAXPLAYERS + 1];
int g_iPlayerBoosts[MAXPLAYERS + 1];
int g_iPlayerRegenToken[MAXPLAYERS + 1];
int g_iPlayerParticle[MAXPLAYERS + 1];
Handle g_hPlayerSpeedTimer[MAXPLAYERS + 1];
Handle g_hPlayerInvulTimer[MAXPLAYERS + 1];
Handle g_hPlayerAmmoTimer[MAXPLAYERS + 1];
Handle g_hPlayerFireTimer[MAXPLAYERS + 1];
Handle g_hPlayerRegenTimer[MAXPLAYERS + 1];
Handle g_hPlayerExplTimer[MAXPLAYERS + 1];
Handle g_hPlayerReverseTimer[MAXPLAYERS + 1];
Handle g_hPlayerFragileTimer[MAXPLAYERS + 1];
Handle g_hPlayerAnglesTimer[MAXPLAYERS + 1];

// Some global variables
int g_iNextMobSize = -1; // To override mob sizes
bool g_bL4D2;

public Plugin myinfo =
{
	name = "[L4D & L4D2] LootBoxes",
	author = "Eärendil",
	description = "Zombies drop Loot Boxes that contains random things.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2781646#post2781646",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if( GetEngineVersion() == Engine_Left4Dead2 )
		g_bL4D2 = true;
	else if( GetEngineVersion() != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2");
		return APLRes_SilentFailure;		
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("lootboxes_version",			PLUGIN_VERSION,			"Loot Boxes plugin version",		FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_hAllow =			CreateConVar("l4d_lootbox_enable",					"1",				"1 = Plugin On. 0 = Plugin Off.", FCVAR_FLAGS, true, 0.0, true, 1.0);
	g_hGameModes =		CreateConVar("l4d_lootbox_gamemodes",				"",					"Enable plugin in these gamemodes, separated by commas, no spaces.\nEmpty to allow all.", FCVAR_FLAGS);

	g_hBoxLifeTime =	CreateConVar("l4d_lootbox_lifetime",				"30.0",				"Lifetime of the Loot Boxes in seconds.", FCVAR_FLAGS, true, 10.0, true, 60.0);
	g_hPosProb =		CreateConVar("l4d_lootbox_positive_chance",			"50.0",				"Chance in % to have a good Loot Box opening.", FCVAR_FLAGS, true, 0.0, true, 100.0);

	g_hBoostTimes =		CreateConVar("l4d_lootbox_boost_durations",			BOOST_TIMES,		"Duration of good Box boosts in seconds.\n6 values, separated by commas, no spaces.\n<Speed,Invulnerability,Regeneration,FireDamage,InfiniteAmmo,ExplosiveShots>.", FCVAR_FLAGS);
	g_hNerfTimes =		CreateConVar("l4d_lootbox_nerf_durations",			NERF_TIMES,			"Duration of bad Box nerfs in seconds.\n13| values, separated by commmas, no spaces.\n<ReverseControls,Fragility,RandomAngles>\nIf one value is placed, it will be set for all the durations.", FCVAR_FLAGS);
	if( g_bL4D2 )
	{
		g_hPosWeight =		CreateConVar("l4d_lootbox_positive_weights",		POS_WEIGHTS,		"Weight of good Loot Box results.\n17 values, separated by commas, no spaces.\n<T1,T2,T3,Secondary,Drugs,Medical,Throwables,Items,Ammoupgrade,LaserBox,Speed,Invulnerability,Regeneration,Fire,InfiniteAmmo,ExplosiveShots,InfinityGaunlet>", FCVAR_FLAGS);
		g_hNegRes =			CreateConVar("l4d_lootbox_negative_weights",		NEG_WEIGHTS,		"Weight of bad Loot Box results.\n17 values, separated by commas, no spaces.\n<Mob,Panic,VomitTrap,SpitTrap,Witch,Tank,ToxicCloud,JockeyRide,Barrel,BlackAndWhite,FreezeTrap,ReverseControls,Fragility,BearTrap,RandomAngles,FireWorks,FullSITeam>", FCVAR_FLAGS);
		g_hSpecialDrops =	CreateConVar("l4d_lootbox_special_drop_chance",		SI_CHANCES,			"Chance to drop a LootBox when a Special infected dies.\n1|6 values, separated by commas, no spaces, values from 0.0 to 100.0\nOrder:<smoker,boomer,hunter,spitter,jockey,charger>\nIf one value is placed, it will be set for all SI.", FCVAR_FLAGS);	
	}
	else
	{
		g_hPosWeight =		CreateConVar("l4d_lootbox_positive_weights",		POS_WEIGHTS_1,		"Weight of good Loot Box results.\n14 values, separated by commas, no spaces.\n<T1,T2,Secondary,Drugs,Medical,Throwables,Items,Speed,Invulnerability,Regeneration,Fire,InfiniteAmmo,ExplosiveShots,InfinityGaunlet>", FCVAR_FLAGS);
		g_hNegRes =			CreateConVar("l4d_lootbox_negative_weights",		NEG_WEIGHTS_1,		"Weight of bad Loot Box results.\n14 values, separated by commas, no spaces.\n<Mob,Panic,VomitTrap,Witch,Tank,ToxicCloud,Barrel,BlackAndWhite,FreezeTrap,ReverseControls,Fragility,BearTrap,RandomAngles,FullSITeam>", FCVAR_FLAGS);
		g_hSpecialDrops =	CreateConVar("l4d_lootbox_special_drop_chance",		SI_CHANCES_1,		"Chance to drop a LootBox when a Special infected dies.\n1|3 values, separated by commas, no spaces, values from 0.0 to 100.0\nOrder:<smoker,boomer,hunter>\nIf one value is placed, it will be set for all SI.", FCVAR_FLAGS);
	}
	g_hTankDrops =		CreateConVar("l4d_lootbox_tank_drops",				"1,3",				"Min and max amount of lootboxes dropped when a tank dies.\n1|2 values, separated by commas, no spaces.\nIf 1 value is placed, max and min values will be the same.", FCVAR_FLAGS);
	g_hWitchDrops =		CreateConVar("l4d_lootbox_witch_drops",				"1,2",				"Min and max amount of lootboxes dropped when a witch dies.\n1|2 values, separated by commas, no spaces.\nIf 1 value is placed, max and min values will be the same.", FCVAR_FLAGS);

	g_hWeaponLock =		CreateConVar("l4d_lootbox_weapon_lock",				"5.0",				"Prevent bots to steal weapons/items this amount of time (0.0 to disable).", FCVAR_FLAGS, true, 0.0, true, 15.0);
	g_hWeaponLife =		CreateConVar("l4d_lootbox_weapon_lifetime",			"20.0",				"Lifetime of the weapons/items in boxes, in seconds.", FCVAR_FLAGS, true, 15.0, true, 60.0);

	g_hToxCloudLife =	CreateConVar("l4d_lootbox_toxicloud_lifetime",		"40",				"Lifetime of the toxic cloud in seconds.", FCVAR_FLAGS, true, 10.0, true, 240.0);
	g_hIntoxChance = 	CreateConVar("l4d_lootbox_intoxication_chance",		"15.0",				"Chance for a survivor to get intoxicated when receiving toxic cloud damage.", FCVAR_FLAGS, true, 0.0, true, 100.0);
	g_hToxicHits =		CreateConVar("l4d_lootbox_toxichits",				"50",				"Amount of toxic hits that an intoxicated survivor will receive after intoxication.", FCVAR_FLAGS, true, 1.0);
	g_hBleedHits =		CreateConVar("l4d_lootbox_bleedhits",				"30",				"Amount of bleed hits that survivors will get after opening a bear trap.", FCVAR_FLAGS, true, 1.0);
	g_hFreezeTime =		CreateConVar("l4d_lootbox_freezetime",				"10.0",				"Amount of time in seconds that survivors will be frozen with the freeze trap.", FCVAR_FLAGS, true, 1.0);
	g_hFragilityMult =	CreateConVar("l4d_lootbox_fragility_multiplier",	"5.0",				"Multiply the damage received by survivor under fragility by this amount.", FCVAR_FLAGS, true, 1.0);

	g_hMobSize =		CreateConVar("l4d_lootbox_mob_size",				"80",				"Size of mob obtained from LootBox.", FCVAR_FLAGS, true, 20.0);
	g_hMegaMobSize =	CreateConVar("l4d_lootbox_megamob_size",			"140",				"Size of megamob obtained from LootBox", FCVAR_FLAGS, true, 30.0);
	g_hCurrGamemode =	FindConVar("mp_gamemode");
	
	g_hAllow.AddChangeHook(CvarChange_Enable);
	g_hGameModes.AddChangeHook(CvarChange_Enable);
	g_hCurrGamemode.AddChangeHook(CvarChange_Enable);
	g_hPosWeight.AddChangeHook(CVarChange_Probs);
	g_hNegRes.AddChangeHook(CVarChange_Probs);
	g_hSpecialDrops.AddChangeHook(CVarChange_Drops);
	g_hTankDrops.AddChangeHook(CVarChange_Drops);
	g_hBoostTimes.AddChangeHook(CVarChange_Times);
	g_hNerfTimes.AddChangeHook(CVarChange_Times);
	
	RegAdminCmd("sm_lootbox_spawn", AdminSpawnBox, ADMFLAG_KICK, "Spawn Lootboxes at your crosshair position.");
	RegAdminCmd("sm_lootbox_wipe", AdminWipeEnts, ADMFLAG_KICK, "Remove boxes and weapons generated by plugin.");
	
	AutoExecConfig(true, "l4d_lootboxes");
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) )
			SDKHook(i, SDKHook_OnTakeDamage, IgnoreExplosions_Callback);
	}
}

public void OnMapStart()
{
	WipeLootBoxes();
	WipeWeapons();
	WipeClouds();
	for( int i = 1; i <= MaxClients; i++ )
		ResetClientData(i);
		
	PrecacheSound(SND_BOOMER_EXPL, false);
	PrecacheSound(SND_BAD_OPEN, false);
	PrecacheSound(SND_REGEN, false);
	PrecacheSound(SND_BOOST_END, false);
	PrecacheSound(SND_DENY, false);
		
	if( g_bL4D2 )
	{
		PrecacheSound(SND_GOOD_OPEN, false);
		PrecacheSound(SND_BOOST_START, false);
		PrecacheSound(SND_FIRE, false);
		PrecacheSound(SND_THANOS, false);
		PrecacheSound(SND_SHIELD, false);
		PrecacheSound(SND_BEARTRAP, false);
		PrecacheSound(SND_EXPL1, false);
		PrecacheSound(SND_EXPL2, false);
		PrecacheSound(SND_EXPL3, false);
	}
	else
	{
		PrecacheSound(SND_GOOD_OPEN_1, false);
		PrecacheSound(SND_BOOST_START_1, false);
		PrecacheSound(SND_FIRE_1, false);
		PrecacheSound(SND_THANOS_1, false);
		PrecacheSound(SND_SHIELD_1, false);
		PrecacheSound(SND_BEARTRAP_1, false);
	}
	
	PrecacheModel(MODEL_BARREL, true);
	PrecacheModel(MODEL_BARRELA, true);
	PrecacheModel(MODEL_BARRELB, true);
	PrecacheModel(MODEL_BOX, true);
	PrecacheModel(MODEL_FIREWORK, true);
	PrecacheModel(MODEL_GASCAN, true);
	PrecacheModel(MODEL_PROPANETANK, true);
	PrecacheModel(MODEL_OXYGENTANK, true);

	PrecacheParticle(PARTICLE_BOOMER);
	PrecacheParticle(PARTICLE_EMBERS);
	PrecacheParticle(PARTICLE_FIRE);
	PrecacheParticle(PARTICLE_SMOKE);
	PrecacheParticle(PARTICLE_TOXIC);
	PrecacheParticle(PARTICLE_BARREL_FLY);
}

public void OnConfigsExecuted()
{
	GetGameMode();
	SwitchPlugin();
	GetProbs();
	GetDrops();
	GetBoostTimes();
}

public void OnClientConnected(int client)
{
	ResetClientData(client);
}

public void OnClientPutInServer(int client)
{
	if( g_bPluginOn )		
		SDKHook(client, SDKHook_OnTakeDamage, IgnoreExplosions_Callback);
}

public void OnClientDisconnect(int client)
{
	if( g_bPluginOn )		
		SDKUnhook(client, SDKHook_OnTakeDamage, IgnoreExplosions_Callback);
}

public void OnMapEnd()
{
	WipeLootBoxes();
	WipeWeapons();
	WipeClouds();
}

public void OnPluginEnd()
{
	WipeLootBoxes();
	WipeWeapons();
	WipeClouds();
	for( int i = 1; i <= MaxClients; i++ )
	{
		int entity = EntRefToEntIndex(g_iPlayerParticle[i]);
		if( entity != 0 && entity != INVALID_ENT_REFERENCE )
			RemoveEntity(entity);
	}
}

/* ========================================================================================= *
 *                                       ConVars                                             *
 * ========================================================================================= */

public void CvarChange_Enable(Handle conVar, const char[] oldValue, const char[] newValue)
{
	GetGameMode();
	SwitchPlugin();
}

public void CVarChange_Probs(Handle conVar, const char[] oldValue, const char[] newValue)
{
	GetProbs();
}

public void CVarChange_Drops(Handle conVar, const char[] oldValue, const char[] newValue)
{
	GetDrops();
}

public void CVarChange_Times(Handle conVar, const char[] oldValue, const char[] newValue)
{
	GetBoostTimes();
}

// Gets the current gamemode and evalates if its valid
void GetGameMode()
{
	char sCurrGameMode[32], sGameModes[128];
	g_hCurrGamemode.GetString(sCurrGameMode, sizeof(sCurrGameMode));
	g_hGameModes.GetString(sGameModes, sizeof(sGameModes));

	if( sGameModes[0] )
	{
		char sBuffer[32][32];
		if( ExplodeString(sGameModes, ",", sBuffer, sizeof(sBuffer), sizeof(sBuffer[])) == 0 ) // Invalid ConVar value, allow gamemode by default
		{
			g_bAllowedGamemode = true;
			return;
		}
		
		for( int i = 0; i < sizeof(sBuffer); i++ ) // Loop through all different gamemodes allowed in the ConVar
		{
			if( StrEqual(sBuffer[i], sCurrGameMode, false) )
			{
				g_bAllowedGamemode = true;
				return;
			}
		}
		// No match = Not allowed Gamemode
		g_bAllowedGamemode = false;
		return;
	}
	g_bAllowedGamemode = true;
}

void SwitchPlugin()
{
	if( g_bPluginOn == false && g_hAllow.BoolValue == true && g_bAllowedGamemode == true )
	{
		g_bPluginOn = true;
		HookEvent("round_start",			Event_Round_Start,		EventHookMode_PostNoCopy);
		HookEvent("round_end",				Event_Round_End,		EventHookMode_PostNoCopy);
		HookEvent("player_death",			Event_Player_Death);
		HookEvent("infected_hurt",			Event_Infected_Hurt);
		HookEvent("player_hurt",			Event_Player_Hurt);
		HookEvent("bullet_impact",			Event_Bullet_Impact);
		if( g_bL4D2 )
			HookEvent("weapon_fire",		Event_Weapon_Fire);
		else
			HookEvent("weapon_fire",		Event_Weapon_Fire_1);

	}
	
	if( g_bPluginOn == true && (g_hAllow.BoolValue == false || g_bAllowedGamemode == false) )
	{
		g_bPluginOn = false;
		UnhookEvent("round_start",				Event_Round_Start);
		UnhookEvent("round_end",				Event_Round_End);
		UnhookEvent("player_death",				Event_Player_Death);
		UnhookEvent("infected_hurt",			Event_Infected_Hurt);
		UnhookEvent("player_hurt",				Event_Player_Hurt);
		UnhookEvent("bullet_impact",			Event_Bullet_Impact);
		if( g_bL4D2 )
			UnhookEvent("weapon_fire",			Event_Weapon_Fire);
		else
			UnhookEvent("weapon_fire",			Event_Weapon_Fire_1);
		
		WipeLootBoxes();
		WipeWeapons();
		WipeClouds();
		for( int i = 1; i <= MaxClients; i++ )
			ResetClientData(i);
	}
}

void GetProbs()
{
	char sConVar[256];
	char sBuffer[20][8];
	g_iPosWeightSum = 0;
	g_iNegWeightSum = 0;
	int iArrSize;
	
	g_hPosWeight.GetString(sConVar, sizeof(sConVar));
	if( (iArrSize = ExplodeString( sConVar, ",", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]) )) != POS_SIZE )
	{
		PrintToServer("[LB] Warning: Invalid ConVar <l4d_lootbox_positive_weights> value amount. Expected %d, found %d", POS_SIZE, iArrSize);
		ExplodeString(POS_WEIGHTS, ",", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));
		g_hPosWeight.RestoreDefault(false, false);
	}
			
	for( int i = 0; i < POS_SIZE; i++ )
	{
		g_iPosWeights[i] = StringToInt(sBuffer[i]);
		if( g_iPosWeights[i] < 0 ) g_iPosWeights[i] = 0;

		g_iPosWeightSum += g_iPosWeights[i];
	}
	
	g_hNegRes.GetString(sConVar, sizeof(sConVar));
	if( (iArrSize = ExplodeString( sConVar, ",", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]) )) != NEG_SIZE )
	{
		PrintToServer("[LB] Warning: Invalid ConVar <l4d_lootbox_negative_weights> value amount. Expected %d, found %d", NEG_SIZE, iArrSize);
		ExplodeString(NEG_WEIGHTS, ",", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));
		g_hNegRes.RestoreDefault(false, false);
	}
			
	for( int i = 0; i < NEG_SIZE; i++ )
	{
		g_iNegWeights[i] = StringToInt(sBuffer[i]);
		if( g_iNegWeights[i] < 0 ) g_iNegWeights[i] = 0;
			
		g_iNegWeightSum += g_iNegWeights[i];
	}
}

void GetDrops()
{
	char sConVar[128];
	char sBuffer[8][8];
	int iArrSize;
	int iSpecials = g_bL4D2 ? 6 : 3;
	
	g_hSpecialDrops.GetString(sConVar, sizeof(sConVar));
	if( (iArrSize = ExplodeString( sConVar, ",", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]) )) != iSpecials && iArrSize != 1 )
	{
		PrintToServer("[LB] Warning: Invalid ConVar <l4d_lootbox_special_drop_chance> value amount. Expected %d|1, found %d", iSpecials, iArrSize);
		ExplodeString(SI_CHANCES, ",", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));
		g_hSpecialDrops.RestoreDefault(false, false);
	}
			
	for( int i = 0; i < iSpecials; i++ )
	{
		g_fSpecialDrops[i] = iArrSize == 1 ? g_hSpecialDrops.FloatValue : StringToFloat(sBuffer[i]);			
		if( g_fSpecialDrops[i] < 0.0 )
			g_fSpecialDrops[i] = 0.0;
		else if( g_fSpecialDrops[i] > 100.0 )
			g_fSpecialDrops[i] = 100.0;
	}
	
	g_hTankDrops.GetString(sConVar, sizeof(sConVar));
	if( (iArrSize = ExplodeString( sConVar, ",", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]) )) != 2 && iArrSize != 1 )
	{
		PrintToServer("[LB] Warning: Invalid ConVar <l4d_lootbox_tank_drops> value amount. Expected 2|1, found %d", iArrSize);
		g_iTankDrops = { 1, 3 };
		g_hTankDrops.RestoreDefault(false, false);	
	}
	else
	{
		if( iArrSize == 1 )
		{
			g_iTankDrops[0] = g_hTankDrops.IntValue;
			g_iTankDrops[1] = g_iTankDrops[0];
		}
		else
		{
			g_iTankDrops[0] = StringToInt(sBuffer[0]);
			g_iTankDrops[1] = StringToInt(sBuffer[1]);
		}
		if( g_iTankDrops[0] < 0 ) g_iTankDrops[0] = 0;
		if( g_iTankDrops[1] < 0 ) g_iTankDrops[1] = 0;
	}
	
	g_hWitchDrops.GetString(sConVar, sizeof(sConVar));
	if( (iArrSize = ExplodeString( sConVar, ",", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]) )) != 2 && iArrSize != 1 )
	{
		PrintToServer("[LB] Warning: Invalid ConVar <l4d_lootbox_witch_drops> value amount. Expected 2|1, found %d", iArrSize);
		g_iWitchDrops = { 1, 2 };
		g_hWitchDrops.RestoreDefault(false, false);	
	}
	else
	{
		if( iArrSize == 1 )
		{
			g_iWitchDrops[0] = g_hWitchDrops.IntValue;
			g_iWitchDrops[1] = g_iWitchDrops[0];
		}
		else
		{
			g_iWitchDrops[0] = StringToInt(sBuffer[0]);
			g_iWitchDrops[1] = StringToInt(sBuffer[1]);
		}
		if( g_iWitchDrops[0] < 0 ) g_iWitchDrops[0] = 0;
		if( g_iWitchDrops[1] < 0 ) g_iWitchDrops[1] = 0;
	}
}

void GetBoostTimes()
{
	char sConVar[128];
	char sBuffer[8][8];
	int iArrSize;
	
	g_hBoostTimes.GetString(sConVar, sizeof(sConVar));
	if( (iArrSize = ExplodeString( sConVar, ",", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]) )) != 6 && iArrSize != 1 )
	{
		PrintToServer("[LB] Warning: Invalid ConVar <l4d_lootbox_boost_durations> value amount. Expected 6|1, found %d", iArrSize);
		ExplodeString(BOOST_TIMES, ",", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));
		g_hBoostTimes.RestoreDefault(false, false);
	}
	for( int i = 0; i < 6; i++ )
	{
		g_fBoostTimes[i] = iArrSize == 1 ? g_hBoostTimes.FloatValue : StringToFloat(sBuffer[i]);
		if( g_fBoostTimes[i] < 0.1 )
			g_fBoostTimes[i] = 0.1;
	}
	g_hNerfTimes.GetString(sConVar, sizeof(sConVar));
	if( (iArrSize = ExplodeString( sConVar, ",", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]) )) != 3 && iArrSize != 1 )
	{
		PrintToServer("[LB] Warning: Invalid ConVar <l4d_lootbox_boost_durations> value amount. Expected 2|1, found %d", iArrSize);
		ExplodeString(NERF_TIMES, ",", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));
		g_hNerfTimes.RestoreDefault(false, false);
	}
	g_fNerfTimes[0] = iArrSize == 1 ? g_hNerfTimes.FloatValue : StringToFloat(sBuffer[0]);
	g_fNerfTimes[1] = iArrSize == 1 ? g_hNerfTimes.FloatValue : StringToFloat(sBuffer[1]);
	g_fNerfTimes[2] = iArrSize == 1 ? g_hNerfTimes.FloatValue : StringToFloat(sBuffer[2]);
}

/* ========================================================================================= *
 *                             Events, SDKHooks, Left4DHooks                                 *
 * ========================================================================================= */ 

Action Event_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 1; i <= MaxClients; i++ )
		ResetClientData(i);

	WipeLootBoxes();
	WipeWeapons();
	WipeClouds();
}

Action Event_Round_End(Event event, const char[] name, bool dontBroadcast)
{
	WipeLootBoxes();
	WipeWeapons();
	WipeClouds();
}

Action Event_Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( !client ) 
	{
		char sName[16];
		float vPos[3];
		int entity = event.GetInt("entityid");
		GetEntityNetClass(entity, sName, sizeof(sName));
		if( StrEqual(sName, "witch", false) )
		{
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
			RandomLootBoxSpawn(vPos, g_iWitchDrops[0], g_iWitchDrops[1]);
		}
	}
		
	else if( GetClientTeam(client) == 2 )
		ResetClientData(client);
		
	else if( GetClientTeam(client) == 3 )
	{
		float vPos[3];
		GetClientAbsOrigin(client, vPos);
		vPos[2] += 16.0;
		int iClass = GetEntProp(client, Prop_Send, "m_zombieClass");
		float fRand = GetRandomFloat(0.0, 100.0);
		if( g_bL4D2 )
		{
			if( iClass != ZC_TANK )
			{
				if( fRand <= g_fSpecialDrops[iClass - 1] )
					RandomLootBoxSpawn(vPos, 1, 1);
			}
			else
				RandomLootBoxSpawn(vPos, g_iTankDrops[0], g_iTankDrops[1]);
		}
		else
		{
			if( iClass != ZC_TANK_1 )
			{
				// Array range: 0-5, infected range 1-6.
				if( fRand <= g_fSpecialDrops[iClass - 1] )
					RandomLootBoxSpawn(vPos, 1, 1);
			}
			else
				RandomLootBoxSpawn(vPos, g_iTankDrops[0], g_iTankDrops[1]);
		}
	}
	return Plugin_Continue;
}

Action Event_Weapon_Fire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( g_iPlayerBoosts[client] & PB_IAMMO == 0 )
		return Plugin_Continue;
		
	int iClip, iSlot = -1;
	char sWeapon[32];
	event.GetString("weapon", sWeapon, sizeof(sWeapon));
	if( StrEqual(sWeapon, "pistol", false) )
	{
		iSlot = 1;
		if( GetEntProp(GetPlayerWeaponSlot(client, 1), Prop_Send, "m_isDualWielding") > 0 )
			iClip = 30;
		else
			iClip = 15;
	}
	else if( strncmp(sWeapon[7], "magnum", 6) == 0 ) // pistol_magnum
	{
		iSlot = 1;
		iClip = 8;
	}
	else if( strncmp(sWeapon[6], "ak", 2) == 0) //rifle_ak47
	{
		iSlot = 0;
		iClip = 40;
	}
	else if( strncmp(sWeapon[6], "des", 3) == 0 ) // rifle_desert
	{
		iSlot = 0;
		iClip = 60;
	}
	else if( strncmp(sWeapon[6], "m60", 3) == 0 ) // rifle_m60
	{
		iSlot = 0;
		iClip = 150;
	}
	else if( strncmp(sWeapon, "gre", 3) == 0 ) // grenade_launcher
	{
		iSlot = 0;
		iClip = 1;
	}
	else if( strncmp(sWeapon, "pump", 4) == 0 || strncmp(sWeapon[8], "chro", 4) == 0 ) // pumpshotgun, shotgun_chrome
	{
		iSlot = 0;
		iClip = 8;
	}
	else if( strncmp(sWeapon, "auto", 4) == 0 || strncmp(sWeapon[8], "spas", 4) == 0 ) // autoshotgun, shotgun_spas
	{
		iSlot = 0;
		iClip = 10;
	}
	else if( strncmp(sWeapon, "hunt", 4) == 0 || strncmp(sWeapon[7], "scout", 5) == 0 ) // hunting_rifle, sniper_scout
	{
		iSlot = 0;
		iClip = 15;
	}
	else if( strncmp(sWeapon[7], "mili", 4) == 0 ) // sniper_military
	{
		iSlot = 0;
		iClip = 30;
	}
	else if( strncmp(sWeapon, "awp", 3) == 0 ) // sniper_awp
	{
		iSlot = 0;
		iClip = 20;
	}
	else if( strncmp(sWeapon, "rifle", 5) == 0 || strncmp(sWeapon, "smg", 3) == 0 ) // rifle, rifle_sg552, smg, smg_silenced, smg_mp5
	{
		iSlot = 0;
		iClip = 50;
	}
	else return Plugin_Continue;
	
	if( iSlot != -1 )
	{
		int iWeapon = GetPlayerWeaponSlot(client, iSlot);
		if( IsValidEntity(iWeapon) )
			SetEntProp(iWeapon, Prop_Send, "m_iClip1", iClip + 1);
	}
	return Plugin_Continue;
}

// The same but for Left 4 Dead 1, since it has less weapon names to check
Action Event_Weapon_Fire_1(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( g_iPlayerBoosts[client] & PB_IAMMO == 0 )
		return Plugin_Continue;
		
	int iClip, iSlot = -1;
	char sWeapon[32];
	event.GetString("weapon", sWeapon, sizeof(sWeapon));
	if( StrEqual(sWeapon, "pistol", false) )
	{
		iSlot = 1;
		if( GetEntProp(GetPlayerWeaponSlot(client, 1), Prop_Send, "m_isDualWielding") > 0 )
			iClip = 30;
		else
			iClip = 15;
	}
	else if( strncmp(sWeapon, "pump", 4) == 0 ) // pumpshotgun, shotgun_chrome
	{
		iSlot = 0;
		iClip = 8;
	}
	else if( strncmp(sWeapon, "auto", 4) == 0 ) // autoshotgun, shotgun_spas
	{
		iSlot = 0;
		iClip = 10;
	}
	else if( strncmp(sWeapon, "rifle", 5) == 0 ) // rifle
	{
		iSlot = 0;
		iClip = 10;
	}
	else if ( strncmp(sWeapon, "hunt", 4) == 0 ) // hunting_rifle
	{
		iSlot = 0;
		iClip = 15;
	}
	if( iSlot != -1 )
	{
		int iWeapon = GetPlayerWeaponSlot(client, iSlot);
		if( IsValidEntity(iWeapon) )
			SetEntProp(iWeapon, Prop_Send, "m_iClip1", iClip+1);
	}
	return Plugin_Continue;
}

Action Event_Infected_Hurt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int infected = event.GetInt("entityid");
	int type = event.GetInt("type");
	if( g_iPlayerBoosts[attacker] & PB_FIRE && type != 8 )
		SDKHooks_TakeDamage(infected, attacker, attacker, 10.0, 8, -1, NULL_VECTOR, NULL_VECTOR);
		
	return Plugin_Continue;
}

Action Event_Player_Hurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int entity = event.GetInt("attackerentid");
	char sClassname[32];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));
	if( g_iPlayerBoosts[client] & PB_FIRE )
	{
		if( attacker && IsClientInGame(attacker) && GetClientTeam(attacker) == 3 )
			SDKHooks_TakeDamage(attacker, client, client, 10.0, 8, -1, NULL_VECTOR, NULL_VECTOR);
		else if( IsValidEntity(entity) && (StrEqual(sClassname, "infected") || StrEqual(sClassname, "witch")) )
			SDKHooks_TakeDamage(entity, client, client, 10.0, 8, -1, NULL_VECTOR, NULL_VECTOR);
	}
	else if( g_iPlayerBoosts[attacker] & PB_FIRE )
	{
		int type = event.GetInt("type");
		if( type == 8 )
			return Plugin_Continue;
			
		if( GetClientTeam(client) == 3 )
			SDKHooks_TakeDamage(client, attacker, attacker, 10.0, 8, -1, NULL_VECTOR, NULL_VECTOR);
	}
	return Plugin_Continue;
}

Action Event_Bullet_Impact(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));	// Get the player who shooted
	if( g_iPlayerBoosts[client] & PB_EXPL && !g_bPlayerExpl[client] )
	{
		float vPos[3];
		vPos[0] = GetEventFloat(event, "x");
		vPos[1] = GetEventFloat(event, "y");
		vPos[2] = GetEventFloat(event, "z");
		
		// Create an env_explosion
		int entity = CreateEntityByName("env_explosion");
		TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(entity, "iMagnitude", "100");
		DispatchKeyValue(entity, "rendermode", "5");
		DispatchKeyValue(entity, "spawnflags", "128");	// Random orientation
		DispatchKeyValue(entity, "fireballsprite", "sprites/zerogxplode.spr");
		SetEntPropEnt(entity, Prop_Data, "m_hInflictor", client);	// Make the player who created the env_explosion the owner of it
		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
		
		DispatchSpawn(entity);
		
		SetVariantString("OnUser1 !self:Explode::0.01:1)");	// Add a delay to allow explosion effect to be visible
		AcceptEntityInput(entity, "Addoutput");
		AcceptEntityInput(entity, "FireUser1");
		// env_explosion is autodeleted after 0.3s while spawnflag repeteable is not added
		g_bPlayerExpl[client] = true;
		CreateTimer(0.2, EnableExpl_Timer, client);
		// Play an explosion sound
		if( !g_bL4D2 )
			return Plugin_Continue;
			
		switch (GetRandomInt(1,3))
		{
			case 1: EmitAmbientSound(SND_EXPL1, vPos);
			case 2: EmitAmbientSound(SND_EXPL2, vPos);
			case 3: EmitAmbientSound(SND_EXPL3, vPos);
		}
	}
	return Plugin_Continue;
}

Action Invulnerability_Callback(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	// Player, ignore damage
	if( attacker <= MaxClients && attacker > 0 )
	{
		EmitSoundToClient(victim, SND_SHIELD);
		return Plugin_Handled;
	}
	// Entity, ignore witches and infected damage
	if( IsValidEntity(attacker) )
	{
		char sClassname[32];
		GetEntityClassname(attacker, sClassname, sizeof(sClassname));
		// Witch or infected, ignore damage
		if( StrEqual(sClassname, "infected") || StrEqual(sClassname, "witch") )
		{
			EmitSoundToClient(victim, SND_SHIELD);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

Action Fragility_Callback(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	// Just ignore teammates
	if( attacker <= MaxClients && attacker > 0 )
	{
		if( GetClientTeam(attacker) == 2 )
			return Plugin_Continue;
	}
	
	damage *= g_hFragilityMult.FloatValue;
	return Plugin_Changed;
}

Action IgnoreExplosions_Callback(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if( GetClientTeam(victim) != 2 )
		return Plugin_Continue;
		
	if( damagetype != 64 || weapon != -1 )
		return Plugin_Continue;
	
	if( attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(attacker) == 2 )
		return Plugin_Handled;
		
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if( g_iPlayerBoosts[client] & PN_REVERSE )
	{
		if( buttons & IN_FORWARD )
		{
			buttons ^= IN_FORWARD;
			buttons |= IN_BACK;
		}
		if( buttons & IN_BACK )
		{
			buttons ^= IN_BACK;
			buttons |= IN_FORWARD;
		}
		if( buttons & IN_LEFT )
		{
			buttons ^= IN_LEFT;
			buttons |= IN_RIGHT;
		}
		if( buttons & IN_RIGHT )
		{
			buttons ^= IN_RIGHT;
			buttons |= IN_LEFT;
		}
		vel[0] = -vel[0];
		vel[1] = -vel[1];
//		vel[2] = -vel[2];
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action L4D_OnSpawnMob(int &amount)
{
	if( !g_bPluginOn )
		return Plugin_Continue;

	if( g_iNextMobSize > 0 )
	{
		amount = g_iNextMobSize;
		g_iNextMobSize = -1;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

/* ========================================================================================= *
 *                                       Admin Commands                                      *
 * ========================================================================================= */
 
Action AdminSpawnBox(int client, int args)		// Admin can spawn lootboxes at player position DISABLED
{
	if( !g_bPluginOn ) return Plugin_Handled;
	if( !client )
	{
		ReplyToCommand(client, "[LB] Commands can be only used in game.");
		return Plugin_Handled;
	}
	
	float vPos[3], vAng[3];
	if( !IsValidPosition(client, vPos, vAng) )
	{
		PrintToChat(client, "%s Can't spawn a LootBox here, please try again.", CHAT_TAG);
		return Plugin_Handled;
	}
	vPos[2] += 8.0;
	int iCount;
	char sArgs[8];
	if( args > 0 )
	{
		GetCmdArg(1, sArgs, sizeof(sArgs));
		iCount = StringToInt(sArgs);
	}
	else iCount = 1;
	for( int i = 0; i < iCount; i++ )
	{
		if( !SpawnLootBox(vPos, vAng, NULL_VECTOR) )
		{
			ReplyToCommand(client, "%s Limit of LootBoxes reached.", CHAT_TAG);
			break;
		}
	}
	return Plugin_Handled;
}

// This one can be called via server console, because it doesn't require player angles or position
Action AdminWipeEnts(int client, int args)
{
	if( !g_bPluginOn ) return Plugin_Handled;
	
	WipeLootBoxes();
	WipeWeapons();
	return Plugin_Handled;
}

/* ========================================================================================= *
 *                                 Timers and Frames                                         *
 * ========================================================================================= */
 
Action BoxLife_Timer(Handle timer, int arrIndex)
{
	g_hLootBoxTimer[arrIndex] = null;
	int entity = EntRefToEntIndex(g_iLootBoxEnt[arrIndex]);
	if( entity != 0 && entity != INVALID_ENT_REFERENCE )
		RemoveEntity(entity);

	g_iLootBoxEnt[arrIndex] = 0;
	return Plugin_Continue;
}

Action PlayerSpeed_Timer(Handle timer, int client)
{
	if( !IsClientInGame(client) || !IsPlayerAlive(client) )
		return Plugin_Continue;
		
	g_hPlayerSpeedTimer[client] = null;
	DefaultPlayerSpeed(client);
	g_iPlayerBoosts[client] &= ~PB_SPEED;
	EmitSoundToClient(client, SND_BOOST_END);
	int entity = EntRefToEntIndex(g_iPlayerParticle[client]);
	if( entity != 0 && entity != INVALID_ENT_REFERENCE )
		RemoveEntity(entity);
		
	PrintToChat(client, "%s \x03Speed boost\x01 ended.", CHAT_TAG);
	return Plugin_Continue;
}

Action PlayerInvul_Timer(Handle timer, int client)
{
	g_hPlayerInvulTimer[client] = null;
	g_iPlayerBoosts[client] &= ~PB_INVUL;
	SDKUnhook(client, SDKHook_OnTakeDamage, Invulnerability_Callback);
	EmitSoundToClient(client, SND_BOOST_END);
	PrintToChat(client, "%s \x03Invulnerability\x01 ended.", CHAT_TAG);
	return Plugin_Continue;
}

Action PlayerFire_Timer(Handle timer, int client)
{
	g_hPlayerFireTimer[client] = null;
	g_iPlayerBoosts[client] &= ~PB_FIRE;
	StopSound(client, SNDCHAN_AUTO, SND_FIRE);
	EmitSoundToClient(client, SND_BOOST_END);
	int entity = EntRefToEntIndex(g_iPlayerParticle[client]);
	if( entity != 0 && entity != INVALID_ENT_REFERENCE )
		RemoveEntity(entity);
		
	PrintToChat(client, "%s \x03Invulnerability\x01 ended.", CHAT_TAG);
	return Plugin_Continue;
}

Action PlayerInfAmmo_Timer(Handle timer, int client)
{
	g_hPlayerAmmoTimer[client] = null;
	g_iPlayerBoosts[client] &= ~PB_IAMMO;
	return Plugin_Continue;
}

Action PlayerRegen_Timer(Handle timer, int client)
{
	g_hPlayerRegenTimer[client] = null;
	
	if( !IsClientInGame(client) || !IsPlayerAlive(client) )
		return Plugin_Continue;
		
	if( GetClientHealth(client) < 98 )
	{
		SetEntityHealth(client, (GetClientHealth(client)) + 2);
		SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
		SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
	}
	else
		SetEntityHealth(client, 100);
		
	if( GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1 )
	{
		L4D_ReviveSurvivor(client);
	}
	if( --g_iPlayerRegenToken[client] > 0 )
		g_hPlayerRegenTimer[client] = CreateTimer(0.5, PlayerRegen_Timer, client);
	else
	{
		PrintToChat(client, "%s \x03Regeneration\x01 ended.", CHAT_TAG);
		StopSound(client, SNDCHAN_AUTO, SND_REGEN);
		EmitSoundToClient(client, SND_BOOST_END);
		g_iPlayerBoosts[client] &= ~PB_REGEN;
		int entity = EntRefToEntIndex(g_iPlayerParticle[client]);
		if( entity != 0 && entity != INVALID_ENT_REFERENCE )
			RemoveEntity(entity);
	}
	return Plugin_Continue;
}

Action WeaponUnlock_Timer(Handle timer, int arrPos)
{
	g_hWeaponUnlockTimer[arrPos] = null;
	int entity = EntRefToEntIndex(g_iWeaponEnt[arrPos]);
	if( entity != 0 && entity != INVALID_ENT_REFERENCE )
		SDKUnhook(entity, SDKHook_Use, Weapon_Used);
		
	return Plugin_Continue;
}

Action WeaponDelete_Timer(Handle timer, int arrPos)
{
	g_hWeaponDeleteTimer[arrPos] = null;
	int entity = EntRefToEntIndex(g_iWeaponEnt[arrPos]);
	if( entity != 0 && entity != INVALID_ENT_REFERENCE )
	{
		RemoveEntity(entity);
		delete g_hWeaponUnlockTimer[arrPos];
	}

	g_iWeaponEnt[arrPos] = 0;
	return Plugin_Continue;
}


Action RemoveBot_Timer(Handle timer, int clientSerial)
{
	int client = GetClientFromSerial(clientSerial);
	if( client == 0 || !IsClientInGame(client) )
		return Plugin_Continue;
		
	KickClient(client);
	return Plugin_Continue;
}

Action ToxicCloud_Timer(Handle timer, int arrPos)
{
	g_hToxCloudTimer[arrPos] = null;
	int entity = g_iToxCloudEnt[arrPos];
	if( entity == INVALID_ENT_REFERENCE )
		return Plugin_Continue;
		
	float vPos[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
	vPos[2] +=144;
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( !IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != 2  )
			continue;
			
		float vClient[3];
		GetClientEyePosition(i, vClient);
		if( vPos[2] - vClient[2] < -128.0 || vPos[2] - vClient[2] > 128.0 )
			continue;
		
		float fDistXY = Pow(vPos[0] - vClient[0], 2.0) + Pow(vPos[1] - vClient[1], 2.0);
		if( fDistXY < 135424 )
		{
			SDKHooks_TakeDamage(i, i, i, 4.0, 0, -1, NULL_VECTOR, NULL_VECTOR);
			EmitSoundToClient(i, SND_CHOKE);
			if( !SU_IsToxic(i) && !IsFakeClient(i) && GetRandomFloat(0.0,100.0) <= g_hIntoxChance.FloatValue )
				SU_AddToxic(i, g_hToxicHits.IntValue); 
		}
	}
	if( --g_iToxCloudCounter[arrPos] > 0 )
		g_hToxCloudTimer[arrPos] = CreateTimer(2.0, ToxicCloud_Timer, arrPos);
	else
	{
		if( entity != 0 ) // Because 0 is the server, and killing the server... crashes
			RemoveEntity(entity);
		g_iToxCloudEnt[arrPos] = 0;
	}
		
	return Plugin_Continue;
}

Action PlayerReverse_Timer(Handle timer, int client)
{
	g_hPlayerReverseTimer[client] = null;
	g_iPlayerBoosts[client] &= ~PN_REVERSE;
	if( !IsClientInGame(client) || !IsPlayerAlive(client) )
		return Plugin_Continue;
		
	PrintToChat(client, "%s \x03Reversed controls\x01 effect has ended.", CHAT_TAG);
	EmitSoundToClient(client, SND_BOOST_END);
	return Plugin_Continue;
}

Action PlayerExpl_Timer(Handle timer, int client)
{
	g_hPlayerExplTimer[client] = null;
	g_iPlayerBoosts[client] &= ~PB_EXPL;
	if( !IsClientInGame(client) || !IsPlayerAlive(client) )
		return Plugin_Continue;
		
	PrintToChat(client, "%s \x03Explosive shots\x01 effect has ended.", CHAT_TAG);
	EmitSoundToClient(client, SND_BOOST_END);
	return Plugin_Continue;
}

Action PlayerFragile_Timer(Handle timer, int client)
{
	g_hPlayerFragileTimer[client] = null;
	g_iPlayerBoosts[client] &= ~PN_FRAGILE;
	if( !IsClientInGame(client) || !IsPlayerAlive(client) )
		return Plugin_Continue;
		
	PrintToChat(client, "%s \x03Fragility\x01 ended.", CHAT_TAG);
	EmitSoundToClient(client, SND_BOOST_END);
	return Plugin_Continue;
}

Action PlayerAngles_Timer(Handle timer, int client)
{
	g_hPlayerAnglesTimer[client] = null;
	if( g_iPlayerBoosts[client] & PN_ANGLES )
	{
		float fTime = g_fPlayerAngleTime[client] - GetGameTime();
		float vPos[3];
		GetClientAbsOrigin(client, vPos);
		float v0 = GetRandomFloat(-89.0, 89.0), v1 = GetRandomFloat(0.0, 360.0);
		float vAng[3];
		vAng[0] = v0;
		vAng[1] = v1;
		vAng[2] = 0.0;
		TeleportEntity(client, vPos, vAng, NULL_VECTOR);
		if( fTime <= 5.0 )
		{
			g_iPlayerBoosts[client] &= ~PN_ANGLES;
			PrintToChat(client, "%s \x03Random orientation\x01 ended.", CHAT_TAG);
			EmitSoundToClient(client, SND_BOOST_END);	
		}
		else
		{
			float fRndTime = GetRandomFloat(1.8, 5.0);
			g_hPlayerAnglesTimer[client] = CreateTimer(fRndTime, PlayerAngles_Timer, client);		
		}
	}
	else
	{
		PrintToChat(client, "%s \x03Random orientation\x01 ended.", CHAT_TAG);
		EmitSoundToClient(client, SND_BOOST_END);
	}
	return Plugin_Continue;
}

Action EnableExpl_Timer(Handle timer, int client)
{
	g_bPlayerExpl[client] = false;
	return Plugin_Continue;
}

/* Its needed to wait a frame to spawn a weapon to prevent errors
 * if the weapon is spawned in the same frame the player is opening a box
 * the weapon will be picked up instantly
 */
void WeaponSpawn_Frame(int arrPos)
{
	int entity = EntRefToEntIndex(g_iWeaponEnt[arrPos]);
	if( entity == INVALID_ENT_REFERENCE )
		return;
		
	DispatchSpawn(entity);
}

/* ========================================================================================= *
 *                                Loot Box spawn & delete                                    *
 * ========================================================================================= */

void WipeLootBoxes()
{
	for( int i = 0; i < MAX_LBOXES; i++ )
	{
		int entity = EntRefToEntIndex(g_iLootBoxEnt[i]);
		// Check if entity still exists before attempting to delete it
		if( entity != 0 && entity != INVALID_ENT_REFERENCE )
			RemoveEntity(g_iLootBoxEnt[i]); // Maybe the entity has been removed before this, so prevent bugs

		g_iLootBoxEnt[i] = 0;		
		delete g_hLootBoxTimer[i]; // Allways try to close timer handles (this doesn't throw errors)
	}
}

void WipeWeapons()
{
	for( int i = 0; i < MAX_WEAPONS; i++ )
	{
		int entity = EntRefToEntIndex(g_iWeaponEnt[i]);
		if( entity != 0 && entity != INVALID_ENT_REFERENCE )
			RemoveEntity(entity);
			
		// Force delete timers and reset variable just in case
		delete g_hWeaponDeleteTimer[i];
		delete g_hWeaponUnlockTimer[i];
		g_iWeaponEnt[i] = 0;
	}
}

void WipeClouds()
{
	for( int i = 0; i < MAX_TOXCLOUD; i++ )
	{
		int entity = EntRefToEntIndex(g_iToxCloudEnt[i]);
		if( entity != 0 && entity != INVALID_ENT_REFERENCE )
			RemoveEntity(entity);
			
		delete g_hToxCloudTimer[i];
		g_iToxCloudEnt[i] = 0;
	}
}

void RandomLootBoxSpawn(float vPos[3], int minAm, int maxAm)
{
	int spawnAm = minAm != maxAm ? GetRandomInt(minAm, maxAm) : minAm;
	float vAng[3], vForce[3];
	for( int i = 0; i < spawnAm; i++ )
	{
		vAng[0] = GetRandomFloat(0.0, 360.0);
		vAng[1] = GetRandomFloat(0.0, 360.0);
		vAng[2] = GetRandomFloat(0.0, 360.0);
		vForce[0] = GetRandomFloat(-128.0, 128.0);
		vForce[1] = GetRandomFloat(-128.0, 128.0);
		vForce[2] = GetRandomFloat(32.0, 180.0);
		SpawnLootBox(vPos, vAng, vForce);
	}
}

bool SpawnLootBox(float origin[3], float angles[3], float force[3])
{
	// Get the lowest value of the array to store the lootbox entity reference for manipulations
	int index = -1;
	for( int i = 0; i < MAX_LBOXES; i++ )
	{
		if( g_iLootBoxEnt[i] == 0 )
		{
			index = i;
			break;
		}
	}
	// Array full, cant spawn lootboxes
	if( index == -1 )
		return false;
		
	int entity = -1;
	entity = CreateEntityByName("prop_physics_override");
	if( entity != -1 )
	{
		g_iLootBoxEnt[index] = EntIndexToEntRef(entity);
		delete g_hLootBoxTimer[index];	// Just in the case the timer has not been deleted yet!
		g_hLootBoxTimer[index] = CreateTimer(g_hBoxLifeTime.FloatValue, BoxLife_Timer, index); // Parse the array index

		DispatchKeyValue(entity, "model", MODEL_BOX);
//		DispatchKeyValue(entity, "targetname", TN_BOX);		// Not used really
		DispatchKeyValue(entity, "spawnflags", "8448");		// "Don`t take physics damage" + "Generate output on +USE" + "Force Server Side"
		DispatchKeyValue(entity, "glowstate", "3");
		DispatchKeyValue(entity, "glowcolor", "195 195 0");
		DispatchKeyValue(entity, "glowrange", "768");
		
		DispatchSpawn(entity);
		TeleportEntity(entity, origin, angles, force);
		
		SDKHook(entity, SDKHook_Use, LootBox_Used);
		return true;
	}
	PrintToServer("[LB] ERROR: LootBox Spawn failed.");
	return false;
}

Action LootBox_Used(int entity, int caller, int activator, UseType type, float value)
{
	// First check if player is able to open the box
	if( g_fPlayerUse[activator] + 3.0 > GetGameTime() )
	{
		// Just print chat alert once
		if( !g_bPlayerAdvert[activator] )
		{
			PrintToChat(activator, "%s Wait %.1f seconds to open next LootBox.", CHAT_TAG, 3 - GetGameTime() + g_fPlayerUse[activator]);
			g_bPlayerAdvert[activator] = true;
		}
		EmitSoundToClient(activator, SND_DENY);
		return Plugin_Continue;
	}
	else g_bPlayerAdvert[activator] = false; // Remove warnings block because player could open the box
	
	// Lets open the lootbox
	int entRef = EntIndexToEntRef(entity);
	// Instead of storing the lootbox reference somewhere wasting memory, search the reference in the array of lootboxes
	for( int i = 0; i < MAX_LBOXES; i++ )
	{
		if( g_iLootBoxEnt[i] == entRef )
		{
			OpenLootBox(entRef, activator, g_hPosProb.FloatValue);
			RemoveEntity(g_iLootBoxEnt[i]);
			g_iLootBoxEnt[i] = 0;
			delete g_hLootBoxTimer[i];
			break;
		}
	}
	
	g_fPlayerUse[activator] = GetGameTime();
	g_bPlayerAdvert[activator] = false;
	
	return Plugin_Continue;
}

Action Weapon_Used(int entity, int caller, int activator, UseType type, float value)
{
	// Just a stupid bot trying to steal the weapon
	if( IsFakeClient(activator) )
	{
		L4D_StaggerPlayer(activator, entity, NULL_VECTOR);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

/* ========================================================================================= *
 *                                       Loot Box open                                       *
 * ========================================================================================= */

void OpenLootBox(int box, int client, float chance)
{
	float vPos[3];
	bool bPass;
	
	GetEntPropVector(box, Prop_Send, "m_vecOrigin", vPos);				// Box position to know where to place stuff
	
	if( GetRandomFloat(0.0, 100.0) <= chance )
	{
		// Sometimes a roll could fail, so try another one
		do {
			bPass = OpenPos(vPos, client);
		} while (!bPass);
	}
	else
	{
		do {
			bPass = OpenNeg(vPos, client);			
		} while( !bPass );
	}
}

bool OpenPos(float[3] vPos, int client)
{
	// Roulette selection algorithm
	int choice;
	int abs = 0;
	int iRnd = GetRandomInt(0, g_iPosWeightSum);

	for( int i = 0; i < (g_bL4D2 ? POS_SIZE : POS_SIZE_1); i++ )
	{
		abs += g_iPosWeights[i];
		if( abs >= iRnd )
		{
			choice = i;
			break;
		}
	}
	if( g_bL4D2 )
	{
		switch( choice )
		{
			case POS_T1: return SPawnT1(client, vPos);
			case POS_T2: return SpawnT2(client, vPos);
			case POS_T3: return SpawnT3(client, vPos);
			case POS_DRUGS: return SpawnDrugs(client, vPos);
			case POS_MEDS: return SpawnMeds(client, vPos);
			case POS_SECNDARY: return SpawnSecondary(client, vPos);
			case POS_THROW: return SpawnThrowable(client, vPos);
			case POS_ITEM: return SpawnItem(client, vPos);
			case POS_UPGRADE: return SpawnUpgrade(client, vPos);
			case POS_LASER: return SpawnLaser(client, vPos);
			case POS_SPEED: GivePlayerSpeed(client);
			case POS_INVUL: GivePlayerInvulnerability(client);
			case POS_REGEN: GivePlayerRegen(client);
			case POS_FIRE: GivePlayerFire(client);
			case POS_IAMMO: GivePlayerInfAmmo(client);
			case POS_EXPL: GivePlayerExplosive(client);
			case POS_THANOS: WipeHalfZombies(client);
		}
	}
	else
	{
		switch( choice )
		{
			case POS_T1_1: return SPawnT1(client, vPos);
			case POS_T2_1: return SpawnT2(client, vPos);
			case POS_DRUGS_1: return SpawnDrugs(client, vPos);
			case POS_MEDS_1: return SpawnMeds(client, vPos);
			case POS_SECNDARY_1: return SpawnSecondary(client, vPos);
			case POS_THROW_1: return SpawnThrowable(client, vPos);
			case POS_ITEM_1: return SpawnItem(client, vPos);
			case POS_SPEED_1: GivePlayerSpeed(client);
			case POS_INVUL_1: GivePlayerInvulnerability(client);
			case POS_REGEN_1: GivePlayerRegen(client);
			case POS_FIRE_1: GivePlayerFire(client);
			case POS_IAMMO_1: GivePlayerInfAmmo(client);
			case POS_EXPL_1: GivePlayerExplosive(client);
			case POS_THANOS_1: WipeHalfZombies(client);

		}
	}
	return true;
}

bool OpenNeg(float[3] vPos, int client)
{
	int choice;
	int abs = 0;
	int iRnd = GetRandomInt(0, g_iNegWeightSum);
	
	for( int i = 0; i < (g_bL4D2 ? NEG_SIZE : NEG_SIZE_1); i++ )
	{
		abs += g_iNegWeights[i];
		if( abs >= iRnd )
		{
			choice = i;
			break;
		}
	}
	if( g_bL4D2 )
	{
		switch( choice )
		{
			case NEG_MOB: SpawnMob(client, false);
			case NEG_PANIC: SpawnMob(client, true);
			case NEG_VOMIT: BoxTrap(client, vPos, true);
			case NEG_SPIT: SpitTrap(client, vPos);
			case NEG_WITCH: return SpawnWitch(client, vPos);
			case NEG_TANK: return SpawnTank(client, vPos);
			case NEG_TOXIC: return ToxicCloud(client, vPos);
			case NEG_JOCKEY: return JockeyRide(client);
			case NEG_BARREL: return SpawnExplBarrel(client, vPos);
			case NEG_BLACKWHITE: BlackWhite(client);
			case NEG_FROZEN: BoxTrap(client, vPos, false);
			case NEG_REVERSE: ReverseControls(client);
			case NEG_FRAGILE: GiveFragility(client);
			case NEG_BEARTRAP: BearTrap(client, vPos);
			case NEG_ANGLES: RandomAngles(client);
			case NEG_FIREWORK: return SpawnFireworks(client, vPos);
			case NEG_FULLSI: return SpawnFullTeam(client);
		}
	}
	else
	{
		switch( choice )
		{
			case NEG_MOB_1: SpawnMob(client, false);
			case NEG_PANIC_1: SpawnMob(client, true);
			case NEG_VOMIT_1: BoxTrap(client, vPos, true);
			case NEG_WITCH_1: return SpawnWitch(client, vPos);
			case NEG_TANK_1: return SpawnTank(client, vPos);
			case NEG_TOXIC_1: return ToxicCloud(client, vPos);
			case NEG_BARREL_1: return SpawnExplBarrel(client, vPos);
			case NEG_BLACKWHITE_1: BlackWhite(client);
			case NEG_FROZEN_1: BoxTrap(client, vPos, false);
			case NEG_REVERSE_1: ReverseControls(client);
			case NEG_FRAGILE_1: GiveFragility(client);
			case NEG_BEARTRAP_1: BearTrap(client, vPos);
			case NEG_ANGLES_1: RandomAngles(client);
			case NEG_FULLSI_1: return SpawnFullTeam(client);
		}

	}
	return true;
}

/* ========================================================================================= *
 *                                        RayTracing                                         *
 * ========================================================================================= */

// Check if a RayTrace 
bool IsValidImpact(float vSource[3], float vTarget[3])
{
	Handle hTrace = TR_TraceRayFilterEx(vSource, vTarget, MASK_SHOT, RayType_EndPoint, _TraceFilter);
	if( !TR_DidHit(hTrace) )
	{
		delete hTrace;
		return true;	
	}
	delete hTrace;
	return false;
}

bool IsValidPosition(int client, float vPos[3], float vAng[3])
{
	GetClientEyePosition(client, vPos);
	GetClientEyeAngles(client, vAng);
	
	Handle trace = TR_TraceRayFilterEx(vPos, vAng, MASK_SHOT, RayType_Infinite, _TraceFilter);
	if( TR_DidHit(trace) )
	{
		TR_GetEndPosition(vPos, trace);
		vPos[2] += 4.0;
		if( FoundObstacle(vPos) )
		{
			delete trace;
			return false;
		}
	}
	else
	{
		delete trace;
		return false;
	}
	delete trace;
	return true;
}

bool FoundObstacle(const float vPos[3])
{
	float vAng[3], vEnd[3];
	Handle trace2;
	vAng[0] = -90.0;
	trace2 = TR_TraceRayFilterEx(vPos, vAng, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite, _TraceFilter);
	if( TR_DidHit(trace2) )
	{
		TR_GetEndPosition(vEnd, trace2);
		if( GetVectorDistance(vEnd, vPos, true) < 5184.0 )
		{
			delete trace2;
			return true;
		}
	}
	vAng[0]= 0.0;
	
	for( int i = 0; i < 8; i++ )
	{
		vAng[1] = 45.0 * i;
		trace2 = TR_TraceRayFilterEx(vPos, vAng, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite, _TraceFilter);
		if( TR_DidHit(trace2) )
		{
			TR_GetEndPosition(vEnd, trace2);
			if( GetVectorDistance(vEnd, vPos, true) < 64.0 )
			{
				delete trace2;
				return true;
			}
		}
	}
	delete trace2;
	return false;
}

bool _TraceFilter(int entity, int contentsMask)
{
	if( !entity ) return true;
	return entity > MaxClients;
}

/* ========================================================================================= *
 *                                Good Loot Box functions                                    *
 * ========================================================================================= */

bool SPawnT1(int client, float[3] vPos)
{
	int iWeapon;
	if( g_bL4D2 ) iWeapon = WeaponSpawn("weapon_spawn", "tier1_any");
	else iWeapon = GetRandomInt(0, 1) == 0 ? WeaponSpawn("weapon_smg_spawn") : WeaponSpawn("weapon_pumpshotgun_spawn");
		
	if (iWeapon == -1)
		return false;
		
	TeleportEntity(iWeapon, vPos, NULL_VECTOR, NULL_VECTOR);
	PrintToChat(client, "%s You have found a \x03tier 1 weapon\x01.", CHAT_TAG);
	EmitAmbientSound(SND_GOOD_OPEN, vPos);
	return true;
}

bool SpawnT2(int client, float[3] vPos)
{
	int iWeapon;
	if( g_bL4D2 ) iWeapon = WeaponSpawn("weapon_spawn", "tier2_any");
	else iWeapon = GetRandomInt(0, 1) == 0 ? WeaponSpawn("weapon_rifle_spawn") : WeaponSpawn("weapon_autoshotgun_spawn");
	if( iWeapon == -1 )
		return false;
		
	TeleportEntity(iWeapon, vPos, NULL_VECTOR, NULL_VECTOR);
	PrintToChat(client, "%s You have found a \x03tier 2 weapon\x01.", CHAT_TAG);
	EmitAmbientSound(SND_GOOD_OPEN, vPos);
	return true;
}

bool SpawnT3(int client, float[3] vPos)
{
	int iWeapon;
	if( GetRandomInt(0, 1) == 0 )
	{
		iWeapon = WeaponSpawn("weapon_rifle_m60_spawn");
		if( iWeapon == -1 )
			return false;
			
		TeleportEntity(iWeapon, vPos, NULL_VECTOR, NULL_VECTOR);
		PrintToChat(client, "%s You have found a \x03M60 rifle\x01.", CHAT_TAG);
	}
	else
	{
		iWeapon = WeaponSpawn("weapon_grenade_launcher_spawn");
		if( iWeapon == -1 )
			return false;
			
		TeleportEntity(iWeapon, vPos, NULL_VECTOR, NULL_VECTOR);
		PrintToChat(client, "%s You have found a \x03grenade launcher\x01.", CHAT_TAG);
	}
	EmitAmbientSound(SND_GOOD_OPEN, vPos);
	return true;
}

bool SpawnSecondary(int client, float[3] vPos)
{
	int iRand = GetRandomInt(1, 3);
	float fRand = g_bL4D2 ? GetRandomFloat(0.0, 1.0) : 0.0; // Force pistols in L4D
	int iWeapon;
	bool bSpawn;
	
	for( int i = 0; i < iRand; i++ )
	{
		if( fRand < 0.4 )
		{
			iWeapon = WeaponSpawn("weapon_pistol_spawn");
			if( iWeapon == -1 )
				continue;
				
			TeleportEntity(iWeapon, vPos, NULL_VECTOR, NULL_VECTOR);
			bSpawn = true;
		}
			
		else if( fRand < 0.8 )
		{
			char weaponName[32];
			strcopy(weaponName, sizeof(weaponName), g_sMeleeList[GetRandomInt(0, sizeof(g_sMeleeList) - 1)]);
			iWeapon = WeaponSpawn("weapon_melee_spawn", weaponName);
			if( iWeapon == -1 )
				continue;

			TeleportEntity(iWeapon, vPos, NULL_VECTOR, NULL_VECTOR);
			bSpawn = true;
		}
		else
		{
			iWeapon = WeaponSpawn("weapon_pistol_magnum_spawn");
			if( iWeapon == -1 )
				continue;
				
			TeleportEntity(iWeapon, vPos, NULL_VECTOR, NULL_VECTOR);
			bSpawn = true;
		}			
	}
	if( !bSpawn )
		return false;
		
	PrintToChat(client, "%s You have found \x03secondary weapons\x01.", CHAT_TAG);
	EmitAmbientSound(SND_GOOD_OPEN, vPos);
	return true;
}

bool SpawnDrugs(int client, float[3] vPos)
{
	int iRand = GetRandomInt(1, 4);
	int iRand2 = g_bL4D2 ? GetRandomInt(0, 1) : 0;
	int iWeapon;
	bool bSpawn;
	for( int i = 0; i < iRand; i++ )
	{
		if( iRand2 == 0 )
			iWeapon = WeaponSpawn("weapon_pain_pills_spawn");
		else
			iWeapon = WeaponSpawn("weapon_adrenaline_spawn");
		
		if( iWeapon == -1 )
			continue;
		
		TeleportEntity(iWeapon, vPos, NULL_VECTOR, NULL_VECTOR);
		bSpawn = true;
	}
	if( !bSpawn ) 
		return false;
		
	PrintToChat(client, "%s You have found \x03drugs\x01.", CHAT_TAG);
	EmitAmbientSound(SND_GOOD_OPEN, vPos);
	return true;
}

bool SpawnMeds(int client, float[3] vPos)
{
	int iRand = GetRandomInt(1, 3);
	int iRand2 = g_bL4D2 ? GetRandomInt(0, 4) : 1;
	int iWeapon;
	bool bSpawn;
	for( int i = 0; i < iRand; i++ )
	{
		if( iRand2 == 0 )
			iWeapon = WeaponSpawn("weapon_defibrillator_spawn");
		else
			iWeapon = WeaponSpawn("weapon_first_aid_kit_spawn");
			
		if( iWeapon == -1 )
			continue;
			
		bSpawn = true;
		TeleportEntity(iWeapon, vPos, NULL_VECTOR, NULL_VECTOR);
	}
	if( !bSpawn )
		return false;
		
	PrintToChat(client, "%s You have found \x03medical items\x01.", CHAT_TAG);
	EmitAmbientSound(SND_GOOD_OPEN, vPos);
	return true;
}

bool SpawnThrowable(int client, float[3] vPos)
{
	int iRand = g_bL4D2 ? GetRandomInt(0, 2) : GetRandomInt(0, 1);
	int iWeapon;
	if( iRand == 0 )
		iWeapon = WeaponSpawn("weapon_pipe_bomb_spawn");
	else if( iRand == 1 )
		iWeapon = WeaponSpawn("weapon_molotov_spawn");
	else
		iWeapon = WeaponSpawn("weapon_vomitjar_spawn");
		
	if( iWeapon == -1 )
		return false;
		
	TeleportEntity(iWeapon, vPos, NULL_VECTOR, NULL_VECTOR);
	PrintToChat(client, "%s You have found a \x03throwable\x01.", CHAT_TAG);
	EmitAmbientSound(SND_GOOD_OPEN, vPos);
	return true;
}

bool SpawnItem(int client, float[3] vPos)
{
	int iEntity = -1;
	int iRand = g_bL4D2 ? GetRandomInt(0, 3) : GetRandomInt(1, 3);
	iEntity = CreateEntityByName("physics_prop");
	char sName[20];
	if( iEntity != -1 )
	{
		switch( iRand )
		{
			case 0: {
				SetEntityModel(iEntity, MODEL_FIREWORK);
				sName = "firework crate";
			}
			case 1: {
				SetEntityModel(iEntity, MODEL_GASCAN);
				sName = "gascan";
			}
			case 2: {
				SetEntityModel(iEntity, MODEL_PROPANETANK);
				sName = "propane tank";
			}
			case 3: {
				SetEntityModel(iEntity, MODEL_OXYGENTANK);
				sName = "oxygen tank";
			}
		}
		DispatchSpawn(iEntity);
		TeleportEntity(iEntity, vPos, NULL_VECTOR, NULL_VECTOR);
		PrintToChat(client, "%s You have found a \x03%s\x01.", CHAT_TAG, sName);
		return true;
	}
	return false;
}

bool SpawnUpgrade(int client, float[3] vPos)
{
	int iWeapon;
	if( GetRandomInt(0, 1) == 0 )
		iWeapon = WeaponSpawn("weapon_upgradepack_explosive_spawn");
	else
		iWeapon = WeaponSpawn("weapon_upgradepack_explosive_spawn");

	if( iWeapon == -1 )
		return false;
		
	TeleportEntity(iWeapon, vPos, NULL_VECTOR, NULL_VECTOR);
	PrintToChat(client, "%s You have found an \x03upgrade pack\x01.", CHAT_TAG);
	EmitAmbientSound(SND_GOOD_OPEN, vPos);
	return true;
}

bool SpawnLaser(int client, float[3] vPos)
{
	int iArrPos = -1;
	for( int i = 0; i < MAX_WEAPONS; i++ )
	{
		if( g_iWeaponEnt[i] == 0 )
		{
			iArrPos = i;
			break;
		}
	}
	if( iArrPos == -1 )
		return false;

	int iEntity = -1;
	iEntity = CreateEntityByName("upgrade_laser_sight");
	if( iEntity == -1 )
		return false;

	g_iWeaponEnt[iArrPos] = EntIndexToEntRef(iEntity);
	TeleportEntity(iEntity, vPos, NULL_VECTOR, NULL_VECTOR);
	g_hWeaponDeleteTimer[iArrPos] = CreateTimer(g_hWeaponLife.FloatValue, WeaponDelete_Timer, iArrPos);
	RequestFrame(WeaponSpawn_Frame, iArrPos);
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( i != client && IsClientInGame(i) && !IsFakeClient(i) )
			PrintToChat(i, "%s \x03%N\x01 has found a \x03laser box\x01.", CHAT_TAG, client);
	}
	PrintToChat(client, "%s You have found a \x03laser box\x01.", CHAT_TAG);
	return true;
}

void GivePlayerSpeed(int client)
{
	if( CheckPlayerBoost(client, PB_SPEED) )
	{
		delete g_hPlayerSpeedTimer[client];
		g_hPlayerSpeedTimer[client] = CreateTimer(g_fBoostTimes[0], PlayerSpeed_Timer, client);
		PrintToChat(client, "%s You have extended your \x03speed boost\x01.", CHAT_TAG);
		return;
	}

	SU_SetSpeed(client, SPEED_RUN, SU_GetSpeed(client, SPEED_RUN) * 1.2);
	SU_SetSpeed(client, SPEED_LIMP, SU_GetSpeed(client, SPEED_LIMP) * 1.2);
	SU_SetSpeed(client, SPEED_CRITICAL, SU_GetSpeed(client, SPEED_CRITICAL) * 1.2);
	g_hPlayerSpeedTimer[client] = CreateTimer(g_fBoostTimes[0], PlayerSpeed_Timer, client);
	g_iPlayerBoosts[client] |= PB_SPEED;
	PrintToChat(client, "%s You have obtained \x03speed boost\x01.", CHAT_TAG);
	
	int iParticleRef = SetPlayerParticle(client, PARTICLE_SMOKE);
	if( iParticleRef != INVALID_ENT_REFERENCE )
		g_iPlayerParticle[client] = iParticleRef;
}

void GivePlayerInvulnerability(int client)
{
	if( CheckPlayerBoost(client, PB_INVUL) )
	{
		delete g_hPlayerInvulTimer[client];
		g_hPlayerInvulTimer[client] = CreateTimer(g_fBoostTimes[1], PlayerInvul_Timer, client);
		PrintToChat(client, "%s You have extended your \x03invulnerability\x01.", CHAT_TAG);
		return;
	}
	
	SDKHook(client, SDKHook_OnTakeDamage, Invulnerability_Callback);
	g_hPlayerInvulTimer[client] = CreateTimer(g_fBoostTimes[1], PlayerInvul_Timer, client);
	g_iPlayerBoosts[client] |= PB_INVUL;
	PrintToChat(client, "%s You have obtained \x03invulnerability\x01.", CHAT_TAG);
}

void GivePlayerRegen(int client)
{
	g_iPlayerRegenToken[client] = RoundToNearest(g_fBoostTimes[2] * 2);
	if( CheckPlayerBoost(client, PB_REGEN) )
	{
		PrintToChat(client, "%s You have extended your \x03regeneration\x01.", CHAT_TAG);
		return;		
	}
	
	EmitSoundToClient(client, SND_REGEN);
	CreateTimer(1.0, PlayerRegen_Timer, client);
	g_iPlayerBoosts[client] = PB_REGEN;
	PrintToChat(client, "%s You have obtained \x03regeneration\x01.", CHAT_TAG);
	
	int iParticleRef = SetPlayerParticle(client, PARTICLE_EMBERS);
	if( iParticleRef != INVALID_ENT_REFERENCE )
		g_iPlayerParticle[client] = iParticleRef;
}

void GivePlayerFire(int client)
{
	if( CheckPlayerBoost(client, PB_FIRE) )
	{
		delete g_hPlayerFireTimer[client];
		g_hPlayerFireTimer[client] = CreateTimer(g_fBoostTimes[3], PlayerFire_Timer, client);
		PrintToChat(client, "%s You have extended your \x03fire power\x01.", CHAT_TAG);
		return;
	}
	
	EmitSoundToClient(client, SND_FIRE);
	g_hPlayerFireTimer[client] = CreateTimer(g_fBoostTimes[3], PlayerFire_Timer, client);
	g_iPlayerBoosts[client] = PB_FIRE;
	PrintToChat(client, "%s You have obtained \x01fire power\x01.", CHAT_TAG);
	
	int iParticleRef = SetPlayerParticle(client, PARTICLE_FIRE);
	if( iParticleRef != INVALID_ENT_REFERENCE )
		g_iPlayerParticle[client] = iParticleRef;
}

void GivePlayerInfAmmo(int client)
{
	if( CheckPlayerBoost(client, PB_IAMMO) )
	{
		delete g_hPlayerAmmoTimer[client];
		g_hPlayerAmmoTimer[client] = CreateTimer(g_fBoostTimes[4], PlayerInfAmmo_Timer, client);
		PrintToChat(client, "%s You have extended your \x03infinite ammo\x01.", CHAT_TAG);
		return;
	}
	
	g_hPlayerAmmoTimer[client] = CreateTimer(g_fBoostTimes[4], PlayerInfAmmo_Timer, client);
	g_iPlayerBoosts[client] = PB_IAMMO;
	PrintToChat(client, "%s You have obtained \x03infinite ammo\x01.", CHAT_TAG);
}

void GivePlayerExplosive(int client)
{
	if( CheckPlayerBoost(client, PB_EXPL) )
	{
		delete g_hPlayerExplTimer[client];
		g_hPlayerExplTimer[client] = CreateTimer(g_fBoostTimes[5], PlayerExpl_Timer, client);
		PrintToChat(client, "%s You have extended your \x03explosive shots\x01.", CHAT_TAG);
	}
	else
	{
		g_iPlayerBoosts[client] |= PB_EXPL;
		g_hPlayerExplTimer[client] = CreateTimer(g_fBoostTimes[5], PlayerExpl_Timer, client);
		PrintToChat(client, "%s You have obtained \x03explosive shots\x01.", CHAT_TAG);
	}
}

void WipeHalfZombies(int client)
{
	bool bMustDie = true;
	int infected, witch;
	while( (infected = FindEntityByClassname(infected, "infected")) != INVALID_ENT_REFERENCE )
	{
		if( bMustDie )
		{
			// Using SDKHooks_TakeDamage ensures that the kill will be added to the client activator
			SDKHooks_TakeDamage(infected, client, client, 10000.0, 0, -1, NULL_VECTOR, NULL_VECTOR);
			bMustDie = false;
		}
		else
			bMustDie = true;
	}
	while( (witch = FindEntityByClassname(witch, "witch")) != INVALID_ENT_REFERENCE )
	{
		if( bMustDie )
		{
			SDKHooks_TakeDamage(witch, client, client, 10000.0, 0, -1, NULL_VECTOR, NULL_VECTOR);
			bMustDie = false;
		}
		else
			bMustDie = true;
	}
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && GetClientTeam(i) == 1 && IsPlayerAlive(i) )
		{
			if( GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK )
			{
				SDKHooks_TakeDamage(i, client, client, GetClientHealth(client) / 2.0, 0, -1, NULL_VECTOR, NULL_VECTOR); // Halve tank health
				continue;
			}
			if( bMustDie )
			{
				SDKHooks_TakeDamage(i, client, client, 10000.0, 0, -1, NULL_VECTOR, NULL_VECTOR);
				bMustDie = false;
			}
			else
				bMustDie = true;
		}
		if( i != client && IsClientInGame(i) && !IsFakeClient(i) )
		{
			PrintToChat(i, "%s \x03%N\x01 has found \x03The Infinity Gauntlet\x01.", CHAT_TAG, client);
		}
	}
	EmitSoundToAll(SND_THANOS);
	PrintToChat(client, "%s You have found \x03The Infinity Gauntlet\x01.", CHAT_TAG);
}

/* ========================================================================================= *
 *                                 Bad Loot Box functions                                    *
 * ========================================================================================= */

void SpawnMob(int client, bool mega)
{
	if( mega )
	{
		char[] command = "director_force_panic_event";
		int iComFlags = GetCommandFlags(command);
		SetCommandFlags(command, iComFlags & ~FCVAR_CHEAT);
		FakeClientCommand(client, "%s", command);
		SetCommandFlags(command, iComFlags);
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( i != client && IsClientInGame(i) && !IsFakeClient(i) )
				PrintToChat(i, "%s \x03%N\x01 has found a \x03panic event\x01.", CHAT_TAG, client);
		}
		PrintToChat(client, "%s You have found a \x03panic event\x01.", CHAT_TAG);
		g_iNextMobSize = g_hMegaMobSize.IntValue;
	}
	else
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( i != client && IsClientInGame(i) && !IsFakeClient(i) )
				PrintToChat(i, "%s \x03%N\x01 has found \x03some zombies\x01.", CHAT_TAG, client);
		}
		PrintToChat(client, "%s You have found \x03some zombies\x01.", CHAT_TAG);
	}
	// Spawn a mob even on panic, because sometimes panic events may not be called
	int iComFlags = GetCommandFlags("z_spawn_old");
	SetCommandFlags("z_spawn_old", iComFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "z_spawn_old %s", "mob");
	SetCommandFlags("z_spawn_old", iComFlags);
	if( g_iNextMobSize < 0 )
		g_iNextMobSize = g_hMobSize.IntValue;
}

void BoxTrap(int client, float[3] vPos, bool isVomit)
{
	float vClientPos[3];
	vPos[2] += 16;
	int newEnt = -1;
	newEnt = CreateEntityByName("info_particle_system");
	if( newEnt != -1 )
	{
		DispatchKeyValue(newEnt, "effect_name", PARTICLE_BOOMER);
		DispatchSpawn(newEnt);
		ActivateEntity(newEnt);
		TeleportEntity(newEnt, vPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(newEnt, "Enable");
		AcceptEntityInput(newEnt, "Start");
		// Entity will kill himself using game entity I/O
		SetVariantString("OnUser1 !self:Kill:1:1");
		AcceptEntityInput(newEnt, "AddOutput");
		AcceptEntityInput(newEnt, "FireUser1");
	}

	EmitAmbientSound(SND_BOOMER_EXPL, vPos);
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( !IsClientInGame(i) )
			continue;
			
		if( client != i && !IsFakeClient(i) )
			PrintToChat(i, "%s \x03%N\x01 Has opened %s", CHAT_TAG, client, isVomit ? "a \x03vomit trap\x01." : "an \x03ice trap\x01.");
			
		if( !IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i) )
		{
			continue;
		}
		GetClientEyePosition(i, vClientPos);
		if( GetVectorDistance(vPos, vClientPos) > 256.0 || !IsValidImpact(vPos, vClientPos) )
			continue;

		if( isVomit )
		{
			L4D_CTerrorPlayer_OnVomitedUpon(i, client);
			L4D_StaggerPlayer(i, client, vPos);
		}
		else
			SU_AddFreeze(i, g_hFreezeTime.FloatValue);
	}
	PrintToChat(client, "%s You have opened %s", CHAT_TAG, isVomit ? "a \x03vomit trap\x01." : "an \x03ice trap\x01.");
}

void ReverseControls(int client)
{
	if( g_iPlayerBoosts[client] & PN_REVERSE)
	{
		delete g_hPlayerReverseTimer[client];
		g_hPlayerReverseTimer[client] = CreateTimer(g_fNerfTimes[0], PlayerReverse_Timer, client);
		PrintToChat(client, "%s You have extended your \x03reversed controls\x01.", CHAT_TAG);
		return;
	}
	g_hPlayerReverseTimer[client] = CreateTimer(g_fNerfTimes[0], PlayerReverse_Timer, client);
	PrintToChat(client, "%s You have obtained \x03reversed controls\x01.", CHAT_TAG);
	EmitSoundToClient(client, SND_BAD_OPEN);
	g_iPlayerBoosts[client] |= PN_REVERSE;
}

void SpitTrap(int client, float[3] vPos)
{
	float vAng[3];
	vAng[2] = 150.0;
	vPos[2] += 16;
	int iBot = CreateFakeClient("Loot Box");	//Create a fake infected to display acid sound effect and make survivor bots leave the area
	ChangeClientTeam(iBot, 3);
	L4D2_SpitterPrj(iBot, vPos, vAng);
	
	for( int i = 0; i < 2; i++ )
	{
		vAng[0] = g_fTriSpitForces[i][0];
		vAng[1] = g_fTriSpitForces[i][1];
		L4D2_SpitterPrj(iBot, vPos, vAng);
	}
	CreateTimer(10.0, RemoveBot_Timer, GetClientSerial(iBot), TIMER_FLAG_NO_MAPCHANGE);
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( i != client && IsClientInGame(i) && !IsFakeClient(i) )
			PrintToChat(i, "%s \x03%N\x01 has opened a \x03spit trap\x01.", CHAT_TAG, client);
	}
	PrintToChat(client, "%s You have opened a \x03spit trap\x01.", CHAT_TAG);
}

bool SpawnWitch(int client, float[3] vPos)
{
	int result = -1;
	result = L4D2_SpawnWitch(vPos, NULL_VECTOR);
	
	if( result < 0 )
		return false;
		
	EmitAmbientSound(SND_BAD_OPEN, vPos);
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && i != client && !IsFakeClient(i) )
			PrintToChat(i, "%s \x03%N\x01 has found a \x03Witch\x01.", CHAT_TAG, client);
	}
	PrintToChat(client, "%s You have found a \x03Witch\x01.", CHAT_TAG);
	return true;
}

bool SpawnTank(int client, float[3]vPos)
{
	float vector[3];
	int result = -1;
	// Try to get an appropiate place to spawn a tank
	if( L4D_GetRandomPZSpawnPosition(client, ZC_TANK, 10, vector) )
	{
		result = L4D2_SpawnTank(vector, NULL_VECTOR);
		SDKHooks_TakeDamage(result, client, client, 4.0, 0, -1, NULL_VECTOR, NULL_VECTOR);
	}
	// If the place is not found, spawn where the box has been opened, bad luck!	
	else
		result = L4D2_SpawnTank(vPos, NULL_VECTOR);
		
	if( result < 0 )
		return false;
	
	EmitAmbientSound(SND_BAD_OPEN, vPos);
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && i != client && !IsFakeClient(i) )
			PrintToChat(i, "%s \x03%N\x01 has found a \x03Tank\x01.", CHAT_TAG, client);
	}
	PrintToChat(client, "%s You have found a \x03Tank\x01.", CHAT_TAG);
	return true;
}

bool ToxicCloud(int client, float[3] vPos)
{
	vPos[2] -= 144;
	int iEntity = -1;
	int iArrPos;
	
	for( int i = 0; i < MAX_TOXCLOUD; i++ )
	{
		if( g_iToxCloudEnt[i] == 0 )
		{
			iArrPos = i;
			break;
		}
		else if( i == MAX_TOXCLOUD - 1 )
			return false;
	}
	
	iEntity = CreateEntityByName("info_particle_system");
	if( iEntity != -1 )
	{
		g_iToxCloudEnt[iArrPos] = EntIndexToEntRef(iEntity);
		DispatchKeyValue(iEntity, "effect_name", PARTICLE_TOXIC);
		DispatchSpawn(iEntity);
		TeleportEntity(iEntity, vPos, NULL_VECTOR, NULL_VECTOR);
		ActivateEntity(iEntity);
		AcceptEntityInput(iEntity, "Enable");
		AcceptEntityInput(iEntity, "Start");
		
		g_hToxCloudTimer[iArrPos] = CreateTimer(2.0, ToxicCloud_Timer, iArrPos);
	}
	else return false;
	
	EmitAmbientSound(SND_BAD_OPEN, vPos);
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && i != client && !IsFakeClient(i) )
			PrintToChat(i, "%s \x03%N\x01 has found a \x03toxic cloud\x01.", CHAT_TAG, client);
	}
	// Because each token is consumed each 2 seconds, divide the time of ConVar by 2
	g_iToxCloudCounter[iArrPos] = g_hToxCloudLife.IntValue / 2;
	PrintToChat(client, "%s You have found a \x03toxic cloud\x01.", CHAT_TAG);
	return true;
}

bool JockeyRide(int client)
{
	float vPos[3];
	GetClientEyePosition(client, vPos);
	int result = -1;
	result = L4D2_SpawnSpecial(ZC_JOCKEY, vPos, NULL_VECTOR);
	EmitSoundToClient(client, SND_BAD_OPEN);
	
	if( result > 0 )
	{
		PrintToChat(client, "%s You have found a \x03 Jockey\x01.", CHAT_TAG);
		return true;
	}
	return false;
}

bool SpawnExplBarrel(int client, float[3] vPos)
{
	int iEntity = -1;
	iEntity = CreateEntityByName("prop_fuel_barrel");
	
	if( iEntity != -1 )
	{
		DispatchKeyValue(iEntity, "model", MODEL_BARREL);
		DispatchKeyValue(iEntity, "BasePiece", MODEL_BARRELB);
		DispatchKeyValue(iEntity, "FlyingPiece01", MODEL_BARRELA);
		DispatchKeyValue(iEntity, "FlyingParticles", "barrel_fly");
		DispatchKeyValue(iEntity, "DetonateParticles", "weapon_pipebomb");
		DispatchKeyValue(iEntity, "DetonateSound", "BaseGrenade.Explode");
		TeleportEntity(iEntity, vPos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(iEntity);
	}
	else return false;
	
	EmitAmbientSound(SND_BAD_OPEN, vPos);
	IgniteEntity(iEntity, 60.0);
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame(i) && i != client && !IsFakeClient(i) )
			PrintToChat(i, "%s \x03%N\x01 has found an \x03explosive barrel\x01.", CHAT_TAG, client);
	}
	PrintToChat(client, "%s You have found an \x03explosive barrel\x01.", CHAT_TAG);
	return true;
}

void BlackWhite(int client)
{
	ConVar hIncapLimit = FindConVar("survivor_max_incapacitated_count"); // Max amount of incapacitations before killing a player
	int num = hIncapLimit.IntValue;
	SetEntProp(client, Prop_Send, "m_currentReviveCount", num);
	SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 1);
	
	PrintToChat(client, "%s You have obtained \x03black and white\x01.", CHAT_TAG);
} 

void GiveFragility(int client)
{
	// Player is invulnerable, remove only the boost
	if( g_iPlayerBoosts[client] & PB_INVUL )
	{
		delete g_hPlayerInvulTimer[client];
		g_iPlayerBoosts[client] &= ~PB_INVUL;
		SDKUnhook(client, SDKHook_OnTakeDamage, Invulnerability_Callback);
		EmitSoundToClient(client, SND_BAD_OPEN);
		PrintToChat(client, "%s You have obtained\x03fragility\x01, your \x03invulnerability\x01 has been removed.", CHAT_TAG);
	}
	else if( g_iPlayerBoosts[client] & PN_FRAGILE )
	{
		delete g_hPlayerFragileTimer[client];
		g_hPlayerFragileTimer[client] = CreateTimer(g_fNerfTimes[1], PlayerFragile_Timer, client);
		EmitSoundToClient(client, SND_BAD_OPEN);
		PrintToChat(client, "%s You have extended your \x03fragility\x01 effect.", CHAT_TAG);
	}
	else
	{
		g_iPlayerBoosts[client] |= PN_FRAGILE;
		g_hPlayerFragileTimer[client] = CreateTimer(g_fNerfTimes[1], PlayerFragile_Timer, client);
		SDKHook(client, SDKHook_OnTakeDamage, Fragility_Callback);
		EmitSoundToClient(client, SND_BAD_OPEN);
		PrintToChat(client, "%s You have found \x03fragility\x01 effect.", CHAT_TAG);
	}
}

void BearTrap(int client, float[3] vPos)
{
	PrintToChat(client, "%s You have opened a \x03bear trap\x01.", CHAT_TAG);
	SDKHooks_TakeDamage(client, client, client, 10.0, 0, -1, NULL_VECTOR, NULL_VECTOR);
	SU_AddBleed(client, g_hBleedHits.IntValue);
	EmitAmbientSound(SND_BEARTRAP, vPos);
}

void RandomAngles(int client)
{
	g_fPlayerAngleTime[client] = GetGameTime() + g_fNerfTimes[2];
	if( g_iPlayerBoosts[client] & PN_ANGLES )
	{
		PrintToChat(client, "%s You have extended your \x03random orientation\x01.", CHAT_TAG);
		return;
	}
	g_iPlayerBoosts[client] |= PN_ANGLES;
	PrintToChat(client, "%s You have obtained \x03random orientation\x01.",CHAT_TAG);
	g_hPlayerAnglesTimer[client] = CreateTimer(2.0, PlayerAngles_Timer, client);
}

bool SpawnFireworks(int client, float[3] vPos)
{
	vPos[2] +=16.0;
	bool result = false;
	for( int i = 0; i < 4; i++ )
	{
		int iEntity = -1;
		iEntity = CreateEntityByName("physics_prop");
		if( iEntity != -1 )
		{
			float vForce[3];
			vForce[0] = 225.0 * ( (i - 1) % 2 );
			vForce[1] = 225.0 * ( (i - 2) % 2 );
			vForce[2] = 175.0;
			SetEntityModel(iEntity, MODEL_FIREWORK);
			DispatchKeyValue(iEntity, "spawnflags", "4");
			DispatchSpawn(iEntity);
			TeleportEntity(iEntity, vPos, NULL_VECTOR, vForce);
			IgniteEntity(iEntity, 60.0);
			result = true;
		}
	}
	if( result )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( i != client && IsClientInGame(i) && !IsFakeClient(i) )
				PrintToChat(i, "%s \x03%N\x01 has found \x03firework party\x01.", CHAT_TAG, client);
		}
		PrintToChat(client, "%s You have found \x03firework party\x01.", CHAT_TAG);
	}
	return result;
}

bool SpawnFullTeam(int client)
{
	bool result = false;
	for( int i = 1; i < (g_bL4D2 ? 7 : 4); i++ )
	{
		float vPos[3];
		int pos = -1;
		pos = L4D_GetRandomPZSpawnPosition(client, i, 10, vPos);
		if( pos != -1 )
		{
			L4D2_SpawnSpecial(i, vPos, NULL_VECTOR);
			result = true;	
		}
	}
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( i != client && IsClientInGame(i) && !IsFakeClient(i) )
			PrintToChat(i, "%s \x03%N\x01 has found a \x03full team of infected\x01.", CHAT_TAG, client);
	}
	PrintToChat(client, "%s You have found a \x03full team of infected\x01.", CHAT_TAG);
	return result;
}

/* ========================================================================================= *
 *                                     Weapon Handling                                       *
 * ========================================================================================= */

public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier)
{
	speedmodifier = SpeedModifier(client, speedmodifier); //send speedmodifier to be modified
}

public void WH_OnStartThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnReadyingThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnGetRateOfFire(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnDeployModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = SpeedModifier(client, speedmodifier);
}

float SpeedModifier(int client, float speedmodifier)
{
	if( g_iPlayerBoosts[client] & PB_SPEED )
	{
		speedmodifier = speedmodifier * 1.4;// multiply current modifier to not overwrite any existing modifiers already
	}
	else
		speedmodifier = 1.0;
	return speedmodifier;
}

/* ========================================================================================= *
 *                                    Other functions                                        *
 * ========================================================================================= */

int PrecacheParticle(const char[] sEffectName)
{
    static int table = INVALID_STRING_TABLE;

    if( table == INVALID_STRING_TABLE )
    {
        table = FindStringTable("ParticleEffectNames");
    }

    int index = FindStringIndex(table, sEffectName);
    if( index == INVALID_STRING_INDEX )
    {
        bool save = LockStringTables(false);
        AddToStringTable(table, sEffectName);
        LockStringTables(save);
        index = FindStringIndex(table, sEffectName);
    }

    return index;
}  

int WeaponSpawn(const char[] className, const char[] weaponType = "none")
{
	// Try to find an available spot for the entity in the array list, if there is no space, delete entity & return -1
	int iArrPos = -1;
	for( int i = 0; i < MAX_WEAPONS; i++ )
	{
		if( g_iWeaponEnt[i] == 0 )
		{
			iArrPos = i;
			break;
		}
	}
	if( iArrPos == -1 )
		return -1;

	int iEntity = -1;
	iEntity = CreateEntityByName(className);
	if( iEntity != -1 )
	{
		DispatchKeyValue(iEntity, "spawnflags", "3");
		DispatchKeyValue(iEntity, "solid", "6");
		DispatchKeyValue(iEntity, "count", "1");
		DispatchKeyValue(iEntity, "spawn_without_director", "1");
		DispatchKeyValue(iEntity, "body", "0");
		if( StrEqual(className, "weapon_spawn", false) && !StrEqual(weaponType, "none", false) )
			DispatchKeyValue(iEntity, "weapon_selection", weaponType);
			
		else if( StrEqual(className, "weapon_melee_spawn") && !StrEqual(weaponType, "none", false) )
			DispatchKeyValue(iEntity, "melee_weapon", weaponType);
		
		g_iWeaponEnt[iArrPos] = EntIndexToEntRef(iEntity);
	}
	else
	{
		PrintToServer("[LB] Warning: Failed to spawn %s.", className);
		return -1;
	}
	
	float fTime;
	if( (fTime = g_hWeaponLock.FloatValue) > 0.0 )
		g_hWeaponUnlockTimer[iArrPos] = CreateTimer(fTime, WeaponUnlock_Timer, iArrPos);
		
	g_hWeaponDeleteTimer[iArrPos] = CreateTimer(g_hWeaponLife.FloatValue, WeaponDelete_Timer, iArrPos);
	RequestFrame(WeaponSpawn_Frame, iArrPos);
	SDKHook(iEntity, SDKHook_Use, Weapon_Used);
	return iEntity;
}


void DefaultPlayerSpeed(int client)
{
	SU_SetSpeed(client, SPEED_RUN, SU_GetSpeed(client, SPEED_RUN) / 1.2);
	SU_SetSpeed(client, SPEED_LIMP, SU_GetSpeed(client, SPEED_LIMP) / 1.2);
	SU_SetSpeed(client, SPEED_CRITICAL, SU_GetSpeed(client, SPEED_CRITICAL) / 1.2);
}

int SetPlayerParticle(int client, char[] particleName)
{
	int iEntity = -1;
	float vPos[3];
	GetClientAbsOrigin(client, vPos);
	iEntity = CreateEntityByName("info_particle_system");
	if( iEntity != -1 )
	{
		DispatchKeyValue(iEntity, "effect_name", particleName);
		DispatchSpawn(iEntity);
		TeleportEntity(iEntity, vPos, NULL_VECTOR, NULL_VECTOR);
		SetVariantString("!activator");
		AcceptEntityInput(iEntity, "SetParent", client, client);
		ActivateEntity(iEntity);
		AcceptEntityInput(iEntity, "Enable");
		AcceptEntityInput(iEntity, "Start");
		return EntIndexToEntRef(iEntity);
	}
	return INVALID_ENT_REFERENCE;
}

bool CheckPlayerBoost(int client, int boostType)
{
	bool result = false;
	int entity = EntRefToEntIndex(g_iPlayerParticle[client]);
	
	if( g_iPlayerBoosts[client] & PB_SPEED )
	{
		if( boostType & PB_SPEED )
			result = true;
		else
		{
			delete g_hPlayerSpeedTimer[client];
			g_iPlayerBoosts[client] &= ~PB_SPEED;
			DefaultPlayerSpeed(client);	
			if( entity != 0 && entity != INVALID_ENT_REFERENCE )
				RemoveEntity(entity);
		}
	}
	if( g_iPlayerBoosts[client] & PB_REGEN )
	{
		if( boostType & PB_REGEN )
			return true;
		else
		{
			delete g_hPlayerRegenTimer[client];
			g_iPlayerBoosts[client] &= ~PB_REGEN;
			StopSound(client, SNDCHAN_AUTO, SND_REGEN);
			if( entity != 0 && entity != INVALID_ENT_REFERENCE )
				RemoveEntity(entity);

		}
	}
	if( g_iPlayerBoosts[client] & PB_INVUL )
	{
		if( boostType & PB_INVUL )
			result = true;
		else
		{
			delete g_hPlayerInvulTimer[client];
			g_iPlayerBoosts[client] &= ~PB_INVUL;
			SDKUnhook(client, SDKHook_OnTakeDamage, Invulnerability_Callback);
		}
	}
	if( g_iPlayerBoosts[client] & PB_IAMMO )
	{
		if( boostType & PB_IAMMO )
			result = true;
		else
		{
			delete g_hPlayerAmmoTimer[client];
			g_iPlayerBoosts[client] &= ~PB_IAMMO;
		}
	}
	if( g_iPlayerBoosts[client] & PB_FIRE )
	{
		if( boostType & PB_FIRE )
			result = true;
		else
		{
			delete g_hPlayerFireTimer[client];
			StopSound(client, SNDCHAN_AUTO, SND_FIRE);
			g_iPlayerBoosts[client] &= ~PB_FIRE;
			if( entity != 0 && entity != INVALID_ENT_REFERENCE )
				RemoveEntity(entity);
		}
	}
	if( g_iPlayerBoosts[client] & PB_EXPL )
	{
		if( boostType & PB_EXPL )
			result = true;
		else
		{
			delete g_hPlayerExplTimer[client];
			g_iPlayerBoosts[client] &= ~PB_EXPL;
		}
	}
	return result;
}

void ResetClientData(int client)
{
	g_fPlayerUse[client] = 0.0;
	g_bPlayerAdvert[client] = false;
	delete g_hPlayerAmmoTimer[client];
	delete g_hPlayerFireTimer[client];
	delete g_hPlayerInvulTimer[client];
	delete g_hPlayerRegenTimer[client];
	delete g_hPlayerReverseTimer[client];
	delete g_hPlayerSpeedTimer[client];
	delete g_hPlayerFragileTimer[client];
	delete g_hPlayerAnglesTimer[client];
	CheckPlayerBoost(client, 0); // Calling without checking a concrete boost will disable everything
	if( g_iPlayerBoosts[client] & PN_FRAGILE )
		SDKUnhook(client, SDKHook_OnTakeDamage, Fragility_Callback);
			
	g_iPlayerBoosts[client] = PB_NONE;

	int entity = EntRefToEntIndex(g_iPlayerParticle[client]);
	if( entity != 0 && entity != INVALID_ENT_REFERENCE )
		RemoveEntity(entity);
}

/*============================================================================================
                                          Changelog
----------------------------------------------------------------------------------------------
* 1.1.1	(17-Jun-2022)
		- Fixed errors in message prints.
		- Fixed a bug in reverse controls where player couldn't use other buttons apart
		  of movement buttons.
* 1.1	(16-Jun-2022)
		- Merged Left 4 Dead and Left 4 Dead 2 plugin files.
		- Fixed error with Toxic Cloud that limited the amount of clouds per round to 8.
		- Fixed error where infinite ammo boost was not working properly.
        - Optimized client weapon check for infinte ammo boost.
		- Fixed warning messages for SM 1.11
		- Added new ConVar (l4d2_lootbox_fragility_multiplier).
		- Removed public function declarations where they were not required.
		- Weapon removal and validation is made through entity index instead of reference.
		
* 1.0	(14-Jun-2022)
		- Initial release.
============================================================================================*/