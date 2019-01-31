#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new g_iPlayerEquipGear;
int nClientSupplier = 0;
int nDefaultResupplyPenalty;
int nDefaultResupplyBase;
int g_nReducePenalty = 0;
int nBackpackTheaterID1 = 37;
int nBackpackTheaterID2 = 38;
bool bSupplyDestroyCacheOnly = false;

public Plugin:myinfo = {
    name = "[INS] Backpack Resupply",
    description = "Resupply handle depend on player backpack",
    author = "Neko- (Linothorax)",
    version = "1.2.0",
}

new const String:BlacklistWeaponNames[][] =
{
	"weapon_kabar",
	"weapon_gurkha",
	"weapon_knife",
	"weapon_kukri",
	"weapon_katana",
	"weapon_c4_clicker",
	"weapon_c4_clickers",
	"weapon_c4_ied",
	"weapon_rpg7",
	"weapon_rpg7s",
	"weapon_at4",
	"weapon_at4s",
	"weapon_p2a1"
}

new const String:GrenadeWeaponNames[][] =
{
	"weapon_m67",
	"weapon_f1",
	"weapon_gas_grenade",
	"weapon_anm14",
	"weapon_molotov",
	"weapon_m18",
	"weapon_m84"
}

new const String:GLWeaponNames[][] =
{
	"grenade_m203_he",
	"grenade_gp25_he",
	"grenade_m203_flash",
	"grenade_gp25_flash",
	"grenade_m203_incid",
	"grenade_gp25_incid",
	"grenade_m203_smoke",
	"grenade_gp25_smoke"
}

public OnPluginStart() 
{
	//Find player gear offset
	g_iPlayerEquipGear = FindSendPropInfo("CINSPlayer", "m_EquippedGear");
	
	HookEvent("player_spawn", Event_PlayerRespawn);
	HookEvent("player_pick_squad", Event_PlayerPickSquad_Post);
	HookEvent("object_destroyed", Event_ObjectDestroyed);
	HookEvent("round_start", Event_RoundStart);
	
	RegConsoleCmd("giveresupply", GiveSupply, "Give player magazine");
	
	AddCommandListener(ResupplyListener, "inventory_resupply");
	AddCommandListener(BlockResupplyListener, "inventory_confirm");
}

public void OnMapStart()
{
	//Get default
	ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
	nDefaultResupplyPenalty = GetConVarInt(cvarResupplyPenalty);
	
	ConVar cvarResupplyBase = FindConVar("mp_player_resupply_coop_delay_base");
	nDefaultResupplyBase = GetConVarInt(cvarResupplyBase);
	
	g_nReducePenalty = 0;
}

public void OnMapEnd()
{
	ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
	ConVar cvarResupplyBase = FindConVar("mp_player_resupply_coop_delay_base");
	
	int nResupplyBaseFlags = GetConVarFlags(cvarResupplyBase);
	int nResupplyPenaltyFlags = GetConVarFlags(cvarResupplyPenalty);
	
	SetConVarFlags(cvarResupplyBase, nResupplyBaseFlags & ~FCVAR_NOTIFY);
	SetConVarFlags(cvarResupplyPenalty, nResupplyPenaltyFlags & ~FCVAR_NOTIFY);
	
	SetConVarInt(cvarResupplyBase, nDefaultResupplyBase);
	SetConVarInt(cvarResupplyPenalty, nDefaultResupplyPenalty);
}

public OnClientDisconnect(client)
{
	if(client == nClientSupplier)
	{
		nClientSupplier = 0;
		bSupplyDestroyCacheOnly = false;
		
		ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
		ConVar cvarResupplyBase = FindConVar("mp_player_resupply_coop_delay_base");
		
		int nResupplyBaseFlags = GetConVarFlags(cvarResupplyBase);
		int nResupplyPenaltyFlags = GetConVarFlags(cvarResupplyPenalty);
		
		SetConVarFlags(cvarResupplyBase, nResupplyBaseFlags & ~FCVAR_NOTIFY);
		SetConVarFlags(cvarResupplyPenalty, nResupplyPenaltyFlags & ~FCVAR_NOTIFY);
		
		SetConVarInt(cvarResupplyBase, nDefaultResupplyBase);
		SetConVarInt(cvarResupplyPenalty, nDefaultResupplyPenalty);
	}
}

