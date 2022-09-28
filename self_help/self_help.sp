#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <colors>

#define PLUGIN_VERSION "0.3"

enum SelfHelpState
{
	SHS_NONE = 0,
	SHS_START_SELF = 1,
	SHS_START_OTHER = 2,
	SHS_CONTINUE = 3,
	SHS_END = 4
};

ConVar shEnable, shUse, shIncapPickup, shDelay, shKillAttacker, shBot, shBotChance, shHardHP,
	shTempHP, shMaxCount, cvarReviveDuration, cvarMaxIncapCount, cvarAdrenalineDuration;

bool bIsL4D, bEnabled, bIncapPickup, bKillAttacker, bBot;
float fAdrenalineDuration, fDelay, fTempHP, fLastPos[MAXPLAYERS+1][3], fSelfHelpTime[MAXPLAYERS+1];
int iSurvivorClass, iUse, iBotChance, iHardHP, iMaxCount, iAttacker[MAXPLAYERS+1],
	iBotHelp[MAXPLAYERS+1], iReviveDuration, iMaxIncapCount, iSHCount[MAXPLAYERS+1];

Handle hSHTime[MAXPLAYERS+1] = null, hSHGameData = null, hSHSetTempHP = null, hSHAdrenalineRush = null,
	hSHOnRevived = null, hSHStagger = null;

char sGameSounds[6][] =
{
	"music/terror/PuddleOfYou.wav",
	"music/terror/ClingingToHellHit1.wav",
	"music/terror/ClingingToHellHit2.wav",
	"music/terror/ClingingToHellHit3.wav",
	"music/terror/ClingingToHellHit4.wav",
	"player/heartbeatloop.wav"
};

SelfHelpState shsBit[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evRetVal = GetEngineVersion();
	if (evRetVal != Engine_Left4Dead && evRetVal != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "(S★H) Plugin Supports L4D And L4D2 Only!");
		return APLRes_SilentFailure;
	}
	
	bIsL4D = (evRetVal == Engine_Left4Dead) ? true : false;
	iSurvivorClass = (evRetVal == Engine_Left4Dead2) ? 9 : 6;
	
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "Self-Help (Reloaded)",
	author = "cravenge, panxiaohai",
	description = "Lets Players Help Themselves When Troubled.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=281620"
};

