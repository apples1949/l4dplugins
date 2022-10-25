
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <pan0s>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define VERSION             "v1.1"

enum
{
    MAP_PREV,
    MAP_NEXT,
}

// Official map codes list
char g_sMaps[][][] =
{
    //prev, next
	{"c14m2_lighthouse", "c1m1_hotel",},
	{"c1m4_atrium", "c2m1_highway",},
	{"c2m5_concert", "c3m1_plankcountry",},
	{"c3m4_plantation", "c4m1_milltown_a",},
	{"c4m5_milltown_escape", "c5m1_waterfront",},
	{"c5m5_bridge", "c6m1_riverbank",},
	{"c6m3_port", "c7m1_docks",},
	{"c7m3_port", "c8m1_apartment",},
	{"c8m5_rooftop", "c9m1_alleys",},
	{"c9m2_lots", "c10m1_caves",},
	{"c10m5_houseboat", "c11m1_greenhouse",},
	{"c11m5_runway", "c12m1_hilltop",},
	{"c12m5_cornfield", "c13m1_alpinecreek",},
	{"c13m4_cutthroatcreek", "c14m1_junkyard",},

    // Custom maps
    //prev, next
//	{"c14m2_lighthouse", "re1m1",},
//	{"re1m6", "re2a1",},
//	{"re2a4", "re2b1",},
//	{"re2b4", "re3m1",},
};      

// ConVar
ConVar cvar_random_on;
ConVar cvar_delay;
ConVar cvar_random_official_on;
ConVar cvar_random_custom_on;
ConVar cvar_random_repeat_num;

ArrayList g_listMap;

int g_iStart;
int g_iEnd;
int g_iMapSize;
public Plugin myinfo =
{
	name = "L4D2 Next Map",
	description = "When the end of finale chapter, map will be changed automatically.",
	author = "pan0s",
	version = "1.1",
	url = ""
};

public void OnPluginStart()
{
    LoadTranslations("l4d2_nextmap.phrases");
    
    RegAdminCmd("sm_rm", HandleCmdRm, ADMFLAG_KICK);
    RegAdminCmd("sm_nm", HandleCmdNm, ADMFLAG_KICK);

    CreateConVar("l4d2_maps_version", VERSION, "L4D2 auto change next map version", CVAR_FLAGS);
    cvar_delay = CreateConVar("l4d2_maps_delay", "5.0", "过关后多少秒换图?", CVAR_FLAGS, true, 0.0);

    cvar_random_on = CreateConVar("l4d2_maps_random_on", "1", "是否随机换图?\n0=否, 1=是", CVAR_FLAGS, true, 0.0, true, 1.0);
    cvar_random_official_on = CreateConVar("14d2_random_official_on", "1", "是否包括官方地图的随机地图?\n0=否, 1=是", CVAR_FLAGS, true, 0.0, true, 1.0);
    cvar_random_custom_on = CreateConVar("l4d2_random_custom_on", "1", "是否包括三方地图的随机地图?\n0=否, 1=是", CVAR_FLAGS, true, 0.0, true, 1.0);
    cvar_random_repeat_num = CreateConVar("l4d2_custom_random_repeat_num", "0", "随机切换多少次地图后才允许切换重复的地图?\n0=从不，直到所有的地图都切换过", CVAR_FLAGS, true, 0.0);


    HookEvent("finale_win", Event_FinaleWin);

    AutoExecConfig(true, "l4d2_nextmap");

    g_listMap = new ArrayList();

    g_iStart = 0;
    if(!cvar_random_official_on.BoolValue && sizeof(g_sMaps)>14) g_iEnd = 14;
    g_iEnd = sizeof(g_sMaps) -1;
    if(!cvar_random_custom_on.BoolValue) g_iEnd = 13;
    g_iMapSize = (g_iEnd + 1 - g_iStart);
}

public void OnMapStart()
{
    char map[32];
    GetCurrentMap(map, sizeof(map));
    int mapId = FindMapId(map, MAP_NEXT);

    // push current map to map list
    if(mapId != -1)
    {
        int repeatNum = cvar_random_repeat_num.IntValue;
        if(g_listMap.Length +1 >= g_iMapSize || repeatNum > 0 && g_listMap.Length +1 >=repeatNum) g_listMap.Clear();
        g_listMap.Push(mapId);
        // PrintToServer("================MAP: %d, SIZE:%d================", mapId, g_listMap.Length);
    }
}

public int FilterRandMap()
{
    int next = GetRandomInt(g_iStart, g_iEnd);

    bool isSucceed;
    while(g_listMap.Length > 0)
    {
        for(int i = 0; i < g_listMap.Length; i++)
        {
            int map = g_listMap.Get(i);
            if(map == next)
            {
                next = GetRandomInt(g_iStart, g_iEnd);
                break;
            }
            if(i == g_listMap.Length-1) isSucceed = true;
        }
        if(isSucceed) return next;
    }
    return next;
}

public void GetRandMap(char[] buffer)
{
    // CPrintToChatAll("%d/%d, L:%d, mapsize:%d", g_iStart, g_iEnd, g_listMap.Length, g_iMapSize);
    int next = FilterRandMap();
    Format(buffer, 32, "%s", g_sMaps[next][1]);
}

public int FindMapId(const char[] map, const int type)
{
    int x = 0;

    for(int i=0; i<sizeof(g_sMaps); i++)
    {
        x = i;
        if(StrEqual(map, g_sMaps[i][type])) break;
        if(x == sizeof(g_sMaps) - 1) x = -1; // Next map not found
    }
    return x;
}

public void GetNextMapEx(char[] buffer, bool isForceRand)
{
    if(isForceRand || cvar_random_on.BoolValue) GetRandMap(buffer);
    else
    {
        char map[32];
        GetCurrentMap(map, sizeof(map));
        int mapId = FindMapId(map, MAP_PREV);
        
        if(mapId == -1)
        {
            GetRandMap(buffer);
            return;
        }
        Format(buffer, 32, "%s", g_sMaps[mapId][1]);
    }
}

void Next(bool isForceRand = false)
{
    char map[32];
    GetNextMapEx(map, isForceRand);
    float delay = cvar_delay.FloatValue;

    for(int i=1; i<= MaxClients; i++)
    {
        if(!IsValidClient(i)) continue;

        char translated[64];
        if(TranslationPhraseExists(map)) Format(translated, sizeof(translated), "%T", map, i);
        else Format(translated, sizeof(translated), "%s", map, i);
        CPrintToChat(i, "%T%T", "SYSTEM", i, "COMPLETED_FINALE", i, translated, delay);
    }

    DataPack pack = CreateDataPack();
    pack.WriteString(map);
    CreateTimer(delay, HandleTimerNextMap, pack);
}

public Action Event_FinaleWin(Event event, char[] name, bool dontBroadcast)
{
    Next();
}

public Action HandleCmdRm(int client, int args)
{
	Next(true);
}

public Action HandleCmdNm(int client, int args)
{
	Next();
}

public Action HandleTimerNextMap(Handle timer, DataPack pack)
{
    pack.Reset();
    char map[32];
    pack.ReadString(map, sizeof(map));
    ServerCommand("changelevel %s", map);
    delete pack;
}