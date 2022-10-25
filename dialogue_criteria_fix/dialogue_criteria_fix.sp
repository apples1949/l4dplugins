#pragma semicolon 1
#include <sourcemod>
#include <dhooks>

#define PLUGIN_VERSION "0.65"

enum OS
{
	OS_Windows,
	OS_Linux
}

OS os_RetVal;

Address aDCF[4];
EngineVersion ev_RetVal;

int iActor;
bool bCriteriaFix;

static int iOriginalBytes_DCF[28] = {-1, ...};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	ev_RetVal = GetEngineVersion();
	if (ev_RetVal != Engine_Left4Dead && ev_RetVal != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "This is for L4D and L4D2 only");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "Dialogue Criteria Fix",
	author = "cravenge",
	description = "Resolves issues regarding talker criteria",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=335875"
};

public void OnPluginStart()
{
	os_RetVal = GetServerOS();
	
	GameData gd_Temp = FetchGameData("dialogue_criteria_fix");
	if (gd_Temp == null)
	{
		SetFailState("Game data file not found!");
	}
	
	DynamicDetour dd_Temp;
	
	if (ev_RetVal == Engine_Left4Dead2)
	{
		Address aTemp;
		
		int iTemp;
		
		if (os_RetVal == OS_Linux)
		{
			aTemp = gd_Temp.GetAddress("ModifyOrAppendGlobalCriteria");
			if (aTemp != Address_Null)
			{
				iTemp = gd_Temp.GetOffset("ModifyOrAppendGlobalCriteria_TeamNumberCondition");
				if (iTemp != -1)
				{
					aDCF[0] = aTemp + view_as<Address>(iTemp);
					if (LoadFromAddress(aDCF[0], NumberType_Int8) != 0x02)
					{
						SetFailState("Offset for \"ModifyOrAppendGlobalCriteria_TeamNumberCondition\" is incorrect!");
					}
					
					StoreToAddress(aDCF[0], 0x03, NumberType_Int8);
					StoreToAddress(aDCF[0] + view_as<Address>(2), 0x85, NumberType_Int8);
					
					PrintToServer("[FIX] Patched all \"IsAlive\" criteria to be appended for the Passing team as well");
				}
				else
				{
					SetFailState("Offset for \"ModifyOrAppendGlobalCriteria_TeamNumberCondition\" is missing!");
				}
				
				iTemp = gd_Temp.GetOffset("ModifyOrAppendGlobalCriteria_CharacterCondition");
				if (iTemp != -1)
				{
					aDCF[1] = aTemp + view_as<Address>(iTemp);
					if (LoadFromAddress(aDCF[1], NumberType_Int8) != 0x03)
					{
						SetFailState("Offset for \"ModifyOrAppendGlobalCriteria_CharacterCondition\" is incorrect!");
					}
					
					StoreToAddress(aDCF[1], 0x07, NumberType_Int8);
					
					PrintToServer("[FIX] Patched the L4D1 \"IsAlive\" criteria to be appended for the L4D2 survivor set as well");
				}
				else
				{
					SetFailState("Offset for \"ModifyOrAppendGlobalCriteria_CharacterCondition\" is missing!");
				}
			}
			else
			{
				SetFailState("Address for \"ModifyOrAppendGlobalCriteria\" is missing!");
			}
		}
		else
		{
			aTemp = gd_Temp.GetAddress("ForEachSurvivorSACF");
			if (aTemp != Address_Null)
			{
				iTemp = gd_Temp.GetOffset("ForEachSurvivorSACF_TeamNumberCondition");
				if (iTemp != -1)
				{
					aDCF[0] = aTemp + view_as<Address>(iTemp);
					if (LoadFromAddress(aDCF[0], NumberType_Int8) != 0x02)
					{
						SetFailState("Offset for \"ForEachSurvivorSACF_TeamNumberCondition\" is incorrect!");
					}
					
					StoreToAddress(aDCF[0], 0x03, NumberType_Int8);
					StoreToAddress(aDCF[0] + view_as<Address>(1), 0x74, NumberType_Int8);
					
					PrintToServer("[FIX] Patched all \"IsAlive\" criteria to be appended for the Passing team as well");
				}
				else
				{
					SetFailState("Offset for \"ForEachSurvivorSACF_TeamNumberCondition\" is missing!");
				}
			}
			else
			{
				SetFailState("Address for \"ForEachSurvivorSACF\" returned NULL!");
			}
			
			aTemp = gd_Temp.GetAddress("ModifyOrAppendGlobalCriteriaInternal");
			if (aTemp != Address_Null)
			{
				iTemp = gd_Temp.GetOffset("ModifyOrAppendGlobalCriteriaInternal_CharacterCondition");
				if (iTemp != -1)
				{
					aDCF[1] = aTemp + view_as<Address>(iTemp);
					if (LoadFromAddress(aDCF[1], NumberType_Int8) != 0x03)
					{
						SetFailState("Offset for \"ModifyOrAppendGlobalCriteriaInternal_CharacterCondition\" is incorrect!");
					}
					
					StoreToAddress(aDCF[1], 0x07, NumberType_Int8);
					
					PrintToServer("[FIX] Patched the L4D1 \"IsAlive\" criteria to be appended for the L4D2 survivor set as well");
				}
				else
				{
					SetFailState("Offset for \"ModifyOrAppendGlobalCriteriaInternal_CharacterCondition\" is missing!");
				}
			}
			else
			{
				SetFailState("Address for \"ModifyOrAppendGlobalCriteriaInternal\" returned NULL!");
			}
		}
		
		aTemp = gd_Temp.GetAddress("ModifyOrAppendCriteria_CTP");
		if (aTemp != Address_Null)
		{
			char sTemp[64];
			for (int i = 0; i < 2; i++)
			{
				FormatEx(sTemp, sizeof(sTemp), "CTPModifyOrAppendCriteria_%sCall", (i != 0) ? "SurvivorSet" : "TeamNumber");
				
				iTemp = gd_Temp.GetOffset(sTemp);
				if (iTemp != -1)
				{
					aDCF[i + 2] = aTemp + view_as<Address>(iTemp);
					
					for (iTemp = 0; iTemp < 14; iTemp++)
					{
						iOriginalBytes_DCF[14 * i + iTemp] = LoadFromAddress(aDCF[i + 2] + view_as<Address>(iTemp), NumberType_Int8);
						if (!iTemp && iOriginalBytes_DCF[14 * i] != 0xE8)
						{
							SetFailState("Offset for \"%s\" is incorrect!", sTemp);
						}
						
						StoreToAddress(aDCF[i + 2] + view_as<Address>(iTemp), 0x90, NumberType_Int8);
					}
					
					PrintToServer("[FIX] Patched %s \"DistTo\" criteria to no longer check for the current %s", (i != 1) ? "all" : "the L4D1", (i == 1) ? "survivor set" : "team");
				}
				else
				{
					SetFailState("Offset for \"%s\" is missing!", sTemp);
				}
			}
		}
		else
		{
			SetFailState("Address for \"ModifyOrAppendCriteria_CTP\" returned NULL!");
		}
	
		dd_Temp = DynamicDetour.FromConf(gd_Temp, "ModifyOrAppendGlobalCriteria");
		if (dd_Temp.Enable(Hook_Pre, dtrModifyOrAppendGlobalCriteria_Pre))
		{
			PrintToServer("[FIX] Pre-detour of \"ModifyOrAppendGlobalCriteria\" has been successfully made!");
		}
		else
		{
			SetFailState("Failed to make a pre-detour of \"ModifyOrAppendGlobalCriteria\"!");
		}
		
		dd_Temp = DynamicDetour.FromConf(gd_Temp, "SurvivorResponseCachedInfo::GetClosestSurvivorTo");
		if (dd_Temp != null)
		{
			if (!dd_Temp.Enable(Hook_Pre, dtrGetClosestSurvivorTo_Pre))
			{
				SetFailState("Failed to make a pre-detour of \"SurvivorResponseCachedInfo::GetClosestSurvivorTo\"!");
			}
			
			PrintToServer("[FIX] Pre-detour of \"SurvivorResponseCachedInfo::GetClosestSurvivorTo\" has been successfully made!");
		}
		else
		{
			SetFailState("Signature for \"SurvivorResponseCachedInfo::GetClosestSurvivorTo\" is broken!");
		}
	}
	else
	{
		dd_Temp = DynamicDetour.FromConf(gd_Temp, "ForEachSurvivor<SurvivorAliveCritFunctor>");
		if (dd_Temp != null)
		{
			if (!dd_Temp.Enable(Hook_Pre, dtrForEachSurvivorSACF_Pre))
			{
				SetFailState("Failed to make a pre-detour of \"ForEachSurvivor<SurvivorAliveCritFunctor>\"!");
			}
			
			PrintToServer("[FIX] Pre-detour of \"ForEachSurvivor<SurvivorAliveCritFunctor>\" has been successfully made!");
		}
		else
		{
			SetFailState("Signature for \"ForEachSurvivor<SurvivorAliveCritFunctor> is broken!");
		}
		
		dd_Temp = DynamicDetour.FromConf(gd_Temp, "CTerrorPlayer::ModifyOrAppendCriteria");
		if (dd_Temp == null)
		{
			SetFailState("Signature for \"CTerrorPlayer::ModifyOrAppendCriteria\" is broken!");
		}
	}
	
	dd_Temp = DynamicDetour.FromConf(gd_Temp, "UTIL_PlayerByIndex");
	if (dd_Temp != null)
	{
		if (!dd_Temp.Enable(Hook_Post, dtrPlayerByIndex_Post))
		{
			SetFailState("Failed to make a post detour of \"UTIL_PlayerByIndex\"!");
		}
		
		PrintToServer("[FIX] Post detour of \"UTIL_PlayerByIndex\" has been successfully made!");
	}
	else
	{
		SetFailState("Signature for \"UTIL_PlayerByIndex\" is broken!");
	}
	
	dd_Temp = DynamicDetour.FromConf(gd_Temp, "AI_CriteriaSet::AppendCriteria");
	if (dd_Temp != null)
	{
		if (!dd_Temp.Enable(Hook_Pre, dtrAppendCriteriaPre))
		{
			SetFailState("Failed to make a pre-detour of \"AI_CriteriaSet::AppendCriteria\"!");
		}
		
		PrintToServer("[FIX] Pre-detour of \"AI_CriteriaSet::AppendCriteria\" has been successfully made!");
	}
	else
	{
		SetFailState("Signature for \"AI_CriteriaSet::AppendCriteria\" is broken!");
	}
	
	dd_Temp = DynamicDetour.FromConf(gd_Temp, "CTerrorPlayer::ModifyOrAppendCriteria");
	if (dd_Temp.Enable(Hook_Pre, dtrModifyOrAppendCriteria_Pre))
	{
		PrintToServer("[FIX] Pre-detour of \"CTerrorPlayer::ModifyOrAppendCriteria\" has been successfully made!");
	}
	else
	{
		SetFailState("Failed to make a pre-detour of \"CTerrorPlayer::ModifyOrAppendCriteria\"!");
	}
	
	CreateConVar("dialogue_criteria_fix_version", PLUGIN_VERSION, "Version of the plug-in", FCVAR_NOTIFY);
}

