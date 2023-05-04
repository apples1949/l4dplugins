#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <l4d2lib>
#include <colors>
#include <readyup>
#define REQUIRE_PLUGIN

#define CLAMP(%0,%1,%2) (((%0) > (%2)) ? (%2) : (((%0) < (%1)) ? (%1) : (%0)))

#define PLUGIN_TAG "" // \x04[Air Bonus]

#define SM2_DEBUG    0

/** 
	Bibliography:
	'l4d2_scoremod' by CanadaRox, ProdigySim
	'damage_bonus' by CanadaRox, Stabby
	'l4d2_scoringwip' by ProdigySim
	'srs.scoringsystem' by AtomicStryker
**/

new Handle:hCvarBonusPerSurvivorMultiplier;
new Handle:hCvarPermBonusProportion;
new Handle:hCvarAllowPills;
new Handle:hCvarPillsBonusFactor;
new Handle:hCvarAllowAdrenaline;
new Handle:hCvarAdrenalineBonusFactor;
new Handle:hCvarAllowMed;
new Handle:hCvarMedBonusFactor;
new Handle:hCvarAllowThrow;
new Handle:hCvarThrowBonusFactor;
new Handle:hCvarPermTotal;
new Handle:hCvarTempTotal;
new Handle:hCvarAllowTempExtraBonus;
new Handle:hCvarTempExtraBonusFactor;
new Handle:hCvarIncapPenalty;
new Handle:hCvarAllowMix;
new Handle:hCvarTempToPerm;
new Handle:hCvarPermToTemp;
new Handle:hCvarDeathPenaltyFactor;
new Handle:hCvarDeathMininumPenalty;
// new Handle:hCvarTiebreakerBonus;

new Handle:hCvarValveSurvivalBonus;
new Handle:hCvarValveTieBreaker;

new Float:fMapBonus;
new Float:fMapDamageBonus;
new Float:fPermHpWorth;
new Float:fTempHpWorth;
new Float:fSurvivorBonus[2];
new Float:fTempExtraBonusWorth;
new Float:fPermHealthProportion;
new Float:fTempHealthProportion;

new iMapDistance;
new iTeamSize;
new iPillWorth;
new iAdrenWorth;
new iMedWorth;
new iThrowWorth;
new iLostTempHealth[2];
new iLostPermHealth[2];
new iTempHealth[MAXPLAYERS + 1];
new iPermHealth[MAXPLAYERS + 1];
new iSiDamage[2];

new String:sSurvivorState[2][32];

new bool:bLateLoad;
new bool:bRoundOver;
new bool:bTiebreakerEligibility[2];
new bool:bTempEB[2];

public Plugin:myinfo =
{
	name = "L4D2 ScoreMod Remake by Air",
	author = "Visor , A1R",
	description = "The scoring plugin made by air",
	version = "1.1",
	url = "https://github.com/A1oneR/L4D2_DRDK_Plugins"
};

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], errMax)
{
        //CreateNative("SMPlus_GetDamageBonus", Native_GetDamageBonus);
        //CreateNative("SMPlus_GetItemsBonus", Native_GetItemsBonus);
       // CreateNative("SMPlus_GetItemsMaxBonus", Native_GetItemsMaxBonus);
       // CreateNative("SMPlus_GetMaxDamageBonus", Native_GetMaxDamageBonus);
       // CreateNative("SMPlus_GetTempExtraBonus", Native_GetTempExtraBonus);
       // CreateNative("SMPlus_GetTempExtraBonusWorth", Native_GetTempExtraBonusWorth);
        RegPluginLibrary("l4d3_scoremod_DRDK_remake");
        bLateLoad = late;
        return APLRes_Success;
}

