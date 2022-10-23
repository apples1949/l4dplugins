#define PLUGIN_VERSION	"1.0"
#define PLUGIN_NAME		"l4d_penetraction_pistol"

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

/**
 *	v1.0 just releases; 25-March-2022
 *
 */

public Plugin myinfo = {
	name = "[L4D & L4D2] Limb-Based Penetration Pistol",
	author = "NoroHime",
	description = "i decided make pistol great again",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/NoroHime/"
}


#define isNetworkedEntity(%1) (MaxClients < %1 <= 2048)

enum {
	GENERIC = 0,
	HEAD,
	CHEST,
	STOMACH,
	ARM_LEFT,
	ARM_RIGHT,
	LEG_LEFT,
	LEG_RIGHT
}

ConVar Penetration_limb_full;	int penetration_limb_full;
ConVar Penetration_limb_perc;	int penetration_limb_perc;
ConVar Penetration_limb_lucky;	int penetration_limb_lucky;
ConVar Penetration_rate_perc;	float penetration_rate_perc;
ConVar Penetration_rate_lukcy;	int penetration_rate_lukcy;

public void OnPluginStart() {

	CreateConVar						("penetraction_pistol_version", PLUGIN_VERSION,			"Version of 'Limb-Based Penetration Pistol'", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	Penetration_limb_full = 			CreateConVar("penetraction_pistol_limb_full", "7",		"击中哪些肢体会直接导致僵尸死亡\n1=头部 2=胸部 4=腹部 8=左臂 16=右臂 32=左腿 64=右腿 127=全部", FCVAR_NOTIFY);
	Penetration_limb_perc = 			CreateConVar("penetraction_pistol_limb_perc", "100",		"击中哪些肢体有可能直接导致僵尸死亡 \n 1=头部 2=胸部 4=腹部 8=左臂 16=右臂 32=左腿 64=右腿 127=全部", FCVAR_NOTIFY);
	Penetration_limb_lucky = 			CreateConVar("penetraction_pistol_limb_lucky", "100",	"击中哪些肢体会造成伤害，至少与最大生命值成正比 \n 1=头部 2=胸部 4=腹部 8=左臂 16=右臂 32=左腿 64=右腿 127=全部", FCVAR_NOTIFY);
	Penetration_rate_perc = 			CreateConVar("penetraction_pistol_rate_perc", "0.5",	"击中'limb_perc'选择的四肢至少造成最大健康值的伤害", FCVAR_NOTIFY);
	Penetration_rate_lukcy = 			CreateConVar("penetraction_pistol_rate_lukcy", "2",		"击中'limb_lucky'被选中的肢体有多少概率导致僵尸直接死亡，数值越低越容易死亡，1=100%(1/1) 2=1/2,3=1/3.以此类推", FCVAR_NOTIFY);

	AutoExecConfig(true, PLUGIN_NAME);

	Penetration_limb_full		.AddChangeHook(OnConVarChanged);
	Penetration_limb_perc		.AddChangeHook(OnConVarChanged);
	Penetration_limb_lucky		.AddChangeHook(OnConVarChanged);
	Penetration_rate_perc		.AddChangeHook(OnConVarChanged);
	Penetration_rate_lukcy		.AddChangeHook(OnConVarChanged);
	
	ApplyCvars();
}

public void ApplyCvars() {
	
	penetration_limb_full = Penetration_limb_full.IntValue;
	penetration_limb_perc = Penetration_limb_perc.IntValue;
	penetration_limb_lucky = Penetration_limb_lucky.IntValue;
	penetration_rate_perc = Penetration_rate_perc.FloatValue;
	penetration_rate_lukcy = Penetration_rate_lukcy.IntValue;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	ApplyCvars();
}

public void OnConfigsExecuted() {
	ApplyCvars();
}

bool hookedInfected[2049];

public void OnEntityCreated(int entity, const char[] classname) {

	if (isNetworkedEntity(entity) && strcmp(classname, "infected") == 0) {

		SDKHook(entity, SDKHook_TraceAttackPost, OnTraceAttackPost);
		SDKHook(entity, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);

		hookedInfected[entity] = true;
	}
}

public void OnEntityDestroyed(int entity) {

	if (isNetworkedEntity(entity) && hookedInfected[entity]) {
		
		SDKUnhook(entity, SDKHook_TraceAttack, OnTraceAttackPost);
		SDKUnhook(entity, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);

		hookedInfected[entity] = false;
	}
}

int lastHitted;

public void OnTraceAttackPost(int victim, int attacker, int inflictor, float damage, int damagetype, int ammotype, int hitbox, int hitgroup) {
	lastHitted = hitgroup;
}

public Action OnTakeDamageAlive(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3]) {

	static char name_weapon[32];

	if (isNetworkedEntity(weapon) && GetEntityNetClass(weapon, name_weapon, sizeof(name_weapon)) && strcmp(name_weapon, "CPistol") == 0) {
		
		if (HasEntProp(victim, Prop_Data, "m_iMaxHealth")) {

			int health_max = GetEntProp(victim, Prop_Data, "m_iMaxHealth");

			if (penetration_limb_full & (1 << lastHitted - 1)) {

				damage = float(health_max) + 1;

				return Plugin_Changed;
			}

			if (penetration_limb_lucky & (1 << lastHitted - 1) && GetRandomInt(1, penetration_rate_lukcy) == 1) {

				damage = float(health_max) + 1;

				return Plugin_Changed;
			}

			if (penetration_limb_perc & (1 << lastHitted - 1) && damage < (penetration_rate_perc * health_max)) {

				damage = health_max * penetration_rate_perc + 1;

				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}