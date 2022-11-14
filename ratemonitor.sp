#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>
#include <colors>

#define STEAMID_SIZE 32

ConVar
	hCvarAllowedRateChanges,
	hCvarMinRate,
	hCvarMinUpd,
	hCvarMinCmd,
	hCvarProhibitFakePing,
	hCvarProhibitedAction,
	hCvarPublicNotice;

ArrayList
	hClientSettingsArray;

int
	iAllowedRateChanges,
	iMinRate,
	iMinUpd,
	iMinCmd,
	iActionUponExceed;

bool
	IsLateLoad,
	bPublic,
	bProhibitFakePing,
	bIsMatchLive;

#if SOURCEMOD_V_MINOR > 9
enum struct NetsettingsStruct
{
	char Client_SteamId[STEAMID_SIZE];
	int Client_Rate;
	int Client_Cmdrate;
	int Client_Updaterate;
	int Client_Changes;
}
#else
enum NetsettingsStruct
{
	String:Client_SteamId[STEAMID_SIZE],
	Client_Rate,
	Client_Cmdrate,
	Client_Updaterate,
	Client_Changes
};
#endif

public Plugin myinfo =
{
	name = "RateMonitor",
	author = "Visor, Sir, A1m`",
	description = "Keep track of players' netsettings",
	version = "2.6",
	url = "https://github.com/A1mDev/L4D2-Competitive-Plugins"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	IsLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	hCvarAllowedRateChanges = CreateConVar("rm_allowed_rate_changes", "-1", "Allowed number of rate changes during a live round(存活阶段玩家rate值最多能更改多少次-1: 无限制)");
	hCvarPublicNotice = CreateConVar ("rm_public_notice", "0", "是否在屏幕中播报玩家rate值变更? (rm_countermeasure 1和3仍将是公开播报)");
	hCvarMinRate = CreateConVar("rm_min_rate", "60000", "允许最低的rate值(-1: none)");
	hCvarMinUpd = CreateConVar("rm_min_upd", "60", "允许最低的cl_updaterate值(-1: none)");
	hCvarMinCmd = CreateConVar("rm_min_cmd", "60", "允许最低的cl_cmdrate值(-1: none)");
	hCvarProhibitFakePing = CreateConVar("rm_no_fake_ping", "0", "允不允许在网络设置中使用+ - ...，这通常用于在记分栏中隐藏真实的ping");
	hCvarProhibitedAction = CreateConVar("rm_countermeasure", "1", "针对非法行为的对策--改变超限/禁止的网络设置(1:聊天通知,2:移动到规格,3:踢出))", _, true, 1.0, true, 3.0);

	iAllowedRateChanges = hCvarAllowedRateChanges.IntValue;
	iMinRate = hCvarMinRate.IntValue;
	iMinUpd = hCvarMinUpd.IntValue;
	iMinCmd = hCvarMinCmd.IntValue;
	bProhibitFakePing = hCvarProhibitFakePing.BoolValue;
	iActionUponExceed = hCvarProhibitedAction.IntValue;
	bPublic = hCvarPublicNotice.BoolValue;
	
	hCvarAllowedRateChanges.AddChangeHook(cvarChanged_AllowedRateChanges);
	hCvarMinRate.AddChangeHook(cvarChanged_MinRate);
	hCvarMinCmd.AddChangeHook(cvarChanged_MinCmd);
	hCvarProhibitFakePing.AddChangeHook(cvarChanged_ProhibitFakePing);
	hCvarProhibitedAction.AddChangeHook(cvarChanged_ExceedAction);
	hCvarPublicNotice.AddChangeHook(cvarChanged_PublicNotice);

	RegConsoleCmd("sm_rates", ListRates, "List netsettings of all players in game");
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", Event_RoundGoesLive, EventHookMode_PostNoCopy);
	HookEvent("player_team", OnTeamChange);
	
#if SOURCEMOD_V_MINOR > 9
	hClientSettingsArray = new ArrayList(sizeof(NetsettingsStruct));
#else
	hClientSettingsArray = new ArrayList(view_as<int>(NetsettingsStruct));
#endif

	if (IsLateLoad) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && !IsFakeClient(i)) {
				RegisterSettings(i);
			}
		}
	}
}

