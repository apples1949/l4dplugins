#pragma newdecls required
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <sdkhooks>

#define Pie 3.14159265358979323846

#define State_None 0
#define State_Climb 1
#define State_OnAir 2

#define ACT_CLIMB_UP "ACT_CLIMB_UP"

#define ZOMBIECLASS_SURVIVOR 9
#define ZOMBIECLASS_SMOKER 1
#define ZOMBIECLASS_BOOMER 2
#define ZOMBIECLASS_HUNTER 3
#define ZOMBIECLASS_SPITTER 4
#define ZOMBIECLASS_JOCKEY 5
#define ZOMBIECLASS_CHARGER 6

static int ZOMBIECLASS_TANK;

#define model_zoey 1
#define model_bill 2
#define model_louis 3
#define model_francis 4
#define model_coach 5
#define model_nick 6
#define model_ellis 7
#define model_rochelle 8

#define model_tank 9
#define model_boomer 10
#define model_smoker 11
#define model_hunter 12
#define model_spitter 13
#define model_jockey 14
#define model_charger 15
#define model_boomer_female 16

#define JumpSpeed 300.0 
#define gbodywidth 20.0 
#define bodylength 70.0

Handle l4d_climb_enable;  
Handle l4d_climb_team; 
Handle l4d_climb_glow; 
Handle l4d_climb_msg;
Handle l4d_climb_speed[10]; 
Handle l4d_climb_infected[10];

static int GameMode;
static bool L4D2Version;

static int Clone[MAXPLAYERS+1] = -1;

static bool FirstRun[MAXPLAYERS+1];

static float BodyNormal[MAXPLAYERS+1][3];
static float Angle[MAXPLAYERS+1];

static int State[MAXPLAYERS+1];

static float BodyPos[MAXPLAYERS+1][3];
static float LastPos[MAXPLAYERS+1][3];
static float SafePos[MAXPLAYERS+1][3];

static float BodyWidth[MAXPLAYERS+1];

static float JumpTime[MAXPLAYERS+1];
static float LastTime[MAXPLAYERS+1];

static float Interval[MAXPLAYERS+1];

static float GlowTime[MAXPLAYERS+1];
static bool GlowIndicator[MAXPLAYERS+1];

static float ClimbSpeed[MAXPLAYERS+1];
static float PlayBackRate[MAXPLAYERS+1];
static float StuckIndicator[MAXPLAYERS+1];  

static int ShowMsg[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "Climb Everywhere",
	author = "Pan Xiaohai, Shadowysn (New syntax)",
	description = "Makes Everyone Climb On Surfaces.",
	version = "1.05",
}
 
