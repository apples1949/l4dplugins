/**
// ====================================================================================================
Change Log:

1.0.8 (23-September-2021)
    - Added cvar to block damage from any damage type.
    - Added cvar to block damage from generic damage types. (thanks "KRUTIK" for reporting)

1.0.7 (11-April-2021)
    - Fixed gascans not applying damage forces on shove. (thanks "Forgetest" for reporting)

1.0.6 (26-January-2021)
    - Fixed incompatibility with other plugins that use OnTakeDamage. (thanks "Tonblader" for reporting)
    - Added invulnerability cvar to the chainsaw.

1.0.5 (12-January-2021)
    - Added cvar to control distance invulnerability. (thanks "cravenge" for requesting)

1.0.4 (03-January-2021)
    - Fixed "Invalid memory access" error. (thanks "ur5efj" for reporting)

1.0.3 (31-December-2020)
    - Added cvar to control both normal and scavenge gascan health. (thanks "Tonblader" for requesting)
    - Added cvar to block shove damage.

1.0.2 (29-November-2020)
    - Added support to physics_prop, prop_physics_override and prop_physics_multiplayer.

1.0.1 (26-October-2020)
    - Added cvar to block bullet damage. (thanks to "Psyk0tik")
    - Added cvar to block melee damage.
    - Added support to prop_physics / physics_prop gascans.
    - Added L4D1 support.
    - Improved the damage type check.

1.0.0 (26-October-2020)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D1 & L4D2] Gascan Invulnerable"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Turns gascan invulnerable to certain damages types"
#define PLUGIN_VERSION                "1.0.8"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=328100"

// ====================================================================================================
// Plugin Info
// ====================================================================================================
public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = PLUGIN_URL
}

// ====================================================================================================
// Includes
// ====================================================================================================
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// ====================================================================================================
// Pragmas
// ====================================================================================================
#pragma semicolon 1
#pragma newdecls required

// ====================================================================================================
// Cvar Flags
// ====================================================================================================
#define CVAR_FLAGS                    FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION     FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

// ====================================================================================================
// Filenames
// ====================================================================================================
#define CONFIG_FILENAME               "l4d_gascan_invul"

// ====================================================================================================
// Defines
// ====================================================================================================
#define MODEL_GASCAN                  "models/props_junk/gascan001a.mdl"

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;
ConVar g_hCvar_Health;
ConVar g_hCvar_Distance;
ConVar g_hCvar_AnyDamage;
ConVar g_hCvar_GenericDamage;
ConVar g_hCvar_ShoveDamage;
ConVar g_hCvar_MeleeDamage;
ConVar g_hCvar_BulletDamage;
ConVar g_hCvar_FireDamage;
ConVar g_hCvar_BlastDamage;
ConVar g_hCvar_ChainsawDamage;
ConVar g_hCvar_SpitDamage;
ConVar g_hCvar_ScavengeGascan;
ConVar g_hCvar_ScavengeHealth;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bL4D2;
bool g_bCvar_Enabled;
bool g_bCvar_Distance;
bool g_bCvar_Health;
bool g_bCvar_AnyDamage;
bool g_bCvar_GenericDamage;
bool g_bCvar_ShoveDamage;
bool g_bCvar_MeleeDamage;
bool g_bCvar_BulletDamage;
bool g_bCvar_FireDamage;
bool g_bCvar_BlastDamage;
bool g_bCvar_ChainsawDamage;
bool g_bCvar_SpitDamage;
bool g_bCvar_ScavengeGascan;
bool g_bCvar_ScavengeHealth;

// ====================================================================================================
// int - Plugin Variables
// ====================================================================================================
int g_iModel_Gascan = -1;
int g_iCvar_Health;
int g_iCvar_ScavengeHealth;

// ====================================================================================================
// float - Plugin Variables
// ====================================================================================================
float g_fCvar_Distance;

// ====================================================================================================
// Plugin Start
// ====================================================================================================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion engine = GetEngineVersion();

    if (engine != Engine_Left4Dead && engine != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "This plugin only runs in \"Left 4 Dead\" and \"Left 4 Dead 2\" game");
        return APLRes_SilentFailure;
    }

    g_bL4D2 = (engine == Engine_Left4Dead2);

    return APLRes_Success;
}

/****************************************************************************************************/

