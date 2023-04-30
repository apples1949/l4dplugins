//本插件用來防止玩家換隊濫用的Bug
//禁止期間不能閒置、不能打指令換隊、亦不可按M換隊
//(離開安全區域才會生效)
//1.嚇了Witch或被Witch抓倒 期間禁止換隊 (防止Witch失去目標)
//2.被特感抓住期間 期間禁止換隊 (防止濫用特感控了無傷)
//3.人類玩家死亡 期間禁止換隊 (防止玩家故意死亡 然後跳隊裝B)
//4.換隊成功之後 必須等待數秒才能再換隊 (防止玩家頻繁換隊洗頻伺服器)
//5.出安全室之後 不得隨意換隊 (防止跳狗)
//6.玩家點燃火瓶、汽油或油桶期間禁止換隊 (防止友傷bug、防止Witch失去目標)
//7.玩家投擲火瓶、土製炸彈、膽汁期間禁止換隊 (防止Witch失去目標)
//8.玩家武器裝彈期間禁止換隊 (防止快速隊伍切換省略裝彈時間)
//9.特感玩家剛復活的期間 (防止切換特感)
//1.特感玩家抓住了人類 (防止jockey and ghost charger的爭議)
//111.管理員可以強制玩家更換隊伍 "sm_swapto <player> <team>"
/*
**Change team to Spectate
	"sm_afk"
	"sm_s"
	"sm_away"
	"sm_idle"
	"sm_spectate"
	"sm_spec"
	"sm_spectators"
	"sm_joinspectators"
	"sm_joinspectator"
	"sm_jointeam1"
	"sm_js"
	
**Change team to Survivor
	"sm_join"
	"sm_bot"
	"sm_jointeam"
	"sm_survivors"
	"sm_survivor"
	"sm_sur"
	"sm_joinsurvivors"
	"sm_joinsurvivor"
	"sm_jointeam2"
	"sm_jg"
	"sm_takebot"
	"sm_takeover"
	
**Change team to Infected
	"sm_infected"
	"sm_inf"
	"sm_joininfected"
	"sm_joininfecteds"
	"sm_jointeam3"
	"sm_zombie"
	
**Switch team to fully an observer
	"sm_observer"
	"sm_ob"
	"sm_observe"

**Adm force player to change team
	"sm_swapto", "sm_swapto <player1> [player2] ... [playerN] <teamnum> - swap all listed players to <teamnum> (1,2, or 3)"
*/


#define PLUGIN_VERSION 		"4.5"
#define PLUGIN_NAME			"[L4D(2)] AFK and Join Team Commands Improved"
#define PLUGIN_AUTHOR		"MasterMe & HarryPotter"
#define PLUGIN_DES			"Adds commands to let the player spectate and join team. (!afk, !survivors, !infected, etc.), but no change team abuse"
#define PLUGIN_URL			"https://steamcommunity.com/profiles/76561198026784913"

#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <left4dhooks>

#undef REQUIRE_PLUGIN
#include <unscramble> //compatible with r2comp_unscramble (https://forums.alliedmods.net/showthread.php?t=327711)

#define STEAMID_SIZE 		32
#define L4D_TEAM_NAME(%1) (%1 == 2 ? "Survivors" : (%1 == 3 ? "Infected" : (%1 == 1 ? "Spectators" : "Unknown")))
const int ARRAY_TEAM = 1;
const int ARRAY_COUNT = 2;
#define MODEL_CRATE				"models/props_junk/explosive_box001.mdl"
#define MODEL_GASCAN			"models/props_junk/gascan001a.mdl"
#define MODEL_BARREL			"models/props_industrial/barrel_fuel.mdl"

//convar
ConVar g_hCoolTime, g_hDeadSurvivorBlock, g_hGameTimeBlock, g_hSurvivorSuicideSeconds, g_hWeaponReloadBlock,
	g_hInfectedCapBlock, g_hInfectedAttackBlock, g_hWitchAttackBlock, g_hWPressMBlock, g_hImmueAccess,
	g_hTakeABreakBlock, g_hSpecCommandAccess, g_hInfCommandAccess, g_hSurCommandAccess,
	g_hObsCommandAccess,
	g_hTakeControlBlock, g_hBreakPropCooldown, g_hThrowableCooldown, g_hInfectedSpawnCooldown;
ConVar g_hGameMode, g_hZMaxPlayerZombies;

//value
char g_sImmueAcclvl[16], g_sSpecCommandAccesslvl[16], g_sInfCommandAccesslvl[16], 
	g_sSurCommandAccesslvl[16], g_sObsCommandAccesslvl[16];
bool g_bL4D2Version, g_bHasLeftSafeRoom, g_bMapStarted, g_bGameTeamSwitchBlock;
bool g_bDeadSurvivorBlock, g_bTakeControlBlock, g_bWeaponReloadBlock, g_bInfectedAttackBlock, 
	g_bWitchAttackBlock, g_bInfectedCapBlock, g_bPressMBlock, g_bTakeABreakBlock;
float g_fBreakPropCooldown, g_fThrowableCooldown, g_fSurvivorSuicideSeconds, g_fInfectedSpawnCooldown;
int g_iCvarGameTimeBlock, g_iCountDownTime, g_iZMaxPlayerZombies;

//arraylist
ArrayList nClientSwitchTeam;
ArrayList nClientAttackedByWitch[MAXPLAYERS+1]; //每個玩家被多少個witch攻擊
//timer
int g_iRoundStart, g_iPlayerSpawn;
Handle PlayerLeftStartTimer, CountDownTimer;

bool InCoolDownTime[MAXPLAYERS+1] = {false};//是否還有換隊冷卻時間
bool bClientJoinedTeam[MAXPLAYERS+1] = {false}; //在冷卻時間是否嘗試加入
float g_iSpectatePenaltTime[MAXPLAYERS+1] ;//各自的冷卻時間
float fBreakPropTime[MAXPLAYERS+1] ;//點燃火瓶、汽油或油桶的時間
float fThrowableTime[MAXPLAYERS+1] ;//投擲物品的時間
float fInfectedSpawnTime[MAXPLAYERS+1] ;//特感重生復活的時間
float ClientJoinSurvivorTime[MAXPLAYERS+1] ;//加入倖存者隊伍的時間
float fCoolTime;
int clientteam[MAXPLAYERS+1];//玩家換隊成功之後的隊伍
int iClientFlags[MAXPLAYERS+1];
int g_iGameMode;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DES,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

