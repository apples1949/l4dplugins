#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define UNRESERVE_VERSION "2.0.0"

#define UNRESERVE_DEBUG 0
#define UNRESERVE_DEBUG_LOG 0

#define L4D_MAXCLIENTS MaxClients
#define L4D_MAXCLIENTS_PLUS1 (L4D_MAXCLIENTS + 1)

#define L4D_MAXHUMANS_LOBBY_VERSUS 8
#define L4D_MAXHUMANS_LOBBY_OTHER 4

bool g_bUnreserved = false;

public Plugin myinfo =
{
	name = "L4D 1/2 Remove Lobby Reservation",
	author = "Downtown1, Anime4000",
	description = "Removes lobby reservation when server is full",
	version = UNRESERVE_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=87759"
}

ConVar g_hcvarUnreserve;
ConVar g_hcvarAutoLobby;
ConVar g_hcvarGameMode;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	HookEvent("player_disconnect", OnPlayerDisconnect);
	RegAdminCmd("sm_unreserve", Command_Unreserve, ADMFLAG_BAN, "sm_unreserve - manually force removes the lobby reservation");

	g_hcvarUnreserve = CreateConVar("l4d_unreserve_full", "1", "Automatically unreserve server after a full lobby joins", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_hcvarAutoLobby = CreateConVar("l4d_autolobby", "1", "Automatically adjust sv_allow_lobby_connect_only. When lobby full it set to 0, when server empty it set to 1", FCVAR_SPONLY|FCVAR_NOTIFY);
	CreateConVar("l4d_unreserve_version", UNRESERVE_VERSION, "Version of the Lobby Unreserve plugin.", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_hcvarGameMode = FindConVar("mp_gamemode");
}

bool IsVersusOrScavengeMode()
{
	char sGameMode[32];
	g_hcvarGameMode.GetString(sGameMode, sizeof(sGameMode));
	if(strncmp(sGameMode, "versus", sizeof(sGameMode), false) == 0)
		return true;

	if(strncmp(sGameMode, "scavenge", sizeof(sGameMode), false) == 0)
		return true;

	return false;
}

bool IsServerLobbyFull()
{
	int humans = GetHumanCount();

	if(IsVersusOrScavengeMode())
		return humans >= L4D_MAXHUMANS_LOBBY_VERSUS;

	return humans >= L4D_MAXHUMANS_LOBBY_OTHER;
}

void IsAllowLobby(int value)
{
	if(g_hcvarAutoLobby.BoolValue)
		FindConVar("sv_allow_lobby_connect_only").SetInt(value);
}

public void OnClientPutInServer(int client)
{
	DebugPrintToAll("Client put in server %N", client);

	if(g_hcvarUnreserve.BoolValue && !g_bUnreserved && IsServerLobbyFull())
	{
		if(FindConVar("sv_hosting_lobby").IntValue > 0)
		{
			LogMessage("[UL] A full lobby has connected, automatically unreserving the server.");
			L4D_LobbyUnreserve();
			g_bUnreserved = true;
			IsAllowLobby(0);
		}
	}
}

//OnClientDisconnect will fired when changing map, issued by gH0sTy at http://docs.sourcemod.net/api/index.php?fastload=show&id=390&
public Action OnPlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client == 0)
		return;

	if(IsFakeClient(client))
		return;

	if(!RealClientsInServer(client))
	{
		PrintToServer("[UL] No human want to play in this server. :(");
		g_bUnreserved = false;
		IsAllowLobby(1);
	}
}

public Action Command_Unreserve(int client, int args)
{
	if(g_bUnreserved)
		ReplyToCommand(client, "[UL] Server has already been unreserved.");
	else
	{
		L4D_LobbyUnreserve();
		g_bUnreserved = true;
		ReplyToCommand(client, "[UL] Lobby reservation has been removed.");
		IsAllowLobby(0);
	}

	return Plugin_Handled;
}

//client is in-game and not a bot
stock bool IsClientInGameHuman(int client)
{
	return IsClientInGame(client) && !IsFakeClient(client);
}

stock int GetHumanCount()
{
	int humans;
	for(int i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i))
			humans++;
	}
	return humans;
}

void DebugPrintToAll(const char[] format, any ...)
{
	#if UNRESERVE_DEBUG	|| UNRESERVE_DEBUG_LOG
	char buffer[192];

	VFormat(buffer, sizeof(buffer), format, 2);

	#if UNRESERVE_DEBUG
	PrintToChatAll("[UNRESERVE] %s", buffer);
	PrintToConsole(0, "[UNRESERVE] %s", buffer);
	#endif

	LogMessage("%s", buffer);
	#else
	//suppress "format" never used warning
	if(format[0])
		return;
	else
		return;
	#endif
}

//No need check client in game, issue when client left and server empty, then got client still connecting.
bool RealClientsInServer(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client)
		{
			if(IsClientConnected(i) && !IsFakeClient(i))
				return true;
		}
	}
	return false;
}
