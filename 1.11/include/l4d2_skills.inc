#if defined _l4d2_skills_included
	#endinput
#endif

#define _l4d2_skills_included

#define EXPORT_ARRAY_SIZE 32
#define EXPORT_ARRAY_DELIMITER ", "

#define SKILLS_CONFIG "data/skills.cfg"
#define SKILLS_GLOBALS "Skills Globals"

#define SKILLS_TAG "\x04[\x05Skills\x04]\x01"
#define SKILLS_TAG_NO_COLOR "[Skills]"

#define MAX_SKILL_NAME_LENGTH 64
#define MAX_SKILLS_COUNT 30
#define MAX_SKILL_LEVELS 16

#define ERROR(%0) LogError(%0)

//#if defined DEBUG
	#define LOG(%0) LogMessage(%0)
//#else
//	#define LOG(%0) (0)	warning 215: expression has no effect
//#endif

#define EXPORT_SKILL_START(%1) kv.Rewind(); kv.JumpToKey(%1, true)
#define EXPORT_SKILL_FINISH() KeyValueExportToFile(kv)

#define EXPORT_ENTER_SECTION(%1) if (kv.JumpToKey(%1, true))
#define EXPORT_LEAVE_SECTION() kv.GoBack()

#define EXPORT_BOOL_DEFAULT(%1,%2,%3) Skills_ExportBool(kv, %1, %2, %3)
#define EXPORT_INT_DEFAULT(%1,%2,%3) Skills_ExportInt(kv, %1, %2, %3)
#define EXPORT_FLOAT_DEFAULT(%1,%2,%3) Skills_ExportFloat(kv, %1, %2, %3)
#define EXPORT_VECTOR_DEFAULT(%1,%2,%3) Skills_ExportVector(kv, %1, %2, %3)
#define EXPORT_STRING_DEFAULT(%1,%2,%3,%4) Skills_ExportString(kv, %1, %2, %3, %4)
#define EXPORT_INT_ARRAY_DEFAULT(%1,%2,%3,%4) Skills_ExportIntArray(kv, %1, %2, %3, %4)
#define EXPORT_FLOAT_ARRAY_DEFAULT(%1,%2,%3,%4) Skills_ExportFloatArray(kv, %1, %2, %3, %4)

#define EXPORT_BOOL(%1,%2) Skills_ExportBool(kv, %1, %2)
#define EXPORT_INT(%1,%2) Skills_ExportInt(kv, %1, %2)
#define EXPORT_FLOAT(%1,%2) Skills_ExportFloat(kv, %1, %2)
#define EXPORT_VECTOR(%1,%2) Skills_ExportVector(kv, %1, %2)
#define EXPORT_STRING(%1,%2,%3) Skills_ExportString(kv, %1, %2, %3)
#define EXPORT_INT_ARRAY(%1,%2,%3) Skills_ExportIntArray(kv, %1, %2, %3)
#define EXPORT_FLOAT_ARRAY(%1,%2,%3) Skills_ExportFloatArray(kv, %1, %2, %3)

// ====================================================================================================
// Aliases for readability & convinience
// ====================================================================================================

#define EXPORT_SKILL_COST(%1,%2) Skills_ExportFloat(kv, "cost", %1.cost, %2)
#define EXPORT_SKILL_MAXLEVEL(%1,%2) Skills_ExportInt(kv, "maxlevel", %1.maxlevel, %2)
#define EXPORT_SKILL_UPGRADE_COSTS(%1,%2) Skills_ExportFloatArray(kv, "upgrade_costs", %1.upgrade_costs, %1.maxlevel, %2)

#define EXPORT_START(%1) EXPORT_SKILL_START(%1)
#define EXPORT_FINISH() EXPORT_SKILL_FINISH()

#define EXPORT_SECTION_START(%1) EXPORT_ENTER_SECTION(%1)
#define EXPORT_SECTION_END() EXPORT_LEAVE_SECTION()

#define INVALID_USERDATA 0

//

enum SkillsFunctorFlags
{
	SFF_NONE = 0x0000,
	SFF_ALIVE = 0x0002,
	SFF_INGAME = 0x0004,
	SFF_CONNECTED = 0x008,
	SFF_PLAYERS = 0x0010,
	SFF_BOTS = 0x0020,

