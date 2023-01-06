/**
// ====================================================================================================
Change Log:

1.0.1 (11-August-2022)
    - Added team filter.
    - Fixed fade not triggering for incapacitated clients.

1.0.0 (10-August-2022)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D1 & L4D2] Smoker Cloud Screen Fade"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Adds a blind fade effect while in Smoker cloud"
#define PLUGIN_VERSION                "1.0.1"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=339035"

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
#define CONFIG_FILENAME               "l4d_cloud_screen_fade"

// ====================================================================================================
// Defines
// ====================================================================================================
#define TEAM_SPECTATOR                1
#define TEAM_SURVIVOR                 2
#define TEAM_INFECTED                 3
#define TEAM_HOLDOUT                  4

#define FLAG_TEAM_NONE                (0 << 0) // 0 | 0000
#define FLAG_TEAM_SURVIVOR            (1 << 0) // 1 | 0001
#define FLAG_TEAM_INFECTED            (1 << 1) // 2 | 0010
#define FLAG_TEAM_SPECTATOR           (1 << 2) // 4 | 0100
#define FLAG_TEAM_HOLDOUT             (1 << 3) // 8 | 1000

#define L4D_ZOMBIECLASS_SMOKER        1

#define FFADE_IN                      0x0001
#define FFADE_OUT                     0x0002
#define FFADE_STAYOUT                 0x0008
#define FFADE_PURGE                   0x0010

#define SCREENFADE_FRACBITS           (1 << 9) // 512

#define MAXENTITIES                   2048

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;
ConVar g_hCvar_Color;
ConVar g_hCvar_Alpha;
ConVar g_hCvar_FadeOutDuration;
ConVar g_hCvar_FadeInDuration;
ConVar g_hCvar_FadeLife;
ConVar g_hCvar_FadeSize;
ConVar g_hCvar_Block;
ConVar g_hCvar_Team;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bEventsHooked;
bool g_bCvar_Enabled;
bool g_bCvar_RandomColor;
bool g_bCvar_Block;

// ====================================================================================================
// int - Plugin Variables
// ====================================================================================================
int g_iCvar_Color[3];
int g_iCvar_Alpha;
int g_iFadeOutDuration;
int g_iFadeInDuration;
int g_iCvar_Team;

// ====================================================================================================
// float - Plugin Variables
// ====================================================================================================
float g_fCvar_FadeOutDuration;
float g_fCvar_FadeInDuration;
float g_fCvar_FadeLife;
float g_fCvar_FadeSize;
float g_vFadeMins[3];
float g_vFadeMaxs[3];

// ====================================================================================================
// string - Plugin Variables
// ====================================================================================================
char g_sCvar_Color[12];
char g_sKillInput[50];

// ====================================================================================================
// UserMsg - Plugin Variables
// ====================================================================================================
UserMsg g_umFade;

// ====================================================================================================
// client - Plugin Variables
// ====================================================================================================
bool gc_bFade[MAXPLAYERS+1];
int gc_iColor[MAXPLAYERS+1][3];
ArrayList gc_alFadeRef[MAXPLAYERS+1];

// ====================================================================================================
// entity - Plugin Variables
// ====================================================================================================
bool ge_bTriggerFade[MAXENTITIES+1];

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
    for (int client = 1; client <= MaxClients; client++)
    {
        gc_alFadeRef[client] = new ArrayList();
    }

    g_umFade = GetUserMessageId("Fade");

    CreateConVar("l4d_cloud_screen_fade_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled         = CreateConVar("l4d_cloud_screen_fade_enable", "1", "是否启用插件.\n0 = 禁用, 1 = 启用.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Color           = CreateConVar("l4d_cloud_screen_fade_color", "20 20 20", "褪色的颜色.\n 使用'random'来获得随机颜色.\n使用三个0-255之间的数值，用空格分隔(\"<0-255> <0-255> <0-255>\").", CVAR_FLAGS);
    g_hCvar_Alpha           = CreateConVar("l4d_cloud_screen_fade_alpha", "245", "淡化阿尔法透明度.\n0 = 不可见, 255 = 完全可见.", CVAR_FLAGS, true, 0.0, true, 255.0);
    g_hCvar_FadeOutDuration = CreateConVar("l4d_cloud_screen_fade_out_duration", "0.5", "淡出(开始)时间，单位是秒.", CVAR_FLAGS, true, 0.0);
    g_hCvar_FadeInDuration  = CreateConVar("l4d_cloud_screen_fade_in_duration", "0.5", "淡出(结束)时间，单位是秒.", CVAR_FLAGS, true, 0.0);
    g_hCvar_FadeLife        = CreateConVar("l4d_cloud_screen_fade_life", "14.0", "触发区域在消失前会存在多长时间.", CVAR_FLAGS, true, 0.0);
    g_hCvar_FadeSize        = CreateConVar("l4d_cloud_screen_fade_size", "100.0", "淡出触发区域大小.", CVAR_FLAGS, true, 0.0);
    g_hCvar_Block           = CreateConVar("l4d_cloud_screen_fade_block", "1", "在插件淡出时，阻止应用于客户端的其他淡出效果.\n例如：受到伤害时的红屏.\n0 = 禁用, 1 = 启用.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Team            = CreateConVar("l4d_cloud_screen_fade_team", "1", " 哪些队伍应该受到该插件的影响.\n0 = 无, 1 = 生还者, 2 = 感染者, 4 = 旁观者, 8 = HOLDOUT(抵抗者?).\n加入大于0的数字表示多个选项.\n例如:3表示启用生还者和感染者.", CVAR_FLAGS, true, 0.0, true, 15.0);

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Color.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Alpha.AddChangeHook(Event_ConVarChanged);
    g_hCvar_FadeOutDuration.AddChangeHook(Event_ConVarChanged);
    g_hCvar_FadeInDuration.AddChangeHook(Event_ConVarChanged);
    g_hCvar_FadeLife.AddChangeHook(Event_ConVarChanged);
    g_hCvar_FadeSize.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Block.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Team.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_cloudfade", CmdCloudFade, ADMFLAG_ROOT, "对自身(无参数)或指定目标添加淡入淡出效果。示例：self -> sm_cloudfade / target -> sm_cloudfade @humanss.");
    RegAdminCmd("sm_print_cvars_l4d_cloud_screen_fade", CmdPrintCvars, ADMFLAG_ROOT, "将插件相关的 cvars 及其各自的值打印到控制台.");
}

/****************************************************************************************************/