public MRESReturn dtrModifyOrAppendGlobalCriteria_Pre(DHookReturn hReturn, DHookParam hParams)
{
	return HandleActorIndexes();
}

public MRESReturn dtrGetClosestSurvivorTo_Pre(DHookReturn hReturn, DHookParam hParams)
{
	hReturn.Value = GetEntProp(GetNearestAliveSurvivor(iActor), Prop_Send, "m_survivorCharacter");
	return MRES_Supercede;
}

public MRESReturn dtrForEachSurvivorSACF_Pre(DHookReturn hReturn, DHookParam hParams)
{
	return HandleActorIndexes();
}

public MRESReturn dtrPlayerByIndex_Post(DHookReturn hReturn, DHookParam hParams)
{
	if (!bCriteriaFix)
	{
		return MRES_Ignored;
	}
	
	if (hParams.Get(1) >= MaxClients)
	{
		bCriteriaFix = false;
	}
	
	int iReturn = hReturn.Value;
	if (iReturn != -1 && IsClientInGame(iReturn) && ((ev_RetVal != Engine_Left4Dead && GetClientTeam(iReturn) == 1) || GetEntProp(iReturn, Prop_Send, "m_survivorCharacter") < 0))
	{
		hReturn.Value = -1;
		return MRES_Override;
	}
	
	return HandleResponseActors(iReturn);
}

