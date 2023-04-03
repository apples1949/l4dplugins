#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <l4d2_skills>

public Plugin myinfo =
{
	name = "[L4D2] Skills Core",
	author = "BHaType",
	description = "Main module of skills",
	version = "1.1",
	url = "https://github.com/Vinillia/l4d2_skills"
};

enum
{
	err_kName = 0x001,
	err_kID = 0x002
};

enum struct SkillInfo
{
	Handle owner;
	SkillType type;
	bool upgradable;
}

enum struct Skills
{
	int count;
	
	StringMap skillMap;
	StringMap skillInfo;
	
	void Init()
	{
		this.skillMap = new StringMap();
		this.skillInfo = new StringMap();
	}
	
	void Reset()
	{
		this.count = 0;
		delete this.skillMap;
		delete this.skillInfo;
	}

	bool GetName( int id, char[] name, int maxlength = MAX_SKILL_NAME_LENGTH )
	{
		char szSkill[MAX_SKILL_NAME_LENGTH];
		IntToString(id, szSkill, 4);
		
		if ( !this.skillMap.GetString(szSkill, szSkill, maxlength) )
			return false;
			
		strcopy(name, maxlength, szSkill);
		return true;
	}
		
	bool GetContainsName( int &id, const char[] name, bool caseSensetive = true )
	{
		if ( !this.count )
			return false;
		
		char skill[MAX_SKILL_NAME_LENGTH];
		
		for( int i = this.count; i >= 0; i-- )
		{
			this.GetName(i, skill);
			
			if ( StrContains(skill, name, caseSensetive) != -1 )
			{
				id = i;
				return true;
			}
		}
		
		return false;
	}
	
	int GetID( const char[] name )
	{
		int id;
		if ( !this.skillMap.GetValue(name, id) )
			return -1;
			
		return id;
	}
		
	bool GetInfo( const char[] name, SkillInfo out )
	{
		return this.skillInfo.GetArray(name, out, sizeof SkillInfo);
	}
	
	bool FillInfo( const char[] name, Handle _owner, SkillType _type, bool _upgradable )
	{
		SkillInfo info;
		
		info.owner = _owner;
		info.type = _type;
		info.upgradable = _upgradable;

		return this.skillInfo.SetArray(name, info, sizeof SkillInfo);
	}
	
	int Register( const char[] name )
	{
		int id;
		char temp[4];
		
		id = this.count++;
		IntToString(id, temp, sizeof temp);

		this.skillMap.SetString(temp, name);
		this.skillMap.SetValue(name, id);
		
		NotifySkillRegistered(name, id);
		return id;
	}
}

enum struct Economy
{	
	float money;
	float multiplier;
	
	void AddMoney( float value ) { this.money += value; }
}

enum struct PlayerSkills
{
	int count;
	bool skill[MAX_SKILLS_COUNT];
}

enum struct PlayerInfo
{
	PlayerSkills skills;
	Economy economy;
}

GlobalForward g_hFwdOnRegistered, g_hFwdOnStateChanged, g_hFwdOnCoreStart, g_hFwdOnCoreLoaded, g_hFwdOnStateReset;

PlayerInfo g_PlayersInfo[MAXPLAYERS + 1];
Economy g_teamEconomy;
Skills g_Skills;

public any NAT_Skills_GetClientMoney(Handle plugin, int numparams)
{
	int client = GetNativeCell(1);
	return g_PlayersInfo[client].economy.money;
}

public any NAT_Skills_SetClientMoney(Handle plugin, int numparams)
{
	int client = GetNativeCell(1);
	g_PlayersInfo[client].economy.money = GetNativeCell(2);
	return 0;
}

public any NAT_Skills_GetClientMoneyMultiplier(Handle plugin, int numparams)
{
	int client = GetNativeCell(1);
	return g_PlayersInfo[client].economy.multiplier;
}

