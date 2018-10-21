#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "[INS] Flare and VIP",
    description = "Flare respawn and VIP class",
    author = "Neko-",
    version = "1.0.3",
};

#define SPECTATOR_TEAM	0
#define TEAM_SPEC 		1
#define TEAM_SECURITY	2
#define TEAM_INSURGENTS	3

#define MAXENTITIES 2048
new g_nGlowingEntity[MAXENTITIES+1] = {-1, ...}

new Handle:g_hForceRespawn;
new Handle:g_hGameConfig;
bool g_nFlareFiredActivated = false;
new bool:g_nPlayer[MAXPLAYERS+1] = {false, ...};
new bool:g_bPlayerRespawn[MAXPLAYERS+1] = {true, ...};
new nShooterID;
new g_nVIP_ID = 0;
new g_nRoundStatus = 0;
new bool:g_bVIP_Alive = false;
new bool:g_TimerRunning = false;
int g_nVIP_Kills = 0;
int g_nVIP_TotalKills = 0;
int g_nVIP_TotalKillsTemp;
int g_nSignaller_ID = 0;
new m_hMyWeapons;
int g_nFlareCost = 0;
int g_nFlareCostCounter = 0;


public OnPluginStart() 
{
	RegConsoleCmd("vip", Cmd_VIP, "Check more VIP info");
	RegConsoleCmd("givesupplypoint", Cmd_GiveSupply, "Give the current playing you looking a supply point");
	RegConsoleCmd("getflare", Cmd_GetFlare, "Exchange supply point for flare");
	
	HookEvent("weapon_fire", WeaponFireEvents, EventHookMode_Pre);
	HookEvent("player_pick_squad", Event_PlayerPickSquad_Post, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerRespawnPre, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", OnPlayerTeam);
	HookEvent("controlpoint_captured", Event_ControlPointCaptured);
	
	AddCommandListener(RespawnPlayerAllowCheckListener, "kill");
	
	m_hMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons");
	
	StartPrepSDKCall(SDKCall_Player);
	g_hGameConfig = LoadGameConfigFile("insurgency.games");
	PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Signature, "ForceRespawn");
	g_hForceRespawn = EndPrepSDKCall();
	if (g_hForceRespawn == INVALID_HANDLE)
	{
		SetFailState("Fatal Error: Unable to find signature for \"ForceRespawn\"!");
	}
}

public void OnMapEnd() {
	g_nVIP_ID = 0;
	g_nRoundStatus = 0;
	g_bVIP_Alive = false;
	g_TimerRunning = false;
	g_nVIP_Kills = 0;
	g_nSignaller_ID = 0;
	g_nFlareCost = 0;
	g_nFlareCostCounter = 0;
}

public OnClientPostAdminCheck(client)
{
	g_nPlayer[client] = false;
	g_bPlayerRespawn[client] = true;
}

public OnClientDisconnect(client)
{
	g_nPlayer[client] = false;
	g_bPlayerRespawn[client] = true;
	if(client == g_nVIP_ID)
	{
		g_nVIP_ID = 0;
	}
	
	if(client == g_nSignaller_ID)
	{
		g_nSignaller_ID = 0;
	}
}

public OnClientPutInServer(client) 
{
	if(!IsFakeClient(client))
	{
		SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
	}
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
}

public Action:OnWeaponEquip(client, weapon)
{
	if((g_nGlowingEntity[weapon] != -1) && (IsValidEdict(g_nGlowingEntity[weapon])))
	{
		//RemoveEdict(g_nGlowingEntity[weapon]);
		AcceptEntityInput(g_nGlowingEntity[weapon], "kill");
		g_nGlowingEntity[weapon] = -1;
	}
}