public void OnPluginStart()
{
	GameCheck();
	
 	l4d_climb_enable = CreateConVar("climb_everywhere_enable", "2", "Enable Mode: 1=Co-op Only, 2=All Game Modes", FCVAR_ARCHIVE);
	l4d_climb_team = CreateConVar("climb_everywhere_team", "3", "Enable Mode: 1=Both Teams, 2=Survivors Team Only, 3=Infected Team Only", FCVAR_ARCHIVE);	
	l4d_climb_msg = CreateConVar("climb_everywhere_msg", "2", "Limit Of Messages Shown", FCVAR_ARCHIVE);	
	l4d_climb_glow = CreateConVar("climb_everywhere_glow", "0", "Enable/Disable Glow", FCVAR_ARCHIVE);
	
	l4d_climb_infected[ZOMBIECLASS_HUNTER] = CreateConVar("climb_everywhere_hunter", "1", "Hunter Enable Mode: 1=On, 2=Only Alive", FCVAR_ARCHIVE);	
	l4d_climb_infected[ZOMBIECLASS_SMOKER] = CreateConVar("climb_everywhere_smoker", "1", "Smoker Enable Mode: 1=On, 2=Only Alive", FCVAR_ARCHIVE);	
	l4d_climb_infected[ZOMBIECLASS_TANK] = CreateConVar("climb_everywhere_tank", "1", "Tank Enable Mode: 1=On, 2=Only Alive", FCVAR_ARCHIVE);	
	l4d_climb_infected[ZOMBIECLASS_BOOMER] = CreateConVar("climb_everywhere_boomer", "1", "Boomer Enable Mode: 1=On, 2=Only Alive", FCVAR_ARCHIVE);	
	l4d_climb_infected[ZOMBIECLASS_JOCKEY] = CreateConVar("climb_everywhere_jockey", "1", "Jockey Enable Mode: 1=On, 2=Only Alive", FCVAR_ARCHIVE);	
	l4d_climb_infected[ZOMBIECLASS_SPITTER] = CreateConVar("climb_everywhere_spitter", "1", "Spitter Enable Mode: 1=On, 2=Only Alive", FCVAR_ARCHIVE);	
	l4d_climb_infected[ZOMBIECLASS_CHARGER] = CreateConVar("climb_everywhere_charger", "1", "Charger Enable Mode: 1=On, 2=Only Alive", FCVAR_ARCHIVE);	
	
	l4d_climb_speed[0] = CreateConVar("climb_everywhere_speed", "40", "Speed Applied When Climbing", FCVAR_ARCHIVE);
	l4d_climb_speed[ZOMBIECLASS_SURVIVOR] = CreateConVar("climb_everywhere_speed_survivor", "1.0", "Speed Applied For Survivors", FCVAR_ARCHIVE);
	l4d_climb_speed[ZOMBIECLASS_HUNTER] = CreateConVar("climb_everywhere_speed_hunter", "2.4", "Speed Applied For Hunters", FCVAR_ARCHIVE);	
	l4d_climb_speed[ZOMBIECLASS_SMOKER] = CreateConVar("climb_everywhere_speed_smoker", "2.1", "Speed Applied For Smokers", FCVAR_ARCHIVE);	
	l4d_climb_speed[ZOMBIECLASS_TANK] = CreateConVar("climb_everywhere_speed_tank", "1.5", "Speed Applied For Tanks", FCVAR_ARCHIVE);	
	l4d_climb_speed[ZOMBIECLASS_BOOMER] = CreateConVar("climb_everywhere_speed_boomer", "1.8", "Speed Applied For Boomers", FCVAR_ARCHIVE);	
	l4d_climb_speed[ZOMBIECLASS_JOCKEY] = CreateConVar("climb_everywhere_speed_jockey", "2.4", "Speed Applied For Jockeys", FCVAR_ARCHIVE);	
	l4d_climb_speed[ZOMBIECLASS_SPITTER] = CreateConVar("climb_everywhere_speed_spitter", "2.0", "Speed Applied For Spitters", FCVAR_ARCHIVE);	
	l4d_climb_speed[ZOMBIECLASS_CHARGER] = CreateConVar("climb_everywhere_speed_charger", "2.5", "Speed Applied For Chargers", FCVAR_ARCHIVE);
	
	AutoExecConfig(true, "climb_everywhere");
	
	HookEvent("player_bot_replace", player_bot_replace);	 
	HookEvent("player_jump", player_jump);
	if(L4D2Version)
	{
		HookEvent("jockey_ride", events_to_interrupt);
		HookEvent("charger_carry_start", events_to_interrupt);
		HookEvent("charger_pummel_start", events_to_interrupt);
	}
	HookEvent("tongue_grab", events_to_interrupt);
	HookEvent("player_ledge_grab", events_to_interrupt);
	HookEvent("lunge_pounce", events_to_interrupt);
	HookEvent("player_incapacitated_start", events_to_interrupt); 	
	HookEvent("player_death", player_death);
	HookEvent("player_spawn", player_spawn);
	
	HookEvent("round_start", on_round_reset);
	HookEvent("round_end", on_round_reset);
	HookEvent("finale_win", on_round_reset);
	HookEvent("mission_lost", on_round_reset);
	HookEvent("map_transition", on_round_reset);	
	
	RegConsoleCmd("sm_anim", GetAnimation);
	
	ResetAllState();
}

Action GetAnimation(int client, any args)
{
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		int m = GetEntProp(client, Prop_Send, "m_nSequence");	
		PrintToChat(client, "Current Animation: %d", m);
	}
	
	return Plugin_Handled;
}

Action on_round_reset(Handle event, const char[] name, bool dontBroadcast)
{
	ResetAllState();
}

void ResetAllState()
{
	for(int i=1; i<=MaxClients; i++)
	{
		Stop(i);
		ShowMsg[i] = 0;
	}
}

/*Action OnHeld(Handle event, const char[] name, bool dontBroadcast)
{ EventInterrupt(event, "victim"); }

Action OnPlayerLedgeGrab(Handle event, const char[] name, bool dontBroadcast)
{ EventInterrupt(event); }

Action OnPlayerIncapacitatedStart(Handle event, const char[] name, bool dontBroadcast)
{ EventInterrupt(event); }*/

Action events_to_interrupt(Handle event, const char[] name, bool dontBroadcast)
{
	if (StrEqual(name, "jockey_ride", false) || StrEqual(name, "charger_carry_start", false) ||
	StrEqual(name, "charger_pummel_start", false) || StrEqual(name, "tongue_grab", false) ||
	StrEqual(name, "lunge_pounce", false))
	{ EventInterrupt(event, "victim"); }
	else
	{ EventInterrupt(event); }
}

void EventInterrupt(Handle event, const char[] name = "userid")
{
	if(GetConVarInt(l4d_climb_enable) <= 0) return;
	
	int victim = GetClientOfUserId(GetEventInt(event, name)); 
	Interrupt(victim);
}

Action player_bot_replace(Handle event, const char[] name, bool dontBroadcast)
{
	if(GetConVarInt(l4d_climb_enable) <= 0) return;
	
	int client = GetClientOfUserId(GetEventInt(event, "player"));
	int bot = GetClientOfUserId(GetEventInt(event, "bot")); 
	Stop(client);
	Stop(bot); 
}

