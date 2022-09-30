#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

EngineVersion game;
int ZOMBIECLASS_SPECIALS;
int ZOMBIECLASS_TANK;

ConVar cvarAllowBile;
ConVar cvarAllowMolotov;
ConVar cvarAllowPipe;
ConVar cvarTargetTank;
bool allowBile;
bool allowMolotov;
bool allowPipe;
bool targetTank;

bool bChill[2], bTongueOwned[MAXPLAYERS+1], bShootOrder[MAXPLAYERS+1];
int chosenThrower, chosenTarget, failedTimes[MAXPLAYERS+1],
	lastChosen[3];

float throwerPos[3], targetPos[3], fMobPos[3];
ArrayList throwablesFound;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead && test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "[GTB] Plugin Supports L4D(2) Only!");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "[L4D(2)] Grenade Throwing Bots",
	author = "cravenge, Edison1318, Windy Wind, Lux, MasterMe",
	description = "Allows Bots To Throw Grenades Themselves.",
	version = "1.9",
	url = "https://forums.alliedmods.net/showthread.php?t=296150"
};

public void OnPluginStart()
{
	game = GetEngineVersion();
	if (game == Engine_Left4Dead2)
	{
		ZOMBIECLASS_SPECIALS = 7;
		ZOMBIECLASS_TANK = 8;
		cvarAllowBile = CreateConVar("l4d_gtb_allowbile", "1", "允许bot使用胆汁. 0=关闭, 1=开启", FCVAR_NOTIFY);
		cvarAllowBile.AddChangeHook(OnCvarChange);
	}
	else
	{
		ZOMBIECLASS_SPECIALS = 4;
		ZOMBIECLASS_TANK = 5;
	}
	cvarAllowMolotov = CreateConVar("l4d_gtb_allowmolotov", "0", "允许bot使用燃烧瓶. 0=关闭, 1=开启", FCVAR_NOTIFY);
	cvarAllowMolotov.AddChangeHook(OnCvarChange);
	cvarAllowPipe = CreateConVar("l4d_gtb_allowpipe", "1", "允许bot使用自制手雷. 0=关闭, 1=开启", FCVAR_NOTIFY);
	cvarAllowPipe.AddChangeHook(OnCvarChange);
	cvarTargetTank = CreateConVar("l4d_gtb_targettank", "0", "如果bot允许扔燃烧瓶，那么是否允许bot向坦克扔燃烧瓶. 0=关闭, 1=开启", FCVAR_NOTIFY);
	cvarTargetTank.AddChangeHook(OnCvarChange);
	UpdateFromCvars();
	AutoExecConfig(true, "l4d_grenade_throwing_bots");

	HookEvent("round_start", OnRoundStart);
	HookEvent("tongue_grab", OnTongueGrab);
	HookEvent("tongue_release", OnTongueRelease);

	HookEvent("player_hurt", OnPlayerHurt);
}

public void OnMapStart()
{
	throwablesFound = new ArrayList();

	CreateTimer(1.0, CheckForDanger, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity <= 0 || entity > 2048 || classname[0] != 'w' || classname[1] != 'e' || classname[2] != 'a')
	{
		return;
	}

	CreateTimer(2.0, LookForGrenades, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

public Action LookForGrenades(Handle timer, int ref)
{
	int entity = EntRefToEntIndex(ref);
	if (!IsValidEntity(entity))
	{
		return Plugin_Stop;
	}

	char sEntityClass[64];
	GetEntityClassname(entity, sEntityClass, sizeof(sEntityClass));
	if (StrContains(sEntityClass, "weapon_", false) != -1)
	{
		if (IsGrenade(entity))
		{
			if (!IsEquipped(entity))
			{
				for (int i = 0; i < throwablesFound.Length; i++)
				{
					if (entity == throwablesFound.Get(i))
					{
						return Plugin_Stop;
					}
					else if (!IsValidEntity(throwablesFound.Get(i)))
					{
						throwablesFound.Erase(i);
					}
				}
				throwablesFound.Push(entity);
			}
		}
	}

	return Plugin_Stop;
}

public void OnEntityDestroyed(int entity)
{
	if (throwablesFound != null && IsGrenade(entity))
	{
		if (!IsEquipped(entity))
		{
			for (int i = 0; i < throwablesFound.Length; i++)
			{
				if (entity == throwablesFound.Get(i))
				{
					throwablesFound.Erase(i);
				}
			}
		}
	}
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	chosenThrower = 0;
	chosenTarget = 0;

	bChill[0] = false;
	bChill[1] = false;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			bShootOrder[i] = false;
			failedTimes[i] = 0;

			bTongueOwned[i] = false;
		}
	}

	for (int i = 0; i < 3; i++)
	{
		lastChosen[i] = 0;

		throwerPos[i] = 0.0;
		targetPos[i] = 0.0;
	}

	return Plugin_Continue;
}

