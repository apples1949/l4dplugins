#define ZOMBIECLASS_TANK 8
#define PLUGIN_VERSION "1.5"
#define CVAR_SHOW FCVAR_NOTIFY
#define CVAR_HIDE~FCVAR_NOTIFY

ConVar displayType,
Logging;
int damageReport[MAXPLAYERS + 1][MAXPLAYERS + 1],
startHealth[MAXPLAYERS + 1],
class[MAXPLAYERS + 1],
clientdamage[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "Tank Damage Reporter",
	author = "Skyy / Foxhound",
	description = "Displays Damage Information on Tank Death.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=1677234"
}

public void OnPluginStart() {
	CreateConVar("tdr_version", PLUGIN_VERSION, "plugin version.", CVAR_SHOW);

	displayType = CreateConVar("tdr_display_type", "1", "0 - Displays tank damage info to players privately. 1 - Displays all information publicly.", CVAR_SHOW);
	Logging = CreateConVar("tdr_logging", "1", "whether or not to enable logging.", CVAR_SHOW);

	AutoExecConfig(true, "tdr_config");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("tank_killed", Event_TankKilled);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated);
}

public void OnClientPostAdminCheck(int client) {
	if (client != 0 && !IsFakeClient(client)) {
		EC_OnClientPostAdminCheck(client);
	}
}

public Action Event_TankKilled(Handle event, const char[] event_name, bool dontBroadcast) {
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsClientIndexOutOfRange(victim)) return;
	if (!IsFakeClient(victim)) return;
	if (GetClientTeam(victim) != 3) {
		class[victim] = 0;
		return;
	}
	DisplayTankInformation(victim);
}

public Action Event_PlayerSpawn(Handle event, const char[] event_name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientInGame(client)) return;
	if (GetClientTeam(client) != 3) {
		class[client] = 0;
		return;
	}

	class[client] = GetEntProp(client, Prop_Send, "m_zombieClass");

	if (class[client] == ZOMBIECLASS_TANK) {
		clearUserData(client);
		startHealth[client] = GetClientHealth(client);
	}
}

public Action Event_PlayerHurt(Handle event, const char[] event_name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int damage = GetEventInt(event, "dmg_health");

	if (IsClientIndexOutOfRange(victim)) return;
	if (IsClientIndexOutOfRange(attacker) || !IsClientInGame(attacker) || IsFakeClient(attacker) || GetClientTeam(attacker) != 2) return;
	if (!IsClientInGame(victim) || GetClientTeam(victim) != 3) return;

	class[victim] = GetEntProp(victim, Prop_Send, "m_zombieClass");
	if (class[victim] != ZOMBIECLASS_TANK) return;

	if (!IsTankIncapacitated(victim)) damageReport[attacker][victim] += damage;
	if (damageReport[attacker][victim] > startHealth[victim]) damageReport[attacker][victim] = startHealth[victim];
}

public Action Event_PlayerIncapacitated(Handle event, const char[] event_name, bool dontBroadcast) {
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsClientIndexOutOfRange(victim)) return;
	if (IsFakeClient(victim)) return;
	if (GetClientTeam(victim) != 3) {
		class[victim] = 0;
		return;
	}
	DisplayTankInformation(victim);
}

void EC_OnClientPostAdminCheck(int client) {

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i)) continue;
		damageReport[client][i] = 0;
		damageReport[i][client] = 0;
	}
	if (GetConVarInt(Logging) == 1) LogToFile("tdr_log", "[TDR] Cleared Data for user %N", client);
}

void clearUserData(int client) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientIndexOutOfRange(i) || !IsClientInGame(i) || IsFakeClient(i)) continue;
		damageReport[i][client] = 0;
	}
	if (GetConVarInt(Logging) == 1) LogToFile("tdr_log", "[TDR] Cleared All User Data for %N", client);
}

stock bool: IsClientIndexOutOfRange(int client) {
	if (client <= 0 || client > MaxClients) return true;
	else return false;
}

stock bool: IsTankIncapacitated(int client) {
	if (IsIncapacitated(client) || GetClientHealth(client) < 1) return true;
	return false;
}

stock bool: IsIncapacitated(int client) {
	return bool: GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

void DisplayTankInformation(int victim) {
  if (GetConVarInt(Logging) == 1) LogToFile("tdr_log", "[TDR] Displaying Damage Report for Dead Tank: %N", victim);
  char pct[16];
  Format(pct, sizeof(pct), "%");

  if (GetConVarInt(displayType) == 1) {

    for (int i = 1; i <= MaxClients; i++) {
      if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 2) continue;
      PrintToChat(i, "\x05[\x04TDR\x05] \x01Tank player: \x04%N \x01has been killed.", victim);
    }
    for (int i = 1; i <= MaxClients; i++) {
      if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 2) continue;
      if (damageReport[i][victim] < 1) continue;
      float damage = (damageReport[i][victim] * 1.0) / (startHealth[victim] * 1.0) * 100.0;

      clientdamage[i] = RoundToZero(damage);

    }

    for (int MaxToMin = 101; MaxToMin > 0; MaxToMin--) {
      for (int ii = 1; ii <= MaxClients; ii++) {

        if (!IsClientInGame(ii) || IsFakeClient(ii) || GetClientTeam(ii) != 2) continue;

        if (MaxToMin == clientdamage[ii])

          PrintToChatAll("\x03%N \x05[\x04%d\x05]\x01 - \x03(\x04%i%s\x03)", ii, damageReport[ii][victim], clientdamage[ii], pct);
        clientdamage[ii] = -1;

      }
    }

  } else {

    for (int i = 1; i <= MaxClients; i++) {
      if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 2) continue;
      if (damageReport[i][victim] < 1) continue;
      float damage = (damageReport[i][victim] * 1.0) / (startHealth[victim] * 1.0) * 100.0;
      PrintToChat(i, "\x05[\x04TDR\x05] \x01Tank player: \x04%N \x01has been killed.", victim);

      PrintToChat(i, "\x01Damage Done: \x03%N \x05[\x04%d\x05]\x01 - \x03(\x04%i%s\x03)", i, damageReport[i][victim], RoundToZero(damage), pct); //NEW
    }
  }
}