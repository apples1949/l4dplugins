#include <sourcemod>
#include <sdktools>
#include "left4downtown.inc"

#define UNRESERVE_VERSION "2.0.0"

#define UNRESERVE_DEBUG 0
#define UNRESERVE_DEBUG_LOG 0

#define L4D_MAXCLIENTS MaxClients
#define L4D_MAXCLIENTS_PLUS1 (L4D_MAXCLIENTS + 1)

#define L4D_MAXHUMANS_LOBBY_VERSUS 8
#define L4D_MAXHUMANS_LOBBY_OTHER 4

new bool:g_bUnreserved = false;

public Plugin:myinfo =
{
	name = "L4D 1/2 Remove Lobby Reservation",
	author = "Downtown1, Anime4000",
	description = "Removes lobby reservation when server is full",
	version = UNRESERVE_VERSION,
	url = "https://github.com/Attano/Left4Downtown2/blob/master/scripting/l4d2_unreservelobby.sp"
}

new Handle:cvarUnreserve = INVALID_HANDLE;
new Handle:cvarAutoLobby = INVALID_HANDLE;

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	HookEvent("player_disconnect", OnPlayerDisconnect)
	RegAdminCmd("sm_unreserve", Command_Unreserve, ADMFLAG_BAN, "sm_unreserve - 手动强制删除大厅");

	cvarUnreserve = CreateConVar("l4d_unreserve_full", "1", "是否满人后删除大厅", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY);
	cvarAutoLobby = CreateConVar("l4d_autolobby", "1", "仅自动调整sv_allow_lobby_connect_only。当大厅已满时设置为0，当服务器为空时设置为1", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY);
	CreateConVar("l4d_unreserve_version", UNRESERVE_VERSION, "Version of the Lobby Unreserve plugin.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY);
}

//DDRKhat thanks http://forums.alliedmods.net/showpost.php?p=811533&postcount=76
Gamemode() // 1 = Co-Op, 2 = Versus, 3 = Survival. False on anything else.
{
	new String:gmode[32];
	GetConVarString(FindConVar("mp_gamemode"),gmode,sizeof(gmode));
	if (strncmp(gmode,"coop",sizeof(gmode),false)==0) return 1;
	else if (strncmp(gmode,"versus",sizeof(gmode),false)==0) return 2;
	else if (strncmp(gmode,"survival",sizeof(gmode),false)==0) return 3;
	else if (strncmp(gmode,"scavenge",sizeof(gmode),false)==0) return 4;
	else if (strncmp(gmode,"realism",sizeof(gmode),false)==0) return 5;
        else return false;
}

IsServerLobbyFull()
{
	new humans = GetHumanCount();
	new gamemode = Gamemode();

	DebugPrintToAll("IsServerLobbyFull : humans = %d, gamemode = %d", humans, gamemode);

	if(gamemode == 2 || gamemode == 4)
	{
		return humans >= L4D_MAXHUMANS_LOBBY_VERSUS;
	}

	return humans >= L4D_MAXHUMANS_LOBBY_OTHER;
}

IsAllowLobby(bool:e)
{
	if(GetConVarBool(cvarAutoLobby))
		SetConVarBool(FindConVar("sv_allow_lobby_connect_only"), e);
}

public OnClientPutInServer(client)
{
	DebugPrintToAll("Client put in server %N", client);

	if(GetConVarBool(cvarUnreserve) && !g_bUnreserved && IsServerLobbyFull())
	{
		if (GetConVarInt(FindConVar("sv_hosting_lobby")) > 0)
		{
			LogMessage("[UL] A full lobby has connected, automatically unreserving the server.");
			L4D_LobbyUnreserve();
			g_bUnreserved = true;
			IsAllowLobby(false);
		}
	}
}
//OnClientDisconnect will fired when changing map, issued by gH0sTy at http://docs.sourcemod.net/api/index.php?fastload=show&id=390&
public Action:OnPlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client == 0)
		return;

	if (IsFakeClient(client))
		return;
	
	if (!RealClientsInServer(client))
	{
		PrintToServer("[UL] No human want to play in this server. :(");
		g_bUnreserved = false;
		IsAllowLobby(true);
	}
}

public Action:Command_Unreserve(client, args)
{
	if(g_bUnreserved)
	{
		ReplyToCommand(client, "[UL] Server has already been unreserved.");
	}
	else
	{
		L4D_LobbyUnreserve();
		g_bUnreserved = true;
		ReplyToCommand(client, "[UL] Lobby reservation has been removed.");
		IsAllowLobby(false);
	}

	return Plugin_Handled;
}

//client is in-game and not a bot
stock bool:IsClientInGameHuman(client)
{
	return IsClientInGame(client) && !IsFakeClient(client);
}

stock GetHumanCount()
{
	new humans = 0;

	new i;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i))
		{
			humans++
		}
	}

	return humans;
}

DebugPrintToAll(const String:format[], any:...)
{
	#if UNRESERVE_DEBUG	|| UNRESERVE_DEBUG_LOG
	decl String:buffer[192];

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
public RealClientsInServer(client)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (i != client)
		{
			if (IsClientConnected(i) && !IsFakeClient(i))
				return true;
		}
	}
	return false;
}
