/*
 * @Author:             我是派蒙啊
 * @Last Modified by:   派蒙
 * @Create Date:        2021-12-18 15:48:14
 * @Last Modified time: 2022-04-01 10:59:49
 * @Github:             http://github.com/PaimonQwQ
 */
#pragma semicolon 1
#pragma newdecls required

#include <colors>
#include <sdktools>
#include <l4d2tools>
#include <sourcemod>
#include <adminmenu>
#include <left4dhooks>

#define MAXSIZE 33
#define VERSION "7.54.3"
#define MENU_DISPLAY_TIME 15

public Plugin myinfo =
{
    name = "AnneServer",
    author = "Anne & 彩笔 & 我是派蒙啊",
    description = "修改Server核心使玩家可以使用特感并整合了我的另一个插件ForceSpec",
    version = VERSION,
    url = "http://github.com/PaimonQwQ/L4D2-Plugins/anneserver.sp",
    //another url to download = "http://anne.paimeng.ltd/l4d2_plugins/anneserver.sp",
    //url of ForceSpec = "http://github.com/PaimonQwQ/L4D2-Plugins/l4d_forcespec.sp",
};

enum Msgs
{
    Msg_Warn = 0,
    Msg_Connected,
    Msg_DisConnected,
    Msg_InfectedDisabled,
    Msg_RoundStart,
    Msg_JoinInfected,
    Msg_JoinSINotice,
    Msg_TakeTank,
    Msg_Error,
    Msg_Notice,
    Msg_TakeGhost,
    Msg_TankBeenTaken,
    Msg_TankAI,
    Msg_PlayerTankAI,
    Msg_WillTakeTank,
    Msg_CantTakeTank,
    Msg_AlreadyInfected,
    Msg_UnableToUse,
    Msg_ForceSpectated
};//Message enums for message array(as an index)

char
    messages[][] =
    {
        "{olive}[Paimon] {lightgreen}请注意：\n若路人局遇{orange}内鬼嘲讽{lightgreen}，请直接{orange}投票送走{lightgreen}，事后我会补{orange}永久封禁{lightgreen}一个！",
        "{olive}[Paimon] {blue}%N {olive}正在爬进服务器",
        "{olive}[Paimon] {blue}%N {olive}离开服务器",
        "{olive}[Paimon] {orange}玩家特感{lightgreen}已被{orange}禁止！",
        "{olive}[Paimon] {lightgreen}对局已经{orange}开始{lightgreen}，{orange}禁止{lightgreen}加入特感！",
        "{olive}[Paimon] {orange}%N {orange}加入{lightgreen}特感阵营！",
        "{olive}[Paimon] {lightgreen}输入{orange} !cs {lightgreen}切换特感{orange} !it {lightgreen}接管tank(克局之前输入)",
        "{olive}[Paimon] {orange}%N {lightgreen}已接管Tank！",
        "{olive}[Paimon] {red}#检测到未知错误，即将重启地图！",
        "{olive}[Paimon] {lightgreen}请注意：本服内置{orange}内鬼插件{lightgreen}，使用{orange}!inf{lightgreen}加入特感\n{orange}内鬼模式{lightgreen}可在{orange}投票 >> 特殊操作{lightgreen}中关闭",
        "{olive}[Paimon] {lightgreen}请勿{orange}长时间{lightgreen}占用特感！",
        "{olive}[Paimon] {lightgreen}克已被{orange} %N {lightgreen}接管！",
        "{olive}[Paimon] {lightgreen}克已{orange}AI{lightgreen}，{orange}禁止{lightgreen}接管！",
        "{olive}[Paimon] {lightgreen}某笨比的克{orange}AI{lightgreen}了！",
        "{olive}[Paimon] {orange}%N {lightgreen}将于{orange}克局{lightgreen}接管Tank！",
        "{olive}[Paimon] {orange}生还{lightgreen}和{orange}旁观{lightgreen}禁止接管Tank！",
        "{olive}[Paimon] {olive}你已经是{orange}特感方{lightgreen}了！",
        "{olive}[Paimon] {orange}旁观{lightgreen}不能使用本功能！",
        "{olive}[Paimon] 笨比{orange} %N {lightgreen}被{orange}管理{lightgreen}强制旁观啦！"
    };//Messages for player to show

int
    tankPlayer = -1,
    playerInfectedSwitch = 1,
    serverMaxSurvivorCount = 0;

float
    lastDisconnectTime = 0.0;

bool
    isRoundStart = false,
    canInfectedJoin = true,
    playerFirstJoin[MAXSIZE] = false;

ConVar
    serverMaxSurvivorConvar,
    playerInfectedSwitchConvar,
    specialRespawnIntervalConvar,
    //导演刷特限制
    g_hHunterLimit,
    g_hBoomerLimit,
    g_hSmokerLimit,
    g_hJockeyLimit,
    g_hChargerLimit,
    g_hSpitterLimit;

Handle
    AdminMenu = INVALID_HANDLE,
    playerGhostHandle[MAXSIZE] = INVALID_HANDLE;

TopMenuObject
    SpecMenuObj = INVALID_TOPMENUOBJECT,
    PlayerCMDMenuObj = INVALID_TOPMENUOBJECT;

