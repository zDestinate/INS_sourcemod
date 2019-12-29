//(C) 2014 Jared Ballou <sourcemod@jballou.com>
//Released under GPLv3

#pragma semicolon 1
#pragma unused cvarVersion
#include <sourcemod> 
#include <sdktools>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#include <updater>

#define AUTOLOAD_EXTENSIONS 
#define REQUIRE_EXTENSIONS

#pragma unused cvarVersion

#define PLUGIN_VERSION "1.0.3"
#define PLUGIN_DESCRIPTION "Adds suicide bomb for bots and player"
#define UPDATE_URL    ""

#define MAX_FILE_LEN 80

new Handle:cvarVersion = INVALID_HANDLE; // version cvar!
new Handle:cvarEnabled = INVALID_HANDLE; // are we enabled?
new Handle:cvarDeathChance = INVALID_HANDLE; //global death chance
new Handle:cvarIncenDeathChance = INVALID_HANDLE; //death chance if explosion
new Handle:cvarExplosiveDeathChance = INVALID_HANDLE; //death chance if explosion
new Handle:cvarChestStomachDeathChance = INVALID_HANDLE; //death chance if chest/stomach
new Handle:cvarLimbsDeathChance = INVALID_HANDLE;
new Handle:cvar_yelling_delay = INVALID_HANDLE; //Yelling delay time
new Handle:cvar_jammer_range = INVALID_HANDLE; //Range of jammer
new Handle:cvar_jammer_chance = INVALID_HANDLE; //Chance jammer has to jam bomber
new g_ClientBombs[MAXPLAYERS+1];
new Float:g_BomberLastPos[MAXPLAYERS+1][3];
new String:g_client_last_classstring[MAXPLAYERS+1][64];
//new bool:bEnabled = false;
new g_isDetonating[MAXPLAYERS+1];
new g_yellCounter[MAXPLAYERS+1];
new g_iRoundStatus = 0;
new g_nSuiciderClass = 0;
new bool:g_bAutoSuicide = false;
new bool:g_preRoundInitial = false;
/*hitgroups
generic = 0?
head = 1
chest = 2
stomach = 3
leftArm = 4
rightArm = 5
leftLeg = 6
rightLeg = 7
Gear = 8 ?
*/

// list of specific files that are decent
new String:DetonateYellSounds[][] = {
	"allahuakbar/detonate01.ogg",
	"allahuakbar/allahu_akbar01.ogg",
	"allahuakbar/allahu_akbar02.ogg",
	"allahuakbar/detonate02.ogg"
};
new String:RoamingSounds[][] = {
	"allahuakbar/roam01.ogg",
	"allahuakbar/roam02.ogg",
	"allahuakbar/roam03.ogg",
	"allahuakbar/roam04.ogg",
	"allahuakbar/roam05.ogg",
	"allahuakbar/roam06.ogg",
	"allahuakbar/roam07.ogg",
	"allahuakbar/roam08.ogg",
	"allahuakbar/roam09.ogg",
	"allahuakbar/roam10.ogg",
	"allahuakbar/roam11.ogg"
};

new String:BlacklistWeaponNames[][] =
{
	"weapon_kabar",
	"weapon_gurkha",
	"weapon_knife",
	"weapon_kukri",
	"weapon_katana",
	"weapon_riotshield"
};

public Plugin:myinfo = {
	name= "[INS] Suicide Bombers (Rehash version)",
	author  = "Neko-",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
};

