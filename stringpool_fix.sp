#include <sourcemod>

public Plugin myinfo = 
{
	name = "Stringpool Fix",
	author = "ekshon & ZooL",
	description = "Fixes stringpool not emptying and causing a crash with the message: CUtlRBTree overflow! - This will delay it.",
	version = "1.0.0",
	url = "https://forums.alliedmods.net/showthread.php?t=328421"
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(HasEntProp(entity, Prop_Data, "m_bForcePurgeFixedupStrings"))
    SetEntProp(entity, Prop_Data, "m_bForcePurgeFixedupStrings", true);
}