#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
new Handle:hC_SMG;
new C_SMG;
new Handle:hC_Shotgun;
new C_Shotgun;
new Handle:hC_Autoshotgun;
new C_Autoshotgun;
new Handle:hC_AssaultRifle;
new C_AssaultRifle;
new Handle:hC_HuntingRifle;
new C_HuntingRifle;
new Handle:hC_SniperRifle;
new C_SniperRifle;
new Handle:hC_GrenadeLauncher;
new C_GrenadeLauncher;
new Handle:hC_M60;
new C_M60;
new Handle:h_Theammoset;
new Theammoset;

public void OnPluginStart()
{
	
	CreateConVar("L4D2_ammo_set_version", "L4D2备弹量设定1.0", "!ammoset设置弹药 !offammo关闭", 8512, false, 0, false, 0);
	RegConsoleCmd("sm_onammo", Onammosets, "", 0);
	RegConsoleCmd("sm_offammo", Offammosets, "", 0);
	RegConsoleCmd("sm_onammo2", Onammosets2, "", 0);
	RegConsoleCmd("sm_onammo1", Onammosets1, "", 0);
	HookEvent("round_start", EventHook:ammoEvent_RoundStart);
	hC_SMG = CreateConVar("C_SMG", "650", "自定微冲备弹数0-2048(2048=无限)", FCVAR_PLUGIN, bool:true, Float:0.0, bool:true, Float:2048.0);
	C_SMG = GetConVarInt(Handle:hC_SMG);
	hC_Shotgun = CreateConVar("C_Shotgun", "72", "自定单喷备弹数0-2048(2048=无限)", FCVAR_PLUGIN, bool:true, Float:0.0, bool:true, Float:2048.0);
	C_Shotgun = GetConVarInt(Handle:hC_Shotgun);
	hC_Autoshotgun = CreateConVar("C_Autoshotgun", "90", "自定连喷备弹数0-2048(2048=无限)", FCVAR_PLUGIN, bool:true, Float:0.0, bool:true, Float:2048.0);
	C_Autoshotgun = GetConVarInt(Handle:hC_Autoshotgun);
	hC_AssaultRifle = CreateConVar("C_AssaultRifle", "360", "自定步枪备弹数0-2048(2048=无限)", FCVAR_PLUGIN, bool:true, Float:0.0, bool:true, Float:2048.0);
	C_AssaultRifle = GetConVarInt(Handle:hC_AssaultRifle);
	hC_HuntingRifle = CreateConVar("C_HuntingRifle", "150", "自定1代狙备弹数0-2048(2048=无限)", FCVAR_PLUGIN, bool:true, Float:0.0, bool:true, Float:2048.0);
	C_HuntingRifle = GetConVarInt(Handle:hC_HuntingRifle);
	hC_SniperRifle = CreateConVar("C_SniperRifle", "180", "自定2代狙备弹数0-2048(2048=无限)", FCVAR_PLUGIN, bool:true, Float:0.0, bool:true, Float:2048.0);
	C_SniperRifle = GetConVarInt(Handle:hC_SniperRifle);
	hC_GrenadeLauncher = CreateConVar("C_GrenadeLauncher", "30", "自定榴弹备弹数0-2048(2048=无限)", FCVAR_PLUGIN, bool:true, Float:0.0, bool:true, Float:2048.0);
	C_GrenadeLauncher = GetConVarInt(Handle:hC_GrenadeLauncher);
	hC_M60 = CreateConVar("C_M60", "0", "自定M60备弹数0-2048(2048=无限)", FCVAR_PLUGIN, bool:true, Float:0.0, bool:true, Float:2048.0);
	C_M60 = GetConVarInt(Handle:hC_M60);
	Theammoset = GetConVarInt(Handle:h_Theammoset);
	AutoExecConfig(true, "l4d2_ammo_set");
	CreateTimer(0.1, InitConVar, any:0, 0);
}

public Action:InitConVar(Handle:timer)
{
	C_SMG = GetConVarInt(Handle:hC_SMG);
	C_Shotgun = GetConVarInt(Handle:hC_Shotgun);
	C_Autoshotgun = GetConVarInt(Handle:hC_Autoshotgun);
	C_AssaultRifle = GetConVarInt(Handle:hC_AssaultRifle);
	C_HuntingRifle = GetConVarInt(Handle:hC_HuntingRifle);
	C_SniperRifle = GetConVarInt(Handle:hC_SniperRifle);
	C_GrenadeLauncher = GetConVarInt(Handle:hC_GrenadeLauncher);
	C_M60 = GetConVarInt(Handle:hC_M60);
	Theammoset = GetConVarInt(Handle:h_Theammoset);
}

public Action:Onammosets(client, args)
{
	Theammoset = 1;
	CreateTimer(0.1, ammosetStartDelays, any:0, 0);
	return Action:3;
}

public Action:Offammosets(client, args)
{
	Theammoset = 0;
	CreateTimer(0.1, ammosetStartDelays, any:0, 0);
	return Action:3;
}

