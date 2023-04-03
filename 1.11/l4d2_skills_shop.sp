#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#include <l4d2_skills>

public Plugin myinfo =
{
	name = "[L4D2] Skills Shop",
	author = "BHaType",
	description = "Simple shop module for skills",
	version = "1.1",
	url = "https://github.com/Vinillia/l4d2_skills"
};

enum struct ShopItem
{
	char classname[64];
	char display[64];
	float cost;
}

ArrayList g_hItems;
bool g_bLate;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hItems = new ArrayList(sizeof(ShopItem));

	RegAdminCmd("sm_skills_dump_shop_items", sm_skills_dump_shop_items, ADMFLAG_ROOT);
}

public void OnAllPluginsLoaded()
{
	Skills_AddMenuItem("skills_shop", "Shop", ItemMenuCallback);

	if (g_bLate)
		Skills_RequestConfigReload();
}

public Action sm_skills_dump_shop_items(int client, int args)
{
	ShopItem item;
	int size = g_hItems.Length;

	for(int i; i < size; i++)
	{
		g_hItems.GetArray(i, item);
		//Skills_ReplyToCommand(client, "Classname: %s, Alias: %s, Cost: %f", item.classname, item.display, item.cost);
		Skills_ReplyToCommand(client, "类名: %s, 缩写: %s, 价格: %f", item.classname, item.display, item.cost);
	}

	return Plugin_Continue;
}

public void ItemMenuCallback( int client, const char[] item )
{
	ShowClientShop(client);
}

void ShowClientShop( int client, int selection = 0 )
{
	Menu menu = new Menu(VMenuHandler);
	char display[72], temp[4];
	ShopItem item;
	int size = g_hItems.Length;

	for(int i; i < size; i++)
	{
		g_hItems.GetArray(i, item);
		FormatEx(display, sizeof display, "%s (%.0f)", item.display, item.cost);
		IntToString(i, temp, sizeof temp);
		menu.AddItem(temp, display);
	}
	
	//menu.SetTitle("Skills: Shop");
	menu.SetTitle("技能商店");
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	
	menu.DisplayAt(client, selection, MENU_TIME_FOREVER);
}

public int VMenuHandler( Menu menu, MenuAction action, int client, int index )
{
	switch( action )
	{
		case MenuAction_End: delete menu;
		case MenuAction_Cancel:
		{
			if( index == MenuCancel_ExitBack || index == MenuCancel_NoDisplay )
				FakeClientCommand(client, "sm_skills");
		}
		case MenuAction_Select:
		{
			ShopItem item;
			char szItem[4];
			int arridx;
			float money;

			menu.GetItem(index, szItem, sizeof szItem);
			arridx = StringToInt(szItem);
			g_hItems.GetArray(arridx, item);

			money = Skills_GetClientMoney(client);
			ShowClientShop(client, menu.Selection);
			
			if ( money < item.cost )
			{
				//Skills_PrintToChat(client, "\x05You \x04don't \x05have enough \x03money");
				Skills_PrintToChat(client, "\x05你\x04没有\x05足够的\x03积分");
				return 0;
			}
			
			if ( IsLaserSight(item.classname) )
			{
				ExecuteCheatCommand(client, "upgrade_add", "laser_sight");
			}
			else
			{
				GivePlayerItem(client, item.classname);
			}
			
			Skills_AddClientMoney(client, -item.cost, true, true);
		}
	}
	
	return 0;
}

bool IsLaserSight( const char[] item )
{
	return strcmp(item, "laser_sight") == 0;
}

public void Skills_OnGetSettings( KeyValues kv )
{
	EXPORT_START("Skills Shop");
	
	ShopItem item;
	bool next = kv.GotoFirstSubKey(false);

	while(next)
	{
		kv.GetSectionName(item.classname, sizeof ShopItem::classname);
		EXPORT_FLOAT_DEFAULT("cost", item.cost, 500.0);
		EXPORT_STRING_DEFAULT("alias", item.display, sizeof ShopItem::display, item.classname);

		g_hItems.PushArray(item);
		next = kv.GotoNextKey(false);
	}

	EXPORT_FINISH();
}