Action player_jump(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client) || IsFakeClient(client)) return;
	
	bool isGhost = false;
	if(IsInfected(client) && GetEntProp(client, Prop_Send, "m_isGhost"))
	{ isGhost = true; }
	
	if(!CanUse(client, isGhost)) return;
	
	SDKUnhook(client, SDKHook_PostThinkPost, PreThink); 
	SDKUnhook(client, SDKHook_SetTransmit, OnSetTransmitClient);
	
	State[client] = State_OnAir;
	
	SDKHook(client, SDKHook_PostThinkPost, PreThink);
	
	float pos[3];
	GetClientAbsOrigin(client, pos);
	CopyVector(pos, SafePos[client]);
	
	LastTime[client] = GetEngineTime();
	JumpTime[client] = LastTime[client];
	
	return;
}

Action player_death(Handle event, const char[] name, bool dontBroadcast)
{
	if(GetConVarInt(l4d_climb_enable) <= 0) return;
	
	int victim = GetClientOfUserId(GetEventInt(event, "userid")); 
	Stop(victim); 
	ShowMsg[victim] = 0;
}

Action player_spawn(Handle event, const char[] name, bool dontBroadcast)
{
	if(GetConVarInt(l4d_climb_enable) <= 0) return;
	
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	ShowMsg[victim] = 0;
	Stop(victim);
	
	if(ShowMsg[victim] < GetConVarInt(l4d_climb_msg))
	{
		ShowMsg[victim]++;
		if(CanUse(victim))
		{
			CreateTimer(1.0, ShowInfo, victim);
		}
	}
}

bool CanUse(int client, bool isGhost = false)
{
 	int mode = GetConVarInt(l4d_climb_enable);
	if(mode <= 0) return false;
	
	if(mode == 1 && GameMode == 2) return false;
	
	if(IsValidClient(client))
	{
		if(IsPlayerAlive(client))
		{
			int teammode = GetConVarInt(l4d_climb_team);
			if (IsSurvivor(client))
			{
				if(teammode == 1 || teammode == 2)
				{ return true; }
				else
				{ return false; }
			}
			else if (IsInfected(client))
			{
				if(teammode == 1 || teammode == 3)
				{
					int c = GetEntProp(client, Prop_Send, "m_zombieClass");
					int m = GetConVarInt(l4d_climb_infected[c]);
					if(m == 1)
					{ return true; }
					else if(m == 2 && !isGhost)
					{ return true; }
					else
					{ return false; }
				}
				else
				{ return false; }
			}
			return true;
		}
		return true;
	}
	else
	{ return true; }
}

void Interrupt(int client)
{
	if(State[client] == State_Climb)
	{
		Jump(client, false, 50.0);
		Stop(client);
	}
	else if(State[client] == State_OnAir)
	{
		Stop(client);
	}
}

void Stop(int client)
{
	if(State[client] == State_None) return;
	
	State[client] = State_None;
	if(IsValidEntityAndNotWorld(Clone[client]))
	{
		AcceptEntityInput(Clone[client], "kill");
		Clone[client] = 0;
	}
	
	if(IsValidClient(client))
	{
		GotoFirstPerson(client);
		VisiblePlayer(client, true);
		
		if (!GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
		{ SetEntityMoveType(client, MOVETYPE_WALK); }
		
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
	}
	
	SDKUnhook(client, SDKHook_PostThinkPost, PreThink);
	SDKUnhook(client, SDKHook_SetTransmit, OnSetTransmitClient);
}

void Start(int client)
{
	float vAngles[3];
	float vOrigin[3];
	float hit[3];
	float normal[3];
	float up[3];
	
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);	 
	
	GetRay(client, vOrigin, vAngles, hit, normal, 0.0 - gbodywidth); 
	if(GetVectorDistance(hit, vOrigin) < gbodywidth * 2.0)
	{
		SetVector(up, 0.0, 0.0, 1.0);
		float f = GetAngle(normal, up) * 180 / Pie;
		if(f < 10.0 || f > 170.0)
		{ return; }
		
		CopyVector(normal, BodyNormal[client]); 
		CopyVector(hit, BodyPos[client]);
		
		Angle[client] = 0.0;
		CopyVector(normal, BodyNormal[3]);
		
		int clone = CreateClone(client);
		if(IsValidEntity(clone))
		{
			Clone[client] = clone; 
			
			SetEntityMoveType(client, MOVETYPE_NONE);
			
			GotoThirdPerson(client);
			VisiblePlayer(client, false);
			
			SDKUnhook(client, SDKHook_SetTransmit, OnSetTransmitClient);
			SDKHook(client, SDKHook_SetTransmit, OnSetTransmitClient);
			
			bool isGhost = false;
			if(IsInfected(client) && GetEntProp(client, Prop_Send, "m_isGhost"))
			{
				isGhost = true;
			}
			
			if (isGhost)
			{
				SDKUnhook(clone, SDKHook_SetTransmit, OnSetTransmitClient); 
				SDKHook(clone, SDKHook_SetTransmit, OnSetTransmitClient);
			}
			
			SDKUnhook(client, SDKHook_PostThinkPost, PreThink); 
			SDKHook(client, SDKHook_PostThinkPost, PreThink);
			
			SaveWeapon(client);
			
			State[client] = State_Climb;
			FirstRun[client] = true;
			
			GlowIndicator[client] = false;
			GlowTime[client] = 0.0;
		}
		else
		{ PrintToChat(client, "Unknown model!"); }
	}
}

