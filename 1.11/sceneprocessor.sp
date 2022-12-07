#define PLUGIN_VERSION "1.33.2"

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <sceneprocessor>

int iSkippedFrames;
char sVocalizeScene[MAXPLAYERS+1][MAX_VOCALIZE_LENGTH];
bool bSceneHasInitiator[MAXPLAYERS+1], bScenesUnprocessed, bUnvocalizedCommands, bJailbreakVocalize, bIsL4D;

float fStartTimeStamp, fVocalizePreDelay[MAXPLAYERS+1], fVocalizePitch[MAXPLAYERS+1];
Handle hSceneStageForward, hVocalizeCommandForward;

ArrayList alVocalize;
ArrayStack asScene;

enum struct SceneData
{
	SceneStages ssDataBit;
	bool bInFakePostSpawn;
	float fTimeStampData;
	int iActorData;
	int iInitiatorData;
	char sFileData[MAX_SCENEFILE_LENGTH];
	char sVocalizeData[MAX_VOCALIZE_LENGTH];
	float fPreDelayData;
	float fPitchData;
}

SceneData nSceneData[2048];
int iScenePlaying[MAXPLAYERS+1], iVocalizeTick[MAXPLAYERS+1], iVocalizeInitiator[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evGame = GetEngineVersion();
	if (evGame == Engine_Left4Dead)
	{
		bIsL4D = true;
	}
	else if (evGame != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "[SP] Plugin Supports L4D And L4D2 Only!");
		return APLRes_Failure;
	}
	
	CreateNative("GetSceneStage", SP_GetSceneStage);
	CreateNative("GetSceneStartTimeStamp", SP_GetSceneStartTimeStamp);
	CreateNative("GetActorFromScene", SP_GetSceneActor);
	CreateNative("GetSceneFromActor", SP_GetActorScene);
	CreateNative("GetSceneInitiator", SP_GetSceneInitiator);
	CreateNative("GetSceneFile", SP_GetSceneFile);
	CreateNative("GetSceneVocalize", SP_GetSceneVocalize);
	CreateNative("GetScenePreDelay", SP_GetScenePreDelay);
	CreateNative("SetScenePreDelay", SP_SetScenePreDelay);
	CreateNative("GetScenePitch", SP_GetScenePitch);
	CreateNative("SetScenePitch", SP_SetScenePitch);
	CreateNative("CancelScene", SP_CancelScene);
	CreateNative("PerformScene", SP_PerformScene);
	CreateNative("PerformSceneEx", SP_PerformSceneEx);
	
	RegPluginLibrary("sceneprocessor");
	return APLRes_Success;
}

public any SP_GetSceneStage(Handle plugin, int numParams)
{
	if (numParams == 0)
	{
		return SceneStage_Unknown;
	}
	
	int scene = GetNativeCell(1);
	if (scene < 1 || scene > 2048 || !IsValidEntity(scene))
	{
		return SceneStage_Unknown;
	}
	
	return nSceneData[scene].ssDataBit;
}

public any SP_GetSceneStartTimeStamp(Handle plugin, int numParams)
{
	if (numParams == 0)
	{
		return 0.0;
	}
	
	int scene = GetNativeCell(1);
	if (!IsValidScene(scene))
	{
		return 0.0;
	}
	
	return nSceneData[scene].fTimeStampData;
}

public int SP_GetActorScene(Handle plugin, int numParams)
{
	if (numParams == 0)
	{
		return INVALID_ENT_REFERENCE;
	}
	
	int iActor = GetNativeCell(1);
	if (iActor < 1 || iActor > MaxClients || !IsClientInGame(iActor) || GetClientTeam(iActor) != 2 || !IsPlayerAlive(iActor))
	{
		return INVALID_ENT_REFERENCE;
	}
	
	return iScenePlaying[iActor];
}

public int SP_GetSceneActor(Handle plugin, int numParams)
{
	if (numParams == 0)
	{
		return 0;
	}
	
	int scene = GetNativeCell(1);
	if (!IsValidScene(scene))
	{
		return 0;
	}
	
	return nSceneData[scene].iActorData;
}

public int SP_GetSceneInitiator(Handle plugin, int numParams)
{
	if (numParams == 0)
	{
		return 0;
	}
	
	int scene = GetNativeCell(1);
	if (!IsValidScene(scene))
	{
		return 0;
	}
	
	return nSceneData[scene].iInitiatorData;
}