public Event_PlayerPickSquad_Post(Handle:event, const String:name[], bool:dontBroadcast )
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!IsFakeClient(client))
	{
		decl String:class_template[64];
		GetEventString(event, "class_template",class_template,sizeof(class_template));
		//PrintToChat(client, "[Flare Debug by Circleus] Player: True;\nClass: %s", class_template);
		
		if(StrContains(class_template, "supplier") > -1)
		{
			nClientSupplier = client;
			bSupplyDestroyCacheOnly = true;
		}
		
		if((client == nClientSupplier) && (StrContains(class_template, "supplier") == -1))
		{
			nClientSupplier = 0;
			bSupplyDestroyCacheOnly = false;
			
			ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
			ConVar cvarResupplyBase = FindConVar("mp_player_resupply_coop_delay_base");
			
			int nResupplyBaseFlags = GetConVarFlags(cvarResupplyBase);
			int nResupplyPenaltyFlags = GetConVarFlags(cvarResupplyPenalty);
			
			SetConVarFlags(cvarResupplyBase, nResupplyBaseFlags & ~FCVAR_NOTIFY);
			SetConVarFlags(cvarResupplyPenalty, nResupplyPenaltyFlags & ~FCVAR_NOTIFY);
			
			SetConVarInt(cvarResupplyBase, nDefaultResupplyBase);
			SetConVarInt(cvarResupplyPenalty, nDefaultResupplyPenalty);
		}
	}
}

public Action:Event_PlayerRespawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(client == nClientSupplier)
	{
		//Get player backpack item (4th offset with a DWORD(4 bytes))
		new nBackpackID = GetEntData(client, g_iPlayerEquipGear + (4 * 5));
		
		if(nBackpackID == nBackpackTheaterID1)
		{
			ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
			int nResupplyPenaltyFlags = GetConVarFlags(cvarResupplyPenalty);
			SetConVarFlags(cvarResupplyPenalty, nResupplyPenaltyFlags & ~FCVAR_NOTIFY);

			int nPenalty;
			if(g_nReducePenalty > 100)
			{
				nPenalty = 0;
			}
			else
			{
				nPenalty = 100 - g_nReducePenalty;
			}
			
			SetConVarInt(cvarResupplyPenalty, nPenalty);
		}
		else if(nBackpackID == nBackpackTheaterID2)
		{
			ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
			ConVar cvarResupplyBase = FindConVar("mp_player_resupply_coop_delay_base");
			
			int nResupplyBaseFlags = GetConVarFlags(cvarResupplyBase);
			int nResupplyPenaltyFlags = GetConVarFlags(cvarResupplyPenalty);
			
			SetConVarFlags(cvarResupplyBase, nResupplyBaseFlags & ~FCVAR_NOTIFY);
			SetConVarFlags(cvarResupplyPenalty, nResupplyPenaltyFlags & ~FCVAR_NOTIFY);
			
			int nPenalty;
			if(g_nReducePenalty > 60)
			{
				nPenalty = 0;
			}
			else
			{
				nPenalty = 60 - g_nReducePenalty;
			}
			
			SetConVarInt(cvarResupplyBase, 30);
			SetConVarInt(cvarResupplyPenalty, nPenalty);
		}
		else
		{
			ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
			ConVar cvarResupplyBase = FindConVar("mp_player_resupply_coop_delay_base");
			
			int nResupplyBaseFlags = GetConVarFlags(cvarResupplyBase);
			int nResupplyPenaltyFlags = GetConVarFlags(cvarResupplyPenalty);
			
			SetConVarFlags(cvarResupplyBase, nResupplyBaseFlags & ~FCVAR_NOTIFY);
			SetConVarFlags(cvarResupplyPenalty, nResupplyPenaltyFlags & ~FCVAR_NOTIFY);
			
			SetConVarInt(cvarResupplyBase, nDefaultResupplyBase);
			SetConVarInt(cvarResupplyPenalty, nDefaultResupplyPenalty);
		}
	}
}

