#pragma semicolon 1
#pragma newdecls required
//#define DEBUG

#include <sourcemod>
#include <sdktools>

#define PLUGIN_NAME			  "[L4D/2] Incapped Pickup Items"
#define PLUGIN_AUTHOR		  "xZk"
#define PLUGIN_DESCRIPTION	  "incapped survivors can pickup items and weapons"
#define PLUGIN_VERSION		  "1.4.0"
#define PLUGIN_URL			  "https://forums.alliedmods.net/showthread.php?t=320828"

#define GAMEDATA			"l4d2_incapped_pickup"

ConVar g_cvarEnable,g_cvarDistance, g_cvarScavengeItem, g_cvarScavengeCarry;
bool g_bCvarEnable; float g_fCvarDistance; int g_iCvarScavengeItem; bool g_bCvarScavengeCarry;

Handle g_hSDK_Call_FindUseEntity;
bool g_bIsOnUse[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	g_cvarEnable = CreateConVar("l4d_incapped_pickup", "1", "0:禁用插件, 1:启用插件", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvarDistance = CreateConVar("l4d_incapped_pickup_distance", "96.0", "可拾取物品的距离限制 (默认96) ", FCVAR_NONE, true, 1.0);
	g_cvarScavengeItem = CreateConVar("l4d_incapped_pickup_scavenge", "2", "0:无法捡起收集类物品, 1:允许倒地时拾取油桶, 2: 允许倒地拾取可乐, 3:可拾取全部物品", FCVAR_NONE, true, 0.0, true, 3.0);
	g_cvarScavengeCarry = CreateConVar("l4d_incapped_pickup_carryable", "0", "0:禁用, 1:允许拾取全部可携带物品(侏儒、煤气罐等)", FCVAR_NONE, true, 0.0, true, 1.0);
	AutoExecConfig(true, "l4d_incapped_pickup");

	g_cvarEnable.AddChangeHook(CvarsChanged);
	g_cvarDistance.AddChangeHook(CvarsChanged);
	g_cvarScavengeItem.AddChangeHook(CvarsChanged);
	g_cvarScavengeCarry.AddChangeHook(CvarsChanged);
	CvarsChanged(null, "", "");
	vLoadGameData();
}

public void CvarsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bCvarEnable = g_cvarEnable.BoolValue;
	g_fCvarDistance = g_cvarDistance.FloatValue;
	g_iCvarScavengeItem = g_cvarScavengeItem.IntValue;
	g_bCvarScavengeCarry = g_cvarScavengeCarry.BoolValue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(!g_bCvarEnable)
		return Plugin_Continue;
	
	if(!IsValidSurvivor(client))
		return Plugin_Continue;
		
	if(!IsPlayerAlive(client))
		return Plugin_Continue;
		
	if(!IsPlayerIncapped(client) || IsPlayerHanding(client) || IsPlayerCapped(client))
		return Plugin_Continue;
	
	if ((buttons & IN_USE) && !g_bIsOnUse[client]) 
	{
		g_bIsOnUse[client] = true;
		int itemtarget = iFindUseEntity(client, g_fCvarDistance);
		if(IsValidItemPickup(itemtarget)){
			AcceptEntityInput(itemtarget, "Use", client, itemtarget);
			return Plugin_Continue;
		}else{//find object blocked for invisible entities
			itemtarget = GetItemOnFloor(client, "weapon_*", g_fCvarDistance);
		}
		if (IsValidItemPickup(itemtarget) && IsVisibleTo(client, itemtarget))
		{
			int owneritem = GetEntPropEnt(itemtarget, Prop_Data, "m_hOwnerEntity");
			if ((owneritem == client || owneritem == -1)) {
				AcceptEntityInput(itemtarget, "Use", client, itemtarget);
			}
		}
	}
	else if(!(buttons & IN_USE))
	{
		g_bIsOnUse[client] = false;
	}
	return Plugin_Continue;
}

bool IsValidItemPickup(int item){
		
	if(IsValidWeapon(item)){
		if(IsWeaponGascan(item) && !(g_iCvarScavengeItem & 1)){
			return false;
		}else if(IsWeaponColaBottles(item) && !(g_iCvarScavengeItem & 2)){
			return false;
		}
		return true;
	}else if(IsValidEnt(item) && HasEntProp(item, Prop_Send, "m_isCarryable") && g_bCvarScavengeCarry){
		return true;
	}
	return false;
}

void vLoadGameData(){
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if(FileExists(sPath) == false)
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(hGameData == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Player);
	if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTerrorPlayer::FindUseEntity") == false)
		SetFailState("Failed to find offset: CTerrorPlayer::FindUseEntity");
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDK_Call_FindUseEntity = EndPrepSDKCall();
	if(g_hSDK_Call_FindUseEntity == null)
		SetFailState("Failed to create SDKCall: CTerrorPlayer::FindUseEntity");

	delete hGameData;
}

int iFindUseEntity(int client, float fUseRadius){
	return SDKCall(g_hSDK_Call_FindUseEntity, client, fUseRadius, 0.0, 0.0, false, false);
}