void Jump(int client, bool check = true, float jump_speed = JumpSpeed)
{
	float time = GetEngineTime(); 
	if(check)
	{
		if(time - JumpTime[client] < 2.0)
		{
			PrintCenterText(client, "Too Quick To Jump!");
			return;
		}
	}
	
 	if(Clone[client] > 0)
	{
		AcceptEntityInput(Clone[client], "kill");
		Clone[client] = 0;
		if(IsValidClient(client))
		{ RestoreWeapon(client); }
	}
	
	SDKUnhook(client, SDKHook_SetTransmit, OnSetTransmitClient);
	
	if(!IsValidClient(client)) return;
	
	GotoFirstPerson(client);
	VisiblePlayer(client, true);
	
	SetEntityMoveType(client, MOVETYPE_WALK);
	
	float vAngles[3];
	float vOrigin[3];
	float vec[3];
	float pos[3];
	
	GetClientEyePosition(client, vOrigin);
	CopyVector(BodyNormal[client], vec);
	NormalizeVector(vec, vec);
	ScaleVector(vec, BodyWidth[client]);
	AddVectors(vOrigin, vec, pos);
	
	GetClientEyeAngles(client, vAngles);
	GetAngleVectors(vAngles, vec, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vec, vec);
	ScaleVector(vec, jump_speed);
	TeleportEntity(client, pos, NULL_VECTOR, vec);
	CopyVector(pos, LastPos[client]);
	SetEntPropFloat(client, Prop_Send, "m_flFallVelocity", 0.0);
	
	JumpTime[client] = time;
	StuckIndicator[client] = 0.0;
	State[client] = State_OnAir;
}

Action OnSetTransmitClient(int climber, int client)
{
	if(!IsValidClient(climber) || !IsValidClient(client))
	{ return Plugin_Handled; }
	
	if(climber != client)
	{
		if(IsSurvivor(climber))
		{ return Plugin_Handled; }
		
		if(IsSurvivor(client) || IsInfected(client))
		{ return Plugin_Handled; }
		
		if(GlowIndicator[climber])
		{ return Plugin_Continue; }
		
		return Plugin_Handled;
	}
	else
	{ return Plugin_Continue; }
}

void PreThink(int client)
{
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		if (IsValidEntityAndNotWorld(Clone[client]))
		{
			SetEntPropFloat(Clone[client], Prop_Send, "m_flPoseParameter", GetEntPropFloat(client, Prop_Send, "m_flPoseParameter", 0), 0); // body_pitch
			SetEntPropFloat(Clone[client], Prop_Send, "m_flPoseParameter", GetEntPropFloat(client, Prop_Send, "m_flPoseParameter", 1), 1); // body_yaw
		}
		// Modified lines taken from https://forums.alliedmods.net/showthread.php?t=299560 which in turn 
		// had the original line contributed by DeathChaos25
		
		float time = GetEngineTime();
		float interval = time - LastTime[client]; 
		Interval[client] = interval;
		
		if(State[client] == State_OnAir)
		{ OnAir(client); }
		else if(State[client] == State_Climb)
		{ Climb(client, interval); }
		
		LastTime[client] = time;
		
		if(GetConVarInt(l4d_climb_glow) == 1)
		{
			GlowTime[client] += interval;
			if(GlowTime[client] > 4.0)
			{
				GlowIndicator[client] = false;
				GlowTime[client] = 0.0;  
			}
			else if(GlowTime[client] > 3.5)
			{ GlowIndicator[client] = true; }
		}
	}
	else
	{ Stop(client); }
}

void OnAir(int client)
{
	int flag = GetEntityFlags(client);
	if(flag & FL_ONGROUND)
	{
		Stop(client);
		return;
	}
	
	int button = GetClientButtons(client);
	if((!GetEntProp(client, Prop_Send, "m_isGhost") && (button & IN_USE)) || (GetEntProp(client, Prop_Send, "m_isGhost", 1) && (button & IN_DUCK)))
	{ 
		Start(client); 
	}
	
	float time = GetEngineTime();
	if(time > JumpTime[client] + 1.0)
	{ return; }
	
	float pos[3];
	GetClientAbsOrigin(client, pos);
	StuckIndicator[client] += GetVectorDistance(pos, LastPos[client]);
	
	CopyVector(pos, LastPos[client]);
	if(time > JumpTime[client] + 0.5 && StuckIndicator[client] < 10.0)
	{
		TeleportEntity(client, SafePos[client], NULL_VECTOR, NULL_VECTOR); 
		PrintHintText(client, "You were stuck!");
		Stop(client);
	} 
}