public Action:BlockResupplyListener(client, const String:cmd[], argc)
{
	if((IsValidClient(client)) && (client == nClientSupplier))
	{
		//Get player backpack item (4th offset with a DWORD(4 bytes))
		new nBackpackID = GetEntData(client, g_iPlayerEquipGear + (4 * 5));
		
		if(nBackpackID == nBackpackTheaterID1)
		{
			ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
			int nResupplyPenaltyFlags = GetConVarFlags(cvarResupplyPenalty);
			SetConVarFlags(cvarResupplyPenalty, nResupplyPenaltyFlags & ~FCVAR_NOTIFY);

			int nPenalty;
			if(g_nReducePenalty > 100)
			{
				nPenalty = 0;
			}
			else
			{
				nPenalty = 100 - g_nReducePenalty;
			}
			
			SetConVarInt(cvarResupplyPenalty, nPenalty);
		}
		else if(nBackpackID == nBackpackTheaterID2)
		{
			ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
			ConVar cvarResupplyBase = FindConVar("mp_player_resupply_coop_delay_base");
			
			int nResupplyBaseFlags = GetConVarFlags(cvarResupplyBase);
			int nResupplyPenaltyFlags = GetConVarFlags(cvarResupplyPenalty);
			
			SetConVarFlags(cvarResupplyBase, nResupplyBaseFlags & ~FCVAR_NOTIFY);
			SetConVarFlags(cvarResupplyPenalty, nResupplyPenaltyFlags & ~FCVAR_NOTIFY);
			
			int nPenalty;
			if(g_nReducePenalty > 60)
			{
				nPenalty = 0;
			}
			else
			{
				nPenalty = 60 - g_nReducePenalty;
			}
			
			SetConVarInt(cvarResupplyBase, 30);
			SetConVarInt(cvarResupplyPenalty, nPenalty);
		}
		else
		{
			ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
			ConVar cvarResupplyBase = FindConVar("mp_player_resupply_coop_delay_base");
			
			int nResupplyBaseFlags = GetConVarFlags(cvarResupplyBase);
			int nResupplyPenaltyFlags = GetConVarFlags(cvarResupplyPenalty);
			
			SetConVarFlags(cvarResupplyBase, nResupplyBaseFlags & ~FCVAR_NOTIFY);
			SetConVarFlags(cvarResupplyPenalty, nResupplyPenaltyFlags & ~FCVAR_NOTIFY);
			
			SetConVarInt(cvarResupplyBase, nDefaultResupplyBase);
			SetConVarInt(cvarResupplyPenalty, nDefaultResupplyPenalty);
		}
	}
	
	return Plugin_Continue;
}

