/**
 * vim: set ts=4 :
 * =============================================================================
 * L4D2_Direct
 * Copyright (C) 2012 Michael "ProdigySim" Busby
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */
#if defined _l4d2_direct_included
 #endinput
#endif
#define _l4d2_direct_included

#include <sourcemod>
#include <l4d2d_internals>
#include <l4d2d_timers>


/* CDirector Variable access */

/**
 * Get the current Tank count stored by the director.
 * 
 * @note This should work on any gamemode, and is a good check to see if there is a tank in play
 *
 *
 * @return			The current number of tanks in play.
 * @error			Director address not found.
 */
stock int L4D2Direct_GetTankCount()
{
	return LoadFromAddress( L4D2Direct_GetTankCountAddr() , NumberType_Int32 );
}

/**
 * Get a reference to the CDirector natural mob spawn CountdownTimer
 *
 * @note This timer is used to control the spawning of natural hordes.
 * @note This timer gets reset during unnatural hordes as well (boomer/car alarm hordes)
 * @note Some scripted events will effectively "take over", by reducing the mob spawn time.
 *
 * @return				CountdownTimer reference to the timer, or CTimer_Null on lookup failure.
 */
stock CountdownTimer L4D2Direct_GetMobSpawnTimer()
{
	static Address pMobSpawnTimer = Address_Null;
	if(pMobSpawnTimer == Address_Null)
	{
		int offs = GameConfGetOffset(L4D2Direct_GetGameConf(), "CDirector::MobSpawnTimer");
		if(offs == -1) return CTimer_Null;
		pMobSpawnTimer = L4D2Direct_GetCDirector() + view_as<Address>(offs);
	}
	return view_as<CountdownTimer>(pMobSpawnTimer);
}

/**
 * Get a reference to a IntervalTimer that counts up from the last death of a given SI class
 *
 * @note The main place I've seen these timers used is in the SI spawning algorithms (CDirector::UpdateSpecialSpawns)
 * @note This timer gets checked against SI respawn interval for different gamemodes, some of which are cvar controlled (e.g. versus_special_respawn_interval)
 *
 * @param class		SI Class to retrieve timer for
 * @return			IntervalTimer reference to the timer, or ITimer_Null on lookup failure or bad class.
 */
stock IntervalTimer L4D2Direct_GetSIClassDeathTimer(int class)
{
	// Should be between smoker and charger
	if(class < 1 || class > 6) return ITimer_Null;
	
	static Address pSIDeathTimers = Address_Null;
	if(pSIDeathTimers == Address_Null)
	{
		int offs = GameConfGetOffset(L4D2Direct_GetGameConf(), "CDirector::ClassDeathTimers");
		if(offs == -1) return ITimer_Null;
		pSIDeathTimers = L4D2Direct_GetCDirector() + view_as<Address>(offs);
	}
	return view_as<IntervalTimer>(view_as<int>(pSIDeathTimers) + ((class - 1) * SIZEOF_ITIMER));
}

/**
 * Get a reference to a CountdownTimer that counts down from the last attempted director-controlled spawn of an SI
 *
 * @note The main place I've seen these timers used is in the SI spawning algorithms (CDirector::UpdateSpecialSpawns)
 * @note This timer is hard-coded to use a duration of 20.0s.
 *
 * @param class		SI Class to retrieve timer for
 * @return			CountdownTimer reference to the timer, or CTimer_Null on lookup failure or bad class.
 */
stock CountdownTimer L4D2Direct_GetSIClassSpawnTimer(int class)
{
	// Should be between smoker and charger
	if(class < 1 || class > 6) return CTimer_Null;
	
	static Address pSISpawnTimers = Address_Null;
	if(pSISpawnTimers == Address_Null)
	{
		int offs = GameConfGetOffset(L4D2Direct_GetGameConf(), "CDirector::ClassSpawnTimers");
		if(offs == -1) return CTimer_Null;
		pSISpawnTimers = L4D2Direct_GetCDirector() + view_as<Address>(offs);
	}
	return view_as<CountdownTimer>(view_as<int>(pSISpawnTimers) + ((class - 1) * SIZEOF_CTIMER));
}