public void OnPluginStart()
{
	hSHGameData = LoadGameConfigFile("self_help");
	if (hSHGameData == null)
	{
		SetFailState("(S★H) Game Data Missing!");
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hSHGameData, SDKConf_Signature, "OnStaggered");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	hSHStagger = EndPrepSDKCall();
	if (hSHStagger == null)
	{
		SetFailState("(S★H) Signature 'OnStaggered' Broken!");
	}
	
	if (!bIsL4D)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hSHGameData, SDKConf_Signature, "OnRevived");
		hSHOnRevived = EndPrepSDKCall();
		if (hSHOnRevived == null)
		{
			SetFailState("(S★H) Signature 'OnRevived' Broken!");
		}
		
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hSHGameData, SDKConf_Signature, "SetHealthBuffer");
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		hSHSetTempHP = EndPrepSDKCall();
		if (hSHSetTempHP == null)
		{
			SetFailState("(S★H) Signature 'SetHealthBuffer' Broken!");
		}
		
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hSHGameData, SDKConf_Signature, "OnAdrenalineUsed");
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		hSHAdrenalineRush = EndPrepSDKCall();
		if (hSHAdrenalineRush == null)
		{
			SetFailState("(S★H) Signature 'OnAdrenalineUsed' Broken!");
		}
		
		delete hSHGameData;
	}
	
	cvarReviveDuration = FindConVar("survivor_revive_duration");
	iReviveDuration = cvarReviveDuration.IntValue;
	cvarReviveDuration.AddChangeHook(OnSHCVarsChanged);
	
	if (bIsL4D)
	{
		delete cvarAdrenalineDuration;
	}
	else
	{
		delete shMaxCount;
		
		cvarMaxIncapCount = FindConVar("survivor_max_incapacitated_count");
		iMaxIncapCount = cvarMaxIncapCount.IntValue;
		cvarMaxIncapCount.AddChangeHook(OnSHCVarsChanged);
		
		cvarAdrenalineDuration = FindConVar("adrenaline_duration");
		fAdrenalineDuration = cvarAdrenalineDuration.FloatValue;
		cvarAdrenalineDuration.AddChangeHook(OnSHCVarsChanged);
	}
	
	CreateConVar("self_help_version", PLUGIN_VERSION, "Self-Help (Reloaded) Version", FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DONTRECORD);
	shEnable = CreateConVar("self_help_enable", "1", "Enable/Disable Plugin", FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
	shUse = CreateConVar("self_help_use", "3", "使用什么自救: 0=无, 1=医疗包和止痛药, 2=仅医疗包, 3=两者", FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 3.0);
	shIncapPickup = CreateConVar("self_help_incap_pickup", "1", "当倒地时是否可以拾取物品", FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
	shDelay = CreateConVar("self_help_delay", "1.0", "插件功能启动延迟", FCVAR_NOTIFY|FCVAR_SPONLY);
	shKillAttacker = CreateConVar("self_help_kill_attacker", "1", "是否将攻击玩家的特感杀死", FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
	shBot = CreateConVar("self_help_bot", "1", "AI是否可以自救", FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
	shBotChance = CreateConVar("self_help_bot_chance", "1", "AI自救频率: 1=有时, 2=经常, 3=很少", FCVAR_NOTIFY|FCVAR_SPONLY, true, 1.0, true, 3.0);
	shHardHP = CreateConVar("self_help_hard_hp", "50", "自救后多少实血", FCVAR_NOTIFY|FCVAR_SPONLY, true, 1.0);
	shTempHP = CreateConVar("self_help_temp_hp", "50.0", "自救后多少", FCVAR_NOTIFY|FCVAR_SPONLY, true, 1.0);
	
	if (bIsL4D)
	{
		shMaxCount = CreateConVar("self_help_max_count", "3", "Maximum Attempts of Self-Help", FCVAR_NOTIFY|FCVAR_SPONLY, true, 3.0);
		iMaxCount = shMaxCount.IntValue;
		shMaxCount.AddChangeHook(OnSHCVarsChanged);
	}
	
	iUse = shUse.IntValue;
	iBotChance = shBotChance.IntValue;
	iHardHP = shHardHP.IntValue;
	
	bEnabled = shEnable.BoolValue;
	bIncapPickup = shIncapPickup.BoolValue;
	bKillAttacker = shKillAttacker.BoolValue;
	bBot = shBot.BoolValue;
	
	fDelay = shDelay.FloatValue;
	fTempHP = shTempHP.FloatValue;
	
	shEnable.AddChangeHook(OnSHCVarsChanged);
	shUse.AddChangeHook(OnSHCVarsChanged);
	shIncapPickup.AddChangeHook(OnSHCVarsChanged);
	shDelay.AddChangeHook(OnSHCVarsChanged);
	shKillAttacker.AddChangeHook(OnSHCVarsChanged);
	shBot.AddChangeHook(OnSHCVarsChanged);
	shBotChance.AddChangeHook(OnSHCVarsChanged);
	shHardHP.AddChangeHook(OnSHCVarsChanged);
	shTempHP.AddChangeHook(OnSHCVarsChanged);
	
	AutoExecConfig(true, "self_help");
	
	HookEvent("round_start", OnRoundEvents);
	HookEvent("round_end", OnRoundEvents);
	HookEvent("finale_win", OnRoundEvents);
	HookEvent("mission_lost", OnRoundEvents);
	HookEvent("map_transition", OnRoundEvents);
	
	HookEvent("player_incapacitated", OnPlayerDown);
	HookEvent("player_ledge_grab", OnPlayerDown);
	
	HookEvent("player_bot_replace", OnReplaceEvents);
	HookEvent("bot_player_replace", OnReplaceEvents);
	
	HookEvent("revive_begin", OnReviveBegin);
	HookEvent("revive_end", OnReviveEnd);
	HookEvent("revive_success", OnReviveSuccess);
	
	HookEvent("heal_success", OnHealSuccess);
	
	HookEvent("tongue_grab", OnInfectedGrab);
	HookEvent("lunge_pounce", OnInfectedGrab);
	if (!bIsL4D)
	{
		HookEvent("jockey_ride", OnInfectedGrab);
		HookEvent("charger_pummel_start", OnInfectedGrab);
		
		HookEvent("jockey_ride_end", OnInfectedRelease);
		HookEvent("charger_pummel_end", OnInfectedRelease);
		
		HookEvent("defibrillator_used", OnDefibrillatorUsed);
	}
	HookEvent("tongue_release", OnInfectedRelease);
	HookEvent("pounce_stopped", OnInfectedRelease);
	
	AddNormalSoundHook(OnSHSoundsFix);
	
	CreateTimer(0.1, RecordLastPosition, _, TIMER_REPEAT);
}

public void OnSHCVarsChanged(ConVar cvar, const char[] sOldValue, const char[] sNewValue)
{
	if (!bIsL4D)
	{
		iMaxIncapCount = cvarMaxIncapCount.IntValue;
		
		fAdrenalineDuration = cvarAdrenalineDuration.FloatValue;
	}
	
	iReviveDuration = cvarReviveDuration.IntValue;
	
	iUse = shUse.IntValue;
	iBotChance = shBotChance.IntValue;
	iHardHP = shHardHP.IntValue;
	
	bEnabled = shEnable.BoolValue;
	bIncapPickup = shIncapPickup.BoolValue;
	bKillAttacker = shKillAttacker.BoolValue;
	bBot = shBot.BoolValue;
	
	fDelay = shDelay.FloatValue;
	fTempHP = shTempHP.FloatValue;
	
	if (bIsL4D)
	{
		iMaxCount = shMaxCount.IntValue;
	}
}

public Action OnSHSoundsFix(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (StrEqual(sample, "music/tags/PuddleOfYouHit.wav", false) || StrEqual(sample, "music/tags/ClingingToHellHit1.wav", false) || StrEqual(sample, "music/tags/ClingingToHellHit2.wav", false) || 
		StrEqual(sample, "music/tags/ClingingToHellHit3.wav", false) || StrEqual(sample, "music/tags/ClingingToHellHit4.wav", false))
	{
		numClients = 0;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || GetClientTeam(i) == 3 || IsFakeClient(i))
			{
				continue;
			}
			
			clients[numClients++] = i;
		}
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action RecordLastPosition(Handle timer)
{
	if (!IsServerProcessing())
	{
		return Plugin_Continue;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
		{
			continue;
		}
		
		if (!GetEntProp(i, Prop_Send, "m_isHangingFromLedge", 1))
		{
			if (!bBot && IsFakeClient(i))
			{
				continue;
			}
			
			float fCurrentPos[3];
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", fCurrentPos);
			
			fLastPos[i] = fCurrentPos;
		}
	}
	
	return Plugin_Continue;
}

public void OnMapStart()
{
	
	PrecacheSound("weapons/knife/knife_deploy.wav", true);
	PrecacheSound("weapons/knife/knife_hitwall1.wav", true);
}

public void OnRoundEvents(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled)
	{
		return;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			shsBit[i] = SHS_NONE;
			
			iAttacker[i] = 0;
			iBotHelp[i] = 0;
			
			if (bIsL4D)
			{
				iSHCount[i] = 0;
			}
			
			fSelfHelpTime[i] = 0.0;
			
			if (hSHTime[i] != null)
			{
				hSHTime[i] = null;
			}
		}
	}
}

public void OnPlayerDown(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled)
	{
		return;
	}
	
	int wounded = GetClientOfUserId(event.GetInt("userid"));
	if (IsSurvivor(wounded))
	{
		if (GetEntProp(wounded, Prop_Send, "m_zombieClass") != iSurvivorClass)
		{
			return;
		}
		
		CreateTimer(fDelay, FireUpMechanism, GetClientUserId(wounded));
		
		if (StrEqual(name, "player_incapacitated"))
		{
			PrintHintText(wounded, "(按住换弹键以复活其他倒地的生还者");
			
			if (bIsL4D)
			{
				if (iSHCount[wounded] + 1 > iMaxCount)
				{
					iSHCount[wounded] = iMaxCount - 1;
				}
				
				CPrintToChat(wounded, "你倒地了! [{green}%d{default}/{green}%i{default}]", iSHCount[wounded] + 1, iMaxCount);
				if (iSHCount[wounded] == iMaxCount)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (!IsClientInGame(i) || IsFakeClient(i) || i == wounded)
						{
							continue;
						}
						
						PrintHintText(i, "%N将在倒地/自救后处于黑白状态！", wounded);
					}
				}
			}
			else
			{
				int iReviveCount = GetEntProp(wounded, Prop_Send, "m_currentReviveCount");
				if (iReviveCount + 1 > iMaxIncapCount)
				{
					iReviveCount = iMaxIncapCount - 1;
				}
				
				CPrintToChat(wounded, "你倒地了! |{green}%d{default}/{green}%i{default}|", iReviveCount + 1, iMaxIncapCount);
				if (iReviveCount == iMaxIncapCount)
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (!IsClientInGame(i) || IsFakeClient(i) || i == wounded)
						{
							continue;
						}
						
						PrintHintText(i, "%N将在倒地/自救后处于黑白状态！", wounded);
					}
				}
			}
		}
	}
}

