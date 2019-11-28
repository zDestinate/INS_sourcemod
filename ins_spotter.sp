#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "[INS] Spotter Perk",
    description = "Spotter perk",
    author = "Neko-",
    version = "1.0.1",
};

new g_iPlayerEquipGear;
int g_nSpotterID = 29;
new bool:g_nPlayerCanBeMark[MAXPLAYERS+1] = {true, ...};

public OnPluginStart()
{
	//Find player gear offset
	g_iPlayerEquipGear = FindSendPropInfo("CINSPlayer", "m_EquippedGear");
	
	HookEvent("player_pick_squad", Event_PlayerPickSquad_Post, EventHookMode_Post);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &nSubType, &nCmdNum, &nTickCount, &nSeed)
{
	if((!IsFakeClient(client)) && (IsPlayerAlive(client)))
	{
		int nSpotterItemID = GetEntData(client, g_iPlayerEquipGear + (4 * 4));
		if(nSpotterItemID == g_nSpotterID)
		{
			int nTargetView = getClientViewClient(client);
			int nTargetAim = GetClientAimTarget(client, true);
			if((nTargetView == nTargetAim) && (GetClientTeam(client) != GetClientTeam(nTargetAim)) && (IsPlayerAlive(nTargetAim)) && (g_nPlayerCanBeMark[nTargetAim]))
			{
				int nValue = GetEntProp(nTargetAim, Prop_Send, "m_bGlowEnabled");
				if(!nValue)
				{
					SetEntProp(nTargetAim, Prop_Send, "m_bGlowEnabled", true);
					CreateTimer(3.0, Timer_RemoveGlowTarget, nTargetAim);
				}
			}
		}
	}
}

public OnClientPostAdminCheck(client)
{
	g_nPlayerCanBeMark[client] = true;
}

public OnClientDisconnect(client)
{
	g_nPlayerCanBeMark[client] = true;
}

public Event_PlayerPickSquad_Post(Handle:event, const String:name[], bool:dontBroadcast )
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	decl String:class_template[64];
	GetEventString(event, "class_template",class_template,sizeof(class_template));
	
	//Bot class imposter (To prevent bot with this class from getting mark)
	if(StrContains(class_template, "imposter") > -1)
	{
		g_nPlayerCanBeMark[client] = false;
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