public void OnPluginStart()
{
    AddCommandListener(Command_Jointeam, "jointeam");
    AddCommandListener(Command_ChooseTeam, "chooseteam");

    HookEvent("round_start", Event_RoundStart);
    HookEvent("tank_killed", Event_PlayerDead);
    HookEvent("player_death", Event_PlayerDead);
    HookEvent("witch_killed", Event_WitchKilled);
    HookEvent("finale_win", Event_ResetSurvivors);
    HookEvent("player_team", Event_PlayerChangeTeam);
    HookEvent("map_transition", Event_ResetSurvivors);
    HookEvent("bot_player_replace", Event_PlayerReplaceTankBot);

    serverMaxSurvivorConvar = FindConVar("survivor_limit");
    serverMaxSurvivorCount = GetConVarInt(serverMaxSurvivorConvar);
    specialRespawnIntervalConvar = FindConVar("versus_special_respawn_interval");
    playerInfectedSwitchConvar = CreateConVar("l4d2_player_specials", "1", "开启玩家特感");

    g_hHunterLimit = FindConVar("z_hunter_limit");
    g_hBoomerLimit = FindConVar("z_boomer_limit");
    g_hSmokerLimit = FindConVar("z_smoker_limit");
    g_hJockeyLimit = FindConVar("z_jockey_limit");
    g_hChargerLimit = FindConVar("z_charger_limit");
    g_hSpitterLimit = FindConVar("z_spitter_limit");

    HookConVarChange(serverMaxSurvivorConvar, CvarEvent_MaxSurvivorChange);
    HookConVarChange(specialRespawnIntervalConvar, CvarEvent_SpecialIntervalChange);
    HookConVarChange(playerInfectedSwitchConvar, CvarEvent_PlayerSpecialSwitchChange);

    g_hHunterLimit.AddChangeHook(CvarEvent_LimitChangeed);
    g_hBoomerLimit.AddChangeHook(CvarEvent_LimitChangeed);
    g_hSmokerLimit.AddChangeHook(CvarEvent_LimitChangeed);
    g_hJockeyLimit.AddChangeHook(CvarEvent_LimitChangeed);
    g_hChargerLimit.AddChangeHook(CvarEvent_LimitChangeed);
    g_hSpitterLimit.AddChangeHook(CvarEvent_LimitChangeed);

    RegConsoleCmd("sm_it", Cmd_PlayTank, "Take tank");
    RegConsoleCmd("sm_c", Cmd_ChangeClass, "Change SI");
    RegConsoleCmd("sm_cs", Cmd_ChangeClass, "Change SI");
    RegConsoleCmd("sm_playtank", Cmd_PlayTank, "Take tank");
    RegConsoleCmd("sm_taketank", Cmd_PlayTank, "Take tank");
    RegConsoleCmd("sm_changeclass", Cmd_ChangeClass, "Change SI");
    RegConsoleCmd("sm_ammo", Cmd_GiveClientAmmo, "Give survivor ammo");
    RegConsoleCmd("sm_s", Cmd_AFKTurnClientToSpe, "Turn player to spectator");
    RegConsoleCmd("sm_spec", Cmd_AFKTurnClientToSpe, "Turn player to spectator");
    RegConsoleCmd("sm_away", Cmd_AFKTurnClientToSpe, "Turn player to spectator");
    RegConsoleCmd("sm_jg", Cmd_AFKTurnClientToSurvivor, "Turn player to survivor");
    RegConsoleCmd("sm_join", Cmd_AFKTurnClientToSurvivor, "Turn player to survivor");
    RegConsoleCmd("sm_team", Cmd_AFKTurnClientTeam, "Turn player to the designated team");
    RegConsoleCmd("sm_inf", Cmd_AFKTurnClientToInfected, "Turn player to special infected");
    RegConsoleCmd("sm_team3", Cmd_AFKTurnClientToInfected, "Turn player to special infected");

    RegAdminCmd("sm_restartmap", Cmd_RestartMap, ADMFLAG_GENERIC, "Restart map");
    RegAdminCmd("sm_restart", Cmd_RestartServer, ADMFLAG_GENERIC, "Kick all clients and restart server");

    if (LibraryExists("adminmenu") && (GetAdminTopMenu() != INVALID_HANDLE))
        Event_OnAdminMenuReady(GetAdminTopMenu());
}

                /*  ########################################
                            SourceModHookEvent:START==>
                ########################################    */

//地图加载
public void OnMapStart()
{
    tankPlayer = -1;
    isRoundStart = false;
    FindConVar("director_allow_infected_bots").SetInt(0);
    for (int client = 1; client <= MaxClients; client++)
        if (IsValidClient(client) && !IsFakeClient(client))
        {
            if (IsInfected(client))
                CloseGhostHandle(client);
            SetPlayerMode(client, GetClientTeam(client));
        }
    CheckModel();
}

//玩家连接
public void OnClientConnected(int client)
{
    if (GetSurvivorCount() > serverMaxSurvivorCount)
        CreateTimer(3.0, Timer_ReStartMap, 0, TIMER_FLAG_NO_MAPCHANGE);

    if (IsFakeClient(client)) return;

    CPrintToChatAll(messages[Msg_Connected], client);
    playerFirstJoin[client] = true;
}