	SFF_CLIENTS = SFF_INGAME | SFF_PLAYERS | SFF_BOTS
};

enum SkillType
{
	ST_INVALID = -1,
	ST_NONE,
	ST_ACTIVATION,
	ST_PASSIVE,
	ST_INPUT
};

enum UpgradeImpl
{
	UI_NULL,
	UI_DEFAULT,
	UI_CUSTOM
};

enum SkillState
{
	SS_NULL,
	SS_PURCHASED,
	SS_UPGRADED
};

enum struct BaseSkillExport
{
	int maxlevel;
	float cost;
	float upgrade_costs[MAX_SKILL_LEVELS];
}

enum struct BaseSkill
{
	int level;

	void reset()
	{
		this.level = 0;
	}
}

typedef Skills_OnSkillStateReset = function Action( int id );
typedef Skills_OnUpgradeMenuRequest = function UpgradeImpl( int client, int id, int &nextLevel, float &upgradeCost );
typedef Skills_OnCanClientUpgradeSkill = function bool( int client, int id );
typedef Skills_ItemMenuCallback = function void( int client, const char[] item );
typedef Skills_CollectorFunctor = function bool( int client );

typeset Skills_ForEveryFunctor
{
	function bool();
	function bool(int client);
	function bool(int client, any userdata);
}

static any gUserData;

// ====================================================================================================
// FORWARDS
// ====================================================================================================

/**
 * @brief Called when client opened main menu of skills
 *
 * @param menu			Handle of main menu 
 * @param client		Client index who opened menu
 *
 * @noreturn
 */
forward void Skills_OnClientMenuOpen( Menu menu, int client );

/**
 * @brief Called whenever some plugin registered skill
 *
 * @param name			Name of registered skill 
 * @param type			Type of registered skill (see SkillType)
 *
 * @noreturn
 */
forward void Skills_OnRegistered( const char[] name, SkillType type );

/**
 * @brief Called when skill changes it's state  (Eg. upgraded or puchased)
 * @remarks This is will catch all registered skills, to catch only skills owned by this plugin see Skills_OnSkillStateChangedPrivate
 *
 * @param client		Client index who owns this skill 
 * @param id			Unique id of changed skill
 * @param state			New state of skill (see SkillState)
 *
 * @noreturn
 */
forward void Skills_OnStateChanged( int client, int id, SkillState state );

/**
 * @brief Same as Skills_OnSkillStateChanged but this is called only for skill owner
 *
 * @param client		Client index who owns this skill 
 * @param id			Unique id of changed skill
 * @param state			New state of skill (see SkillState)
 *
 * @noreturn
 */
forward void Skills_OnStateChangedPrivate( int client, int id, SkillState state );

/**
 * @brief Called when it's time to load skill settings
 * @remarks Use this with EXPORT_XXX helpers
 *
 * @param kv		KeyValues with skill settings 
 *
 * @noreturn
 */
forward void Skills_OnGetSettings( KeyValues kv )

/**
 * @brief Called when l4d2_skills_core is started (OnPluginStart)
 *
 * @noreturn
 */
forward void Skills_OnCoreStart();

/**
 * @brief Called when l4d2_skills_core is loaded (OnAllPluginsLoaded)
 *
 * @noreturn
 */
forward void Skills_OnCoreLoaded();

/**
 * @brief Called when skills should reset their states
 * @remarks Clears internal state in core (see SkillState) 
 *
 * @return Plugin_Continue to allow reset any other value will be considered as block
 */
forward Action Skills_OnStateReset();

// ====================================================================================================
// NATIVES
// ====================================================================================================

/**
 * @brief Returns number of purchased skills 
 *
 * @param client	Client index
 *
 * @return 			Number of purchased skills
 */
native int Skills_GetClientSkillsCount( int client );

/**
 * @brief Returns client money
 *
 * @param client	Client index
 *
 * @return 			Client money
 */
native float Skills_GetClientMoney( int client );

/**
 * @brief Sets client money
 *
 * @param client	Client index
 * @param money		Value to set
 *
 * @noreturn
 */
native void Skills_SetClientMoney( int client, float money );

/**
 * @brief Returns client money multiplier
 *
 * @param client	Client index
 *
 * @return 			Client money multiplier
 */
native float Skills_GetClientMoneyMultiplier( int client );