public Action CheckForDanger(Handle timer)
{
	// MasterMe: Although called CheckForDanger() this function only handles
	// grenade throwing towards tanks, hence the check is placed at the top.
	if (!targetTank || !IsServerProcessing() || bChill[0])
	{
		return Plugin_Continue;
	}

	if (chosenThrower == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsSurvivor(i) && IsFakeClient(i) && IsInShape(i) && i != lastChosen[0])
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", throwerPos);

				chosenThrower = i;
				lastChosen[0] = i;

				break;
			}
		}
	}
	else
	{
		if (!IsClientInGame(chosenThrower) || GetClientTeam(chosenThrower) != 2 || !IsPlayerAlive(chosenThrower))
		{
			chosenThrower = 0;
			failedTimes[chosenThrower] = 0;

			return Plugin_Continue;
		}

		if (chosenTarget == 0)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK && !GetEntProp(i, Prop_Send, "m_isGhost", 1))
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", targetPos);
					chosenTarget = i;

					break;
				}
			}
		}
		else
		{
			if (!IsClientInGame(chosenTarget) || GetClientTeam(chosenTarget) != 3 || !IsPlayerAlive(chosenTarget) || GetEntProp(chosenTarget, Prop_Send, "m_zombieClass") != ZOMBIECLASS_TANK)
			{
				chosenTarget = 0;
				failedTimes[chosenThrower] = 0;

				bChill[0] = true;
				CreateTimer(7.5, FireAgain, _, TIMER_FLAG_NO_MAPCHANGE);

				return Plugin_Continue;
			}

			if (CanBeSeen(chosenThrower, chosenTarget, 750.0))
			{
				ChangeToGrenade(chosenThrower, true, _, true);
				bChill[0] = true;
				CreateTimer(15.0, FireAgain, _, TIMER_FLAG_NO_MAPCHANGE);

				float fEyePos[3], fTargetTrajectory[3], fEyeAngles[3];

				GetClientEyePosition(chosenThrower, fEyePos);
				MakeVectorFromPoints(fEyePos, targetPos, fTargetTrajectory);
				GetVectorAngles(fTargetTrajectory, fEyeAngles);

				fEyeAngles[2] -= 7.5;
				TeleportEntity(chosenThrower, NULL_VECTOR, fEyeAngles, NULL_VECTOR);

				bShootOrder[chosenThrower] = true;
				CreateTimer(2.0, TankDelayThrow, GetClientUserId(chosenThrower), TIMER_FLAG_NO_MAPCHANGE);
				CreateTimer(3.0, ChooseAnother, _, TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				if (failedTimes[chosenThrower] >= 10)
				{
					failedTimes[chosenThrower] = 0;

					chosenThrower = 0;
					chosenTarget = 0;
				}
				else
				{
					failedTimes[chosenThrower] += 1;
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action FireAgain(Handle timer)
{
	if (!bChill[0])
	{
		return Plugin_Stop;
	}

	bChill[0] = false;
	return Plugin_Stop;
}

public Action ChooseAnother(Handle timer)
{
	if (chosenThrower == 0 && chosenTarget == 0)
	{
		return Plugin_Stop;
	}

	chosenThrower = 0;
	chosenTarget = 0;

	return Plugin_Stop;
}

public Action DelayThrow(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsSurvivor(client) || !bShootOrder[client])
	{
		return Plugin_Stop;
	}

	bShootOrder[client] = false;
	return Plugin_Stop;
}

public Action CommonDelayThrow(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsSurvivor(client) || !bShootOrder[client])
	{
		return Plugin_Stop;
	}

	float fEyePos[3], fTargetTrajectory[3], fEyeAngles[3];

	GetClientEyePosition(client, fEyePos);
	MakeVectorFromPoints(fEyePos, fMobPos, fTargetTrajectory);
	GetVectorAngles(fTargetTrajectory, fEyeAngles);

	fEyeAngles[2] += 5.0;
	TeleportEntity(client, NULL_VECTOR, fEyeAngles, NULL_VECTOR);
	return Plugin_Stop;
}

public Action TankDelayThrow(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsSurvivor(client) || !bShootOrder[client])
	{
		return Plugin_Stop;
	}

	bShootOrder[client] = false;
	float fEyePos[3], fTargetTrajectory[3], fEyeAngles[3];
	GetClientEyePosition(client, fEyePos);
	MakeVectorFromPoints(fEyePos, targetPos, fTargetTrajectory);
	GetVectorAngles(fTargetTrajectory, fEyeAngles);
	fEyeAngles[2] -= 7.5;
	TeleportEntity(client, NULL_VECTOR, fEyeAngles, NULL_VECTOR);
	return Plugin_Stop;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsSurvivor(client) && IsFakeClient(client))
	{
		int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (iActiveWeapon != -1 && IsValidEntity(iActiveWeapon))
		{
			char sActiveWeapon[64];
			GetEntityClassname(iActiveWeapon, sActiveWeapon, sizeof(sActiveWeapon));
			if (iActiveWeapon == GetPlayerWeaponSlot(client, 2) && (StrEqual(sActiveWeapon, "weapon_molotov") || StrEqual(sActiveWeapon, "weapon_pipe_bomb") || StrEqual(sActiveWeapon, "weapon_vomitjar")))
			{
				switch (bShootOrder[client])
				{
					case true: buttons &= IN_ATTACK;
					case false: buttons &= ~IN_ATTACK;
				}
			}
		}
	}

	return Plugin_Continue;
}

