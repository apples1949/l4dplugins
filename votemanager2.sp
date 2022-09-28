#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION "1.5.6c"
#define CVAR_FLAGS FCVAR_NOTIFY
#define TEAM_SPECTATOR 1
#define TEAM_INFECTED 3
#define VOTE_DELAY 10.0

// cvar handles

ConVar lobbyAccess, difficultyAccess, levelAccess, restartAccess, kickAccess, 
       kickImmunity, sendToLog, vetoAccess, passVoteAccess, voteTimeout, voteNoTimeoutAccess, 
       customAccess, voteNotify, survivalMap, survivalLobby, survivalRestart, tankKickImmunity;

bool inVoteTimeout[MAXPLAYERS + 1], hasVoted[MAXPLAYERS + 1], playerVoted[MAXPLAYERS + 1];

// custom vote variables

bool customVoteInProgress = false;  
char customVote[128] = "";
int customVotesMax, customYesVotes, customNoVotes;

// exploit fix

bool voteInProgress = false;
bool postVoteDelay = false;

public Plugin myinfo =
{
	name            = "L4D Vote Manager 2",
	author          = "Madcap",
	description     = "Control permissions on voting and make voting respect admin levels.",
	version         = PLUGIN_VERSION,
	url             = "https://forums.alliedmods.net/showthread.php?p=2788129#post2788129"
};

public void OnPluginStart()
{
	CreateConVar("l4d_votemanager", PLUGIN_VERSION, "Version number for Vote Manager 2 Plugin", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	lobbyAccess         = CreateConVar("l4d_vote_lobby_access",           "",  "开始返回大厅投票需要什么权限", CVAR_FLAGS);
	difficultyAccess    = CreateConVar("l4d_vote_difficulty_access",      "",  "开始更改难度投票需要什么权限", CVAR_FLAGS);
	levelAccess         = CreateConVar("l4d_vote_level_access",           "",  "开始更改地图投票需要什么权限", CVAR_FLAGS);
	restartAccess       = CreateConVar("l4d_vote_restart_access",         "",  "启动重置地图投票需要什么权限", CVAR_FLAGS);
	kickAccess          = CreateConVar("l4d_vote_kick_access",            "",  "开始投票踢人需要什么权限", CVAR_FLAGS);
	kickImmunity        = CreateConVar("l4d_vote_kick_immunity",          "1", "管理员无法被踢", CVAR_FLAGS, true, 0.0, true, 1.0);
	vetoAccess          = CreateConVar("l4d_vote_veto_access",            "z", "否决投票需要什么权限", CVAR_FLAGS);
	passVoteAccess      = CreateConVar("l4d_vote_pass_access",            "z", "通过投票需要什么权限", CVAR_FLAGS);
	voteTimeout         = CreateConVar("l4d_vote_timeout",                "0", "玩家必须在投票之间等待(超时)这么多秒. 0 = no timeout", CVAR_FLAGS, true, 0.0);
	voteNoTimeoutAccess = CreateConVar("l4d_vote_no_timeout_access",      "",  "没有投票超时需要什么权限.", CVAR_FLAGS);
	sendToLog           = CreateConVar("l4d_vote_log",                    "0", "记录投票", CVAR_FLAGS, true, 0.0, true, 1.0);
	customAccess        = CreateConVar("l4d_custom_vote_access",          "z", "调用自定义投票需要什么权限.", CVAR_FLAGS);
	voteNotify          = CreateConVar("l4d_vote_notify_access",          "",  "谁会看到某些与投票相关的通知. 如果空白每个人都看到他们.", CVAR_FLAGS);
	survivalMap         = CreateConVar("l4d_vote_surv_map_access",        "",  "切换生存地图需要什么权限.", CVAR_FLAGS);
	survivalRestart     = CreateConVar("l4d_vote_surv_restart_access",    "",  "重新启动生存地图需要什么权限.", CVAR_FLAGS);
	survivalLobby       = CreateConVar("l4d_vote_surv_lobby_access",      "z", "在生存地图上返回大厅需要什么权限.", CVAR_FLAGS);
	tankKickImmunity    = CreateConVar("l4d_vote_tank_kick_immunity",     "1", "坦克玩家不会被踢.", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	RegConsoleCmd("custom_vote", CustomVote_Handler);
	RegConsoleCmd("Vote", Vote_Handler);
	RegConsoleCmd("callvote", Callvote_Handler);
	RegConsoleCmd("veto", Veto_Handler);
	RegConsoleCmd("passvote", PassVote_Handler);

	HookEvent("vote_started", EventVoteStart);
	HookEvent("vote_passed", EventVoteEnd);
	HookEvent("vote_failed", EventVoteEnd);
	
	AutoExecConfig(true, "l4d_votemanager");
}

void Notify(int client, char[] format, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), format, 3);

	char notify[16];
	GetConVarString(voteNotify, notify, sizeof(notify)); 

	for(int i = 1; i <= MaxClients; i++)
	{
		if  (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && i != client && (strlen(notify) == 0 || GetUserFlagBits(i) & ReadFlagString(notify) != 0))
		{
			PrintToChat(i, buffer);
		}
	}
	
	if (client > 0 && IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client))
	{
		PrintToChat(client, buffer);
	}
}

