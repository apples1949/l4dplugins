#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_NAME				"L4D2 Door Lock"
#define PLUGIN_AUTHOR			"Glide Loading, sorallll"
#define PLUGIN_DESCRIPTION		"Saferoom Door locked until all players loaded and infected are ready to spawn"
#define PLUGIN_VERSION			"2.7.2"
#define PLUGIN_URL				"http://forums.alliedmods.net/showpost.php?p=1373587&postcount=136"

#define CVAR_FLAGS				FCVAR_NOTIFY
#define SOUND_COUNTDOWN			"buttons/blip1.wav"
#define SOUND_MOVEOUT			"ui/survival_teamrec.wav"
#define SOUND_BREAK1			"physics/metal/metal_box_break1.wav"
#define SOUND_BREAK2			"physics/metal/metal_box_break2.wav"

Handle
	g_hTimer;

ConVar
	g_cSbStop,
	g_cNbStop,
	g_cAllow,
	g_cGameMode,
	g_cModes,
	g_cModesOff,
	g_cModesTog,
	g_cBreakTheDoor,
	g_cPrepareTime1r,
	g_cPrepareTime2r,
	g_cClientTimeOut,
	g_cDisplayMode,
	g_cDisplayPanel,
	g_cFreezeNodoor;

bool
	g_bCvarAllow,
	g_bMapStarted,
	g_bFirstRound,
	g_bBreakTheDoor,
	g_bFreezeNodoor,
	g_bFreezeAllowed,
	g_bIsLoading[MAXPLAYERS + 1];

