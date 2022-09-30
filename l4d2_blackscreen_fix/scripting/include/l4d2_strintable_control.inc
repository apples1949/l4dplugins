#if defined _stringtable_included
  #endinput
#endif
#define _stringtable_included

enum ()
{
	index_downloadables			= 0,
	index_modelprecache			= 1,
	index_genericprecache       = 2,
	index_soundprecache         = 3,
	index_decalprecache         = 4,
	index_instancebaseline      = 5,
	index_lightstyles           = 6,
	index_userinfo              = 7,
	index_server_query_info     = 8,
	index_ParticleEffectNames   = 9,
	index_EffectDispatch        = 10,
	index_VguiScreen            = 11,
	index_Materials             = 12,
	index_InfoPanel             = 13,
	index_Scenes                = 14,
	index_MeleeWeapons          = 15,
	index_GameRulesCreation     = 16,
	index_BlackMarketTable      = 17
}


/**
 * @brief Get pointer of s_NetworkStringTableServer
 *
 * @return		s_NetworkStringTableServer pointer.
 */
native int StringtableGetPointer();

/**
 * @brief Delete all string from stringtable
 *	
 * @param		index of stringtable.
 * @return		true if all string has been deleted, false else.
 */
native bool StringtableReset(int index);

/**
 * @brief Gets name of stringtable by index.
 *	
 * @param		index of stringtable.
 * @param		buffer to store name.
 * @param		size of buffer.
 * @return		no return.
 */
native void StringtableGetNameByIndex(int index, char[] szBuffer, int size);