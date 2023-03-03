#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0.1"
#define CVAR_FLAGS			FCVAR_NOTIFY

int l4d2_player_num = 0;

bool l4d2_add_zombie;
bool l4d2_add_zombie_PutIn;

static bool PluginEnable;
static bool PluginHintEnable;
static bool AIEnabledZombie;
static int AIPlayerCountZombie;
static int CommonLimit;
static int MegamobLimit;
static int MobSpawnMin;
static int MobSpawnMax;
static int AutoAddZombie;

static int MaxZombie;

static int Cur_CommonLimit;
static int Cur_MegamobLimit;
static int Cur_MobSpawnMin;
static int Cur_MobSpawnMax;

static ConVar h_PluginEnable;
static ConVar h_PluginHintEnable;
static ConVar AI_EnabledZombie;
static ConVar AI_PlayerCountZombie;
static ConVar h_CommonLimit;
static ConVar h_MegamobLimit;
static ConVar h_MobSpawnMin;
static ConVar h_MobSpawnMax;
static ConVar h_AutoAddZombie;

static ConVar h_MaxZombie;

public Plugin myinfo =
{
	name = "动态僵尸.",
	author = "Tom.",
	description = "根据玩家人数动态调整小僵尸数量.",
	version = "1.0.1",
	url = ""
};

public void OnPluginStart()   
{

	CreateConVar("l4d_autoaddzombie_version", PLUGIN_VERSION, "Version of L4D2 autoaddzombie", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	RegConsoleCmd("sm_zm", ShowZombieCountInfo);
	
	h_PluginEnable = CreateConVar("plugin_enable", "1", "1=启用插件(输入!zm可查看僵尸数量信息), 0=关闭插件", CVAR_FLAGS);
	h_PluginHintEnable = CreateConVar("plugin_hint", "1", "1=打开提示, 0=关闭提示", CVAR_FLAGS);
	AI_EnabledZombie = CreateConVar("ai_enabled_zombie", "1", "是否动态改变僵尸数量. 0=固定, 1=动态.", CVAR_FLAGS);
	AI_PlayerCountZombie = CreateConVar("ai_playercount_zombie", "4", "幸存者大于这个人数的时候才启用动态模式.", CVAR_FLAGS);
	
	h_CommonLimit = CreateConVar("l4d2_common_limit", "15", "每次刷新丧尸的数量", CVAR_FLAGS);
	h_MegamobLimit = CreateConVar("l4d2_mega_mob_size", "25", "警报时刷新丧尸的数量", CVAR_FLAGS);
	
	h_MobSpawnMin = CreateConVar("l4d2_mob_spawn_min_size", "5", "每次尸潮出现的最小僵尸数量.", CVAR_FLAGS);
	h_MobSpawnMax = CreateConVar("l4d2_mob_spawn_max_size", "15", "每次尸潮出现的最大僵尸数量.", CVAR_FLAGS);
	
	h_AutoAddZombie = CreateConVar("l4d2_ai_auto_add_zombie", "5", "每多一个人僵尸增加几个.", CVAR_FLAGS);
	
	h_MaxZombie = CreateConVar("l4d2_ai_max_zombie", "120", "尸潮数量限制,调整尸潮数量的四个参数不会超过这个值, 0=不限制.", CVAR_FLAGS);
	
	
	h_PluginEnable.AddChangeHook(l4d2ConVarChanged);
	h_PluginHintEnable.AddChangeHook(l4d2ConVarChanged);
	AI_EnabledZombie.AddChangeHook(l4d2ConVarChanged);
	AI_PlayerCountZombie.AddChangeHook(l4d2ConVarChanged);
	h_CommonLimit.AddChangeHook(l4d2ConVarChanged);
	h_MegamobLimit.AddChangeHook(l4d2ConVarChanged);
	h_MobSpawnMin.AddChangeHook(l4d2ConVarChanged);
	h_MobSpawnMax.AddChangeHook(l4d2ConVarChanged);
	h_AutoAddZombie.AddChangeHook(l4d2ConVarChanged);
	h_MaxZombie.AddChangeHook(l4d2ConVarChanged);
	
	
	
	HookEvent("round_start", Event_RoundStart);//回合开始.
	HookEvent("round_end", Event_RoundEnd);//回合结束.
	HookEvent("player_left_start_area", Event_playerleftstartarea);//玩家离开安全区.

	AutoExecConfig(true, "l4d2_auto_add_zombie");//生成指定文件名的CFG.
}


//地图开始
public void OnMapStart()
{	
	l4d2_player_num = 0;
	l4d2_cvar_add_zombie();
	l4d2_add_zombie = false;
	l4d2_add_zombie_PutIn = false;
}

public void l4d2ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	l4d2_cvar_add_zombie();
}

