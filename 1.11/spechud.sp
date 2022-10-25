#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

#define PANELDISPLAYTIME 0.5
#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define GETLONGWEAPONNAME(%0) (IsValidWeaponId(%0) ? (LongWeaponNames[%0]) : "")
#define GETLONGMELEEWEAPONNAME(%0) (IsValidMeleeWeaponId(%0) ? (LongMeleeWeaponNames[%0]) : "")

// 特感类型
enum
{
    ZC_NONE = 0,
    ZC_SMOKER,
    ZC_BOOMER,
    ZC_HUNTER,
    ZC_SPITTER,
    ZC_JOCKEY,
    ZC_CHARGER,
    ZC_WITCH,
    ZC_TANK,
    ZC_NOTINFECTED,
	INFECTED_SIZE		// 10 size
};

enum
{
	WEPID_NONE,             // 0
	WEPID_PISTOL,           // 1
	WEPID_SMG,              // 2
	WEPID_PUMPSHOTGUN,      // 3
	WEPID_AUTOSHOTGUN,      // 4
	WEPID_RIFLE,            // 5
	WEPID_HUNTING_RIFLE,    // 6
	WEPID_SMG_SILENCED,     // 7
	WEPID_SHOTGUN_CHROME,   // 8
	WEPID_RIFLE_DESERT,     // 9
	WEPID_SNIPER_MILITARY,  // 10
	WEPID_SHOTGUN_SPAS,     // 11
	WEPID_FIRST_AID_KIT,    // 12
	WEPID_MOLOTOV,          // 13
	WEPID_PIPE_BOMB,        // 14
	WEPID_PAIN_PILLS,       // 15
	WEPID_GASCAN,           // 16
	WEPID_PROPANE_TANK,     // 17
	WEPID_OXYGEN_TANK,      // 18
	WEPID_MELEE,            // 19
	WEPID_CHAINSAW,         // 20
	WEPID_GRENADE_LAUNCHER, // 21
	WEPID_AMMO_PACK,        // 22
	WEPID_ADRENALINE,       // 23
	WEPID_DEFIBRILLATOR,    // 24
	WEPID_VOMITJAR,         // 25
	WEPID_RIFLE_AK47,       // 26
	WEPID_GNOME_CHOMPSKI,   // 27
	WEPID_COLA_BOTTLES,     // 28
	WEPID_FIREWORKS_BOX,    // 29
	WEPID_INCENDIARY_AMMO,  // 30
	WEPID_FRAG_AMMO,        // 31
	WEPID_PISTOL_MAGNUM,    // 32
	WEPID_SMG_MP5,          // 33
	WEPID_RIFLE_SG552,      // 34
	WEPID_SNIPER_AWP,       // 35
	WEPID_SNIPER_SCOUT,     // 36
	WEPID_RIFLE_M60,        // 37
	WEPID_TANK_CLAW,        // 38
	WEPID_HUNTER_CLAW,      // 39
	WEPID_CHARGER_CLAW,     // 40
	WEPID_BOOMER_CLAW,      // 41
	WEPID_SMOKER_CLAW,      // 42
	WEPID_SPITTER_CLAW,     // 43
	WEPID_JOCKEY_CLAW,      // 44
	WEPID_MACHINEGUN,       // 45
	WEPID_VOMIT,            // 46
	WEPID_SPLAT,            // 47
	WEPID_POUNCE,           // 48
	WEPID_LOUNGE,           // 49
	WEPID_PULL,             // 50
	WEPID_CHOKE,            // 51
	WEPID_ROCK,             // 52
	WEPID_PHYSICS,          // 53
	WEPID_AMMO,             // 54
	WEPID_UPGRADE_ITEM,     // 55
	WEPID_SIZE 				//56 size
};

enum
{
	WEPID_MELEE_NONE,
	WEPID_KNIFE,
	WEPID_BASEBALL_BAT,
	WEPID_MELEE_CHAINSAW,
	WEPID_CRICKET_BAT,
	WEPID_CROWBAR,
	WEPID_DIDGERIDOO,
	WEPID_ELECTRIC_GUITAR,
	WEPID_FIREAXE,
	WEPID_FRYING_PAN,
	WEPID_GOLF_CLUB,
	WEPID_KATANA,
	WEPID_MACHETE,
	WEPID_RIOT_SHIELD,
	WEPID_TONFA,
	WEPID_SHOVEL,
	WEPID_PITCHFORK,
	WEPID_MELEES_SIZE 		//15 size
};

