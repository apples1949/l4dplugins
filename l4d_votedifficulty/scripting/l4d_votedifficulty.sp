#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <geoip>

#define PLUGIN_VERSION "1.15"

#define CVAR_FLAGS		FCVAR_NOTIFY

public Plugin myinfo = 
{
	name = "[L4D] Vote difficulty (no black screen)",
	author = "Dragokas",
	description = "Vote for game difficulty with translucent menu",
	version = PLUGIN_VERSION,
	url = "https://github.com/dragokas"
};

/*
	Description:
	 - This plugin replaces annoing black screen vote for difficulty by translucent menu.
	 
	Note: it is also technically easy to append here new difficulty level.
	
	Features:
	 - no black screen.
	 - vote announcement
	 - flexible configuration of access rights
	 - all actions are logged (who vote, who tried to vote witout success, what difficulty ...)
	
	Logfile location:
	 - logs/vote_difficulty.log

	Permissions:
	 - by default, vote can be started by everybody (adjustable) if immunity and player count checks passed.
	 - ability to set minimum time to allow repeat the vote.
	 - ability to set minimum players count to allow starting the vote.
	 - set #PRIVATE_STUFF to 1 to unlock some additional options - forbid vote by name or SteamID
	
	Settings (ConVars):
	 - sm_votedifficulty_delay - def.: 60 - Minimum delay (in sec.) allowed between votes
	 - sm_votedifficulty_timeout - def.: 10 - How long (in sec.) does the vote last
	 - sm_votedifficulty_announcedelay - def.: 2.0 - Delay (in sec.) between announce and vote menu appearing
	 - sm_votedifficulty_minplayers - def.: 1 - Minimum players present in game to allow starting vote for kick
	 - sm_votedifficulty_accessflag - def.: "" - Admin flag required to start the vote (leave empty to allow for everybody)
	 - sm_votedifficulty_log - def.: 1 - Use logging? (1 - Yes / 0 - No)
	
	Commands:
	
	- sm_vd - Try to start vote for difficluty
	- sm_veto - Allow admin to veto current vote (ADMFLAG_BAN is required)
	- sm_votepass - Allow admin to bypass current vote (ADMFLAG_BAN is required)
	
	Requirements:
	 - GeoIP extension (included in SourceMod).
	
	Languages:
	 - Russian
	 - English
	
	Installation:
	 - copy smx file to addons/sourcemod/plugins/
	 - copy phrases.txt file to addons/sourcemod/translations/
	
	ChangeLog:
	1.6
	 - First release (division of another plugin).
	 
	1.9
	 - Added Expert+ and Master+ difficulties.
	You have to prepare server_hard+.cfg, server_expert+.cfg and server_default.cfg files and put them next to server.cfg file.
	By default, disabled. Use new convars to enable: "sm_votedifficulty_use_master_plus" and "sm_votedifficulty_use_expert_plus".
	 
	1.10 (12-Mar-2020)
	 - Fixed menu title phrase sometimes displayed as random language.
	 
	1.11 (08-Apr-2020)
	 - Removed binding "plus" difficulties detection to my own server cvars.
	 - Added "sm_votedifficulty_use_config_per_dif" ConVar - ability to execute per-difficulty configs, by default:
		* "cfg/server_easy.cfg"
		* "cfg/server_normal.cfg"
		* "cfg/server_hard.cfg"
		* "cfg/server_expert.cfg"
	
	1.12 (26-Nov-2021)
	 - Added missing NOTIFY flag to ConVar version.
	 - New ConVar "z_difficulty_ex" (read only!) - allows for other plugins to track extended game difficulty name string voted via this plugin. Pre-defined values are:
		* Easy
		* Normal
		* Hard
		* Hard+
		* Impossible
		* Impossible+
	 - Removed #PRIVATE_STUFF
	 - Added data/votedifficulty_vote_block.txt file allowing to block users from using vote functionality by name and SteamId.
	 
	1.13 (29-Nov-2021)
	 - Able to change difficulty when lobby is reserved (thanks to Silvers).
	 
	1.14 (13-Nov-2022)
	 - Added ConVar "sm_votedifficulty_default_set" - Do we need to set default difficulty when the server get restarted? (1 - Yes, 0 - No)
	 - Added ConVar "sm_votedifficulty_default_difficulty" - Default difficulty to use when the server get restarted
	 - Fixed warnings in SM 1.11.
	 
	1.15 (26-Nov-2022)
	 - Fixed ConVar "z_difficulty_locked" does not exist in L4D2.
	 
*/

