#pragma semicolon 1

// ====[ INCLUDES ]============================================================
#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN

// ====[ DEFINES ]=============================================================
#define PLUGIN_NAME				"Enhanced Sprays | Dead Sprays"
#define PLUGIN_VERSION			"1.1"
#define SOUND_SPRAY				"player/sprayer.wav"

// ====[ HANDLES | CVARS ]=====================================================
new Handle:g_hCvarEnabled;
new Handle:g_hCvarDelay;
new Handle:g_hCvarDistance;

// ====[ CVAR VARIABLES ]======================================================
new bool:g_bEnabled;
new Float:g_fDistance;
new g_iDelay;

// ====[ VARIABLES ]===========================================================
new g_iLastSprayed				[MAXPLAYERS + 1];

// ====[ PLUGIN ]==============================================================
public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = "ReFlexPoison",
	description = "Enhances player's ability to spray",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
}

// ====[ EVENTS ]==============================================================
public OnPluginStart()
{
	CreateConVar("sm_enhancedsprays_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);

	g_hCvarEnabled = CreateConVar("sm_enhancedsprays_enabled", "1", "是否启用插件\n0 = 禁用\n1 = 启用", _, true, 0.0, true, 1.0);
	g_bEnabled = GetConVarBool(g_hCvarEnabled);
	HookConVarChange(g_hCvarEnabled, OnConVarChange);

	g_hCvarDistance = CreateConVar("sm_enhancedsprays_distance", "150", "使用喷漆的冷却时间", _, true, 0.0);
	g_fDistance = GetConVarFloat(g_hCvarDistance);
	HookConVarChange(g_hCvarDistance, OnConVarChange);

	g_hCvarDelay = CreateConVar("sm_decalfrequency", "0", "使用喷漆的冷却时间", _, true, 0.0);
	g_iDelay = GetConVarInt(g_hCvarDelay);
	HookConVarChange(g_hCvarDelay, OnConVarChange);
	
	AutoExecConfig(true,				"enhancedspray");
}

public OnConVarChange(Handle:hConvar, const String:strOldValue[], const String:strNewValue[])
{
	if(hConvar == g_hCvarEnabled)
		g_bEnabled = GetConVarBool(g_hCvarEnabled);
	if(hConvar == g_hCvarDistance)
		g_fDistance = GetConVarFloat(g_hCvarDistance);
	if(hConvar == g_hCvarDelay)
		g_iDelay = GetConVarInt(g_hCvarDelay);
}

public OnClientConnected(iClient)
{
	g_iLastSprayed[iClient] = false;
}

public OnMapStart()
{
	PrecacheSound(SOUND_SPRAY, true);
}

public Action:OnPlayerRunCmd(iClient, &iButtons, &iImpulse, Float:fVelocity[3], Float:fAngles[3], &iWeapon)
{
	if(!g_bEnabled || !IsValidClient(iClient) || iImpulse != 201)
		return Plugin_Continue;

	if(!IsPlayerAlive(iClient))
		return Plugin_Handled;

	new iTime = GetTime();
	if(iTime - g_iLastSprayed[iClient] < g_iDelay)
		return Plugin_Handled;

	decl Float:fClientEyePosition[3];
	GetClientEyePosition(iClient, fClientEyePosition);

	decl Float:fClientEyeViewPoint[3];
	GetPlayerEyeViewPoint(iClient, fClientEyeViewPoint);

	decl Float:fVector[3];
	MakeVectorFromPoints(fClientEyeViewPoint, fClientEyePosition, fVector);

	if(GetVectorLength(fVector) > g_fDistance)
		return Plugin_Handled;

	TE_Start("Player Decal");
	TE_WriteVector("m_vecOrigin", fClientEyeViewPoint);
	TE_WriteNum("m_nPlayer", iClient);
	TE_SendToAll();

	if(IsPlayerAlive(iClient))
		EmitSoundToAll(SOUND_SPRAY, iClient, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.6);

	g_iLastSprayed[iClient] = iTime;
	return Plugin_Handled;
}

// ====[ STOCKS ]==============================================================
stock bool:IsValidClient(iClient, bool:bReplay = true)
{
	if(iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return false;
	if(bReplay && (IsClientSourceTV(iClient) || IsClientReplay(iClient)))
		return false;
	return true;
}

stock GetPlayerEyeViewPoint(iClient, Float:fPosition[3])
{
	decl Float:fAngles[3];
	GetClientEyeAngles(iClient, fAngles);

	decl Float:fOrigin[3];
	GetClientEyePosition(iClient, fOrigin);

	new Handle:hTrace = TR_TraceRayFilterEx(fOrigin, fAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	if(TR_DidHit(hTrace))
	{
		TR_GetEndPosition(fPosition, hTrace);
		CloseHandle(hTrace);
		return true;
	}
	CloseHandle(hTrace);
	return false;
}

public bool:TraceEntityFilterPlayer(iEntity, iContentsMask)
{
	return iEntity > MaxClients;
}