public any NAT_Skills_SetClientMoneyMultiplier(Handle plugin, int numparams)
{
	int client = GetNativeCell(1);
	g_PlayersInfo[client].economy.multiplier = GetNativeCell(2);
	return 0;
}

public any NAT_Skills_GetTeamMoney(Handle plugin, int numparams)
{
	return g_teamEconomy.money;
}

public any NAT_Skills_SetTeamMoney(Handle plugin, int numparams)
{
	g_teamEconomy.money = GetNativeCell(1);
	return 0;
}

public any NAT_Skills_GetTeamMoneyMultiplier(Handle plugin, int numparams)
{
	return g_teamEconomy.multiplier;
}

public any NAT_Skills_SetTeamMoneyMultiplier(Handle plugin, int numparams)
{
	g_teamEconomy.multiplier = GetNativeCell(2);
	return 0;
}

public any NAT_Skills_GetName(Handle plugin, int numparams)
{
	int id = GetNativeCell(1);
	int length = GetNativeCell(3);
	char name[MAX_SKILL_NAME_LENGTH];
	
	if ( !g_Skills.GetName(id, name) )
		return false;
		
	SetNativeString(2, name, length + 1);
	return true;
}

public any NAT_Skills_GetID(Handle plugin, int numparams)
{
	char name[MAX_SKILL_NAME_LENGTH];
	GetNativeString(1, name, sizeof name);
	
	return g_Skills.GetID(name);
}

public any NAT_Skills_ClientHaveByName(Handle plugin, int numparams)
{
	int client, id;
	char name[MAX_SKILL_NAME_LENGTH];
	
	client = GetNativeCell(1);
	GetNativeString(2, name, sizeof name);
	id = g_Skills.GetID(name);
	
	if ( id == -1 )
		return ThrowNativeError(err_kName, "Invalid skill name: %s", name);
	
	return GetClientSkillState(client, id);
}

public any NAT_Skills_ClientHaveByID(Handle plugin, int numparams)
{
	int client = GetNativeCell(1);
	int id = GetNativeCell(2);
	return GetClientSkillState(client, id);
}

public any NAT_Skills_Register(Handle plugin, int numparams)
{
	char name[MAX_SKILL_NAME_LENGTH];
	int id;
	SkillType type;
	bool upgradable;

	GetNativeString(1, name, sizeof name);
	type = GetNativeCell(2);
	upgradable = GetNativeCell(3);
	id = g_Skills.GetID(name);
	g_Skills.FillInfo(name, plugin, type, upgradable);
	
	if ( id != -1 )
	{
		RequestFrame(Skills_OnSkillStateChangedFrame, id);
		NotifySkillRegistered(name, id);
		return id;
	}
	
	return g_Skills.Register(name);
}

public any NAT_Skills_ChangeState(Handle plugin, int numparams)
{
	int client = GetNativeCell(1);
	int id = GetNativeCell(2);
	SkillState state = GetNativeCell(3);
	
	SetClientSkillState(client, id, state);
	return 0;
}

public any NAT_Skills_GetCount(Handle plugin, int numparams)
{
	return g_Skills.count;
}

public any NAT_Skills_IsUpgradable(Handle plugin, int numparams)
{
	char name[MAX_SKILL_NAME_LENGTH];
	SkillInfo info;
	
	GetNativeString(1, name, sizeof name);
	if ( !g_Skills.GetInfo(name, info) )
		return ThrowNativeError(err_kID, "Invalid skill name %s", name);
	
	return info.upgradable;
}

public any NAT_Skills_GetType(Handle plugin, int numparams)
{
	char name[MAX_SKILL_NAME_LENGTH];
	SkillInfo info;
	
	GetNativeString(1, name, sizeof name);
	if ( !g_Skills.GetInfo(name, info) )
		return ST_INVALID;	
	
	return info.type;
}

public any NAT_Skills_GetOwner(Handle plugin, int numparams)
{
	char name[MAX_SKILL_NAME_LENGTH];
	SkillInfo info;
	
	GetNativeString(1, name, sizeof name);
	if ( !g_Skills.GetInfo(name, info) )
		return ST_INVALID;	
	
	return info.owner;
}