public void OnPluginStart()
{
    CreateConVar("l4d_gascan_invul_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled            = CreateConVar("l4d_gascan_invul_enable", "1", "是否启用插件.\n0 = 禁用, 1 = 启用", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Health             = CreateConVar("l4d_gascan_invul_health", "0", "设置油桶血量 否则为游戏默认\n0 = 关闭.\n游戏默认血量 = 20.", CVAR_FLAGS, true, 0.0);
    g_hCvar_Distance           = CreateConVar("l4d_gascan_invul_distance", "0.0", "油桶可攻击的最大距离.\n0 = 任何距离都可以点燃", CVAR_FLAGS, true, 0.0);
    g_hCvar_AnyDamage          = CreateConVar("l4d_gascan_invul_any_damage", "0", "油桶是否免疫任何伤害 (不管伤害类型为什么)\n0 = 关闭, 1 = 开启", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_GenericDamage      = CreateConVar("l4d_gascan_invul_generic_damage", "0", "是否使油桶免疫一般伤害 (DMG_GENERIC)\n0 = 关闭, 1 = 开启", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_ShoveDamage        = CreateConVar("l4d_gascan_invul_shove_damage", "1", "油桶是否免疫推的伤害 (DMG_CLUB and inflictor = valid client index)\n0 = 关闭, 1 = 开启", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_MeleeDamage        = CreateConVar("l4d_gascan_invul_melee_damage", "1", "油桶是否免疫近战伤害 (DMG_SLASH or DMG_CLUB)\n0 = 关闭, 1 = 开启", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_BulletDamage       = CreateConVar("l4d_gascan_invul_bullet_damage", "0", "油桶是否免疫子弹伤害 (DMG_BULLET)\n0 = 关闭, 1 = 开启", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_FireDamage         = CreateConVar("l4d_gascan_invul_fire_damage", "0", "油桶是否免疫火焰伤害 (DMG_BURN)\n0 = 关闭, 1 = 开启", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_BlastDamage        = CreateConVar("l4d_gascan_invul_blast_damage", "1", "油桶是否免疫爆炸伤害 (DMG_BLAST)\n0 = 关闭, 1 = 开启", CVAR_FLAGS, true, 0.0, true, 1.0);
    if (g_bL4D2)
    {
        g_hCvar_ChainsawDamage = CreateConVar("l4d_gascan_invul_chainsaw_damage", "1", "油桶是否免疫电锯伤害 (DMG_DISSOLVE)\n仅L4D2.\n0 = 关闭, 1 = 开启", CVAR_FLAGS, true, 0.0, true, 1.0);
        g_hCvar_SpitDamage     = CreateConVar("l4d_gascan_invul_spit_damage", "1", "油桶是否免疫酸液伤害 (DMG_ENERGYBEAM)\n仅L4D2收集类油桶有效\n0 = 关闭, 1 = 开启", CVAR_FLAGS, true, 0.0, true, 1.0);
        g_hCvar_ScavengeGascan = CreateConVar("l4d_gascan_invul_scavenge_only", "1", "是否只对收集类油桶有效 否则为游戏默认\n仅L4D2\n0 = 关闭, 1 = 开启", CVAR_FLAGS, true, 0.0, true, 1.0);
        g_hCvar_ScavengeHealth = CreateConVar("l4d_gascan_invul_scavenge_health", "0", "O收集类油桶血量\nL4D2 only.\n0 = 关闭.\n游戏默认血量 = 20", CVAR_FLAGS, true, 0.0);
    }

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Health.AddChangeHook(Event_ConVarChanged);
    g_hCvar_AnyDamage.AddChangeHook(Event_ConVarChanged);
    g_hCvar_GenericDamage.AddChangeHook(Event_ConVarChanged);
    g_hCvar_ShoveDamage.AddChangeHook(Event_ConVarChanged);
    g_hCvar_MeleeDamage.AddChangeHook(Event_ConVarChanged);
    g_hCvar_BulletDamage.AddChangeHook(Event_ConVarChanged);
    g_hCvar_FireDamage.AddChangeHook(Event_ConVarChanged);
    g_hCvar_BlastDamage.AddChangeHook(Event_ConVarChanged);
    if (g_bL4D2)
    {
        g_hCvar_ChainsawDamage.AddChangeHook(Event_ConVarChanged);
        g_hCvar_SpitDamage.AddChangeHook(Event_ConVarChanged);
        g_hCvar_ScavengeGascan.AddChangeHook(Event_ConVarChanged);
        g_hCvar_ScavengeHealth.AddChangeHook(Event_ConVarChanged);
    }

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d_gascan_invul", CmdPrintCvars, ADMFLAG_ROOT, "Print the plugin related cvars and their respective values to the console.");
}

/****************************************************************************************************/

public void OnMapStart()
{
    g_iModel_Gascan = PrecacheModel(MODEL_GASCAN, true);
}

/****************************************************************************************************/

public void OnConfigsExecuted()
{
    GetCvars();

    LateLoad();
}

/****************************************************************************************************/

void Event_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();
}

/****************************************************************************************************/

void GetCvars()
{
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
    g_iCvar_Health = g_hCvar_Health.IntValue;
    g_bCvar_Health = (g_iCvar_Health > 0);
    g_fCvar_Distance = g_hCvar_Distance.FloatValue;
    g_bCvar_Distance = (g_fCvar_Distance > 0.0);
    g_bCvar_AnyDamage = g_hCvar_AnyDamage.BoolValue;
    g_bCvar_GenericDamage = g_hCvar_GenericDamage.BoolValue;
    g_bCvar_ShoveDamage = g_hCvar_ShoveDamage.BoolValue;
    g_bCvar_MeleeDamage = g_hCvar_MeleeDamage.BoolValue;
    g_bCvar_BulletDamage = g_hCvar_BulletDamage.BoolValue;
    g_bCvar_FireDamage = g_hCvar_FireDamage.BoolValue;
    g_bCvar_BlastDamage = g_hCvar_BlastDamage.BoolValue;
    if (g_bL4D2)
    {
        g_bCvar_ChainsawDamage = g_hCvar_ChainsawDamage.BoolValue;
        g_bCvar_SpitDamage = g_hCvar_SpitDamage.BoolValue;
        g_bCvar_ScavengeGascan = g_hCvar_ScavengeGascan.BoolValue;
        g_iCvar_ScavengeHealth = g_hCvar_ScavengeHealth.IntValue;
        g_bCvar_ScavengeHealth = (g_iCvar_ScavengeHealth > 0);
    }
}

/****************************************************************************************************/

void LateLoad()
{
    int entity;

    if (g_bL4D2)
    {
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, "weapon_gascan")) != INVALID_ENT_REFERENCE)
        {
            RequestFrame(OnNextFrame, EntIndexToEntRef(entity));
        }
    }

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, "prop_physics*")) != INVALID_ENT_REFERENCE)
    {
        if (HasEntProp(entity, Prop_Send, "m_isCarryable")) // CPhysicsProp
            RequestFrame(OnNextFrame, EntIndexToEntRef(entity));
    }

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, "physics_prop")) != INVALID_ENT_REFERENCE)
    {
        RequestFrame(OnNextFrame, EntIndexToEntRef(entity));
    }
}