public int SP_GetSceneFile(Handle plugin, int numParams)
{
	if (numParams != 3)
	{
		return 0;
	}
	
	int scene = GetNativeCell(1);
	if (!IsValidScene(scene))
	{
		return 0;
	}
	
	int len = GetNativeCell(3);
	
	int bytesWritten;
	SetNativeString(2, nSceneData[scene].sFileData, len, _, bytesWritten);
	return bytesWritten;
}

public int SP_GetSceneVocalize(Handle plugin, int numParams)
{
	if (numParams != 3)
	{
		return 0;
	}
	
	int scene = GetNativeCell(1);
	if (!IsValidScene(scene))
	{
		return 0;
	}
	
	int len = GetNativeCell(3);
	
	int bytesWritten;
	SetNativeString(2, nSceneData[scene].sVocalizeData, len, _, bytesWritten);
	return bytesWritten;
}

public any SP_GetScenePreDelay(Handle plugin, int numParams)
{
	if (numParams == 0)
	{
		return 0.0;
	}
	
	int scene = GetNativeCell(1);
	if (!IsValidScene(scene))
	{
		return 0.0;
	}
	
	return nSceneData[scene].fPreDelayData;
}

public int SP_SetScenePreDelay(Handle plugin, int numParams)
{
	if (numParams != 2)
	{
		return 0;
	}
	
	int scene = GetNativeCell(1);
	if (!IsValidScene(scene))
	{
		return 0;
	}
	
	float fPreDelay = GetNativeCell(2);
	
	SetEntPropFloat(scene, Prop_Data, "m_flPreDelay", fPreDelay);
	nSceneData[scene].fPreDelayData = fPreDelay;

	return 0;
}

public int SP_GetScenePitch(Handle plugin, int numParams)
{
	if (numParams == 0)
	{
		return 0;
	}
	
	int scene = GetNativeCell(1);
	if (!IsValidScene(scene))
	{
		return 0;
	}
	
	return view_as<int>(nSceneData[scene].fPitchData);
}

public int SP_SetScenePitch(Handle plugin, int numParams)
{
	if (numParams != 2)
	{
		return 0;
	}
	
	int scene = GetNativeCell(1);
	if (!IsValidScene(scene))
	{
		return 0;
	}
	
	float fPitch = GetNativeCell(2);
	
	SetEntPropFloat(scene, Prop_Data, "m_fPitch", fPitch);
	nSceneData[scene].fPitchData = fPitch;

	return 0;
}

public int SP_CancelScene(Handle plugin, int numParams)
{
	if (numParams == 0)
	{
		return 0;
	}
	
	int scene = GetNativeCell(1);
	if (scene < 1 || scene > 2048 || !IsValidEntity(scene))
	{
		return 0;
	}
	
	SceneStages ssBit = nSceneData[scene].ssDataBit;
	if (ssBit == SceneStage_Unknown)
	{
		return 0;
	}
	else if (ssBit == SceneStage_Started || (ssBit == SceneStage_SpawnedPost && nSceneData[scene].bInFakePostSpawn))
	{
		AcceptEntityInput(scene, "Cancel");
	}
	else if (ssBit != SceneStage_Cancelled && ssBit != SceneStage_Completion && ssBit != SceneStage_Killed)
	{
		AcceptEntityInput(scene, "Kill");
	}

	return 0;
}

public int SP_PerformScene(Handle plugin, int numParams)
{
	if (numParams < 2)
	{
		return 0;
	}
	
	int client = GetNativeCell(1);
	
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
	{
		return 0;
	}
	
	static char sVocalize[MAX_VOCALIZE_LENGTH], sFile[MAX_SCENEFILE_LENGTH];
	float fPreDelay = DEFAULT_SCENE_PREDELAY, fPitch = DEFAULT_SCENE_PITCH;
	int iInitiator = SCENE_INITIATOR_PLUGIN;
	
	if (GetNativeString(2, sVocalize, MAX_VOCALIZE_LENGTH) != SP_ERROR_NONE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Unknown Vocalize Parameter!");
		return 0;
	}
	
	if (numParams >= 3)
	{
		if (GetNativeString(3, sFile, MAX_SCENEFILE_LENGTH) != SP_ERROR_NONE)
		{
			ThrowNativeError(SP_ERROR_NATIVE, "Unknown File Parameter!");
			return 0;
		}
	}
	
	if (numParams >= 4)
	{
		fPreDelay = GetNativeCell(4);
	}
	
	if (numParams >= 5)
	{
		fPitch = GetNativeCell(5);
	}
	
	if (numParams >= 6)
	{
		iInitiator = GetNativeCell(6);
	}
	
	Scene_Perform(client, sVocalize, sFile, fPreDelay, fPitch, iInitiator);

	return 0;
}