int
	g_iStartDoor,
	g_iCountDown,
	g_iRoundStart,
	g_iPlayerSpawn,
	g_iPrepareTime1r,
	g_iPrepareTime2r,
	g_iClientTimeOut,
	g_iDisplayMode,
	g_iDisplayPanel,
	g_iTimeout[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	LoadTranslations("doorlock.phrases");
	CreateConVar("l4d2_dlock_version", PLUGIN_VERSION, "Plugin version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_REPLICATED);

	g_cAllow =			CreateConVar("l4d2_dlock_allow",		"1",	"0=插件禁用, 1=插件启用.", CVAR_FLAGS);
	g_cModes =			CreateConVar("l4d2_dlock_modes",		"",		"在这些游戏模式中启用插件, 用英文逗号分割 (无空格),(无内容=全模式)", CVAR_FLAGS);
	g_cModesOff =		CreateConVar("l4d2_dlock_modes_off",	"",		"在这些游戏模式中禁用插件, 用英文逗号分割 (无空格),(无内容=无)", CVAR_FLAGS);
	g_cModesTog =		CreateConVar("l4d2_dlock_modes_tog",	"0",	"在这些游戏模式中启用插件. 0=全模式, 1=战役, 2=生还者, 4=对抗, 8=清道夫. 多个模式则设置多个模式值的和", CVAR_FLAGS);
	g_cBreakTheDoor =	CreateConVar("l4d2_dlock_weakdoor",		"1",	"如果为1，则安全屋的门开启后将会掉落.", CVAR_FLAGS);
	g_cPrepareTime1r =	CreateConVar("l4d2_dlock_prepare1st",	"7",	"在所有玩家加载完毕后，插件将等待多少秒，然后开始在地图上进行第一轮游戏(适用于对抗类型的模式)", CVAR_FLAGS);
	g_cPrepareTime2r =	CreateConVar("l4d2_dlock_prepare2nd",	"7",	"在所有玩家加载完毕后，插件将等待多少秒，然后开始在地图上进行第二轮游戏(适用于对抗类型的模式)", CVAR_FLAGS);
	g_cClientTimeOut =	CreateConVar("l4d2_dlock_timeout",		"45",	"在地图开始后，插件会等待多少秒才会放弃等待连接中的玩家？", CVAR_FLAGS);
	g_cDisplayMode =	CreateConVar("l4d2_dlock_displaymode",	"1",	"设置倒计时的显示模式。(0-隐藏,1-游戏提示,2-屏幕中心,3-聊天框.任何其他数值都可以隐藏倒计时)", CVAR_FLAGS);
	g_cDisplayPanel =	CreateConVar("l4d2_dlock_displaypanel",	"2",	"玩家状态面板的显示模式,0-不显示，1-隐藏连接失败的玩家，2-完整显示", CVAR_FLAGS);
	g_cFreezeNodoor =	CreateConVar("l4d2_dlock_freezenodoor",	"1",	"如果没有启动安全室的门，则冻结生还者", CVAR_FLAGS);

	g_cSbStop =			FindConVar("sb_stop");
	g_cNbStop =			FindConVar("nb_stop");
	g_cGameMode =		FindConVar("mp_gamemode");
	g_cGameMode.AddChangeHook(CvarChanged_Allow);
	g_cModes.AddChangeHook(CvarChanged_Allow);
	g_cModesOff.AddChangeHook(CvarChanged_Allow);
	g_cModesTog.AddChangeHook(CvarChanged_Allow);
	g_cAllow.AddChangeHook(CvarChanged_Allow);

	g_cBreakTheDoor.AddChangeHook(CvarChanged);
	g_cPrepareTime1r.AddChangeHook(CvarChanged);
	g_cPrepareTime2r.AddChangeHook(CvarChanged);
	g_cClientTimeOut.AddChangeHook(CvarChanged);
	g_cDisplayMode.AddChangeHook(CvarChanged);
	g_cDisplayPanel.AddChangeHook(CvarChanged);
	g_cFreezeNodoor.AddChangeHook(CvarChanged);

	//AutoExecConfig(true);
}

public void OnConfigsExecuted() {
	IsAllowed();
}

void CvarChanged_Allow(ConVar convar, const char[] oldValue, const char[] newValue) {
	IsAllowed();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	bool last = g_bBreakTheDoor;

	g_bBreakTheDoor =	g_cBreakTheDoor.BoolValue;
	g_iPrepareTime1r =	g_cPrepareTime1r.IntValue;
	g_iPrepareTime2r =	g_cPrepareTime2r.IntValue;
	g_iClientTimeOut =	g_cClientTimeOut.IntValue;
	g_iDisplayMode =	g_cDisplayMode.IntValue;
	g_iDisplayPanel =	g_cDisplayPanel.IntValue;
	g_bFreezeNodoor =	g_cFreezeNodoor.BoolValue;

	if (last != g_bBreakTheDoor) {
		if (g_iStartDoor && EntRefToEntIndex(g_iStartDoor) != -1)
			UnhookSingleEntityOutput(g_iStartDoor, "OnOpen", OnOpen);
	}
}

//Silvers
void IsAllowed() {
	bool bCvarAllow = g_cAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if (g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true) {
		g_bCvarAllow = true;
		//InitPlugin();
		HookEvents(true);
	}
	else if (g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false)) {
		g_bCvarAllow = false;
		HookEvents(false);
		ResetPlugin();
		DeleteTimer();

		if (g_iStartDoor && EntRefToEntIndex(g_iStartDoor) != -1)
			UnhookSingleEntityOutput(g_iStartDoor, "OnOpen", OnOpen);
	}
}

int g_iCurrentMode;
public void L4D_OnGameModeChange(int gamemode) {
	g_iCurrentMode = gamemode;
}

bool IsAllowedGameMode() {
	if (!g_cGameMode)
		return false;

	if (!g_iCurrentMode)
		g_iCurrentMode = L4D_GetGameModeType();

	if (!g_bMapStarted)
		return false;

	int iCvarModesTog = g_cModesTog.IntValue;
	if (iCvarModesTog && !(iCvarModesTog & g_iCurrentMode))
		return false;

	char sGameModes[64], sGameMode[64];
	g_cGameMode.GetString(sGameMode, sizeof sGameMode);
	Format(sGameMode, sizeof sGameMode, ",%s,", sGameMode);

	g_cModes.GetString(sGameModes, sizeof sGameModes);
	if (sGameModes[0]) {
		Format(sGameModes, sizeof sGameModes, ",%s,", sGameModes);
		if (StrContains(sGameModes, sGameMode, false) == -1)
			return false;
	}

	g_cModesOff.GetString(sGameModes, sizeof sGameModes);
	if (sGameModes[0]) {
		Format(sGameModes, sizeof sGameModes, ",%s,", sGameModes);
		if (StrContains(sGameModes, sGameMode, false) != -1)
			return false;
	}

	return true;
}