public void Event_RoundStart(Event hEvent, const char[] name, bool dontBroadcast)
{
	int iSize = hClientSettingsArray.Length;
#if SOURCEMOD_V_MINOR > 9
	NetsettingsStruct player;
	for (int i = 0; i < iSize; i++) {
		hClientSettingsArray.GetArray(i, player, sizeof(NetsettingsStruct));
		player.Client_Changes = 0;
		hClientSettingsArray.SetArray(i, player, sizeof(NetsettingsStruct));
	}
#else
	NetsettingsStruct player[NetsettingsStruct];
	for (int i = 0; i < iSize; i++) {
		hClientSettingsArray.GetArray(i, player[0], view_as<int>(NetsettingsStruct));
		player[Client_Changes] = 0;
		hClientSettingsArray.SetArray(i, player[0], view_as<int>(NetsettingsStruct));
	}
#endif
}

public void Event_RoundGoesLive(Event hEvent, const char[] name, bool dontBroadcast)
{
	//This event works great with the plugin readyup.smx (does not conflict)
	//This event works great in different game modes: versus, coop, scavenge and etc
	bIsMatchLive = true;
}

public void Event_RoundEnd(Event hEvent, const char[] name, bool dontBroadcast)
{
	bIsMatchLive = false;
}

public void OnMapEnd()
{
	hClientSettingsArray.Clear();
}

