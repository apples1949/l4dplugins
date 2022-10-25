/*=======================================================================================
	Credits:
	 - Dragokas - for his idea and post,  https://forums.alliedmods.net/showthread.php?t=316656 .
	
=======================================================================================*/

#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

static const char g_sTableNames[][] =
{
	"downloadables",
	"modelprecache",
	"genericprecache",
	"soundprecache",
	"decalprecache",
	"instancebaseline",
	"lightstyles",
	"userinfo",
	"server_query_info",
	"ParticleEffectNames",
	"EffectDispatch",
	"VguiScreen",
	"Materials",
	"InfoPanel",
	"Scenes",
	"MeleeWeapons",
	"GameRulesCreation",
	"BlackMarketTable"
};

Handle sdkTableDeleteAllStrings, sdkFindTable, sdkDirectory, sdkRemoveAll;
char g_szItems[8192][PLATFORM_MAX_PATH];
int g_iItemsTotal, g_iPointer;

public Plugin myinfo =
{
	name = "[L4D2] Stringtable control",
	author = "BHaType",
	description = "Allows you to manage stringtables",
	version = "0.0.4",
	url = "N/A"
}

public int GetPointer_NAT(Handle plugin, int numParams)
{
	SDKGetPointer();
	return g_iPointer;
}

public int ResetStringTable_NAT(Handle plugin, int numParams)
{
	if(numParams < 1)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid num params");
		
	int index = GetNativeCell(1);
	
	if(index < 0 || index > 17)
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid index %i", index);
		return false;
	}
	
	int iPtrNetworkStringTable = SDKCall(sdkFindTable, g_iPointer, g_sTableNames[index]);
	if(iPtrNetworkStringTable == 0)
	{
		ThrowNativeError(SP_ERROR_ABORTED, "Couldn't call FindTable");
		return false;
	}

	bool bState = LockStringTables(false);
	SDKCall(sdkTableDeleteAllStrings, iPtrNetworkStringTable);
	LockStringTables(bState);

	return true;
}


public int GetNameStringTable_NAT(Handle plugin, int numParams)
{
	if(numParams != 3)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid num params");
		
	int index = GetNativeCell(1);
	
	if(index < 0 || index > 17)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid index %i", index);
	
	int size = GetNativeCell(3);
	
	if(size <= 0)
		ThrowNativeError(SP_ERROR_PARAM, "Null string size (%i)", size);
		
	SetNativeString(2, g_sTableNames[index], size, false);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion engine = GetEngineVersion();
	if (engine != Engine_Left4Dead2 && engine != Engine_Left4Dead)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead & Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	
	CreateNative("StringtableGetPointer", GetPointer_NAT);
	CreateNative("StringtableReset", ResetStringTable_NAT);
	CreateNative("StringtableGetNameByIndex", GetNameStringTable_NAT);
	
	return APLRes_Success;
}


