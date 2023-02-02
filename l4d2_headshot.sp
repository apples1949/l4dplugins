#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

static const char
	g_sSounds[][] = {
		"player/survivor/voice/teengirl/niceshot05.wav",
		"player/survivor/voice/teengirl/niceshot06.wav",
		"player/survivor/voice/teengirl/niceshot14.wav",
		"player/survivor/voice/teengirl/niceshot15.wav"
	};

public Plugin myinfo = {
	name = "L4D2 HeadShot",
	author = "sorallll",
	version = "1.0"
}

public void OnPluginStart() {
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

public void OnMapStart() {
	for(int i; i < sizeof g_sSounds; i++)
		PrecacheSound(g_sSounds[i]);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 3)
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(!attacker || !IsClientInGame(attacker) || IsFakeClient(attacker) || GetClientTeam(attacker) != 2)
		return;

	if(!event.GetBool("headshot"))
		vShowHint(attacker, attacker, "击杀", "255 255 255", "icon_skull", "0", "2.5", "2000.0", "0");
	else {
		vShowHint(attacker, attacker, "爆头", "255 0 0", "icon_skull", "0", "2.5", "2000.0", "0");
		vPlaySound(attacker, g_sSounds[GetRandomInt(0, sizeof g_sSounds - 1)]);
	}
}

void vShowHint(int client, int iTarget, const char[] sHintCaption, const char[] sHintColor = "255 255 255", const char[] sHintIconOn, const char[] sPulse = "0", const char[] sTimeout = "5.0", const char[] sHintRange = "2000.0", const char[] sHintType = "0") {
	int iEnt = CreateEntityByName("env_instructor_hint");
	if(iEnt == -1)
		return;

	static char sTemp[64];
	if(iTarget > -1) {
		FormatEx(sTemp, sizeof sTemp, "hint_target_%d", GetClientUserId(iTarget));
		DispatchKeyValue(iTarget, "targetname", sTemp);
	}
	else {
		FormatEx(sTemp, sizeof sTemp, "hint_target_%d", EntIndexToEntRef(iEnt));
		DispatchKeyValue(client, "targetname", sTemp);
	}

	DispatchKeyValue(iEnt, "hint_target", sTemp);
	DispatchKeyValue(iEnt, "hint_allow_nodraw_target", "1");
	DispatchKeyValue(iEnt, "hint_caption", sHintCaption);
	DispatchKeyValue(iEnt, "hint_color", sHintColor);
	DispatchKeyValue(iEnt, "hint_forcecaption", "1");
	DispatchKeyValue(iEnt, "hint_icon_onscreen", sHintIconOn);
	DispatchKeyValue(iEnt, "hint_nooffscreen", "0");
	DispatchKeyValue(iEnt, "hint_pulseoption", sPulse);
	DispatchKeyValue(iEnt, "hint_timeout", sTimeout);
	DispatchKeyValue(iEnt, "hint_range", sHintRange);
	DispatchKeyValue(iEnt, "hint_display_limit", "0");
	DispatchKeyValue(iEnt, "hint_instance_type", sHintType);

	DispatchSpawn(iEnt);
	AcceptEntityInput(iEnt, "ShowHint", client);

	FormatEx(sTemp, sizeof sTemp, "OnUser1 !self:Kill::%s:-1", sTimeout);
	SetVariantString(sTemp);
	AcceptEntityInput(iEnt, "AddOutput");
	AcceptEntityInput(iEnt, "FireUser1");
}

void vPlaySound(int client, const char[] sSound) {
	EmitSoundToClient(client, sSound, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}