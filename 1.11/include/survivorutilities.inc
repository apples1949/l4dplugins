#if defined _l4d_su_included
 #endinput
#endif
#define _l4d_su_included

public SharedPlugin __l4d_su = 
{
	name = "survivorutilities",
	file = "l4d_survivor_utilities.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __l4d_ssc_SetNTVOptional()
{
	// Add effects to survivor & modify speeds
	MarkNativeAsOptional("SU_AddFreeze");
	MarkNativeAsOptional("SU_AddBleed");
	MarkNativeAsOptional("SU_AddToxic");
	MarkNativeAsOptional("SU_AddExhaust");
	MarkNativeAsOptional("SU_SetSpeed");
	// Remove effects
	MarkNativeAsOptional("SU_RemoveFreeze");
	MarkNativeAsOptional("SU_RemoveBleed");
	MarkNativeAsOptional("SU_RemoveToxic");
	MarkNativeAsOptional("SU_RemoveExhaust");
	// Check survivor values
	MarkNativeAsOptional("SU_IsBleeding");
	MarkNativeAsOptional("SU_IsToxic");
	MarkNativeAsOptional("SU_IsExhausted");
	MarkNativeAsOptional("SU_GetSpeed");
}
#endif

enum
{
	SPEED_RUN,			// Min 110.0
	SPEED_WALK,			// Min 65.0
	SPEED_CROUCH,		// Min 65.0
	SPEED_LIMP,			// Min 65.0
	SPEED_CRITICAL,		// Min 65.0
	SPEED_WATER,		// Min 65.0
	SPEED_EXHAUST,		// Min 110.0
	SPEED_ADRENALINE,	// Min 110.0
	SPEED_SCOPE			// Min 65.0
};
/*==========================================================================
								Natives									  
----------------------------------------------------------------------------
	- Natives will only work on alive survivors, if client isn't
	connected, is not survivor or is dead, native will throw an error.
	Only SU_SetSpeed can be called on dead survivors.
	
	- The option to stack the effects to survivors depends of the server
	ConVar, so if you try to apply an effect to a player who already has
	this effect, that may not stack, see plugin ConVars to see how they
	work. By default the plugin stacks the lifetime of all effects.
	
	- Effects on survivors will be removed when a survivor dies.
	
	- Speeds are reset only on round restart or map change, not when survivor dies.
============================================================================*/

/**
 * @brief Freezes a survivor.
 *
 * @param client			Target Survivor
 * @param time				Amount of time in seconds the survivor will be frozen, minimum allowed value: 0.1
 *
 */
native void SU_AddFreeze(int client, const float time);

/**
 * @brief Remove Freeze effect on survivor
 *
 * @param client			Target Survivor
 */
native void SU_RemoveFreeze(int client);

/**
 * @brief Makes a survivor bleed.
 *
 * @param client			The client to bleed.
 * @param amount			Amount of hit bleeds the survivor will receive until effect ends, positive values only.
 *
 * @remark					Amount can be stacked if server settings allow it
 */
native void SU_AddBleed(int client, int amount);

/**
 * @brief Removes survivor bleeding
 *
 * @param client			Target Survivor				
 */
native void SU_RemoveBleed(int client);

/**
 * @brief Intoxicates a survivor.
 *
 * @param client			Target Survivor
 * @param amount			Amount of toxic damage hits the survivor will receive until effect ends, positive values only.
 *
 * @remark					Amount can be stacked if server settings allow it
 */
native void SU_AddToxic(int client, int amount);

/**
 * @brief Removes intoxication effect on survivor
 *
 * @param client			Target Survivor
 */
native void SU_RemoveToxic(int client);

/**
 * @brief Sets the speed of the survivor
 *
 * @param client			Target Survivor
 * @param speedType			Type of speed to modify. Valid values: SPEED_RUN, SPEED_WALK, SPEED_CROUCH, SPEED_LIMP, SPEED_CRITICAL, SPEED_WATER, SPEED_EXHAUST.
 * @param amount			Amount of speed (absolute value), lower speeds than the indicated in the speed enum will be clamped.
 *
 * @remark					Default ConVar speeds are asigned when players connects to server, or a new round starts.
 * @remark					Speeds are preserved upon survivor death, you can set survivor speed while dead.
 */
native void SU_SetSpeed(int client, int speedType, const float amount);

/**
 * @brief Exhausts a survivor.
 *
 * @param client			Target Survivor 
 * @param amount			Amount of exhaust tokens, 10 tokens means 1 second to recover from exhaust, 2 if the survivor is moving
 */
native void SU_AddExhaust(int client, int amount); 

/**
 * @brief Removes exhaustion on survivor
 *
 * @param client			Target Survivor
 */
native void SU_RemoveExhaust(int client);

/**
 * @brief Checks if a survivor is frozen
 *
 * @param client			Client to check.
 *
 * @return					True if survivor is frozen, false otherwise.
 */
native bool SU_IsFrozen(int client);

/**
 * @brief Checks if a survivor is bleeding.
 *
 * @param client			Client to check.
 *
 * @return					True if survivor is bleeding, false otherwise.
 */
native bool SU_IsBleeding(int client);

/**
 * @brief Checks if a survivor is intoxicated.
 *
 * @param client			Client to check.
 *
 * @return					True if survivor is intoxicated, false otherwise.
 */
native bool SU_IsToxic(int client);

/**
 * @brief Checks if a survivor is exhausted
 *
 * @param client			Survivor to check.
 *
 * @return					True if exhausted, false otherwise.
 */
native bool SU_IsExhausted(int client);

/**
 * @brief Returns player speed.
 *
 * @param client			Client to check.
 * @param speedType			Type of speed to check. Valid values: SPEED_RUN, SPEED_WALK, SPEED_CROUCH, SPEED_LIMP, SPEED_CRITICAL, SPEED_WATER, SPEED_EXHAUST.
 *
 * @return					Current survivor speed value.
 */
native float SU_GetSpeed(int client, int speedType);

/*==========================================================================
							GlobalForwards									  
----------------------------------------------------------------------------
	- GlobalForwards can be used to hook plugin events,they also
	can be hooked to modify parameters or even block the event.
	
	- Effect ends cannot be blocked, only notify.
	- Exhaust/bleed okens are refered to the amount of damage hits that
	the survivor will receive until effect ends.
	- Survivor death removes the current effects, but does not call
	any GlobalForward.
	- Post forwards are used to get the results of the native call
	after hooks, in case the native has been blocked via Plugin_Handled,
	post forwards won't be fired,
==========================================================================*/

/**
 * @brief 					Called whenever SU_AddExhaust is invoked
 *
 * @param client			Target survivor.
 * @param amount			Amount of exhaust tokens.
 *
 * @return					Plugin_Handled to block the exhaustion, Plugin_Continue otherwise.
 */
forward Action SU_OnExhaust(int client, int& amount);

/**
 * @brief 					Post forward for SU_OnExhaust, gives the final values after hooking.
 *
 * @param client			Target client.
 * @param amount			Amount of exhaust tokens.
 * @param overload			True if the player is already under the effect and is an effect override/extension. False otherwise.
 *
 * @noreturn
 */
forward void SU_OnExhaust_Post(int client, int amount, const bool overload);

/**
 * @brief					Called whenever SU_AddFreeze is invoked.
 *
 * @param client			Target survivor.
 * @param time				Duration of the freeze (if survivor is already frozen it may not be applied based on server config)
 * 
 * @return					Plugin_Handled to block the freeze, Plugin_Changed to override time value, Plugin_Continue otherwise.
 */
forward Action SU_OnFreeze(int client, float& time);

/**
 * @brief					Post forward for SU_OnFreeze, gives the final values after hooking.
 *
 * @param client			Frozen survivor.
 * @param time				Duration of the freeze.
 * @param overload			True if the player is already under the effect and is an effect override/extension. False otherwise.
 * 
 * @noreturn
 */
forward void SU_OnFreeze_Post(int client, float time, const bool overload);

/**
 * @brief					Called whenever SU_AddBleed is invoked.
 *
 * @param client			Target survivor.
 * @param amount			Amount of bleed tokens.
 *
 * @return					Plugin_Handled to block the bleed, Plugin_Changed to override token amount, Plugin_Continue otherwise. 
 */
forward Action SU_OnBleed(int client, int& amount);

/**
 * @brief					Post forward for SU_OnBleed, gives the final values after hooking.
 *
 * @param client			Target survivor.
 * @param amount			Amount of bleed tokens.
 * @param overload			True if the player is already under the effect and is an effect override/extension. False otherwise.
 *
 * @noreturn
 */
forward void SU_OnBleed_Post(int client, int amount, const bool overload);
 
/**
 * @brief					Called whenever SU_AddToxic is invoked.
 *
 * @param client			Target survivor.
 * @param amount			Amount of toxic tokens.
 * 
 * @return					Plugin_Handled to block the intoxication, Plugin_Changed to override token amount, Plugin_Continue otherwise. 
 */
forward Action SU_OnToxic(int client, int& amount);

/**
 * @brief					Post forward for SU_OnToxic, gives the final values after hooking.
 *
 * @param client			Target survivor.
 * @param amount			Amount of toxic tokens.
 * @param overload			True if the player is already under the effect and is an effect override/extension. False otherwise.
 * 
 * @noreturn
 */
forward void SU_OnToxic_Post(int client, int amount, const bool overload);

/**
 * @brief					Called whenever SU_RemoveFreeze is invoked.
 *
 * @param client			Target survivor.
 *
 * @noreturn
 */
forward void SU_OnFreezeEnd(int client);

/**
 * @brief					Called whenever SU_RemoveBleed is invoked.
 *
 * @param client			Target survivor.
 *
 * @noreturn
 */
forward void SU_OnBleedEnd(int client);

/**
 * @brief					Called whenever SU_RemoveToxic is invoked.
 *
 * @param client			Target survivor.
 *
 * @noreturn
 */
forward void SU_OnToxicEnd(int client);

/**
 * @brief					Called whenever SU_RemoveExhaust is invoked.
 *
 * @param client			Target survivor
 *
 * @noreturn
 */
forward void SU_OnExhaustEnd(int client);

/*==========================================================================
							Backpack use & revive								  
----------------------------------------------------------------------------
	- Caution when overriding duration, bots are not programmed to keep
	healing over 10 seconds, so they will reset their action endlessly!
	
	- 9.75 should be a limit time, as plugin maker is your job to
	ensure that if a bot is going to heal, don't set very high time.
==========================================================================*/

/**
 * @brief					Called when a survivor is using a defibrillator
 *
 * @param client			Survivor using the defibrillator
 * @param targetModel		Death model entity being defibrillated
 * @param duration			Duration of the defib event
 * @remark					L4D2.
 *
 * @return					Plugin_Handled to block the defibrillation, Plugin_Changed to override duration, Plugin_Continue otherwise
 */
forward Action SU_OnDefib(int client, int targetModel, float& duration);

/**
 * @brief					Post forward for SU_OnFreeze, gives the final values after hooking.
 *
 * @param client			Survivor using the defibrillator.
 * @param targetModel		Index of death model entity target.
 * @param duration			Duration of the defib event.
 * @remark					Only works in L4D2
 *
 * @noreturn
 */
forward void SU_Ondefib_Post(int client, int targetModel, float duration);

/**
 * @brief					Called when a survivor revives another one
 *
 * @param client			Survivor reviving
 * @param target			Survivor being revived
 * @param duration			Duration of the deploy
 *
 * @return					Plugin_Handled to block the reviving, Plugin_Changed to override duration, Plugin_Continue otherwise
 */
forward Action SU_OnRevive(int client, int target, float& duration);

/**
 * @brief					Post event for survivor reviving, use to get the final values after hooks
 *
 * @param client			Survivor reviving
 * @param target			Survivor being revived
 * @param duration			Duration of the deploy
 *
 * @noreturn
 */
forward void SU_OnRevive_Post(int client, int target, float duration);

/**
 * @brief					Called when a survivor heals with a first aid kit
 *
 * @param client			Survivor performing heal
 * @param target			Survivor being healed
 * @param duration			Duration of the healing
 * @remark					L4D AND L4D2
 *
 * @return					Plugin_Handled to block the healing, Plugin_Changed to override duration, Plugin_Continue otherwise
 */
forward Action SU_OnHeal(int client, int target, float& duration);

/**
 * @brief					Post event for survivor healing, use to get the final values after hooks
 *
 * @param client			Survivor performing heal
 * @param target			Survivor being healed
 * @param duration			Duration of the healing
 * @remark					L4D AND L4D2
 *
 * @noreturn
 */
forward void SU_OnHeal_Post(int client, int target, float duration);