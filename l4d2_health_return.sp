#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.5.0"

int l4d2_Switch;
char slName1[16], slName2[16], slName3[16], slName4[16], slName5[16], slName6[16], classname[128];
int CountKIHNumHead, CountKIHNumShot, CountPistolAmmoHead, CountPistolAmmoShot, CountMagnumAmmoHead, CountMagnumAmmoShot, CountRifleAmmoHead, CountRifleAmmoShot, CountSmgAmmoHead, CountSmgAmmoShot, CountShotgunAmmoHead, CountShotgunAmmoShot, CountChainsawHead, CountChainsawShot;
int CountAutoshotAmmoHead, CountAutoshotAmmoShot, CountHuntingAmmoHead, CountHuntingAmmoShot, CountSniperAmmoHead, CountSniperAmmoShot, CountGrenadeAmmoHead, CountGrenadeAmmoShot;
ConVar hCountPistolAmmoHead, hCountPistolAmmoShot, hCountMagnumAmmoHead, hCountMagnumAmmoShot, hCountRifleAmmoHead, hCountRifleAmmoShot, hCountSmgAmmoHead, hCountSmgAmmoShot, hCountShotgunAmmoHead, hCountShotgunAmmoShot;
ConVar hCountAutoshotAmmoHead, hCountAutoshotAmmoShot, hCountHuntingAmmoHead, hCountHuntingAmmoShot, hCountSniperAmmoHead, hCountSniperAmmoShot, hCountGrenadeAmmoHead, hCountGrenadeAmmoShot, hCountChainsawHead, hCountChainsawShot;
int CountKIHenabled, CountKIHLimit, CountKIHNumoff, CountKIHuhealke, CountKIHurevive, CountKIHrescued, CountKIHWitch, CountKIHWitchShot, CountKIHused, CountKIHTank;
ConVar hCountKIHenabled, hCountKIHNumHead, hCountKIHNumShot, hCountKIHNumoff, hCountKIHTank, hCountKIHWitch, hCountKIHWitchShot, hCountKIHLimit, hCountKIHused, hCountKIHSwitch, hCountKIHrevive, hCountKIHrescued, hCountKIHhealk;
bool HLReturnset, l4d2_HLReturnset, hCountKIH_Switch_true = true;
char clientName[32];