/**
 * Gets the number of times the tank has passed to a player.
 *
 * @note When this variable is >1 the tank will be replaced with a bot when the his frustration reaches 0.
 * @note The initial pass from AI to a player counts as a pass.
 * @note As this is global on the director weird things could potentially happen if more than one tank is alive at a time with z_frustration 1.
 *
 * @return          The number of passes.
 */
stock int L4D2Direct_GetTankPassedCount()
{
	return LoadFromAddress(L4D2Direct_GetTankPassedCountAddr(), NumberType_Int32);
}

/**
 * Sets the number of times the tank has passed to a player.
 *
 * @note When this variable is >1 the tank will be replaced with a bot when the his frustration reaches 0.
 * @note The initial pass from AI to a player counts as a pass.
 * @note As this is global on the director weird things could potentially happen if more than one tank is alive at a time with z_frustration 1.
 *
 * @param           New number of passes value
 * @noreturn
 */
stock void L4D2Direct_SetTankPassedCount(int passes)
{
	StoreToAddress(L4D2Direct_GetTankPassedCountAddr(), passes, NumberType_Int32);
}

/* CDirectorVersusMode Variable access */

/**
 * Reads the director's stored campaign score for a given team.
 * 
 * @note You can use the gamerules m_bAreTeamsFlipped property to figure out team numbers
 * @note The campaign scores value is also stored in gamerules, however this is the "master" version.
 * @note Campaign scores are only updated on round end, so this will not reflect current survivor distance score
 *
 *
 * @param teamNumber	Team number to read campaign score of, 0 or 1.
 * @return				Campaign score for the given team.
 * @error				Director or Versus Director address not found.
 */
stock int L4D2Direct_GetVSCampaignScore( int teamNumber )
{
	if(teamNumber < 0 || teamNumber > 1) return -1;

	return LoadFromAddress( L4D2Direct_GetVSCampaignScoresAddr() + view_as<Address>(teamNumber * 4), NumberType_Int32 );
}

/**
 * Set the director's stored campaign score for a given team.
 * 
 * @note You can use the gamerules m_bAreTeamsFlipped property to figure out team numbers
 * @note The campaign scores value is also stored in gamerules, however this is the "master" version.
 * @note Keep in mind the current survivor team's distance/bonus score will be added at the end of a round
 *
 *
 * @param teamNumber	Team number to set campaign score of, 0 or 1.
 * @param score			Score to set for the team
 * @error				Director or Versus Director address not found.
 * @noreturn
 */
stock void L4D2Direct_SetVSCampaignScore( int teamNumber , int score )
{
	if(teamNumber < 0 || teamNumber > 1) return;

	StoreToAddress(L4D2Direct_GetVSCampaignScoresAddr() + view_as<Address>(teamNumber * 4), score, NumberType_Int32);
}

/**
 * Reads the tank flow percent for a given round for versus mode
 * 
 * @note You should check GetVSTankToSpawnThisRound to find out if a tank is going to be spawned for this round.
 * @note When the survivors reach this flow percent minus versus_boss_buffer converted to flow percent, a tank will spawn.
 *
 *
 * @param roundNumber	Round number to read tank spawn flow percent of
 * @return				Tank spawn flow percent for the given round
 * @error				Director or Versus Director address not found.
 */
stock float L4D2Direct_GetVSTankFlowPercent(int roundNumber)
{
	if(roundNumber < 0 || roundNumber > 1) return -1.0;
	
	return view_as<float>(LoadFromAddress(L4D2Direct_GetVSTankFlowAddr() + view_as<Address>(roundNumber * 4) , NumberType_Int32));
}

/**
 * Sets the tank flow percent for a given round for versus mode
 * 
 * @note You should check GetVSTankToSpawnThisRound to find out if there is still a tank to spawn this round.
 * @note When the survivors reach this flow percent minus versus_boss_buffer converted to flow percent, a tank will spawn.
 *
 *
 * @param roundNumber	Round number to set tank spawn flow percent of
 * @param flow			Floating point percent of flow distance.
 * @noreturn
 * @error				Director or Versus Director address not found.
 */
