#pragma semicolon 1
#pragma newdecls required

public SharedPlugin l4d2_GetWitchNumber = 
{
    name = "l4d2_GetWitchNumber", file = "l4d2_GetWitchNumber.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

/*
#if !defined REQUIRE_PLUGIN
public l4d2_GetWitchNumber_SetNTVOptional()
{
    
}
#endif
*/

/**
 * @根据女巫ID返回编号.
 *
 * @param iWitchid			传入女巫实体ID.
 *
 * @return					如果是第一个出现的女巫则return 0.
 */
native int GetWitchNumber(int iWitchid);