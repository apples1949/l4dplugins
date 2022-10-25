#pragma semicolon 1
#include <sourcemod>

new Handle:l4d2_msg_system_zh_heal_info;
new Handle:l4d2_msg_system_zh_tank_spawn;
new Handle:l4d2_msg_system_zh_tank_killed;
new Handle:l4d2_msg_system_zh_witch_killed;
new Handle:l4d2_msg_system_zh_witch_harasser_set;
new Handle:l4d2_msg_system_zh_player_death;
new Handle:l4d2_msg_system_zh_create_panic_event;
new Handle:l4d2_msg_system_zh_player_incapacitated;
new Handle:l4d2_msg_system_zh_player_in_out;
new Handle:l4d2_msg_system_zh_kill_in;
new Handle:l4d2_msg_system_zh_save_up;
new Handle:l4d2_msg_system_zh_use_def;

public Plugin:myinfo =
{
    name = "L4D2 Message System",
    author = "LK!",
    description = "A message system for L4D2.",
    version = "PLUGIN_VERSION",
    url = ""
};

public OnPluginStart()
{
    CreateConVar("l4d2_msg_system_zh_version", "1.0", "l4d2_msg_system_zh Version", 8448, false, 0.0, false, 0.0);
    l4d2_msg_system_zh_heal_info = CreateConVar("l4d2_msg_system_zh_heal_info", "1", "显示治疗信息", 0, false, 0.0, false, 0.0);
    l4d2_msg_system_zh_tank_spawn = CreateConVar("l4d2_msg_system_zh_tank_spawn", "0", "开启tank产生提示", 0, false, 0.0, false, 0.0);
    l4d2_msg_system_zh_tank_killed = CreateConVar("l4d2_msg_system_zh_tank_killed", "0", "杀死tank提示", 0, false, 0.0, false, 0.0);
    l4d2_msg_system_zh_witch_killed = CreateConVar("l4d2_msg_system_zh_witch_killed", "0", "杀死witch提示", 0, false, 0.0, false, 0.0);
    l4d2_msg_system_zh_witch_harasser_set = CreateConVar("l4d2_msg_system_zh_witch_harasser_set", "1", "惊动witch提示", 1, false, 0.0, false, 0.0);
    l4d2_msg_system_zh_player_death = CreateConVar("l4d2_msg_system_zh_player_death", "0", "玩家死亡提示", 0, false, 0.0, false, 0.0);
    l4d2_msg_system_zh_create_panic_event = CreateConVar("l4d2_msg_system_zh_create_panic_event", "0", "触发警报提示", 0, false, 0.0, false, 0.0);
    l4d2_msg_system_zh_player_incapacitated = CreateConVar("l4d2_msg_system_zh_player_incapacitated", "1", "倒地提示", 0, false, 0.0, false, 0.0);
    l4d2_msg_system_zh_player_in_out = CreateConVar("l4d2_msg_system_zh_player_in_out", "0", "玩家进入退出提示", 0, false, 0.0, false, 0.0);
    l4d2_msg_system_zh_kill_in = CreateConVar("l4d2_msg_system_zh_kill_in", "1", "击杀特感提示（聊天框内）", 0, false, 0.0, false, 0.0);
    l4d2_msg_system_zh_save_up = CreateConVar("l4d2_msg_system_zh_save_up", "1", "救起玩家提示", 0, false, 0.0, false, 0.0);
    l4d2_msg_system_zh_use_def = CreateConVar("l4d2_msg_system_zh_use_def", "1", "复活玩家提示", 0, false, 0.0, false, 0.0);

    HookEvent("heal_success", HealSuccess);
    HookEvent("tank_spawn", tankSpawn);
    HookEvent("witch_killed", witchKilled);
    HookEvent("witch_harasser_set", witchHrasserSet);
    HookEvent("tank_killed", tankKilled);
    HookEvent("player_death", playerDeath);
    HookEvent("player_incapacitated_start", playerIncapacitated);
    HookEvent("revive_success", EventReviveSuccess);
    HookEvent("defibrillator_used", EventDefiSuccess);
    HookEvent("create_panic_event", createPanicEvent);

    AutoExecConfig(true, "l4d2_msg_system_zh");
}