//玩家断开连接
public void OnClientDisconnect(int client)
{
    if (!IsValidClient(client)) return;

    if (IsClientInGame(client) && IsFakeClient(client))
        return;

    float currenttime = GetGameTime();

    if (playerGhostHandle[client] != INVALID_HANDLE)
        CloseHandle(playerGhostHandle[client]);

    if (IsClientInGame(client))
        CPrintToChatAll(messages[Msg_DisConnected], client);

    playerFirstJoin[client] = false;
    if (lastDisconnectTime == currenttime)
        return;

    CreateTimer(3.0, Timer_IsNobodyConnected, currenttime, TIMER_FLAG_NO_MAPCHANGE);
    lastDisconnectTime = currenttime;
}

//玩家进入服务器
public void OnClientPutInServer(int client)
{
    if (IsValidEntity(client) && !IsFakeClient(client))
        CreateTimer(1.0, Timer_CheckPlayerTeam, client, TIMER_FLAG_NO_MAPCHANGE);
}

//特感连跳
public Action OnPlayerRunCmd(int client, int &buttons, int &impuls)
{
    if (!IsValidClient(client)) return Plugin_Continue;

    if (!IsSurvivor(client) && (buttons & IN_JUMP)
        && GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1)
        buttons &= ~IN_JUMP;

    if (IsSurvivor(client) && IsFakeClient(client) && IsPlayerAlive(client))
        if (GetEntityMoveType(client) != MOVETYPE_LADDER)
            SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.0);
        else SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 4.0);

    return Plugin_Continue;
}

                /*  ########################################
                            <==SourceModHookEvent:END
                ########################################    */


                /*  ########################################
                            L4DHookEvent:START==>
                ########################################    */

//玩家特感进入灵魂状态
public void L4D_OnEnterGhostState(int client)
{
    if (!IsValidClient(client)) return;
    CloseGhostHandle(client);
    playerGhostHandle[client] = CreateTimer(60.0, Timer_PlayerTakeGhost, client, TIMER_FLAG_NO_MAPCHANGE);
    //Event_CreateClipMenu(client);
}

//玩家灵魂复活
public void L4D_OnMaterializeFromGhost(int client)
{
    if (!IsValidClient(client)) return;

    CloseGhostHandle(client);
    SetEntityMoveType(client, MOVETYPE_WALK);
}

//玩家离开安全屋
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
    isRoundStart = true;
    CreateTimer(0.5, Timer_AutoGive, 0, TIMER_FLAG_NO_MAPCHANGE);
    CPrintToChatAll(messages[Msg_Warn]);
}

//接管克事件
public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStasis)
{
    tankPlayer = IsValidClient(tankPlayer) ? tankPlayer : FindRandomInfected();
    if (IsValidClient(tankPlayer) && L4D2Direct_GetTankPassedCount() < 2)
    {
        CreateTimer(2.0, Timer_ReplaceTank, tank_index, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

                /*  ########################################
                            <==L4DHookEvent:END
                ########################################    */


                /*  ########################################
                        ConsoleCommandHookEvent:START==>
                ########################################    */

//控制台切换队伍指令
public Action Command_Jointeam(int client, const char[] command, int args)
{
    char arg[32];
    GetCmdArg(1, arg, 32);

    if (!IsValidClient(client)) return Plugin_Continue;

    if (StrEqual(arg, "infected", true) || StrEqual(arg, "3", true))
    {
        if (IsInfected(client))
        {
            CPrintToChat(client, messages[Msg_AlreadyInfected]);
            return Plugin_Handled;
        }

        if (!IsInfected(client) && !canInfectedJoin)
        {
            CPrintToChat(client, messages[Msg_InfectedDisabled]);
            return Plugin_Handled;
        }

        if (isRoundStart && IsSurvivor(client))
        {
            CPrintToChat(client, messages[Msg_RoundStart]);
            return Plugin_Handled;
        }

        CPrintToChatAll(messages[Msg_JoinInfected], client);
        CPrintToChat(client, messages[Msg_JoinSINotice]);
    }

    return Plugin_Continue;
}

//控制台选择队伍指令
public Action Command_ChooseTeam(int client, const char[] command, any args)
{
    if (!IsValidClient(client)) return Plugin_Continue;
    if (!IsFakeClient(client)) return Plugin_Handled;
    return Plugin_Continue;
}

                /*  ########################################
                        <==ConsoleCommandHookEvent:END
                ########################################    */


                /*  ########################################
                            MyHookEvent:START==>
                ########################################    */

//回合开始事件
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(3.0, Timer_DelayedOnRoundStart, 0, TIMER_FLAG_NO_MAPCHANGE);
}

//克死亡事件
public Action Event_PlayerDead(Event event, const char[] name, bool dont_broadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid", 0));

    if (!IsValidClient(client)) return;

    if (IsInfected && GetInfectedClass(client) == view_as<int>(ZC_Tank))
    {
        L4D2Direct_SetTankPassedCount(1);
        CloseGhostHandle(client);
        tankPlayer = -1;
    }

    if (GetAliveSurvivorCount() == 0)
    {
        isRoundStart = false;
        tankPlayer = -1;
        if (playerInfectedSwitch == 1)
            SetConVarInt(FindConVar("director_no_specials"), 0);
        for (int i = 1; i <= MaxClients; i++)
            CloseGhostHandle(i);
    }
}

//秒妹加血
public Action Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid", 0));

    if (!IsValidClient(client)) return;

    if (client > 0 && client <= MaxClients && IsClientInGame(client) &&
        IsSurvivor(client) && IsPlayerAlive(client) && !IsPlayerIncap(client))
    {
        int maxhp = GetEntProp(client, Prop_Data, "m_iMaxHealth");
        int targetHealth = GetPlayerHealth(client) + 15;
        if (targetHealth > maxhp + 20)
            targetHealth = maxhp + 20;
        SetPlayerHealth(client, targetHealth);
    }
}

//玩家切换队伍
public Action Event_PlayerChangeTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid", 0));
    int team = GetEventInt(event, "team", 0);
    int oldteam = GetEventInt(event, "oldteam", 0);

    if (!IsValidClient(client)) return Plugin_Continue;

    if (oldteam == 3)
        CloseGhostHandle(client);

    if (IsFakeClient(client)) return Plugin_Continue;

    if (team == 3 && !canInfectedJoin)
    {
        CPrintToChat(client, messages[Msg_InfectedDisabled]);
        CreateTimer(0.01, Timer_CheckAway, client, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Handled;
    }

    if (!IsFakeClient(client)) SetPlayerMode(client, team);

    if (team == 2 && client == tankPlayer) tankPlayer = -1;

    return Plugin_Continue;
}

//重置玩家信息
public Action Event_ResetSurvivors(Event event, const char[] name, bool dontBroadcast)
{
    RestoreHealth();
    ResetInventory();

    for (int i = 1; i <= MaxClients; i++)
        CloseGhostHandle(i);
}

//玩家替换TankBot事件
public Action Event_PlayerReplaceTankBot(Event event, const char[] name, bool dont_broadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "player", 0));

    if (!IsValidClient(client)) return;

    if (!L4D2_IsTankInPlay() || !IsInfected(client)) return;

    if (GetInfectedClass(client) == view_as<int>(ZC_Tank))
    {
        if (tankPlayer == -1)
            tankPlayer = client;
        else if (client == tankPlayer)
        {
            SetTankFrustration(tankPlayer, 100);
            L4D2Direct_SetTankPassedCount(1);
        }
        CloseGhostHandle(tankPlayer);
        CPrintToChatAll(messages[Msg_TakeTank], tankPlayer);
        CreateTimer(0.5, Timer_CheckTankFrustration, tankPlayer, TIMER_REPEAT);
        CreateTimer(10.0, Timer_FirstCheckTankView, tankPlayer, TIMER_FLAG_NO_MAPCHANGE);
    }
}

