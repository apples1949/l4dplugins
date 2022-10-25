#pragma semicolon 1
#pragma tabsize 0
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#include <left4dhooks>
#include <colors>
#include <smlib>
//常规设定
#define TEAM_SPECTATORS 1		//Team数值
#define TEAM_SURVIVORS 2		//Team数值
#define TEAM_INFECTED 3		//Team数值
#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))    //定义客户端是否在游戏中
#define IsValidAliveClient(%1)	(1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1))   //定义客户端是否在游戏中并且扮演
//购买武器
#define ARMS 			1	//武器
#define WEAPON			2	//近战
#define PROPS 			3	//道具
#define	PISTOL			10	//手枪
#define	MAGNUM			11	//马格南手枪
#define	SMG				12	//冲锋枪
#define	SMGSILENCED		13	//消声冲锋枪
#define	AddFullCount		14	//满属性体验卡
#define PUMPSHOTGUN1	15	//老式单发霰弹
#define PUMPSHOTGUN2	16	//新式单发霰弹
#define	AUTOSHOTGUN1	17	//老式连发霰弹
#define	AUTOSHOTGUN2	18	//新式连发霰弹
#define HUNTING1		19	//猎枪
#define	HUNTING2		20	//G3SG1狙击枪
#define M16				23  //M16
#define	AK47			24   //AK47
#define	SCAR			25	//三连发
#define	AWP			26	//AWP
#define	grenadelauncher			27	//榴弹
#define	sniperscout			28	//AWP
#define	m60			29	//m60
//补给物品
#define	ADRENALINE		50	//肾上腺素
#define	PAINPILLS		51	//药丸
#define	FIRSTAIDKIT		52	//医疗包
#define	GASCAN		53	//油桶
/** 属性上限 **/
enum data
{
	MELEE,
	BLOOD,
	MONEY,
};
int player_data[MAXPLAYERS+1][data];
#define colored	1
#define simple	2
new BuyCount[MAXPLAYERS+1];
new Handle:ReturnBlood;
#define SCORE_DELAY_EMPTY_SERVER 3.0
#define L4D_MAXHUMANS_LOBBY_OTHER 3
new Float:lastDisconnectTime;
new	String:logfilepath[256];\
/* 存档和排名 */
new String:SavePath[256];
new Handle:RPGSave = INVALID_HANDLE;
new Handle:g_BShuiLimit = INVALID_HANDLE;
new BShuiLimit;
public void OnPluginStart()
{
	BuildPath(Path_SM, logfilepath, sizeof(logfilepath), "server\\PlayerMessage.log");
	RPGSave = CreateKeyValues("United RPG Save");
	/* 设置Save和Ranking位置 */
	BuildPath(Path_SM, SavePath, 255, "data/RPGSave.txt");
	if (FileExists(SavePath))
	{
		FileToKeyValues(RPGSave, SavePath);
	}
	else
	{
		KeyValuesToFile(RPGSave, SavePath);
	}
	RegConsoleCmd("sm_rpg",			Menu_RPG);
	RegConsoleCmd("sm_buy",			Menu_RPG);
	AddCommandListener(SayTeamCommand, "say_team");
	AddCommandListener(SayCommand, "say");
	RegConsoleCmd("say",		Command_Say);
	RegConsoleCmd("say_team",		Command_SayTeam);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", event_RoundStart);
	HookEvent("mission_lost", EventHook:GiveMoney, EventHookMode_PostNoCopy);
	HookEvent("map_transition", EventHook:ResetMoney, EventHookMode_PostNoCopy);
	HookEvent("finale_win", EventHook:ResetMoney, EventHookMode_PostNoCopy);
	ReturnBlood = CreateConVar("ReturnBlood", "0");
	g_BShuiLimit = CreateConVar("BS_limit", "500");
	HookConVarChange(g_BShuiLimit, Cvar_BShuiLimit);
	BShuiLimit = GetConVarInt(g_BShuiLimit);
}

