#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#define VERSION "0.9.7"

new Handle:melee_damage;
new Handle:head_damage;
new Handle:chest_damage;
new Handle:stomach_damage;
new Handle:arm_damage;
new Handle:leg_damage;
new Handle:ff_damage;
new Handle:shove_damage;
new down_counts[66];

public Plugin:myinfo =
{
    name = "L4D Damage",
    description = "Adds damage related cvars.",
    author = "Voiderest",
    version = VERSION,
    url = "N/A"
};

public OnPluginStart()
{
    melee_damage = CreateConVar("l4d_damage_melee", "0", "0: 近战无伤害.", FCVAR_REPLICATED|FCVAR_GAMEDLL|FCVAR_NOTIFY, true, 0.0, true, 1.0);
    head_damage = CreateConVar("l4d_damage_head_only", "0", "1: 只允许头部伤害.", FCVAR_REPLICATED|FCVAR_GAMEDLL|FCVAR_NOTIFY, true, 0.0, true, 1.0);
    chest_damage = CreateConVar("l4d_damage_chest", "1", "1: 允许胸部伤害.", FCVAR_REPLICATED|FCVAR_GAMEDLL|FCVAR_NOTIFY, true, 0.0, true, 1.0);
    stomach_damage = CreateConVar("l4d_damage_stomach", "1", "1: 允许腹部伤害.", FCVAR_REPLICATED|FCVAR_GAMEDLL|FCVAR_NOTIFY, true, 0.0, true, 1.0);
    arm_damage = CreateConVar("l4d_damage_arm", "0", "1: 允许手臂伤害.", FCVAR_REPLICATED|FCVAR_GAMEDLL|FCVAR_NOTIFY, true, 0.0, true, 1.0);
    leg_damage = CreateConVar("l4d_damage_leg", "1", "1: 允许腿部伤害.", FCVAR_REPLICATED|FCVAR_GAMEDLL|FCVAR_NOTIFY, true, 0.0, true, 1.0);
    ff_damage = CreateConVar("l4d_damage_ff", "1", "0: 关闭友伤 1: 正常友伤 2: FF 反伤 3: 双方均摊友伤(2和3估计有问题)", FCVAR_REPLICATED|FCVAR_GAMEDLL|FCVAR_NOTIFY, true, 0.0, true, 3.0);
    shove_damage = CreateConVar("l4d_damage_shove", "0", "推击对玩家造成的伤害", FCVAR_REPLICATED|FCVAR_GAMEDLL|FCVAR_NOTIFY, true, 0.0, false, 0.0);
    HookConVarChange(head_damage, Headshot_Only);
    HookEvent("infected_hurt", Event_Infected_Hurt, EventHookMode_Pre); 
    HookEvent("player_hurt", Event_Player_Hurt, EventHookMode_Pre);
    HookEvent("player_shoved", Event_Player_Shoved, EventHookMode_Pre);
    HookEvent("player_incapacitated", Event_Player_Incapacitated, EventHookMode_Pre);
    HookEvent("heal_success", Event_Heal_Success, EventHookMode_Pre);
    HookEvent("player_death", Event_Player_Death, EventHookMode_Pre);
    HookEvent("player_first_spawn", Event_Player_First_Spawn, EventHookMode_Pre);
    AutoExecConfig(true, "MirroredFFDamageIncap");
}

public OnClientPostAdminCheck(client)
{
    GetConVarInt(head_damage);
}

public Action:Event_Infected_Hurt(Handle:event, String:name[], bool:dontBroadcast)
{
    new zombieid = GetEventInt(event, "entityid");
    new hitgroup = GetEventInt(event, "hitgroup");
    new amount = GetEventInt(event, "amount");
    new type = GetEventInt(event, "type");
    return (type == 128 && GetConVarInt(melee_damage)) || (GetConVarInt(head_damage) == 1 || (hitgroup == 2 && GetConVarInt(chest_damage)) || (hitgroup == 3 && GetConVarInt(stomach_damage)) || ((hitgroup == 4 || hitgroup == 5) && GetConVarInt(arm_damage) && ((hitgroup == 6 || hitgroup == 7) && GetConVarInt(leg_damage))));
}