public Plugin myinfo =
{
	name = "加血奖励插件",
	author = "",
	description = "health return",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_onhp", OnHLReturn, "管理员开启击杀特感提示和血量奖励.");
	RegConsoleCmd("sm_offhp", OffHLReturn, "管理员关闭击杀特感提示和血量奖励.");
	
	HookEvent("witch_killed", KIHEvent_KillWitch);//女巫死亡.
	HookEvent("player_death", KIHEvent_KillInfected);//玩家死亡.
	HookEvent("tank_killed", KIHEvent_KillTank);//坦克死亡.
	HookEvent("witch_harasser_set", Witch_Harasser_event);//惊扰女巫
	HookEvent("defibrillator_used", Event_defibrillatorused);//幸存者使用电击器救活队友.
	HookEvent("revive_success", KIHEvent_revive);//救起幸存者
	HookEvent("survivor_rescued", evtSurvivorRescued);//幸存者在营救门复活.
	HookEvent("heal_success", HealSuccess);//幸存者治疗
	
	hCountKIHenabled		= CreateConVar("l4d2_Kill_enabled_health", "1", "启用幸存者血量奖励插件? (指令 !offhp 关闭, ) 0=禁用(总开关,禁用后指令开关也不可用), 1=启用.", FCVAR_NOTIFY);
	hCountKIHSwitch		= CreateConVar("l4d2_Kill_enabled_health_switch", "2", "设置默认开启或关闭血量奖励? (指令 !onhp 开启击杀提示和血量奖励, 再次输入指令只显示击杀提示) 0=关闭, 1=开启击杀提示, 2=开启击杀提示和血量奖励.", FCVAR_NOTIFY);
	hCountKIHNumoff		= CreateConVar("l4d2_Kill_inf_Healthoff", "1", "启用击杀特感提示?(因为多特服特感太多,导致提示过于刷屏) 0=禁用, 1=启用.", FCVAR_NOTIFY);
	hCountKIHNumHead		= CreateConVar("l4d2_Kill_inf_health_Infected_head", "2", "击杀一个特感奖励多少血量(不包括坦克). 0=禁用击杀特感提示,血量和前置弹药奖励.", FCVAR_NOTIFY);
	hCountKIHNumShot		= CreateConVar("l4d2_Kill_inf_health_Infected_shot", "3", "爆头击杀一个特感奖励多少血量(不包括坦克). 0=禁用击杀特感提示,血量和前置弹药奖励.", FCVAR_NOTIFY);
	hCountPistolAmmoHead	= CreateConVar("l4d2_Kill_inf_health_ammo_Pistol_head", "3", "小手枪击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountPistolAmmoShot	= CreateConVar("l4d2_Kill_inf_health_ammo_Pistol_shot", "5", "小手枪爆头击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountAutoshotAmmoHead	= CreateConVar("l4d2_Kill_inf_health_ammo_autoshotgun_head", "1", "连喷击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountAutoshotAmmoShot	= CreateConVar("l4d2_Kill_inf_health_ammo_autoshotgun_shot", "2", "连喷爆头击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountChainsawHead		= CreateConVar("l4d2_Kill_inf_health_ammo_chainsaw_head", "5", "电锯击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountChainsawShot		= CreateConVar("l4d2_Kill_inf_health_ammo_chainsaw_shot", "10", "电锯爆头击杀一个特感奖励多少前置弹药(不包括坦克,好像电锯没有爆头判定). 0=禁用.", FCVAR_NOTIFY);
	hCountGrenadeAmmoHead	= CreateConVar("l4d2_Kill_inf_health_ammo_grenadelauncher_head", "1", "榴弹发射器击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountGrenadeAmmoShot	= CreateConVar("l4d2_Kill_inf_health_ammo_grenadelauncher_shot", "2", "榴弹发射器爆头击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountHuntingAmmoHead	= CreateConVar("l4d2_Kill_inf_health_ammo_huntingrifle_head", "1", "猎枪击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountHuntingAmmoShot	= CreateConVar("l4d2_Kill_inf_health_ammo_huntingrifle_shot", "2", "猎枪爆头击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountMagnumAmmoHead	= CreateConVar("l4d2_Kill_inf_health_ammo_pistol_magnum_head", "1", "马格南击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountMagnumAmmoShot	= CreateConVar("l4d2_Kill_inf_health_ammo_pistol_magnum_shot", "2", "马格南爆头击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountRifleAmmoHead		= CreateConVar("l4d2_Kill_inf_health_ammo_rifle_head", "2", "步枪击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountRifleAmmoShot		= CreateConVar("l4d2_Kill_inf_health_ammo_rifle_shot", "3", "步枪爆头击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountShotgunAmmoHead	= CreateConVar("l4d2_Kill_inf_health_ammo_shotgun_head", "2", "单喷击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountShotgunAmmoShot	= CreateConVar("l4d2_Kill_inf_health_ammo_shotgun_shot", "3", "单喷爆头击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountSmgAmmoHead		= CreateConVar("l4d2_Kill_inf_health_ammo_smg_head", "3", "冲锋枪击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountSmgAmmoShot		= CreateConVar("l4d2_Kill_inf_health_ammo_smg_shot", "4", "冲锋枪爆头击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountSniperAmmoHead	= CreateConVar("l4d2_Kill_inf_health_ammo_sniperrifle_head", "1", "狙击枪击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountSniperAmmoShot	= CreateConVar("l4d2_Kill_inf_health_ammo_sniperrifle_shot", "2", "狙击枪爆头击杀一个特感奖励多少前置弹药(不包括坦克). 0=禁用.", FCVAR_NOTIFY);
	hCountKIHrevive		= CreateConVar("l4d2_Kill_revive_health", "5", "救起倒地的幸存者奖励多少血. 0=禁用提示和血量奖励.", FCVAR_NOTIFY);
	hCountKIHTank			= CreateConVar("l4d2_Kill_tank_health", "15", "杀死坦克的幸存者奖励多少血. 0=禁用提示和血量奖励.", FCVAR_NOTIFY);
	hCountKIHrescued		= CreateConVar("l4d2_Kill_rescued_health", "10", "营救队友的幸存者奖励多少血. 0=禁用提示和血量奖励.", FCVAR_NOTIFY);
	hCountKIHhealk			= CreateConVar("l4d2_Kill_heal_health", "15", "治愈队友的幸存者奖励多少血. 0=禁用提示和血量奖励.", FCVAR_NOTIFY);
	hCountKIHused			= CreateConVar("l4d2_Kill_sed_health", "20", "电击器复活队友的幸存者奖励多少血. 0=禁用提示和血量奖励.", FCVAR_NOTIFY);
	hCountKIHWitch			= CreateConVar("l4d2_Kill_witch_health", "15", "击杀女巫的幸存者奖励多少血. 0=禁用提示和血量奖励.", FCVAR_NOTIFY);
	hCountKIHWitchShot		= CreateConVar("l4d2_Kill_witch_health_2", "25", "秒杀女巫的幸存者奖励多少血. 0=禁用提示和血量奖励.", FCVAR_NOTIFY);
	hCountKIHLimit			= CreateConVar("l4d2_health_Limit", "0", "设置幸存者获得血量奖励的最高上限(获取幸存者血量上限跟这个值相加).", FCVAR_NOTIFY);
	
	hCountKIHNumHead.AddChangeHook(HealthConVarChanged);
	hCountKIHNumShot.AddChangeHook(HealthConVarChanged);
	hCountPistolAmmoHead.AddChangeHook(HealthConVarChanged);
	hCountPistolAmmoShot.AddChangeHook(HealthConVarChanged);
	hCountMagnumAmmoHead.AddChangeHook(HealthConVarChanged);
	hCountMagnumAmmoShot.AddChangeHook(HealthConVarChanged);
	hCountRifleAmmoHead.AddChangeHook(HealthConVarChanged);
	hCountRifleAmmoShot.AddChangeHook(HealthConVarChanged);
	hCountSmgAmmoHead.AddChangeHook(HealthConVarChanged);
	hCountSmgAmmoShot.AddChangeHook(HealthConVarChanged);
	hCountShotgunAmmoHead.AddChangeHook(HealthConVarChanged);
	hCountShotgunAmmoShot.AddChangeHook(HealthConVarChanged);
	hCountAutoshotAmmoHead.AddChangeHook(HealthConVarChanged);
	hCountAutoshotAmmoShot.AddChangeHook(HealthConVarChanged);
	hCountHuntingAmmoHead.AddChangeHook(HealthConVarChanged);
	hCountHuntingAmmoShot.AddChangeHook(HealthConVarChanged);
	hCountSniperAmmoHead.AddChangeHook(HealthConVarChanged);
	hCountSniperAmmoShot.AddChangeHook(HealthConVarChanged);
	hCountGrenadeAmmoHead.AddChangeHook(HealthConVarChanged);
	hCountGrenadeAmmoShot.AddChangeHook(HealthConVarChanged);
	hCountChainsawHead.AddChangeHook(HealthConVarChanged);
	hCountChainsawShot.AddChangeHook(HealthConVarChanged);
	hCountKIHNumoff.AddChangeHook(HealthConVarChanged);
	hCountKIHrevive.AddChangeHook(HealthConVarChanged);
	hCountKIHTank.AddChangeHook(HealthConVarChanged);
	hCountKIHrescued.AddChangeHook(HealthConVarChanged);
	hCountKIHhealk.AddChangeHook(HealthConVarChanged);
	hCountKIHused.AddChangeHook(HealthConVarChanged);
	hCountKIHWitch.AddChangeHook(HealthConVarChanged);
	hCountKIHWitchShot.AddChangeHook(HealthConVarChanged);
	hCountKIHLimit.AddChangeHook(HealthConVarChanged);
	
	AutoExecConfig(true, "l4d2_health_return");//生成指定文件名的CFG.
}

//地图开始.
public void OnMapStart()
{
	l4d2_HealthChange();
}

public void HealthConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	l4d2_HealthChange();
}

void l4d2_HealthChange()
{
	l4d2_Switch = hCountKIHSwitch.IntValue;
	CountKIHenabled = hCountKIHenabled.IntValue;
	CountKIHLimit = hCountKIHLimit.IntValue;
	CountKIHNumoff = hCountKIHNumoff.IntValue;
	CountKIHuhealke = hCountKIHhealk.IntValue;
	CountKIHurevive = hCountKIHrevive.IntValue;
	CountKIHrescued = hCountKIHrescued.IntValue;
	CountKIHWitch = hCountKIHWitch.IntValue;
	CountKIHWitchShot = hCountKIHWitchShot.IntValue;
	CountKIHused = hCountKIHused.IntValue;
	CountKIHTank = hCountKIHTank.IntValue;
	CountKIHNumHead = hCountKIHNumHead.IntValue;
	CountKIHNumShot = hCountKIHNumShot.IntValue;
	CountPistolAmmoHead = hCountPistolAmmoHead.IntValue;
	CountPistolAmmoShot = hCountPistolAmmoShot.IntValue;
	CountMagnumAmmoHead = hCountMagnumAmmoHead.IntValue;
	CountMagnumAmmoShot = hCountMagnumAmmoShot.IntValue;
	CountRifleAmmoHead = hCountRifleAmmoHead.IntValue;
	CountRifleAmmoShot = hCountRifleAmmoShot.IntValue;
	CountSmgAmmoHead = hCountSmgAmmoHead.IntValue;
	CountSmgAmmoShot = hCountSmgAmmoShot.IntValue;
	CountShotgunAmmoHead = hCountShotgunAmmoHead.IntValue;
	CountShotgunAmmoShot = hCountShotgunAmmoShot.IntValue;
	CountChainsawHead = hCountChainsawHead.IntValue;
	CountChainsawShot = hCountChainsawShot.IntValue;
	CountAutoshotAmmoHead = hCountAutoshotAmmoHead.IntValue;
	CountAutoshotAmmoShot = hCountAutoshotAmmoShot.IntValue;
	CountHuntingAmmoHead = hCountHuntingAmmoHead.IntValue;
	CountHuntingAmmoShot = hCountHuntingAmmoShot.IntValue;
	CountSniperAmmoHead = hCountSniperAmmoHead.IntValue;
	CountSniperAmmoShot = hCountSniperAmmoShot.IntValue;
	CountGrenadeAmmoHead = hCountGrenadeAmmoHead.IntValue;
	CountGrenadeAmmoShot = hCountGrenadeAmmoShot.IntValue;
}

public void OnConfigsExecuted()
{
	if(hCountKIH_Switch_true)
	{
		switch (l4d2_Switch)
		{
			case 0:
			{
				HLReturnset = false;
				l4d2_HLReturnset = false;
			}
			case 1:
			{
				HLReturnset = false;
				l4d2_HLReturnset = true;
			}
			case 2:
			{
				HLReturnset = true;
				l4d2_HLReturnset = true;
			}
		}
	}
}

public Action OffHLReturn(int client, int args)
{
	if(bCheckClientAccess(client) && iGetClientImmunityLevel(client) >= 98)
	{
		switch (CountKIHenabled)
		{
			case 0:
				PrintToChat(client, "\x04[提示]\x05击杀特感坦克女巫提示和血量奖励已禁用,请在CFG中设为1启用.");
			case 1:
			{
				if (l4d2_HLReturnset)
				{
					HLReturnset = false;
					l4d2_HLReturnset = false;
					hCountKIH_Switch_true = false;
					PrintToChatAll("\x04[提示]\x03已关闭\x05击杀特感坦克女巫血量奖励功能和提示.");
				}
				else
				{
					HLReturnset = false;
					l4d2_HLReturnset = false;
					hCountKIH_Switch_true = false;
					PrintToChatAll("\x04[提示]\x03已关闭\x05击杀特感坦克女巫血量奖励功能和提示.");
				}
			}
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

public Action OnHLReturn(int client, int args)
{
	if(bCheckClientAccess(client) && iGetClientImmunityLevel(client) >= 98)
	{
		switch (CountKIHenabled)
		{
			case 0:
				PrintToChat(client, "\x04[提示]\x05击杀特感坦克女巫提示和血量奖励已禁用,请在CFG中设为1启用.");
			case 1:
			{
				if (!l4d2_HLReturnset)
				{
					if (HLReturnset)
					{
						HLReturnset = false;
						l4d2_HLReturnset = true;
						hCountKIH_Switch_true = false;
						PrintToChatAll("\x04[提示]\x03已开启\x05击杀特感坦克女巫提示,禁用了血量奖励.");//聊天窗提示.
					}
					else
					{
						HLReturnset = true;
						l4d2_HLReturnset = true;
						hCountKIH_Switch_true = false;
						PrintToChatAll("\x04[提示]\x03已开启\x05击杀特感坦克女巫血量奖励.");
					}
				}
				else
				{
					if (HLReturnset)
					{
						HLReturnset = false;
						l4d2_HLReturnset = true;
						hCountKIH_Switch_true = false;
						PrintToChatAll("\x04[提示]\x03已开启\x05击杀特感坦克女巫提示,禁用了血量奖励.");//聊天窗提示.
					}
					else
					{
						HLReturnset = true;
						l4d2_HLReturnset = true;
						hCountKIH_Switch_true = false;
						PrintToChatAll("\x04[提示]\x03已开启\x05击杀特感坦克女巫血量奖励.");
					}
				}
			}
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}

int iGetClientImmunityLevel(int client)
{
	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, sSteamID);
	if(admin == INVALID_ADMIN_ID)
		return -999;

	return admin.ImmunityLevel;
}

public void Witch_Harasser_event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (CountKIHenabled == 0)
		return;
		
	if (CountKIHenabled == 1 && l4d2_HLReturnset)
	{
		if(IsValidClient(client) && GetClientTeam(client) == 2)
		{
			GetTrueName(client, clientName);
			PrintToChatAll("\x04[提示]\x03%s\x05惊扰了女巫.", clientName);//聊天窗提示.
		}
	}
}

public void HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	
	if (CountKIHenabled == 0)
		return;
		
	if (CountKIHuhealke == 0)
		return;
		
	if (CountKIHenabled == 1 && l4d2_HLReturnset)
	{
		char subjectname[32];
		GetTrueName(client, clientName);
		GetTrueName(subject, subjectname);
		
		if (client == subject)
			return;
		
		if (GetClientTeam(client) == 2)
		{
			if (HLReturnset)
			{
				if (IsPlayerAlive(client) && !IsPlayerFallen(client))
				{
					int Attackerhealth = GetClientHealth(client);
					int tmphealth = L4D_GetPlayerTempHealth(client);
					int iMaxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
					int iMaxHealthLimit = iMaxHealth + CountKIHLimit;
					if (tmphealth == -1)
						tmphealth = 0;
					if (Attackerhealth + tmphealth + CountKIHuhealke > iMaxHealthLimit)
					{
						float overhealth,fakehealth;
						overhealth = float(Attackerhealth + tmphealth + CountKIHuhealke - iMaxHealthLimit);
						if (tmphealth < overhealth)
							fakehealth = 0.0;
						else
							fakehealth = float(tmphealth) - overhealth;
						SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
						SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fakehealth);
					}
					if ((Attackerhealth + CountKIHuhealke) < iMaxHealthLimit)
						SetEntProp(client, Prop_Send, "m_iHealth", Attackerhealth + CountKIHuhealke);
					else
						SetEntProp(client, Prop_Send, "m_iHealth", iMaxHealthLimit);
					
					int Attackerhealth2 = Attackerhealth + tmphealth;
					
					if (Attackerhealth2 < iMaxHealthLimit)
						PrintToChatAll("\x04[提示]\x03%s\x05治愈了\x03%s\x04,\x05奖励\x03%d\x05点血量.", clientName, subjectname, CountKIHuhealke);//聊天窗提示.
					else
						PrintToChatAll("\x04[提示]\x03%s\x05治愈了\x03%s\x04,\x05血量已达\x03%d\x05上限.", clientName, subjectname, iMaxHealthLimit);//聊天窗提示.
				}
			}
			else
				PrintToChatAll("\x04[提示]\x03%s\x05治愈了\x03%s", clientName, subjectname);//聊天窗提示.
		}
	}
}

public void KIHEvent_KillInfected(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int headshot = GetEventBool(event, "headshot");
	int HLZClass, iMaxHealth, iMaxHealthLimit, iClipCountHead, iClipCountShot;
	
	if (CountKIHenabled == 0)
		return;
		
	if (CountKIHenabled == 1 && l4d2_HLReturnset)
	{
		if(IsValidClient(attacker) && GetClientTeam(attacker) == 2 && IsValidClient(client) && GetClientTeam(client) == 3)
		{
			HLZClass = GetEntProp(client, Prop_Send, "m_zombieClass");
			iMaxHealth = GetEntProp(attacker, Prop_Send, "m_iMaxHealth");
			iMaxHealthLimit = iMaxHealth + CountKIHLimit;
			FormatEx(slName1, sizeof(slName1), "%N", client);
			SplitString(slName1, "Smoker", slName1, sizeof(slName1));
			
			FormatEx(slName2, sizeof(slName2), "%N", client);
			SplitString(slName2, "Boomer", slName2, sizeof(slName2));
			
			FormatEx(slName3, sizeof(slName3), "%N", client);
			SplitString(slName3, "Hunter", slName3, sizeof(slName3));
			
			FormatEx(slName4, sizeof(slName4), "%N", client);
			SplitString(slName4, "Spitter", slName4, sizeof(slName4));
			
			FormatEx(slName5, sizeof(slName5), "%N", client);
			SplitString(slName5, "Jockey", slName5, sizeof(slName5));
			
			FormatEx(slName6, sizeof(slName6), "%N", client);
			SplitString(slName6, "Charger", slName6, sizeof(slName6));

			if (HLZClass == 8)
				return;
			
			int Weapon = GetEntPropEnt(attacker, Prop_Data, "m_hActiveWeapon");
			
			if(!IsValidEdict(Weapon))
				return;
			
			int PrimType = GetEntProp(Weapon, Prop_Send, "m_iPrimaryAmmoType");
			int Clip = GetEntProp(Weapon, Prop_Data, "m_iClip1");
			GetEntityClassname(Weapon, classname, sizeof(classname));
			
			switch (headshot)
			{
				case 0:
				{
					if (CountKIHNumHead == 0)
						return;
					
					switch(PrimType)
					{
						//小手枪.
						case 1:
						{
							iClipCountHead = CountPistolAmmoHead;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountPistolAmmoHead);
						}
						//马格南.
						case 2:
						{
							iClipCountHead = CountMagnumAmmoHead;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountMagnumAmmoHead);
						}
						//步枪.
						case 3:
						{
							iClipCountHead = CountRifleAmmoHead;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountRifleAmmoHead);
						}
						//冲锋枪
						case 5:
						{
							iClipCountHead = CountSmgAmmoHead;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountSmgAmmoHead);
						}
						//单喷
						case 7:
						{
							iClipCountHead = CountShotgunAmmoHead;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountShotgunAmmoHead);
						}
						//连喷
						case 8:
						{
							iClipCountHead = CountAutoshotAmmoHead;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountAutoshotAmmoHead);
						}
						//猎枪
						case 9:
						{
							iClipCountHead = CountHuntingAmmoHead;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountHuntingAmmoHead);
						}
						//狙击枪
						case 10:
						{
							iClipCountHead = CountSniperAmmoHead;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountSniperAmmoHead);
						}
						//榴弹发射器
						case 17:
						{
							iClipCountHead = CountGrenadeAmmoHead;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountGrenadeAmmoHead);
						}
						//电锯
						case 19:
						{
							iClipCountHead = CountChainsawHead;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountChainsawHead);
						}
					}
					
					if (!HLReturnset)
					{
						if (CountKIHNumoff == 0)
							return;
						
						GetAttackerName(attacker, PrimType, HLZClass, iClipCountHead);
					}
					else
					{
						if (IsPlayerAlive(attacker) && !IsPlayerFallen(attacker))
						{
							int Attackerhealth = GetClientHealth(attacker);
							int tmphealth = L4D_GetPlayerTempHealth(attacker);
						
							if (tmphealth == -1)
								tmphealth = 0;
							
							if (Attackerhealth + tmphealth + CountKIHNumHead > iMaxHealthLimit)
							{
								float overhealth,fakehealth;
								overhealth = float(Attackerhealth + tmphealth + CountKIHNumHead - iMaxHealthLimit);
								
								if (tmphealth < overhealth)
									fakehealth = 0.0;
								else
									fakehealth = float(tmphealth) - overhealth;
								
								SetEntPropFloat(attacker, Prop_Send, "m_healthBufferTime", GetGameTime());
								SetEntPropFloat(attacker, Prop_Send, "m_healthBuffer", fakehealth);
							}
								
							if ((Attackerhealth + CountKIHNumHead) < iMaxHealthLimit)
								SetEntProp(attacker, Prop_Send, "m_iHealth", Attackerhealth + CountKIHNumHead);
							else
								SetEntProp(attacker, Prop_Send, "m_iHealth",  iMaxHealthLimit);
							
							if (CountKIHNumoff == 0)
								return;
								
							int Attackerhealth2 = Attackerhealth + tmphealth;
							
							if (Attackerhealth2 < iMaxHealthLimit)
								if (StrEqual(classname, "weapon_melee"))
									GetAttackerNameThe(attacker, -1, HLZClass, iClipCountHead);
								else
									GetAttackerNameThe(attacker, PrimType, HLZClass, iClipCountHead);
							else
								GetAttackerNameLimit(attacker, PrimType, HLZClass, iClipCountHead, iMaxHealthLimit);
						}
						else
						{
							if (CountKIHNumoff == 0)
								return;

							GetAttackerName(attacker, PrimType, HLZClass, iClipCountHead);
						}
					}
				}
				case 1:
				{
					if (CountKIHNumShot == 0)
						return;
					
					switch(PrimType)
					{
						//小手枪.
						case 1:
						{
							iClipCountShot = CountPistolAmmoShot;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountPistolAmmoShot);
						}
						//马格南.
						case 2:
						{
							iClipCountShot = CountMagnumAmmoShot;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountMagnumAmmoShot);
						}
						//步枪.
						case 3:
						{
							iClipCountShot = CountRifleAmmoShot;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountRifleAmmoShot);
						}
						//冲锋枪
						case 5:
						{
							iClipCountShot = CountSmgAmmoShot;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountSmgAmmoShot);
						}
						//单喷
						case 7:
						{
							iClipCountShot = CountShotgunAmmoShot;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountShotgunAmmoShot);
						}
						//连喷
						case 8:
						{
							iClipCountShot = CountAutoshotAmmoShot;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountAutoshotAmmoShot);
						}
						//猎枪
						case 9:
						{
							iClipCountShot = CountHuntingAmmoShot;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountHuntingAmmoShot);
						}
						//狙击枪
						case 10:
						{
							iClipCountShot = CountSniperAmmoShot;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountSniperAmmoShot);
						}
						//榴弹发射器
						case 17:
						{
							iClipCountShot = CountGrenadeAmmoShot;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountGrenadeAmmoShot);
						}
						//电锯
						case 19:
						{
							iClipCountShot = CountChainsawShot;
							SetEntProp(Weapon, Prop_Send, "m_iClip1", Clip + CountChainsawShot);
						}
					}
					if (!HLReturnset)
					{
						if (CountKIHNumoff == 0)
							return;
						
						GetAttackerShotName(attacker, PrimType, HLZClass, iClipCountShot);
					}
					else
					{
						if (IsPlayerAlive(attacker) && !IsPlayerFallen(attacker))
						{
							int Attackerhealth = GetClientHealth(attacker);
							int tmphealth = L4D_GetPlayerTempHealth(attacker);
						
							if (tmphealth == -1)
								tmphealth = 0;
							
							if (Attackerhealth + tmphealth + CountKIHNumShot > iMaxHealthLimit)
							{
								float overhealth,fakehealth;
								overhealth = float(Attackerhealth + tmphealth + CountKIHNumShot - iMaxHealthLimit);
								
								if (tmphealth < overhealth)
									fakehealth = 0.0;
								else
									fakehealth = float(tmphealth) - overhealth;
								
								SetEntPropFloat(attacker, Prop_Send, "m_healthBufferTime", GetGameTime());
								SetEntPropFloat(attacker, Prop_Send, "m_healthBuffer", fakehealth);
							}
							if ((Attackerhealth + CountKIHNumShot) < iMaxHealthLimit)
								SetEntProp(attacker, Prop_Send, "m_iHealth", Attackerhealth + CountKIHNumShot);
							else
								SetEntProp(attacker, Prop_Send, "m_iHealth", iMaxHealthLimit);
							
							if (CountKIHNumoff == 0)
								return;
								
							int Attackerhealth2 = Attackerhealth + tmphealth;
							
							if (Attackerhealth2 < iMaxHealthLimit)
								if (StrEqual(classname, "weapon_melee"))
									GetAttackerShotNameThe(attacker, -1, HLZClass, iClipCountHead);
								else
									GetAttackerShotNameThe(attacker, PrimType, HLZClass, iClipCountShot);
							else
								GetAttackerShotNameLimit(attacker, PrimType, HLZClass, iClipCountShot, iMaxHealthLimit);
						}
						else
						{
							if (CountKIHNumoff == 0)
								return;

							GetAttackerShotName(attacker, PrimType, HLZClass, iClipCountShot);
						}
					}
				}
			}
		}
	}
}

