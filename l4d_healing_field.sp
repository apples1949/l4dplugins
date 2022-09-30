#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION 	"1.6"

#define SOUND_EFFECTS 	"ui/menu_countdown.wav"

#define SPRITE_BEAM		"materials/sprites/laserbeam.vmt"
#define SPRITE_HALO		"materials/sprites/glow01.vmt"
#define SPRITE_GLOW		"sprites/blueglow1.vmt" // Prevents late pre-cache messages on the console for beacons.

int	BeamSprite;
int HaloSprite;

int iArrayEntities[2048][3];

static ConVar hCvar_HealingFieldChance;
static ConVar hCvar_HealingFieldRange;
static ConVar hCvar_EntityMaxLife;
static ConVar hCvar_AmountHealth;
static ConVar hCvar_ColorEffects;
static ConVar hCvar_GlowEnabled;
static ConVar hCvar_DecayDecay;
static ConVar hCvar_MaxIncapCount;

static char sCvar_ColorEffects[16];

static int iCvar_HealingFieldChance;
static int iCvar_AmountHealth;
static int iCvar_MaxIncapCount;

static float fCvar_HealingFieldRange;
static float fCvar_EntityMaxLife;
static float fEntityLife[2000];

static bool bCvar_GlowEnabled;
static bool bRoundEnd;
static bool bLeft4DeadTwo;

static const char sModelArray[][] =
{
	"models/props_interiors/sofa.mdl", 					// Sofa
	"models/props_interiors/toilet_b.mdl", 				// Toilet
	"models/props/de_inferno/ceiling_fan_blade.mdl", 	// Ceiling Fan Blades
	"models/w_models/weapons/w_eq_painpills.mdl", 		// Pills
	"models/props_debris/concrete_chunk01a.mdl", 		// Rock
	"models/w_models/weapons/w_eq_medkit.mdl", 			// Medkit
	"models/extras/info_speech.mdl", 					// Speaking
	"models/props_interiors/dvd_player.mdl", 			// DVD
	"models/props_industrial/barrel_fuel.mdl", 			// Barrel
	"models/props_interiors/waterbottle.mdl", 			// Water Bottle
	"models/props_interiors/sofa_chair01.mdl", 			// Sofa Chair Blue
	"models/props_unique/airport/atlas_break_ball.mdl", // Globe
	"models/props_interiors/lamp_floor.mdl", 			// Floor Lamp
	"models/props_interiors/luggagecarthotel01.mdl", 	// Luggage Cart
	"models/props_furniture/piano.mdl", 				// Piano
	"models/props_interiors/teddy_bear.mdl", 			// Teddy Bear
	"models/props_lighting/light_battery_rigged_01.mdl",// Battery
	"models/props_interiors/fridge_mini.mdl", 			// Mini Fridge
	"models/props_interiors/lamp_table01.mdl", 			// Table Lamp
	"models/props_interiors/toiletpaperroll.mdl", 		// Toilet Paper Roll
	"models/props_fairgrounds/elephant.mdl", 			// Elephant - L4D2
	"models/props_fairgrounds/giraffe.mdl", 			// Giraffe - L4D2
	"models/props_fairgrounds/snake.mdl", 				// Snake - L4D2
	"models/props_fairgrounds/alligator.mdl", 			// Alligator - L4D2
	"models/items/l4d_gift.mdl", 						// Gift - L4D2
	"models/f18/f18_sb.mdl" 							// Mini F18 - L4D2
};

static const char sNameArray[][] =
{	
	"Sᴏғᴀ", "Tᴏɪʟᴇᴛ", "Fᴀɴ Bʟᴀᴅᴇs", "Pɪʟʟs", "Rᴏᴄᴋ", "Mᴇᴅᴋɪᴛ", 
	"Sᴘᴇᴀᴋɪɴɢ", "DVD", "Bᴀʀʀᴇʟ", "Wᴀᴛᴇʀ Bᴏᴛᴛʟᴇ", "Sᴏғᴀ Cʜᴀɪʀ",
	"Gʟᴏʙᴇ", "Fʟᴏᴏʀ Lᴀᴍᴘ", "Lᴜɢɢᴀɢᴇ Cᴀʀᴛ", "Pɪᴀɴᴏ", "Tᴇᴅᴅʏ Bᴇᴀʀ",
	"Bᴀᴛᴛᴇʀʏ", "Mɪɴɪ Fʀɪᴅɢᴇ", "Tᴀʙʟᴇ Lᴀᴍᴘ", "Tᴏɪʟᴇᴛ Pᴀᴘᴇʀ Rᴏʟʟ",
	"Eʟᴇᴘʜᴀɴᴛ", "Gɪʀᴀғғᴇ", "Sɴᴀᴋᴇ", "Aʟʟɪɢᴀᴛᴏʀ", "Gɪғᴛ", "Mɪɴɪ F18"
};