static const char WeaponNames[WEPID_SIZE][] =
{
	"weapon_none", "weapon_pistol", "weapon_smg",                                            // 0
	"weapon_pumpshotgun", "weapon_autoshotgun", "weapon_rifle",                              // 3
	"weapon_hunting_rifle", "weapon_smg_silenced", "weapon_shotgun_chrome",                  // 6
	"weapon_rifle_desert", "weapon_sniper_military", "weapon_shotgun_spas",                  // 9
	"weapon_first_aid_kit", "weapon_molotov", "weapon_pipe_bomb",                            // 12
	"weapon_pain_pills", "weapon_gascan", "weapon_propanetank",                              // 15
	"weapon_oxygentank", "weapon_melee", "weapon_chainsaw",                                  // 18
	"weapon_grenade_launcher", "weapon_ammo_pack", "weapon_adrenaline",                      // 21
	"weapon_defibrillator", "weapon_vomitjar", "weapon_rifle_ak47",                          // 24
	"weapon_gnome", "weapon_cola_bottles", "weapon_fireworkcrate",                           // 27
	"weapon_upgradepack_incendiary", "weapon_upgradepack_explosive", "weapon_pistol_magnum", // 30
	"weapon_smg_mp5", "weapon_rifle_sg552", "weapon_sniper_awp",                             // 33
	"weapon_sniper_scout", "weapon_rifle_m60", "weapon_tank_claw",                           // 36
	"weapon_hunter_claw", "weapon_charger_claw", "weapon_boomer_claw",                       // 39
	"weapon_smoker_claw", "weapon_spitter_claw", "weapon_jockey_claw",                       // 42
	"weapon_machinegun", "vomit", "splat",                                                   // 45
	"pounce", "lounge", "pull",                                                              // 48
	"choke", "rock", "physics",                                                              // 51
	"ammo", "upgrade_item"                                                                   // 54
};

static const char MeleeWeaponNames[WEPID_MELEES_SIZE][] =
{
	"",
	"knife",
	"baseball_bat",
	"chainsaw",
	"cricket_bat",
	"crowbar",
	"didgeridoo",
	"electric_guitar",
	"fireaxe",
	"frying_pan",
	"golfclub",
	"katana",
	"machete",
	"riotshield",
	"tonfa",
	"shovel",
	"pitchfork"
};

static const char LongWeaponNames[WEPID_SIZE][] = 
{
	"无", "手枪", "Uzi", 										// 0
	"木喷", "一代连喷", "M-16", 								// 3
	"猎枪", "Mac", "铁喷", 										// 6
	"SCAR", "连狙", "二代连喷", 								// 9
	"急救包", "火瓶", "土制炸药", 								// 12
	"止痛药", "油桶", "煤气罐", 								// 15
	"氧气瓶", "近战", "电锯", 									// 18
	"榴弹", "弹药包", "肾上腺素",	 							// 21
	"电击器", "胆汁", "AK-47", 									// 24
	"侏儒玩偶", "可乐瓶", "烟花", 								// 27
	"燃烧弹药包", "高爆弹药包", "马格南", 						// 30
	"MP5", "SG552", "AWP", 										// 33
	"SCOUT", "M60", "Tank Claw", 								// 36
	"Hunter Claw", "Charger Claw", "Boomer Claw", 				// 39
	"Smoker Claw", "Spitter Claw", "Jockey Claw", 				// 42
	"Turret", "vomit", "splat", 								// 45
	"pounce", "lounge", "pull", 								// 48
	"choke", "rock", "physics", 								// 51
	"ammo", "upgrade_item" 										// 54
};

static const char LongMeleeWeaponNames[WEPID_MELEES_SIZE][] =
{
	"无",
	"小刀",
	"棒球棒",
	"电锯",
	"板球拍",
	"撬棍",
	"didgeridoo", // derp
	"吉他",
	"消防斧",
	"平底锅",
	"高尔夫球杆",
	"武士刀",
	"开山刀",
	"防爆盾",
	"警棍",
	"铲子",
	"草叉"
};

