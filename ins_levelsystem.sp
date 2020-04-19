#include <sourcemod>
#include <sdktools>
#include <ins_levelsystem>

#define PLUGIN_DESCRIPTION "Level System"
#define PLUGIN_NAME "[INS] Level System"
#define PLUGIN_VERSION "1.0.3"
#define PLUGIN_AUTHOR "Neko-"

#define INS_LEVELSYSTEM

public Plugin:myinfo = {
	name            = PLUGIN_NAME,
	author          = PLUGIN_AUTHOR,
	description     = PLUGIN_DESCRIPTION,
	version         = PLUGIN_VERSION,
};

int g_nPlayerResource;
int g_nPlayerScore;
static String:strLevelSystemPath[PLATFORM_MAX_PATH];
new Handle:hLevelSystemFile = INVALID_HANDLE;

new Handle:cvarScoreRequireBaseLevel = INVALID_HANDLE;
new Handle:cvarScoreRequirePerLevel = INVALID_HANDLE;
new Handle:cvarMaxLevel = INVALID_HANDLE;
int g_nScoreRequireBaseLevel;
int g_nScoreRequirePerLevel;
int g_nMaxLevel;

new g_nCurrentPlayerScore[MAXPLAYERS+1] = {0, ...};
bool g_bPlayerLoaded[MAXPLAYERS+1] = {false, ...};
new g_nCurrentPlayerPenaltyScore[MAXPLAYERS+1] = {0, ...};

//Creating a lib so other plugins can use this plugin
public APLRes:Plugin_Setup_natives()
{
	CreateNative("LS_GetClientScore", Native_GetClientScore);
	CreateNative("LS_GetClientRank", Native_GetClientRank);
	CreateNative("LS_AddClientScore", Native_AddClientScore);
	CreateNative("LS_RemoveClientScore", Native_RemoveClientScore);
	CreateNative("LS_AddClientScorePenalty", Native_AddClientScorePenalty);
	CreateNative("LS_RemoveClientScorePenalty", Native_RemoveClientScorePenalty);

	return APLRes_Success;
}

//Load lib
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("ins_levelsystem");
	return Plugin_Setup_natives();
}

public OnPluginStart() 
{
	//Get Player score
	g_nPlayerResource = FindEntityByClassname(-1, "ins_player_manager");
	g_nPlayerScore = FindSendPropInfo("CINSPlayerResource", "m_iPlayerScore");
	
	//Creating cvar
	cvarScoreRequireBaseLevel = CreateConVar("lv_score_base_level", "2000", "Score that start with for the first level", FCVAR_PROTECTED);
	cvarScoreRequirePerLevel = CreateConVar("lv_score_per_level", "1000", "Extra score that require for each level to level up", FCVAR_PROTECTED);
	cvarMaxLevel = CreateConVar("lv_max_level", "100", "Max level the player can get", FCVAR_PROTECTED);
	
	//Hook cvar to variable
	g_nScoreRequireBaseLevel = GetConVarInt(cvarScoreRequireBaseLevel);
	g_nScoreRequirePerLevel = GetConVarInt(cvarScoreRequirePerLevel);
	g_nMaxLevel = GetConVarInt(cvarMaxLevel);
	HookConVarChange(cvarScoreRequireBaseLevel, OnConVarChange);
	HookConVarChange(cvarScoreRequirePerLevel, OnConVarChange);
	HookConVarChange(cvarMaxLevel, OnConVarChange);
	
	//Commands
	RegConsoleCmd("level", Cmd_Level, "Check the amount of score you require for your next level");
	RegConsoleCmd("rank", Cmd_Level, "Check the amount of score you require for your next level");
	
	//Admin commands
	RegAdminCmd("setrank", Cmd_SetRank, ADMFLAG_KICK, "Allow admin to set their rank/level");
	RegAdminCmd("addrank", Cmd_AddRank, ADMFLAG_KICK, "Allow admin to add their rank/level");
	RegAdminCmd("addscore", Cmd_AddScore, ADMFLAG_KICK, "Allow admin to add score");
	RegAdminCmd("removescore", Cmd_RemoveScore, ADMFLAG_KICK, "Allow admin to remove score");
	RegAdminCmd("addpenalty", Cmd_AddPenalty, ADMFLAG_KICK, "Allow admin to add score penalty");
	RegAdminCmd("removepenalty", Cmd_RemovePenalty, ADMFLAG_KICK, "Allow admin to remove score penalty");
	
	HookEvent("player_changename", Event_PlayerChangename, EventHookMode_Pre);
	
	//Check plugins level folder and file
	LoadConfig();
	
	//Create if doesn't exist or load cvar file for this plugin
	AutoExecConfig(true,"ins.levelsystem");
	
	//Load all player level when plugin first load (This doesn't occur during map change, only when server start or using sm plugins load)
	LoadLevels();
}