//Admin准备事件
public Action Event_OnAdminMenuReady(Handle topmenu)
{
    if (AdminMenu == topmenu)
        return;
    AdminMenu = topmenu;
    PlayerCMDMenuObj = FindTopMenuCategory(AdminMenu, "PlayerCommands");
    if (PlayerCMDMenuObj == INVALID_TOPMENUOBJECT) return;
    SpecMenuObj = AddToTopMenu(AdminMenu, "spec_menu", TopMenuObject_Item, Handle_SetSpecMenuItem, PlayerCMDMenuObj);
}

//创建SpecMenu
public Action Event_CreateSpecMenu(int client)
{
    Handle menu = CreateMenu(Handle_ExecSpecMenu);
    SetMenuTitle(menu, "ForceSpec player:");
    SetMenuExitBackButton(menu, true);
    SetMenuExitButton(menu, true);
    AddTargetsToMenu(menu, 0);
    DisplayMenu(menu, client, MENU_DISPLAY_TIME);

    return Plugin_Handled;
}

//创建ClassMenu
public Action Event_CreateClassMenu(int client)
{
    Handle menu = CreateMenu(Handle_ExecClassMenu);
    //1=Smoker, 2=Boomer, 3=Hunter, 4=Spitter, 5=Jockey, 6=Charger 7=Witch(Unsafe) 8=Tank
    if (IsInfected(client))
    {
        SetMenuTitle(menu, "Choose zombie:");
        AddMenuItem(menu, "Smoker",   "Smoker");
        AddMenuItem(menu, "Boomer",   "Boomer");
        AddMenuItem(menu, "Hunter",   "Hunter");
        AddMenuItem(menu, "Spitter", "Spitter");
        AddMenuItem(menu, "Jockey",   "Jockey");
        AddMenuItem(menu, "Charger", "Charger");
        if (GetUserFlagBits(client) != 0)
        {
            AddMenuItem(menu, "None", "None");
            AddMenuItem(menu, "Tank", "Tank");
        }
    }
    else
    {
        SetMenuTitle(menu, "Choose survivor:");
        AddMenuItem(menu, "models/survivors/survivor_gambler.mdl", "Nick");
        AddMenuItem(menu, "models/survivors/survivor_producer.mdl", "Rochelle");
        AddMenuItem(menu, "models/survivors/survivor_coach.mdl", "Coach");
        AddMenuItem(menu, "models/survivors/survivor_mechanic.mdl", "Ellis");
        AddMenuItem(menu, "models/survivors/survivor_namvet.mdl", "Bill");
        AddMenuItem(menu, "models/survivors/survivor_teenangst.mdl", "Zoey");
        AddMenuItem(menu, "models/survivors/survivor_biker.mdl", "Francis");
        AddMenuItem(menu, "models/survivors/survivor_manager.mdl", "Louis");
    }
    SetMenuPagination(menu, MENU_NO_PAGINATION);
    SetMenuExitButton(menu, true);
    DisplayMenu(menu, client, MENU_DISPLAY_TIME);

    return Plugin_Handled;
}