public Action L4D2_OnFindScavengeItem(int client, int &item)
{
	if (!item)
	{
		float itemOrigin[3], scavengerOrigin[3];

		int throwable = GetPlayerWeaponSlot(client, 2);
		if (!IsValidEdict(throwable))
		{
			for (int i = 0; i < throwablesFound.Length; i++)
			{
				if (!IsValidEntity(throwablesFound.Get(i)))
				{
					return Plugin_Continue;
				}

				GetEntPropVector(throwablesFound.Get(i), Prop_Send, "m_vecOrigin", itemOrigin);
				GetEntPropVector(client, Prop_Send, "m_vecOrigin", scavengerOrigin);

				float distance = GetVectorDistance(scavengerOrigin, itemOrigin);
				if (distance < 250.0)
				{
					item = throwablesFound.Get(i);
					return Plugin_Changed;
				}
			}
		}
	}
	else if (IsGrenade(item))
	{
		int throwable = GetPlayerWeaponSlot(client, 2);
		if (throwable > 0 && IsValidEntity(throwable) && IsValidEdict(throwable))
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action OnTongueGrab(Event event, const char[] name, bool dontBroadcast)
{
	int grabbed = GetClientOfUserId(event.GetInt("victim"));
	if (grabbed <= 0 || grabbed > MaxClients || !IsClientInGame(grabbed) || GetClientTeam(grabbed) != 2 || !IsFakeClient(grabbed))
	{
		return Plugin_Continue;
	}

	if (!bTongueOwned[grabbed])
	{
		bTongueOwned[grabbed] = true;
	}
	return Plugin_Continue;
}

public Action OnTongueRelease(Event event, const char[] name, bool dontBroadcast)
{
	int released = GetClientOfUserId(event.GetInt("victim"));
	if (released <= 0 || released > MaxClients || !IsClientInGame(released) || GetClientTeam(released) != 2 || !IsFakeClient(released))
	{
		return Plugin_Continue;
	}

	if (bTongueOwned[released])
	{
		bTongueOwned[released] = false;
	}
	return Plugin_Continue;
}

public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (bChill[1])
	{
		return Plugin_Continue;
	}

	int damaged = GetClientOfUserId(event.GetInt("userid"));
	if (damaged <= 0 || damaged > MaxClients || !IsClientInGame(damaged) || GetClientTeam(damaged) != 2 || !IsFakeClient(damaged) || !IsInShape(damaged) || damaged == chosenThrower || damaged == lastChosen[1])
	{
		return Plugin_Continue;
	}

	int dangerousEnt = 0;

	float fDangerPos[3];
	GetEntPropVector(damaged, Prop_Send, "m_vecOrigin", fDangerPos);

	for (int damager = 1; damager < 2049; damager++)
	{
		if (!IsCommonInfected(damager) && !IsSpecialInfected(damager))
		{
			continue;
		}

		float fDamagerPos[3];
		GetEntPropVector(damager, Prop_Send, "m_vecOrigin", fDamagerPos);

		if (GetVectorDistance(fDangerPos, fDamagerPos) > 150.0)
		{
			continue;
		}

		dangerousEnt += 1;
	}
	if (dangerousEnt >= 15 && ChangeToGrenade(damaged, true, true, true))
	{
		bChill[1] = true;
		CreateTimer(5.0, ApplyCooldown, _, TIMER_FLAG_NO_MAPCHANGE);

		lastChosen[1] = damaged;

		float fLookAngles[3];
		GetClientEyeAngles(damaged, fLookAngles);
		fLookAngles[2] += 90.0;

		bShootOrder[damaged] = true;
		CreateTimer(2.0, DelayThrow, GetClientUserId(damaged), TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}

public Action ApplyCooldown(Handle timer)
{
	if (!bChill[1])
	{
		return Plugin_Stop;
	}

	bChill[1] = false;
	return Plugin_Stop;
}

public Action L4D_OnSpawnMob(int &amount)
{

	for (int i = 1; i < 2049; i++)
	{
		if (!IsCommonInfected(i))
		{
			continue;
		}

		GetEntPropVector(i, Prop_Send, "m_vecOrigin", fMobPos);
		break;
	}

	if (fMobPos[0] != 0.0 || fMobPos[1] != 0.0 || fMobPos[2] != 0.0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsSurvivor(i) && IsFakeClient(i) && IsInShape(i) && i != chosenThrower && i != lastChosen[2])
			{
				if (!ChangeToGrenade(i, true, true, true))
				{
					continue;
				}

				lastChosen[2] = i;

				float fEyePos[3], fTargetTrajectory[3], fEyeAngles[3];

				GetClientEyePosition(lastChosen[2], fEyePos);
				MakeVectorFromPoints(fEyePos, fMobPos, fTargetTrajectory);
				GetVectorAngles(fTargetTrajectory, fEyeAngles);

				fEyeAngles[2] += 5.0;
				TeleportEntity(lastChosen[2], NULL_VECTOR, fEyeAngles, NULL_VECTOR);

				bShootOrder[lastChosen[2]] = true;
				CreateTimer(3.0, CommonDelayThrow, GetClientUserId(lastChosen[2]), TIMER_FLAG_NO_MAPCHANGE);

				break;
			}
		}
	}

	return Plugin_Continue;
}

public void OnMapEnd()
{
	throwablesFound.Clear();
}

bool CanBeSeen(int client, int other, float distance = 0.0)
{
	float fPos[2][3];

	GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos[0]);
	fPos[0][2] += 50.0;

	GetClientEyePosition(other, fPos[1]);

	if (distance == 0.0 || GetVectorDistance(fPos[0], fPos[1], false) < distance)
	{
		Handle trace = TR_TraceRayFilterEx(fPos[0], fPos[1], MASK_SOLID_BRUSHONLY, RayType_EndPoint, EntityChecker);
		if (TR_DidHit(trace))
		{
			delete trace;
			return false;
		}

		delete trace;
		return true;
	}

	return false;
}