public HealSuccess(Handle:event, String:name[], bool:dontBroadcast)
{
    new UserId = GetEventInt(event, "userid", 0);
    new Subject = GetEventInt(event, "subject", 0);
    new healee = GetClientOfUserId(Subject);
    new healer = GetClientOfUserId(UserId);
    new String:PName1[64];
    new String:PName2[64];
    if (GetConVarInt(l4d2_msg_system_zh_heal_info) == 1)
    {
        GetClientName(healer, PName1, 64);
        GetClientName(healee, PName2, 64);
        if (StrEqual(PName1, PName2, true))
        {
            PrintToChatAll("%s\x04%s \x03治疗了自己", "\x05[提示]\x03 ", PName1);
        }
        PrintToChatAll("%s\x04%s \x03治疗了\x04 %s\x03", "\x05[提示]\x03 ", PName1, PName2);
    }
    return 0;
}

public Action:tankSpawn(Handle:event, String:name[], bool:dontBroadcast)
{
    if (GetConVarInt(l4d2_msg_system_zh_tank_spawn) == 1)
    {
        new tank = GetClientOfUserId(GetEventInt(event, "userid", 0));
        PrintToChatAll("%s\x04%N \x03根据当前人数血量自动调整为 \x04%i", "\x05[提示]\x03 ", tank, GetClientHealth(tank));
    }
    return Plugin_Continue;
}

public Action:tankKilled(Handle:event, String:name[], bool:dontBroadcast)
{
    if (GetConVarInt(l4d2_msg_system_zh_tank_killed) == 1)
    {
        new client = GetClientOfUserId(GetEventInt(event, "userid", 0));
        new attacker = GetClientOfUserId(GetEventInt(event, "attacker", 0));
        new class = GetEntProp(client, PropType:0, "m_zombieClass", 4, 0);
        if (class == 8 && attacker && GetClientTeam(attacker) == 2)
        {
            PrintToChatAll("%s\x04%N \x03的致命一击结束了 \x04%N \x03的性命！", "\x05[提示]\x03 ", attacker, client);
        }
    }
    return Plugin_Continue;
}

public Action:witchKilled(Handle:event, String:name[], bool:dontBroadcast)
{
    if (GetConVarInt(l4d2_msg_system_zh_witch_killed) == 1)
    {
        new player = GetClientOfUserId(GetEventInt(event, "userid", 0));
        if (player && IsClientInGame(player))
        {
            PrintToChatAll("%s\x04%N \x03的致命一击结束了 \x04Witch \x03的性命！", "\x05[提示]\x03 ", player);
        }
    }
    return Plugin_Continue;
}

public Action:witchHrasserSet(Handle:event, String:name[], bool:dontBroadcast)
{
    if (GetConVarInt(l4d2_msg_system_zh_witch_harasser_set) == 1)
    {
        new player = GetClientOfUserId(GetEventInt(event, "userid", 0));
        PrintHintTextToAll("%N 惊扰了Witch", player);
        PrintToChatAll("%s\x04%N \x03嫖妹又不给钱 被妹子追杀中！", "\x05[提示]\x03 ", player);
    }
    return Plugin_Continue;
}

public Action:playerDeath(Handle:event, String:name[], bool:dontBroadcast)
{
    if (GetConVarInt(l4d2_msg_system_zh_player_death) == 1)
    {
        new player = GetClientOfUserId(GetEventInt(event, "userid", 0));
        new attacker = GetClientOfUserId(GetEventInt(event, "attacker", 0));
        if (player && GetClientTeam(player) == 2)
        {
            if (attacker && attacker != player)
            {
                PrintToChatAll("%s\x04%N \x03杀死了 \x04%N\x03", "\x05[提示]\x03 ", attacker, player);
                PrintHintTextToAll("%N 跪了", player);
            }
            else
            {
                PrintToChatAll("%s\x04%N\x03 跪了", "\x05[提示]\x03 ", player);
                PrintHintTextToAll("%N 跪了", player);
            }
        }
        else
        {
            if (GetConVarInt(l4d2_msg_system_zh_kill_in) == 1 && player && GetClientTeam(player) == 3)
            {
                new class = GetEntProp(player, PropType:0, "m_zombieClass", 4, 0);
                if (class == 1)
                {
                    PrintToChat(attacker, "\x01击杀 Smoker");
                }
                else
                {
                    if (class == 2)
                    {
                        PrintToChat(attacker, "\x01击杀 Boomer");
                    }
                    if (class == 3)
                    {
                        PrintToChat(attacker, "\x01击杀 Hunter");
                    }
                    if (class == 4)
                    {
                        PrintToChat(attacker, "\x01击杀 Spitter");
                    }
                    if (class == 5)
                    {
                        PrintToChat(attacker, "\x01击杀 Jockey");
                    }
                    if (class == 6)
                    {
                        PrintToChat(attacker, "\x01击杀 Charger");
                    }
                }
            }
        }
    }
    return Plugin_Continue;
}