void Climb(int client, float interval)
{
	int clone = Clone[client];
	if(IsValidEntityAndNotWorld(clone))
	{
		SetEntProp(client, Prop_Send, "m_iAddonBits", 0);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
		
		float colonPos[3];
		float clientPos[3];
		float bodyPos[3]; 
		float headOffset[3]; 
		float footOffset[3];
		float bodyTouchPos[3];
		float headTouchPos[3];
		float footTouchPos[3];			
		float moveDir[3];    
		float cloneAnge[3];
		float bodyNormal[3];
		float eyeNormal[3];
		float footNormal[3];
		float normal[3];
		float temp[3];
		float up[3];
		
		SetVector(up, 0.0, 0.0, 1.0); 
		int button = GetClientButtons(client);
		SetEntityMoveType(client, MOVETYPE_NONE); 
		
		float playrate = 0.0;	
		bool needprocess = false;
		bool moveforward;
		bool moveback;
		
		if(button & IN_FORWARD)
		{
			needprocess = true; 
			moveforward = true;
		}
		else if(button & IN_BACK)
		{
			needprocess = true; 
			moveback = true;
		}
		
		if(button & IN_MOVELEFT)
		{
			Angle[client] += interval * 90.0;
			playrate = PlayBackRate[client] * 0.5;
			needprocess = true;
		}
		else if(button & IN_MOVERIGHT)
		{
			Angle[client] -= interval * 90.0;
			playrate = PlayBackRate[client] * 0.5;
			needprocess = true;
		}
		
		if(button & IN_JUMP || button & IN_ATTACK || button & IN_ATTACK2)
		{
			Jump(client);
			return;
		}
 
		while(needprocess || FirstRun[client])
		{
			FirstRun[client] = false;
			
			CopyVector(BodyPos[client], bodyPos);  
			CopyVector(BodyNormal[client], normal);
			CopyVector(normal, cloneAnge);
			
			ScaleVector(cloneAnge, -1.0);
			GetVectorAngles(cloneAnge, cloneAnge);
			
			cloneAnge[2] = 0.0 - Angle[client]; 
			
			float f = GetAngle(BodyNormal[client], up) * 180 / Pie;
			if(f < 10.0 || f > 170.0)
			{
				Jump(client, false, 0.0);
				return;
			}
			
			SetVector(headOffset, 0.0, 0.0, 1.0); 
			GetProjection(normal, up, headOffset);
			
			RotateVector(normal, headOffset, AngleCovert(Angle[client]), headOffset); 
			CopyVector(headOffset, footOffset);
			
			NormalizeVector(headOffset, headOffset);
			NormalizeVector(footOffset, footOffset);
			
			ScaleVector(footOffset, 0.0 - bodylength * 0.5);
			ScaleVector(headOffset, bodylength * 0.5);
			
			AddVectors(bodyPos, headOffset, headTouchPos);
			AddVectors(bodyPos, footOffset, footTouchPos);
			
			bool b = GetRaySimple(client, headTouchPos, footTouchPos, temp);
			if(b)
			{
				break;
			}
			
			CopyVector(footTouchPos, colonPos);
			
			float disBody = GetRay(client, bodyPos, cloneAnge, bodyTouchPos, bodyNormal, 0.0 - BodyWidth[client]);  
			float disHead = GetRay(client, headTouchPos, cloneAnge, headTouchPos, eyeNormal, 0.0 - BodyWidth[client]);  
			float disFoot = GetRay(client, footTouchPos, cloneAnge, footTouchPos, footNormal, 0.0 - BodyWidth[client]);  
			if(disBody > BodyWidth[client] * 2.0)
			{
				Jump(client, false, 50.0);				 
				return;
			}
			
			bool needrotatenormal = false;
			if(disHead > BodyWidth[client])
			{
				disHead = BodyWidth[client];
				needrotatenormal = true;
			}
			
			if(disFoot > BodyWidth[client])
			{
				disFoot = BodyWidth[client];
				needrotatenormal = true;
			}
			
			float ft = disHead - disFoot;
			if(needrotatenormal)
			{
				ft = ArcSine(ft/SquareRoot(ft * ft + bodylength * 0.5 * bodylength * 0.5));
				GetVectorCrossProduct(bodyNormal, headOffset, temp); 
				RotateVector(temp, normal, ft * 0.5, normal); 
				CopyVector(normal, normal);
			}
			else
			{
				CopyVector(bodyNormal, normal);
			}
			
			CopyVector(headOffset ,moveDir);
			NormalizeVector(moveDir, moveDir); 
			ScaleVector(moveDir, ClimbSpeed[client] * interval);  
			
			CopyVector(bodyTouchPos, bodyPos); 
			
			if(moveforward)
			{
				playrate=PlayBackRate[client]; 
				AddVectors(colonPos, moveDir, colonPos);
				AddVectors(bodyPos, moveDir, bodyPos);
			}
			else if(moveback)
			{
				playrate = 0.0 - PlayBackRate[client];
				
				SubtractVectors(colonPos, moveDir, colonPos);
				SubtractVectors(bodyPos, moveDir, bodyPos);
			}
			
			CopyVector(bodyPos, clientPos);
			clientPos[2] -= bodylength * 0.5;
			
			TeleportEntity(client, clientPos, NULL_VECTOR, NULL_VECTOR); 
			TeleportEntity(clone, colonPos, cloneAnge, NULL_VECTOR);
			
			CopyVector(bodyPos, BodyPos[client]);  
			CopyVector(normal, BodyNormal[client]);
			
			break;
		}
		if (IsValidEntityAndNotWorld(clone))
		SetEntPropFloat(clone, Prop_Send, "m_flPlaybackRate", playrate);
	}
	else
	{
		Stop(client);
	}
}