void l4d2_cvar_add_zombie()
{
	PluginEnable = h_PluginEnable.BoolValue;
	PluginHintEnable = h_PluginHintEnable.BoolValue;
	AIEnabledZombie = AI_EnabledZombie.BoolValue;
	
	AIPlayerCountZombie = AI_PlayerCountZombie.IntValue;
	CommonLimit = h_CommonLimit.IntValue;
	MegamobLimit = h_MegamobLimit.IntValue;
	MobSpawnMin = h_MobSpawnMin.IntValue;
	MobSpawnMax = h_MobSpawnMax.IntValue;
	AutoAddZombie = h_AutoAddZombie.IntValue;
	MaxZombie = h_MaxZombie.IntValue;
}

//玩家离开安全区.
public void Event_playerleftstartarea(Event event, const char[] name, bool dontBroadcast)
{
	if (l4d2_player_num > AIPlayerCountZombie)
	{
		showHint();
	}
}

//玩家连接成功.
public void OnClientPostAdminCheck(int client)
{
	if (!PluginEnable)
		return;
	
	if(IsFakeClient(client))
		return;
	
	if(!l4d2_add_zombie_PutIn)
	{
		l4d2_add_zombie_PutIn = true;
		CreateTimer(1.0, l4d2_start, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

//回合结束.
public void Event_RoundEnd(Event event, const char [] name, bool dontBroadcast)
{
	if (!PluginEnable)
		return;
	
	if(!l4d2_add_zombie)
	{
		l4d2_add_zombie = true;
	}
}


//回合开始.
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!PluginEnable)
		return;
	
	if(l4d2_add_zombie)
	{
		l4d2_add_zombie = false;
		CreateTimer(1.0, l4d2_start, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

//回合开始或玩家连接成功.
public Action l4d2_start(Handle timer)
{
	if (!PluginEnable)
		return;
	
	int connectnum = GetAllPlayerCount();
	int connectnum1 = GetConnectingPlayerNum(false);
	int connectnum2 = connectnum + connectnum1;
	
	CheckZombieCount(connectnum2, false);
}

public void SetZombieCount()
{
	SetConVarInt(FindConVar("z_common_limit"), Cur_CommonLimit);
	SetConVarInt(FindConVar("z_mega_mob_size"), Cur_MegamobLimit);
	SetConVarInt(FindConVar("z_mob_spawn_min_size"), Cur_MobSpawnMin);
	SetConVarInt(FindConVar("z_mob_spawn_max_size"), Cur_MobSpawnMax);
}

public Action ShowZombieCountInfo(int client, int args)
{
	if (client)
	{
		int commonLimit = FindConVar("z_common_limit").IntValue;
		int megamobLimit = FindConVar("z_mega_mob_size").IntValue;
		int mobSpawnMin = FindConVar("z_mob_spawn_min_size").IntValue;
		int mobSpawnMax = FindConVar("z_mob_spawn_max_size").IntValue;
		PrintToChat(client, "\x04僵尸数量信息:↓↓↓");
		PrintToChat(client, "\x05僵尸数量(z_common_limit) = \x03%i", commonLimit);
		PrintToChat(client, "\x05警报数量(z_mega_mob_size) = \x03%i", megamobLimit);
		PrintToChat(client, "\x05最小数量(z_mob_spawn_min_size) = \x03%i", mobSpawnMin);
		PrintToChat(client, "\x05最大数量(z_mob_spawn_max_size) = \x03%i", mobSpawnMax);
		PrintToChat(client, "\x05进人增加数量 = \x03%i", AutoAddZombie);
	}
}

public void CheckZombieCount(int playerNum, bool isShowHint)
{
	Cur_CommonLimit = CommonLimit;
	Cur_MegamobLimit = MegamobLimit;
	Cur_MobSpawnMin = MobSpawnMin;
	Cur_MobSpawnMax = MobSpawnMax;
	
	if (AIEnabledZombie)
	{
		if (playerNum > AIPlayerCountZombie)
		{
			int Add_PlayerZombies = playerNum - AIPlayerCountZombie;
			if(Add_PlayerZombies >= 1)
			{
				Cur_CommonLimit = CommonLimit + AutoAddZombie*Add_PlayerZombies;
				Cur_MegamobLimit = MegamobLimit + AutoAddZombie*Add_PlayerZombies/2;
				Cur_MobSpawnMin = MobSpawnMin + AutoAddZombie*Add_PlayerZombies;
				Cur_MobSpawnMax = MobSpawnMax + AutoAddZombie*Add_PlayerZombies;
				
				if(MaxZombie > 0)
				{
					if(Cur_CommonLimit > MaxZombie){
						Cur_CommonLimit = MaxZombie;
					}
					if(Cur_MegamobLimit > MaxZombie){
						Cur_MegamobLimit = MaxZombie;
					}
					if(Cur_MobSpawnMin > MaxZombie){
						Cur_MobSpawnMin = MaxZombie;
					}
					if(Cur_MobSpawnMax > MaxZombie){
						Cur_MobSpawnMax = MaxZombie;
					}
				}
				
				if(isShowHint)
				{
					showHint();
				}
				
			}
		}
	}
	
	SetZombieCount();
}

//玩家连接
public void OnClientConnected(int client)
{   
	if (!PluginEnable)
		return;
	
	if(IsFakeClient(client))
		return;

	l4d2_player_num += 1;
	//int Survivor_Limit = SurvivorLimit();
	
	CheckZombieCount(l4d2_player_num, true);
}

//玩家退出
public void OnClientDisconnect(int client)
{   
	if (!PluginEnable)
		return;
	
	if(IsFakeClient(client))
		return;
	
	l4d2_player_num -=1 ;
	//int Survivor_Limit = SurvivorLimit();
	
	CheckZombieCount(l4d2_player_num, true);
}

public void showHint()
{
	if (!PluginEnable)
		return;
		
	if (PluginHintEnable)
	{
		if (AIEnabledZombie){
			PrintToChatAll("\x04[提示]\x05幸存者\x04:\x03%d\x05人\x04,\x05动态调整尸潮数量为\x04:\x03%d\x04~\x03%d\x05只.", l4d2_player_num, Cur_MobSpawnMin, Cur_MobSpawnMax);
		}
	}
}

/**
int SurvivorLimit()
{
	int maxcl;
	Handle invalid = null;
	Handle downtownrun = FindConVar("l4d_maxplayers");
	Handle toolzrun = FindConVar("sv_maxplayers");
	if (downtownrun != (invalid))
	{
		int downtown = (GetConVarInt(FindConVar("l4d_maxplayers")));
		if (downtown >= 1)
		{
			maxcl = (GetConVarInt(FindConVar("l4d_maxplayers")));
		}
	}
	if (toolzrun != (invalid))
	{
		int toolz = (GetConVarInt(FindConVar("sv_maxplayers")));
		if (toolz >= 1)
		{
			maxcl = (GetConVarInt(FindConVar("sv_maxplayers")));
		}
	}
	if (downtownrun == (invalid) && toolzrun == (invalid))
	{
		maxcl = (MaxClients);
	}
	return maxcl;
}**/

int GetAllPlayerCount()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidPlayer(i) && !IsFakeClient(i))
		{
			count++;
		}
	}
	
	return count;
}

int GetConnectingPlayerNum(bool allowbot)
{
	int num;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsClientInGame(i))
		{
			if (!allowbot)
			{
				if (!IsFakeClient(i))
					num++;
			}
			else
				num++;
		}
	}
	
	return num;
}

bool IsValidPlayer(int client, bool AllowBot = true, bool AllowDeath = true)
{
	if (client < 1 || client > MaxClients)
		return false;
	if (!IsClientConnected(client) || !IsClientInGame(client))
		return false;
	if (!AllowBot)
	{
		if (IsFakeClient(client))
			return false;
	}
	if (!AllowDeath)
	{
		if (!IsPlayerAlive(client))
			return false;
	}	
	return true;
}
