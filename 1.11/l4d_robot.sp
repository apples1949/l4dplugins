#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

#define PLUGIN_NAME "[L4D1/2] Robot Guns"
#define PLUGIN_AUTHOR "Pan Xiaohai, Shadowysn (edit)"
#define PLUGIN_DESC "Use automatic robot guns to passively attack."
#define PLUGIN_VERSION "1.5b"
#define PLUGIN_URL "https://forums.alliedmods.net/showthread.php?t=130177"
#define PLUGIN_NAME_SHORT "Robot Guns"
#define PLUGIN_NAME_TECH "l4d_robot"

#define SOUNDCLIPEMPTY		   "weapons/ClipEmpty_Rifle.wav" 
#define SOUNDRELOAD			  "weapons/shotgun/gunother/shotgun_load_shell_2.wav" 
#define SOUNDREADY			 "weapons/shotgun/gunother/shotgun_pump_1.wav"

#define ORIGINAL_PAN 0

#define WEAPONCOUNT 18

#define SOUND0 "weapons/hunting_rifle/gunfire/hunting_rifle_fire_1.wav" 
#define SOUND1 "weapons/rifle/gunfire/rifle_fire_1.wav" 
#define SOUND2 "weapons/auto_shotgun/gunfire/auto_shotgun_fire_1.wav" 
#define SOUND3 "weapons/shotgun/gunfire/shotgun_fire_1.wav" 
#define SOUND4 "weapons/SMG/gunfire/smg_fire_1.wav" 
#define SOUND5 "weapons/pistol/gunfire/pistol_fire.wav" 
#define SOUND6 "weapons/magnum/gunfire/magnum_shoot.wav" 
#define SOUND7 "weapons/rifle_ak47/gunfire/rifle_fire_1.wav" 
#define SOUND8 "weapons/rifle_desert/gunfire/rifle_fire_1.wav" 
#define SOUND9 "weapons/sg552/gunfire/sg552-1.wav"
#define SOUND10 "weapons/machinegun_m60/gunfire/machinegun_fire_1.wav"
#define SOUND11 "weapons/shotgun_chrome/gunfire/shotgun_fire_1.wav"
#define SOUND12 "weapons/auto_shotgun_spas/gunfire/shotgun_fire_1.wav"
#define SOUND13 "weapons/sniper_military/gunfire/sniper_military_fire_1.wav"
#define SOUND14 "weapons/scout/gunfire/scout_fire-1.wav"
#define SOUND15 "weapons/awp/gunfire/awp1.wav"
#define SOUND16 "weapons/mp5navy/gunfire/mp5-1.wav"
#define SOUND17 "weapons/smg_silenced/gunfire/smg_fire_1.wav"

#define MODEL0 "weapon_hunting_rifle"
#define MODEL1 "weapon_rifle"
#define MODEL2 "weapon_autoshotgun"
#define MODEL3 "weapon_pumpshotgun"
#define MODEL4 "weapon_smg"
#define MODEL5 "weapon_pistol"
#define MODEL6 "weapon_pistol_magnum"
#define MODEL7 "weapon_rifle_ak47"
#define MODEL8 "weapon_rifle_desert"
#define MODEL9 "weapon_rifle_sg552"
#define MODEL10 "weapon_rifle_m60"
#define MODEL11 "weapon_shotgun_chrome"
#define MODEL12 "weapon_shotgun_spas"
#define MODEL13 "weapon_sniper_military"
#define MODEL14 "weapon_sniper_scout"
#define MODEL15 "weapon_sniper_awp"
#define MODEL16 "weapon_smg_mp5"
#define MODEL17 "weapon_smg_silenced"

//int g_PointHurt = 0;
static char SOUND[WEAPONCOUNT+3][70]=
{												SOUND0,	SOUND1,	SOUND2,	SOUND3,	SOUND4,	SOUND5,	SOUND6,	SOUND7,	SOUND8,	SOUND9,	SOUND10,SOUND11,SOUND12,SOUND13,SOUND14,SOUND15,SOUND16,SOUND17,SOUNDCLIPEMPTY,	SOUNDRELOAD,	SOUNDREADY};

static char MODEL[WEAPONCOUNT][32]=
{												MODEL0,	MODEL1,	MODEL2,	MODEL3,	MODEL4,	MODEL5,	MODEL6,	MODEL7,	MODEL8,	MODEL9,	MODEL10,MODEL11,MODEL12,MODEL13,MODEL14,MODEL15,MODEL16,MODEL17};

static char weaponbulletdamagestr[WEAPONCOUNT][10]={"", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""};

//weapon data
static float fireinterval[WEAPONCOUNT] =		{0.25,	0.068,	0.30,	0.65,	0.060,	0.20,	0.33,	0.145,	0.14,	0.14,	0.068,	0.65,	0.30,	0.265,	0.9,	1.25,	0.065,	0.055	};