static const char sFixArray[][] = 						// Prevents late precache messages on the console.
{
	"models/props_interiors/lamp_floor_gib1.mdl",
	"models/props_interiors/lamp_floor_gib2.mdl",
	"models/props_interiors/lamp_table01_gib1.mdl",
	"models/props_interiors/lamp_table01_gib2.mdl"
};

public Plugin myinfo = 
{
	name 		= "[L4D1 AND L4D2] Healing Field",
	author 		= "Ernecio (Satanael)",
	description = "When the Tank dies a field is generated in which the survivors receive health.",
	version 	= PLUGIN_VERSION,
	url 		= "https://steamcommunity.com/profiles/76561198404709570/"
}

/**
 * Called on pre plugin start.
 *
 * @param hMyself        Handle to the plugin.
 * @param bLate          Whether or not the plugin was loaded "late" (after map load).
 * @param sError         Error message buffer in case load failed.
 * @param Error_Max      Maximum number of characters for error message buffer.
 * @return               APLRes_Success for load success, APLRes_Failure or APLRes_SilentFailure otherwise.
 */
public APLRes AskPluginLoad2( Handle hMyself, bool bLate, char[] sError, int Error_Max )
{
	EngineVersion Engine = GetEngineVersion();
	if( Engine != Engine_Left4Dead && Engine != Engine_Left4Dead2 )
	{
		strcopy( sError, Error_Max, "The Plugin \"Healing Field\" only runs in the \"Left 4 Dead 1/2\" Games!." );
		return APLRes_SilentFailure;
	}
	
	bLeft4DeadTwo = ( Engine == Engine_Left4Dead2 );
	return APLRes_Success;
}

/**
 * Called on plugin start.
 *
 * @noreturn
 */
public void OnPluginStart()
{
	CreateConVar(							   "l4d_healing_field_version", PLUGIN_VERSION, "Healing Field Version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	hCvar_HealingFieldChance 	= CreateConVar("l4d_healing_field_chance", 		"50", 		"坦克死亡时产生治疗阵的几率。0=插件关闭", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	hCvar_HealingFieldRange 	= CreateConVar("l4d_healing_field_range", 		"200.0", 	"设置治疗阵的范围.", FCVAR_NOTIFY, true, 50.0, true, 500.0);
	hCvar_EntityMaxLife			= CreateConVar("l4d_healing_field_life",		"30.0",		"治疗阵的持续时间 (秒).", FCVAR_NOTIFY, true, 5.0, true, 60.0);
	hCvar_AmountHealth 			= CreateConVar("l4d_healing_field_health", 		"6", 		"幸存者每秒获取的治疗量", FCVAR_NOTIFY, true, 1.0, true, 10.0);
	hCvar_ColorEffects 			= CreateConVar("l4d_healing_field_colors", 		"1", 		"设置治疗区域的颜色.\n1 = 随机颜色 \n2 = 默认颜色 \n 自定义颜色，例如: \"0 255 255 255\"",FCVAR_NOTIFY);
	hCvar_GlowEnabled 			= CreateConVar("l4d_healing_field_glow", 		"1", 		"开启关闭实体上的发光 1=开启发光 0 =关闭发光", FCVAR_NOTIFY, true, 0.0, true, 1.0);	
	hCvar_MaxIncapCount 		= FindConVar("survivor_max_incapacitated_count");
	hCvar_DecayDecay 			= FindConVar("pain_pills_decay_rate");
	
	hCvar_HealingFieldChance.AddChangeHook( Event_ConVarChanged );
	hCvar_HealingFieldRange.AddChangeHook( Event_ConVarChanged );
	hCvar_EntityMaxLife.AddChangeHook( Event_ConVarChanged );
	hCvar_AmountHealth.AddChangeHook( Event_ConVarChanged );
	hCvar_ColorEffects.AddChangeHook( Event_ConVarChanged );
	hCvar_GlowEnabled.AddChangeHook( Event_ConVarChanged );
	hCvar_MaxIncapCount.AddChangeHook(Event_ConVarChanged);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post );
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	RegAdminCmd("sm_healing", CmdSpawnerHealing, ADMFLAG_BAN, "Create an entity which radiates healing for anyone in the vicinity.");
	
	AutoExecConfig( true, "l4d_healing_field" );
}