static const int WeaponSlots[WEPID_SIZE] =
{
	-1, // WEPID_NONE
	1,  // WEPID_PISTOL
	0,  // WEPID_SMG
	0,  // WEPID_PUMPSHOTGUN
	0,  // WEPID_AUTOSHOTGUN
	0,  // WEPID_RIFLE
	0,  // WEPID_HUNTING_RIFLE
	0,  // WEPID_SMG_SILENCED
	0,  // WEPID_SHOTGUN_CHROME
	0,  // WEPID_RIFLE_DESERT
	0,  // WEPID_SNIPER_MILITARY
	0,  // WEPID_SHOTGUN_SPAS
	3,  // WEPID_FIRST_AID_KIT
	2,  // WEPID_MOLOTOV
	2,  // WEPID_PIPE_BOMB
	4,  // WEPID_PAIN_PILLS
	-1, // WEPID_GASCAN
	-1, // WEPID_PROPANE_TANK
	-1, // WEPID_OXYGEN_TANK
	1,  // WEPID_MELEE
	1,  // WEPID_CHAINSAW
	0,  // WEPID_GRENADE_LAUNCHER
	3,  // WEPID_AMMO_PACK
	4,  // WEPID_ADRENALINE
	3,  // WEPID_DEFIBRILLATOR
	2,  // WEPID_VOMITJAR
	0,  // WEPID_RIFLE_AK47
	-1, // WEPID_GNOME_CHOMPSKI
	-1, // WEPID_COLA_BOTTLES
	-1, // WEPID_FIREWORKS_BOX
	3,  // WEPID_INCENDIARY_AMMO
	3,  // WEPID_FRAG_AMMO
	1,  // WEPID_PISTOL_MAGNUM
	0,  // WEPID_SMG_MP5
	0,  // WEPID_RIFLE_SG552
	0,  // WEPID_SNIPER_AWP
	0,  // WEPID_SNIPER_SCOUT
	0,  // WEPID_RIFLE_M60
	-1, // WEPID_TANK_CLAW
	-1, // WEPID_HUNTER_CLAW
	-1, // WEPID_CHARGER_CLAW
	-1, // WEPID_BOOMER_CLAW
	-1, // WEPID_SMOKER_CLAW
	-1, // WEPID_SPITTER_CLAW
	-1, // WEPID_JOCKEY_CLAW
	-1, // WEPID_MACHINEGUN
	-1, // WEPID_FATAL_VOMIT
	-1, // WEPID_EXPLODING_SPLAT
	-1, // WEPID_LUNGE_POUNCE
	-1, // WEPID_LOUNGE
	-1, // WEPID_FULLPULL
	-1, // WEPID_CHOKE
	-1, // WEPID_THROWING_ROCK
	-1, // WEPID_TURBO_PHYSICS
	-1, // WEPID_AMMO
	-1  // WEPID_UPGRADE_ITEM
};

static const char InfectedNames[INFECTED_SIZE][] =
{
	"Common",
	"Smoker",
	"Boomer",
	"Hunter",
	"Spitter",
	"Jockey",
	"Charger",
	"Witch",
	"Tank",
	"Survivor"
};

public Plugin myinfo = 
{
	name 			= "Spectator Professional HUD",
	author 			= "夜羽真白",
	description 	= "旁观者专业面板",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}
// 大部分代码来自 spechud.sp（Hyper-V HUD Manager）By：Visor, Forgetest，链接：https://github.com/Target5150/MoYu_Server_Stupid_Plugins

// ConVars
ConVar g_hHostName, g_hSurvivorLimit, g_hInfectedLimit, g_hVersusBossBuffer, g_hSpawnLimit, g_hSpawnTime;
// Ints
int maxplayers = 0, maxzombies = 0, spawnlimit, spawntime, roundcount = 1;
// Floats
float versusbossbuffer = 0.0;
// Bools
bool hiddenspechhud[MAXPLAYERS + 1] = false;
// Char
char hostname[64], currentmap[32], previousmap[32];
// StringMap
static StringMap hWeaponNamesTire = null, hMeleeWeaponNamesTrie = null;
// Handle
Handle hspechudtimer;