public void EventVoteStart(Event event, const char[] name, bool dontBroadcast)
{
	voteInProgress = true;
	for(int i = 0; i < sizeof(playerVoted); i++)
	{
		playerVoted[i] = false;
	}
}

public void EventVoteEnd(Event event, const char[] name, bool dontBroadcast)
{
	voteInProgress = false;
	postVoteDelay = true;
	CreateTimer(VOTE_DELAY, VoteDelay);		
}

public Action VoteDelay(Handle timer, any client)
{
	postVoteDelay = false;
	return Plugin_Handled;
}

public void OnMapStart()
{
	for(int i = 0; i < sizeof(inVoteTimeout); i++)
	{
		inVoteTimeout[i] = false;
	}
		
	customVoteInProgress = false;
	voteInProgress = false;
	postVoteDelay = false;
}

public void OnClientConnected(int client)
{
	inVoteTimeout[client] = false;
}

void LogVote(int client, char[] format, any ...)
{
	if (GetConVarBool(sendToLog))
	{
		char buffer[512];
		VFormat(buffer, sizeof(buffer), format, 3);
		char name[MAX_NAME_LENGTH] = "";
		char player_authid[32] = "";
			
		if (client == 0)
		{
			name = "Server";
			player_authid = "ServerID";
		}
		else
		{
			GetClientName(client, name, sizeof(name));
			GetClientAuthId(client, AuthId_Steam2, player_authid, sizeof(player_authid));
		}
	
		LogMessage("<%s><%s> %s", name, player_authid, buffer);
	}
}