/*
public OnPluginEnd() 
{
	SaveLevels();
}
*/

//When cvar change then change variable value
public OnConVarChange(Handle:hCVar, const String:oldValue[], const String:newValue[])
{
	if(hCVar == cvarScoreRequireBaseLevel) g_nScoreRequireBaseLevel = StringToInt(newValue);
	else if(hCVar == cvarScoreRequirePerLevel) g_nScoreRequirePerLevel = StringToInt(newValue);
	else if(hCVar == cvarMaxLevel) g_nMaxLevel = StringToInt(newValue);
}

//Load config function to create file and folder for level if it doesn't exist
void LoadConfig()
{
	if(hLevelSystemFile != INVALID_HANDLE)
	{
		CloseHandle(hLevelSystemFile);
	}
	hLevelSystemFile = CreateKeyValues("level_system");
	
	BuildPath(Path_SM, strLevelSystemPath, PLATFORM_MAX_PATH, "data/ins_levelsystem/levelsystem.json");
	if(!FileExists(strLevelSystemPath))
	{
		//Create folder
		decl String:strDirPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, strDirPath, sizeof(strDirPath), "data/ins_levelsystem");
		if(!DirExists(strDirPath))
			CreateDirectory(strDirPath, 755);
		
		//Create config file if it doesn't exist
		new Handle:hFileHandle;
		hFileHandle = OpenFile(strLevelSystemPath, "w+");
		CloseHandle(hFileHandle);
		
		//Save the first key value
		KeyValuesToFile(hLevelSystemFile, strLevelSystemPath);
	}
	
	FileToKeyValues(hLevelSystemFile, strLevelSystemPath);
}

//When map start get player resource to grab the player score
public OnMapStart()
{
	g_nPlayerResource = FindEntityByClassname(-1, "ins_player_manager");
	LoadConfig();
}

//When player join we set player rank in their name
public OnClientPostAdminCheck(client)
{
	decl String:strName[65];
	
	if(1 <= client <= MaxClients && !IsFakeClient(client))
	{
		g_nCurrentPlayerScore[client] = 0;
		g_nCurrentPlayerPenaltyScore[client] = 0;
		GetClientName(client, strName, sizeof(strName));
		SetNewName(client, strName);
	}
}

//When player disconnect we save their level
public OnClientDisconnect(client)
{
	if(1 <= client <= MaxClients && !IsFakeClient(client))
	{
		SaveClientLevel(client);
		g_bPlayerLoaded[client] = false;
	}
}


/*
=========================================
	NATIVE FOR PLUGINS (LIB)
=========================================
*/

public Native_GetClientScore(Handle:plugin, numParams) {
	int nClient = GetNativeCell(1);
	return g_nCurrentPlayerScore[nClient];
}

public Native_GetClientRank(Handle:plugin, numParams) {
	int nClient = GetNativeCell(1);
	int nRank = GetClientRank(g_nCurrentPlayerScore[nClient]);
	
	return nRank;
}

public Native_AddClientScore(Handle:plugin, numParams) {
	int nClient = GetNativeCell(1);
	int nScore = GetNativeCell(2);
	AddScore(nClient, nScore);
}

public Native_RemoveClientScore(Handle:plugin, numParams) {
	int nClient = GetNativeCell(1);
	int nScore = GetNativeCell(2);
	RemoveScore(nClient, nScore);
}

public Native_AddClientScorePenalty(Handle:plugin, numParams) {
	int nClient = GetNativeCell(1);
	int nScore = GetNativeCell(2);
	AddPenalty(nClient, nScore);
}

public Native_RemoveClientScorePenalty(Handle:plugin, numParams) {
	int nClient = GetNativeCell(1);
	int nScore = GetNativeCell(2);
	RemovePenalty(nClient, nScore);
}


/*
=========================================
	LOAD SAVE CLIENT SCORE
=========================================
*/

