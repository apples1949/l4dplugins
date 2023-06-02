#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#define PLUGIN_VERSION "1.2" 


public Plugin:myinfo =
{
    name = "Fly You Fools",
    author = "ConnerRia",
    description = "Survivor bots will retreat from tank. ",
    version = PLUGIN_VERSION,
    url = "N/A"
}

new bool: bIsTankInPlay = false;
float fTankDangerDistance;
int TankClient; 
ConVar hTankDangerDistance;

public OnPluginStart()
{
	decl String:game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2", false) && !StrEqual(game_name, "left4dead", false))
	{		
		SetFailState("Plugin supports Left 4 Dead series only.");
	}
	
	CreateConVar("FlyYouFools_Version", PLUGIN_VERSION, "FlyYouFools Version", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	hTankDangerDistance = CreateConVar("200IQBots_TankDangerRange", "800.0", "The range by which survivors bots will detect the presence of tank and retreat. ", FCVAR_NOTIFY|FCVAR_REPLICATED);
	
	HookEvent("map_transition", Event_MapTransition, EventHookMode_Pre);	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("tank_killed", Event_TankDeath);	
	//HookEvent("player_incapacitated", Event_PlayerIncapped);
	
	AutoExecConfig(true, "200IQBots_FlyYouFools");
	
}

public OnMapStart()
{	
	bIsTankInPlay = false;
}	

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	bIsTankInPlay = false;
}

public Action:Event_MapTransition(Handle:event, const String:name[], bool:dontBroadcast)
{
	bIsTankInPlay = false;
}

public Action:Event_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	bIsTankInPlay = true;
	TankClient = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.1, BotControlTimer, _, TIMER_REPEAT);
}

public Action:Event_TankDeath(Handle:event, const String:name[], bool:dontBroadcast)	
{
	bIsTankInPlay = false;
}

public Action:BotControlTimer(Handle:Timer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && (GetClientTeam(i) == 2) && IsFakeClient(i))
		{	
			new TheTank = TankClient;
			if (IsClientInGame(TheTank) && IsPlayerAlive(TheTank) && (GetClientTeam(TheTank) == 3))	
			{
				fTankDangerDistance = hTankDangerDistance.FloatValue;
				new Float:TankPosition[3];
				GetClientAbsOrigin(TheTank, TankPosition);
				new Float:BotPosition[3];
				GetClientAbsOrigin(i, BotPosition);
				if (GetVectorDistance(BotPosition, TankPosition) < fTankDangerDistance)
				{
					L4D2_RunScript("CommandABot({cmd=2,bot=GetPlayerFromUserID(%i),target=GetPlayerFromUserID(%i)})", GetClientUserId(i), GetClientUserId(TheTank));
				}
			}
		}
	}	  
	
	if (!bIsTankInPlay)
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:Event_PlayerIncapped(Handle:event, const String:name[], bool:dontBroadcast)
{	
	if (bIsTankInPlay)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && (GetClientTeam(i) == 2) && IsFakeClient(i))
			{	
				L4D2_RunScript("CommandABot({cmd=3,bot=GetPlayerFromUserID(%i)})", GetClientUserId(i));
			}
		}
	}
}


//Credits to Timocop for the stock :D
/**
* Runs a single line of vscript code.
* NOTE: Dont use the "script" console command, it starts a new instance and leaks memory. Use this instead!
*
* @param sCode		The code to run.
* @noreturn
*/
stock L4D2_RunScript(const String:sCode[], any:...)
{
	static iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) {
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
			SetFailState("Could not create 'logic_script'");
		
		DispatchSpawn(iScriptLogic);
	}
	
	static String:sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}