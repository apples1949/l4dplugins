#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "2.22.1"
#define CVAR_FLAGS FCVAR_NOTIFY

#define DEBUG 0
#define ZOMBIECLASS_SMOKER	1
#define DAMAGE_SOUND "player/survivor/voice/choke_5.wav"

const float TRACE_TOLERANCE = 25.0;

ConVar g_hCvarCloudEnabled;
ConVar g_hCvarCloudDuration;
ConVar g_hCvarCloudRadius;
ConVar g_hCvarCloudDamage;
ConVar g_hCvarCloudShake;
ConVar g_hCvarCloudBlocksRevive;
ConVar g_hCvarCloudMeleeSlowEnabled;
ConVar g_hCvarCloudDamageIngame;
ConVar g_hCvarModes;
ConVar g_hCvarModesOff;
ConVar g_hCvarModesTog;
ConVar g_hCvarMPGameMode;

bool g_bCvarAllow;
bool g_bIsInCloud[MAXPLAYERS+1];
bool g_bMeleeDelay[MAXPLAYERS+1];
bool g_bAnybodyInCloud;
bool g_bMapStarted;
bool g_bCloudMeleeSlowEnabled, g_bCloudShake, g_bCloudBlocksRevive, g_bCloudDamageIngame;

float g_fCloudDamage, g_fCloudDuration, g_fCloudRadius;

int g_iMeleeEntInfo;
int g_iPropInfoGhost;

/*
	* 2.22.1 (Dragokas)
	 - Converted to new SM & MM
	 - Some optimizations
	 - Security enhancements
	 - Fixed handles leak
	 - Simplified damage code (point_hurt replaced by SDKHooks_TakeDamage).
	 - Removed Stop shake since it's already defined with timeout
	 - Removed "swapped teams" timers / events since the flag is unused.
	 - Added sound precache.
	 - Added ConVar values caching.
	 - ConVar "l4d2_cloud_gamemodesactive" ranamed into "l4d_cloud_modes"; added ConVars "l4d_cloud_modes_off" and "l4d_cloud_modes_tog".
	 - ConVar "l4d_cloud_damage_sound" moved to define DAMAGE_SOUND.
	 - Added ConVar "l4d_cloud_damage_ingame" - Damage client only when smoker still in-game (usually ~ 5 sec after kill) (1 - Yes, 0 - while cloud lifetime)
*/

