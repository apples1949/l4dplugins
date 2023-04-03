#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <l4d2_skills>

public Plugin myinfo =
{
	name = "[L4D2] Skills Config",
	author = "BHaType",
	description = "Provides natives for exporting data from config",
	version = "1.1",
	url = "https://github.com/Vinillia/l4d2_skills"
};

KeyValues g_hSettings;
GlobalForward g_hFwdOnGetSettings;
bool g_bLateload;

public any NAT_Skills_ExportIntByName(Handle plugin, int numparams)
{
	char name[MAX_SKILL_NAME_LENGTH], key[128];
	int value, defValue = GetNativeCell(4);
	bool createKey = GetNativeCell(5);
	
	GetNativeString(1, name, sizeof name);
	GetNativeString(2, key, sizeof key);
	SetNativeCellRef(3, defValue);
	
	g_hSettings.Rewind();
	
	if ( !g_hSettings.JumpToKey(name) ) 
		return false;

	if ( !g_hSettings.JumpToKey(key))
	{
		if (!createKey)
			return false;

		g_hSettings.SetNum(key, defValue);
		KeyValueExportToFile(g_hSettings);
		return true;
	}
	
	value = g_hSettings.GetNum(NULL_STRING, defValue);
	SetNativeCellRef(3, value);
	g_hSettings.Rewind();
	return true;
}

public any NAT_Skills_ExportFloatByName(Handle plugin, int numparams)
{
	char name[MAX_SKILL_NAME_LENGTH], key[128];
	float value, defValue = GetNativeCell(4);
	bool createKey = GetNativeCell(5);

	GetNativeString(1, name, sizeof name);
	GetNativeString(2, key, sizeof key);
	SetNativeCellRef(3, defValue);
	
	g_hSettings.Rewind();

	if ( !g_hSettings.JumpToKey(name) ) 
		return false;

	if ( !g_hSettings.JumpToKey(key))
	{
		if (!createKey)
			return false;

		g_hSettings.SetFloat(key, defValue);
		KeyValueExportToFile(g_hSettings);
		return true;
	}

	value = g_hSettings.GetFloat(NULL_STRING, defValue);
	SetNativeCellRef(3, value);
	g_hSettings.Rewind();
	return true;
}

public any NAT_Skills_ExportStringByName(Handle plugin, int numparams)
{
	char name[MAX_SKILL_NAME_LENGTH], key[128], defValue[128];
	bool createKey = GetNativeCell(6);
	
	int length = GetNativeCell(4);
	char[] value = new char[length];

	GetNativeString(1, name, sizeof name);
	GetNativeString(2, key, sizeof key);
	GetNativeString(5, defValue, sizeof defValue);
	SetNativeString(3, defValue, sizeof defValue);
	
	g_hSettings.Rewind();
	
	if ( !g_hSettings.JumpToKey(name) ) 
		return false;

	if ( !g_hSettings.JumpToKey(key))
	{
		if (!createKey)
			return false;

		g_hSettings.SetString(key, defValue);
		KeyValueExportToFile(g_hSettings);
		return true;
	}

	g_hSettings.GetString(NULL_STRING, value, length, defValue);
	SetNativeString(3, value, length);
	g_hSettings.Rewind();
	return true;
}

public any NAT_Skills_ExportVectorByName(Handle plugin, int numparams)
{
	char name[MAX_SKILL_NAME_LENGTH], key[128];
	float value[3], defValue[3];
	bool createKey = GetNativeCell(5);
	
	GetNativeString(1, name, sizeof name);
	GetNativeString(2, key, sizeof key);
	GetNativeArray(4, defValue, sizeof defValue);
	SetNativeArray(3, defValue, sizeof defValue);

	g_hSettings.Rewind();
	
	if ( !g_hSettings.JumpToKey(name) ) 
		return false;

	if ( !g_hSettings.JumpToKey(key))
	{
		if (!createKey)
			return false;

		g_hSettings.SetVector(key, defValue);
		KeyValueExportToFile(g_hSettings);
		return true;
	}
	
	g_hSettings.GetVector(NULL_STRING, value, defValue);
	SetNativeArray(3, value, sizeof value);
	g_hSettings.Rewind();
	return true;
}

public any NAT_Skills_RequestConfigReload(Handle plugin, int numparams)
{
	if ( GetNativeCell(1) )
		GetSkillSettings();
		
	Function f = GetFunctionByName(plugin, "Skills_OnGetSettings");
	
	if ( f == INVALID_FUNCTION )
		return ThrowNativeError(0x00, "Requested config reload but Skills_OnGetSettings function not found");
	
	Call_StartFunction(plugin, f);
	Call_PushCell(g_hSettings);
	Call_Finish();
	
	return 0;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errormax) 
{
	g_bLateload = late;
	
	CreateNative("Skills_ExportIntByName", NAT_Skills_ExportIntByName);
	CreateNative("Skills_ExportFloatByName", NAT_Skills_ExportFloatByName);
	CreateNative("Skills_ExportStringByName", NAT_Skills_ExportStringByName);
	CreateNative("Skills_ExportVectorByName", NAT_Skills_ExportVectorByName);
	CreateNative("Skills_RequestConfigReload", NAT_Skills_RequestConfigReload);
	
	g_hFwdOnGetSettings = new GlobalForward("Skills_OnGetSettings", ET_Ignore, Param_Cell);
	return APLRes_Success;
}
	
public void OnPluginStart()
{
	GetSkillSettings();
	
	RegAdminCmd("sm_skills_config_reload", sm_skills_config_reload, ADMFLAG_RCON);
	RegAdminCmd("sm_skills_config_reload_hard", sm_skills_config_reload_hard, ADMFLAG_RCON);
}

public void OnAllPluginsLoaded()
{
	if ( g_bLateload )
		NotifySkillSettings();
}

public void Skills_OnRegistered( const char[] name, SkillType type )
{
	Handle owner = Skills_GetOwner(name);
	Function f = GetFunctionByName(owner, "Skills_OnGetSettings");
	
	if ( f == INVALID_FUNCTION )
		return;
	
	GetSkillSettings();
	
	Call_StartFunction(owner, f);
	Call_PushCell(g_hSettings);
	Call_Finish();
}

public Action sm_skills_config_reload( int client, int args )
{
	NotifySkillSettings();
	//Skills_ReplyToCommand(client, "Reloaded configuration");
	Skills_ReplyToCommand(client, "重新加载配置");
	return Plugin_Handled;
}

public Action sm_skills_config_reload_hard( int client, int args )
{
	if (g_hSettings)
		delete g_hSettings;
	
	GetSkillSettings();
	NotifySkillSettings();
	//Skills_ReplyToCommand(client, "Hard reloaded configuration");
	Skills_ReplyToCommand(client, "硬性重新加载配置");
	return Plugin_Handled;
}

void GetSkillSettings()
{
	if (g_hSettings)
		return;
	/*
	if ( g_hSettings != null )
		delete g_hSettings;
	*/

	g_hSettings = new KeyValues("SkillsSettings");
	g_hSettings.SetEscapeSequences(true);

	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof szPath, SKILLS_CONFIG);
	
	if ( !FileExists(szPath) || !g_hSettings.ImportFromFile(szPath) )
		LOG("Skills config file doesn't exist!");
}

void NotifySkillSettings()
{
	Call_StartForward(g_hFwdOnGetSettings);
	Call_PushCell(g_hSettings);
	Call_Finish();
}
