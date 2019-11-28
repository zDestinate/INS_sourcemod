/*-------------------------------------

	This plugin is to ignite the player when they taking fire damage
	The fire damage stack up the longer the player in the fire
	They will have to prone to remove all fire on them
	
---------------------------------------*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "[INS] Burn",
    description = "Ignite player when player taking fire damage",
    author = "Neko-",
    version = "1.0.5",
};

enum Teams
{
	TEAM_NONE = 0,
	TEAM_SPECTATORS,
	TEAM_SECURITY,
	TEAM_INSURGENTS,
};

int g_iPlayerEquipGear;
int nArmorFireResistance = 8;
int nFireAmmoID = 114;

public OnPluginStart()
{
	g_iPlayerEquipGear = FindSendPropInfo("CINSPlayer", "m_EquippedGear");
	
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
}

public OnMapStart()
{
	CreateTimer(1.0, Timer_SpreadBurn,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public OnClientPutInServer(client)
{
	//Hook damage taken to change the damage it deals
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &nSubType, &nCmdNum, &nTickCount, &nSeed) 
{
	if(IsPlayerAlive(client))
	{
		//Get player stance
		int nStance = GetEntProp(client, Prop_Send, "m_iCurrentStance");
		
		//nStance = 2 (Prone)
		if(nStance == 2)
		{
			//Remove all fire
			int ent = GetEntPropEnt(client, Prop_Data, "m_hEffectEntity");
			if(IsValidEdict(ent))
			{
				//Reset to 0.0 to remove all fire
				SetEntPropFloat(ent, Prop_Data, "m_flLifetime", 0.0);  
			}
		}
	}
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	decl String:weaponCheck[64];
	GetEventString(event, "weapon", weaponCheck, sizeof(weaponCheck)); 
	if(StrEqual(weaponCheck, "entityflame", false))
	{
		//Rename [entityflame] to [Flame] for the top right (Killfeed)
		SetEventString(event, "weapon", "Flame");
	}
	
	//Remove fire when player dead
	int ent = GetEntPropEnt(client, Prop_Data, "m_hEffectEntity");
	if(IsValidEdict(ent))
	{
		SetEntPropFloat(ent, Prop_Data, "m_flLifetime", 0.0);  
	}
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));	
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	//Get player ArmorID
	int nArmorItemID = GetEntData(client, g_iPlayerEquipGear);
	if(nArmorItemID == nArmorFireResistance)
	{
		return Plugin_Continue;
	}
	
	decl String:sWeapon[32];
	GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));
	
	//If player don't have fire resistance armor and get hurt by those weapon then burn the player
	//If you're running this plugin and don't have FireResistance armor then remove that Armor check in the if statement
	//If you have more custom fire weapon then add it in here to have those weapon trigger the burn on players
	if((StrEqual(sWeapon, "grenade_molotov")) || (StrEqual(sWeapon, "grenade_anm14")) || (StrEqual(sWeapon, "grenade_m203_incid")) || (StrEqual(sWeapon, "grenade_gp25_incid")))
	{
		IgniteEntity(client, 7.0);
	}
	
	//=============================
	//FIRE AMMO SECTION (START)
	//Remove this section if you are not using fire ammo
	//=============================
	
	//Get weapon ID
	int AttackerWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
	if(AttackerWeapon < 0)
	{
		return Plugin_Continue;
	}
	
	//Get weapon upgrades
	int m_hUpgradeSlotOffset = GetEntSendPropOffs(AttackerWeapon, "m_upgradeSlots", true);
	
	if(m_hUpgradeSlotOffset != -1)
    {
		for(int i = 0; i < (4*8); i += 4)
		{
			int nWeaponUpgradeID = GetEntData(AttackerWeapon, m_hUpgradeSlotOffset + i);

			//Burn player if there is fire ammo
			if(nWeaponUpgradeID == nFireAmmoID)
			{
				IgniteEntity(client, 5.0);
			}
		}
	}
	//=============================
	//FIRE AMMO SECTION (END)
	//=============================
	
	return Plugin_Continue; 
}

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype)
{
	//Get weapon name
	decl String:sWeapon[32];
	GetEdictClassname(inflictor, sWeapon, sizeof(sWeapon));
	
	if(GetEntPropEnt(client, Prop_Send, "m_hEffectEntity") <= 0 && StrEqual(sWeapon, "entityflame"))
	{
		return Plugin_Handled;
	}
	
	if(StrEqual(sWeapon, "entityflame"))
	{
		//Per fire damage (This damage stack up if player have more than 1 fire on them)
		damage = 0.5;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action:Timer_SpreadBurn(Handle:Timer)
{
	for(int nPlayer = 1; nPlayer <= MaxClients; nPlayer++)
	{
		if(IsClientInGame(nPlayer) && IsPlayerAlive(nPlayer) && (GetClientTeam(nPlayer) != view_as<int>(TEAM_SPECTATORS)))
		{
			int ent = GetEntPropEnt(nPlayer, Prop_Data, "m_hEffectEntity");
			if(!IsValidEdict(ent))
			{
				continue;
			}
				
			for(int nPlayerTarget = 1; nPlayerTarget <= MaxClients; nPlayerTarget++)
			{
				if(!IsClientInGame(nPlayerTarget) || !IsPlayerAlive(nPlayerTarget) || (nPlayerTarget == nPlayer))
				{
					continue;
				}
				
				//Get player ArmorID
				int nArmorItemID = GetEntData(nPlayerTarget, g_iPlayerEquipGear);
				if(nArmorItemID == nArmorFireResistance)
				{
					continue;
				}
				
				//Get player stance
				int nStance = GetEntProp(nPlayerTarget, Prop_Send, "m_iCurrentStance");
				//nStance = 2 (Prone)
				if(nStance == 2)
				{
					continue;
				}
				
				//Already on fire
				/*
				int entTarget = GetEntPropEnt(nPlayerTarget, Prop_Data, "m_hEffectEntity");
				if(IsValidEdict(entTarget))
				{
					continue;
				}
				*/
				
				float fDistance = GetDistance(nPlayer, nPlayerTarget);
				if(fDistance <= 95.0)
				{
					IgniteEntity(nPlayerTarget, 7.0);
				}
			}
		}
	}
	
	return Plugin_Continue
}

float GetDistance(nClient, nTarget)
{
	float fClientOrigin[3], fTargetOrigin[3];
	GetClientAbsOrigin(nClient, fClientOrigin);
	GetClientAbsOrigin(nTarget, fTargetOrigin);
	return GetVectorDistance(fClientOrigin, fTargetOrigin);
}