/**
 * @brief Sets client money multiplier
 *
 * @param client		Client index
 * @param multiplier	Value to set
 *
 * @noreturn
 */
native void Skills_SetClientMoneyMultiplier( int client, float multiplier );
	
/**
 * @brief Returns team money
 *
 * @return 			Client money
 */
native float Skills_GetTeamMoney();

/**
 * @brief Sets team money
 *
 * @param money		Value to set
 *
 * @noreturn
 */
native void Skills_SetTeamMoney( float money );

/**
 * @brief Returns team money multiplier
 *
 * @return 			Team money multiplier
 */
native float Skills_GetTeamMoneyMultiplier();

/**
 * @brief Sets team money multiplier
 *
 * @param multiplier	Value to set
 *
 * @noreturn
 */
native void Skills_SetTeamMoneyMultiplier( float multiplier );

/**
 * @brief Retrieves a skill name by ID
 *
 * @param id		Unique skill ID
 * @param name		Buffer to store name
 * @param length	Buffer length
 *
 * @return			true on success, false otherwise
 */
native bool Skills_GetName( int id, char[] name, int length = MAX_SKILL_NAME_LENGTH );

/**
 * @brief Retrieves a skill ID by name
 *
 * @param name		Skill name
 *
 * @return			ID on success, -1 on failure
 */
native int Skills_GetID( const char[] name );

/**
 * @brief Returns number of registered skills
 *
 * @noreturn
 */
native int Skills_GetCount();

/**
 * @brief Returns skill type by it's name
 *
 * @param name		Skill name
 *
 * @return			SkillType
 */
native SkillType Skills_GetType( const char[] name );

/**
 * @brief Returns plugin handle of the skill owner
 *
 * @param name		Skill name
 *
 * @return			Plugin handle
 */
native Handle Skills_GetOwner( const char[] name );

/**
 * @brief Checks if skills can be upgraded
 *
 * @param name		Skill name
 *
 * @return			true if can be upgraded, false otherwise
 */
native bool Skills_IsUpgradable( const char[] name );

/**
 * @brief Checks if client have skill by name
 *
 * @param client	Client index
 * @param name		Skill name
 *
 * @return			true if client has skill, false otherwise
 */
native bool Skills_ClientHaveByName( int client, const char[] name );

/**
 * @brief Checks if client have skill by ID
 *
 * @param client	Client index
 * @param id		Skill ID
 *
 * @return			true if client has skill, false otherwise
 */
native bool Skills_ClientHaveByID(  int client, int id );

/**
 * @brief Changes skill state
 *
 * @param client	Client index
 * @param id		Skill ID
 * @param state		New skill state (See SkillState)
 *
 * @noreturn
 */
native void Skills_ChangeState( int client, int id, SkillState state );

/**
 * @brief Returns default upgrade menu
 * @remarks Menu must be closed via delete
 *
 * @param client	Client index
 * @param id		Skill ID
 * @param nextLevel	Next level of skill
 * @param cost		Cost of upgrade
 *
 * @return			Menu handle
 */
native Menu Skills_RequestDefaultUpgradeMenu( int client, int id, int nextLevel, float cost );

/**
 * @brief Adds item to main menu
 *
 * @param item		Unique item name
 * @param id		Display string
 * @param callback	Callback for added item
 *
 * @noreturn
 */
native void Skills_AddMenuItem(const char[] item, const char[] display, Skills_ItemMenuCallback callback);

/**
 * @brief Registers new skill
 *
 * @param name			Unique skill name
 * @param SkillType		Type of skill (see SkilType)
 * @param upgradable	Pass true if skill can be upgraded, false otherwise 
 *
 * @return				Unique skill ID
 */
native int Skills_Register( const char[] name, SkillType type, bool upgradable = false );

/**
 * @brief Exports int value from config by name
 * @remarks Use escape '/' to travese multiple keys
 *
 * @param skill			Key to travese (Usually skill name)
 * @param key			Key to export
 * @param value			Variable to store exported value 
 * @param defaultValue 	Variable to store default value if key doesn't exist 
 * @param createKey 	Creates key if it doesn't exist (optional)
 *
 * @return				true if key exist and was successfully exported, false otherwise
 */
native bool Skills_ExportIntByName( const char[] skill, const char[] key, int &value, const int defaultValue = 0, bool createKey = false);

