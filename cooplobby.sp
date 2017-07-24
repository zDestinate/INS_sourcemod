//(C) 2014 Jared Ballou <sourcemod@jballou.com>
//Released under GPLv3

#pragma semicolon 1

#include <sourcemod>
#undef REQUIRE_PLUGIN

#define AUTOLOAD_EXTENSIONS
#define REQUIRE_EXTENSIONS

#define PLUGIN_VERSION "0.0.3"
#define PLUGIN_DESCRIPTION "Plugin for overriding Insurgency Coop max players"

public Plugin:myinfo = {
        name        = "[INS] Coop Lobby Override",
        author      = "Neko- (Jared Ballou (jballou))",
        description = PLUGIN_DESCRIPTION,
        version     = PLUGIN_VERSION,
        url         = "http://jballou.com/"
};

public OnPluginStart()
{
	decl String:folder[64];
	GetGameFolderName(folder, sizeof(folder));
	if (strcmp(folder, "insurgency") == 0)
	{
		HookEvent("server_spawn", Event_GameStart, EventHookMode_Pre);
		HookEvent("game_init", Event_GameStart, EventHookMode_Pre);
		HookEvent("game_start", Event_GameStart, EventHookMode_Pre);
		HookEvent("game_newmap", Event_GameStart, EventHookMode_Pre);
		set_lobbysize();
	}
}


public Event_GameStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	set_lobbysize();
}

public set_lobbysize()
{
	new Handle:cvar;
	cvar = FindConVar("mp_coop_lobbysize");
	SetConVarBounds(cvar,ConVarBound_Upper, true, 18.0);
	SetConVarInt(cvar, 18);
	PrintToServer("Successfully changed lobby size!");
}