/**
 * Called on configs executed.
 *
 * @noreturn
 */
public void OnConfigsExecuted()
{
	GetCvars();
}

void Event_ConVarChanged(Handle hCvar, const char[] sOldVal, const char[] sNewVal)
{
	GetCvars();
}

void GetCvars()
{
	hCvar_ColorEffects.GetString( sCvar_ColorEffects, sizeof( sCvar_ColorEffects ) );
	TrimString( sCvar_ColorEffects );  // Removes whitespace characters from the beginning and end of a string.
	
	iCvar_HealingFieldChance = hCvar_HealingFieldChance.IntValue;
	iCvar_AmountHealth = hCvar_AmountHealth.IntValue;
	fCvar_HealingFieldRange = hCvar_HealingFieldRange.FloatValue;
	fCvar_EntityMaxLife = hCvar_EntityMaxLife.FloatValue;
	bCvar_GlowEnabled = hCvar_GlowEnabled.BoolValue;
	iCvar_MaxIncapCount = hCvar_MaxIncapCount.IntValue;
}

/**
 * The map is starting.
 *
 * @noreturn
 **/
public void OnMapStart()
{
	BeamSprite = PrecacheModel( SPRITE_BEAM );
	HaloSprite = PrecacheModel( SPRITE_HALO );
	
	PrecacheModel( SPRITE_GLOW, true );
	
	PrecacheSound( SOUND_EFFECTS, true );
	
	for( int i = 0; i < ( bLeft4DeadTwo ? sizeof( sModelArray ) : sizeof( sModelArray ) - 6 ); i ++ )
		PrecacheModel( sModelArray[i], true );
	
	for( int i = 0; i < sizeof( sFixArray ); i ++ )
		PrecacheModel( sFixArray[i], true );
}

/* =================================================================================================
											¡¡¡EVENTS!!!
   ================================================================================================= */

public void Event_RoundStart( Event hEvent, const char[] sName, bool bDontBroadcast )
{
	bRoundEnd = true;
}

public void Event_RoundEnd( Event hEvent, const char[] sName, bool bDontBroadcast )
{
	bRoundEnd = false;
}

/**
 * Event callback (player_death)
 * The player is about to die.
 * 
 * @param hEvent 			The event handle.
 * @param sName	    		The name of the event.
 * @param bDontBroadcast 	If true, event is broadcasted to all clients, false if not.
 **/
public void Event_PlayerDeath( Event hEvent, const char[] sName, bool bDontBroadcast )
{
	int client = GetClientOfUserId( hEvent.GetInt( "userid" ) );
	
	if( IsTank( client ) )
		if( GetRandomInt( 1, 100 ) <= iCvar_HealingFieldChance)
			CreateHealingField( client );
}

/* =================================================================================================
									CREATION FROM THE CLIENT											
   ================================================================================================= */
public Action CmdSpawnerHealing( int client, int args )
{
	if( iCvar_HealingFieldChance != 0 )
		CreateHealingField( client );
	else
		PrintToChat( client, "[ღ治疗失败ღ]插件未启动" );
	
	return Plugin_Handled;
}