public Cvar_BShuiLimit( Handle:cvar, const String:oldValue[], const String:newValue[] ) 
{
	BShuiLimit = GetConVarInt(g_BShuiLimit);
}
public event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new client = 1; client <= MaxClients; client++) 
	{	
		BuyCount[client] = 0;
	}
}
public OnMapStart()
{
	RPGSave = CreateKeyValues("United RPG Save");
	BuildPath(Path_SM, SavePath, 255, "data/RPGSave.txt");
	FileToKeyValues(RPGSave, SavePath);
}
public OnMapEnd()
{
	CloseHandle(RPGSave);
}
public Action:ResetMoney(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		player_data[client][MONEY] = 0;
	}
}
public Action:GiveMoney(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		if (IsSurvivor(client)) 
		{
			player_data[client][MONEY] = BShuiLimit;
		}
	}
}
public Action:SayCommand(client, const String:command[], args)
{
	if (client == 0 || IsChatTrigger())
	{
		return Plugin_Continue;
	}
	decl	String:sMessage[1024];
	GetCmdArgString(sMessage, sizeof(sMessage));
	CPrintToChatAll("\x04%N {olive}: %s", client, sMessage);
	LogToFile(logfilepath, "%N:%s", client, sMessage);
	return Plugin_Handled;
}