public OnPluginStart()
{
	hCvarBonusPerSurvivorMultiplier = CreateConVar("am_survivor_multi", "0.5", "Total Survivor Base Bonus = this * Number of Survivors * Map Distance", FCVAR_NONE, true, 0.0, true, 100.0);
	hCvarPermBonusProportion = CreateConVar("am_perm_bonus_proportion", "0.5", "Perm Bonus = this * Damage Bonus", FCVAR_NONE, true, 0.0, true, 1.0);
	hCvarAllowPills = CreateConVar("am_items_bonus_allow_pills", "1", "Are we allow pills as the part of scoring");
	hCvarPillsBonusFactor = CreateConVar("am_items_pills_bonus_factor", "0.1", "Unused pills can gain this * Map Distance", FCVAR_NONE, true, 0.0, true, 1000.0);
	hCvarAllowAdrenaline = CreateConVar("am_items_bonus_allow_adrenaline", "1", "Are we allow adrenaline as the part of scoring");
	hCvarAdrenalineBonusFactor = CreateConVar("am_items_adrenaline_bonus_factor", "0.1", "Unused adrenalines can gain this * Map Distance", FCVAR_NONE, true, 0.0, true, 100.0);
	hCvarAllowMed = CreateConVar("am_items_bonus_allow_med", "1", "Are we allow medkits as the part of scoring");
	hCvarMedBonusFactor = CreateConVar("am_items_med_bonus_factor", "0.4", "Unused Medkits can gain this * Map Distance", FCVAR_NONE, true, 0.0, true, 1000.0);
	hCvarAllowThrow = CreateConVar("am_items_bonus_allow_throw", "1", "Are we allow thrown as the part of scoring");
	hCvarThrowBonusFactor = CreateConVar("am_items_throw_bonus_factor", "0.02", "Unused Throwable can gain this * Map Distance", FCVAR_NONE, true, 0.0, true, 1000.0);
	hCvarPermTotal = CreateConVar("am_perm_total", "400", "We consider the max of the survivor team's perm health", FCVAR_NONE, true, 1.0, true, 10000.0);
	hCvarTempTotal = CreateConVar("am_temp_total", "240", "We consider the max of the survivor team's temp health", FCVAR_NONE, true, 1.0, true, 10000.0);
	hCvarAllowTempExtraBonus = CreateConVar("am_bonus_allow_temp_extra", "1", "Are we allow the extrabonus for entering saferoom without any temphealth lost");
	hCvarTempExtraBonusFactor = CreateConVar("am_temp_extra_bonus_factor", "0.5", "The extra bonus will be this * Map Distance", FCVAR_NONE, true, 0.0, true, 1000.0);
	hCvarIncapPenalty = CreateConVar("am_incap_penalty", "30.0", "When someone is incapped, we reduce the tempbonus", FCVAR_NONE, true, 1.0, true, 1000.0);
	hCvarAllowMix = CreateConVar("am_health_damage_mix", "1", "Are we allow two pools mix together");
	hCvarPermToTemp = CreateConVar("am_health_damage_ptt", "1.0", "1 Perm Damage times this value to thansfer TotalMix Penalty (Mix set to 1)", FCVAR_NONE, true, 0.0);
	hCvarTempToPerm = CreateConVar("am_health_damage_ttp", "1.0", "1 Temp Damage times this value to thansfer TotalMix Penalty (Mix set to 1)", FCVAR_NONE, true, 0.0);
	hCvarDeathPenaltyFactor = CreateConVar("am_death_penalty_factor", "0.3", "Reduce the Bonus when someone died", FCVAR_NONE, true, 0.0, true, 1.0);
	hCvarDeathMininumPenalty = CreateConVar("am_death_min_penalty", "50.0", "The mininum bonus will be reduced when someone died", FCVAR_NONE, true, 0.0);
	// hCvarTiebreakerBonus = CreateConVar("sm2_tiebreaker_bonus", "25", "Tiebreaker for those cases when both teams make saferoom with no bonus", FCVAR_PLUGIN);
	
	hCvarValveSurvivalBonus = FindConVar("vs_survival_bonus");
	hCvarValveTieBreaker = FindConVar("vs_tiebreak_bonus");

	HookConVarChange(hCvarBonusPerSurvivorMultiplier, CvarChanged);
	HookConVarChange(hCvarPermBonusProportion, CvarChanged);

	HookEvent("round_start", EventHook:OnRoundStart, EventHookMode_PostNoCopy);
	//HookEvent("player_ledge_grab", OnPlayerLedgeGrab);
	//HookEvent("player_incapacitated", OnPlayerIncapped);
	HookEvent("player_hurt", OnPlayerHurt);
	//HookEvent("revive_success", OnPlayerRevived, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath);

	RegConsoleCmd("sm_health", CmdBonus);
	RegConsoleCmd("sm_damage", CmdBonus);
	RegConsoleCmd("sm_bonus", CmdBonus);
	RegConsoleCmd("sm_mapinfo", CmdMapInfo);
	RegAdminCmd("sm_recover", CmdRecover, ADMFLAG_GENERIC);

	if (bLateLoad) 
	{
		for (new i = 1; i <= MaxClients; i++) 
		{
			if (!IsClientInGame(i))
				continue;

			OnClientPutInServer(i);
		}
	}
}

public OnPluginEnd()
{
	ResetConVar(hCvarValveSurvivalBonus);
	ResetConVar(hCvarValveTieBreaker);
}

public OnConfigsExecuted()
{
	iTeamSize = GetConVarInt(FindConVar("survivor_limit"));
	SetConVarInt(hCvarValveTieBreaker, 0);

	iMapDistance = L4D2_GetMapValueInt("max_distance", L4D_GetVersusMaxCompletionScore());
	L4D_SetVersusMaxCompletionScore(iMapDistance);

	fPermHealthProportion = GetConVarFloat(hCvarPermBonusProportion);
	fTempHealthProportion = 1.0 - fPermHealthProportion;
	new iPermTotal = GetConVarInt(hCvarPermTotal);
	new iTempTotal = GetConVarInt(hCvarTempTotal);
	fMapBonus = iMapDistance * (GetConVarFloat(hCvarBonusPerSurvivorMultiplier) * iTeamSize);
	fMapDamageBonus = fMapBonus;
	fPermHpWorth = fMapDamageBonus / iPermTotal;
	fTempHpWorth = fMapDamageBonus / iTempTotal;
	if (GetConVarBool(hCvarAllowPills))
	{
		iPillWorth = RoundToFloor(fMapBonus * GetConVarFloat(hCvarPillsBonusFactor) / 4);
	}
	else
	{
		iPillWorth = 0;
	}
	if (GetConVarBool(hCvarAllowAdrenaline))
	{
		iAdrenWorth = RoundToFloor(fMapBonus * GetConVarFloat(hCvarAdrenalineBonusFactor) / 4);
	}
	else
	{
		iAdrenWorth = 0;
	}
	if (GetConVarBool(hCvarAllowMed))
	{
		iMedWorth = RoundToFloor(fMapBonus * GetConVarFloat(hCvarMedBonusFactor) / 4);
	}
	else
	{
		iMedWorth = 0;
	}
	if (GetConVarBool(hCvarAllowThrow))
	{
		iThrowWorth = RoundToFloor(fMapBonus * GetConVarFloat(hCvarThrowBonusFactor) / 4);
	}
	else
	{
		iThrowWorth = 0;
	}
	if (GetConVarBool(hCvarAllowTempExtraBonus))
	{
		fTempExtraBonusWorth = RoundToFloor(fMapBonus * GetConVarFloat(hCvarTempExtraBonusFactor)) * 1.0;
	}
	else
	{
		fTempExtraBonusWorth = 0.0;
	}
}

