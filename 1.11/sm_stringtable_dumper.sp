#define PLUGIN_VERSION 		"1.1"

/*=======================================================================================
	Change Log:

1.1 (02-Apr-2020)
	- Fixed armument quotation (thanks to Bacardi).

1.0 (01-Feb-2019)
	- Initial release.

=======================================================================================

	Credits:
	 - Dr. Api - for sm string table examples.
	
=======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name = "[DEV] String Tables Dumper",
	author = "Alex Dragokas",
	description = "Dumps records of all string tables. For developers.",
	version = PLUGIN_VERSION,
	url = "https://github.com/dragokas/"
}

public void OnPluginStart()
{
	CreateConVar("sm_dump_st_version",	PLUGIN_VERSION,	"String Tables Dumper plugin version.",	FCVAR_NOTIFY | FCVAR_DONTRECORD);

	RegAdminCmd("sm_dump_st", 		Cmd_DumpStringtables, 		ADMFLAG_ROOT, 	"<Num> (optional). Dumps ALL stringtables to log files. Show list of stringtables to console. Set num to 1 - to dump user data as well");
	RegAdminCmd("sm_dump_sti",	 	Cmd_DumpStringtableItems, 	ADMFLAG_ROOT, 	"<table_name>. Show contents of this table to console and dumps it in log file.");
}

public Action Cmd_DumpStringtables(int client, int args)
{
	char sArg[4];
	int iDumpUserData = 0;
	if( args > 0 )
	{
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
	for( int i = 0; i < iNum; i++ )
	{
		GetStringTableName(i, sName, sizeof(sName));
		Format(sLine, sizeof(sLine), "%d. %s (%d/%d strings)", i, sName, GetStringTableNumStrings(i), GetStringTableMaxStrings(i));
		ReplyToCommand(client, sLine);
		hFile.WriteLine(sLine);
	}
	for( int i = 0; i < iNum; i++ )
	{
		GetStringTableName(i, sName, sizeof(sName));
		DumpTable(client, sName, view_as<bool>(iDumpUserData), false);
	}
	hFile.Close();
	return Plugin_Handled;
}

public Action Cmd_DumpStringtableItems(int client, int args)
{
	if( args == 0 )
	{
		ReplyToCommand(client, "Using: sm_dump_sti <string table name>");
		return Plugin_Handled;
	}
	
	char sStName[64];
	GetCmdArg(1, sStName, sizeof sStName);
	DumpTable(client, sStName, false, true);
	
	return Plugin_Handled;
}

bool DumpTable(int client, char[] sStName, bool bShowUserData, bool bShowCon)
{
	int iTable = FindStringTable(sStName);
	if( iTable == INVALID_STRING_TABLE )
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
	else {
		hFile.WriteLine("Contents of string table \"%s\":", sStName);
	}
	
	int iNum = GetStringTableNumStrings(iTable);
	char sName[PLATFORM_MAX_PATH];
	
	int iNumBytes;
	char sUserData[PLATFORM_MAX_PATH];
	
	for( int i = 0; i < iNum; i++ )
	{
		ReadStringTable(iTable, i, sName, sizeof(sName));
		if( bShowUserData )
		{
			iNumBytes = GetStringTableData(iTable, i, sUserData, sizeof(sUserData));
			if( iNumBytes == 0 )
			{
				sUserData[0] = '\0';
			}
			if( bShowCon )
			{
				ReplyToCommand(client, "%d. %s (%s)", i, sName, sUserData);
			}
			if( hFile != null )
			{
				hFile.WriteLine("%s (%s)", sName, sUserData);
			}
		}
		else {
			if( bShowCon )
			{
				ReplyToCommand(client, "%d. %s", i, sName);
			}
			if( hFile != null )
			{
				hFile.WriteLine(sName);
			}
		}
	}
	
	if( hFile != null )
	{
		hFile.Close();
		ReplyToCommand(client, "Dump is saved to: %s", sLogPath);
	}
	return true;
}