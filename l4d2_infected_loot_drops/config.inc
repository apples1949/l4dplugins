#if defined _config_included
  #endinput
#endif
#define _config_included
#include <core>

enum SettingType {
	ST_None = 0,
	ST_Group = 1,
	ST_Int = 2,
	ST_Float = 3,
	ST_String = 4,
	ST_Bool = 5,
	ST_Array = 6,
	ST_List = 7,
}


// the api documentation can be found at http://forums.alliedmods.net/showthread.php?t=69167


/**
 * Creates a new empty config object.
 *
 * @note this handle has to be closed
 *
 * @return Handle					The config handle
 */
native Handle ConfigCreate();

native bool ConfigFileExists(const char[] FileName = "");
native bool ConfigReadFile(Handle Config, const char[] FileName = "", char[] ErrorMsg = "", int MaxLength = 0, int &ErrorLine = 0);
native bool ConfigWriteFile(Handle Config, const char[] FileName = "");

// config set/get auto convert

native int ConfigLookupInt(Handle Config, const char[] Path);
native float ConfigLookupFloat(Handle Config, const char[] Path);
native bool ConfigLookupBool(Handle Config, const char[] Path);
native bool ConfigLookupString(Handle Config, const char[] Path, char[] Result, int MaxLength);

native Handle ConfigLookup(Handle Config, const char[] Path);

native int ConfigSettingGetInt(Handle Setting);
native float ConfigSettingGetFloat(Handle Setting);
native bool ConfigSettingGetBool(Handle Setting);
native bool ConfigSettingGetString(Handle Setting, char[] Result, int MaxLength);

native bool ConfigSettingSetInt(Handle Setting, int Value);
native bool ConfigSettingSetFloat(Handle Setting, float Value);
native bool ConfigSettingSetBool(Handle Setting, bool Value);
native bool ConfigSettingSetString(Handle Setting, const char[] Value);

// setting get/set format

native Handle ConfigSettingGetMember(Handle Setting, char[] Name);
native Handle ConfigSettingGetElement(Handle Setting, int Index);

native int ConfigSettingGetIntElement(Handle Setting, int Index);
native float ConfigSettingGetFloatElement(Handle Setting, int Index);
native bool ConfigSettingGetBoolElement(Handle Setting, int Index);
native bool ConfigSettingGetStringElement(Handle Setting, int Index, char[] Result, int MaxLength);

native bool ConfigSettingSetIntElement(Handle Setting, int Index, int Value);
native bool ConfigSettingSetFloatElement(Handle Setting, int Index, float Value);
native bool ConfigSettingSetBoolElement(Handle Setting, int Index, bool Value);
native bool ConfigSettingSetStringElement(Handle Setting, int Index, const char[] Value);

native Handle ConfigSettingAdd(Handle ParentSetting, char[] Name, SettingType Type);
native bool ConfigSettingRemove(Handle ParentSetting, char[] Name);

native Handle ConfigRootSetting(Handle Config);

native int ConfigSettingName(Handle Setting, char[] Result, int MaxLength);
native int ConfigSettingLength(Handle Setting);
native SettingType ConfigSettingType(Handle Setting);

native bool ConfigSettingIsGroup(Handle Setting);
native bool ConfigSettingIsArray(Handle Setting);
native bool ConfigSettingIsList(Handle Setting);

native bool ConfigSettingIsAggregate(Handle Setting);
native bool ConfigSettingIsScalar(Handle Setting);
native bool ConfigSettingIsNumber(Handle Setting);

native void ConfigSettingSourceLine(Handle Setting);

/**
 * _________________Do not edit below this line!_______________________
 */
public Extension __ext_smconfig = 
{
	name = "Config",
	file = "config.ext",
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
#if defined REQUIRE_EXTENSIONS
	required = 1,
#else
	required = 0,
#endif
};