public OnPluginStart()
{
	//PrintToServer("[SUICIDE] Starting");
	cvarVersion = CreateConVar("sm_suicidebomb_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD);
	cvarEnabled = CreateConVar("sm_suicidebomb_enabled", "1", "sets whether suicide bombs are enabled", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarDeathChance = CreateConVar("sm_suicidebomb_death_chance", "0.0", "Chance as a fraction of 1 that a bomber will explode when killed", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarIncenDeathChance = CreateConVar("sm_suicidebomb_incen_death_chance", "0.15", "Chance as a fraction of 1 that a bomber will explode when hurt by incen/molotov", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarExplosiveDeathChance = CreateConVar("sm_suicidebomb_explosive_death_chance", "0.75", "Chance as a fraction of 1 that a bomber will explode when hurt by explosive", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarChestStomachDeathChance = CreateConVar("sm_suicidebomb_chest_stomach_death_chance", "0.50", "Chance as a fraction of 1 that a bomber will explode if shot in stomach/chest", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarLimbsDeathChance = CreateConVar("sm_suicidebomb_limbs_death_chance", "0.25", "Chance as a fraction of 1 that a bomber will explode if shot in limbs", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvar_yelling_delay = CreateConVar("sm_yelling_delay", "6", "Yelling delay time");
	cvar_jammer_range = CreateConVar("sm_jammer_range", "1200", "Range of the jammer");
	cvar_jammer_chance = CreateConVar("sm_jammer_chance", "70", "Chance the jammer has to prevent trigger");
	
	RegConsoleCmd("suicide", Cmd_Suicide, "Suicide yourself");
	RegConsoleCmd("suicideauto", Cmd_SuicideAuto, "Auto-suicide yourself");
	RegConsoleCmd("allahu", Cmd_Yell, "Yell allahu akbar");
	
	AutoExecConfig(true,"plugin.suicide");
	
	HookConVarChange(cvarEnabled,ConVarChanged);
	HookEvent("player_spawn", Event_PlayerRespawn);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_pick_squad", Event_PlayerPickSquad);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("game_end", Event_GameEnd, EventHookMode_PostNoCopy);
}
public OnConfigsExecuted()
{
	decl String:buffer[MAX_FILE_LEN];
	new noncached = 0;
	
	// cache sounds in string array to be used
	for (new i = 0; i < sizeof(RoamingSounds); i++) {
		Format(buffer, sizeof(buffer), "sound/%s", RoamingSounds[i]);
		AddFileToDownloadsTable(buffer);
		noncached++;
	}
	for (new i = 0; i < sizeof(DetonateYellSounds); i++) {
		Format(buffer, sizeof(buffer), "sound/%s", DetonateYellSounds[i]);
		AddFileToDownloadsTable(buffer);
		noncached++;
	}
	PrintToServer("[SUICIDE] Done adding %d sounds to download table", noncached);
}
public OnMapStart()
{	
	CreateTimer(3.0, Timer_BomberLoop, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	PrecacheSound("weapons/ied/handling/ied_trigger_ins.wav");
	PrecacheSound("player/voip_end_transmit_beep_03.wav");

	PrecacheSound("ui/sfx/beep.wav");
	PrecacheAllahuSound();
	
	PrecacheModel("models/weapons/w_ied.mdl", true);
	g_preRoundInitial = true;
}
public OnMapEnd()
{
	g_iRoundStatus = 0;
}

PrecacheAllahuSound()
{
	new noncached = 0;
	// cache sounds in string array to be used
	for (new i = 0; i < sizeof(RoamingSounds); i++) {
		//if (!IsSoundPrecached(RoamingSounds[i])) {
			PrecacheSound(RoamingSounds[i]);
			noncached++;
			//PrintToServer("[FY] Cached: %s", sAllahuSounds[i]);
		//}
	}
	for (new i = 0; i < sizeof(DetonateYellSounds); i++) {
		//if (!IsSoundPrecached(DetonateYellSounds[i])) {
			PrecacheSound(DetonateYellSounds[i]);
			noncached++;
			//PrintToServer("[FY] Cached: %s", sAllahuSounds[i]);
		//}
	}
	PrintToServer("[SUICIDE] Done caching %d sounds", noncached);
}
public ConVarChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	//if(cvar == cvarEnabled)
	//	bEnabled = bool:StringToInt(newVal);
}
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iPreRoundFirst = GetConVarInt(FindConVar("mp_timer_preround_first"));
	new iPreRound = GetConVarInt(FindConVar("mp_timer_preround"));
	if (g_preRoundInitial == true)
	{
		CreateTimer(float(iPreRoundFirst), RoundStartTimer);
	
		g_preRoundInitial = false;
	}
	else
	{
		CreateTimer(float(iPreRound), RoundStartTimer);
	}
}
public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_iRoundStatus = 0;
}
public Action:Event_GameEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_iRoundStatus = 0;
}

public Event_PlayerPickSquad(Handle:event, const String:name[], bool:dontBroadcast)
{
	//PrintToServer("[SUICIDE] Running Event_PlayerPickSquad");
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	decl String:class_template[64];
	GetEventString(event, "class_template",class_template,sizeof(class_template));
	if(client)
	{
		g_client_last_classstring[client] = class_template;
		if(StrContains(class_template, "suicider") > -1)
		{
			g_nSuiciderClass = 0;
		}
	}
}

public Event_PlayerRespawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(StrContains(g_client_last_classstring[client], "bomber") > -1)
	{
		new CurrentUserWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if(CurrentUserWeapon < 0)
		{
			return;
		}
		
		decl String:User_Weapon[32];
		GetEdictClassname(CurrentUserWeapon, User_Weapon, sizeof(User_Weapon));
		if(StrEqual(User_Weapon, "weapon_model10"))
		{
			SDKHooks_DropWeapon(client, CurrentUserWeapon, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

public Action:RoundStartTimer(Handle:Timer)
{
	g_iRoundStatus = 1;
}

public Action:Cmd_Suicide(client, args)
{
	// Check round state
	if(g_iRoundStatus == 0) return Plugin_Handled;
	if(g_nSuiciderClass > 0) return Plugin_Handled;
	
	//Get user health
	new userHealth = GetClientHealth(client);
	
	if(userHealth <= 0)
	{
		return Plugin_Handled;
	}
	
	if((client) && (StrContains(g_client_last_classstring[client], "suicider") > -1))
	{
		g_nSuiciderClass = client;
		//g_nSuiciderClass = 0;
		new Float:vecOrigin[3],Float:vecAngles[3];
		GetClientEyePosition(client, vecOrigin);

		new ent = CreateEntityByName("grenade_c4");
		if(IsValidEntity(ent))
		{
			vecAngles[0] = vecAngles[1] = vecAngles[2] = 0.0;
			TeleportEntity(ent, vecOrigin, vecAngles, vecAngles);
			SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", client);
			SetEntProp(ent, Prop_Data, "m_nNextThinkTick", 1); //for smoke
			SetEntProp(ent, Prop_Data, "m_takedamage", 2);
			SetEntProp(ent, Prop_Data, "m_iHealth", 1);
			SetEntProp(ent, Prop_Data, "m_usSolidFlags", 0);
			SetEntProp(ent, Prop_Data, "m_nSolidType", 0);
			g_ClientBombs[client] = EntIndexToEntRef(ent);
			CreateTimer(0.03, Timer_DetonatePeriodPlayer, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			
			if (DispatchSpawn(ent)) {
				YellDetonateSound(client);
				DealDamage(ent,280,client,DMG_BLAST,"weapon_c4_clicker");
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:Cmd_SuicideAuto(client, args)
{
	if((client) && (StrContains(g_client_last_classstring[client], "suicider") > -1) && (GetClientTeam(client) == 2))
	{
		if(g_bAutoSuicide)
		{
			PrintToChat(client, "\x01\x0759b0f9[INS] \x01\x11[Suicide] \x01\x07c42121Off\x01 (Auto suicide is now off)");
			g_bAutoSuicide = false;
		}
		else
		{
			PrintToChat(client, "\x01\x0759b0f9[INS] \x01\x11[Suicide] \x01\x0735d611On\x01 (Auto suicide is now on. You will auto trigger C4 on death)");
			g_bAutoSuicide = true;
		}
	}
	return Plugin_Handled;
}

public Action:Cmd_Yell(client, args)
{
	//Get user health
	new userHealth = GetClientHealth(client);
	
	new AdminId:admin = GetUserAdmin(client);
	if((admin != INVALID_ADMIN_ID) && (GetAdminFlag(admin, Admin_Generic, Access_Effective) == true) && (userHealth > 0))
	{
		YellDetonateSound(client);
	}
	else if((client) && (StrContains(g_client_last_classstring[client], "suicider") > -1) && (userHealth > 0))
	{
		YellDetonateSound(client);
	}
	
	return Plugin_Handled;
}

public Action:Timer_BomberLoop(Handle:timer) //this controls bomber loop to check if distance from player
{
	//new Float:fBomberDistance = GetRandomFloat(100.0, 350.0);
	new Float:fBomberDistance = 350.0;
	//PrintToServer("[SUICIDE] TIMER: g_isDetonating: %i", g_isDetonating);
	
	////PrintToServer("[SUICIDE] TIMER STARTED");
	for (new bomber = 1; bomber <= MaxClients; bomber++)
	{
		if (bomber < 1 || !IsClientInGame(bomber) || !IsFakeClient(bomber) && g_isDetonating[bomber] != 1)
			continue;
			
		if ((StrContains(g_client_last_classstring[bomber], "bomber") > -1) && 
			IsPlayerAlive(bomber))
		{
			////PrintToServer("[SUICIDE] TIMER BOMBER DETECTED");
			
			// yell allahu akbar
			if (g_yellCounter[bomber] <= 0)
			{
				YellRomaingSound(bomber);
				g_yellCounter[bomber] = GetConVarInt(cvar_yelling_delay) / 2;
			}
			else
			{
				g_yellCounter[bomber]--;
			}
			
			/*
			for (new victim = 1; victim <= MaxClients; victim++) // lets get our victim to compare distance
			{
				if (victim < 1 || !IsClientInGame(victim) || IsFakeClient(victim))
					continue;
					
				if (IsPlayerAlive(victim))
				{
					new Float:tDistance = (GetEntitiesDistance(bomber, victim)); // get current distance
					//tDistance = Math_UnitsToMeters(tDistance);
					//PrintToServer("[SUICIDE] Bomber Distance: %f ", tDistance);
					
					//PrintToServer("[SUICIDE] TIMER VICTIM DETECTED");
					
					if(tDistance < fBomberDistance)
					{
						new Float:fBomberViewThreshold = 0.5; //0.8 if negative, bombers back is turned
						new tCanBomberSeeTarget = (ClientViews(bomber, victim, fBomberDistance, fBomberViewThreshold));
						if (tCanBomberSeeTarget)
						{	
							EmitSoundToAll("weapons/ied/handling/ied_trigger_ins.wav", bomber, SNDCHAN_VOICE, _, _, 1.0);
								
							PrintToServer("[SUICIDE] BOOM");
							g_isDetonating[bomber] = 1;
							CheckExplodeHurt(bomber);
						}
						else
						{
							//PrintToServer("[SUICIDE] BOMBER HAS NO LOS!");
						}
					}
				}
			}
			*/
		}
	}
}

//Find Valid Prop
public FindValidProp_InDistance(client)
{
	new prop;
	while ((prop = FindEntityByClassname(prop, "prop_dynamic_override")) != INVALID_ENT_REFERENCE)
	{
		new String:propModelName[128];
		GetEntPropString(prop, Prop_Data, "m_ModelName", propModelName, 128);
		if (StrEqual(propModelName, "models/static_fittings/antenna02b.mdl"))
		{
			new Float:tDistance = (GetEntitiesDistance(client, prop));
			if (tDistance <= (GetConVarInt(cvar_jammer_range) / 2))
			{
				return prop;
			}
		}

	}
	return -1;
}

// ----------------------------------------------------------------------------
// ClientViews()
// ----------------------------------------------------------------------------
stock bool:ClientViews(Viewer, Target, Float:fMaxDistance=0.0, Float:fThreshold=0.73)
{
    // Retrieve view and target eyes position
    decl Float:fViewPos[3];   GetClientEyePosition(Viewer, fViewPos);
    decl Float:fViewAng[3];   GetClientEyeAngles(Viewer, fViewAng);
    decl Float:fViewDir[3];
    decl Float:fTargetPos[3]; GetClientEyePosition(Target, fTargetPos);
    decl Float:fTargetDir[3];
    decl Float:fDistance[3];
    
    // Calculate view direction
    fViewAng[0] = fViewAng[2] = 0.0;
    GetAngleVectors(fViewAng, fViewDir, NULL_VECTOR, NULL_VECTOR);
    
    // Calculate distance to viewer to see if it can be seen.
    fDistance[0] = fTargetPos[0]-fViewPos[0];
    fDistance[1] = fTargetPos[1]-fViewPos[1];
    fDistance[2] = 0.0;
    if (fMaxDistance != 0.0)
    {
        if (((fDistance[0]*fDistance[0])+(fDistance[1]*fDistance[1])) >= (fMaxDistance*fMaxDistance))
            return false;
    }
    
    // Check dot product. If it's negative, that means the viewer is facing
    // backwards to the target.
    NormalizeVector(fDistance, fTargetDir);
    if (GetVectorDotProduct(fViewDir, fTargetDir) < fThreshold) return false;
    
    // Now check if there are no obstacles in between through raycasting
    new Handle:hTrace = TR_TraceRayFilterEx(fViewPos, fTargetPos, MASK_PLAYERSOLID_BRUSHONLY, RayType_EndPoint, ClientViewsFilter);
    if (TR_DidHit(hTrace)) { CloseHandle(hTrace); return false; }
    CloseHandle(hTrace);
    
    // Done, it's visible
    return true;
}

// ----------------------------------------------------------------------------
// ClientViewsFilter()
// ----------------------------------------------------------------------------
public bool:ClientViewsFilter(Entity, Mask, any:Junk)
{
    if (Entity >= 1 && Entity <= MaxClients) return false;
    return true;
}  
stock Float:GetEntitiesDistance(ent1, ent2)
{
	new Float:orig1[3];
	GetEntPropVector(ent1, Prop_Send, "m_vecOrigin", orig1);
	
	new Float:orig2[3];
	GetEntPropVector(ent2, Prop_Send, "m_vecOrigin", orig2);

	return GetVectorDistance(orig1, orig2);
} 

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victimId = GetEventInt(event, "userid");
	new victim = GetClientOfUserId(victimId);
	new attackerId = GetEventInt(event, "attacker");
	new attacker = GetClientOfUserId(attackerId);
	
	////PrintToServer("[SUICIDE] Victim ID is %d, g_isDetonating: %i",victimId, g_isDetonating);
	if (StrContains(g_client_last_classstring[victim], "bomber") > -1) //make sure its a bot bomber
	{
		if (IsClientInGame(victim) && IsFakeClient(victim) && g_isDetonating[victim] != 1)
		{
			new Float:fChestStomachDeathChance = GetConVarFloat(cvarChestStomachDeathChance);
			new Float:fLimbsDeathChance = GetConVarFloat(cvarLimbsDeathChance);
			new Float:fExplosiveDeathChance = GetConVarFloat(cvarExplosiveDeathChance);
			new Float:fIncenDeathChance = GetConVarFloat(cvarIncenDeathChance);
			
			new hitgroup = GetEventInt(event, "hitgroup");
			decl String:weapon[32];
			//new Int:victimHealth = GetEventInt(event, "health");
			GetEventString(event, "weapon", weapon, sizeof(weapon));
			
			//Addition
			for (new count=0; count < sizeof(BlacklistWeaponNames); count++)
			{
				if (StrEqual(weapon, BlacklistWeaponNames[count]))
				{
					return Plugin_Continue;
				}
			}
			
			//PrintToServer("[SUICIDE] victimHealth is: %i, Damage Taken: %i | RETURNING",victimHealth, dmg_taken);
			
			new Float:fRandom = GetRandomFloat(0.0, 1.0);
			//PrintToServer("[SUICIDE] Weapon used: %s, Damage done: %i",weapon, dmg_taken);

			if (hitgroup == 0)
			{
				//explosive list
				//incens
				//grenade_molotov, grenade_anm14
				//grenade_m67, grenade_f1, grenade_ied, grenade_c4, rocket_rpg7, rocket_at4, grenade_gp25_he, grenade_m203_he
				if (StrEqual(weapon, "grenade_anm14", false) || StrEqual(weapon, "grenade_molotov", false))
				{
					//PrintToServer("[SUICIDE] incen/molotov DETECTED!");
					if (fRandom <= fIncenDeathChance)
					{
						CheckExplodeHurt(victim);
					}
				}
				else if (StrEqual(weapon, "grenade_m67", false) || 
					StrEqual(weapon, "grenade_f1", false) || 
					StrEqual(weapon, "grenade_ied", false) || 
					StrEqual(weapon, "grenade_c4", false) || 
					StrEqual(weapon, "rocket_rpg7", false) || 
					StrEqual(weapon, "rocket_at4", false) || 
					StrEqual(weapon, "grenade_gp25_he", false) || 
					StrEqual(weapon, "grenade_m203_he", false))
				{
					//PrintToServer("[SUICIDE] Explosive DETECTED!");
					if (fRandom <= fExplosiveDeathChance)
					{
						CheckExplodeHurt(victim);
					}
				}
				//PrintToServer("[SUICIDE] HITRGOUP 0 [GENERIC]");
			}
			else if (hitgroup == 1)
			{
				//PrintToServer("[SUICIDE] BOOM HEADSHOT");
			}
			else if (hitgroup == 2 || hitgroup == 3)
			{
				//if (fRandom < 0.75) // To compensate for higher caliber rifles that may kill target in 1-2 shots we raise chance o 75%
				if (fRandom <= fChestStomachDeathChance)
				{
					CheckExplodeHurt(victim);
				}
			}
			else if (hitgroup == 4 || hitgroup == 5  || hitgroup == 6 || hitgroup == 7)
			{
				if (fRandom <= fLimbsDeathChance) //25% chance if shot in legs/arms to panic detonate
				{
					CheckExplodeHurt(victim);
				}
			}
		}
	}
	
	//PrintToServer("[SUICIDE] EventDeath: Victim ID is %d, g_isDetonating: %i",victimId, g_isDetonating);
	return Plugin_Continue;
}
public Action:Timer_DetonatePeriod(Handle:timer, any:client)
{
	//new client;
	new bomb;
	new Float:clientPos[3];
	//PrintToServer("[DEBUG]-------BOMB ACTIVE");
	//ResetPack(bomberPack);
	//client = ReadPackCell(bomberPack);
	//bomb = ReadPackCell(bomberPack);
	if (client > 0 && IsClientConnected(client) && IsClientInGame(client))
	{
		bomb = EntRefToEntIndex(g_ClientBombs[client]);
		GetClientAbsOrigin(client, Float:clientPos);
		clientPos[2] = clientPos[2] + 54;
	    //client is our victim and we are running through all medics to see whos nearby
		if(IsFakeClient(client) && IsPlayerAlive(client) && bomb > 0 && bomb != INVALID_ENT_REFERENCE && IsValidEdict(bomb) && IsValidEntity(bomb))
		{	
			TeleportEntity(bomb, clientPos, NULL_VECTOR, NULL_VECTOR);
		}
		else
		{
			return Plugin_Stop;
		}
	}
	else
	{
		return Plugin_Stop;
	}
	
	//Addition
	return Plugin_Continue;
}
public Action:Timer_DetonatePeriodPlayer(Handle:timer, any:client)
{
	//new client;
	new bomb;
	new Float:clientPos[3];
	//PrintToServer("[DEBUG]-------BOMB ACTIVE");
	//ResetPack(bomberPack);
	//client = ReadPackCell(bomberPack);
	//bomb = ReadPackCell(bomberPack);
	if (client > 0 && IsClientConnected(client) && IsClientInGame(client))
	{
		bomb = EntRefToEntIndex(g_ClientBombs[client]);
		GetClientAbsOrigin(client, Float:clientPos);
		clientPos[2] = clientPos[2] + 54;
	    //client is our victim and we are running through all medics to see whos nearby
		if(IsPlayerAlive(client) && bomb > 0 && bomb != INVALID_ENT_REFERENCE && IsValidEdict(bomb) && IsValidEntity(bomb))
		{	
			TeleportEntity(bomb, clientPos, NULL_VECTOR, NULL_VECTOR);
		}
		else
		{
			return Plugin_Stop;
		}
	}
	else
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}
public CheckExplodeHurt(client) {
	g_isDetonating[client] = 1;
	//new m_iSquad = GetEntProp(client, Prop_Send, "m_iSquad");
	//new m_iSquadSlot = GetEntProp(client, Prop_Send, "m_iSquadSlot");
	
	//PrintToServer("[SUICIDE] Running CheckExplodeHURT for client %d name %N squad %d squadslot %d",client,client,m_iSquad,m_iSquadSlot);
	PrintToServer("[SUICIDE] Blowing Up %N with class %s!",client,g_client_last_classstring[client]);

	new Float:vecOrigin[3],Float:vecAngles[3];
	GetClientEyePosition(client, vecOrigin);

	new ent = CreateEntityByName("grenade_ied");
	if(IsValidEntity(ent))
	{
		vecAngles[0] = vecAngles[1] = vecAngles[2] = 0.0;
		TeleportEntity(ent, vecOrigin, vecAngles, vecAngles);
		SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", client);
		SetEntProp(ent, Prop_Data, "m_nNextThinkTick", 1); //for smoke
		SetEntProp(ent, Prop_Data, "m_takedamage", 2);
		SetEntProp(ent, Prop_Data, "m_iHealth", 1);
		SetEntProp(ent, Prop_Data, "m_usSolidFlags", 0);
		SetEntProp(ent, Prop_Data, "m_nSolidType", 0);
		g_ClientBombs[client] = EntIndexToEntRef(ent);
		//new Handle:bomberPack;
		//CreateDataTimer(0.0 , Timer_DetonatePeriod, bomberPack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);	
		CreateTimer(0.03, Timer_DetonatePeriod, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        
        // WritePackCell(bomberPack, client);
        // WritePackCell(bomberPack, ent);

		if (DispatchSpawn(ent)) {
			YellDetonateSound(client);
			//PrintToChatAll("\x05Suicide Bomber detonated bomb.");
			
			DealDamage(ent,304,client,DMG_BLAST,"weapon_c4_ied");
		}
	}
}
public Action:Event_PlayerDeathPre(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:weaponCheck[64];
	GetEventString(event, "weapon", weaponCheck, sizeof(weaponCheck)); 
	if(StrEqual(weaponCheck, "grenade_ied", false))
	{
		SetEventString(event, "weapon", "IED");
	}
}
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Float:fExplosiveDeathChance = GetConVarFloat(cvarExplosiveDeathChance);
	new Float:fDeathChance = GetConVarFloat(cvarDeathChance);
	
	new Float:fRandom = GetRandomFloat(0.0, 1.0);
	new victimId = GetEventInt(event, "userid");
	new victim = GetClientOfUserId(victimId);
	
	if ((StrContains(g_client_last_classstring[victim], "bomber") > -1) || (StrContains(g_client_last_classstring[victim], "suicider") > -1))
	{
		//PrintToServer("[SUICIDE] EventDeath: Victim ID is %d, g_isDetonating: %i",victimId, g_isDetonating);
		decl String:weapon[32];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		if (victim > 0)
		{
			if (IsClientInGame(victim) && IsFakeClient(victim) && g_isDetonating[victim] != 1)
			{
				if (fRandom < fDeathChance)
				{	
					CheckExplodeDeath(victim);
				}
				else if (StrEqual(weapon, "grenade_m67", false) || 
					StrEqual(weapon, "grenade_f1", false) || 
					StrEqual(weapon, "grenade_ied", false) || 
					StrEqual(weapon, "grenade_c4", false) || 
					StrEqual(weapon, "rocket_rpg7", false) || 
					StrEqual(weapon, "rocket_at4", false) || 
					StrEqual(weapon, "grenade_gp25_he", false) || 
					StrEqual(weapon, "grenade_m203_he", false) ||
					StrEqual(weapon, "grenade_anm14", false) || 
					StrEqual(weapon, "grenade_molotov", false))
				{
					if (fRandom < fExplosiveDeathChance)
					{
						CheckExplodeDeath(victim);
					}
				}
			}
			else if(IsClientInGame(victim) && (g_isDetonating[victim] != 1) && (g_nSuiciderClass == 0) && (g_bAutoSuicide))
			{
				CheckExplodeDeath(victim);
			}
		}
	}
	
	if(victim == g_nSuiciderClass)
	{
		g_nSuiciderClass = 0;
	}
	
	g_isDetonating[victim] = 0;
	
	return Plugin_Continue;
}
public CheckExplodeDeath(client) {
	//new m_iSquad = GetEntProp(client, Prop_Send, "m_iSquad");
	//new m_iSquadSlot = GetEntProp(client, Prop_Send, "m_iSquadSlot");
	//new Float:fDeathChance = GetConVarFloat(cvarDeathChance);
	//new Float:fExplosiveDeathChance = GetConVarFloat(cvarExplosiveDeathChance);
	
	//PrintToServer("[SUICIDE] Running CheckExplodeDEATH for client %d name %N squad %d squadslot %d",client,client,m_iSquad,m_iSquadSlot);

	//PrintToServer("[SUICIDE] Blowing Up %N with class %s!",client,g_client_last_classstring[client]);
	
	//Assign random variable first
	//new String:shotWeapName[32];
	
	new Float:vecOrigin[3],Float:vecAngles[3];
	GetClientEyePosition(client, vecOrigin);

	new ent;
	if(!IsFakeClient(client))
	{
		ent = CreateEntityByName("grenade_c4");
	}
	else
	{
		ent = CreateEntityByName("grenade_ied");
	}
	
	if(IsValidEntity(ent))
	{
		//PrintToServer("[SUICIDE] Created IED entity");
		vecAngles[0] = vecAngles[1] = vecAngles[2] = 0.0;
		TeleportEntity(ent, vecOrigin, vecAngles, vecAngles);
		SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", client);
		SetEntProp(ent, Prop_Data, "m_nNextThinkTick", 1); //for smoke
		SetEntProp(ent, Prop_Data, "m_takedamage", 2);
		SetEntProp(ent, Prop_Data, "m_iHealth", 1);
		SetEntProp(ent, Prop_Data, "m_usSolidFlags", 0);
		SetEntProp(ent, Prop_Data, "m_nSolidType", 0);
		g_ClientBombs[client] = EntIndexToEntRef(ent);
		//new Handle:bomberPack;
		//CreateDataTimer(0.0 , Timer_DetonatePeriod, bomberPack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);	
		if(!IsFakeClient(client))
		{
			CreateTimer(0.03, Timer_DetonatePeriodPlayer, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			CreateTimer(0.03, Timer_DetonatePeriod, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
        //WritePackCell(bomberPack, client);
        //WritePackCell(bomberPack, ent);
		
		if (DispatchSpawn(ent)) {
			//PrintToServer("[SUICIDE] Detonating IED entity");
			
			YellDetonateSound(client);
			//PrintToChatAll("\x05Suicide Bomber detonated bomb.");
			
			DealDamage(ent,280,client,DMG_BLAST,"weapon_c4_ied");
		}
	}
}

DealDamage(victim,damage,attacker=0,dmg_type=DMG_GENERIC,String:weapon[]="")
{
	if(victim>0 && IsValidEdict(victim) && damage>0)
	{
		decl String:dmg_str[16];
		IntToString(damage,dmg_str,16);
		decl String:dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		new pointHurt=CreateEntityByName("point_hurt");
		if(pointHurt)
		{
			DispatchKeyValue(victim,"targetname","hurtme");
			DispatchKeyValue(pointHurt,"DamageTarget","hurtme");
			DispatchKeyValue(pointHurt,"Damage",dmg_str);
			DispatchKeyValue(pointHurt,"DamageType",dmg_type_str);
			if(!StrEqual(weapon,""))
			{
				DispatchKeyValue(pointHurt,"classname",weapon);
			}
			DispatchSpawn(pointHurt);
			AcceptEntityInput(pointHurt,"Hurt",(attacker>0)?attacker:-1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			DispatchKeyValue(victim,"targetname","donthurtme");
			RemoveEdict(pointHurt);
		}
	}

}

public Action:YellRomaingSound(client) {
	// statics
	static idx_Sound = -1;
	// static voice = false;

	// decide on voice or sound
	new idx_Old = idx_Sound;
	idx_Sound = GetRandomInt(0, sizeof(RoamingSounds) - 1);

	//PrintToServer("[SUICIDE] Sound ID: Old %d, New %d", idx_Old, idx_Sound);

	// prevent playing the same sound in a row
	if (idx_Old == idx_Sound) {
		return YellRomaingSound(client);
	} else {
		EmitSoundToAll(RoamingSounds[idx_Sound], client);
	}
	
	return Plugin_Continue;
}
YellDetonateSound(client) {
	//EmitSoundToAll("weapons/ied/handling/ied_trigger_ins.wav", client, SNDCHAN_VOICE, _, _, 1.0);
	new idx_Sound = -1;
	idx_Sound = GetRandomInt(0, sizeof(DetonateYellSounds) - 1);

	EmitSoundToAll(DetonateYellSounds[idx_Sound], client);
}