stock void L4D2Direct_SetVSTankFlowPercent( int roundNumber , float flow )
{
	if(roundNumber < 0 || roundNumber > 1) return;
	
	StoreToAddress(L4D2Direct_GetVSTankFlowAddr() + view_as<Address>(roundNumber * 4) , view_as<int>(flow), NumberType_Int32 );
}

/**
 * Is there going to be a tank spawned during the given round
 *
 * @param roundNumber	Round number to check for tank spawn on
 * @return				True if there is still a tank to spawn for the given round, false if it has already been spawned or will not spawn.
 * @error				Director or Versus Director address not found.
 */
stock bool L4D2Direct_GetVSTankToSpawnThisRound( int roundNumber )
{
	if(roundNumber < 0 || roundNumber > 1) return false;

	return view_as<bool>(LoadFromAddress(L4D2Direct_GeVSTankToSpawnAddr() + view_as<Address>(roundNumber), NumberType_Int8));
}

/**
 * Tell the director whether or not to spawn a(nother) flow distance-based tank for this round.
 *
 * @note If you set this to true after a flow-distance-based tank has been spawned, this can trigger another tank to be spawned based on flow distance
 *
 * @param roundNumber	Round number to set a tank spawn on
 * @param spawn			Whether or not to spawn a flow-distance-based tank for this round.
 * @noreturn
 * @error				Director or Versus Director address not found.
 */
stock void L4D2Direct_SetVSTankToSpawnThisRound( int roundNumber , bool spawn )
{
	if(roundNumber < 0 || roundNumber > 1) return;
	
	StoreToAddress(L4D2Direct_GeVSTankToSpawnAddr() + view_as<Address>(roundNumber) , view_as<int>(spawn), NumberType_Int8);
}

/**
 * Reads the witch flow percent for a given round for versus mode
 * 
 * @note You should check GetVSWitchToSpawnThisRound to find out if a witch is going to be spawned for this round.
 * @note When the survivors reach this flow percent minus versus_boss_buffer converted to flow percent, a witch will spawn.
 *
 *
 * @param roundNumber	Round number to read witch spawn flow percent of
 * @return				Witch spawn flow percent for the given round
 * @error				Director or Versus Director address not found.
 */
stock float L4D2Direct_GetVSWitchFlowPercent( int roundNumber )
{
	if(roundNumber < 0 || roundNumber > 1) return -1.0;

	return view_as<float>(LoadFromAddress(L4D2Direct_GetVSWitchFlowAddr() + view_as<Address>(roundNumber * 4), NumberType_Int32));
}

/**
 * Sets the witch flow percent for a given round for versus mode
 * 
 * @note You should check GetVSWitchToSpawnThisRound to find out if there is still a witch to spawn this round.
 * @note When the survivors reach this flow percent minus versus_boss_buffer converted to flow percent, a witch will spawn.
 *
 *
 * @param roundNumber	Round number to set witch spawn flow percent of
 * @param flow			Floating point percent of flow distance.
 * @noreturn
 * @error				Director or Versus Director address not found.
 */
stock void L4D2Direct_SetVSWitchFlowPercent( int roundNumber , float flow )
{
	if(roundNumber < 0 || roundNumber > 1) return;
	
	StoreToAddress(L4D2Direct_GetVSWitchFlowAddr() + view_as<Address>(roundNumber * 4), view_as<int>(flow), NumberType_Int32);
}

/**
 * Is there going to be a witch spawned during the given round
 *
 * @param roundNumber	Round number to check for witch spawn on
 * @return				True if there is still a witch to spawn for the given round, false if it has already been spawned or will not spawn.
 * @error				Director or Versus Director address not found.
 */
stock bool L4D2Direct_GetVSWitchToSpawnThisRound( int roundNumber )
{
	if(roundNumber < 0 || roundNumber > 1) return false;
	
	return view_as<bool>(LoadFromAddress(L4D2Direct_GetVSWitchToSpawnAddr() + view_as<Address>(roundNumber), NumberType_Int8));
}

/**
 * Tell the director whether or not to spawn a(nother) flow distance-based witch for this round.
 *
 * @note If you set this to true after a flow-distance-based witch has been spawned, this can trigger another witch to be spawned based on flow distance
 *
 * @param roundNumber	Round number to set a witch spawn on
 * @param spawn			Whether or not to spawn a flow-distance-based witch for this round.
 * @noreturn
 * @error				Director or Versus Director address not found.
 */