public void OnPluginStart()
{
	// Cvars
	g_hHostName = CreateConVar("spechud_hostname", "纯狱风", "显示给旁观面板的 hostname", FCVAR_NOTIFY);
	// OtherCvars
	g_hSurvivorLimit = FindConVar("survivor_limit");
	g_hInfectedLimit = FindConVar("z_max_player_zombies");
	g_hVersusBossBuffer = FindConVar("versus_boss_buffer");
	// InfectedControl
	g_hSpawnLimit = FindConVar("l4d_infected_limit");
	g_hSpawnTime = FindConVar("versus_special_respawn_interval");
	// Events
	HookEvent("tank_spawn", evt_TankSpawn);
	HookEvent("player_death", evt_PlayerDeath);
	HookEvent("round_end", evt_RoundEnd);
	// AddChangeHook
	g_hSurvivorLimit.AddChangeHook(GameCvarChanged);
	g_hInfectedLimit.AddChangeHook(GameCvarChanged);
	g_hVersusBossBuffer.AddChangeHook(GameCvarChanged);
	g_hSpawnLimit.AddChangeHook(GameCvarChanged);
	g_hSpawnTime.AddChangeHook(GameCvarChanged);
	g_hHostName.AddChangeHook(ServerCvarChanged);
	// Do
	GetConVarString(g_hHostName, hostname, sizeof(hostname));
	GetCvars();
	// Command
	RegConsoleCmd("sm_spechud", Cmd_SpecHud);
	// DrawHud
	hspechudtimer = CreateTimer(PANELDISPLAYTIME, DrawSpecHud, _, TIMER_REPEAT);
}

public void GameCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

public void ServerCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetConVarString(g_hHostName, hostname, sizeof(hostname));
}

void GetCvars()
{
	maxplayers = g_hSurvivorLimit.IntValue;
	maxzombies = g_hInfectedLimit.IntValue;
	versusbossbuffer = g_hVersusBossBuffer.FloatValue;
	spawnlimit = g_hSpawnLimit.IntValue;
	spawntime = g_hSpawnTime.IntValue;
}

public Action Cmd_SpecHud(int client, int args)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SPECTATOR)
	{
		if (!hiddenspechhud[client])
		{
			hiddenspechhud[client] = true;
			CPrintToChat(client, "{G}<specHUD>：{W}specHUD now is {LG}disabled\nType {O}!spechud {W}into chat to toggle the {LG}specHUD");
		}
		else if (!HasAnyTank())
		{
			hiddenspechhud[client] = false;
			CPrintToChat(client, "{G}<specHUD>：{W}specHUD now is {LG}enabled");
		}
	}
}

public Action DrawSpecHud(Handle timer)
{
	Panel spechud = new Panel();
	FillSlotsInfo(spechud);
	FillConfigInfo(spechud);
	FillSurvivorInfo(spechud);
	FillInfectedInfo(spechud);
	FillOtherInfo(spechud);
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SPECTATOR && !hiddenspechhud[client])
		{
			spechud.Send(client, PanelHandler, 3);
		}
	}
	delete spechud;
	return Plugin_Continue;
}

public int PanelHandler(Menu hMenu, MenuAction action, int param1, int param2)
{
	return 1;
}

// **************
//	    事件
// **************
public void OnMapStart()
{
	GetCurrentMap(currentmap, sizeof(currentmap));
	if (strcmp(currentmap, previousmap) != 0)
	{
		roundcount = 1;
	}
}

public void evt_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	GetCurrentMap(previousmap, sizeof(previousmap));
	roundcount++;
}

// 为不与 tankhud 冲突，坦克刷新时关闭 spechud，坦克死亡时重新绘制 spechud
public void evt_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (hspechudtimer != INVALID_HANDLE)
	{
		delete hspechudtimer;
		hspechudtimer = INVALID_HANDLE;
	}
}

public void evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED && GetInfectedClass(client) == ZC_TANK)
	{
		if (!FindNewTank(client))
		{
			hspechudtimer = CreateTimer(PANELDISPLAYTIME, DrawSpecHud, _, TIMER_REPEAT);
		}
	}
}