public Action FireUpMechanism(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsSurvivor(client) || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}
	
	shsBit[client] = SHS_NONE;
	if (hSHTime[client] == null)
	{
		if (!GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))
		{
			if (iAttacker[client] == 0 || (iAttacker[client] != 0 && (!IsClientInGame(iAttacker[client]) || !IsPlayerAlive(iAttacker[client]))))
			{
				return Plugin_Stop;
			}
		}
		
		if (GetEntProp(client, Prop_Send, "m_reviveOwner") > 0 && GetEntProp(client, Prop_Send, "m_reviveOwner") != client)
		{
			return Plugin_Stop;
		}
		
		if (bBot && IsFakeClient(client) && iBotHelp[client] == 0 && GetRandomInt(1, 3) == iBotChance)
		{
			iBotHelp[client] = 1;
		}
		
		fSelfHelpTime[client] = 0.0;
		
		if (IsSelfHelpAble(client) && !IsFakeClient(client))
		{
			CPrintToChat(client, "按住{green}下蹲键{default}自救!");
		}
		hSHTime[client] = CreateTimer(0.1, AnalyzePlayerState, GetClientUserId(client), TIMER_REPEAT);
	}
	
	return Plugin_Stop;
}

public Action AnalyzePlayerState(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsSurvivor(client) || !IsPlayerAlive(client) || (!bBot && IsFakeClient(client)) || shsBit[client] == SHS_END)
	{
		shsBit[client] = SHS_NONE;
		
		if (hSHTime[client] != null)
		{
			if (!bIsL4D)
			{
				KillTimer(hSHTime[client]);
			}
			hSHTime[client] = null;
		}
		return Plugin_Stop;
	}
	
	if (!GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))
	{
		if (iAttacker[client] == 0 || (iAttacker[client] != 0 && (!IsClientInGame(iAttacker[client]) || !IsPlayerAlive(iAttacker[client]))))
		{
			iAttacker[client] = 0;
			
			if (hSHTime[client] != null)
			{
				if (!bIsL4D)
				{
					KillTimer(hSHTime[client]);
				}
				hSHTime[client] = null;
			}
			return Plugin_Stop;
		}
	}
	
	if (hSHTime[client] == null)
	{
		return Plugin_Stop;
	}
	
	int iButtons = GetClientButtons(client);
	char sSHMessage[128];
	
	if (IsSelfHelpAble(client))
	{
		if (iButtons & IN_DUCK)
		{
			if (shsBit[client] == SHS_NONE || shsBit[client] == SHS_CONTINUE)
			{
				shsBit[client] = SHS_START_SELF;
				if (!IsFakeClient(client))
				{
					strcopy(sSHMessage, sizeof(sSHMessage), "REVIVING YOURSELF");
					DisplaySHProgressBar(client, client, iReviveDuration, sSHMessage, true);
					
					if (!bIsL4D)
					{
						PrintHintText(client, "请你自救!");
					}
				}
				
				DataPack dpSHRevive = new DataPack();
				dpSHRevive.WriteCell(GetClientUserId(client));
				CreateTimer(0.1, SHReviveCompletion, dpSHRevive, TIMER_REPEAT|TIMER_DATA_HNDL_CLOSE);
			}
		}
		else
		{
			if (shsBit[client] == SHS_START_SELF)
			{
				shsBit[client] = SHS_NONE;
			}
		}
	}
	
	if (iButtons & IN_RELOAD)
	{
		float fPos[3], fOtherPos[3];
		
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
		
		int iTarget = 0;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i) || i == client)
			{
				continue;
			}
			
			if (GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) && iAttacker[i] == 0)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", fOtherPos);
				
				if (GetVectorDistance(fOtherPos, fPos) > 100.0)
				{
					continue;
				}
				
				iTarget = i;
				break;
			}
		}
		if (IsSurvivor(iTarget) && IsPlayerAlive(iTarget) && GetEntProp(iTarget, Prop_Send, "m_isIncapacitated", 1) && iAttacker[iTarget] == 0)
		{
			if (shsBit[client] == SHS_NONE || shsBit[client] == SHS_CONTINUE)
			{
				shsBit[client] = SHS_START_OTHER;
				if (!IsFakeClient(client))
				{
					strcopy(sSHMessage, sizeof(sSHMessage), "HELPING TEAMMATE");
					DisplaySHProgressBar(client, iTarget, iReviveDuration, sSHMessage, true);
					
					if (!bIsL4D)
					{
						PrintHintText(client, "你正在救助%N!", iTarget);
					}
				}
				
				if (!IsFakeClient(iTarget))
				{
					Format(sSHMessage, sizeof(sSHMessage), "BEING HELPED");
					DisplaySHProgressBar(iTarget, client, iReviveDuration, sSHMessage);
					
					if (!bIsL4D)
					{
						PrintHintText(iTarget, "%N救了你!", client);
					}
				}
				
				DataPack dpSHReviveOther = new DataPack();
				dpSHReviveOther.WriteCell(GetClientUserId(client));
				dpSHReviveOther.WriteCell(GetClientUserId(iTarget));
				CreateTimer(0.1, SHReviveOtherCompletion, dpSHReviveOther, TIMER_REPEAT|TIMER_DATA_HNDL_CLOSE);
			}
		}
		else
		{
			iTarget = 0;
			
			if (shsBit[client] == SHS_START_OTHER)
			{
				shsBit[client] = SHS_NONE;
			}
		}
	}
	else
	{
		if (shsBit[client] == SHS_START_OTHER || shsBit[client] == SHS_CONTINUE)
		{
			shsBit[client] = SHS_NONE;
		}
	}
	
	if ((iButtons & IN_DUCK) && bIncapPickup)
	{
		int iItemEnt = -1;
		float fPos[3], fItemPos[3];
		
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
		
		if (!CheckPlayerSupply(client, 3))
		{
			while ((iItemEnt = FindEntityByClassname(iItemEnt, "weapon_first_aid_kit")) != -1)
			{
				if (!IsValidEntity(iItemEnt) || !IsValidEdict(iItemEnt))
				{
					continue;
				}
				
				GetEntPropVector(iItemEnt, Prop_Send, "m_vecOrigin", fItemPos);
				
				if (GetVectorDistance(fPos, fItemPos) <= 150.0)
				{
					ExecuteCommand(client, "give", "first_aid_kit");
					PrintHintText(client, "获取急救包!");
					
					AcceptEntityInput(iItemEnt, "Kill");
					RemoveEdict(iItemEnt);
					
					break;
				}
			}
		}
		else if (!CheckPlayerSupply(client, 4))
		{
			while ((iItemEnt = FindEntityByClassname(iItemEnt, "weapon_pain_pills")) != -1)
			{
				if (!IsValidEntity(iItemEnt) || !IsValidEdict(iItemEnt))
				{
					continue;
				}
				
				GetEntPropVector(iItemEnt, Prop_Send, "m_vecOrigin", fItemPos);
				
				if (GetVectorDistance(fPos, fItemPos) <= 150.0)
				{
					ExecuteCommand(client, "give", "pain_pills");
					PrintHintText(client, "获取止痛药!");
					
					AcceptEntityInput(iItemEnt, "Kill");
					RemoveEdict(iItemEnt);
					
					break;
				}
			}
			
			if (!bIsL4D)
			{
				while ((iItemEnt = FindEntityByClassname(iItemEnt, "weapon_adrenaline")) != -1)
				{
					if (!IsValidEntity(iItemEnt) || !IsValidEdict(iItemEnt))
					{
						continue;
					}
					
					GetEntPropVector(iItemEnt, Prop_Send, "m_vecOrigin", fItemPos);
					
					if (GetVectorDistance(fPos, fItemPos) <= 150.0)
					{
						ExecuteCommand(client, "give", "adrenaline");
						PrintHintText(client, "获取肾上腺素!");
						
						AcceptEntityInput(iItemEnt, "Kill");
						RemoveEdict(iItemEnt);
						
						break;
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action SHReviveCompletion(Handle timer, Handle dpSHRevive)
{
	ResetPack(dpSHRevive);
	
	int client = GetClientOfUserId(ReadPackCell(dpSHRevive));
	if (!IsSurvivor(client) || !IsPlayerAlive(client) || !(GetClientButtons(client) & IN_DUCK))
	{
		RemoveSHProgressBar(client, true);
		
		fSelfHelpTime[client] = 0.0;
		return Plugin_Stop;
	}
	
	if (hSHTime[client] == null || shsBit[client] == SHS_NONE || (GetEntProp(client, Prop_Send, "m_reviveOwner") > 0 && GetEntProp(client, Prop_Send, "m_reviveOwner") != client))
	{
		RemoveSHProgressBar(client, true, true);
		
		fSelfHelpTime[client] = 0.0;
		return Plugin_Stop;
	}
	
	if (fSelfHelpTime[client] >= float(iReviveDuration) + 0.1)
	{
		RemoveSHProgressBar(client, true);
		
		bool bAidCheck;
		SHStatsFixer(client, (GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1)) ? true : false, _, bAidCheck);
		
		if (!GetEntProp(client, Prop_Send, "m_isIncapacitated", 1))
		{
			SetEntProp(client, Prop_Send, "m_isIncapacitated", 1, 1);
			
			Event ePlayerIncapacitated = CreateEvent("player_incapacitated");
			ePlayerIncapacitated.SetInt("userid", GetClientUserId(client));
			ePlayerIncapacitated.SetInt("attacker", GetClientUserId(iAttacker[client]));
			ePlayerIncapacitated.Fire();
			
			DataPack dpSHReviveDelay = new DataPack();
			dpSHReviveDelay.WriteCell(GetClientUserId(client));
			dpSHReviveDelay.WriteCell(bAidCheck);
			CreateTimer(0.1, SelfReviveDelay, dpSHReviveDelay, TIMER_DATA_HNDL_CLOSE);
		}
		else
		{
			Event eReviveSuccess = CreateEvent("revive_success");
			eReviveSuccess.SetInt("userid", GetClientUserId(client));
			eReviveSuccess.SetInt("subject", GetClientUserId(client));
			eReviveSuccess.SetBool("ledge_hang", (!GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1)) ? false : true);
			if (bIsL4D)
			{
				eReviveSuccess.SetBool("lastlife", (iSHCount[client] + 1 >= iMaxCount) ? true : false);
			}
			else
			{
				eReviveSuccess.SetBool("lastlife", (GetEntProp(client, Prop_Send, "m_currentReviveCount") == iMaxIncapCount) ? true : false);
			}
			eReviveSuccess.Fire();
			
			DoSelfHelp(client, bAidCheck);
			
			for (int i = 0; i < 5; i++)
			{
				UnloopAnnoyingMusic(client, sGameSounds[i]);
			}
		}
		
		RemoveHindrance(client);
		
		fSelfHelpTime[client] = 0.0;
		return Plugin_Stop;
	}
	
	fSelfHelpTime[client] += 0.1;
	return Plugin_Continue;
}

public Action SelfReviveDelay(Handle timer, Handle dpSHReviveDelay)
{
	ResetPack(dpSHReviveDelay);
	
	int client = GetClientOfUserId(ReadPackCell(dpSHReviveDelay));
	if (!IsSurvivor(client) || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}
	
	if (!bIsL4D)
	{
		SDKCall(hSHOnRevived, client);
	}
	else
	{
		iSHCount[client] -= 1;
		
		Event eReviveSuccess = CreateEvent("revive_success");
		eReviveSuccess.SetInt("userid", GetClientUserId(client));
		eReviveSuccess.SetInt("subject", GetClientUserId(client));
		eReviveSuccess.SetBool("ledge_hang", (!GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1)) ? false : true);
		eReviveSuccess.SetBool("lastlife", (iSHCount[client] + 1 >= iMaxCount) ? true : false);
		eReviveSuccess.Fire();
		
		bool bLastAidCheck = view_as<bool>(ReadPackCell(dpSHReviveDelay));
		DoSelfHelp(client, bLastAidCheck);
	}
	return Plugin_Stop;
}

public Action SHReviveOtherCompletion(Handle timer, Handle dpSHReviveOther)
{
	ResetPack(dpSHReviveOther);
	
	int reviver = GetClientOfUserId(ReadPackCell(dpSHReviveOther));
	if (!IsSurvivor(reviver) || !IsPlayerAlive(reviver) || !(GetClientButtons(reviver) & IN_RELOAD))
	{
		RemoveSHProgressBar(reviver, true);
		
		fSelfHelpTime[reviver] = 0.0;
		return Plugin_Stop;
	}
	
	int revived = GetClientOfUserId(ReadPackCell(dpSHReviveOther));
	if (!IsSurvivor(revived) || !IsPlayerAlive(revived) || !GetEntProp(revived, Prop_Send, "m_isIncapacitated", 1) || iAttacker[revived] != 0)
	{
		RemoveSHProgressBar(reviver, true);
		RemoveSHProgressBar(revived);
		
		fSelfHelpTime[reviver] = 0.0;
		return Plugin_Stop;
	}
	
	if (hSHTime[reviver] == null || shsBit[reviver] == SHS_NONE || (GetEntProp(revived, Prop_Send, "m_reviveOwner") > 0 && GetEntProp(revived, Prop_Send, "m_reviveOwner") != reviver))
	{
		RemoveSHProgressBar(reviver, true);
		RemoveSHProgressBar(revived, _, true);
		
		fSelfHelpTime[reviver] = 0.0;
		return Plugin_Stop;
	}
	
	if (fSelfHelpTime[reviver] >= float(iReviveDuration) + 0.1)
	{
		RemoveSHProgressBar(reviver, true);
		RemoveSHProgressBar(revived);
		
		bool bTempCheck;
		SHStatsFixer(revived, (!GetEntProp(revived, Prop_Send, "m_isHangingFromLedge", 1)) ? false : true, false, bTempCheck);
		
		Event eReviveSuccess = CreateEvent("revive_success");
		eReviveSuccess.SetInt("userid", GetClientUserId(reviver));
		eReviveSuccess.SetInt("subject", GetClientUserId(revived));
		eReviveSuccess.SetBool("ledge_hang", (GetEntProp(revived, Prop_Send, "m_isHangingFromLedge", 1)) ? true : false);
		if (bIsL4D)
		{
			eReviveSuccess.SetBool("lastlife", (iSHCount[revived] + 1 >= iMaxCount) ? true : false);
		}
		else
		{
			eReviveSuccess.SetBool("lastlife", (GetEntProp(revived, Prop_Send, "m_currentReviveCount") == iMaxIncapCount) ? true : false);
		}
		eReviveSuccess.Fire();
		
		DoSelfHelp(revived);
		
		for (int i = 0; i < 5; i++)
		{
			UnloopAnnoyingMusic(revived, sGameSounds[i]);
		}
		
		fSelfHelpTime[reviver] = 0.0;
		return Plugin_Stop;
	}
	
	fSelfHelpTime[reviver] += 0.1;
	return Plugin_Continue;
}

public void OnReplaceEvents(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled)
	{
		return;
	}
	
	int player = GetClientOfUserId(event.GetInt("player"));
	if (player > 0 && IsClientInGame(player) && !IsFakeClient(player))
	{
		int	bot = GetClientOfUserId(event.GetInt("bot"));
		
		if (StrEqual(name, "player_bot_replace"))
		{
			if (bIsL4D)
			{
				iSHCount[bot] = iSHCount[player];
				iSHCount[player] = 0;
			}
			
			iAttacker[bot] = iAttacker[player];
			iAttacker[player] = 0;
			
			for (int i = 0; i < 6; i++)
			{
				UnloopAnnoyingMusic(player, sGameSounds[i]);
			}
		}
		else
		{
			if (GetClientTeam(player) != 2)
			{
				return;
			}
			
			if (bIsL4D)
			{
				iSHCount[player] = iSHCount[bot];
				iSHCount[bot] = 0;
			}
			
			iAttacker[player] = iAttacker[bot];
			iAttacker[bot] = 0;
			
			CreateTimer(fDelay, FireUpMechanism, GetClientUserId(player));
		}
	}
}

public void OnReviveBegin(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled)
	{
		return;
	}
	
	int revived = GetClientOfUserId(event.GetInt("subject"));
	if (IsSurvivor(revived))
	{
		if (hSHTime[revived] == null)
		{
			return;
		}
		
		hSHTime[revived] = null;
	}
}