public int SP_PerformSceneEx(Handle plugin, int numParams)
{
	if (numParams < 2)
	{
		return 0;
	}
	
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client))
	{
		return 0;
	}
	
	static char sVocalize[MAX_VOCALIZE_LENGTH], sFile[MAX_SCENEFILE_LENGTH];
	float fPreDelay = DEFAULT_SCENE_PREDELAY, fPitch = DEFAULT_SCENE_PITCH;
	int iInitiator = SCENE_INITIATOR_PLUGIN;
	
	if (GetNativeString(2, sVocalize, MAX_VOCALIZE_LENGTH) != SP_ERROR_NONE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Unknown Vocalize Parameter!");
		return 0;
	}
	
	if (numParams >= 3)
	{
		if (GetNativeString(3, sFile, MAX_SCENEFILE_LENGTH) != SP_ERROR_NONE)
		{
			ThrowNativeError(SP_ERROR_NATIVE, "Unknown File Parameter!");
			return 0;
		}
	}
	
	if (numParams >= 4)
	{
		fPreDelay = GetNativeCell(4);
	}
	
	if (numParams >= 5)
	{
		fPitch = GetNativeCell(5);
	}
	
	if (numParams >= 6)
	{
		iInitiator = GetNativeCell(6);
	}
	
	Scene_Perform(client, sVocalize, sFile, fPreDelay, fPitch, iInitiator, true);

	return 0;
}

public Plugin myinfo = 
{
	name = "Scene Processor",
	author = "Buster \"Mr. Zero\" Nielsen (Fork by cravenge & Dragokas)",
	description = "Provides Forwards and Natives For Scenes' Manipulation.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=241585"
};

public void OnPluginStart()
{
	hSceneStageForward = CreateGlobalForward("OnSceneStageChanged", ET_Ignore, Param_Cell, Param_Cell);
	hVocalizeCommandForward = CreateGlobalForward("OnVocalizeCommand", ET_Hook, Param_Cell, Param_String, Param_Cell);
	
	CreateConVar("sceneprocessor_version", PLUGIN_VERSION, "Scene Processor Version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	if (!bIsL4D)
	{
		ConVar spJailbreakVocalize = CreateConVar("sceneprocessor_jailbreak_vocalize", "1", "Enable/Disable Jailbreak Vocalizations", FCVAR_SPONLY|FCVAR_NOTIFY);
		spJailbreakVocalize.AddChangeHook(OnSPCVarChanged);
		bJailbreakVocalize = spJailbreakVocalize.BoolValue;
	}
	
	AddCommandListener(OnVocalizeCmd, "vocalize");
	
	asScene = new ArrayStack();
	alVocalize = new ArrayList(MAX_VOCALIZE_LENGTH);
	
	for (int i = 1; i < 2049; i++)
	{
		if (IsValidEntity(i) && IsValidEdict(i))
		{
			SceneData_SetStage(i, SceneStage_Unknown);
		}
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ResetClientVocalizeData(i);
		}
	}
}

public void OnSPCVarChanged(ConVar cvar, const char[] sOldValue, const char[] sNewValue)
{
	bJailbreakVocalize = cvar.BoolValue;
}

