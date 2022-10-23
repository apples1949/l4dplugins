#define PLUGIN_VERSION "1.2.3"

/*
 *	v1.0 just released; 6-2-22
 *	v1.0.1 fix issue 'double buff gain under 100 health'; 6-2-22
 *	v1.0.2 fix issue 'switch weapon quickly before pills use will cause wrong health record'; 7-2-22
 *	v1.1 add feature 'First Aid support', now name change to 'medicines no more limited', thanks my best friend i want heal for him; 9-2-22
 *	v1.1.1 overflow temp health of first aid causes also can turn to health; 9-2-22
 *	v1.1.2 optional to stop player wasted pills when health reached cap 'medicines_unlimited_allow_fail', plugin switch and unload work better now; 9-2-22
 *	v1.2 support record adrenaline duration; 9-2-22
 *	v1.2.1 fix issue 'adrenaline duration not corretly work'; 28-2-22
 *	v1.2.2 stricter check patch; 14-March-2022
 *	v1.2.3 fix wrong adrenaline duration, thanks to Silvers; 17-October-2022
 */
#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools>
#include <sourcemod>

#define EventPills "pills_used"
#define EventAdrenaline "adrenaline_used"

ConVar Enabled;
ConVar Pills_decay;			float pills_decay;
ConVar Pills_cap;
ConVar Pills_buff;			float pills_buff;
ConVar Adrenaline_buff;		float adrenaline_buff;
ConVar Health_max;			float health_max;
ConVar Overflow_turn;		float overflow_turn;
ConVar First_aid_percent;	float first_aid_health;
ConVar First_aid_cap;
ConVar Allow_fail;			bool allow_fail;
ConVar Adrenaline_duration;	float adrenaline_duration;

bool isLeft4Dead2 = false;

enum L4DWeaponSlot
{
	L4DWeaponSlot_Primary			= 0,
	L4DWeaponSlot_Secondary			= 1,
	L4DWeaponSlot_Grenade			= 2,
	L4DWeaponSlot_FirstAid			= 3,
	L4DWeaponSlot_Pills				= 4
}

public Plugin myinfo = {
	name = "[L4D & L4D2] Medicines No More Limited",
	author = "NoroHime",
	description = "ate more pills and gets more pain",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/NoroHime/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	char game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));

	if (StrEqual(game_name, "left4dead2", false)) {
		isLeft4Dead2 = true;
	}
	return APLRes_Success; 
}

