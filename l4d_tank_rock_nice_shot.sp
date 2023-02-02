/**
// ====================================================================================================
Change Log:

1.0.2 (19-December-2021)
    - Added sounds precache.
    - Changed sound level to SNDLEVEL_SCREAMING.

1.0.1 (19-December-2021)
    - Added cvar attacker laugh. (thanks to "KadabraZz" for requesting)
    - Added missing death check. (thanks "finishlast" for reporting)

1.0.0 (18-December-2021)
    - Initial release.

// ====================================================================================================
*/

// ====================================================================================================
// Plugin Info - define
// ====================================================================================================
#define PLUGIN_NAME                   "[L4D1 & L4D2] Tank Rock Nice Shot"
#define PLUGIN_AUTHOR                 "Mart"
#define PLUGIN_DESCRIPTION            "Survivors emit a nice shot voice line when a teammate destroys a Tank rock"
#define PLUGIN_VERSION                "1.0.2"
#define PLUGIN_URL                    "https://forums.alliedmods.net/showthread.php?t=335613"

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
#define CONFIG_FILENAME              "l4d_tank_rock_nice_shot"

// ====================================================================================================
// Defines
// ====================================================================================================
#define TEAM_SURVIVOR                 2
#define TEAM_HOLDOUT                  4

#define SURVIVOR_UNKNOWN              0
#define SURVIVOR_BILL                 1
#define SURVIVOR_FRANCIS              2
#define SURVIVOR_LOUIS                3
#define SURVIVOR_ZOEY                 4
#define SURVIVOR_COACH                5
#define SURVIVOR_ELLIS                6
#define SURVIVOR_NICK                 7
#define SURVIVOR_ROCHELLE             8

#define MAX_VOICE_LINE_STRLENGTH      47

#define MAXENTITIES                   2048

// ====================================================================================================
// Plugin Cvars
// ====================================================================================================
ConVar g_hCvar_Enabled;
ConVar g_hCvar_Chance;
ConVar g_hCvar_LaughChance;

// ====================================================================================================
// bool - Plugin Variables
// ====================================================================================================
bool g_bL4D2;
bool g_bCvar_Enabled;

// ====================================================================================================
// int - Plugin Variables
// ====================================================================================================
int g_iCvar_Chance;
int g_iCvar_LaughChance;

// ====================================================================================================
// entity - Plugin Variables
// ====================================================================================================
bool ge_bOnTakeDamageAlivePostHooked[MAXENTITIES+1];