#define EASY_CONFIG 		"server_easy.cfg"
#define NORMAL_CONFIG 		"server_normal.cfg"
#define HARD_CONFIG 		"server_hard.cfg"
#define HARD_PLUS_CONFIG	"server_hard+.cfg"
#define EXPERT_CONFIG		"server_expert.cfg"
#define EXPERT_PLUS_CONFIG	"server_expert+.cfg"
#define DEFAULT_CONFIG		"server_default.cfg"

char FILE_VOTE_BLOCK[]		= "data/votedifficulty_vote_block.txt";
//没搞懂干嘛的
ConVar g_ConVarDifficulty;
ConVar g_ConVarZDiffLocked;
ConVar g_ConVarDifficultyEx;
ConVar g_hCvarDelay;
ConVar g_hCvarTimeout;
ConVar g_hCvarAnnounceDelay;
ConVar g_hMinPlayers;
ConVar g_hCvarAccessFlag;
ConVar g_hCvarLog;
ConVar g_hCvarAllowDifficultyMenu;
ConVar g_hCvarUseMasterPlus;
ConVar g_hCvarUseExpertPlus;
ConVar g_hCvarUseConfigPerDif;
ConVar g_hCvarDefaultDif;
ConVar g_hCvarDefaultSet;

ArrayList hArrayVoteBlock;

int iLastTime[MAXPLAYERS+1];

char g_sLog[PLATFORM_MAX_PATH];
char g_sVoteResult[32];

