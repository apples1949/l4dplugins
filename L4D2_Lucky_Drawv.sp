#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new Handle:hTimerAchieved[66];
new Handle:hTimerMiniFireworks[66];
new Handle:hTimerLoopEffect[66];
bool rolled[66];
bool sift[66];
int count[66];
int L[66];
int gain[66];
int prize1[66];
int prize2[66];
int prize3[66];
int prize4[66];
int prize5[66];
int prize6[66];
new Handle:StopTime[66];
new Handle:GodTime[66];
new Handle:GravityTime[66];
new Handle:kills;
new Handle:infected_count;
new Handle:tank_count;
new Handle:LDW_MSG_time;
new Handle:timer_handle;

public OnPluginStart()
{
	RegConsoleCmd("sm_ldw", LDW, "", 0);
	RegConsoleCmd("sm_setldw", setLDW, "", 0);
	HookEvent("infected_death", infected_death, EventHookMode:1);
	HookEvent("player_death", player_death, EventHookMode:1);
	HookEvent("round_start", round_start, EventHookMode:1);
	HookEvent("round_end", Event_RoundEnd, EventHookMode:1);
	HookEvent("finale_win", Event_RoundEnd, EventHookMode:1);
	HookEvent("mission_lost", Event_RoundEnd, EventHookMode:1);
	HookEvent("map_transition", Event_RoundEnd, EventHookMode:1);
	kills = CreateConVar("common_kills", "50", "击杀多少小僵尸可获得一次抽奖机会", 262144, false, 0.0, false, 0.0);
	infected_count = CreateConVar("infected_kill_counts", "1", "击杀一个特感可获得多少次抽奖机会", 262144, false, 0.0, false, 0.0);
	tank_count = CreateConVar("tank_iskill_count", "2", "tank死亡时所有幸存者可获得多少次抽奖机会", 262144, false, 0.0, false, 0.0);
	LDW_MSG_time = CreateConVar("ldw_msg_time", "60.0", "抽奖系统公告多少时间播放一次", 262144, false, 0.0, false, 0.0);
	AutoExecConfig(true, "L4D2_Lucky_Draw", "sourcemod");
}

public OnMapStart()
{
	new i = 1;
	while (i <= MaxClients)
	{
		rolled[i] = false;
		sift[i] = true;
		i++;
	}
	PrecacheSound("ui/littlereward.wav", true);
	PrecacheSound("level/gnomeftw.wav", true);
	PrecacheSound("npc/moustachio/strengthattract05.wav", true);
	PrecacheSound("buttons/button14.wav", true);
}

public OnClientDisconnect(Client)
{
	if (!IsFakeClient(Client))
	{
		L[Client] = 0;
		if (StopTime[Client])
		{
			KillTimer(StopTime[Client], false);
			StopTime[Client] = INVALID_HANDLE;
		}
		PrintToServer("清除玩家%N的抽奖次数", Client);
	}
}

public Action:round_start(Handle:event, String:name[], bool:dontBroadcast)
{
	if (timer_handle)
	{
		KillTimer(timer_handle, false);
		timer_handle = INVALID_HANDLE;
	}
	if (!timer_handle)
	{
		timer_handle = CreateTimer(GetConVarFloat(LDW_MSG_time), Msg, any:0, 1);
	}
	return Action:0;
}

public Action:infected_death(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new id = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (1 <= id <= MaxClients && IsClientInGame(id))
	{
		if (GetClientTeam(id) == 2 && !IsFakeClient(id))
		{
			if (GetConVarInt(kills) > count[id])
			{
				count[id] += 1;
				return Action:0;
			}
			count[id] = 0;
			L[id] += 1;
			PrintHintText(id, "抽奖机会+1");
		}
	}
	return Action:0;
}

public Action:player_death(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "attacker"));
	new vic = GetClientOfUserId(GetEventInt(event, "userid"));
	if ((1 <= client <= MaxClients && IsClientInGame(client)) && (1 <= vic <= MaxClients && IsClientInGame(vic)))
	{
		if (IsClientInGame(vic) && IsClientInGame(client) && !IsFakeClient(client))
		{
			if (GetClientTeam(client) == 2 && GetClientTeam(vic) == 3)
			{
				if (GetEntProp(vic, PropType:0, "m_zombieClass", 4, 0) != 8 || IsWitch(vic))
				{
					PrintHintText(client, "抽奖机会+%d", GetConVarInt(infected_count));
					L[client] += GetConVarInt(infected_count);
				}
				else
				{
					new i = 1;
					while (i <= MaxClients)
					{
						if (IsClientInGame(i))
						{
							if (GetClientTeam(i) == 2)
							{
								PrintHintText(i, "抽奖机会+%d", GetConVarInt(tank_count));
								L[i] += GetConVarInt(tank_count);
							}
						}
						i++;
					}
				}
			}
		}
		if (GetClientTeam(vic) == 2 && rolled[vic])
		{
			KillTimer(StopTime[vic], false);
			StopTime[vic] = INVALID_HANDLE;
			rolled[vic] = false;
			sift[vic] = true;
			PrintToChat(vic, "\x04由于角色死亡,抽奖强制終止!");
			PrintCenterText(vic, "抽奖终止!");
		}
	}
	return Action:0;
}

