#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "[INS] Bot explosive damage",
    description = "Increase the explosive damage for bot",
    author = "Neko-",
    version = "1.0.3",
};

new const String:GrenadeName[][] =
{
	"grenade_m67",
	"grenade_f1",
	"grenade_gp25_he"
}

new const String:GrenadeFireName[][] =
{
	"grenade_molotov",
	"grenade_anm14"
}

new const String:RocketName[][] =
{
	"rocket_at4",
	"rocket_rpg7"
}



new Handle:cvarEnabled = INVALID_HANDLE;
new Handle:cvarGrenadeMultiplierAmount = INVALID_HANDLE;
new Handle:cvarFireMultiplierAmount = INVALID_HANDLE;
new Handle:cvarRocketMultiplierAmount = INVALID_HANDLE;

int nGrenadeMultiplierAmount;
int nFireMultiplierAmount;
int nRocketMultiplierAmount;

public OnPluginStart() 
{
	cvarEnabled = CreateConVar("sm_ins_bot_explosive_enabled", "1", "sets whether is bot explosive enable or not", FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvarGrenadeMultiplierAmount = CreateConVar("sm_ins_bot_grenade_multiplier", "1", "the amount of grenade damage multiplier", FCVAR_PROTECTED, true, 1.0, true, 4.0);
	cvarFireMultiplierAmount = CreateConVar("sm_ins_bot_firegrenade_multiplier", "1", "the amount of fire grenade like AN-M14 and Molotov damage multiplier", FCVAR_PROTECTED, true, 1.0, true, 4.0);
	cvarRocketMultiplierAmount = CreateConVar("sm_ins_bot_rocket_multiplier", "1", "the amount of rocket damage multiplier", FCVAR_PROTECTED, true, 1.0, true, 4.0);
	

	AutoExecConfig(true,"ins.bot_explosive_damage");
}

public OnMapStart()
{
	nGrenadeMultiplierAmount = GetConVarInt(cvarGrenadeMultiplierAmount);
	nFireMultiplierAmount = GetConVarInt(cvarFireMultiplierAmount);
	nRocketMultiplierAmount = GetConVarInt(cvarRocketMultiplierAmount);
}

public OnClientPutInServer(client) 
{
	if(GetConVarBool(cvarEnabled) && !IsFakeClient(client))
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(!IsValidClient(attacker) || !IsValidClient(victim))
	{
		return Plugin_Continue;
	}

	decl String:sWeapon[32];
	GetEdictClassname(inflictor, sWeapon, sizeof(sWeapon));
	
	new VictimTeam = GetClientTeam(victim);
	new AttackerTeam = GetClientTeam(attacker);
	
	if(AttackerTeam == VictimTeam)
	{
		return Plugin_Continue;
	}
	
	for (new count=0; count<3; count++)
	{
		if(StrEqual(sWeapon, GrenadeName[count]))
		{
			damage *= nGrenadeMultiplierAmount;
			return Plugin_Changed;
		}
	}
	
	for (new count=0; count<2; count++)
	{
		if(StrEqual(sWeapon, GrenadeFireName[count]))
		{
			damage *= nFireMultiplierAmount;
			return Plugin_Changed;
		}
	}
	
	for (new count=0; count<2; count++)
	{
		if(StrEqual(sWeapon, RocketName[count]))
		{
			damage *= nRocketMultiplierAmount;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

bool:IsValidClient(client) 
{
	if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
		return false; 
	
	return true; 
}  