static float bulletaccuracy[WEAPONCOUNT] =		{1.15,	1.4,	3.5,	3.5,	1.6,	1.7,	1.7,	1.5,	1.6,	1.5,	1.5,	3.5,	3.5,	1.15,	1.00,	0.8,	1.6,	1.6		};

static float weaponbulletdamage[WEAPONCOUNT] =	{90.0,	30.0,	25.0,	30.0,	20.0,	30.0,	60.0,	70.0,	40.0,	40.0,	50.0,	30.0,	30.0,	90.0,	100.0,	150.0,	35.0,	35.0	};

static int weaponclipsize[WEAPONCOUNT] =		{15,	50,		10,		8,		50,		30,		8,		40,		20,		50,		150,	8,		10,		30,		15,		20,		50,		50		};

static int weaponbulletpershot[WEAPONCOUNT] =	{1,		1,		7,		7,		1,		1,		1,		1,		1,		1,		1,		7,		7,		1,		1,		1,		1,		1		};

static float weaponloadtime[WEAPONCOUNT] =		{2.0,	1.5,	0.3,	0.3,	1.5,	1.5,	1.9,	1.5,	1.5,	1.6,	0.0,	0.3,	0.3,	2.0,	2.0,	2.0,	1.5,	1.5		};

static int weaponloadcount[WEAPONCOUNT] =		{15,	50,		1,		1,		50,		30,		8,		40,		60,		50,		1,		1,		1,		30,		15,		20,		50,		50		};

static bool weaponloaddisrupt[WEAPONCOUNT] =	{false,	false,	true,	true,	false,	false,	false,	false,	false,	true,	true,	true,	false,	false,	false,	false,	false,	false	};
//weapon data

static int robot[MAXPLAYERS+1];
static int keybuffer[MAXPLAYERS+1];
static int weapontype[MAXPLAYERS+1];
static int bullet[MAXPLAYERS+1];
static float firetime[MAXPLAYERS+1];
static bool reloading[MAXPLAYERS+1];
static float reloadtime[MAXPLAYERS+1];
static float scantime[MAXPLAYERS+1];
static float walktime[MAXPLAYERS+1];
static float botenergy[MAXPLAYERS+1];

static int SIenemy[MAXPLAYERS+1];
static int CIenemy[MAXPLAYERS+1];
//static float CIenemyTime[MAXPLAYERS+1];

static float robotangle[MAXPLAYERS+1][3];

ConVar l4d_robot_limit;
ConVar l4d_robot_reactiontime;
ConVar l4d_robot_scanrange; 
ConVar l4d_robot_energy; 
ConVar l4d_robot_damagefactor; 
// New
ConVar l4d_robot_messages;
ConVar l4d_robot_glow; 

#define BITFLAG_MESSAGE_INFO (1 << 0)
#define BITFLAG_MESSAGE_STEAL (1 << 1)

static float robot_reactiontime;
static float robot_scanrange; 
static float robot_energy;
static float robot_damagefactor;
static int robot_messages;
static char robot_glow[12];

static int g_sprite;
 
static bool L4D2Version = false;
static int GameMode=0;

static bool gamestart = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() == Engine_Left4Dead2)
	{
		L4D2Version = true;
		return APLRes_Success;
	}
	else if (GetEngineVersion() == Engine_Left4Dead)
	{
		return APLRes_Success;
	}
	strcopy(error, err_max, "Plugin only supports Left 4 Dead and Left 4 Dead 2.");
	return APLRes_SilentFailure;
}

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESC,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

