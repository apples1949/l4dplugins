/**
// ====================================================================================================
Change Log:

1.0.3 (17-March-2022)
    - Fixed plugin not removing invisible walls on Last Stand map. (thanks "VYRNACH_GAMING" for reporting)

1.0.2 (13-March-2022)
    - Fixed plugin not removing invisible walls on Crash Course map. (thanks "VYRNACH_GAMING" for reporting)
    - Fixed blacklist map logic not blocking changes for some events.
    - Added support for the upcoming update that will change the "anv_mapfixes" prefix to "community_update".

1.0.1 (01-July-2021)
    - Now requires left4dhooks.
    - Fixed a bug where SI couldn't spawn before finale starts on vs (2nd team). (thanks "noto3" for reporting)
    - Removed TLS rocks blocking the way on Death Tool finale. (thanks "Maur0" for reporting).
    - Added cvar to only apply on vanilla (not custom) maps. (thanks "SDArt" for requesting)

1.0.0 (28-June-2021)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D2] Unlock Finales"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Allow to start finale events with survivors everywhere"
#define PLUGIN_VERSION                "1.0.3"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=333274"

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
#tryinclude <left4dhooks> // Download here: https://forums.alliedmods.net/showthread.php?t=321696

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
#define CONFIG_FILENAME               "l4d2_unlock_finales"

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;
ConVar g_hCvar_BlacklistMaps;
ConVar g_hCvar_VanillaOnly;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bLeft4DHooks;
bool g_bEventsHooked;
bool g_bIsBlacklistMap;
bool g_bIsVanillaFinaleMap;
bool g_bC10M5;
bool g_bCvar_Enabled;
bool g_bCvar_VanillaOnly;

// ====================================================================================================
// string - Plugin Variables
// ====================================================================================================
char g_sMapName[64];
char g_sCvar_BlacklistMaps[512];

/****************************************************************************************************/

char strScriptUnlockBuffer[256];
char strScriptUnlock[][] =
{
    "NAV_FINALE <- 64",
    "",
    "local table = {};",
    "NavMesh.GetAllAreas(table);",
    "",
    "foreach (area in table) {",
    "    if (!area.HasSpawnAttributes(NAV_FINALE)) {",
    "        area.SetSpawnAttributes(NAV_FINALE);",
    "    }",
    "}"
};

char strScriptResetBuffer[256];
char strScriptReset[][] =
{
    "NAV_FINALE <- 64",
    "NAV_CHECKPOINT <- 2048",
    "",
    "local table = {};",
    "NavMesh.GetAllAreas(table);",
    "",
    "foreach (area in table) {",
    "if (area.HasSpawnAttributes(NAV_CHECKPOINT)) {",
    "    area.RemoveSpawnAttributes(NAV_FINALE);",
    "    }",
    "}"
};

// ====================================================================================================
// left4dhooks - Plugin Dependencies
// ====================================================================================================
#if !defined _l4dh_included
native bool L4D_IsMissionFinalMap();
#endif

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

    ImplodeStrings(strScriptUnlock, sizeof(strScriptUnlock), "\n", strScriptUnlockBuffer, sizeof(strScriptUnlockBuffer));
    ImplodeStrings(strScriptReset, sizeof(strScriptReset), "\n", strScriptResetBuffer, sizeof(strScriptResetBuffer));

    #if !defined _l4dh_included
    MarkNativeAsOptional("L4D_IsMissionFinalMap");
    #endif

    return APLRes_Success;
}

/****************************************************************************************************/

public void OnAllPluginsLoaded()
{
    g_bLeft4DHooks = (GetFeatureStatus(FeatureType_Native, "L4D_IsMissionFinalMap") == FeatureStatus_Available);
}

/****************************************************************************************************/

