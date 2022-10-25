#define PLUGIN_VERSION		"1.2"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Global Shadow Fix
*	Author	:	SilverShot
*	Descp	:	Corrects the global shadow position on some official maps.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=149041
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.2 (10-May-2020)
	- Various changes to tidy up code.

1.1 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.

1.0 (01-Feb-2011)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>



// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Global Shadow Fix",
	author = "SilverShot",
	description = "Corrects the global shadow position on some official maps.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=149041"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	// Cvars
	CreateConVar("l4d2_global_shadow_fix_version", PLUGIN_VERSION, "Shadow Fix version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	// Reset to the new values and manually change the shadow direction
	/*
	RegAdminCmd("sm_shadows", CmdSh, ADMFLAG_GENERIC);
	RegAdminCmd("sm_shadowx", CmdShX, ADMFLAG_GENERIC);
	RegAdminCmd("sm_shadowy", CmdShY, ADMFLAG_GENERIC);
	RegAdminCmd("sm_shadowz", CmdShZ, ADMFLAG_GENERIC);
	*/
}

// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public void OnConfigsExecuted()
{
	SetPos();
}

bool SetPos()
{
	float fCorrected[3];
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	// Dead Center:
	if( strcmp(sMap, "c1m1_hotel", false) == 0 )		//-0.612372 0.353553 -0.707106
		fCorrected = view_as<float>({ 0.587627, 0.353553, -0.207106 });

	else if( strcmp(sMap, "c1m2_streets") == 0 )		//0.150383 0.086824 -0.984807
		fCorrected = view_as<float>({ 0.750383, 0.486824, -0.484807 });

	else if( strcmp(sMap, "c1m3_mall") == 0 )			//01.187627 0.553553 -0.707106
		fCorrected = view_as<float>({ 2.587627, 0.953553, -0.207106 });

	else if( strcmp(sMap, "c1m4_atrium") == 0 )		//-0.612372 0.353553 -0.707106
		fCorrected = view_as<float>({ 2.587627, 0.353553, -0.207106 });

	// Hard Rain:
	else if( strcmp(sMap, "c4m1_milltown_a") == 0 )	//0.330366 -0.088521 -0.939692
		fCorrected = view_as<float>({ 1.130365, 0.711478, -0.439692 });

	else
		return false;	// No other maps

	int ent = -1;
	while( (ent = FindEntityByClassname(ent, "shadow_control")) != INVALID_ENT_REFERENCE )
	{
		SetEntPropVector(ent, Prop_Send, "m_shadowDirection", fCorrected);
	}

	return true;
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
/*
public Action:CmdSh(client, args)
{
	if( SetPos() == true )
		PrintToChat(client, "\x04[\x01Shadow Fix\x04]\x01 Corrected!");
	else
		PrintToChat(client, "\x04[\x01Shadow Fix\x04]\x01 Wrong Map!");
	return Plugin_Handled;
}

public Action:CmdShX(client, args)
{
	SetShadow(client, 1, args);
	return Plugin_Handled;
}

public Action:CmdShY(client, args)
{
	SetShadow(client, 2, args);
	return Plugin_Handled;
}

public Action:CmdShZ(client, args)
{
	SetShadow(client, 3, args);
	return Plugin_Handled;
}

SetShadow(client, type, any:...)
{
	decl String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));

	new ent = -1, Float:fCorrected[3], Float:fLen = StringToFloat(arg1);

	while( (ent = FindEntityByClassname(ent, "shadow_control")) != INVALID_ENT_REFERENCE )
	{
		GetEntPropVector(ent, Prop_Send, "m_shadowDirection", fCorrected);
		PrintToChat(client, "\x04[\x01Shadow Fix\x04]\x01 Was: %f %f %f", fCorrected[0], fCorrected[1], fCorrected[2]);
		switch(type)
		{
			case 1:	fCorrected[0] += fLen;
			case 2:	fCorrected[1] += fLen;
			case 3:	fCorrected[2] += fLen;
		}
		SetEntPropVector(ent, Prop_Send, "m_shadowDirection", fCorrected);
		PrintToChat(client, "\x04[\x01Shadow Fix\x04]\x01 Now: %f %f %f", fCorrected[0], fCorrected[1], fCorrected[2]);
	}
}
*/