public void OnReviveEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled)
	{
		return;
	}
	
	int revived = GetClientOfUserId(event.GetInt("subject"));
	if (IsSurvivor(revived))
	{
		if (!IsPlayerAlive(revived) || !GetEntProp(revived, Prop_Send, "m_isIncapacitated", 1))
		{
			return;
		}
		
		CreateTimer(fDelay, FireUpMechanism, GetClientUserId(revived));
	}
}

public void OnReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled)
	{
		return;
	}
	
	int reviver = GetClientOfUserId(event.GetInt("userid")),
		revived = GetClientOfUserId(event.GetInt("subject"));
	
	if (IsSurvivor(reviver) && IsSurvivor(revived))
	{
		if (bBot && IsFakeClient(revived) && iBotHelp[revived] == 1)
		{
			iBotHelp[revived] = 0;
		}
		
		if (event.GetBool("ledge_hang"))
		{
			if (reviver != revived)
			{
				if (!IsFakeClient(reviver))
				{
					CPrintToChat(reviver, "{blue}(S★H) {default}你救了{olive}%N{default}!", revived);
				}
				
				if (!IsFakeClient(revived))
				{
					CPrintToChat(revived, "{olive}%N{default}救了你!", reviver);
				}
			}
			else
			{
				if (!IsFakeClient(revived))
				{
					CPrintToChat(revived, "你救了你自己!");
				}
			}
		}
		else
		{
			if (!bIsL4D)
			{
				int iReviveCount = GetEntProp(revived, Prop_Send, "m_currentReviveCount");
				if (iReviveCount > iMaxIncapCount)
				{
					iReviveCount = iMaxIncapCount;
				}
				
				if (reviver == revived)
				{
					if (!IsFakeClient(revived))
					{
						CPrintToChat(revived, "你救了你自己! |{green}%d{default}/{green}%i{default}|", iReviveCount, iMaxIncapCount);
					}
				}
				else
				{
					if (!IsFakeClient(reviver))
					{
						if (GetEntProp(reviver, Prop_Send, "m_isIncapacitated", 1))
						{
							CPrintToChatAll("{%N在黑白状态下救了{olive}%N!", reviver, revived);
						}
						
						CPrintToChat(reviver, "你救了{olive}%N{default}! |{green}%d{default}/{green}%i{default}|", revived, iReviveCount, iMaxIncapCount);
					}
					
					if (!IsFakeClient(revived))
					{
						CPrintToChat(revived, "{olive}%N{default}救了你! |{green}%d{default}/{green}%i{default}|", reviver, iReviveCount, iMaxIncapCount);
					}
				}
			}
			else
			{
				if (iSHCount[revived] >= iMaxCount - 1)
				{
					iSHCount[revived] = iMaxCount;
					
					SetEntProp(revived, Prop_Send, "m_currentReviveCount", 2);
					SetEntProp(revived, Prop_Send, "m_isGoingToDie", 1, 1);
				}
				else
				{
					iSHCount[revived] += 1;
					if (iSHCount[revived] != 0)
					{
						SetEntProp(revived, Prop_Send, "m_currentReviveCount", 1);
						SetEntProp(revived, Prop_Send, "m_isGoingToDie", 0, 1);
					}
				}
				
				if (reviver == revived)
				{
					if (!IsFakeClient(revived))
					{
						CPrintToChat(revived, "你救了你自己! |{green}%d{default}/{green}%i{default}|", iSHCount[revived], iMaxCount);
					}
				}
				else
				{
					if (!IsFakeClient(reviver))
					{
						if (GetEntProp(reviver, Prop_Send, "m_isIncapacitated", 1))
						{
							CPrintToChatAll("%N在黑白状态下救了{olive}%N", reviver, revived);
						}
						
						CPrintToChat(reviver, "你救了{olive}%N{default}! |{green}%d{default}/{green}%i{default}|", revived, iSHCount[revived], iMaxCount);
					}
					
					if (!IsFakeClient(revived))
					{
						CPrintToChat(revived, "%N{default}救了你! |{green}%d{default}/{green}%i{default}|", reviver, iSHCount[revived], iMaxCount);
					}
				}
			}
		}
		
		if (hSHTime[revived] == null)
		{
			return;
		}
		
		hSHTime[revived] = null;
	}
}

