/*
v0.0.1	- small HP bug during trying to break free from SI.
v0.0.2	- fixed required item to break free is not working when message is turning off.
v0.0.3	- break free and get up message is separated.
		- added Special Infected dead check.
		- added pounce_end event check.
		- add check to prevent player to get up if close to tank.
		- add cvar on last life color.
		- add cvar update upon cvar changed.
		- code clean up.
*/

#define PLUGIN_VERSION	"0.0.3"
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

public Plugin myinfo = 
{
	name			= "[L4D, L4D2] Self Get Up",
	author			= " GsiX ",
	description		= "Self help from incap, ledge grabs, and break free from infected attacks",
	version			= PLUGIN_VERSION,
	url				= "https://forums.alliedmods.net/showthread.php?t=195623"	
}

#define	PLUGIN_FCVAR		FCVAR_NOTIFY|FCVAR_SPONLY
#define GAME_DATA			"l4d2_selfstandup"
#define SOUND_KILL1			"/weapons/knife/knife_hitwall1.wav"
#define SOUND_KILL2			"/weapons/knife/knife_deploy.wav"
#define SOUND_HEART_BEAT	"player/heartbeatloop.wav"
#define SOUND_GETUP			"ui/bigreward.wav"
#define SOUND_ERROR			"ui/beep_error01.wav"

#define INCAP				1
#define INCAP_LEDGE			2

#define STATE_NONE			0
#define STATE_SELFGETUP		1

#define NONE_F				0.0
#define NONE				0
#define SMOKER				1
#define HUNTER				3
#define JOCKEY				5
#define CHARGER				6
#define TANK				8

ConVar selfstandup_enable, selfstandup_blackwhite, selfstandup_kill, selfstandup_health_incap, selfstandup_duration;
ConVar selfstandup_crawl, selfstandup_crawl_speed, selfstandup_message, selfstandup_costly, selfstandup_costly_item;
ConVar selfstandup_clearance, selfstandup_teamdistance, selfstandup_color;
ConVar selfstandup_enable_incap_pickup, selfstandup_incap_pickup_distance, selfstandup_incap_pickup_scavenge_item;
bool g_bIsOnUse[MAXPLAYERS + 1];

Handle Timers[MAXPLAYERS + 1]			= { null, ... };
float ReviveHealthBuff[MAXPLAYERS + 1]	= { 0.0, ... };
int TeamHealth[MAXPLAYERS + 1]			= { 0, ... };
float TeamHealthBuff[MAXPLAYERS + 1]	= { 0.0, ... };
float StartTime[MAXPLAYERS + 1]			= { 0.0, ... };
float Duration[MAXPLAYERS + 1]			= { 0.0, ... };
bool Restart[MAXPLAYERS + 1]			= { false, ... };
bool Button[MAXPLAYERS + 1]				= { false, ... };
int RevHelper[MAXPLAYERS + 1]			= { 0, ... };
int Attacker[MAXPLAYERS + 1]			= { 0, ... };
int HelpState[MAXPLAYERS + 1]			= { 0, ... };
int ReviveHealth[MAXPLAYERS + 1]		= { 0, ... };
int TargetTeam[MAXPLAYERS + 1]			= { 0, ... };
int RevCount[MAXPLAYERS + 1]			= { 0, ... };
int PlayerWeaponSlot[MAXPLAYERS + 1]	= { -1, ... };
char Gauge1[2] = "-";
char Gauge3[2] = "#";

bool g_Pills							= false;
bool g_Adrenaline						= false;
bool g_Med_Kit							= false;
bool g_Defibrillator					= false;
bool g_Incendiary						= false;
bool g_Explosive						= false;
bool UseAdrenKill[MAXPLAYERS + 1]       = {false, ...};
bool g_selfstandup_enable_incap_pickup  = false;

int g_enable							= 0;
int g_blackwhite						= 0;
int g_kill								= 0;
float g_health_incap					= 0.0;
float g_duration						= 0.0;
int g_message							= 0;
int g_costly							= 0;
char g_costly_item[256]					= " ";
float g_clearance						= 0.0;
float g_teamdistance					= 0.0;
int g_lastlifecolor						= 0;
float g_selfstandup_incap_pickup_distance;
int g_selfstandup_incap_pickup_scavenge_item;

public void OnPluginStart()
{
	CreateConVar("selfstandup_version", PLUGIN_VERSION, "Self Get Up plugin version", PLUGIN_FCVAR|FCVAR_DONTRECORD);
	selfstandup_enable			= CreateConVar("selfstandup_enable",			"1",		"是否启用自救插件？0=关闭 1=开启", PLUGIN_FCVAR);
	selfstandup_blackwhite		= CreateConVar("selfstandup_max",				"3",		"设置玩家倒地几次后黑白(限制 小于 1 关闭: 9999 或 其他)", PLUGIN_FCVAR);
	selfstandup_kill			= CreateConVar("selfstandup_kill",				"1",		"自救后是否杀死特殊感染者 0=否 1=是", PLUGIN_FCVAR);	
	selfstandup_health_incap	= CreateConVar("selfstandup_health_incap",		"100.0",		"倒地自救后有多少临时血量.", PLUGIN_FCVAR);
	selfstandup_duration		= CreateConVar("selfstandup_duration",			"2.0",		"自救所需时间(限制：0 ~ 5秒之间 )", PLUGIN_FCVAR);
	selfstandup_crawl			= CreateConVar("selfstandup_crawl",				"1",		"玩家是否可在倒地时爬行？0=关闭 1=开启)", PLUGIN_FCVAR);
	selfstandup_crawl_speed		= CreateConVar("selfstandup_crawl_speed",		"50",		"设置玩家倒地时爬行速度", PLUGIN_FCVAR);
	selfstandup_message			= CreateConVar("selfstandup_message",			"1",		"是否启用聊天通知？0=关闭 1=开启", PLUGIN_FCVAR);
	selfstandup_costly			= CreateConVar("selfstandup_costly",			"1",		"玩家自救是否需要消耗物品？0=不消耗 1=消耗", PLUGIN_FCVAR);
	selfstandup_costly_item		= CreateConVar("selfstandup_costly_item",		"med_kit,pills,adrenaline",	"自救时可消耗的物品清单, '物品清单' 必须填写括号内的字符(med_kit, pills, adrenaline, defibrillator, incendiary, explosive)", PLUGIN_FCVAR);
	selfstandup_clearance		= CreateConVar("selfstandup_clearance",			"0",	"多大范围内有感染者不能自救 最大半径扫描范围 0=关闭 最高200");", PLUGIN_FCVAR);
	selfstandup_teamdistance	= CreateConVar("selfstandup_teamdistance",		"100.0",	"倒地玩家允许拉起倒地队友的最大距离 0=关闭 最高200)", PLUGIN_FCVAR);
	selfstandup_color			= CreateConVar("selfstandup_color",				"0",		"0: 关闭,   1: 开启, 是否设置玩家黑白的颜色", PLUGIN_FCVAR);

	selfstandup_enable_incap_pickup	= CreateConVar("selfstandup_enable_incap_pickup", "1", "是否设置玩家倒地可拾取物品？0=关闭 1=开启", PLUGIN_FCVAR);
	selfstandup_incap_pickup_distance = CreateConVar("selfstandup_incap_pickup_distance", "101.8", "倒地拾取物品的范围", PLUGIN_FCVAR);
	selfstandup_incap_pickup_scavenge_item = CreateConVar("selfstandup_incap_pickup_scavenge_item", "0", "0:禁用倒地拾取物品，1:允许拾取汽油，2:允许拾取可乐，3:全部", PLUGIN_FCVAR);

	LoadTranslations("l4d2_Self_Get_Up.phrases");
	AutoExecConfig( true, GAME_DATA );
	
	HookEvent( "lunge_pounce",					EVENT_LungePounce );
	HookEvent( "pounce_stopped",				EVENT_PounceStopped );
	HookEvent( "pounce_end",					EVENT_PounceStopped );
	HookEvent( "tongue_grab",					EVENT_TongueGrab ); //
	HookEvent( "choke_start",					EVENT_TongueGrab );
	HookEvent( "tongue_release",				EVENT_TongueRelease );
	HookEvent( "jockey_ride",					EVENT_JockeyRide );
	HookEvent( "jockey_ride_end",				EVENT_JockeyRideEnd );
	HookEvent( "charger_pummel_start",			EVENT_ChargerPummelStart );
	HookEvent( "charger_pummel_end",			EVENT_ChargerPummelEnd );
	HookEvent( "player_hurt",					EVENT_PlayerHurt );
	HookEvent( "player_death",					EVENT_PlayerDeath );
	HookEvent( "heal_success",					EVENT_HealSuccess );
	HookEvent( "round_start",					EVENT_RoundStart );
	HookEvent( "player_spawn",					EVENT_PlayerSpawn );
	HookEvent( "survivor_rescued",				EVENT_PlayerSpawn );
	HookEvent( "player_incapacitated",			EVENT_PlayerIncapacitated );
	HookEvent( "player_ledge_grab",				EVENT_PlayerIncapacitated );
	HookEvent( "revive_begin",					EVENT_ReviveBegin );
	HookEvent( "revive_end",					EVENT_ReviveEnd );
	HookEvent( "revive_success",				EVENT_ReviveSuccess );
	HookEvent( "pills_used",					EVENT_PillsUsed );
	HookEvent( "adrenaline_used",				EVENT_PillsUsed );

	selfstandup_enable.AddChangeHook(bw_CVARChanged);
	selfstandup_blackwhite.AddChangeHook(bw_CVARChanged);
	selfstandup_kill.AddChangeHook(bw_CVARChanged);
	selfstandup_health_incap.AddChangeHook(bw_CVARChanged);
	selfstandup_health_incap.AddChangeHook(bw_CVARChanged);
	selfstandup_duration.AddChangeHook(bw_CVARChanged);
	selfstandup_message.AddChangeHook(bw_CVARChanged);
	selfstandup_costly.AddChangeHook(bw_CVARChanged);
	selfstandup_costly_item.AddChangeHook(bw_CVARChanged);
	selfstandup_teamdistance.AddChangeHook(bw_CVARChanged);
	selfstandup_enable_incap_pickup.AddChangeHook(bw_CVARChanged);
	selfstandup_incap_pickup_distance.AddChangeHook(bw_CVARChanged);
	selfstandup_incap_pickup_scavenge_item.AddChangeHook(bw_CVARChanged);
}