bool g_bLateLoad, g_Use_r2comp_unscramble = false;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead)
		g_bL4D2Version = false;
	else if (test == Engine_Left4Dead2 )
		g_bL4D2Version = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("l4d_afk_commands.phrases");

	RegConsoleCmd("sm_afk", TurnClientToSpectate);
	RegConsoleCmd("sm_s", TurnClientToSpectate);
	RegConsoleCmd("sm_away", TurnClientToSpectate);
	RegConsoleCmd("sm_idle", TurnClientToSpectate);
	RegConsoleCmd("sm_spectate", TurnClientToSpectate);
	RegConsoleCmd("sm_spec", TurnClientToSpectate);
	RegConsoleCmd("sm_spectators", TurnClientToSpectate);
	RegConsoleCmd("sm_joinspectators", TurnClientToSpectate);
	RegConsoleCmd("sm_joinspectator", TurnClientToSpectate);
	RegConsoleCmd("sm_jointeam1", TurnClientToSpectate);
	
	RegConsoleCmd("sm_jg", TurnClientToSurvivors);
	RegConsoleCmd("sm_join", TurnClientToSurvivors);
	RegConsoleCmd("sm_bot", TurnClientToSurvivors);
	RegConsoleCmd("sm_jointeam", TurnClientToSurvivors);
	RegConsoleCmd("sm_survivors", TurnClientToSurvivors);
	RegConsoleCmd("sm_survivor", TurnClientToSurvivors);
	RegConsoleCmd("sm_sur", TurnClientToSurvivors);
	RegConsoleCmd("sm_joinsurvivors", TurnClientToSurvivors);
	RegConsoleCmd("sm_joinsurvivor", TurnClientToSurvivors);
	RegConsoleCmd("sm_jointeam2", TurnClientToSurvivors);
	RegConsoleCmd("sm_takebot", TurnClientToSurvivors);
	RegConsoleCmd("sm_takeover", TurnClientToSurvivors);
	
	RegConsoleCmd("sm_infected", TurnClientToInfected);
	RegConsoleCmd("sm_infecteds", TurnClientToInfected);
	RegConsoleCmd("sm_inf", TurnClientToInfected);
	RegConsoleCmd("sm_joininfected", TurnClientToInfected);
	RegConsoleCmd("sm_jointeam3", TurnClientToInfected);
	RegConsoleCmd("sm_zombie", TurnClientToInfected);
	
	RegConsoleCmd("jointeam", WTF); // press M
	RegConsoleCmd("go_away_from_keyboard", WTF2); //esc -> take a break
	RegConsoleCmd("sb_takecontrol", WTF3);  //sb_takecontrol

	RegAdminCmd("sm_swapto", Command_SwapTo, ADMFLAG_BAN, "sm_swapto <player1> [player2] ... [playerN] <teamnum> - swap all listed players to <teamnum> (1,2, or 3)");
	RegConsoleCmd("sm_zs", ForceSurvivorSuicide, "Alive Survivor Suicide himself Command.");

	RegConsoleCmd("sm_observer", TurnClientToObserver, "Switch team to fully an observer.");
	RegConsoleCmd("sm_ob", TurnClientToObserver, "Switch team to fully an observer.");
	RegConsoleCmd("sm_observe", TurnClientToObserver, "Switch team to fully an observer.");

	g_hZMaxPlayerZombies = FindConVar("z_max_player_zombies");
	g_hCoolTime = CreateConVar("l4d_afk_commands_changeteam_cooltime_block", "10.0", "再次换边的冷却时间. (0=关闭)", FCVAR_NOTIFY, true, 0.0);
	g_hDeadSurvivorBlock = CreateConVar("l4d_afk_commands_deadplayer_block", "1", "如果为1, 死亡的生还者不能换边.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hGameTimeBlock = CreateConVar("l4d_afk_commands_during_game_seconds_block", "0", "玩家离开初始安全区域至少多少秒之前，玩家可以换边 (0=关闭).", FCVAR_NOTIFY, true, 0.0);
	g_hInfectedAttackBlock = CreateConVar("l4d_afk_commands_infected_attack_block", "1", "如果为1, 生还者被特感控住时不能换边.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hWitchAttackBlock = CreateConVar("l4d_afk_commands_witch_attack_block", "1", "如果为1, 生还者惊扰Witch或者被Witch攻击时无法换边.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hSurvivorSuicideSeconds = CreateConVar("l4d_afk_commands_suicide_allow_second", "30.0", "允许活着的生还者在加入队伍后至少多少秒后使用'!zs'指令自杀 (0=关闭)", FCVAR_NOTIFY, true, 0.0);
	g_hWeaponReloadBlock = CreateConVar("l4d_afk_commands_weapon_reload_block", "0", "如果为1, 生还者换弹时不能换边.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hInfectedCapBlock = CreateConVar("l4d_afk_commands_infected_cap_block", "1", "如果为1, 感染者玩家在扑向/骑着/冲向/拉着生还者时不能换边.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_hWPressMBlock = CreateConVar("l4d_afk_commands_pressM_block", "0", "如果为1, 阻止玩家在控制台使用 'jointeam' 指令. (这也会阻止玩家通过选择队伍菜单来转换队伍)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hTakeABreakBlock = CreateConVar("l4d_afk_commands_takeabreak_block", "1", "如果为1, 阻止玩家使用控制台中的'go_away_from_keyboard'命令. (这也会阻止玩家使用 'esc->take a break'来闲置)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hTakeControlBlock = CreateConVar("l4d_afk_commands_takecontrol_block", "1", "如果为1, 阻止玩家在控制台使用'sb_takecontrol' 指令.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hBreakPropCooldown = CreateConVar("l4d_afk_commands_igniteprop_cooltime_block", "5.0", "在玩家点燃 燃烧瓶、煤气罐、烟花盒或油桶后多少秒不能换边? (0=关闭).", FCVAR_NOTIFY, true, 0.0);
	g_hThrowableCooldown = CreateConVar("l4d_afk_commands_throwable_cooltime_block", "10.0", "生还者扔投抛后多久才能换边. (0=关闭).", FCVAR_NOTIFY, true, 0.0);
	g_hInfectedSpawnCooldown = CreateConVar("l4d_afk_commands_infected_spawn_cooltime_block", "5.0", "感染者玩家现身后多久才能换边. (0=关闭).", FCVAR_NOTIFY, true, 0.0);
	g_hImmueAccess = CreateConVar("l4d_afk_commands_immue_block_flag", "-1", "拥有这些权限的玩家无视所有换边限制 (无内容 = 所有人, -1: 没有人", FCVAR_NOTIFY);
	g_hSpecCommandAccess = CreateConVar("l4d_afk_commands_spec_access_flag", "", "拥有这些权限的玩家可以切换到旁观者阵营. (无内容 = 所有人, -1: 没有人", FCVAR_NOTIFY);
	g_hInfCommandAccess = CreateConVar("l4d_afk_commands_infected_access_flag", "", "拥有这些权限的玩家可以切换到感染者阵营. (无内容 = 所有人, -1: 没有人", FCVAR_NOTIFY);
	g_hSurCommandAccess = CreateConVar("l4d_afk_commands_survivor_access_flag", "", "拥有这些权限的玩家可以切换到感染者阵营. (无内容 = 所有人, -1: 没有人", FCVAR_NOTIFY);
	g_hObsCommandAccess = CreateConVar("l4d_afk_commands_observer_access_flag", "z", "拥有这些权限的玩家可以切换到观察员(ob)阵营. (无内容 = 所有人, -1: 没有人", FCVAR_NOTIFY);
	
	GetCvars();
	g_hGameMode = FindConVar("mp_gamemode");
	g_hGameMode.AddChangeHook(ConVarChange_CvarGameMode);
	g_hCoolTime.AddChangeHook(ConVarChanged_Cvars);
	g_hDeadSurvivorBlock.AddChangeHook(ConVarChanged_Cvars);
	g_hGameTimeBlock.AddChangeHook(ConVarChanged_Cvars);
	g_hInfectedAttackBlock.AddChangeHook(ConVarChanged_Cvars);
	g_hWitchAttackBlock.AddChangeHook(ConVarChanged_Cvars);
	g_hSurvivorSuicideSeconds.AddChangeHook(ConVarChanged_Cvars);
	g_hWeaponReloadBlock.AddChangeHook(ConVarChanged_Cvars);
	g_hInfectedCapBlock.AddChangeHook(ConVarChanged_Cvars);
	g_hWPressMBlock.AddChangeHook(ConVarChanged_Cvars);
	g_hTakeControlBlock.AddChangeHook(ConVarChanged_Cvars);
	g_hTakeABreakBlock.AddChangeHook(ConVarChanged_Cvars);
	g_hBreakPropCooldown.AddChangeHook(ConVarChanged_Cvars);
	g_hThrowableCooldown.AddChangeHook(ConVarChanged_Cvars);
	g_hInfectedSpawnCooldown.AddChangeHook(ConVarChanged_Cvars);
	g_hImmueAccess.AddChangeHook(ConVarChanged_Cvars);
	g_hSpecCommandAccess.AddChangeHook(ConVarChanged_Cvars);
	g_hInfCommandAccess.AddChangeHook(ConVarChanged_Cvars);
	g_hSurCommandAccess.AddChangeHook(ConVarChanged_Cvars);
	g_hObsCommandAccess.AddChangeHook(ConVarChanged_Cvars);
	g_hZMaxPlayerZombies.AddChangeHook(ConVarChanged_Cvars);
	
	HookEvent("witch_harasser_set", OnWitchWokeup);
	HookEvent("round_start", Event_RoundStart);
	if(g_bL4D2Version) HookEvent("survival_round_start", Event_SurvivalRoundStart,		EventHookMode_PostNoCopy); //生存模式之下計時開始之時 (一代沒有此事件)
	else HookEvent("create_panic_event" , Event_SurvivalRoundStart,		EventHookMode_PostNoCopy); //一代生存模式之下計時開始觸發屍潮
	HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd); //戰役過關到下一關的時候 (沒有觸發round_end)
	HookEvent("mission_lost", Event_RoundEnd); //戰役滅團重來該關卡的時候 (之後有觸發round_end)
	HookEvent("finale_vehicle_leaving", Event_RoundEnd); //救援載具離開之時  (沒有觸發round_end)
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerChangeTeam);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("break_prop",	Event_BreakProp,		EventHookMode_Pre);

	Clear();

	nClientSwitchTeam = new ArrayList(ByteCountToCells(STEAMID_SIZE));

	if( g_bLateLoad )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( IsClientInGame(i) && !IsFakeClient(i))
			{
				OnClientPostAdminCheck(i);
			}
		}

		CreateTimer(0.5, Timer_PluginStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}

	AutoExecConfig(true, "l4d_afk_commands");
	
	// Check if we have r2comp_unscramble.smx loaded
	g_Use_r2comp_unscramble = LibraryExists("r2comp_unscramble");
}

public void OnAllPluginsLoaded()
{
	if(PlayerLeftStartTimer == null) PlayerLeftStartTimer = CreateTimer(1.0, Timer_PlayerLeftStart, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
	Clear();
	ResetTimer();
	ClearDefault();
	
	delete nClientSwitchTeam;
	for (int i = 1; i <= MaxClients; i++)
	{
		delete nClientAttackedByWitch[i];
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "r2comp_unscramble"))
		g_Use_r2comp_unscramble = false;
}


public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "r2comp_unscramble"))
		g_Use_r2comp_unscramble = true;
}