public Action:SayTeamCommand(client, const String:command[], args)
{
	if (client == 0 || IsChatTrigger())
	{
		return Plugin_Continue;
	}
	decl	String:sMessage[1024];
	GetCmdArgString(sMessage, sizeof(sMessage));
	CPrintToChatAll("\x04%N {olive}: %s", client, sMessage);
	LogToFile(logfilepath, "%N:%s", client, sMessage);
	return Plugin_Handled;
}
public Action:Command_Say(client,args)
{
	return Plugin_Handled;
}
public Action:Command_SayTeam(client,args)
{
	return Plugin_Handled;
}
public Action:L4D_OnFirstSurvivorLeftSafeArea() 
{
	for (new client = 1; client <= MaxClients; client++) 
	{
		if (IsSurvivor(client)) 
		{
			ClientSaveToFileLoad(client);
			SetConVarString(FindConVar("mp_gamemode"), "coop");
			CreateTimer(0.5, Timer_AutoGive, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Stop;
}
public Action:Timer_AutoGive(Handle:timer,any client) 
{
	if (player_data[client][MELEE] == 1 ) 
	{ 
		BypassAndExecuteCommand(client, "give", "machete");
	}
	if (player_data[client][MELEE] == 2) 
	{ 
		BypassAndExecuteCommand(client, "give","fireaxe"); 
	}
	if (player_data[client][MELEE] == 3) 
	{ 
		BypassAndExecuteCommand(client, "give","knife"); 
	}
	if (player_data[client][MELEE] == 4) 
	{ 
		BypassAndExecuteCommand(client, "give","katana"); 
	}
	if (player_data[client][MELEE] == 5) 
	{ 
		BypassAndExecuteCommand(client, "give","pistol_magnum"); 
	}
}
// 玩家离开游戏 
public OnClientDisconnect(client)
{
	if(!IsFakeClient(client) && IsClientInGame(client))
	{
		PrintToChatAll("\x04 %N \x05 离开了游戏", client);
		new Float:currenttime = GetGameTime();
		if (lastDisconnectTime == currenttime)
		{
			return;
		}
		CreateTimer(SCORE_DELAY_EMPTY_SERVER, IsNobodyConnected, currenttime);
		lastDisconnectTime = currenttime;
	}
}
public Action:IsNobodyConnected(Handle:timer, any:timerDisconnectTime)
{
	if (timerDisconnectTime != lastDisconnectTime)
	{
		return Plugin_Stop;
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			return  Plugin_Stop;
		}
	}
	return Plugin_Stop;
}

// 各种经验值和技能回血效果
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(IsValidClient(victim))
	{
		if(GetClientTeam(victim) == TEAM_INFECTED)
		{
			if(IsSurvivor(attacker))	//玩家幸存者杀死特殊感染者
			{
				
					if(!IsFakeClient(attacker))
					{
						if(bool:GetConVarBool(ReturnBlood))
						{
							new maxhp = GetEntProp(attacker, Prop_Data, "m_iMaxHealth");
							new targetHealth = GetSurvivorPermHealth(attacker);
							if(player_data[attacker][BLOOD] > 0)
							{
								targetHealth += 2;
							}
							if(targetHealth > maxhp)
							{
								targetHealth = maxhp;
							}
							if(!IsPlayerIncap(attacker))
							{
								SetSurvivorPermHealth(attacker, targetHealth);
							}
						}
					}
					else
					{
						new targetHealth = GetSurvivorPermHealth(attacker);
						targetHealth += 2;
						if(targetHealth > 100)
						{
							targetHealth = 100;
						}
						if(!IsPlayerIncap(attacker))
						{
							SetSurvivorPermHealth(attacker, targetHealth);
						}
					}
				}
			}
	}
	return Plugin_Continue;
}


/******************************************************
*	United RPG选单
*******************************************************/
//近战技能
public Action:AddStrength(Client, args) 
{
	if(player_data[Client][MONEY] >= 0 || player_data[Client][MELEE] > 0)
	{
		if (args < 1)
		{
			if(player_data[Client][MELEE] + 1 > 5)
			{
				return Plugin_Handled;
			}
			else
			{
				player_data[Client][MELEE] += 1;
				ClientSaveToFileSave(Client);
				MenuFunc_AddStatus(Client);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Handled;
}

//回血技能
public Action:AddEndurance(Client, args) 
{
	if(player_data[Client][MONEY] >= 0)
	{
		if (args < 1)
		{
			if(player_data[Client][BLOOD]  + 1 > 1)
			{
				return Plugin_Handled;
			}
			else
			{
				player_data[Client][BLOOD]  += 1;
				ClientSaveToFileSave(Client);
				MenuFunc_AddStatus(Client);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Handled;
}
//重置技能
public Action:ResetBshu(Client, args)
{
	if(player_data[Client][MONEY] >= 0)
	{
		if (args < 1)
		{
			player_data[Client][BLOOD] = 0;
			player_data[Client][MELEE] = 0;
			ClientSaveToFileSave(Client);
			MenuFunc_AddStatus(Client);
			return Plugin_Handled;	
		}
	}
	return Plugin_Handled;
}
/******************************************************
*	United RPG选单
*******************************************************/
public Action:Menu_RPG(Client,args)
{
	MenuFunc_Xsbz(Client);
	return Plugin_Handled;
}

/* RPG面板*/
public Action:MenuFunc_Xsbz(Client)
{
	decl String:line[256];
	new Handle:menu = CreatePanel();
	Format(line, sizeof(line), "AnneHappy");			
	SetPanelTitle(menu, line);
    
	Format(line, sizeof(line), "购物商店");
	DrawPanelItem(menu, line);
	
	Format(line, sizeof(line), "技能商店");
	DrawPanelItem(menu, line);
	
	SendPanelToClient(menu, Client, MenuHandler_Xsbz, MENU_TIME_FOREVER);
}

//RPG面板执行
public MenuHandler_Xsbz(Handle:menu, MenuAction:action, Client, param)//基础菜单	
{
	if (action == MenuAction_Select) 
	{
		switch (param)
		{
			case 1: ShowMenu(Client);
			case 2: MenuFunc_AddStatus(Client);
		}
	}
}

/* 技能菜单 */
public Action:MenuFunc_AddStatus(Client)
{
	ClientSaveToFileLoad(Client);
	new Handle:menu = CreatePanel();
	decl String:line[256];
	Format(line, sizeof(line), "B数: %d", player_data[Client][MONEY]);
	SetPanelTitle(menu, line);

	Format(line, sizeof(line), "出门近战 (%d/%d)", player_data[Client][MELEE], 5);
	DrawPanelItem(menu, line);
	Format(line, sizeof(line), "1砍刀 2斧头 3小刀 4武士刀 5马格南");
	DrawPanelText(menu, line);
	if(bool:GetConVarBool(ReturnBlood))
	{
		Format(line, sizeof(line), "杀特回血 (%d/%d)", player_data[Client][BLOOD], 1);
		DrawPanelItem(menu, line);
		Format(line, sizeof(line), "击特回2点实血，无法超过生命值上限");
		DrawPanelText(menu, line);
	}
	Format(line, sizeof(line), "重置技能");
	DrawPanelItem(menu, line);

	SendPanelToClient(menu, Client, MenuHandler_AddStatus, MENU_TIME_FOREVER);
}
//技能加点
public MenuHandler_AddStatus(Handle:menu, MenuAction:action, Client, param)
{
	if(action == MenuAction_Select)
	{
		if(bool:GetConVarBool(ReturnBlood))
		{
			switch(param)
			{
				
				case 1:	AddStrength(Client, 0);
				case 2:	AddEndurance(Client, 0);
				case 3:	ResetBshu(Client, 0);
			}
		}
		else
		{
			switch(param)
			{
				case 1:	AddStrength(Client, 0);
				case 2:	ResetBshu(Client, 0);
			}
		}
	}
}

/*-----------------------------------------方法区--------------------------------------------------*/
//这是主界面

public CharMenu(Handle:menu, MenuAction:action, param1, param2) 
{
	switch (action) 
	{
		case MenuAction_Select: 
		{
			decl String:item[8];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			switch(StringToInt(item)) 
			{
				case ARMS:		{	ShowTypeMenu(param1,ARMS);	}
				case PROPS:		{	ShowTypeMenu(param1,PROPS);	}
			}
		}
		case MenuAction_Cancel:
		{
			
		}
		case MenuAction_End: 
		{
			CloseHandle(menu);
		}
	}
}

public Action:ShowMenu(Client)
{	
	decl String:sMenuEntry[8];
	new Handle:menu = CreateMenu(CharMenu);
	SetMenuTitle(menu, "B数:%i",player_data[Client][MONEY]);
	IntToString(ARMS, sMenuEntry, sizeof(sMenuEntry));
	AddMenuItem(menu, sMenuEntry, "购买枪械");
	IntToString(PROPS, sMenuEntry, sizeof(sMenuEntry));
	AddMenuItem(menu, sMenuEntry, "购买补给");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}

//这是购买武器

public CharArmsMenu(Handle:menu, MenuAction:action, param1, param2) 
{
	switch (action) 
	{
		case MenuAction_Select: 
		{
			decl String:item[8];
			GetMenuItem(menu, param2, item, sizeof(item));
			
			switch(StringToInt(item)) 
			{
				case PISTOL:
				{
					if(IsSurvivor(param1))
					{
						BypassAndExecuteCommand(param1, "give", "ammo");
					}
				}
				case MAGNUM:	
				{	
					if(player_data[param1][MONEY] < 1)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "pistol_magnum");
						player_data[param1][MONEY] -= 50;
						PrintToChatAll("\x04%N\x03花了50点B数购买了马格南手枪",param1);
					}
				}
				case SMG:	
				{	
					if(BuyCount[param1] == 0)
					{
						BypassAndExecuteCommand(param1, "give", "smg");
						BuyCount[param1] += 1;
					}
					else
					{
						BypassAndExecuteCommand(param1, "give", "smg");
						player_data[param1][MONEY] -= 50;
						PrintToChatAll("\x04%N\x03花了50点B数购买了UZI冲锋枪",param1);
					}
				}
				case SMGSILENCED:	
				{	
					if(BuyCount[param1] == 0)
					{
						BypassAndExecuteCommand(param1, "give", "smg_silenced");
						BuyCount[param1] += 1;
					}
					else
					{
						BypassAndExecuteCommand(param1, "give", "smg_silenced");
						player_data[param1][MONEY] -= 50;
						PrintToChatAll("\x04%N\x03花了50点B数购买了SMG冲锋枪",param1);
					}
				}
				case PUMPSHOTGUN1:
				{
					if(BuyCount[param1] == 0)
					{
						BypassAndExecuteCommand(param1, "give", "pumpshotgun");
						BuyCount[param1] += 1;
					}
					else
					{
						BypassAndExecuteCommand(param1, "give", "pumpshotgun");
						player_data[param1][MONEY] -= 50;
						PrintToChatAll("\x04%N\x03花了50点B数购买了一代单发霰弹枪",param1);
					}
				}
				case PUMPSHOTGUN2:
				{
					if(IsSurvivor(param1) && BuyCount[param1] == 0)
					{
						BypassAndExecuteCommand(param1, "give", "shotgun_chrome");
						BuyCount[param1] += 1;
					}
					else if(BuyCount[param1] != 0)
					{
						BypassAndExecuteCommand(param1, "give", "shotgun_chrome");
						player_data[param1][MONEY] -= 50;
						PrintToChatAll("\x04%N\x03花了50点B数购买了二代单发霰弹枪",param1);
					}
				}
				case AUTOSHOTGUN1:
				{
					if(player_data[param1][MONEY] < 200)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "autoshotgun");
						player_data[param1][MONEY] -= 200;
						PrintToChatAll("\x04%N\x03花了200点B数购买了一代连发霰弹枪",param1);
					}
				}
				case AUTOSHOTGUN2:
				{
					if(player_data[param1][MONEY] < 200)
					{
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "shotgun_spas");
						player_data[param1][MONEY] -= 200;
						PrintToChatAll("\x04%N\x03花了200点B数购买了二代连发霰弹枪",param1);
					}
				}
				case HUNTING1:
				{
					if(player_data[param1][MONEY] < 200)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "hunting_rifle");
						player_data[param1][MONEY] -= 200;
						PrintToChatAll("\x04%N\x03花了200点B数购买了一代狙击枪",param1);
					}
				}
				case HUNTING2:
				{
					if(player_data[param1][MONEY] < 200)
					{
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "sniper_military");
						player_data[param1][MONEY] -= 200;
						PrintToChatAll("\x04%N\x03花了200点B数购买了二代狙击枪",param1);
					}
				}
				
				case M16:
				{
					if(player_data[param1][MONEY] < 200)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "rifle");
						player_data[param1][MONEY] -= 200;
						PrintToChatAll("\x04%N\x03花了200点B数购买了M16步枪",param1);
					}
				}
				case AK47:
				{
					if(player_data[param1][MONEY] < 200)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "rifle_ak47");
						player_data[param1][MONEY] -= 200;
						PrintToChatAll("\x04%N\x03花了200点B数购买了AK47步枪",param1);
					}
				}
				case SCAR:
				{
					if(player_data[param1][MONEY] < 200)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "rifle_desert");
						player_data[param1][MONEY] -= 200;
						PrintToChatAll("\x04%N\x03花了200点B数购买了SCAR步枪",param1);
					}
				}
				case AWP:
				{
					if(player_data[param1][MONEY] < 500)
					{
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "sniper_awp");
						player_data[param1][MONEY] -= 500;
						PrintToChatAll("\x04%N\x03花了500点B数购买了AWP狙击枪",param1);
					}
				}
				case grenadelauncher:
				{
					if(player_data[param1][MONEY] <500)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "grenade_launcher");
						player_data[param1][MONEY] -= 500;
						PrintToChatAll("\x04%N\x03花了500点B数购买了榴弹发射器",param1);
					}
				}
				case sniperscout:
				{
					if(player_data[param1][MONEY] < 300)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "sniper_scout");
						player_data[param1][MONEY] -= 300;
						PrintToChatAll("\x04%N\x03花了300点B数购买了鸟狙",param1);
					}
				}
				case m60:
				{
					if(player_data[param1][MONEY] < 500)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else if(IsSurvivor(param1))
					{
						BypassAndExecuteCommand(param1, "give", "rifle_m60");
						player_data[param1][MONEY] -= 500;
						PrintToChatAll("\x04%N\x03花了500点B数购买了M60",param1);
					}
				}
				case ADRENALINE:
				{
					if(player_data[param1][MONEY] < 300)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "adrenaline");
						player_data[param1][MONEY] -= 300;
						PrintToChatAll("\x04%N\x03花了300点B数购买了肾上腺素",param1);
					}
				}
				case PAINPILLS:
				{
					if(player_data[param1][MONEY] < 400)
					{
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "pain_pills");
						player_data[param1][MONEY] -= 400;
						PrintToChatAll("\x04%N\x03花了400点B数购买了止痛药",param1);
					}
				}
				case FIRSTAIDKIT:
				{
					if(player_data[param1][MONEY] < 500)
					{ 
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "first_aid_kit");
						player_data[param1][MONEY] -= 500;
						PrintToChatAll("\x04%N\x03花了500点B数购买了急救包",param1);
					}
				}
				case GASCAN:
				{
					if(player_data[param1][MONEY] < 200)
					{
						PrintToChat(param1,"\x03你自己心里没有点B数吗?");
					} 
					else
					{
						BypassAndExecuteCommand(param1, "give", "gascan");
						player_data[param1][MONEY] -= 200;
						PrintToChatAll("\x04%N\x03花了200点B数购买了油桶",param1);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			
		}
		case MenuAction_End: 
		
		{
			CloseHandle(menu);
		}
	}
}