/****************************************************************************************************/

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity < 0)
        return;

    switch (classname[0])
    {
        case 'w':
        {
            if (!g_bL4D2)
                return;

            if (classname[1] != 'e') // weapon_*
                return;

            if (StrEqual(classname, "weapon_gascan"))
                RequestFrame(OnNextFrame, EntIndexToEntRef(entity));
        }
        case 'p':
        {
            if (HasEntProp(entity, Prop_Send, "m_isCarryable")) // CPhysicsProp
                RequestFrame(OnNextFrame, EntIndexToEntRef(entity));
        }
    }
}

/****************************************************************************************************/

void OnNextFrame(int entityRef)
{
    int entity = EntRefToEntIndex(entityRef);

    if (entity == INVALID_ENT_REFERENCE)
        return;

    int modelIndex = GetEntProp(entity, Prop_Send, "m_nModelIndex");

    if (modelIndex != g_iModel_Gascan)
        return;

    SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);

    if (!g_bCvar_Enabled)
        return;

    if (g_bL4D2 && IsScavengeGascan(entity))
    {
        if (!g_bCvar_ScavengeHealth)
            return;

        SetEntProp(entity, Prop_Data, "m_iHealth", g_iCvar_ScavengeHealth);
        SetEntProp(entity, Prop_Data, "m_iMaxHealth", g_iCvar_ScavengeHealth);
    }
    else
    {
        if (!g_bCvar_Health)
            return;

        SetEntProp(entity, Prop_Data, "m_iHealth", g_iCvar_Health);
        SetEntProp(entity, Prop_Data, "m_iMaxHealth", g_iCvar_ScavengeHealth);
    }
}