public void OnPluginStart()
{
    CreateConVar("l4d2_unlock_finales_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled       = CreateConVar("l4d2_unlock_finales_enable", "1", "Enable/Disable the plugin.\n0 = Disable, 1 = Enable.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_VanillaOnly   = CreateConVar("l4d2_unlock_finales_vanilla_only", "0", "Enable/Disable the plugin only on vanilla (not custom) maps.\n0 = Disable, 1 = Enable.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_BlacklistMaps = CreateConVar("l4d2_unlock_finales_blacklist_maps", "", "Prevent unlocking additional finale navs on these maps.\nSeparate by commas (no spaces).\nEmpty = none.", CVAR_FLAGS);

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_VanillaOnly.AddChangeHook(Event_ConVarChanged);
    g_hCvar_BlacklistMaps.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d2_unlock_finales", CmdPrintCvars, ADMFLAG_ROOT, "Print the plugin related cvars and their respective values to the console.");
}

/****************************************************************************************************/

public void OnMapStart()
{
    GetCurrentMap(g_sMapName, sizeof(g_sMapName));
    Format(g_sMapName, sizeof(g_sMapName), ",%s,", g_sMapName);
    StringToLowerCase(g_sMapName);

    g_bIsVanillaFinaleMap = IsVanillaFinale();
    g_bC10M5 = (StrEqual(g_sMapName, ",c10m5_houseboat,"));
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

    HookEvents();
}

/****************************************************************************************************/

void GetCvars()
{
    g_bCvar_Enabled = g_hCvar_Enabled.BoolValue;
    g_bCvar_VanillaOnly = g_hCvar_VanillaOnly.BoolValue;
    g_hCvar_BlacklistMaps.GetString(g_sCvar_BlacklistMaps, sizeof(g_sCvar_BlacklistMaps));
    Format(g_sCvar_BlacklistMaps, sizeof(g_sCvar_BlacklistMaps), ",%s,", g_sCvar_BlacklistMaps);
    ReplaceString(g_sCvar_BlacklistMaps, sizeof(g_sCvar_BlacklistMaps), " ", "");
    ReplaceString(g_sCvar_BlacklistMaps, sizeof(g_sCvar_BlacklistMaps), ",,", "");
    StringToLowerCase(g_sCvar_BlacklistMaps);

    g_bIsBlacklistMap = (StrContains(g_sCvar_BlacklistMaps, g_sMapName, false) != -1);
}

/****************************************************************************************************/

void LateLoad()
{
    if (!g_bCvar_Enabled)
        return;

    if (g_bIsBlacklistMap)
        return;

    if (!HasAnySurvivorLeftSafeArea())
        return;

    if (!g_bIsVanillaFinaleMap)
    {
        if (g_bCvar_VanillaOnly)
            return;

        if (!g_bLeft4DHooks)
            return;

        if (!L4D_IsMissionFinalMap())
            return;
    }

    UnlockFinaleNav();

    DoMapSpecificConfigs();
}

/****************************************************************************************************/

public void OnEntityCreated(int entity, const char[] classname)
{
    if (!g_bC10M5)
        return;

    if (!g_bCvar_Enabled)
        return;

    if (g_bIsBlacklistMap)
        return;

    if (entity < 0)
        return;

    SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
}

/****************************************************************************************************/

void OnSpawnPost(int entity)
{
    char targetname[23];
    GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
    StringToLowerCase(targetname);

    if (targetname[0] == 0)
        return;

    if (StrContains(targetname, "anv_mapfixes_rockslide") != -1 || StrContains(targetname, "community_update_rockslide") != -1)
        AcceptEntityInput(entity, "Kill");
}

/****************************************************************************************************/

void HookEvents()
{
    if (g_bCvar_Enabled && !g_bEventsHooked)
    {
        g_bEventsHooked = true;

        HookEvent("player_left_safe_area", Event_PlayerLeftSafeArea);
        HookEvent("round_end", Event_RoundEnd);

        HookEntityOutput("trigger_finale", "UseStart", OnUseStart);
        HookEntityOutput("trigger_finale", "FinaleStart", OnFinaleStart);

        return;
    }

    if (!g_bCvar_Enabled && g_bEventsHooked)
    {
        g_bEventsHooked = false;

        UnhookEvent("player_left_safe_area", Event_PlayerLeftSafeArea);
        UnhookEvent("round_end", Event_RoundEnd);

        UnhookEntityOutput("trigger_finale", "UseStart", OnUseStart);
        UnhookEntityOutput("trigger_finale", "FinaleStart", OnFinaleStart);

        return;
    }
}

/****************************************************************************************************/

void Event_PlayerLeftSafeArea(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bIsBlacklistMap)
        return;

    if (!g_bIsVanillaFinaleMap)
    {
        if (g_bCvar_VanillaOnly)
            return;

        if (!g_bLeft4DHooks)
            return;

        if (!L4D_IsMissionFinalMap())
            return;
    }

    UnlockFinaleNav();

    DoMapSpecificConfigs();
}

/****************************************************************************************************/

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bIsBlacklistMap)
        return;

    if (g_bIsVanillaFinaleMap)
    {
        ResetFinaleNav();
    }
    else
    {
        if (g_bCvar_VanillaOnly)
            return;

        if (!g_bLeft4DHooks)
            return;

        if (!L4D_IsMissionFinalMap())
            return;

        ResetFinaleNav();
    }
}

/****************************************************************************************************/