void CreateHealingField( int client )
{
	float vOrigin[3];
	GetEntPropVector( client, Prop_Send, "m_vecOrigin", vOrigin );
	vOrigin[2] += 10.0;
	
	static char sCookie[16];
	static char sChars[4][4];
	sCookie = GetRandomClors();
	
	ExplodeString(sCookie, " ", sChars, sizeof sChars, sizeof sChars[]);
	
	int entity = - 1;
	int RandomModel = GetRandomInt( 0, bLeft4DeadTwo ? sizeof( sModelArray ) - 1 : sizeof( sModelArray ) - 7 );
	
	if( bLeft4DeadTwo )
		entity = CreateEntityByName("prop_dynamic_override");
	else
		entity = CreateEntityByName("prop_glowing_object");
	if( entity != -1 )
	{
		if( !bLeft4DeadTwo )
			DispatchKeyValue( entity, "StartGlowing", bCvar_GlowEnabled ? "1" : "0" );
		DispatchKeyValue( entity, "model", sModelArray[RandomModel] );
		DispatchKeyValueVector( entity, "origin", vOrigin );
		DispatchSpawn( entity );
		
		iArrayEntities[entity][0] = StringToInt( sChars[0] );
		iArrayEntities[entity][1] = StringToInt( sChars[1] );
		iArrayEntities[entity][2] = StringToInt( sChars[2] );
		
		if( bCvar_GlowEnabled && bLeft4DeadTwo )
			Glowing( entity );
		
		fEntityLife[entity] = 0.0;
		
		CreateTimer( 0.1, Timer_RotationEffects, EntIndexToEntRef( entity ), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
		CreateTimer( 1.0, Timer_Explode_Medic, EntIndexToEntRef( entity ), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
		
		EntityEffects_Medic( entity );
	
		PrintToChatAll( "[ღ%sღ]在%.2f %.2f %.2f创建治疗阵", sNameArray[RandomModel], vOrigin[0], vOrigin[1], vOrigin[2] );
	}	
}

stock char[] GetRandomClors()
{
	static char sColor[16];
	static char sDefault[16] = "0 150 0 255";
	static char sErrorDefault[16] =  "-1 -1 -1 255";
	static char sCustomColors[16]; 
	Format( sCustomColors, sizeof( sCustomColors ), sCvar_ColorEffects );
	
	switch( GetRandomInt( 1, 12 ) )
	{
		case 1: Format( sColor, sizeof( sColor ), "255 0 0 255" ); 		// Red
		case 2: Format( sColor, sizeof( sColor ), "0 255 0 255" ); 		// Green
		case 3: Format( sColor, sizeof( sColor ), "0 0 255 255" ); 		// Blue
		case 4: Format( sColor, sizeof( sColor ), "100 0 150 255" ); 	// Purple
		case 5: Format( sColor, sizeof( sColor ), "255 155 0 255" ); 	// Orange
		case 6: Format( sColor, sizeof( sColor ), "255 255 0 255" ); 	// Yellow
		case 7: Format( sColor, sizeof( sColor ), "-1 -1 -1 255" ); 	// White
		case 8: Format( sColor, sizeof( sColor ), "255 0 150 255" ); 	// Pink
		case 9: Format( sColor, sizeof( sColor ), "0 255 255 255" ); 	// Cyan
		case 10:Format( sColor, sizeof( sColor ), "128 255 0 255" ); 	// Lime
		case 11:Format( sColor, sizeof( sColor ), "0 128 128 255" ); 	// Teal
		case 12:Format( sColor, sizeof( sColor ), "50 50 50 255" ); 	// Grey
	}
	
//	Format( sColor, sizeof( sColor ), "%i %i %i 255", GetRandomInt( 0, 255 ), GetRandomInt( 0, 255 ), GetRandomInt( 0, 255 ) ); // Works but the beacon colors don't always match the color of the light entity.
	
	if( StrEqual( sCvar_ColorEffects, "1" ) ) return sColor;
	else if( StrEqual( sCvar_ColorEffects, "2" ) ) return sDefault;
	else if( StrContains( sCvar_ColorEffects, " 255", false ) != -1 ) return sCustomColors;
	
	PrintToServer("                                                                      ");
	PrintToServer("                      --> 治疗失败 <--                           ");
	PrintToServer("颜色设置不正确，检查设置，改成白色...");
	PrintToServer("                                                                      ");
	return sErrorDefault;
}

stock void Glowing( int entity )
{	
	int iRGBA[4];
	iRGBA[0] = iArrayEntities[entity][0];
	iRGBA[1] = iArrayEntities[entity][1];
	iRGBA[2] = iArrayEntities[entity][2];

	SetEntProp( entity, Prop_Send, "m_iGlowType", 3 );
	SetEntProp( entity, Prop_Send, "m_bFlashing", 1 );
	SetEntProp( entity, Prop_Send, "m_nGlowRange", 10000 );
//	SetEntProp( entity, Prop_Send, "m_nGlowRangeMin", 100);
	SetEntProp( entity, Prop_Send, "m_glowColorOverride", iRGBA[0] + ( iRGBA[1] * 256 ) + ( iRGBA[2] * 65536 ) );
//	AcceptEntityInput( entity, "StartGlowing" );
}

/**
 * Handler for the start of rotation in the entity.
 * 
 * @param hTimer 		Handle for the timer
 * @param index			Entity Index
 */
public Action Timer_RotationEffects( Handle hTimer, any EntityID )
{
	int entity = EntRefToEntIndex( EntityID );
	if( IsValidEntity( entity ))
	{
		fEntityLife[entity] += 0.1;
		if( !bRoundEnd || fEntityLife[entity] > fCvar_EntityMaxLife )
		{
			fEntityLife[entity] = 0.0;
			AcceptEntityInput( entity, "kill" );
			
			return Plugin_Stop;
		}
		
		RotateAdvance( entity, 15.0, 1 );
		
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

/**
 * Handler for starting beacons, healing, sounds and screen effects.
 * 
 * @param hTimer 		Handle for the timer
 * @param index			Entity Index
 */
public Action Timer_Explode_Medic( Handle hTimer, any EntityID )
{
	int entity = EntRefToEntIndex( EntityID );
	if( !IsValidEntity( entity ) )
		return Plugin_Stop;
	
	Explode_Medic( entity );
	
	return Plugin_Continue;
}

/* =================================================================================================
										EXPLOSION FX - MEDIC										
   ================================================================================================= */
public void Explode_Medic( int entity )
{	
	// Entity Pos
	static float vPos[3];
	
	GetEntPropVector( entity, Prop_Data, "m_vecAbsOrigin", vPos );

	// Shake
	CreateShake( 1.0, fCvar_HealingFieldRange, vPos );

	// Sound
	PlaySound( entity, SOUND_EFFECTS );
	
	int iRGBA[4];
	iRGBA[0] = iArrayEntities[entity][0];
	iRGBA[1] = iArrayEntities[entity][1];
	iRGBA[2] = iArrayEntities[entity][2];
	iRGBA[3] = 255;

	// Beam Ring
	CreateBeamRing( entity, iRGBA, 0.1, fCvar_HealingFieldRange * 2 ); // Converting to diameter.

	// Heal survivors
	int iHealth;
	float fHealth;
	float vEnd[3];
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame( i ) && GetClientTeam( i ) == 2 && IsPlayerAlive( i ) )
		{
			GetClientAbsOrigin( i, vEnd );
			if( GetVectorDistance( vPos, vEnd ) <= fCvar_HealingFieldRange )
			{
				iHealth = GetClientHealth( i );
				if( iHealth < 100 )
				{
//					iHealth += RoundFloat( 6.0 );
					iHealth += iCvar_AmountHealth; // Add the extra amount wants to the current amount.
					if( iHealth > 100 )
						iHealth = 100;

					fHealth = GetTempHealth( i );
					if( iHealth + fHealth > 100 )
					{
						fHealth = 100.0 - iHealth;
						SetTempHealth( i, fHealth );
					}

					SetEntityHealth( i, iHealth );
					SetClientHealth( i, fHealth );
				}
			}
		}
	}
}

/* =================================================================================================
										¡¡¡STOCKS - HEALTH!!!
   ================================================================================================= */
float GetTempHealth(int client)
{
	float fGameTime = GetGameTime();
	float fHealthTime = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
	float fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (fGameTime - fHealthTime) * hCvar_DecayDecay.FloatValue;
	return fHealth < 0.0 ? 0.0 : fHealth;
}

void SetTempHealth(int client, float fHealth)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fHealth < 0.0 ? 0.0 : fHealth );
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}