public Action:ResupplyListener(client, const String:cmd[], argc)
{	
	if((IsValidClient(client)) && (client == nClientSupplier))
	{
		//Get player backpack item (4th offset with a DWORD(4 bytes))
		new nBackpackID = GetEntData(client, g_iPlayerEquipGear + (4 * 5));
		
		if(nBackpackID == nBackpackTheaterID1)
		{
			ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
			int nResupplyPenaltyFlags = GetConVarFlags(cvarResupplyPenalty);
			SetConVarFlags(cvarResupplyPenalty, nResupplyPenaltyFlags & ~FCVAR_NOTIFY);

			int nPenalty;
			if(g_nReducePenalty > 100)
			{
				nPenalty = 0;
			}
			else
			{
				nPenalty = 100 - g_nReducePenalty;
			}
			
			SetConVarInt(cvarResupplyPenalty, nPenalty);
		}
		else if(nBackpackID == nBackpackTheaterID2)
		{
			ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
			ConVar cvarResupplyBase = FindConVar("mp_player_resupply_coop_delay_base");
			
			int nResupplyBaseFlags = GetConVarFlags(cvarResupplyBase);
			int nResupplyPenaltyFlags = GetConVarFlags(cvarResupplyPenalty);
			
			SetConVarFlags(cvarResupplyBase, nResupplyBaseFlags & ~FCVAR_NOTIFY);
			SetConVarFlags(cvarResupplyPenalty, nResupplyPenaltyFlags & ~FCVAR_NOTIFY);
			
			int nPenalty;
			if(g_nReducePenalty > 60)
			{
				nPenalty = 0;
			}
			else
			{
				nPenalty = 60 - g_nReducePenalty;
			}
			
			SetConVarInt(cvarResupplyBase, 30);
			SetConVarInt(cvarResupplyPenalty, nPenalty);
		}
		else
		{
			ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
			ConVar cvarResupplyBase = FindConVar("mp_player_resupply_coop_delay_base");
			
			int nResupplyBaseFlags = GetConVarFlags(cvarResupplyBase);
			int nResupplyPenaltyFlags = GetConVarFlags(cvarResupplyPenalty);
			
			SetConVarFlags(cvarResupplyBase, nResupplyBaseFlags & ~FCVAR_NOTIFY);
			SetConVarFlags(cvarResupplyPenalty, nResupplyPenaltyFlags & ~FCVAR_NOTIFY);
			
			SetConVarInt(cvarResupplyBase, nDefaultResupplyBase);
			SetConVarInt(cvarResupplyPenalty, nDefaultResupplyPenalty);
		}
	}
	
	return Plugin_Continue;
}

public Action:Event_ObjectDestroyed(Handle:event, const String:name[], bool:dontBroadcast)
{
	int nAttacker = GetEventInt(event, "attacker");
	if(nAttacker == nClientSupplier)
	{
		new nBackpackID = GetEntData(nClientSupplier, g_iPlayerEquipGear + (4 * 5));
		if((nBackpackID == nBackpackTheaterID1) || (nBackpackID == nBackpackTheaterID2))
		{
			int nTempPenalty = GetRandomInt(5, 10);
			g_nReducePenalty += nTempPenalty;
			PrintHintTextToAll("Supplier destroyed a cache\nResupply penalty reduced %i seconds permanently", nTempPenalty);
			
			if(nBackpackID == nBackpackTheaterID1)
			{
				ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
				int nResupplyPenaltyFlags = GetConVarFlags(cvarResupplyPenalty);
				SetConVarFlags(cvarResupplyPenalty, nResupplyPenaltyFlags & ~FCVAR_NOTIFY);

				int nPenalty;
				if(g_nReducePenalty > 100)
				{
					nPenalty = 0;
				}
				else
				{
					nPenalty = 100 - g_nReducePenalty;
				}
				
				SetConVarInt(cvarResupplyPenalty, nPenalty);
			}
			else if(nBackpackID == nBackpackTheaterID2)
			{
				ConVar cvarResupplyPenalty = FindConVar("mp_player_resupply_coop_delay_penalty");
				ConVar cvarResupplyBase = FindConVar("mp_player_resupply_coop_delay_base");
				
				int nResupplyBaseFlags = GetConVarFlags(cvarResupplyBase);
				int nResupplyPenaltyFlags = GetConVarFlags(cvarResupplyPenalty);
				
				SetConVarFlags(cvarResupplyBase, nResupplyBaseFlags & ~FCVAR_NOTIFY);
				SetConVarFlags(cvarResupplyPenalty, nResupplyPenaltyFlags & ~FCVAR_NOTIFY);
				
				int nPenalty;
				if(g_nReducePenalty > 60)
				{
					nPenalty = 0;
				}
				else
				{
					nPenalty = 60 - g_nReducePenalty;
				}
				
				SetConVarInt(cvarResupplyBase, 30);
				SetConVarInt(cvarResupplyPenalty, nPenalty);
			}
		}
	}
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	SearchAllCache();
}