stock void L4D2Direct_SetVSWitchToSpawnThisRound( int roundNumber , bool spawn )
{
	if(roundNumber < 0 || roundNumber > 1) return;
	
	StoreToAddress(L4D2Direct_GetVSWitchToSpawnAddr() + view_as<Address>(roundNumber), view_as<int>(spawn), NumberType_Int8);
}

/**
 * Get a reference to the VersusStart CountdownTimer
 *
 * @note This timer controls when the saferoom door will open and PZ spawning is enabled
 * @note The default duration for this timer is controlled by cvar: versus_force_start_time
 *
 * @return				CountdownTimer reference to the timer, or CTimer_Null on lookup failure.
 * @error				Director address not found.
 */
stock CountdownTimer L4D2Direct_GetVSStartTimer()
{
	static Address pVSStartTimer = Address_Null;
	if(pVSStartTimer == Address_Null)
	{
		int offs = GameConfGetOffset(L4D2Direct_GetGameConf(), "CDirectorVersusMode::VersusStartTimer");
		if(offs == -1) return CTimer_Null;
		pVSStartTimer = L4D2Direct_GetCDirectorVersusMode() + view_as<Address>(offs);
	}
	return view_as<CountdownTimer>(pVSStartTimer);
}

/* CDirectorScavengeMode Variable access */

/**
 * Get a reference to the Scavenge Round Setup CountdownTimer
 *
 * @note This timer controls when the scavenge "warmup" time ends and PZ/game timers start.
 * @note The default duration for this timer is controlled by cvar: scavenge_round_setup_time
 *
 * @return				CountdownTimer reference to the timer, or CTimer_Null on lookup failure.
 * @error				Director address not found.
 */
stock CountdownTimer L4D2Direct_GetScavengeRoundSetupTimer()
{
	static Address pRoundSetupTimer = Address_Null;
	if(pRoundSetupTimer == Address_Null)
	{
		int offs = GameConfGetOffset(L4D2Direct_GetGameConf(), "CDirectorScavengeMode::RoundSetupTimer");
		if(offs == -1) return CTimer_Null;
		pRoundSetupTimer = L4D2Direct_GetCDirectorScavengeMode() + view_as<Address>(offs);
	}
	return view_as<CountdownTimer>(pRoundSetupTimer);
}

/**
 * Get a reference to the Scavenge Overtime Grace CountdownTimer
 *
 * @note This timer keeps track of how long survivors have gone without holding a can during overtime.
 * @note The default duration for this timer is controlled by cvar: scavenge_overtime_grace_time
 *
 * @return				CountdownTimer reference to the timer, or CTimer_Null on lookup failure.
 * @error				Director address not found.
 */
stock CountdownTimer L4D2Direct_GetScavengeOvertimeGraceTimer()
{
	static Address pOvertimeGraceTimer = Address_Null;
	if(pOvertimeGraceTimer == Address_Null)
	{
		int offs = GameConfGetOffset(L4D2Direct_GetGameConf(), "CDirectorScavengeMode::OvertimeGraceTimer");
		if(offs == -1) return CTimer_Null;
		pOvertimeGraceTimer = L4D2Direct_GetCDirectorScavengeMode() + view_as<Address>(offs);
	}
	return view_as<CountdownTimer>(pOvertimeGraceTimer);
}

/* TerrorNavMesh Variable access */

/**
 * Get the max flow distance (in flow units) for the current map.
 *
 * @note The flow distance for each map is generated as it is loaded, and it can change slightly (a few hundred units) with each load.
 * @note You can use this value to convert a flow distance to a flow percent, and vice versa.
 *
 * @return				Max flow distance for the current loaded map.
 * @error				TerrorNavMesh address not found.
 */
stock float L4D2Direct_GetMapMaxFlowDistance()
{
	return view_as<float>(LoadFromAddress(L4D2Direct_GetMapMaxFlowDistanceAddr() , NumberType_Int32));
}

/* CTerrorPlayer Variable access */

