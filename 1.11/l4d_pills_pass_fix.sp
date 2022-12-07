/* >>> CHANGELOG <<< //
[ v1.0 ]
	Initial Release
[ v1.1 ]
	Code Cleanup
[ v1.2 ]
	Code Cleanup
	Fixed L4D1 Support
// >>> CHANGELOG <<< */

#include <sourcemod>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
    name = "[L4D/L4D2] Pills Pass Fix",
    author = "MasterMind420",
    description = "Prevents auto switching to pills or adrenaline when passed to you",
    version = "1.2",
    url = ""
};

public void OnPluginStart()
{
	HookEvent("weapon_given", eWeaponGiven);
}

public void eWeaponGiven(Event event, const char[] name, bool dontBroadcast)
{
	int weapon = GetEventInt(event, "weapon");

	if (weapon == 12 || weapon == 15 || weapon == 23)
		SDKHook(GetClientOfUserId(event.GetInt("userid")), SDKHook_WeaponSwitch, OnWeaponSwitch);
}

public Action OnWeaponSwitch(int client, int weapon)
{
	SDKUnhook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
	return Plugin_Handled;
}