public Action OnVocalizeCmd(int client, const char[] command, int args)
{
	if (client == 0 || args == 0)
	{
		return Plugin_Continue;
	}
	
	if (!IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	static char sVocalize[128];
	GetCmdArg(1, sVocalize, sizeof(sVocalize));
	
	if (!bIsL4D && args != 2)
	{
		if (bJailbreakVocalize)
		{
			JailbreakVocalize(client, sVocalize);
		}
		return Plugin_Handled;
	}
	
	int iTick = GetGameTickCount();
	
	if (!bSceneHasInitiator[client] || (iVocalizeTick[client] > 0 && iVocalizeTick[client] != iTick))
	{
		iVocalizeInitiator[client] = client;
		
		if (!bIsL4D && args > 1 && StrEqual(sVocalize, "smartlook", false))
		{
			static char sTime[32];
			GetCmdArg(2, sTime, sizeof(sTime));
			if (StrEqual(sTime, "auto", false))
			{
				iVocalizeInitiator[client] = SCENE_INITIATOR_WORLD;
			}
		}
	}
	
	strcopy(sVocalizeScene[client], MAX_VOCALIZE_LENGTH, sVocalize);
	iVocalizeTick[client] = iTick;
	
	Action aResult = Plugin_Continue;
	
	Call_StartForward(hVocalizeCommandForward);
	Call_PushCell(client);
	Call_PushString(sVocalize);
	Call_PushCell(iVocalizeInitiator[client]);
	Call_Finish(aResult);
	
	return (aResult == Plugin_Stop) ? Plugin_Handled : Plugin_Continue;
}

public void OnPluginEnd()
{
	RemoveCommandListener(OnVocalizeCmd, "vocalize");
}

public void OnMapStart()
{
	iSkippedFrames = 0;
	fStartTimeStamp = GetGameTime();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity < 1 || entity > 2048)
	{
		return;
	}
	
	if (StrEqual(classname, "instanced_scripted_scene"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
		SceneData_SetStage(entity, SceneStage_Created);
	}
}

public void OnSpawnPost(int entity)
{
	int iActor = GetEntPropEnt(entity, Prop_Data, "m_hOwner");
	nSceneData[entity].iActorData = iActor;
	
	static char sFile[MAX_SCENEFILE_LENGTH];
	GetEntPropString(entity, Prop_Data, "m_iszSceneFile", sFile, MAX_SCENEFILE_LENGTH);
	
	strcopy(nSceneData[entity].sFileData, MAX_SCENEFILE_LENGTH, sFile);
	nSceneData[entity].fPitchData = GetEntPropFloat(entity, Prop_Data, "m_fPitch");
	
	if (iActor > 0 && iActor <= MaxClients && IsClientInGame(iActor))
	{
		if (iVocalizeTick[iActor] == GetGameTickCount())
		{
			strcopy(nSceneData[entity].sVocalizeData, MAX_VOCALIZE_LENGTH, sVocalizeScene[iActor]);
			
			nSceneData[entity].iInitiatorData = iVocalizeInitiator[iActor];
			nSceneData[entity].fPreDelayData = fVocalizePreDelay[iActor];
			nSceneData[entity].fPitchData = fVocalizePitch[iActor];
		}
		ResetClientVocalizeData(iActor);
	}
	
	SetEntPropFloat(entity, Prop_Data, "m_fPitch", nSceneData[entity].fPitchData);
	SetEntPropFloat(entity, Prop_Data, "m_flPreDelay", nSceneData[entity].fPreDelayData);
	
	asScene.Push(entity);
	bScenesUnprocessed = true;
	
	HookSingleEntityOutput(entity, "OnStart", OnSceneStart_EntOutput);
	HookSingleEntityOutput(entity, "OnCanceled", OnSceneCanceled_EntOutput);
	
	SceneData_SetStage(entity, SceneStage_Spawned);
}

public void OnSceneStart_EntOutput(const char[] output, int caller, int activator, float delay)
{
	if (caller < 1 || caller > 2048 || !IsValidEntity(caller))
	{
		return;
	}
	
	static char sFile[MAX_SCENEFILE_LENGTH];
	strcopy(sFile, MAX_SCENEFILE_LENGTH, nSceneData[caller].sFileData);
	if (!sFile[0])
	{
		return;
	}
	
	nSceneData[caller].fTimeStampData = GetEngineTime();
	
	if (nSceneData[caller].ssDataBit == SceneStage_Spawned)
	{
		nSceneData[caller].bInFakePostSpawn = true;
		SceneData_SetStage(caller, SceneStage_SpawnedPost);
	}
	
	if (nSceneData[caller].ssDataBit == SceneStage_SpawnedPost)
	{
		int iActor = nSceneData[caller].iActorData;
		if (iActor > 0 && iActor <= MaxClients && IsClientInGame(iActor))
		{
			iScenePlaying[iActor] = caller;
		}
		SceneData_SetStage(caller, SceneStage_Started);
	}
}

public void OnSceneCanceled_EntOutput(const char[] output, int caller, int activator, float delay)
{
	if (caller < 1 || caller > 2048 || !IsValidEntity(caller))
	{
		return;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (iScenePlaying[i] == caller)
		{
			iScenePlaying[i] = INVALID_ENT_REFERENCE;
			break;
		}
	}
	
	SceneData_SetStage(caller, SceneStage_Cancelled);
}

public void OnEntityDestroyed(int entity)
{
	if (entity < 1 || entity > 2048 || !IsValidEdict(entity))
	{
		return;
	}
	
	static char sEntityClass[64];
	GetEdictClassname(entity, sEntityClass, sizeof(sEntityClass));
	if (!StrEqual(sEntityClass, "instanced_scripted_scene"))
	{
		return;
	}
	
	SDKUnhook(entity, SDKHook_SpawnPost, OnSpawnPost);
	
	SceneStages ssBit = nSceneData[entity].ssDataBit;
	if (ssBit != SceneStage_Unknown)
	{
		if (ssBit == SceneStage_Started)
		{
			SceneData_SetStage(entity, SceneStage_Completion);
		}
		SceneData_SetStage(entity, SceneStage_Killed);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || iScenePlaying[i] != entity)
			{
				continue;
			}
			
			iScenePlaying[i] = INVALID_ENT_REFERENCE;
			break;
		}
	}
	
	SceneData_SetStage(entity, SceneStage_Unknown);
}