public void OnHealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled)
	{
		return;
	}
	
	int healer = GetClientOfUserId(event.GetInt("userid")),
		healed = GetClientOfUserId(event.GetInt("subject"));
	
	if (IsSurvivor(healer))
	{
		if (!IsSurvivor(healed))
		{
			return;
		}
		
		UnloopAnnoyingMusic(healed, sGameSounds[5]);
		PrintHintTextToAll("%N被%N完全治愈!", healed, healer);
		
		if (bIsL4D && iSHCount[healed] != 0)
		{
			iSHCount[healed] = 0;
		}
	}
}

public void OnInfectedGrab(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled)
	{
		return;
	}
	
	int grabber = GetClientOfUserId(event.GetInt("userid")),
		grabbed = GetClientOfUserId(event.GetInt("victim"));
	
	if (grabber && IsSurvivor(grabbed))
	{
		iAttacker[grabbed] = grabber;
		CreateTimer(fDelay, FireUpMechanism, GetClientUserId(grabbed));
	}
}

public void OnInfectedRelease(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled)
	{
		return;
	}
	
	int released = GetClientOfUserId(event.GetInt("victim"));
	if (IsSurvivor(released))
	{
		if (bBot && IsFakeClient(released) && iBotHelp[released] == 1)
		{
			iBotHelp[released] = 0;
		}
		
		if (StrEqual(name, "pounce_stopped"))
		{
			iAttacker[released] = 0;
		}
		else
		{
			int releaser = GetClientOfUserId(event.GetInt("userid"));
			if (!releaser || iAttacker[released] != releaser)
			{
				return;
			}
			
			iAttacker[released] = 0;
		}
	}
}