public Action:OnWeaponDrop(client, weapon)
{
	decl String:UserWeaponClass[64];
	GetEdictClassname(weapon, UserWeaponClass, sizeof(UserWeaponClass));
	
	if(IsValidEntity(weapon) && (StrEqual(UserWeaponClass, "weapon_p2a1")))
	{
		CreateTimer(0.0, AddGlow, weapon);
	}
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_nRoundStatus = 1;
	g_nVIP_Kills = 0;
	g_nFlareCost = 0;
	g_nFlareCostCounter = 0;
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_nRoundStatus = 0;
	g_bVIP_Alive = false;
}

public Action:Event_ControlPointCaptured(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:strCapper[256];
	GetEventString(event, "cappers", strCapper, sizeof(strCapper));
	for (new i = 0 ; i < strlen(strCapper); i++)
	{
		new clientCapper = strCapper[i];
		if(clientCapper == g_nVIP_ID)
		{
			CreateTimer(0.0, RewardSupplyPointCapture);
		}
	}
}

public Action:WeaponFireEvents(Event event, const char[] name, bool dontBroadcast)
{
	//Get client
	new clientID = GetEventInt(event, "userid");
	new client = GetClientOfUserId(clientID);
	new health = GetClientHealth(client);
	decl String:UserWeaponClass[64];
	
	//Check if client is fake player and alive
	if(!IsFakeClient(client) && (health > 0))
	{
		//Get weapon classname of client current active weapon in hand
		new CurrentUserWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		GetEdictClassname(CurrentUserWeapon, UserWeaponClass, sizeof(UserWeaponClass));

		//If the person shot using weapon_p2a1 which is flare and is looking up the skybox then continue
		if(IsValidEntity(CurrentUserWeapon) && (StrEqual(UserWeaponClass, "weapon_p2a1")) && (IsLookingAtSkybox(client)))
		{
			//If flare is activate then skip this part
			//To prevent multiple flare shooting up at the sky
			if((!g_nFlareFiredActivated))
			{
				//Set shooter respawn false
				nShooterID = client;
				
				//Start respawning timer
				CreateTimer(1.0, Timer_RespawnPlayer, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				PrintHintText(client, "There is already another flare activated");
			}
		}
		else if(IsValidEntity(CurrentUserWeapon) && (StrEqual(UserWeaponClass, "weapon_p2a1")) && (!IsLookingAtSkybox(client)))
		{
			PrintHintText(client, "Drone unable to see your flare. No reinforcements");
		}
	}
	
	//return Plugin_Continue;
}

public Event_PlayerPickSquad_Post(Handle:event, const String:name[], bool:dontBroadcast )
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!IsFakeClient(client))
	{
		decl String:class_template[64];
		GetEventString(event, "class_template",class_template,sizeof(class_template));
		//PrintToChat(client, "[Flare Debug by Circleus] Player: True;\nClass: %s", class_template);
		
		if(class_template[0] != EOS)
		{
			g_nPlayer[client] = true;
			//PrintToConsole(client, "[Flare Debug by Circleus] Player: True;\nClass not found");
		}
		else
		{
			g_nPlayer[client] = false;
			//PrintToConsole(client, "[Flare Debug by Circleus] Player: False;\nClass found");
		}
		
		if(StrContains(class_template, "vip") > -1)
		{
			g_nVIP_ID = client;
		}
		
		if((client == g_nVIP_ID) && (StrContains(class_template, "vip") == -1))
		{
			g_nVIP_ID = 0;
		}
		
		if(StrContains(class_template, "signaller") > -1)
		{
			g_nSignaller_ID = client;
		}
		
		if((client == g_nSignaller_ID) && (StrContains(class_template, "signaller") == -1))
		{
			g_nSignaller_ID = 0;
		}
	}
}

public Action:OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client  = GetClientOfUserId(GetEventInt(event, "userid"));
	new team    = GetEventInt(event, "team");
	if((team == TEAM_SPEC) && (client == g_nVIP_ID))
	{
		g_nPlayer[client] = false;
		g_nVIP_ID = 0;
		g_nVIP_Kills = 0;
		g_bVIP_Alive = false;
	}
	
	return Plugin_Continue;
}