public void OnPluginStart()
{
	static char temp_str[32];
	
	Format(temp_str, sizeof(temp_str), "%s_limit", PLUGIN_NAME_TECH);
 	l4d_robot_limit = CreateConVar(temp_str, "12", "机器人数量[0-3]", FCVAR_NONE);
	
	Format(temp_str, sizeof(temp_str), "%s_reactiontime", PLUGIN_NAME_TECH);
	l4d_robot_reactiontime = CreateConVar(temp_str, "0.5", "机器人反应时间[0.5,5.0]", FCVAR_NONE);
	
	Format(temp_str, sizeof(temp_str), "%s_scanrange", PLUGIN_NAME_TECH);
	l4d_robot_scanrange = CreateConVar(temp_str, "1000.0", "扫描敌人的射程[100.0,10000.0]", FCVAR_NONE);
 	
	Format(temp_str, sizeof(temp_str), "%s_energy", PLUGIN_NAME_TECH);
	l4d_robot_energy = CreateConVar(temp_str, "10.0", "机器人对玩家的时间限制（分钟）[0.01.100.0]", FCVAR_NONE);
	
	Format(temp_str, sizeof(temp_str), "%s_damagefactor", PLUGIN_NAME_TECH);
	l4d_robot_damagefactor = CreateConVar(temp_str, "0.5", "伤害[0.2,1.0]", FCVAR_NONE);
	
	Format(temp_str, sizeof(temp_str), "%s_messages", PLUGIN_NAME_TECH);
	l4d_robot_messages = CreateConVar(temp_str, "3", "要启用哪些消息，如位标志[1=信息，2=窃取（未使用）]", FCVAR_NONE);

	Format(temp_str, sizeof(temp_str), "%s_glow", PLUGIN_NAME_TECH);
	l4d_robot_glow = CreateConVar(temp_str, "144 238 144", "用于机器人的发光颜色[R、G、B]", FCVAR_NONE);

	AutoExecConfig(true, "l4d_robot_12");
	HookConVarChange(l4d_robot_reactiontime, ConVarChange);
	HookConVarChange(l4d_robot_scanrange, ConVarChange); 
	HookConVarChange(l4d_robot_energy, ConVarChange);
	HookConVarChange(l4d_robot_damagefactor, ConVarChange);
	HookConVarChange(l4d_robot_messages, ConVarChange);
	HookConVarChange(l4d_robot_glow, ConVarChange);
	GetConVar();

	static char GameName[13];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	
	if (strncmp(GameName, "survival", 8, false) == 0)
		GameMode = 3;
	else if (strncmp(GameName, "versus", 6, false) == 0 || strncmp(GameName, "teamversus", 10, false) == 0 || strncmp(GameName, "scavenge", 8, false) == 0 || strcmp(GameName, "teamscavenge", false) == 0)
		GameMode = 2;
	else if (strncmp(GameName, "coop", 4, false) == 0 || strncmp(GameName, "realism", 7, false) == 0)
		GameMode = 1;
	else
		GameMode = 0;
 
 	RegConsoleCmd("sm_robot", sm_robot);
	//HookEvent("player_use", player_use, EventHookMode_Post);
	HookEvent("round_start", RoundStart, EventHookMode_Post);
	//HookEvent("map_transition", map_transition, EventHookMode_PostNoCopy);
	
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	
	HookEvent("round_end", RoundEnd, EventHookMode_Post);
	HookEvent("finale_win", RoundEnd, EventHookMode_Post);
	HookEvent("mission_lost", RoundEnd, EventHookMode_Post);
	HookEvent("map_transition", RoundEnd, EventHookMode_Post);
	HookEvent("player_spawn", Event_Spawn, EventHookMode_Post);	 
 	gamestart = false;
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (RealValidEntity(robot[i]))
		{
			Release(i);	 
 		}
	}
}

void GetConVar()
{
	robot_reactiontime = GetConVarFloat(l4d_robot_reactiontime );
	robot_scanrange = GetConVarFloat(l4d_robot_scanrange );
 	robot_energy = GetConVarFloat(l4d_robot_energy ) * 60.0;
 	robot_damagefactor = GetConVarFloat(l4d_robot_damagefactor);
	robot_messages = GetConVarInt(l4d_robot_messages);
	GetConVarString(l4d_robot_glow, robot_glow, sizeof(robot_glow));
	static char str[10];
	for (int i = 0; i < WEAPONCOUNT; i++)
	{
		Format(str, sizeof(str), "%d", RoundFloat(weaponbulletdamage[i] * robot_damagefactor));
		weaponbulletdamagestr[i] = str;
	}
}
void ConVarChange(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetConVar();
}

public void OnMapStart()
{
	PrecacheModel(MODEL[0], true);
	PrecacheModel(MODEL[1], true);
	PrecacheModel(MODEL[2], true);
	PrecacheModel(MODEL[3], true);
	PrecacheModel(MODEL[4], true);
	PrecacheModel(MODEL[5], true);

	PrecacheSound(SOUND[0], true);
	PrecacheSound(SOUND[1], true);
	PrecacheSound(SOUND[2], true);
	PrecacheSound(SOUND[3], true);
	PrecacheSound(SOUND[4], true);
	PrecacheSound(SOUND[5], true);
	
	PrecacheSound(SOUNDCLIPEMPTY, true);
	PrecacheSound(SOUNDRELOAD, true);
	PrecacheSound(SOUNDREADY, true);
	
	if (L4D2Version)
	{
		g_sprite = PrecacheModel("materials/sprites/laserbeam.vmt");	
		
		for (int i = 6; i < WEAPONCOUNT; i++)
		{
			PrecacheModel( MODEL[i] , true );
			PrecacheSound(SOUND[i], true) ;
		}
	}
	else
	{
		g_sprite = PrecacheModel("materials/sprites/laser.vmt");	
 
	}
	gamestart = false;
}

void RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (RealValidEntity(robot[i]))
		{
			Release(i, false);	 
 		}
		botenergy[i] = 0.0;
	}
	//g_PointHurt = 0;
}

void RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (RealValidEntity(robot[i]))
		{
			Release(i);	 
 		}
	}
	gamestart = false;
}
/*void player_use(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int entity = GetEventInt(event, "targetid");
	for (int i = 1; i <= MaxClients; i++)
	{
		if (RealValidEntity(robot[i]) && robot[i] == entity)
		{
			//RemovePlayerItem(client, entity);
			if (client == i && (robot_messages & BITFLAG_MESSAGE_INFO))
			{
				PrintHintText(client, "按下SHIFT+E关闭机器人", client);
			}
			else
			{
				if (robot_messages & BITFLAG_MESSAGE_STEAL)
				{
					PrintHintText(i, "%N 拿走了你的机器人);
					PrintHintText(client, "你试图拿走 %N 的机器人", i);
				}
				if (RealValidEntity(GetEntPropEnt(robot[i], Prop_Data, "m_hOwnerEntity")))
				{
					Release(i);	
					AddRobot(i);
				}
			}
 		}
		else if (robot[i] > 0)
		{
			Release(i);	
			AddRobot(i);
		}
	}
}*/
/*void Output_OnUse(const char[] output, int entity, int client, float delay)
{
	
}*/
void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	robot[client] = 0;
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!gamestart) return;
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidClient(attacker))
	{	
		if (attacker != victim && GetClientTeam(attacker) == 3)
		{
			scantime[victim] = GetEngineTime();
			SIenemy[victim] = attacker;
		}
	}
	else
	{
		int ent = GetEventInt(event, "attackerentid");	
		CIenemy[victim] = ent;
	}
}
void DelRobot(int ent)
{
	if (!RealValidEntity(ent)) return;
	
	/*static char item[7];
	GetEntityClassname(ent, item, sizeof(item));
	if (strcmp(item, "weapon") == 0)
	{*/
	AcceptEntityInput(ent, "Kill");
	//}
}

void Release(int controller, bool del = true)
{
	int r = robot[controller];
	if (RealValidEntity(r))
	{
		robot[controller] = 0;
	 
		if (del) DelRobot(r);
	}
	if (gamestart)
	{
		int count = 0;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (RealValidEntity(robot[i]))
			{
				count++; 
			}
		}
		if (count == 0) gamestart = false;
	}
}