public OnMapStart()
{
	OnConfigsExecuted();

	iLostTempHealth[0] = 0;
	iLostTempHealth[1] = 0;
	iLostPermHealth[0] = 0;
	iLostPermHealth[1] = 0;
	bTempEB[0] = true;
	bTempEB[1] = true;
	iSiDamage[0] = 0;
	iSiDamage[1] = 0;
	bTiebreakerEligibility[0] = false;
	bTiebreakerEligibility[1] = false;
}

public OnRoundIsLive()
{
	iLostTempHealth[InSecondHalfOfRound()] = 0;
	iLostPermHealth[InSecondHalfOfRound()] = 0;
}



public CvarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	OnConfigsExecuted();
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public OnRoundStart(Handle:convar, const String:oldValue[], const String:newValue[])
{
	for (new i = 0; i < MAXPLAYERS; i++)
	{
		iTempHealth[i] = 0;
	}
	bRoundOver = false;
}
public Action:CmdRecover(client, args)
{
	iLostTempHealth[InSecondHalfOfRound()] = 0;
	iLostPermHealth[InSecondHalfOfRound()] = 0;
	CPrintToChatAll("{default}生还者{blue}血分{default}已恢复");

	return Plugin_Handled;
}

/**
public Native_GetHealthBonus(Handle:plugin, numParams)
{
    return RoundToFloor(GetSurvivorHealthBonus());
}
 
public Native_GetMaxHealthBonus(Handle:plugin, numParams)
{
    return RoundToFloor(fMapHealthBonus);
}
 
public Native_GetDamageBonus(Handle:plugin, numParams)
{
    return RoundToFloor(GetSurvivorDamageBonus());
}
 
public Native_GetMaxDamageBonus(Handle:plugin, numParams)
{
    return RoundToFloor(fMapDamageBonus);
}
 
public Native_GetPillsBonus(Handle:plugin, numParams)
{
    return RoundToFloor(GetSurvivorPillBonus());
}

public Native_GetMaxPillsBonus(Handle:plugin, numParams)
{
    return iPillWorth * iTeamSize;
}

public Native_GetMedBonus(Handle:plugin, numParams)
{
    return RoundToFloor(GetSurvivorMedBonus());
}

public Native_GetMaxMedBonus(Handle:plugin, numParams)
{
    return iMedWorth * iTeamSize;
}

public Native_GetThrowBonus(Handle:plugin, numParams)
{
    return RoundToFloor(GetSurvivorThrowBonus());
}

public Native_GetMaxThrowBonus(Handle:plugin, numParams)
{
    return iThrowWorth * iTeamSize;
}
**/

