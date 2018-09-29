#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "[INS] Killfeed",
    description = "Limit the killfeed and make it show only the teammate death",
    author = "Neko-",
    version = "1.0.0",
};

#define SPECTATOR_TEAM	0
#define TEAM_SPEC 		1
#define TEAM_SECURITY	2
#define TEAM_INSURGENTS	3

public OnPluginStart() 
{
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	char szWeaponEventName[64];
	GetEventString(event, "weapon", szWeaponEventName, sizeof(szWeaponEventName));
	if(StrEqual(szWeaponEventName, "Dropped a flare"))
	{
		return Plugin_Continue;
	}
	
	int nAttackerID = GetEventInt(event, "attacker");
	int nAttacker = GetClientOfUserId(nAttackerID);
	
	if(!IsValidClient(nAttacker))
	{
		return Plugin_Continue;
	}
	
	int nAttackerTeam = GetClientTeam(nAttacker);
	
	//If attacker is security team then don't show in the killfeed
	//We don't want them to know if they kill the enemy or not to make it realistic
	if(nAttackerTeam == TEAM_SECURITY)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

bool:IsValidClient(client) 
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}