/**
 * @brief Exports float value from config by name
 * @remarks Use escape '/' to travese multiple keys
 *
 * @param skill			Key to travese (Usually skill name)
 * @param key			Key to export
 * @param value			Variable to store exported value 
 * @param defaultValue 	Variable to store default value if key doesn't exist 
 * @param createKey 	Creates key if it doesn't exist (optional)
 *
 * @return				true if key exist and was successfully exported, false otherwise
 */
native bool Skills_ExportFloatByName( const char[] skill, const char[] key, float &value, const float defaultValue = 0.0, bool createKey = false);

/**
 * @brief Exports string from config by name
 * @remarks Use escape '/' to travese multiple keys
 *
 * @param skill			Key to travese (Usually skill name)
 * @param key			Key to export
 * @param buffer		Buffer to store exported value
 * @param maxlength		Length of buffer
 * @param defaultValue 	Variable to store default value if key doesn't exist 
 * @param createKey 	Creates key if it doesn't exist (optional)
 *
 * @return				true if key exist and was successfully exported, false otherwise
 */
native bool Skills_ExportStringByName( const char[] skill, const char[] key, char[] buffer, int maxlength, const char[] defaultValue = "", bool createKey = false);

/**
 * @brief Exports vector from config by name
 * @remarks Use escape '/' to travese multiple keys
 *
 * @param skill			Key to travese (Usually skill name)
 * @param key			Key to export
 * @param value			Vector variable to store exported value
 * @param defaultValue 	Variable to store default value if key doesn't exist 
 * @param createKey 	Creates key if it doesn't exist (optional)
 *
 * @return				true if key exist and was successfully exported, false otherwise
 */
native bool Skills_ExportVectorByName( const char[] skill, const char[] key, float value[3], const float defaultValue[3] = {0.0, 0.0, 0.0}, bool createKey = false);

/**
 * @brief Used to request reload from config module
 * @remarks Will produce error if Skills_OnGetSkillSettings callback will not be found
 *
 * @param reopen	If true config will be reopened to take user changes 
 *
 * @noreturn
 */
native void Skills_RequestConfigReload( bool reopen = true );

// ====================================================================================================
// STOCKS/WRAPPERS
// ====================================================================================================

stock void Skills_SetUserData(any data)
{
	gUserData = data;
}

stock void Skills_ForEveryClient(SkillsFunctorFlags flags, Skills_ForEveryFunctor ef, Skills_CollectorFunctor cf = INVALID_FUNCTION, any userdata = INVALID_USERDATA)
{
	if (userdata != INVALID_USERDATA)
		Skills_SetUserData(userdata);
	
	ArrayStack stack = Skills_CollectPlayers(flags, cf);

	while(!stack.Empty)
	{
		bool pass;

		Call_StartFunction(null, ef);
		Call_PushCell(stack.Pop());
		Call_PushCell(gUserData);
		Call_Finish(pass);

		if (!pass)
			break;
	}

	delete stack;
}

stock ArrayStack Skills_CollectPlayers(SkillsFunctorFlags flags, Skills_CollectorFunctor cf = INVALID_FUNCTION)
{
	ArrayStack stack = new ArrayStack();

	for(int i = 1; i <= MaxClients; i++)
	{
		if (flags & SFF_CONNECTED && !IsClientConnected(i))
			continue;

		if (flags & SFF_INGAME && !IsClientInGame(i))
			continue;

		if (flags & SFF_ALIVE && !IsPlayerAlive(i))
			continue;

		if ((flags & SFF_CONNECTED || flags && SFF_INGAME) && !(flags & SFF_BOTS && flags & SFF_PLAYERS))
		{
			bool fakeclient = IsFakeClient(i);
			if ((!fakeclient && flags & SFF_BOTS) || (fakeclient && flags & SFF_PLAYERS))
			{
				continue;
			}
		}

		if (cf != INVALID_FUNCTION)
		{
			Action action;

			Call_StartFunction(null, cf);
			Call_PushCell(i);
			Call_Finish(action);

			if (action == Plugin_Changed)
				continue;
			else if (action == Plugin_Handled)
				break;
		}

		stack.Push(i);
	}

	return stack;
}

