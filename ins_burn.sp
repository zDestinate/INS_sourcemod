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
    version = "1.0.0",
};

int g_iPlayerEquipGear;
int nArmorFireResistance = 8;

public OnPluginStart()
{
	g_iPlayerEquipGear = FindSendPropInfo("CINSPlayer", "m_EquippedGear");
	
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
}

/*
public OnMapStart()
{
	CreateTimer(1.0, Timer_SpreadBurn,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}
*/

public OnGameFrame(){
	for(int nPlayer = 1; nPlayer <= MaxClients; nPlayer++)
	{
		if(IsClientInGame(nPlayer) && IsPlayerAlive(nPlayer))
		{
			CheckSpreadBurn(nPlayer);
		}
	}
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
	//int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	decl String:weaponCheck[64];
	GetEventString(event, "weapon", weaponCheck, sizeof(weaponCheck)); 
	if(StrEqual(weaponCheck, "entityflame", false))
	{
		//Rename [entityflame] to [Flame] for the top right (Killfeed)
		SetEventString(event, "weapon", "Flame");
	}
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));	
	
	//Get player ArmorID
	int nArmorItemID = GetEntData(client, g_iPlayerEquipGear);
	
	//Get weapon name
	decl String:sWeapon[32];
	GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));
	
	//If player don't have fire resistance armor and get hurt by those weapon then burn the player
	//If you're running this plugin and don't have FireResistance armor then remove that Armor check in the if statement
	//If you have more custom fire weapon then add it in here to have those weapon trigger the burn on players
	if((nArmorItemID != nArmorFireResistance) && ((StrEqual(sWeapon, "grenade_molotov")) || (StrEqual(sWeapon, "grenade_anm14")) || (StrEqual(sWeapon, "grenade_m203_incid")) || (StrEqual(sWeapon, "grenade_gp25_incid"))))
	{
		//DisplayInstructorHint(client, 5.0, 0.0, 0.0, true, false, "icon_tip", "icon_tip", "", true, {255, 255, 255}, "You're burning! Drop and roll to remove the fire!"); 
		IgniteEntity(client, 7.0);
	}
	
	return Plugin_Continue; 
}

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype)
{
	//Get weapon name
	decl String:sWeapon[32];
	GetEdictClassname(inflictor, sWeapon, sizeof(sWeapon));
	
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
		if(IsClientInGame(nPlayer) && IsPlayerAlive(nPlayer))
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
					//DisplayInstructorHint(nPlayerTarget, 5.0, 0.0, 0.0, true, false, "icon_tip", "icon_tip", "", true, {255, 255, 255}, "You're burning! Drop and roll to remove the fire!"); 
					IgniteEntity(nPlayerTarget, 7.0);
				}
			}
		}
	}
	
	return Plugin_Continue;
}

stock void CheckSpreadBurn(const any:client)
{
	int ent = GetEntPropEnt(client, Prop_Data, "m_hEffectEntity");
	if(IsValidEdict(ent))
	{
		for(int nPlayerTarget = 1; nPlayerTarget <= MaxClients; nPlayerTarget++)
		{
			if(!IsClientInGame(nPlayerTarget) || !IsPlayerAlive(nPlayerTarget) || (nPlayerTarget == client))
			{
				continue;
			}
			
			//Get player ArmorID
			int nArmorItemID = GetEntData(nPlayerTarget, g_iPlayerEquipGear);
			if(nArmorItemID == nArmorFireResistance)
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
			
			float fDistance = GetDistance(client, nPlayerTarget);
			if(fDistance <= 95.0)
			{
				//DisplayInstructorHint(nPlayerTarget, 5.0, 0.0, 0.0, true, false, "icon_tip", "icon_tip", "", true, {255, 255, 255}, "You're burning! Drop and roll to remove the fire!"); 
				IgniteEntity(nPlayerTarget, 7.0);
			}
		}
	}
}

float GetDistance(nClient, nTarget)
{
	float fClientOrigin[3], fTargetOrigin[3];
	GetClientAbsOrigin(nClient, fClientOrigin);
	GetClientAbsOrigin(nTarget, fTargetOrigin);
	return GetVectorDistance(fClientOrigin, fTargetOrigin);
}

stock void DisplayInstructorHint(int iTargetEntity, float fTime, float fHeight, float fRange, bool bFollow, bool bShowOffScreen, char[] sIconOnScreen, char[] sIconOffScreen, char[] sCmd, bool bShowTextAlways, int iColor[3], char[] sText)
{
	int iEntity = CreateEntityByName("env_instructor_hint");
	if(iEntity <= 0)
		return;
		
	char sBuffer[32];
	FormatEx(sBuffer, sizeof(sBuffer), "%d", iTargetEntity);
	
	// Target
	DispatchKeyValue(iTargetEntity, "targetname", sBuffer);
	DispatchKeyValue(iEntity, "hint_target", sBuffer);
	
	// Static
	FormatEx(sBuffer, sizeof(sBuffer), "%d", bFollow);
	DispatchKeyValue(iEntity, "hint_static", sBuffer);
	
	// Timeout
	FormatEx(sBuffer, sizeof(sBuffer), "%f", fTime);
	DispatchKeyValue(iEntity, "hint_timeout", sBuffer);
	if(fTime > 0.0)
        RemoveHintTimeout(iEntity, fTime);
	
	// Height
	FormatEx(sBuffer, sizeof(sBuffer), "%f", fHeight);
	DispatchKeyValue(iEntity, "hint_icon_offset", sBuffer);
	
	// Range
	FormatEx(sBuffer, sizeof(sBuffer), "%f", fRange);
	DispatchKeyValue(iEntity, "hint_range", sBuffer);
	
	// Show off screen
	FormatEx(sBuffer, sizeof(sBuffer), "%d", !bShowOffScreen);
	DispatchKeyValue(iEntity, "hint_nooffscreen", sBuffer);
	
	// Icons
	DispatchKeyValue(iEntity, "hint_icon_onscreen", sIconOnScreen);
	DispatchKeyValue(iEntity, "hint_icon_offscreen", sIconOffScreen);
	
	// Command binding
	DispatchKeyValue(iEntity, "hint_binding", sCmd);
	
	// Show text behind walls
	FormatEx(sBuffer, sizeof(sBuffer), "%d", bShowTextAlways);
	DispatchKeyValue(iEntity, "hint_forcecaption", sBuffer);
	
	// Text color
	FormatEx(sBuffer, sizeof(sBuffer), "%d %d %d", iColor[0], iColor[1], iColor[2]);
	DispatchKeyValue(iEntity, "hint_color", sBuffer);
	
	//Text
	ReplaceString(sText, 254, "\n", " ");
	Format(sText, 254, "%s", sText);
	DispatchKeyValue(iEntity, "hint_caption", sText);
	
	DispatchSpawn(iEntity);
	AcceptEntityInput(iEntity, "ShowHint");
}

stock void RemoveHintTimeout(entity, float time = 0.0)
{
    if(time == 0.0)
    {
        if(IsValidEntity(entity))
        {
            char edictname[32];
            GetEdictClassname(entity, edictname, 32);

            if (!StrEqual(edictname, "player"))
                AcceptEntityInput(entity, "kill");
        }
    }
    else if(time > 0.0)
        CreateTimer(time, RemoveHintTimeoutTimer, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

public Action RemoveHintTimeoutTimer(Handle Timer, any entityRef)
{
    int entity = EntRefToEntIndex(entityRef);
    if (entity != INVALID_ENT_REFERENCE)
        RemoveEdict(entity);
    
    return (Plugin_Stop);
}