public Action:Onammosets2(client, args)
{
	Theammoset = 2;
	CreateTimer(0.1, ammosetStartDelays, any:0, 0);
	return Action:3;
}

public Action:Onammosets1(client, args)
{
	Theammoset = 3;
	CreateTimer(0.1, ammosetStartDelays, any:0, 0);
	return Action:3;
}

public Action:ammoEvent_RoundStart(Handle:event, String:name[], bool:dontBroadcast)
{
	Theammoset = GetConVarInt(Handle:h_Theammoset);
	CreateTimer(0.1, ammosetStartDelays, any:0, 0);
	return Action:0;
}

public Action:ammosetStartDelays(Handle:timer)
{
	switch (Theammoset)
	{
		case 0: {
			SetConVarInt(FindConVar("ammo_smg_max"), 650, false, false);
			SetConVarInt(FindConVar("ammo_shotgun_max"), 72, false, false);
			SetConVarInt(FindConVar("ammo_autoshotgun_max"), 90, false, false);
			SetConVarInt(FindConVar("ammo_assaultrifle_max"), 360, false, false);
			SetConVarInt(FindConVar("ammo_huntingrifle_max"), 150, false, false);
			SetConVarInt(FindConVar("ammo_sniperrifle_max"), 180, false, false);
			SetConVarInt(FindConVar("ammo_grenadelauncher_max"), 30, false, false);
			SetConVarInt(FindConVar("ammo_m60_max"), 0, false, false);
			PrintToChatAll("\x04[!提示!]\x03 已关闭更多备弹量");
			
			}
		case 1: {
			SetConVarInt(FindConVar("ammo_smg_max"), 1300, false, false);
			SetConVarInt(FindConVar("ammo_shotgun_max"), 144, false, false);
			SetConVarInt(FindConVar("ammo_autoshotgun_max"), 180, false, false);
			SetConVarInt(FindConVar("ammo_assaultrifle_max"), 720, false, false);
			SetConVarInt(FindConVar("ammo_huntingrifle_max"), 300, false, false);
			SetConVarInt(FindConVar("ammo_sniperrifle_max"), 360, false, false);
			SetConVarInt(FindConVar("ammo_grenadelauncher_max"), 60, false, false);
			SetConVarInt(FindConVar("ammo_m60_max"), 150, false, false);
			PrintToChatAll("\x04[!提示!]\x03 已开启2倍备弹");
		}
		case 2: {
			SetConVarInt(FindConVar("ammo_smg_max"), -2, false, false);
			SetConVarInt(FindConVar("ammo_shotgun_max"), -2, false, false);
			SetConVarInt(FindConVar("ammo_autoshotgun_max"), -2, false, false);
			SetConVarInt(FindConVar("ammo_assaultrifle_max"), -2, false, false);
			SetConVarInt(FindConVar("ammo_huntingrifle_max"), -2, false, false);
			SetConVarInt(FindConVar("ammo_sniperrifle_max"), -2, false, false);
			SetConVarInt(FindConVar("ammo_grenadelauncher_max"), -2, false, false);
			SetConVarInt(FindConVar("ammo_m60_max"), -2, false, false);
			PrintToChatAll("\x04[!提示!]\x03 已开启无限备弹");
		}
		case 3: {
			if (C_SMG == 2048)
			{
				C_SMG = -2;
			}
			if (C_Shotgun == 2048)
			{
				C_Shotgun = -2;
			}
			if (C_Autoshotgun == 2048)
			{
				C_Autoshotgun = -2;
			}
			if (C_AssaultRifle == 2048)
			{
				C_AssaultRifle = -2;
			}
			if (C_HuntingRifle == 2048)
			{
				C_HuntingRifle = -2;
			}
			if (C_SniperRifle == 2048)
			{
				C_SniperRifle = -2;
			}
			if (C_GrenadeLauncher == 2048)
			{
				C_GrenadeLauncher = -2;
			}
			if (C_M60 == 2048)
			{
				C_M60 = -2;
			}
			SetConVarInt(FindConVar("ammo_smg_max"), C_SMG, false, false);
			SetConVarInt(FindConVar("ammo_shotgun_max"), C_Shotgun, false, false);
			SetConVarInt(FindConVar("ammo_autoshotgun_max"), C_Autoshotgun, false, false);
			SetConVarInt(FindConVar("ammo_assaultrifle_max"), C_AssaultRifle, false, false);
			SetConVarInt(FindConVar("ammo_huntingrifle_max"), C_HuntingRifle, false, false);
			SetConVarInt(FindConVar("ammo_sniperrifle_max"), C_SniperRifle, false, false);
			SetConVarInt(FindConVar("ammo_grenadelauncher_max"), C_GrenadeLauncher, false, false);
			SetConVarInt(FindConVar("ammo_m60_max"), C_M60, false, false);
			PrintToChatAll("\x04[!提示!]\x03 已开启自定义备弹");
			}
		default: {
			return Action:0;
		}
	}
	return Action:0;
}