public void OnMapStart()
{
	g_bMapStarted = true;
	nClientSwitchTeam.Clear();
}

public void OnMapEnd()
{
	g_bMapStarted = false;
	Clear();
	ResetTimer();
	ClearDefault();
}

public void OnConfigsExecuted()
{
	GameModeCheck();
}

void GameModeCheck()
{
	if(g_bMapStarted == false){
		g_iGameMode = 0;
		return;
	}
		
	int entity = CreateEntityByName("info_gamemode");
	if( IsValidEntity(entity) )
	{
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
			RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
	}
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iGameMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iGameMode = 3;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iGameMode = 2;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iGameMode = 2;
}

public Action Command_SwapTo(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] %T", "Usage: sm_swapto", client);
		return Plugin_Handled;
	}
	
	char teamStr[64];
	GetCmdArg(args, teamStr, sizeof(teamStr));
	int team = StringToInt(teamStr);
	if(0>=team||team>=4)
	{
		ReplyToCommand(client, "[SM] %T", "Invalid team Number", client, teamStr);
		return Plugin_Handled;
	}
	
	int player_id;

	char player[64];
	
	for(int i = 0; i < args - 1; i++)
	{
		GetCmdArg(i+1, player, sizeof(player));
		player_id = FindTarget(client, player, true /*nobots*/, false /*immunity*/);
		
		if(player_id == -1)
			continue;
		
		if(team == 1)
			ChangeClientTeam(player_id,1);
		else if(team == 2)
		{
			int bot = FindBotToTakeOver(true);
			if (bot==0)
			{
				bot = FindBotToTakeOver(false);
			}
			if (bot==0)
			{
				ChangeClientTeam(player_id,2);
				return Plugin_Handled;
			}

			L4D_SetHumanSpec(bot, player_id);
			L4D_TakeOverBot(player_id);
		}
		else if (team == 3)
			ChangeClientTeam(player_id,3);
			
		if(client != player_id) C_PrintToChatAll("[{olive}VS{default}] %t", "ADM Swap Player Team", client, player_id, L4D_TEAM_NAME(team));
	}
	
	return Plugin_Handled;
}

public Action ForceSurvivorSuicide(int client, int args)
{
	if (g_fSurvivorSuicideSeconds > 0.0 && client && GetClientTeam(client) == 2 && !IsFakeClient(client) && IsPlayerAlive(client))
	{
		if(g_bHasLeftSafeRoom == false)
		{
			PrintHintText(client, "[VS] %T","You wish!",client);
			return Plugin_Handled;
		}

		if(GetInfectedAttacker(client) != -1)
		{
			PrintHintText(client, "[VS] %T","In your dreams!",client);
			return Plugin_Handled;
		}
		
		if( nClientAttackedByWitch[client].Length != 0 )
		{
			PrintHintText(client, "[VS] %T","Not on your life!",client);
			return Plugin_Handled;
		}

		if( GetEngineTime() - ClientJoinSurvivorTime[client] < g_fSurvivorSuicideSeconds)
		{
			PrintHintText(client, "[VS] %T","Not gonna happen!",client);
			return Plugin_Handled;
		}

		C_PrintToChatAll("[{olive}VS{default}] %T","Suicide",client,client);
		ForcePlayerSuicide(client);
	}
	return Plugin_Handled;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(!victim || !IsClientAndInGame(victim)) return;
	ResetAttackedByWitch(victim);

	if((g_bGameTeamSwitchBlock == true && g_iCvarGameTimeBlock > 0) && IsClientInGame(victim) && !IsFakeClient(victim) && GetClientTeam(victim) == 2)
	{
		char steamID[STEAMID_SIZE];
		GetClientAuthId(victim, AuthId_Steam2,steamID, STEAMID_SIZE);
		int index = nClientSwitchTeam.FindString(steamID);
		if (index == -1) {
			nClientSwitchTeam.PushString(steamID);
			nClientSwitchTeam.Push(4);
		}
		else
		{
			nClientSwitchTeam.Set(index + ARRAY_TEAM, 4);
		}			
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	if( g_iPlayerSpawn == 0 && g_iRoundStart == 1 )
		CreateTimer(0.5, Timer_PluginStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;	

	int userid = event.GetInt("userid");
	int player = GetClientOfUserId(userid);
	if(player > 0 && player <=MaxClients && IsClientInGame(player) && !IsFakeClient(player))
	{
		if (GetClientTeam(player) == 2)
		{
			CreateTimer(2.0,checksurvivorspawn, userid);
			ClientJoinSurvivorTime[player] = GetEngineTime();
		}
		else if (GetClientTeam(player) == 3)
		{
			fInfectedSpawnTime[player] = GetEngineTime() + g_fInfectedSpawnCooldown;
		}
	}
}

public void Event_BreakProp(Event event, const char[] name, bool dontBroadcast)
{
	char sTemp[42];
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2) return;

	int entity = event.GetInt("entindex");
	GetEdictClassname(entity, sTemp, sizeof(sTemp));
	if( strcmp(sTemp, "prop_physics") == 0 || strcmp(sTemp, "prop_fuel_barrel") == 0)
	{
		GetEntPropString(entity, Prop_Data, "m_ModelName", sTemp, sizeof(sTemp));
		if( strcmp(sTemp, MODEL_CRATE) == 0 ||
			strcmp(sTemp, MODEL_GASCAN) == 0  || // only trigger gas can when not picked up yet
			strcmp(sTemp, MODEL_BARREL) == 0 )
		{
			if(g_fBreakPropCooldown > 0.0) fBreakPropTime[client] = GetEngineTime() + g_fBreakPropCooldown;
		}
	}
}

public Action checksurvivorspawn(Handle timer, int client)
{
	client = GetClientOfUserId(client);
	if(g_bGameTeamSwitchBlock == true && g_iCvarGameTimeBlock > 0 && client && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		char steamID[STEAMID_SIZE];
		GetClientAuthId(client, AuthId_Steam2,steamID, STEAMID_SIZE);
		int index = nClientSwitchTeam.FindString(steamID);
		if (index == -1) {
			nClientSwitchTeam.PushString(steamID);
			nClientSwitchTeam.Push(2);
		}
		else
		{
			nClientSwitchTeam.Set(index + ARRAY_TEAM, 2);
		}			
	}

	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	if(!IsFakeClient(client)) iClientFlags[client] = GetUserFlagBits(client);
}
public void OnClientPutInServer(int client)
{
	Clear(client);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	Clear(client);
}

public Action OnTakeDamage(int victim, int &attacker, int  &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!IsValidEdict(victim) || !IsValidEdict(attacker) || !IsValidEdict(inflictor) ) { return Plugin_Continue; }
	
	if(!IsClientAndInGame(victim) || GetClientTeam(victim) != 2) { return Plugin_Continue; }
	
	char sClassname[64];
	GetEntityClassname(inflictor, sClassname, 64);
	if(StrEqual(sClassname, "witch"))
	{
		AddWitchAttack(attacker, victim);
	}
	return Plugin_Continue;
}