int LoadClientLevel(int client)
{
	new String:strAuth[64];
	GetClientAuthString(client, strAuth, sizeof(strAuth));
	
	//Check if strAuth contain STEAM_1 key
	if(strlen(strAuth) && strcmp(strAuth, "BOT", false) && strcmp(strAuth, "STEAM_ID_PENDING", false))
	{
		//SteamID exist so set player loaded to true
		g_bPlayerLoaded[client] = true;
		
		//Rewind to level system file beginning
		KvRewind(hLevelSystemFile);
		
		//Jump to player STEAM_1 key (If doesn't exit then create)
		if(KvJumpToKey(hLevelSystemFile, strAuth))
		{
			//Load player score (If doesn't exit then score is 0 as default)
			g_nCurrentPlayerScore[client] = KvGetNum(hLevelSystemFile, "score");
			KvGoBack(hLevelSystemFile);
			
			//Use GetClientRank function to return the right rank
			int nRank = GetClientRank(g_nCurrentPlayerScore[client]);
			
			return nRank;
		}
		else
		{
			return 0;
		}
	}
	
	return 0;
}

SaveClientLevel(int client)
{
	new String:strAuth[64];
	GetClientAuthString(client, strAuth, sizeof(strAuth));
	
	//Check if strAuth contain STEAM_1 key
	if(strlen(strAuth) && strcmp(strAuth, "BOT", false) && strcmp(strAuth, "STEAM_ID_PENDING", false) && g_bPlayerLoaded[client])
	{
		//Rewind to level system file beginning
		KvRewind(hLevelSystemFile);
		
		//Get current score from scoreboard
		int nCurrentScore = GetEntData(g_nPlayerResource, g_nPlayerScore + (4 * client));

		//Jump to player STEAM_1 key (If doesn't exit then create)
		if(KvJumpToKey(hLevelSystemFile, strAuth, true))
		{
			/*
			if(g_nCurrentPlayerScore[client] <= 0)
			{
				g_nCurrentPlayerScore[client] = KvGetNum(hLevelSystemFile, "score", 0);
			}
			*/
			
			//Calculate the new score
			int nNewScore = (nCurrentScore + g_nCurrentPlayerScore[client]) - g_nCurrentPlayerPenaltyScore[client];
			if(nNewScore < 0)
			{
				nNewScore = 0;
			}
			//Save score
			KvSetNum(hLevelSystemFile, "score", nNewScore);
			
			//Get player name and save name
			decl String:strUsername[64];
			GetClientName(client, strUsername, sizeof(strUsername));
			EscapeString(strUsername, 64);
			KvSetString(hLevelSystemFile, "name", strUsername);
			
			KvGoBack(hLevelSystemFile);
			
			//Save player level to file
			KeyValuesToFile(hLevelSystemFile, strLevelSystemPath);
		}
	}
}

//Load all player levels
LoadLevels()
{
	for(new client = 1; client <= MaxClients; client++)
	{
		if((IsValidClient(client)) && (IsClientConnected(client)) && (!IsFakeClient(client)))
		{
			g_nCurrentPlayerScore[client] = 0;
			g_nCurrentPlayerPenaltyScore[client] = 0;
			LoadClientLevel(client);
		}
	}
}

//Save all player levels
SaveLevels()
{
	for(new client = 1; client <= MaxClients; client++)
	{
		if((IsValidClient(client)) && (IsClientConnected(client)) && (!IsFakeClient(client)))
		{
			SaveClientLevel(client);
		}
	}
}


/*
=========================================
	FUNCTIONS FOR COMPUTING RANK
=========================================
*/

int GetClientRank(int score)
{
	bool bLoop = true;
	int nRank = 0;
	int nScoreLeft = score;
	
	while(bLoop)
	{
		int nScoreRequirement = g_nScoreRequireBaseLevel + (g_nScoreRequirePerLevel * nRank);
		if(nScoreLeft >= nScoreRequirement)
		{
			nScoreLeft -= nScoreRequirement;
			nRank++;
			bLoop = true;
		}
		else
		{
			bLoop = false;
		}
	}
	
	if(nRank > g_nMaxLevel)
	{
		nRank = g_nMaxLevel;
	}
	
	return nRank;
}