void GetModelInfo(const char[] model, float& speedvalue, float& playbackrate, float& bodywidth)
{	
	int speed = 0;
	float S = 0.0;
	bodywidth = gbodywidth;
	if(StrContains(model, "survivor_teenangst") != -1)
	{
		speed = ZOMBIECLASS_SURVIVOR; 
		S = 30.0;
	}
	else if(StrContains(model, "survivor_manager") != -1)
	{
		speed = ZOMBIECLASS_SURVIVOR; 
		S = 30.0;
	}
	else if(StrContains(model, "survivor_namvet") != -1)
	{
		speed = ZOMBIECLASS_SURVIVOR; 
		S = 30.0;
	}
	else if(StrContains(model, "survivor_biker") != -1)
	{
		speed = ZOMBIECLASS_SURVIVOR;
		S = 30.0;
	}
	else if(StrContains(model, "gambler") != -1)
	{
		speed = ZOMBIECLASS_SURVIVOR;
		S = 30.0;
	}
 	else if(StrContains(model, "producer") != -1)
	{
		speed = ZOMBIECLASS_SURVIVOR;
		S = 30.0;
	}
	else if(StrContains(model, "coach") != -1)
	{
		speed = ZOMBIECLASS_SURVIVOR;
		S = 30.0;
	}
 	else if(StrContains(model, "mechanic") != -1)
	{
		speed = ZOMBIECLASS_SURVIVOR;
		S = 30.0;
	}
	else if(StrContains(model, "hulk") != -1 || StrContains(model, "fs_glowtank") != -1)
	{
		speed = ZOMBIECLASS_TANK; 
		if(L4D2Version)
		{ S = 50.0; }
		else
		{ S = 70.0; }
	}
	else if(StrContains(model, "hunter") != -1)
	{
		speed = ZOMBIECLASS_HUNTER;
		S = 70.0;
	}
	else if(StrContains(model, "smoker") != -1)
	{
		speed = ZOMBIECLASS_SMOKER;
		S = 70.0;
		bodywidth = 25.0;
	}
	else if(StrContains(model, "boomette") != -1)
	{
		speed = ZOMBIECLASS_BOOMER;
		S = 50.0;
	}
	else if(StrContains(model, "boomer") != -1) 
	{
		speed = ZOMBIECLASS_BOOMER; 
		S = 60.0;
	}
 	else if(StrContains(model, "jockey") != -1)
	{
		speed = ZOMBIECLASS_JOCKEY;
		S = 60.0;
	}
	else if(StrContains(model, "spitter") != -1)
	{
		speed = ZOMBIECLASS_SPITTER;
		S = 70.0;
	}
	else if(StrContains(model, "charger") != -1)
	{
		speed = ZOMBIECLASS_CHARGER;
		S = 70.0;
		bodywidth = 25.0;
	}
	
	speedvalue = GetConVarFloat(l4d_climb_speed[speed]) * GetConVarFloat(l4d_climb_speed[0]);
	playbackrate = 1.0 + (speedvalue - S) / S;
}