public void OnPluginStart() {
	CreateConVar("medicines_unlimited_version", PLUGIN_VERSION, "Version of 'Medicines No More Limited'", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	Enabled = CreateConVar("medicines_unlimited_enable", "1", "是否启用插件", FCVAR_NOTIFY);
	Health_max = CreateConVar("medicines_unlimited_health_max", "225", "血量上限", FCVAR_NOTIFY, true, 100.0);
	Overflow_turn = CreateConVar("medicines_unlimited_overflow_turn", "0.5", "当虚血达到最大值时，将溢出的虚血变成实血, 0.5: 溢出的虚血一半变成实血 0: 关闭 1: 全部变成实血", FCVAR_NOTIFY, true, 0.0);
	Pills_decay = FindConVar("pain_pills_decay_rate");
	Pills_cap = FindConVar("pain_pills_health_threshold");
	Pills_buff = FindConVar("pain_pills_health_value");
	Adrenaline_buff = FindConVar("adrenaline_health_buffer");
	First_aid_percent = FindConVar("first_aid_heal_percent");
	First_aid_cap = FindConVar("first_aid_kit_max_heal");
	Allow_fail = CreateConVar("medicines_unlimited_allow_fail", "0", "允许使用疼痛药，即使健康状况达到上限，但只是在使用过程中变成虚血，设置为0可以阻止玩家浪费药", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	Adrenaline_duration = FindConVar("adrenaline_duration");

	AutoExecConfig(true, "l4d_medicines_unlimited");

	Enabled.AddChangeHook(OnConVarChanged);
	Pills_decay.AddChangeHook(OnConVarChanged);
	Pills_cap.AddChangeHook(OnConVarChanged);
	Pills_buff.AddChangeHook(OnConVarChanged);
	Adrenaline_buff.AddChangeHook(OnConVarChanged);
	Health_max.AddChangeHook(OnConVarChanged);
	Overflow_turn.AddChangeHook(OnConVarChanged);
	First_aid_percent.AddChangeHook(OnConVarChanged);
	First_aid_cap.AddChangeHook(OnConVarChanged);
	Allow_fail.AddChangeHook(OnConVarChanged);
	Adrenaline_duration.AddChangeHook(OnConVarChanged);
	
	ApplyCvars();
}

public void OnPluginEnd() {
	ResetControlledCvars();
}

public void ResetControlledCvars() {
	ResetConVar(Pills_cap);
	ResetConVar(First_aid_cap);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	ApplyCvars();
}

public void OnConfigsExecuted() {
	ApplyCvars();
}

public void ApplyCvars() {

	static bool hooked = false;
	bool enabled = Enabled.BoolValue;

	if (enabled && !hooked) {

		HookEvent("pills_used_fail", OnPillsUsedFail);
		HookEvent("weapon_fire", OnWeaponFire);
		HookEvent(EventAdrenaline, OnBuffingPre, EventHookMode_Pre);
		HookEvent(EventPills, OnBuffingPre, EventHookMode_Pre);
		HookEvent("heal_begin", OnHealBegin);
		HookEvent("heal_end", OnHealEnd, EventHookMode_Pre);
		HookEvent("heal_success", OnHealSucessPre, EventHookMode_Pre); //pre hook for better thirparty plugin support
		HookEvent("heal_interrupted", OnHealInterrupted, EventHookMode_Pre);

		hooked = true;

	} else if (!enabled && hooked) {

		UnhookEvent("pills_used_fail", OnPillsUsedFail);
		UnhookEvent("weapon_fire", OnWeaponFire);
		UnhookEvent(EventAdrenaline, OnBuffingPre, EventHookMode_Pre);
		UnhookEvent(EventPills, OnBuffingPre, EventHookMode_Pre); //seems unhook not twice needed
		UnhookEvent("heal_begin", OnHealBegin);
		UnhookEvent("heal_end", OnHealEnd, EventHookMode_Pre);
		UnhookEvent("heal_success", OnHealSucessPre, EventHookMode_Pre);
		UnhookEvent("heal_interrupted", OnHealInterrupted, EventHookMode_Pre);

		hooked = false;
	}

	pills_decay = Pills_decay.FloatValue;
	health_max = Health_max.FloatValue;
	pills_buff = Pills_buff.FloatValue;
	adrenaline_buff = Adrenaline_buff.FloatValue;
	overflow_turn = Overflow_turn.FloatValue;
	first_aid_health = First_aid_percent.FloatValue * 100;
	adrenaline_duration = Adrenaline_duration.FloatValue;

	if (enabled){
		Pills_cap.SetFloat(health_max - 1);
		First_aid_cap.SetFloat(health_max - 1);
	} else 
		ResetControlledCvars();
	
}


static int remaining_health[MAXPLAYERS + 1]; //recording for proper health
static float remaining_buffer[MAXPLAYERS + 1];
static float remaining_adrenaline[MAXPLAYERS + 1];

public void OnWeaponFire(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	char weapon_name[32];
	event.GetString("weapon", weapon_name, sizeof(weapon_name));

	bool isAdrenaline = strcmp(weapon_name, "adrenaline") == 0;
	bool isPills = strcmp(weapon_name, "pain_pills") == 0;

	if (isAdrenaline || isPills)
		RecordHealth(client);
}


static int healing[MAXPLAYERS + 1]; //event 'Heal_End' wrong data, fix it by plugin

public void OnHealBegin(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	int subject = GetClientOfUserId(event.GetInt("subject"));

	if (isAliveSurvivor(subject))
		healing[client] = subject; //record healing target
}

public void OnHealEnd(Event event, const char[] name, bool dontBroadcast) {

	int client = GetClientOfUserId(event.GetInt("userid")); //subject data always itself, just read from healer
	if (isAliveSurvivor(client) && isAliveSurvivor(healing[client]))
		RecordHealth(healing[client]); //record health for proper target
}

public void OnHealInterrupted(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (isClientIndex(client))
		healing[client] = 0;
}

public void OnHealSucessPre(Event event, const char[] name, bool dontBroadcast) {

	int client = GetClientOfUserId(event.GetInt("subject"));

	if (isAliveSurvivor(client)) {

		RestoreHealth(client);
		AddHealth(client, first_aid_health);
		AddBuffer(client, 0.0);
	}
}

public void OnBuffingPre(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (isAliveSurvivor(client) && remaining_health[client] > 0 || remaining_buffer[client] > 0) {

		RestoreHealth(client);

		if (strcmp(name, EventPills) == 0)
			AddBuffer(client, pills_buff);

		if (strcmp(name, EventAdrenaline) == 0) {

			AddBuffer(client, adrenaline_buff);
			Terror_SetAdrenalineTime(client,  Terror_GetAdrenalineTime(client) + adrenaline_duration);
		}
	}
}

public Action OnPillsUsedFail(Event event, const char[] name, bool dontBroadcast) {

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	bool isPills = IsValidEntity(GetPlayerWeaponSlot(client, view_as<int>(L4DWeaponSlot_Pills)));

	if (isPills && allow_fail && isAliveSurvivor(client)) {

		AddBuffer(client, pills_buff);
		L4D_RemoveWeaponSlot(client, L4DWeaponSlot_Pills);

		Event ate = CreateEvent("pills_used");
		if (ate) {
			ate.SetInt("userid", userid);
			ate.SetInt("subject", userid);
			ate.Fire();
		}

		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void RecordHealth(int client) {

	remaining_health[client] = GetClientHealth(client);
	remaining_buffer[client] = GetTempHealth(client);

	if (isLeft4Dead2)
		remaining_adrenaline[client] = Terror_GetAdrenalineTime(client);
}

void RestoreHealth(int client) {

	SetEntityHealth(client, remaining_health[client]); //read reacord to prevent game health modify
	remaining_health[client] = 0;
	SetTempHealth(client, remaining_buffer[client]);
	remaining_buffer[client] = 0.0;

	if (isLeft4Dead2)
		Terror_SetAdrenalineTime(client, remaining_adrenaline[client]);

}

void AddHealth(int client, float health) {
	int healthing = GetClientHealth(client);

	if (healthing + health > health_max)
		SetEntityHealth(client, RoundToFloor(health_max));
	else
		SetEntityHealth(client, healthing + RoundToFloor(health));
}

void AddBuffer(int client, float buff) {

	float buffing = GetTempHealth(client);
	int health = GetClientHealth(client);

	if (health + buffing + buff > health_max) {

		if (overflow_turn > 0) {

			float overflow = FloatAbs(health_max - health - buffing - buff) * overflow_turn;

			if (health + overflow > health_max) {

				SetEntityHealth(client, RoundToFloor(health_max));
				SetTempHealth(client, 0.0);

			} else {

				SetEntityHealth(client, health + RoundToFloor(overflow));
				SetTempHealth(client, health_max - health - overflow);
			}
		} else 
			SetTempHealth(client, health_max - health);
		
	} else 
		SetTempHealth(client, buffing + buff);
}

stock bool isAliveSurvivor(int client) {
	return isClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}
  
stock bool isClient(int client) {
	return isClientIndex(client) && IsValidEntity(client) && IsClientInGame(client);
}

stock bool isClientIndex(int client) {
	return (1 <= client <= MaxClients);
}


// ====================================================================================================
//										STOCKS - HEALTH (left4dhooks.sp)
// ====================================================================================================
float GetTempHealth(int client)
{
	float fGameTime = GetGameTime();
	float fHealthTime = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
	float fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (fGameTime - fHealthTime) * pills_decay;
	return fHealth < 0.0 ? 0.0 : fHealth;
}

void SetTempHealth(int client, float fHealth)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fHealth < 0.0 ? 0.0 : fHealth);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}

/**
 * Removes the weapon from a client's weapon slot
 *
 * @param client		Player's index.
 * @param slot			Slot index.
 * @noreturn
 * @error				Invalid client or lack of mod support.
 */

stock void L4D_RemoveWeaponSlot(int client, L4DWeaponSlot slot)
{
	int weaponIndex;
	while ((weaponIndex = GetPlayerWeaponSlot(client, view_as<int>(slot))) != -1)
	{
		RemovePlayerItem(client, weaponIndex);
		RemoveEdict(weaponIndex);
	}
}

/**
 * Sets the adrenaline effect duration of a survivor.
 *
 * @param iClient		Client index of the survivor.
 * @param flDuration		Duration of the adrenaline effect.
 *
 * @error			Invalid client index.
 **/
// L4D2 only.
stock void Terror_SetAdrenalineTime(int iClient, float flDuration)
{
	// Get CountdownTimer address
	static int timerAddress = -1;
	if(timerAddress == -1)
	{
		timerAddress = FindSendPropInfo("CTerrorPlayer", "m_bAdrenalineActive") - 12;
	}
	
	//timerAddress + 4 = Duration
	//timerAddress + 8 = TimeStamp
	SetEntDataFloat(iClient, timerAddress + 4, flDuration);
	SetEntDataFloat(iClient, timerAddress + 8, GetGameTime() + flDuration);
	SetEntProp(iClient, Prop_Send, "m_bAdrenalineActive", (flDuration <= 0.0 ? 0 : 1), 1);
}

/**
 * Returns the remaining duration of a survivor's adrenaline effect.
 *
 * @param iClient		Client index of the survivor.
 *
 * @return 			Remaining duration or -1.0 if there's no effect.
 * @error			Invalid client index.
 **/
// L4D2 only.
stock float Terror_GetAdrenalineTime(int iClient)
{
	// Get CountdownTimer address
	static int timerAddress = -1;
	if(timerAddress == -1)
	{
		timerAddress = FindSendPropInfo("CTerrorPlayer", "m_bAdrenalineActive") - 12;
	}
	
	//timerAddress + 8 = TimeStamp
	float flGameTime = GetGameTime();
	float flTime = GetEntDataFloat(iClient, timerAddress + 8);
	if(flTime <= flGameTime)
		return -1.0;

	if (!GetEntProp(iClient, Prop_Send, "m_bAdrenalineActive"))
		return -1.0;

	return flTime - flGameTime;
}