public void OnClientDisconnect(int client)
{
	hiddenspechhud[client] = false;
}

// **************
//	  面板绘制
// **************
void FillSlotsInfo(Panel &hudpanel)
{
	static int servertickrate = 0;
	if (servertickrate == 0 && IsServerProcessing())
	{
		servertickrate = RoundToNearest(1.0 / GetTickInterval());
	}
	static char info[64], time[64];
	DrawPanelText(hudpanel, "树树子 Server Spectator HUD");
	DrawPanelText(hudpanel, " \n");
	FormatEx(info, sizeof(info), "▶ 服务器：%s", hostname);
	DrawPanelText(hudpanel, info);
	FormatTime(time, sizeof(time), "%Y/%m/%d-%T %p");
	FormatEx(info, sizeof(info), "▶ 当前时间：%s", time);
	FormatEx(info, sizeof(info), "▶ 当前地图：%s", currentmap);
	DrawPanelText(hudpanel, info);
	FormatEx(info ,sizeof(info), "▶ 位置：%d/%d - %d Tickrate", GetHumanCount(), maxplayers, servertickrate);
	DrawPanelText(hudpanel, info);
}

void FillConfigInfo(Panel &hudpanel)
{
	static char info[64];
	DrawPanelText(hudpanel, " \n");
	FormatEx(info, sizeof(info), "▶ 当前特感配置：%d特%d秒", spawnlimit, spawntime);
	DrawPanelText(hudpanel, info);
}

void FillSurvivorInfo(Panel &hudpanel)
{
	static char info[128], name[MAX_NAME_LENGTH];
	DrawPanelText(hudpanel, " \n");
	FormatEx(info, sizeof(info), "▶ 生还者：%d 玩家 / %d AI", GetHumanSurvivorCount(), GetSurvivorCount() - GetHumanSurvivorCount());
	DrawPanelText(hudpanel, info);
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR)
		{
			GetClientFixedName(client, name, sizeof(name));
			if (!IsPlayerAlive(client))
			{
				FormatEx(info, sizeof(info), "%s（已死亡）", name);
			}
			else
			{
				if (IsHanging(client))
				{
					FormatEx(info, sizeof(info), "%s（%d HP | 挂边）", name, GetClientHealth(client));
				}
				else if (IsIncapped(client))
				{
					int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
					GetLongWeaponName(IdentifyWeapon(weapon), info, sizeof(info));
					Format(info, sizeof(info), "%s：倒地（已倒地%d次）%d HP - [武器：%s %d]", name, GetSurvivorIncapCount(client), GetClientHealth(client), info, GetWeaponClipAmmo(weapon));
				}
				else
				{
					GetWeaponInfo(client, info, sizeof(info));
					float temphealth = L4D_GetTempHealth(client);
					int health = GetClientHealth(client) + RoundToNearest(temphealth);
					int incapcount = GetSurvivorIncapCount(client);
					if (incapcount == 0)
					{
						Format(info, sizeof(info), "%s: %d HP%s - [武器：%s]", name, health, (temphealth > 0 ? "#" : ""), info);
					}
					else
					{
						Format(info, sizeof(info), "%s: %d HP (#已倒地%d次) - [武器：%s]", name, health, incapcount, info);
					}
				}
			}
			DrawPanelText(hudpanel, info);
		}
	}
}

void FillInfectedInfo(Panel &hudpanel)
{
	static char info[128], name[MAX_NAME_LENGTH];
	DrawPanelText(hudpanel, " \n");
	FormatEx(info, sizeof(info), "▶ 感染者：%d 在场 / %d 上限", GetInfectedCount(), maxzombies);
	DrawPanelText(hudpanel, info);
	for (int infected = 1; infected <= MaxClients; infected++)
	{
		if (IsClientConnected(infected) && IsClientInGame(infected) && GetClientTeam(infected) == TEAM_INFECTED)
		{
			GetClientFixedName(infected, name, sizeof(name));
			int zombieclass = GetInfectedClass(infected);
			if (zombieclass != ZC_TANK)
			{
				char zombieclassname[16];
				GetInfectedClassName(zombieclass, zombieclassname, sizeof(zombieclassname));
				int health = GetClientHealth(infected);
				int maxhealth = GetEntProp(infected, Prop_Send, "m_iMaxHealth");
				if (GetEntityFlags(infected) & FL_ONFIRE)
				{
					Format(info, sizeof(info), "%s（%d/%d HP）正在燃烧", name, health, maxhealth);
				}
				else
				{
					Format(info, sizeof(info), "%s（%d/%d HP）未被燃烧", name, health, maxhealth);
				}
			}
			DrawPanelText(hudpanel, info);
		}
	}
	int infectedcount = GetInfectedCount();
	if (infectedcount == 0)
	{
		DrawPanelText(hudpanel, "当前无在场特殊感染者");
	}
}

