#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS		FCVAR_NOTIFY
#define DEBUG 0

#define PLUGIN_VERSION "1.3"

public Plugin myinfo = 
{
	name = "Random MOTD pictures",
	author = "Dragokas",
	description = "Show random MOTD picture on each round start (default picture - for newly connected players)",
	version = PLUGIN_VERSION,
	url = "https://github.com/dragokas"
}

/*
	ChangeLog:

	1.0 (03-Mar-2019)
	 - Initial release

	1.1 (30-Aug-2019)
	 - Fixed case with "double" motd show
	 - Code logic is simplified
	 - "motd" ConVar is set to "0" by default because it is handled by this plugin.
	 
	1.2 (30-Aug-2019)
	 - Fixed incorrect cvar name.
	 
	1.3 (24-Jan-2020)
	 - Fixed KeyValues handles leak.

========================================================================================

	This plugin was made using source code from the following plugins.
	If I have used your code and not credited you, please let me know.

*	Thanks to "p3tsin" for "String table MOTD replacer"
	https://forums.alliedmods.net/showpost.php?p=797033&postcount=12
	
*	Thanks to "psychonic" for "Dynamic MotD Replacer"
	https://forums.alliedmods.net/showthread.php?t=147193

========================================================================================

	TODO:
	
	- find a method to detect when string table finish caching the image.

*/

enum /* Ep2vMOTDCmd */ {
	Cmd_None,
	Cmd_JoinGame,
	Cmd_ChangeTeam,
	Cmd_Impulse101,
	Cmd_MapInfo,
	Cmd_ClosedHTMLPage,
	Cmd_ChooseTeam,
};

EngineVersion g_Engine;

// For the "big" motd.
bool g_bFirstMOTDNext[MAXPLAYERS+1] = { false, ... };
ArrayList g_cmdQueue[MAXPLAYERS+1];

ConVar 	g_hCvarEnable;
ConVar 	g_hCvarDynamicmotd_big;
ConVar 	g_hCvarURL;
ConVar 	g_hCvarCount;
ConVar 	g_hCvarSelType;
ConVar 	g_hCvarTitle;

int 	g_iPictCount;
int		g_iPictIdx = 1;

bool 	g_bEnabled;
bool 	g_bBIG;
bool 	g_bIgnoreNextVGUI;
bool 	g_bPictIdxChoosen;
bool 	g_bPictReset;
bool 	g_bLateload;
bool 	g_bFirstConnect[MAXPLAYERS+1] = {true, ...};
bool 	g_bFirstReplace[MAXPLAYERS+1] = {true, ...};

char 	g_szTitle[128];
char 	g_szUrl[256];
char 	g_szBody[256];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateload = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_Engine = GetEngineVersion();

	g_hCvarEnable = CreateConVar(	"sm_motd_random_enable",			"1",											"Enable plugin (1 - On / 0 - Off)", CVAR_FLAGS );
	g_hCvarURL = CreateConVar(		"sm_motd_random_picture_address",	"http://202.189.9.186:40050/{}.jpg",	"Web-address of pictures. {} will be replaced by number (1 ... N)", CVAR_FLAGS );
	g_hCvarCount = CreateConVar(	"sm_motd_random_count",				"1",											"Total count of pictures on FTP", CVAR_FLAGS );
	g_hCvarSelType = CreateConVar(	"sm_motd_random_selection_type",	"1",											"How to select picture number: 0 - randomly, 1 - consistently", CVAR_FLAGS );
	// Welcome to Bloody Witch //^.^\\ - Have a nice day and fun :)
	g_hCvarTitle = CreateConVar(	"sm_motd_random_title",				"Welcome",										"Title of MOTD", CVAR_FLAGS );
	CreateConVar(					"sm_motd_random_version",			PLUGIN_VERSION,									"Plugin version", FCVAR_DONTRECORD );
	
	if (g_Engine == Engine_TF2)
	{
		g_hCvarDynamicmotd_big = CreateConVar("dynamicmotd_big", 		"0",	"If enabled, uses a larger MOTD window (TF2-only!). 0 - Disabled (default), 1 - Enabled", CVAR_FLAGS);
		HookConVarChange(g_hCvarDynamicmotd_big,	ConVarChanged);
		
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientConnected(i)) {
				if (g_cmdQueue[i] != null)
				{
					delete g_cmdQueue[i];
				}
				
				g_cmdQueue[i] = new ArrayList();
			}
		}
	}
	
	AutoExecConfig(true,			"sm_motd_random");
	
	HookConVarChange(g_hCvarEnable,				ConVarChanged);
	HookConVarChange(g_hCvarURL,				ConVarChanged);
	HookConVarChange(g_hCvarCount,				ConVarChanged);
	HookConVarChange(g_hCvarTitle,				ConVarChanged);

	GetCvars();
	
	RegAdminCmd("sm_motd", Cmd_MOTD, ADMFLAG_ROOT, "Change MOTD screen and open it.");
	
	if (g_bLateload)
		SelectRandomIndex();
}