public Action:CmdBonus(client, args)
{
	if (bRoundOver || !client)
	return Plugin_Handled;

	decl String:sCmdType[64];
	GetCmdArg(1, sCmdType, sizeof(sCmdType));

	new Float:fDamageBonus = GetSurvivorDamageBonus();
	new Float:fItemsBonus = GetSurvivorItemsBonus();
	new Float:fItemsMaxBonus = float(iPillWorth * iTeamSize + iAdrenWorth * iTeamSize + iMedWorth * iTeamSize + iThrowWorth * iTeamSize);
	new Float:fTempExtraBonus = GetSurvivorTempExtraBonus();

	if (GetConVarBool(hCvarAllowTempExtraBonus))
	{
		if (InSecondHalfOfRound())
		{
			CPrintToChat(client, "%s{default}R{red}#1{default} 得分: {red}%d{default} <{olive}%.1f%%{default}>", PLUGIN_TAG, RoundToFloor(fSurvivorBonus[0]), CalculateBonusPercent(fSurvivorBonus[0]));
		}
		CPrintToChat(client, "%s{default}R{blue}#%i{default} 得分: {blue}%d{default} <{olive}%.1f%%{default}> [DB: {blue}%.0f%%{default} | Items: {default}%.0f%{default} | TempEB: {blue}%.0f%{default}({olive}%s{default})]", PLUGIN_TAG, InSecondHalfOfRound() + 1, RoundToFloor(fDamageBonus + fItemsBonus + fTempExtraBonus), CalculateBonusPercent(fDamageBonus + fItemsBonus + fTempExtraBonus, fMapDamageBonus + fItemsMaxBonus + fTempExtraBonusWorth), CalculateBonusPercent(fDamageBonus, fMapDamageBonus), fItemsBonus, fTempExtraBonus, bTempEB[InSecondHalfOfRound()] ? "T" : "F");
		// R#1 Bonus: 700 <70.0%> [DB: 50% | items: 200 | TempEB: 200(T)]
	}
	else if (fItemsMaxBonus > 0.0)
	{
		if (InSecondHalfOfRound())
		{
			CPrintToChat(client, "%s{default}R{red}#1{default} 得分: {red}%d{default} <{olive}%.1f%%{default}>", PLUGIN_TAG, RoundToFloor(fSurvivorBonus[0]), CalculateBonusPercent(fSurvivorBonus[0]));
		}
		CPrintToChat(client, "%s{default}R{blue}#%i{default} 得分: {blue}%d{default} <{olive}%.1f%%{default}> [DB: {blue}%.0f%%{default} | Items: {default}%.0f%{default}]", PLUGIN_TAG, InSecondHalfOfRound() + 1, RoundToFloor(fDamageBonus + fItemsBonus), CalculateBonusPercent(fDamageBonus + fItemsBonus, fMapDamageBonus + fItemsMaxBonus), CalculateBonusPercent(fDamageBonus, fMapDamageBonus), fItemsBonus);
		// R#1 Bonus: 700 <70.0%> [DB: 50% | items: 200]
	}
	else
	{
		if (InSecondHalfOfRound())
		{
			CPrintToChat(client, "%s{default}R{red}#1{default} 得分: {red}%d{default} <{olive}%.1f%%{default}>", PLUGIN_TAG, RoundToFloor(fSurvivorBonus[0]), CalculateBonusPercent(fSurvivorBonus[0]));
		}
		CPrintToChat(client, "%s{default}R{blue}#%i{default} 得分: {blue}%d{default} <{olive}%.1f%%{default}> [DB: {blue}%.0f%%{default}]", PLUGIN_TAG, InSecondHalfOfRound() + 1, RoundToFloor(fDamageBonus + fItemsBonus), CalculateBonusPercent(fDamageBonus + fItemsBonus, fMapDamageBonus + fItemsMaxBonus), CalculateBonusPercent(fDamageBonus, fMapDamageBonus));
		// R#1 Bonus: 700 <70.0%> [DB: 50%]
	}
	return Plugin_Handled;
}

public Action:CmdMapInfo(client, args)
{
	new Float:fMaxPillsBonus = float(iPillWorth * iTeamSize);
	new Float:fMaxMedBonus = float(iMedWorth * iTeamSize);
	new Float:fMaxThrowBonus = float(iThrowWorth * iTeamSize);
	new Float:fMaxAdrenBonus = float(iAdrenWorth * iTeamSize);
	new Float:fItemsMaxBonus = fMaxAdrenBonus + fMaxMedBonus + fMaxPillsBonus + fMaxThrowBonus;
	new Float:fTotalBonus;
	if (GetConVarBool(hCvarAllowTempExtraBonus))
	{
		fTotalBonus = fMapDamageBonus + fItemsMaxBonus + fTempExtraBonusWorth - (fMaxPillsBonus <= fMaxAdrenBonus ? fMaxPillsBonus : fMaxAdrenBonus);
	}
	else
	{
		fTotalBonus = fMapDamageBonus + fItemsMaxBonus - (fMaxPillsBonus <= fMaxAdrenBonus ? fMaxPillsBonus : fMaxAdrenBonus);
	}
	
	CPrintToChat(client, "{default}[{olive}Air Bonus {lightgreen}Remake{default} :: {olive}%iv%i{default}] 地图设置", iTeamSize, iTeamSize);
	CPrintToChat(client, "{default}路程: {lightgreen}%d{default}", iMapDistance);
	CPrintToChat(client, "{default}总分: {lightgreen}%d{default} <{olive}100.0%%{default}>", RoundToFloor(fTotalBonus));
	CPrintToChat(client, "{default}伤害分: {lightgreen}%d{default} <{olive}%.1f%%{default}>", RoundToFloor(fMapDamageBonus), CalculateBonusPercent(fMapDamageBonus, fTotalBonus));
	if (GetConVarBool(hCvarAllowPills))
	{
		CPrintToChat(client, "{default}药分: {blue}%d{default}(最高 {blue}%d{default}) <{olive}%.1f%%{default}>", iPillWorth, RoundToFloor(fMaxPillsBonus), CalculateBonusPercent(fMaxPillsBonus, fTotalBonus));
	}
	if (GetConVarBool(hCvarAllowAdrenaline))
	{
		CPrintToChat(client, "{default}针分: {blue}%d{default}(最高 {blue}%d{default}) <{olive}%.1f%%{default}>", iAdrenWorth, RoundToFloor(fMaxAdrenBonus), CalculateBonusPercent(fMaxAdrenBonus, fTotalBonus));
	}
	if (GetConVarBool(hCvarAllowMed))
	{
		CPrintToChat(client, "{default}包分: {red}%d{default}(最高 {red}%d{default}) <{olive}%.1f%%{default}>", iMedWorth, RoundToFloor(fMaxMedBonus), CalculateBonusPercent(fMaxMedBonus, fTotalBonus));
	}
	if (GetConVarBool(hCvarAllowThrow))
	{
		CPrintToChat(client, "{default}投掷分: {olive}%d{default}(最高 {olive}%d{default}) <{olive}%.1f%%{default}>", iThrowWorth, RoundToFloor(fMaxThrowBonus), CalculateBonusPercent(fMaxThrowBonus, fTotalBonus));
	}
	
	// PrintToChat(client, "\x01破平分: \x05%d\x01", iPillWorth);
	// [Air ScoreMod Remake :: 4v4] Map Info
	// Distance: 400
	// Bonus: 960 <100.0%>
	// Damage Bonus: 800 <21.7%>
	// Items Bonus: Max 300 <13.1%>
	// Temp ExtraBonus: 160 <13.1%>
	// Tiebreaker: 30
	return Plugin_Handled;
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (!IsSurvivor(victim) || IsPlayerIncap(victim)) return Plugin_Continue;

#if SM2_DEBUG
	if (GetSurvivorTemporaryHealth(victim) > 0) PrintToChatAll("\x04%N\x01 has \x05%d\x01 temp HP now(damage: \x03%.1f\x01)", victim, GetSurvivorTemporaryHealth(victim), damage);
#endif
	iTempHealth[victim] = GetSurvivorTemporaryHealth(victim);
	iPermHealth[victim] = GetSurvivorPermanentHealth(victim);
	if (iPermHealth[victim] > 0)
	{
	    iLostPermHealth[InSecondHalfOfRound()] += (damage <= iPermHealth[victim] ? RoundFloat(damage) : iPermHealth[victim]);
	}
	
	// Small failsafe/workaround for stuff that inflicts more than 100 HP damage (like tank hittables); we don't want to reward that more than it's worth
	if (!IsAnyInfected(attacker)) iSiDamage[InSecondHalfOfRound()] += (damage <= 100.0 ? RoundFloat(damage) : 100);
	
	return Plugin_Continue;
}

