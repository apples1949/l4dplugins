#include <sourcemod>
#include <sdkhooks>
 
#pragma semicolon 1
 
#define PLUGIN_VERSION "1.3.2"

#define ENABLE_AUTOEXEC true

//removed supertanks support.

public Plugin:myinfo =
{
    name = "[L4D/L4D2]TankDamageModifier",
    author = "Lux",
    description = "Lets you Choose your own custom damage for Tanks",
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/showthread.php?p=2421778#post2421778"
};

static Handle:hCvar_DmgEnable = INVALID_HANDLE;
static Handle:hCvar_Damage = INVALID_HANDLE;
static Handle:hCvar_IncapMulti = INVALID_HANDLE;

static bool:g_DmgEnable;
static Float:g_iDamage;
static Float:g_iImultiplyer;

static bool:g_bDisable = false;
static ZOMBIECLASS_TANK;

public OnPluginStart()
{
	decl String:sGameName[12];
	GetGameFolderName(sGameName, sizeof(sGameName));
	if(StrEqual(sGameName, "left4dead"))
		ZOMBIECLASS_TANK = 5;
	else if(StrEqual(sGameName, "left4dead2"))
		ZOMBIECLASS_TANK = 8;
	else
		SetFailState("This plugin only runs on Left 4 Dead and Left 4 Dead 2!");
	
	CreateConVar("TankDamageModifier_Version", PLUGIN_VERSION, "TankDamageModifier Plugin Version", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	hCvar_DmgEnable = CreateConVar("tank_damage_enable", "1", "是否启用坦克伤害修改插件", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hCvar_Damage = CreateConVar("tank_damage", "20.0", "坦克攻击生还者造成多少伤害", FCVAR_NOTIFY, true, 0.0, true, 9999.0);
	hCvar_IncapMulti = CreateConVar("tank_damage_modifier", "10.0", "对倒地的生还者造成多少倍数的伤害(设置的伤害*倒地时设定的伤害倍数)", FCVAR_NOTIFY, true, 0.0, true, 9999.0);
	
	HookConVarChange(hCvar_DmgEnable, eConvarChanged);
	HookConVarChange(hCvar_Damage, eConvarChanged);
	HookConVarChange(hCvar_IncapMulti, eConvarChanged);
	
	#if ENABLE_AUTOEXEC
	AutoExecConfig(true, "TankDamageModifier");
	#endif
}

public OnMapStart()
{
	CvarsChanged();
}

public eConvarChanged(Handle:hCvar, const String:sOldVal[], const String:sNewVal[])
{
	CvarsChanged();
}

CvarsChanged()
{
	g_DmgEnable = GetConVarInt(hCvar_DmgEnable) > 0;
	g_iDamage = GetConVarFloat(hCvar_Damage);
	g_iImultiplyer = GetConVarFloat(hCvar_IncapMulti);
}

public OnClientPutInServer(iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamage, eOnTakeDamage);
}

public Action:eOnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamagetype)
{
	if(!g_DmgEnable || g_bDisable)
		return Plugin_Continue;
   
	if(!IsClientInGame(iVictim) || GetClientTeam(iVictim) != 2)
		return Plugin_Continue;
       
	if(iAttacker < 1 || iAttacker > MaxClients)
		return Plugin_Continue;
		
	if(GetClientTeam(iAttacker) != 3 || GetEntProp(iAttacker, Prop_Send, "m_zombieClass") != ZOMBIECLASS_TANK)
		return Plugin_Continue;
	
	static String:sInflictor[18];
	GetEntityClassname(iInflictor, sInflictor, sizeof(sInflictor));
	
	if(sInflictor[0] == 'p' && StrContains(sInflictor, "prop") > 0 )// should work for all props however if the classname is changed to something else, maybe i should check the net class instead
		return Plugin_Continue;
	
	if(IsSurvivorIncapacitated(iVictim))
	{
		fDamage = (g_iDamage * g_iImultiplyer);
		return Plugin_Changed;
	}
	else
	{
		fDamage = g_iDamage;// supports point hurt entity for realish tank physx
		return Plugin_Changed;
	}
}

bool:IsSurvivorIncapacitated(iClient)
{
	return GetEntProp(iClient, Prop_Send, "m_isIncapacitated", 1) > 0;
}