stock void ReloadPlugin() {
    char filename[PLATFORM_MAX_PATH];
    GetPluginFilename(INVALID_HANDLE, filename, sizeof(filename));
    ServerCommand("sm plugins reload %s", filename);
}  

public Action:Event_PlayerRespawnPre(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_bPlayerRespawn[client] = true;
	
	if(!IsFakeClient(client))
	{
		//Flare
		if(client == nShooterID)
		{
			nShooterID = 0;
		}
		
		//VIP
		if((client) && (client == g_nVIP_ID) && (g_TimerRunning == false))
		{
			g_bVIP_Alive = true;
			g_TimerRunning = true;
			CreateTimer(1.0, Timer_Check_VIP, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if((client) && (client == g_nVIP_ID))
	{
		g_nVIP_Kills = 0;
		g_bVIP_Alive = false;
	}
	
	//new victimId = GetEventInt(event, "userid");
	new attackerId = GetEventInt(event, "attacker");
	//new victim = GetClientOfUserId(victimId);
	new attacker = GetClientOfUserId(attackerId);
	
	if(g_bVIP_Alive && (attacker == g_nVIP_ID))
	{
		g_nVIP_Kills++;
	}
	
	decl String:sWeapon[32];
	GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));
	
	if(IsValidClient(client) && IsFakeClient(client))
	{
		float fRandom = GetRandomFloat(0.0, 1.0);
		
		if(fRandom <= 0.01)
		{
			new newWeapon = GivePlayerItem(client, "weapon_p2a1");
			new PrimaryAmmoType = GetEntProp(newWeapon, Prop_Data, "m_iPrimaryAmmoType");
			SetEntProp(client, Prop_Send, "m_iAmmo", 1, _, PrimaryAmmoType);
			
			/*
			int nTeam = GetClientTeam(client);
			
			Handle newEvent = CreateEvent("player_death", true);
			SetEventInt(newEvent, "attacker", GetClientUserId(client));
			SetEventInt(newEvent, "attackerteam", nTeam);
			SetEventString(newEvent, "weapon", "Dropped a flare");
			SetEventInt(newEvent, "weaponid", -1);
			SetEventInt(newEvent, "userid", -1);
			SetEventInt(newEvent, "deathflags", 0);
			SetEventInt(newEvent, "customkill", 1);
			FireEvent(newEvent, false);
			*/
		}
	}
	
	/*
	if(IsFakeClient(client) && (attacker == g_nSignaller_ID) && (StrEqual(sWeapon, "kabar") || StrEqual(sWeapon, "gurkha")))
	{
		float fRandom = GetRandomFloat(0.0, 1.0);
		
		if(fRandom <= 0.5)
		{
			new newWeapon = GivePlayerItem(client, "weapon_p2a1");
			new PrimaryAmmoType = GetEntProp(newWeapon, Prop_Data, "m_iPrimaryAmmoType");
			SetEntProp(client, Prop_Send, "m_iAmmo", 1, _, PrimaryAmmoType);
			
			int nTeam = GetClientTeam(client);
			
			Handle newEvent = CreateEvent("player_death", true);
			SetEventInt(newEvent, "attacker", GetClientUserId(client));
			SetEventInt(newEvent, "attackerteam", nTeam);
			SetEventString(newEvent, "weapon", "Dropped a flare");
			SetEventInt(newEvent, "weaponid", -1);
			SetEventInt(newEvent, "userid", -1);
			SetEventInt(newEvent, "deathflags", 0);
			SetEventInt(newEvent, "customkill", 1);
			FireEvent(newEvent, false);
		}
	}
	*/
	
	return Plugin_Continue;
}

public Action:Cmd_GiveSupply(client, args)
{
	if(IsPlayerAlive(client))
	{
		int clientTarget = GetClientAimTarget(client, true);
		
		if((clientTarget > -1) && (IsPlayerAlive(clientTarget)) && (!IsFakeClient(clientTarget)))
		{
			float fDistance = GetDistance(client, clientTarget);
			decl String:szTargetName[64];
			GetClientName(clientTarget, szTargetName, sizeof(szTargetName));
			
			if((fDistance != 0.000) && (fDistance <= 70.0))
			{
				int nCurrentSupplyPoint = GetEntProp(client, Prop_Send, "m_nAvailableTokens");
				int nCurrentTotalSupply = GetEntProp(client, Prop_Send, "m_nRecievedTokens");
				
				if(nCurrentSupplyPoint > 0)
				{
					ConVar cvar_tokenmax = FindConVar("mp_supply_token_max");
					new nMaxSupply = GetConVarInt(cvar_tokenmax);
					
					int nTargetSupplyPoint = GetEntProp(clientTarget, Prop_Send, "m_nAvailableTokens");
					int nTargetTotalSupply = GetEntProp(clientTarget, Prop_Send, "m_nRecievedTokens");
					
					if(nTargetTotalSupply <= nMaxSupply)
					{
						SetEntProp(client, Prop_Send, "m_nRecievedTokens", nCurrentTotalSupply - 1);
						SetEntProp(client, Prop_Send, "m_nAvailableTokens", nCurrentSupplyPoint - 1);
						PrintHintText(client, "%s received a supply point", szTargetName);
						
						decl String:szPlayerName[64];
						GetClientName(client, szPlayerName, sizeof(szPlayerName));
						SetEntProp(clientTarget, Prop_Send, "m_nRecievedTokens", nCurrentTotalSupply + 1);
						SetEntProp(clientTarget, Prop_Send, "m_nAvailableTokens", nTargetSupplyPoint + 1);
						PrintHintText(clientTarget, "%s gave you a supply point", szPlayerName);
					}
					else
					{
						PrintHintText(client, "%s can't have anymore supply point", szTargetName);
					}
				}
				else
				{
					PrintHintText(client, "You don't have any available supply point");
				}
			}
			else
			{
				PrintHintText(client, "%s is too far", szTargetName);
			}
		}
	}
	
	return Plugin_Handled;
}

float GetDistance(client1, client2)
{
	new Float:ClientVec1[3];
	new Float:ClientVec2[3];
	
	if((IsClientInGame(client1)) && (IsPlayerAlive(client1)) &&(!IsFakeClient(client1)))
	{
		GetEntPropVector(client1, Prop_Send, "m_vecOrigin", ClientVec1);
	}
	else
	{
		ClientVec1[0] = 0.000;
	}
	
	if((IsClientInGame(client2)) && (IsPlayerAlive(client2)) &&(!IsFakeClient(client2)))
	{
		GetEntPropVector(client2, Prop_Send, "m_vecOrigin", ClientVec2);
	}
	else
	{
		ClientVec2[0] = 0.000;
	}
	
	if((ClientVec1[0] != 0.000) && (ClientVec2[0] != 0.000))
	{
		return GetVectorDistance(ClientVec1, ClientVec2);
	}
	else
	{
		return 0.000;
	}
}

public Action:Cmd_GetFlare(client, args)
{
	if(g_nFlareCost == 0)
	{
		g_nFlareCost = 2;
	}
	else if(g_nFlareCost > 5)
	{
		g_nFlareCost = 5;
	}
	
	if(IsPlayerAlive(client) && (client == g_nSignaller_ID))
	{
		int nCurrentSupplyPoint = GetEntProp(client, Prop_Send, "m_nAvailableTokens");
		int nCurrentTotalSupply = GetEntProp(client, Prop_Send, "m_nRecievedTokens");
		
		if(nCurrentSupplyPoint >= g_nFlareCost)
		{
			decl String:strWeaponClassName[64];

			//Loop player weapon check if player already have flare
			for(int i = 0; i < 128; i += 4)
			{
				int nWeaponID = GetEntDataEnt2(client, m_hMyWeapons + i);

				if(nWeaponID > 0)
				{
					GetEdictClassname(nWeaponID, strWeaponClassName, sizeof(strWeaponClassName));
					if(StrContains(strWeaponClassName, "weapon_p2a1") > -1)
					{
						PrintHintText(client, "You can't have more than 1 flare gun");
						return Plugin_Handled;
					}
				}
			}
			
			int newWeapon = GivePlayerItem(client, "weapon_p2a1");
			SetEntProp(newWeapon, Prop_Send, "m_iClip1", 1);
			int PrimaryAmmoType = GetEntProp(newWeapon, Prop_Data, "m_iPrimaryAmmoType");
			SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, PrimaryAmmoType);
			
			//Loop player weapon check if player receive a flare
			for(int i = 0; i < 128; i += 4)
			{
				int nWeaponID = GetEntDataEnt2(client, m_hMyWeapons + i);

				if(nWeaponID > 0)
				{
					GetEdictClassname(nWeaponID, strWeaponClassName, sizeof(strWeaponClassName));
					if(StrContains(strWeaponClassName, "weapon_p2a1") > -1)
					{
						SetEntProp(client, Prop_Send, "m_nAvailableTokens", nCurrentSupplyPoint - g_nFlareCost);
						SetEntProp(client, Prop_Send, "m_nRecievedTokens", nCurrentTotalSupply - g_nFlareCost);
						break;
					}
				}
			}
			
			g_nFlareCostCounter++;
			
			if(g_nFlareCostCounter > 2)
			{
				g_nFlareCostCounter = 0;
				g_nFlareCost++;
			}
			
			return Plugin_Handled;
		}
		else
		{
			PrintHintText(client, "You need %d available supply points", g_nFlareCost);
		}
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action Timer_RespawnPlayer(Handle timer, any client)
{
	static int nSecond = 10;
	if(g_nRoundStatus == 0)
	{
		g_nFlareFiredActivated = false;
		nSecond = 10;
		return Plugin_Stop;
	}
	
	g_nFlareFiredActivated = true;
	decl String:sGameMode[32];
	GetConVarString(FindConVar("mp_gamemode"), sGameMode, sizeof(sGameMode));
	
	if(nSecond <= 0) 
    {
		for(new i = 1; i <= MaxClients; i++)
		{
			if(StrEqual(sGameMode,"checkpoint") && (i != g_nVIP_ID))
			{
				CreateRespawnPlayerTimer(i);
			}
			else if(!StrEqual(sGameMode,"checkpoint"))
			{
				CreateRespawnPlayerTimer(i);
			}
		}
		
		g_nFlareFiredActivated = false;
		PrintHintTextToAll("Team reinforcements have arrived!");
		//PrintHintText(client, "Team reinforcements have arrived!");
		nSecond = 10;
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("Team reinforcements inbound in %d", nSecond);
		//PrintHintText(client, "Team reinforcements inbound in %d", nSecond);
		nSecond--;
	}
 
	return Plugin_Continue;
}

public CreateRespawnPlayerTimer(client)
{
	CreateTimer(0.0, RespawnPlayer, client);
}

public Action:RespawnPlayer(Handle:Timer, any:client)
{
	// Exit if client is not in game
	if (!IsClientInGame(client)) return;
	
	new currentPlayerTeam = GetClientTeam(client);
	if((IsValidClient(client)) && (!IsFakeClient(client)) && (!IsPlayerAlive(client)) && (currentPlayerTeam == TEAM_SECURITY) && (IsClientConnected(client)) && (client != nShooterID) && (g_nPlayer[client]) && (g_bPlayerRespawn[client]))
	{
		SDKCall(g_hForceRespawn, client);
	}
	else
	{
		return;
	}
}

public Action:RespawnPlayerAllowCheckListener(client, const String:cmd[], argc)
{
	g_bPlayerRespawn[client] = false;
}

public bool:FilterOutPlayer(entity, contentsMask, any:data)
{
    if (entity == data)
    {
        return false;
    }
    
    return true;
}

bool:IsLookingAtSkybox(client)
{
	decl Float:pos[3], Float:ang[3], Float:EndOrigin[3];
	
	//Get client position
	//GetClientAbsOrigin(client, pos);
	GetClientEyePosition(client, pos);
	
	//Get client angles
	GetClientEyeAngles(client, ang);
	
	//Trace ray to find if the bullet hit the end of the entity
	//Using MASK_SHOT to trace like bullet that hit walls and stuff
	//RayType_Infinite to make the start position to infinite in case if its the sky
	//(Skybox doesn't have end position unless the map maker add invisible wall at the top)
	//TR_TraceRay(pos, ang, MASK_SHOT, RayType_Infinite);
	TR_TraceRayFilter(pos, ang, MASK_SHOT, RayType_Infinite, TraceEntityFilter:FilterOutPlayer, client);
	
	//If it it hit then run the if statement
	if(TR_DidHit())
	{
		//Get the end position of the traceray
		TR_GetEndPosition(EndOrigin);
		
		//Use GetVectorDistance to get the distance between the client and the end position
		if((ang[0] < -30) && (GetVectorDistance(EndOrigin, pos) > 400))
		{
			return true;
		}
		else
		{
			return false;
		}
	}
	return false;
}

public Action Timer_Check_VIP(Handle timer)
{
	if(!IsValidClient(g_nVIP_ID)) return Plugin_Continue; 
	
	new nCurrentPlayerTeam = GetClientTeam(g_nVIP_ID);
	if((g_nVIP_ID == 0) || (nCurrentPlayerTeam != 2))
	{
		g_nVIP_TotalKills = 0;
		g_nVIP_ID = 0;
		g_nVIP_Kills = 0;
		g_TimerRunning = false;
		g_bVIP_Alive = false;
		return Plugin_Stop;
	}
	
	// Check round state
	if (g_nRoundStatus == 0) 
	{
		return Plugin_Continue;
	}
	
	if(g_bVIP_Alive == true)
	{
		//PrintToChat(g_nVIP_ID, "Your survival time is %i", nSecond);
		
		if(g_nVIP_TotalKills <= 0)
		{
			g_nVIP_TotalKills = GetRandomInt(8, 12);
		}
		
		if(g_nVIP_Kills >= g_nVIP_TotalKills)
		{
			g_nVIP_Kills = 0;
			g_nVIP_TotalKillsTemp = g_nVIP_TotalKills;
			g_nVIP_TotalKills = 0;
			CreateTimer(0.0, RewardSupplyPointKills);
		}
	}
	else if(g_bVIP_Alive == false)
	{
		//CreateTimer(0.0, RemoveSupplyPoint);
		g_TimerRunning = false;
		g_nVIP_Kills = 0;
		
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:RemoveSupplyPoint(Handle:Timer)
{
	//For Loop to get each client until it reach MaxClients
	for(new client = 1; client <= MaxClients; client++)
	{
		//Get currently client's team
		new nCurrentPlayerTeam = GetClientTeam(client);
		//Check if client is in game and is connected. Make sure its not fake client (Bot). Client must be in team 2 (SECURITY_TEAM)
		if((IsValidClient(client)) && (IsClientConnected(client)) && (!IsFakeClient(client)) && (nCurrentPlayerTeam == 2))
		{
			//Create a panel
			new Handle:UserPanel = CreatePanel(INVALID_HANDLE);
			new String:sFirstLinePanel[80];
			new String:sSecondLinePanel[80];
			
			//Get client supply point
			int nSupplyPoint = GetEntProp(client, Prop_Send, "m_nRecievedTokens");
			
			Format(sFirstLinePanel,sizeof(sFirstLinePanel), "Supply Point(Before): %i", nSupplyPoint);
			DrawPanelText(UserPanel, sFirstLinePanel);
			
			//If nSupplyPoint is less than 0 we will keep it at 0
			if(nSupplyPoint <= 0)
			{
				nSupplyPoint = 0;
				PrintHintText(client, "VIP has died\nYou can't lose anymore supply point");
			}
			//Otherwise we get a random supply point 1 to 2 and substract if off from the nSupplyPoint we get from client
			else
			{
				new nRandomPoint = GetRandomInt(1, 2);
				nSupplyPoint -= nRandomPoint;
				PrintHintText(client, "VIP has died\nYou lose %i supply point(s)", nRandomPoint);
			}
			
			Format(sSecondLinePanel,sizeof(sSecondLinePanel), "Supply Point(Now): %i", nSupplyPoint);
			DrawPanelText(UserPanel, sSecondLinePanel);

			//Set client nSupplyPoint
			SetEntProp(client, Prop_Send, "m_nRecievedTokens",nSupplyPoint);
			
			//Send Panel to client
			SendPanelToClient(UserPanel, client, NullMenuHandler, 2);
		}
	}
	
	return;
}

public Action:RewardSupplyPoint(Handle:Timer)
{
	ConVar cvar_tokenmax = FindConVar("mp_supply_token_max");
	new nMaxSupply = GetConVarInt(cvar_tokenmax);
	
	for(new client = 1; client <= MaxClients; client++)
	{
		//new nCurrentPlayerTeam = GetClientTeam(client);
		if((IsValidClient(client)) && (IsClientConnected(client)) && (!IsFakeClient(client)))
		{
			int nSupplyPoint = GetEntProp(client, Prop_Send, "m_nRecievedTokens");
			int nAvailableSupplyPoint = GetEntProp(client, Prop_Send, "m_nAvailableTokens");
			
			if(nSupplyPoint <= nMaxSupply)
			{
				new nRandomPoint = GetRandomInt(1, 3);
				nSupplyPoint += nRandomPoint;
				nAvailableSupplyPoint += nRandomPoint;
				//PrintHintText(client, "VIP has survived\nYou have received %i supply point(s) as reward", nRandomPoint);
			}

			//Set client nSupplyPoint
			SetEntProp(client, Prop_Send, "m_nRecievedTokens",nSupplyPoint);
			SetEntProp(client, Prop_Send, "m_nAvailableTokens", nAvailableSupplyPoint);
		}
	}
	
	return;
}

public Action:RewardSupplyPointCapture(Handle:Timer)
{
	ConVar cvar_tokenmax = FindConVar("mp_supply_token_max");
	new nMaxSupply = GetConVarInt(cvar_tokenmax);
	
	for(new client = 1; client <= MaxClients; client++)
	{
		//new nCurrentPlayerTeam = GetClientTeam(client);
		if((IsValidClient(client)) && (IsClientConnected(client)) && (!IsFakeClient(client)))
		{
			int nSupplyPoint = GetEntProp(client, Prop_Send, "m_nRecievedTokens");
			int nAvailableSupplyPoint = GetEntProp(client, Prop_Send, "m_nAvailableTokens");
			
			if(nSupplyPoint <= nMaxSupply)
			{
				//new nRandomPoint = GetRandomInt(1, 2);
				new nRandomPoint = 1;
				nSupplyPoint += nRandomPoint;
				nAvailableSupplyPoint += nRandomPoint;
				PrintHintText(client, "VIP has captured a point\nYou have received %i supply point as reward", nRandomPoint);
			}

			//Set client nSupplyPoint
			SetEntProp(client, Prop_Send, "m_nRecievedTokens",nSupplyPoint);
			SetEntProp(client, Prop_Send, "m_nAvailableTokens", nAvailableSupplyPoint);
		}
	}
	
	return;
}

public Action:RewardSupplyPointKills(Handle:Timer)
{
	ConVar cvar_tokenmax = FindConVar("mp_supply_token_max");
	new nMaxSupply = GetConVarInt(cvar_tokenmax);
	
	for(new client = 1; client <= MaxClients; client++)
	{
		//new nCurrentPlayerTeam = GetClientTeam(client);
		if((IsValidClient(client)) && (IsClientConnected(client)) && (!IsFakeClient(client)))
		{
			int nSupplyPoint = GetEntProp(client, Prop_Send, "m_nRecievedTokens");
			int nAvailableSupplyPoint = GetEntProp(client, Prop_Send, "m_nAvailableTokens");
			
			if(nSupplyPoint <= nMaxSupply)
			{
				new nRandomPoint = GetRandomInt(1, 3);
				nSupplyPoint += nRandomPoint;
				nAvailableSupplyPoint += nRandomPoint;
				//PrintHintText(client, "VIP has killed %i enemies without dying\nYou have received %i supply point(s) as reward", g_nVIP_TotalKillsTemp, nRandomPoint);
			}

			//Set client nSupplyPoint
			SetEntProp(client, Prop_Send, "m_nRecievedTokens",nSupplyPoint);
			SetEntProp(client, Prop_Send, "m_nAvailableTokens", nAvailableSupplyPoint);
		}
	}
	
	return;
}

public Action:Cmd_VIP(client, args)
{
	int nPlayerHealth = GetClientHealth(client);
	if((client == g_nVIP_ID) && (nPlayerHealth > 0))
	{
		PrintHintText(client, "%i/%i kills without dying\nbefore your teammates get supply point reward", g_nVIP_Kills, g_nVIP_TotalKills);
	}
	else if((g_nVIP_ID != 0) && g_bVIP_Alive && (nPlayerHealth > 0))
	{
		PrintHintText(client, "VIP need %i/%i kills without dying", g_nVIP_Kills, g_nVIP_TotalKills);
	}
	else if((g_nVIP_ID != 0) && (!g_bVIP_Alive) && (client != g_nVIP_ID) && (nPlayerHealth > 0))
	{
		PrintHintText(client, "VIP is dead");
	}
	else if((g_nVIP_ID == 0) && (nPlayerHealth > 0))
	{
		PrintHintText(client, "No VIP available");
	}
	return Plugin_Handled;
}

public Action AddGlow(Handle timer, any:ent)
{
	decl String:m_ModelName[PLATFORM_MAX_PATH];
	GetEntPropString(ent, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
	
	int glow = CreateEntityByName("prop_dynamic_override");
	
	float fPos[3];
	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", fPos);
	float fAngles[3];
	GetEntPropVector(ent, Prop_Send, "m_angRotation", fAngles);
	
	DispatchKeyValue(glow, "model", m_ModelName);
	DispatchKeyValue(glow, "disablereceiveshadows", "1");
	DispatchKeyValue(glow, "disableshadows", "1");
	DispatchKeyValue(glow, "solid", "0");
	DispatchKeyValue(glow, "spawnflags", "256");
	
	DispatchSpawn(glow);
	TeleportEntity(glow, fPos, fAngles, NULL_VECTOR);
	
	SetEntProp(glow, Prop_Send, "m_CollisionGroup", 11);
	SetEntProp(glow, Prop_Send, "m_bShouldGlow", true);
	//SetEntProp(glow, Prop_Send, "m_nGlowStyle", 1);
	SetEntPropFloat(glow, Prop_Send, "m_flGlowMaxDist", 1000000.0);
	
	SetVariantColor({244, 66, 226, 255});
	AcceptEntityInput(glow, "SetGlowColor");
	SetVariantString("!activator");
	AcceptEntityInput(glow, "SetParent", ent);
	g_nGlowingEntity[ent] = glow;
}

bool:IsValidClient(client) 
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}

public NullMenuHandler(Handle:menu, MenuAction:action, param1, param2) 
{
}