public void OnMapStart()
{
	CreateTimer(1.0, Timer_SaveDownloadables, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_SaveDownloadables(Handle timer)
{
	SaveDownloadables();
}

public void OnPluginStart()
{
	Handle hGameConf = LoadGameConfigFile("l4d2_stringtable_control");
	if( hGameConf == null )
		SetFailState("Couldn't find the offsets and signatures file. Please, check that it is installed correctly.");
	StartPrepSDKCall(SDKCall_Raw);
	if( PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CNetworkStringTable::DeleteAllStrings") == false )
		SetFailState("Could not load the \"CNetworkStringTable::DeleteAllStrings\" gamedata signature.");
	
	sdkTableDeleteAllStrings = EndPrepSDKCall();
	if( sdkTableDeleteAllStrings == null )
		SetFailState("Could not prep the \"CNetworkStringTable::DeleteAllStrings\" function.");
	
	Handle hDetour2 = DHookCreateFromConf(hGameConf, "SV_CreateDictionary");
	if( !DHookEnableDetour(hDetour2, true, detour) ) SetFailState("Failed to detour.");	

	StartPrepSDKCall(SDKCall_Raw);
	if( PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CNetworkStringTable::FindTable") == false )
		SetFailState("Could not load the \"CNetworkStringTable::FindTable\" gamedata signature.");

	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	sdkFindTable = EndPrepSDKCall();
	if( sdkFindTable == null )
		SetFailState("Could not prep the \"CNetworkStringTable::FindTable\" function.");
	
	StartPrepSDKCall(SDKCall_Static);
	if( PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "SV_CreateDictionary") == false )
		SetFailState("Could not load the \"SV_CreateDictionary\" gamedata signature.");
	sdkDirectory = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Raw);
	if( PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "RemoveTables") == false )
		SetFailState("Could not load the \"RemoveTables\" gamedata signature.");
	sdkRemoveAll = EndPrepSDKCall();
	
	delete hGameConf;

	RegAdminCmd("sm_get_pointer",			Cmd_GetPointer, 			ADMFLAG_ROOT, 	"Get pointer"															);
	RegAdminCmd("sm_dump_st",	 			Cmd_DumpStringtables, 		ADMFLAG_ROOT, 	"Dump the list of stringtables to console and ALL tables to log file. Set arg 1 - to dump user data as well"		);
	RegAdminCmd("sm_dump_sti",	 			Cmd_DumpStringtableItems, 	ADMFLAG_ROOT, 	"Dump the items of specified stringtable to console and log file"		);
	RegAdminCmd("sm_downloadables_restore",	Cmd_RestoreDownloadables, 	ADMFLAG_ROOT, 	"Restore downloadables stringtable items"								);
	RegAdminCmd("sm_downloadables_reset",	Cmd_DeleteStrings, 			ADMFLAG_ROOT, 	"Reset downloadables stringtable"										);
	RegAdminCmd("sm_delete_all",	 		Cmd_DeleteAll, 				ADMFLAG_ROOT, 	"Delete all stringtables"												);
	RegAdminCmd("sm_delete_all_strings",	Cmd_DeleteAllStrings, 		ADMFLAG_ROOT, 	"Delete all strings in all stringtables"								);
	
	SDKGetPointer();
}

public Action Cmd_DeleteAll(int client, int args)
{
	SDKCall(sdkRemoveAll, g_iPointer);
}

public Action Cmd_DeleteAllStrings(int client, int args)
{
	int iPtrNetworkStringTable;
	for(int i; i < sizeof g_sTableNames; i++)
	{
		iPtrNetworkStringTable = SDKCall(sdkFindTable, g_iPointer, g_sTableNames[i]);
		if(iPtrNetworkStringTable == 0)
		{
			ReplyToCommand(client, "Couldn't call FindTable.");
			return Plugin_Handled;
		}
			
		bool bState = LockStringTables(false);
		SDKCall(sdkTableDeleteAllStrings, iPtrNetworkStringTable);
		LockStringTables(bState);
		
		ReplyToCommand(client, "Delete all strings for %s is successfull.", g_sTableNames[i]);
	}
	return Plugin_Handled;
}

public Action Cmd_GetPointer(int client, int args)
{
	SDKGetPointer();
	ReplyToCommand(client, "Successfull. g_iPointer = %i.", g_iPointer);
	return Plugin_Handled;
}

public Action Cmd_DeleteStrings(int client, int args)
{
	int iPtrNetworkStringTable = SDKCall(sdkFindTable, g_iPointer, "downloadables");
	if(iPtrNetworkStringTable == 0)
	{
		ReplyToCommand(client, "Couldn't call FindTable.");
		return Plugin_Handled;
	}

	bool bState = LockStringTables(false);
	SDKCall(sdkTableDeleteAllStrings, iPtrNetworkStringTable);
	LockStringTables(bState);
	
	ReplyToCommand(client, "Delete all strings call for downloadables is successfull.");
	return Plugin_Handled;
}

public Action Cmd_RestoreDownloadables(int client, int args)
{
	if (g_iItemsTotal == 0) {
		ReplyToCommand(client, "Cannot restore. Downloadables string table is not saved.");
		return Plugin_Handled;
	}
	
	for (int i = 0; i < g_iItemsTotal; i++)
	{
		if (strlen(g_szItems[i]))
			AddFileToDownloadsTable(g_szItems[i]);
	}
	ReplyToCommand(client, "All data has been restored");
	return Plugin_Handled;
}

public Action Cmd_DumpStringtableItems(int client, int args)
{
	if (args == 0) {
		ReplyToCommand(client, "Using: sm_dump_sti <string table name>");
		return Plugin_Handled;
	}
	
	char sStName[64];
	GetCmdArgString(sStName, sizeof(sStName));
	DumpTable(client, sStName);
	
	return Plugin_Handled;
}

public Action Cmd_DumpStringtables(int client, int args)
{
	char sArg[4];
	int iDumpUserData = 0;
	if (args > 0) {
		GetCmdArgString(sArg, sizeof(sArg));
		iDumpUserData = StringToInt(sArg);
	}
	
	char sLogPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sLogPath, sizeof(sLogPath), "logs/StringTables.log");

	File hFile = OpenFile(sLogPath, "w");
	if( hFile == null )
	{
		ReplyToCommand(client, "Cannot open file for write access: %s", sLogPath);
	}
	else {
		hFile.WriteLine("String table list:");
		ReplyToCommand(client, "String table list is saved to: %s", sLogPath);
	}
	
	int iNum = GetNumStringTables();
	ReplyToCommand(client, "Listing %d stringtables:", iNum);
	char sName[64], sLine[128];
	for (int i = 0; i < iNum; i++)
	{
		GetStringTableName(i, sName, sizeof(sName));
		Format(sLine, sizeof(sLine), "%d. %s (%d/%d strings)", i, sName, GetStringTableNumStrings(i), GetStringTableMaxStrings(i));
		ReplyToCommand(client, sLine);
		hFile.WriteLine(sLine);
	}
	for (int i = 0; i < iNum; i++)
	{
		GetStringTableName(i, sName, sizeof(sName));
		DumpTable(client, sName, view_as<bool>(iDumpUserData), false);
	}
	FlushFile(hFile);
	hFile.Close();
	return Plugin_Handled;
}

