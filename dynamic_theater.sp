//----------------------------------------------------
//	Dynamic theater for [INS]
//	Put "exec theatertype.cfg" in bottom of server.cfg
//	This plugin will edit the theatertype.cfg to run the right theater file
//	Each time the server load or change map will run server.cfg but with theatertype.cfg execute
//----------------------------------------------------

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

//int nDynamicTheater;
bool bAllowVoteTheater = true;
bool bVoteStart = false;
int nVoteYes = 0;
int nVoteNo = 0;
new bool:g_bPlayerCanVote[MAXPLAYERS+1] = {true, ...};
//bool bNeedReload = false;

public Plugin:myinfo = {
    name = "[INS] Dynamic Theater File",
    description = "Dynamically change theater file in game",
    author = "Neko-",
    version = "1.2.0",
}

public OnPluginStart() 
{
	RegConsoleCmd("votetheater", Vote_Theater, "Vote theater for next map");
	RegConsoleCmd("yes", Vote_Yes, "Vote yes for next map theater change");
	RegConsoleCmd("no", Vote_No, "Vote no for next map theater change");
	
	//Admin command
	//Admin can set theater right away
	RegAdminCmd("settheater", SetDynamicTheater, ADMFLAG_KICK, "Set dynamic theater type");
} 

public Action:SetDynamicTheater(client, args)
{
	if (args < 1)
    {
		PrintToChat(client, "[DTheater] Usage: !dtheater <args>");
		return Plugin_Handled;
    }
	
	decl String:Message[255];
	GetCmdArgString(Message, 255);
	
	decl String:NickName[64];
	GetClientName(client, NickName, sizeof(NickName));
	
	if(StrContains(Message, "sniper") != -1)
	{
		DynamicTheater(1);
		PrintToChatAll("\x0759b0f9[INS]\x01 %s has set starting next map to use sniper theater", NickName);
		//bNeedReload = true;
	}
	else if(StrContains(Message, "nospy") != -1)
	{
		DynamicTheater(2);
		PrintToChatAll("\x0759b0f9[INS]\x01 %s has set starting next map to use no spy theater with no indicator", NickName);
		//bNeedReload = true;
	}
	else if(StrContains(Message, "ins") != -1)
	{
		DynamicTheater(3);
		PrintToChatAll("\x0759b0f9[INS]\x01 %s has set starting next map to use insurgent theater (Play as insurgent)", NickName);
		//bNeedReload = true;
	}
	else
	{
		DynamicTheater(0);
		PrintToChatAll("\x0759b0f9[INS]\x01 %s has set starting next map to use normal theater", NickName);
		//bNeedReload = true;
	}
	return Plugin_Handled;
}

public OnMapEnd()
{
	bAllowVoteTheater = true;
	bVoteStart = false;
	nVoteYes = 0;
	nVoteNo = 0;
}

public OnClientPostAdminCheck(client)
{
	g_bPlayerCanVote[client] = true;
}

public OnClientDisconnect(client)
{
	g_bPlayerCanVote[client] = true;
}

public DynamicTheater(nTheaterType)
{
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM,path,PLATFORM_MAX_PATH,"../../cfg/theatertype.cfg");
	new Handle:fileHandle=OpenFile(path,"wb");
	
	if(nTheaterType == 1)
	{
		WriteFileLine(fileHandle, "mp_theater_override ins_custom_hardcore_sniper");
	}
	else if(nTheaterType == 2)
	{
		WriteFileLine(fileHandle, "mp_theater_override ins_custom_hardcore_nospy");
		WriteFileLine(fileHandle, "sv_hud_targetindicator 0");
	}
	else if(nTheaterType == 3)
	{
		WriteFileLine(fileHandle, "mp_theater_override ins_switch_team_custom_hardcore");
	}
	else
	{
		WriteFileLine(fileHandle, "mp_theater_override ins_custom_hardcore");
	}
	CloseHandle(fileHandle);
	
	// ConVar hTheaterOverride = FindConVar("mp_theater_override");
	// ConVar cvarIndicator = FindConVar("sv_hud_targetindicator");
	
	// if(nDynamicTheater == 1)
	// {
		// //ServerCommand("mp_theater_override ins_custom_hardcore_sniper");
		// SetConVarString(hTheaterOverride, "ins_custom_hardcore_sniper");
	// }
	// else if(nDynamicTheater == 2)
	// {
		// //ServerCommand("mp_theater_override ins_custom_hardcore_nospy");
		// SetConVarString(hTheaterOverride, "ins_custom_hardcore_nospy");
		// SetConVarInt(cvarIndicator, 0);
	// }
	// else
	// {
		// //ServerCommand("mp_theater_override ins_custom_hardcore");
		// SetConVarString(hTheaterOverride, "ins_custom_hardcore");
	// }
	
	
	//nDynamicTheater = 0;
}