public Action:Event_RoundEnd(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new i = 1;
	while (i <= MaxClients)
	{
		if (IsClientInGame(i))
		{
			if (StopTime[i])
			KillTimer(StopTime[i], false);
			StopTime[i] = INVALID_HANDLE;
		}
		i++;
	}
	if (timer_handle)
	{
		KillTimer(timer_handle, false);
		timer_handle = INVALID_HANDLE;
	}
	i = 1;
	while (i <= MaxClients)
	{
		if (IsClientInGame(i))
		{
			rolled[i] = false;
			sift[i] = true;
		}
		i++;
	}
	return Action:0;
}

public Action:setLDW(Client, args)
{
	if (GetClientTeam(Client) == 2)
	{
		PrintToChat(Client, "增加100次抽奖次数！");
		L[Client] = L[Client] + 100;
	}
	else
	{
		PrintToChat(Client, "此功能只有幸存者可以使用!");
	}
	return Action:0;
}

public Action:LDW(Client, args)
{
	if (GetClientTeam(Client) == 2)
	{
		draw_function(Client);
	}
	else
	{
		PrintToChat(Client, "此功能只有幸存者可以使用!");
	}
	return Action:0;
}

public Action:draw_function(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel(Handle:0);
	if (!rolled[Client])
	{
		Format(line, 256, "   -抽奖系统列表-");
		SetPanelTitle(menu, line, false);
		if (0 < L[Client])
		{
			Format(line, 256, "你有%d次抽奖机会", L[Client]);
			DrawPanelText(menu, line);
			Format(line, 256, "【详情请查看规则说明】");
			DrawPanelText(menu, line);
		}
		else
		{
			L[Client] = 0;
			Format(line, 256, "你暂时没有抽奖机会");
			DrawPanelText(menu, line);
			Format(line, 256, "【详情请查看规则说明】");
			DrawPanelText(menu, line);
		}
		Format(line, 256, "准备抽奖");
		DrawPanelItem(menu, line, 0);
		Format(line, 256, "规则说明");
		DrawPanelItem(menu, line, 0);
		Format(line, 256, "刷新列表");
		DrawPanelItem(menu, line, 0);
		DrawPanelItem(menu, "Exit", 1);
		SendPanelToClient(menu, Client, RollMenuHandler, 0);
		CloseHandle(menu);
	}
	else
	{
		Format(line, 256, "  -祝您好运-");
		SetPanelTitle(menu, line, false);
		Format(line, 256, "~~~~~~~~~~~~~~", L[Client]);
		DrawPanelText(menu, line);
		Format(line, 256, "   抽奖中...  ", L[Client]);
		DrawPanelText(menu, line);
		Format(line, 256, "~~~~~~~~~~~~~~", L[Client]);
		DrawPanelText(menu, line);
		Format(line, 256, "-停-");
		DrawPanelItem(menu, line, 0);
		DrawPanelItem(menu, "如果列表关闭,请再次打开,选择:-停-", 1);
		SendPanelToClient(menu, Client, Stop, 0);
		CloseHandle(menu);
	}
	return Action:0;
}

public RollMenuHandler(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction:4)
	{
		switch (param)
		{
			case 1:
			{
				if (0 < L[Client])
				{
					if (sift[Client])
					{
						sift_start1(Client);
						sift_start2(Client);
						sift_start3(Client);
						sift_start4(Client);
						sift_start5(Client);
						sift_start6(Client);
						sift[Client] = false;
					}
					Award_List(Client);
				}
				else
				{
					PrintToChat(Client, "\x04Sorry,你没有抽奖机会!");
				}
			}
			case 2:
			{
				Explain(Client);
			}
			case 3:
			{
				draw_function(Client);
				EmitSoundToClient(Client, "buttons/button14.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
			}
			default:
			{
			}
		}
	}
	return 0;
}

public Stop(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction:4)
	{
		switch (param)
		{
			case 1:
			{
				KillTimer(StopTime[Client], false);
				StopTime[Client] = INVALID_HANDLE;
				rolled[Client] = false;
				sift[Client] = true;
				Award(Client);
			}
			default:
			{
			}
		}
	}
	return 0;
}

public Action:Explain(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel(Handle:0);
	Format(line, 256, "    -规则说明-");
	SetPanelTitle(menu, line, false);
	Format(line, 256, "请选择你想了解的说明");
	DrawPanelText(menu, line);
	Format(line, 256, "操作说明");
	DrawPanelItem(menu, line, 0);
	Format(line, 256, "抽奖机会获得方法");
	DrawPanelItem(menu, line, 0);
	Format(line, 256, "奖项出现概率");
	DrawPanelItem(menu, line, 0);
	Format(line, 256, "返回");
	DrawPanelItem(menu, line, 0);
	DrawPanelItem(menu, "Exit", 1);
	SendPanelToClient(menu, Client, Declare, 0);
	CloseHandle(menu);
	return Action:0;
}