void GetAttackerName(int client, int PrimType, int HLZClass, int iClipCountHead)
{
	if (PrimType == 1 || PrimType == 2 || PrimType == 3 || PrimType == 5 || PrimType == 7 || PrimType == 8 || PrimType == 9 || PrimType == 10 || PrimType == 17 || PrimType == 19)
	{
		switch (HLZClass)
		{
			case 1: //smoker
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03舌头%s\x04,\x05奖励\x03%d\x05前置弹药.", slName1, iClipCountHead);//聊天窗提示.
			case 2: //boomer
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03胖子%s\x04,\x05奖励\x03%d\x05前置弹药.", slName2, iClipCountHead);//聊天窗提示.
			case 3: //hunter
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03猎人%s\x04,\x05奖励\x03%d\x05前置弹药.", slName3, iClipCountHead);//聊天窗提示.
			case 4: //spitter
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03口水%s\x04,\x05奖励\x03%d\x05前置弹药.", slName4, iClipCountHead);//聊天窗提示.
			case 5: //jockey
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03猴子%s\x04,\x05奖励\x03%d\x05前置弹药.", slName5, iClipCountHead);//聊天窗提示.
			case 6: //charger
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03牛牛%s\x04,\x05奖励\x03%d\x05前置弹药.", slName6, iClipCountHead);//聊天窗提示.
		}
	}
	else
	{
		switch (HLZClass)
		{
			case 1: //smoker
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03舌头%s\x04.", slName1);//聊天窗提示.
			case 2: //boomer
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03胖子%s\x04.", slName2);//聊天窗提示.
			case 3: //hunter
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03猎人%s\x04.", slName3);//聊天窗提示.
			case 4: //spitter
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03口水%s\x04.", slName4);//聊天窗提示.
			case 5: //jockey
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03猴子%s\x04.", slName5);//聊天窗提示.
			case 6: //charger
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03牛牛%s\x04.", slName6);//聊天窗提示.
		}
	}
}