int hasVoteAccess(int client, char voteName[32])
{
	if (client == 0)
	{
		return true;
	}

	char acclvl[16];
	char gmode[32];
	
	GetConVarString(FindConVar("mp_gamemode"), gmode, sizeof(gmode));

	bool survival = false;
	if (strcmp(gmode, "survival", false) == 0)
	{
		survival = true;
	}
		
	if (strcmp(voteName, "ReturnToLobby", false) == 0)
	{
		if (survival)
		{
			GetConVarString(survivalLobby, acclvl, sizeof(acclvl));
		}
		else
		{
			GetConVarString(lobbyAccess, acclvl, sizeof(acclvl));
		}
	}

	else if (strcmp(voteName, "ChangeDifficulty", false) == 0) 
	{
		GetConVarString(difficultyAccess, acclvl, sizeof(acclvl));
	}

	else if (strcmp(voteName, "ChangeMission", false) == 0) 
	{
		GetConVarString(levelAccess, acclvl, sizeof(acclvl));
	}

	else if (strcmp(voteName, "RestartGame", false) == 0) 
	{
		if (survival)
		{
			GetConVarString(survivalRestart, acclvl, sizeof(acclvl));
		}
		else
		{
			GetConVarString(restartAccess, acclvl, sizeof(acclvl));
		}
	}

	else if (strcmp(voteName, "Kick", false) == 0) 
	{
		GetConVarString(kickAccess, acclvl, sizeof(acclvl));
	}

	else if (strcmp(voteName, "Veto", false) == 0) 
	{
		GetConVarString(vetoAccess, acclvl, sizeof(acclvl));
	}

	else if (strcmp(voteName, "PassVote", false) == 0) 
	{
		GetConVarString(passVoteAccess, acclvl, sizeof(acclvl));
	}

	else if (strcmp(voteName, "Custom", false) == 0) 
	{
		GetConVarString(customAccess, acclvl, sizeof(acclvl));
	}

	else if (strcmp(voteName, "ChangeChapter", false) == 0) 
	{
		GetConVarString(survivalMap, acclvl, sizeof(acclvl));	
	}

	else return false;

	if (strlen(acclvl) == 0)
	{
		return true;
	}

	if (GetUserFlagBits(client) & ReadFlagString(acclvl) == 0)
	{
		return false;
	}

	return true;
}

int isInVoteTimeout(int client)
{
	if (GetConVarBool(voteTimeout))
	{
		char acclvl[16];
		GetConVarString(voteNoTimeoutAccess, acclvl, sizeof(acclvl));
	
		if (GetUserFlagBits(client) & ReadFlagString(acclvl) != 0)
		{
			return false;
		}
			
		return inVoteTimeout[client];	
	}
	
	return false;
}

int isValidVote(char voteName[32])
{
	if	((strcmp(voteName, "Kick", false) == 0) ||
		(strcmp(voteName, "ReturnToLobby", false) == 0) ||
		(strcmp(voteName, "ChangeDifficulty", false) == 0) ||
		(strcmp(voteName, "ChangeMission", false) == 0) ||
		(strcmp(voteName, "RestartGame", false) == 0) ||
		(strcmp(voteName, "Custom", false) == 0) ||
		(strcmp(voteName, "ChangeChapter", false) == 0))
	{	
		return true;
	}
		
	return false;	
}

public Action Callvote_Handler(int client, int args)
{
	char voteName[32];
	char initiatorName[MAX_NAME_LENGTH];
	GetClientName(client, initiatorName, sizeof(initiatorName));
	GetCmdArg(1, voteName, sizeof(voteName));
	
	if (voteInProgress)
	{
		PrintToChat(client, "\x04[VOTE]\x01在当前投票结束之前，你不能开始投票。");
		LogVote(client, " <%s> 尝试发起一个投票但已有一个投票正在进行中.", voteName);
		return Plugin_Handled;
	}

	if (postVoteDelay)
	{
		PrintToChat(client, "\x04[VOTE]\x01请在 \x03%f 秒 \x01再投票.", VOTE_DELAY);
		LogVote(client, " <%s>尝试发起一个投票但离他上一次投票时间太短", voteName);
		return Plugin_Handled;
	}
	
	if (!isValidVote(voteName))
	{
		PrintToChat(client,"\x04[VOTE]\x01无效投票类型: \x03 %s", voteName);
		LogVote(client, "尝试发起一个无效投票类型: <%s>", voteName);
		return Plugin_Handled;
	}

	if (isInVoteTimeout(client))
	{
		LogVote(client, "无法发起一个<%s>投票 原因:超时", voteName);
		PrintToChat(client, "\x04[VOTE]\x01你必须在\x03%.1f秒\x01后发起一次投票.", GetConVarFloat(voteTimeout));
		return Plugin_Handled;		
	}

	if (hasVoteAccess(client, voteName))
	{
		inVoteTimeout[client] = true;
		
		float timeout = GetConVarFloat(voteTimeout);
		if (timeout > 0.0)
		{
			CreateTimer(timeout, TimeOutOver, client);
		}

		if (strcmp(voteName, "Kick", false) == 0)
		{
			return Kick_Vote_Logic(client, args);
		}
		
		if (strcmp(voteName, "Custom", false) == 0)
		{
			return Custom_Vote_Logic(client, args);
		}

		LogVote(client, "started a <%s> vote", voteName);
		Notify(client, "\x04[VOTE] \x03%s\x01发起了一个\x03%s \x01投票.", initiatorName, voteName);
		return Plugin_Continue;
	}
	else
	{
		LogVote(client, "一个<%s>投票被阻止 原因:访问被拒绝", voteName);
		Notify(client, "\x04[VOTE]\x03%s\x01尝试发起一个\x03%s \x01投票！访问被拒绝！", initiatorName, voteName);
		return Plugin_Handled;
	}
}