public bool EntityChecker(int entity, int contentsMask, any data)
{
	return (entity == data);
}

bool ChangeToGrenade(int client, bool incFire = false, bool incPipe = false, bool incBile = false)
{
	int grenade = GetPlayerWeaponSlot(client, 2);
	if (grenade != -1 && IsValidEntity(grenade) && IsValidEdict(grenade))
	{
		char sGrenade[32];
		GetEdictClassname(grenade, sGrenade, sizeof(sGrenade));
		if (allowMolotov && StrEqual(sGrenade, "weapon_molotov") && incFire)
		{
			FakeClientCommand(client, "use weapon_molotov");
			return true;
		}
		else if (allowPipe && StrEqual(sGrenade, "weapon_pipe_bomb") && incPipe)
		{
			FakeClientCommand(client, "use weapon_pipe_bomb");
			return true;
		}
		else if (allowBile && StrEqual(sGrenade, "weapon_vomitjar") && incBile)
		{
			FakeClientCommand(client, "use weapon_vomitjar");
			return true;
		}
	}

	return false;
}

bool IsInShape(int client)
{
	if (game == Engine_Left4Dead2)
	{
		return (!GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) && !bTongueOwned[client] && GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") <= 0 && GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") <= 0 && GetEntPropEnt(client, Prop_Send, "m_carryAttacker") <= 0 && GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") <= 0);
	}
	return (!GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) && !bTongueOwned[client] && GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") <= 0);
}