/**
 * Get a reference to a CountdownTimer that tracks when an SI player can next spawn.
 *
 * @note The duration of this timer is controlled by the cvars z_ghost_delay_min and z_ghost_delay_max.
 * @param client		Client id to get the spawn timer for
 * @return				CountdownTimer reference to the timer, or CTimer_Null on lookup failure.
 * @error				Invalid client.
 */
stock CountdownTimer L4D2Direct_GetSpawnTimer(int client)
{
	if (client < 1 || client > MaxClients)
		return CTimer_Null;

	Address pEntity = GetEntityAddress(client);
	if (pEntity == Address_Null)
		return CTimer_Null;

	int offs = GameConfGetOffset(L4D2Direct_GetGameConf(), "CTerrorPlayer::SpawnTimer");
	if (offs == -1)
		return CTimer_Null;

	return view_as<CountdownTimer>(pEntity + view_as<Address>(offs));
}

/**
 * Get a reference to a CountdownTimer that tracks when an survivor player is invulnerable due to "godframes".
 *
 * @param client		Client id to get the godframes timer for
 * @return				CountdownTimer reference to the timer, or CTimer_Null on lookup failure.
 * @error				Invalid client.
 */
stock CountdownTimer L4D2Direct_GetInvulnerabilityTimer(int client)
{
	if (client < 1 || client > MaxClients)
		return CTimer_Null;

	Address pEntity = GetEntityAddress(client);
	if (pEntity == Address_Null)
		return CTimer_Null;

	int offs = GameConfGetOffset(L4D2Direct_GetGameConf(), "CTerrorPlayer::InvulnerabilityTimer");
	if (offs == -1)
		return CTimer_Null;

	return view_as<CountdownTimer>(pEntity + view_as<Address>(offs));
}

/**
 * Looks up the number of tickets a client has for entry into the tank lottery.
 *
 * @note The number of tickets you have is equal to your damage done as an SI and will still increase as you do damage with the Tank.
 * @note When the tank is passed away from you your tickets are set back to zero.
 * @param client		Client id to get the tickets for
 * @return				Number of tickets.
 * @error				Invalid client.
 */
stock int L4D2Direct_GetTankTickets(int client)
{
	if (client < 1 || client > MaxClients)
		return -1;

	int value;
	if (GetEntityValueFromOffset(client, "CTerrorPlayer::m_iTankTickets", NumberType_Int32, value))
		return value;
	
	return -1;
}

/**
 * Sets the number of tickets a player has for entry into the tank lottery.
 *
 * @param client		Client id to set the tickets for
 * @param tickets		New value for the client's tank lottery tickets
 * @noreturn
 * @error				Invalid client.
 */
stock void L4D2Direct_SetTankTickets(int client, int tickets)
{
	if (client < 1 || client > MaxClients)
		return;

	SetEntityValueFromOffset(client, "CTerrorPlayer::m_iTankTickets", NumberType_Int32, tickets);
}

/**
 * Gets a client's shove penalty.
 *
 * @note The returned value will be between 0 and z_gun_swing_{vs,coop}_max_penalty.
 * @param client		Client id
 * @return				Shove penlty of -1 on error
 */
stock int L4D2Direct_GetShovePenalty(int client)
{
	if (client < 1 || client > MaxClients)
		return -1;
	
	int value;
	if (GetEntityValueFromOffset(client, "CTerrorPlayer::m_iShovePenalty", NumberType_Int32, value))
	    return value;
	
	return -1;
}

/**
 * Sets a client's shove penalty.
 *
 * @note The penalty should be set between 0 and z_gun_swing_{vs,coop}_max_penalty.
 * @param client		Client id
 * @param penalty		Shove penalty
 * @noreturn
 */ 
stock void L4D2Direct_SetShovePenalty(int client, int penalty)
{
	if (client < 1 || client > MaxClients)
		return;
	
	SetEntityValueFromOffset(client, "CTerrorPlayer::m_iShovePenalty", NumberType_Int32, penalty);
}

/**
 * Gets the time at which a survivor can perform his next +attack2.
 *
 * @param client		Client id
 * @return				Time or 0.0 on error
 */