//创建ClipMenu
//public Action Event_CreateClipMenu(int client)
//{
//    if (!IsInfected(client)) return Plugin_Handled;
//    Handle menu = CreateMenu(Handle_ExecClipMenu);
//    SetMenuTitle(menu, "Noclip status:");
//    AddMenuItem(menu, "NOCLIP",   "On");
//    AddMenuItem(menu, "WLAK",   "Off");
//    SetMenuPagination(menu, MENU_NO_PAGINATION);
//    SetMenuExitButton(menu, true);
//    DisplayMenu(menu, client, MENU_DISPLAY_TIME);

//    return Plugin_Handled;
//}

                /*  ########################################
                            <==MyHookEvent:END
                ########################################    */


                /*  ########################################
                            ConVarEvent:START==>
                ########################################    */

//生还数量更改
public void CvarEvent_MaxSurvivorChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    serverMaxSurvivorCount = GetConVarInt(serverMaxSurvivorConvar);
}

//特感复活时间改变事件
public void CvarEvent_SpecialIntervalChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    CreateTimer(0.5, Timer_SpecialInterval, 0, TIMER_FLAG_NO_MAPCHANGE);
}

//玩家特感开关事件
public void CvarEvent_PlayerSpecialSwitchChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    playerInfectedSwitch = playerInfectedSwitchConvar.IntValue;
    if (playerInfectedSwitch == 0)
    {
        SetConVarInt(FindConVar("director_no_specials"), 1);
        for (int client = 1; client <= MaxClients; client++)
            if (IsInfected(client))
                ChangeClientTeam(client, 1);
        canInfectedJoin = false;
    }
    else
    {
        SetConVarInt(FindConVar("director_no_specials"), 0);
        canInfectedJoin = true;
    }
}

//特感数量更改
public void CvarEvent_LimitChangeed(ConVar convar, const char[] oldValue, const char[] newValue)
{
    convar.SetInt(0, true);
}

                /*  ########################################
                            <==ConVarEvent:END
                ########################################    */


                /*  ########################################
                                Timer:START==>
                ########################################    */

//地图重启
public Action Timer_ReStartMap(Handle timer, int client)
{
    if (GetSurvivorCount() > serverMaxSurvivorCount)
    {
        CPrintToChatAll(messages[Msg_Error]);
        ServerCommand("sm_restartmap");
    }
}

//玩家都断开连接时
public Action Timer_IsNobodyConnected(Handle timer, any timerDisconnectTime)
{
    if (lastDisconnectTime != timerDisconnectTime)
        return Plugin_Stop;

    for (int i = 1; i <= MaxClients ;i++)
        if (IsValidClient(i) && !IsFakeClient(i))
            return Plugin_Stop;

    CrashServer();

    return Plugin_Stop;
}

//纠正进入游戏的玩家队伍
public Action Timer_CheckPlayerTeam(Handle timer, int client)
{
    if (!IsValidClient(client) || IsFakeClient(client)) return;

    if (playerFirstJoin[client])
        if (IsInfected(client))
        {
            if (playerInfectedSwitch == 0)
            {
                if (IsSurvivorTeamFull())
                    ChangeClientTeam(client, 1);
                else ChangePlayerSurvivor(client);
            }
            else if (IsSurvivorTeamFull())
            {
                if (GetInfectedPlayerCount() == 0)
                    ChangeClientTeam(client, 1);
            }
            else if (!isRoundStart)
                ChangePlayerSurvivor(client);
            else
                ChangeClientTeam(client, 1);
        }
        else if (!isRoundStart && IsSurvivor(client))
            ChangeClientTeam(client, 1);

    playerFirstJoin[client] = false;

    CPrintToChat(client, messages[Msg_Notice]);
}

//玩家占用特感Timer
public Action Timer_PlayerTakeGhost(Handle timer, int client)
{
    if (!IsValidClient(client)) return;
    if (L4D2_IsTankInPlay() && client == tankPlayer)
    {
        CloseGhostHandle(client);
        return;
    }

    ChangeClientTeam(client, 1);
    CPrintToChat(client, messages[Msg_TakeGhost]);
    CloseGhostHandle(client);
}

//替换玩家Tank
public Action Timer_ReplaceTank(Handle timer, int tankClient)
{
    L4D_TakeOverZombieBot(tankPlayer, tankClient);
    L4D2Direct_SetTankPassedCount(1);
    CreateTimer(0.5, Timer_CheckTankFrustration, tankPlayer, TIMER_REPEAT);
    CreateTimer(10.0, Timer_FirstCheckTankView, tankPlayer, TIMER_FLAG_NO_MAPCHANGE);
}

