#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <left4dhooks>
//#include <l4d2_changelevel>

#define Version "2.5"
#define MAX_ARRAY_LINE 50
#define MAX_MAPNAME_LEN 64
#define MAX_CREC_LEN 2
#define MAX_REBFl_LEN 8

#define NEXTLEVEL_Seconds 6.0

ConVar DefMCoop, DefMSurvival, DefMVersus, CheckRoundCounterCoop, CheckRoundCounterCoopFinal, ChDelayVS, 
	ChDelaySurvival, CheckRoundCounterSurvival, cvarAnnounce, h_GameMode;
//ConVar ChDelayCOOPFinal;

int g_iCurrentMode;
char current_map[64];
char announce_map[64];
char next_mission_def_coop[64];
char next_mission_def_survival[64];
char next_mission_def_versus[64];
char next_mission_type[64];
char next_mission_map[64];
char next_mission_name[64];
bool cvarAnnounceValue, g_bHasRoundEnd, g_bFinalMap;
float ChDelayVSValue, ChDelaySurvivalValue;
//float ChDelayCOOPFinalValue;
int CoopRoundEndCounter = 0;
int CheckRoundCounterCoopFinalValue, CheckRoundCounterCoopValue, CheckRoundCounterSurvivalValue;

Handle hKVSettings = null;

public Plugin myinfo = 
{
	name = "L4D Force Mission Changer",
	author = "Dionys, Harry, Jeremy Villanueva",
	description = "Force change to next mission when current mission end.",
	version = Version,
	url = "https://steamcommunity.com/profiles/76561198026784913"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	EngineVersion test = GetEngineVersion();
	
	if( test != Engine_Left4Dead2 && test != Engine_Left4Dead)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success; 
}