void OnUseStart(const char[] output, int caller, int activator, float delay)
{
    if (g_bIsBlacklistMap)
        return;

    int entity;
    char targetname[64];

    if (StrEqual(g_sMapName, ",c3m4_plantation,"))
    {
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, "env_physics_blocker")) != INVALID_ENT_REFERENCE)
        {
            GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
            StringToLowerCase(targetname);

            if (StrEqual(targetname, "anv_mapfixes_point_of_no_return") || StrEqual(targetname, "community_update_point_of_no_return"))
                AcceptEntityInput(entity, "Kill");
        }
    }
    else if (StrEqual(g_sMapName, ",c4m5_milltown_escape,"))
    {
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, "env_physics_blocker")) != INVALID_ENT_REFERENCE)
        {
            GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
            StringToLowerCase(targetname);

            if (StrEqual(targetname, "anv_mapfixes_point_of_no_return") || StrEqual(targetname, "community_update_point_of_no_return"))
                AcceptEntityInput(entity, "Kill");
        }
    }
    else if (StrEqual(g_sMapName, ",c9m2_lots,"))
    {
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, "env_physics_blocker")) != INVALID_ENT_REFERENCE)
        {
            GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
            StringToLowerCase(targetname);

            if (StrEqual(targetname, "anv_mapfixes_point_of_no_return") || StrEqual(targetname, "community_update_point_of_no_return"))
                AcceptEntityInput(entity, "Kill");
        }
    }
    else if (StrEqual(g_sMapName, ",c12m5_cornfield,"))
    {
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, "env_physics_blocker")) != INVALID_ENT_REFERENCE)
        {
            GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
            StringToLowerCase(targetname);

            if (StrEqual(targetname, "anv_mapfixes_point_of_no_return") || StrEqual(targetname, "community_update_point_of_no_return"))
                AcceptEntityInput(entity, "Kill");
        }
    }
}

/****************************************************************************************************/

void OnFinaleStart(const char[] output, int caller, int activator, float delay)
{
    if (g_bIsBlacklistMap)
        return;

    int entity;
    char targetname[64];

    if (StrEqual(g_sMapName, ",c9m2_lots,"))
    {
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, "env_physics_blocker")) != INVALID_ENT_REFERENCE)
        {
            GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
            StringToLowerCase(targetname);

            if (StrEqual(targetname, "anv_mapfixes_point_of_no_return") || StrEqual(targetname, "community_update_point_of_no_return"))
                AcceptEntityInput(entity, "Kill");
        }
    }
}

/****************************************************************************************************/

void UnlockFinaleNav()
{
    int entity = CreateEntityByName("logic_script");
    DispatchSpawn(entity);

    SetVariantString(strScriptUnlockBuffer);
    AcceptEntityInput(entity, "RunScriptCode");
    AcceptEntityInput(entity, "Kill");
}

/****************************************************************************************************/

void ResetFinaleNav()
{
    int entity = CreateEntityByName("logic_script");
    DispatchSpawn(entity);

    SetVariantString(strScriptResetBuffer);
    AcceptEntityInput(entity, "RunScriptCode");
    AcceptEntityInput(entity, "Kill");
}

/****************************************************************************************************/