public Action:createPanicEvent(Handle:event, String:name[], bool:dontBroadcast)
{
    if (GetConVarInt(l4d2_msg_system_zh_create_panic_event) == 1)
    {
        new player = GetClientOfUserId(GetEventInt(event, "userid", 0));
        if (player && !IsFakeClient(player) && IsClientInGame(player))
        {
            PrintHintTextToAll("%N 触发了警报！", player);
            PrintToChatAll("%s\x04%N\x03 这个蠢货又双叒叕触发了警报！！！", "\x05[提示]\x03 ", player);
        }
    }
    return Plugin_Continue;
}

public Action:playerIncapacitated(Handle:hEvent, String:strName[], bool:DontBroadcast)
{
    if (GetConVarInt(l4d2_msg_system_zh_player_incapacitated))
    {
        new client = GetClientOfUserId(GetEventInt(hEvent, "userid", 0));
        decl String:player_name[68];
        GetClientName(client, player_name, 65);
        decl String:buff[168];
        new attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker", 0));
        if (attacker)
        {
            decl String:player_name2[68];
            GetClientName(attacker, player_name2, 65);
            if (GetClientTeam(attacker) == 2 || GetClientTeam(attacker) == 3)
            {
                Format(buff, 165, "%s\x04%s \x03制服了\x04 %s", "\x05[提示]\x03 ", player_name2, player_name);
                PrintToChatAll(buff);
            }
        }
        else
        {
            Format(buff, 165, "%s\x04%s \x03倒下了", "\x05[提示]\x03 ", player_name);
            PrintToChatAll(buff);
        }
        return Plugin_Continue;
    }
    return Plugin_Continue;
}

public EventReviveSuccess(Handle:event, String:name[], bool:dontBroadcast)
{
    new player = GetClientOfUserId(GetEventInt(event, "userid", 0));
    new target = GetClientOfUserId(GetEventInt(event, "subject", 0));
    decl String:targetName[64];
    decl String:palyerName[64];
    GetClientName(target, targetName, 64);
    GetClientName(player, palyerName, 64);
    if (target != player)
    {
        if (GetConVarInt(l4d2_msg_system_zh_save_up) == 1)
        {
            PrintToChatAll("%s\x04%s \x03救起了 \x04%s ", "\x05[提示]\x03 ", palyerName, targetName);
        }
    }
    return 0;
}

public EventDefiSuccess(Handle:event, String:name[], bool:dontBroadcast)
{
    new player = GetClientOfUserId(GetEventInt(event, "userid", 0));
    new target = GetClientOfUserId(GetEventInt(event, "subject", 0));
    decl String:targetName[64];
    decl String:palyerName[64];
    GetClientName(target, targetName, 64);
    GetClientName(player, palyerName, 64);
    if (target != player)
    {
        if (GetConVarInt(l4d2_msg_system_zh_use_def) == 1)
        {
            PrintToChatAll("%s\x04 %s \x03复活了 \x04%s ", "\x05[提示]\x03 ", palyerName, targetName);
            PrintHintTextToAll("%s 复活了 %s", palyerName, targetName);
        }
    }
    return 0;
}

public OnClientConnected(client)
{
    if (GetConVarInt(l4d2_msg_system_zh_player_in_out) == 1 && IsValidPlayer(client))
    {
        if (!IsFakeClient(client))
        {
            PrintToChatAll("%s\x04%N \x03正在连接服务器，服务器当前总人数 \x04%i \x03人.", "\x05[提示]\x03 ", client, getCurPlayerCount());
        }
    }
}

public Action:Event_PlayerDisconnect(Handle:event, String:strName[], bool:bDontBroadcast)
{
    PrintToChatAll("\x04[提示]\x03  有人离开了游戏");
    return Plugin_Continue;
}

public Action:Event_PlayerConnect(Handle:event, String:strName[], bool:bDontBroadcast)
{
    PrintToChatAll("\x04[提示]\x03  有人进入了游戏");
    return Plugin_Continue;
}

public OnClientDisconnect(client)
{
    if (GetConVarInt(l4d2_msg_system_zh_player_in_out) == 1 && IsValidPlayer(client) && !IsFakeClient(client))
    {
        PrintToChatAll("%s\x04%N \x03离开了服务器，服务器当前总人数 \x04%i \x03人.", "\x05[提示]\x03 ", client, getCurPlayerCount() + -1);
    }
}

bool:IsValidPlayer(client)
{
    if (0 < client <= MaxClients)
    {
        return true;
    }
    return false;
}

getCurPlayerCount()
{
    new j;
    new i = 1;
    while (i <= MaxClients)
    {
        if (IsClientConnected(i) && !IsFakeClient(i))
        {
            j++;
        }
        i++;
    }
    return j;
}