Action sm_robot(int client, int args)
{  
	if (GameMode == 2) return Plugin_Handled;
	if (!IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Handled;
	if (RealValidEntity(robot[client]))
	{
		PrintToChat(client, "你已经有了一个机器人！按SHIFT+E以删除旧的机器人");
		return Plugin_Handled;
	}
	
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (RealValidEntity(robot[i]))
		{
			count++; 
 		}
	}
	
	if (count + 1 > GetConVarInt(l4d_robot_limit))
	{
		PrintToChat(client, "No more robots to use!");
		return Plugin_Handled;
	}

	if (args >= 1)
	{
		static char arg[24];
		GetCmdArg(1, arg, sizeof(arg));
		if (strncmp(arg, "hunting", 7, false) == 0) weapontype[client]=0;
		else if (strncmp(arg, "rifle", 5, false) == 0) weapontype[client]=1;
		else if (strncmp(arg, "auto", 4, false) == 0) weapontype[client]=2;
		else if (strncmp(arg, "pump", 4, false) == 0) weapontype[client]=3;
		else if (strncmp(arg, "smg", 3, false) == 0) weapontype[client]=4;
		else if (strncmp(arg, "pistol", 6, false) == 0) weapontype[client]=5;
		else if (strncmp(arg, "magnum", 6, false) == 0 && L4D2Version) weapontype[client]=6;
		else if (strncmp(arg, "ak47", 4, false) == 0 && L4D2Version) weapontype[client]=7;
		else if (strncmp(arg, "desert", 6, false) == 0 && L4D2Version) weapontype[client]=8;
		else if (strncmp(arg, "sg552", 5, false) == 0 && L4D2Version) weapontype[client]=9;
		else if (strncmp(arg, "m60", 3, false) == 0 && L4D2Version) weapontype[client]=10;
		else if (strncmp(arg, "chrome", 6, false) == 0 && L4D2Version) weapontype[client]=11;
		else if (strncmp(arg, "spas", 4, false) == 0 && L4D2Version) weapontype[client]=12;
		else if (strncmp(arg, "military", 8, false) == 0 && L4D2Version) weapontype[client]=13;
		else if (strncmp(arg, "scout", 5, false) == 0 && L4D2Version) weapontype[client]=14;
		else if (strncmp(arg, "awp", 3, false) == 0 && L4D2Version) weapontype[client]=15;
		else if (strncmp(arg, "mp5", 3, false) == 0 && L4D2Version) weapontype[client]=16;
		else if (strncmp(arg, "silenced", 8, false) == 0 && L4D2Version) weapontype[client]=17;
		else
		{
			if (L4D2Version)
			{ weapontype[client] = GetRandomInt(0, WEAPONCOUNT-1); }
			else
			{ weapontype[client] = GetRandomInt(0, 5); }
		}
	}	
	else
	{
		if (L4D2Version)
		{ weapontype[client] = GetRandomInt(0, WEAPONCOUNT-1); }
		else
		{ weapontype[client] = GetRandomInt(0, 5); }
	}
	AddRobot(client, true);
	return Plugin_Handled;
} 
void AddRobot(int client, bool showmsg = false)
{
	bullet[client] = weaponclipsize[weapontype[client]];
	float vAngles[3], vOrigin[3], pos[3];

	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);

	TR_TraceRayFilter(vOrigin, vAngles, MASK_SOLID,  RayType_Infinite, TraceEntityFilterPlayer);

	if (TR_DidHit())
	{
		TR_GetEndPosition(pos);
	}

	float v1[3], v2[3];
	 
	SubtractVectors(vOrigin, pos, v1);
	NormalizeVector(v1, v2);

	ScaleVector(v2, 50.0);

	AddVectors(pos, v2, v1);  // v1 explode taget
	
	int temp_ent = CreateEntityByName(MODEL[weapontype[client]]);
	if (!RealValidEntity(temp_ent)) return;
	DispatchSpawn(temp_ent);
	static char temp_str[128];
	GetEntPropString(temp_ent, Prop_Data, "m_ModelName", temp_str, sizeof(temp_str));
	AcceptEntityInput(temp_ent, "Kill");
	
	int ent = CreateEntityByName("prop_dynamic_override");
	//int ent = CreateEntityByName("prop_physics_override");
	//DispatchKeyValue(ent, "spawnflags", "4");
	DispatchKeyValue(ent, "solid", "6");
	DispatchKeyValue(ent, "model", temp_str);
	DispatchKeyValue(ent, "glowcolor", robot_glow);
	DispatchKeyValue(ent, "glowstate", "2");
	//DispatchKeyValue(ent, "targetname", MODEL[weapontype[client]]);
	DispatchSpawn(ent);
	TeleportEntity(ent, v1, NULL_VECTOR, NULL_VECTOR);
	
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 1);
	SetEntityMoveType(ent, MOVETYPE_FLY);
	
	SetVariantString("idle");
	AcceptEntityInput(ent, "SetAnimation");
	SetVariantString("idle");
	AcceptEntityInput(ent, "SetDefaultAnimation");
	// Setting the robots to do the idle animation is vital for them to actually move
	
	SIenemy[client] = 0;
	CIenemy[client] = 0;
	scantime[client] = 0.0;
	keybuffer[client] = 0;
	bullet[client] = 0;
	reloading[client] = false;
	reloadtime[client] = 0.0;
	firetime[client] = 0.0;
	robot[client] = ent;
	if (showmsg && (robot_messages & BITFLAG_MESSAGE_INFO))
	{
		PrintHintText(client, "你已经召唤了一个机器人，按SHIFT+E删除机器人");
		PrintToChatAll("\x04%N\x03 召唤了一个机器人", client);
	}
	
	//SetVariantString("function InputUse() {return false}");
	//AcceptEntityInput(ent, "RunScriptCode");
	
	//HookSingleEntityOutput(ent, "OnUsed", Output_OnUse);
	
	gamestart = true;
}

static float lasttime=0.0;

static int button;

static float robotpos[3], robotvec[3];

static float clienteyepos[3];

static float clientangle[3], enemypos[3], infectedorigin[3], infectedeyepos[3];
 
static float chargetime;