/*
public OnPlayerLedgeGrab(Handle:event, const String:name[], bool:dontBroadcast)
{
	iLostTempHealth[InSecondHalfOfRound()] += 1;
}
*/

/*
public OnPlayerIncapped(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new Float:fIncapPenalty = GetConVarFloat(hCvarIncapPenalty);
	if (IsSurvivor(client))
	{
		iLostTempHealth[InSecondHalfOfRound()] += RoundToFloor(fTempHpWorth * fIncapPenalty);
		PrintToChatAll("Reduce:%i", RoundToFloor(fTempHpWorth * fIncapPenalty));
	} 
}
*/

public Action OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsSurvivor(client))
	{
		return Plugin_Continue;
	}
	if (GetConVarBool(hCvarAllowMix))
	{
		new iTotalHealthPoolCac = GetConVarInt(hCvarPermTotal) + GetConVarInt(hCvarTempTotal);
		new Float:fDamageWorthCac = fMapDamageBonus / float(iTotalHealthPoolCac);
		new Float:fDamageBonusCac = fMapDamageBonus - (float(iLostPermHealth[InSecondHalfOfRound()]) * GetConVarFloat(hCvarPermToTemp) * fDamageWorthCac + float(iLostTempHealth[InSecondHalfOfRound()]) * GetConVarFloat(hCvarTempToPerm) * fDamageWorthCac);
		new fPPenalty = RoundToFloor(fDamageBonusCac * GetConVarFloat(hCvarPermToTemp) * fDamageWorthCac * GetConVarFloat(hCvarDeathPenaltyFactor) / 4);
		new fTPenalty = RoundToFloor(fDamageBonusCac * GetConVarFloat(hCvarTempToPerm) * fDamageWorthCac * GetConVarFloat(hCvarDeathPenaltyFactor) / 4);
		if (fPPenalty + fTPenalty <= GetConVarFloat(hCvarDeathMininumPenalty))
		{
			iLostPermHealth[InSecondHalfOfRound()] += GetConVarInt(hCvarDeathMininumPenalty) / 2;
			iLostTempHealth[InSecondHalfOfRound()] += GetConVarInt(hCvarDeathMininumPenalty) / 2;
		}
		else
		{
			iLostPermHealth[InSecondHalfOfRound()] += fPPenalty;
			iLostTempHealth[InSecondHalfOfRound()] += fTPenalty;
		}
		//PrintToChatAll("LostPerm:%i, LostTemp:%i, PP:%.1f%, TP:%.1f%", iLostPermHealth[InSecondHalfOfRound()], iLostTempHealth[InSecondHalfOfRound()], fPPenalty, fTPenalty);
		return Plugin_Continue;
	}
	else
	{
		iLostPermHealth[InSecondHalfOfRound()] += (fMapDamageBonus * fPermHealthProportion - float(iLostPermHealth[InSecondHalfOfRound()]) * fPermHpWorth / 2) * GetConVarFloat(hCvarDeathPenaltyFactor);
		iLostTempHealth[InSecondHalfOfRound()] += (fMapDamageBonus * fTempHealthProportion - float(iLostTempHealth[InSecondHalfOfRound()]) * fTempHpWorth / 2) * GetConVarFloat(hCvarDeathPenaltyFactor);
	}
	return Plugin_Continue;
}