public void OnDefibrillatorUsed(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled)
	{
		return;
	}
	
	int defibber = GetClientOfUserId(event.GetInt("userid")),
		defibbed = GetClientOfUserId(event.GetInt("subject"));
	
	if (IsSurvivor(defibber))
	{
		if (!IsSurvivor(defibbed))
		{
			return;
		}
		
		DataPack dpDefibAnnounce = new DataPack();
		dpDefibAnnounce.WriteCell(GetClientUserId(defibber));
		dpDefibAnnounce.WriteCell(GetClientUserId(defibbed));
		CreateTimer(0.1, DelaySHNotify, dpDefibAnnounce, TIMER_DATA_HNDL_CLOSE);
	}
}

public Action DelaySHNotify(Handle timer, Handle dpDefibAnnounce)
{
	ResetPack(dpDefibAnnounce);
	
	int defibber = GetClientOfUserId(ReadPackCell(dpDefibAnnounce)),
		defibbed = GetClientOfUserId(ReadPackCell(dpDefibAnnounce));
	
	if (!IsSurvivor(defibber) || !IsSurvivor(defibbed))
	{
		return Plugin_Stop;
	}
	
	int iReviveCount = GetEntProp(defibbed, Prop_Send, "m_currentReviveCount");
	
	if (defibber == defibbed)
	{
		if (!IsFakeClient(defibbed))
		{
			CPrintToChat(defibbed, "{blue}}你自杀了! |{green}%d{default}/{green}%i{default}|", iReviveCount, iMaxIncapCount);
		}
	}
	else
	{
		if (!IsFakeClient(defibber))
		{
			CPrintToChat(defibber, "你杀死了{olive}%N{default}! |{green}%d{default}/{green}%i{default}|", defibbed, iReviveCount, iMaxIncapCount);
		}
		
		if (!IsFakeClient(defibbed))
		{
			CPrintToChat(defibbed, "%N{default}杀死了你! |{green}%d{default}/{green}%i{default}|", defibber, iReviveCount, iMaxIncapCount);
		}
	}
	
	return Plugin_Stop;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!bEnabled || !bBot)
	{
		return Plugin_Continue;
	}
	
	if (IsSurvivor(client))
	{
		if (!IsPlayerAlive(client) || !IsFakeClient(client) || iBotHelp[client] == 0)
		{
			return Plugin_Continue;
		}
		
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1))
		{
			int iTarget = 0;
			float fPlayerPos[2][3];
			
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPlayerPos[0]);
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i) || i == client || iAttacker[i] != 0)
				{
					continue;
				}
				
				if (GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) && GetEntProp(i, Prop_Send, "m_reviveOwner") < 1)
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", fPlayerPos[1]);
					
					if (GetVectorDistance(fPlayerPos[0], fPlayerPos[1]) > 100.0)
					{
						continue;
					}
					
					iTarget = i;
					break;
				}
			}
			if (IsSurvivor(iTarget) && IsPlayerAlive(iTarget) && GetEntProp(iTarget, Prop_Send, "m_isIncapacitated", 1) && GetEntProp(iTarget, Prop_Send, "m_reviveOwner") < 1)
			{
				buttons |= IN_RELOAD;
			}
			else
			{
				if (buttons & IN_RELOAD)
				{
					buttons ^= IN_RELOAD;
				}
				
				if (IsSelfHelpAble(client))
				{
					buttons |= IN_DUCK;
				}
			}
		}
		else if (iAttacker[client] != 0)
		{
			if (!IsSelfHelpAble(client))
			{
				return Plugin_Continue;
			}
			
			buttons |= IN_DUCK;
		}
	}
	
	return Plugin_Continue;
}

bool IsSelfHelpAble(int client)
{
	bool bHasPA = CheckPlayerSupply(client, 4), bHasMedkit = CheckPlayerSupply(client, 3);
	
	if ((iUse == 1 || iUse == 3) && bHasPA)
	{
		return true;
	}
	else if ((iUse == 2 || iUse == 3) && bHasMedkit)
	{
		return true;
	}
	
	return false;
}