public MRESReturn dtrAppendCriteriaPre(DHookReturn hReturn, DHookParam hParams)
{
	static char sParam[24];
	hParams.GetString(1, sParam, sizeof(sParam));
	if (strncmp(sParam, "Is", 2) != 0 && strncmp(sParam, "DistTo", 6) != 0)
	{
		return MRES_Ignored;
	}
	
	if (sParam[0] == 'D')
	{
		static char sNewParam[16];
		GetNearestAliveSurvivor(iActor, sNewParam, GetCharacterByLetter(sParam[9]));
		
		hParams.SetString(2, sNewParam);
	}
	else
	{
		hParams.SetString(2, (!GetNearestAliveSurvivor(iActor, _, GetCharacterByLetter(sParam[5]), true)) ? "0" : "1");
	}
	return MRES_ChangedHandled;
}

public MRESReturn dtrModifyOrAppendCriteria_Pre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	return HandleResponseActors(pThis);
}

public void OnPluginEnd()
{
	if (ev_RetVal != Engine_Left4Dead2)
	{
		return;
	}
	
	int iTemp;
	for (int i = 3; i > -1; --i)
	{
		if (aDCF[i] == Address_Null)
		{
			continue;
		}
		
		if (1 < i)
		{
			PrintToServer("[FIX] Restoring the %s check for %s \"DistTo\" criteria...", (i != 3) ? "team" : "survivor set", (i != 2) ? "the L4D1" : "all");
			
			for (iTemp = 13; iTemp > -1; --iTemp)
			{
				StoreToAddress(aDCF[i] + view_as<Address>(iTemp), iOriginalBytes_DCF[14 * (i - 2) + iTemp], NumberType_Int8);
				
				iOriginalBytes_DCF[14 * (i - 2) + iTemp] = -1;
			}
		}
		else
		{
			if (i)
			{
				PrintToServer("[FIX] Detaching the L4D1 \"IsAlive\" criteria from the L4D2 survivor set...");
				
				StoreToAddress(aDCF[i], 0x03, NumberType_Int8);
			}
			else
			{
				PrintToServer("[FIX] Detaching all \"IsAlive\" criteria from the Passing team...");
				
				if (os_RetVal == OS_Windows)
				{
					StoreToAddress(aDCF[i] + view_as<Address>(1), 0x75, NumberType_Int8);
				}
				else
				{
					StoreToAddress(aDCF[i] + view_as<Address>(2), 0x84, NumberType_Int8);
				}
				StoreToAddress(aDCF[i], 0x02, NumberType_Int8);
			}
		}
	}
}