void SetClientHealth(int client, float fHealth)
{	
//	if( GetEntProp( client, Prop_Send, "m_currentReviveCount" ) >= iCvar_MaxIncapCount ) 			// The client has his screen in black and white.
	if( GetEntProp( client, Prop_Send, "m_currentReviveCount" ) >= 1 && iCvar_MaxIncapCount >= 1 ) 	// The client has been incompetent once.
	{
//		int iFixedHealth = GetClientHealth( client );
		
		int iUserFlags = GetUserFlagBits( client );
		SetUserFlagBits(client, ADMFLAG_ROOT);
		int iFlags = GetCommandFlags( "give" );
		SetCommandFlags( "give", iFlags & ~FCVAR_CHEAT );
		FakeClientCommand( client,"give health" );
		SetCommandFlags( "give", iFlags );
		SetUserFlagBits( client, iUserFlags );
		
		SetEntProp( client, Prop_Send, "m_iHealth", iCvar_AmountHealth, 1 ); 	// Sets client's life to default amount.
//		SetEntProp( client, Prop_Send, "m_iHealth", iFixedHealth - 1, 1 ); 		// Fixs the client's state of health.
//		SetEntityHealth( client, iFixedHealth - 1 );
		
		SetEntPropFloat( client, Prop_Send, "m_healthBuffer", fHealth < 0.0 ? 0.0 : fHealth );
		SetEntPropFloat( client, Prop_Send, "m_healthBufferTime", GetGameTime() );
		
		StopSoundsAllChannels( client, "player/heartbeatloop.wav" ); // Its very strange, but it can happen that the sound gets stuck.
	}
	else if( GetEntProp( client, Prop_Send, "m_currentReviveCount") == 0 )
	{
		StopSoundsAllChannels( client, "player/heartbeatloop.wav" ); // In case you haven't stopped before.
	}
}

