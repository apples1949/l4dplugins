/**
// ====================================================================================================
Change Log:

1.0.1 (31-January-2021)
    - Fixed spawnflag check. (thanks to "Krufftys Killers")

1.0.0 (30-January-2021)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D2] Multiple Gascan and Cola Fill"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Allow multiple gascans and colas to be filled at the same time"
#define PLUGIN_VERSION                "1.0.1"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=330351"

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
#define CONFIG_FILENAME               "l4d2_multiple_gascan_fill"

// ====================================================================================================
// Defines
// ====================================================================================================
#define FLAG_USABLE_BY_GASCAN         (1 << 0) // 1 | 01
#define FLAG_USABLE_BY_COLA           (1 << 1) // 2 | 10

#define MAXENTITIES                   2048

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;
ConVar g_hCvar_Type;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bCvar_Enabled;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
int g_iCvar_Type;

// ====================================================================================================
// entity - Plugin Variables
// ====================================================================================================
bool ge_bOnUseStartedHooked[MAXENTITIES+1];

// ====================================================================================================
// Plugin Start
// ====================================================================================================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion engine = GetEngineVersion();

    if (engine != Engine_Left4Dead && engine != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "This plugin only runs in \"Left 4 Dead 2\" game");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

/****************************************************************************************************/

public void OnPluginStart()
{
    CreateConVar("l4d2_multiple_gascan_fill_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled = CreateConVar("l4d2_multiple_gascan_fill_enable", "1", "是否启用插件.\n0 = 禁用, 1 = 启用", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Type    = CreateConVar("l4d2_multiple_gascan_fill_type", "3", "插件对那些有影响.\n0 = 无, 1 = 油桶, 2 = 可乐，3 = 两个都可以 ", CVAR_FLAGS, true, 0.0, true, 3.0);

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Type.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d2_multiple_gascan_fill", CmdPrintCvars, ADMFLAG_ROOT, "Print the plugin related cvars and their respective values to the console.");
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
    g_iCvar_Type = g_hCvar_Type.IntValue;
}

/****************************************************************************************************/

void LateLoad()
{
    int entity;

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, "point_prop_use_target")) != INVALID_ENT_REFERENCE)
    {
        HookEntity(entity);
    }
}

/****************************************************************************************************/

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity < 0)
        return;

    if (StrEqual(classname, "point_prop_use_target"))
        HookEntity(entity);
}

/****************************************************************************************************/

public void OnEntityDestroyed(int entity)
{
    if (entity < 0)
        return;

    ge_bOnUseStartedHooked[entity] = false;
}

/****************************************************************************************************/

void HookEntity(int entity)
{
    if (ge_bOnUseStartedHooked[entity])
        return;

    ge_bOnUseStartedHooked[entity] = true;
    HookSingleEntityOutput(entity, "OnUseStarted", OnUseStarted);
}

/****************************************************************************************************/

void OnUseStarted(const char[] output, int caller, int activator, float delay)
{
    if (!g_bCvar_Enabled)
        return;

    if (GetEntProp(caller, Prop_Data, "m_spawnflags") & g_iCvar_Type)
        SetEntPropEnt(caller, Prop_Send, "m_useActionOwner", -1);
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "-------------- Plugin Cvars (l4d2_multiple_gascan_fill) --------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d2_multiple_gascan_fill_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d2_multiple_gascan_fill_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d2_multiple_gascan_fill_type : %i (GASCAN = %s | COLA = %s)", g_iCvar_Type, g_iCvar_Type & FLAG_USABLE_BY_GASCAN ? "true" : "false", g_iCvar_Type & FLAG_USABLE_BY_COLA ? "true" : "false");
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");

    return Plugin_Handled;
}