OS GetServerOS()
{
	static char sCmdLine[4];
	GetCommandLine(sCmdLine, sizeof(sCmdLine));
	return (sCmdLine[0] == '.') ? OS_Linux : OS_Windows;
}

GameData FetchGameData(const char[] file)
{
	char sFilePath[128];
	BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "gamedata/%s.txt", file);
	if (!FileExists(sFilePath))
	{
		File fileTemp = OpenFile(sFilePath, "w");
		if (fileTemp == null)
		{
			SetFailState("Something went wrong while creating the game data file!");
		}
		
		fileTemp.WriteLine("\"Games\"");
		fileTemp.WriteLine("{");
		fileTemp.WriteLine("	\"#default\"");
		fileTemp.WriteLine("	{");
		fileTemp.WriteLine("		\"Functions\"");
		fileTemp.WriteLine("		{");
		fileTemp.WriteLine("			\"UTIL_PlayerByIndex\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"signature\"			\"UTIL_PlayerByIndex\"");
		fileTemp.WriteLine("				\"callconv\"			\"cdecl\"");
		fileTemp.WriteLine("				\"return\"			\"cbaseentity\"");
		fileTemp.WriteLine("				\"arguments\"");
		fileTemp.WriteLine("				{");
		fileTemp.WriteLine("					\"a1\"");
		fileTemp.WriteLine("					{");
		fileTemp.WriteLine("						\"type\"		\"int\"");
		fileTemp.WriteLine("					}");
		fileTemp.WriteLine("				}");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"AI_CriteriaSet::AppendCriteria\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"signature\"			\"AI_CriteriaSet::AppendCriteria\"");
		fileTemp.WriteLine("				\"callconv\"			\"thiscall\"");
		fileTemp.WriteLine("				\"return\"			\"int\"");
		fileTemp.WriteLine("				\"arguments\"");
		fileTemp.WriteLine("				{");
		fileTemp.WriteLine("					\"a1\"");
		fileTemp.WriteLine("					{");
		fileTemp.WriteLine("						\"type\"		\"charptr\"");
		fileTemp.WriteLine("					}");
		fileTemp.WriteLine("					\"a2\"");
		fileTemp.WriteLine("					{");
		fileTemp.WriteLine("						\"type\"		\"charptr\"");
		fileTemp.WriteLine("					}");
		fileTemp.WriteLine("					\"a3\"");
		fileTemp.WriteLine("					{");
		fileTemp.WriteLine("						\"type\"		\"float\"");
		fileTemp.WriteLine("					}");
		fileTemp.WriteLine("				}");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"CTerrorPlayer::ModifyOrAppendCriteria\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"signature\"			\"CTerrorPlayer::ModifyOrAppendCriteria\"");
		fileTemp.WriteLine("				\"callconv\"			\"thiscall\"");
		fileTemp.WriteLine("				\"return\"			\"int\"");
		fileTemp.WriteLine("				\"this\"				\"entity\"");
		fileTemp.WriteLine("				\"arguments\"");
		fileTemp.WriteLine("				{");
		fileTemp.WriteLine("					\"a1\"");
		fileTemp.WriteLine("					{");
		fileTemp.WriteLine("						\"type\"		\"int\"");
		fileTemp.WriteLine("					}");
		fileTemp.WriteLine("				}");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("		}");
		fileTemp.WriteLine("		");
		fileTemp.WriteLine("		\"Signatures\"");
		fileTemp.WriteLine("		{");
		fileTemp.WriteLine("			\"UTIL_PlayerByIndex\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"linux\"		\"@_Z18UTIL_PlayerByIndexi\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"AI_CriteriaSet::AppendCriteria\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"linux\"		\"@_ZN14AI_CriteriaSet14AppendCriteriaEPKcS1_f\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"CTerrorPlayer::ModifyOrAppendCriteria\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"linux\"		\"@_ZN13CTerrorPlayer22ModifyOrAppendCriteriaER14AI_CriteriaSet\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("		}");
		fileTemp.WriteLine("	}");
		fileTemp.WriteLine("	\"left4dead\"");
		fileTemp.WriteLine("	{");
		fileTemp.WriteLine("		\"Functions\"");
		fileTemp.WriteLine("		{");
		fileTemp.WriteLine("			\"ForEachSurvivor<SurvivorAliveCritFunctor>\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"signature\"			\"ForEachSurvivor<SurvivorAliveCritFunctor>\"");
		fileTemp.WriteLine("				\"callconv\"			\"cdecl\"");
		fileTemp.WriteLine("				\"return\"			\"bool\"");
		fileTemp.WriteLine("				\"arguments\"");
		fileTemp.WriteLine("				{");
		fileTemp.WriteLine("					\"a1\"");
		fileTemp.WriteLine("					{");
		fileTemp.WriteLine("						\"type\"		\"int\"");
		fileTemp.WriteLine("					}");
		fileTemp.WriteLine("				}");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("		}");
		fileTemp.WriteLine("		");
		fileTemp.WriteLine("		\"Signatures\"");
		fileTemp.WriteLine("		{");
		fileTemp.WriteLine("			\"UTIL_PlayerByIndex\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"windows\"	\"\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x85\\x2A\\x7E\\x2A\\x8B\\x2A\\x2A\\x2A\\x2A\\x2A\\x3B\\x2A\\x2A\\x7F\\x2A\\x3D\"");
		fileTemp.WriteLine("				/* ? ? ? ? ? ? ? 85 ? 7E ? 8B ? ? ? ? ? 3B ? ? 7F ? 3D */");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"AI_CriteriaSet::AppendCriteria\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"windows\"	\"\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x50\\x8D\\x2A\\x2A\\x2A\\x51\\xB9\\x2A\\x2A\\x2A\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\xD9\\x2A\\x2A\\x2A\\x8B\"");
		fileTemp.WriteLine("				/* ? ? ? ? ? ? ? 50 8D ? ? ? 51 B9 ? ? ? ? E8 ? ? ? ? D9 ? ? ? 8B */");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"ForEachSurvivor<SurvivorAliveCritFunctor>\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"linux\"		\"@_Z15ForEachSurvivorIN12_GLOBAL__N_124SurvivorAliveCritFunctorEEbRT__constprop_79\"");
		fileTemp.WriteLine("				\"windows\"	\"\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x53\\x56\\x57\\xBF\\x2A\\x2A\\x2A\\x2A\\x39\\x2A\\x2A\\x7C\\x2A\\x8B\\x2A\\x2A\\x2A\\x57\\xE8\\x2A\\x2A\\x2A\\x2A\\x8B\\x2A\\x83\\x2A\\x2A\\x85\\x2A\\x74\\x2A\\x8B\\x2A\\x2A\\x85\\x2A\\x74\\x2A\\x8B\\x2A\\x2A\\x2A\\x2A\\x2A\\x2B\\x2A\\x2A\\xC1\\x2A\\x2A\\x74\\x2A\\x8B\\x2A\\x8B\\x2A\\x2A\\x2A\\x2A\\x2A\\x8B\\x2A\\xFF\\x2A\\x84\\x2A\\x74\\x2A\\x83\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x74\\x2A\\x8B\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\x83\\x2A\\x2A\\x75\\x2A\\x56\\x8B\\x2A\\xE8\\x18\\xFD\"");
		fileTemp.WriteLine("				/* ? ? ? ? ? ? 53 56 57 BF ? ? ? ? 39 ? ? 7C ? 8B ? ? ? 57 E8 ? ? ? ? 8B ? 83 ? ? 85 ? 74 ? 8B ? ? 85 ? 74 ? 8B ? ? ? ? ? 2B ? ? C1 ? ? 74 ? 8B ? 8B ? ? ? ? ? 8B ? FF ? 84 ? 74 ? 83 ? ? ? ? ? ? 74 ? 8B ? E8 ? ? ? ? 83 ? ? 75 ? 56 8B ? E8 18 FD */");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"CTerrorPlayer::ModifyOrAppendCriteria\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"windows\"	\"\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x55\\x56\\x57\\xBE\\x2A\\x2A\\x2A\\x2A\\x33\"");
		fileTemp.WriteLine("				/* ? ? ? ? ? ? 55 56 57 BE ? ? ? ? 33 */");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("		}");
		fileTemp.WriteLine("	}");
		fileTemp.WriteLine("	\"left4dead2\"");
		fileTemp.WriteLine("	{");
		fileTemp.WriteLine("		\"Addresses\"");
		fileTemp.WriteLine("		{");
		fileTemp.WriteLine("			\"ModifyOrAppendGlobalCriteria\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"signature\"		\"ModifyOrAppendGlobalCriteria\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"ForEachSurvivorSACF\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"windows\"");
		fileTemp.WriteLine("				{");
		fileTemp.WriteLine("					\"signature\"	\"ForEachSurvivor<SurvivorAliveCritFunctor>\"");
		fileTemp.WriteLine("				}");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"ModifyOrAppendGlobalCriteriaInternal\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"windows\"");
		fileTemp.WriteLine("				{");
		fileTemp.WriteLine("					\"signature\"	\"ModifyOrAppendGlobalCriteriaInternal\"");
		fileTemp.WriteLine("				}");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"ModifyOrAppendCriteria_CTP\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"signature\"		\"CTerrorPlayer::ModifyOrAppendCriteria\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("		}");
		fileTemp.WriteLine("		");
		fileTemp.WriteLine("		\"Functions\"");
		fileTemp.WriteLine("		{");
		fileTemp.WriteLine("			\"ModifyOrAppendGlobalCriteria\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"windows\"");
		fileTemp.WriteLine("				{");
		fileTemp.WriteLine("					\"signature\"		\"ForEachSurvivor<SurvivorAliveCritFunctor>\"");
		fileTemp.WriteLine("					\"return\"		\"bool\"");
		fileTemp.WriteLine("				}");
		fileTemp.WriteLine("				\"linux\"");
		fileTemp.WriteLine("				{");
		fileTemp.WriteLine("					\"signature\"		\"ModifyOrAppendGlobalCriteria\"");
		fileTemp.WriteLine("					\"return\"		\"int\"");
		fileTemp.WriteLine("				}");
		fileTemp.WriteLine("				\"callconv\"			\"cdecl\"");
		fileTemp.WriteLine("				\"arguments\"");
		fileTemp.WriteLine("				{");
		fileTemp.WriteLine("					\"a1\"");
		fileTemp.WriteLine("					{");
		fileTemp.WriteLine("						\"type\"		\"int\"");
		fileTemp.WriteLine("					}");
		fileTemp.WriteLine("				}");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"SurvivorResponseCachedInfo::GetClosestSurvivorTo\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"signature\"			\"SurvivorResponseCachedInfo::GetClosestSurvivorTo\"");
		fileTemp.WriteLine("				\"callconv\"			\"thiscall\"");
		fileTemp.WriteLine("				\"return\"			\"int\"");
		fileTemp.WriteLine("				\"arguments\"");
		fileTemp.WriteLine("				{");
		fileTemp.WriteLine("					\"a1\"");
		fileTemp.WriteLine("					{");
		fileTemp.WriteLine("						\"type\"		\"int\"");
		fileTemp.WriteLine("					}");
		fileTemp.WriteLine("				}");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("		}");
		fileTemp.WriteLine("		");
		fileTemp.WriteLine("		\"Offsets\"");
		fileTemp.WriteLine("		{");
		fileTemp.WriteLine("			\"ModifyOrAppendGlobalCriteria_TeamNumberCondition\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"linux\"		\"274\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"ModifyOrAppendGlobalCriteria_CharacterCondition\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"linux\"		\"986\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"ForEachSurvivorSACF_TeamNumberCondition\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"windows\"	\"96\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"ModifyOrAppendGlobalCriteriaInternal_CharacterCondition\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"windows\"	\"18\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"CTPModifyOrAppendCriteria_TeamNumberCall\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"windows\"	\"2281\"");
		fileTemp.WriteLine("				\"linux\"		\"3517\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"CTPModifyOrAppendCriteria_SurvivorSetCall\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"windows\"	\"2839\"");
		fileTemp.WriteLine("				\"linux\"		\"5844\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("		}");
		fileTemp.WriteLine("		");
		fileTemp.WriteLine("		\"Signatures\"");
		fileTemp.WriteLine("		{");
		fileTemp.WriteLine("			\"ModifyOrAppendGlobalCriteria\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"linux\"		\"@_ZL28ModifyOrAppendGlobalCriteriaP14AI_CriteriaSet\"");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"ForEachSurvivor<SurvivorAliveCritFunctor>\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"windows\"	\"\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x53\\x56\\x57\\xBF\\x2A\\x2A\\x2A\\x2A\\x39\\x2A\\x2A\\x7C\\x2A\\x8B\\x2A\\x2A\\x57\\xE8\\x2A\\x2A\\x2A\\x2A\\x8B\\x2A\\x83\\x2A\\x2A\\x85\\x2A\\x74\\x2A\\x8B\\x2A\\x2A\\x85\\x2A\\x74\\x2A\\x8B\\x2A\\x2A\\x2A\\x2A\\x2A\\x2B\\x2A\\x2A\\xC1\\x2A\\x2A\\x85\\x2A\\x74\\x2A\\x8B\\x2A\\x8B\\x2A\\x2A\\x2A\\x2A\\x2A\\x8B\\x2A\\xFF\\x2A\\x84\\x2A\\x74\\x2A\\x83\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x74\\x2A\\x8B\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\x83\\x2A\\x2A\\x2A\\x2A\\x56\\x8B\\x2A\\xE8\\x05\\xFB\"");
		fileTemp.WriteLine("				/* ? ? ? ? ? ? ? ? 53 56 57 BF ? ? ? ? 39 ? ? 7C ? 8B ? ? 57 E8 ? ? ? ? 8B ? 83 ? ? 85 ? 74 ? 8B ? ? 85 ? 74 ? 8B ? ? ? ? ? 2B ? ? C1 ? ? 85 ? 74 ? 8B ? 8B ? ? ? ? ? 8B ? FF ? 84 ? 74 ? 83 ? ? ? ? ? ? 74 ? 8B ? E8 ? ? ? ? 83 ? ? ? ? 56 8B ? E8 05 FB */");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"ModifyOrAppendGlobalCriteriaInternal\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"windows\"	\"\\x55\\x8B\\x2A\\x56\\x57\\x8B\\x2A\\x8B\\x2A\\x2A\\x8B\\x2A\\x2A\\x2A\\x2A\\x2A\\x83\"");
		fileTemp.WriteLine("				/* 55 8B ? 56 57 8B ? 8B ? ? 8B ? ? ? ? ? 83 */");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"CTerrorPlayer::ModifyOrAppendCriteria\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"windows\"	\"\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x83\\x2A\\x2A\\x83\\x2A\\x2A\\x55\\x8B\\x2A\\x2A\\x89\\x2A\\x2A\\x2A\\x8B\\x2A\\x81\\x2A\\x2A\\x2A\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x56\\x8B\\x2A\\x2A\\x33\"");
		fileTemp.WriteLine("				/* ? ? ? ? ? ? 83 ? ? 83 ? ? 55 8B ? ? 89 ? ? ? 8B ? 81 ? ? ? ? ? A1 ? ? ? ? 33 ? 89 ? ? 56 8B ? ? 33 */");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"UTIL_PlayerByIndex\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"windows\"	\"\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x57\\x33\\x2A\\x85\\x2A\\x7E\\x2A\\x8B\\x2A\\x2A\\x2A\\x2A\\x2A\\x3B\"");
		fileTemp.WriteLine("				/* ? ? ? ? ? ? 57 33 ? 85 ? 7E ? 8B ? ? ? ? ? 3B */");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"AI_CriteriaSet::AppendCriteria\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"windows\"	\"\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x56\\x8B\\x2A\\x50\\x8D\\x2A\\x2A\\x51\\xB9\"");
		fileTemp.WriteLine("				/* ? ? ? ? ? ? 56 8B ? 50 8D ? ? 51 B9 */");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("			\"SurvivorResponseCachedInfo::GetClosestSurvivorTo\"");
		fileTemp.WriteLine("			{");
		fileTemp.WriteLine("				\"library\"	\"server\"");
		fileTemp.WriteLine("				\"linux\"		\"@_ZN26SurvivorResponseCachedInfo20GetClosestSurvivorToE21SurvivorCharacterType\"");
		fileTemp.WriteLine("				\"windows\"	\"\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x8B\\x2A\\xC1\\x2A\\x2A\\x03\\x2A\\x57\\xB9\"");
		fileTemp.WriteLine("				/* ? ? ? ? ? ? ? ? 8B ? C1 ? ? 03 ? 57 B9 */");
		fileTemp.WriteLine("			}");
		fileTemp.WriteLine("		}");
		fileTemp.WriteLine("	}");
		fileTemp.WriteLine("}");
		
		fileTemp.Close();
	}
	return new GameData(file);
}