int CreateClone(int client)
{
	float vAngles[3];
	float vOrigin[3];
	GetClientAbsOrigin(client, vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	char playerModel[42]; 
	GetEntPropString(client, Prop_Data, "m_ModelName", playerModel, sizeof(playerModel));
	if (!IsModelPrecached(playerModel))
	{ PrecacheModel(playerModel); }
	
	GetModelInfo(playerModel, ClimbSpeed[client], PlayBackRate[client], BodyWidth[client]);
	int clone = 0;
	if (IsSurvivor(client))
	{
		clone = CreateEntityByName("commentary_dummy");
	}
	else
	{ clone = CreateEntityByName("prop_dynamic_override"); }
	if(IsValidEntity(clone))
	{
		SetEntityModel(clone, playerModel);
		
		float vPos[3]; float vAng[3];
		vPos[0] = -0.0; 
		vPos[1] = -0.0;
		vPos[2] = -30.0;
		
		vAng[2] = -90.0;
		vAng[0] = -90.0;
		vAng[1] = 0.0;
		
		TeleportEntity(clone,  vOrigin, vAngles, NULL_VECTOR);
		
		DispatchKeyValue(clone, "solid", "0");
		if (IsSurvivor(client))
		{ SetEntProp(clone, Prop_Send, "m_bClientSideAnimation", 1); }
		DispatchSpawn(clone);
		ActivateEntity(clone);
		
		SetVariantString(ACT_CLIMB_UP);
		AcceptEntityInput(clone, "SetDefaultAnimation");
		SetVariantString(ACT_CLIMB_UP);
		AcceptEntityInput(clone, "SetAnimation");
		
		SetEntPropFloat(clone, Prop_Send, "m_flPlaybackRate", 1.0);
		SetEntPropFloat(clone, Prop_Send, "m_fadeMinDist", 10000.0); 
		SetEntPropFloat(clone, Prop_Send, "m_fadeMaxDist", 20000.0); 
		
		if(L4D2Version && IsSurvivor(client))
		{
			SetEntProp(clone, Prop_Send, "m_iGlowType", 3);
			SetEntProp(clone, Prop_Send, "m_nGlowRange", 0);
			SetEntProp(clone, Prop_Send, "m_nGlowRangeMin", 600);
			
			int red = 0;
			int gree = 151;
			int blue = 0;
			
			SetEntProp(clone, Prop_Send, "m_glowColorOverride", red + (gree * 256) + (blue * 65536)); 
		}
	}
	return clone;
}

void SaveWeapon(int client)
{ 
	client = client + 1;
}

void RestoreWeapon(int client)
{ 
	client = client + 1;
}

bool IsInfected(int client)
{
	if (!IsValidClient(client)) return false;
	if (GetClientTeam(client) == 3) return true;
	return false;
}

bool IsSurvivor(int client)
{
	if (!IsValidClient(client)) return false;
	if (GetClientTeam(client) == 2 || (L4D2Version && GetClientTeam(client) == 4)) return true;
	return false;
}

bool IsValidClient(int client, bool replaycheck = true)
{
	//if (!IsValidEntity(client)) return false;
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	//if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	if (replaycheck)
	{
		if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	}
	return true;
}

void VisiblePlayer(int client, bool visible = true)
{
	if(visible)
	{
		SetEntityRenderMode(client, RENDER_NORMAL);
		SetEntityRenderColor(client, 255, 255, 255, 255);		 
	}
	else
	{
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, 0, 0, 0, 0);
	} 
}

float RayVec[3];

bool GetRaySimple(int client, float pos1[3], float pos2[3], float hitpos[3])
{
	Handle trace;
	bool hit = false;  
	trace = TR_TraceRayFilterEx(pos1, pos2, MASK_SOLID, RayType_EndPoint, DontHitCloneAndOxygenTank, client); 
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(hitpos, trace); 
		hit = true;
	}
	CloseHandle(trace); 
	return hit;
}

float GetRay(int client, float pos[3], float angle[3], float hitpos[3], float normal[3], float offset = 0.0)
{
	Handle trace;
	float ret = 9999.0;
	trace = TR_TraceRayFilterEx(pos, angle, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelfAndClone, client); 
	if(TR_DidHit(trace))
	{			
		CopyVector(pos, RayVec);
		TR_GetEndPosition(hitpos, trace);
		TR_GetPlaneNormal(trace, normal);
		NormalizeVector(normal, normal); 
		if(offset != 0.0)
		{
			float t[3];
			GetAngleVectors(angle, t, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(t, t);
			ScaleVector(t, offset);
			AddVectors(hitpos, t, hitpos); 
		}
		ret = GetVectorDistance(RayVec, hitpos);
	}
	CloseHandle(trace); 
	return ret;
}

void CopyVector(float source[3], float target[3])
{
	target[0] = source[0];
	target[1] = source[1];
	target[2] = source[2];
}

void SetVector(float target[3], float x, float y, float z)
{
	target[0] = x;
	target[1] = y;
	target[2] = z;
}

/*bool DontHitSelf(int entity, int mask, any data)
{
	if(entity == data) 
	{
		return false; 
	}
	return true;
}*/

float AngleCovert(float angle)
{
	return angle / 180.0 * Pie;
}

float GetAngle(float x1[3], float x2[3])
{
	return ArcCosine(GetVectorDotProduct(x1, x2) / (GetVectorLength(x1) * GetVectorLength(x2)));
}

void GetProjection(float n[3], float t[3], float r[3])
{
	float A = n[0];
	float B = n[1];
	float C = n[2];
	
	float a = t[0];
	float b = t[1];
	float c = t[2];
	
	float p = -1.0 * (A * a + B * b + C * c) / (A * A + B * B + C * C);
	r[0] = A * p + a;
	r[1] = B * p + b;
	r[2] = C * p + c;
}

void RotateVector(float direction[3], float vec[3], float alfa, float result[3])
{
   	float v[3];
	CopyVector(vec, v);
	
	float u[3];
	CopyVector(direction, u);
	NormalizeVector(u, u);
	
	float uv[3];
	GetVectorCrossProduct(u, v, uv);
	
	float sinuv[3];
	CopyVector(uv, sinuv);
	ScaleVector(sinuv, Sine(alfa));
	
	float uuv[3];
	GetVectorCrossProduct(u, uv, uuv);
	ScaleVector(uuv, 2.0 * Pow(Sine(alfa * 0.5), 2.0));	
	
	AddVectors(v, sinuv, result);
	AddVectors(result, uuv, result);
}

void GameCheck()
{
	char GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	if (StrEqual(GameName, "survival", false))
	{
		GameMode = 3;
	}
	else if (StrEqual(GameName, "versus", false) || StrEqual(GameName, "teamversus", false) || StrEqual(GameName, "scavenge", false) || StrEqual(GameName, "teamscavenge", false))
	{
		GameMode = 2;
	}
	else if (StrEqual(GameName, "coop", false) || StrEqual(GameName, "realism", false))
	{
		GameMode = 1;
	}
	else
	{
		GameMode = 0;
 	}
	
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrEqual(GameName, "left4dead2", false))
	{
		ZOMBIECLASS_TANK = 8;
		L4D2Version = true;
	}	
	else
	{
		ZOMBIECLASS_TANK = 5;
		L4D2Version = false;
	}
}
 
