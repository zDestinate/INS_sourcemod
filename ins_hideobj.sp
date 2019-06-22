#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "[INS] Hide Objective",
    description = "Hide the next objective until all enemies are killed",
    author = "Neko-",
    version = "1.0.0",
};

int g_nObjResource;
int g_nCurrentActiveObj;
int g_nTotalObj;
int g_nSecurityLockedObj;
bool g_bLoaded = false;

public OnPluginStart() 
{
	g_nObjResource = FindEntityByClassname(-1, "ins_objective_resource");
	g_nCurrentActiveObj = FindSendPropInfo("CINSObjectiveResource", "m_nActivePushPointIndex");
	g_nTotalObj = FindSendPropInfo("CINSObjectiveResource", "m_iNumControlPoints");
	g_nSecurityLockedObj = FindSendPropInfo("CINSObjectiveResource", "m_bSecurityLocked");
	
	RegAdminCmd("listobj", Listobj, ADMFLAG_KICK, "List all the obj");
	RegAdminCmd("showobj", Showobj, ADMFLAG_KICK, "Show the next obj");
	RegAdminCmd("hideobj", Hideobj, ADMFLAG_KICK, "Hide the next obj");
	
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

public Action:Listobj(client, args)
{
	int ncp = GetEntData(g_nObjResource, g_nTotalObj);
	for(int i = 0; i < ncp; i++)
	{
		int nLocked = GetEntData(g_nObjResource, g_nSecurityLockedObj + i, 1);
		ReplyToCommand(client, "ACP[%d]: %d", i, nLocked);
	}
	
	return Plugin_Handled;
}

public Action:Hideobj(client, args)
{
	int acp = GetEntData(g_nObjResource, g_nCurrentActiveObj);
	SetEntData(g_nObjResource, g_nSecurityLockedObj + acp, 1, 1);
	
	ReplyToCommand(client, "Objective %d is hidden", acp);
	
	return Plugin_Handled;
}

public Action:Showobj(client, args)
{
	int acp = GetEntData(g_nObjResource, g_nCurrentActiveObj);
	SetEntData(g_nObjResource, g_nSecurityLockedObj + acp, 0, 1);
	
	ReplyToCommand(client, "Objective %d is show", acp);
	
	return Plugin_Handled;
}

public Action:Timer_Check(Handle:Timer)
{
	int acp = GetEntData(g_nObjResource, g_nCurrentActiveObj);
	if(acp < 0) return Plugin_Continue;
	
	//int SecurityLockedObj = GetEntData(g_nObjResource, g_nSecurityLockedObj + acp, 1);
	
	if(IsCounterAttack())
	{
		SetEntData(g_nObjResource, g_nSecurityLockedObj + acp, 0, 1);
		return Plugin_Continue;
	}
	else
	{
		int nTotalInsurgents;
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && IsFakeClient(i))
			{
				nTotalInsurgents++;
			}
		}
		
		if(nTotalInsurgents <= 2)
		{
			SetEntData(g_nObjResource, g_nSecurityLockedObj + acp, 0, 1);
		}
		else
		{
			SetEntData(g_nObjResource, g_nSecurityLockedObj + acp, 1, 1);
		}
	}
	
	return Plugin_Continue;
}

bool:IsCounterAttack()
{
	bool ret = bool:GameRules_GetProp("m_bCounterAttack");
	return ret;
}