public void OnWitchWokeup(Event event, const char[] name, bool dontBroadcast) 
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	int witchid = event.GetInt("witchid");
	
	if(client > 0 && client <= MaxClients &&  IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		AddWitchAttack(witchid, client);
	}
	
}

public void OnEntityDestroyed(int entity)
{
	if( entity > 0 && IsValidEdict(entity) )
	{
		char strClassName[64];
		GetEdictClassname(entity, strClassName, sizeof(strClassName));
		if(StrEqual(strClassName, "witch"))	
		{
			RemoveWitchAttack(entity);
		}
	}
}

public void Event_PlayerChangeTeam(Event event, const char[] name, bool dontBroadcast) 
{
	CreateTimer(0.1, ClientReallyChangeTeam, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE); // check delay
}

public void ConVarChange_CvarGameMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GameModeCheck();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bDeadSurvivorBlock = g_hDeadSurvivorBlock.BoolValue;
	g_iCvarGameTimeBlock = g_hGameTimeBlock.IntValue;
	g_bInfectedAttackBlock = g_hInfectedAttackBlock.BoolValue;
	g_bWitchAttackBlock = g_hWitchAttackBlock.BoolValue;
	g_hSpecCommandAccess.GetString(g_sSpecCommandAccesslvl,sizeof(g_sSpecCommandAccesslvl));
	g_hInfCommandAccess.GetString(g_sInfCommandAccesslvl,sizeof(g_sInfCommandAccesslvl));
	g_hSurCommandAccess.GetString(g_sSurCommandAccesslvl,sizeof(g_sSurCommandAccesslvl));
	g_hObsCommandAccess.GetString(g_sObsCommandAccesslvl,sizeof(g_sObsCommandAccesslvl));
	g_hImmueAccess.GetString(g_sImmueAcclvl,sizeof(g_sImmueAcclvl));
	g_fSurvivorSuicideSeconds = g_hSurvivorSuicideSeconds.FloatValue;
	g_bWeaponReloadBlock = g_hWeaponReloadBlock.BoolValue;
	g_bInfectedCapBlock = g_hInfectedCapBlock.BoolValue;
	g_bPressMBlock = g_hWPressMBlock.BoolValue;
	g_bTakeABreakBlock = g_hTakeABreakBlock.BoolValue;
	g_bTakeControlBlock = g_hTakeControlBlock.BoolValue;
	fCoolTime = g_hCoolTime.FloatValue;
	g_fBreakPropCooldown = g_hBreakPropCooldown.FloatValue;
	g_fThrowableCooldown = g_hThrowableCooldown.FloatValue;
	g_fInfectedSpawnCooldown = g_hInfectedSpawnCooldown.FloatValue;
	g_iZMaxPlayerZombies = g_hZMaxPlayerZombies.IntValue;
	
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) 
{
	ResetTimer();
	ClearDefault();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	for (int i = 0; i < (nClientSwitchTeam.Length / ARRAY_COUNT); i++) {
		nClientSwitchTeam.Set( (i * ARRAY_COUNT) + ARRAY_TEAM, 0);
	}
	
	Clear();

	if( g_iPlayerSpawn == 1 && g_iRoundStart == 0 )
		CreateTimer(0.5, Timer_PluginStart, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

public void Event_SurvivalRoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	if(g_bHasLeftSafeRoom == true || L4D_GetGameModeType() != GAMEMODE_SURVIVAL) return;
	
	GameStart();
}

Action Timer_PluginStart(Handle timer)
{
	ClearDefault();

	if(L4D_GetGameModeType() != GAMEMODE_SURVIVAL)
	{
		delete PlayerLeftStartTimer;
		PlayerLeftStartTimer = CreateTimer(1.0, Timer_PlayerLeftStart, _, TIMER_REPEAT);
	}

	return Plugin_Continue;
}

Action Timer_PlayerLeftStart(Handle Timer)
{
	if (L4D_HasAnySurvivorLeftSafeArea())
	{
		GameStart();

		PlayerLeftStartTimer = null;
		return Plugin_Stop;
	}
	return Plugin_Continue; 
}

void GameStart()
{
	g_bHasLeftSafeRoom = true;
	g_iCountDownTime = g_iCvarGameTimeBlock;
	if(g_iCountDownTime > 0)
	{
		delete CountDownTimer;
		CountDownTimer = CreateTimer(1.0, Timer_CountDown, _, TIMER_REPEAT);
	}
}

Action Timer_CountDown(Handle timer)
{
	if(g_iCountDownTime <= 0) 
	{
		g_bGameTeamSwitchBlock = true;
		CountDownTimer = null;
		return Plugin_Stop;
	}
	g_iCountDownTime--;
	return Plugin_Continue;
}

void Clear(int client = -1)
{
	if(client == -1)
	{
		for(int i = 1; i <= MaxClients; i++)
		{	
			InCoolDownTime[i] = false;
			bClientJoinedTeam[i] = false;
			clientteam[i] = 0;
			fBreakPropTime[i] = 0.0;
			fThrowableTime[i] = 0.0;
			fInfectedSpawnTime[i] = 0.0;
			ResetAttackedByWitch(i);
		}
		g_bHasLeftSafeRoom = false;
		g_bGameTeamSwitchBlock = false;
	}	
	else
	{
		InCoolDownTime[client] = false;
		bClientJoinedTeam[client] = false;
		clientteam[client] = 0;
		fBreakPropTime[client] = 0.0;
		fThrowableTime[client] = 0.0;
		fInfectedSpawnTime[client] = 0.0;
		ResetAttackedByWitch(client);
	}

}

public Action TurnClientToSpectate(int client, int argCount)
{
	if (client == 0)
	{
		PrintToServer("[VS] command cannot be used by server.");
		return Plugin_Handled;
	}
	
	if (GetClientTeam(client) == 1)
	{
		if(IsClientIdle(client))
		{
			PrintHintText(client, "[VS] %T","Idle",client);
		}

		return Plugin_Handled;
	}
	
	if(Is_AFK_COMMAND_Block()) return Plugin_Handled;
	
	if(HasAccess(client, g_sSpecCommandAccesslvl) == false)
	{
		PrintHintText(client, "[VS] %T","You don't have access to change team to spectator",client);
		return Plugin_Handled;
	}

	int iTeam = GetClientTeam(client);
	if(iTeam != 1)
	{
		if(CanClientChangeTeam(client,1) == false) return Plugin_Handled;
		
		if(iTeam == 2 && g_iGameMode != 2)
		{
			if(IsPlayerAlive(client)) 
			{
				L4D_GoAwayFromKeyboard(client);
				clientteam[client] = 2;
				return Plugin_Handled;
			}
			else
			{
				ChangeClientTeam(client, 1);
			}
		}
		else ChangeClientTeam(client, 1);
		
		clientteam[client] = 1;
		StartChangeTeamCoolDown(client);
	}
	else
	{
		ChangeClientTeam(client, 3);
		CreateTimer(0.1, Timer_Respectate, client, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Handled;
}

public Action TurnClientToObserver(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("[VS] command cannot be used by server.");
		return Plugin_Handled;
	}
	
	if(Is_AFK_COMMAND_Block()) return Plugin_Handled;
	
	if(HasAccess(client, g_sObsCommandAccesslvl) == false)
	{
		PrintHintText(client, "[VS] %T","You don't have access to be an observer",client);
		return Plugin_Handled;
	}

	if(GetClientTeam(client) != 1)
	{
		if(CanClientChangeTeam(client,1) == false) return Plugin_Handled;

		ChangeClientTeam(client, 1);
	}
	else
	{
		if(IsClientIdle(client))
		{
			L4D_TakeOverBot(client);
			ChangeClientTeam(client, 1);
			return Plugin_Handled;
		}
		
		ChangeClientTeam(client, 3);
		CreateTimer(0.1, Timer_Respectate, client, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Handled;
}

public Action Timer_Respectate(Handle timer, int client)
{
	ChangeClientTeam(client, 1);

	return Plugin_Continue;
}

public Action TurnClientToSurvivors(int client, int args)
{ 
	if (client == 0)
	{
		PrintToServer("[VS] command cannot be used by server.");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) == 2)			//if client is survivor
	{
		PrintHintText(client, "[VS] %T","You are already in survivor team.",client);
		return Plugin_Handled;
	}
	if (IsClientIdle(client))
	{
		PrintHintText(client, "[VS] %T","You are in idle, Press Left Mouse to play",client);
		return Plugin_Handled;
	}
	
	if(Is_AFK_COMMAND_Block()) return Plugin_Handled;
	
	if(HasAccess(client, g_sSurCommandAccesslvl) == false)
	{
		PrintHintText(client, "[VS] %T.","You don't have access to change team to survivor",client);
		return Plugin_Handled;
	}

	if(CanClientChangeTeam(client,2) == false) return Plugin_Handled;
	
	int maxSurvivorSlots = GetTeamMaxSlots(2);
	int survivorUsedSlots = GetTeamHumanCount(2);
	int freeSurvivorSlots = (maxSurvivorSlots - survivorUsedSlots);

	//PrintToChatAll("Number of Survivor Slots %d.\nNumber of Survivor Players %d.\nNumber of Free Slots %d.", maxSurvivorSlots, survivorUsedSlots, freeSurvivorSlots);
	
	if (freeSurvivorSlots <= 0)
	{
		PrintHintText(client, "[VS] %T","Survivor team is full now.",client);
		return Plugin_Handled;
	}
	else
	{
		int bot = FindBotToTakeOver(true)	;
		if (bot==0)
		{
			bot = FindBotToTakeOver(false);
		}
		if (bot==0) return Plugin_Handled;
		
		if(g_iGameMode != 2) //coop/survival
		{
			if(GetClientTeam(client) == 3) ChangeClientTeam(client,1);

			if(IsPlayerAlive(bot))
			{
				L4D_SetHumanSpec(bot, client);
				SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
			}
			else
			{
				L4D_SetHumanSpec(bot, client);
				L4D_TakeOverBot(client);	
				clientteam[client] = 2;	
				StartChangeTeamCoolDown(client);
			}
		}
		else //versus
		{
			L4D_SetHumanSpec(bot, client);
			L4D_TakeOverBot(client);	
			clientteam[client] = 2;	
			StartChangeTeamCoolDown(client);
		}
	}
	return Plugin_Handled;
}

public Action TurnClientToInfected(int client, int args)
{ 
	if (client == 0)
	{
		PrintToServer("[VS] command cannot be used by server.");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) == 3)			//if client is Infected
	{
		PrintHintText(client, "[VS] %T","You are already in infected team.",client);
		return Plugin_Handled;
	}
	
	if(Is_AFK_COMMAND_Block()) return Plugin_Handled;
	
	if(HasAccess(client, g_sInfCommandAccesslvl) == false)
	{
		PrintHintText(client, "[VS] %T","You don't have access to change team to Infected",client);
		return Plugin_Handled;
	}

	if(CanClientChangeTeam(client,3) == false) return Plugin_Handled;

	int maxInfectedSlots = GetTeamMaxSlots(3);
	int infectedUsedSlots = GetTeamHumanCount(3);
	int freeInfectedSlots = (maxInfectedSlots - infectedUsedSlots);
	if (freeInfectedSlots <= 0)
	{
		PrintHintText(client, "[VS] %T","Infected team is full now.",client);
		return Plugin_Handled;
	}
	if(g_iGameMode != 2)
	{
		return Plugin_Handled;
	}
	
	ChangeClientTeam(client, 3);
	clientteam[client] = 3;
	
	StartChangeTeamCoolDown(client);
	
	return Plugin_Handled;
}

int GetTeamMaxSlots(int team)
{
	int teammaxslots = 0;
	if(team == 2)
	{
		for(int i = 1; i < (MaxClients + 1); i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == team)
			{
				teammaxslots++;
			}
		}
	}
	else if (team == 3)
	{
		return g_iZMaxPlayerZombies;
	}
	
	return teammaxslots;
}
int GetTeamHumanCount(int team)
{
	int humans = 0;
	
	int i;
	for(i = 1; i < (MaxClients + 1); i++)
	{
		if(IsClientInGameHuman(i) && GetClientTeam(i) == team)
		{
			humans++;
		}
	}
	
	return humans;
}
//client is in-game and not a bot and not spec
bool IsClientInGameHuman(int client)
{
	return IsClientInGame(client) && !IsFakeClient(client) && ((GetClientTeam(client) == 2 || GetClientTeam(client) == 3));
}

public bool IsInteger(char[] buffer)
{
    int len = strlen(buffer);
    for (int i = 0; i < len; i++)
    {
        if ( !IsCharNumeric(buffer[i]) )
            return false;
    }

    return true;    
}

public Action WTF(int client, int args) //press m (jointeam)
{
	if (client == 0)
	{
		PrintToServer("[VS] command cannot be used by server.");
		return Plugin_Handled;
	}

	if(Is_AFK_COMMAND_Block()) return Plugin_Handled;

	if(args > 2) return Plugin_Handled;

	bool bHaveAccess = HasAccess(client, g_sImmueAcclvl);
	if(g_bPressMBlock == true && bHaveAccess == false) 
	{
		PrintHintText(client, "[VS] %T","This function has been blocked!",client);	
		return Plugin_Handled;
	}

	if(args == 2)
	{
		char arg1[64];
		GetCmdArg(1, arg1, 64);
		char arg2[64];
		GetCmdArg(2, arg2, 64);
		if(StrEqual(arg1,"2") &&
			(StrEqual(arg2,"Nick") ||
			 StrEqual(arg2,"Ellis") ||
			 StrEqual(arg2,"Rochelle") ||
			 StrEqual(arg2,"Coach") ||
			 StrEqual(arg2,"Bill") ||
			 StrEqual(arg2,"Zoey") ||
			 StrEqual(arg2,"Francis") ||
			 StrEqual(arg2,"Louis") 
			)
		)
		{	
			if(g_bHasLeftSafeRoom == false) return Plugin_Continue;
			if(CanClientChangeTeam(client, 2, bHaveAccess)  == false) return Plugin_Handled;
			return Plugin_Continue;
		}
		ReplyToCommand(client, "Usage: jointeam 2 <character_name>");	
		return Plugin_Handled;
	}
	
	char arg1[64];
	GetCmdArg(1, arg1, 64);
	if(IsInteger(arg1))
	{
		int iteam = StringToInt(arg1);
		if(iteam == 2)
		{
			TurnClientToSurvivors(client,0);
			return Plugin_Handled;
		}
		else if(iteam == 3)
		{
			TurnClientToInfected(client,0);
			return Plugin_Handled;
		}
		else if(iteam == 1)
		{
			TurnClientToSpectate(client,0);
			return Plugin_Handled;
		}
		ReplyToCommand(client, "Usage: jointeam <1,2,3>");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action WTF2(int client, int args) //esc->take a break (go_away_from_keyboard)
{
	if (client == 0)
	{
		PrintToServer("[VS] command cannot be used by server.");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) == 1)
	{
		if(IsClientIdle(client))
		{
			PrintHintText(client, "[VS] %T","Idle",client);
		}
		
		return Plugin_Handled;
	}

	if (GetClientTeam(client) == 3)			//if client is Infected
	{
		PrintHintText(client, "[VS] %T","Infected can't go idle",client);
		return Plugin_Handled;
	}
	
	if(Is_AFK_COMMAND_Block()) return Plugin_Handled;
	
	bool bHaveAccess = HasAccess(client, g_sImmueAcclvl);
	if(g_bTakeABreakBlock == true && bHaveAccess == false) 
	{
		PrintHintText(client, "[VS] %T","This function has been blocked!",client);	
		return Plugin_Handled;
	}

	if(g_bHasLeftSafeRoom == false) return Plugin_Continue;
	if(CanClientChangeTeam(client, 1, bHaveAccess) == false) return Plugin_Handled;
	
	RequestFrame(go_away_from_keyboard_NextFrame, GetClientUserId(client));
	return Plugin_Continue;
}

public void go_away_from_keyboard_NextFrame(any iUserID)
{
	int client = GetClientOfUserId(iUserID);
	
	if(!client || !IsClientInGame(client))
		return;

	if(GetClientTeam(client) == 1)
	{
		if(IsClientIdle(client))
		{
			clientteam[client] = 2;
			//StartChangeTeamCoolDown(client);
		}
		else
		{
			clientteam[client] = 1;
			StartChangeTeamCoolDown(client);
		}
	}	
}

public Action WTF3(int client, int args) //sb_takecontrol
{
	if (client == 0)
	{
		PrintToServer("[VS] command cannot be used by server.");
		return Plugin_Handled;
	}

	if(Is_AFK_COMMAND_Block()) return Plugin_Handled;

	if(args > 1) return Plugin_Handled;

	bool bHaveAccess = HasAccess(client, g_sImmueAcclvl);
	if(g_bTakeControlBlock == true && bHaveAccess == false) 
	{
		ReplyToCommand(client, "[VS] %T","This function has been blocked!",client);	
		return Plugin_Handled;
	}

	if(args == 1)
	{
		char arg1[64];
		GetCmdArg(1, arg1, 64);
		if(StrEqual(arg1,"Nick") ||
			 StrEqual(arg1,"Ellis") ||
			 StrEqual(arg1,"Rochelle") ||
			 StrEqual(arg1,"Coach") ||
			 StrEqual(arg1,"Bill") ||
			 StrEqual(arg1,"Zoey") ||
			 StrEqual(arg1,"Francis") ||
			 StrEqual(arg1,"Louis") 
		)
		{
			if(g_bHasLeftSafeRoom == false) return Plugin_Continue;
			if(CanClientChangeTeam(client, 2, bHaveAccess) == false) return Plugin_Handled;
			return Plugin_Continue;
		}
		ReplyToCommand(client, "Usage: sb_takecontrol <character_name>");	
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

bool IsClientAndInGame(int index)
{
	if (index > 0 && index <= MaxClients)
	{
		return IsClientInGame(index);
	}
	return false;
}

bool IsClientIdle(int client)
{
	if(GetClientTeam(client) != 1)
		return false;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			if(HasEntProp(i, Prop_Send, "m_humanSpectatorUserID"))
			{
				if(GetClientOfUserId(GetEntProp(i, Prop_Send, "m_humanSpectatorUserID")) == client)
					return true;
			}
		}
	}
	return false;
}

int FindBotToTakeOver(bool alive)
{
	int iClientCount, iClients[MAXPLAYERS+1];
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i)==2 && !HasIdlePlayer(i) && IsPlayerAlive(i) == alive)
		{
			iClients[iClientCount++] = i;
		}
	}

	return (iClientCount == 0) ? 0 : iClients[GetRandomInt(0, iClientCount - 1)];
}