public Declare(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction:4)
	{
		switch (param)
		{
			case 1:
			{
				E1(Client);
			}
			case 2:
			{
				E2(Client);
			}
			case 3:
			{
				E3(Client);
			}
			case 4:
			{
				draw_function(Client);
			}
			default:
			{
			}
		}
	}
	return 0;
}

public Action:E1(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel(Handle:0);
	Format(line, 256, "   -操作说明-");
	SetPanelTitle(menu, line, false);
	Format(line, 256, ">如果你有抽奖机会");
	DrawPanelText(menu, line);
	Format(line, 256, ">请点击主菜单的 【准备抽奖】");
	DrawPanelText(menu, line);
	Format(line, 256, ">此时会出现一个列表,上面显示你本次奖项的奖品");
	DrawPanelText(menu, line);
	Format(line, 256, ">然后选择【开始抽奖】");
	DrawPanelText(menu, line);
	Format(line, 256, "下一页");
	DrawPanelItem(menu, line, 0);
	Format(line, 256, "返回");
	DrawPanelItem(menu, line, 0);
	DrawPanelItem(menu, "Exit", 1);
	SendPanelToClient(menu, Client, Page1, 0);
	CloseHandle(menu);
	return Action:0;
}

public Page1(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction:4)
	{
		switch (param)
		{
			case 1:
			{
				E1_1(Client);
			}
			case 2:
			{
				Explain(Client);
			}
			default:
			{
			}
		}
	}
	return 0;
}

public Action:E1_1(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel(Handle:0);
	Format(line, 256, "   -操作说明-");
	SetPanelTitle(menu, line, false);
	Format(line, 256, ">此时你准心上方会出现一个跳动的奖项条");
	DrawPanelText(menu, line);
	Format(line, 256, ">当你选择菜单中的【-停-】时,奖项条停止跳动");
	DrawPanelText(menu, line);
	Format(line, 256, ">你即可获得奖项栏对应的奖品");
	DrawPanelText(menu, line);
	Format(line, 256, "上一页");
	DrawPanelItem(menu, line, 0);
	Format(line, 256, "返回");
	DrawPanelItem(menu, line, 0);
	DrawPanelItem(menu, "Exit", 1);
	SendPanelToClient(menu, Client, Page2, 0);
	CloseHandle(menu);
	return Action:0;
}

public Page2(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction:4)
	{
		switch (param)
		{
			case 1:
			{
				E1(Client);
			}
			case 2:
			{
				Explain(Client);
			}
			default:
			{
			}
		}
	}
	return 0;
}

public Action:E2(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel(Handle:0);
	Format(line, 256, "  -抽奖机会获得方法-");
	SetPanelTitle(menu, line, false);
	Format(line, 256, ">击杀%d个小僵尸即可获得1次抽奖机会", GetConVarInt(kills));
	DrawPanelText(menu, line);
	Format(line, 256, ">击杀1个特感可以获得%d次抽奖机会", GetConVarInt(infected_count));
	DrawPanelText(menu, line);
	Format(line, 256, ">Tank死亡时,所有幸存者可获得%d次抽奖机会", GetConVarInt(tank_count));
	DrawPanelText(menu, line);
	Format(line, 256, "返回");
	DrawPanelItem(menu, line, 0);
	DrawPanelItem(menu, "Exit", 1);
	SendPanelToClient(menu, Client, Back, 0);
	CloseHandle(menu);
	return Action:0;
}

public Back(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction:4)
	{
		switch (param)
		{
			case 1:
			{
				Explain(Client);
			}
			default:
			{
			}
		}
	}
	return 0;
}

public Action:E3(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel(Handle:0);
	Format(line, 256, "   -奖项出现概率-");
	SetPanelTitle(menu, line, false);
	Format(line, 256, "以下为奖项条跳动时,各类奖项出现概率:");
	DrawPanelText(menu, line);
	Format(line, 256, ">特等奖5％出现");
	DrawPanelText(menu, line);
	Format(line, 256, ">一等奖10％出现");
	DrawPanelText(menu, line);
	Format(line, 256, ">二等奖15％出现");
	DrawPanelText(menu, line);
	Format(line, 256, ">三等奖25％出现");
	DrawPanelText(menu, line);
	Format(line, 256, ">安慰奖40％出现");
	DrawPanelText(menu, line);
	Format(line, 256, ">惩罚5％出现");
	DrawPanelText(menu, line);
	Format(line, 256, "返回");
	DrawPanelItem(menu, line, 0);
	DrawPanelItem(menu, "Exit", 1);
	SendPanelToClient(menu, Client, Back, 0);
	CloseHandle(menu);
	return Action:0;
}