bool CheckPlayerSupply(int client, int iSlot, int &iItem = 0, char sItemName[64] = "")
{
	if (!IsSurvivor(client) || !IsPlayerAlive(client))
	{
		return false;
	}
	
	int iSupply = GetPlayerWeaponSlot(client, iSlot);
	if (IsValidEnt(iSupply))
	{
		char sSupplyClass[64];
		GetEdictClassname(iSupply, sSupplyClass, sizeof(sSupplyClass));
		
		if (iSlot == 3 && StrEqual(sSupplyClass, "weapon_first_aid_kit", false))
		{
			iItem = iSupply;
			strcopy(sItemName, sizeof(sItemName), sSupplyClass);
			
			return true;
		}
		else if (iSlot == 4 && (StrEqual(sSupplyClass, "weapon_pain_pills", false) || (!bIsL4D && StrEqual(sSupplyClass, "weapon_adrenaline", false))))
		{
			iItem = iSupply;
			strcopy(sItemName, sizeof(sItemName), sSupplyClass);
			
			return true;
		}
	}
	
	return false;
}

void DisplaySHProgressBar(int client, int other = 0, int iDuration, char[] sMsg, bool bReverse = false)
{
	if (bReverse)
	{
		SetEntProp(client, Prop_Send, "m_reviveTarget", other);
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_reviveOwner", other);
	}
	
	SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
	if (bIsL4D)
	{
		SetEntProp(client, Prop_Send, "m_iProgressBarDuration", iDuration);
		
		SetEntPropString(client, Prop_Send, "m_progressBarText", sMsg);
	}
	else
	{
		SetEntPropFloat(client, Prop_Send, "m_flProgressBarDuration", float(iDuration));
	}
}

void RemoveSHProgressBar(int client, bool bReverse = false, bool bExclude = false)
{
	if (!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}
	
	if (bReverse)
	{
		SetEntProp(client, Prop_Send, "m_reviveTarget", -1);
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_reviveOwner", -1);
	}
	
	if (!bExclude)
	{
		SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
		if (!bIsL4D)
		{
			SetEntPropFloat(client, Prop_Send, "m_flProgressBarDuration", 0.0);
		}
		else
		{
			SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
			
			SetEntPropString(client, Prop_Send, "m_progressBarText", "");
		}
	}
}

void SHStatsFixer(int client, bool bDoNotTamper, bool bUseItem = true, bool &bMedkitUsed)
{
	if (shsBit[client] == SHS_START_SELF)
	{
		shsBit[client] = SHS_END;
	}
	else if (shsBit[client] == SHS_START_OTHER)
	{
		shsBit[client] = SHS_CONTINUE;
	}
	
	if (bUseItem)
	{
		int iUsedItem;
		bool bEmergencyUsed, bFirstAidUsed, bSmartHeal;
		char sUsedItemName[64];
		
		if (iUse == 3)
		{
			if (!bIsL4D)
			{
				if (GetEntProp(client, Prop_Send, "m_currentReviveCount") < iMaxIncapCount)
				{
					if (CheckPlayerSupply(client, 4, iUsedItem, sUsedItemName))
					{
						bEmergencyUsed = true;
						bFirstAidUsed = false;
						bSmartHeal = false;
					}
					else if (CheckPlayerSupply(client, 3, iUsedItem))
					{
						bFirstAidUsed = true;
						bEmergencyUsed = false;
						bSmartHeal = true;
					}
				}
				else
				{
					if (CheckPlayerSupply(client, 3, iUsedItem))
					{
						bFirstAidUsed = true;
						bEmergencyUsed = false;
					}
					else if (CheckPlayerSupply(client, 4, iUsedItem, sUsedItemName))
					{
						bEmergencyUsed = true;
						bFirstAidUsed = false;
					}
				}
			}
			else
			{
				if (iSHCount[client] >= iMaxCount)
				{
					if (CheckPlayerSupply(client, 3, iUsedItem))
					{
						bFirstAidUsed = true;
						bEmergencyUsed = false;
						bSmartHeal = true;
					}
					else if (CheckPlayerSupply(client, 4, iUsedItem, sUsedItemName))
					{
						bEmergencyUsed = true;
						bFirstAidUsed = false;
						bSmartHeal = false;
					}
				}
				else
				{
					if (CheckPlayerSupply(client, 4, iUsedItem, sUsedItemName))
					{
						bEmergencyUsed = true;
						bFirstAidUsed = false;
						bSmartHeal = false;
					}
					else if (CheckPlayerSupply(client, 3, iUsedItem))
					{
						bFirstAidUsed = true;
						bEmergencyUsed = false;
						bSmartHeal = true;
					}
				}
			}
		}
		else
		{
			if (iUse == 1)
			{
				CheckPlayerSupply(client, 4, iUsedItem, sUsedItemName);
				
				bEmergencyUsed = true;
				bFirstAidUsed = false;
			}
			else if (iUse == 2)
			{
				CheckPlayerSupply(client, 3, iUsedItem);
				
				bFirstAidUsed = true;
				bEmergencyUsed = false;
			}
			
			bSmartHeal = false;
		}
		
		if ((bEmergencyUsed || bFirstAidUsed) && RemovePlayerItem(client, iUsedItem))
		{
			AcceptEntityInput(iUsedItem, "Kill");
			RemoveEdict(iUsedItem);
			
			if (bFirstAidUsed)
			{
				CPrintToChatAll("{olive}%N{default}用{green}急救包{default}自救了!", client);
				
				if (bSmartHeal)
				{	
					Event eHealSuccess = CreateEvent("heal_success");
					eHealSuccess.SetInt("userid", GetClientUserId(client));
					eHealSuccess.SetInt("subject", GetClientUserId(client));
					eHealSuccess.Fire();
					
					if (bIsL4D)
					{
						SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
						
						if (GetEntProp(client, Prop_Send, "m_isGoingToDie", 1))
						{
							SetEntProp(client, Prop_Send, "m_isGoingToDie", 0, 1);
						}
					}
					else
					{
						SetEntProp(client, Prop_Send, "m_currentReviveCount", -1);
					}
				}
			}
			else if (bEmergencyUsed)
			{
				if (!bIsL4D && StrEqual(sUsedItemName, "weapon_adrenaline", false))
				{
					if (!GetEntProp(client, Prop_Send, "m_bAdrenalineActive", 1))
					{
						SetEntProp(client, Prop_Send, "m_bAdrenalineActive", 1, 1);
					}
					
					Event eAdrenalineUsed = CreateEvent("adrenaline_used", true);
					eAdrenalineUsed.SetInt("userid", GetClientUserId(client));
					eAdrenalineUsed.Fire();
					
					SDKCall(hSHAdrenalineRush, client, fAdrenalineDuration);
					CPrintToChatAll("{olive}%N{default}用{green}肾上腺素{default}自救了!", client);
				}
				else
				{
					Event ePillsUsed = CreateEvent("pills_used", true);
					ePillsUsed.SetInt("userid", GetClientUserId(client));
					ePillsUsed.SetInt("subject", GetClientUserId(client));
					ePillsUsed.Fire();
					
					CPrintToChatAll("{olive}%N{default}用{green}止痛药{default}自救了!", client);
				}
			}
		}
		
		bMedkitUsed = bFirstAidUsed;
	}
	
	if (!bDoNotTamper && !bIsL4D)
	{
		int iReviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount");
		if (iReviveCount >= iMaxIncapCount - 1)
		{
			SetEntProp(client, Prop_Send, "m_currentReviveCount", iMaxIncapCount);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 1, 1);
			SetEntProp(client, Prop_Send, "m_isGoingToDie", 1, 1);
		}
		else
		{
			SetEntProp(client, Prop_Send, "m_currentReviveCount", iReviveCount + 1);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0, 1);
			SetEntProp(client, Prop_Send, "m_isGoingToDie", 0, 1);
		}
	}
}