void GetAttackerNameThe(int client, int PrimType, int HLZClass, int iClipCountHead)
{
	if (PrimType == 1 || PrimType == 2 || PrimType == 3 || PrimType == 5 || PrimType == 7 || PrimType == 8 || PrimType == 9 || PrimType == 10 || PrimType == 17 || PrimType == 19)
	{
		switch (HLZClass)
		{
			case 1: //smoker
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03舌头%s\x04,\x05奖励\x03%d\x05前置弹药和\x03%d\x05点血量.", slName1, iClipCountHead, CountKIHNumHead);//聊天窗提示.
			case 2: //boomer
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03胖子%s\x04,\x05奖励\x03%d\x05前置弹药和\x03%d\x05点血量.", slName2, iClipCountHead, CountKIHNumHead);//聊天窗提示.
			case 3: //hunter
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03猎人%s\x04,\x05奖励\x03%d\x05前置弹药和\x03%d\x05点血量.", slName3, iClipCountHead, CountKIHNumHead);//聊天窗提示.
			case 4: //spitter
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03口水%s\x04,\x05奖励\x03%d\x05前置弹药和\x03%d\x05点血量.", slName4, iClipCountHead, CountKIHNumHead);//聊天窗提示.
			case 5: //jockey
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03猴子%s\x04,\x05奖励\x03%d\x05前置弹药和\x03%d\x05点血量.", slName5, iClipCountHead, CountKIHNumHead);//聊天窗提示.
			case 6: //charger
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03牛牛%s\x04,\x05奖励\x03%d\x05前置弹药和\x03%d\x05点血量.", slName6, iClipCountHead, CountKIHNumHead);//聊天窗提示.
		}
	}
	else
	{
		switch (HLZClass)
		{
			case 1: //smoker
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03舌头%s\x04,\x05奖励\x03%d\x05点血量.", slName1, CountKIHNumHead);//聊天窗提示.
			case 2: //boomer
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03胖子%s\x04,\x05奖励\x03%d\x05点血量.", slName2, CountKIHNumHead);//聊天窗提示.
			case 3: //hunter
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03猎人%s\x04,\x05奖励\x03%d\x05点血量.", slName3, CountKIHNumHead);//聊天窗提示.
			case 4: //spitter
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03口水%s\x04,\x05奖励\x03%d\x05点血量.", slName4, CountKIHNumHead);//聊天窗提示.
			case 5: //jockey
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03猴子%s\x04,\x05奖励\x03%d\x05点血量.", slName5, CountKIHNumHead);//聊天窗提示.
			case 6: //charger
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03牛牛%s\x04,\x05奖励\x03%d\x05点血量.", slName6, CountKIHNumHead);//聊天窗提示.
		}
	}
}