void SearchAllCache()
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
				SDKHook(ent, SDKHook_OnTakeDamage, OnCacheTakeDamage);
				continue;
			}
		}
		i = 0;
	}
}

public Action:OnCacheTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	//PrintToChatAll("Damage: %f", damage);

	/* Reference LIST this was done using the theater you are using, but maybe damages might be off ~
	f1 = 181.0 ~
	molotov = 15.0 ~ per second
	m26a2 = 180.0 ~
	m67 = 180.0 ~
	anm14 = 81.0 ~ init 35.0 per second at end of life 38.0 per second
	c4 = 262.0 ~
	ied = 260.0 ~
	rpg = 218.0 ~
	law = 291.0 ~
	at4 = 290.0 ~
	*/

	//64 blast
	//2056 fire
	//PrintToChatAll("damagetype : %i", damagetype);
	
	char strCache[64];
	GetEdictClassname(victim, strCache, sizeof(strCache));

	if(StrEqual(strCache,"obj_weapon_cache"))
	{
		if(IsValidEdict(victim) && IsValidClient(attacker))
		{
			if(GetEntProp(victim, Prop_Data, "m_lifeState") == 0)
			{
				if((bSupplyDestroyCacheOnly) && (nClientSupplier != 0) && (nClientSupplier == attacker) && (IsPlayerAlive(nClientSupplier)))
				{
					//Only supplier can destroy cache when supplier present
					return Plugin_Continue;
				}
				else if((!bSupplyDestroyCacheOnly) || (nClientSupplier == 0) || (!IsPlayerAlive(nClientSupplier)))
				{
					//Anyone can destroy if supplier not present
					return Plugin_Continue;
				}
				else
				{
					PrintHintText(attacker, "Only supplier can destroy the cache");
					damage = 0.0
					return Plugin_Handled;
				}
			}
			else
			{
				SDKUnhook(victim, SDKHook_OnTakeDamage, OnCacheTakeDamage);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:GiveSupply(client, args)
{
	new nBackpackID = GetEntData(nClientSupplier, g_iPlayerEquipGear + (4 * 5));
	
	if((client == nClientSupplier) && (IsPlayerAlive(client)) && ((nBackpackID == nBackpackTheaterID1) || (nBackpackID == nBackpackTheaterID2)))
	{
		int clientTarget = GetClientAimTarget(client, true);
		
		if((clientTarget > -1) && (IsPlayerAlive(clientTarget)) && (!IsFakeClient(clientTarget)))
		{
			float fDistance = GetDistance(client, clientTarget);
			
			decl String:szTargetName[64];
			GetClientName(clientTarget, szTargetName, sizeof(szTargetName));
			
			if((fDistance != 0.000) && (fDistance <= 70.0))
			{
				new CurrentUserWeapon1 = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
				if (CurrentUserWeapon1 < 0) {
					PrintHintText(client, "You don't have any weapon");
					return Plugin_Handled;
				}
				
				new CurrentUserWeapon2 = GetEntPropEnt(clientTarget, Prop_Send, "m_hActiveWeapon");
				if (CurrentUserWeapon2 < 0) {
					PrintHintText(client, "%s don't have any weapon", szTargetName);
					return Plugin_Handled;
				}
				
				decl String:User_Weapon1[32];
				GetEdictClassname(CurrentUserWeapon1, User_Weapon1, sizeof(User_Weapon1));
				decl String:User_Weapon2[32];
				GetEdictClassname(CurrentUserWeapon2, User_Weapon2, sizeof(User_Weapon2));
				for(new count=0; count<sizeof(BlacklistWeaponNames); count++)
				{
					if((StrEqual(User_Weapon1, BlacklistWeaponNames[count])) || (StrEqual(User_Weapon2, BlacklistWeaponNames[count])))
					{
						PrintHintText(client, "You can't resupply that weapon");
						PrintHintText(clientTarget, "Supplier can't resupply that weapon");
						return Plugin_Handled;
					}
				}
				
				new PrimaryAmmoType1 = GetEntProp(CurrentUserWeapon1, Prop_Data, "m_iPrimaryAmmoType");
				new PrimaryAmmoType2 = GetEntProp(CurrentUserWeapon2, Prop_Data, "m_iPrimaryAmmoType");
				if((PrimaryAmmoType1 == -1) || (PrimaryAmmoType2 == -1))
				{
					return Plugin_Handled;
				}
				
				int AmmoAmount1 = GetEntProp(client, Prop_Send, "m_iAmmo", _, PrimaryAmmoType1);
				int AmmoAmount2 = GetEntProp(clientTarget, Prop_Send, "m_iAmmo", _, PrimaryAmmoType2);
				
				if(AmmoAmount1 <= 1)
				{
					PrintHintText(client, "You don't have any supply to give to your teammate");
					return Plugin_Handled;
				}
				else
				{
					for(new count=0; count<sizeof(GrenadeWeaponNames); count++)
					{
						if((StrEqual(User_Weapon2, GrenadeWeaponNames[count])) && (AmmoAmount2 > 3))
						{
							PrintHintText(client, "%s can't have any more grenade", szTargetName);
							PrintHintText(clientTarget, "you can't resupply any more grenade");
							return Plugin_Handled;
						}
					}
					
					for(new count=0; count<sizeof(GLWeaponNames); count++)
					{
						if((StrEqual(User_Weapon2, GLWeaponNames[count])) && (AmmoAmount2 > 4))
						{
							PrintHintText(client, "%s can't have any more grenade launcher", szTargetName);
							PrintHintText(clientTarget, "you can't resupply any more grenade launcher");
							return Plugin_Handled;
						}
					}
					
					for(new count=0; count<sizeof(GrenadeWeaponNames); count++)
					{
						if((StrEqual(User_Weapon1, GrenadeWeaponNames[count])) && (AmmoAmount1 == 1))
						{
							PrintHintText(client, "You don't have any supply to give to your teammate");
							return Plugin_Handled;
						}
					}
					
					if(StrEqual(User_Weapon1, "weapon_model10"))
					{
						if(AmmoAmount1 > 7)
						{
							SetEntProp(client, Prop_Send, "m_iAmmo", AmmoAmount1 - 6, _, PrimaryAmmoType1);
						}
						else
						{
							PrintHintText(client, "You don't have any supply to give to your teammate");
							return Plugin_Handled;
						}
					}
					else if((StrEqual(User_Weapon2, "weapon_m67")) || (StrEqual(User_Weapon2, "weapon_f1")) || (StrEqual(User_Weapon2, "weapon_gas_grenade")) || (StrEqual(User_Weapon2, "weapon_anm14")) || (StrEqual(User_Weapon2, "weapon_molotov")) || (StrEqual(User_Weapon2, "weapon_m18")) || (StrEqual(User_Weapon2, "weapon_m84")))
					{
						SetEntProp(client, Prop_Send, "m_iAmmo", AmmoAmount1 - 1, _, PrimaryAmmoType1);
					}
					else
					{
						int nRoundAmount1 = GetEntProp(CurrentUserWeapon1, Prop_Send, "m_iClip1");
						if(nRoundAmount1 >= 1)
						{
							SetEntProp(CurrentUserWeapon1, Prop_Send, "m_iClip1", 0);
						}
						else
						{
							PrintHintText(client, "You don't have any rounds left to give to resupply teammate");
							return Plugin_Handled;
						}
					}
					
					PrintHintText(client, "You resupplied your teammate");
					
					if(StrEqual(User_Weapon2, "weapon_model10"))
					{
						SetEntProp(clientTarget, Prop_Send, "m_iAmmo", AmmoAmount2 + 6, _, PrimaryAmmoType2);
						PrintHintText(clientTarget, "You received a mag from your supplier");
					}
					else if(StrEqual(User_Weapon2, "weapon_m590"))
					{
						SetEntProp(clientTarget, Prop_Send, "m_iAmmo", AmmoAmount2 + 8, _, PrimaryAmmoType2);
						PrintHintText(clientTarget, "You received a mag from your supplier");
					}
					else if(StrEqual(User_Weapon2, "weapon_toz"))
					{
						SetEntProp(clientTarget, Prop_Send, "m_iAmmo", AmmoAmount2 + 6, _, PrimaryAmmoType2);
						PrintHintText(clientTarget, "You received a mag from your supplier");
					}
					else if(StrEqual(User_Weapon2, "weapon_m40a1"))
					{
						SetEntProp(clientTarget, Prop_Send, "m_iAmmo", AmmoAmount2 + 5, _, PrimaryAmmoType2);
						PrintHintText(clientTarget, "You received a mag from your supplier");
					}
					else if(StrEqual(User_Weapon2, "weapon_mosin"))
					{
						SetEntProp(clientTarget, Prop_Send, "m_iAmmo", AmmoAmount2 + 5, _, PrimaryAmmoType2);
						PrintHintText(clientTarget, "You received a mag from your supplier");
					}
					else if((StrEqual(User_Weapon2, "weapon_m67")) || (StrEqual(User_Weapon2, "weapon_f1")) || (StrEqual(User_Weapon2, "weapon_gas_grenade")) || (StrEqual(User_Weapon2, "weapon_anm14")) || (StrEqual(User_Weapon2, "weapon_molotov")) || (StrEqual(User_Weapon2, "weapon_m18")) || (StrEqual(User_Weapon2, "weapon_m84")))
					{
						SetEntProp(clientTarget, Prop_Send, "m_iAmmo", AmmoAmount2 + 1, _, PrimaryAmmoType2);
						PrintHintText(clientTarget, "You received a grenade from your supplier");
					}
					else if((StrEqual(User_Weapon2, "weapon_m203_he")) || (StrEqual(User_Weapon2, "weapon_gp25_he")) || (StrEqual(User_Weapon2, "weapon_m203_flash")) || (StrEqual(User_Weapon2, "weapon_gp25_flash")) || (StrEqual(User_Weapon2, "weapon_m203_incid")) || (StrEqual(User_Weapon2, "weapon_gp25_incid")) || (StrEqual(User_Weapon2, "weapon_m203_smoke")) || (StrEqual(User_Weapon2, "weapon_gp25_smoke")))
					{
						SetEntProp(clientTarget, Prop_Send, "m_iAmmo", AmmoAmount2 + 1, _, PrimaryAmmoType2);
						PrintHintText(clientTarget, "You received a grenade launcher from your supplier");
					}
					else
					{
						int nRandomRound = GetRandomInt(5, 20);
						int nRoundAmount2 = GetEntProp(CurrentUserWeapon2, Prop_Send, "m_iClip1");
						SetEntProp(CurrentUserWeapon2, Prop_Send, "m_iClip1", nRoundAmount2 + nRandomRound);
						
						PrintHintText(clientTarget, "You received %i rounds from your supplier", nRandomRound);
					}
				}
			}
			else
			{
				PrintHintText(client, "%s is too far", szTargetName);
			}
		}
		else
		{
			PrintHintText(client, "No player nearby");
			return Plugin_Handled;
		}
	}
	else if((client == nClientSupplier) && ((nBackpackID != nBackpackTheaterID1) || (nBackpackID != nBackpackTheaterID2)))
	{
		PrintHintText(client, "You can't give resupply without backpack");
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

bool:IsValidClient(client) 
{
	if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
		return false; 
	
	return true; 
}  