stock void Skills_AddClientMoney( int client, float add, bool noMultiplier = false, bool notify = false )
{
	if ( !noMultiplier )
		add *= Skills_GetClientMoneyMultiplier(client);
		
	float money = Skills_GetClientMoney(client) + add;
	Skills_SetClientMoney(client, money);

	if (notify)
	{
		if (add < 0)
		{
			Skills_PrintToChat(client, "\x04\x02-\x05%.0f", Skills_fabs(add));
		}
		else
		{
			Skills_PrintToChat(client, "\x04\x01+\x05%.0f", add);
		}
	}
}

stock void Skills_AddTeamMoney( float add, bool noMultiplier = false )
{
	if ( !noMultiplier )
		add *= Skills_GetTeamMoneyMultiplier();
		
	float money = Skills_GetTeamMoney() + add;
	Skills_SetTeamMoney(money);
}

stock bool Skills_ExportBoolByID( int id, const char[] key, bool &value, const bool defaultValue = false, bool createKey = false)
{
	char name[MAX_SKILL_NAME_LENGTH];
	
	if ( !Skills_GetName(id, name) )
		return false;	
	
	return Skills_ExportIntByName(name, key, view_as<bool>(value), view_as<bool>(defaultValue), createKey);
}

stock bool Skills_ExportIntByID( int id, const char[] key, int &value, const int defaultValue = 0, bool createKey = false)
{
	char name[MAX_SKILL_NAME_LENGTH];
	
	if ( !Skills_GetName(id, name) )
		return false;	
	
	return Skills_ExportIntByName(name, key, value, defaultValue, createKey);
}

stock bool Skills_ExportFloatByID( int id, const char[] key, float &value, const float defaultValue = 0.0, bool createKey = false)
{
	char name[MAX_SKILL_NAME_LENGTH];
	
	if ( !Skills_GetName(id, name) )
		return false;	
	
	return Skills_ExportFloatByName(name, key, value, defaultValue, createKey);
}

stock bool Skills_ExportStringByID( int id, const char[] key, char[] value, int maxlength, const char[] defaultValue = "", bool createKey = false)
{
	char name[MAX_SKILL_NAME_LENGTH];
	
	if ( !Skills_GetName(id, name) )
		return false;	
	
	return Skills_ExportStringByName(name, key, value, maxlength, defaultValue, createKey);
}

stock bool Skills_ExportVectorByID( int id, const char[] key, float value[3], const float defaultValue[3] = {0.0, 0.0, 0.0}, bool createKey = false)
{
	char name[MAX_SKILL_NAME_LENGTH];
	
	if ( !Skills_GetName(id, name) )
		return false;	
	
	return Skills_ExportVectorByName(name, key, value, defaultValue, createKey);
}

stock bool Skills_ExportBool( KeyValues kv, const char[] key, bool& value, const bool defaultValue = false )
{
	return Skills_ExportInt(kv, key, view_as<int>(value), view_as<int>(defaultValue));
}

stock bool Skills_ExportInt( KeyValues kv, const char[] key, int& value, const int defaultValue = 0 )
{
	int id;
	
	if ( !kv.GetSectionSymbol(id) )
		return false;

	if ( !kv.JumpToKey(key) )
	{
		value = defaultValue;
		kv.SetNum(key, defaultValue);
		kv.JumpToKeySymbol(id);
		return false;
	}
	
	value = kv.GetNum(NULL_STRING, defaultValue)
	kv.GoBack();
	return true;
}

stock bool Skills_ExportFloat( KeyValues kv, const char[] key, float& value, const float defaultValue = 0.0 )
{
	int id;
	
	if ( !kv.GetSectionSymbol(id) )
		return false;

	if ( !kv.JumpToKey(key) )
	{
		value = defaultValue;
		kv.SetFloat(key, defaultValue);
		kv.JumpToKeySymbol(id);
		return false;
	}

	value = kv.GetFloat(NULL_STRING, defaultValue);
	kv.GoBack();
	return true;
}

stock bool Skills_ExportString( KeyValues kv, const char[] key, char[] value, int maxlength, const char[] defaultValue = "" )
{
	int id;
	
	if ( !kv.GetSectionSymbol(id) )
		return false;

	if ( !kv.JumpToKey(key) )
	{
		strcopy(value, maxlength, defaultValue);
		kv.SetString(key, defaultValue);
		kv.GoBack();
		kv.JumpToKeySymbol(id);
		return false;
	}
	
	kv.GetString(NULL_STRING, value, maxlength, defaultValue);
	kv.GoBack();
	return true;
}