void DoMapSpecificConfigs()
{
    if (!g_bCvar_Enabled)
        return;

    int entity;
    char targetname[64];

    if (StrEqual(g_sMapName, ",c2m5_concert,"))
    {
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, "logic_relay")) != INVALID_ENT_REFERENCE)
        {
            GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
            StringToLowerCase(targetname);

            if (StrEqual(targetname, "stadium_entrance_door_relay"))
                AcceptEntityInput(entity, "Kill");
        }
    }
    else if (StrEqual(g_sMapName, ",c7m3_port,"))
    {
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, "point_template")) != INVALID_ENT_REFERENCE)
        {
            GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
            StringToLowerCase(targetname);

            if (StrEqual(targetname, "door_spawner"))
            {
                AcceptEntityInput(entity, "Kill");
                break;
            }
        }

        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, "func_button_timed")) != INVALID_ENT_REFERENCE)
        {
            GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
            StringToLowerCase(targetname);

            if (StrContains(targetname, "finale_start_button") != -1)
                AcceptEntityInput(entity, "Unlock");
        }
    }
    else if (StrEqual(g_sMapName, ",c8m5_rooftop,"))
    {
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, "point_template")) != INVALID_ENT_REFERENCE)
        {
            GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
            StringToLowerCase(targetname);

            if (StrEqual(targetname, "rooftop_playerclip_template"))
            {
                AcceptEntityInput(entity, "Kill");
                break;
            }
        }

        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, "func_button")) != INVALID_ENT_REFERENCE)
        {
            GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
            StringToLowerCase(targetname);

            if (StrEqual(targetname, "radio_button"))
            {
                AcceptEntityInput(entity, "Unlock");
                break;
            }
        }
    }
    else if (StrEqual(g_sMapName, ",c9m2_lots,"))
    {
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, "func_button_timed")) != INVALID_ENT_REFERENCE)
        {
            GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
            StringToLowerCase(targetname);

            if (StrEqual(targetname, "finaleswitch_initial"))
            {
                AcceptEntityInput(entity, "Unlock");
                break;
            }
        }
    }
    else if (StrEqual(g_sMapName, ",c14m2_lighthouse,"))
    {
        entity = INVALID_ENT_REFERENCE;
        while ((entity = FindEntityByClassname(entity, "func_brush")) != INVALID_ENT_REFERENCE)
        {
            GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
            StringToLowerCase(targetname);

            if (StrEqual(targetname, "lookout_clip"))
            {
                AcceptEntityInput(entity, "Kill");
                break;
            }
        }
    }
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "--------------- Plugin Cvars (l4d2_unlock_finales) ---------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d2_unlock_finales_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d2_unlock_finales_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d2_unlock_finales_vanilla_only : %b (%s)", g_bCvar_VanillaOnly, g_bCvar_VanillaOnly ? "true" : "false");
    PrintToConsole(client, "l4d2_unlock_finales_blacklist_maps : \"%s\"", g_sCvar_BlacklistMaps);
    PrintToConsole(client, "");
    PrintToConsole(client, "---------------------------- Other Infos  ----------------------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "left4dhooks : %s", g_bLeft4DHooks ? "true" : "false");
    PrintToConsole(client, "Map : \"%s\"", g_sMapName);
    PrintToConsole(client, "Vanilla Finale Map? : %b (%s)", g_bIsVanillaFinaleMap, g_bIsVanillaFinaleMap ? "true" : "false");
    PrintToConsole(client, "Blacklist Map? : %b (%s)", g_bIsBlacklistMap, g_bIsBlacklistMap ? "true" : "false");
    PrintToConsole(client, "Final Map? : \"%s\"", !g_bLeft4DHooks ? "unknown" : L4D_IsMissionFinalMap() ? "true" : "false");
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");

    return Plugin_Handled;
}

// ====================================================================================================
// Helpers
// ====================================================================================================
/**
 * Converts the string to lower case.
 *
 * @param input         Input string.
 */
void StringToLowerCase(char[] input)
{
    for (int i = 0; i < strlen(input); i++)
    {
        input[i] = CharToLower(input[i]);
    }
}

/****************************************************************************************************/

/**
 * Returns whether any survivor have left the safe area.
 *
 * @return              True if any survivor have left safe area, false otherwise.
 */
int g_iEntTerrorPlayerManager = INVALID_ENT_REFERENCE;
bool HasAnySurvivorLeftSafeArea()
{
    int entity = EntRefToEntIndex(g_iEntTerrorPlayerManager);

    if (entity == INVALID_ENT_REFERENCE)
        entity = FindEntityByClassname(-1, "terror_player_manager");

    if (entity == INVALID_ENT_REFERENCE)
    {
        g_iEntTerrorPlayerManager = INVALID_ENT_REFERENCE;
        return false;
    }

    g_iEntTerrorPlayerManager = EntIndexToEntRef(entity);

    return (GetEntProp(entity, Prop_Send, "m_hasAnySurvivorLeftSafeArea") == 1);
}

/****************************************************************************************************/

/**
 * Returns if the current map is a vanilla finale campaign
 *
 * @return              True if the current map is a vanilla finale campaign, false otherwise.
 */
bool IsVanillaFinale()
{
    if (StrEqual(g_sMapName, ",c1m4_atrium,"))
        return true;
    if (StrEqual(g_sMapName, ",c2m5_concert,"))
        return true;
    if (StrEqual(g_sMapName, ",c3m4_plantation,"))
        return true;
    if (StrEqual(g_sMapName, ",c4m5_milltown_escape,"))
        return true;
    if (StrEqual(g_sMapName, ",c6m3_port,"))
        return true;
    if (StrEqual(g_sMapName, ",c7m3_port,"))
        return true;
    if (StrEqual(g_sMapName, ",c8m5_rooftop,"))
        return true;
    if (StrEqual(g_sMapName, ",c9m2_lots,"))
        return true;
    if (StrEqual(g_sMapName, ",c10m5_houseboat,"))
        return true;
    if (StrEqual(g_sMapName, ",c11m5_runway,"))
        return true;
    if (StrEqual(g_sMapName, ",c12m5_cornfield,"))
        return true;
    if (StrEqual(g_sMapName, ",c13m4_cutthroatcreek,"))
        return true;
    if (StrEqual(g_sMapName, ",c14m2_lighthouse,"))
        return true;
    if (StrEqual(g_sMapName, ",tutorial_standards,"))
        return true;
    if (StrEqual(g_sMapName, ",tutorial_standards_vs,"))
        return true;

    return false;
}