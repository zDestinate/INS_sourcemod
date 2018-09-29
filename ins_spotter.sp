#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "[INS] Spotter Perk",
    description = "Spotter perk",
    author = "Neko-",
    version = "1.0.0",
};

new g_iPlayerEquipGear;
int g_nSpotterID = 29;

public OnPluginStart()
{
	//Find player gear offset
	g_iPlayerEquipGear = FindSendPropInfo("CINSPlayer", "m_EquippedGear");
}

public OnMapStart()
{
	CreateTimer(3.0, Timer_MapStart);
}

public Action:Timer_MapStart(Handle:Timer)
{
	CreateTimer(1.0, Timer_CheckTargetSpot, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_CheckTargetSpot(Handle:Timer)
{
	for(int i = 1; i < MaxClients; i++)
	{
		if(IsValidClient(i) && (!IsFakeClient(i)) && (IsPlayerAlive(i)))
		{
			int nSpotterItemID = GetEntData(i, g_iPlayerEquipGear + (4 * 4));
			if(nSpotterItemID == g_nSpotterID)
			{
				int nTargetView = getClientViewClient(i);
				int nTargetAim = GetClientAimTarget(i, true);
				if((nTargetView == nTargetAim) && (GetClientTeam(i) != GetClientTeam(nTargetAim)) && (IsPlayerAlive(nTargetAim)))
				{
					int nValue = GetEntProp(nTargetAim, Prop_Send, "m_bGlowEnabled");
					if(!nValue)
					{
						SetEntProp(nTargetAim, Prop_Send, "m_bGlowEnabled", true);
						CreateTimer(8.0, Timer_RemoveGlowTarget, nTargetAim);
					}
				}
			}
			
		}
	}
}

public Action:Timer_RemoveGlowTarget(Handle:Timer, any client)
{
	int nValue = GetEntProp(client, Prop_Send, "m_bGlowEnabled");
	if(IsValidClient(client) && IsPlayerAlive(client) && (nValue))
	{
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", false);
	}
	
}

stock int getClientViewClient(int client) {
	float m_vecOrigin[3];
	float m_angRotation[3];
	GetClientEyePosition(client, m_vecOrigin);
	GetClientEyeAngles(client, m_angRotation);
	Handle tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_VISIBLE, RayType_Infinite, TraceEntityFilter:FilterOutPlayer, client);
	int pEntity = -1;
	if (TR_DidHit(tr)) {
		pEntity = TR_GetEntityIndex(tr);
		delete tr;
		if (!IsValidClient(client))
			return -1;
		if (!IsValidEntity(pEntity))
			return -1;
		float playerPos[3];
		float entPos[3];
		GetClientAbsOrigin(client, playerPos);
		GetEntPropVector(pEntity, Prop_Data, "m_vecOrigin", entPos);
		return pEntity;
	}
	delete tr;
	return -1;
}

public bool:FilterOutPlayer(entity, contentsMask, any:data)
{
    if (entity == data)
    {
        return false;
    }
    
    return true;
}

bool:IsValidClient(client) 
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}