stock void StopSoundsAllChannels( int client, const char[] sSound )
{
	StopSound( client, SNDCHAN_REPLACE, sSound );
	StopSound( client, SNDCHAN_AUTO, sSound );
	StopSound( client, SNDCHAN_WEAPON, sSound );
	StopSound( client, SNDCHAN_VOICE, sSound );
	StopSound( client, SNDCHAN_ITEM, sSound );
	StopSound( client, SNDCHAN_BODY, sSound );
	StopSound( client, SNDCHAN_STREAM, sSound );
	StopSound( client, SNDCHAN_STATIC, sSound );
	StopSound( client, SNDCHAN_VOICE_BASE, sSound );
	StopSound( client, SNDCHAN_USER_BASE, sSound );
}

/* =================================================================================================
									¡¡¡STOCKS - EFFECTS!!!											
   ================================================================================================= */
void CreateShake(float intensity, float range, float vPos[3])
{
	if( intensity == 0.0 ) return;

	int entity = CreateEntityByName("env_shake");
	if( entity == -1 )
	{
		LogError("Failed to create 'env_shake'");
		return;
	}

	static char sTemp[8];
	FloatToString(intensity, sTemp, sizeof sTemp);
	DispatchKeyValue(entity, "amplitude", sTemp);
	DispatchKeyValue(entity, "frequency", "1.5");
	DispatchKeyValue(entity, "duration", "0.9");
	FloatToString(range, sTemp, sizeof sTemp);
	DispatchKeyValue(entity, "radius", sTemp);
	DispatchKeyValue(entity, "spawnflags", "8");
	DispatchSpawn(entity);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "Enable");

	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entity, "StartShake");
	RemoveEdict(entity);
}

void EntityEffects_Medic( int entity )
{	
	int iRGBA[3];
	iRGBA[0] = iArrayEntities[entity][0];
	iRGBA[1] = iArrayEntities[entity][1];
	iRGBA[2] = iArrayEntities[entity][2];
	
	static char sRGBA[10];
	Format( sRGBA, sizeof( sRGBA ), "%i %i %i", iRGBA[0], iRGBA[1], iRGBA[2] );
	
	// Entity Pos + Effects
	static float vPos[3];
	SetupEntityEffects( entity, vPos, sRGBA );
}

