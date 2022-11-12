/*
	Thanks go to coleo for his gracious help and endless patience while helping me learn 
	the ins and outs of SourceMod.
*/

#include <sourcemod>

#define EASY "Easy"
#define NORMAL "Normal"
#define ADVANCED "Hard"
#define EXPERT "Impossible"

public Plugin myinfo =
{
	name = "[L4D2] Too Easy",
	author = "Distemper",
	description = "Makes sure people are playing the official maps at harder difficulties.",
	version = "1.0",
	url = "https://github.com/nuviktor/sm-l4d2-tooeasy"
};

ConVar cvDifficulty;
ConVar cvGamemode;

bool wasTooEasy;

static bool IsOfficialMap() {
	char currentMap[32];
	char map[6];

	GetCurrentMap(currentMap, sizeof(currentMap));

	for (int i = 1; i <= 13; i++) {
		Format(map, sizeof(map), "c%im", i);
		if (StrContains(currentMap, map, true) == 0)
			return true;
	}

	return false;
}

static bool IsCoop() {
	char gamemode[16];

	cvGamemode.GetString(gamemode, sizeof(gamemode));

	return StrEqual(gamemode, "coop");
}

static bool IsTooEasy() {
	bool isEasy;
	char difficulty[16];

	cvDifficulty.GetString(difficulty, sizeof(difficulty));
	isEasy = StrEqual(difficulty, EASY);

	return (IsCoop() && IsOfficialMap() && isEasy);
}

static bool AnyHumanPlayers() {
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && (! IsFakeClient(i)))
			return true;

	return false;
}

static void MakeItHard() {
	PrintToServer("[Too Easy] Setting difficulty to normal");
	cvDifficulty.SetString(NORMAL);
}

public void Event_PlayerActivate(Event event, const char[] name, bool dontBroadcast) {
	int player = GetClientOfUserId(event.GetInt("userid"));

	// Print a helpful message if the difficulty was forcibly changed at the beginning of the map.
	if (wasTooEasy)
		PrintToChat(player, "[难度管理]服务器禁止简单难度，已自动变更为普通难度");
}

public void OnDifficultyChange(ConVar convar, char[] oldValue, char[] newValue) {
	// Check if any human players are on the server which suggests the difficulty was voted down.
	if (AnyHumanPlayers() && IsTooEasy()) {
		MakeItHard();
		PrintToChatAll("[难度管理]服务器禁止简单难度，已自动变更为普通难度");
	}
}

public void OnPluginStart() {
	cvDifficulty = FindConVar("z_difficulty");
	cvGamemode = FindConVar("mp_gamemode");

	cvDifficulty.AddChangeHook(OnDifficultyChange);

	HookEvent("player_activate", Event_PlayerActivate);
}

public void OnMapStart() {
	wasTooEasy = false;

	if (IsTooEasy()) {
		MakeItHard();
		wasTooEasy = true;
	}
}
