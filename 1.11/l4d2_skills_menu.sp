#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <l4d2_skills>
#include <left4dhooks>

public Plugin myinfo =
{
	name = "[L4D2] Skills Menu",
	author = "BHaType",
	description = "Provides menu API for skills",
	version = "1.1",
	url = "https://github.com/Vinillia/l4d2_skills"
};

enum struct ItemInfo
{
	Handle owner;
	Function callback;
	char display[128];
	char item[64];
}

enum struct NativeItems
{
	ArrayList items; // list of ItemInfo's
	
	void ensureinitialized()
	{
		if ( this.items == null )
			this.items = new ArrayList(sizeof ItemInfo);
	}
	
	int FindByName( const char[] name )
	{
		this.ensureinitialized();
		
		int count = this.items.Length;
		ItemInfo info;
		
		for( int i; i < count; i++ )
		{
			this.items.GetArray(i, info);
			
			if ( strcmp(info.item, name) == 0 )
			{
				return i;
			}
		}
		
		return -1;
	}
	
	void AddItem( ItemInfo info )
	{
		this.ensureinitialized();
		
		int i = this.FindByName(info.item);
		
		if ( i == -1 )
			this.items.PushArray(info);
		else
			this.items.SetArray(i, info);
	}
	
	bool GetItem( int i, ItemInfo out )
	{
		this.ensureinitialized();
		return this.items.GetArray(i, out) == sizeof ItemInfo;
	}
}

enum struct SkillsMenuExport
{
	bool allow_use_only_in_saferoom;
	float time_to_block;
}

float g_flUpgradeCost[MAXPLAYERS + 1];
bool g_isBlocked, g_bLate;
NativeItems g_NativeItems;
SkillsMenuExport gExport;

public any NAT_Skills_RequestDefaultUpgradeMenu( Handle plugin, int numparams )
{
	int client = GetNativeCell(1);
	int skillID = GetNativeCell(2);
	int nextLevel = GetNativeCell(3);
	float cost = GetNativeCell(4);
	
	Menu menu = CreateUpgradeMenu(client, skillID, nextLevel, cost);
	Menu newOwner = view_as<Menu>(CloneHandle(menu, plugin));
	
	if ( newOwner == null )
		return 0;
	
	delete menu;
	return newOwner;
}