public Action TimeOutOver(Handle timer, any client)
{
	inVoteTimeout[client] = false;
	return Plugin_Handled;
}

public Action Kick_Vote_Logic(int client, int args)
{
	char initiatorName[MAX_NAME_LENGTH];
	GetClientName(client, initiatorName, sizeof(initiatorName));

	char arg2[12];
	GetCmdArg(2, arg2, sizeof(arg2));
	int target = GetClientOfUserId(StringToInt(arg2));

	if (target <= 0 || target > MaxClients || !IsClientInGame(target))
	{
		LogVote(client, "一次对<%s>的踢出投票被阻止 原因:目标无效", arg2);
		Notify(client, "\x04[VOTE]\x03 %s\x01尝试投票踢出\x03%s\x01但目标玩家不存在", initiatorName, arg2);
		PrintToChat(client, "\x04[VOTE]\x01如果你想手动发起一次踢出玩家投票，指令格式为: 'callvote kick <玩家id>'");
		return Plugin_Handled;
	}

	char targetName[MAX_NAME_LENGTH];
	GetClientName(target, targetName, sizeof(targetName));

	if (GetConVarBool(tankKickImmunity) && GetClientTeam(target) == TEAM_INFECTED && IsPlayerAlive(target))
	{
		char model[128];
		GetClientModel(target, model, sizeof(model));
		if (StrContains(model, "hulk", false) > 0)
		{
			LogVote(client, "一次对<%s>的踢出投票被阻止 原因: 该玩家正在扮演坦克", targetName);
			Notify(client,"\x04[VOTE]\x03%s\x01尝试对\x03%s\x01发起一次踢出投票但坦克玩家无法被踢出", initiatorName, targetName);
			return Plugin_Handled;
		}
	}
	
	if (GetClientTeam(client) == TEAM_SPECTATOR)
	{
		LogVote(client, "一次对<%s>的踢出投票被阻止 原因:旁观无法发起踢出玩家投票 ", targetName);
		Notify(client, "\x04[VOTE]\x03%s\x01尝试对\x03%s\x01发起一次踢出玩家投票但旁观无法踢出玩家", initiatorName, targetName);
		return Plugin_Handled;
	}

	if (GetConVarBool(kickImmunity))
	{
		AdminId clientAdminId = GetUserAdmin(client);
		AdminId targetAdminId = GetUserAdmin(target);
	
		if (isAdmin(targetAdminId))
		{
			if (!CanAdminTarget(clientAdminId, targetAdminId))
			{
				LogVote(client, "一次对<%s>的踢出投票被阻止 原因: 目标玩家豁免被踢", targetName);
				Notify(client, "\x04[VOTE]\x03%s\x01尝试对\x03%s\x01发起一次踢出投票但失败了", initiatorName, targetName);
				return Plugin_Handled;
			}
		}
	}
	
	LogVote(client, "发起一次对<%s>的踢出投票.", targetName);
	Notify(client, "\x04[VOTE]\x03%s\x01is starting a Kick Vote against\x03%s", initiatorName, targetName);
	return Plugin_Continue;
}

