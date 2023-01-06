/**
// ====================================================================================================
Change Log:

1.1.1 (18-December-2021)
    - Added cvar to control which attacker team should trigger the message.

1.1.0 (28-January-2021)
    - New version released.

1.0.0 (26-April-2019)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D1 & L4D2] Tank Rock Destroyer Announce"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Announces which player destroyed the rock thrown by the Tank"
#define PLUGIN_VERSION                "1.1.1"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=315818"

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
#define CONFIG_FILENAME              "l4d_tank_rock_destroyer_announce"
#define TRANSLATION_FILENAME         "l4d_tank_rock_destroyer_announce.phrases"

// ====================================================================================================
// Defines
// ====================================================================================================
#define MODEL_CONCRETE_CHUNK          "models/props_debris/concrete_chunk01a.mdl"
#define MODEL_TREE_TRUNK              "models/props_foliage/tree_trunk.mdl"

#define TEAM_SPECTATOR                1
#define TEAM_SURVIVOR                 2
#define TEAM_INFECTED                 3
#define TEAM_HOLDOUT                  4

#define FLAG_TEAM_NONE                (0 << 0) // 0 | 0000
#define FLAG_TEAM_SURVIVOR            (1 << 0) // 1 | 0001
#define FLAG_TEAM_INFECTED            (1 << 1) // 2 | 0010
#define FLAG_TEAM_SPECTATOR           (1 << 2) // 4 | 0100
#define FLAG_TEAM_HOLDOUT             (1 << 3) // 8 | 1000

#define TYPE_UNKNOWN                  (0 << 0) // 0 | 000
#define TYPE_CONCRETE_CHUNK           (1 << 0) // 1 | 001
#define TYPE_TREE_TRUNK               (1 << 1) // 2 | 010

#define MAXENTITIES                   2048

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;
ConVar g_hCvar_Team;
ConVar g_hCvar_TeamAttacker;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bCvar_Enabled;

// ====================================================================================================
// int - Plugin Variables
// ====================================================================================================
int g_iModel_Rock = -1;
int g_iModel_Trunk = -1;
int g_iCvar_Team;
int g_iCvar_TeamAttacker;

// ====================================================================================================
// entity - Plugin Variables
// ====================================================================================================
bool ge_bOnTakeDamageAlivePostHooked[MAXENTITIES+1];

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
    LoadPluginTranslations();

    CreateConVar("l4d_tank_rock_destroyer_announce", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled      = CreateConVar("l4d_tank_rock_destroyer_announce_enable", "1", "是否启用插件.\n0 = 禁用, 1 = 启用.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Team         = CreateConVar("l4d_tank_rock_destroyer_announce_team", "15", "消息应该传送给哪些队伍.\n0 = 无, 1 = 生还者, 2 = 感染者, 4 = 旁观, 8 = HOLDOUT（抵抗者？）.\n如果有多个选项，则添加大于0的数字.例如: 3表示生还者和感染者", CVAR_FLAGS, true, 0.0, true, 15.0);
    g_hCvar_TeamAttacker = CreateConVar("l4d_tank_rock_destroyer_announce_team_attacker", "1", "哪些队伍应该触发该消息.\n0 = 无, 1 = 生还者, 2 = 感染者, 4 = 旁观, 8 = HOLDOUT（抵抗者？）.\n如果有多个选项，则添加大于0的数字.例如: 3表示生还者和感染者", CVAR_FLAGS, true, 0.0, true, 15.0);

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Team.AddChangeHook(Event_ConVarChanged);
    g_hCvar_TeamAttacker.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d_tank_rock_destroyer_announce", CmdPrintCvars, ADMFLAG_ROOT, "Prints the plugin related cvars and their respective values to the console.");
}

/****************************************************************************************************/

public void OnMapStart()
{
    g_iModel_Rock = PrecacheModel(MODEL_CONCRETE_CHUNK, true);
    g_iModel_Trunk = PrecacheModel(MODEL_TREE_TRUNK, true);
}

/****************************************************************************************************/

void LoadPluginTranslations()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "translations/%s.txt", TRANSLATION_FILENAME);
    if (FileExists(path))
        LoadTranslations(TRANSLATION_FILENAME);
    else
        SetFailState("Missing required translation file on \"translations/%s.txt\", please re-download.", TRANSLATION_FILENAME);
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
    g_iCvar_Team = g_hCvar_Team.IntValue;
    g_iCvar_TeamAttacker = g_hCvar_TeamAttacker.IntValue;
}

/****************************************************************************************************/

void LateLoad()
{
    int entity;

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, "tank_rock")) != INVALID_ENT_REFERENCE)
    {
        HookEntity(entity);
    }
}

/****************************************************************************************************/

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity < 0)
        return;

    if (StrEqual(classname, "tank_rock"))
        HookEntity(entity);
}

/****************************************************************************************************/

public void OnEntityDestroyed(int entity)
{
    if (entity < 0)
        return;

    ge_bOnTakeDamageAlivePostHooked[entity] = false;
}

/****************************************************************************************************/

void HookEntity(int entity)
{
    if (ge_bOnTakeDamageAlivePostHooked[entity])
        return;

    ge_bOnTakeDamageAlivePostHooked[entity] = true;
    SDKHook(entity, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);
}