void SetupEntityEffects(int entity, float vPos[3], const char[] color)
{
	// Entity Pos
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);
	
	// Steam
	static float vAng[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vAng);
	vAng[0] = -85.0;
	MakeEnvSteam(entity, vPos, vAng, color);

	// Light
	int light = MakeLightDynamic(entity, vPos);
	SetVariantEntity(light);
	SetVariantString(color);
	AcceptEntityInput(light, "color");
	AcceptEntityInput(light, "TurnOn");
}

int MakeLightDynamic(int target, const float vPos[3])
{
	int entity = CreateEntityByName("light_dynamic");
	if( entity == -1 )
	{
		LogError("Failed to create 'light_dynamic'");
		return 0;
	}

	DispatchKeyValue(entity, "_light", "0 255 0 0");
	DispatchKeyValue(entity, "brightness", "0.1");
	DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
	DispatchKeyValueFloat(entity, "distance", 600.0);
	DispatchKeyValue(entity, "style", "6");
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "TurnOff");

	TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

	// Attach
	if( target )
	{
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", target);
	}

	return entity;
}

void MakeEnvSteam(int target, const float vPos[3], const float vAng[3], const char[] sColor)
{
	int entity = CreateEntityByName("env_steam");
	if( entity == -1 )
	{
		LogError("Failed to create 'env_steam'");
		return;
	}

	static char sTemp[32];
	Format(sTemp, sizeof sTemp, "silv_steam_%d", target);
	DispatchKeyValue(entity, "targetname", sTemp);
	DispatchKeyValue(entity, "SpawnFlags", "1");
	DispatchKeyValue(entity, "rendercolor", sColor);
	DispatchKeyValue(entity, "SpreadSpeed", "10");
	DispatchKeyValue(entity, "Speed", "100");
	DispatchKeyValue(entity, "StartSize", "5");
	DispatchKeyValue(entity, "EndSize", "10");
	DispatchKeyValue(entity, "Rate", "50");
	DispatchKeyValue(entity, "JetLength", "100");
	DispatchKeyValue(entity, "renderamt", "150");
	DispatchKeyValue(entity, "InitialState", "1");
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "TurnOn");
	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

	// Attach
	if( target )
	{
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", target);
	}

	return;
}

void CreateBeamRing( int entity, int Color[4], float vMin, float vMax )
{
	// Entity Pos
	static float vPos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vPos);

	// Make beam rings
/*	for( int i = 1; i <= 5; i++ )
	{
		vPos[2] += 20;
		TE_SetupBeamRingPoint( vPos, vMin, vMax, BeamSprite, HaloSprite, 0, 15, 1.0, 1.0, 2.0, Color, 20, 0 );
		TE_SendToAll();
	} */
	
//	vPos[2] += 10;
	TE_SetupBeamRingPoint( vPos, vMin, vMax, BeamSprite, HaloSprite, 0, 10, 1.0, 2.0, 0.0, Color, 20, 0 );
	TE_SendToAll();
}

void RotateAdvance( int index, float vValue, int vAxis )
{
	if( IsValidEntity( index ) )
	{
		float vRotate[3];
		GetEntPropVector( index, Prop_Data, "m_angRotation", vRotate );
		vRotate[vAxis] += vValue;
		TeleportEntity( index, NULL_VECTOR, vRotate, NULL_VECTOR );
	}
}

void PlaySound( int entity, const char[] sSound, int level = SNDLEVEL_NORMAL )
{
	EmitSoundToAll( sSound, entity, level == SNDLEVEL_RAIDSIREN ? SNDCHAN_ITEM : SNDCHAN_AUTO, level );
}

/**
 * Validates if the current client is valid to run the plugin.
 *
 * @param client		The client index.
 * @return              False if the client is not the Tank, true otherwise.
 */
stock bool IsTank( int client )
{
	if( client > 0 && client <= MaxClients && IsClientInGame( client ) && GetClientTeam( client ) == 3 )
		if( GetEntProp( client, Prop_Send, "m_zombieClass" ) == ( bLeft4DeadTwo ? 8 : 5 ) )
			return true;
	
	return false;
}