void Do(int client, float currenttime, float duration)
{
	if (RealValidEntity(robot[client]))
	{
		if (IsFakeClient(client) || !IsValidClient(client) || !IsPlayerAlive(client))
		{
			Release(client);
		}
		else  
		{			
			botenergy[client] += duration;
			if (robot_energy > -1.0 && botenergy[client] > robot_energy)
			{
				Release(client);
				PrintHintText(client, "你的机器人能量不够");
				return;
			}
			
			button = GetClientButtons(client);
 		 	GetEntPropVector(robot[client], Prop_Send, "m_vecOrigin", robotpos);	
	 		 
			if ((button & IN_USE) && (button & IN_SPEED) && !(keybuffer[client] & IN_USE))
			{
				Release(client);
				if (robot_messages & BITFLAG_MESSAGE_INFO)
				{ PrintToChatAll("\x04%N\x03 关掉了他的机器人", client); }
				return;
			}
			if (currenttime - scantime[client] > robot_reactiontime)
			{
				scantime[client] = currenttime;
				SIenemy[client] = ScanEnemy(client, robotpos);
				#if ORIGINAL_PAN
					CIenemy[client] = 0;
				#else
					CIenemy[client] = ScanCommon(client, robotpos);
				#endif
			}
			bool targetok = false;
			if (IsValidClient(SIenemy[client]) && IsPlayerAlive(SIenemy[client]))
			{
				GetClientEyePosition(SIenemy[client], infectedeyepos);
				GetClientAbsOrigin(SIenemy[client], infectedorigin);	
				enemypos[0] = infectedorigin[0] * 0.4 + infectedeyepos[0] * 0.6;
				enemypos[1] = infectedorigin[1] * 0.4 + infectedeyepos[1] * 0.6;
				enemypos[2] = infectedorigin[2] * 0.4 + infectedeyepos[2] * 0.6;
				
				SubtractVectors(enemypos, robotpos, robotangle[client]);
				GetVectorAngles(robotangle[client], robotangle[client]);
				targetok = true;
			}
			else 
			{
				SIenemy[client] = 0;
			}
			if (!targetok)
			{
				if (RealValidEntity(CIenemy[client]))
				{
					GetEntPropVector(CIenemy[client], Prop_Send, "m_vecOrigin", enemypos);	
					enemypos[2] += 40.0;
					SubtractVectors(enemypos, robotpos, robotangle[client]);
					GetVectorAngles(robotangle[client], robotangle[client]);
					targetok = true;
				}
				else
				{
					CIenemy[client] = 0;
				}
			}
			if (reloading[client])
			{
				//PrintToChatAll("%f", reloadtime[client]);
				if (bullet[client] >= weaponclipsize[weapontype[client]] && currenttime - reloadtime[client] > weaponloadtime[weapontype[client]])
				{
					reloading[client] = false;	
					reloadtime[client] = currenttime;
					EmitSoundToAll(SOUNDREADY, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos, NULL_VECTOR, false, 0.0);
					//PrintHintText(client, " ");
				}
				else if (currenttime - reloadtime[client] > weaponloadtime[weapontype[client]])
				{
					reloadtime[client] = currenttime;
					bullet[client] += weaponloadcount[weapontype[client]];
					EmitSoundToAll(SOUNDRELOAD, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos, NULL_VECTOR, false, 0.0);
					//PrintHintText(client, "Reloading %d", bullet[client]);
				}
			}
			if (!reloading[client])
			{
				if (!targetok) 
				{
					if (bullet[client] < weaponclipsize[weapontype[client]])					
					{
						reloading[client] = true;	
						reloadtime[client] = 0.0;
						if (!weaponloaddisrupt[weapontype[client]])
						{
							bullet[client] = 0;
						}
					}
				}	
			}
			chargetime = fireinterval[weapontype[client]];
			 
			if (!reloading[client])
			{
				if (currenttime - firetime[client] > chargetime)
				{
					if (targetok) 
					{
						if (bullet[client] > 0)
						{
							bullet[client] = bullet[client] - 1;
							
							FireBullet(client, robot[client], enemypos, robotpos);
						 
							firetime[client] = currenttime;	
						 	reloading[client] = false;
						}
						else
						{
							firetime[client] = currenttime;
						 	EmitSoundToAll(SOUNDCLIPEMPTY, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, robotpos, NULL_VECTOR, false, 0.0);
							reloading[client] = true;	
							reloadtime[client] = currenttime;
						}
					}
				}
			}
	
 			GetClientEyePosition(client, clienteyepos);
			clienteyepos[2] += 30.0;
			GetClientEyeAngles(client, clientangle);
			float distance = GetVectorDistance(robotpos, clienteyepos);
			 
			if (distance > 500.0)
			{
				TeleportEntity(robot[client], clienteyepos, robotangle[client], NULL_VECTOR);
			}
			else if (distance > 100.0)		
			{
				MakeVectorFromPoints( robotpos, clienteyepos, robotvec);
				NormalizeVector(robotvec,robotvec);
				ScaleVector(robotvec, 5*distance);
				if (!targetok )
				{
					GetVectorAngles(robotvec, robotangle[client]);
				}
				TeleportEntity(robot[client], NULL_VECTOR, robotangle[client] ,robotvec);
				walktime[client]=currenttime;
			}
			else 
			{
				robotvec[0] = robotvec[1] = robotvec[2] = 0.0;
				if (!targetok && currenttime-firetime[client] > 4.0 && currenttime-walktime[client] > 1.0 )
				{ robotangle[client][1] += 5.0; }
				TeleportEntity(robot[client], NULL_VECTOR, robotangle[client], robotvec);
			}
		 	keybuffer[client] = button;
		}
	}
	else 
	{
		botenergy[client] = botenergy[client] - duration * 0.5;
		if (botenergy[client] < 0.0)
			botenergy[client] = 0.0;
	}
}
public void OnGameFrame()
{
	if (!gamestart) return;
	
	float currenttime = GetEngineTime();
	float duration = currenttime - lasttime;
	if (duration < 0.0 || duration > 1.0)
	{ duration = 0.0; }
	for (int client = 1; client <= MaxClients; client++)
	{
		Do(client, currenttime, duration);
	}
	lasttime = currenttime;
	return;
}
#if !ORIGINAL_PAN
int ScanCommon(int client, float rpos[3])
{
	float infectedpos[3], vec[3], angle[3];
 	int find = 0;
	float mindis = 100000.0, dis = 0.0;
	for (int i = MaxClients+1; i <= GetMaxEntities(); i++)
	{
		if (!RealValidEntity(i)) continue;
		static char classname[9];
		GetEntityClassname(i, classname, sizeof(classname));
		if (strcmp(classname, "infected", false) != 0) continue;
		
		int health = GetEntProp(i, Prop_Data, "m_iHealth");
		if (health <= 0) continue;
		
		GetEntPropVector(i, Prop_Data, "m_vecOrigin", infectedpos);	
		//infectedpos[2] += 40.0;
		dis = GetVectorDistance(rpos, infectedpos);
		//PrintToChatAll("%f %N" ,dis, i);
		if (dis < robot_scanrange && dis <= mindis)
		{
			SubtractVectors(infectedpos, rpos, vec);
			GetVectorAngles(vec, angle);
			TR_TraceRayFilter(infectedpos, rpos, MASK_SOLID, RayType_EndPoint, TraceRayDontHitSelfAndLive, robot[client]);
		
			if (!TR_DidHit())
			{
				find = i;
				mindis = dis;
				return find;
			}
		}
	}
 
	return find;
}
#endif
int ScanEnemy(int client, float rpos[3])
{
	float infectedpos[3], vec[3], angle[3];
 	int find = 0;
	float mindis = 100000.0, dis = 0.0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
		{
			GetClientEyePosition(i, infectedpos);
			dis = GetVectorDistance(rpos, infectedpos);
			//PrintToChatAll("%f %N" ,dis, i);
			if (dis < robot_scanrange && dis <= mindis)
			{
				SubtractVectors(infectedpos, rpos, vec);
				GetVectorAngles(vec, angle);
				TR_TraceRayFilter(infectedpos, rpos, MASK_SOLID, RayType_EndPoint, TraceRayDontHitSelfAndLive, robot[client]);
			
				if (!TR_DidHit())
				{
					find = i;
					mindis = dis;
					return find;
				}
			}
		}
	}
 
	return find;
}
void FireBullet(int controller, int bot, float infectedpos[3], float botorigin[3])
{
	float vAngles[3], vAngles2[3], pos[3];
	
	SubtractVectors(infectedpos, botorigin, infectedpos);
	GetVectorAngles(infectedpos, vAngles);
	 
	float arr1, arr2;
	arr1 = 0.0 - bulletaccuracy[weapontype[controller]];	
	arr2 = bulletaccuracy[weapontype[controller]];
	
	float v1[3], v2[3];
	//PrintToChatAll("%f %f",arr1, arr2);
	for (int c = 0; c < weaponbulletpershot[weapontype[controller]]; c++)
	{
		//PrintToChatAll("fire");
		vAngles2[0] = vAngles[0] + GetRandomFloat(arr1, arr2);	
		vAngles2[1] = vAngles[1] + GetRandomFloat(arr1, arr2);	
		vAngles2[2] = vAngles[2] + GetRandomFloat(arr1, arr2);
		
		int hittarget = 0;
		TR_TraceRayFilter(botorigin, vAngles2, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelfAndSurvivor, bot);
		
		if (TR_DidHit())
		{
			TR_GetEndPosition(pos);
			hittarget = TR_GetEntityIndex();
			
			float Direction[3];
			Direction[0] = GetRandomFloat(-1.0, 1.0);
			Direction[1] = GetRandomFloat(-1.0, 1.0);
			Direction[2] = GetRandomFloat(-1.0, 1.0);
			TE_SetupSparks(pos, Direction, 1, 3);
			TE_SendToAll();
		}

		if (hittarget > 0)		
		{
			DoDamage(weapontype[controller], hittarget, controller);
		}
		
		SubtractVectors(botorigin, pos, v1);
		NormalizeVector(v1, v2);	
		ScaleVector(v2, 36.0);
		SubtractVectors(botorigin, v2, infectedorigin);
	 
		int color[4];
		color[0] = 200; 
		color[1] = 200;
		color[2] = 200;
		color[3] = 230;
		
		float life = 0.06, width1 = 0.01, width2 = 0.3;		
		if (L4D2Version)
			width2 = 0.08;
  
		TE_SetupBeamPoints(infectedorigin, pos, g_sprite, 0, 0, 0, life, width1, width2, 1, 0.0, color, 0);
		TE_SendToAll();
 
		//EmitAmbientSound(SOUND[weapontype[controller]], vOrigin, controller, SNDLEVEL_RAIDSIREN);
		EmitSoundToAll(SOUND[weapontype[controller]], 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, botorigin, NULL_VECTOR, false, 0.0);
	}
}

