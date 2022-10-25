
#include <sourcemod>
#include <sdktools>
#define PLUGIN_VERSION "1.1.5"

public Plugin:myinfo = 
{
	name = "Auto Bhop Plugin",
	author = "KnifeLemon",
	description = "Auto Bhop Plugin",
	version = PLUGIN_VERSION,
	url = ""
}

#define MAX_STEAMID 256

new String:g_steamids[64];
new String:steamids[MAX_STEAMID][64];
new steamidlist = 0;
new Handle:g_Cvarauto_bhop;
new Handle:g_Cvarsteamids;
new bool:ON_OFF[MAXPLAYERS+1];
new Bhopon[MAXPLAYERS+1];

new String:Path[256];
new LoadCheck[MAXPLAYERS+1];

public OnPluginStart()
{
	CreateConVar("sm_autobhop_version", PLUGIN_VERSION, "Made KnifeLemon", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_Cvarauto_bhop = CreateConVar("sm_auto_bhop", "1", "auto bhop on = 1 , off = 0");
	g_Cvarsteamids = CreateConVar("sm_auto_bhop_steamid", "STEAM_1:1:74771523", "Steam ID that can be used for autobhop, comma delimited. (example: STEAM:0:0:1234567,STEAM:0:0:1234567,STEAM:0:0:1234567)");
	RegConsoleCmd("sm_auto", Command_AutoBunny);
	ServerCommand("sv_enablebunnyhopping 1");
	AutoExecConfig(true, "autobhop");
	
	HookEvent("player_spawn", EventSpawn);
	
	BuildPath(Path_SM, Path, 256, "data/autobhop.txt");
}

public OnClientPutInServer(Client)
{
	if(IsClientConnectedIngame(Client))
	{
		Bhopon[Client] = 0;
		
		CreateTimer(2.0, Load, Client);
	}
}

public OnClientDisconnect(Client)
{
	if(LoadCheck[Client] == 1)
	{
		Save(Client);
	}
	
	Bhopon[Client] = 0;
}

public EventSpawn(Handle:Event, const String:Spawn_Name[], bool:Spawn_Broadcast)
{
	new Client = GetClientOfUserId(GetEventInt(Event, "userid"));

	if(AliveCheck(Client) == true)
	{
		if(Bhopon[Client] == 1)
		{
			ON_OFF[Client] = true;
		}
	}
}

public Action:Command_AutoBunny(Client, Args)
{
	new sm_auto_bhop = GetConVarInt(g_Cvarauto_bhop);
	if(sm_auto_bhop == 1)
	{
		GetConVarString(g_Cvarsteamids, g_steamids, sizeof(g_steamids));
		if (!StrEqual(g_steamids, "", false))
		{
			new String:AuthString[32], String:Formatting[32];
			GetClientAuthString(Client, AuthString, sizeof(AuthString))
			steamidlist = ExplodeString(g_steamids, ",", steamids, MAX_STEAMID, 64);
			for (new i = 0; i <= steamidlist -1; i++)
			{
				Format(Formatting, sizeof(Formatting), "%s", steamids[i]);
				
				if(StrEqual(AuthString, Formatting, false))
				{
					auto_bhop_popup(Client);
				}
			}
		}
	}
}

public auto_bhop_popup(Client)
{
	new Handle:Auto_Bhop_P = CreateMenu(Menu_auto_bhop);
	SetMenuTitle(Auto_Bhop_P, "BHOP ON / OFF SYSTEM");
	AddMenuItem(Auto_Bhop_P, "1", "Enable");
	AddMenuItem(Auto_Bhop_P, "2", "Disable");
	DisplayMenu(Auto_Bhop_P, Client, MENU_TIME_FOREVER);
}

public Menu_auto_bhop(Handle:menu, MenuAction:action, Client, Select)
{
	if (action == MenuAction_Select)
	{
		if(Select == 0)
		{
			if(ON_OFF[Client] == false)
			{
				PrintToChat(Client, "\x04[AutoBhop] - \x01Auto Bhop Enable");
				Bhopon[Client] = 1;
				ON_OFF[Client] = true;
			}
		}

		if(Select == 1)
		{
			if(ON_OFF[Client] == true){
				PrintToChat(Client, "\x04[AutoBhop] - \x01Auto Bhop Disable");
				Bhopon[Client] = 0;
				ON_OFF[Client] = false;
			}
		}
	}
	if(action == MenuAction_End)
	{
		CloseHandle(menu);
 	}
}

public Action:OnPlayerRunCmd(Client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(ON_OFF[Client] == true)
	{
		if(JoinCheck(Client) && IsPlayerAlive(Client))
		{
			if(buttons & IN_JUMP)
			{
				if(!(GetEntityFlags(Client) & FL_ONGROUND) && !(GetEntityFlags(Client) & FL_INWATER) && !(GetEntityFlags(Client) & FL_WATERJUMP) && !(GetEntityMoveType(Client) == MOVETYPE_LADDER))
				{
					buttons &= ~IN_JUMP;
				}
			}
		}
	}
	return Plugin_Continue;
}

public Save(Client)
{
	if(Client > 0 && IsClientInGame(Client))
	{
		new String:SteamID[32];
		GetClientAuthString(Client, SteamID, 32);

		decl Handle:Vault;

		Vault = CreateKeyValues("Vault");

		if(FileExists(Path))
			FileToKeyValues(Vault, Path);
		
		if(Bhopon[Client] > 0)
		{	
			KvJumpToKey(Vault, "Bhop", true);
			KvSetNum(Vault, SteamID, Bhopon[Client]);
			KvRewind(Vault);
		}
		else
		{
			KvJumpToKey(Vault, "Bhop", false);
			KvDeleteKey(Vault, SteamID);
			KvRewind(Vault);
		}
		
		KvRewind(Vault);
		
		LoadCheck[Client] = 0;

		KeyValuesToFile(Vault, Path);

		CloseHandle(Vault);
	}
}

public Action:Load(Handle:Timer, any:Client)
{
	if(IsClientConnectedIngame(Client))
	{
		if(Client > 0 && Client <= MaxClients)
		{
			new String:SteamID[32];
			GetClientAuthString(Client, SteamID, 32);

			decl Handle:Vault;
		
			Vault = CreateKeyValues("Vault");

			FileToKeyValues(Vault, Path);

			KvJumpToKey(Vault, "Bhop", false);
			Bhopon[Client] = KvGetNum(Vault, SteamID);
			KvRewind(Vault);
			
			LoadCheck[Client] = 1;
			
			KvRewind(Vault);

			CloseHandle(Vault);
		}
	}
}

public bool:AliveCheck(Client){
	if(Client > 0 && Client <= MaxClients){
		if(IsClientConnected(Client) == true){
			if(IsClientInGame(Client) == true){
				if(IsPlayerAlive(Client) == true){
					return true;
				}
				else{
					return false;
				}
			}
			else{	
				return false;	
			}
		}
		else{		
			return false;		
		}
	}
	else{		
		return false;		
	}
}

stock bool:JoinCheck(Client)
{
	if(Client > 0 && Client <= MaxClients)
	{
		if(IsClientConnected(Client) == true)
		{
			if(IsClientInGame(Client) == true)
			{
				return true;
			}
			else return false;
		}
		else return false;
	}
	else return false;
}

stock bool:IsClientConnectedIngame(client){
	if(client > 0 && client <= MaxClients){
		if(IsClientConnected(client) == true){
			if(IsClientInGame(client) == true){
				return true;
			}else{
				return false;	
			}
		}else{
			return false;			
		}
	}else{
		return false;	
	}	
}