bool isAdmin(AdminId id)
{ 
	return !(id == INVALID_ADMIN_ID);
}

public Action Veto_Handler(int client, int args)
{
	if (!voteInProgress || postVoteDelay) 
	{
		LogVote(client, "投票被否决但没有正在进行的投票");
		if (client != 0)
		{
			PrintToChat(client, "\x04[VOTE]\x01没有可否决的投票"); 
		}
		
		return Plugin_Handled;
	}
	
	if (client == 0)
	{
		Veto();
	
		LogVote(client, "否决了一场投票");
		Notify(0, "\x04 [VOTE]\x01服务器否决了这个投票");
		return Plugin_Continue;
	}

	char vetoerName[MAX_NAME_LENGTH];	
	GetClientName(client, vetoerName, sizeof(vetoerName));
	
	if (hasVoteAccess(client, "Veto"))
	{	
		Veto();
		
		LogVote(client, "否决了一场投票");
		Notify(client, "\x04 [VOTE]\x03%s\x01否决了一场投票", vetoerName);
		return Plugin_Continue;
	}

	LogVote(client, "否决一场投票失败 原因:访问被拒绝 ");
	Notify(client, "\x04[VOTE]\x03%s\x01尝试否决一场投票但他没有权限", vetoerName);
	return Plugin_Handled;
}

void Veto()
{
	int count = MaxClients;
	for(int i = 1; i <= count; i++)
	{
		if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
		{
			FakeClientCommandEx(i, "Vote No");
		}
	}
}

public Action PassVote_Handler(int client, int args)
{
	if (!voteInProgress || postVoteDelay) 
	{
		LogVote(client, "强制通过了一场投票但没有可强制通过的投票");
		if (client != 0)
		{
			PrintToChat(client, "\x04[VOTE]\x01没有可强制通过的投票"); 
		}
		return Plugin_Handled;
	}
	
	if (client == 0)
	{
		PassVote();
	
		LogVote(client, "已通过投票");
		Notify(0, "\x04[VOTE]\x01服务器通过了这个投票");
		return Plugin_Continue;
	}

	char passerName[MAX_NAME_LENGTH];	
	GetClientName(client, passerName, sizeof(passerName));
	
	if (hasVoteAccess(client, "PassVote"))
	{	
		PassVote();
		
		LogVote(client, "已通过投票");
		Notify(client, "\x04[VOTE]\x03%s\x01已通过这个投票", passerName);
		return Plugin_Continue;
	}

	LogVote(client, "否决一场投票失败 原因:访问被拒绝");
	Notify(client, "\x04[VOTE]\x03%s\x01尝试强制通过一场投票但他没有权限", passerName);
	return Plugin_Handled;
}

void PassVote()
{
	int count = MaxClients;
	for(int i = 1; i <= count; i++)
	{
		if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
		{
			FakeClientCommandEx(i, "Vote Yes");
		}
	}
}

public Action CustomVote_Handler(int client, int args)
{
	char initiatorName[MAX_NAME_LENGTH];
	GetClientName(client, initiatorName, sizeof(initiatorName));
	
	if (!voteInProgress)
	{
		int leng1 = GetCmdArg(1, customVote, sizeof(customVote));
		
		if (leng1 == 0)
		{
			PrintToConsole(client, "Usage: custom_vote \"<question to vote on>\" ");
			return Plugin_Handled;
		}
		
		int i;
		customVotesMax = 0;
		for(i = 1; i < sizeof(hasVoted); i++)
		{
			hasVoted[i] = true;
			
			if (i <= MaxClients && IsClientConnected(i) && !IsFakeClient(i))
			{
				customVotesMax++;
				hasVoted[i] = false;
			}
		}
		
		customNoVotes = 0;
		customYesVotes = 0;

		LogVote(client, "attempting custom vote. Issue: <%s> ", customVote);
		
		FakeClientCommandEx(client, "callvote Custom"); 
	}
	else
	{
		LogVote(client, "尝试发起一场自定义投票但一场投票正在进行中");
		Notify(client, "\x04[VOTE]\x03%s\x01尝试发起一场自定义投票但一场投票正在进行中", initiatorName);
	}
	
	return Plugin_Handled;
}

