/*===========================================================================
	Change Log:
1.2 (16-Mar-2022)
	- ������PrecacheSoundʹ�ô���
1.1 (20-Dec-2021)
	- �������cookie�Լ�¼��Ч���ء�
	- ȥ����һ������warning��
	- ������Ĭ����Ч��
1.0 (10-Dec-2021)
	- �״η�����

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
	description = "�Զ��屬ͷ��Ч!",
	version = "1.2",
	url = "https://space.bilibili.com/24447721"		//Bվ�ƺ��޷�ʶ���ĩ�ֺţ��˴�ĩβӦΪ�ֺ�
}

public OnPluginStart()
{
	//��ȡDingShotSounds.txt�ļ�
	decl String:sBuffer[128];
g_hSoundsKV = CreateKeyValues("DingShotSounds");
BuildPath(Path_SM, sBuffer, sizeof(sBuffer), DINGSHOTSOUNDS_PATH);
if (!FileToKeyValues(g_hSoundsKV, sBuffer))
{
	SetFailState("����DingShotSounds.txtʧ��!");
}

//hook�¼�����ǰ��ָ���ص�����
HookEvent("player_hurt", HeadShotHook, EventHookMode_Pre);
HookEvent("infected_hurt", HeadShotHook, EventHookMode_Pre);
HookEvent("infected_death", HeadShotHook, EventHookMode_Pre);

//�����²���������Ĭ�ϱ�ͷ��Ч
g_cvDefaultSound = CreateConVar("dingshot_default", "level/scoreregular.wav", "Ĭ�ϱ�ͷ��Ч");
GetConVarString(g_cvDefaultSound, g_sDefaultSound, sizeof(g_sDefaultSound));
g_cvDefaultSound.AddChangeHook(DingShotDefaultSoundsChange);

//����cfg�ļ�
AutoExecConfig(true, "dingshot");

//���ÿͻ�������
RegConsoleCmd("sm_yinxiao", cmdDingShot, "��ͷ��Ч����");
RegConsoleCmd("sm_yinxiaomenu", cmdDingShotMenu, "��ͷ��Ч�˵�");
RegConsoleCmd("sm_yinxiaomeun", cmdDingShotMenu, "��ͷ��Ч�˵�");

//����cookie
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
	//��ͷ��Ч����Ĭ��ֵ
	gb_ClientDingShot[client] = false;
	//���ͻ���cookie�Ƿ����
	if (AreClientCookiesCached(client))
	{
		LoadPreferences(client);
	}
}

public OnClientCookiesCached(client)
{
	//�ų�������
	if (IsFakeClient(client)) return;

	//���ͻ���cookie�Ƿ����
	if (AreClientCookiesCached(client))
	{
		LoadPreferences(client);
	}
}

//���ؿͻ���cookie
void LoadPreferences(client)
{
	//��ȡ�ͻ���cookie
	char sCookie[64];
	char sSwitch[64];
	GetClientCookie(client, g_hCookieSounds, sCookie, sizeof(sCookie));
	GetClientCookie(client, g_hCookieSwitch, sSwitch, sizeof(sSwitch));

	//����ͻ���cookie��Ϊ��ʹ�ÿͻ�����Ч��Ϊ��ʹ��Ĭ����Ч
	if (sCookie[0] != '\0')
	{
		if (FileExists(sCookie, false))
		{
			PrintToChat(client, "δ�ҵ�%s", sCookie);
		}
		g_sDingShotSounds[client] = sCookie;
	}
	else
	{
		g_sDingShotSounds[client] = g_sDefaultSound;
	}

	gb_ClientDingShot[client] = (sSwitch[0] != '\0' && StringToInt(sSwitch));
}

//�������Ϸ�иı�Ĭ����Ч������ִ�иú���
public DingShotDefaultSoundsChange(ConVar convar, char[] oldValue, char[] newValue)
{
	//��ȡ�²���
	GetConVarString(g_cvDefaultSound, g_sDefaultSound, sizeof(g_sDefaultSound));

	//ˢ�¿ͻ�����Ч
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			LoadPreferences(i);
	}

}

//��Ч�˵�����
public Action cmdDingShotMenu(int client, int argc)
{
	if (!client) return Plugin_Handled;
	DingShotMenu(client);
	return Plugin_Handled;
}

//��Ч�˵�
DingShotMenu(client)
{
	new Handle:hMenu = CreateMenu(DingShotMenuHandler);
	SetMenuTitle(hMenu, "ѡ��ͷ��Ч:");
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
		//�õ��ͻ���ѡ�����Ч��sPath��·����sName����Ч��
		new String:sName[64], String: sPath[64];
		GetMenuItem(menu, param2, sPath, sizeof(sPath), _, sName, sizeof(sName));

		//���ÿͻ���cookie����������Ч
		int client = param1;
		SetClientCookie(client, g_hCookieSounds, sPath);
		g_sDingShotSounds[client] = sPath;
		PrintToChat(client, "[QAQ]cookie�ѱ���");

		//������ѡ�����Ч
		EmitSoundToClient(client, sPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

//��Ч����
public Action cmdDingShot(int client, int args)
{
	if (!client) return Plugin_Handled;

	gb_ClientDingShot[client] = !gb_ClientDingShot[client];

	if (gb_ClientDingShot[client])
	{
		SetClientCookie(client, g_hCookieSwitch, "1");
		PrintToChat(client, "[QAQ]��ͷ��Ч ����");
	}
	else
	{
		SetClientCookie(client, g_hCookieSwitch, "0");
		PrintToChat(client, "[QAQ]��ͷ��Ч �ر�");
	}

	return Plugin_Handled;
}

public HeadShotHook(Handle event, const char[] name, bool dontBroadcast)
{
	//��ȡevent��Ϣ
	int hitgroup;
	int attacker = GetEventInt(event, "attacker");
	int type = GetEventInt(event, "type");
	int client = GetClientOfUserId(attacker);

	//�жϿͻ�����Ч����
	if (!gb_ClientDingShot[client]) return;

	//��ȡ��ͷ��Ϣ
	if (strcmp(name, "infected_death") == 0)
	{
		hitgroup = GetEventInt(event, "headshot");
	}
	else
	{
		hitgroup = GetEventInt(event, "hitgroup");
	}

	//������Ч
	//Bugs:Tank��������ģ���ӳ���ʧʱ����Ƶ�������ж���
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