/****************************************************************************************************/

void OnTakeDamageAlivePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3])
{
    if (!g_bCvar_Enabled)
        return;

    if (GetEntProp(victim, Prop_Data, "m_iHealth") > 0)
        return;

    if (!IsValidClient(attacker))
        return;

    if (!(GetTeamFlag(GetClientTeam(attacker)) & g_iCvar_TeamAttacker))
        return;

    int type = GetRockType(victim);

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
            continue;

        if (IsFakeClient(client))
            continue;

        if (!(GetTeamFlag(GetClientTeam(client)) & g_iCvar_Team))
            continue;

        switch (type)
        {
            case TYPE_CONCRETE_CHUNK: CPrintToChat(client, "%t", "Rock", attacker);
            case TYPE_TREE_TRUNK: CPrintToChat(client, "%t", "Trunk", attacker);
            case TYPE_UNKNOWN: CPrintToChat(client, "%t", "Unknown", attacker);
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
    PrintToConsole(client, "------------ Plugin Cvars (l4d_tank_rock_destroyer_announce) -----------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d_tank_rock_destroyer_announce : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d_tank_rock_destroyer_announce_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d_tank_rock_destroyer_announce_team : %i (SPECTATOR = %s | SURVIVOR = %s | INFECTED = %s | HOLDOUT = %s)", g_iCvar_Team,
    g_iCvar_Team & FLAG_TEAM_SPECTATOR ? "true" : "false", g_iCvar_Team & FLAG_TEAM_SURVIVOR ? "true" : "false", g_iCvar_Team & FLAG_TEAM_INFECTED ? "true" : "false", g_iCvar_Team & FLAG_TEAM_HOLDOUT ? "true" : "false");
    PrintToConsole(client, "l4d_tank_rock_destroyer_announce_team_attacker : %i (SPECTATOR = %s | SURVIVOR = %s | INFECTED = %s | HOLDOUT = %s)", g_iCvar_TeamAttacker,
    g_iCvar_TeamAttacker & FLAG_TEAM_SPECTATOR ? "true" : "false", g_iCvar_TeamAttacker & FLAG_TEAM_SURVIVOR ? "true" : "false", g_iCvar_TeamAttacker & FLAG_TEAM_INFECTED ? "true" : "false", g_iCvar_TeamAttacker & FLAG_TEAM_HOLDOUT ? "true" : "false");
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
 * @param client          Client index.
 * @return                True if client index is valid, false otherwise.
 */
bool IsValidClientIndex(int client)
{
    return (1 <= client <= MaxClients);
}

/****************************************************************************************************/

/**
 * Validates if is a valid client.
 *
 * @param client          Client index.
 * @return                True if client index is valid and client is in game, false otherwise.
 */
bool IsValidClient(int client)
{
    return (IsValidClientIndex(client) && IsClientInGame(client));
}

/****************************************************************************************************/

/**
 * Returns the team flag from a team.
 *
 * @param team          Team index.
 * @return              Team flag.
 */
int GetTeamFlag(int team)
{
    switch (team)
    {
        case TEAM_SURVIVOR:
            return FLAG_TEAM_SURVIVOR;
        case TEAM_INFECTED:
            return FLAG_TEAM_INFECTED;
        case TEAM_SPECTATOR:
            return FLAG_TEAM_SPECTATOR;
        case TEAM_HOLDOUT:
            return FLAG_TEAM_HOLDOUT;
        default:
            return FLAG_TEAM_NONE;
    }
}

/****************************************************************************************************/

/**
 * Returns the rock type.
 *
 * @param entity        Entity index.
 * @return              Entity rock type.
 */
int GetRockType(int entity)
{
    int modelIndex = GetEntProp(entity, Prop_Send, "m_nModelIndex");

    if (modelIndex == g_iModel_Rock)
        return TYPE_CONCRETE_CHUNK;

    if (modelIndex == g_iModel_Trunk)
        return TYPE_TREE_TRUNK;

    return TYPE_UNKNOWN;
}

// ====================================================================================================
// colors.inc replacement (Thanks to Silvers)
// ====================================================================================================
/**
 * Prints a message to a specific client in the chat area.
 * Supports color tags.
 *
 * @param client        Client index.
 * @param message       Message (formatting rules).
 *
 * On error/Errors:     If the client is not connected an error will be thrown.
 */
void CPrintToChat(int client, char[] message, any ...)
{
    char buffer[512];
    SetGlobalTransTarget(client);
    VFormat(buffer, sizeof(buffer), message, 3);

    ReplaceString(buffer, sizeof(buffer), "{default}", "\x01");
    ReplaceString(buffer, sizeof(buffer), "{white}", "\x01");
    ReplaceString(buffer, sizeof(buffer), "{cyan}", "\x03");
    ReplaceString(buffer, sizeof(buffer), "{lightgreen}", "\x03");
    ReplaceString(buffer, sizeof(buffer), "{orange}", "\x04");
    ReplaceString(buffer, sizeof(buffer), "{green}", "\x04"); // Actually orange in L4D1/L4D2, but replicating colors.inc behaviour
    ReplaceString(buffer, sizeof(buffer), "{olive}", "\x05");

    PrintToChat(client, buffer);
}