stock float L4D2Direct_GetNextShoveTime(int client)
{
	if (client < 1 || client > MaxClients)
		return 0.0;
	
	int time;
	if (GetEntityValueFromOffset(client, "CTerrorPlayer::m_fNextShoveTime", NumberType_Int32, time))
		return Float:time;
	
	return 0.0;
}

/**
 * Sets the time at which a survivor can perform his next +attack2.
 *
 * @param client		Client id
 * @param time			Game time
 * @noreturn
 */
stock void L4D2Direct_SetNextShoveTime(int client, float time)
{
	if (client < 1 || client > MaxClients)
		return;
	
	SetEntityValueFromOffset(client, "CTerrorPlayer::m_fNextShoveTime", NumberType_Int32, view_as<int>(time));
}

/**
 * Gets the health of the survivor from before they were incapacitated
 *
 * @note This may only apply to hanging players
 * @param client		Client id
 * @return				Real health before incapacitation
 */
stock int L4D2Direct_GetPreIncapHealth(int client)
{
	if (client < 1 || client > MaxClients)
		return -1;

	int value;
	if (!GetEntityValueFromOffset(client, "CTerrorPlayer::m_preIncapacitatedHealth", NumberType_Int32, value)) value = -1;
	return value;
}

/**
 * Sets the health of the survivor from before they were incapacitated
 *
 * @note This may only apply to hanging players
 * @param client		Client id
 * @param health		New pre-incap health
 * @noreturn
 */
stock void L4D2Direct_SetPreIncapHealth(int client, int health)
{
	if (client < 1 || client > MaxClients)
		return;

	SetEntityValueFromOffset(client, "CTerrorPlayer::m_preIncapacitatedHealth", NumberType_Int32, health);
}

/**
 * Gets the temporary health of the survivor from before they were incapacitated
 *
 * @note This may only apply to hanging players
 * @param client		Client id
 * @return				Temporary health before incapacitation
 */
stock void L4D2Direct_GetPreIncapHealthBuffer(int client)
{
	if (client < 1 || client > MaxClients)
		return -1;

	int value;
	if (!GetEntityValueFromOffset(client, "CTerrorPlayer::m_preIncapacitatedHealthBuffer", NumberType_Int32, value)) value = -1;
	return value;
}

/**
 * Sets the health of the survivor from before they were incapacitated
 *
 * @note This may only apply to hanging players
 * @param client		Client id
 * @param health		New pre-incap temporary health
 * @noreturn
 */
stock void L4D2Direct_SetPreIncapHealthBuffer(int client, int health)
{
	if (client < 1 || client > MaxClients)
		return;

	SetEntityValueFromOffset(client, "CTerrorPlayer::m_preIncapacitatedHealthBuffer", NumberType_Int32, health);
}

/**
 * Gets the maximum number of flames a CInferno is allowed to spawn.
 *
 * @param entity		Entity id
 * @return				Number of flames or -1 on error
 */
stock int L4D2Direct_GetInfernoMaxFlames(int entity)
{
	int flames;
	if (GetEntityValueFromOffset(entity, "CInferno::m_maxFlames", NumberType_Int32, flames))
		return flames;
	
	return -1;
}

/**
 * Sets the maximum number of flames a CInferno is allowed to spawn.
 *
 * @param entity		Entity id
 * @param flames		Number of flames
 * @noreturn
 */
stock void L4D2Direct_SetInfernoMaxFlames(int entity, int flames)
{
	SetEntityValueFromOffset(entity, "CInferno::m_maxFlames", NumberType_Int32, flames);
}

/**
 * Get the TerrorNavArea which holds a specific position.
 *
 * @note Some positions will not return a nav area (Address_Null). Notable examples are saferooms and small ledges like the guard rail at the start of c2m1_highway.
 * @param pos           The position to find the containing nav area of
 * @param beneathLimit
 * @return              Address to a TerrorNavArea or Address_Null
 * @error               Unable to prepare SDK call
 */