public void OnConfigsExecuted()
{
    GetCvars();

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
    g_hCvar_Color.GetString(g_sCvar_Color, sizeof(g_sCvar_Color));
    TrimString(g_sCvar_Color);
    StringToLowerCase(g_sCvar_Color);
    g_bCvar_RandomColor = StrEqual(g_sCvar_Color, "random");
    g_iCvar_Color = ConvertRGBToIntArray(g_sCvar_Color);
    g_iCvar_Alpha = g_hCvar_Alpha.IntValue;
    g_fCvar_FadeOutDuration = g_hCvar_FadeOutDuration.FloatValue;
    g_iFadeOutDuration = RoundFloat(g_fCvar_FadeOutDuration * SCREENFADE_FRACBITS);
    g_fCvar_FadeInDuration = g_hCvar_FadeInDuration.FloatValue;
    g_iFadeInDuration = RoundFloat(g_fCvar_FadeInDuration * SCREENFADE_FRACBITS);
    g_fCvar_FadeLife = g_hCvar_FadeLife.FloatValue;
    FormatEx(g_sKillInput, sizeof(g_sKillInput), "OnUser1 !self:Kill::%.1f:-1", g_fCvar_FadeLife);
    g_fCvar_FadeSize = g_hCvar_FadeSize.FloatValue;
    g_vFadeMins[0] = -g_fCvar_FadeSize;
    g_vFadeMins[1] = -g_fCvar_FadeSize;
    g_vFadeMins[2] = 0.0;
    g_vFadeMaxs[0] = g_fCvar_FadeSize;
    g_vFadeMaxs[1] = g_fCvar_FadeSize;
    g_vFadeMaxs[2] = g_fCvar_FadeSize;
    g_bCvar_Block = g_hCvar_Block.BoolValue;
    g_iCvar_Team = g_hCvar_Team.IntValue;
}

/****************************************************************************************************/

void HookEvents()
{
    if (g_bCvar_Enabled && !g_bEventsHooked)
    {
        g_bEventsHooked = true;

        HookEvent("player_death", Event_PlayerDeath);
        HookUserMessage(g_umFade, FadeHook, true);

        return;
    }

    if (!g_bCvar_Enabled && g_bEventsHooked)
    {
        g_bEventsHooked = false;

        UnhookEvent("player_death", Event_PlayerDeath);
        UnhookUserMessage(g_umFade, FadeHook, true);

        return;
    }
}

/****************************************************************************************************/

public void OnClientDisconnect(int client)
{
    gc_bFade[client] = false;
    gc_iColor[client] = {0, 0, 0};
    gc_alFadeRef[client].Clear();
}

/****************************************************************************************************/