// ====================================================================================================
// ArrayList - Plugin Variables
// ====================================================================================================
ArrayList g_alBillNiceShot;
ArrayList g_alFrancisNiceShot;
ArrayList g_alLouisNiceShot;
ArrayList g_alZoeyNiceShot;
ArrayList g_alCoachNiceShot;
ArrayList g_alEllisNiceShot;
ArrayList g_alNickNiceShot;
ArrayList g_alRochelleNiceShot;
ArrayList g_alBillLaugh;
ArrayList g_alFrancisLaugh;
ArrayList g_alLouisLaugh;
ArrayList g_alZoeyLaugh;
ArrayList g_alCoachLaugh;
ArrayList g_alEllisLaugh;
ArrayList g_alNickLaugh;
ArrayList g_alRochelleLaugh;

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
    g_alBillNiceShot = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alFrancisNiceShot = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alLouisNiceShot = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alZoeyNiceShot = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alCoachNiceShot = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alEllisNiceShot = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alNickNiceShot = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alRochelleNiceShot = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alBillLaugh = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alFrancisLaugh = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alLouisLaugh = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alZoeyLaugh = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alCoachLaugh = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alEllisLaugh = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alNickLaugh = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));
    g_alRochelleLaugh = new ArrayList(ByteCountToCells(MAX_VOICE_LINE_STRLENGTH));

    LoadNiceShot();
    LoadLaugh();

    CreateConVar("l4d_tank_rock_nice_shot_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, CVAR_FLAGS_PLUGIN_VERSION);
    g_hCvar_Enabled     = CreateConVar("l4d_tank_rock_nice_shot_enable", "1", "是否启用插件.\n0 = 禁用, 1 = 启用.", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hCvar_Chance      = CreateConVar("l4d_tank_rock_nice_shot_chance", "100", "发出nice shot语音几率(%)", CVAR_FLAGS, true, 0.0, true, 100.0);
    g_hCvar_LaughChance = CreateConVar("l4d_tank_rock_nice_shot_laugh_chance", "100", "打碎石头发出大笑语音几率(%)", CVAR_FLAGS, true, 0.0, true, 100.0);

    // Hook plugin ConVars change
    g_hCvar_Enabled.AddChangeHook(Event_ConVarChanged);
    g_hCvar_Chance.AddChangeHook(Event_ConVarChanged);
    g_hCvar_LaughChance.AddChangeHook(Event_ConVarChanged);

    // Load plugin configs from .cfg
    AutoExecConfig(true, CONFIG_FILENAME);

    // Admin Commands
    RegAdminCmd("sm_print_cvars_l4d_tank_rock_nice_shot", CmdPrintCvars, ADMFLAG_ROOT, "
Prints the plugin related cvars and their respective values to the console.
将插件相关的cvar及其各自的值打印到控制台");
}

/****************************************************************************************************/

void LoadNiceShot()
{
    g_alBillNiceShot.PushString("player/survivor/voice/namvet/niceshot01.wav");
    g_alBillNiceShot.PushString("player/survivor/voice/namvet/niceshot02.wav");
    g_alBillNiceShot.PushString("player/survivor/voice/namvet/niceshot03.wav");
    g_alBillNiceShot.PushString("player/survivor/voice/namvet/niceshot04.wav");
    g_alBillNiceShot.PushString("player/survivor/voice/namvet/niceshot05.wav");
    g_alBillNiceShot.PushString("player/survivor/voice/namvet/niceshot06.wav");
    g_alBillNiceShot.PushString("player/survivor/voice/namvet/niceshot07.wav");
    g_alBillNiceShot.PushString("player/survivor/voice/namvet/niceshot08.wav");
    g_alBillNiceShot.PushString("player/survivor/voice/namvet/niceshot09.wav");
    g_alBillNiceShot.PushString("player/survivor/voice/namvet/niceshot13.wav");
    g_alBillNiceShot.PushString("player/survivor/voice/namvet/niceshot14.wav");

    g_alFrancisNiceShot.PushString("player/survivor/voice/biker/niceshot01.wav");
    g_alFrancisNiceShot.PushString("player/survivor/voice/biker/niceshot02.wav");
    g_alFrancisNiceShot.PushString("player/survivor/voice/biker/niceshot03.wav");
    g_alFrancisNiceShot.PushString("player/survivor/voice/biker/niceshot04.wav");
    g_alFrancisNiceShot.PushString("player/survivor/voice/biker/niceshot07.wav");
    g_alFrancisNiceShot.PushString("player/survivor/voice/biker/niceshot08.wav");
    g_alFrancisNiceShot.PushString("player/survivor/voice/biker/niceshot09.wav");
    g_alFrancisNiceShot.PushString("player/survivor/voice/biker/niceshot10.wav");

    g_alLouisNiceShot.PushString("player/survivor/voice/manager/niceshot01.wav");
    g_alLouisNiceShot.PushString("player/survivor/voice/manager/niceshot02.wav");
    g_alLouisNiceShot.PushString("player/survivor/voice/manager/niceshot03.wav");
    g_alLouisNiceShot.PushString("player/survivor/voice/manager/niceshot04.wav");
    g_alLouisNiceShot.PushString("player/survivor/voice/manager/niceshot05.wav");
    g_alLouisNiceShot.PushString("player/survivor/voice/manager/niceshot07.wav");
    g_alLouisNiceShot.PushString("player/survivor/voice/manager/niceshot08.wav");
    g_alLouisNiceShot.PushString("player/survivor/voice/manager/niceshot09.wav");
    g_alLouisNiceShot.PushString("player/survivor/voice/manager/niceshot10.wav");

    g_alZoeyNiceShot.PushString("player/survivor/voice/teengirl/niceshot01.wav");
    g_alZoeyNiceShot.PushString("player/survivor/voice/teengirl/niceshot04.wav");
    g_alZoeyNiceShot.PushString("player/survivor/voice/teengirl/niceshot05.wav");
    g_alZoeyNiceShot.PushString("player/survivor/voice/teengirl/niceshot06.wav");
    g_alZoeyNiceShot.PushString("player/survivor/voice/teengirl/niceshot07.wav");
    g_alZoeyNiceShot.PushString("player/survivor/voice/teengirl/niceshot08.wav");
    g_alZoeyNiceShot.PushString("player/survivor/voice/teengirl/niceshot11.wav");
    g_alZoeyNiceShot.PushString("player/survivor/voice/teengirl/niceshot12.wav");
    g_alZoeyNiceShot.PushString("player/survivor/voice/teengirl/niceshot13.wav");
    g_alZoeyNiceShot.PushString("player/survivor/voice/teengirl/niceshot14.wav");
    g_alZoeyNiceShot.PushString("player/survivor/voice/teengirl/niceshot15.wav");
    g_alZoeyNiceShot.PushString("player/survivor/voice/teengirl/niceshot16.wav");
    g_alZoeyNiceShot.PushString("player/survivor/voice/teengirl/niceshot17.wav");

    if (!g_bL4D2)
        return;

    g_alCoachNiceShot.PushString("player/survivor/voice/coach/niceshot01.wav");
    g_alCoachNiceShot.PushString("player/survivor/voice/coach/niceshot02.wav");
    g_alCoachNiceShot.PushString("player/survivor/voice/coach/niceshot03.wav");
    g_alCoachNiceShot.PushString("player/survivor/voice/coach/niceshot04.wav");
    g_alCoachNiceShot.PushString("player/survivor/voice/coach/niceshot05.wav");
    g_alCoachNiceShot.PushString("player/survivor/voice/coach/niceshot06.wav");
    g_alCoachNiceShot.PushString("player/survivor/voice/coach/niceshot07.wav");
    g_alCoachNiceShot.PushString("player/survivor/voice/coach/niceshot08.wav");
    g_alCoachNiceShot.PushString("player/survivor/voice/coach/niceshot09.wav");
    g_alCoachNiceShot.PushString("player/survivor/voice/coach/niceshot10.wav");
    g_alCoachNiceShot.PushString("player/survivor/voice/coach/niceshot11.wav");

    g_alEllisNiceShot.PushString("player/survivor/voice/mechanic/niceshot01.wav");
    g_alEllisNiceShot.PushString("player/survivor/voice/mechanic/niceshot02.wav");
    g_alEllisNiceShot.PushString("player/survivor/voice/mechanic/niceshot03.wav");
    g_alEllisNiceShot.PushString("player/survivor/voice/mechanic/niceshot04.wav");
    g_alEllisNiceShot.PushString("player/survivor/voice/mechanic/niceshot05.wav");
    g_alEllisNiceShot.PushString("player/survivor/voice/mechanic/niceshot06.wav");
    g_alEllisNiceShot.PushString("player/survivor/voice/mechanic/niceshot07.wav");
    g_alEllisNiceShot.PushString("player/survivor/voice/mechanic/niceshot08.wav");
    g_alEllisNiceShot.PushString("player/survivor/voice/mechanic/niceshot09.wav");
    g_alEllisNiceShot.PushString("player/survivor/voice/mechanic/niceshot10.wav");
    g_alEllisNiceShot.PushString("player/survivor/voice/mechanic/niceshot11.wav");

    g_alNickNiceShot.PushString("player/survivor/voice/gambler/niceshot01.wav");
    g_alNickNiceShot.PushString("player/survivor/voice/gambler/niceshot02.wav");
    g_alNickNiceShot.PushString("player/survivor/voice/gambler/niceshot03.wav");
    g_alNickNiceShot.PushString("player/survivor/voice/gambler/niceshot04.wav");
    g_alNickNiceShot.PushString("player/survivor/voice/gambler/niceshot05.wav");
    g_alNickNiceShot.PushString("player/survivor/voice/gambler/niceshot06.wav");
    g_alNickNiceShot.PushString("player/survivor/voice/gambler/niceshot07.wav");
    g_alNickNiceShot.PushString("player/survivor/voice/gambler/niceshot08.wav");
    g_alNickNiceShot.PushString("player/survivor/voice/gambler/niceshot09.wav");

    g_alRochelleNiceShot.PushString("player/survivor/voice/producer/niceshot01.wav");
    g_alRochelleNiceShot.PushString("player/survivor/voice/producer/niceshot02.wav");
    g_alRochelleNiceShot.PushString("player/survivor/voice/producer/niceshot03.wav");
    g_alRochelleNiceShot.PushString("player/survivor/voice/producer/niceshot04.wav");
    g_alRochelleNiceShot.PushString("player/survivor/voice/producer/niceshot05.wav");
}

/****************************************************************************************************/

void LoadLaugh()
{
    g_alBillLaugh.PushString("player/survivor/voice/namvet/laughter01.wav");
    g_alBillLaugh.PushString("player/survivor/voice/namvet/laughter02.wav");
    g_alBillLaugh.PushString("player/survivor/voice/namvet/laughter04.wav");
    g_alBillLaugh.PushString("player/survivor/voice/namvet/laughter05.wav");
    g_alBillLaugh.PushString("player/survivor/voice/namvet/laughter06.wav");
    g_alBillLaugh.PushString("player/survivor/voice/namvet/laughter07.wav");
    g_alBillLaugh.PushString("player/survivor/voice/namvet/laughter08.wav");
    g_alBillLaugh.PushString("player/survivor/voice/namvet/laughter09.wav");
    g_alBillLaugh.PushString("player/survivor/voice/namvet/laughter10.wav");
    g_alBillLaugh.PushString("player/survivor/voice/namvet/laughter11.wav");
    g_alBillLaugh.PushString("player/survivor/voice/namvet/laughter12.wav");
    g_alBillLaugh.PushString("player/survivor/voice/namvet/laughter13.wav");
    g_alBillLaugh.PushString("player/survivor/voice/namvet/laughter14.wav");

    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter01.wav");
    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter02.wav");
    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter03.wav");
    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter04.wav");
    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter05.wav");
    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter06.wav");
    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter07.wav");
    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter08.wav");
    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter09.wav");
    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter10.wav");
    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter11.wav");
    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter12.wav");
    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter13.wav");
    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter14.wav");
    g_alFrancisLaugh.PushString("player/survivor/voice/biker/laughter15.wav");

    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter01.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter02.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter03.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter04.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter05.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter06.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter07.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter08.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter09.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter10.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter11.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter12.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter13.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter14.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter15.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter16.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter17.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter18.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter19.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter20.wav");
    g_alLouisLaugh.PushString("player/survivor/voice/manager/laughter21.wav");

    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter01.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter02.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter03.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter04.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter05.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter06.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter07.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter08.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter09.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter10.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter11.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter12.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter13.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter14.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter15.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter16.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter17.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter18.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter19.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter20.wav");
    g_alZoeyLaugh.PushString("player/survivor/voice/teengirl/laughter21.wav");

    if (!g_bL4D2)
        return;

    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter01.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter02.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter03.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter04.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter05.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter06.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter07.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter08.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter09.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter10.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter11.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter12.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter13.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter14.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter15.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter16.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter17.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter18.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter19.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter20.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter21.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter22.wav");
    g_alCoachLaugh.PushString("player/survivor/voice/coach/laughter23.wav");

    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter01.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter02.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter03.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter04.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter05.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter06.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter07.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter08.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter09.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter10.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter11.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter12.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter13.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter13a.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter13b.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter13c.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter13d.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter13e.wav");
    g_alEllisLaugh.PushString("player/survivor/voice/mechanic/laughter14.wav");

    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter01.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter02.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter03.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter04.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter05.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter06.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter07.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter08.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter09.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter10.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter11.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter12.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter13.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter14.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter15.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter16.wav");
    g_alNickLaugh.PushString("player/survivor/voice/gambler/laughter17.wav");

    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter01.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter02.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter03.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter04.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter05.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter06.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter07.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter08.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter09.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter10.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter11.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter12.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter13.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter14.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter15.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter16.wav");
    g_alRochelleLaugh.PushString("player/survivor/voice/producer/laughter17.wav");
}

/****************************************************************************************************/

public void OnMapStart()
{
    PrecacheSoundArrayList(g_alBillNiceShot);
    PrecacheSoundArrayList(g_alFrancisNiceShot);
    PrecacheSoundArrayList(g_alLouisNiceShot);
    PrecacheSoundArrayList(g_alZoeyNiceShot);
    PrecacheSoundArrayList(g_alCoachNiceShot);
    PrecacheSoundArrayList(g_alEllisNiceShot);
    PrecacheSoundArrayList(g_alNickNiceShot);
    PrecacheSoundArrayList(g_alRochelleNiceShot);

    PrecacheSoundArrayList(g_alBillLaugh);
    PrecacheSoundArrayList(g_alFrancisLaugh);
    PrecacheSoundArrayList(g_alLouisLaugh);
    PrecacheSoundArrayList(g_alZoeyLaugh);
    PrecacheSoundArrayList(g_alCoachLaugh);
    PrecacheSoundArrayList(g_alEllisLaugh);
    PrecacheSoundArrayList(g_alNickLaugh);
    PrecacheSoundArrayList(g_alRochelleLaugh);
}

/****************************************************************************************************/

void PrecacheSoundArrayList(ArrayList array)
{
    char voiceLine[MAX_VOICE_LINE_STRLENGTH];

    for (int i = 0; i < array.Length; i++)
    {
        array.GetString(i, voiceLine, sizeof(voiceLine));
        PrecacheSound(voiceLine, true);
    }
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
    g_iCvar_Chance = g_hCvar_Chance.IntValue;
    g_iCvar_LaughChance = g_hCvar_LaughChance.IntValue;
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

    int attackerTeam = GetClientTeam(attacker);

    if (attackerTeam != TEAM_SURVIVOR && attackerTeam != TEAM_HOLDOUT)
        return;

    AttackerLaugh(attacker);

    int team;
    char voiceLine[MAX_VOICE_LINE_STRLENGTH];

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
            continue;

        if (client == attacker)
            continue;

        if (g_iCvar_Chance < GetRandomInt(1, 100))
            continue;

        if (!IsPlayerAlive(client))
            continue;

        team = GetClientTeam(client);

        if (team != TEAM_SURVIVOR && team != TEAM_HOLDOUT)
            continue;

        switch (GetSurvivorType(client))
        {
            case SURVIVOR_BILL: g_alBillNiceShot.GetString(GetRandomInt(0, g_alBillNiceShot.Length-1), voiceLine, sizeof(voiceLine));
            case SURVIVOR_FRANCIS: g_alFrancisNiceShot.GetString(GetRandomInt(0, g_alFrancisNiceShot.Length-1), voiceLine, sizeof(voiceLine));
            case SURVIVOR_LOUIS: g_alLouisNiceShot.GetString(GetRandomInt(0, g_alLouisNiceShot.Length-1), voiceLine, sizeof(voiceLine));
            case SURVIVOR_ZOEY: g_alZoeyNiceShot.GetString(GetRandomInt(0, g_alZoeyNiceShot.Length-1), voiceLine, sizeof(voiceLine));
            case SURVIVOR_COACH: g_alCoachNiceShot.GetString(GetRandomInt(0, g_alCoachNiceShot.Length-1), voiceLine, sizeof(voiceLine));
            case SURVIVOR_ELLIS: g_alEllisNiceShot.GetString(GetRandomInt(0, g_alEllisNiceShot.Length-1), voiceLine, sizeof(voiceLine));
            case SURVIVOR_NICK: g_alNickNiceShot.GetString(GetRandomInt(0, g_alNickNiceShot.Length-1), voiceLine, sizeof(voiceLine));
            case SURVIVOR_ROCHELLE: g_alRochelleNiceShot.GetString(GetRandomInt(0, g_alRochelleNiceShot.Length-1), voiceLine, sizeof(voiceLine));
            default: continue;
        }

        EmitSoundToAll(voiceLine, client, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
    }
}

/****************************************************************************************************/

void AttackerLaugh(int client)
{
    if (g_iCvar_LaughChance < GetRandomInt(1, 100))
        return;

    if (!IsPlayerAlive(client))
        return;

    char voiceLine[MAX_VOICE_LINE_STRLENGTH];

    switch (GetSurvivorType(client))
    {
        case SURVIVOR_BILL: g_alBillLaugh.GetString(GetRandomInt(0, g_alBillLaugh.Length-1), voiceLine, sizeof(voiceLine));
        case SURVIVOR_FRANCIS: g_alFrancisLaugh.GetString(GetRandomInt(0, g_alFrancisLaugh.Length-1), voiceLine, sizeof(voiceLine));
        case SURVIVOR_LOUIS: g_alLouisLaugh.GetString(GetRandomInt(0, g_alLouisLaugh.Length-1), voiceLine, sizeof(voiceLine));
        case SURVIVOR_ZOEY: g_alZoeyLaugh.GetString(GetRandomInt(0, g_alZoeyLaugh.Length-1), voiceLine, sizeof(voiceLine));
        case SURVIVOR_COACH: g_alCoachLaugh.GetString(GetRandomInt(0, g_alCoachLaugh.Length-1), voiceLine, sizeof(voiceLine));
        case SURVIVOR_ELLIS: g_alEllisLaugh.GetString(GetRandomInt(0, g_alEllisLaugh.Length-1), voiceLine, sizeof(voiceLine));
        case SURVIVOR_NICK: g_alNickLaugh.GetString(GetRandomInt(0, g_alNickLaugh.Length-1), voiceLine, sizeof(voiceLine));
        case SURVIVOR_ROCHELLE: g_alRochelleLaugh.GetString(GetRandomInt(0, g_alRochelleLaugh.Length-1), voiceLine, sizeof(voiceLine));
        default: return;
    }

    EmitSoundToAll(voiceLine, client, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
}

// ====================================================================================================
// Admin Commands
// ====================================================================================================
Action CmdPrintCvars(int client, int args)
{
    PrintToConsole(client, "");
    PrintToConsole(client, "======================================================================");
    PrintToConsole(client, "");
    PrintToConsole(client, "--------------- Plugin Cvars (l4d_tank_rock_nice_shot) ---------------");
    PrintToConsole(client, "");
    PrintToConsole(client, "l4d_tank_rock_nice_shot_version : %s", PLUGIN_VERSION);
    PrintToConsole(client, "l4d_tank_rock_nice_shot_enable : %b (%s)", g_bCvar_Enabled, g_bCvar_Enabled ? "true" : "false");
    PrintToConsole(client, "l4d_tank_rock_nice_shot_chance : %i%%", g_iCvar_Chance);
    PrintToConsole(client, "l4d_tank_rock_nice_shot_laugh_chance : %i%%", g_iCvar_LaughChance);
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

int GetSurvivorType(int client)
{
    char modelname[MAX_VOICE_LINE_STRLENGTH];
    GetEntPropString(client, Prop_Data, "m_ModelName", modelname, sizeof(modelname));

    if (g_bL4D2)
    {
        switch (CharToLower(modelname[29]))
        {
            case 'v': return SURVIVOR_BILL;
            case 'e': return SURVIVOR_FRANCIS;
            case 'a': return SURVIVOR_LOUIS;
            case 'n': return SURVIVOR_ZOEY;
            case 'c': return SURVIVOR_COACH;
            case 'h': return SURVIVOR_ELLIS;
            case 'b': return SURVIVOR_NICK;
            case 'd': return SURVIVOR_ROCHELLE;
        }
    }
    else
    {
        switch (CharToLower(modelname[29]))
        {
            case 'v': return SURVIVOR_BILL;
            case 'e': return SURVIVOR_FRANCIS;
            case 'a': return SURVIVOR_LOUIS;
            case 'n': return SURVIVOR_ZOEY;
        }
    }

    return SURVIVOR_UNKNOWN;
}