void HookEvents(bool hook) {
	if (hook) {
		HookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
		HookEvent("round_start",	Event_RoundStart,	EventHookMode_PostNoCopy);
		HookEvent("player_spawn",	Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		HookEvent("player_team",	Event_PlayerTeam);
	}
	else {
		UnhookEvent("round_end",	Event_RoundEnd,		EventHookMode_PostNoCopy);
		UnhookEvent("round_start",	Event_RoundStart,	EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn",	Event_PlayerSpawn,	EventHookMode_PostNoCopy);
		UnhookEvent("player_team",	Event_PlayerTeam);
	}
}

public Action OnPlayerRunCmd(int client) {
	if (!g_iCountDown || !g_bFreezeAllowed)
		return Plugin_Continue;

	if (GetClientTeam(client) == 2)
		SetEntityMoveType(client, MOVETYPE_NONE);
		
	return Plugin_Continue;
}

public void OnClientDisconnect(int client) {
	g_iTimeout[client] = 0;
	g_bIsLoading[client] = false;
}

public void OnMapStart() {
	g_bMapStarted = true;
	g_bFirstRound = true;

	PrecacheSound(SOUND_BREAK1);
	PrecacheSound(SOUND_BREAK2);
	PrecacheSound(SOUND_MOVEOUT);
	PrecacheSound(SOUND_COUNTDOWN);
}

public void OnMapEnd() {
	ResetPlugin();
	g_bMapStarted = false;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	ResetPlugin();
	g_bFirstRound = false;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		InitPlugin();
	g_iRoundStart = 1;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		InitPlugin();
	g_iPlayerSpawn = 1;
}

void ResetPlugin() {
	g_iCountDown = 0;
	g_iStartDoor = 0;
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bFreezeAllowed = false;

	DeleteTimer();
}

void DeleteTimer() {
	if (g_hTimer) {
		UnFreezeSurBots();
		UnFreezePlayers();
	}
	delete g_hTimer;
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	if (!g_iCountDown)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client) && !IsFakeClient(client))
		ResetLoadingState(client);
}

void ResetLoadingState(int client, bool state = false) {
	g_iTimeout[client] = 0;
	g_bIsLoading[client] = state;
}

void StartSequence() {
	DeleteTimer();

	for (int i = 1; i <= MaxClients; i++)
		ResetLoadingState(i, true);

	if (g_iStartDoor && EntRefToEntIndex(g_iStartDoor) != -1) {
		g_iCountDown = -1;
		LockDoor();
		FreezeSurBots();
		g_hTimer = CreateTimer(1.0, tmrLoading, _, TIMER_REPEAT);
	}
	else if (g_bFreezeNodoor) {
		g_iCountDown = -1;
		g_bFreezeAllowed = true;
		g_cNbStop.SetInt(1); // 没有安全门则连同僵尸特感一起定住
		g_hTimer = CreateTimer(1.0, tmrLoading, _, TIMER_REPEAT);
	}
}

Action tmrLoading(Handle timer) {
	if (g_iCountDown >= 0) {
		if (g_iCountDown >= (g_bFirstRound ? g_iPrepareTime1r : g_iPrepareTime2r)) {
			g_iCountDown = 0;

			UnLockDoor();
			UnFreezeSurBots();
			UnFreezePlayers();

			PlaySound(SOUND_MOVEOUT);
			PrintTextAll("%t", "DL_Moveout");

			g_hTimer = null;
			return Plugin_Stop;
		}
		else {
			PlaySound(SOUND_COUNTDOWN);

			if (!g_bFreezeAllowed)
				PrintTextAll("%t", "DL_Locked", (g_bFirstRound ? g_iPrepareTime1r : g_iPrepareTime2r) - g_iCountDown);
			else
				PrintTextAll("%t", "DL_Frozen", (g_bFirstRound ? g_iPrepareTime1r : g_iPrepareTime2r) - g_iCountDown);

			g_iCountDown++;
		}
	}
	else
		g_iCountDown = IsFinishedLoading() ? 0 : -1;

	return Plugin_Continue;
}