public void OnPluginStart()
{
	LoadTranslations("sm_l4d_mapchanger.phrases");

	hKVSettings=CreateKeyValues("ForceMissionChangerSettings");

	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	//HookEvent("finale_win", Event_FinalWin);
	HookEvent("mission_lost", Event_MissionLost);
	
	h_GameMode = FindConVar("mp_gamemode");

	DefMCoop = CreateConVar("sm_l4d_fmc_def_coop", "c2m1_highway", "战役/写实模式中默认更换的地图.(无内容=无默认更改地图)", FCVAR_NOTIFY);
	DefMSurvival = CreateConVar("sm_l4d_fmc_def_survival", "", "生还者模式中默认更换的地图(无内容=无默认更改地图)", FCVAR_NOTIFY);
	DefMVersus = CreateConVar("sm_l4d_fmc_def_versus", "c8m1_apartment", "对抗模式中默认更换的地图(无内容=无默认更改地图)", FCVAR_NOTIFY);
	CheckRoundCounterCoop = CreateConVar("sm_l4d_fmc_crec_coop_map", "3", "战役/写实模式中，非最后一关团灭多少次换图 (0=关)", FCVAR_NOTIFY, true, 0.0);
	CheckRoundCounterCoopFinal = CreateConVar("sm_l4d_fmc_crec_coop_final", "3", "战役/写实模式中,最后一关团灭多少次换图 (0=关)", FCVAR_NOTIFY, true, 0.0);
	CheckRoundCounterSurvival = CreateConVar("sm_l4d_fmc_crec_survival_map", "5", "生还者模式中团灭多少次换图(0=关)", FCVAR_NOTIFY, true, 0.0);
	ChDelayVS = CreateConVar("sm_l4d_fmc_delay_vs", "13.0", "对抗模式中一场游戏结束后多少秒换图 (0=关)", FCVAR_NOTIFY, true, 0.0);
	ChDelaySurvival = CreateConVar("sm_l4d_fmc_delay_survival", "15.0", "生还者模式中一场游戏结束后多少秒换图 (0=关)", FCVAR_NOTIFY, true, 0.0);
	//ChDelayCOOPFinal = CreateConVar("sm_l4d_fmc_delay_coop_final", "15.0", "战役/写实模式中一场游戏结束后多少秒换图 (0=关)", FCVAR_NOTIFY, true, 0.0);
	cvarAnnounce = CreateConVar("sm_l4d_fmc_announce", "1", "在最后一关开始时是否向玩家展示更换的地图", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	AutoExecConfig(true, "sm_l4d_mapchanger");

	GetCvars();
	GameModeCheck();
	h_GameMode.AddChangeHook(ConVarGameMode);
	DefMCoop.AddChangeHook(ConVarChanged_Cvars);
	DefMSurvival.AddChangeHook(ConVarChanged_Cvars);
	CheckRoundCounterCoop.AddChangeHook(ConVarChanged_Cvars);
	CheckRoundCounterCoopFinal.AddChangeHook(ConVarChanged_Cvars);
	CheckRoundCounterSurvival.AddChangeHook(ConVarChanged_Cvars);
	ChDelayVS.AddChangeHook(ConVarChanged_Cvars);
	ChDelaySurvival.AddChangeHook(ConVarChanged_Cvars);
	//ChDelayCOOPFinal.AddChangeHook(ConVarChanged_Cvars);
	cvarAnnounce.AddChangeHook(ConVarChanged_Cvars);

	RegConsoleCmd("sm_fmc_nextmap", Cmd_NextMap, "Display Next Map");
	RegConsoleCmd("sm_fmc", Cmd_NextMap, "Display Next Map");

}

public Action Cmd_NextMap(int client, int args)
{
	ReplyToCommand(client, "%T","Announce Map Command", client, announce_map, next_mission_type);

	return Plugin_Handled;
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	DefMCoop.GetString(next_mission_def_coop, sizeof(next_mission_def_coop));
	DefMSurvival.GetString(next_mission_def_survival, sizeof(next_mission_def_survival));
	DefMVersus.GetString(next_mission_def_versus, sizeof(next_mission_def_versus));
	
	CheckRoundCounterCoopValue = CheckRoundCounterCoop.IntValue;
	CheckRoundCounterCoopFinalValue = CheckRoundCounterCoopFinal.IntValue;
	CheckRoundCounterSurvivalValue = CheckRoundCounterSurvival.IntValue;
	ChDelayVSValue = ChDelayVS.FloatValue;
	ChDelaySurvivalValue = ChDelaySurvival.FloatValue;
	//ChDelayCOOPFinalValue = ChDelayCOOPFinal.FloatValue;
	cvarAnnounceValue = cvarAnnounce.BoolValue;
}

public void ConVarGameMode(ConVar cvar, const char[] sOldValue, const char[] sintValue)
{
	GameModeCheck();
}

bool g_bMapStarted;
public void OnMapStart()
{
	g_bMapStarted = true;
	CoopRoundEndCounter = 0;
}

public void OnConfigsExecuted()
{
	GameModeCheck();

	GetCvars();
	PluginInitialization();
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}
/*
public void OnClientPutInServer(int client)
{
	// Make the announcement in 20 seconds unless announcements are turned off
	if(client && !IsFakeClient(client) && cvarAnnounceValue)
		CreateTimer(10.0, TimerAnnounce, client, TIMER_FLAG_NO_MAPCHANGE);
}
*/
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) 
{
	g_bHasRoundEnd = false;

	if( StrEqual(next_mission_map, "none") == false )
	{
		if(g_iCurrentMode == 1)
		{
			int left;
			if(g_bFinalMap)
			{
				if(CheckRoundCounterCoopFinalValue > 0 && CoopRoundEndCounter > 0) 
				{
					left = CheckRoundCounterCoopFinalValue-CoopRoundEndCounter;//Intentos - Intentos Realizados
					if(left > 0 && cvarAnnounceValue) CPrintToChatAll("%t","Finale Tries Left",left);/*
					if(left == 1)
					{
						if(cvarAnnounceValue) CPrintToChatAll("%t","Finale 1 Try Left");
					}*/
				}
			}
			else
			{
				if(CheckRoundCounterCoopValue > 0 && CoopRoundEndCounter > 0) 
				{
					left = CheckRoundCounterCoopValue - CoopRoundEndCounter;
					if(left > 0 && cvarAnnounceValue) CPrintToChatAll("%t","Tries Left", left);
				}
			}
		}
		else if(g_iCurrentMode == 3)
		{
			int left;
			if(CheckRoundCounterSurvivalValue > 0 && CoopRoundEndCounter > 0) 
			{
				left = CheckRoundCounterSurvivalValue - CoopRoundEndCounter;
				if(left > 0 && cvarAnnounceValue) CPrintToChatAll("%t","Tries Left", left);
			}
		}
	}
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) 
{
	if(g_bHasRoundEnd == true) return;
	g_bHasRoundEnd = true;

	if(StrEqual(next_mission_map, "none") == false)
	{
		if(g_iCurrentMode == 2 && InSecondHalfOfRound() && g_bFinalMap)
		{
			if( ChDelayVSValue > 0 )
			{
				//CreateTimer(ChDelayVSValue, Timer_ChangeMap, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		else if(g_iCurrentMode == 3)
		{
			CoopRoundEndCounter++;
			
			if(CheckRoundCounterSurvivalValue > 0 && CoopRoundEndCounter >= CheckRoundCounterSurvivalValue)
			{
				if( ChDelaySurvivalValue > 0)
				{
					CPrintToChatAll("%t","Force Pass Map No Tries Left", CheckRoundCounterSurvivalValue);
					//CreateTimer(ChDelaySurvivalValue, Timer_ChangeMap, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
	}
}

/*
public void Event_FinalWin(Event event, const char[] name, bool dontBroadcast) 
{
	if(ChDelayCOOPFinalValue > 0 && g_iCurrentMode == 1 && StrEqual(next_mission_map, "none") == false)
		CreateTimer(ChDelayCOOPFinalValue, Timer_ChangeMap, TIMER_FLAG_NO_MAPCHANGE);
}
*/
public void Event_MissionLost(Event event, const char[] name, bool dontBroadcast) 
{
	if(StrEqual(next_mission_map, "none") == false)
	{
		if(g_iCurrentMode == 1)
		{
			CoopRoundEndCounter += 1;//Intentos Realizados +1
			if(g_bFinalMap)
			{
				if(CheckRoundCounterCoopFinalValue > 0 && CoopRoundEndCounter >= CheckRoundCounterCoopFinalValue)
				{
					CPrintToChatAll("%t","Force Pass Campaign No Tries Left", CheckRoundCounterCoopFinalValue);
					//CreateTimer(NEXTLEVEL_Seconds, Timer_ChangeMap, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
			else
			{
				if(CheckRoundCounterCoopValue > 0 && CoopRoundEndCounter >= CheckRoundCounterCoopValue)
				{
					CPrintToChatAll("%t","Force Pass Map No Tries Left", CheckRoundCounterCoopValue);
					CreateTimer(NEXTLEVEL_Seconds, Timer_ChangeMap, TIMER_FLAG_NO_MAPCHANGE);
				}		
			}
		}
		}
}
/*
public Action TimerAnnounce(Handle timer, any client)
{
	if(IsClientInGame(client))
	{
		if (g_iCurrentMode != 3) // not survival
		{
			if( g_bFinalMap ) CPrintToChat(client, "%T","Announce Map", client, announce_map);
		}
		else
		{
			CPrintToChat(client, "%T","Announce Map", client, announce_map);
		}
	}

	return Plugin_Continue;
}
*/
public Action Timer_ChangeMap(Handle timer)
{
	ServerCommand("changelevel %s", next_mission_map);
	//L4D2_ChangeLevel(next_mission_map);

	return Plugin_Continue;
}

void ClearKV(Handle kvhandle)
{
	KvRewind(kvhandle);
	if (KvGotoFirstSubKey(kvhandle))
	{
		do
		{
			KvDeleteThis(kvhandle);
			KvRewind(kvhandle);
		}
		while (KvGotoFirstSubKey(kvhandle));
		KvRewind(kvhandle);
	}
}

void PluginInitialization()
{
	GameModeCheck();
	ClearKV(hKVSettings);
	
	char FMC_FileSettings[128];
	BuildPath(Path_SM, FMC_FileSettings, sizeof(FMC_FileSettings), "data/sm_l4d_mapchanger.txt");
	if( !FileExists(FMC_FileSettings) )
	{
		SetFailState("data/sm_l4d_mapchanger.txt does not exits !!!");
	}

	if(!FileToKeyValues(hKVSettings, FMC_FileSettings))
		SetFailState("Force Mission Changer settings not found! Shutdown.");
	
	next_mission_map = "none";
	next_mission_name = "none";
	announce_map = "none";
	next_mission_type = "none";
	GetCurrentMap(current_map, sizeof(current_map));

	g_bFinalMap = L4D_IsMissionFinalMap();
	KvRewind(hKVSettings);

	if(g_iCurrentMode == 1)
	{
		if(!g_bFinalMap)
		{
			int ent = FindEntityByClassname(-1, "info_changelevel");
			if(ent == -1)
			{
				ent = FindEntityByClassname(-1, "trigger_changelevel");
			}

			if(ent == -1)
			{
				FormatEx(announce_map, sizeof(announce_map), "Empty");
				FormatEx(next_mission_type, sizeof(next_mission_type), "next level not found");
			}
			else
			{
				GetEntPropString(ent, Prop_Data, "m_mapName", next_mission_map, sizeof(next_mission_map)); // Get Prop Name
				FormatEx(announce_map, sizeof(announce_map), "%s", next_mission_map);
				FormatEx(next_mission_type, sizeof(next_mission_type), "next level");
			}
			//LogMessage("sm_l4d_mapchanger: Next stage: %s", next_mission_map);
		}
		
		if(KvJumpToKey(hKVSettings, current_map))
		{
			KvGetString(hKVSettings, "next mission map", next_mission_map, sizeof(next_mission_map), "none");//Force Next Campaign,Def Next Map
			//LogMessage("next_mission map: %s",next_mission_map);
			KvGetString(hKVSettings, "next mission name", next_mission_name, sizeof(next_mission_name), "none");
			//LogMessage("next mission name: %s",next_mission_name);
		}
	}
	else if(g_iCurrentMode == 2 && g_bFinalMap)
	{
		if(KvJumpToKey(hKVSettings, current_map))
		{
			KvGetString(hKVSettings, "next mission map", next_mission_map, sizeof(next_mission_map), "none");//Force Next Campaign,Def Next Map
			//LogMessage("next_mission map: %s",next_mission_map);
			KvGetString(hKVSettings, "next mission name", next_mission_name, sizeof(next_mission_name), "none");
			//LogMessage("next mission name: %s",next_mission_name);
		}
	}
	else if(g_iCurrentMode == 3)
	{
		if(KvJumpToKey(hKVSettings, current_map))
		{
			KvGetString(hKVSettings, "survival_nextmap", next_mission_map, sizeof(next_mission_map), "none");
			KvGetString(hKVSettings, "survival_nextname", next_mission_name, sizeof(next_mission_name), "none");
		}
	}
	KvRewind(hKVSettings);
		
	if (StrEqual(next_mission_map, "none") == false)
	{
		if (!IsMapValid(next_mission_map))
		{
			FormatEx(announce_map, sizeof(announce_map), "%s", next_mission_map);
			FormatEx(next_mission_type, sizeof(next_mission_type), "invalid map");
			next_mission_map = "none";
			return;
		}
		
		if (StrEqual(next_mission_name, "none") == false)
		{
			FormatEx(announce_map, sizeof(announce_map), "%s", next_mission_name);
			if(strcmp(next_mission_type, "none") == 0) FormatEx(next_mission_type, sizeof(next_mission_type), "next map");
		}
		else
		{
			FormatEx(announce_map, sizeof(announce_map), "%s", next_mission_map);
			if(strcmp(next_mission_type, "none") == 0) FormatEx(next_mission_type, sizeof(next_mission_type), "next map");
		}
	}
	else
	{
		if(g_iCurrentMode == 1)
		{
			if(StrEqual(announce_map, "Empty")) return;

			if(strlen(next_mission_def_coop) > 0)
			{
				FormatEx(announce_map, sizeof(announce_map), "%s", next_mission_def_coop);
				FormatEx(next_mission_type, sizeof(next_mission_type), "default");
				next_mission_map = next_mission_def_coop;
			}
			else
			{
				FormatEx(announce_map, sizeof(announce_map), "none");
				FormatEx(next_mission_type, sizeof(next_mission_type), "none");
			}
		}
		else if(g_iCurrentMode == 2)
		{
			if(g_bFinalMap && strlen(next_mission_def_versus) > 0)
			{
				FormatEx(announce_map, sizeof(announce_map), "%s", next_mission_def_versus);
				FormatEx(next_mission_type, sizeof(next_mission_type), "default");
				next_mission_map = next_mission_def_versus;
			}
			else
			{
				FormatEx(announce_map, sizeof(announce_map), "none");
				FormatEx(next_mission_type, sizeof(next_mission_type), "none");
			}
		}
		else if(g_iCurrentMode == 3)
		{
			if(strlen(next_mission_def_survival) > 0)
			{
				FormatEx(announce_map, sizeof(announce_map), "%s", next_mission_def_survival);
				FormatEx(next_mission_type, sizeof(next_mission_type), "default");
				next_mission_map = next_mission_def_survival;
			}
			else
			{
				FormatEx(announce_map, sizeof(announce_map), "none");
				FormatEx(next_mission_type, sizeof(next_mission_type), "none");
			}
		}
	}
}

void GameModeCheck()
{
	if(!g_bMapStarted) return; 

	int entity = CreateEntityByName("info_gamemode");
	if( IsValidEntity(entity) )
	{
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
			RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
	}
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 3;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 2;
}

bool InSecondHalfOfRound() {
    return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}