public Action Custom_Vote_Logic(int client, int args)
{

	char initiatorName[MAX_NAME_LENGTH];
	GetClientName(client, initiatorName, sizeof(initiatorName));

	if (!customVoteInProgress)
	{
		Handle voteEvent = CreateEvent("vote_started");
		SetEventString(voteEvent, "issue", "#L4D_TargetID_Player");
		SetEventString(voteEvent, "param1", customVote);
		SetEventInt(voteEvent, "team", -1);
		SetEventInt(voteEvent, "initiator", GetClientUserId(client));
		FireEvent(voteEvent);
		
		Handle voteChangeEvent = CreateEvent("vote_changed");
		SetEventInt(voteChangeEvent, "yesVotes", 0);
		SetEventInt(voteChangeEvent, "noVotes", 0);
		SetEventInt(voteChangeEvent, "potentialVotes", customVotesMax);
		FireEvent(voteChangeEvent);

		FakeClientCommandEx(client, "Vote Yes");
		
		LogVote(client, "启动了自定义投票");
		Notify(client, "\x04[VOTE]\x03%s\x01发起了一场自定义投票", initiatorName);
		
		CreateTimer(30.0, EndCustomVote, client);
		
		customVoteInProgress = true;
	}	
	
	return Plugin_Handled;
}

public Action Vote_Handler(int client, int args)
{

	char voterName[MAX_NAME_LENGTH];
	GetClientName(client, voterName, sizeof(voterName));
	
	char vote[8];
	GetCmdArg(1, vote, sizeof(vote));

	if (customVoteInProgress && !hasVoted[client])
	{
		if (strcmp(vote, "Yes", true) == 0)
		{
			customYesVotes++;
		}
		else if (strcmp(vote, "No", true) == 0)
		{
			customNoVotes++;
		}
		
		hasVoted[client] = true;

		Handle voteChangeEvent = CreateEvent("vote_changed");
		SetEventInt(voteChangeEvent, "yesVotes", customYesVotes);
		SetEventInt(voteChangeEvent, "noVotes", customNoVotes);
		SetEventInt(voteChangeEvent, "potentialVotes", customVotesMax);
		FireEvent(voteChangeEvent);

		if ((customYesVotes + customNoVotes) == customVotesMax)
		{
			CreateTimer(2.0, EndCustomVote, client);
		}
	
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action EndCustomVote(Handle timer, any client)
{
	if (customVoteInProgress)
	{
		Handle voteEndEvent = CreateEvent("vote_ended");
		FireEvent(voteEndEvent);
	
		if (customYesVotes > customNoVotes)
		{
			char param1[128];
			Format(param1, sizeof(param1), "Vote succeeds: %s", customVote);
		
			Handle votePassEvent = CreateEvent("vote_passed");
			SetEventString(votePassEvent, "details", "#L4D_TargetID_Player");
			SetEventString(votePassEvent, "param1", param1);
			SetEventInt(votePassEvent, "team", -1);
			FireEvent(votePassEvent);
		
			LogVote(client, "自定义投票通过 投票内容: <%s> ", customVote);
		}
		else
		{				
			Handle voteFailEvent = CreateEvent("vote_failed");
			SetEventInt(voteFailEvent, "team", 0);
			FireEvent(voteFailEvent);
		
			LogVote(client, "自定义投票未通过 投票内容: <%s> ", customVote);
		}
	}

	customVoteInProgress = false;
	
	return Plugin_Handled;
}