void LoadingPanel() {
	int i = 1;
	int loading;
	int connected;
	int loadFailed;
	for (; i <= MaxClients; i++) {
		if (IsClientConnected(i) && !IsFakeClient(i)) {
			if (g_bIsLoading[i])
				loading++;
			else if (g_iTimeout[i] >= g_iClientTimeOut)
				loadFailed++;
			else 
				connected++;
		}
	}

	Panel panel;
	static char buffer[254];

	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) && !IsFakeClient(client)) {
			panel = new Panel();

			FormatEx(buffer, sizeof buffer, "%T", "DL_Menu_Header", client);
			panel.DrawText(buffer);

			if (loading) {
				FormatEx(buffer, sizeof buffer, "%T", "DL_Menu_Connecting", client);
				panel.DrawText(buffer);

				loading = 0;
				for (i = 1; i <= MaxClients; i++) {
					if (IsClientConnected(i) && !IsFakeClient(i) && g_bIsLoading[i]) {
						loading++;
						FormatEx(buffer, sizeof buffer, "->%d. %N", loading, i);
						panel.DrawText(buffer);
					}
				}
			}

			if (connected) {
				FormatEx(buffer, sizeof buffer, "%T", "DL_Menu_Ingame", client);
				panel.DrawText(buffer);

				connected = 0;
				for (i = 1; i <= MaxClients; i++) {
					if (IsClientConnected(i) && !IsFakeClient(i) && !g_bIsLoading[i] && g_iTimeout[i] < g_iClientTimeOut) {
						connected++;
						FormatEx(buffer, sizeof buffer, "->%d. %N", connected, i);
						panel.DrawText(buffer);
					}
				}
			}

			if (g_iDisplayPanel > 1) {
				if (loadFailed) {
					FormatEx(buffer, sizeof buffer, "%T", "DL_Menu_Fail", client);
					panel.DrawText(buffer);

					loadFailed = 0;
					for (i = 1; i <= MaxClients; i++) {
						if (IsClientConnected(i) && !IsFakeClient(i) && !g_bIsLoading[i] && g_iTimeout[i] >= g_iClientTimeOut) {
							loadFailed++;
							FormatEx(buffer, sizeof buffer, "->%d. %N", loadFailed, i);
							panel.DrawText(buffer);
						}
					}
				}
			}

			panel.Send(client, PanelHandler, 5);
			delete panel;
		}
	}
}

int PanelHandler(Menu menu, MenuAction action, int param1, int param2) {
	return 0;
}

void LockDoor() {
	if (g_iStartDoor && EntRefToEntIndex(g_iStartDoor) != -1)
		SetEntProp(g_iStartDoor, Prop_Send, "m_spawnflags", DOOR_FLAG_SILENT|DOOR_FLAG_IGNORE_USE);
}

void UnLockDoor() {
	if (g_iStartDoor && EntRefToEntIndex(g_iStartDoor) != -1)
		SetEntProp(g_iStartDoor, Prop_Send, "m_spawnflags", DOOR_FLAG_USE_CLOSES);
}

void FreezeSurBots() {
	g_cSbStop.SetInt(1);
}

void UnFreezeSurBots() {
	g_cSbStop.SetInt(0);
}

void UnFreezePlayers() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetEntityMoveType(i) == MOVETYPE_NONE) {
			SetEntityMoveType(i, MOVETYPE_WALK);
		}
	}

	g_cNbStop.SetInt(0);
}

void InitPlugin() {
	g_iStartDoor = 0;
	int ent = L4D_GetCheckpointFirst();
	if (ent != -1 && GetEntProp(ent, Prop_Send, "m_bLocked") == 1) {
		g_iStartDoor = EntIndexToEntRef(ent);
		if (!g_bBreakTheDoor) {
			SetVariantString("OnOpen !self:Lock::0.0:-1");
			AcceptEntityInput(ent, "AddOutput");
		}
		else
			HookSingleEntityOutput(ent, "OnOpen", OnOpen);
	}

	StartSequence();
}