/****************************************************************************************************/

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
    if (!g_bCvar_Enabled)
        return Plugin_Continue;

    if (g_bCvar_ScavengeGascan && !IsScavengeGascan(victim))
        return Plugin_Continue;

    if (g_bCvar_Distance)
    {
        if (IsValidClient(inflictor))
        {
            float vPosVictim[3];
            GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", vPosVictim);

            float vPosInflictor[3];
            GetEntPropVector(inflictor, Prop_Data, "m_vecAbsOrigin", vPosInflictor);

            if (GetVectorDistance(vPosVictim, vPosInflictor) <= g_fCvar_Distance)
                return Plugin_Continue;
        }
    }

    if (g_bCvar_AnyDamage)
    {
        damagetype &= ~(DMG_BURN|DMG_ENERGYBEAM); // Prevent ignite and explode
        damage = 0.0;
        return Plugin_Changed;
    }

    if (g_bCvar_GenericDamage && (damagetype == DMG_GENERIC))
    {
        damage = 0.0;
        return Plugin_Changed;
    }

    int damagetypeOld = damagetype;

    if (IsValidClientIndex(inflictor))
    {
        if (g_bCvar_ShoveDamage && (damagetype & DMG_CLUB))
            damagetype &= ~DMG_CLUB;
    }
    else
    {
        if (g_bCvar_MeleeDamage && (damagetype & DMG_SLASH || damagetype & DMG_CLUB))
            damagetype &= ~(DMG_SLASH | DMG_CLUB);
    }

    if (g_bCvar_BulletDamage && (damagetype & DMG_BULLET))
        damagetype &= ~DMG_BULLET;

    if (g_bCvar_FireDamage && (damagetype & DMG_BURN))
        damagetype &= ~DMG_BURN;

    if (g_bCvar_BlastDamage && (damagetype & DMG_BLAST))
        damagetype &= ~DMG_BLAST;

    if (g_bL4D2)
    {
        if (g_bCvar_ChainsawDamage && (damagetype & DMG_DISSOLVE))
            damagetype &= ~DMG_DISSOLVE;

        if (g_bCvar_SpitDamage && (damagetype & DMG_ENERGYBEAM))
            damagetype &= ~DMG_ENERGYBEAM;
    }

    if (damagetype != damagetypeOld)
    {
        damagetype = damagetypeOld;
        damagetype &= ~(DMG_BURN|DMG_ENERGYBEAM); // Prevent ignite and explode
        damage = 0.0;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "------------------ Plugin Cvars (l4d_gascan_invul) -------------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d_gascan_invul_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d_gascan_invul_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d_gascan_invul_health : %i", g_iCvar_Health);
    PrintToConsole(client, "l4d_gascan_invul_distance : %.1f", g_fCvar_Distance);
    PrintToConsole(client, "l4d_gascan_invul_any_damage : %b (%s)", g_bCvar_AnyDamage, g_bCvar_AnyDamage ? "true" : "false");
    PrintToConsole(client, "l4d_gascan_invul_generic_damage : %b (%s)", g_bCvar_GenericDamage, g_bCvar_GenericDamage ? "true" : "false");
    PrintToConsole(client, "l4d_gascan_invul_shove_damage : %b (%s)", g_bCvar_ShoveDamage, g_bCvar_ShoveDamage ? "true" : "false");
    PrintToConsole(client, "l4d_gascan_invul_melee_damage : %b (%s)", g_bCvar_MeleeDamage, g_bCvar_MeleeDamage ? "true" : "false");
    PrintToConsole(client, "l4d_gascan_invul_bullet_damage : %b (%s)", g_bCvar_BulletDamage, g_bCvar_BulletDamage ? "true" : "false");
    PrintToConsole(client, "l4d_gascan_invul_fire_damage : %b (%s)", g_bCvar_FireDamage, g_bCvar_FireDamage ? "true" : "false");
    PrintToConsole(client, "l4d_gascan_invul_blast_damage : %b (%s)", g_bCvar_BlastDamage, g_bCvar_BlastDamage ? "true" : "false");
    if (g_bL4D2) PrintToConsole(client, "l4d_gascan_invul_chainsaw_damage : %b (%s)", g_bCvar_ChainsawDamage, g_bCvar_ChainsawDamage ? "true" : "false");
    if (g_bL4D2) PrintToConsole(client, "l4d_gascan_invul_spit_damage : %b (%s)", g_bCvar_SpitDamage, g_bCvar_SpitDamage ? "true" : "false");
    if (g_bL4D2) PrintToConsole(client, "l4d_gascan_invul_scavenge_only : %b (%s)", g_bCvar_ScavengeGascan, g_bCvar_ScavengeGascan ? "true" : "false");
    if (g_bL4D2) PrintToConsole(client, "l4d_gascan_invul_scavenge_health : %i", g_iCvar_ScavengeHealth);
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");

    return Plugin_Handled;
}

// ====================================================================================================
// Helpers
// ====================================================================================================
/**
 * Validates if is a valid client index.
 *
 * @param client        Client index.
 * @return              True if client index is valid, false otherwise.
 */
bool IsValidClientIndex(int client)
{
    return (1 <= client <= MaxClients);
}

/****************************************************************************************************/

/**
 * Validates if is a valid client.
 *
 * @param client        Client index.
 * @return              True if client index is valid and client is in game, false otherwise.
 */
bool IsValidClient(int client)
{
    return (IsValidClientIndex(client) && IsClientInGame(client));
}

/****************************************************************************************************/

/**
 * Returns if is a scavenge gascan based on its skin.
 * Works in L4D2 only.
 *
 * @param entity        Entity index.
 * @return              True if gascan skin is greater than 0 (default).
 */
bool IsScavengeGascan(int entity)
{
    int skin = GetEntProp(entity, Prop_Send, "m_nSkin");

    return skin > 0;
}