bool g_bVeto;
bool g_bVotepass;
bool g_bVoteInProgress;
bool g_bVoteDisplayed;
bool g_bConfigExecute = true;
bool g_bDetectDifficulty = true;
bool g_bEasy, g_bNormal, g_bHard, g_bHardPlus, g_bExpert, g_bExpertPlus;
bool g_bLateload;
bool g_bFirstStart = true;
bool g_bLeft4Dead2;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLeft4Dead2 = (GetEngineVersion() == Engine_Left4Dead2);
	g_bLateload = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("l4d_votedifficulty.phrases");
	
	CreateConVar("l4d_votedifficulty_version", PLUGIN_VERSION, "Plugin version", CVAR_FLAGS | FCVAR_DONTRECORD);
	
	g_hCvarDelay = CreateConVar(			"sm_votedifficulty_delay",				"10",			"投票之间允许的最小延迟(秒)", CVAR_FLAGS );
	g_hCvarTimeout = CreateConVar(			"sm_votedifficulty_timeout",			"10",			"投票持续多长时间(秒)", CVAR_FLAGS );
	g_hCvarAnnounceDelay = CreateConVar(	"sm_votedifficulty_announcedelay",		"2.0",			"宣布和投票菜单出现之间的延迟(秒)", CVAR_FLAGS );
	g_hMinPlayers = CreateConVar(			"sm_votedifficulty_minplayers",			"1",			"最少要有多少名玩家在场才可以开始投票", CVAR_FLAGS );
	g_hCvarAccessFlag = CreateConVar(		"sm_votedifficulty_accessflag",			"",				"发起投票所需要的权限 (无内容则所有人可发起投票)", CVAR_FLAGS );
	g_hCvarLog = CreateConVar(				"sm_votedifficulty_log",				"0",			"是否启用日志? (1 - 是 / 0 - 否)", CVAR_FLAGS );
	g_hCvarUseMasterPlus = CreateConVar(	"sm_votedifficulty_use_master_plus",	"1",			"是否启用自定义难度 '困难 +' ? (1 - 是 / 0 - 否)", CVAR_FLAGS );
	g_hCvarUseExpertPlus = CreateConVar(	"sm_votedifficulty_use_expert_plus",	"1",			"是否启用自定义难度 '专家 +' ? (1 - 是 / 0 - 否)", CVAR_FLAGS );
	g_hCvarUseConfigPerDif = CreateConVar(	"sm_votedifficulty_use_config_per_dif",	"1",			"在服务器重启后是否设置默认难度? (1 - 是 / 0 - 否)", CVAR_FLAGS );
	g_hCvarDefaultSet = CreateConVar(		"sm_votedifficulty_default_set",		"0",			"你想要服务器重启时设置为插件预设的默认难度吗? (1 - 是, 0 - 否)", CVAR_FLAGS );
	g_hCvarDefaultDif = CreateConVar(		"sm_votedifficulty_default_difficulty",	"Easy",			"服务器重启后设置的默认难度", CVAR_FLAGS );
	
	AutoExecConfig(true,				"l4d_votedifficulty");
	
	g_hCvarAllowDifficultyMenu = FindConVar("sv_vote_issue_change_difficulty_allowed");
	
	RegConsoleCmd("sm_vd", CmdVoteMenu, "Show menu to vote for difficulty");
	
	RegAdminCmd("sm_vetovd", 			Command_Veto, 		ADMFLAG_VOTE, 	"允许管理员否决当前投票");
	RegAdminCmd("sm_votepassvd", 		Command_Votepass, 	ADMFLAG_VOTE, 	"允许管理员强制通过当前投票");
	
	g_ConVarDifficulty 		= FindConVar("z_difficulty");
	
	if( !g_bLeft4Dead2 )
	{
		g_ConVarZDiffLocked 	= FindConVar("z_difficulty_locked");
	}
	
	char diff[32];
	g_ConVarDifficulty.GetDefault(diff, sizeof(diff));
	g_ConVarDifficultyEx 	= CreateConVar("z_difficulty_ex",	diff,	"延长游戏难度字符串", FCVAR_DONTRECORD );
	
	if( g_bLateload )
	{
		g_bConfigExecute = false;
	}
	DetectDifficulty();
	g_bConfigExecute = true;
	
	HookConVarChange(g_ConVarDifficulty, OnDiffChanged);
	
	hArrayVoteBlock = new ArrayList(ByteCountToCells(MAX_NAME_LENGTH));
	
	BuildPath(Path_SM, g_sLog, sizeof(g_sLog), "logs/vote_difficulty.log");
	
	HookEvent("round_freeze_end", Event_RoundFreezeEnd, EventHookMode_PostNoCopy);
}

void ReadFileToArrayList(char[] sRelativePath, ArrayList list)
{
	static char sFile[PLATFORM_MAX_PATH], str[MAX_NAME_LENGTH];
	BuildPath(Path_SM, sFile, sizeof(sFile), sRelativePath);
	File hFile = OpenFile(sFile, "r");
	if( hFile == null )
	{
		SetFailState("Failed to open file: \"%s\". You are missing at installing!", sFile);
	}
	else {
		list.Clear();
		while( !hFile.EndOfFile() && hFile.ReadLine(str, sizeof(str)) )
		{
			TrimString(str);
			list.PushString(str);
		}
		delete hFile;
	}
}

public void OnMapStart()
{
	g_bHardPlus = false;
	g_bExpertPlus = false;
	ReadFileToArrayList(FILE_VOTE_BLOCK, hArrayVoteBlock);
	if( g_bFirstStart )
	{
		g_bFirstStart = false;
		if( g_hCvarDefaultSet.IntValue != 0 )
		{
			char s[16];
			g_hCvarDefaultDif.GetString(s, sizeof(s));
			g_ConVarDifficulty.SetString(s, true, true);
			g_ConVarDifficultyEx.SetString(s, false, false);
		}
	}
}

void DetectDifficulty()
{
	char sDif[32];
	g_ConVarDifficulty.GetString(sDif, sizeof sDif);
	ApplyDifficulty(sDif);
}

public void OnDiffChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if( g_bDetectDifficulty )
	{
		ApplyDifficulty(newValue);
	}
}