public any NAT_Skills_AddMenuItem( Handle plugin, int numparams )
{
	ItemInfo info;
	
	GetNativeString(1, info.item, sizeof ItemInfo::item);
	GetNativeString(2, info.display, sizeof ItemInfo::display);
	info.callback = GetNativeFunction(3);
	info.owner = plugin;

	g_NativeItems.AddItem(info);
	return 0;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errormax) 
{
	CreateNative("Skills_AddMenuItem", NAT_Skills_AddMenuItem);
	CreateNative("Skills_RequestDefaultUpgradeMenu", NAT_Skills_RequestDefaultUpgradeMenu);

	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_skills", sm_skills);

	HookEvent("round_end", reset_command_block, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", reset_command_block, EventHookMode_PostNoCopy);
}

public void OnAllPluginsLoaded()
{
	if (g_bLate)
		Skills_RequestConfigReload();
}

public void reset_command_block(Event event, const char[] name, bool dontBroadcast)
{
	g_isBlocked = false;
}

public Action sm_skills( int client, int args )
{
	char reason[64];
	if (!AllowedToOpenMenu(client, reason, sizeof reason))
	{
		Skills_PrintToChat(client, "%s", reason);
		return Plugin_Handled;
	}

	ShowClientSkillMenu(client);
	return Plugin_Handled;
}

void ShowClientSkillMenu( int client )
{
	char display[128], item[128];
	Menu menu = new Menu(VMenuHandler);
	//menu.SetTitle("Skills: Main menu");
	menu.SetTitle("技能菜单");
	
	Format(display, sizeof display, "Money: %.1f | Multiplier: %.2f", Skills_GetClientMoney(client), Skills_GetClientMoneyMultiplier(client));
	menu.AddItem("", display, ITEMDRAW_DISABLED);
	
	Format(display, sizeof display, "Team Money: %.1f | Multiplier: %.2f", Skills_GetTeamMoney(), Skills_GetTeamMoneyMultiplier());
	menu.AddItem("", display, ITEMDRAW_DISABLED);
	
	if ( Skills_GetClientSkillsCount(client) > 0) 
	{
		//menu.AddItem("0", "My skills");
		menu.AddItem("0", "我的技能");
	}
	else  
	{
		//menu.AddItem("0", "My skills", ITEMDRAW_DISABLED);
		menu.AddItem("0", "我的技能", ITEMDRAW_DISABLED);
	}
	
	//menu.AddItem("1", "Players balance");
	menu.AddItem("1", "玩家平衡");
	
	//menu.AddItem("2", "Passive skills");
	menu.AddItem("2", "被动技能");
	//menu.AddItem("3", "Activation skills");
	menu.AddItem("3", "激活技能");
	//menu.AddItem("4", "Input skills");
	menu.AddItem("4", "输入技能");
	
	if ( g_NativeItems.items )
	{
		int count = g_NativeItems.items.Length;
		ItemInfo info;

		for( int i; i < count; i++ )
		{
			g_NativeItems.GetItem(i, info);

			FormatEx(item, sizeof item, "__plNative__%i", i);
			FormatEx(display, sizeof display, "%s", info.display);
			menu.AddItem(item, display);
		}
	}
	menu.ExitButton = true;
	
	menu.Display(client, MENU_TIME_FOREVER);
}

void ShowBalances( int client )
{
	static Menu menu;
	
	if ( !menu )
	{
		menu = new Menu(VEmptyHandler);
		menu.ExitBackButton = true;
	}
	
	menu.RemoveAllItems();
	
	char buffer[64];
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if ( !IsClientInGame(i) || client == i || IsFakeClient(i) )
			continue;
			
		Format(buffer, sizeof buffer, "%N - %.1f", i, Skills_GetClientMoney(i));
		menu.AddItem("", buffer, ITEMDRAW_DISABLED);
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
}	

void ShowClientSkills( int client, int selection = 0 )
{
	{
		// warning 217: inconsistent indentation (did you mix tabs and spaces?)
		#pragma unused selection
	}

	Menu menu = new Menu(VSkillUpgradeHandler);
	menu.ExitBackButton = true;
	
	menu.RemoveAllItems();
	
	char name[MAX_SKILL_NAME_LENGTH], temp[4];
	int count = Skills_GetCount(), style;
	
	Format(name, sizeof name, "Purchased skills count: %i", Skills_GetClientSkillsCount(client));
	menu.AddItem("-1", name, ITEMDRAW_DISABLED);
	
	for( int i; i < count; i++ )
	{
		if ( !Skills_ClientHaveByID(client, i) )
			continue;
		
		IntToString(i, temp, sizeof temp);
		style = ITEMDRAW_DEFAULT;
		
		Skills_GetName(i, name);
		
		if ( !Skills_IsUpgradable(name) || !CanClientUpgradeSkill(client, i, name) )
			style = ITEMDRAW_DISABLED;
			
		menu.AddItem(temp, name, style);
	}
	
	//menu.SetTitle("Your skills:");
	menu.SetTitle("你的技能:");
	menu.DisplayAt(client, 0/* selection */, MENU_TIME_FOREVER);
}	

void ShowSkills( int client, SkillType type )
{
	char buffer[MAX_SKILL_NAME_LENGTH + 12], temp[4];
	int count = Skills_GetCount(), style;
	bool have;
	float cost;
	
	Menu menu = new Menu(VSkillsHandler);
	
	for( int i; i < count; i++ )
	{
		Skills_GetName(i, buffer);
		
		if ( Skills_GetType(buffer) != type )
			continue;
			
		if ( !Skills_ExportFloatByName(buffer, "cost", cost, 0.0) )
		{
			ERROR("Failed to get cost for skill %s (%i)", buffer, i);
			continue;
		}

		style = ITEMDRAW_DEFAULT;
		
		IntToString(i, temp, sizeof temp);
		have = Skills_ClientHaveByID(client, i);
		
		if ( have )
			style = ITEMDRAW_DISABLED;
		
		Format(buffer, sizeof buffer, "%s - %.0f", buffer, cost);
		menu.AddItem(temp, buffer, style);
	}
	
	menu.ExitBackButton = true;
	//menu.SetTitle("Skills:");
	menu.SetTitle("技能:");
	menu.Display(client, MENU_TIME_FOREVER);
}

Menu CreateUpgradeMenu( int client, int skillID, int nextLevel, float upgradeCost )
{
	g_flUpgradeCost[client] = upgradeCost;
	
	char buffer[MAX_SKILL_NAME_LENGTH], temp[4];
	Menu menu = new Menu(VMenuUpgradeHandler);
	
	IntToString(skillID, temp, sizeof temp);
	Skills_GetName(skillID, buffer);
	
	//Format(buffer, sizeof buffer, "Skill name: %s", buffer);
	Format(buffer, sizeof buffer, "技能名称: %s", buffer);
	menu.AddItem("", buffer, ITEMDRAW_DISABLED);
	
	//Format(buffer, sizeof buffer, "Next level: %i", nextLevel);
	Format(buffer, sizeof buffer, "下一级别: %i", nextLevel);
	menu.AddItem("", buffer, ITEMDRAW_DISABLED);
	
	Format(buffer, sizeof buffer, "Your money: %.1f", Skills_GetClientMoney(client));
	//Format(buffer, sizeof buffer, "你的积分: %.1f", Skills_GetClientMoney(client));
	menu.AddItem("", buffer, ITEMDRAW_DISABLED);
	
	//Format(buffer, sizeof buffer, "Upgrade cost: %.1f", upgradeCost);
	Format(buffer, sizeof buffer, "升级费用: %.1f", upgradeCost);
	menu.AddItem(buffer, buffer, ITEMDRAW_DISABLED);
	
	menu.AddItem(buffer, buffer, ITEMDRAW_SPACER);
	menu.AddItem(buffer, buffer, ITEMDRAW_SPACER);
	
	menu.AddItem(temp, "Upgrade");
	
	menu.ExitBackButton = true;
	//menu.SetTitle("Upgrade menu:");
	menu.SetTitle("升级菜单:");
	
	return menu;
}

bool CanClientUpgradeSkill( int client, int id, const char[] name )
{
	Function Skills_OnCanClientUpgrade;
	Handle owner = Skills_GetOwner(name);
	
	Skills_OnCanClientUpgrade = GetFunctionByName(owner, "Skills_OnCanClientUpgrade");
	
	if ( Skills_OnCanClientUpgrade == INVALID_FUNCTION )
		return true;
	
	bool canUpgrade;
	
	Call_StartFunction(owner, Skills_OnCanClientUpgrade);
	Call_PushCell(client);
	Call_PushCell(id);
	Call_Finish(canUpgrade);
	
	return canUpgrade;
}

public int VMenuHandler( Menu menu, MenuAction action, int client, int index )
{
	switch( action )
	{
		case MenuAction_End: delete menu;
		case MenuAction_Cancel:
		{
			if( index == MenuCancel_NoDisplay )
				ShowClientSkillMenu(client);
		}
		case MenuAction_Select:
		{
			char item[128];
			menu.GetItem(index, item, sizeof item);
			
			if ( ReplaceString(item, sizeof item, "__plNative__", "", false) > 0 )
			{
				ItemInfo info;
				g_NativeItems.GetItem(StringToInt(item), info);
				
				Call_StartFunction(info.owner, info.callback);
				Call_PushCell(client);
				Call_PushString(info.item);
				Call_Finish();
				
				return 0;
			}
			
			index = StringToInt(item);
			
			if ( !index )
			{
				ShowClientSkills(client, index);
			}
			else
			{
				if ( index == 1 )		ShowBalances(client);
				else if ( index == 2 )	ShowSkills(client, ST_PASSIVE);
				else if ( index == 3 )	ShowSkills(client, ST_ACTIVATION); 
				else if ( index == 4 )	ShowSkills(client, ST_INPUT); 		
			}
		}
	}
	
	return 0;
}

public int VSkillsHandler( Menu menu, MenuAction action, int client, int id )
{
	switch( action )
	{
		case MenuAction_End: delete menu;
		case MenuAction_Cancel:
		{
			if( id == MenuCancel_ExitBack || id == MenuCancel_NoDisplay )
				ShowClientSkillMenu(client);
		}
		case MenuAction_Select:
		{
			char skill[MAX_SKILL_NAME_LENGTH], item[4];
			float cost, money;
			
			menu.GetItem(id, item, sizeof item);
			id = StringToInt(item);
			
			if ( !Skills_GetName(id, skill) )
			{
				ERROR("Failed to get name for %i", id);
				return 0;
			}
			
			if ( !Skills_ExportFloatByName(skill, "cost", cost, 0.0) )
			{
				ERROR("Failed to get cost for %s (%i)", skill, id);
				return 0;
			}
			
			money = Skills_GetClientMoney(client);
			
			if ( money < cost )
			{
				//Skills_PrintToChat(client, "\x04You \x05don't \x04have enough \x03money");
				Skills_PrintToChat(client, "\x04你\x05没有\x04足够的\x03积分");
				sm_skills(client, 0);
				return 0;
			}
			
			Skills_SetClientMoney(client, money - cost);
			Skills_ChangeState(client, id, SS_PURCHASED);
			//Skills_PrintToChatAll("\x04%N \x05bought \x03%s", client, skill);
			Skills_PrintToChatAll("\x04%N\x05买了\x03%s", client, skill);
			sm_skills(client, 0);
		}
	}
	
	return 0;
}

public int VSkillUpgradeHandler( Menu menu, MenuAction action, int client, int index )
{
	switch( action )
	{
		case MenuAction_End: delete menu;
		case MenuAction_Cancel:
		{
			if( index == MenuCancel_ExitBack || index == MenuCancel_NoDisplay )
				ShowClientSkillMenu(client);
		}
		case MenuAction_Select:
		{
			char name[MAX_SKILL_NAME_LENGTH], item[4];
			Function Skills_OnUpgradeMenuRequest;
			Handle owner;
			
			menu.GetItem(index, item, sizeof item);
			index = StringToInt(item);
			
			if ( !Skills_GetName(index, name) )
			{
				ERROR("Failed to get skill name %s (%i)", name, index);
				return 0;
			}			
			
			owner = Skills_GetOwner(name);
			Skills_OnUpgradeMenuRequest = GetFunctionByName(owner, "Skills_OnUpgradeMenuRequest");
			
			if ( Skills_OnUpgradeMenuRequest == INVALID_FUNCTION )
			{
				ERROR("Skill \"%s\" is upgradable but doesn't have Skills_OnUpgradeMenuRequest implementation", name);
				return 0;
			}
			
			UpgradeImpl impl = UI_NULL; 
			int nextLevel;
			float cost;
			
			Call_StartFunction(owner, Skills_OnUpgradeMenuRequest);
			Call_PushCell(client);
			Call_PushCell(index);
			Call_PushCellRef(nextLevel);
			Call_PushFloatRef(cost);
			Call_Finish(impl);
			
			if ( impl == UI_DEFAULT )
			{
				Menu upgradeMenu = CreateUpgradeMenu(client, index, nextLevel, cost);
				upgradeMenu.Display(client, MENU_TIME_FOREVER);
			}
		}
	}
	
	return 0;
}

public int VMenuUpgradeHandler( Menu menu, MenuAction action, int client, int index )
{
	switch( action )
	{
		case MenuAction_End: delete menu;
		case MenuAction_Cancel:
		{
			if( index == MenuCancel_ExitBack || index == MenuCancel_NoDisplay )
				ShowClientSkills(client);
		}
		case MenuAction_Select:
		{
			char name[MAX_SKILL_NAME_LENGTH], item[4];
			menu.GetItem(index, item, sizeof item);
			index = StringToInt(item);
			
			if ( !Skills_GetName(index, name) )
			{
				ERROR("Failed to get skill name %s (%i)", name, index);
				return 0;
			}			
			
			float money, cost;
			
			money = Skills_GetClientMoney(client);
			cost = g_flUpgradeCost[client];
			
			if ( money < cost )
			{
				//Skills_PrintToChat(client, "\x04You \x05don't \x04have enough \x03money");
				Skills_PrintToChat(client, "\x04你\x05没有\x04足够的\x03积分");
				ShowClientSkills(client, index);
				return 0;
			}
			
			Skills_SetClientMoney(client, money - cost);
			Skills_ChangeState(client, index, SS_UPGRADED);
			//Skills_PrintToChat(client, "\x05You have \x04upgraded \x03%s", name);
			Skills_PrintToChat(client, "\x05你已经\x04升级了\x03%s", name);
			ShowClientSkills(client, index);
		}
	}
	
	return 0;
}

public int VEmptyHandler( Menu menu, MenuAction action, int client, int index )
{
	switch( action )
	{
		case MenuAction_Cancel:
		{
			if( index == MenuCancel_ExitBack || index == MenuCancel_NoDisplay )
				ShowClientSkillMenu(client);
		}
	}
	
	return 0;
}

bool AllowedToOpenMenu(int cl, char[] reason, int maxlength)
{
	if (gExport.allow_use_only_in_saferoom && !L4D_IsInFirstCheckpoint(cl) && !L4D_IsInLastCheckpoint(cl))
	{
		strcopy(reason, maxlength, "You must be in saferoom to open skills menu.");
		return false;
	}

	strcopy(reason, maxlength, "Timer to use command expired. Wait for next round.");
	return !g_isBlocked; 
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
	g_isBlocked = false;

	if (gExport.time_to_block != -1.0)
		CreateTimer(gExport.time_to_block, timer_block_command, TIMER_FLAG_NO_MAPCHANGE);
}

public Action timer_block_command(Handle timer)
{
	if (g_isBlocked)
		return Plugin_Continue;

	//Skills_PrintToChatAll("Command to open skills menu has been blocked!");
	Skills_PrintToChatAll("技能菜单指令已被禁用!");
	g_isBlocked = true;
	return Plugin_Continue;
}

public void Skills_OnGetSettings(KeyValues kv)
{
	EXPORT_START("Skills Menu");

	EXPORT_BOOL("allow_use_only_in_saferoom", gExport.allow_use_only_in_saferoom);
	EXPORT_FLOAT_DEFAULT("time_to_block", gExport.time_to_block, -1.0);

	EXPORT_FINISH();
}