void FillOtherInfo(Panel &hudpanel)
{
	static char info[64];
	int survivorflow = GetHighestSurvivorFlow();
	DrawPanelText(hudpanel, " \n");
	FormatEx(info, sizeof(info), "▶ 回合：%d \n▶ 当前：%d%%", roundcount, survivorflow);
	DrawPanelText(hudpanel, info);
}

// **************
//	  其他方法
// **************
int GetSurvivorCount()
{
	int survivor = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR)
		{
			survivor++;
		}
	}
	return survivor;
}

int GetHumanCount()
{
	int human = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && !IsFakeClient(client))
		{
			human++;
		}
	}
	return human;
}

int GetHumanSurvivorCount()
{
	int survivor = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR)
		{
			survivor++;
		}
	}
	return survivor;
}

int GetInfectedCount()
{
	int infected = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED && GetInfectedClass(client) != ZC_TANK)
		{
			infected++;
		}
	}
	return infected;
}

bool IsIncapped(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

int GetSurvivorIncapCount(int client)
{
	return GetEntProp(client, Prop_Send, "m_currentReviveCount");
}

int GetWeaponClipAmmo(int weapon)
{
	return (weapon > 0 ? GetEntProp(weapon, Prop_Send, "m_iClip1") : -1);
}

#define	ASSAULT_RIFLE_OFFSET_IAMMO		12;
#define	SMG_OFFSET_IAMMO				20;
#define	PUMPSHOTGUN_OFFSET_IAMMO		28;
#define	AUTO_SHOTGUN_OFFSET_IAMMO		32;
#define	HUNTING_RIFLE_OFFSET_IAMMO		36;
#define	MILITARY_SNIPER_OFFSET_IAMMO	40;
#define	GRENADE_LAUNCHER_OFFSET_IAMMO	68;
int GetWeaponExtraAmmo(int client, int weaponid)
{
	static int ammooffset;
	if (!ammooffset)
	{
		ammooffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");
	}
	int offset;
	switch (weaponid)
	{
		case WEPID_RIFLE, WEPID_RIFLE_AK47, WEPID_RIFLE_DESERT, WEPID_RIFLE_SG552:
		{
			offset = ASSAULT_RIFLE_OFFSET_IAMMO
		}
		case WEPID_SMG, WEPID_SMG_SILENCED:
		{
			offset = SMG_OFFSET_IAMMO
		}
		case WEPID_PUMPSHOTGUN, WEPID_SHOTGUN_CHROME:
		{
			offset = PUMPSHOTGUN_OFFSET_IAMMO
		}
		case WEPID_AUTOSHOTGUN, WEPID_SHOTGUN_SPAS:
		{
			offset = AUTO_SHOTGUN_OFFSET_IAMMO
		}
		case WEPID_HUNTING_RIFLE:
		{
			offset = HUNTING_RIFLE_OFFSET_IAMMO
		}
		case WEPID_SNIPER_MILITARY, WEPID_SNIPER_AWP, WEPID_SNIPER_SCOUT:
		{
			offset = MILITARY_SNIPER_OFFSET_IAMMO
		}
		case WEPID_GRENADE_LAUNCHER:
		{
			offset = GRENADE_LAUNCHER_OFFSET_IAMMO
		}
		default:
		{
			return -1;
		}
	}
	return GetEntData(client, ammooffset + offset);
}

int GetSlotFromWeaponId(int weaponid)
{
	return (IsValidWeaponId(weaponid)) ? WeaponSlots[weaponid] : -1;
}

int GetInfectedClass(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

void GetInfectedClassName(int class, char[] buffer, const int length)
{
	strcopy(buffer, length, InfectedNames[class]);
}

bool IsHanging(int client)
{
	return (view_as<bool>(GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1)) || view_as<bool>(GetEntProp(client, Prop_Send, "m_isFallingFromLedge", 1)));
}

int GetHighestSurvivorFlow()
{
	int flow = -1;
	int client = L4D_GetHighestFlowSurvivor();
	if (client > 0)
	{
		flow = RoundToNearest(100.0 * (L4D2Direct_GetFlowDistance(client) + versusbossbuffer) / L4D2Direct_GetMapMaxFlowDistance());
	}
	return flow < 100 ? flow : 100;
}

void GetClientFixedName(int client, char[] name, int len)
{
	GetClientName(client, name, len);
	if (name[0] == '[')
	{
		char temp[MAX_NAME_LENGTH];
		strcopy(temp, sizeof(temp), name);
		temp[sizeof(temp) - 2] = 0;
		strcopy(name[1], len - 1, temp);
		name[0] = ' ';
	}
	if (strlen(name) > 18)
	{
		name[15] = name[16] = name[17] = '.';
		name[18] = 0;
	}
}

void GetWeaponInfo(int client, char[] info, int length)
{
	static char buffer[32];
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	int primaryweapon = GetPlayerWeaponSlot(client, 0);
	int weaponid = IdentifyWeapon(weapon);
	int primaryweaponid = IdentifyWeapon(primaryweapon);
	switch (weaponid)
	{
		// 玩家手持手枪的情况
		case WEPID_PISTOL, WEPID_PISTOL_MAGNUM:
		{
			if (weaponid == WEPID_PISTOL && GetEntProp(weapon, Prop_Send, "m_isDualWielding"))
			{
				FormatEx(buffer, sizeof(buffer), "DualPistol");
			}
			else
			{
				GetLongWeaponName(weaponid, buffer, sizeof(buffer));
			}
			FormatEx(info, length, "%s %d", buffer, GetWeaponClipAmmo(weapon));
		}
		// 其他情况
		default:
		{
			GetLongWeaponName(primaryweaponid, buffer, sizeof(buffer));
			FormatEx(info, length, "%s %d/%d", buffer, GetWeaponClipAmmo(primaryweapon), GetWeaponExtraAmmo(client, primaryweaponid));
		}
	}
	// 主武器索引无效，判断是否为近战武器
	if (primaryweapon == -1)
	{
		if (weaponid == WEPID_MELEE || WEPID_CHAINSAW)
		{
			int meleeweaponid = IdentifyMeleeWeapon(weaponid);
			GetLongMeleeWeaponName(meleeweaponid, info, length);
		}
	}
	else
	{
		if (GetSlotFromWeaponId(weaponid) != 1 || weaponid == WEPID_MELEE || weaponid == WEPID_CHAINSAW)
		{
			GetMeleePrefix(client, buffer, sizeof(buffer));
			FormatEx(info, length, "%s | %s", info, buffer);
		}
		else
		{
			GetLongWeaponName(primaryweaponid, buffer, sizeof(buffer));
			FormatEx(info, length, "%s | %s/%d", info, buffer, GetWeaponClipAmmo(primaryweapon) + GetWeaponExtraAmmo(client, primaryweaponid));
		}
	}
}

void GetMeleePrefix(int client, char[] prefix, int length)
{
	int melee = GetPlayerWeaponSlot(client, 1);
	int meleeweapon = IdentifyWeapon(melee);
	static char buffer[16];
	switch (meleeweapon)
	{
		case WEPID_NONE:
		{
			buffer = "无";
		}
		case WEPID_PISTOL:
		{
			buffer = (GetEntProp(melee, Prop_Send, "m_isDualWielding") ? "双手枪" : "单手枪");
		}
		case WEPID_PISTOL_MAGNUM:
		{
			buffer = "马格南";
		}
		case WEPID_MELEE:
		{
			buffer = "近战";
		}
		default:
		{
			buffer = "未知";
		}
	}
	strcopy(prefix, length, buffer);
}

public void InitWeaponNamesTrie()
{
	hWeaponNamesTire = new StringMap();
	for (int i = 0; i < WEPID_SIZE; i++)
	{
		hWeaponNamesTire.SetValue(WeaponNames[i], i);
	}
	hMeleeWeaponNamesTrie = new StringMap();
	for (int i = 0; i < WEPID_MELEES_SIZE; i++)
	{
		hMeleeWeaponNamesTrie.SetValue(MeleeWeaponNames[i], i);
	}
}

public int IdentifyWeapon(int entity)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		char classname[64];
		if (GetEdictClassname(entity, classname, sizeof(classname)))
		{
			if (strcmp(classname, "weapon_spawn") == 0)
			{
				return GetEntProp(entity, Prop_Send, "m_weaponID");
			}
			int len = strlen(classname);
			int sublen = len - 6;
			if (sublen > 0 && strcmp(classname[sublen], "_spawn") == 0)
			{
				classname[sublen] = '\0';
				return WeaponNameToId(classname);
			}
			return WeaponNameToId(classname);
		}
		else
		{
			return WEPID_NONE;
		}
	}
	else
	{
		return WEPID_NONE;
	}
}