void GetAttackerNameLimit(int client, int PrimType, int HLZClass, int iClipCountHead, int iMaxHealthLimit)
{
	if (PrimType == 1 || PrimType == 2 || PrimType == 3 || PrimType == 5 || PrimType == 7 || PrimType == 8 || PrimType == 9 || PrimType == 10 || PrimType == 17 || PrimType == 19)
	{
		switch (HLZClass)
		{
			case 1: //smoker
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03舌头%s\x04,\x05奖励\x03%d\x05前置弹药,血量已达\x03%d\x05上限.", slName1, iClipCountHead, iMaxHealthLimit);//聊天窗提示.
			case 2: //boomer
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03胖子%s\x04,\x05奖励\x03%d\x05前置弹药,血量已达\x03%d\x05上限.", slName2, iClipCountHead, iMaxHealthLimit);//聊天窗提示.
			case 3: //hunter
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03猎人%s\x04,\x05奖励\x03%d\x05前置弹药,血量已达\x03%d\x05上限.", slName3, iClipCountHead, iMaxHealthLimit);//聊天窗提示.
			case 4: //spitter
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03口水%s\x04,\x05奖励\x03%d\x05前置弹药,血量已达\x03%d\x05上限.", slName4, iClipCountHead, iMaxHealthLimit);//聊天窗提示.
			case 5: //jockey
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03猴子%s\x04,\x05奖励\x03%d\x05前置弹药,血量已达\x03%d\x05上限.", slName5, iClipCountHead, iMaxHealthLimit);//聊天窗提示.
			case 6: //charger
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03牛牛%s\x04,\x05奖励\x03%d\x05前置弹药,血量已达\x03%d\x05上限.", slName6, iClipCountHead, iMaxHealthLimit);//聊天窗提示.
		}
	}
	else
	{
		switch (HLZClass)
		{
			case 1: //smoker
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03舌头%s\x04,\x05血量已达\x03%d\x05上限.", slName1, iMaxHealthLimit);//聊天窗提示.
			case 2: //boomer
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03胖子%s\x04,\x05血量已达\x03%d\x05上限.", slName2, iMaxHealthLimit);//聊天窗提示.
			case 3: //hunter
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03猎人%s\x04,\x05血量已达\x03%d\x05上限.", slName3, iMaxHealthLimit);//聊天窗提示.
			case 4: //spitter
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03口水%s\x04,\x05血量已达\x03%d\x05上限.", slName4, iMaxHealthLimit);//聊天窗提示.
			case 5: //jockey
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03猴子%s\x04,\x05血量已达\x03%d\x05上限.", slName5, iMaxHealthLimit);//聊天窗提示.
			case 6: //charger
				PrintToChat(client, "\x04[提示]\x05击杀感染者\x03牛牛%s\x04,\x05血量已达\x03%d\x05上限.", slName6, iMaxHealthLimit);//聊天窗提示.
		}
	}
}