/*
public Action OnPlayerRevived(Handle:event, const String:name[], bool:dontBroadcast)
{
	bool bLedge = GetEventBool(event, "ledge_hang");
	if (!bLedge) return;

	int client = GetClientOfUserId(GetEventInt(event, "subject"));
	if (!IsSurvivor(client)) return;

	new Float:fIncapPenalty = GetConVarFloat(hCvarIncapPenalty);
	iLostTempHealth[InSecondHalfOfRound()] -= RoundToFloor(fTempHpWorth * fIncapPenalty);
	PrintToChatAll("Recover:%i", RoundToFloor(fTempHpWorth * fIncapPenalty));
	RequestFrame(Revival, client);
}

public void Revival(int client)
{
	new Float:fIncapPenalty = GetConVarFloat(hCvarIncapPenalty);
	iLostTempHealth[InSecondHalfOfRound()] -= RoundToFloor(fTempHpWorth * fIncapPenalty);
	PrintToChatAll("Recover:%i", RoundToFloor(fTempHpWorth * fIncapPenalty));
}
*/

public Action:OnPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new damage = GetEventInt(event, "dmg_health");
	new damagetype = GetEventInt(event, "type");

	new fFakeDamage = damage;

	// Victim has to be a Survivor.
	// Attacker has to be a Survivor.
	// Player can't be Incapped.
	// Damage has to be from manipulated Shotgun FF. (Plasma)
	// Damage has to be higher than the Survivor's permanent health.
	if (!IsSurvivor(victim) || !IsSurvivor(attacker) || IsPlayerIncap(victim) || damagetype != DMG_PLASMA || fFakeDamage < GetSurvivorPermanentHealth(victim)) return Plugin_Continue;

	iTempHealth[victim] = GetSurvivorTemporaryHealth(victim);
	if (fFakeDamage > iTempHealth[victim]) fFakeDamage = iTempHealth[victim];

	iLostTempHealth[InSecondHalfOfRound()] += fFakeDamage;
	iTempHealth[victim] = GetSurvivorTemporaryHealth(victim) - fFakeDamage;

	return Plugin_Continue;
}

public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype)
{
	if (!IsSurvivor(victim)) return;
		
#if SM2_DEBUG
	PrintToChatAll("\x03%N\x01\x05 lost %i\x01 temp HP after being attacked(arg damage: \x03%.1f\x01)", victim, iTempHealth[victim] - (IsPlayerAlive(victim) ? GetSurvivorTemporaryHealth(victim) : 0), damage);
#endif
	if (!IsPlayerAlive(victim) || (IsPlayerIncap(victim) && !IsPlayerLedged(victim)))
	{
		iLostTempHealth[InSecondHalfOfRound()] += iTempHealth[victim];
	}
	else if (!IsPlayerLedged(victim))
	{
		iLostTempHealth[InSecondHalfOfRound()] += iTempHealth[victim] ? (iTempHealth[victim] - GetSurvivorTemporaryHealth(victim)) : 0;
	}
	iTempHealth[victim] = IsPlayerIncap(victim) ? 0 : GetSurvivorTemporaryHealth(victim);
}

// Compatibility with Alternate Damage Mechanics plugin
// This plugin(i.e. Scoremod2) will work ideally fine with or without the aforementioned plugin
public L4D2_ADM_OnTemporaryHealthSubtracted(client, oldHealth, newHealth)
{
	new healthLost = oldHealth - newHealth;
	iTempHealth[client] = newHealth;
	iLostTempHealth[InSecondHalfOfRound()] += healthLost;
	iSiDamage[InSecondHalfOfRound()] += healthLost; // this forward doesn't fire for ledged/incapped survivors so we're good
}

public Action:L4D2_OnEndVersusModeRound(bool:countSurvivors)
{
#if SM2_DEBUG
	PrintToChatAll("CDirector::OnEndVersusModeRound() called. InSecondHalfOfRound(): %d, countSurvivors: %d", InSecondHalfOfRound(), countSurvivors);
#endif
	if (bRoundOver)
		return Plugin_Continue;

	new team = InSecondHalfOfRound();
	new iSurvivalMultiplier = GetUprightSurvivors();    // I don't know how reliable countSurvivors is and I'm too lazy to test
	if (GetConVarBool(hCvarAllowTempExtraBonus))
	{
		fSurvivorBonus[team] = GetSurvivorDamageBonus() + GetSurvivorItemsBonus() + GetSurvivorTempExtraBonus();
	}
	else
	{
		fSurvivorBonus[team] = GetSurvivorDamageBonus() + GetSurvivorItemsBonus();
	}
	fSurvivorBonus[team] = float(RoundToFloor(fSurvivorBonus[team] / float(iTeamSize)) * iTeamSize); // make it a perfect divisor of team size value
	if (iSurvivalMultiplier > 0 && RoundToFloor(fSurvivorBonus[team] / iSurvivalMultiplier) >= iTeamSize) // anything lower than team size will result in 0 after division
	{
		SetConVarInt(hCvarValveSurvivalBonus, RoundToFloor(fSurvivorBonus[team] / iSurvivalMultiplier));
		fSurvivorBonus[team] = float(GetConVarInt(hCvarValveSurvivalBonus) * iSurvivalMultiplier);    // workaround for the discrepancy caused by RoundToFloor()
		Format(sSurvivorState[team], 32, "%s%i\x01/\x05%i\x01", (iSurvivalMultiplier == iTeamSize ? "\x05" : "\x04"), iSurvivalMultiplier, iTeamSize);
	#if SM2_DEBUG
		PrintToChatAll("\x01Survival bonus cvar updated. Value: \x05%i\x01 [multiplier: \x05%i\x01]", GetConVarInt(hCvarValveSurvivalBonus), iSurvivalMultiplier);
	#endif
	}
	else
	{
		fSurvivorBonus[team] = 0.0;
		SetConVarInt(hCvarValveSurvivalBonus, 0);
		Format(sSurvivorState[team], 32, "\x04%s\x01", (iSurvivalMultiplier == 0 ? "途中去世" : "没有得分"));
		bTiebreakerEligibility[team] = (iSurvivalMultiplier == iTeamSize);
	}

	// Check if it's the end of the second round and a tiebreaker case
	if (team > 0 && bTiebreakerEligibility[0] && bTiebreakerEligibility[1])
	{
		GameRules_SetProp("m_iChapterDamage", iSiDamage[0], _, 0, true);
		GameRules_SetProp("m_iChapterDamage", iSiDamage[1], _, 1, true);
		
		// That would be pretty funny otherwise
		if (iSiDamage[0] != iSiDamage[1])
		{
			SetConVarInt(hCvarValveTieBreaker, iPillWorth);
		}
	}
	
	// Scores print
	CreateTimer(3.0, PrintRoundEndStats, _, TIMER_FLAG_NO_MAPCHANGE);

	bRoundOver = true;
	return Plugin_Continue;
}