public void OnEntityDestroyed(int entity)
{
    if (entity < 0)
        return;

    if (!ge_bTriggerFade[entity])
        return;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
            continue;

        int count = gc_alFadeRef[client].Length;

        int find = gc_alFadeRef[client].FindValue(EntIndexToEntRef(entity));
        if (find != -1)
            gc_alFadeRef[client].Erase(find);

        if (count == 1)
            PerformFadeIn(client);
    }
}

/****************************************************************************************************/

Action FadeHook(UserMsg msg_id, BfRead bf, const int[] players, int playersNum, bool reliable, bool init)
{
    if (!g_bCvar_Block)
        return Plugin_Continue;

    if (playersNum != 1)
        return Plugin_Continue;

    int client = players[0];

    if (!IsValidClient(client))
        return Plugin_Continue;

    if (IsFakeClient(client))
        return Plugin_Continue;

    if (gc_bFade[client])
    {
        gc_bFade[client] = false;
        return Plugin_Continue;
    }

    if (gc_alFadeRef[client].Length == 0)
        return Plugin_Continue;

    return Plugin_Handled;
}

/****************************************************************************************************/

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    float vPos[3];
    vPos[0] = event.GetFloat("victim_x");
    vPos[1] = event.GetFloat("victim_y");
    vPos[2] = event.GetFloat("victim_z");

    if (client == 0)
        return;

    if (GetClientTeam(client) != TEAM_INFECTED)
        return;

    if (GetZombieClass(client) != L4D_ZOMBIECLASS_SMOKER)
        return;

    CreateTriggerFade(vPos);
}

/****************************************************************************************************/

void PerformFadeOut(int client)
{
    if (!IsValidClient(client))
        return;

    if (IsFakeClient(client))
        return;

    if (!(GetTeamFlag(GetClientTeam(client)) & g_iCvar_Team))
        return;

    if (g_bCvar_RandomColor)
    {
        gc_iColor[client][0] = GetRandomInt(0, 255);
        gc_iColor[client][1] = GetRandomInt(0, 255);
        gc_iColor[client][2] = GetRandomInt(0, 255);
    }
    else
    {
        gc_iColor[client] = g_iCvar_Color;
    }

    gc_bFade[client] = true;
    ScreenFade(client, g_iFadeOutDuration, SCREENFADE_FRACBITS, FFADE_PURGE|FFADE_OUT|FFADE_STAYOUT, gc_iColor[client][0], gc_iColor[client][1], gc_iColor[client][2], g_iCvar_Alpha);
}

/****************************************************************************************************/

void PerformFadeIn(int client)
{
    if (!IsValidClient(client))
        return;

    if (IsFakeClient(client))
        return;

    if (!(GetTeamFlag(GetClientTeam(client)) & g_iCvar_Team))
        return;

    gc_bFade[client] = true;
    ScreenFade(client, g_iFadeInDuration, SCREENFADE_FRACBITS, FFADE_PURGE|FFADE_IN, gc_iColor[client][0], gc_iColor[client][1], gc_iColor[client][2], g_iCvar_Alpha);
}

/****************************************************************************************************/

void OnStartTouch(const char[] output, int caller, int activator, float delay)
{
    int entity = caller;
    int client = activator;

    if (!IsValidClient(client))
        return;

    if (gc_alFadeRef[client].Length == 0)
        PerformFadeOut(client);

    gc_alFadeRef[client].Push(EntIndexToEntRef(entity));
}

/****************************************************************************************************/

void OnEndTouch(const char[] output, int caller, int activator, float delay)
{
    int entity = caller;
    int client = activator;

    if (!IsValidClient(client))
        return;

    int find = gc_alFadeRef[client].FindValue(EntIndexToEntRef(entity));
    if (find != -1)
        gc_alFadeRef[client].Erase(find);

    if (gc_alFadeRef[client].Length == 0)
        PerformFadeIn(client);
}

/****************************************************************************************************/