public void OnClientDisconnect(int client)
{
	if (client == 0)
	{
		return;
	}
	
	iScenePlaying[client] = INVALID_ENT_REFERENCE;
}

public void OnGameFrame()
{
	iSkippedFrames += 1;
	if (iSkippedFrames < 3)
	{
		return;
	}
	
	iSkippedFrames = 1;
	if (bScenesUnprocessed)
	{
		bScenesUnprocessed = false;
		
		int dScene;
		while (!asScene.Empty)
		{
			asScene.Pop(dScene);
			if (dScene < 1 || dScene > 2048 || !IsValidEntity(dScene))
			{
				continue;
			}
			
			if (nSceneData[dScene].ssDataBit != SceneStage_Spawned)
			{
				continue;
			}
			
			nSceneData[dScene].fPreDelayData = GetEntPropFloat(dScene, Prop_Data, "m_flPreDelay");
			nSceneData[dScene].bInFakePostSpawn = false;
			
			SceneData_SetStage(dScene, SceneStage_SpawnedPost);
		}
	}
	
	if (bUnvocalizedCommands)
	{
		int iArraySize = alVocalize.Length,
			iCurrentTick = GetGameTickCount();
		
		static char sVocalize[MAX_VOCALIZE_LENGTH];
		float fPreDelay, fPitch;
		int client, dInitiator, dTick;
		
		for (int i = 0; i < iArraySize; i += 6)
		{
			dTick = alVocalize.Get(i + 5);
			if (iCurrentTick != dTick)
			{
				continue;
			}
			
			client = alVocalize.Get(i + 0);
			alVocalize.GetString(i + 1, sVocalize, MAX_VOCALIZE_LENGTH);
			fPreDelay = view_as<float>(alVocalize.Get(i + 2));
			fPitch = view_as<float>(alVocalize.Get(i + 3));
			dInitiator = alVocalize.Get(i + 4);
			
			Scene_Perform(client, sVocalize, _, fPreDelay, fPitch, dInitiator, true);
			
			for (int j = 0; j < 6; j++)
			{
				alVocalize.Erase(i);
				iArraySize -= 1;
			}
		}
		if (iArraySize < 1)
		{
			alVocalize.Clear();
			bUnvocalizedCommands = false;
		}
	}
}

public void OnMapEnd()
{
	iSkippedFrames = 0;
	
	bScenesUnprocessed = false;
	bUnvocalizedCommands = false;
	
	while (!asScene.Empty)
	{
		PopStack(asScene);
	}
	alVocalize.Clear();
	
	for (int i = 1; i < 2049; i++)
	{
		if (IsValidEntity(i) && IsValidEdict(i))
		{
			SceneData_SetStage(i, SceneStage_Unknown);
		}
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			iScenePlaying[i] = INVALID_ENT_REFERENCE;
		}
	}
}