bool DumpTable(int client, char[] sStName, bool bShowUserData = false, bool bShowCon = true)
{
	int iTable = FindStringTable(sStName);
	if(iTable == INVALID_STRING_TABLE)
	{
		ReplyToCommand(client, "Couldn't find %s stringtable.", sStName);
		return false;
	}
	
	char sLogPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sLogPath, sizeof(sLogPath), "logs/StringTable_%s.log", sStName);
	
	File hFile = OpenFile(sLogPath, "w");
	if( hFile == null )
	{
		ReplyToCommand(client, "Cannot open file for write access: %s", sLogPath);
		return false;
	}
	else
		hFile.WriteLine("Contents of string table \"%s\":", sStName);
	
	int iNum = GetStringTableNumStrings(iTable);
	char sName[PLATFORM_MAX_PATH];
	
	int iNumBytes;
	char sUserData[PLATFORM_MAX_PATH];
	
	for (int i = 0; i < iNum; i++)
	{
		ReadStringTable(iTable, i, sName, sizeof(sName));
		if (bShowUserData) {
			iNumBytes = GetStringTableData(iTable, i, sUserData, sizeof(sUserData));
			if (iNumBytes == 0)
				sUserData[0] = '\0';
			if (bShowCon)
				ReplyToCommand(client, "%d. %s (%s)", i, sName, sUserData);
			if (hFile != null)
				hFile.WriteLine("%s (%s)", sName, sUserData);
		}
		else {
			if (bShowCon)
				ReplyToCommand(client, "%d. %s", i, sName);
			if (hFile != null)
				hFile.WriteLine(sName);
		}
	}
	
	if (hFile != null) {
		FlushFile(hFile);
		hFile.Close();
		ReplyToCommand(client, "Dump is saved to: %s", sLogPath);
	}
	return true;
}

void SDKGetPointer()
{
	SDKCall(sdkDirectory);
}

void SaveDownloadables()
{
	int iTable = FindStringTable("downloadables");
	if(iTable == INVALID_STRING_TABLE) {
		LogError("Cannot find 'downloadables' string table!");
		return;
	}
	
	g_iItemsTotal = 0;
	int iNum = GetStringTableNumStrings(iTable);

	for (int i = 0; i < iNum; i++)
	{
		ReadStringTable(iTable, i, g_szItems[g_iItemsTotal], sizeof(g_szItems[]));
		g_iItemsTotal++;
	}
}

public MRESReturn detour(Handle hReturn, Handle hParams)
{
	g_iPointer = DHookGetReturn(hReturn);
	return MRES_Ignored;
}