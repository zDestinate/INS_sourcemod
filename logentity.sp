#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "[INS]",
    description = "List entity classnames",
    author = "Neko-",
    version = "1.0.0",
};

public OnPluginStart() 
{
	RegAdminCmd("logentity", LogEntity, ADMFLAG_KICK, "Test stuff");
}

public Action:LogEntity(client, args)
{
	new String:strClassName[32];
	
	new String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "logs/entities.log");
	new Handle:file = OpenFile(path, "w+");
	WriteFileLine(file, "==== Entity List ====");
	
	for(new i=0;i<= GetMaxEntities() ;i++){
		if(!IsValidEntity(i))
			continue;
		if(GetEdictClassname(i, strClassName, sizeof(strClassName))){
			decl String:strEntityName[128];
			GetEntPropString(i, Prop_Data, "m_iName", strEntityName, sizeof(strEntityName));
			
			if(FindDataMapInfo(i, "m_bDisabled") != -1)
			{
				int nValue = GetEntProp(i, Prop_Data, "m_bDisabled");
				WriteFileLine(file, "%s : %s : %d", strClassName, strEntityName, nValue);
			}
			else
			{
				WriteFileLine(file, "%s : %s", strClassName, strEntityName);
			}
		}
	}

	FlushFile(file);
	CloseHandle(file);
	
	return Plugin_Handled;
}