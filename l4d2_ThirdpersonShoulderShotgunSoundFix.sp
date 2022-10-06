#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

static const String:SOUND_AUTOSHOTGUN[] 		= "weapons/auto_shotgun/gunfire/auto_shotgun_fire_1.wav";
static const String:SOUND_SPASSHOTGUN[] 		= "weapons/auto_shotgun_spas/gunfire/shotgun_fire_1.wav";
static const String:SOUND_PUMPSHOTGUN[] 		= "weapons/shotgun/gunfire/shotgun_fire_1.wav";
static const String:SOUND_CHROMESHOTGUN[] 		= "weapons/shotgun_chrome/gunfire/shotgun_fire_1.wav";

public Plugin:myinfo = 
{
    name = "L4D2 Thirdpersonshoulder Shotgun sound bug fix",
    author = "DeathChaos25",
    description = "Fixes the bug where shotguns make no sound when shot in thirdperson shoulder",
    version = "1.0",
    url = "https://forums.alliedmods.net/showthread.php?t=259986"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{
    decl String:s_GameFolder[32];
    GetGameFolderName(s_GameFolder, sizeof(s_GameFolder)); 
    if (!StrEqual(s_GameFolder, "left4dead2", false))
    {
        strcopy(error, err_max, "This plugin is for Left 4 Dead 2 Only!"); 
        return APLRes_Failure;
    }
    return APLRes_Success; 
}

public OnPluginStart()
{
    HookEvent("weapon_fire", Event_WeaponFire);
}

public OnMapStart()
{
    
    PrefetchSound(SOUND_AUTOSHOTGUN);
    PrecacheSound(SOUND_AUTOSHOTGUN, true);

    PrefetchSound(SOUND_SPASSHOTGUN);
    PrecacheSound(SOUND_SPASSHOTGUN, true);

    PrefetchSound(SOUND_CHROMESHOTGUN);
    PrecacheSound(SOUND_CHROMESHOTGUN, true);

    PrefetchSound(SOUND_PUMPSHOTGUN);
    PrecacheSound(SOUND_PUMPSHOTGUN, true);
    
}

public Action:Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
    new String:weapon[64];
    GetEventString(event, "weapon", weapon, sizeof(weapon));
    
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client < 0 || client > MAXPLAYERS || !IsPlayerAlive(client) || GetClientTeam(client) != 2) 
        return Plugin_Handled;
    
    // Thirdperson Shoulder check coming soon tm
    
    if (StrEqual(weapon, "autoshotgun"))
    {
        EmitSoundToAll(SOUND_AUTOSHOTGUN, client, SNDCHAN_WEAPON);
    }
    else if (StrEqual(weapon, "shotgun_spas"))
    {
        EmitSoundToAll(SOUND_SPASSHOTGUN, client, SNDCHAN_WEAPON);
    }
    else if (StrEqual(weapon, "pumpshotgun"))
    {
        EmitSoundToAll(SOUND_PUMPSHOTGUN, client, SNDCHAN_WEAPON);
    }
    else if (StrEqual(weapon, "shotgun_chrome"))
    {
        EmitSoundToAll(SOUND_CHROMESHOTGUN, client, SNDCHAN_WEAPON);
    }
    
    return Plugin_Continue;
}  