//https://forums.alliedmods.net/showthread.php?p=2700212
void OnOpen(const char[] output, int entity, int activator, float delay) {
	char sModel[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof sModel);

	float vPos[3], vAng[3], vDir[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
	// GetEntPropVector(entity, Prop_Data, "m_angRotationOpenForward", vDir);

	// Make old door non-solid, so physics door does not collide and stutter
	// Collison group fixes "in solid list (not solid)"
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);
	SetEntProp(entity, Prop_Data, "m_CollisionGroup", 1);

	// Teleport up to prevent using and door shadow showing. Must stay alive or L4D1 crashes.
	vPos[2] += 10000.0;
	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	vPos[2] -= 10000.0;

	// Hide old door
	SetEntityRenderMode(entity, RENDER_TRANSALPHA);
	SetEntityRenderColor(entity, 0, 0, 0, 0);

	UnhookSingleEntityOutput(entity, "OnOpen", OnOpen);

	// Create new physics door
	int ent = CreateEntityByName("prop_physics");
	DispatchKeyValue(ent, "spawnflags", "4"); // Prevent collision - make non-solid
	DispatchKeyValue(ent, "model", sModel);
	DispatchSpawn(ent);

	// Teleport to current door, ready to take it's attachments
	TeleportEntity(ent, vPos, vAng, NULL_VECTOR);

	// Handle fall animation from old door
	SetVariantString("unlock");
	AcceptEntityInput(entity, "SetAnimation");

	SetEntProp(entity, Prop_Send, "m_eDoorState", DOOR_STATE_CLOSING_IN_PROGRESS);
	SetEntProp(entity, Prop_Send, "m_spawnflags", DOOR_FLAG_SILENT|DOOR_FLAG_IGNORE_USE); // Prevent +USE + Door silent

	// Wait for handle to fall (does not work for wooden handle - Last Stand: TODO FIXME) - deleting crashes in L4D1 so keeping it alive.
	// SetVariantString("OnUser4 !self:Kill::1.0:1");
	// AcceptEntityInput(entity, "AddOutput");
	// AcceptEntityInput(entity, "FireUser4");

	// Find attachments, swap to our new door
	entity = EntRefToEntIndex(entity);
	for (int att; att < 2048; att++) {
		if (IsValidEdict(att)) {
			if (HasEntProp(att, Prop_Send, "moveparent") && GetEntPropEnt(att, Prop_Send, "moveparent") == entity) {
				SetVariantString("!activator");
				AcceptEntityInput(att, "SetParent", ent);
			}
		}
	}

	float dist = strcmp(sModel, "models/props_doors/checkpoint_door_-01.mdl") == 0 ? -10.0 : 10.0;

	// Tilt ang away
	GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
	vPos[0] += (vDir[0] * dist);
	vPos[1] += (vDir[1] * dist);
	vAng[0] = dist;
	vDir[0] = 0.0;
	vDir[1] = vAng[1] < 270.0 ? 10.0 : -10.0 * dist;
	vDir[2] = 0.0;

	TeleportEntity(ent, vPos, vAng, vDir);

	EmitSoundToAll(GetRandomInt(0, 1) ? SOUND_BREAK1 : SOUND_BREAK2, ent);
}

bool IsFinishedLoading() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i)) {
			if (!IsClientInGame(i) && !IsFakeClient(i)) {
				g_iTimeout[i]++;
				if (g_bIsLoading[i] && g_iTimeout[i] == 1)
					g_bIsLoading[i] = true;

				if (g_iTimeout[i] == g_iClientTimeOut)
					g_bIsLoading[i] = false;
			}
			else
				g_bIsLoading[i] = false;
		}
		else
			g_bIsLoading[i] = false;
	}

	if (g_iDisplayPanel > 0 && g_bFirstRound)
		LoadingPanel();

	return !IsAnyClientLoading();
}

bool IsAnyClientLoading() {
	for (int i = 1; i <= MaxClients; i++) {
		if (g_bIsLoading[i])
			return true;
	}
	return false;
}

void PrintTextAll(const char[] format, any ...) {
	char buffer[254];
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof buffer, format, 2);
			switch (g_iDisplayMode) {
				case 1:
					PrintHintText(i, "%s", buffer);
				case 2:
					PrintCenterText(i, "%s", buffer);
				case 3:
					PrintToChat(i, "%s", buffer);
			}
		}
	}
}

void PlaySound(const char[] sample) {
	EmitSoundToAll(sample, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}