stock Address L4D2Direct_GetTerrorNavArea(float pos[3], float beneathLimit = 120.0)
{
	static Handle GetNavAreaSDKCall = null;

	if (GetNavAreaSDKCall == null)
	{
		StartPrepSDKCall(SDKCall_Raw);
		
		if (!PrepSDKCall_SetFromConf(L4D2Direct_GetGameConf(), SDKConf_Signature, "CNavMesh::GetNavArea"))
		{
			return Address_Null;
		}
		
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		GetNavAreaSDKCall = EndPrepSDKCall();
		
		if (GetNavAreaSDKCall == null)
		{
			return Address_Null;
		}
	}
	return view_as<Address>(SDKCall(GetNavAreaSDKCall, L4D2Direct_GetTerrorNavMesh(), pos, beneathLimit));
}

/**
 * Find the distance through the map (in flow units) that a TerrorNavArea is located.
 *
 * @param  pTerrorNavArea   Pointer to a TerrorNavArea
 * @return                  The flow units through the map that the TerrorNavArea is located at.
 * @error                   When passed an Address_Null
 */
stock float L4D2Direct_GetTerrorNavAreaFlow(Address pTerrorNavArea)
{
	if (pTerrorNavArea == Address_Null)
		return 0.0;

	int offs = GameConfGetOffset(L4D2Direct_GetGameConf(), "TerrorNavArea::m_flow");
	if (offs == -1)
		return 0.0;

	return view_as<float>(LoadFromAddress(pTerrorNavArea + view_as<Address>(offs), NumberType_Int32));
}

/**
 * Force the director to pass the tank.
 *
 * @param entity			Entity index of the tank
 * @param bEnterStasis		Should the tank be put in statis
 * @return					False on error otherwise true
 * @error					SDK call preparation failed
 */ 
stock bool L4D2Direct_TryOfferingTankBot(int entity, int bEnterStasis)
{
	static Handle TryOfferingTankBotSDKCall = null;

	if (TryOfferingTankBotSDKCall == null)
	{
		StartPrepSDKCall(SDKCall_Raw);
		
		if (!PrepSDKCall_SetFromConf(L4D2Direct_GetGameConf(), SDKConf_Signature, "CDirector::TryOfferingTankBot"))
		{
			return false;
		}
		
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		TryOfferingTankBotSDKCall = EndPrepSDKCall();
		
		if (TryOfferingTankBotSDKCall == null)
		{
			return false;
		}
	}
	
	SDKCall(TryOfferingTankBotSDKCall, L4D2Direct_GetCDirector(), entity, bEnterStasis);
	return true;
}

/**
 * Gets a player's distance in flow units.
 *
 * @param client			Client ID
 * @return					0.0 on error otherwise flow distance
 * @error					SDK call preparation failed
 */ 
stock float L4D2Direct_GetFlowDistance(int client)
{
	static Handle GetFlowDistanceSDKCall = null;
	if (GetFlowDistanceSDKCall == null)
	{
		StartPrepSDKCall(SDKCall_Player);
		
		if (!PrepSDKCall_SetFromConf(L4D2Direct_GetGameConf(), SDKConf_Signature, "CTerrorPlayer::GetFlowDistance"))
		{
			return 0.0;
		}
		
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
		GetFlowDistanceSDKCall = EndPrepSDKCall();
		
		if (GetFlowDistanceSDKCall == null)
		{
			return 0.0;
		}
	}
	return view_as<float>(SDKCall(GetFlowDistanceSDKCall, client, 0));
}

/**
 * Plays the specified animation for a player
 *
 * @note The event argument is NOT the same as the sequence numbers found in the model viewer
 * @note You can get the number for your animation by looking at the disasm for virtual calls to DoAnimationEvent
 * @param client
 * @param event PlayerAnimEvent_t
 * @noreturn
 */
stock void L4D2Direct_DoAnimationEvent(int client, int event)
{
	if(client <= 0 || client > MaxClients + 1)
	{
		return;
	}
	static Handle DoAnimationEventSDKCall = null;
	if(DoAnimationEventSDKCall == null)
	{
		StartPrepSDKCall(SDKCall_Player);
		if(!PrepSDKCall_SetFromConf(L4D2Direct_GetGameConf(), SDKConf_Virtual, "CTerrorPlayer::DoAnimationEvent"))
		{
			return;
		}
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		DoAnimationEventSDKCall = EndPrepSDKCall();
		
		if(DoAnimationEventSDKCall == null)
		{
			return;
		}
	}
	SDKCall(DoAnimationEventSDKCall, client, event, 0);
}