public ShowTypeMenu(Client,type)
{	
	decl String:sMenuEntry[8];
	new String:money[64];
	new Handle:menu = CreateMenu(CharArmsMenu);
	switch(type)
	{
		case ARMS:
		{
			SetMenuTitle(menu, "B数:%i",player_data[Client][MONEY]);
			
			Format(money,sizeof(money),"子弹堆(%d点B数)",0);
			IntToString(PISTOL, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"马格南手枪(%d点B数)",50);
			IntToString(MAGNUM, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			if(BuyCount[Client] == 0)
			{
				Format(money,sizeof(money),"UZI冲锋枪(%d点B数)",0);
				IntToString(SMG, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
				
				Format(money,sizeof(money),"SMG冲锋枪(%d点B数)",0);
				IntToString(SMGSILENCED, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
			
				Format(money,sizeof(money),"一代单发霰弹枪(%d点B数)",0);
				IntToString(PUMPSHOTGUN1, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
					
				Format(money,sizeof(money),"二代单发霰弹枪(%d点B数)",0);
				IntToString(PUMPSHOTGUN2, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
				
				
			}
			else
			{
				Format(money,sizeof(money),"UZI冲锋枪(%d点B数)",50);
				IntToString(SMG, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
				
				Format(money,sizeof(money),"SMG冲锋枪(%d点B数)",50);
				IntToString(SMGSILENCED, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
					
				Format(money,sizeof(money),"一代单发霰弹枪(%d点B数)",50);
				IntToString(PUMPSHOTGUN1, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
					
				Format(money,sizeof(money),"二代单发霰弹枪(%d点B数)",50);
				IntToString(PUMPSHOTGUN2, sMenuEntry, sizeof(sMenuEntry));
				AddMenuItem(menu, sMenuEntry, money);
			}
			
			Format(money,sizeof(money),"一代连发霰弹枪(%d点B数)",200);
			IntToString(AUTOSHOTGUN1, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"二代连发霰弹枪(%d点B数)",200);
			IntToString(AUTOSHOTGUN2, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"一代狙击枪(%d点B数)",200);
			IntToString(HUNTING1, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
					
			Format(money,sizeof(money),"二代狙击枪(%d点B数)",200);
			IntToString(HUNTING2, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"M16步枪(%d点B数)",200);
			IntToString(M16, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"AK47步枪(%d点B数)",200);
			IntToString(AK47, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"SCAR步枪(%d点B数)",200);
			IntToString(SCAR, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"AWP狙击枪(%d点B数)",500);
			IntToString(AWP, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"榴弹发射器(%d点B数)",500);
			IntToString(grenadelauncher, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"鸟狙(%d点B数)",300);
			IntToString(sniperscout, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"M60(%d点B数)",500);
			IntToString(m60, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
		}
		
		case PROPS:
		{
			SetMenuTitle(menu, "B数:%i",player_data[Client][MONEY]);
			
			Format(money,sizeof(money),"肾上腺素(%d点B数)",300);
			IntToString(ADRENALINE, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"止痛药(%d点B数)",400);
			IntToString(PAINPILLS, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"医疗包(%d点B数)",500);
			IntToString(FIRSTAIDKIT, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
			
			Format(money,sizeof(money),"油桶(%d点B数)",200);
			IntToString(GASCAN, sMenuEntry, sizeof(sMenuEntry));
			AddMenuItem(menu, sMenuEntry, money);
		}
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, Client, MENU_TIME_FOREVER);
}

//给物品函数
stock BypassAndExecuteCommand(client, String: strCommand[], String: strParam1[])
{
	new flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}

//判断是否为生还者
stock bool:IsSurvivor(client) 
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2) 
	{
		return true;
	} 
	else 
	{
		return false;
	}
}

stock bool:IsValidPlayer(Client, bool:AllowBot = true, bool:AllowDeath = true)
{
	if (Client < 1 || Client > MaxClients)
		return false;
	if (!IsClientConnected(Client) || !IsClientInGame(Client))
		return false;
	if (!AllowBot)
	{
		if (IsFakeClient(Client))
			return false;
	}

	if (!AllowDeath)
	{
		if (!IsPlayerAlive(Client))
			return false;
	}	
	
	return true;
}

//判断生还者是否已经被控
stock bool:IsPinned(client) {
	new bool:bIsPinned = false;
	if (IsSurvivor(client)) {
		// check if held by:
		if( GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ) bIsPinned = true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) bIsPinned = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) bIsPinned = true; // charger carry
		if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) bIsPinned = true; // charger pound
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ) bIsPinned = true; // jockey
	}		
	return bIsPinned;
}

//获取实血
stock GetSurvivorPermHealth(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}
//设置实血
stock SetSurvivorPermHealth(client, health)
{
	SetEntProp(client, Prop_Send, "m_iHealth", health);
}
//判断是否倒地
stock bool:IsPlayerIncap(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

/* 读取存档Function */
ClientSaveToFileLoad(Client)
{
	/* 读取玩家姓名 */
	decl String:infoBuffer[64]="";
	GetClientAuthId(Client, AuthId_Steam2, infoBuffer, sizeof(infoBuffer));
	KvJumpToKey(RPGSave, infoBuffer, true);

	player_data[Client][MELEE]					=	KvGetNum(RPGSave, "MELEE_SKILL", 0);
	player_data[Client][BLOOD]					=	KvGetNum(RPGSave, "BLOOD_SKILL", 0);
	KvGoBack(RPGSave);
}

/* 存档Function */
ClientSaveToFileSave(Client)
{
	decl String:infoBuffer[64]="";
	GetClientAuthId(Client, AuthId_Steam2, infoBuffer, sizeof(infoBuffer));
	KvJumpToKey(RPGSave, infoBuffer, true);
	
	KvSetNum(RPGSave, "MELEE_SKILL", player_data[Client][MELEE]);
	KvSetNum(RPGSave, "BLOOD_SKILL", player_data[Client][BLOOD]);

	KvRewind(RPGSave);
	KeyValuesToFile(RPGSave, SavePath);
}