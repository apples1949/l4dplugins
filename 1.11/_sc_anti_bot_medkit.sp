#include <sourcemod>
#include <sdkhooks>
#include <dhooks>
#include <sdktools_functions>

Handle hShouldStartAction = null;

ConVar cvmkp_minhealth = null;
ConVar cvmkp_usetemphealth = null;
ConVar pain_pills_decay_rate = null;
ConVar ShowMsgCVAR=null;

const int UseAction_SelfHeal = 0;
const int UseAction_TargetHeal = 1;

#define PLUGIN_VERSION "1.2.1"

public Plugin myInfo =
{
	name = "Bot Medkit Preventer",
	author = "SamaelXXX",
	description = "Prevents the use of the medkit for bot when in good health",
	version = PLUGIN_VERSION,
	url = ""
}

public void OnPluginStart()
{

	cvmkp_minhealth = CreateConVar("minhealth", "10", "Specify the amount the player needs to be at to use Medkits.", FCVAR_NOTIFY, true, 1.0, true, 100.0);
	cvmkp_usetemphealth = CreateConVar("usetemphealth", "0", "Should temporary health be included in the health check.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	ShowMsgCVAR=CreateConVar("abm_show_msg","1","Should Log out Message",FCVAR_NOTIFY);

	pain_pills_decay_rate = FindConVar("pain_pills_decay_rate");

	Handle hGameConfig = LoadGameConfigFile("antimedkit");
	if(hGameConfig == null)
	{
		SetFailState("Gamedata file antimedkit.txt is missing!");
		return;
	}

	int offset = GameConfGetOffset(hGameConfig, "CFirstAidKit::ShouldStartAction");
	hShouldStartAction = DHookCreate(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, OnShouldStartAction);
	DHookAddParam(hShouldStartAction, HookParamType_Int);
	DHookAddParam(hShouldStartAction, HookParamType_CBaseEntity);
	DHookAddParam(hShouldStartAction, HookParamType_CBaseEntity);
	delete hGameConfig;

	int entity = -1;
	
	while ((entity = FindEntityByClassname(entity, "weapon_first_aid_kit")) != -1)
	{
		DHookEntity(hShouldStartAction, true, entity);
	}

	AutoExecConfig(true, "anti_bot_medkit");

}

public void OnEntityCreated(int entity, const char[] szClassname)
{
	if(StrEqual("weapon_first_aid_kit", szClassname, false))
	{
		DHookEntity(hShouldStartAction, true, entity);
	}
}

public MRESReturn OnShouldStartAction(int pThis, Handle hReturn, Handle hParams)
{
	int client = GetEntPropEnt(pThis, Prop_Data, "m_hOwner");
	int useAction = DHookGetParam(hParams, 1);
	int target = DHookGetParam(hParams, 3);

	if(!IsFakeClient(client))
	{
		return MRES_Ignored;
	}

	if(IsValidEntity(client))
	{
		// Ignore if we are in Black / White Mode
		if(GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike"))
			return MRES_Ignored;

		if(useAction == UseAction_SelfHeal)
		{
			if(cvmkp_usetemphealth.BoolValue)
			{
				if(GetClientRealHealth(client) > cvmkp_minhealth.IntValue)
				{
					PrintDebugMessage("\x03[AI行为规范] \x01已拦截电脑的自我打包行为");
					DHookSetReturn(hReturn, false);
					return MRES_Supercede;
				}
			}
			// This only checks normal hp. It does not check for temp health
			if(GetClientHealth(client) > cvmkp_minhealth.IntValue )
			{
				PrintDebugMessage("\x03[AI行为规范] \x01已拦截电脑的自我打包行为");
				DHookSetReturn(hReturn, false);
				return MRES_Supercede;
			}
		}
		// else if(useAction == UseAction_TargetHeal && IsValidEntity(target))
		// {
		// 	if(cvmkp_usetemphealth.BoolValue)
		// 	{
		// 		if(GetClientRealHealth(target) > cvmkp_minhealth.IntValue)
		// 		{
		// 			PrintDebugMessage("\x03[AI行为规范] \x01已拦截电脑为玩家打包的行为");
		// 			DHookSetReturn(hReturn, false);
		// 			return MRES_Supercede;
		// 		}
		// 	}
		// 	// This only checks normal hp. It does not check for temp health
		// 	if(GetClientHealth(target) > cvmkp_minhealth.IntValue )
		// 	{
		// 		PrintDebugMessage("\x03[AI行为规范] \x01已拦截电脑为玩家打包的行为");
		// 		DHookSetReturn(hReturn, false);
		// 		return MRES_Supercede;
		// 	}
		// }	
	}
	return MRES_Ignored;
}


int GetClientRealHealth(int client)
{
	// Code based on: https://forums.alliedmods.net/showthread.php?t=144780
	float buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");

	// Time difference between using the temp health item and current time.
	float bufferTimeDifference = GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");

	// This is used to determine the amount of time has to pass before 1 Temp HP is removed.
	float constant = 1.0 / pain_pills_decay_rate.FloatValue;

	float tempHealth = buffer - (bufferTimeDifference / constant);
	if(tempHealth < 0.0)
		tempHealth = 0.0;

	return GetClientHealth(client) + RoundToFloor(tempHealth);
}

stock bool PrintDebugMessage(const char[] msg)
{
	int showMsg=GetConVarInt(ShowMsgCVAR);
	if(showMsg==1)
	{
		PrintToChatAll(msg);
	}		
}