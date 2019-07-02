#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "[INS] Protect Cache",
    description = "Protect cache when there's counter attack",
    author = "Neko-",
    version = "1.0.2",
};

enum Teams
{
	TEAM_NONE = 0,
	TEAM_SPECTATORS,
	TEAM_SECURITY,
	TEAM_INSURGENTS,
};

int g_nObjResource;
int g_nCurrentActiveObj;
int g_nTotalObj;
int g_nInsurgentsLockedObj;
int g_nSecurityLockedObj;
int g_nObjectType;

bool g_bLoaded = false;

public OnPluginStart() 
{
	g_nObjResource = FindEntityByClassname(-1, "ins_objective_resource");
	g_nCurrentActiveObj = FindSendPropInfo("CINSObjectiveResource", "m_nActivePushPointIndex");
	g_nTotalObj = FindSendPropInfo("CINSObjectiveResource", "m_iNumControlPoints");
	g_nInsurgentsLockedObj = FindSendPropInfo("CINSObjectiveResource", "m_bInsurgentsLocked");
	g_nSecurityLockedObj = FindSendPropInfo("CINSObjectiveResource", "m_bSecurityLocked");
	g_nObjectType = FindSendPropInfo("CINSObjectiveResource", "m_iObjectType");
	
	//EventHookMode_Pre
	HookEvent("round_start", Event_RoundStart);
	HookEvent("object_destroyed", Event_ObjectDestroyed);
	
	RegAdminCmd("protectcache", CacheInfo, ADMFLAG_KICK, "List cache info");
	
	if(!g_bLoaded)
	{
		CreateTimer(5.0, Timer_Check,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public OnMapStart()
{
	g_bLoaded = false;
	g_nObjResource = FindEntityByClassname(-1, "ins_objective_resource");
	if(!g_bLoaded)
	{
		CreateTimer(5.0, Timer_Check,_ , TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Timer_Check(Handle:Timer)
{
	int acp = GetEntData(g_nObjResource, g_nCurrentActiveObj);
	if(acp < 0) return Plugin_Continue;
	
	int ncp = GetEntData(g_nObjResource, g_nTotalObj);
	if((acp+1) != ncp)
	{
		int nObjType = GetEntData(g_nObjResource, g_nObjectType + (acp * 4));
		
		if(nObjType == 0)
		{
			SetEntData(g_nObjResource, g_nInsurgentsLockedObj + acp, 0, 1);
			SetEntData(g_nObjResource, g_nSecurityLockedObj + acp, 0, 1);
		}
	}
	
	return Plugin_Continue;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	ResetCache();
}

public Action:Event_ObjectDestroyed(Handle:event, const String:name[], bool:dontBroadcast)
{
	int nTeam = GetEventInt(event, "team");
	int nEnt = GetEventInt(event, "index");
	
	if(nTeam == view_as<int>(TEAM_INSURGENTS))
	{
		CreateTimer(1.0, ChangeCacheData, nEnt);
	}
}

public Action ChangeCacheData(Handle timer, any:ent)
{
	SetEntProp(ent, Prop_Data, "m_lifeState", 0);
	SetEntProp(ent, Prop_Data, "m_iTeamNum", TEAM_SECURITY);
	SetEntProp(ent, Prop_Data, "m_takedamage", 2, 1);
	//SetEntProp(ent, Prop_Data, "m_iDamageCount", 0);
	//SetEntProp(ent, Prop_Data, "m_SolidToPlayers", 0);
	
	decl String:sModel[128];
	GetEntPropString(ent, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	
	ReplaceString(sModel, sizeof(sModel), "ins_01_destr", "sec_01");
	SetEntityModel(ent, sModel);
}

public Action:CacheInfo(client, args)
{
	SearchAllCache(client);
	
	return Plugin_Handled;
}

void SearchAllCache(client)
{
	new ent = -1;
	new i = 1;
	while(i == 1)
	{
		ent = FindEntityByClassname(ent,"obj_weapon_cache");
		if(IsValidEntity(ent))
		{
			decl String:strEntName[32];
			GetEntPropString(ent, Prop_Data, "m_iszControlPoint", strEntName, sizeof(strEntName));
			decl String:targetname[64];
			GetEntPropString(ent, Prop_Data, "m_iName", targetname, sizeof(targetname));
			if((strlen(strEntName) > 0) && (strlen(targetname) > 0))
			{
				int nLifeState = GetEntProp(ent, Prop_Data, "m_lifeState");
				int nTeam = GetEntProp(ent, Prop_Data, "m_iTeamNum");
				
				ReplyToCommand(client, "%s %s: %d \nLifeState: %d \nTeam: %d\n", targetname, strEntName, ent, nLifeState, nTeam);
				
				continue;
			}
		}
		i = 0;
	}
}

void ResetCache()
{
	new ent = -1;
	new i = 1;
	while(i == 1)
	{
		ent = FindEntityByClassname(ent,"obj_weapon_cache");
		if(IsValidEntity(ent))
		{
			decl String:strEntName[32];
			GetEntPropString(ent, Prop_Data, "m_iszControlPoint", strEntName, sizeof(strEntName));
			decl String:targetname[64];
			GetEntPropString(ent, Prop_Data, "m_iName", targetname, sizeof(targetname));
			if((strlen(strEntName) > 0) && (strlen(targetname) > 0))
			{
				SetEntProp(ent, Prop_Data, "m_lifeState", 0);
				SetEntProp(ent, Prop_Data, "m_iTeamNum", TEAM_INSURGENTS);
				
				continue;
			}
		}
		i = 0;
	}
}

bool:IsValidClient(client) 
{
	if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
		return false; 
	
	return true; 
}

bool:IsCounterAttack()
{
	bool ret = bool:GameRules_GetProp("m_bCounterAttack");
	return ret;
}