stock bool Skills_ExportVector( KeyValues kv, const char[] key, float value[3], const float defaultValue[3] = { 0.0, 0.0, 0.0 } )
{
	int id;
	
	if ( !kv.GetSectionSymbol(id) )
		return false;

	if ( !kv.JumpToKey(key) )
	{
		value = defaultValue;
		kv.SetVector(key, defaultValue);
		kv.JumpToKeySymbol(id);
		return false;
	}
	
	kv.GetVector(NULL_STRING, value, defaultValue);
	kv.GoBack();
	return true;
}

stock bool Skills_ExportIntArray( KeyValues kv, const char[] key, int[] array, int arraysize, int[] defaultValueArray = { 0, 0, 0 }, int defaultValueArraySize = -1 )
{
	if (defaultValueArraySize == -1)
		defaultValueArraySize = arraysize;

	int size = EXPORT_ARRAY_SIZE * arraysize;
	char[] data = new char[size];
	char[] defaultValue = new char[size];
	bool r;

	IntArrayToString(defaultValueArray, defaultValueArraySize, defaultValue, size);
	r = Skills_ExportString(kv, key, data, size, defaultValue);
	StringToIntArray(data, array, arraysize);
	return r;
}

stock bool Skills_ExportFloatArray( KeyValues kv, const char[] key, float[] array, int arraysize, float[] defaultValueArray = { 0.0, 0.0, 0.0 }, int defaultValueArraySize = -1 )
{
	if (defaultValueArraySize == -1)
		defaultValueArraySize = arraysize;

	int size = EXPORT_ARRAY_SIZE * arraysize;
	char[] data = new char[size];
	char[] defaultValue = new char[size];
	bool r;

	FloatArrayToString(defaultValueArray, defaultValueArraySize, defaultValue, size);
	r = Skills_ExportString(kv, key, data, size, defaultValue);
	StringToFloatArray(data, array, arraysize);
	return r;
}

stock void KeyValueExportToFile( KeyValues kv )
{
	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof szPath, SKILLS_CONFIG);
	
	kv.Rewind();
	kv.ExportToFile(szPath);
}

// ====================================================================================================
// STOCKS/HELPERS
// ====================================================================================================

stock void StringToFloatArray(const char[] str, float[] array, int arraysize)
{
	char[][] data = new char[arraysize][EXPORT_ARRAY_SIZE];
	int n = ExplodeString(str, EXPORT_ARRAY_DELIMITER, data, arraysize, EXPORT_ARRAY_SIZE);
	n = Skills_Min(n, arraysize);

	for(int i; i < n; i++)
	{
		array[i] = StringToFloat(data[i]);
	}
}

stock void StringToIntArray(const char[] str, int[] array, int arraysize)
{
	char[][] data = new char[arraysize][EXPORT_ARRAY_SIZE];
	int n = ExplodeString(str, EXPORT_ARRAY_DELIMITER, data, arraysize, EXPORT_ARRAY_SIZE);
	n = Skills_Min(n, arraysize);

	for(int i; i < n; i++)
	{
		array[i] = StringToInt(data[i]);
	}
}

stock void FloatArrayToString(float[] array, int arraysize, char[] out, int maxlen)
{
	char[][] data = new char[arraysize][EXPORT_ARRAY_SIZE];
	
	for(int i; i < arraysize; i++)
	{
		FloatToString(array[i], data[i], EXPORT_ARRAY_SIZE);
	}

	ImplodeStrings(data, arraysize, EXPORT_ARRAY_DELIMITER, out, maxlen);
}

stock void IntArrayToString(int[] array, int arraysize, char[] out, int maxlen)
{
	char[][] data = new char[arraysize][EXPORT_ARRAY_SIZE];
	
	for(int i; i < arraysize; i++)
	{
		IntToString(array[i], data[i], EXPORT_ARRAY_SIZE);
	}

	ImplodeStrings(data, arraysize, EXPORT_ARRAY_DELIMITER, out, maxlen);
}

stock void ExecuteCheatCommand(int client, const char[] command, const char[] arg)
{
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arg);
	SetCommandFlags(command, flags);
}

