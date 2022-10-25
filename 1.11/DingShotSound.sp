/*===========================================================================
	Change Log:
1.2 (16-Mar-2022)
	- 更正了PrecacheSound使用错误。
1.1 (20-Dec-2021)
	- 添加了新cookie以记录音效开关。
	- 去除了一处编译warning。
	- 更改了默认音效。
1.0 (10-Dec-2021)
	- 首次发布。

==============================================================================*/

#pragma semicolon 1
# include <sourcemod>
# include <sdktools>
# include <sdkhooks>
# include <clientprefs>

#define DINGSHOTSOUNDS_PATH		"configs/dingshotsounds.txt"

ConVar g_cvDefaultSound;
char g_sDefaultSound[64];

new bool:gb_ClientDingShot[MAXPLAYERS + 1];
new String:g_sDingShotSounds[MAXPLAYERS + 1][64];
new Handle:g_hCookieSounds = INVALID_HANDLE;
new Handle:g_hCookieSwitch = INVALID_HANDLE;
new Handle:g_hSoundsKV;

public Plugin:myinfo =
{
	name = "Dingshot",
	author = "Mengsk",
	description = "自定义爆头音效!",
	version = "1.2",
	url = "https://space.bilibili.com/24447721"		//B站似乎无法识别句末分号，此处末尾应为分号
}

public OnPluginStart()
{
	//读取DingShotSounds.txt文件
	decl String:sBuffer[128];
g_hSoundsKV = CreateKeyValues("DingShotSounds");
BuildPath(Path_SM, sBuffer, sizeof(sBuffer), DINGSHOTSOUNDS_PATH);
if (!FileToKeyValues(g_hSoundsKV, sBuffer))
{
	SetFailState("加载DingShotSounds.txt失败!");
}

//hook事件发生前并指定回调函数
HookEvent("player_hurt", HeadShotHook, EventHookMode_Pre);
HookEvent("infected_hurt", HeadShotHook, EventHookMode_Pre);
HookEvent("infected_death", HeadShotHook, EventHookMode_Pre);

//创建新参数，设置默认爆头音效
g_cvDefaultSound = CreateConVar("dingshot_default", "level/scoreregular.wav", "默认爆头音效");
GetConVarString(g_cvDefaultSound, g_sDefaultSound, sizeof(g_sDefaultSound));
g_cvDefaultSound.AddChangeHook(DingShotDefaultSoundsChange);

//生成cfg文件
AutoExecConfig(true, "dingshot");

//设置客户端命令
RegConsoleCmd("sm_yinxiao", cmdDingShot, "爆头音效开关");
RegConsoleCmd("sm_yinxiaomenu", cmdDingShotMenu, "爆头音效菜单");
RegConsoleCmd("sm_yinxiaomeun", cmdDingShotMenu, "爆头音效菜单");

//创建cookie
g_hCookieSounds = RegClientCookie("DingShot_choices", "DingShot Sounds Choice", CookieAccess_Public);
g_hCookieSwitch = RegClientCookie("DingShot_switch", "DingShot Sounds Choice", CookieAccess_Public);
}

public void OnMapStart()
{
	PrecacheSound("ui/littlereward.wav");
	PrecacheSound("level/bell_normal.wav");
}

public void OnClientConnected(client)
{
	//爆头音效开关默认值
	gb_ClientDingShot[client] = false;
	//检测客户端cookie是否加载
	if (AreClientCookiesCached(client))
	{
		LoadPreferences(client);
	}
}

public OnClientCookiesCached(client)
{
	//排除机器人
	if (IsFakeClient(client)) return;

	//检测客户端cookie是否加载
	if (AreClientCookiesCached(client))
	{
		LoadPreferences(client);
	}
}

