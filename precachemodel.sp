#include <sourcemod> 
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "[INS] Precache Model",
    description = "PrecacheModel",
    author = "Neko-",
    version = "1.0.0",
};

public OnMapStart()
{
	PrecacheModel("models/weapons/v_m18i.mdl", true);
	PrecacheModel("models/weapons/w_m18i.mdl", true);
	PrecacheModel("models/weapons/v_m67i.mdl", true);
	PrecacheModel("models/weapons/w_m67i.mdl", true);
	PrecacheModel("models/weapons/v_f1i.mdl", true);
	PrecacheModel("models/weapons/w_f1i.mdl", true);
	PrecacheModel("models/weapons/v_x4_ins.mdl", true);
	PrecacheModel("models/weapons/w_xed.mdl", true);
	
	PrecacheModel("models/characters/witchhat.mdl", true);
	PrecacheModel("models/characters/santahat.mdl", true);
	PrecacheModel("models/characters/skeleton.mdl", true);
	PrecacheModel("models/characters/2b.mdl", true);
	PrecacheModel("models/characters/shirakami.mdl", true);
}