stock bool ClassMatchesComplex( int entity, const char[] match )
{
	static char name[36];
	
	if ( !GetEntityClassname(entity, name, sizeof name) )
		return false;
		
	return strcmp(name, match, false) == 0;
}

stock bool IsValidEntRef(int ref)
{
	int entity = EntRefToEntIndex(ref);
	return entity > 0 && IsValidEntity(entity);
}

stock void Skills_PrintToChat( int client, const char[] fmt, any ... )
{
	char buffer[254];
	VFormat(buffer, sizeof buffer, fmt, 3);
	PrintToChat(client, "%s %s", SKILLS_TAG, buffer);
}

stock void Skills_PrintToChatAll( const char[] fmt, any ... )
{
	char buffer[254];
	VFormat(buffer, sizeof buffer, fmt, 2);
	PrintToChatAll("%s %s", SKILLS_TAG, buffer);
}

stock void Skills_ReplyToCommand( int client, const char[] fmt, any ... )
{
	char buffer[254];
	VFormat(buffer, sizeof buffer, fmt, 3);
	ReplyToCommand(client, "%s %s", GetCmdReplySource() == SM_REPLY_TO_CONSOLE ? SKILLS_TAG_NO_COLOR : SKILLS_TAG, buffer);
}

stock bool Skills_GivePlayerByID(int client, int id)
{
	Skills_ChangeState(client, id, SS_PURCHASED);
	return true;
}

stock bool Skills_RemovePlayerByID(int client, int id)
{
	Skills_ChangeState(client, id, SS_NULL);
	return true;
}

stock void Skills_GiveEveryByID(int skillID)
{
	Skills_SetUserData(skillID);
	Skills_ForEveryClient(SFF_NONE, Skills_GivePlayerByID);
}

stock void Skills_RemoveEveryByID(int skillID)
{
	Skills_SetUserData(skillID);
	Skills_ForEveryClient(SFF_NONE, Skills_RemovePlayerByID);
}

stock any Skills_Min(any value, any min)
{
	return value < min ? min : value;
}

stock any Skills_Max(any value, any max)
{
	return value > max ? max : value;
}

stock any Skills_Clamp(any value, any min, any max)
{
	return Skills_Min(Skills_Max(value, max), min);
}

stock UpgradeImpl Skills_DefaultUpgradeImpl(BaseSkill skill, BaseSkillExport exp, int &nextLevel, float &upgradeCost)
{
	if (sizeof(exp.upgrade_costs) < skill.level)
	{
		ERROR("sizeof(exp.upgrade_costs) < skill.level) <-- Expand max levels in source or decrease max level in config");
		return UI_NULL;
	}

	nextLevel = skill.level;
	upgradeCost = exp.upgrade_costs[skill.level - 1];
	return UI_DEFAULT;
}

stock bool Skills_DefaultCanClientUpgrade(BaseSkill skill, BaseSkillExport exp)
{
	return !Skills_BaseHasMaxLevel(skill, exp);
}

stock int Skills_BaseGetLevelAA(BaseSkill skill)
{
	return Skills_BaseGetLevel(skill) - 1;
}

stock int Skills_BaseGetLevel(BaseSkill skill)
{
	return skill.level - 1;
}

stock void Skills_BaseReset(BaseSkill skill)
{
	skill.reset();
}

stock void Skills_BaseUpgrade(BaseSkill skill)
{
	skill.level++;
}

stock bool Skills_BaseHasMaxLevel(BaseSkill skill, BaseSkillExport exp)
{
	return exp.maxlevel > 0 && Skills_BaseGetLevel(skill) >= exp.maxlevel;
}

stock bool Skills_IsBaseUpgraded(BaseSkill skill)
{
	return Skills_BaseHasSkill(skill) && !Skills_IsBaseLevel(skill, 0);
}

stock bool Skills_IsBaseLevel(BaseSkill skill, int level)
{
	return Skills_BaseGetLevel(skill) == level;
} 

stock bool Skills_BaseHasSkill(BaseSkill skill)
{
	return Skills_BaseGetLevel(skill) >= 0;
}

stock int Skills_abs(int value)
{
	return value < 0 ? -value : value;
}

stock float Skills_fabs(float value)
{
	return value < 0.0 ? -value : value;
}