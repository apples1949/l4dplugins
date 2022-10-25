#define PLUGIN_VERSION	"1.0.1"
#define PLUGIN_NAME		"l4d_headshot_buff"

/**
 *	v1.0 just releases; 26-2-22
 *		now all the idea about kill well done i may wont made more, i have to learn more other
 *	v1.0.1 fix player zombies not works; 28-2-22
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

forward void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier);

forward void WH_OnReloadModifier(int client, int weapon, int weapontype, float &speedmodifier);

forward void WH_OnGetRateOfFire(int client, int weapon, int weapontype, float &speedmodifier);

forward void WH_OnDeployModifier(int client, int weapon, int weapontype, float &speedmodifier);

ConVar Enabled;
ConVar Duration_hurt;	float duration_hurt;
ConVar Duration_kill;	float duration_kill;
ConVar Keep_switch;		bool keep_switch;
ConVar Sound_hurt;		char sound_hurt[64];
ConVar Sound_kill;		char sound_kill[64];
ConVar Death_only;		bool death_only;
ConVar Speed_rate;		float speed_rate;
ConVar Buff_actions;	int buff_actions;

public Plugin myinfo = {
	name = "[L4D & L4D2] Headshot Buff / Ding Sounds",
	author = "NoroHime",
	description = "gain the buff and play reward sound when you doing headshot",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/NoroHime/"
}

public void OnPluginStart() {

	CreateConVar("headshot_buff_version", PLUGIN_VERSION, "Version of 'Headshot Buff'", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	Enabled = 			CreateConVar("headshot_buff_enabled", "1", "Enabled 'Headshot Buff'", FCVAR_NOTIFY);
	Duration_hurt =		CreateConVar("headshot_buff_gain_hurt", "0.3", "buff duration gains of headshot hurt 0:sound only", FCVAR_NOTIFY);
	Duration_kill =		CreateConVar("headshot_buff_gain_kill", "0.6", "buff duration gains of headshot killed 0:sound only", FCVAR_NOTIFY);
	Keep_switch =		CreateConVar("headshot_buff_keep", "0", "keep buff when switch weapon 0:clear 1:keep", FCVAR_NOTIFY);
	Sound_hurt =		CreateConVar("headshot_buff_sound_hurt", "ui/littlereward.wav", "which sound wanna play for headshot hurt empty:noplay", FCVAR_NOTIFY);
	Sound_kill =		CreateConVar("headshot_buff_sound_kill", "level/bell_normal.wav", "which sound wanna play for headshot kill empty:noplay", FCVAR_NOTIFY);
	Death_only =		CreateConVar("headshot_buff_death", "0", "death only, ignore headshot hurt", FCVAR_NOTIFY);
	Speed_rate =		CreateConVar("headshot_buff_speed", "1.5", "buff speed rate 2:double speed", FCVAR_NOTIFY);
	Buff_actions =		CreateConVar("headshot_buff_actions", "-1", "buff actions 1=Firing 2=Deploying 4=Reloading 8=MeleeSwinging", FCVAR_NOTIFY);

	AutoExecConfig(true, PLUGIN_NAME);

	Enabled.AddChangeHook(Event_ConVarChanged);
	Duration_hurt.AddChangeHook(Event_ConVarChanged);
	Duration_kill.AddChangeHook(Event_ConVarChanged);
	Keep_switch.AddChangeHook(Event_ConVarChanged);
	Sound_hurt.AddChangeHook(Event_ConVarChanged);
	Sound_kill.AddChangeHook(Event_ConVarChanged);
	Death_only.AddChangeHook(Event_ConVarChanged);
	Speed_rate.AddChangeHook(Event_ConVarChanged);
	Buff_actions.AddChangeHook(Event_ConVarChanged);

	ApplyCvars();
	Caching();
}

void Caching() {

	if (sound_hurt[0])
		PrecacheSound(sound_hurt);

	if (sound_kill[0])
		PrecacheSound(sound_kill);
}

public void ApplyCvars() {

	static bool hooked = false;
	bool enabled = Enabled.BoolValue;

	if (enabled && !hooked) {

		HookEvent("player_death", OnPlayerDeath);
		HookEvent("infected_hurt", OnInfectedHurt);
		HookEvent("player_hurt", OnInfectedHurt);

		hooked = true;

	} else if (!enabled && hooked) {

		UnhookEvent("player_death", OnPlayerDeath);
		UnhookEvent("infected_hurt", OnInfectedHurt);
		UnhookEvent("player_hurt", OnInfectedHurt);

		hooked = false;
	}

	duration_hurt = Duration_hurt.FloatValue;
	duration_kill = Duration_kill.FloatValue;
	keep_switch = Keep_switch.BoolValue;
	Sound_hurt.GetString(sound_hurt, sizeof(sound_hurt));
	Sound_kill.GetString(sound_kill, sizeof(sound_kill));
	death_only = Death_only.BoolValue;
	speed_rate = Speed_rate.FloatValue;
	buff_actions = Buff_actions.IntValue;

}

public void Event_ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	ApplyCvars();

	if (convar == Sound_hurt || convar == Sound_kill)
		Caching();
}

public void OnConfigsExecuted() {
	ApplyCvars();
}

static float buff_remain[MAXPLAYERS + 1];
static Handle timer_buff[MAXPLAYERS + 1];

public void OnInfectedHurt(Event event, const char[] name, bool dontBroadcast) {


	if (event.GetInt("hitgroup") == 1 && !death_only) {

		int	attacker = GetClientOfUserId(event.GetInt("attacker"));
		int type_damage = event.GetInt("type");

		if (isAliveSurvivor(attacker) && !(type_damage & DMG_BURN)) {
			
			if (duration_hurt > 0) {

				buff_remain[attacker] += duration_hurt;

				if ( !IsValidHandle( timer_buff[attacker] ) )
					timer_buff[attacker] = CreateTimer(1.0, Timer_Countdown, TIMER_REPEAT);
			}

			if (sound_hurt[0] && !IsFakeClient(attacker)) 
				EmitSoundToClient(attacker, sound_hurt, SOUND_FROM_PLAYER);
		}
	}
}


public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {

	if (event.GetBool("headshot")) {

		int attacker = GetClientOfUserId(event.GetInt("attacker"));
		int type_damage = event.GetInt("type");

		if (isAliveSurvivor(attacker) && !(type_damage & DMG_BURN)) {

			if (duration_kill > 0) {

				buff_remain[attacker] += duration_kill;

				if ( !IsValidHandle( timer_buff[attacker] ) )
					timer_buff[attacker] = CreateTimer(1.0, Timer_Countdown, TIMER_REPEAT);
			}

			if (sound_kill[0] && !IsFakeClient(attacker)) 
				EmitSoundToClient(attacker, sound_kill, SOUND_FROM_PLAYER);
		}
	}
}

public Action Timer_Countdown(Handle timer, int client) {

	if (buff_remain[client] > 0) {

		buff_remain[client]--;
		return Plugin_Continue;
	}

	return Plugin_Stop;
}

void StopCountdown(int client) {

	if ( IsValidHandle( timer_buff[client] ) )
		KillTimer(timer_buff[client]);

	buff_remain[client] = 0.0;

}
public void OnClientPutInServer(int client) {

	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
}

public void OnClientDisconnect_Post(int client) {

	StopCountdown(client);

	SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
}

public void OnWeaponSwitchPost(int client, int weapon) {

	if (isAliveSurvivor(client) && !keep_switch) 

		StopCountdown(client);
}

enum {
	Firing = 0,
	Deploying,
	Reloading,
	MeleeSwinging
}

public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier) {
	if (buff_actions & (1 << MeleeSwinging) && buff_remain[client] > 0)
		speedmodifier *= speed_rate;
}

public  void WH_OnReloadModifier(int client, int weapon, int weapontype, float &speedmodifier) {
	if (buff_actions & (1 << Reloading) && buff_remain[client] > 0)
		speedmodifier *= speed_rate;
}

public void WH_OnGetRateOfFire(int client, int weapon, int weapontype, float &speedmodifier) {
	if (buff_actions & (1 << Firing) && buff_remain[client] > 0)
		speedmodifier *= speed_rate;
}

public void WH_OnDeployModifier(int client, int weapon, int weapontype, float &speedmodifier) {
	if (buff_actions & (1 << Deploying) && buff_remain[client] > 0)
		speedmodifier *= speed_rate;
}

/*Stocks below*/

stock bool isAliveSurvivor(int client) {
	return isClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

stock bool isClient(int client) {
	return isClientIndex(client) && IsValidEntity(client) && IsClientInGame(client);
}

stock bool isClientIndex(int client) {
	return (1 <= client <= MaxClients);
}