void GetAttackerShotName(int client, int PrimType, int HLZClass, int iClipCountShot)
{
	if (PrimType == 1 || PrimType == 2 || PrimType == 3 || PrimType == 5 || PrimType == 7 || PrimType == 8 || PrimType == 9 || PrimType == 10 || PrimType == 17 || PrimType == 19)
	{
		switch (HLZClass)
		{
			case 1: //smoker
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03舌头%s\x04,\x05奖励\x03%d\x05前置弹药.", slName1, iClipCountShot);//聊天窗提示.
			case 2: //boomer
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03胖子%s\x04,\x05奖励\x03%d\x05前置弹药.", slName2, iClipCountShot);//聊天窗提示.
			case 3: //hunter
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03猎人%s\x04,\x05奖励\x03%d\x05前置弹药.", slName3, iClipCountShot);//聊天窗提示.
			case 4: //spitter
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03口水%s\x04,\x05奖励\x03%d\x05前置弹药.", slName4, iClipCountShot);//聊天窗提示.
			case 5: //jockey
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03猴子%s\x04,\x05奖励\x03%d\x05前置弹药.", slName5, iClipCountShot);//聊天窗提示.
			case 6: //charger
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03牛牛%s\x04,\x05奖励\x03%d\x05前置弹药.", slName6, iClipCountShot);//聊天窗提示.
		}
	}
	else
	{
		switch (HLZClass)
		{
			case 1: //smoker
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03舌头%s\x04.", slName1);//聊天窗提示.
			case 2: //boomer
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03胖子%s\x04.", slName2);//聊天窗提示.
			case 3: //hunter
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03猎人%s\x04.", slName3);//聊天窗提示.
			case 4: //spitter
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03口水%s\x04.", slName4);//聊天窗提示.
			case 5: //jockey
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03猴子%s\x04.", slName5);//聊天窗提示.
			case 6: //charger
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03牛牛%s\x04.", slName6);//聊天窗提示.
		}
	}
}

void GetAttackerShotNameThe(int client, int PrimType, int HLZClass, int iClipCountShot)
{
	if (PrimType == 1 || PrimType == 2 || PrimType == 3 || PrimType == 5 || PrimType == 7 || PrimType == 8 || PrimType == 9 || PrimType == 10 || PrimType == 17 || PrimType == 19)
	{
		switch (HLZClass)
		{
			case 1: //smoker
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03舌头%s\x04,\x05奖励\x03%d\x05前置弹药和\x03%d\x05点血量.", slName1, iClipCountShot, CountKIHNumShot);//聊天窗提示.
			case 2: //boomer
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03胖子%s\x04,\x05奖励\x03%d\x05前置弹药和\x03%d\x05点血量.", slName2, iClipCountShot, CountKIHNumShot);//聊天窗提示.
			case 3: //hunter
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03猎人%s\x04,\x05奖励\x03%d\x05前置弹药和\x03%d\x05点血量.", slName3, iClipCountShot, CountKIHNumShot);//聊天窗提示.
			case 4: //spitter
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03口水%s\x04,\x05奖励\x03%d\x05前置弹药和\x03%d\x05点血量.", slName4, iClipCountShot, CountKIHNumShot);//聊天窗提示.
			case 5: //jockey
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03猴子%s\x04,\x05奖励\x03%d\x05前置弹药和\x03%d\x05点血量.", slName5, iClipCountShot, CountKIHNumShot);//聊天窗提示.
			case 6: //charger
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03牛牛%s\x04,\x05奖励\x03%d\x05前置弹药和\x03%d\x05点血量.", slName6, iClipCountShot, CountKIHNumShot);//聊天窗提示.
		}
	}
	else
	{
		switch (HLZClass)
		{
			case 1: //smoker
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03舌头%s\x04,\x05奖励\x03%d\x05点血量.", slName1, CountKIHNumShot);//聊天窗提示.
			case 2: //boomer
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03胖子%s\x04,\x05奖励\x03%d\x05点血量.", slName2, CountKIHNumShot);//聊天窗提示.
			case 3: //hunter
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03猎人%s\x04,\x05奖励\x03%d\x05点血量.", slName3, CountKIHNumShot);//聊天窗提示.
			case 4: //spitter
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03口水%s\x04,\x05奖励\x03%d\x05点血量.", slName4, CountKIHNumShot);//聊天窗提示.
			case 5: //jockey
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03猴子%s\x04,\x05奖励\x03%d\x05点血量.", slName5, CountKIHNumShot);//聊天窗提示.
			case 6: //charger
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03牛牛%s\x04,\x05奖励\x03%d\x05点血量.", slName6, CountKIHNumShot);//聊天窗提示.
		}
	}
}

void GetAttackerShotNameLimit(int client, int PrimType, int HLZClass, int iClipCountShot, int iMaxHealthLimit)
{
	if (PrimType == 1 || PrimType == 2 || PrimType == 3 || PrimType == 5 || PrimType == 7 || PrimType == 8 || PrimType == 9 || PrimType == 10 || PrimType == 17 || PrimType == 19)
	{
		switch (HLZClass)
		{
			case 1: //smoker
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03舌头%s\x04,\x05奖励\x03%d\x05前置弹药,血量已达\x03%d\x05上限.", slName1, iClipCountShot, iMaxHealthLimit);//聊天窗提示.
			case 2: //boomer
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03胖子%s\x04,\x05奖励\x03%d\x05前置弹药,血量已达\x03%d\x05上限.", slName2, iClipCountShot, iMaxHealthLimit);//聊天窗提示.
			case 3: //hunter
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03猎人%s\x04,\x05奖励\x03%d\x05前置弹药,血量已达\x03%d\x05上限.", slName3, iClipCountShot, iMaxHealthLimit);//聊天窗提示.
			case 4: //spitter
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03口水%s\x04,\x05奖励\x03%d\x05前置弹药,血量已达\x03%d\x05上限.", slName4, iClipCountShot, iMaxHealthLimit);//聊天窗提示.
			case 5: //jockey
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03猴子%s\x04,\x05奖励\x03%d\x05前置弹药,血量已达\x03%d\x05上限.", slName5, iClipCountShot, iMaxHealthLimit);//聊天窗提示.
			case 6: //charger
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03牛牛%s\x04,\x05奖励\x03%d\x05前置弹药,血量已达\x03%d\x05上限.", slName6, iClipCountShot, iMaxHealthLimit);//聊天窗提示.
		}
	}
	else
	{
		switch (HLZClass)
		{
			case 1: //smoker
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03舌头%s\x04,\x05血量已达\x03%d\x05上限.", slName1, iMaxHealthLimit);//聊天窗提示.
			case 2: //boomer
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03胖子%s\x04,\x05血量已达\x03%d\x05上限.", slName2, iMaxHealthLimit);//聊天窗提示.
			case 3: //hunter
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03猎人%s\x04,\x05血量已达\x03%d\x05上限.", slName3, iMaxHealthLimit);//聊天窗提示.
			case 4: //spitter
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03口水%s\x04,\x05血量已达\x03%d\x05上限.", slName4, iMaxHealthLimit);//聊天窗提示.
			case 5: //jockey
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03猴子%s\x04,\x05血量已达\x03%d\x05上限.", slName5, iMaxHealthLimit);//聊天窗提示.
			case 6: //charger
				PrintToChat(client, "\x04[提示]\x05爆头击杀感染者\x03牛牛%s\x04,\x05血量已达\x03%d\x05上限.", slName6, iMaxHealthLimit);//聊天窗提示.
		}
	}
}