public Action:Event_Player_Hurt(Handle:event, String:name[], bool:dontBroadcast)
{
    new client_userid = GetEventInt(event, "userid");
    new client = GetClientOfUserId(client_userid);
    new attacker_userid = GetEventInt(event, "attacker");
    new attacker = GetClientOfUserId(attacker_userid);
    new health = GetEventInt(event, "health");
    new dmg = GetEventInt(event, "dmg_health");
    new type = GetEventInt(event, "type");
    new fftype = GetConVarInt(ff_damage);
    if (attacker && client && fftype == 1 && (type == 64 || type == 8 || type == 2056) && GetClientTeam(attacker) == GetClientTeam(client))
    {
        return Plugin_Continue;
    }
    FF_Damage(client, attacker, dmg, fftype, health);
    return Plugin_Continue;
}

public Action:Event_Player_Shoved(Handle:event, String:name[], bool:dontBroadcast)
{
    new attacker_userid = GetEventInt(event, "attacker");
    new attacker = GetClientOfUserId(attacker_userid);
    new client_userid = GetEventInt(event, "userid");
    new client = GetClientOfUserId(client_userid);
    new damage = GetConVarInt(shove_damage);
    new fftype = GetConVarInt(ff_damage);
    if (attacker && client && fftype >= 2 && damage <= 0 && GetClientTeam(attacker) == GetClientTeam(client))
    {
        return Plugin_Continue;
    }
    new health = GetEntProp(client, Prop_Data, "m_iHealth", 4, 0);
    if (fftype == 1)
    {
        SetEntProp(client, Prop_Data, "m_iHealth", health - damage, 4, 0);
        return Plugin_Continue;
    }
    FF_Damage(client, attacker, damage, GetConVarInt(ff_damage), health);
    return Plugin_Continue;
}

public FF_Damage(client, attacker, dmg, fftype, health)
{
    if (fftype)
    {
        if (fftype == 2)
        {
            SetEntProp(client, Prop_Data, "m_iHealth", dmg + health, 4, 0);
            health = GetEntProp(attacker, Prop_Data, "m_iHealth", 4, 0);
            if (0 >= health - dmg)
            {
                IgniteEntity(attacker, 5.0, false, 0.0, false);
                CreateTimer(3.0, SlapTimer, attacker);
                ClientCommand(attacker, "play UI/beep22");
                if (down_counts[GetClientOfUserId(attacker)] == 2)
                {
                    SlapPlayer(attacker, 6, false);
                }
            }
            SetEntProp(attacker, Prop_Data, "m_iHealth", health - dmg, 4, 0);
        }
        dmg /= 2;
        SetEntProp(client, Prop_Data, "m_iHealth", dmg + health, 4, 0);
        health = GetEntProp(attacker, Prop_Data, "m_iHealth", 4, 0);
        if (0 >= health - dmg)
        {
            IgniteEntity(attacker, 5.0, false, 0.0, false);
            if (down_counts[GetClientOfUserId(attacker)] == 2)
            {
                SlapPlayer(attacker, 1, false);
            }
        }
        SetEntProp(attacker, Prop_Data, "m_iHealth", health - dmg, 4, 0);
    }
    else
    {
        SetEntProp(client, Prop_Data, "m_iHealth", dmg + health, 4, 0);
    }
}

public Action:Event_Player_Incapacitated(Handle:event, String:name[], bool:dontBroadcast)
{
    new id = GetClientOfUserId(GetEventInt(event, "userid"));
    down_counts[id] = down_counts[id] + 1;
    PrintToChatAll("\x04 * * * 一个队友倒地了!");
    PrintToChatAll("\x04 * * * 警告: \x03过多的友伤会导致你死亡");
    PrintToChatAll("\x04 * * * \x03倒地时使用 \x04!helpme \x03指令激活求救信号灯,让队友知道你有麻烦了.");
    return Plugin_Continue;
}

public Action:Event_Heal_Success(Handle:event, String:name[], bool:dontBroadcast)
{
    down_counts[GetClientOfUserId(GetEventInt(event, "subject"))] = 0;
    return Plugin_Continue;
}

public Action:Event_Player_Death(Handle:event, String:name[], bool:dontBroadcast)
{
    down_counts[GetClientOfUserId(GetEventInt(event, "userid"))] = 0;
    return Plugin_Continue;
}

public Action:Event_Player_First_Spawn(Handle:event, String:name[], bool:dontBroadcast)
{
    down_counts[GetClientOfUserId(GetEventInt(event, "userid"))] = 0;
    return Plugin_Continue;
}

public Headshot_Only(Handle:cvar, String:oldVal[], String:newVal[])
{
    StringToInt(newVal, 10);
}

public Action:SlapTimer(Handle:timer, any:attacker)
{
    SlapPlayer(attacker, 1, false);
    ClientCommand(attacker, "play UI/helpful_event_1.wav");
    return Plugin_Continue;
}