void UdateCvarChange()
{
	g_enable			= selfstandup_enable.IntValue;
	g_blackwhite		= selfstandup_blackwhite.IntValue;
	g_kill				= selfstandup_kill.IntValue;
	g_health_incap		= selfstandup_health_incap.FloatValue;
	g_duration			= selfstandup_duration.FloatValue;
	g_message			= selfstandup_message.IntValue;
	g_costly			= selfstandup_costly.IntValue;
	g_clearance			= selfstandup_clearance.FloatValue;
	g_teamdistance		= selfstandup_teamdistance.FloatValue;
	g_lastlifecolor		= selfstandup_color.IntValue;
	g_selfstandup_enable_incap_pickup = selfstandup_enable_incap_pickup.BoolValue;
	g_selfstandup_incap_pickup_distance = selfstandup_incap_pickup_distance.FloatValue;
	g_selfstandup_incap_pickup_scavenge_item = selfstandup_incap_pickup_scavenge_item.IntValue;

	if ( g_clearance > 200.0 )
	{
		g_clearance = 200.0;
	}
	if ( g_teamdistance > 200.0 )
	{
		g_teamdistance = 200.0;
	}
	selfstandup_costly_item.GetString(g_costly_item, sizeof(g_costly_item));

	FindConVar("survivor_max_incapacitated_count").SetInt(g_blackwhite);
	FindConVar("survivor_revive_health").SetFloat(g_health_incap);
	FindConVar("survivor_allow_crawling").SetInt(selfstandup_crawl.IntValue);
	FindConVar("survivor_crawl_speed").SetInt(selfstandup_crawl_speed.IntValue);
	FindConVar("z_grab_ledges_solo").SetInt(1);

	if ( g_duration > 0.0 )
	{
		FindConVar("survivor_revive_duration").SetFloat(g_duration);
	}
}

public void OnMapStart()
{
	PrecacheSound( SOUND_KILL2, true );
	PrecacheSound( SOUND_HEART_BEAT, true );
	PrecacheSound( SOUND_GETUP, true );
	PrecacheSound( SOUND_ERROR, true );
	UdateCvarChange();
}

public void OnClientDisconnect( int client )
{
	if ( client > NONE && client <= MaxClients )
	{
		Restart[client] = true;
		g_bIsOnUse[client] = false;
	}
}

public void bw_CVARChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	UdateCvarChange();
}

public void EVENT_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsValidSurvivor( i ))
		{
			Timers[i]			= null;
			Attacker[i]			= NONE;
			HelpState[i]		= NONE;
			RevHelper[i]		= NONE;
			RevCount[i]			= NONE;
			TargetTeam[i]		= NONE;
			PlayerWeaponSlot[i]	= -1;
			Restart[i]			= false;
			Button[i]			= false;
		}
	}
	UdateCvarChange();
}

public void EVENT_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	FindConVar("survivor_allow_crawling").SetInt(NONE);
	FindConVar("survivor_crawl_speed").SetInt(15);
}

public void EVENT_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int client = GetClientOfUserId( event.GetInt( "userid" ));
	if ( IsValidSurvivor( client ))
	{
		GetClientHP( client );
		Attacker[client]			= NONE;
		RevCount[client]			= NONE;
		RevHelper[client]			= NONE;
		TargetTeam[client]			= NONE;
		PlayerWeaponSlot[client]	= -1;
		TeamHealth[client]			= NONE;
		TeamHealthBuff[client]		= NONE_F;
		Restart[client]				= false;
		Button[client]				= false;

		CreateTimer( 30.0, Timer_Hint, client );
	}
}

public void EVENT_TongueGrab (Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim		= GetClientOfUserId( event.GetInt( "victim" ));
	int attacker	= GetClientOfUserId( event.GetInt( "userid" ));
	if ( IsValidSurvivor( victim ))
	{
		Attacker[victim] = attacker;
		if(Timers[victim])
		{
			Restart[victim] = true;
		}
	}
}

public void EVENT_TongueRelease (Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim		= GetClientOfUserId( event.GetInt( "victim" ));
	if ( victim > NONE && victim <= MaxClients )
	{
		Attacker[victim] = NONE;
	}
}

public void EVENT_LungePounce (Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim		= GetClientOfUserId( event.GetInt( "victim" ));
	int attacker	= GetClientOfUserId( event.GetInt( "userid" ));
	if ( IsValidSurvivor( victim ))
	{
		Attacker[victim] = attacker;
		if(Timers[victim])
		{
			Restart[victim] = true;
		}
	}
}

public void EVENT_PounceStopped (Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim		= GetClientOfUserId( event.GetInt( "victim" ));
	if ( victim > NONE && victim <= MaxClients )
	{
		Attacker[victim] = NONE;
	}
}

public void EVENT_JockeyRide (Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim		= GetClientOfUserId( event.GetInt( "victim" ));
	int attacker	= GetClientOfUserId( event.GetInt( "userid" ));
	if ( IsValidSurvivor( victim ))
	{
		Attacker[victim] = attacker;
		if(Timers[victim])
		{
			Restart[victim] = true;
		}
	}
}

public void EVENT_JockeyRideEnd (Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim		= GetClientOfUserId( event.GetInt( "victim" ));
	if ( victim > NONE && victim <= MaxClients )
	{
		Attacker[victim] = NONE;
	}
}

public void EVENT_ChargerPummelStart (Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim		= GetClientOfUserId( event.GetInt( "victim" ));
	int attacker	= GetClientOfUserId( event.GetInt( "userid" ));
	if ( IsValidSurvivor( victim ))
	{
		Attacker[victim] = attacker;
		if(Timers[victim])
		{
			Restart[victim] = true;
		}
	}
}

public void EVENT_ChargerPummelEnd (Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim	= GetClientOfUserId( event.GetInt( "victim" ));
	if ( victim > NONE && victim <= MaxClients )
	{
		Attacker[victim] = NONE;
	}
}

public void EVENT_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim = GetClientOfUserId( event.GetInt( "userid" ));
	if ( IsValidSurvivor( victim ))
	{
		if(Timers[victim])
		{
			Restart[victim] = true;
		}
	}
}