public Action ReloadMapCheck(Handle timer)
{
	decl String:sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
	decl String:sMapName[128];
	GetCurrentMap(sMapName, sizeof(sMapName));
	ServerCommand("map %s %s", sMapName, sGameMode);
	//bNeedReload = false;
}

public Action:Vote_Theater(client,args)
{
	if (args < 1)
    {
		PrintToChat(client, "[DTheater] Usage: !votetheater <type>");
		return Plugin_Handled;
    }
	
	if(!bAllowVoteTheater)
	{
		PrintToChat(client, "A vote already start");
		return Plugin_Handled;
	}
	
	decl String:Message[255];
	GetCmdArgString(Message, 255);
	decl String:NickName[64];
	GetClientName(client, NickName, sizeof(NickName));
	
	if(StrContains(Message, "sniper") != -1)
	{
		bAllowVoteTheater = false;
		bVoteStart = true;
		PrintToChatAll("\x0759b0f9[INS]\x01 %s has started a vote to use sniper theater starting next map\nUse /yes and /no to vote", NickName);
		CreateTimer(25.0, Timer_VoteTheater, 1, TIMER_FLAG_NO_MAPCHANGE);
	}
	else if(StrContains(Message, "nospy") != -1)
	{
		bAllowVoteTheater = false;
		bVoteStart = true;
		PrintToChatAll("\x0759b0f9[INS]\x01 %s has started a vote to use no spy theater and no indicator starting next map\nUse /yes and /no to vote", NickName);
		CreateTimer(25.0, Timer_VoteTheater, 2, TIMER_FLAG_NO_MAPCHANGE);
	}
	else if(StrContains(Message, "ins") != -1)
	{
		bAllowVoteTheater = false;
		bVoteStart = true;
		PrintToChatAll("\x0759b0f9[INS]\x01 %s has started a vote to use insurgent theater (Play as insurgent) starting next map\nUse /yes and /no to vote", NickName);
		CreateTimer(25.0, Timer_VoteTheater, 3, TIMER_FLAG_NO_MAPCHANGE);
	}
	else if(StrContains(Message, "normal") != -1)
	{
		bAllowVoteTheater = false;
		bVoteStart = true;
		PrintToChatAll("\x0759b0f9[INS]\x01 %s has started a vote to use normal theater starting next map\nUse /yes and /no to vote", NickName);
		CreateTimer(25.0, Timer_VoteTheater, 0, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		PrintToChat(client, "[DTheater] Invalid theater. Please use normal, ins, nospy, or sniper");
	}
	
	return Plugin_Handled;
}

public Action Timer_VoteTheater(Handle timer, nTheaterType)
{
	if(nVoteYes > nVoteNo)
	{
		PrintToChatAll("\x0759b0f9[INS]\x01 Vote success! Theater will be change starting next map\nYes: %d\nNo: %d", nVoteYes, nVoteNo);
		DynamicTheater(nTheaterType);
		//bNeedReload = true;
	}
	else
	{
		PrintToChatAll("\x0759b0f9[INS]\x01 Vote failed! Theater will not change\nYes: %d\nNo: %d", nVoteYes, nVoteNo);
	}
	
	//reset
	bVoteStart = false;
	bAllowVoteTheater = true;
	nVoteYes = 0;
	nVoteNo = 0;
	
	for(new i = 1; i <= MaxClients; i++)
	{
		g_bPlayerCanVote[i] = true;
	}
}

public Action:Vote_Yes(client,args)
{
	if((bVoteStart) && (g_bPlayerCanVote[client]))
	{
		g_bPlayerCanVote[client] = false;
		nVoteYes++;
		PrintToChat(client, "You voted yes");
	}
	else if((bVoteStart) && (!g_bPlayerCanVote[client]))
	{
		PrintToChat(client, "You already voted");
	}
	else
	{
		return Plugin_Stop;
	}
	
	return Plugin_Handled;
}

public Action:Vote_No(client,args)
{
	if((bVoteStart) && (g_bPlayerCanVote[client]))
	{
		g_bPlayerCanVote[client] = false;
		nVoteNo++;
		PrintToChat(client, "You voted no");
		return Plugin_Handled;
	}
	else if((bVoteStart) && (!g_bPlayerCanVote[client]))
	{
		PrintToChat(client, "You already voted");
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Stop;
	}
}

bool:IsValidClient(client) 
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}