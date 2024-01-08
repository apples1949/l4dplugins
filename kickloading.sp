public Plugin myinfo =
{
	name = "Kick Loading",
	author = "Bacardi",
	description = "Kick connecting players if takes too long",
	version = "18.8.2022",
	url = "http://www.sourcemod.net/"
};


ConVar kickloadstuckers_duration;
Handle playertimers[MAXPLAYERS+1];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	RegAdminCmd("sm_kickloading", kickloading, ADMFLAG_KICK, "Kick all players who are connecting into server but are not yet in game.");
	kickloadstuckers_duration = CreateConVar("kickloadstuckers_duration", "90.0", "Kick player after this many second if they still connecting to server", _, true, 60.0);
}


public Action kickloading(int client, int args)
{
	bool kicked = false;

	for(int i = 1; i <= MaxClients; i++)
	{
		// Let's skip those who have not timer running
		if(playertimers[i] == null)
			continue;

		// To be safe side, skip these
		if(i == client || !IsClientConnected(i) || IsFakeClient(i))
			continue;

		if(!IsClientInGame(i) && !IsClientInKickQueue(i))
		{
			kicked = true;
			ShowActivity2(client, "[SM]", "踢出连接中的玩家 %N", i);
			LogAction(client, i, "管理员 \"%L\" 踢出加载中的玩家 \"%L\"", client, i);
			KickClient(i, "Admin kicked connecting players", i);
			
			// Timer should end when player disconnect
		}
	}

	if(!kicked)
		ReplyToTargetError(client, COMMAND_TARGET_NONE);


	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	if(playertimers[client] != null)
		delete playertimers[client];
}

public void OnClientPutInServer(int client)
{
	if(playertimers[client] != null)
		delete playertimers[client];
}

public void OnClientConnected(int client)
{

	if(playertimers[client] != null)
		delete playertimers[client];

	if(IsFakeClient(client))
		return;


	char steamid[30];

	if(GetClientAuthId(client, AuthId_Engine, steamid, sizeof(steamid)))
	{
		// Find player steamid from admin cache (this is not good method for admin immunity check, but we handle client upon connection...)
		if(FindAdminByIdentity(AUTHMETHOD_STEAM, steamid) != INVALID_ADMIN_ID)
			return;
	}


	DataPack pack;
	playertimers[client] = CreateDataTimer(kickloadstuckers_duration.FloatValue, TimerKick, pack);

	pack.WriteCell(client);
	pack.WriteCell(GetClientUserId(client));
	pack.Reset();

	//PrintToServer(" - TimerKick created %N", client);
}


public Action TimerKick(Handle timer, DataPack pack)
{
	int index = pack.ReadCell();

	// clear handle first
	playertimers[index] = null;

	int client = GetClientOfUserId(pack.ReadCell());

	// when we not find client index anymore with given userid
	if(client == 0)
		return Plugin_Continue;


	// Player still not in game, player is not in kick queue
	if(!IsClientInGame(client) && !IsClientInKickQueue(client))
	{
		LogAction(0, client, "玩家 %N 因连接时长大于 %0.0f 秒而自动踢出!", client, kickloadstuckers_duration.FloatValue);
		ShowActivity(0, "玩家 %N 因连接时长大于 %0.0f 秒而自动踢出!", client, kickloadstuckers_duration.FloatValue);
		KickClient(client, "你因连接时长大于 %0.0f 秒而自动踢出!", kickloadstuckers_duration.FloatValue);
	}


	return Plugin_Continue;
}