//自动给予药品
public Action Timer_AutoGive(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
        if (IsSurvivor(client))
        {
            if (!IsPlayerAlive(client)) L4D_RespawnPlayer(client);
            BypassAndExecuteCommand(client, "give", "pain_pills");
            BypassAndExecuteCommand(client, "give", "health");
            SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
            SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
            SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
            GiveInventoryItems(client);
        }
    if (playerInfectedSwitch == 1)
        SetConVarInt(FindConVar("director_no_specials"), 0);
    else
        SetConVarInt(FindConVar("director_no_specials"), 1);
}

//执行地图信息
public Action Timer_DelayedOnRoundStart(Handle timer)
{
    SetConVarString(FindConVar("mp_gamemode"), "coop");
    char sMapConfig[128];
    GetCurrentMap(sMapConfig, 128);
    Format(sMapConfig, 128, "cfg/sourcemod/map_cvars/%s.cfg", sMapConfig);
    if (FileExists(sMapConfig, true, "GAME"))
    {
        strcopy(sMapConfig, 128, sMapConfig[1]);
        ServerCommand("exec \"%s\"", sMapConfig);
    }
    for (int client = 1; client <= MaxClients; client++)
        if (IsValidClient(client) &&!IsFakeClient(client))
            SetPlayerMode(client, GetClientTeam(client));
    SetConVarInt(FindConVar("director_no_specials"), 0);
}