public Action:PrintRoundEndStats(Handle:timer) 
{
	for (new i = 0; i <= InSecondHalfOfRound(); i++)
	{
		CPrintToChatAll("%s{default}本局轮数 {olive}%i{default} 得分: {blue}%d{default}/{olive}%d{default} <{olive}%.1f%%{default}> [%s]", PLUGIN_TAG, (i + 1), RoundToFloor(fSurvivorBonus[i]), RoundToFloor(fMapBonus + float(iPillWorth * iTeamSize) + float(iAdrenWorth * iTeamSize) + float(iMedWorth * iTeamSize) + float(iThrowWorth * iTeamSize) + fTempExtraBonusWorth), CalculateBonusPercent(fSurvivorBonus[i]), sSurvivorState[i]);
		// [EQSM :: Round 1] Bonus: 487/1200 <42.7%> [3/4]
	}
	
	if (InSecondHalfOfRound() && bTiebreakerEligibility[0] && bTiebreakerEligibility[1])
	{
		PrintToChatAll("%s\x03TIEBREAKER\x01: Team \x04%#1\x01 - \x05%i\x01, Team \x04%#2\x01 - \x05%i\x01", PLUGIN_TAG, iSiDamage[0], iSiDamage[1]);
		if (iSiDamage[0] == iSiDamage[1])
		{
			PrintToChatAll("%s\x05Teams have performed absolutely equal! Impossible to decide a clear round winner", PLUGIN_TAG);
		}
	}
}

Float:GetSurvivorDamageBonus()
{
	new survivalMultiplier = GetUprightSurvivors();
	new Float:fPermDamageBonus = fMapDamageBonus * fPermHealthProportion - float(iLostPermHealth[InSecondHalfOfRound()]) * fPermHpWorth / 2;
	new Float:fTempDamageBonus = fMapDamageBonus * fTempHealthProportion - float(iLostTempHealth[InSecondHalfOfRound()]) * fTempHpWorth / 2;
	if (GetConVarBool(hCvarAllowMix))
	{
		new iTotalHealthPool = GetConVarInt(hCvarPermTotal) + GetConVarInt(hCvarTempTotal);
		new Float:fDamageWorth = fMapDamageBonus / float(iTotalHealthPool);
		new Float:fDamageBonus = fMapDamageBonus - (float(iLostPermHealth[InSecondHalfOfRound()]) * GetConVarFloat(hCvarPermToTemp) * fDamageWorth + float(iLostTempHealth[InSecondHalfOfRound()]) * GetConVarFloat(hCvarTempToPerm) * fDamageWorth);
		//PrintToChatAll("LostPerm=%i, %i, %.1f, %.1f", iLostPermHealth[InSecondHalfOfRound()], iLostTempHealth[InSecondHalfOfRound()], fDamageBonus, fMapDamageBonus);
		return (fDamageBonus > 0.0 && survivalMultiplier > 0) ? fDamageBonus : 0.0;
	}
	if (fPermDamageBonus <= 0)
	{
		fPermDamageBonus = 0.0;
	}
	if (fTempDamageBonus <= 0)
	{
		fTempDamageBonus = 0.0;
	}
	new Float:fDamageBonus = fPermDamageBonus + fTempDamageBonus;
#if SM2_DEBUG
	PrintToChatAll("\x01Adding temp hp bonus: \x05%.1f\x01 (eligible survivors: \x05%d\x01)", fDamageBonus, survivalMultiplier);
#endif
	return (fDamageBonus > 0.0 && survivalMultiplier > 0) ? fDamageBonus : 0.0;
}