void DoSelfHelp(int client, bool bWasMedkitUsed = false)
{
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1))
	{
		SetEntProp(client, Prop_Send, "m_isIncapacitated", 0, 1);
		if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))
		{
			SetEntProp(client, Prop_Send, "m_isHangingFromLedge", 0, 1);
			SetEntProp(client, Prop_Send, "m_isFallingFromLedge", 0, 1);
		}
	}
	
	TeleportEntity(client, fLastPos[client], NULL_VECTOR, NULL_VECTOR);
	if (bWasMedkitUsed)
	{
		SetEntProp(client, Prop_Send, "m_iHealth", GetEntProp(client, Prop_Send, "m_iMaxHealth"));
		if (bIsL4D)
		{
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
			SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		}
		else
		{
			SDKCall(hSHSetTempHP, client, 0.0);
		}
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_iHealth", iHardHP);
		if (!bIsL4D)
		{
			SDKCall(hSHSetTempHP, client, fTempHP);
		}
		else
		{
			SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fTempHP);
			SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		}
	}
}

void UnloopAnnoyingMusic(int client, const char[] sGivenSound)
{
	StopSound(client, SNDCHAN_REPLACE, sGivenSound);
	StopSound(client, SNDCHAN_AUTO, sGivenSound);
	StopSound(client, SNDCHAN_WEAPON, sGivenSound);
	StopSound(client, SNDCHAN_VOICE, sGivenSound);
	StopSound(client, SNDCHAN_ITEM, sGivenSound);
	StopSound(client, SNDCHAN_BODY, sGivenSound);
	StopSound(client, SNDCHAN_STREAM, sGivenSound);
	StopSound(client, SNDCHAN_STATIC, sGivenSound);
	StopSound(client, SNDCHAN_VOICE_BASE, sGivenSound);
	StopSound(client, SNDCHAN_USER_BASE, sGivenSound);
}

void RemoveHindrance(int client)
{
	int dominator = iAttacker[client];
	iAttacker[client] = 0;
	
	if (dominator != 0 && IsClientInGame(dominator) && GetClientTeam(dominator) == 3 && IsPlayerAlive(dominator))
	{
		switch (GetEntProp(dominator, Prop_Send, "m_zombieClass"))
		{
			case 1:
			{
				Event eTonguePullStopped = CreateEvent("tongue_pull_stopped", true);
				eTonguePullStopped.SetInt("userid", GetClientUserId(client));
				eTonguePullStopped.SetInt("victim", GetClientUserId(client));
				eTonguePullStopped.Fire();
			}
			case 3:
			{
				Event ePounceStopped = CreateEvent("pounce_stopped");
				ePounceStopped.SetInt("userid", GetClientUserId(client));
				ePounceStopped.SetInt("victim", GetClientUserId(client));
				ePounceStopped.Fire();
			}
			case 5:
			{
				if (!bIsL4D)
				{
					Event eJockeyRideEnd = CreateEvent("jockey_ride_end");
					eJockeyRideEnd.SetInt("userid", GetClientUserId(dominator));
					eJockeyRideEnd.SetInt("victim", GetClientUserId(client));
					eJockeyRideEnd.SetInt("rescuer", GetClientUserId(client));
					eJockeyRideEnd.Fire();
				}
			}
			case 6:
			{
				if (!bIsL4D)
				{
					Event eChargerPummelEnd = CreateEvent("charger_pummel_end");
					eChargerPummelEnd.SetInt("userid", GetClientUserId(dominator));
					eChargerPummelEnd.SetInt("victim", GetClientUserId(client));
					eChargerPummelEnd.SetInt("rescuer", GetClientUserId(client));
					eChargerPummelEnd.Fire();
				}
			}
		}
		
		if (!bKillAttacker)
		{
			float fStaggerPos[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", fStaggerPos);
			SDKCall(hSHStagger, dominator, client, fStaggerPos);
		}
		else
		{
			ForcePlayerSuicide(dominator);
			
			Event ePlayerDeath = CreateEvent("player_death");
			ePlayerDeath.SetInt("userid", GetClientUserId(dominator));
			ePlayerDeath.SetInt("attacker", GetClientUserId(client));
			ePlayerDeath.Fire();
		}
		
		if (bIsL4D)
		{
			EmitSoundToAll("weapons/knife/knife_hitwall1.wav", client, SNDCHAN_WEAPON);
		}
		else
		{
			int iRandSound = GetRandomInt(1, 2);
			switch (iRandSound)
			{
				case 1: EmitSoundToAll("weapons/knife/knife_deploy.wav", client, SNDCHAN_WEAPON);
				case 2: EmitSoundToAll("weapons/knife/knife_hitwall1.wav", client, SNDCHAN_WEAPON);
			}
		}
	}
}

stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

stock bool IsSurvivor(int client)
{
	return (IsValidClient(client) && GetClientTeam(client) == 2);
}

stock bool IsValidEnt(int entity)
{
	return (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity));
}

stock void ExecuteCommand(int client, const char[] sCommand, const char[] sArgument)
{
	int iFlags = GetCommandFlags(sCommand);
	SetCommandFlags(sCommand, iFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", sCommand, sArgument);
	SetCommandFlags(sCommand, iFlags);
}