//加载客户端cookie
void LoadPreferences(client)
{
	//获取客户端cookie
	char sCookie[64];
	char sSwitch[64];
	GetClientCookie(client, g_hCookieSounds, sCookie, sizeof(sCookie));
	GetClientCookie(client, g_hCookieSwitch, sSwitch, sizeof(sSwitch));

	//如果客户端cookie不为空使用客户端音效，为空使用默认音效
	if (sCookie[0] != '\0')
	{
		if (FileExists(sCookie, false))
		{
			PrintToChat(client, "未找到%s", sCookie);
		}
		g_sDingShotSounds[client] = sCookie;
	}
	else
	{
		g_sDingShotSounds[client] = g_sDefaultSound;
	}

	gb_ClientDingShot[client] = (sSwitch[0] != '\0' && StringToInt(sSwitch));
}

//如果在游戏中改变默认音效参数，执行该函数
public DingShotDefaultSoundsChange(ConVar convar, char[] oldValue, char[] newValue)
{
	//获取新参数
	GetConVarString(g_cvDefaultSound, g_sDefaultSound, sizeof(g_sDefaultSound));

	//刷新客户端音效
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			LoadPreferences(i);
	}

}

//音效菜单命令
public Action cmdDingShotMenu(int client, int argc)
{
	if (!client) return Plugin_Handled;
	DingShotMenu(client);
	return Plugin_Handled;
}

//音效菜单
DingShotMenu(client)
{
	new Handle:hMenu = CreateMenu(DingShotMenuHandler);
	SetMenuTitle(hMenu, "选择爆头音效:");
	new String:sPath[64];
	new String:sName[64];
	KvRewind(g_hSoundsKV);
	if (KvGotoFirstSubKey(g_hSoundsKV))
	{
		do
		{
			KvGetSectionName(g_hSoundsKV, sPath, sizeof(sPath));
			KvGetString(g_hSoundsKV, "name", sName, sizeof(sName));
			AddMenuItem(hMenu, sPath, sName);
		} while (KvGotoNextKey(g_hSoundsKV));
	}
	DisplayMenu(hMenu, client, 20);
}

public DingShotMenuHandler(Handle:menu, MenuAction: action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		//得到客户端选择的音效，sPath是路劲，sName是音效名
		new String:sName[64], String: sPath[64];
		GetMenuItem(menu, param2, sPath, sizeof(sPath), _, sName, sizeof(sName));

		//设置客户端cookie，并更改音效
		int client = param1;
		SetClientCookie(client, g_hCookieSounds, sPath);
		g_sDingShotSounds[client] = sPath;
		PrintToChat(client, "[QAQ]cookie已保存");

		//播放已选择的音效
		EmitSoundToClient(client, sPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

//音效开关
public Action cmdDingShot(int client, int args)
{
	if (!client) return Plugin_Handled;

	gb_ClientDingShot[client] = !gb_ClientDingShot[client];

	if (gb_ClientDingShot[client])
	{
		SetClientCookie(client, g_hCookieSwitch, "1");
		PrintToChat(client, "[QAQ]爆头音效 开启");
	}
	else
	{
		SetClientCookie(client, g_hCookieSwitch, "0");
		PrintToChat(client, "[QAQ]爆头音效 关闭");
	}

	return Plugin_Handled;
}

public HeadShotHook(Handle event, const char[] name, bool dontBroadcast)
{
	//获取event信息
	int hitgroup;
	int attacker = GetEventInt(event, "attacker");
	int type = GetEventInt(event, "type");
	int client = GetClientOfUserId(attacker);

	//判断客户端音效开关
	if (!gb_ClientDingShot[client]) return;

	//获取爆头信息
	if (strcmp(name, "infected_death") == 0)
	{
		hitgroup = GetEventInt(event, "headshot");
	}
	else
	{
		hitgroup = GetEventInt(event, "hitgroup");
	}

	//播放音效
	//Bugs:Tank死亡后，在模型延迟消失时，会频繁触发判定。
	if (IsClientValid(client) && hitgroup == 1 && type != 8)
	{  // 8 == death by fire...
		EmitSoundToClient(client, g_sDingShotSounds[client], SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
	}
}

bool IsClientValid(int client)
{
	if (client >= 1 && client <= MaxClients)
	{
		if (IsClientConnected(client))
		{
			if (IsClientInGame(client))
			{
				return true;
			}
		}
	}
	return false;
}