bool IsEquipped(int grenade)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i) && GetPlayerWeaponSlot(i, 2) == grenade)
		{
			return true;
		}
	}

	return false;
}

bool IsGrenade(int entity)
{
	if (entity > 0 && entity < 2048 && IsValidEntity(entity))
	{
		char sEntityClass[64], sEntityModel[128];

		GetEntityClassname(entity, sEntityClass, sizeof(sEntityClass));
		GetEntPropString(entity, Prop_Data, "m_ModelName", sEntityModel, sizeof(sEntityModel));

		if (StrEqual(sEntityClass, "weapon_molotov") || StrEqual(sEntityClass, "weapon_molotov_spawn") || StrEqual(sEntityModel, "models/w_models/weapons/w_eq_molotov.mdl") ||
			StrEqual(sEntityClass, "weapon_pipe_bomb") || StrEqual(sEntityClass, "weapon_pipe_bomb_spawn") || StrEqual(sEntityModel, "models/w_models/weapons/w_eq_pipebomb.mdl") ||
			StrEqual(sEntityClass, "weapon_vomitjar") || StrEqual(sEntityClass, "weapon_vomitjar_spawn") || StrEqual(sEntityModel, "models/w_models/weapons/w_eq_bile_flask.mdl"))
		{
			return true;
		}
	}

	return false;
}

public void OnCvarChange(ConVar convar, char[] oldValue, char[] newValue)
{
	UpdateFromCvars();
}

public void UpdateFromCvars()
{
	allowBile = (game == Engine_Left4Dead2) ? cvarAllowBile.BoolValue : false;
	allowMolotov = cvarAllowMolotov.BoolValue;
	allowPipe = cvarAllowPipe.BoolValue;
	targetTank = cvarTargetTank.BoolValue;
}

stock bool IsCommonInfected(int entity)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		char entType[64];
		GetEdictClassname(entity, entType, sizeof(entType));
		return StrEqual(entType, "infected");
	}
	return false;
}

stock bool IsSurvivor(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client));
}

stock bool IsSpecialInfected(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") < ZOMBIECLASS_SPECIALS);
}