public int IdentifyMeleeWeapon(int entity)
{
	if (IdentifyWeapon(entity) == WEPID_MELEE)
	{
		char name[64];
		if (GetMeleeWeaponNameFromEntity(entity, name, sizeof(name)))
		{
			if (hMeleeWeaponNamesTrie == null)
			{
				InitWeaponNamesTrie();
			}
			int meleeid;
			if (hMeleeWeaponNamesTrie.GetValue(name, meleeid))
			{
				return meleeid;
			}
			return WEPID_MELEE_NONE;
		}
		else
		{
			return WEPID_MELEE_NONE;
		}
	}
	else
	{
		return WEPID_MELEE_NONE;
	}
}

bool GetMeleeWeaponNameFromEntity(int entity, char[] buffer, const int length)
{
	char classname[64];
	if (GetEdictClassname(entity, classname, sizeof(classname)))
	{
		if (strcmp(classname, "weapon_melee_spawn"))
		{
			if (hMeleeWeaponNamesTrie == null)
			{
				InitWeaponNamesTrie();
			}
			char modelname[PLATFORM_MAX_PATH];
			GetEntPropString(entity, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
			if (strncmp(modelname, "models/", 7, false) == 0)
			{
				strcopy(modelname, sizeof(modelname), modelname[6]);
			}
			if (hMeleeWeaponNamesTrie.GetString(modelname, buffer, length))
			{
				return true;
			}
			return false;
		}
		else if (strcmp(classname, "weapon_melee"))
		{
			GetEntPropString(entity, Prop_Data, "m_strMapSetScriptName", buffer, length);
			return true;
		}
	}
	return false;
}

public int WeaponNameToId(const char[] WeaponName)
{
	if (hWeaponNamesTire == null)
	{
		InitWeaponNamesTrie();
	}
	int weaponid;
	if (hWeaponNamesTire.GetValue(WeaponName, weaponid))
	{
		return weaponid;
	}
	return WEPID_NONE;
}

void GetLongWeaponName(int weaponid, char[] buffer, const int length)
{
	strcopy(buffer, length, GETLONGWEAPONNAME(weaponid));
}

void GetLongMeleeWeaponName(int weaponid, char[] buffer, const int length)
{
	strcopy(buffer, length, GETLONGMELEEWEAPONNAME(weaponid));
}

bool IsValidWeaponId(int weaponid)
{
	return view_as<bool>(weaponid >= WEPID_NONE && weaponid < WEPID_SIZE);
}

bool IsValidMeleeWeaponId(int weaponid)
{
	return (weaponid >= WEPID_MELEE_NONE && weaponid < WEPID_MELEES_SIZE);
}

bool HasAnyTank()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && GetInfectedClass(client) == ZC_TANK)
		{
			return true;
		}
	}
	return false;
}

bool FindNewTank(int oldtankclient)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (client != oldtankclient && IsClientInGame(client) && GetClientTeam(client) == 3 && GetInfectedClass(client) == ZC_TANK)
		{
			return true;
		}
	}
	return false;
}