/**
// ====================================================================================================
Change Log:

1.1.0 (18-April-2021)
    - New version released.

1.0.0 (23-April-2019)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D1 & L4D2] Random Tank Rock"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Randomize the rock model thrown by the Tank"
#define PLUGIN_VERSION                "1.1.0"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=315775"

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
#define CONFIG_FILENAME               "l4d_random_tank_rock"

// ====================================================================================================
// Defines
// ====================================================================================================
#define MODEL_CONCRETE_CHUNK          "models/props_debris/concrete_chunk01a.mdl"
#define MODEL_TREE_TRUNK              "models/props_foliage/tree_trunk.mdl"

// ====================================================================================================
// Plugin Cvar
// ====================================================================================================
ConVar g_hCvar_Enabled;
ConVar g_hCvar_RockChance;
ConVar g_hCvar_TrunkChance;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bCvar_Enabled;

// ====================================================================================================
// int - Plugin Variables
// ====================================================================================================
int g_iCvar_RockChance;
int g_iCvar_TrunkChance;
int g_iRandomMax;

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

    return APLRes_Success;
}

/****************************************************************************************************/

public void OnPluginStart()
{
    CreateConVar("l4d_random_tank_rock_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled     = CreateConVar("l4d_random_tank_rock_enable", "1", "是否启用插件 \n0 = 禁用 1 = 启用", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_RockChance  = CreateConVar("l4d_random_tank_rock_rock_chance", "1", "随机为默认岩石模型的概率\nExample:\nrock_chance = \"1\" and trunk_chance = \"1\", 岩石概率 [50%] / 树干概率 [50%].\nrock_chance = \"2\" and trunk_chance = \"3\", 岩石概率 [40%] / 树干概率 [60%].\n0 = OFF.", CVAR_FLAGS, true, 0.0, true, 100.0);
    g_hCvar_TrunkChance = CreateConVar("l4d_random_tank_rock_trunk_chance", "1", "随机为树干模型的概率\nExample:\nrock_chance = \"1\" and trunk_chance = \"1\", 岩石概率 [50%] / 树干概率 [50%].\nrock_chance = \"2\" and trunk_chance = \"3\", 岩石概率 [40%] / 树干概率 [60%].\n0 = OFF.", CVAR_FLAGS, true, 0.0, true, 100.0);

    // Hook Plugin ConVars Change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_RockChance.AddChangeHook(Event_ConVarChanged);
    g_hCvar_TrunkChance.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d_random_tank_rock", CmdPrintCvars, ADMFLAG_ROOT, "Prints the plugin related cvars and their respective values to the console.");
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
    g_iCvar_RockChance = g_hCvar_RockChance.IntValue;
    g_iCvar_TrunkChance = g_hCvar_TrunkChance.IntValue;
    g_iRandomMax = g_iCvar_RockChance + g_iCvar_TrunkChance;

    if (g_iCvar_RockChance > 0)
        PrecacheModel(MODEL_CONCRETE_CHUNK, true);

    if (g_iCvar_TrunkChance > 0)
        PrecacheModel(MODEL_TREE_TRUNK, true);
}

/****************************************************************************************************/

void LateLoad()
{
    int entity;

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, "tank_rock")) != INVALID_ENT_REFERENCE)
    {
        SetTankRockModel(entity);
    }
}

/****************************************************************************************************/

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity < 0)
        return;

    if (StrEqual(classname, "tank_rock"))
        SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
}

/****************************************************************************************************/

void OnSpawnPost(int entity)
{
    SetTankRockModel(entity);
}

/****************************************************************************************************/

void SetTankRockModel(int entity)
{
    if (!g_bCvar_Enabled)
        return;

    if (g_iRandomMax == 0)
        return;

    int random = GetRandomInt(1, g_iRandomMax);

    if (random <= g_iCvar_RockChance)
        SetEntityModel(entity, MODEL_CONCRETE_CHUNK);
    else
        SetEntityModel(entity, MODEL_TREE_TRUNK);
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "----------------- Plugin Cvars (l4d_random_tank_rock) ----------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "插件版本 : %s", PLUGIN_VERSION);
    PrintToConsole(client, "插件已%b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "启用" : "禁用");
    PrintToConsole(client, "默认岩石概率 : %i (%.1f%%)", g_iCvar_RockChance, g_iRandomMax == 0 ? 0.0 : (g_iCvar_RockChance / float(g_iRandomMax)) * 100.0);
    PrintToConsole(client, "特殊树干概率 : %i (%.1f%%)", g_iCvar_TrunkChance, g_iRandomMax == 0 ? 0.0 : (g_iCvar_TrunkChance / float(g_iRandomMax)) * 100.0);
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");

    return Plugin_Handled;
}