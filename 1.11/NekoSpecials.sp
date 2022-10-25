#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <left4dhooks>
#include <binhooks>
#include <neko/nekotools>
#include <neko/nekonative>
#include "nspecials/globals.sp"

public Plugin myinfo =
{
	name = "Neko Specials Spawner",
	description = "Neko Specials Spawner Base on Binhooks",
	author = "Neko Channel & Mr Cheng",
	version = PLUGIN_VERSION,
	url = "https://himeneko.cn/nekospecials"
	//请勿修改插件信息！
};

public void OnPluginStart()
{
	AutoExecConfig_SetFile(PLUGIN_CONFIG);
	
	NCvar[CSpecial_PluginStatus] = 					AutoExecConfig_CreateConVar("Special_PluginStatus", "1", "[0=关|1=开]禁用/启用刷特[禁用后插件将不会刷出特感，若Special_CanCloseDirector为打开状态，将会一只特感都不会刷出]", _, true, 0.0, true, 1.0);
	NCvar[CSpecial_Fast_Response] = 				AutoExecConfig_CreateConVar("Special_Fast_Response", "1", "[0=关|1=开]禁用/启用更快的特殊感染反应[建议开着就好]", _, true, 0.0, true, 1.0);
	NCvar[CSpecial_CanCloseDirector] = 				AutoExecConfig_CreateConVar("Special_CanCloseDirector", "0", "[0=关|1=开]是否插件控制导演系统开关[若刷不出坦克请关掉此选项，此选项能让单一特感刷新模式时防止其他类型的特感刷出来，如果发现开了单一特感类型刷新时会出现其他特感，请开启，开启后请配合boss_spawn插件食用]", _, true, 0.0, true, 1.0);
	
	NCvar[CSpecial_LeftPoint_SpawnTime] = 			AutoExecConfig_CreateConVar("Special_LeftPoint_SpawnTime", "5.0", "离开安全区域后多久刷特[默认5.0秒]", _, true, 0.1, true, 120.0);
	NCvar[CSpecial_Spawn_Time] = 					AutoExecConfig_CreateConVar("Special_Spawn_Time", "28", "全局特感刷新时间间隔[3-180]", _, true, 3.0, true, 180.0);
	NCvar[CSpecial_Spawn_Time_DifficultyChange] = 	AutoExecConfig_CreateConVar("Special_Spawn_Time_DifficultyChange", "0", "[0=关|1=开]禁用/启用根据游戏难度改变刷特时间[启用后-全局特感刷新时间间隔-将不会生效]", _, true, 0.0, true, 1.0);
	NCvar[CSpecial_Spawn_Time_Easy] = 				AutoExecConfig_CreateConVar("Special_Spawn_Time_Easy", "25", "简单难度特感刷新时间间隔[3-180]", _, true, 3.0, true, 180.0);
	NCvar[CSpecial_Spawn_Time_Normal] = 			AutoExecConfig_CreateConVar("Special_Spawn_Time_Normal", "20", "普通难度特感刷新时间间隔[3-180]", _, true, 3.0, true, 180.0);
	NCvar[CSpecial_Spawn_Time_Hard] = 				AutoExecConfig_CreateConVar("Special_Spawn_Time_Hard", "15", "高级难度特感刷新时间间隔[3-180]", _, true, 3.0, true, 180.0);
	NCvar[CSpecial_Spawn_Time_Impossible] = 		AutoExecConfig_CreateConVar("Special_Spawn_Time_Impossible", "10", "专家难度特感刷新时间间隔[3-180]", _, true, 3.0, true, 180.0);

	NCvar[CSpecial_Num] = 							AutoExecConfig_CreateConVar("Special_Num", "4", "特感初始的刷新数量[1-32]", _, true, 1.0, true, 32.0);
	NCvar[CSpecial_AddNum] = 						AutoExecConfig_CreateConVar("Special_AddNum", "1", "特感每次进人增加数量[0-8][前提请设置Special_PlayerAdd]", _, true, 0.0, true, 8.0);
	NCvar[CSpecial_PlayerNum] = 					AutoExecConfig_CreateConVar("Special_PlayerNum", "4", "玩家初始计算人数[1-32][意思为从第几个玩家开始，来增加特感数量，低于或等于这个数值则按Special_Num的数量刷特，如果不会弄就不需要改这个]", _, true, 1.0, true, 32.0);
	NCvar[CSpecial_PlayerAdd] = 					AutoExecConfig_CreateConVar("Special_PlayerAdd", "1", "玩家增加数量[1-8][玩家每进几个人，才增加Special_AddNum数量的特感，Special_AddNum不为0才生效]", _, true, 1.0, true, 8.0);
	NCvar[CSpecial_PlayerCountSpec] = 				AutoExecConfig_CreateConVar("Special_PlayerCountSpec", "0", "[0=关|1=开]计算玩家人数时，是否把旁观者也算进去[这个会把旁观者也算进去，非常不建议打开!]", _, true, 0.0, true, 1.0);
	NCvar[CSpecial_Num_NotCul_Death] = 				AutoExecConfig_CreateConVar("Special_Num_NotCul_Death", "0", "[0=关|1=开]计算玩家人数时，不把死亡玩家也算进去[这个不会把死亡玩家也算进去，非常不建议打开!]", _, true, 0.0, true, 1.0);

	NCvar[CSpecial_Random_Mode] = 					AutoExecConfig_CreateConVar("Special_Random_Mode", "0", "[0=关|1=开]启用随机特感[开启后会随机Special_Default_Mode中包含的模式，仅供娱乐]", _, true, 0.0, true, 1.0);
	NCvar[CSpecial_Default_Mode] = 					AutoExecConfig_CreateConVar("Special_Default_Mode", "7", "指定刷新模式(当随机特感关闭生效)[1=全猎人|2=全牛|3=全猴子|4=全口水|5=全胖子|6=全舌头|7=默认][默认模式为全部特感类型都会刷新，其他为单一类型刷新]", _, true, 1.0, true, 8.0);
	NCvar[CSpecial_Spawn_Mode] = 					AutoExecConfig_CreateConVar("Special_Spawn_Mode", "1", "[0=引擎|1=普通|2=噩梦|3=地狱]特感生成方式[引擎就是游戏自带的导演系统，普通是插件默认选项比较适合普通玩家，噩梦与地狱适合大佬游玩，地狱是最高难度，噩梦与地狱刷特位置会比较近]", _, true, 0.0, true, 3.0);
	NCvar[CSpecial_IsModeInNormal] =				AutoExecConfig_CreateConVar("Special_IsModeInNormal", "1", "[1=模式1(默认)|2=模式2]在Special_Spawn_Mode的普通、噩梦、地狱模式下有效的子模式,只有1和2可选，具体说明请看插件的说明书。", _, true, 1.0, true, 2.0);
	
	NCvar[CSpecial_Spawn_Tank_Alive] = 				AutoExecConfig_CreateConVar("Special_Spawn_Tank_Alive", "1", "[0=关|1=开]特感是否在坦克活着时刷新", _, true, 0.0, true, 1.0);
	NCvar[CSpecial_Spawn_Tank_Alive_Pro] = 			AutoExecConfig_CreateConVar("Special_Spawn_Tank_Alive_Pro", "0", "[0=关|1=开]当坦克活着时，特感强制在刷新的时候被踢出[开启后可试图修复CSpecial_Spawn_Tank_Alive关闭后坦克存活依旧刷特问题]", _, true, 0.0, true, 1.0);
	NCvar[CSpecial_AutoKill_StuckTank] = 			AutoExecConfig_CreateConVar("Special_AutoKill_StuckTank", "0", "[0=关|1=开]自动处死卡住的坦克[有防卡插件可以关闭]", _, true, 0.0, true, 1.0);
	
	NCvar[CSpecial_Show_Tips] = 					AutoExecConfig_CreateConVar("Special_Show_Tips", "1", "[0=关|1=开]显示特感数量改变提示", _, true, 0.0, true, 1.0);
	NCvar[CSpecial_Show_Tips_Chat] = 				AutoExecConfig_CreateConVar("Special_Show_Tips_Chat", "0", "[0=关|1=开]将特感改变提示变为聊天框输出，关闭就使用HUD显示", _, true, 0.0, true, 1.0);
	
	NCvar[CSpecial_Boomer_Num] = 					AutoExecConfig_CreateConVar("Special_Boomer_Num", "4", "Boomer最大刷新数量[当指定默认刷新模式时生效]", _, true, 0.0, true, 32.0);
	NCvar[CSpecial_Smoker_Num] = 					AutoExecConfig_CreateConVar("Special_Smoker_Num", "4", "Smoker最大刷新数量[当指定默认刷新模式时生效]", _, true, 0.0, true, 32.0);
	NCvar[CSpecial_Charger_Num] = 					AutoExecConfig_CreateConVar("Special_Charger_Num", "4", "Charger最大刷新数量[当指定默认刷新模式时生效]", _, true, 0.0, true, 32.0);
	NCvar[CSpecial_Hunter_Num] = 					AutoExecConfig_CreateConVar("Special_Hunter_Num", "4", "Hunter最大刷新数量[当指定默认刷新模式时生效]", _, true, 0.0, true, 32.0);
	NCvar[CSpecial_Spitter_Num] = 					AutoExecConfig_CreateConVar("Special_Spitter_Num", "4", "Spitter最大刷新数量[当指定默认刷新模式时生效]", _, true, 0.0, true, 32.0);
	NCvar[CSpecial_Jockey_Num] = 					AutoExecConfig_CreateConVar("Special_Jockey_Num", "4", "Jockey最大刷新数量[当指定默认刷新模式时生效]", _, true, 0.0, true, 32.0);

	NCvar[CSpecial_Boomer_Spawn_Weight] = 			AutoExecConfig_CreateConVar("Special_Boomer_Spawn_Weight", "50", "Boomer刷新概率[范围1-100|当其他特感也设置了数量时生效]", _, true, 1.0, true, 100.0);
	NCvar[CSpecial_Smoker_Spawn_Weight] = 			AutoExecConfig_CreateConVar("Special_Smoker_Spawn_Weight", "50", "Smoker刷新概率[范围1-100|当其他特感也设置了数量时生效]", _, true, 1.0, true, 100.0);
	NCvar[CSpecial_Charger_Spawn_Weight] = 			AutoExecConfig_CreateConVar("Special_Charger_Spawn_Weight", "50", "Charger刷新概率[范围1-100|当其他特感也设置了数量时生效]", _, true, 1.0, true, 100.0);
	NCvar[CSpecial_Hunter_Spawn_Weight] = 			AutoExecConfig_CreateConVar("Special_Hunter_Spawn_Weight", "50", "Hunter刷新概率[范围1-100|当其他特感也设置了数量时生效]", _, true, 1.0, true, 100.0);
	NCvar[CSpecial_Spitter_Spawn_Weight] = 			AutoExecConfig_CreateConVar("Special_Spitter_Spawn_Weight", "50", "Spitter刷新概率[范围1-100|当其他特感也设置了数量时生效]", _, true, 1.0, true, 100.0);
	NCvar[CSpecial_Jockey_Spawn_Weight] =			AutoExecConfig_CreateConVar("Special_Jockey_Spawn_Weight", "50", "Jockey刷新概率[范围1-100|当其他特感也设置了数量时生效]", _, true, 1.0, true, 100.0);

	NCvar[CSpecial_Boomer_Spawn_DirChance] = 		AutoExecConfig_CreateConVar("Special_Boomer_Spawn_DirChance", "50", "Boomer刷新方位概率，数值越大越容易刷在前方，数值越小越容易刷在后方[范围1-100|仅梦魇和炼狱模式有效]", _, true, 1.0, true, 100.0);
	NCvar[CSpecial_Smoker_Spawn_DirChance] = 		AutoExecConfig_CreateConVar("Special_Smoker_Spawn_DirChance", "50", "Smoker刷新方位概率，数值越大越容易刷在前方，数值越小越容易刷在后方[范围1-100|仅梦魇和炼狱模式有效]", _, true, 1.0, true, 100.0);
	NCvar[CSpecial_Charger_Spawn_DirChance] = 		AutoExecConfig_CreateConVar("Special_Charger_Spawn_DirChance", "50", "Charger刷新方位概率，数值越大越容易刷在前方，数值越小越容易刷在后方[范围1-100|仅梦魇和炼狱模式有效]", _, true, 1.0, true, 100.0);
	NCvar[CSpecial_Hunter_Spawn_DirChance] = 		AutoExecConfig_CreateConVar("Special_Hunter_Spawn_DirChance", "50", "Hunter刷新方位概率，数值越大越容易刷在前方，数值越小越容易刷在后方[范围1-100|仅梦魇和炼狱模式有效]", _, true, 1.0, true, 100.0);
	NCvar[CSpecial_Spitter_Spawn_DirChance] =		AutoExecConfig_CreateConVar("Special_Spitter_Spawn_DirChance", "50", "Spitter刷新方位概率，数值越大越容易刷在前方，数值越小越容易刷在后方[范围1-100|仅梦魇和炼狱模式有效]", _, true, 1.0, true, 100.0);
	NCvar[CSpecial_Jockey_Spawn_DirChance] =		AutoExecConfig_CreateConVar("Special_Jockey_Spawn_DirChance", "50", "Jockey刷新方位概率，数值越大越容易刷在前方，数值越小越容易刷在后方[范围1-100|仅梦魇和炼狱模式有效]", _, true, 1.0, true, 100.0);
	
	NCvar[CSpecial_Boomer_Spawn_Area] = 			AutoExecConfig_CreateConVar("Special_Boomer_Spawn_Area", "1", "Boomer刷新区域，0为产生在官方区域，1为产生在任何区域[仅梦魇和炼狱模式有效]", _, true, 0.0, true, 1.0);
	NCvar[CSpecial_Smoker_Spawn_Area] = 			AutoExecConfig_CreateConVar("Special_Smoker_Spawn_Area", "1", "Smoker刷新区域，0为产生在官方区域，1为产生在任何区域[仅梦魇和炼狱模式有效]", _, true, 0.0, true, 1.0);
	NCvar[CSpecial_Charger_Spawn_Area] = 			AutoExecConfig_CreateConVar("Special_Charger_Spawn_Area", "1", "Charger刷新区域，0为产生在官方区域，1为产生在任何区域[仅梦魇和炼狱模式有效]", _, true, 0.0, true, 1.0);
	NCvar[CSpecial_Hunter_Spawn_Area] = 			AutoExecConfig_CreateConVar("Special_Hunter_Spawn_Area", "1", "Hunter刷新区域，0为产生在官方区域，1为产生在任何区域[仅梦魇和炼狱模式有效]", _, true, 0.0, true, 1.0);
	NCvar[CSpecial_Spitter_Spawn_Area] = 			AutoExecConfig_CreateConVar("Special_Spitter_Spawn_Area", "1", "Spitter刷新区域，0为产生在官方区域，1为产生在任何区域[仅梦魇和炼狱模式有效]", _, true, 0.0, true, 1.0);
	NCvar[CSpecial_Jockey_Spawn_Area] = 			AutoExecConfig_CreateConVar("Special_Jockey_Spawn_Area", "1", "Jockey刷新区域，0为产生在官方区域，1为产生在任何区域[仅梦魇和炼狱模式有效]", _, true, 0.0, true, 1.0);

	NCvar[CSpecial_Boomer_Spawn_MaxDis] = 			AutoExecConfig_CreateConVar("Special_Boomer_Spawn_MaxDis", "2000", "Boomer刷新最大距离[范围不能小于1|仅梦魇和炼狱模式有效]", _, true, 1.0, false);
	NCvar[CSpecial_Smoker_Spawn_MaxDis] = 			AutoExecConfig_CreateConVar("Special_Smoker_Spawn_MaxDis", "2000", "Smoker刷新最大距离[范围不能小于1|仅梦魇和炼狱模式有效]", _, true, 1.0, false);
	NCvar[CSpecial_Charger_Spawn_MaxDis] =		 	AutoExecConfig_CreateConVar("Special_Charger_Spawn_MaxDis", "2000", "Charger刷新最大距离[范围不能小于1|仅梦魇和炼狱模式有效]", _, true, 1.0, false);
	NCvar[CSpecial_Hunter_Spawn_MaxDis] = 			AutoExecConfig_CreateConVar("Special_Hunter_Spawn_MaxDis", "2000", "Hunter刷新最大距离[范围不能小于1|仅梦魇和炼狱模式有效]", _, true, 1.0, false);
	NCvar[CSpecial_Spitter_Spawn_MaxDis] = 			AutoExecConfig_CreateConVar("Special_Spitter_Spawn_MaxDis", "2000", "Spitter刷新最大距离[范围不能小于1|仅梦魇和炼狱模式有效]", _, true, 1.0, false);
	NCvar[CSpecial_Jockey_Spawn_MaxDis] = 			AutoExecConfig_CreateConVar("Special_Jockey_Spawn_MaxDis", "2000", "Jockey刷新最大距离[范围不能小于1|仅梦魇和炼狱模式有效]", _, true, 1.0, false);

	NCvar[CSpecial_Boomer_Spawn_MinDis] = 			AutoExecConfig_CreateConVar("Special_Boomer_Spawn_MinDis", "500", "Boomer刷新最小距离[范围不能小于1|仅梦魇和炼狱模式有效]", _, true, 1.0, false);
	NCvar[CSpecial_Smoker_Spawn_MinDis] = 			AutoExecConfig_CreateConVar("Special_Smoker_Spawn_MinDis", "500", "Smoker刷新最小距离[范围不能小于1|仅梦魇和炼狱模式有效]", _, true, 1.0, false);
	NCvar[CSpecial_Charger_Spawn_MinDis] = 			AutoExecConfig_CreateConVar("Special_Charger_Spawn_MinDis", "500", "Charger刷新最小距离[范围不能小于1|仅梦魇和炼狱模式有效]", _, true, 1.0, false);
	NCvar[CSpecial_Hunter_Spawn_MinDis] = 			AutoExecConfig_CreateConVar("Special_Hunter_Spawn_MinDis", "500", "Hunter刷新最小距离[范围不能小于1|仅梦魇和炼狱模式有效]", _, true, 1.0, false);
	NCvar[CSpecial_Spitter_Spawn_MinDis] = 			AutoExecConfig_CreateConVar("Special_Spitter_Spawn_MinDis", "500", "Spitter刷新最小距离[范围不能小于1|仅梦魇和炼狱模式有效]", _, true, 1.0, false);
	NCvar[CSpecial_Jockey_Spawn_MinDis] = 			AutoExecConfig_CreateConVar("Special_Jockey_Spawn_MinDis", "500", "Jockey刷新最小距离[范围不能小于1|仅梦魇和炼狱模式有效]", _, true, 1.0, false);

	NCvar[CSpecial_Spawn_MaxDis] = 					AutoExecConfig_CreateConVar("Special_Spawn_MaxDis", "1500", "全部特感刷新最大距离[范围不能小于1|仅引擎和普通模式有效]", _, true, 1.0, false);
	NCvar[CSpecial_Spawn_MinDis] = 					AutoExecConfig_CreateConVar("Special_Spawn_MinDis", "500", "全部特感刷新最小距离[范围不能小于1|仅引擎和普通模式有效]", _, true, 1.0, false);
	
	NCvar[CGame_Difficulty] = FindConVar("z_difficulty");

	AutoExecConfig_OnceExec();
	
	HookEvent("round_start", 		OnRoundStart);
	HookEvent("tank_spawn", 		OnTankSpawn, 		EventHookMode_Pre);
	HookEvent("tank_killed", 		OnTankDeath, 		EventHookMode_PostNoCopy);
	HookEvent("player_death", 		OnPlayerDeath);
	HookEvent("player_spawn", 		OnPlayerSpawn);
	HookEvent("mission_lost",		OnRoundEnd);
	HookEvent("round_end", 			OnRoundEnd);
	HookEvent("player_team", 		player_team);
	HookEvent("player_disconnect", 	OnPlayerDisconnect, EventHookMode_Pre);	
	
	RequestFrame(SetCvarHook);
	RequestFrame(SetAISpawnInit);
	
	AddCommandListener(ChatListener, "say");
	AddCommandListener(ChatListener, "say2");
	AddCommandListener(ChatListener, "say_team");
	
	RegAdminCmd("sm_ntg", 				OpenSpecialMenu, 	ADMFLAG_ROOT, "打开管理员特感菜单");
	RegAdminCmd("sm_ntgversion", 		SpecialVersionCMD, 	ADMFLAG_ROOT, "Neko多特版本&状态查询");
	RegAdminCmd("sm_reloadntgconfig", 	ReloadNTGConfig, 	ADMFLAG_ROOT, "重载多特配置文件");
	RegAdminCmd("sm_updatentgconfig",	UpdateNTGConfig, 	ADMFLAG_ROOT, "写入多特配置文件");
	RegAdminCmd("sm_resetntgconfig",	ReSetNTGConfig, 	ADMFLAG_ROOT, "重置多特配置文件");
}

#include "nspecials/native.sp"
#include "nspecials/cmd.sp"
#include "nspecials/hooks.sp"
#include "nspecials/menus.sp"
#include "nspecials/events.sp"
#include "nspecials/timer.sp"
#include "nspecials/api.sp"

public void OnConfigsExecuted()
{
	SetAISpawnInit();
	TgModeStartSet();
	UpdateSpawnWeight();
	UpdateSpawnDirChance();
	UpdateSpawnArea();
	UpdateSpawnDistance();

	for (int i = 1; i <= MaxClients; i++)
	{
		cleanplayerwait(i);
		MenuPageItem[i] = 0;
	}
}

public void OnMapEnd()
{
	SetSpecialRunning(false);
	IsPlayerLeftCP = false;
}

public void DifficultyChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CheckDifficulty();
}

public void HookChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	UpdateNekoAllSettings();
}

void SetCvarHook()
{
	NCvar[CGame_Difficulty].AddChangeHook(DifficultyChanged);

	for(int i=1;i < Cvar_Max;i++)
	{
		if(i == CGame_Difficulty)
			continue;

		NCvar[i].AddChangeHook(HookChanged);
	}
}