public void KIHEvent_revive(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	
	if (CountKIHenabled == 0)
		return;
		
	if (CountKIHurevive == 0)
		return;
		
	if (CountKIHenabled == 1 && l4d2_HLReturnset)
	{
		if(IsValidClient(client) && GetClientTeam(client) == 2 && IsValidClient(subject) && GetClientTeam(subject) == 2)
		{
			char subjectname[32];
			GetTrueName(client, clientName);
			GetTrueName(subject, subjectname);
			
			if (client == subject)
			{
				PrintToChatAll("\x04[提示]\x03%s\x05救起了自己.", clientName);//聊天窗提示.
				return;
			}
			if (HLReturnset)
			{
				if (IsPlayerAlive(client) && !IsPlayerFallen(client))
				{
					int Attackerhealth = GetClientHealth(client);
					int tmphealth = L4D_GetPlayerTempHealth(client);
					int iMaxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
					int iMaxHealthLimit = iMaxHealth + CountKIHLimit;
					if (tmphealth == -1)
					{
						tmphealth = 0;
					}
						
					if (Attackerhealth + tmphealth + CountKIHurevive > iMaxHealthLimit)
					{
						float overhealth,fakehealth;
						overhealth = float(Attackerhealth + tmphealth + CountKIHurevive - iMaxHealthLimit);
						if (tmphealth < overhealth)
						{
							fakehealth = 0.0;
						}
						else
						{
							fakehealth = float(tmphealth) - overhealth;
						}
						SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
						SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fakehealth);
					}
					if ((Attackerhealth + CountKIHurevive) < iMaxHealthLimit)
						SetEntProp(client, Prop_Send, "m_iHealth", Attackerhealth + CountKIHurevive);
					else
						SetEntProp(client, Prop_Send, "m_iHealth", iMaxHealthLimit);
						
					int Attackerhealth2 = Attackerhealth + tmphealth;
					
					if (Attackerhealth2 < iMaxHealthLimit)
						PrintToChatAll("\x04[提示]\x03%s\x05救起了\x03%s\x04,\x05奖励\x03%d\x05点血量.", clientName, subjectname, CountKIHurevive);//聊天窗提示.
					else
						PrintToChatAll("\x04[提示]\x03%s\x05救起了\x03%s\x04,\x05血量已达\x03%d\x05上限.", clientName, subjectname, iMaxHealthLimit);//聊天窗提示.
				}
			}
			else
				PrintToChatAll("\x04[提示]\x03%s\x05救起了\x03%s", clientName, subjectname);//聊天窗提示.
		}
	}
}

//幸存者在营救门复活.
public void evtSurvivorRescued(Event event, const char[] name, bool dontBroadcast)
{
	int rescuer = GetClientOfUserId(event.GetInt("rescuer"));
	int client = GetClientOfUserId(event.GetInt("victim"));
	
	if (CountKIHenabled == 0)
		return;
		
	if (CountKIHrescued == 0)
		return;
		
	if (CountKIHenabled == 1 && l4d2_HLReturnset)
	{
		if(IsValidClient(rescuer) && GetClientTeam(rescuer) == 2 && IsValidClient(client) && GetClientTeam(client) == 2)
		{
			char rescuername[32];
			GetTrueName(client, clientName);
			GetTrueName(rescuer, rescuername);
			if (client == rescuer)
			{
				PrintToChatAll("\x04[提示]\x03%s\x05营救了自己.", rescuername);//聊天窗提示.
				return;
			}
			if (HLReturnset)
			{
				if (IsPlayerAlive(rescuer) && !IsPlayerFallen(rescuer))
				{
					int Attackerhealth = GetClientHealth(rescuer);
					int tmphealth = L4D_GetPlayerTempHealth(rescuer);
					int iMaxHealth = GetEntProp(rescuer, Prop_Send, "m_iMaxHealth");
					int iMaxHealthLimit = iMaxHealth + CountKIHLimit;
					
					if (tmphealth == -1)
					{
						tmphealth = 0;
					}
						
					if (Attackerhealth + tmphealth + CountKIHrescued > iMaxHealthLimit)
					{
						float overhealth,fakehealth;
						overhealth = float(Attackerhealth + tmphealth + CountKIHrescued - iMaxHealthLimit);
						if (tmphealth < overhealth)
						{
							fakehealth = 0.0;
						}
						else
						{
							fakehealth = float(tmphealth) - overhealth;
						}
						SetEntPropFloat(rescuer, Prop_Send, "m_healthBufferTime", GetGameTime());
						SetEntPropFloat(rescuer, Prop_Send, "m_healthBuffer", fakehealth);
					}
					if ((Attackerhealth + CountKIHrescued) < iMaxHealthLimit)
						SetEntProp(rescuer, Prop_Send, "m_iHealth", Attackerhealth + CountKIHrescued);
					else
						SetEntProp(rescuer, Prop_Send, "m_iHealth", iMaxHealthLimit);
					
					int Attackerhealth2 = Attackerhealth + tmphealth;
					
					if (Attackerhealth2 < iMaxHealthLimit)
						PrintToChatAll("\x04[提示]\x03%s\x05营救了\x03%s\x04,\x05奖励\x03%d\x05点血量.", rescuername, clientName, CountKIHrescued);//聊天窗提示.
					else
						PrintToChatAll("\x04[提示]\x03%s\x05营救了\x03%s\x04,\x05血量已达\x03%d\x05上限.", rescuername, clientName, iMaxHealthLimit);//聊天窗提示.
				}
			}
			else
				PrintToChatAll("\x04[提示]\x03%s\x05营救了\x03%s", rescuername, clientName);//聊天窗提示.
		}
	}
}

public void Event_defibrillatorused(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));
	
	if (CountKIHenabled == 0)
		return;
		
	if (CountKIHused == 0)
		return;
		
	if (CountKIHenabled == 1 && l4d2_HLReturnset)
	{
		if(IsValidClient(client) && GetClientTeam(client) == 2 && IsValidClient(subject) && GetClientTeam(subject) == 2)
		{
			char subjectname[32];
			GetTrueName(client, clientName);
			GetTrueName(subject, subjectname);
			if (client == subject)
			{
				PrintToChatAll("\x04[提示]\x03%s\x05救活了自己.", clientName);//聊天窗提示.
				return;
			}
			if (HLReturnset)
			{	
				if (IsPlayerAlive(client) && !IsPlayerFallen(client))
				{
					int Attackerhealth = GetClientHealth(client);
					int tmphealth = L4D_GetPlayerTempHealth(client);
					int iMaxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
					int iMaxHealthLimit = iMaxHealth + CountKIHLimit;
					
					if (tmphealth == -1)
					{
						tmphealth = 0;
					}
						
					if (Attackerhealth + tmphealth + CountKIHused > iMaxHealthLimit)
					{
						float overhealth,fakehealth;
						overhealth = float(Attackerhealth + tmphealth + CountKIHused - iMaxHealthLimit);
						if (tmphealth < overhealth)
						{
							fakehealth = 0.0;
						}
						else
						{
							fakehealth = float(tmphealth) - overhealth;
						}
						SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
						SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fakehealth);
					}
					if ((Attackerhealth + CountKIHused) < iMaxHealthLimit)
						SetEntProp(client, Prop_Send, "m_iHealth", Attackerhealth + CountKIHused);
					else
						SetEntProp(client, Prop_Send, "m_iHealth", iMaxHealthLimit);
					
					int Attackerhealth2 = Attackerhealth + tmphealth;
					
					if (Attackerhealth2 < iMaxHealthLimit)
						PrintToChatAll("\x04[提示]\x03%s\x05救活了\x03%s\x04,\x05奖励\x03%d\x05点血量.", clientName, subjectname, CountKIHused);//聊天窗提示.
					else
						PrintToChatAll("\x04[提示]\x03%s\x05救活了\x03%s\x04,\x05血量已达\x03%d\x05上限.", clientName, subjectname, iMaxHealthLimit);//聊天窗提示.
				}
			}
			else
				PrintToChatAll("\x04[提示]\x03%s\x05救活了\x03%s", clientName, subjectname);//聊天窗提示.
		}
	}
}