public Action:Award(Client)
{
	decl String:ms[32];
	decl String:hd[64];
	if (gain[Client] == 1)
	{
		if (prize1[Client] == 1)
		{
			new MaxHP = GetEntProp(Client, PropType:1, "m_iMaxHealth", 4, 0);
			SetEntProp(Client, PropType:1, "m_iHealth", MaxHP, 4, 0);
			Format(hd, 64, "将自己加满HP");
		}
		if (prize1[Client] == 2)
		{
			CheatCommand(Client, "ent_remove_all", "infected");
			Format(hd, 64, "清除所有小僵尸");
		}
		if (prize1[Client] == 3)
		{
			SetEntProp(Client, PropType:1, "m_takedamage", any:0, 1, 0);
			if (GodTime[Client] != INVALID_HANDLE)
			{
				KillTimer(GodTime[Client], false);
				GodTime[Client] = INVALID_HANDLE;
			}
			GodTime[Client] = CreateTimer(30.0, ResetGodmod, Client);
			Format(hd, 64, "他自己进入无敌状态30秒");
		}
		if (prize1[Client] == 4)
		{
			SetEntityGravity(Client, 0.2);
			if (GravityTime[Client] != INVALID_HANDLE)
			{
				KillTimer(GravityTime[Client], false);
				GravityTime[Client] = INVALID_HANDLE;
			}
			GravityTime[Client] = CreateTimer(30.0, ResetGravity, Client);
			Format(hd, 64, "他自己的重力降低30秒");
		}
		if (prize1[Client] == 5)
		{
			new i = 1;
			while (i <= MaxClients)
			{
				if (IsClientInGame(i))
				{
					if (GetClientTeam(i) == 3)
					{
						ForcePlayerSuicide(i);
					}
				}
				i++;
			}
			Format(hd, 64, "处死所有特感");
		}
		Format(ms, 32, "特等奖");
		PrintToChatAll("\x03玩家\x04%N\x03抽到了\x01%s \x05→ \x02%s", Client, ms, hd);
		EmitSoundToClient(Client, "level/gnomeftw.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		AttachParticle(Client, "achieved", 3.0);
	}
	if (gain[Client] == 2)
	{
		if (prize2[Client] == 1)
		{
			CheatCommand(Client, "give", "rifle");
			Format(hd, 32, "获得M16");
		}
		if (prize2[Client] == 2)
		{
			CheatCommand(Client, "give", "rifle_ak47");
			Format(hd, 32, "获得AK47");
		}
		if (prize2[Client] == 3)
		{
			CheatCommand(Client, "give", "sniper_military");
			Format(hd, 32, "获得大型连狙");
		}
		if (prize2[Client] == 4)
		{
			CheatCommand(Client, "give", "hunting_rifle");
			Format(hd, 32, "获得小型连狙");
		}
		if (prize2[Client] == 5)
		{
			CheatCommand(Client, "give", "autoshotgun");
			Format(hd, 32, "获得自动散弹枪");
		}
		if (prize2[Client] == 6)
		{
			CheatCommand(Client, "give", "shotgun_spas");
			Format(hd, 32, "获得spas战斗散弹枪");
		}
		if (prize2[Client] == 7)
		{
			CheatCommand(Client, "give", "shotgun_chrome");
			Format(hd, 32, "获得铬合金散弹枪");
		}
		if (prize2[Client] == 8)
		{
			CheatCommand(Client, "give", "pumpshotgun");
			Format(hd, 32, "获得泵动式散弹枪");
		}
		if (prize2[Client] == 9)
		{
			CheatCommand(Client, "give", " rifle_desert");
			Format(hd, 32, "获得突击步枪");
		}
		if (prize2[Client] == 10)
		{
			CheatCommand(Client, "give", "grenade_launcher");
			Format(hd, 32, "获得榴弹枪");
		}
		if (prize2[Client] == 11)
		{
			CheatCommand(Client, "give", "smg");
			Format(hd, 32, "获得乌兹小冲锋");
		}
		if (prize2[Client] == 12)
		{
			CheatCommand(Client, "give", "smg_silenced");
			Format(hd, 32, "获得消音小冲锋");
		}
		Format(ms, 32, "一等奖");
		PrintToChat(Client, "\x04你抽中了\x01%s \x05→ \x02%s", ms, hd);
		EmitSoundToClient(Client, "level/gnomeftw.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		AttachParticle(Client, "achieved", 3.0);
	}
	if (gain[Client] == 3)
	{
		if (prize3[Client] == 1)
		{
			CheatCommand(Client, "give", "first_aid_kit");
			Format(hd, 32, "获得医药包");
		}
		if (prize3[Client] == 2)
		{
			CheatCommand(Client, "give", "pain_pills");
			Format(hd, 32, "获得止痛药");
		}
		if (prize3[Client] == 3)
		{
			CheatCommand(Client, "give", "adrenaline");
			Format(hd, 32, "获得肾上腺素");
		}
		if (prize3[Client] == 4)
		{
			CheatCommand(Client, "give", "defibrillator");
			Format(hd, 32, "获得电击器");
		}
		Format(ms, 32, "二等奖");
		PrintToChat(Client, "\x04你抽中了\x01%s \x05→ \x02%s", ms, hd);
		EmitSoundToClient(Client, "level/gnomeftw.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		AttachParticle(Client, "achieved", 3.0);
	}
	if (gain[Client] == 4)
	{
		if (prize4[Client] == 1)
		{
			CheatCommand(Client, "give", "pistol_magnum");
			Format(hd, 32, "获得马格南手枪");
		}
		if (prize4[Client] == 2)
		{
			CheatCommand(Client, "give", "baseball_bat");
			Format(hd, 32, "获得棒球棒");
		}
		if (prize4[Client] == 3)
		{
			CheatCommand(Client, "give", "pipe_bomb");
			Format(hd, 32, "获得土制炸弹");
		}
		if (prize4[Client] == 4)
		{
			CheatCommand(Client, "give", "molotov");
			Format(hd, 32, "获得燃烧瓶");
		}
		if (prize4[Client] == 5)
		{
			CheatCommand(Client, "give", "vomitjar");
			Format(hd, 32, "获得胆汁炸弹");
		}
		if (prize4[Client] == 6)
		{
			CheatCommand(Client, "give", "chainsaw");
			Format(hd, 32, "获得电锯");
		}
		Format(ms, 32, "三等奖");
		PrintToChat(Client, "\x04你抽中了\x01%s \x05→ \x02%s", ms, hd);
		EmitSoundToClient(Client, "level/gnomeftw.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		AttachParticle(Client, "achieved", 3.0);
	}
	if (gain[Client] == 5)
	{
		if (prize5[Client] == 1)
		{
			CheatCommand(Client, "give", "upgradepack_incendiary");
			Format(hd, 32, "获得燃烧弹盒");
		}
		if (prize5[Client] == 2)
		{
			CheatCommand(Client, "give", "upgradepack_explosive");
			Format(hd, 32, "获得高爆弹盒");
		}
		if (prize5[Client] == 3)
		{
			CheatCommand(Client, "give", "propanetank");
			Format(hd, 32, "获得煤气罐");
		}
		if (prize5[Client] == 4)
		{
			CheatCommand(Client, "give", "gascan");
			Format(hd, 32, "获得汽油桶");
		}
		if (prize5[Client] == 5)
		{
			CheatCommand(Client, "give", "oxygentank");
			Format(hd, 32, "获得氧气罐");
		}
		Format(ms, 32, "安慰奖");
		PrintToChat(Client, "\x04你抽中了\x01%s \x05→ \x02%s", ms, hd);
		EmitSoundToClient(Client, "level/gnomeftw.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		AttachParticle(Client, "achieved", 3.0);
	}
	if (gain[Client] == 6)
	{
		if (prize6[Client] == 1)
		{
			CheatCommand(Client, "z_spawn", "witch");
			CheatCommand(Client, "z_spawn", "witch");
			Format(hd, 32, "召唤两只Witch");
		}
		if (prize6[Client] == 2)
		{
			CheatCommand(Client, "z_spawn", "tank");
			Format(hd, 32, "召唤一只Tank");
		}
		if (prize6[Client] == 3)
		{
			// ForcePlayerSuicide(Client);
			Format(hd, 32, "自杀!!!");
		}
		if (prize6[Client] == 4)
		{
			CheatCommand(Client, "z_spawn", "mob");
			CheatCommand(Client, "z_spawn", "mob");
			Format(hd, 32, "召唤尸潮!");
		}
		if (prize6[Client] == 5)
		{
			ServerCommand("sm_freeze \"%N\" \"%d\"", Client, 10);
			Format(hd, 32, "被冰冻10秒");
		}
		Format(ms, 32, "惩罚");
		PrintToChatAll("\x03玩家\x04%N\x03抽到了\x01%s \x05→ \x02%s", Client, ms, hd);
		EmitSoundToClient(Client, "npc/moustachio/strengthattract05.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	}
	return Action:0;
}

public Action:ResetGodmod(Handle:timer, any:Client)
{
	if (IsClientInGame(Client))
	{
		SetEntProp(Client, Prop_Data, "m_takedamage", 2, 1);
		PrintToChat(Client, "\x02无敌状态结束");
	}
	if (GodTime[Client] != INVALID_HANDLE)
	{
		KillTimer(GodTime[Client], false);
		GodTime[Client] = INVALID_HANDLE;
	}
	return Action:0;
}

public Action:ResetGravity(Handle:timer, any:Client)
{
	if (IsClientInGame(Client))
	{
		SetEntityGravity(Client, 1.0);
		PrintToChat(Client, "\x02低重力状态结束");
	}
	if (GravityTime[Client] != INVALID_HANDLE)
	{
		KillTimer(GravityTime[Client], false);
		GravityTime[Client] = INVALID_HANDLE;
	}
	return Action:0;
}

public Action:sift_start1(Client)
{
	new diceNum = GetRandomInt(1, 5);
	switch (diceNum)
	{
		case 1:
		{
			prize1[Client] = 1;
		}
		case 2:
		{
			prize1[Client] = 2;
		}
		case 3:
		{
			prize1[Client] = 3;
		}
		case 4:
		{
			prize1[Client] = 4;
		}
		case 5:
		{
			prize1[Client] = 5;
		}
		default:
		{
		}
	}
	return Action:0;
}

public Action:sift_start2(Client)
{
	int diceNum2 = GetRandomInt(1, 12);
	prize2[Client] = diceNum2;
	return Action:0;
}

public Action:sift_start3(Client)
{
	int diceNum3 = GetRandomInt(1, 4);
	prize3[Client] = diceNum3;
	return Action:0;
}

public Action:sift_start4(Client)
{
	int diceNum4 = GetRandomInt(1, 6);
	prize4[Client] = diceNum4;
	return Action:0;
}

public Action:sift_start5(Client)
{
	int diceNum5 = GetRandomInt(1, 5);
	prize5[Client] = diceNum5;
	return Action:0;
}

public Action:sift_start6(Client)
{
	new diceNum6 = GetRandomInt(1, 5);
	prize6[Client] = diceNum6;
	return Action:0;
}

public Action:Award_List(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel(Handle:0);
	Format(line, 256, "-本次奖品-");
	SetPanelTitle(menu, line, false);
	if (prize1[Client] == 1)
	{
		Format(line, 256, "【特等奖】:加满自己的HP");
		DrawPanelText(menu, line);
	}
	else
	{
		if (prize1[Client] == 2)
		{
			Format(line, 256, "【特等奖】:清除所有小僵尸");
			DrawPanelText(menu, line);
		}
		if (prize1[Client] == 3)
		{
			Format(line, 256, "【特等奖】:自己进入无敌状态30秒");
			DrawPanelText(menu, line);
		}
		if (prize1[Client] == 4)
		{
			Format(line, 256, "【特等奖】:自己重力降低30秒");
			DrawPanelText(menu, line);
		}
		if (prize1[Client] == 5)
		{
			Format(line, 256, "【特等奖】:处死所有特感");
			DrawPanelText(menu, line);
		}
	}
	if (prize2[Client] == 1)
	{
		Format(line, 256, "【一等奖】:获得M16步枪");
		DrawPanelText(menu, line);
	}
	else
	{
		if (prize2[Client] == 2)
		{
			Format(line, 256, "【一等奖】:获得AK47");
			DrawPanelText(menu, line);
		}
		if (prize2[Client] == 3)
		{
			Format(line, 256, "【一等奖】:获得大型连狙");
			DrawPanelText(menu, line);
		}
		if (prize2[Client] == 4)
		{
			Format(line, 256, "【一等奖】:获得小型连狙");
			DrawPanelText(menu, line);
		}
		if (prize2[Client] == 5)
		{
			Format(line, 256, "【一等奖】:获得自动散弹枪");
			DrawPanelText(menu, line);
		}
		if (prize2[Client] == 6)
		{
			Format(line, 256, "【一等奖】:获得spas战斗散弹枪");
			DrawPanelText(menu, line);
		}
		if (prize2[Client] == 7)
		{
			Format(line, 256, "【一等奖】:获得铬合金散弹枪");
			DrawPanelText(menu, line);
		}
		if (prize2[Client] == 8)
		{
			Format(line, 256, "【一等奖】:获得泵动式散弹枪");
			DrawPanelText(menu, line);
		}
		if (prize2[Client] == 9)
		{
			Format(line, 256, "【一等奖】:获得突击步枪");
			DrawPanelText(menu, line);
		}
		if (prize2[Client] == 10)
		{
			Format(line, 256, "【一等奖】:获得榴弹枪");
			DrawPanelText(menu, line);
		}
		if (prize2[Client] == 11)
		{
			Format(line, 256, "【一等奖】:获得乌兹小冲锋");
			DrawPanelText(menu, line);
		}
		if (prize2[Client] == 12)
		{
			Format(line, 256, "【一等奖】:获得消音小冲锋");
			DrawPanelText(menu, line);
		}
	}
	if (prize3[Client] == 1)
	{
		Format(line, 256, "【二等奖】:获得医药包");
		DrawPanelText(menu, line);
	}
	else
	{
		if (prize3[Client] == 2)
		{
			Format(line, 256, "【二等奖】:获得止痛药");
			DrawPanelText(menu, line);
		}
		if (prize3[Client] == 3)
		{
			Format(line, 256, "【二等奖】:获得肾上腺素");
			DrawPanelText(menu, line);
		}
		if (prize3[Client] == 4)
		{
			Format(line, 256, "【二等奖】:获得电击器");
			DrawPanelText(menu, line);
		}
	}
	if (prize4[Client] == 1)
	{
		Format(line, 256, "【三等奖】:获得马格南手枪");
		DrawPanelText(menu, line);
	}
	else
	{
		if (prize4[Client] == 2)
		{
			Format(line, 256, "【三等奖】:获得棒球棒");
			DrawPanelText(menu, line);
		}
		if (prize4[Client] == 3)
		{
			Format(line, 256, "【三等奖】:获得土制炸弹");
			DrawPanelText(menu, line);
		}
		if (prize4[Client] == 4)
		{
			Format(line, 256, "【三等奖】:获得燃烧瓶");
			DrawPanelText(menu, line);
		}
		if (prize4[Client] == 5)
		{
			Format(line, 256, "【三等奖】:获得胆汁炸弹");
			DrawPanelText(menu, line);
		}
		if (prize4[Client] == 6)
		{
			Format(line, 256, "【三等奖】:获得电锯");
			DrawPanelText(menu, line);
		}
	}
	if (prize5[Client] == 1)
	{
		Format(line, 256, "【安慰奖】:获得燃烧弹盒");
		DrawPanelText(menu, line);
	}
	else
	{
		if (prize5[Client] == 2)
		{
			Format(line, 256, "【安慰奖】:获得高爆弹盒");
			DrawPanelText(menu, line);
		}
		if (prize5[Client] == 3)
		{
			Format(line, 256, "【安慰奖】:获得煤气罐");
			DrawPanelText(menu, line);
		}
		if (prize5[Client] == 4)
		{
			Format(line, 256, "【安慰奖】:获得汽油桶");
			DrawPanelText(menu, line);
		}
		if (prize5[Client] == 5)
		{
			Format(line, 256, "【安慰奖】:获得氧气罐");
			DrawPanelText(menu, line);
		}
	}
	if (prize6[Client] == 1)
	{
		Format(line, 256, "【惩罚】:召唤两只Witch");
		DrawPanelText(menu, line);
	}
	else
	{
		if (prize6[Client] == 2)
		{
			Format(line, 256, "【惩罚】:召唤一只Tank");
			DrawPanelText(menu, line);
		}
		if (prize6[Client] == 3)
		{
			Format(line, 256, "【惩罚】:自杀!!!");
			DrawPanelText(menu, line);
		}
		if (prize6[Client] == 4)
		{
			Format(line, 256, "【惩罚】:召唤尸潮!");
			DrawPanelText(menu, line);
		}
		if (prize6[Client] == 5)
		{
			Format(line, 256, "【惩罚】:被冰冻10秒");
			DrawPanelText(menu, line);
		}
	}
	Format(line, 256, "开始抽奖");
	DrawPanelItem(menu, line, 0);
	Format(line, 256, "返回");
	DrawPanelItem(menu, line, 0);
	DrawPanelItem(menu, "Exit", 1);
	SendPanelToClient(menu, Client, Start, 0);
	CloseHandle(menu);
	return Action:0;
}

public Start(Handle:menu, MenuAction:action, Client, param)
{
	if (action == MenuAction:4)
	{
		switch (param)
		{
			case 1:
			{
				GetGain(Client);
				StopTime[Client] = CreateTimer(0.04, Roll, Client, 1);
				rolled[Client] = true;
				draw_function(Client);
				L[Client] += -1;
			}
			case 2:
			{
				draw_function(Client);
			}
			default:
			{
			}
		}
	}
	return 0;
}

public Action:GetGain(Client)
{
	decl String:show[32];
	new extract = GetRandomInt(1, 20);
	switch (extract)
	{
		case 1:
		{
			Format(show, 32, "特等奖");
			gain[Client] = 1;
		}
		case 2:
		{
			Format(show, 32, "一等奖");
			gain[Client] = 2;
		}
		case 3:
		{
			Format(show, 32, "一等奖");
			gain[Client] = 2;
		}
		case 4:
		{
			Format(show, 32, "二等奖");
			gain[Client] = 3;
		}
		case 5:
		{
			Format(show, 32, "二等奖");
			gain[Client] = 3;
		}
		case 6:
		{
			Format(show, 32, "二等奖");
			gain[Client] = 3;
		}
		case 7:
		{
			Format(show, 32, "三等奖");
			gain[Client] = 4;
		}
		case 8:
		{
			Format(show, 32, "三等奖");
			gain[Client] = 4;
		}
		case 9:
		{
			Format(show, 32, "三等奖");
			gain[Client] = 4;
		}
		case 10:
		{
			Format(show, 32, "三等奖");
			gain[Client] = 4;
		}
		case 11:
		{
			Format(show, 32, "三等奖");
			gain[Client] = 4;
		}
		case 12:
		{
			Format(show, 32, "安慰奖");
			gain[Client] = 5;
		}
		case 13:
		{
			Format(show, 32, "安慰奖");
			gain[Client] = 5;
		}
		case 14:
		{
			Format(show, 32, "安慰奖");
			gain[Client] = 5;
		}
		case 15:
		{
			Format(show, 32, "安慰奖");
			gain[Client] = 5;
		}
		case 16:
		{
			Format(show, 32, "安慰奖");
			gain[Client] = 5;
		}
		case 17:
		{
			Format(show, 32, "安慰奖");
			gain[Client] = 5;
		}
		case 18:
		{
			Format(show, 32, "安慰奖");
			gain[Client] = 5;
		}
		case 19:
		{
			Format(show, 32, "安慰奖");
			gain[Client] = 5;
		}
		case 20:
		{
			Format(show, 32, "惩罚");
			gain[Client] = 6;
		}
		default:
		{
		}
	}
	PrintCenterText(Client, "★抽奖中★     → %s     请在列表中选择: -停- ", show);
	EmitSoundToClient(Client, "ui/littlereward.wav", -2, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	return Action:0;
}

public Action:Roll(Handle:timer, any:Client)
{
	GetGain(Client);
	return Action:0;
}

CheatCommand(Client, String:command[], String:arguments[])
{
	if (!Client)
	{
		return 0;
	}
	new admindata = GetUserFlagBits(Client);
	SetUserFlagBits(Client, 16384);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & -16385);
	FakeClientCommand(Client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(Client, admindata);
	return 0;
}

Handle:AttachParticle(ent, String:particleType[], Float:time)
{
	if (ent < 1)
	{
		return Handle:0;
	}
	new particle = CreateEntityByName("info_particle_system", -1);
	if (IsValidEdict(particle))
	{
		decl String:tName[32];
		new Float:pos[3];
		GetEntPropVector(ent, PropType:0, "m_vecOrigin", pos, 0);
		pos[2] += 60;
		Format(tName, 32, "target%i", ent);
		DispatchKeyValue(ent, "targetname", tName);
		DispatchKeyValue(particle, "targetname", "tf2particle");
		DispatchKeyValue(particle, "parentname", tName);
		DispatchKeyValue(particle, "effect_name", particleType);
		if (DispatchSpawn(particle))
		{
			TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
			SetVariantString(tName);
			AcceptEntityInput(particle, "SetParent", particle, particle, 0);
			SetVariantString("OnUser1 !self,Start,,0.0,-1");
			AcceptEntityInput(particle, "AddOutput", -1, -1, 0);
			SetVariantString("OnUser2 !self,Stop,,4.0,-1");
			AcceptEntityInput(particle, "AddOutput", -1, -1, 0);
			ActivateEntity(particle);
			AcceptEntityInput(particle, "FireUser1", -1, -1, 0);
			AcceptEntityInput(particle, "FireUser2", -1, -1, 0);
			new Handle:pack;
			new Handle:hTimer = CreateDataTimer(time, DeleteParticle, pack, 0);
			WritePackCell(pack, particle);
			WritePackString(pack, particleType);
			WritePackCell(pack, ent);
			new Handle:packLoop;
			hTimerLoopEffect[ent] = CreateDataTimer(4.2, LoopParticleEffect, packLoop, 1);
			WritePackCell(packLoop, particle);
			WritePackCell(packLoop, ent);
			return hTimer;
		}
		if (IsValidEdict(particle))
		{
			RemoveEdict(particle);
		}
		return Handle:0;
	}
	return Handle:0;
}

public Action:DeleteParticle(Handle:timer, Handle:pack)
{
	decl String:particleType[32];
	ResetPack(pack, false);
	new particle = ReadPackCell(pack);
	ReadPackString(pack, particleType, 32);
	new client = ReadPackCell(pack);
	if (hTimerLoopEffect[client])
	{
		KillTimer(hTimerLoopEffect[client], false);
		hTimerLoopEffect[client] = INVALID_HANDLE;
	}
	if (IsValidEntity(particle))
	{
		decl String:classname[128];
		GetEdictClassname(particle, classname, 128);
		if (StrEqual(classname, "info_particle_system", false))
		{
			RemoveEdict(particle);
		}
	}
	if (StrEqual(particleType, "achieved", true))
	{
		hTimerAchieved[client] = INVALID_HANDLE;
	}
	else
	{
		if (StrEqual(particleType, "mini_fireworks", true))
		{
			hTimerMiniFireworks[client] = INVALID_HANDLE;
		}
	}
	return Action:0;
}

public Action:LoopParticleEffect(Handle:timer, Handle:pack)
{
	ResetPack(pack, false);
	new particle = ReadPackCell(pack);
	new client = ReadPackCell(pack);
	if (IsValidEntity(particle))
	{
		decl String:classname[128];
		GetEdictClassname(particle, classname, 128);
		if (StrEqual(classname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "FireUser1", -1, -1, 0);
			AcceptEntityInput(particle, "FireUser2", -1, -1, 0);
			return Action:0;
		}
	}
	hTimerLoopEffect[client] = INVALID_HANDLE;
	return Action:4;
}

public Action:Msg(Handle:timer, any:data)
{
	PrintToChatAll("\x03想试试你的手气吗? 聊天框输入 \x04!ldw \x03打开 \x01【\x04抽奖系统\x01】");
	return Action:0;
}

public bool IsCommonInfected(iEntity)
{
	if (iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
	{
		decl String:strClassName[64];
		GetEdictClassname(iEntity, strClassName, 64);
		return StrEqual(strClassName, "infected", true);
	}
	return false;
}

public bool IsWitch(iEntity)
{
	if (iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
	{
		decl String:strClassName[64];
		GetEdictClassname(iEntity, strClassName, 64);
		return StrEqual(strClassName, "witch", true);
	}
	return false;
}

