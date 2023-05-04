#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define VERSION "0.4"

//ConVar sv_hibernate_when_empty, sb_all_bot_game, g_cvDelayTime;

//float g_fDelayTime;

public Plugin myinfo =
{
	name = "L4D2 Auto restart",
	author = "Dragokas, Harry Potter, fdxx",
	description = "Auto restart server when the last player disconnects from the server. Only support Linux system",
	version = VERSION,
}

public void OnPluginStart()
{
	RegAdminCmd("sm_restart", Cmd_RestartServer, ADMFLAG_ROOT);
}

Action Cmd_RestartServer(int client, int args)
{
	//LogToFilePlus("手动重启服务器...");
	RestartServer();
	return Plugin_Handled;
}

void RestartServer()
{
	UnloadAccelerator();
	SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
	ServerCommand("crash");
}

void UnloadAccelerator()
{
	int Id = GetAcceleratorId();
	if (Id != -1)
	{
		ServerCommand("sm exts unload %i 0", Id);
		ServerExecute();
	}
}

//by sorallll
int GetAcceleratorId()
{
	char sBuffer[512];
	ServerCommandEx(sBuffer, sizeof(sBuffer), "sm exts list");
	int index = SplitString(sBuffer, "] Accelerator (", sBuffer, sizeof(sBuffer));
	if(index == -1)
		return -1;

	for(int i = strlen(sBuffer); i >= 0; i--)
	{
		if(sBuffer[i] == '[')
			return StringToInt(sBuffer[i + 1]);
	}

	return -1;
}