void ApplyDifficulty(const char[] sDifficulty)
{	
	g_bEasy = false;
	g_bNormal = false;
	g_bHard = false;
	g_bExpert = false;
	
	if( strcmp(sDifficulty, "Easy") == 0 )
	{
		g_bEasy = true;
	}
	else if( strcmp(sDifficulty, "Normal") == 0 )
	{
		g_bNormal = true;
	}
	else if( strcmp(sDifficulty, "Hard") == 0 )
	{
		g_bHard = true;
	}
	else if( strcmp(sDifficulty, "Impossible") == 0 )
	{
		g_bExpert = true;
	}
	
	if( g_hCvarUseConfigPerDif.BoolValue && g_bConfigExecute )
	{
		if( g_bEasy )
		{
			ServerCommand("exec %s", EASY_CONFIG);
		}
		else if( g_bNormal )
		{
			ServerCommand("exec %s", NORMAL_CONFIG);
		}
		else if( g_bHard )
		{
			ServerCommand("exec %s", HARD_CONFIG);
		}
		else if( g_bExpert )
		{
			ServerCommand("exec %s", EXPERT_CONFIG);
		}
		ServerExecute();
	}
}

public void Event_RoundFreezeEnd(Event event, const char[] name, bool dontBroadcast) // just in case
{
	g_bVoteInProgress = false;
	g_hCvarAllowDifficultyMenu.SetInt(0);
}

public Action CmdVoteMenu(int client, int args)
{
	if (client != 0) Menu_Difficulty(client);
	return Plugin_Handled;
}

public Action Command_Veto(int client, int args)
{
	if (g_bVoteInProgress) { // IsVoteInProgress() is not working here, sm bug?
		g_bVeto = true;
		CPrintToChatAll("%t", "veto", client);
		if (g_bVoteDisplayed) CancelVote();
		LogVoteAction(client, "[VETO]");
	}
	return Plugin_Handled;
}

public Action Command_Votepass(int client, int args)
{
	if (g_bVoteInProgress) {
		g_bVotepass = true;
		CPrintToChatAll("%t", "votepass", client);
		if (g_bVoteDisplayed) CancelVote();
		LogVoteAction(client, "[PASS]");
	}
	return Plugin_Handled;
}

public void OnAllPluginsLoaded()
{
	AddCommandListener(CheckVote, "callvote");
}