public void OnAutoConfigsBuffered()
{
	ConVar hCvarMotd = FindConVar("motd_enabled");
	hCvarMotd.SetInt(0);
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bEnabled = g_hCvarEnable.BoolValue;
	g_hCvarURL.GetString(g_szUrl, sizeof(g_szUrl));
	g_hCvarTitle.GetString(g_szTitle, sizeof(g_szTitle));
	g_iPictCount = g_hCvarCount.IntValue;
	
	if (g_Engine == Engine_TF2) {
		g_bBIG = g_hCvarDynamicmotd_big.BoolValue;
	}
	
	InitHook();
}

public Action Cmd_MOTD(int client, int args)
{
	g_bPictIdxChoosen = false;
	SelectRandomIndex();
	CreateTimer(5.0, Timer_ShowMOTD, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

public Action Timer_ShowMOTD(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);
	if (client != 0 && IsClientInGame(client))
	{
		ShowLongMOTD(client, g_szTitle, "motd2");
	}
}

void MakeBody() {
	static char url[sizeof(g_szUrl)];
	static char sNum[8];
	IntToString(g_iPictIdx, sNum, sizeof(sNum));
	strcopy(url, sizeof(url), g_szUrl);
	ReplaceString(url, sizeof(url), "{}", sNum);
	
	Format(g_szBody, sizeof(g_szBody), "<html><body bgcolor=\"#000000\" scroll=\"yes\"><img src=\"%s\"></html>", url);
	
	//temporarily
	//if (g_iPictIdx == 0)
	//Format(g_szBody, sizeof(g_szBody), "<html><body bgcolor=\"#000000\" scroll=\"yes\"><img height=\"100%%\" src=\"%s\" width=\"100%%\"></html>", url);
}

void SelectRandomIndex()
{
	if (!g_bPictIdxChoosen) {
		g_bPictIdxChoosen = true;
		// do not repeat previous
		int iPrev = g_iPictIdx;
		do {
			if (g_hCvarSelType.IntValue == 0)
				g_iPictIdx = GetRandomInt(1, g_iPictCount);
			else {
				g_iPictIdx++;
				if (g_iPictIdx > g_iPictCount)
					g_iPictIdx = 1;
			}
		} while (g_iPictCount > 1 && g_iPictIdx == iPrev);
		MakeBody();
		// HTML data should be precached, so we are set it to stringtable beforehand, otherwise old data will be displayed
		//SetLongMOTD("motd", g_szBody); // default, so we don't touch it
		SetLongMOTD("motd2", g_szBody);  // instead, create new one
	}
}

void InitHook()
{
	static bool bHooked;
	
	if (g_bEnabled) {
		if (!bHooked) {
			HookEvent("round_start", 			Event_RoundStart,		EventHookMode_PostNoCopy);
			HookEvent("round_end", 				Event_RoundEnd,			EventHookMode_PostNoCopy);
			HookEvent("finale_win", 			Event_RoundEnd,			EventHookMode_PostNoCopy);
			HookEvent("mission_lost", 			Event_RoundEnd,			EventHookMode_PostNoCopy);
			HookEvent("map_transition", 		Event_RoundEnd,			EventHookMode_PostNoCopy);
			HookEvent("player_disconnect", 		Event_PlayerDisconnect, EventHookMode_Pre);
			
			if (g_Engine == Engine_CSGO)
				HookUserMessage(GetUserMessageId("VGUIMenu"), OnMsgVGUIMenu_Pb, true);
			else
				HookUserMessage(GetUserMessageId("VGUIMenu"), OnMsgVGUIMenu_Bf, true);
			
			if (g_Engine == Engine_TF2)
				AddCommandListener(closed_htmlpage, "closed_htmlpage");
			
			bHooked = true;
		}
	} else {
		if (bHooked) {
			UnhookEvent("round_start", 			Event_RoundStart,		EventHookMode_PostNoCopy);
			UnhookEvent("round_end", 			Event_RoundEnd,			EventHookMode_PostNoCopy);
			UnhookEvent("finale_win", 			Event_RoundEnd,			EventHookMode_PostNoCopy);
			UnhookEvent("mission_lost", 		Event_RoundEnd,			EventHookMode_PostNoCopy);
			UnhookEvent("map_transition", 		Event_RoundEnd,			EventHookMode_PostNoCopy);
			UnhookEvent("player_disconnect", 	Event_PlayerDisconnect, EventHookMode_Pre);
			
			if (g_Engine == Engine_CSGO)
				UnhookUserMessage(GetUserMessageId("VGUIMenu"), OnMsgVGUIMenu_Pb, true);
			else
				UnhookUserMessage(GetUserMessageId("VGUIMenu"), OnMsgVGUIMenu_Bf, true);
			
			if (g_Engine == Engine_TF2)
				RemoveCommandListener(closed_htmlpage, "closed_htmlpage");
			
			bHooked = false;
		}
	}
}

public void OnClientConnected(int client)
{
	if (g_Engine == Engine_TF2)
	{
		g_bFirstMOTDNext[client] = true;
		if (g_cmdQueue[client] != null)
		{
			delete g_cmdQueue[client];
		}
		g_cmdQueue[client] = new ArrayList();
	}
}

public void OnClientDisconnect(int client)
{
	if (g_Engine == Engine_TF2)
	{
		delete g_cmdQueue[client];
	}
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_bFirstConnect[client] = true;
	g_bFirstReplace[client] = true;
}

public void OnClientPutInServer(int client)
{
	if (client && !IsFakeClient(client))
	{
		// TODO: check for first join
		if (g_bFirstConnect[client])
		{
			ShowLongMOTD(client, g_szTitle, "motd");
		}
		else {
			CreateTimer(5.0, Timer_ShowMOTD, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public void OnMapEnd() // when use "ForceChangeLevel"
{
	PrepareNextRound();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	PrepareNextRound();
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bPictReset = false;
	SelectRandomIndex();
}

public void OnMapStart()
{
	SelectRandomIndex();
}

void PrepareNextRound()
{
	// precache new html beforehand to be able all clients have enough time to precache new image
	#if DEBUG
		PrintToConsoleAll("[MOTD] g_bPictReset ? %b", g_bPictReset);
	#endif
	
	if (!g_bPictReset) {
		g_bPictReset = true;
		g_bPictIdxChoosen = false;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			g_bFirstReplace[i] = true;
		}
	}
}

void ShowLongMOTD(int client, const char[] sTitle, const char[] sPanel)
{
	KeyValues kv = new KeyValues("data");
	kv.SetString("title", sTitle);
	kv.SetNum("type", MOTDPANEL_TYPE_INDEX);
	kv.SetString("msg", sPanel);
	ShowVGUIPanel(client, "info", kv);
	#if DEBUG
		PrintToChat(client, "Displaying MOTD.");
	#endif
	delete kv;
}

bool SetLongMOTD(const char[] sPanel, const char[] sText)
{
	int iTable = FindStringTable("InfoPanel");

	if(iTable != INVALID_STRING_TABLE) {
		int iLen = strlen(sText);
		int iStrIdx = FindStringIndex(iTable, sPanel);
		bool bLocked = LockStringTables(false);
		
		if(iStrIdx == INVALID_STRING_INDEX || iStrIdx == 65535) {   //for some reason it keeps returning 65535
			AddToStringTable(iTable, sPanel, sText, iLen);
			#if DEBUG
				PrintToChatAll("Added new string table item: %s, data: %s", sPanel, sText);
			#endif
		}
		else {
			SetStringTableData(iTable, iStrIdx, sText, iLen);
			#if DEBUG
				PrintToChatAll("Replaced string table data into: %s, data: %s", sPanel, sText);
			#endif
		}
		LockStringTables(bLocked);
		return true;
	}
	return false;
}

public void DoMOTD(any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	KeyValues kv = view_as<KeyValues>(pack.ReadCell());
	
	if (client == 0)
	{
		delete kv;
		delete pack;
		return;
	}
	
	if (g_bBIG)
	{
		kv.SetNum("customsvr", 1);
		int cmd;
		// tf2 doesn't send the cmd on the first one. it displays the mapinfo and team choice first, behind motd (so cmd is 0).
		// we can't rely on that since closing bigmotd clobbers all vgui panels, 
		if ((cmd = kv.GetNum("cmd")) != Cmd_None)
		{
			g_cmdQueue[client].Push(cmd);
			kv.SetNum("cmd", Cmd_ClosedHTMLPage);
		}
		else if (g_bFirstMOTDNext[client])
		{
			g_cmdQueue[client].Push(Cmd_ChangeTeam);
			kv.SetNum("cmd", Cmd_ClosedHTMLPage);
		}
	}

	#if DEBUG
		PrintToConsole(client, "MOTD is hijacked!");
	#endif
	
	kv.SetNum("type", MOTDPANEL_TYPE_INDEX);
	kv.SetString("msg", "motd2");
	
	if (g_szTitle[0] != '\0')
		kv.SetString("title", g_szTitle);
	
	g_bIgnoreNextVGUI = true;
	ShowVGUIPanel(client, "info", kv, true);
	
	delete kv;
	delete pack;
}

bool IsReplaceRequired(int client)
{	
	// replace MOTD only in 1 case: on map transition / new round start
	// on middle play you still should be able to see default MOTD
	
	if (g_bFirstConnect[client])
	{
		g_bFirstConnect[client] = false;
		return false;
	}
	
	if (g_bFirstReplace[client])
	{
		g_bFirstReplace[client] = false;
		return true;
	}
	return false;
}

public Action OnMsgVGUIMenu_Pb(UserMsg msg_id, Protobuf pb, const int[] players, int playersNum, bool reliable, bool init)
{
	if (g_bIgnoreNextVGUI)
	{
		g_bIgnoreNextVGUI = false;
		return Plugin_Continue;
	}
	
	if (IsFakeClient(players[0]))
		return Plugin_Continue;
	
	if (!IsReplaceRequired(players[0])) {
		#if DEBUG
			PrintToConsole(players[0], "[MOTD] Replace is forbidden !!!");
		#endif
		return Plugin_Continue;
	}
	else {
		#if DEBUG
			PrintToConsole(players[0], "[MOTD] Replace is allowed.");
		#endif
	}
	
	// we have no plans to replace MOTDs, skip it
	if (g_szTitle[0] == '\0' && g_szUrl[0] == '\0')
		return Plugin_Continue;
	
	static char buffer1[64];
	static char buffer2[256];
	
	// check menu name
	pb.ReadString("name", buffer1, sizeof(buffer1));
	if (strcmp(buffer1, "info") != 0)
		return Plugin_Continue;
	
	// make sure it's not a hidden one
	if (!pb.ReadBool("show"))
		return Plugin_Continue;
	
	int count = pb.GetRepeatedFieldCount("subkeys");
	
	// we don't one ones with no kv pairs.
	// ones with odd amount are invalid anyway
	if (count == 0)
		return Plugin_Continue;
	
	KeyValues kv = new KeyValues("data");
	for (int i = 0; i < count; ++i)
	{
		Protobuf sk = pb.ReadRepeatedMessage("subkeys", i);
		sk.ReadString("name", buffer1, sizeof(buffer1));
		sk.ReadString("str", buffer2, sizeof(buffer2));
		
		if (strcmp(buffer1, "msg") == 0 && strcmp(buffer2, "motd") != 0)
		{
			// not pulling motd from stringtable. must be a custom
			delete kv;
			return Plugin_Continue;
		}
		
		kv.SetString(buffer1, buffer2);
	}
	
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(players[0]));
	pack.WriteCell(kv);
	RequestFrame(DoMOTD, pack);
	
	return Plugin_Handled;
}

public Action OnMsgVGUIMenu_Bf(UserMsg msg_id, BfRead bf, const int[] players, int playersNum, bool reliable, bool init)
{
	if (g_bIgnoreNextVGUI)
	{
		g_bIgnoreNextVGUI = false;
		return Plugin_Continue;
	}
	
	if (IsFakeClient(players[0]))
		return Plugin_Continue;
	
	// we have no plans to replace MOTDs, skip it
	if (g_szTitle[0] == '\0' && g_szUrl[0] == '\0')
		return Plugin_Continue;
	
	static char buffer1[64];
	static char buffer2[256];
	
	// check menu name
	bf.ReadString(buffer1, sizeof(buffer1));
	if (strcmp(buffer1, "info") != 0)
		return Plugin_Continue;
	
	// make sure it's not a hidden one
	if (bf.ReadByte() != 1)
		return Plugin_Continue;
	
	int count = bf.ReadByte();
	
	// we don't one ones with no kv pairs.
	// ones with odd amount are invalid anyway
	if (count == 0)
		return Plugin_Continue;
	
	KeyValues kv = new KeyValues("data");
	for (int i = 0; i < count; ++i)
	{
		bf.ReadString(buffer1, sizeof(buffer1));
		bf.ReadString(buffer2, sizeof(buffer2));
		
		if (strcmp(buffer1, "customsvr") == 0
			|| (strcmp(buffer1, "msg") == 0 && strcmp(buffer2, "motd") != 0)
			)
		{
			// not pulling motd from stringtable. must be a custom
			delete kv;
			return Plugin_Continue;
		}
		
		kv.SetString(buffer1, buffer2);
	}
	
	if (!IsReplaceRequired(players[0])) {
		#if DEBUG
			PrintToConsole(players[0], "[MOTD] Replace is forbidden !!!");
		#endif
		delete kv;
		return Plugin_Continue;
	}
	else {
		#if DEBUG
			PrintToConsole(players[0], "[MOTD] Replace is allowed.");
		#endif
	}
	
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(players[0]));
	pack.WriteCell(kv);
	RequestFrame(DoMOTD, pack);
	
	return Plugin_Handled;
}

public Action closed_htmlpage(int client, const char[] command, int argc)
{
	if (!g_cmdQueue[client].Length)
	{
		// this one isn't for us i guess
		return Plugin_Continue;
	}
	int cmd = g_cmdQueue[client].Get(0);
	g_cmdQueue[client].Erase(0);
	
	switch (cmd)
	{
		// TF2 doesn't have joingame or chooseteam
		case Cmd_ChangeTeam:
			ShowVGUIPanel(client, "team");
		case Cmd_MapInfo:		// no server cmd equiv
			ShowVGUIPanel(client, "mapinfo");
	}
	return Plugin_Continue;
}