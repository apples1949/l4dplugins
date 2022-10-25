/**
// ====================================================================================================
Change Log:

1.0.1 (08-March-2021)
    - Fixed gascans being blocked to throw with M1 anywhere. (thanks "PEK727" for reporting)
    - Now gascans actions and pour sounds are only blocked near the gas nozzle.

1.0.0 (08-March-2021)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D2] Block Pour Gascan"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Block clients from pouring with normal gascans"
#define PLUGIN_VERSION                "1.0.1"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=331139"

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
#define CONFIG_FILENAME               "l4d2_block_pour_gascan"

// ====================================================================================================
// Defines
// ====================================================================================================
#define MODEL_GASCAN                  "models/props_junk/gascan001a.mdl"

#define SOUND_GASCAN_FILL_POUR        "player/items/gas_can_fill_pour_01.wav"
#define SOUND_GASCAN_FILL_INTERRUPT   "player/items/gas_can_fill_interrupt_01.wav"

// ====================================================================================================
// Native Cvars
// ====================================================================================================
ConVar g_hCvar_gascan_use_range;

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bEventsHooked;
bool g_bCvar_Enabled;

// ====================================================================================================
// int - Plugin Variables
// ====================================================================================================
int g_iModel_Gascan = -1;

// ====================================================================================================
// float - Plugin Variables
// ====================================================================================================
float g_fCvar_gascan_use_range;

// ====================================================================================================
// client - Plugin Variables
// ====================================================================================================
bool gc_bWeaponSwitchPostHooked[MAXPLAYERS+1];
bool gc_bBlockFillSound[MAXPLAYERS+1];
int gc_iWeaponGascanEntRef[MAXPLAYERS+1] = { INVALID_ENT_REFERENCE, ... };

// ====================================================================================================
// Plugin Start
// ====================================================================================================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion engine = GetEngineVersion();

    if (engine != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "This plugin only runs in \"Left 4 Dead 2\" game");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

/****************************************************************************************************/

public void OnPluginStart()
{
    g_hCvar_gascan_use_range = FindConVar("gascan_use_range");

    CreateConVar("l4d2_block_pour_gascan_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled = CreateConVar("l4d2_block_pour_gascan_enable", "1", "Enable/Disable the plugin.\n0 = Disable, 1 = Enable.", CVAR_FLAGS, true, 0.0, true, 1.0);

    // Hook plugin ConVars change
    g_hCvar_gascan_use_range.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d2_block_pour_gascan", CmdPrintCvars, ADMFLAG_ROOT, "Print the plugin related cvars and their respective values to the console.");
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

    HookEvents();
}

/****************************************************************************************************/

void Event_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    GetCvars();

    LateLoad();

    HookEvents();
}

/****************************************************************************************************/

void GetCvars()
{
    g_fCvar_gascan_use_range = g_hCvar_gascan_use_range.FloatValue;
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
}

/****************************************************************************************************/

void LateLoad()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
            continue;

        OnClientPutInServer(client);
    }
}

/****************************************************************************************************/

public void OnClientPutInServer(int client)
{
    if (IsFakeClient(client))
        return;

    if (gc_bWeaponSwitchPostHooked[client])
        return;

    gc_bWeaponSwitchPostHooked[client] = true;
    SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);

    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    OnWeaponSwitchPost(client, weapon);
}

/****************************************************************************************************/

public void OnClientDisconnect(int client)
{
    gc_bWeaponSwitchPostHooked[client] = false;
    gc_bBlockFillSound[client] = false;
    gc_iWeaponGascanEntRef[client] = INVALID_ENT_REFERENCE;
}

/****************************************************************************************************/

void OnWeaponSwitchPost(int client, int weapon)
{
    if (!g_bCvar_Enabled)
        return;

    if (!IsValidEntity(weapon))
        return;

    if (gc_iWeaponGascanEntRef[client] != INVALID_ENT_REFERENCE)
    {
        int entity = EntRefToEntIndex(gc_iWeaponGascanEntRef[client]);

        if (entity != INVALID_ENT_REFERENCE)
            SetEntProp(entity, Prop_Send, "m_bPerformingAction", 0);

        gc_iWeaponGascanEntRef[client] = INVALID_ENT_REFERENCE;
    }

    int modelIndex = GetEntProp(weapon, Prop_Send, "m_nModelIndex");

    if (modelIndex != g_iModel_Gascan)
        return;

    if (IsScavengeGascan(weapon))
        return;

    gc_iWeaponGascanEntRef[client] = EntIndexToEntRef(weapon);
}

/****************************************************************************************************/

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
    if (!IsValidClientIndex(client))
        return;

    gc_bBlockFillSound[client] = false;

    if (!g_bCvar_Enabled)
        return;

    if (gc_iWeaponGascanEntRef[client] == INVALID_ENT_REFERENCE)
        return;

    int entity = EntRefToEntIndex(gc_iWeaponGascanEntRef[client]);

    if (entity == INVALID_ENT_REFERENCE)
    {
        gc_iWeaponGascanEntRef[client] = INVALID_ENT_REFERENCE;
        return;
    }

    bool validDistance = true;

    float vPosClient[3];
    float vPosTarget[3];
    float distance;

    int target = INVALID_ENT_REFERENCE;
    while ((target = FindEntityByClassname(target, "point_prop_use_target")) != INVALID_ENT_REFERENCE)
    {
        GetClientEyePosition(client, vPosClient);
        GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", vPosTarget);
        distance = GetVectorDistance(vPosClient, vPosTarget);

        if (distance <= g_fCvar_gascan_use_range)
        {
            validDistance = false;
            break;
        }
    }

    if (validDistance)
        return;

    gc_bBlockFillSound[client] = true;
    SetEntProp(entity, Prop_Send, "m_bPerformingAction", 1);
}

/****************************************************************************************************/

void HookEvents()
{
    if (g_bCvar_Enabled && !g_bEventsHooked)
    {
        g_bEventsHooked = true;

        HookEvent("gascan_pour_blocked", Event_GascanPourBlocked, EventHookMode_Pre);
        AddNormalSoundHook(SoundHook);

        return;
    }

    if (!g_bCvar_Enabled && g_bEventsHooked)
    {
        g_bEventsHooked = false;

        UnhookEvent("gascan_pour_blocked", Event_GascanPourBlocked, EventHookMode_Pre);
        RemoveNormalSoundHook(SoundHook);

        return;
    }
}

/****************************************************************************************************/

Action Event_GascanPourBlocked(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (client == 0)
        return Plugin_Continue;

    if (gc_bBlockFillSound[client])
        return Plugin_Handled;

    return Plugin_Continue;
}

/****************************************************************************************************/

Action SoundHook(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if (channel != SNDCHAN_STATIC)
        return Plugin_Continue;

    if (!IsValidClientIndex(entity))
        return Plugin_Continue;

    if (!gc_bBlockFillSound[entity])
        return Plugin_Continue;

    if (sample[0] != 'p')
        return Plugin_Continue;

    if (StrEqual(sample, SOUND_GASCAN_FILL_POUR))
        return Plugin_Stop;

    if (StrEqual(sample, SOUND_GASCAN_FILL_INTERRUPT))
        return Plugin_Stop;

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
    PrintToConsole(client, "--------------- Plugin Cvars (l4d2_block_pour_gascan) ----------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d2_block_pour_gascan_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d2_block_pour_gascan_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "");
    PrintToConsole(client, "---------------------------- Game Cvars  -----------------------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "gascan_use_range : %.1f", g_fCvar_gascan_use_range);
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