int GetScoreRemainForNextRank(int score)
{
	bool bLoop = true;
	int nRank = 0;
	int nScoreLeft = score;
	
	while(bLoop)
	{
		int nScoreRequirement = g_nScoreRequireBaseLevel + (g_nScoreRequirePerLevel * nRank);
		if(nScoreLeft >= nScoreRequirement)
		{
			nScoreLeft -= nScoreRequirement;
			nRank++;
			bLoop = true;
		}
		else
		{
			bLoop = false;
		}
	}
	
	if(nRank > g_nMaxLevel)
	{
		return 0;
	}
	
	return nScoreLeft;
}

int GetAmountOfScoreRequirementNextRank(int score)
{
	bool bLoop = true;
	int nRank = 0;
	int nScoreLeft = score;
	int nRequirementForNextRank = 0;
	
	while(bLoop)
	{
		int nScoreRequirement = g_nScoreRequireBaseLevel + (g_nScoreRequirePerLevel * nRank);
		if(nScoreLeft >= nScoreRequirement)
		{
			nScoreLeft -= nScoreRequirement;
			nRank++;
			bLoop = true;
		}
		else
		{
			nRequirementForNextRank = nScoreRequirement;
			bLoop = false;
		}
	}
	
	return nRequirementForNextRank;
}

int GetTotalScoreBaseOnRank(int rank)
{
	int nScore = 0;
	
	if(rank <= 0)
	{
		return 0;
	}
	
	for(int i = 0; i < rank; i++)
	{
		int nScoreRequirement = g_nScoreRequireBaseLevel + (g_nScoreRequirePerLevel * i);
		nScore += nScoreRequirement;
	}
	
	return nScore;
}

/*
=========================================
	COMMANDS
=========================================
*/

public Action:Cmd_Level(client, args)
{
	int nScore = GetEntData(g_nPlayerResource, g_nPlayerScore + (4 * client));

	int nPrevious = GetScoreRemainForNextRank(g_nCurrentPlayerScore[client]);
	int nCurrentScoreTotal = nPrevious + nScore - g_nCurrentPlayerPenaltyScore[client];
	int nLeft = GetAmountOfScoreRequirementNextRank(g_nCurrentPlayerScore[client]) - nCurrentScoreTotal;

	if(nLeft < 0)
	{
		PrintToChat(client, "\x0759b0f9[INS] \x01(Previous: %d + Current: %d - Penalty: %d = %d) You have ranked up! Please wait for map change", nPrevious, nScore, g_nCurrentPlayerPenaltyScore[client], nCurrentScoreTotal);
	}
	else
	{
		PrintToChat(client, "\x0759b0f9[INS] \x01(Previous: %d + Current: %d - Penalty: %d = %d) Require %d score more to get the next rank", nPrevious, nScore, g_nCurrentPlayerPenaltyScore[client], nCurrentScoreTotal, nLeft);
	}
	
	
	return Plugin_Handled;
}

