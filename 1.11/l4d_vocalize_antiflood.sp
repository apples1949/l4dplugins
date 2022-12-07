/* Includes */
#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdktools>
#include <sceneprocessor>

/* Plugin Information */
public Plugin myinfo = 
{
	name		= "Vocalize Anti-Flood",
	author		= "Buster \"Mr. Zero\" Nielsen & HarryPotter",
	description	= "Stops vocalize flooding when reaching token limit",
	version		= "1.3",
	url			= "https://forums.alliedmods.net/showthread.php?t=241588"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	EngineVersion test = GetEngineVersion();
	
	if (test != Engine_Left4Dead2 && test != Engine_Left4Dead )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}


ConVar hConVar1, hConVar2, hConVar3, hConVar4, hConVar5, g_hImmueAccess;

int g_iPlayerTokenTime;
int g_iWorldTokenTime;
int g_iPlayerTokenLimit;
int g_iWorldTokenLimit;
char g_sImmueAcclvl[16];
bool g_bMessage;

float g_flLastVocalizeTimeStamp[MAXPLAYERS + 1];
float g_flLastWorldVocalizeTimeStamp[MAXPLAYERS + 1];
int g_VocalizeTokens[MAXPLAYERS + 1];
int g_WorldVocalizeTokens[MAXPLAYERS + 1];
int g_VocalizeFloodCheckTick[MAXPLAYERS + 1];
int iClientFlags[MAXPLAYERS+1];

/* Plugin Functions */
public void OnPluginStart()
{
	hConVar1 = CreateConVar("l4d_vocalize_antiflood_player_token_time", "20", "一个玩家多少秒后自动减少一个发声标记(秒)", FCVAR_NOTIFY, true, 1.0);
	hConVar2 = CreateConVar("l4d_vocalize_antiflood_word_token_time", "5", "整个世界多少秒后自动减少一个发声标记(秒)", FCVAR_NOTIFY, true, 1.0);
	hConVar3 = CreateConVar("l4d_vocalize_antiflood_player_token_limit", "5", "一个玩家最多有多少发声标记(-1 =无限制)", FCVAR_NOTIFY, true, -1.0);
	hConVar4 = CreateConVar("l4d_vocalize_antiflood_world_token_limit", "-1", "整个最多有多少发声标记(-1 =无限制)", FCVAR_NOTIFY, true, -1.0);
	hConVar5 = CreateConVar("l4d_vocalize_antiflood_notify", "1", "如果是1，则向玩家通知限制信息", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hImmueAccess = CreateConVar("l4d_vocalize_antiflood_immue_flag", "-1", "拥有这些权限的玩家免疫插件限制(无内容=所有人, -1=没有人）", FCVAR_NOTIFY);
	
	GetCvars();
	HookConVarChange(hConVar1, ConVarChanged_ConVar1);
	HookConVarChange(hConVar2, ConVarChanged_ConVar2);
	HookConVarChange(hConVar3, ConVarChanged_Cvars);
	HookConVarChange(hConVar4, ConVarChanged_Cvars);
	HookConVarChange(hConVar5, ConVarChanged_Cvars);
	HookConVarChange(g_hImmueAccess, ConVarChanged_Cvars);	
}
	
void GetCvars()
{
	g_iPlayerTokenTime = hConVar1.IntValue;
	g_iWorldTokenTime = hConVar2.IntValue;
	g_iPlayerTokenLimit = hConVar3.IntValue;
	g_iWorldTokenLimit = hConVar4.IntValue;
	g_bMessage = hConVar5.BoolValue;
	g_hImmueAccess.GetString(g_sImmueAcclvl,sizeof(g_sImmueAcclvl));
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

public void ConVarChanged_ConVar1(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
	
}

public void ConVarChanged_ConVar2(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

public void OnSceneStageChanged(int scene, SceneStages stage)
{
	if (stage != SceneStage_SpawnedPost)
	{
		return;
	}
	
	int client = GetActorFromScene(scene);
	if (client <= 0 || client > MaxClients)
	{
		return;
	}
	
	if (g_VocalizeFloodCheckTick[client] == GetGameTickCount())
	{
		return;
	}
	
	int initiator = GetSceneInitiator(scene);
	if (IsPlayerVocalizeFlooding(client, initiator) == false)
	{
		return;
	}
	
	CancelScene(scene);
}

public Action OnVocalizationProcess(int client, const char[] vocalize, int initiator)
{
	g_VocalizeFloodCheckTick[client] = GetGameTickCount();
	return (IsPlayerVocalizeFlooding(client, initiator) ? Plugin_Stop : Plugin_Continue);
}

bool IsPlayerVocalizeFlooding(int client, int initiator)
{
	bool fromWorld = initiator == SCENE_INITIATOR_WORLD;
	if (initiator == SCENE_INITIATOR_PLUGIN || (initiator != client && fromWorld == false))
	{
		return false;
	}

	if (HasAccess(client, g_sImmueAcclvl)) return false;
	
	
	float curTime = GetEngineTime();
	int dif;
	
	if (fromWorld)
	{
		if (g_iWorldTokenLimit == -1) return false;

		dif = RoundFloat(curTime - g_flLastWorldVocalizeTimeStamp[client]) / g_iWorldTokenTime;
		g_WorldVocalizeTokens[client] -= dif;
		if (g_WorldVocalizeTokens[client] < 0) g_WorldVocalizeTokens[client] = 0;

		g_WorldVocalizeTokens[client]++;
		if(g_WorldVocalizeTokens[client] > g_iWorldTokenLimit) return true;
		
		g_flLastWorldVocalizeTimeStamp[client] = curTime;
	}
	else
	{
		if (g_iPlayerTokenLimit == -1) return false;
		
		dif = RoundFloat(curTime - g_flLastVocalizeTimeStamp[client]) / g_iPlayerTokenTime;
		g_VocalizeTokens[client] -= dif;
		if (g_VocalizeTokens[client] < 0) g_VocalizeTokens[client]=0;

		g_VocalizeTokens[client]++;
		if (g_VocalizeTokens[client] > g_iPlayerTokenLimit) 
		{
			if(g_bMessage) PrintToChat(client, "[\x05提示\x01]你已达到角色语音限制", client);
			return true;
		}
		
		g_flLastVocalizeTimeStamp[client] = curTime;
	}
	
	return false;
}

public void OnClientPostAdminCheck(int client)
{
	if(!IsFakeClient(client)) iClientFlags[client] = GetUserFlagBits(client);
}

public bool HasAccess(int client, char[] g_sAcclvl)
{
	// no permissions set
	if (strlen(g_sAcclvl) == 0)
		return true;

	else if (StrEqual(g_sAcclvl, "-1"))
		return false;

	// check permissions
	if ( iClientFlags[client] & ReadFlagString(g_sAcclvl) || (iClientFlags[client] & ADMFLAG_ROOT) )
	{
		return true;
	}

	return false;
}