void ResetClientVocalizeData(int client)
{
	iVocalizeTick[client] = 0;
	sVocalizeScene[client] = "\0";
	bSceneHasInitiator[client] = false;
	iVocalizeInitiator[client] = SCENE_INITIATOR_WORLD;
	fVocalizePreDelay[client] = DEFAULT_SCENE_PREDELAY;
	fVocalizePitch[client] = DEFAULT_SCENE_PITCH;
}

void SceneData_SetStage(int scene, SceneStages stage)
{
	nSceneData[scene].ssDataBit = stage;
	
	if (stage != SceneStage_Unknown)
	{
		Call_StartForward(hSceneStageForward);
		Call_PushCell(scene);
		Call_PushCell(stage);
		Call_Finish();
	}
	else
	{
		nSceneData[scene].bInFakePostSpawn = false;
		nSceneData[scene].fTimeStampData = 0.0;
		nSceneData[scene].iActorData = 0;
		nSceneData[scene].iInitiatorData = 0;
		strcopy(nSceneData[scene].sFileData, MAX_SCENEFILE_LENGTH, "\0");
		strcopy(nSceneData[scene].sVocalizeData, MAX_VOCALIZE_LENGTH, "\0");
		nSceneData[scene].fPreDelayData = DEFAULT_SCENE_PREDELAY;
		nSceneData[scene].fPitchData = DEFAULT_SCENE_PITCH;
	}
}

void Scene_Perform(int client, const char[] sVocalizeParam, const char[] sFileParam = "", float fScenePreDelay = DEFAULT_SCENE_PREDELAY, float fScenePitch = DEFAULT_SCENE_PITCH, int iSceneInitiator = SCENE_INITIATOR_PLUGIN, bool bVocalizeNow = false)
{
	if (sFileParam[0] && FileExists(sFileParam, true))
	{
		int iScene = CreateEntityByName("instanced_scripted_scene");
		DispatchKeyValue(iScene, "SceneFile", sFileParam);
		
		SetEntPropEnt(iScene, Prop_Data, "m_hOwner", client);
		nSceneData[iScene].iActorData = client;
		SetEntPropFloat(iScene, Prop_Data, "m_flPreDelay", fScenePreDelay);
		nSceneData[iScene].fPreDelayData = fScenePreDelay;
		SetEntPropFloat(iScene, Prop_Data, "m_fPitch", fScenePitch);
		nSceneData[iScene].fPitchData = fScenePitch;
		
		nSceneData[iScene].iInitiatorData = iSceneInitiator;
		strcopy(nSceneData[iScene].sVocalizeData, MAX_VOCALIZE_LENGTH, sVocalizeParam);
		
		DispatchSpawn(iScene);
		ActivateEntity(iScene);
		
		AcceptEntityInput(iScene, "Start", client, client);
	}
	else if (sVocalizeParam[0])
	{
		if (bVocalizeNow)
		{
			iVocalizeInitiator[client] = iSceneInitiator;
			bSceneHasInitiator[client] = true;
			fVocalizePreDelay[client] = fScenePreDelay;
			fVocalizePitch[client] = fScenePitch;
			
			if (bIsL4D)
			{
				FakeClientCommandEx(client, "vocalize %s", sVocalizeParam);
			}
			else
			{
				JailbreakVocalize(client, sVocalizeParam);
			}
		}
		else
		{
			alVocalize.Push(client);
			alVocalize.PushString(sVocalizeParam);
			alVocalize.Push(fScenePreDelay);
			alVocalize.Push(fScenePitch);
			alVocalize.Push(iSceneInitiator);
			alVocalize.Push(GetGameTickCount() + 10 - 1);
			
			bUnvocalizedCommands = true;
		}
	}
}

void JailbreakVocalize(int client, const char[] sVocalize)
{
	char sBuffer[2][32];
	FloatToString((GetGameTime() - fStartTimeStamp) + 2.0, sBuffer[0], 32);
	ExplodeString(sBuffer[0], ".", sBuffer, 2, 32);
	
	Format(sBuffer[1], 2, "%s\0", sBuffer[1][0]);
	FakeClientCommandEx(client, "vocalize %s #%s%s", sVocalize, sBuffer[0], sBuffer[1]);
}