public void KIHEvent_KillTank(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (CountKIHenabled == 0)
		return;
		
	if (CountKIHTank == 0)
		return;
		
	if (CountKIHenabled == 1 && l4d2_HLReturnset)
	{
		if(IsValidClient(attacker) && GetClientTeam(attacker) == 2)
		{
			char attackername[32];
			GetTrueName(attacker, attackername);
			char slName8[8];
			FormatEx(slName8, sizeof(slName8), "%N", client);
			SplitString(slName8, "Tank", slName8, sizeof(slName8));
			
			if (HLReturnset)
			{
				if (IsPlayerAlive(attacker) && !IsPlayerFallen(attacker))
				{
					int Attackerhealth = GetClientHealth(attacker);
					int tmphealth = L4D_GetPlayerTempHealth(attacker);
					int iMaxHealth = GetEntProp(attacker, Prop_Send, "m_iMaxHealth");
					int iMaxHealthLimit = iMaxHealth + CountKIHLimit;
					
					if (tmphealth == -1)
						tmphealth = 0;
						
					if (Attackerhealth + tmphealth + CountKIHTank > iMaxHealthLimit)
					{
						float overhealth,fakehealth;
						overhealth = float(Attackerhealth + tmphealth + CountKIHTank - iMaxHealthLimit);
						if (tmphealth < overhealth)
							fakehealth = 0.0;
						else
							fakehealth = float(tmphealth) - overhealth;
						SetEntPropFloat(attacker, Prop_Send, "m_healthBufferTime", GetGameTime());
						SetEntPropFloat(attacker, Prop_Send, "m_healthBuffer", fakehealth);
					}
					if ((Attackerhealth + CountKIHTank) < iMaxHealthLimit)
						SetEntProp(attacker, Prop_Send, "m_iHealth", Attackerhealth + CountKIHTank);
					else
						SetEntProp(attacker, Prop_Send, "m_iHealth", iMaxHealthLimit);
					
					int Attackerhealth2 = Attackerhealth + tmphealth;
					
					if (Attackerhealth2 < iMaxHealthLimit)
						PrintToChatAll("\x04[提示]\x03%s\x05击杀了\x03坦克%s\x04,\x05奖励\x03%d\x05点血量.", attackername, slName8, CountKIHTank);
					else
						PrintToChatAll("\x04[提示]\x03%s\x05击杀了\x03坦克%s\x04,\x05血量已达\x03%d\x05上限.", attackername, slName8, iMaxHealthLimit);//聊天窗提示.
				}
			}
			else
				PrintToChatAll("\x04[提示]\x03%s\x05击杀了\x03坦克%s\x05.", attackername, slName8);//聊天窗提示.
		}
	}
}

public void KIHEvent_KillWitch(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int Crownd   = GetEventBool(event,"oneshot");
	
	if (CountKIHenabled == 0)
		return;
		
	if (CountKIHenabled == 1 && l4d2_HLReturnset)
	{
		if(IsValidClient(client) && GetClientTeam(client) == 2)
		{
			GetTrueName(client, clientName);
			
			if (IsPlayerAlive(client) && !IsPlayerFallen(client))
			{
				switch (Crownd)
				{
					case 0:
					{
						if (CountKIHWitch == 0)
							return;
						
						if (HLReturnset)
						{
							int Attackerhealth = GetClientHealth(client);
							int tmphealth = L4D_GetPlayerTempHealth(client);
							int iMaxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
							int iMaxHealthLimit = iMaxHealth + CountKIHLimit;
					
							if (tmphealth == -1)
								tmphealth = 0;
						
							if (Attackerhealth + tmphealth + CountKIHWitch > iMaxHealthLimit)
							{
								float overhealth,fakehealth;
								overhealth = float(Attackerhealth + tmphealth + CountKIHWitch - iMaxHealthLimit);
								if (tmphealth < overhealth)
									fakehealth = 0.0;
								else
									fakehealth = float(tmphealth) - overhealth;
								SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
								SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fakehealth);
							}
							if ((Attackerhealth + CountKIHWitch) < iMaxHealthLimit)
								SetEntProp(client, Prop_Send, "m_iHealth", Attackerhealth + CountKIHWitch);
							else
								SetEntProp(client, Prop_Send, "m_iHealth", iMaxHealthLimit);
							
							int Attackerhealth2 = Attackerhealth + tmphealth;
						
							if (Attackerhealth2 < iMaxHealthLimit)
								PrintToChatAll("\x04[提示]\x03%s\x05击杀了\x03女巫\x04,\x05奖励\x03%d\x05点血量.", clientName, CountKIHWitch);
							else
								PrintToChatAll("\x04[提示]\x03%s\x05击杀了\x03女巫\x04,\x05血量已达\x03%d\x05上限.", clientName, iMaxHealthLimit);//聊天窗提示.
						}
						else
							PrintToChatAll("\x04[提示]\x03%s\x05击杀了\x03女巫\x05.", clientName);//聊天窗提示.
					}
					case 1:
					{
						if (CountKIHWitchShot == 0)
							return;
						
						if (HLReturnset)
						{
							int Attackerhealth = GetClientHealth(client);
							int tmphealth = L4D_GetPlayerTempHealth(client);
							int iMaxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
							int iMaxHealthLimit = iMaxHealth + CountKIHLimit;
							
							if (tmphealth == -1)
								tmphealth = 0;
						
							if (Attackerhealth + tmphealth + CountKIHWitchShot > iMaxHealthLimit)
							{
								float overhealth,fakehealth;
								overhealth = float(Attackerhealth + tmphealth + CountKIHWitchShot - iMaxHealthLimit);
								if (tmphealth < overhealth)
									fakehealth = 0.0;
								else
									fakehealth = float(tmphealth) - overhealth;
								SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
								SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fakehealth);
							}
							if ((Attackerhealth + CountKIHWitchShot) < iMaxHealthLimit)
								SetEntProp(client, Prop_Send, "m_iHealth", Attackerhealth + CountKIHWitchShot);
							else
								SetEntProp(client, Prop_Send, "m_iHealth", iMaxHealthLimit);

							int Attackerhealth2 = Attackerhealth + tmphealth;
						
							if (Attackerhealth2 < iMaxHealthLimit)
								PrintToChatAll("\x04[提示]\x03%s\x05奋力一击\x04,\x05秒杀了\x03女巫\x04,\x05奖励\x03%d\x05点血量.", clientName, CountKIHWitchShot);
							else
								PrintToChatAll("\x04[提示]\x03%s\x05奋力一击\x04,\x05秒杀了女巫\x04,\x05血量已达\x03%d\x05上限.", clientName, iMaxHealthLimit);//聊天窗提示.
						}
						else
							PrintToChatAll("\x04[提示]\x03%s\x05奋力一击\x04,\x05秒杀了女巫.", clientName);//聊天窗提示.
					}
				}
			}
		}
	}
}

int L4D_GetPlayerTempHealth(int client)
{
    static Handle painPillsDecayCvar = null;
    if (painPillsDecayCvar == null)
    {
        painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
        if (painPillsDecayCvar == null)
            return -1;
    }

    int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(painPillsDecayCvar))) - 1;
    return tempHealth < 0 ? 0 : tempHealth;
}

bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

//倒地的.
bool IsPlayerFallen(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

void GetTrueName(int bot, char[] savename)
{
	int tbot = IsClientIdle(bot);
	
	if(tbot != 0)
		Format(savename, 32, "★闲置:%N★", tbot);
	else
		GetClientName(bot, savename, 32);
}

int IsClientIdle(int bot)
{
	if(IsClientInGame(bot) && GetClientTeam(bot) == 2 && IsFakeClient(bot))
	{
		char sNetClass[12];
		GetEntityNetClass(bot, sNetClass, sizeof(sNetClass));

		if(strcmp(sNetClass, "SurvivorBot") == 0)
		{
			int client = GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID"));			
			if(client > 0 && IsClientInGame(client))
				return client;
		}
	}
	return 0;
}