//检查玩家控制权Timer
public Action Timer_CheckTankFrustration(Handle timer, int tankClient)
{
    if (!L4D2_IsTankInPlay() || !IsValidClient(tankClient) || IsFakeClient(tankClient))
        return Plugin_Stop;

    if (GetTankFrustration(tankClient) <= 5 && L4D2Direct_GetTankPassedCount() <= 1)
    {
        tankPlayer = -1;
        L4D2Direct_SetTankPassedCount(2);
        SetTankFrustration(tankClient, 100);
        PrintHintText(tankClient, "克已2控 请注意");
        CPrintToChatAll("{red}<{olive}Tank Rage{red}> {olive}Tank Rage Meter {red}Refilled!");
    }
    else if (L4D2Direct_GetTankPassedCount() >= 2 && GetTankFrustration(tankClient) == 5)
    {
        CPrintToChatAll(messages[Msg_PlayerTankAI]);
        SetTankFrustration(tankClient, 0);
        L4D_ReplaceWithBot(tankClient);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

//检查玩家视野Timer
public Action Timer_FirstCheckTankView(Handle timer, int tankClient)
{
    int frust = GetTankFrustration(tankClient);
    if(!IsTankHasView(tankClient))
        SetTankFrustration(tankClient, frust >= 10 ? frust - 5 : 5);
    CreateTimer(2.0, Timer_CheckTankView, tankClient, TIMER_REPEAT);
}

//检查玩家视野Timer
public Action Timer_CheckTankView(Handle timer, int tankClient)
{
    if(!IsValidClient(tankClient) || !IsInfected(tankClient) ||
     !IsPlayerAlive(tankClient) || !IsTank(tankClient)) return Plugin_Stop;

    int frust = GetTankFrustration(tankClient);
    if(!IsTankHasView(tankClient))
        SetTankFrustration(tankClient, frust >= 10 ? frust - 5 : 5);

    return Plugin_Continue;
}

//特感复活事件改变Timer
public Action Timer_SpecialInterval(Handle timer)
{
    if (playerInfectedSwitch == 0)
        SetConVarInt(FindConVar("director_no_specials"), 1);
    else
        SetConVarInt(FindConVar("director_no_specials"), 0);
}

//玩家旁观Timer
public Action Timer_CheckAway(Handle timer, int client)
{
    if (!IsValidClient(client) || IsFakeClient(client)) return;

    ChangeClientTeam(client, 1);
}

                /*  ########################################
                            <==Timer:END
                ########################################    */


                /*  ########################################
                            HandleFunctions:START==>
                ########################################    */

//创建Spec菜单内容
public void Handle_SetSpecMenuItem(TopMenu topmenu, TopMenuAction action, TopMenuObject topobj_id, int client, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
        if (topobj_id == SpecMenuObj)
            Format(buffer, maxlength, "ForceSpec player");
    if (action == TopMenuAction_SelectOption)
        if (topobj_id == SpecMenuObj)
            Event_CreateSpecMenu(client);
}

//处理Spec列表事件
public int Handle_ExecSpecMenu(Menu menu, MenuAction action, int client, int item)
{
    char useridStr[255];
    int target = -1, userid;
    if (!IsValidClient(client)) return 0;
    if (action != MenuAction_Select) return 0;
    GetMenuItem(menu, item, useridStr, 255);
    userid = StringToInt(useridStr);
    target = GetClientOfUserId(userid);
    if (!IsValidClient(target) || IsFakeClient(target) || IsSpectator(target)) return 0;
    CPrintToChatAll(messages[Msg_ForceSpectated], target);
    ChangeClientTeam(target, 1);

    return 1;
}

//处理Class列表事件
public int Handle_ExecClassMenu(Menu menu, MenuAction action, int client, int item)
{
    //1=Smoker, 2=Boomer, 3=Hunter, 4=Spitter, 5=Jockey, 6=Charger 7=Witch(Unsafe) 8=Tank
    if (!IsValidClient(client)) return 0;
    if (action != MenuAction_Select) return 0;
    if (IsInfected(client))
    {
        if (item < 8 && item != 6)
            L4D_SetClass(client, item + 1);
    }
    else
    {
        char model[64];
        GetMenuItem(menu, item, model, 64);

        SetEntProp(client, Prop_Send, "m_survivorCharacter", item);
        SetEntityModel(client, model);
    }

    return 1;
}

//处理Clip列表事件
public int Handle_ExecClipMenu(Menu menu, MenuAction action, int client, int item)
{
    if (!IsValidClient(client)) return 0;
    if (action != MenuAction_Select) return 0;
    if(playerGhostHandle[client] == INVALID_HANDLE) return 0;
    if(item == 0) SetEntityMoveType(client, MOVETYPE_NOCLIP);
    if(item == 1) SetEntityMoveType(client, MOVETYPE_WALK);

    return 1;
}

                /*  ########################################
                            <==HandleFunctions:END
                ########################################    */


                /*  ########################################
                            MyCmdHookEvent:START==>
                ########################################    */

//玩家接管克命令
public Action Cmd_PlayTank(int client, any args)
{
    if (!IsValidClient(client)) return;

    if (!canInfectedJoin)
    {
        CPrintToChat(client, messages[Msg_InfectedDisabled]);
        return;
    }

    if (IsInfected(client))
    {
        if (tankPlayer != -1)
            CPrintToChat(client, messages[Msg_TankBeenTaken], tankPlayer);
        else if (L4D2_IsTankInPlay())
            CPrintToChat(client, messages[Msg_TankAI]);
        else
        {
            tankPlayer = client;
            CPrintToChatAll(messages[Msg_WillTakeTank], tankPlayer);
        }
    }
    else CPrintToChat(client, messages[Msg_CantTakeTank]);
}

//玩家更换特感命令
public Action Cmd_ChangeClass(int client, any args)
{
    if (!IsValidClient(client) || IsTank(client) ||
        ((!IsGhost(client) || playerGhostHandle[client] == INVALID_HANDLE) && IsInfected(client)) ||
        (!IsPlayerAlive(client) && IsSurvivor(client))) return;

    if (!IsSpectator(client))
        Event_CreateClassMenu(client);
    else
        CPrintToChat(client, messages[Msg_UnableToUse]);
}

//给予玩家子弹
public Action Cmd_GiveClientAmmo(int client, any args)
{
    if (!IsValidClient(client)) return;

    if (IsSurvivor(client))
        BypassAndExecuteCommand(client, "give", "ammo");
}

//玩家进入旁观指令（被控禁止旁观）
public Action Cmd_AFKTurnClientToSpe(int client, any args)
{
    if (!IsValidClient(client)) return;

    if (!IsSurvivorPinned(client))
        CreateTimer(2.5, Timer_CheckAway, client, TIMER_FLAG_NO_MAPCHANGE);
}

//玩家切换队伍指令
public Action Cmd_AFKTurnClientTeam(int client, int args)
{
    if (!IsValidClient(client)) return;

    if (args == 1)
    {
        char arg[16];
        GetCmdArg(args, arg, sizeof(arg));
        switch(StringToInt(arg))
        {
            case 1:
            {
                ChangeClientTeam(client, 1);
            }
            case 2:
            {
                if (!IsSurvivorTeamFull())
                    ChangePlayerSurvivor(client);
            }
            case 3:
            {
                if (IsSurvivor(client) && isRoundStart)
                    CPrintToChat(client, messages[Msg_RoundStart]);
                else if (IsInfected(client))
                    CPrintToChat(client, messages[Msg_AlreadyInfected]);
                else
                {
                    ChangeClientTeam(client, 3);
                    CPrintToChatAll(messages[Msg_JoinInfected], client);
                    CPrintToChat(client, messages[Msg_JoinSINotice]);
                }
            }
        }
    }
}

//玩家加入生还指令
public Action Cmd_AFKTurnClientToSurvivor(int client, any args)
{
    if (!IsValidClient(client)) return;

    if (!IsSurvivorTeamFull() || !canInfectedJoin)
        ChangePlayerSurvivor(client);
}

//玩家加入特感指令
public Action Cmd_AFKTurnClientToInfected(int client, any args)
{
    if (!IsValidClient(client)) return;

    if (!canInfectedJoin)
    {
        CPrintToChat(client, messages[Msg_InfectedDisabled]);
        if (IsInfected(client))
            ChangeClientTeam(client, 1);
        return;
    }

    if (IsInfected(client))
    {
        CPrintToChat(client, messages[Msg_AlreadyInfected]);
        return;
    }

    if (!isRoundStart || !IsSurvivor(client))
    {
        ChangeClientTeam(client, 3);
        CPrintToChatAll(messages[Msg_JoinInfected], client);
        CPrintToChat(client, messages[Msg_JoinSINotice]);
    }
    else CPrintToChat(client, messages[Msg_RoundStart]);
}

//重启地图命令
public Action Cmd_RestartMap(int client, any args)
{
    CrashMap();
}

//重启服务器命令
public Action Cmd_RestartServer(int client, any args)
{
    CrashServer();
}

                /*  ########################################
                            <==MyCmdHookEvent:END
                ########################################    */


                /*  ########################################
                            OtherFunctions:START==>
                ########################################    */

//检查模型
void CheckModel()
{
    if (!IsModelPrecached("models/survivors/survivor_teenangst.mdl"))
        PrecacheModel("models/survivors/survivor_teenangst.mdl");
    if (!IsModelPrecached("models/survivors/survivor_biker.mdl"))
        PrecacheModel("models/survivors/survivor_biker.mdl");
    if (!IsModelPrecached("models/survivors/survivor_manager.mdl"))
        PrecacheModel("models/survivors/survivor_manager.mdl");
    if (!IsModelPrecached("models/survivors/survivor_namvet.mdl"))
        PrecacheModel("models/survivors/survivor_namvet.mdl");
    if (!IsModelPrecached("models/survivors/survivor_gambler.mdl"))
        PrecacheModel("models/survivors/survivor_gambler.mdl");
    if (!IsModelPrecached("models/survivors/survivor_coach.mdl"))
        PrecacheModel("models/survivors/survivor_coach.mdl");
    if (!IsModelPrecached("models/survivors/survivor_mechanic.mdl"))
        PrecacheModel("models/survivors/survivor_mechanic.mdl");
    if (!IsModelPrecached("models/survivors/survivor_producer.mdl"))
        PrecacheModel("models/survivors/survivor_producer.mdl");
}

//设置玩家为生还
void ChangePlayerSurvivor(int client)
{
    if (!IsValidClient(client)) return;

    ClientCommand(client, "jointeam survivor");
    if (FindSurvivorBot() > 0)
    {
        int flags = GetCommandFlags("sb_takecontrol");
        SetCommandFlags("sb_takecontrol", flags & (~FCVAR_CHEAT));
        FakeClientCommand(client, "sb_takecontrol");
        SetCommandFlags("sb_takecontrol", flags);
    }
}

// //执行指令
// void BypassAndExecuteCommand(int client, const char[] strCommand, const char[] strParam)
// {
//     if (!IsValidClient(client)) return;

//     int flags = GetCommandFlags(strCommand);
//     SetCommandFlags(strCommand, flags & (~FCVAR_CHEAT));
//     FakeClientCommand(client, "%s %s", strCommand, strParam);
//     SetCommandFlags(strCommand, flags);
// }

//重启地图
void CrashMap()
{
    char mapname[64];
    GetCurrentMap(mapname, 64);
    ServerCommand("changelevel %s", mapname);
}

//重启服务器
void CrashServer()
{
    SetCommandFlags("crash", GetCommandFlags("crash") & (~FCVAR_CHEAT));
    ServerCommand("crash");
}

//重置玩家血量
void RestoreHealth()
{
    for (int client = 1; client <= MaxClients; client++)
        if (IsSurvivor(client))
        {
            BypassAndExecuteCommand(client, "give", "health");
            SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
            SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
            SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
        }
}

//重置玩家背包
void ResetInventory()
{
    for (int client = 1; client <= MaxClients; client++)
        if (IsSurvivor(client))
        {
            for (int i = 0; i < 5; i++)
                DeleteInventoryItem(client, i);

            BypassAndExecuteCommand(client, "give", "pistol");
        }
}

//删除背包物品
void DeleteInventoryItem(int client, int slot)
{
    if (!IsValidClient(client)) return;

    int item = GetPlayerWeaponSlot(client, slot);
    if (item > 0)
        RemovePlayerItem(client, item);
}

//给予背包物品
void GiveInventoryItems(int client)
{
    if (!IsValidClient(client)) return;

    if (IsFakeClient(client))
    {
        for (int i = 0; i < 1; i++)
            DeleteInventoryItem(client, i);

        //BypassAndExecuteCommand(client, "give", "shotgun_chrome");
        BypassAndExecuteCommand(client, "give", "pistol_magnum");
        BypassAndExecuteCommand(client, "give", "pumpshotgun");

        SetEntProp(client, Prop_Send, "m_bAutoAimTarget", 1);
        SetEntProp(client, Prop_Send, "m_bAllowAutoMovement", 1);
        SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.2);
    }
    else BypassAndExecuteCommand(client, "give", "melee");
}

//切换玩家模式
void SetPlayerMode(int client, int team)
{
    if (team == 2)
        SendConVarValue(client, FindConVar("mp_gamemode"), "coop");
    else
        SendConVarValue(client, FindConVar("mp_gamemode"), "versus");
}

//关闭处死玩家特感Handle
void CloseGhostHandle(int client)
{
    if (!IsValidClient(client)) return;

    if (playerGhostHandle[client] != INVALID_HANDLE)
    {
        CloseHandle(playerGhostHandle[client]);
        playerGhostHandle[client] = INVALID_HANDLE;
    }
}

//获得Bot生还
int FindSurvivorBot()
{
    for (int client = 1; client <= MaxClients; client++)
        if (IsClientInGame(client) && IsFakeClient(client) && IsSurvivor(client))
            return client;

    return -1;
}

//随机获得玩家特感Client
int FindRandomInfected()
{
    for (int i = 1; i <= MaxClients; i++)
        if (IsInfected(i) && !IsFakeClient(i)  && GetRandomInt(0, 5) > 3)
            return i;
    return -1;
}

                /*  ########################################
                            <==OtherFunctions:END
                ########################################    */