public any NAT_Skills_GetClientSkillsCount(Handle plugin, int numparams)
{
	int count, client;
	client = GetNativeCell(1);
	
	for( int i; i < g_Skills.count; i++ )
	{
		if ( !GetClientSkillState(client, i) )
			continue;
		
		count++;
	}
	
	return count;
}

native bool L4D_IsFirstMapInScenario();

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errormax) 
{
	CreateNative("Skills_GetClientSkillsCount", NAT_Skills_GetClientSkillsCount);
	
	CreateNative("Skills_GetClientMoney", NAT_Skills_GetClientMoney);
	CreateNative("Skills_SetClientMoney", NAT_Skills_SetClientMoney);

	CreateNative("Skills_GetClientMoneyMultiplier", NAT_Skills_GetClientMoneyMultiplier);
	CreateNative("Skills_SetClientMoneyMultiplier", NAT_Skills_SetClientMoneyMultiplier);
	
	CreateNative("Skills_GetTeamMoney", NAT_Skills_GetTeamMoney);
	CreateNative("Skills_SetTeamMoney", NAT_Skills_SetTeamMoney);
	
	CreateNative("Skills_GetTeamMoneyMultiplier", NAT_Skills_GetTeamMoneyMultiplier);
	CreateNative("Skills_SetTeamMoneyMultiplier", NAT_Skills_SetTeamMoneyMultiplier);
	
	CreateNative("Skills_GetName", NAT_Skills_GetName);
	CreateNative("Skills_GetID", NAT_Skills_GetID);
	CreateNative("Skills_GetCount", NAT_Skills_GetCount);
	CreateNative("Skills_IsUpgradable", NAT_Skills_IsUpgradable);
	
	CreateNative("Skills_GetType", NAT_Skills_GetType);
	CreateNative("Skills_GetOwner", NAT_Skills_GetOwner);
	
	CreateNative("Skills_ClientHaveByName", NAT_Skills_ClientHaveByName);
	CreateNative("Skills_ClientHaveByID", NAT_Skills_ClientHaveByID);
	CreateNative("Skills_ChangeState", NAT_Skills_ChangeState);
	CreateNative("Skills_Register", NAT_Skills_Register);
	
	g_hFwdOnRegistered = new GlobalForward("Skills_OnRegistered", ET_Ignore, Param_String, Param_Cell);
	g_hFwdOnCoreStart = new GlobalForward("Skills_OnCoreStart", ET_Ignore);
	g_hFwdOnCoreLoaded = new GlobalForward("Skills_OnCoreLoaded", ET_Ignore);
	g_hFwdOnStateChanged = new GlobalForward("Skills_OnStateChanged", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hFwdOnStateReset = new GlobalForward("Skills_OnStateReset", ET_Ignore);
	
	MarkNativeAsOptional("L4D_IsFirstMapInScenario");
	
	RegPluginLibrary("l4d2_skills_core");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_Skills.Init();
	
	for( int i = 1; i <= MaxClients; i++ )
		g_PlayersInfo[i].economy.multiplier = 1.0;
	
	g_teamEconomy.multiplier = 1.0;
	
	RegAdminCmd("sm_skills_give_money", sm_skills_give_money, ADMFLAG_RCON);
	RegAdminCmd("sm_skills_give_team_money", sm_skills_give_team_money, ADMFLAG_RCON);
	RegAdminCmd("sm_skills_give_skill", sm_skills_give_skill, ADMFLAG_RCON);
	RegAdminCmd("sm_skills_list", sm_skills_list, ADMFLAG_RCON);
	RegAdminCmd("sm_skills_update", sm_skills_update, ADMFLAG_ROOT);
	
	LoadTranslations("common.phrases.txt");

	NotifyCoreStart();
}

public void OnAllPluginsLoaded()
{
	NotifyCoreLoaded();
}

public void OnMapStart()
{
	if ( L4D_IsFirstMapInScenario() )
	{
		// int count = Skills_GetCount();
		// for( int i; i < count; i++ )
		// {
		// 	NotifySkillReset(i);
		// }
		
		NotifyStateReset();
	}
}

public Action sm_skills_update( int client, int args )
{
	NotifyCoreStart();
	NotifyCoreLoaded();
	return Plugin_Handled;
}

public Action sm_skills_give_team_money( int client, int args )
{
	if ( args < 1 )
	{
		//Skills_ReplyToCommand(client, "Usage: !sm_skills_give_team_money <amount>");
		Skills_ReplyToCommand(client, "Usage: !sm_skills_give_team_money <积分数量>");
		return Plugin_Handled;
	}
	
	float add = float(GetCmdArgInt(1));
	g_teamEconomy.AddMoney(add);
	//Skills_PrintToChatAll("\x01Added \x04%.0f \x01to team money", add);
	Skills_PrintToChatAll("\x01团队积分增加了 \x04%.0f ", add);
	return Plugin_Handled;
}

public Action sm_skills_give_money( int client, int args )
{
	if ( args < 2 || args > 2 )
	{
		//Skills_ReplyToCommand(client, "Usage: !skills_give_money <target> <amount>");
		Skills_ReplyToCommand(client, "Usage: !skills_give_money <对象> <积分数量>");
		return Plugin_Handled;
	}
	
	char szTarget[MAX_TARGET_LENGTH], szAdd[16];
	float add;
	
	GetCmdArg(1, szTarget, sizeof szTarget);
	GetCmdArg(2, szAdd, sizeof szAdd);
	
	add = StringToFloat(szAdd);
	
	int target = FindTarget(client, szTarget, true, false);
	
	if ( target == -1 )
	{
		//Skills_ReplyToCommand(client, "Invalid target: %s", szTarget);
		Skills_ReplyToCommand(client, "无效目标: %s", szTarget);
		return Plugin_Handled;
	}
	
	g_PlayersInfo[client].economy.AddMoney(add);
	//Skills_PrintToChatAll("\x05%N \x04gave \x05%N \x04money \x03%.0f", client, target, add);
	Skills_PrintToChatAll("\x05%N\x04给了\x05%N \x03%.0f \x04积分", client, target, add);
	return Plugin_Handled;
}

public Action sm_skills_give_skill( int client, int args )
{
	if ( args < 2 || args > 2 )
	{
		//Skills_ReplyToCommand(client, "Usage: !skills_give_skill <target> <skill name>");
		Skills_ReplyToCommand(client, "Usage: !skills_give_skill <对象> <技能名称>");
		return Plugin_Handled;
	}
	
	char szTarget[MAX_TARGET_LENGTH], name[MAX_SKILL_NAME_LENGTH];
	int id;
	
	GetCmdArg(1, szTarget, sizeof szTarget);
	GetCmdArg(2, name, sizeof name);
	
	if ( !g_Skills.GetContainsName(id, name, false) )
	{
		//Skills_ReplyToCommand(client, "Invalid skill name: %s", name);
		Skills_ReplyToCommand(client, "无效技能名称: %s", name);
		return Plugin_Handled;
	}

	g_Skills.GetName(id, name);
	
	int target = FindTarget(client, szTarget, true, false);
	
	if ( target == -1 )
	{
		//Skills_ReplyToCommand(client, "Invalid target: %s", szTarget);
		Skills_ReplyToCommand(client, "无效目标: %s", szTarget);
		return Plugin_Handled;
	}
	
	SetClientSkillState(target, id, SS_PURCHASED);
	//Skills_PrintToChatAll("\x05%N \x04gave \x05%N \x04skill \x03%%s", client, target, name);
	Skills_PrintToChatAll("\x05%N\x04把\x03%%s\x04技能\x04给了 \x05%N", client, target, name);
	return Plugin_Handled;
}

public Action sm_skills_list( int client, int args )
{
	SkillInfo info;
	char name[MAX_SKILL_NAME_LENGTH], filename[256];
	
	if ( !g_Skills.count )
	{
		//Skills_ReplyToCommand(client, "No skills registered");
		Skills_ReplyToCommand(client, "无技能记录");
		return Plugin_Handled;
	}
	
	//Skills_ReplyToCommand(client, "Skills list:");
	Skills_ReplyToCommand(client, "技能列表:");
	
	for( int i; i < g_Skills.count; i++ )
	{
		g_Skills.GetName(i, name);
		g_Skills.GetInfo(name, info);
		
		GetPluginFilename(info.owner, filename, sizeof filename);
		Skills_ReplyToCommand(client, "%i. %s (%s)", i + 1, name, filename);
	}
	
	return Plugin_Handled;
}

public void Skills_OnSkillStateChangedFrame( int id )
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if ( !IsClientInGame(i) || IsFakeClient(i) )
			continue;
				
		NotifySkillStateChanged(i, id, GetClientSkillState(i, id) ? SS_PURCHASED : SS_NULL);
	}
}