public Action CheckVote(int client, char[] command, int args)
{
	if (client == 0 || !IsClientInGame(client))
		return Plugin_Stop;

	char s[32];
	if (args >= 1) {
		GetCmdArg(1, s, sizeof(s));
		if (StrEqual(s, "ChangeDifficulty", false)) {
			if (args >= 2) {
				GetCmdArg(2, s, sizeof(s));
				VoteDifficulty(client, s);
			} 
			else {
				Menu_Difficulty(client);
			}
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}

void Menu_Difficulty(int client)
{	
	Menu menu = new Menu(MenuHandler_MenuDifficulty, MENU_ACTIONS_DEFAULT);	
	menu.SetTitle(Translate(client, "%t", "MenuVoteDifficulty"));
//	menu.AddItem("Easy", 		Translate(client, "%s%t", g_bEasy ? 			"[★] " : "", "Easy"),			g_bEasy ?			ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("Normal", 		Translate(client, "%s%t", g_bNormal ? 			"[★] " : "", "Normal"),		g_bNormal ?			ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("Hard", 		Translate(client, "%s%t", g_bHard ? 			"[★] " : "", "Hard"),			g_bHard ?			ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if ( g_hCvarUseMasterPlus.BoolValue )
	{
		menu.AddItem("Hard+", 		Translate(client, "%s%t", g_bHardPlus ? 	"[★] " : "", "Hard+"),			g_bHardPlus ?		ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	menu.AddItem("Impossible", 	Translate(client, "%s%t", g_bExpert ? 			"[★] " : "", "Impossible"),	g_bExpert ?			ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	if ( g_hCvarUseExpertPlus.BoolValue )
	{
		menu.AddItem("Impossible+",	Translate(client, "%s%t", g_bExpertPlus ?	"[★] " : "", "Impossible+"),	g_bExpertPlus ?		ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MenuDifficulty(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
		
		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				Menu_Difficulty(param1);
		
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			VoteDifficulty(param1, sItem);
		}
	}
	return 0;
}

void VoteDifficulty(int client, char[] sDifficulty)
{
	static int iClients;
	
	LogVoteAction(client, "[TRY] Difficulty: %s.", sDifficulty);
	
	if (IsVoteInProgress() || g_bVoteInProgress) {
		CPrintToChat(client, "%t", "other_vote");
		LogVoteAction(client, "[DENY] Difficulty: %s. Reason: another vote is in progress.", sDifficulty);
		return;
	}
	else {
		strcopy(g_sVoteResult, sizeof(g_sVoteResult), sDifficulty);
	}
	
	iClients = GetRealClientCount();
	
	if (iClients < g_hMinPlayers.IntValue) {
		CPrintToChat(client, "%t", "not_enough_players", g_hMinPlayers.IntValue);
		LogVoteAction(client, "[DENY] Difficulty: %s. Reason: Not enough players. Now: %i, required: %i", sDifficulty, iClients, g_hMinPlayers.IntValue);
		return;
	}
	
	if (!HasVoteAccess(client)) {
		CPrintToChat(client, "%t", "access_denied");
		LogVoteAction(client, "[DENY] Difficulty: %s. Reason: client has no sufficient access flags.", sDifficulty);
		return;
	}
	
	if (!IsClientRootAdmin(client)) {
	
		if (iLastTime[client] != 0) // time limit
		{
			if (iLastTime[client] + g_hCvarDelay.IntValue > GetTime()) {
				LogVoteAction(client, "[DENY] Difficulty: %s. Reason: too often.", sDifficulty);
				CPrintToChat(client, "%t", "too_often"); // "You can't vote too often!"
				return;
			}
		}
		iLastTime[client] = GetTime();
		
		if( InDenyFile(client, hArrayVoteBlock) )
		{
			LogVoteAction(client, "[DENY] Reason: player is in deny list.");
			return;
		}
	}
	
	if (iClients == 1) { // 1 player -> no vote needed
		Handler_PostVoteAction(true);
		return;
	}
	
	LogVoteAction(client, "[STARTED] Difficulty: %s.", sDifficulty);
	
	CPrintToChatAll("%t", "vote_started", client, sDifficulty); // %N is started vote for difficulty: {1}
	PrintToServer("%N started the vote for difficulty.", client);
	PrintToConsoleAll("%N started the vote for difficulty.", client);
	
	Menu menu = new Menu(Handle_VoteDifficulty, MenuAction_DisplayItem | MenuAction_Display);
	menu.AddItem(sDifficulty, "Yes");
	menu.AddItem("", "No");
	menu.ExitButton = false;
	g_bVotepass = false;
	g_bVeto = false;
	g_bVoteDisplayed = false;
	CreateTimer(g_hCvarAnnounceDelay.FloatValue, Timer_VoteDelayed, menu);
	CPrintHintTextToAll("%t", "vote_started_announce", g_sVoteResult);
}

bool InDenyFile(int client, ArrayList list)
{
	static char sName[MAX_NAME_LENGTH], str[MAX_NAME_LENGTH];
	static char sSteam[64];
	
	GetClientAuthId(client, AuthId_Steam2, sSteam, sizeof(sSteam));
	GetClientName(client, sName, sizeof(sName));
	
	for( int i = 0; i < list.Length; i++ )
	{
		list.GetString(i, str, sizeof(str));
	
		if( strncmp(str, "STEAM_", 6, false) == 0 )
		{
			if( strcmp(sSteam, str, false) == 0 )
			{
				return true;
			}
		}
		else {
			if( StrContains(str, "*") ) // allow masks like "Dan*" to match "Danny and Danil"
			{
				ReplaceString(str, sizeof(str), "*", "");
				if( StrContains(sName, str, false) != -1 )
				{
					return true;
				}
			}
			else {
				if( strcmp(sName, str, false) == 0 )
				{
					return true;
				}
			}
		}
	}
	return false;
}

Action Timer_VoteDelayed(Handle timer, Menu menu)
{
	if (g_bVotepass || g_bVeto) {
		Handler_PostVoteAction(g_bVotepass);
		delete menu;
	}
	else {
		if (!IsVoteInProgress()) {
			g_bVoteInProgress = true;
			menu.DisplayVoteToAll(g_hCvarTimeout.IntValue);
			g_bVoteDisplayed = true;
		}
		else {
			delete menu;
		}
	}
	return Plugin_Continue;
}

int GetRealClientCount() {
	int cnt;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i)) cnt++;
	return cnt;
}

public int Handle_VoteDifficulty(Menu menu, MenuAction action, int param1, int param2)
{
	static char display[64], buffer[255], sDif[32];
	
	switch (action)
	{
		case MenuAction_End: {
			if (g_bVoteInProgress && g_bVotepass) { // in case vote is passed with CancelVote(), so MenuAction_VoteEnd is not called.
				Handler_PostVoteAction(true);
			}
			g_bVoteInProgress = false;
			delete menu;
		}
		
		case MenuAction_VoteEnd: // 0=yes, 1=no
		{
			if ((param1 == 0 || g_bVotepass) && !g_bVeto) {
				Handler_PostVoteAction(true);
			}
			else {
				Handler_PostVoteAction(false);
			}
			g_bVoteInProgress = false;
		}
		case MenuAction_DisplayItem:
		{
			menu.GetItem(param2, "", 0, _, display, sizeof(display));
			Format(buffer, sizeof(buffer), "%T", display, param1);
			return RedrawMenuItem(buffer);
		}
		case MenuAction_Display:
		{
			menu.GetItem(0, sDif, sizeof(sDif));
			SetGlobalTransTarget(param1);
			Format(buffer, sizeof(buffer), "%t", "vote_started_announce", sDif);
			menu.SetTitle(buffer);
		}
	}
	return 0;
}

//#include <left4dhooks>

void Handler_PostVoteAction(bool bVoteSuccess)
{
	if( bVoteSuccess ) {
		int oldval;
		if( !g_bLeft4Dead2 )
		{
			oldval = g_ConVarZDiffLocked.IntValue;
			g_ConVarZDiffLocked.SetInt(0); // prevents lock by lobby reservation, for test, enter: mm_dedicated_force_servers "IP:PORT"
		}
	
		ServerCommand("exec %s", DEFAULT_CONFIG);
		ServerExecute();
		
		//L4D_LobbyUnreserve();
		//PrintToChatAll("L4D_LobbyUnreserve executed.");
		
		g_bEasy = false;
		g_bNormal = false;
		g_bHard = false;
		g_bExpert = false;
		g_bHardPlus = false;
		g_bExpertPlus = false;
		
		g_bDetectDifficulty = false;
		
		if (StrEqual(g_sVoteResult, "Easy", false))
		{
			g_ConVarDifficulty.SetString("Easy", true, true);
			g_ConVarDifficultyEx.SetString("Easy", false, false);
			DetectDifficulty();
		}
		else if (StrEqual(g_sVoteResult, "Normal", false))
		{
			g_ConVarDifficulty.SetString("Normal", true, true);
			g_ConVarDifficultyEx.SetString("Normal", false, false);
			DetectDifficulty();
		}
		else if (StrEqual(g_sVoteResult, "Hard", false))
		{
			g_ConVarDifficulty.SetString("Hard", true, true);
			g_ConVarDifficultyEx.SetString("Hard", false, false);
			DetectDifficulty();
		}
		else if (StrEqual(g_sVoteResult, "Impossible", false))
		{
			g_ConVarDifficulty.SetString("Impossible", true, true);
			g_ConVarDifficultyEx.SetString("Impossible", false, false);
			DetectDifficulty();
		}
		else if (StrEqual(g_sVoteResult, "Hard+", false))
		{
			g_bHardPlus = true;
			g_ConVarDifficulty.SetString("Hard", true, true);
			g_ConVarDifficultyEx.SetString("Hard+", false, false);
			ServerCommand("exec %s", HARD_PLUS_CONFIG);
			ServerExecute();
			g_bDetectDifficulty = true;
		}
		else if (StrEqual(g_sVoteResult, "Impossible+", false))
		{
			g_bDetectDifficulty = false;
			g_bExpertPlus = true;
			g_ConVarDifficulty.SetString("Impossible", true, true);
			g_ConVarDifficultyEx.SetString("Impossible+", false, false);
			ServerCommand("exec %s", EXPERT_PLUS_CONFIG);
			ServerExecute();
		}
		g_bDetectDifficulty = true;
		
		if( !g_bLeft4Dead2 )
		{
			g_ConVarZDiffLocked.SetInt(oldval);
		}
		
		LogVoteAction(0, "[ACCEPTED] Difficulty: %s.", g_sVoteResult);
		CPrintToChatAll("%t", "vote_success", g_sVoteResult);
	}
	else {
		LogVoteAction(0, "[NOT ACCEPTED] Difficulty: %s.", g_sVoteResult);
		CPrintToChatAll("%t", "vote_failed");
	}
	g_bVoteInProgress = false;
}

bool HasVoteAccess(int client)
{
	int iUserFlag = GetUserFlagBits(client);
	if (iUserFlag & ADMFLAG_ROOT != 0) return true;
	
	char sReq[32];
	g_hCvarAccessFlag.GetString(sReq, sizeof(sReq));
	if( sReq[0] == 0 ) return true;
	
	int iReqFlags = ReadFlagString(sReq);
	return (iUserFlag & iReqFlags != 0);
}

void LogVoteAction(int client, const char[] format, any ...)
{
	if (!g_hCvarLog.BoolValue)
		return;
	
	static char sSteam[64];
	static char sIP[32];
	static char sCountry[4];
	static char sName[MAX_NAME_LENGTH];
	static char buffer[256];
	
	VFormat(buffer, sizeof(buffer), format, 3);
	
	if (client != 0) {
		GetClientAuthId(client, AuthId_Steam2, sSteam, sizeof(sSteam));
		GetClientName(client, sName, sizeof(sName));
		GetClientIP(client, sIP, sizeof(sIP));
		GeoipCode3(sIP, sCountry);
		LogToFile(g_sLog, "%s %s (%s | [%s] %s)", buffer, sName, sSteam, sCountry, sIP);
	}
	else {
		LogToFile(g_sLog, buffer);
	}
}

stock char[] Translate(int client, const char[] format, any ...)
{
	static char buffer[192];
	SetGlobalTransTarget(client);
	VFormat(buffer, sizeof(buffer), format, 3);
	return buffer;
}

stock void ReplaceColor(char[] message, int maxLen)
{
    ReplaceString(message, maxLen, "{white}", "\x01", false);
    ReplaceString(message, maxLen, "{cyan}", "\x03", false);
    ReplaceString(message, maxLen, "{orange}", "\x04", false);
    ReplaceString(message, maxLen, "{green}", "\x05", false);
}

stock void CPrintToChat(int iClient, const char[] format, any ...)
{
    static char buffer[192];
    SetGlobalTransTarget(iClient);
    VFormat(buffer, sizeof(buffer), format, 3);
    ReplaceColor(buffer, sizeof(buffer));
    PrintToChat(iClient, "\x01%s", buffer);
}

stock void CPrintToChatAll(const char[] format, any ...)
{
    static char buffer[192];
    for( int i = 1; i <= MaxClients; i++ )
    {
        if( IsClientInGame(i) && !IsFakeClient(i) )
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            ReplaceColor(buffer, sizeof(buffer));
            PrintToChat(i, "\x01%s", buffer);
        }
    }
}

stock void CPrintHintTextToAll(const char[] format, any ...)
{
    static char buffer[192];
    for( int i = 1; i <= MaxClients; i++ )
    {
        if( IsClientInGame(i) && !IsFakeClient(i) )
        {
            SetGlobalTransTarget(i);
            VFormat(buffer, sizeof(buffer), format, 2);
            PrintHintText(i, buffer);
        }
    }
}

stock bool IsClientRootAdmin(int client)
{
	return ((GetUserFlagBits(client) & ADMFLAG_ROOT) != 0);
}