bool HasIdlePlayer(int bot)
{
	if(IsClientInGame(bot) && IsFakeClient(bot) && GetClientTeam(bot) == 2 && IsPlayerAlive(bot))
	{
		if(HasEntProp(bot, Prop_Send, "m_humanSpectatorUserID"))
		{
			if(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID") > 0)
			{
				return true;
			}
		}
	}
	return false;
}

bool CanClientChangeTeam(int client, int changeteam = 0, bool bIsAdm = false)
{ 
	if(g_bHasLeftSafeRoom == false || bIsAdm || HasAccess(client, g_sImmueAcclvl)) return true;

	int team = GetClientTeam(client);
	if(team == 2)
	{
		if ( GetInfectedAttacker(client) != -1 && g_bInfectedAttackBlock == true)
		{
			PrintHintText(client, "[VS] %T","Infected Attack Block",client);
			return false;
		}	
		
		if( g_bWitchAttackBlock == true && nClientAttackedByWitch[client].Length != 0)
		{
			PrintHintText(client, "[VS] %T","Witch Attack Block",client);
			return false;
		}

		if( g_fBreakPropCooldown > 0.0 && (fBreakPropTime[client] - GetEngineTime() > 0.0) )
		{
			PrintHintText(client, "[VS] %T.", "Can not change team after ignite",client);
			return false;
		}

		if( g_fThrowableCooldown > 0.0 && (fThrowableTime[client] - GetEngineTime() > 0.0) )
		{
			PrintHintText(client, "[VS] %T","Can not change team after throw",client);
			return false;	
		}

		if(g_bDeadSurvivorBlock == true && IsPlayerAlive(client) == false)
		{
			PrintHintText(client, "[VS] %T","Can not change team as dead survivor",client);
			return false;
		}
		
		if(g_bWeaponReloadBlock == true && IsPlayerAlive(client))
		{
			int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if (iActiveWeapon > MaxClients && IsValidEntity(iActiveWeapon)) {
				if(GetEntProp(iActiveWeapon, Prop_Send, "m_bInReload")) //Survivor reloading
				{
					PrintHintText(client, "[VS] %T","Can not change team while reloading weapon",client);
					return false;
				}
			}
		}
	}
	else if(team == 3)
	{
		if(GetSurvivorVictim(client)!= -1 && g_bInfectedCapBlock == true)
		{
			PrintHintText(client, "[VS] %T","Infected Cap Block",client);
			return false;
		}

		if( g_fInfectedSpawnCooldown > 0.0 && (fInfectedSpawnTime[client] - GetEngineTime() > 0.0) && IsPlayerAlive(client) && !IsPlayerGhost(client))
		{
			PrintHintText(client, "[VS] %T","Can not change team after Spawn as a special infected",client);
			return false;	
		}
	}
	
	if(InCoolDownTime[client])
	{
		bClientJoinedTeam[client] = true;
		CPrintToChat(client, "[{olive}VS{default}] %T","Please wait",client, g_iSpectatePenaltTime[client]);
		return false;
	}

	if((g_bGameTeamSwitchBlock == true && g_iCvarGameTimeBlock > 0) && g_bHasLeftSafeRoom && GetClientTeam(client) != 1 && changeteam != 1) 
	{
		CPrintToChat(client, "[{olive}VS{default}] %T","Can not change team during the game!!",client);
		return false;
	}
	
	return true;
}

void StartChangeTeamCoolDown(int client)
{
	if( InCoolDownTime[client] || g_bHasLeftSafeRoom == false || HasAccess(client, g_sImmueAcclvl)) return;
	if(fCoolTime > 0.0)
	{
		InCoolDownTime[client] = true;
		g_iSpectatePenaltTime[client] = fCoolTime;
		CreateTimer(0.25, Timer_CanJoin, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action ClientReallyChangeTeam(Handle timer, int usrid)
{
	int client = GetClientOfUserId(usrid);
	if(!IsClientAndInGame(client) || IsFakeClient(client)) return Plugin_Continue;

	int newteam = GetClientTeam(client);
	bool bIdle = IsClientIdle(client);
	switch(newteam)
	{
		case 1:
		{
			if(!bIdle) CleanUpStateAndMusic(client);
		}
		case 2:
		{
			ClientJoinSurvivorTime[client] = GetEngineTime();
		}
	}

	if(HasAccess(client, g_sImmueAcclvl)) return Plugin_Continue;

	if(g_bGameTeamSwitchBlock == true && g_iCvarGameTimeBlock > 0)
	{
		if(newteam != 1)
		{
			char steamID[STEAMID_SIZE];
			GetClientAuthId(client, AuthId_Steam2, steamID, STEAMID_SIZE);
			int index = nClientSwitchTeam.FindString(steamID);
			if (index == -1) {
				nClientSwitchTeam.PushString(steamID);
				nClientSwitchTeam.Push(newteam);
			}
			else
			{
				int oldteam = nClientSwitchTeam.Get(index + ARRAY_TEAM);
				if(!g_bHasLeftSafeRoom || oldteam == 0)
					nClientSwitchTeam.Set(index + ARRAY_TEAM, newteam);
				else
				{
					//PrintToChatAll("%N newteam: %d, oldteam: %d",client,newteam,oldteam);
					if(newteam != oldteam)
					{
						if(oldteam == 4 && !(newteam == 2 && !IsPlayerAlive(client)) ) //player survivor death
						{
							ChangeClientTeam(client,1);
							CPrintToChat(client,"[{olive}VS{default}] %T","You are a dead survivor",client);
						}
						else if(oldteam != 4)
						{
							ChangeClientTeam(client,1);
							CPrintToChat(client,"[{olive}VS{default}] %T","Go Back Your Team",client,(oldteam == 2) ? "Survivor" : "Infected");
						}
					}
				}
			}		
		}
	}
	
	if(g_bHasLeftSafeRoom && InCoolDownTime[client]) return Plugin_Continue;
	
	//PrintToChatAll("client: %N change Team: %d newteam:%d",client,newteam,clientteam[client]);
	if(newteam != clientteam[client])
	{ 
		if(newteam == 1 && bIdle) return Plugin_Continue;

		if(clientteam[client] != 0) StartChangeTeamCoolDown(client);
		clientteam[client] = newteam;		
	}

	return Plugin_Continue;
}

public Action Timer_CanJoin(Handle timer, int client)
{
	if (!InCoolDownTime[client] || 
	!IsClientInGame(client) || 
	IsFakeClient(client))//if client disconnected or is fake client or take a break on player bot
	{
		InCoolDownTime[client] = false;
		return Plugin_Stop;
	}

	
	if (g_iSpectatePenaltTime[client] != 0)
	{
		g_iSpectatePenaltTime[client]-=0.25;
		if(GetClientTeam(client)!=clientteam[client])
		{	
			bClientJoinedTeam[client] = true;
			CPrintToChat(client, "[{olive}VS{default}] %T","Please wait",client, g_iSpectatePenaltTime[client]);
			ChangeClientTeam(client, 1);clientteam[client]=1;
			return Plugin_Continue;
		}
	}
	else if (g_iSpectatePenaltTime[client] <= 0)
	{
		if(GetClientTeam(client)!=clientteam[client])
		{	
			bClientJoinedTeam[client] = true;
			CPrintToChat(client, "[{olive}VS{default}]] %T","Please wait",client, g_iSpectatePenaltTime[client]);
			ChangeClientTeam(client, 1);clientteam[client]=1;
		}
		if (bClientJoinedTeam[client])
		{
			PrintHintText(client, "[VS] %T","You can change team now.",client);	//only print this hint text to the spectator if he tried to join team, and got swapped before
		}
		InCoolDownTime[client] = false;
		bClientJoinedTeam[client] = false;
		g_iSpectatePenaltTime[client] = fCoolTime;
		return Plugin_Stop;
	}
	
	
	return Plugin_Continue;
}

int GetInfectedAttacker(int client)
{
	int attacker;

	if(g_bL4D2Version)
	{
		/* Charger */
		attacker = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
		if (attacker > 0)
		{
			return attacker;
		}

		attacker = GetEntPropEnt(client, Prop_Send, "m_carryAttacker");
		if (attacker > 0)
		{
			return attacker;
		}
		/* Jockey */
		attacker = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
		if (attacker > 0)
		{
			return attacker;
		}
	}

	/* Hunter */
	attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	if (attacker > 0)
	{
		return attacker;
	}

	/* Smoker */
	attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (attacker > 0)
	{
		return attacker;
	}

	return -1;
}

int GetSurvivorVictim(int client)
{
	int victim;

	if(g_bL4D2Version)
	{
		/* Charger */
		victim = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
		if (victim > 0)
		{
			return victim;
		}

		victim = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
		if (victim > 0)
		{
			return victim;
		}

		/* Jockey */
		victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
		if (victim > 0)
		{
			return victim;
		}
	}

    /* Hunter */
	victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
	if (victim > 0)
	{
		return victim;
 	}

    /* Smoker */
 	victim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");
	if (victim > 0)
	{
		return victim;	
	}

	return -1;
}

bool HasAccess(int client, char[] g_sAcclvl)
{
	// no permissions set
	if (strlen(g_sAcclvl) == 0)
		return true;

	else if (StrEqual(g_sAcclvl, "-1"))
		return false;

	// check permissions
	if ( iClientFlags[client] & ReadFlagString(g_sAcclvl) )
	{
		return true;
	}

	return false;
}

void ResetAttackedByWitch(int client) {
	delete nClientAttackedByWitch[client];
	nClientAttackedByWitch[client] = new ArrayList();
}

void AddWitchAttack(int witchid, int client)
{
	if(nClientAttackedByWitch[client].FindValue(witchid) == -1)
	{
		nClientAttackedByWitch[client].Push(witchid);
	}
}

void RemoveWitchAttack(int witchid)
{
	int index;
	for (int client = 1; client <= MaxClients; client++) {
		if ( (index = nClientAttackedByWitch[client].FindValue(witchid)) != -1 ) {
			nClientAttackedByWitch[client].Erase(index);
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(
		classname[0] == 'm' ||
		classname[0] == 'p' ||
		classname[0] == 'v' ||
		classname[0] == 'i'
	)
	{
		if(
			strncmp(classname, "molotov_projectile", 13) == 0 ||
			strncmp(classname, "pipe_bomb_projectile", 13) == 0 ||
			strncmp(classname, "inferno", 13) == 0 ||
			g_bL4D2Version && strncmp(classname, "vomitjar_projectile", 13) == 0
		)
		{
			SDKHook(entity, SDKHook_SpawnPost, SpawnPost);
			return;
		}
	}
}

public void SpawnPost(int entity)
{
	// 1 frame later required to get velocity
	RequestFrame(OnNextFrame, EntIndexToEntRef(entity));
}

public void OnNextFrame(int entity)
{
	// Validate entity
	if( EntRefToEntIndex(entity) == INVALID_ENT_REFERENCE || !IsValidEntity(entity) )
		return;

	// Get Client
	int client;
	bool bThrowable;
	if(HasEntProp(entity, Prop_Send, "m_hThrower"))
	{
		client = GetEntPropEnt(entity, Prop_Data, "m_hThrower");
		bThrowable = true;
	}
	else
	{
		client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		bThrowable = false;
	}

	if( client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		if( bThrowable == true && g_fThrowableCooldown > 0.0) fThrowableTime[client] = GetEngineTime() + g_fThrowableCooldown;
		if( bThrowable == false && g_fBreakPropCooldown> 0.0) fBreakPropTime[client] = GetEngineTime() + g_fBreakPropCooldown;
	}
}

void ResetTimer()
{
	delete PlayerLeftStartTimer;
	delete CountDownTimer;
}

bool IsPlayerGhost (int client)
{
	if (GetEntProp(client, Prop_Send, "m_isGhost"))
		return true;
	return false;
}

bool Is_AFK_COMMAND_Block()
{
	if(g_Use_r2comp_unscramble == true && R2comp_IsUnscrambled() == false) return true;
	
	return false;
}

void CleanUpStateAndMusic(int client)
{
	// Resets a players state equivalent to when they die
	// does stuff like removing any pounces, stops reviving, stops healing, resets hang lighting, resets heartbeat and other sounds.
	L4D_CleanupPlayerState(client);

	// This fixes the music glitch thats been bothering me and many players for a long time. The music keeps playing over and over when it shouldn't. Doesn't execute
	// on versus.
	if(g_iGameMode != 2)
	{
		if (!g_bL4D2Version)
		{
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Hospital");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Airport");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Farm");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Small_Town");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Garage");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Hospital");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Airport");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Small_Town");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Farm");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Garage");
			L4D_StopMusic(client, "Event.Zombat");
			L4D_StopMusic(client, "Event.Zombat_A2");
			L4D_StopMusic(client, "Event.Zombat_A3");
			L4D_StopMusic(client, "Event.Tank");
			L4D_StopMusic(client, "Event.TankMidpoint");
			L4D_StopMusic(client, "Event.TankBrothers");
			L4D_StopMusic(client, "Event.WitchAttack");
			L4D_StopMusic(client, "Event.WitchBurning");
			L4D_StopMusic(client, "Event.WitchRage");
			L4D_StopMusic(client, "Event.HunterPounce");
			L4D_StopMusic(client, "Event.SmokerChoke");
			L4D_StopMusic(client, "Event.SmokerDrag");
			L4D_StopMusic(client, "Event.VomitInTheFace");
			L4D_StopMusic(client, "Event.LedgeHangTwoHands");
			L4D_StopMusic(client, "Event.LedgeHangOneHand");
			L4D_StopMusic(client, "Event.LedgeHangFingers");
			L4D_StopMusic(client, "Event.LedgeHangAboutToFall");
			L4D_StopMusic(client, "Event.LedgeHangFalling");
			L4D_StopMusic(client, "Event.Down");
			L4D_StopMusic(client, "Event.BleedingOut");
			L4D_StopMusic(client, "Event.Down");
		}
		else
		{
			// Music when Mission Starts
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Mall");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Fairgrounds");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Plankcountry");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Milltown");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_BigEasy");
			
			// Checkpoints
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Mall");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Fairgrounds");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Plankcountry");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Milltown");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_BigEasy");
			
			// Zombat
			L4D_StopMusic(client, "Event.Zombat_1");
			L4D_StopMusic(client, "Event.Zombat_A_1");
			L4D_StopMusic(client, "Event.Zombat_B_1");
			L4D_StopMusic(client, "Event.Zombat_2");
			L4D_StopMusic(client, "Event.Zombat_A_2");
			L4D_StopMusic(client, "Event.Zombat_B_2");
			L4D_StopMusic(client, "Event.Zombat_3");
			L4D_StopMusic(client, "Event.Zombat_A_3");
			L4D_StopMusic(client, "Event.Zombat_B_3");
			L4D_StopMusic(client, "Event.Zombat_4");
			L4D_StopMusic(client, "Event.Zombat_A_4");
			L4D_StopMusic(client, "Event.Zombat_B_4");
			L4D_StopMusic(client, "Event.Zombat_5");
			L4D_StopMusic(client, "Event.Zombat_A_5");
			L4D_StopMusic(client, "Event.Zombat_B_5");
			L4D_StopMusic(client, "Event.Zombat_6");
			L4D_StopMusic(client, "Event.Zombat_A_6");
			L4D_StopMusic(client, "Event.Zombat_B_6");
			L4D_StopMusic(client, "Event.Zombat_7");
			L4D_StopMusic(client, "Event.Zombat_A_7");
			L4D_StopMusic(client, "Event.Zombat_B_7");
			L4D_StopMusic(client, "Event.Zombat_8");
			L4D_StopMusic(client, "Event.Zombat_A_8");
			L4D_StopMusic(client, "Event.Zombat_B_8");
			L4D_StopMusic(client, "Event.Zombat_9");
			L4D_StopMusic(client, "Event.Zombat_A_9");
			L4D_StopMusic(client, "Event.Zombat_B_9");
			L4D_StopMusic(client, "Event.Zombat_10");
			L4D_StopMusic(client, "Event.Zombat_A_10");
			L4D_StopMusic(client, "Event.Zombat_B_10");
			L4D_StopMusic(client, "Event.Zombat_11");
			L4D_StopMusic(client, "Event.Zombat_A_11");
			L4D_StopMusic(client, "Event.Zombat_B_11");
			
			// Zombat specific maps
			
			// C1 Mall
			L4D_StopMusic(client, "Event.Zombat2_Intro_Mall");
			L4D_StopMusic(client, "Event.Zombat3_Intro_Mall");
			L4D_StopMusic(client, "Event.Zombat3_A_Mall");
			L4D_StopMusic(client, "Event.Zombat3_B_Mall");
			
			// A2 Fairgrounds
			L4D_StopMusic(client, "Event.Zombat_Intro_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat_A_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat_B_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat_B_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat2_Intro_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat3_Intro_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat3_A_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat3_B_Fairgrounds");
			
			// C3 Plankcountry
			L4D_StopMusic(client, "Event.Zombat_PlankCountry");
			L4D_StopMusic(client, "Event.Zombat_A_PlankCountry");
			L4D_StopMusic(client, "Event.Zombat_B_PlankCountry");
			L4D_StopMusic(client, "Event.Zombat2_Intro_Plankcountry");
			L4D_StopMusic(client, "Event.Zombat3_Intro_Plankcountry");
			L4D_StopMusic(client, "Event.Zombat3_A_Plankcountry");
			L4D_StopMusic(client, "Event.Zombat3_B_Plankcountry");
			
			// A2 Milltown
			L4D_StopMusic(client, "Event.Zombat2_Intro_Milltown");
			L4D_StopMusic(client, "Event.Zombat3_Intro_Milltown");
			L4D_StopMusic(client, "Event.Zombat3_A_Milltown");
			L4D_StopMusic(client, "Event.Zombat3_B_Milltown");
			
			// C5 BigEasy
			L4D_StopMusic(client, "Event.Zombat2_Intro_BigEasy");
			L4D_StopMusic(client, "Event.Zombat3_Intro_BigEasy");
			L4D_StopMusic(client, "Event.Zombat3_A_BigEasy");
			L4D_StopMusic(client, "Event.Zombat3_B_BigEasy");
			
			// A2 Clown
			L4D_StopMusic(client, "Event.Zombat3_Intro_Clown");
			
			// Death
			
			// ledge hang
			L4D_StopMusic(client, "Event.LedgeHangTwoHands");
			L4D_StopMusic(client, "Event.LedgeHangOneHand");
			L4D_StopMusic(client, "Event.LedgeHangFingers");
			L4D_StopMusic(client, "Event.LedgeHangAboutToFall");
			L4D_StopMusic(client, "Event.LedgeHangFalling");
			
			// Down
			// Survivor is down and being beaten by infected
			
			L4D_StopMusic(client, "Event.Down");
			L4D_StopMusic(client, "Event.BleedingOut");
			
			// Survivor death
			// This is for the death of an individual survivor to be played after the health meter has reached zero
			
			L4D_StopMusic(client, "Event.SurvivorDeath");
			L4D_StopMusic(client, "Event.ScenarioLose");
			
			// Bosses
			
			// Tank
			L4D_StopMusic(client, "Event.Tank");
			L4D_StopMusic(client, "Event.TankMidpoint");
			L4D_StopMusic(client, "Event.TankBrothers");
			L4D_StopMusic(client, "C2M5.RidinTank1");
			L4D_StopMusic(client, "C2M5.RidinTank2");
			L4D_StopMusic(client, "C2M5.BadManTank1");
			L4D_StopMusic(client, "C2M5.BadManTank2");
			
			// Witch
			L4D_StopMusic(client, "Event.WitchAttack");
			L4D_StopMusic(client, "Event.WitchBurning");
			L4D_StopMusic(client, "Event.WitchRage");
			L4D_StopMusic(client, "Event.WitchDead");
			
			// mobbed
			L4D_StopMusic(client, "Event.Mobbed");
			
			// Hunter
			L4D_StopMusic(client, "Event.HunterPounce");
			
			// Smoker
			L4D_StopMusic(client, "Event.SmokerChoke");
			L4D_StopMusic(client, "Event.SmokerDrag");
			
			// Boomer
			L4D_StopMusic(client, "Event.VomitInTheFace");
			
			// Charger
			L4D_StopMusic(client, "Event.ChargerSlam");
			
			// Jockey
			L4D_StopMusic(client, "Event.JockeyRide");
			
			// Spitter
			L4D_StopMusic(client, "Event.SpitterSpit");
			L4D_StopMusic(client, "Event.SpitterBurn");
		}
	}
}

void ClearDefault()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}