MRESReturn HandleActorIndexes()
{
	bCriteriaFix = true;
	return MRES_Ignored;
}

MRESReturn HandleResponseActors(int client)
{
	iActor = client;
	return MRES_Ignored;
}

int GetNearestAliveSurvivor(int client, char sDist[16] = "", int character = -1, bool aliveOnly = false)
{
	int iRetVal, iTeam;
	float fPos[2][3], fDist, fMinDist = 1000000000.0;
	
	GetClientAbsOrigin(client, fPos[0]);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || i == client)
		{
			continue;
		}
		
		iTeam = GetClientTeam(i);
		if (iTeam == 2 || iTeam == 4)
		{
			if (!IsPlayerAlive(i) || (character != -1 && GetEntProp(i, Prop_Send, "m_survivorCharacter") != character))
			{
				continue;
			}
			
			GetClientAbsOrigin(i, fPos[1]);
			
			fDist = GetVectorDistance(fPos[0], fPos[1]);
			if (fMinDist == 1000000000.0 || fDist < fMinDist)
			{
				fMinDist = fDist;
				
				iRetVal = i;
			}
		}
	}
	if (iRetVal == 0 && (!aliveOnly || IsPlayerAlive(client)) && (character == -1 || GetEntProp(client, Prop_Send, "m_survivorCharacter") == character))
	{
		iRetVal = client;
	}
	
	FormatEx(sDist, sizeof(sDist), "%.1f", fMinDist);
	return iRetVal;
}

int GetCharacterByLetter(char c)
{
	int iRetVal = -1;
	
	switch (c)
	{
		case 'b': iRetVal = 0;
		case 'd': iRetVal = 1;
		case 'c': iRetVal = 2;
		case 'h': iRetVal = 3;
		case 'V': iRetVal = 4;
		case 'n': iRetVal = 5;
		case 'e': iRetVal = 6;
		case 'a': iRetVal = 7;
	}
	
	return (ev_RetVal == Engine_Left4Dead && iRetVal != -1) ? ((iRetVal - 4 < 0) ? 4 : iRetVal - 4) : iRetVal;
}