public Plugin myinfo = 
{
	name = "l4d_cloud_damage",
	author = "AtomicStryker (fork by Dragokas)",
	description = "Left 4 Dead Cloud Damage",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=96665"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead && test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "This Plugin only supports L4D or L4D2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{	
	CreateConVar("l4d_cloud_damage_version", PLUGIN_VERSION, "Version of L4D Cloud Damage on this server ", CVAR_FLAGS|FCVAR_DONTRECORD);
	
	g_hCvarCloudEnabled = CreateConVar(			"l4d_cloud_damage_enabled", 	"1", 	"启用/禁用插件", CVAR_FLAGS);
	g_hCvarModes =	CreateConVar(				"l4d_cloud_modes",				"",		"在这些游戏模式下启用插件，用逗号分隔（没有空格）（空=全部）", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(				"l4d_cloud_modes_off",			"",		"在这些游戏模式下禁用插件，用逗号分隔（没有空格）（空=无）", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(				"l4d_cloud_modes_tog",			"0",	"在这些游戏模式中启用插件。0=全部，1=战役，2=生还者，4=对抗，8=清道夫。将数字相加", CVAR_FLAGS );
	g_hCvarCloudDamage = CreateConVar(			"l4d_cloud_damage_damage", 		"2.0", 	"毒烟每秒扣多少血", CVAR_FLAGS);
	g_hCvarCloudDuration = CreateConVar(		"l4d_cloud_damage_time", 		"14.0", "毒烟持续多少伤害多少秒?", CVAR_FLAGS);
	g_hCvarCloudRadius = CreateConVar(			"l4d_cloud_damage_radius", 		"175", 	"毒烟半径", CVAR_FLAGS);
	g_hCvarCloudMeleeSlowEnabled = CreateConVar("l4d_cloud_meleeslow_enabled", 	"0", 	"启用/禁用毒烟近战缓慢效果", CVAR_FLAGS);
	g_hCvarCloudShake = CreateConVar(			"l4d_cloud_shake_enabled", 		"1", 	"启用/禁用毒烟晃动屏幕", CVAR_FLAGS);
	g_hCvarCloudBlocksRevive = CreateConVar(	"l4d_cloud_blocks_revive", 		"0", 	"启用/禁用毒烟暂停恢复", CVAR_FLAGS);
	g_hCvarCloudDamageIngame = CreateConVar(	"l4d_cloud_damage_ingame", 		"0", 	"Damage client only when smoker still in-game当smoker还活着时持续伤害特感与生还 (usually ~ 5 sec after kill一般5秒后处死) (1 - Yes 启用, 0 - while cloud lifetime 禁用 仅限于毒烟持续时间)", CVAR_FLAGS);
	
	AutoExecConfig(true, "l4d_cloud_damage");
	
	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarCloudEnabled.AddChangeHook(ConVarChanged_Allow);
	
	g_hCvarCloudDamage.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCloudDuration.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCloudRadius.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCloudMeleeSlowEnabled.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCloudShake.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCloudBlocksRevive.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarCloudDamageIngame.AddChangeHook(ConVarChanged_Cvars);
	
	g_iMeleeEntInfo = FindSendPropInfo("CTerrorPlayer", "m_iShovePenalty");
	g_iPropInfoGhost = FindSendPropInfo("CTerrorPlayer", "m_isGhost");
}

void GetCvars()
{
	g_bCloudMeleeSlowEnabled = g_hCvarCloudMeleeSlowEnabled.BoolValue;
	g_bCloudShake = g_hCvarCloudShake.BoolValue;
	g_bCloudBlocksRevive = g_hCvarCloudBlocksRevive.BoolValue;
	g_bCloudDamageIngame = g_hCvarCloudDamageIngame.BoolValue;

	g_fCloudDamage = g_hCvarCloudDamage.FloatValue;
	g_fCloudDuration = g_hCvarCloudDuration.FloatValue;
	g_fCloudRadius = g_hCvarCloudRadius.FloatValue;
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarCloudEnabled.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		InitHook();
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		InitHook();
	}
}

void InitHook()
{
	static bool bHooked, bSndHooked;

	if( g_bCvarAllow ) {
		if( !bHooked ) {
			HookEvent("player_death", PlayerDeath);
			bHooked = true;
		}
	} else {
		if( bHooked ) {
			UnhookEvent("player_death", PlayerDeath);
			bHooked = false;
		}
	}
	if( g_bCvarAllow && g_bCloudMeleeSlowEnabled )
	{
		if( !bSndHooked )
		{
			AddNormalSoundHook(view_as<NormalSHook>(HookSound_Callback));
			bSndHooked = true;
		}
	}
	else {
		if( bSndHooked )
		{
			RemoveNormalSoundHook(view_as<NormalSHook>(HookSound_Callback));
			bSndHooked = false;
		}
	}
}

public void OnMapStart()
{
	g_bMapStarted = true;
	PrecacheSound(DAMAGE_SOUND, true);
}

public void OnMapEnd()
{
	g_bMapStarted = false;
}

int g_iCurrentMode;
bool IsAllowedGameMode() // thanks to SilverShot
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		if( g_bMapStarted == false )
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if( IsValidEntity(entity) )
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}

public Action PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3 || IsPlayerSpawnGhost(client))
	{
		return Plugin_Continue;
	}
	
	int class = GetEntProp(client, Prop_Send, "m_zombieClass");
	if( class == ZOMBIECLASS_SMOKER )
	{
		#if DEBUG
		PrintToChatAll("Smokerdeath caught, Plugin running");
		#endif
		
		float pos[3];
		GetClientEyePosition(client, pos);
		CreateGasCloud(client, pos);
	}
	return Plugin_Continue;
}

void CreateGasCloud(int client, float pos[3])
{
	#if DEBUG
	PrintToChatAll("Action GasCloud running");
	#endif
	
	float targettime = GetEngineTime() + g_fCloudDuration;
	
	DataPack data = new DataPack();
	data.WriteCell(GetClientUserId(client));
	data.WriteFloat(pos[0]);
	data.WriteFloat(pos[1]);
	data.WriteFloat(pos[2]);
	data.WriteFloat(targettime);
	
	CreateTimer(1.0, Point_Hurt, data, TIMER_REPEAT | TIMER_DATA_HNDL_CLOSE);
}

