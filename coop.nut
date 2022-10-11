//小手枪替换成马格南
DirectorOptions <-
{
	weaponsToConvert =
	{
		weapon_pistol = "weapon_pistol_magnum_spawn"
	}
	function ConvertWeaponSpawn( classname )
	{
		if ( classname in weaponsToConvert )
		{
			return weaponsToConvert[classname];
		}
		return 0;
	}
	TankHitDamageModifierCoop = 1
}
function OnGameEvent_round_start_post_nav(params)
{
	update_difficulty();
}
function OnGameEvent_difficulty_changed(params)
{
	update_difficulty()
}
function update_difficulty()
{
	local difficulty = Convars.GetStr( "z_difficulty" )
	if (difficulty.tolower() == "easy")
	{
		DirectorOptions.TankHitDamageModifierCoop = 1
	}
	else if (difficulty.tolower() == "normal")
	{
		DirectorOptions.TankHitDamageModifierCoop = 1
	}
	else if (difficulty.tolower() == "hard")
	{
		DirectorOptions.TankHitDamageModifierCoop = 0.728
	}
	else if (difficulty.tolower() == "impossible")
	{
		DirectorOptions.TankHitDamageModifierCoop = 0.41
	}
}