void CreateTriggerFade(float vPos[3])
{
    int entity = CreateEntityByName("trigger_multiple");
    ge_bTriggerFade[entity] = true;
    DispatchKeyValue(entity, "spawnflags", "1"); // Clients
    DispatchKeyValue(entity, "allowincap", "1"); // Yes
    DispatchKeyValueVector(entity, "origin", vPos);
    DispatchSpawn(entity);

    SetEntPropVector(entity, Prop_Send, "m_vecMins", g_vFadeMins);
    SetEntPropVector(entity, Prop_Send, "m_vecMaxs", g_vFadeMaxs);
    SetEntProp(entity, Prop_Send, "m_nSolidType", 2); // Bounding Box

    HookSingleEntityOutput(entity, "OnStartTouch", OnStartTouch);
    HookSingleEntityOutput(entity, "OnEndTouch", OnEndTouch);

    SetVariantString(g_sKillInput);
    AcceptEntityInput(entity, "AddOutput");
    AcceptEntityInput(entity, "FireUser1");
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
Action CmdCloudFade(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;

    float vPos[3];
    GetClientAbsOrigin(client, vPos);

    CreateTriggerFade(vPos);

    return Plugin_Handled;
}

/****************************************************************************************************/

Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "---------------- Plugin Cvars (l4d_cloud_screen_fade) ----------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d_cloud_screen_fade_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d_cloud_screen_fade_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d_cloud_screen_fade_color : \"%s\"", g_sCvar_Color);
    PrintToConsole(client, "l4d_cloud_screen_fade_alpha : %i", g_iCvar_Alpha);
    PrintToConsole(client, "l4d_cloud_screen_fade_out_duration : %.1f", g_fCvar_FadeOutDuration);
    PrintToConsole(client, "l4d_cloud_screen_fade_in_duration : %.1f", g_fCvar_FadeInDuration);
    PrintToConsole(client, "l4d_cloud_screen_fade_life : %.1f", g_fCvar_FadeLife);
    PrintToConsole(client, "l4d_cloud_screen_fade_size : %.1f", g_fCvar_FadeSize);
    PrintToConsole(client, "l4d_cloud_screen_fade_block : %b (%s)", g_bCvar_Block, g_bCvar_Block ? "true" : "false");
    PrintToConsole(client, "l4d_cloud_screen_fade_team : %i (SPECTATOR = %s | SURVIVOR = %s | INFECTED = %s | HOLDOUT = %s)", g_iCvar_Team,
    g_iCvar_Team & FLAG_TEAM_SPECTATOR ? "true" : "false", g_iCvar_Team & FLAG_TEAM_SURVIVOR ? "true" : "false", g_iCvar_Team & FLAG_TEAM_INFECTED ? "true" : "false", g_iCvar_Team & FLAG_TEAM_HOLDOUT ? "true" : "false");
    PrintToConsole(client, "");
    PrintToConsole(client, "----------------------------- Array List -----------------------------");
    PrintToConsole(client, "");
    for (int target = 1; target <= MaxClients; target++)
    {
        if (!IsClientInGame(target))
            continue;

        PrintToConsole(client, "gc_alFadeRef[%i].Length: %N (%i)", target, target, gc_alFadeRef[target].Length);
    }
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
 * Gets the client L4D1/L4D2 zombie class id.
 *
 * @param client        Client index.
 * @return L4D1         1=SMOKER, 2=BOOMER, 3=HUNTER, 4=WITCH, 5=TANK, 6=NOT INFECTED
 * @return L4D2         1=SMOKER, 2=BOOMER, 3=HUNTER, 4=SPITTER, 5=JOCKEY, 6=CHARGER, 7=WITCH, 8=TANK, 9=NOT INFECTED
 */
int GetZombieClass(int client)
{
    return (GetEntProp(client, Prop_Send, "m_zombieClass"));
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
 * Returns the integer array value of a RGB string.
 * Format: Three values between 0-255 separated by spaces. "<0-255> <0-255> <0-255>"
 * Example: "255 255 255"
 *
 * @param sColor        RGB color string.
 * @return              Integer array (int[3]) value of the RGB string or {0,0,0} if not in specified format.
 */
int[] ConvertRGBToIntArray(char[] sColor)
{
    int color[3];

    if (sColor[0] == 0)
        return color;

    char sColors[3][4];
    int count = ExplodeString(sColor, " ", sColors, sizeof(sColors), sizeof(sColors[]));

    switch (count)
    {
        case 1:
        {
            color[0] = StringToInt(sColors[0]);
        }
        case 2:
        {
            color[0] = StringToInt(sColors[0]);
            color[1] = StringToInt(sColors[1]);
        }
        case 3:
        {
            color[0] = StringToInt(sColors[0]);
            color[1] = StringToInt(sColors[1]);
            color[2] = StringToInt(sColors[2]);
        }
    }

    return color;
}

/****************************************************************************************************/

void ScreenFade(int client, int delay, int duration, int type, int red, int green, int blue, int alpha)
{
    Handle message = StartMessageOne("Fade", client);
    BfWrite bf = UserMessageToBfWrite(message);
    bf.WriteShort(delay);
    bf.WriteShort(duration);
    bf.WriteShort(type);
    bf.WriteByte(red);
    bf.WriteByte(green);
    bf.WriteByte(blue);
    bf.WriteByte(alpha);
    EndMessage();
}