public Action:Cmd_SetRank(client, args)
{
	if((args < 1) || (args > 2))
    {
		ReplyToCommand(client, "Usage: setrank <number>");
		return Plugin_Handled;
    }
	
	if(!IsValidClient(client) && (args == 1))
	{
		ReplyToCommand(client, "Invalid client");
		return Plugin_Handled;
	}
	
	if(args == 1)
	{
		decl String:strRank[64];
		GetCmdArg(1, strRank, sizeof(strRank));
		
		int nRank = StringToInt(strRank);
		g_nCurrentPlayerScore[client] = GetTotalScoreBaseOnRank(nRank);
		
		ReplyToCommand(client, "Rank set");
	}
	else if(args == 2)
	{
		decl String:strTarget[64];
		GetCmdArg(1, strTarget, sizeof(strTarget));
		decl String:strRank[64];
		GetCmdArg(2, strRank, sizeof(strRank));
		
		int nRank = StringToInt(strRank);
		
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		
		if ((target_count = ProcessTargetString(
			strTarget,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
		{
			ReplyToCommand(client, "Unable to find target");
			return Plugin_Handled;
		}
		
		for(int i = 0; i < target_count; i++)
		{
			g_nCurrentPlayerScore[target_list[i]] = GetTotalScoreBaseOnRank(nRank);
		}
		
		ReplyToCommand(client, "Rank set");
	}
	
	return Plugin_Handled;
}

public Action:Cmd_AddRank(client, args)
{
	if((args < 1) || (args > 2))
    {
		ReplyToCommand(client, "Usage: addrank <number>");
		return Plugin_Handled;
    }
	
	if(!IsValidClient(client) && (args == 1))
	{
		ReplyToCommand(client, "Invalid client");
		return Plugin_Handled;
	}
	
	if(args == 1)
	{
		decl String:strRank[64];
		GetCmdArg(1, strRank, sizeof(strRank));
		
		int nRank = StringToInt(strRank);
		g_nCurrentPlayerScore[client] += GetTotalScoreBaseOnRank(nRank);
		
		ReplyToCommand(client, "Rank added");
	}
	else if(args == 2)
	{
		decl String:strTarget[64];
		GetCmdArg(1, strTarget, sizeof(strTarget));
		decl String:strRank[64];
		GetCmdArg(2, strRank, sizeof(strRank));
		
		int nRank = StringToInt(strRank);
		
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		
		if ((target_count = ProcessTargetString(
			strTarget,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
		{
			ReplyToCommand(client, "Unable to find target");
			return Plugin_Handled;
		}
		
		for(int i = 0; i < target_count; i++)
		{
			g_nCurrentPlayerScore[target_list[i]] += GetTotalScoreBaseOnRank(nRank);
		}
		
		ReplyToCommand(client, "Rank added");
	}
	
	return Plugin_Handled;
}

public Action:Cmd_AddScore(client, args)
{
	if((args < 1) || (args > 2))
    {
		ReplyToCommand(client, "Usage: addscore <number>");
		return Plugin_Handled;
    }
	
	if(!IsValidClient(client) && (args == 1))
	{
		ReplyToCommand(client, "Invalid client");
		return Plugin_Handled;
	}
	
	if(args == 1)
	{
		decl String:strScore[64];
		GetCmdArg(1, strScore, sizeof(strScore));
		
		int nScore = StringToInt(strScore);
		AddScore(client, nScore);
		
		ReplyToCommand(client, "score added");
	}
	else if(args == 2)
	{
		decl String:strTarget[64];
		GetCmdArg(1, strTarget, sizeof(strTarget));
		decl String:strScore[64];
		GetCmdArg(2, strScore, sizeof(strScore));
		
		int nScore = StringToInt(strScore);
		
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		
		if ((target_count = ProcessTargetString(
			strTarget,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
		{
			ReplyToCommand(client, "Unable to find target");
			return Plugin_Handled;
		}
		
		for(int i = 0; i < target_count; i++)
		{
			AddScore(target_list[i], nScore);
		}
		
		ReplyToCommand(client, "Score added");
	}
	
	return Plugin_Handled;
}

public Action:Cmd_RemoveScore(client, args)
{
	if((args < 1) || (args > 2))
    {
		ReplyToCommand(client, "Usage: removescore <number>");
		return Plugin_Handled;
    }
	
	if(!IsValidClient(client) && (args == 1))
	{
		ReplyToCommand(client, "Invalid client");
		return Plugin_Handled;
	}
	
	if(args == 1)
	{
		decl String:strScore[64];
		GetCmdArg(1, strScore, sizeof(strScore));
		
		int nScore = StringToInt(strScore);
		RemoveScore(client, nScore);
		
		ReplyToCommand(client, "score removed");
	}
	else if(args == 2)
	{
		decl String:strTarget[64];
		GetCmdArg(1, strTarget, sizeof(strTarget));
		decl String:strScore[64];
		GetCmdArg(2, strScore, sizeof(strScore));
		
		int nScore = StringToInt(strScore);
		
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		
		if ((target_count = ProcessTargetString(
			strTarget,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
		{
			ReplyToCommand(client, "Unable to find target");
			return Plugin_Handled;
		}
		
		for(int i = 0; i < target_count; i++)
		{
			RemoveScore(target_list[i], nScore);
		}
		
		ReplyToCommand(client, "Score removed");
	}
	
	return Plugin_Handled;
}

public Action:Cmd_AddPenalty(client, args)
{
	if((args < 1) || (args > 2))
    {
		ReplyToCommand(client, "Usage: addpenalty <number>");
		return Plugin_Handled;
    }
	
	if(!IsValidClient(client) && (args == 1))
	{
		ReplyToCommand(client, "Invalid client");
		return Plugin_Handled;
	}
	
	if(args == 1)
	{
		decl String:strScore[64];
		GetCmdArg(1, strScore, sizeof(strScore));
		
		int nScore = StringToInt(strScore);
		AddPenalty(client, nScore);
		
		ReplyToCommand(client, "penalty added");
	}
	else if(args == 2)
	{
		decl String:strTarget[64];
		GetCmdArg(1, strTarget, sizeof(strTarget));
		decl String:strScore[64];
		GetCmdArg(2, strScore, sizeof(strScore));
		
		int nScore = StringToInt(strScore);
		
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		
		if ((target_count = ProcessTargetString(
			strTarget,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
		{
			ReplyToCommand(client, "Unable to find target");
			return Plugin_Handled;
		}
		
		for(int i = 0; i < target_count; i++)
		{
			AddPenalty(target_list[i], nScore);
		}
		
		ReplyToCommand(client, "penalty added");
	}
	
	return Plugin_Handled;
}

public Action:Cmd_RemovePenalty(client, args)
{
	if((args < 1) || (args > 2))
    {
		ReplyToCommand(client, "Usage: removepenalty <number>");
		return Plugin_Handled;
    }
	
	if(!IsValidClient(client) && (args == 1))
	{
		ReplyToCommand(client, "Invalid client");
		return Plugin_Handled;
	}
	
	if(args == 1)
	{
		decl String:strScore[64];
		GetCmdArg(1, strScore, sizeof(strScore));
		
		int nScore = StringToInt(strScore);
		RemovePenalty(client, nScore);
		
		ReplyToCommand(client, "penalty removed");
	}
	else if(args == 2)
	{
		decl String:strTarget[64];
		GetCmdArg(1, strTarget, sizeof(strTarget));
		decl String:strScore[64];
		GetCmdArg(2, strScore, sizeof(strScore));
		
		int nScore = StringToInt(strScore);
		
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		
		if ((target_count = ProcessTargetString(
			strTarget,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
		{
			ReplyToCommand(client, "Unable to find target");
			return Plugin_Handled;
		}
		
		for(int i = 0; i < target_count; i++)
		{
			RemovePenalty(target_list[i], nScore);
		}
		
		ReplyToCommand(client, "penalty removed");
	}
	
	return Plugin_Handled;
}


/*
=========================================
	OTHER FUNCTIONS FOR CHANGING PLAYER RANK (USE FOR COMMANDS)
=========================================
*/

void AddScore(int client, int nScore)
{
	g_nCurrentPlayerScore[client] += nScore;
}

void RemoveScore(int client, int nScore)
{
	g_nCurrentPlayerScore[client] -= nScore;
	if(g_nCurrentPlayerScore[client] < 0)
	{
		g_nCurrentPlayerScore[client] = 0;
	}
}

void AddPenalty(int client, int nScore)
{
	g_nCurrentPlayerPenaltyScore[client] += nScore;
}

void RemovePenalty(int client, int nScore)
{
	g_nCurrentPlayerPenaltyScore[client] -= nScore;
	if(g_nCurrentPlayerPenaltyScore[client] < 0)
	{
		g_nCurrentPlayerPenaltyScore[client] = 0;
	}
}


/*
=========================================
	SET NAME
=========================================
*/
public Action:Event_PlayerChangename(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:strName[65];
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!IsFakeClient(client))
	{
		GetEventString(event, "newname", strName, 65);
		SetNewName(client, strName);
		return Plugin_Handled; // avoid printing the change to the chat
	}
	return Plugin_Continue;
}

SetNewName(client, String:sName[])
{
	decl String:strScore[7];
	
	int nScore = LoadClientLevel(client);
	
	Format(strScore, 7, "[%d]", nScore);
	
	if(!(StrContains(sName, strScore, false) == 0))
	{
		Format(sName, 69, "%s %s", strScore, sName);
		SetClientName(client, sName);
	}
}

/*
=========================================
	EXTRA FUNCTIONS FOR CHECKING
=========================================
*/

void EscapeString(char[] string, int maxlen)
{
	ReplaceString(string, maxlen, "@", "＠");
	ReplaceString(string, maxlen, "'", "\'");
	ReplaceString(string, maxlen, "\"", "＂");
}

bool:IsValidClient(client) 
{
    if (!(1 <= client <= MaxClients) || !IsClientInGame(client)) 
        return false;
	
    return true; 
}