void SetClientSkillState( int client, int id, SkillState state )
{
	g_PlayersInfo[client].skills.skill[id] = state == SS_NULL ? false : true;
	NotifySkillStateChanged(client, id, state);
}

bool GetClientSkillState( int client, int id )
{
	return !!g_PlayersInfo[client].skills.skill[id];
}
	
void NotifySkillRegistered( const char[] name, int id )
{
	SkillInfo info;
	
	if ( !g_Skills.GetInfo(name, info) )
	{
		ERROR("Failed to get info for %s (%i)", name, id);
		return;
	}
	
	Call_StartForward(g_hFwdOnRegistered);
	Call_PushString(name);
	Call_PushCell(info.type);
	Call_Finish();
}

void NotifySkillStateChanged( int client, int id, SkillState state )
{
	if (state == SS_NULL)
	{
		NotifySkillReset(id);
		return;
	}

	NotifySkillStateChangedPrivate(client, id, state);

	Call_StartForward(g_hFwdOnStateChanged);
	Call_PushCell(client);
	Call_PushCell(id);
	Call_PushCell(state);
	Call_Finish();
}

void NotifySkillStateChangedPrivate(int client, int id, SkillState state)
{
	char name[MAX_SKILL_NAME_LENGTH];
	if (!Skills_GetName(id, name))
		return;

	Handle owner = Skills_GetOwner(name);
	Function f = GetFunctionByName(owner, "Skills_OnStateChangedPrivate");

	if (f != INVALID_FUNCTION)
	{
		Call_StartFunction(owner, f);
		Call_PushCell(client);
		Call_PushCell(id);
		Call_PushCell(state);
		Call_Finish();
	}
}

stock void NotifyCoreStart()
{
	Call_StartForward(g_hFwdOnCoreStart);
	Call_Finish();
}

stock void NotifyCoreLoaded()
{
	Call_StartForward(g_hFwdOnCoreLoaded);
	Call_Finish();
}

stock void NotifyStateReset()
{
	Call_StartForward(g_hFwdOnStateReset);
	Call_Finish();
}

stock bool NotifySkillReset(int i)
{
	char name[MAX_SKILL_NAME_LENGTH];
	Function fSkills_OnStateReset;
	Handle owner;

	Skills_GetName(i, name);
	owner = Skills_GetOwner(name);
				
	if ( (fSkills_OnStateReset = GetFunctionByName(owner, "Skills_OnStateReset")) != INVALID_FUNCTION )
	{
		Action result = Plugin_Continue;

		Call_StartFunction(owner, fSkills_OnStateReset);
		Call_Finish(result);

		if ( result > Plugin_Continue )
			return false;
	}

	Skills_RemoveEveryByID(i);
	return true;
}