public void EVENT_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim = GetClientOfUserId( event.GetInt( "userid" ));
	if ( IsValidSurvivor( victim ))
	{
		GetClientHP( victim );
		if ( GetEntProp( victim, Prop_Send, "m_bIsOnThirdStrike" ) < 1 )
		{
			StopSound( victim, SNDCHAN_AUTO, SOUND_HEART_BEAT );
			if ( g_lastlifecolor > NONE )
			{
				SetEntityRenderMode( victim, RENDER_TRANSCOLOR);
				SetEntityRenderColor( victim, 255, 255, 255, 255 );
			}
		}
	}
}

public void EVENT_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim = GetClientOfUserId( event.GetInt( "subject" ));
	if ( IsValidSurvivor( victim ))
	{
		GetClientHP( victim );
		CreateTimer( 0.2, ResetReviveCount, victim );

		RevCount[victim] = GetEntProp( victim, Prop_Send, "m_currentReviveCount" );
		if ( !IsFakeClient( victim ) && g_message > NONE )
		{
			CPrintToChat( victim, "%t", "[GETUP]: %d of %d", RevCount[victim], g_blackwhite );
		}
	}
}

public void EVENT_ReviveBegin(Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim		= GetClientOfUserId( event.GetInt( "subject" ));
	int helper		= GetClientOfUserId( event.GetInt( "userid" ));
	if ( IsValidSurvivor( victim ))
	{
		if ( helper != victim && ( !IsNo_Incap( victim ) || !IsNo_IncapLedge( victim )))
		{
			RevHelper[victim] = helper;
		}
	}
}

public void EVENT_ReviveEnd(Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim = GetClientOfUserId( event.GetInt( "subject" ));
	if ( victim > NONE && victim <= MaxClients )
	{
		RevHelper[victim] = NONE;
	}
}

public void EVENT_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim = GetClientOfUserId( event.GetInt( "subject" ));
	int helper = GetClientOfUserId( event.GetInt( "userid" ));

	if ( IsValidSurvivor( victim ))
	{
		if ( RevHelper[victim] < 1 )
		{
			if ( event.GetBool(  "ledge_hang" ) == false )
			{
				RevCount[victim] += 1;
			}
		}
		else
		{
			if ( event.GetBool(  "ledge_hang" ) == false )
			{
				RevCount[victim]	= GetEntProp( victim, Prop_Send, "m_currentReviveCount" );
			}

			if ( GetEntProp( victim, Prop_Send, "m_bIsOnThirdStrike" ) > NONE )
			{
				if ( g_lastlifecolor > NONE )
				{
					SetEntityRenderMode( victim, RENDER_TRANSCOLOR );
					SetEntityRenderColor( victim, 128, 255, 128, 255 );
				}
				if ( g_message > NONE )
				{
					CPrintToChatAll("%t", "[GETUP]: %N on last life!!", victim );
				}
			}
			else
			{
				if ( g_message > NONE )
				{
					CPrintToChat( victim, "%t", "[GETUP]: %d of %d, revived by %N", RevCount[victim], g_blackwhite, helper );
				}
			}
		}
	}
	RevHelper[victim] = NONE;
}

public void EVENT_PillsUsed(Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int userid = GetClientOfUserId( event.GetInt( "userid" ));
	if ( IsValidSurvivor( userid ))
	{
		GetClientHP( userid );
	}
}