public void OnTeamChange(Event hEvent, const char[] name, bool dontBroadcast)
{
	if (hEvent.GetInt("team") != L4D2Team_Spectator) {
		int userid = hEvent.GetInt("userid");
		int client = GetClientOfUserId(userid);
		if (client > 0 && !IsFakeClient(client)) {
			CreateTimer(0.1, OnTeamChangeDelay, userid, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action OnTeamChangeDelay(Handle hTimer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client > 0) {
		RegisterSettings(client);
	}

	return Plugin_Stop;
}

public void OnClientSettingsChanged(int client)
{
	if (IsValidEntity(client) && !IsFakeClient(client)) {
		RegisterSettings(client);
	}
}

public Action ListRates(int client, int args)
{
	ReplyToCommand(client, "\x01[RateMonitor] List of player netsettings(\x03cmd\x01/\x04upd\x01/\x05rate\x01):");
	
	int iSize = hClientSettingsArray.Length;

#if SOURCEMOD_V_MINOR > 9
	NetsettingsStruct player;
	for (int i = 0; i < iSize; i++) {
		hClientSettingsArray.GetArray(i, player, sizeof(NetsettingsStruct));

		int iClient = GetClientBySteamId(player.Client_SteamId);
		if (iClient > 0 && GetClientTeam(client) > L4D2Team_Spectator) {
			ReplyToCommand(client, "\x03%N\x01 : %d/%d/%d", iClient, player.Client_Cmdrate, player.Client_Updaterate, player.Client_Rate);
		}
	}
#else
	NetsettingsStruct player[NetsettingsStruct];
	for (int i = 0; i < iSize; i++) {
		hClientSettingsArray.GetArray(i, player[0], view_as<int>(NetsettingsStruct));

		int iClient = GetClientBySteamId(player[Client_SteamId]);
		if (iClient > 0 && GetClientTeam(iClient) > L4D2Team_Spectator) {
			ReplyToCommand(client, "\x03%N\x01 : %d/%d/%d", iClient, player[Client_Cmdrate], player[Client_Updaterate], player[Client_Rate]);
		}
	}
#endif

	return Plugin_Handled;
}

void RegisterSettings(int client)
{
	if (GetClientTeam(client) < L4D2Team_Survivor) {
		return;
	}
	
	char 
		sCmdRate[32],
		sUpdateRate[32],
		sRate[32],
		sSteamId[STEAMID_SIZE],
		sCounter[32] = "";

	GetClientAuthId(client, AuthId_Steam2, sSteamId, STEAMID_SIZE);

	int iIndex = hClientSettingsArray.FindString(sSteamId);

	// rate
	int iRate = GetClientDataRate(client);
	// cl_cmdrate
	GetClientInfo(client, "cl_cmdrate", sCmdRate, sizeof(sCmdRate));
	int iCmdRate = StringToInt(sCmdRate);
	// cl_updaterate
	GetClientInfo(client, "cl_updaterate", sUpdateRate, sizeof(sUpdateRate));
	int iUpdateRate = StringToInt(sUpdateRate);

	// Punish for fake ping or other unallowed symbols in rate settings
	if (bProhibitFakePing) {
		bool bIsCmdRateClean, bIsUpdateRateClean;
		
		bIsCmdRateClean = IsNatural(sCmdRate);
		bIsUpdateRateClean = IsNatural(sUpdateRate);

		if (!bIsCmdRateClean || !bIsUpdateRateClean) {
			sCounter = "[bad cmd/upd]";
			Format(sCmdRate, sizeof(sCmdRate), "%s", sCmdRate);
			Format(sUpdateRate, sizeof(sUpdateRate), "%s", sUpdateRate);
			Format(sRate, sizeof(sRate), "%d", iRate);
			
			PunishPlayer(client, sCmdRate, sUpdateRate, sRate, sCounter, iIndex);
			return;
		}
	}

	 // Punish for low rate settings(if we're good on previous check)
	if ((iCmdRate < iMinCmd && iMinCmd > -1) || (iRate < iMinRate && iMinRate > -1) || (iUpdateRate < iMinUpd && iMinUpd > -1)) {
		sCounter = "[low cmd/update/rate]";
		Format(sCmdRate, sizeof(sCmdRate), "%s%d%s", iCmdRate < iMinCmd ? ">" : "", iCmdRate, iCmdRate < iMinCmd ? "<" : "");
		Format(sUpdateRate, sizeof(sCmdRate), "%s%d%s", iUpdateRate < iMinUpd ? ">" : "", iUpdateRate, iUpdateRate < iMinUpd ? "<" : "");
		Format(sRate, sizeof(sRate), "%s%d%s", iRate < iMinRate ? ">" : "", iRate, iRate < iMinRate ? "<" : "");
		
		PunishPlayer(client, sCmdRate, sUpdateRate, sRate, sCounter, iIndex);
		return;
	}
	
#if SOURCEMOD_V_MINOR > 9
	NetsettingsStruct player;
	if (iIndex > -1) {
		hClientSettingsArray.GetArray(iIndex, player, sizeof(NetsettingsStruct));
		
		if (iRate == player.Client_Rate && iCmdRate == player.Client_Cmdrate && iUpdateRate == player.Client_Updaterate) {
			return; // No change
		}
		
		if (bIsMatchLive && iAllowedRateChanges > -1) {
			player.Client_Changes += 1;
			Format(sCounter, sizeof(sCounter), "[%d/%d]", player.Client_Changes, iAllowedRateChanges);
			
			// If not punished for bad rate settings yet, punish for overlimit rate change(if any)
			if (player.Client_Changes > iAllowedRateChanges) {
				Format(sCmdRate, sizeof(sCmdRate), "%s%d", iCmdRate != player.Client_Cmdrate ? "*" : "", iCmdRate);
				Format(sUpdateRate, sizeof(sUpdateRate), "%s%d\x01", iUpdateRate != player.Client_Updaterate ? "*" : "", iUpdateRate);
				Format(sRate, sizeof(sRate), "%s%d\x01", iRate != player.Client_Rate ? "*" : "", iRate);
			
				PunishPlayer(client, sCmdRate, sUpdateRate, sRate, sCounter, iIndex);
				return;
			}
		}
		
		if (bPublic) {
			CPrintToChatAllEx(client, "{default}<{olive}Rates{default}> {teamcolor}%N{default} 的网络设置从 {teamcolor}%d/%d/%d {default}变更为 {teamcolor}%d/%d/%d {olive}%s", \
						client, player.Client_Cmdrate, player.Client_Updaterate, player.Client_Rate, iCmdRate, iUpdateRate, iRate, sCounter);
		}
		
		player.Client_Cmdrate = iCmdRate;
		player.Client_Updaterate = iUpdateRate;
		player.Client_Rate = iRate;
		
		hClientSettingsArray.SetArray(iIndex, player, sizeof(NetsettingsStruct));
	} else {
		strcopy(player.Client_SteamId, STEAMID_SIZE, sSteamId);
		player.Client_Cmdrate = iCmdRate;
		player.Client_Updaterate = iUpdateRate;
		player.Client_Rate = iRate;
		player.Client_Changes = 0;
		
		hClientSettingsArray.PushArray(player, sizeof(NetsettingsStruct));
		if (bPublic) {
			CPrintToChatAllEx(client, "{default}<{olive}Rates{default}> {teamcolor}%N{default} 的网络设置变更为 {teamcolor}%d/%d/%d", \
						client, player.Client_Cmdrate, player.Client_Updaterate, player.Client_Rate);
		}
	}
#else
	NetsettingsStruct player[NetsettingsStruct];
	if (iIndex > -1) {
		hClientSettingsArray.GetArray(iIndex, player[0], view_as<int>(NetsettingsStruct));
		
		if (iRate == player[Client_Rate] && iCmdRate == player[Client_Cmdrate] && iUpdateRate == player[Client_Updaterate]) {
			return; // No change
		}
		
		if (bIsMatchLive && iAllowedRateChanges > -1) {
			player[Client_Changes] += 1;
			Format(sCounter, sizeof(sCounter), "[%d/%d]", player[Client_Changes], iAllowedRateChanges);
			
			// If not punished for bad rate settings yet, punish for overlimit rate change(if any)
			if (player[Client_Changes] > iAllowedRateChanges) {
				Format(sCmdRate, sizeof(sCmdRate), "%s%d", iCmdRate != player[Client_Cmdrate] ? "*" : "", iCmdRate);
				Format(sUpdateRate, sizeof(sUpdateRate), "%s%d\x01", iUpdateRate != player[Client_Updaterate] ? "*" : "", iUpdateRate);
				Format(sRate, sizeof(sRate), "%s%d\x01", iRate != player[Client_Rate] ? "*" : "", iRate);
			
				PunishPlayer(client, sCmdRate, sUpdateRate, sRate, sCounter, iIndex);
				return;
			}
		}
		
		if (bPublic) {
			CPrintToChatAllEx(client, "{default}<{olive}Rates{default}> {teamcolor}%N{default} 的网络设置从 {teamcolor}%d/%d/%d {default}变更为 {teamcolor}%d/%d/%d {olive}%s", \
						client, player[Client_Cmdrate], player[Client_Updaterate], player[Client_Rate], iCmdRate, iUpdateRate, iRate, sCounter);
		}
		
		player[Client_Cmdrate] = iCmdRate;
		player[Client_Updaterate] = iUpdateRate;
		player[Client_Rate] = iRate;
		
		hClientSettingsArray.SetArray(iIndex, player[0], view_as<int>(NetsettingsStruct));
	} else {
		strcopy(player[Client_SteamId], STEAMID_SIZE, sSteamId);
		player[Client_Cmdrate] = iCmdRate;
		player[Client_Updaterate] = iUpdateRate;
		player[Client_Rate] = iRate;
		player[Client_Changes] = 0;
		
		hClientSettingsArray.PushArray(player[0], view_as<int>(NetsettingsStruct));
		if (bPublic) {
			CPrintToChatAllEx(client, "{default}<{olive}Rates{default}> {teamcolor}%N{default} 的网络设置变更为 {teamcolor}%d/%d/%d", \
						client, player[Client_Cmdrate], player[Client_Updaterate], player[Client_Rate]);
		}
	}
#endif
}

void PunishPlayer(int client, const char[] sCmdRate, const char[] sUpdateRate, const char[] sRate, const char[] sCounter, int iIndex)
{
	bool bInitialRegister = (iIndex > -1) ? false : true;

	switch (iActionUponExceed)
	{
		case 1: {// Just notify all players(zero punishment)
			if (bInitialRegister) {
				CPrintToChatAllEx(client, "{default}<{olive}Rates{default}> {teamcolor}%N{default} 的网络设置被设置为非法值: {teamcolor}%s/%s/%s {olive}%s", \
								client, sCmdRate, sUpdateRate, sRate, sCounter);
			} else {
				CPrintToChatAllEx(client, "{default}<{olive}Rates{default}> {teamcolor}%N{default} 在游戏过程中非法改变了网络设置: {teamcolor}%s/%s/%s {olive}%s", \
								client, sCmdRate, sUpdateRate, sRate, sCounter);
			}
		}
		case 2: {// Move to spec
			ChangeClientTeam(client, L4D2Team_Spectator);
			
			if (bInitialRegister) {
				if (bPublic) {
					CPrintToChatAllEx(client, "{default}<{olive}Rates{default}> {teamcolor}%N {default}因非法网络设置而被移动到旁观: {teamcolor}%s/%s/%s {olive}%s", \
								client, sCmdRate, sUpdateRate, sRate, sCounter);
				}

				CPrintToChatEx(client, client, "{default}<{olive}Rates{default}> 请将您的rate值调整为高于以下的数值 {olive}%d/%d/%d%s", \
								iMinCmd, iMinUpd, iMinRate, bProhibitFakePing ? " 并删除任何非数字字符" : "");
			} else {
				#if SOURCEMOD_V_MINOR > 9
					NetsettingsStruct player;
					hClientSettingsArray.GetArray(iIndex, player, sizeof(NetsettingsStruct));
		
					if (bPublic) {
						CPrintToChatAllEx(client, "{default}<{olive}Rates{default}> {teamcolor}%N {default}因非法网络设置而被移动到旁观: {teamcolor}%s/%s/%s {olive}%s", \
									client, sCmdRate, sUpdateRate, sRate, sCounter);
					}
					CPrintToChatEx(client, client, "{default}<{olive}Rates{default}> 请将你的网络设置重新设置为: {teamcolor}%d/%d/%d", \
									player.Client_Cmdrate, player.Client_Updaterate, player.Client_Rate);
				#else
					NetsettingsStruct player[NetsettingsStruct];
					hClientSettingsArray.GetArray(iIndex, player[0], view_as<int>(NetsettingsStruct));
		
					if (bPublic) {
						CPrintToChatAllEx(client, "{default}<{olive}Rates{default}> {teamcolor}%N {default}因非法网络设置而被移动到旁观: {teamcolor}%s/%s/%s {olive}%s", \
									client, sCmdRate, sUpdateRate, sRate, sCounter);
					}
					CPrintToChatEx(client, client, "{default}<{olive}Rates{default}> 请将你的网络设置重新设置为: {teamcolor}%d/%d/%d", \
									player[Client_Cmdrate], player[Client_Updaterate], player[Client_Rate]);
				#endif
			}
		}
		case 3: {// Kick
			if (bInitialRegister) {
				KickClient(client, "Please use rates higher than %d/%d/%d%s", \
								iMinCmd, iMinUpd, iMinRate, bProhibitFakePing ? " 并删除任何非数字字符" : "");

				CPrintToChatAllEx(client, "{default}<{olive}Rates{default}> {teamcolor}%N {default}因非法网络设置而被踢出: {teamcolor}%s/%s/%s {olive}%s", \
								client, sCmdRate, sUpdateRate, sRate, sCounter);
			} else {
				#if SOURCEMOD_V_MINOR > 9
					NetsettingsStruct player;
					hClientSettingsArray.GetArray(iIndex, player, sizeof(NetsettingsStruct));

					KickClient(client, "请将你的网络设置重新设置为: %d/%d/%d 并删除任何非数字字符", \
									player.Client_Cmdrate, player.Client_Updaterate, player.Client_Rate);
				#else
					NetsettingsStruct player[NetsettingsStruct];
					hClientSettingsArray.GetArray(iIndex, player[0], view_as<int>(NetsettingsStruct));

					KickClient(client, "请将你的网络设置重新设置为: %d/%d/%d 并删除任何非数字字符", \
									player[Client_Cmdrate], player[Client_Updaterate], player[Client_Rate]);
				#endif
				
				CPrintToChatAllEx(client, "{default}<{olive}Rates{default}> {teamcolor}%N {default}因非法网络设置而被踢出: {teamcolor}%s/%s/%s {olive}%s", \
									client, sCmdRate, sUpdateRate, sRate, sCounter);
			}
		}
	}
}

int GetClientBySteamId(const char[] steamID)
{
	char tempSteamID[STEAMID_SIZE];

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			GetClientAuthId(i, AuthId_Steam2, tempSteamID, sizeof(tempSteamID));

			if (strcmp(steamID, tempSteamID) == 0) {
				return i;
			}
		}
	}

	return -1;
}

bool IsNatural(const char[] str)
{
	int x = 0;
	while (str[x] != '\0') 
	{
		if (!IsCharNumeric(str[x])) {
			return false;
		}
	
		x++;
	}

	return true;
}

public void cvarChanged_AllowedRateChanges(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iAllowedRateChanges = hCvarAllowedRateChanges.IntValue;
}

public void cvarChanged_MinRate(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iMinRate = hCvarMinRate.IntValue;
}

public void cvarChanged_MinCmd(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iMinCmd = hCvarMinCmd.IntValue;
}

public void cvarChanged_ProhibitFakePing(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bProhibitFakePing = hCvarProhibitFakePing.BoolValue;
}

public void cvarChanged_ExceedAction(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iActionUponExceed = hCvarProhibitedAction.IntValue;
}

public void cvarChanged_PublicNotice(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bPublic = hCvarPublicNotice.BoolValue;
}
