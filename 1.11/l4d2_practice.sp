// Credit to Don, epilimic, XBetaAlpha, darkid l4d2_swapduringtank.sp
// Source: https://github.com/Attano/L4D2-Competitive-Framework/blob/master/addons/sourcemod/scripting/l4d2_swapduringtank.sp
// Credit to XBetaAlpha for his Zombie Character Select, used to swap between spitter and boomer.
// Source: https://forums.alliedmods.net/showthread.php?p=1118704
// Credit to HyperKiLLeR
// Source: https://forums.alliedmods.net/showthread.php?t=114393
#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6
#define ZC_WITCH                7
#define ZC_TANK                 8
#define ZC_NOTINFECTED          9
#define ZC_TOTAL                7

public Plugin myinfo =
{
	name = "L4D2 Practice",
	author = "devilesk",
	description = "Practice features",
	version = "0.2.0",
	url = "https://github.com/devilesk/rl4d2l-plugins"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char sGame[12];
	GetGameFolderName(sGame, sizeof(sGame));
	if (StrEqual(sGame, "left4dead2"))	// Only load the plugin if the server is running Left 4 Dead 2.
	{
		return APLRes_Success;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports L4D2");
		return APLRes_Failure;
	}
}

Handle g_hSetClass;
Handle g_hCreateAbility;
int g_oAbility;
bool in_attack2[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegConsoleCmd("sm_goto", Command_Goto,"Go to a player");
	RegConsoleCmd("sm_bring", Command_Bring,"Teleport a player to you");
	HookEvent("ghost_spawn_time", PlayerGhostTimer);
	Sub_HookGameData();
}

// When a player pushes a button, if:
// They're infected, as ghost
// They press mouse2
// Then change them to the other class.
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (client <= 0 || client > MaxClients) return;
	if (!IsClientInGame(client)) return;
	if (IsFakeClient(client)) return;
	if (GetClientTeam(client) != 3) return;
	if (!GetEntProp(client, Prop_Send, "m_isGhost")) return;
	// Player was holding m2, and now isn't. (Released)
	if (buttons & IN_ATTACK2 != IN_ATTACK2 && in_attack2[client]) {
		in_attack2[client] = false;
	}
	// Player was not holding m2, and now is. (Pressed)
	if (buttons & IN_ATTACK2 == IN_ATTACK2 && !in_attack2[client]) {
		in_attack2[client] = true;
		int class = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (class == ZC_SMOKER) {
			Sub_DetermineClass(client, ZC_BOOMER);
			PrintHintText(client, "Press <Mouse2> to change to hunter.");
		} else if (class == ZC_BOOMER) {
			Sub_DetermineClass(client, ZC_HUNTER);
			PrintHintText(client, "Press <Mouse2> to change spitter.");
		} else if (class == ZC_HUNTER) {
			Sub_DetermineClass(client, ZC_SPITTER);
			PrintHintText(client, "Press <Mouse2> to change jockey.");
		} else if (class == ZC_SPITTER) {
			Sub_DetermineClass(client, ZC_JOCKEY);
			PrintHintText(client, "Press <Mouse2> to change charger.");
		} else if (class == ZC_JOCKEY) {
			Sub_DetermineClass(client, ZC_CHARGER);
			PrintHintText(client, "Press <Mouse2> to change tank.");
		} else if (class == ZC_CHARGER) {
			Sub_DetermineClass(client, ZC_TANK);
			PrintHintText(client, "Press <Mouse2> to change smoker.");
		} else if (class == ZC_TANK) {
			Sub_DetermineClass(client, ZC_SMOKER);
			PrintHintText(client, "Press <Mouse2> to change boomer.");
		}
	}
}

// Called when an SI respawns, so they know how long until they become a ghost.
public void PlayerGhostTimer(Handle event, const char[] name, bool dontBroadcast)  {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client <= 0 || client > MaxClients) return;
	if (!IsClientInGame(client)) return;
	if (IsFakeClient(client)) return;
	if (GetClientTeam(client) != 3) return;
	// We don't know what their class is until they spawn. We wait an extra .1 sec for safety. Players can still change classes at that time, only the hint text is delayed.
	float spawntime = 0.1+1.0*GetEventInt(event, "spawntime");
	CreateTimer(spawntime, PlayerBecameGhost, client);
}
public Action PlayerBecameGhost(Handle timer, any client) {
	PrintHintText(client, "Press <Mouse2> to change SI class.");
}