public Action Point_Hurt(Handle timer, DataPack dp)
{
	dp.Reset();
	int client = GetClientOfUserId(dp.ReadCell());
	float pos[3];
	pos[0] = dp.ReadFloat();
	pos[1] = dp.ReadFloat();
	pos[2] = dp.ReadFloat();
	float targettime = dp.ReadFloat();
	
	if (targettime - GetEngineTime() < 0)
	{
		#if DEBUG
		PrintToChatAll("Target Time reached Action PointHurter killing itself");
		#endif
		return Plugin_Stop;
	}
	
	#if DEBUG
	PrintToChatAll("Action PointHurter running");
	#endif
	
	if (!client || !IsClientInGame(client)) client = g_bCloudDamageIngame ? -1 : 0;
	
	float targetVector[3];
	float distance;
	
	for (int target = 1; target <= MaxClients; target++)
	{
		if (!target || !IsClientInGame(target) || !IsPlayerAlive(target) || GetClientTeam(target) != 2)
		{
			continue;
		}
		
		GetClientEyePosition(target, targetVector);
		distance = GetVectorDistance(targetVector, pos);
		
		if (distance > g_fCloudRadius || !IsVisibleTo(pos, targetVector)) continue;
		
		if( !IsFakeClient(target) )
		{
			EmitSoundToClient(target, DAMAGE_SOUND);
			
			if (g_bCloudShake)
			{
				Handle hBf = StartMessageOne("Shake", target);
				BfWriteByte(hBf, 0);
				BfWriteFloat(hBf,6.0);
				BfWriteFloat(hBf,1.0);
				BfWriteFloat(hBf,1.0);
				EndMessage();
				//CreateTimer(1.0, StopShake, GetClientUserId(target), TIMER_FLAG_NO_MAPCHANGE);
			}
			
			if ( g_bCloudMeleeSlowEnabled )
			{
				SetInClound(target, true);
				CreateTimer(2.0, ClearMeleeBlock, target);
			}
		}
		if( client != -1 )
		{
			ApplyDamage(g_fCloudDamage, target, client);
		}
	}
	return Plugin_Continue;
}

Action HookSound_Callback(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],
	  int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,
	  char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (!g_bAnybodyInCloud) return Plugin_Continue;
	
	if (StrContains(sample, "Swish", false) == -1) return Plugin_Continue;
	
	if (!entity || entity > MAXPLAYERS) return Plugin_Continue;
	
	if (g_bMeleeDelay[entity]) return Plugin_Continue;
	g_bMeleeDelay[entity] = true;
	CreateTimer(1.0, Resetg_bMeleeDelay, entity);
	
	#if DEBUG
	PrintToChatAll("Melee detected via soundhook.");
	#endif
	
	if (g_bIsInCloud[entity])
	{
		SetEntData(entity, g_iMeleeEntInfo, 1.5, 4);
	}
	return Plugin_Continue;
}

public Action Resetg_bMeleeDelay(Handle timer, int client)
{
	g_bMeleeDelay[client] = false;
	return Plugin_Continue;
}

public Action ClearMeleeBlock(Handle timer, int target)
{
	SetInClound(target, false);
	return Plugin_Continue;
}

void SetInClound(int target, bool state)
{
	g_bIsInCloud[target] = state;
	
	g_bAnybodyInCloud = false;
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( g_bIsInCloud[i] )
		{
			g_bAnybodyInCloud = true;
			break;
		}
	}
}

/*
public Action StopShake(Handle timer, int UserId)
{
	int target = GetClientOfUserId(UserId);
	if (!target || !IsClientInGame(target)) return;
	
	Handle hBf = StartMessageOne("Shake", target);
	BfWriteByte(hBf, 0);
	BfWriteFloat(hBf, 0.0);
	BfWriteFloat(hBf, 0.0);
	BfWriteFloat(hBf, 0.0);
	EndMessage();
}
*/

stock bool IsPlayerSpawnGhost(int client)
{
	if (GetEntData(client, g_iPropInfoGhost, 1)) return true;
	return false;
}

stock bool IsPlayerIncapped(int client)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1)) return true;
	return false;
}

static void ApplyDamage(float damage, int victim, int attacker)
{
	#if DEBUG
	PrintToChatAll("Damaging %N for %f hp (attacked by %i)", victim, damage, attacker);
	#endif
	
	SDKHooks_TakeDamage(victim, attacker, attacker, damage, g_bCloudBlocksRevive ? DMG_NERVEGAS : DMG_ENERGYBEAM | DMG_RADIATION);
}

static bool IsVisibleTo(float position[3], float targetposition[3])
{
	float vAngles[3], vLookAt[3];
	
	MakeVectorFromPoints(position, targetposition, vLookAt);
	GetVectorAngles(vLookAt, vAngles);
	
	bool isVisible;
	Handle trace = TR_TraceRayFilterEx(position, vAngles, MASK_SHOT, RayType_Infinite, TR_TraceFilter);
	if( trace )
	{
		if (TR_DidHit(trace))
		{
			float vStart[3];
			TR_GetEndPosition(vStart, trace);
			
			if ((GetVectorDistance(position, vStart, false) + TRACE_TOLERANCE) >= GetVectorDistance(position, targetposition))
			{
				isVisible = true;
			}
		}
		else
		{
			isVisible = true;
		}
		delete trace;
	}
	return isVisible;
}

public bool TR_TraceFilter(int entity, int contentsMask)
{
	if (!entity || !IsValidEntity(entity))
	{
		return false;
	}
	return true;
} 