Float:GetSurvivorItemsBonus()
{			
	new pillsBonus;
	new medBonus;
	new ThrowBonus;
	new survivorCount;
	for (new i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (IsPlayerAlive(i) && HasPills(i))
			{
				pillsBonus += iPillWorth;
			#if SM2_DEBUG
				PrintToChatAll("\x01Adding \x05%N's\x01 pills contribution, total bonus: \x05%d\x01 pts", i, pillsBonus);
			#endif
			}
			if (IsPlayerAlive(i) && HasAdrenaline(i))
			{
			    pillsBonus += iAdrenWorth;
			}
			if (IsPlayerAlive(i) && !IsPlayerIncap(i) && HasMed(i))
			{
				medBonus += iMedWorth;
			#if SM2_DEBUG
				PrintToChatAll("\x01Adding \x05%N's\x01 med contribution, total bonus: \x05%d\x01 pts", i, pillsBonus);
			#endif
			}
			if (IsPlayerAlive(i) && HasBile(i))
			{
				ThrowBonus += iThrowWorth;
			#if SM2_DEBUG
				PrintToChatAll("\x01Adding \x05%N's\x01 Throw contribution, total bonus: \x05%d\x01 pts", i, MedBonus);
			#endif
			}
			if (IsPlayerAlive(i) && HasMolo(i))
			{
			    ThrowBonus += iThrowWorth;
			}
			if (IsPlayerAlive(i) && HasPipe(i))
			{
			    ThrowBonus += iThrowWorth;
			}
		}
	}
	new ItemsBonus = pillsBonus + medBonus + ThrowBonus;
	return Float:float(ItemsBonus);
}

Float:GetSurvivorTempExtraBonus()
{			
	new Float:HasTempEB;
	if (iLostTempHealth[InSecondHalfOfRound()] <= 0)
	{
		HasTempEB = fTempExtraBonusWorth;
		bTempEB[InSecondHalfOfRound()] = true;
	}
	else
	{
		HasTempEB = 0.0;
		bTempEB[InSecondHalfOfRound()] = false;
	}
	
	return Float:(HasTempEB);
}

Float:CalculateBonusPercent(Float:score, Float:maxbonus = -1.0)
{
	return score / (maxbonus == -1.0 ? (fMapBonus + float(iPillWorth * iTeamSize) + float(iMedWorth * iTeamSize)) : maxbonus) * 100;
}

/************/
/** Stocks **/
/************/

InSecondHalfOfRound()
{
	return GameRules_GetProp("m_bInSecondHalfOfRound");
}

bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

bool:IsAnyInfected(entity)
{
	if (entity > 0 && entity <= MaxClients)
	{
		return IsClientInGame(entity) && GetClientTeam(entity) == 3;
	}
	else if (entity > MaxClients)
	{
		decl String:classname[64];
		GetEdictClassname(entity, classname, sizeof(classname));
		if (StrEqual(classname, "infected") || StrEqual(classname, "witch")) 
		{
			return true;
		}
	}
	return false;
}

bool:IsPlayerIncap(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool:IsPlayerLedged(client)
{
	return bool:(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}

GetUprightSurvivors()
{
	new aliveCount;
	new survivorCount;
	for (new i = 1; i <= MaxClients && survivorCount < iTeamSize; i++)
	{
		if (IsSurvivor(i))
		{
			survivorCount++;
			if (IsPlayerAlive(i) && !IsPlayerIncap(i) && !IsPlayerLedged(i))
			{
				aliveCount++;
			}
		}
	}
	return aliveCount;
}

GetSurvivorTemporaryHealth(client)
{
	new temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return (temphp > 0 ? temphp : 0);
}

GetSurvivorPermanentHealth(client)
{
	// Survivors always have minimum 1 permanent hp
	// so that they don't faint in place just like that when all temp hp run out
	// We'll use a workaround for the sake of fair calculations
	// Edit 2: "Incapped HP" are stored in m_iHealth too; we heard you like workarounds, dawg, so we've added a workaround in a workaround
	return GetEntProp(client, Prop_Send, "m_currentReviveCount") > 0 ? 0 : (GetEntProp(client, Prop_Send, "m_iHealth") > 0 ? GetEntProp(client, Prop_Send, "m_iHealth") : 0);
}

bool:HasPills(client)
{
	new item = GetPlayerWeaponSlot(client, 4);
	if (IsValidEdict(item))
	{
		decl String:buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		return StrEqual(buffer, "weapon_pain_pills");
	}
	return false;
}

bool:HasAdrenaline(client)
{
	new item = GetPlayerWeaponSlot(client, 4);
	if (IsValidEdict(item))
	{
		decl String:buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		return StrEqual(buffer, "weapon_adrenaline");
	}
	return false;
}

bool:HasMed(client)
{
	new item = GetPlayerWeaponSlot(client, 3);
	if (IsValidEdict(item))
	{
		decl String:buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		return StrEqual(buffer, "weapon_first_aid_kit");
	}
	return false;
}

bool:HasBile(client)
{
	new item = GetPlayerWeaponSlot(client, 2);
	if (IsValidEdict(item))
	{
		decl String:buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		return StrEqual(buffer, "weapon_vomitjar");
	}
	return false;
}

bool:HasMolo(client)
{
	new item = GetPlayerWeaponSlot(client, 2);
	if (IsValidEdict(item))
	{
		decl String:buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		return StrEqual(buffer, "weapon_molotov");
	}
	return false;
}

bool:HasPipe(client)
{
	new item = GetPlayerWeaponSlot(client, 2);
	if (IsValidEdict(item))
	{
		decl String:buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		return StrEqual(buffer, "weapon_pipe_bomb");
	}
	return false;
}