/*CreatePointHurt()
{
	new pointHurt=CreateEntityByName("point_hurt");
	if (pointHurt)
	{

		DispatchKeyValue(pointHurt,"Damage","10");
		DispatchKeyValue(pointHurt,"DamageType","2");
		DispatchSpawn(pointHurt);
	}
	return pointHurt;
}
static char N[10];
void DoPointHurtForInfected(int wtype, int victim, int attacker = 0)
{
	if (!RealValidEntity(g_PointHurt))
	{
		g_PointHurt = CreatePointHurt();
	}
	if (!RealValidEntity(g_PointHurt)) return;
	
	if (RealValidEntity(victim))
	{
		Format(N, 20, "target%d", victim);
		DispatchKeyValue(victim, "targetname", N);
		DispatchKeyValue(g_PointHurt, "DamageTarget", N);
		DispatchKeyValue(g_PointHurt, "classname", MODEL[wtype]);
		DispatchKeyValue(g_PointHurt, "Damage", weaponbulletdamagestr[wtype]);
		AcceptEntityInput(g_PointHurt, "Hurt", (attacker>0) ? attacker : -1);
	}
}*/

void DoDamage(int wtype, int target, int sender)
{
	if (!RealValidEntity(target)) return;
	if (!RealValidEntity(sender)) return;
	
	int robot_var = sender;
	if (RealValidEntity(robot[sender]))
		robot_var = robot[sender];
	
	SDKHooks_TakeDamage(target, robot_var, sender, StringToInt(weaponbulletdamagestr[wtype])+0.0, 2, robot_var);
	
	/*float spos[3];
	if (RealValidEntity(sender) && HasEntProp(sender, Prop_Data, "m_vecOrigin"))
	{ GetEntPropVector(sender, Prop_Data, "m_vecOrigin", spos); }
	
	int iDmgEntity = CreateEntityByName("point_hurt");
	if (!RealValidEntity(iDmgEntity))
	{ return -1; }
	TeleportEntity(iDmgEntity, spos, NULL_VECTOR, NULL_VECTOR);
	
	DispatchKeyValue(iDmgEntity, "DamageTarget", "!activator");
	
	DispatchKeyValue(iDmgEntity, "classname", MODEL[wtype]);
	DispatchKeyValue(iDmgEntity, "Damage", weaponbulletdamagestr[wtype]);
	DispatchKeyValue(iDmgEntity, "DamageType", "2");
	
	DispatchSpawn(iDmgEntity);
	ActivateEntity(iDmgEntity);
	AcceptEntityInput(iDmgEntity, "Hurt", target, sender);
	AcceptEntityInput(iDmgEntity, "Kill");
	return iDmgEntity;*/
}

/*bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	if (entity == data) 
	{
		return false; 
	}
	return true;
}*/
bool TraceRayDontHitSelfAndLive(int entity, int mask, any data)
{
	if (entity == data) 
	{
		return false; 
	}
	else if (IsValidClient(entity))
	{
		return false;
	}
	else if (RealValidEntity(entity))
	{
		static char classname[9];
		GetEntityClassname(entity, classname, sizeof(classname));
		if (strcmp(classname, "infected", false) == 0)
		{
			return false;
		}
	}
	return true;
}
bool TraceRayDontHitSelfAndSurvivor(int entity, int mask, any data)
{
	if (entity == data) 
	{
		return false; 
	}
	else if (IsValidClient(entity) && (GetClientTeam(entity) == 2 || GetClientTeam(entity) == 4))
	{
		return false;
	}
	return true;
}

bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return (entity > MaxClients || !entity);
}

bool IsValidClient(int client, bool replaycheck = true)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (replaycheck)
	{
		if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	}
	return true;
}

bool RealValidEntity(int entity)
{
	if (entity <= 0 || !IsValidEntity(entity)) return false;
	return true;
}