//https://forums.alliedmods.net/showthread.php?t=318185
int GetItemOnFloor(int client, char[] sClassname, float fDistance=101.8, float fRadius=25.0){
	float vecEye[3], vecTarget[3], vecDir1[3], vecDir2[3], ang[3];
	float dist, MAX_ANG_DELTA, ang_delta, ang_min = 0.0;
	int ent=-1, entity = -1;
	GetClientEyePosition(client, vecEye);
	while (-1 != (ent = FindEntityByClassname(ent, sClassname))) {
		if (!IsValidEnt(ent))
			continue;
			
		//GetEntPropVector(ent, Prop_Data, "m_vecOrigin", vecTarget);
		GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", vecTarget);//for weapons parented
		dist = GetVectorDistance(vecEye, vecTarget);
		
		if (dist <= fDistance)
		{
			// get directional angle between eyes and target
			SubtractVectors(vecTarget, vecEye, vecDir1);
			NormalizeVector(vecDir1, vecDir1);
		
			// get directional angle of eyes view
			GetClientEyeAngles(client, ang);
			GetAngleVectors(ang, vecDir2, NULL_VECTOR, NULL_VECTOR);
			
			// get angle delta between two directional angles
			ang_delta = GetAngle(vecDir1, vecDir2); // RadToDeg
			
			MAX_ANG_DELTA = ArcTangent(fRadius / dist); // RadToDeg
			
			if (ang_delta <= MAX_ANG_DELTA)
			{
				if(ang_delta < ang_min || ang_min == 0.0)
				{
					ang_min = ang_delta;
					entity = ent;
				}
			}
		}
	}
	return entity;
}
// by Pan XiaoHai
float GetAngle(float x1[3], float x2[3]) {
	return ArcCosine(GetVectorDotProduct(x1, x2)/(GetVectorLength(x1)*GetVectorLength(x2)));
}

//credits Mart
stock bool IsVisibleTo(int client, int target){
	float vClientPos[3];
	float vTargetPos[3];
	//float vLookAt[3];
	float vAng[3];
	float vMins[3];
	float vMaxs[3];

	GetClientEyePosition(client, vClientPos);
	//GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vClientPos);
	//GetClientEyePosition(target, vTargetPos);
	GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", vTargetPos);
	//MakeVectorFromPoints(vClientPos, vTargetPos, vLookAt);
	//GetVectorAngles(vLookAt, vAng);
	GetClientEyeAngles(client, vAng);

	Handle trace = TR_TraceRayFilterEx(vClientPos, vAng, MASK_VISIBLE, RayType_Infinite, TraceFilter, target);

	bool isVisible;

	if (TR_DidHit(trace))
	{
		isVisible = (TR_GetEntityIndex(trace) == target);

		if (!isVisible)
		{
			//vTargetPos[2] -= 62.0; // results the same as GetClientAbsOrigin
			delete trace;
			GetEntPropVector(target, Prop_Data, "m_vecMins", vMins);
			GetEntPropVector(target, Prop_Data, "m_vecMaxs", vMaxs);
			
			trace = TR_TraceHullFilterEx(vClientPos, vTargetPos, vMins, vMaxs, MASK_VISIBLE, TraceFilter, target);

			if (TR_DidHit(trace))
				isVisible = (TR_GetEntityIndex(trace) == target);
		}
	}
	delete trace;
	return isVisible;
}

bool TraceFilter(int entity, int contentsMask, int client){
    if (entity == client)
        return true;

    if (IsValidClient(entity))
        return false;

    return false;
}

stock bool IsWeaponSpawner(int weapon){
	if(IsValidWeapon(weapon)){
		char class_name[64];
		GetEntityClassname(weapon, class_name, sizeof(class_name));
		return (strncmp(class_name[strlen(class_name)-6], "_spawn", 7) == 0);
	}
	return false;
}

stock bool IsWeaponGascan(int weapon){
	if(IsValidWeapon(weapon)){
		char class_name[64];
		GetEntityClassname(weapon, class_name, sizeof(class_name));
		return (strcmp(class_name, "weapon_gascan") == 0);
	}
	return false;
}

stock bool IsWeaponColaBottles(int weapon){
	if(IsValidWeapon(weapon)){
		char class_name[64];
		GetEntityClassname(weapon, class_name, sizeof(class_name));
		return (strcmp(class_name, "weapon_cola_bottles") == 0);
	}
	return false;
}

stock bool IsValidWeapon(int weapon){
	if (IsValidEnt(weapon)) {
		char class_name[64];
		GetEntityClassname(weapon,class_name,sizeof(class_name));
		return (strncmp(class_name, "weapon_", 7) == 0);
	}
	return false;
}

//https://forums.alliedmods.net/showthread.php?t=303716
stock bool IsPlayerCapped(int client)
{	
	if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		return true;
	//only l4D2
	if(HasEntProp(client, Prop_Send, "m_pummelAttacker") && GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	if(HasEntProp(client, Prop_Send, "m_carryAttacker") && GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if(HasEntProp(client, Prop_Send, "m_jockeyAttacker") && GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	
	return false;
} 

stock bool IsPlayerHanding(int client){
	return (GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) == 1);
}

stock bool IsPlayerIncapped(int client){
	return (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) == 1);
}

stock bool IsValidSpect(int client){ 
	return (IsValidClient(client) && GetClientTeam(client) == 1 );
}

stock bool IsValidSurvivor(int client){
	return (IsValidClient(client) && GetClientTeam(client) == 2 );
}

stock bool IsValidInfected(int client){
	return (IsValidClient(client) && GetClientTeam(client) == 3 );
}

stock bool IsValidClient(int client){
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

stock bool IsValidEnt(int entity){
	return (entity > MaxClients && IsValidEntity(entity) && entity != INVALID_ENT_REFERENCE);
}
