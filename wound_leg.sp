#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "[INS] Wound Legs",
    description = "If get shot in leg will prone",
    author = "Neko-",
    version = "1.0.0",
};

public OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int hitgroup = GetEventInt(event, "hitgroup");
	
	int nTakeDamage = GetEntProp(client, Prop_Data, "m_takedamage");
	if (nTakeDamage == 1)
	{
		return Plugin_Continue;
	}
	
	int health = GetClientHealth(client);
	if((health > 0) && (hitgroup == 6 || hitgroup == 7))
	{
		SetEntProp(client, Prop_Send, "m_iCurrentStance", 2);
	}
	
	return Plugin_Continue;
}