// Loads gamedata, preps SDK calls.
public void Sub_HookGameData()
{
	Handle g_hGameConf = LoadGameConfigFile("l4d2_zcs");

	if (g_hGameConf != INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "SetClass");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		g_hSetClass = EndPrepSDKCall();

		if (g_hSetClass == INVALID_HANDLE)
			SetFailState("Unable to find SetClass signature.");

		StartPrepSDKCall(SDKCall_Static);
		PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CreateAbility");
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hCreateAbility = EndPrepSDKCall();

		if (g_hCreateAbility == INVALID_HANDLE)
			SetFailState("Unable to find CreateAbility signature.");

		g_oAbility = GameConfGetOffset(g_hGameConf, "oAbility");

		CloseHandle(g_hGameConf);
	}

	else
		SetFailState("Unable to load l4d2_zcs.txt");
}

// Sets the class of a client.
public void Sub_DetermineClass(any Client, any ZClass)
{
	int WeaponIndex;
	while ((WeaponIndex = GetPlayerWeaponSlot(Client, 0)) != -1)
	{
		RemovePlayerItem(Client, WeaponIndex);
		RemoveEdict(WeaponIndex);
	}

	SDKCall(g_hSetClass, Client, ZClass);
	AcceptEntityInput(MakeCompatEntRef(GetEntProp(Client, Prop_Send, "m_customAbility")), "Kill");
	SetEntProp(Client, Prop_Send, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, Client), g_oAbility));
}

public Action Command_Goto(int Client, int args)
{
    //Error:
	if(args < 1)
	{

		//Print:
		PrintToConsole(Client, "Usage: sm_goto <name>");
		PrintToChat(Client, "Usage:\x04 sm_goto <name>");

		//Return:
		return Plugin_Handled;
	}
	
	//Declare:
	int Player;
	char PlayerName[32];
	float TeleportOrigin[3];
	float PlayerOrigin[3];
	char Name[32];
	
	//Initialize:
	Player = -1;
	GetCmdArg(1, PlayerName, sizeof(PlayerName));
	
	//Find:
	for(int X = 1; X <= MaxClients; X++)
	{

		//Connected:
		if(!IsClientConnected(X)) continue;

		//Initialize:
		GetClientName(X, Name, sizeof(Name));

		//Save:
		if(StrContains(Name, PlayerName, false) != -1) Player = X;
	}
	
	//Invalid Name:
	if(Player == -1)
	{

		//Print:
		PrintToConsole(Client, "Could not find client \x04%s", PlayerName);

		//Return:
		return Plugin_Handled;
	}
	
	//Initialize
	GetClientName(Player, Name, sizeof(Name));
	GetClientAbsOrigin(Player, PlayerOrigin);
	
	//Math
	TeleportOrigin[0] = PlayerOrigin[0];
	TeleportOrigin[1] = PlayerOrigin[1];
	TeleportOrigin[2] = (PlayerOrigin[2] + 73);
	
	//Teleport
	TeleportEntity(Client, TeleportOrigin, NULL_VECTOR, NULL_VECTOR);
	
	return Plugin_Handled;
}

public Action Command_Bring(int Client, int args)
{
    //Error:
	if(args < 1)
	{

		//Print:
		PrintToConsole(Client, "Usage: sm_bring <name>");
		PrintToChat(Client, "Usage:\x04 sm_bring <name>");

		//Return:
		return Plugin_Handled;
	}
	
	//Declare:
	int Player;
	char PlayerName[32];
	float TeleportOrigin[3];
	float PlayerOrigin[3];
	char Name[32];
	
	//Initialize:
	Player = -1;
	GetCmdArg(1, PlayerName, sizeof(PlayerName));
	
	//Find:
	for(int X = 1; X <= MaxClients; X++)
	{

		//Connected:
		if(!IsClientConnected(X)) continue;

		//Initialize:
		GetClientName(X, Name, sizeof(Name));

		//Save:
		if(StrContains(Name, PlayerName, false) != -1) Player = X;
	}
	
	//Invalid Name:
	if(Player == -1)
	{

		//Print:
		PrintToConsole(Client, "Could not find client \x04%s", PlayerName);

		//Return:
		return Plugin_Handled;
	}
	
	//Initialize
	GetClientName(Player, Name, sizeof(Name));
	GetCollisionPoint(Client, PlayerOrigin);
	
	//Math
	TeleportOrigin[0] = PlayerOrigin[0];
	TeleportOrigin[1] = PlayerOrigin[1];
	TeleportOrigin[2] = (PlayerOrigin[2] + 4);
	
	//Teleport
	TeleportEntity(Player, TeleportOrigin, NULL_VECTOR, NULL_VECTOR);
	
	return Plugin_Handled;
}

// Trace

stock void GetCollisionPoint(int client, float pos[3])
{
	float vOrigin[3];
	float vAngles[3];
	
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer);
	
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(pos, trace);
		delete trace;
		
		return;
	}
	
	delete trace;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > MaxClients;
}