bool TraceRayDontHitSelfAndClone(int entity, int mask, any data)
{
	if(entity == data) 
	{
		return false; 
	}
	else if(data >= 1 && data <= MaxClients)
	{
		if(entity == Clone[data])
		{
			return false; 
		}
	}
	
	return true;
}

char g_classname[64];

bool DontHitCloneAndOxygenTank(int entity, int mask, any data)
{
	if(entity == data) 
	{
		return false; 
	}
	else if(data >= 1 && data <= MaxClients)
	{
		if(entity == Clone[data])
		{
			return false; 
		}
	}
	
	if(IsValidEdict(entity))
	{
		GetEdictClassname(entity, g_classname, sizeof(g_classname));
		if(StrEqual(g_classname, "prop_physics"))
		{
			GetEntPropString(entity, Prop_Data, "m_ModelName", g_classname, sizeof(g_classname));			
			if(StrEqual(g_classname, "models/props_equipment/oxygentank01.mdl"))
			{
				return false;
			}
		}
	}
	
	return true;
}

Action ShowInfo(Handle timer, int client)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	if(L4D2Version)
	{ DisplayHint(client); }
	else
	{ PrintToChat(client, "\x03Press \x04E \x0To \x04Climb \x03On A Surface!"); }
	
	return Plugin_Stop;
}

Action DisplayHint(int client)
{
	ClientCommand(client, "gameinstructor_enable 1");
	
	CreateTimer(1.0, DelayDisplayHint, client);
	
	return Plugin_Stop;
}

Action DelayDisplayHint(Handle timer, int client)
{
	DisplayInstructorHint(client, "while jumping toward a wall to climb!", "+use");
	return Plugin_Stop;
}

void DisplayInstructorHint(int client, char s_Message[256], char[] s_Bind)
{
	char s_TargetName[32];
	
	int hint = CreateEntityByName("env_instructor_hint");
	FormatEx(s_TargetName, sizeof(s_TargetName), "hint%d", client);
	ReplaceString(s_Message, sizeof(s_Message), "\n", " ");
	if (IsValidClient(client))
	{ DispatchKeyValue(client, "targetname", s_TargetName); }
	DispatchKeyValue(hint, "hint_target", s_TargetName);
	DispatchKeyValue(hint, "hint_timeout", "5");
	DispatchKeyValue(hint, "hint_range", "0.01");
	DispatchKeyValue(hint, "hint_color", "255 255 255");
	DispatchKeyValue(hint, "hint_icon_onscreen", "use_binding");
	DispatchKeyValue(hint, "hint_caption", s_Message);
	DispatchKeyValue(hint, "hint_binding", s_Bind);
	DispatchSpawn(hint);
	AcceptEntityInput(hint, "ShowHint");
	
	Handle pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, hint);
	CreateTimer(5.0, RemoveInstructorHint, pack);
}
	
Action RemoveInstructorHint(Handle timer, DataPack pack)
{
	ResetPack(pack, false);
	int client = ReadPackCell(pack);
	int hint = ReadPackCell(pack);
	if (pack != null)
	{ CloseHandle(pack); }
	
	if (!client || !IsValidClient(client))
	{ return Plugin_Stop; }
	
	if (IsValidEntity(hint))
	{ AcceptEntityInput(hint, "kill"); }
	
	ClientCommand(client, "gameinstructor_enable 0");
	
	DispatchKeyValue(client, "targetname", "");
	
	return Plugin_Stop;
}

bool IsValidEntityAndNotWorld(int entity)
{
	if (!IsValidEntity(entity)) return false;
	if (entity <= 0) return false;
	return true;
}

void GotoThirdPerson(int client)
{
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
}

void GotoFirstPerson(int client)
{
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
}