public void EVENT_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if ( g_enable == NONE ) return;
	int victim = GetClientOfUserId( event.GetInt( "userid" ));
	if ( victim > NONE && victim <= MaxClients )
	{
		if ( IsClientConnected( victim ) && GetClientTeam( victim ) == 2 )
		{
			RevCount[victim] = NONE;
			SetEntProp( victim, Prop_Data, "m_MoveType", 2 );
			SetEntProp( victim, Prop_Data, "m_takedamage", 2, 1 );
			StopSound( victim, SNDCHAN_AUTO, SOUND_HEART_BEAT );
			if ( g_lastlifecolor > NONE )
			{
				SetEntityRenderMode( victim, RENDER_TRANSCOLOR);
				SetEntityRenderColor( victim, 255, 255, 255, 255 );
			}
		}

		for ( int i = 1; i <= MaxClients; i++ )
		{
			if ( RevHelper[i] == victim )
			{
				RevHelper[i] = NONE;
			}
			if ( Attacker[i] == victim )
			{
				Attacker[i] = NONE;
			}
			if ( TargetTeam[i] == victim )
			{
				TargetTeam[i] = NONE;
			}
			if ( TargetTeam[victim] == i )
			{
				TargetTeam[victim] = NONE;
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if ( !Button[client] )
    {
    	if (client > NONE)
    	{
    	    if(buttons & IN_ZOOM)
    	    {
    	        if(Attacker[client] > NONE && IsNo_IncapLedge(client))
    		    {
    			    if (IsValidSlotToKill(client))
    			    {
    	                UseAdrenKill[client] = true;
    	                GetUp(client);
    			    }
    		    }
    	    }
    
    	    if (buttons & IN_DUCK)
    		{
    			int target = GetClientAimTarget( client, true );
    			float TPos[3], PPos[3];
    			if ( target != -1 && IsValidSurvivor( target ) && g_teamdistance > NONE_F && ProgressionTeam( client, target ) == true )
    			{
    				GetEntPropVector( client, Prop_Send, "m_vecOrigin", PPos );
    				GetEntPropVector( target, Prop_Send, "m_vecOrigin", TPos );
    
    				if ( GetVectorDistance( TPos, PPos ) > g_teamdistance )
    				{
    					Button[client]		= true;
    					CreateTimer( 2.0, Button_Restore, client );
    					return Plugin_Continue;
    				}
    
    				GetDuration( client );
    				Timers[client]			= CreateTimer( 0.1, Timer_TeamGetUP, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
    				Button[client]			= true;
    				Button[target]			= true;
    				TargetTeam[client]		= target;
    				PrintHintText( client, "%t", "[GETUP]: Your target is %N", target );
    				return Plugin_Continue;
    			}
    
    			if( Attacker[client] > NONE || !IsNo_Incap( client ) || !IsNo_IncapLedge( client ))
    			{
    				if ( g_costly > NONE && IsValidSlot( client ) == false )
    				{
    					if ( g_message > NONE )
    					{
    						if ( Attacker[client] > NONE )
    						{
    							PrintHintText( client, "%t", "Required Item to Break Free" );
    						}
    						else if ( !IsNo_Incap( client ) || !IsNo_IncapLedge( client ) )
    						{
    							PrintHintText( client, "%t", "Required Item to Get Up" );
    						}
    					}
    					Button[client] = true;
    					EmitSoundToClient( client, SOUND_ERROR );
    					CreateTimer( 2.0, Button_Restore, client );
    					return Plugin_Continue;
    				}
    				GetDuration( client );
    				Timers[client] = CreateTimer( 0.1, Timer_SelfGetUP, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
    				Button[client] = true;
    			}
    		}

            if(g_selfstandup_enable_incap_pickup)
            {
                if (buttons & IN_USE)
                {
                    if(!g_bIsOnUse[client])
                    {
                        g_bIsOnUse[client] = true;
                        float vecOrigin[3], item_pos[3];
                        GetClientEyePosition(client, vecOrigin);
                        int itemtarget = GetClientAimTarget(client, false);
                        float distance = g_selfstandup_incap_pickup_distance;
                        if (!IsValidItemPickup(itemtarget)) itemtarget = GetItemOnFloor(client, "weapon_*", distance);
                        if (IsValidItemPickup(itemtarget))
                        {
                            int owneritem = GetEntPropEnt(itemtarget, Prop_Data, "m_hOwnerEntity");
                            GetEntPropVector(itemtarget, Prop_Data, "m_vecAbsOrigin", item_pos);
                            if ((owneritem == client || owneritem == -1) && GetVectorDistance(vecOrigin, item_pos) <= distance && IsVisibleTo(vecOrigin, item_pos))
                            AcceptEntityInput(itemtarget, "Use", client, itemtarget);
                        }
                    }
                }
                else if(!(buttons & IN_USE) && g_bIsOnUse[client]) g_bIsOnUse[client] = false;
            }
    	}
    }
    return Plugin_Continue;
}

public Action Timer_SelfGetUP( Handle timer, any victim )
{
	float EngTime = GetEngineTime();
	if ( Progression( victim ) && ( GetClientButtons( victim ) & IN_DUCK ))
	{
		if ( HelpState[victim] == STATE_NONE )
		{
			StartTime[victim]		= EngTime;
			TeamHealth[victim]		= GetEntProp( victim, Prop_Data, "m_iHealth" );
			TeamHealthBuff[victim]	= GetEntPropFloat( victim, Prop_Send, "m_healthBuffer" );
			if (( !IsNo_Incap( victim ) || !IsNo_IncapLedge( victim )) && Attacker[victim] == NONE )
			{
				SetEntProp( victim, Prop_Data, "m_MoveType", NONE );
				SetEntPropEnt( victim, Prop_Send, "m_reviveOwner", victim );
			}
			ShowBar( victim, EngTime - StartTime[victim], Duration[victim] );
			LoadUnloadProgressBar( victim, Duration[victim] );
			HelpState[victim] = STATE_SELFGETUP;
			if ( Attacker[victim] < 1 )
			{
				Execute_EventReviveBegin( victim, victim );
			}
		}
		if ( HelpState[victim] == STATE_SELFGETUP )
		{
			if (( EngTime - StartTime[victim] ) <= Duration[victim] )
			{
				ShowBar( victim, EngTime - StartTime[victim], Duration[victim] );
				if (( !IsNo_Incap( victim ) || !IsNo_IncapLedge( victim )) && Attacker[victim] == NONE )
				{
					SetEntProp( victim, Prop_Data, "m_iHealth", TeamHealth[victim] );
					SetEntPropFloat( victim, Prop_Send, "m_healthBuffer", TeamHealthBuff[victim] );
				}
			}
			else if (( EngTime - StartTime[victim] ) > Duration[victim] )
			{
				HelpState[victim] = STATE_NONE;
				ShowBar( victim, -1.0, Duration[victim] );
				LoadUnloadProgressBar( victim, NONE_F );
				GetUp( victim );
			}
		}
		return Plugin_Continue;
	}

	// player dead, gone, get up or whatever so we terminate the timer.
	if ( IsInGame( victim ))
	{
		ShowBar( victim, -1.0, Duration[victim] );
		SetEntProp( victim, Prop_Data, "m_MoveType", 2 );

		if ( RevHelper[victim] < 1 )
		{
			LoadUnloadProgressBar( victim, NONE_F );
			if( !IsNo_Incap( victim ) || !IsNo_IncapLedge( victim ))
			{
				SetEntPropEnt( victim, Prop_Send, "m_reviveOwner", -1 );
				Execute_EventReviveEnd( victim, victim );
			}
		}
	}

	HelpState[victim]	= STATE_NONE;
	Restart[victim]		= false;
	Timers[victim]		= null;
	CreateTimer( 0.5, Button_Restore, victim );
	return Plugin_Stop;
}

public Action Timer_TeamGetUP( Handle timer, any helper )
{
	int target = TargetTeam[helper];
	float EngTime = GetEngineTime();
	
	if ( ProgressionTeam( helper, target ) && ( GetClientButtons( helper ) & IN_DUCK ))
	{
		if ( HelpState[helper] == STATE_NONE )
		{
			StartTime[helper]			= EngTime;
			TeamHealth[helper]		= GetEntProp( helper, Prop_Data, "m_iHealth" );
			TeamHealthBuff[helper]	= GetEntPropFloat( helper, Prop_Send, "m_healthBuffer" );
			TeamHealth[target]		= GetEntProp( target, Prop_Data, "m_iHealth" );
			TeamHealthBuff[target]	= GetEntPropFloat( target, Prop_Send, "m_healthBuffer" );
			SetEntProp( helper, Prop_Data, "m_MoveType", NONE );
			SetEntProp( target, Prop_Data, "m_MoveType", NONE );
			SetEntPropEnt( target, Prop_Send, "m_reviveOwner", helper );
			SetEntPropEnt( helper, Prop_Send, "m_reviveTarget", target );

			ShowBar( helper, EngTime - StartTime[helper], Duration[helper] );
			ShowBar( target, EngTime - StartTime[helper], Duration[helper] );
			LoadUnloadProgressBar( helper, Duration[helper] );
			LoadUnloadProgressBar( target, Duration[helper] );
			Execute_EventReviveBegin( helper, target );
			HelpState[helper] = STATE_SELFGETUP;
		}
		if ( HelpState[helper] == STATE_SELFGETUP )
		{
			if ( RevHelper[target] != helper )
			{
				Restart[helper] = true;
			}
			if (( EngTime - StartTime[helper] ) <= Duration[helper] )
			{
				if (( !IsNo_Incap( helper ) || !IsNo_IncapLedge( helper )) && Attacker[helper] == NONE )
				{
					SetEntProp( helper, Prop_Data, "m_iHealth", TeamHealth[helper] );
					SetEntPropFloat( helper, Prop_Send, "m_healthBuffer", TeamHealthBuff[helper] );
				}
				if (( !IsNo_Incap( target ) || !IsNo_IncapLedge( target )) && Attacker[target] == NONE )
				{
					SetEntProp( helper, Prop_Data, "m_iHealth", TeamHealth[helper] );
					SetEntPropFloat( helper, Prop_Send, "m_healthBuffer", TeamHealthBuff[helper] );
				}
				ShowBar( helper, EngTime - StartTime[helper], Duration[helper] );
				ShowBar( target, EngTime - StartTime[helper], Duration[helper] );
			}
			if (( EngTime - StartTime[helper] ) > Duration[helper] )
			{
				ShowBar( helper, -1.0, Duration[helper] );
				ShowBar( target, -1.0, Duration[helper] );
				LoadUnloadProgressBar( helper, NONE_F );
				LoadUnloadProgressBar( target, NONE_F );
				RevHelper[target] = NONE;
				GetUpTeam( helper, target );
			}
		}
		return Plugin_Continue;
	}

	if ( IsValidSurvivor( helper ))
	{
		ShowBar( helper, -1.0, Duration[helper] );
		SetEntProp( helper, Prop_Data, "m_MoveType", 2 );
		SetEntPropEnt( helper, Prop_Send, "m_reviveTarget", -1 );
		if ( RevHelper[helper] < 1 )
		{
			LoadUnloadProgressBar( helper, NONE_F );
		}
	}
	if ( IsValidSurvivor( target ))
	{
		ShowBar( target, -1.0, Duration[helper] );
		SetEntProp( target, Prop_Data, "m_MoveType", 2 );
		if (( !IsNo_Incap( target ) || !IsNo_IncapLedge( target )) && RevHelper[target] == helper )
		{
			SetEntPropEnt( target, Prop_Send, "m_reviveOwner", -1 );
			LoadUnloadProgressBar( target, NONE_F );
			Execute_EventReviveEnd( helper, target );
		}
	}
	CreateTimer( 0.5, Button_Restore, helper );
	CreateTimer( 0.5, Button_Restore, target );

	HelpState[helper]		= STATE_NONE;
	Restart[helper]		= false;
	Restart[target]		= false;
	TargetTeam[helper]	= NONE;
	Timers[helper]			= null;
	return Plugin_Stop;
}

public Action Button_Restore( Handle timer, any attacker )
{
	Button[attacker] = false;
	return Plugin_Stop;
}

public Action Timer_RestoreCollution( Handle timer, any attacker )
{
	if( IsValidSpecInfected( attacker ))
	{
		SetEntityMoveType( attacker, MOVETYPE_WALK );
	}
	return Plugin_Stop;
}

public Action Timer_ThirdStrike( Handle timer, any victim )
{
	if ( IsValidSurvivor( victim ))
	{
		if ( GetEntProp( victim, Prop_Send, "m_bIsOnThirdStrike" ) < 1 )
		{
			EmitSoundToClient( victim, SOUND_HEART_BEAT );
			SetEntProp( victim, Prop_Send, "m_currentReviveCount", g_blackwhite );
			SetEntProp( victim, Prop_Send, "m_bIsOnThirdStrike", 1 );
			if ( g_lastlifecolor > NONE )
			{
				SetEntityRenderMode( victim, RENDER_TRANSCOLOR );
				SetEntityRenderColor( victim, 128, 255, 128, 255 );
			}
			if ( g_message > NONE )
			{
				CPrintToChatAll("%t", "[GETUP]: %N on last life!!", victim );
			}
		}
	}
	return Plugin_Stop;
}

public Action Timer_Hint( Handle timer, any playeR )
{
	if ( IsValidSurvivor( playeR ))
	{
		PrintHintText( playeR, "%t", "Hold CTRL key to help yourself" );
	}
	return Plugin_Stop;
}

public Action ResetReviveCount( Handle timer, any victim )
{
	if( IsValidSurvivor( victim ))
	{
		RevCount[victim] = NONE;
		SetEntProp( victim, Prop_Send, "m_currentReviveCount", NONE );
		SetEntPropFloat( victim, Prop_Send, "m_healthBuffer", NONE_F );
		SetEntProp( victim, Prop_Send, "m_bIsOnThirdStrike", NONE );
		if ( g_lastlifecolor > NONE )
		{
			SetEntityRenderMode( victim, RENDER_TRANSCOLOR);
			SetEntityRenderColor( victim, 255, 255, 255, 255 );
		}

		StopBeat( victim );
	}
	return Plugin_Stop;
}

void KillAttacker( int victim )
{
    int attacker = Attacker[victim];
    if ( IsValidSpecInfected( attacker ))
	{
		if (GetEntityColor(attacker) == 255255255)
		{
//			ForcePlayerSuicide( attacker );
//            SetEntProp(attacker, Prop_Send, "m_iHealth", 1, true);
//            float vecPos[3], vecAng[3];
//            GetClientAbsOrigin(attacker, vecPos);
//            GetClientEyeAngles(attacker, vecAng);
//            L4D_MolotovPrj(victim, vecPos, vecAng);

            EmitSoundToAll( SOUND_KILL2, victim );
            int AttackerHealth = GetClientHealth(attacker);
            DealDamage(attacker, AttackerHealth, victim, DMG_BULLET, "weapon_sniper_awp");
            DealDamage(attacker, AttackerHealth, victim, DMG_BULLET, "weapon_sniper_awp");
//            SetEntProp(victim, Prop_Data, "m_iFrags", GetClientFrags(victim) + 1);
		}
	}

    if (UseAdrenKill[victim]) UseAdrenKill[victim] = false;
    Attacker[victim] = NONE;
}

void DealDamage(int victim, int damage, int attacker =  0, int dmg_type = DMG_GENERIC, char[] weapon = "")
{
	if(victim > 0 && IsValidEdict(victim) && IsClientInGame(victim) && IsPlayerAlive(victim))
	{
		char dmg_str[16];
		IntToString(damage, dmg_str, 16);
		char dmg_type_str[32];
		IntToString(dmg_type, dmg_type_str, 32);
		int pointHurt = CreateEntityByName("point_hurt");
		if (pointHurt)
		{
			DispatchKeyValue(victim, "targetname", "hurtme");
			DispatchKeyValue(pointHurt, "DamageTarget", "hurtme");
			DispatchKeyValue(pointHurt, "Damage", dmg_str);
			DispatchKeyValue(pointHurt, "DamageType", dmg_type_str);

			if(!StrEqual(weapon,""))
			{
				DispatchKeyValue(pointHurt,"classname", weapon);
			}

			DispatchSpawn(pointHurt);
			AcceptEntityInput(pointHurt, "Hurt", (attacker > 0) ? attacker : -1);
			DispatchKeyValue(pointHurt, "classname", "point_hurt");
			DispatchKeyValue(victim, "targetname", "hurtme");
			RemoveEdict(pointHurt);
		}
	}
}

void KnockAttacker( int victim )
{
	int attacker = Attacker[victim];
	if ( IsValidSpecInfected( attacker ))
	{
		int class = GetEntProp( attacker, Prop_Send, "m_zombieClass" );
		if ( class == SMOKER )
		{
			SetEntityMoveType( attacker, MOVETYPE_NOCLIP );			// this trick trigger the event tongue_release
			CreateTimer( 0.1, Timer_RestoreCollution, attacker );
			CreatePointPush( attacker, 550.0 );
		}
		if ( class == JOCKEY )
		{
			CallOnJockeyRideEnd( attacker );						// this trick trigger the event jockey_ride_end
			CreatePointPush( attacker, 550.0 );
		}
		if ( class == HUNTER )
		{
			CallOnPounceEnd( victim, GAME_DATA );
			SetEntityMoveType( attacker, MOVETYPE_NOCLIP );
			CreateTimer( 0.1, Timer_RestoreCollution, attacker );
			CreatePointPush( attacker, 550.0 );
		}
		if ( class == CHARGER )
		{
			//KillAttacker( victim );
			CallOnPummelEnded( victim, GAME_DATA );
			CreatePointPush( attacker, 550.0 );
		}
	}
	Attacker[victim] = NONE;
}

void GetUp( int victim )
{
	if ( IsValidSurvivor( victim ))
	{
		if( Attacker[victim] > NONE )
		{
		    if(UseAdrenKill[victim])
		    {
		        KillAttacker(victim);
		        UsePackToKill(victim);
		    }

		    if (g_kill > NONE)
			{
				KillAttacker( victim );
				UsePack( victim, true );
			}
			else
			{
				KnockAttacker( victim );
			}
		}
		else
		{
			bool Incap = false;
			if ( !IsNo_Incap( victim ) && IsNo_IncapLedge( victim ))
			{
				Incap = true;
			}

			StopBeat( victim );
			HealthCheat( victim );

			if ( Incap == true )
			{
				SetEntProp( victim, Prop_Data, "m_iHealth", 1 );
				SetEntPropFloat( victim, Prop_Send, "m_healthBuffer", g_health_incap );
				if ( RevCount[victim] == g_blackwhite )
				{
					CreateTimer( 0.1, Timer_ThirdStrike, victim );
					if ( g_costly > NONE )
					{
						UsePack( victim, false );
					}
				}
				else
				{
					SetEntProp( victim, Prop_Send, "m_currentReviveCount", RevCount[victim] );
					if ( g_message > NONE )
					{
						if ( g_costly == NONE )
						{
							CPrintToChat( victim, "%t", "[GETUP]: %d of %d", RevCount[victim], g_blackwhite );
						}
						else
						{
							UsePack( victim, true );
						}
					}
					else
					{
						if ( g_costly > NONE )
						{
							UsePack( victim, false );
						}
					}
				}
			}
			else
			{
				SetEntProp( victim, Prop_Data, "m_iHealth", ReviveHealth[victim] );
				SetEntPropFloat( victim, Prop_Send, "m_healthBuffer", ReviveHealthBuff[victim]);
				if ( g_message > NONE )
				{
					if ( g_costly == NONE )
					{
						CPrintToChat( victim, "%t", "[GETUP]: %d of %d", RevCount[victim], g_blackwhite );
					}
					else
					{
						UsePack( victim, true );
					}
				}
				else
				{
					if ( g_costly > NONE )
					{
						UsePack( victim, false );
					}
				}
			}
			EmitSoundToClient( victim, SOUND_GETUP );
		}
	}
}

void GetUpTeam( int helper, int victim )
{
	if ( IsValidSurvivor( victim ))
	{
		bool Incap = false;
		if ( !IsNo_Incap( victim ) && IsNo_IncapLedge( victim ))
		{
			Incap = true;
		}

		StopBeat( victim );
		HealthCheat( victim );

		if ( Incap == true )
		{
			SetEntProp( victim, Prop_Data, "m_iHealth", 1 );
			SetEntPropFloat( victim, Prop_Send, "m_healthBuffer", g_health_incap );
			if ( RevCount[victim] == g_blackwhite )
			{
				CreateTimer( 0.1, Timer_ThirdStrike, victim );
			}
			else
			{
				SetEntProp( victim, Prop_Send, "m_currentReviveCount", RevCount[victim] );
				if ( g_message > NONE )
				{
					CPrintToChat( victim, "%t", "[GETUP]: %d of %d, revived by %N", RevCount[victim], g_blackwhite, helper );
					CPrintToChat( helper, "%t", "[GETUP]: Successfully revived %N", victim );
				}
			}
		}
		else
		{
			SetEntProp( victim, Prop_Data, "m_iHealth", ReviveHealth[victim] );
			SetEntPropFloat( victim, Prop_Send, "m_healthBuffer", ReviveHealthBuff[victim]);
			if ( g_message > NONE )
			{
				CPrintToChat( victim, "%t", "[GETUP]: Revived by %N", helper );
				CPrintToChat( helper, "%t", "[GETUP]: Successfully revived %N", victim );
			}
		}
		EmitSoundToClient( victim, SOUND_GETUP );
		EmitSoundToClient( helper, SOUND_GETUP );
	}
}

void ShowBar( int victim, float pos, float max )	 
{
	if ( IsValidSurvivor( victim ))
	{
		if ( pos < NONE_F )
		{
			PrintCenterText( victim, "" );
			return;
		}

		char ChargeBar[100];
		float GaugeNum = pos / max * 100;
		Format( ChargeBar, sizeof( ChargeBar ), "" );

		if ( GaugeNum > 100.0 )	GaugeNum = 100.0;
		if ( GaugeNum < NONE_F ) GaugeNum = NONE_F;
		for ( int m = NONE; m < 100; m++ )
		{
			ChargeBar[m] = Gauge1[NONE];
		}
		int p = RoundFloat( GaugeNum );
		if ( p >= NONE && p < 100 ) ChargeBar[p] = Gauge3[NONE]; 
		PrintCenterText( victim, "%t", "<< SELF GET UP IN PROGRESS >> %3.0f %\n<<< %s >>>", GaugeNum, ChargeBar );
	}
}

void GetClientHP( int victim )
{
	if ( IsValidSurvivor( victim ))
	{
		if ( IsNo_Incap( victim ) && IsNo_IncapLedge( victim ))
		{
			ReviveHealth[victim]			= GetEntProp( victim, Prop_Data, "m_iHealth" );
			ReviveHealthBuff[victim]		= GetEntPropFloat( victim, Prop_Send, "m_healthBuffer" );
		}
	}
}

void StopBeat( int victim )
{
	if ( IsValidSurvivor( victim ))
	{
		StopSound( victim, SNDCHAN_AUTO, SOUND_HEART_BEAT );
	}
}

int ScanEnemy( int victim )
{
	int Enemy = -1;
	if( IsValidSurvivor( victim ))
	{
		char InfName[64];
		float targetPos[3], playerPos[3];
		GetEntPropVector( victim, Prop_Send, "m_vecOrigin", playerPos );

		int EntCount = GetEntityCount();
		for ( int i = 1; i <= EntCount; i++ )
		{
			if ( IsValidEntity( i ))
			{
				if ( IsValidSpecInfected( i ) || IsValidTank( i ))
				{
					GetEntPropVector( i, Prop_Send, "m_vecOrigin", targetPos );
					if ( GetVectorDistance( targetPos, playerPos ) <= g_clearance)
					{
						Enemy = i;
						if ( g_message > NONE )
						{
							PrintHintText( victim, "%t", "[GETUP]: You too close to %N", i );
						}
						break;
					}
				}
				else
				{
					GetEntityClassname( i, InfName, sizeof( InfName ));
					if ( StrEqual( InfName, "infected", false ))
					{
						GetEntPropVector( i, Prop_Send, "m_vecOrigin", targetPos );
						if ( GetVectorDistance( targetPos, playerPos ) <= g_clearance)
						{
							Enemy = i;
							if ( g_message > NONE )
							{
								PrintHintText( victim, "%t", "[GETUP]: You too close to %s", InfName );
							}
							break;
						}
					}
				}
			}
		}
	}
	return Enemy;
}

void GetDuration( int client )
{
	Duration[client] = g_duration;
	if ( !IsNo_IncapLedge( client ))
	{
		Duration[client] = g_duration - 1.0 ;
	}
	if ( Duration[client] > 5.0 )
	{
		Duration[client] = 5.0;
	}
	else if ( Duration[client] < 1.0 )
	{
		Duration[client] = 1.0;
	}
}

stock void CallOnJockeyRideEnd( int attacker )
{
	if ( IsValidSpecInfected( attacker ))
	{
		int flag =  GetCommandFlags( "dismount" );
		SetCommandFlags( "dismount", flag & ~FCVAR_CHEAT );
		FakeClientCommand( attacker, "dismount" );
		SetCommandFlags( "dismount", flag );
	}
}

stock void CallOnPummelEnded( int victim, char[] GAMEDATA )
{
	static Handle hOnPummelEnded;
	if (!hOnPummelEnded)
	{
		GameData hConf = new GameData( GAMEDATA );
		StartPrepSDKCall( SDKCall_Player );
		PrepSDKCall_SetFromConf( hConf, SDKConf_Signature, "CTerrorPlayer::OnPummelEnded" );
		PrepSDKCall_AddParameter( SDKType_Bool,SDKPass_Plain );
		PrepSDKCall_AddParameter( SDKType_CBasePlayer, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL );
		hOnPummelEnded = EndPrepSDKCall();
		delete hConf;
		if (!hOnPummelEnded)
		{
			SetFailState( "Can't get CTerrorPlayer::OnPummelEnded SDKCall!" );
			return;
		}
	}

	if (hOnPummelEnded)
	{
		SDKCall( hOnPummelEnded, victim, true, -1 );
	}
	else
	{
		PrintToServer( "[GETUP]: Can't get CTerrorPlayer::OnPounceEnd SDKCall!" );
	}
}

stock void CallOnPounceEnd( int victim, char[] GAMEDATA )
{
	static Handle hOnPounceEnd;
	if (!hOnPounceEnd)
	{
		GameData hConf = new GameData( GAMEDATA );
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf( hConf, SDKConf_Signature, "CTerrorPlayer::OnPounceEnd" );
		hOnPounceEnd = EndPrepSDKCall();
		delete hConf;
		if (!hOnPounceEnd)
		{
			SetFailState( "Can't get CTerrorPlayer::OnPounceEnd SDKCall!" );
			return;
		}
	}

	if (hOnPounceEnd)
	{
		SDKCall( hOnPounceEnd, victim );
	}
	else
	{
		PrintToServer( "[GETUP]: Can't get CTerrorPlayer::OnPounceEnd SDKCall!" );
	}
}

stock void HealthCheat( int client )
{
	if ( IsValidSurvivor( client ))
	{
		int userflags = GetUserFlagBits( client );
		int cmdflags = GetCommandFlags( "give" );
		SetUserFlagBits( client, ADMFLAG_ROOT );
		SetCommandFlags( "give", cmdflags & ~FCVAR_CHEAT );
		FakeClientCommand( client,"give health" );
		SetCommandFlags( "give", cmdflags );
		SetUserFlagBits( client, userflags );
	}
}

bool Progression( int victim )
{
	if ( !IsValidSurvivor( victim )) return false;
	if ( Restart[victim] ) return false;
	if ( RevHelper[victim] != NONE ) return false;
	if ( IsNo_Incap( victim ) && IsNo_IncapLedge( victim ) && Attacker[victim] == NONE ) return false;

	if ( g_clearance > 1.0 && Attacker[victim] < 1 )
	{
		if ( ScanEnemy( victim ) > NONE )
			return false;
	}
	return true;
}

bool ProgressionTeam( int helper, int target )
{
	if ( !IsValidSurvivor( helper )) return false;
	if ( !IsValidSurvivor( target )) return false;
	if ( Restart[helper] ) return false;
	if ( Restart[target] ) return false;
	if ( Attacker[helper] > NONE ) return false;
	if ( Attacker[target] > NONE ) return false;
	if ( IsNo_Incap( helper ) && IsNo_IncapLedge( helper )) return false;
	if ( IsNo_Incap( target ) && IsNo_IncapLedge( target )) return false;
	return true;
}

stock void Execute_EventReviveBegin( int helper, int victim )
{
	if ( helper > NONE && victim > NONE )
	{
		Event event = CreateEvent( "revive_begin" );
		if (event)
		{
			event.SetInt( "userid", GetClientUserId( helper ));		// person doing the reviving
			event.SetInt( "subject", GetClientUserId( victim ));		// person being revive
			FireEvent( event );
		}
	}
}

stock void Execute_EventReviveEnd( int helper, int victim )
{
	if ( helper > NONE && victim > NONE )
	{
		Event event = CreateEvent( "revive_end" );
		if (event)
		{
			event.SetInt( "userid", GetClientUserId( helper ));		// person doing the reviving
			event.SetInt( "subject", GetClientUserId( victim ));		// person being revive
			if( !IsNo_IncapLedge( victim ))
			{
				event.SetBool( "ledge_hang", true );
			}
			else
			{
				event.SetBool( "ledge_hang", false );
			}
			FireEvent( event );
		}
	}
}

void GetListOfMetrial()
{
	if ( StrContains( g_costly_item, "pills", false ) != -1 )
		g_Pills = true;
	else
		g_Pills = false;

	if ( StrContains( g_costly_item, "adrenaline", false ) != -1 )
		g_Adrenaline = true;
	else
		g_Adrenaline = false;

	if ( StrContains( g_costly_item, "med_kit", false ) != -1 )
		g_Med_Kit = true;
	else
		g_Med_Kit = false;

	if ( StrContains( g_costly_item, "defibrillator", false ) != -1 )
		g_Defibrillator = true;
	else
		g_Defibrillator = false;

	if ( StrContains( g_costly_item, "incendiary", false ) != -1 )
		g_Incendiary = true;
	else
		g_Incendiary = false;

	if ( StrContains( g_costly_item, "explosive", false ) != -1 )
		g_Explosive = true;
	else
		g_Explosive = false;
}

void UsePackToKill(int client)
{
	if ( PlayerWeaponSlot[client] != -1 && IsValidEntity( PlayerWeaponSlot[client] ))
	{
		char slotName[64];
		GetEntityClassname( PlayerWeaponSlot[client], slotName, sizeof( slotName ));
		if ( StrEqual( slotName, "weapon_adrenaline", false ))
		    Format( slotName, sizeof( slotName ), "肾上腺素" );

		AcceptEntityInput( PlayerWeaponSlot[client], "kill" );
		PlayerWeaponSlot[client] = -1;
	}
}

void UsePack( int client, bool Msg )
{
	if ( PlayerWeaponSlot[client] != -1 && IsValidEntity( PlayerWeaponSlot[client] ))
	{
		char slotName[64];
		GetEntityClassname( PlayerWeaponSlot[client], slotName, sizeof( slotName ));
		if ( StrEqual( slotName, "weapon_upgradepack_explosive", false ))
			Format(slotName, sizeof( slotName ), "高爆弹药盒");
		else if ( StrEqual( slotName, "weapon_upgradepack_incendiary", false ))
			Format( slotName, sizeof( slotName ), "燃烧弹药盒" );
		else if ( StrEqual( slotName, "weapon_first_aid_kit", false ))
			Format( slotName, sizeof( slotName ), "医疗包" );
		else if ( StrEqual( slotName, "weapon_defibrillator", false ))
			Format( slotName, sizeof( slotName ), "电击器" );
		else if ( StrEqual( slotName, "weapon_pain_pills", false ))
			Format( slotName, sizeof( slotName ), "止疼药" );		
		else Format( slotName, sizeof( slotName ), "肾上腺素" );

		if ( Msg )
		{
			CPrintToChat( client, "%t", "[GETUP]: %d of %d, cost of %s", RevCount[client], g_blackwhite, slotName );
		}

		AcceptEntityInput( PlayerWeaponSlot[client], "kill" );
		PlayerWeaponSlot[client] = -1;
	}
}

stock bool isSIowner( int client )
{
	// smoker
	if ( GetEntProp( client, Prop_Send, "m_reachedTongueOwner" ) > NONE )	return true;
	if ( GetEntProp( client, Prop_Send, "m_tongueOwner" ) > NONE )			return true;
	if ( GetEntProp( client, Prop_Send, "m_isHangingFromTongue" ) > NONE )	return true;
	if ( GetEntProp( client, Prop_Send, "m_isProneTongueDrag"  ) > NONE )	return true;
	// hunter
	if ( GetEntPropEnt( client, Prop_Send, "m_pounceAttacker" ) > NONE )	return true;
	//charger
	if ( GetEntPropEnt( client, Prop_Send, "m_pummelAttacker" ) > NONE )	return true;
	if ( GetEntPropEnt( client, Prop_Send, "m_carryAttacker" ) > NONE )		return true;
	// jockey
	if ( GetEntPropEnt( client, Prop_Send, "m_jockeyAttacker" ) > NONE )	return true;
	return false;
}

bool IsValidSlotToKill( int client )
{
	if ( IsValidSurvivor( client ))
	{
		GetListOfMetrial();

		char PlayerSlot[128];
		int PlayerSlot_4 = GetPlayerWeaponSlot( client, 4 );

		if ( PlayerSlot_4 != -1 && IsValidEdict(PlayerSlot_4) && g_Adrenaline)
		{
			GetEntityClassname( PlayerSlot_4, PlayerSlot, sizeof( PlayerSlot ));
			if ( StrEqual( PlayerSlot, "weapon_adrenaline", false ) && g_Adrenaline )
			{
				PlayerWeaponSlot[client] = PlayerSlot_4;
				return true;
			}
		}
	}
	PlayerWeaponSlot[client] = -1;
	return false;
}

bool IsValidSlot( int client )
{
	if ( IsValidSurvivor( client ))
	{
		GetListOfMetrial();

		char PlayerSlot[128];
		int PlayerSlot_3 = GetPlayerWeaponSlot( client, 3 );
		int PlayerSlot_4 = GetPlayerWeaponSlot( client, 4 );

		if ( PlayerSlot_4 != -1 && IsValidEdict( PlayerSlot_4 ) && ( g_Pills || g_Adrenaline ))
		{
			GetEntityClassname( PlayerSlot_4, PlayerSlot, sizeof( PlayerSlot ));
		
			if ( StrEqual( PlayerSlot, "weapon_pain_pills", false ) && g_Pills )
			{
				PlayerWeaponSlot[client] = PlayerSlot_4;
				return true;
			}
			if ( StrEqual( PlayerSlot, "weapon_adrenaline", false ) && g_Adrenaline )
			{
				PlayerWeaponSlot[client] = PlayerSlot_4;
				return true;
			}
		}
		if ( PlayerSlot_3 != -1 && IsValidEdict( PlayerSlot_3 ) && ( g_Med_Kit || g_Defibrillator || g_Incendiary || g_Explosive ))
		{
			GetEntityClassname( PlayerSlot_3, PlayerSlot, sizeof( PlayerSlot ));

			if ( StrEqual( PlayerSlot, "weapon_first_aid_kit", false ) && g_Med_Kit )
			{
				PlayerWeaponSlot[client] = PlayerSlot_3;
				return true;
			}
			if ( StrEqual( PlayerSlot, "weapon_defibrillator", false ) && g_Defibrillator )
			{
				PlayerWeaponSlot[client] = PlayerSlot_3;
				return true;
			}
			if ( StrEqual( PlayerSlot, "weapon_upgradepack_incendiary", false ) && g_Incendiary )
			{
				PlayerWeaponSlot[client] = PlayerSlot_3;
				return true;
			}
			if ( StrEqual( PlayerSlot, "weapon_upgradepack_explosive", false ) && g_Explosive )
			{
				PlayerWeaponSlot[client] = PlayerSlot_3;
				return true;
			}
		}
	}
	PlayerWeaponSlot[client] = -1;
	return false;
}

stock bool IsNo_Incap( int client )
{
	if ( IsValidSurvivor( client ))
	{
		// if survivor incaped return false, true otherwise.
		if ( GetEntProp( client, Prop_Send, "m_isIncapacitated" ) == 1 )
			return false;
	}
	return true;
}

stock bool IsNo_IncapLedge( int client )
{
	if ( IsValidSurvivor( client ))
	{
		// if survivor ledge grab return false, true otherwise.
		if ( GetEntProp( client, Prop_Send, "m_isHangingFromLedge" ) == 1 )
			return false;
	}
	return true;
}

stock bool IsValidSurvivor( int client )
{
	if ( client < 1 || client > MaxClients ) return false;
	if ( !IsClientConnected( client )) return false;
	if ( !IsClientInGame( client )) return false;
	if ( !IsPlayerAlive( client )) return false;
	if ( GetClientTeam( client ) != 2 ) return false;
	return true;
}

stock bool IsValidSpecInfected( int client )
{
	if ( client < 1 || client > MaxClients ) return false;
	if ( !IsClientConnected( client )) return false;
	if ( !IsClientInGame( client )) return false;
	if ( !IsPlayerAlive( client )) return false;
	if ( GetClientTeam( client ) != 3 ) return false;
	if ( GetEntProp( client, Prop_Send, "m_zombieClass" ) == TANK ) return false;
	return true;
}

stock bool IsInGame( int client )
{
	if ( client < 1 || client > MaxClients ) return false;
	if ( !IsClientConnected( client )) return false;
	if ( !IsClientInGame( client )) return false;
	return true;
}

stock bool IsValidTank( int client )
{
	if ( client < 1 || client > MaxClients ) return false;
	if ( !IsClientConnected( client )) return false;
	if ( !IsClientInGame( client )) return false;
	if ( !IsPlayerAlive( client )) return false;
	if ( GetClientTeam( client ) != 3 ) return false;
	if ( GetEntProp( client, Prop_Send, "m_zombieClass" ) != TANK ) return false;
	return true;
}

stock int GetEntityColor(int entity)
{
	if(entity > 0)
	{
		int offset = GetEntSendPropOffs(entity, "m_clrRender");
		int r = GetEntData(entity, offset, 1);
		int g = GetEntData(entity, offset + 1, 1);
		int b = GetEntData(entity, offset + 2, 1);
		char rgb[10];
		Format(rgb, sizeof(rgb), "%d%d%d", r, g, b);
		int color = StringToInt(rgb);
		return color;
	}
	return 0;
}

void CreatePointPush( int client, float Force )
{
	if ( IsValidSpecInfected( client ))
	{
		float vecAng[3];
		float vecVec[3];    
		GetEntPropVector( client, Prop_Data, "m_angRotation", vecAng );

		vecAng[0] -= 30.0;

		vecVec[0] *= ( Cosine( DegToRad( vecAng[1] )), Force );
		vecVec[1] *= ( Sine( DegToRad( vecAng[1] )), Force );
		vecVec[2] *= ( Sine( DegToRad( vecAng[0] )), ( -Force ));

		TeleportEntity( client, NULL_VECTOR, NULL_VECTOR, vecVec );
	}
}

bool IsValidItemPickup(int item){
	if(IsValidWeapon(item)){
		if (IsWeaponScavengeItemSpawn(item)) return false;
		if(IsWeaponGascan(item) && (g_selfstandup_incap_pickup_scavenge_item == 1)) return true;
		else if(IsWeaponColaBottles(item) && (g_selfstandup_incap_pickup_scavenge_item == 2)) return true;
		else if(IsWeaponGascan(item) || IsWeaponColaBottles(item) || IsWeaponChainsaw(item))
			return false;

		return true;
	}
	return false;
}

//https://forums.alliedmods.net/showthread.php?t=318185
int GetItemOnFloor(int client, char[] sClassname, float fDistance = 101.8, float fRadius = 25.0)
{
	float vecEye[3], vecTarget[3], vecDir1[3], vecDir2[3], ang[3];
	float dist, MAX_ANG_DELTA, ang_delta, ang_min = 0.0;
	int ent=-1, entity = -1;
	GetClientEyePosition(client, vecEye);
	while (-1 != (ent = FindEntityByClassname(ent, sClassname))) {
		if (!IsValidEnt(ent))
			continue;

		//GetEntPropVector(ent, Prop_Data, "m_vecOrigin", vecTarget);
		GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", vecTarget);//for weapons parented
		dist = GetVectorDistance(vecEye, vecTarget);

		if (dist <= fDistance)
		{
			// get directional angle between eyes and target
			SubtractVectors(vecTarget, vecEye, vecDir1);
			NormalizeVector(vecDir1, vecDir1);

			// get directional angle of eyes view
			GetClientEyeAngles(client, ang);
			GetAngleVectors(ang, vecDir2, NULL_VECTOR, NULL_VECTOR);

			// get angle delta between two directional angles
			ang_delta = GetAngle(vecDir1, vecDir2); // RadToDeg

			MAX_ANG_DELTA = ArcTangent(fRadius / dist); // RadToDeg

			if (ang_delta <= MAX_ANG_DELTA)
			{
				if(ang_delta < ang_min || ang_min == 0.0)
				{
					ang_min = ang_delta;
					entity = ent;
				}
			}
		}
	}
	return entity;
}

float GetAngle(float x1[3], float x2[3]) // by Pan XiaoHai
{
	return ArcCosine(GetVectorDotProduct(x1, x2)/(GetVectorLength(x1)*GetVectorLength(x2)));
}

// credits = "AtomicStryker"
bool IsVisibleTo(float position[3], float targetposition[3])
{
	static float vAngles[3], vLookAt[3];

	MakeVectorFromPoints(position, targetposition, vLookAt); // compute vector from start to target
	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace

	// execute Trace
	static Handle trace;
	trace = TR_TraceRayFilterEx(position, vAngles, MASK_ALL, RayType_Infinite, _TraceFilter);

	static bool isVisible;
	isVisible = false;

	if( TR_DidHit(trace) )
	{
		static float vStart[3];
		TR_GetEndPosition(vStart, trace); // retrieve our trace endpoint

		if( (GetVectorDistance(position, vStart, false) + 25.0 ) >= GetVectorDistance(position, targetposition))
		{
			isVisible = true; // if trace ray length plus tolerance equal or bigger absolute distance, you hit the target
		}
	}
	delete trace;

	return isVisible;
}

public bool _TraceFilter(int entity, int contentsMask)
{
	if( entity <= MaxClients || !IsValidEntity(entity) )
		return false;
	return true;
}

stock bool IsWeaponSpawner(int weapon){
	if(IsValidWeapon(weapon)){
		char class_name[64];
		GetEntityClassname(weapon, class_name, sizeof(class_name));
		return (strncmp(class_name[strlen(class_name)-6], "_spawn", 7) == 0);
	}
	return false;
}

stock bool IsWeaponGascan(int weapon){
	if(IsValidWeapon(weapon)){
		char class_name[64];
		GetEntityClassname(weapon, class_name, sizeof(class_name));
		return (strcmp(class_name, "weapon_gascan") == 0);
	}
	return false;
}

stock bool IsWeaponScavengeItemSpawn(int weapon){
	if(IsValidWeapon(weapon)){
		char class_name[64];
		GetEntityClassname(weapon, class_name, sizeof(class_name));
		return (strcmp(class_name, "weapon_scavenge_item_spawn") == 0);
	}
	return false;
}

stock bool IsWeaponColaBottles(int weapon){
	if(IsValidWeapon(weapon)){
		char class_name[64];
		GetEntityClassname(weapon, class_name, sizeof(class_name));
		return (strcmp(class_name, "weapon_cola_bottles") == 0);
	}
	return false;
}

stock bool IsValidWeapon(int weapon){
	if (IsValidEnt(weapon)) {
		char class_name[64];
		GetEntityClassname(weapon,class_name,sizeof(class_name));
		return (strncmp(class_name, "weapon_", 7) == 0);
	}
	return false;
}

stock bool IsWeaponChainsaw(int weapon){
	if(IsValidWeapon(weapon)){
		char class_name[64];
		GetEntityClassname(weapon, class_name, sizeof(class_name));
		return (strcmp(class_name, "weapon_chainsaw") == 0);
	}
	return false;
}

//https://forums.alliedmods.net/showthread.php?t=303716
stock bool IsPlayerCapped(int client)
{
	if(GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) return true;
	if(GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) return true;
	//only l4D2
	if(HasEntProp(client, Prop_Send, "m_pummelAttacker") && GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) return true;
	if(HasEntProp(client, Prop_Send, "m_carryAttacker") && GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0) return true;
	if(HasEntProp(client, Prop_Send, "m_jockeyAttacker") && GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) return true;
	return false;
}

void LoadUnloadProgressBar( int client, float EngTime )
{
	if ( IsValidSurvivor( client ))
	{
		SetEntPropFloat( client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
		SetEntPropFloat( client, Prop_Send, "m_flProgressBarDuration", EngTime );
	}
}

stock bool IsPlayerHanding(int client){
	return (GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) == 1);
}

stock bool IsPlayerIncapped(int client){
	return (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) == 1);
}

stock bool IsValidSpect(int client){
	return (IsValidClient(client) && GetClientTeam(client) == 1 );
}

stock bool IsValidInfected(int client){
	return (IsValidClient(client) && GetClientTeam(client) == 3 );
}

stock bool IsValidClient(int client){
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

stock bool IsValidEnt(int entity){
	return (entity > MaxClients && IsValidEntity(entity) && entity != INVALID_ENT_REFERENCE);
}

/*
int GetClientFrags(int index, int frags)
{
	GetEntProp(index, Prop_Data, "m_iFrags", frags);
	return 1;
}

int SetClientFrags(int index, int frags)
{
	SetEntProp(index, Prop_Data, "m_iFrags", frags);
	return 1;
}
*/
