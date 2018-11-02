#include <sourcemod>
#include <dynamic>
#include <SteamWorks>

#pragma semicolon 1

ConVar hostname = null;
char gS_WebhookURL[1024];
new String:g_szMessage[1024];
new String:g_szMessageTime[1024];

public Plugin myinfo =
{
	name = "[INS] Discord",
	author = "Neko- (shavit)",
	description = "Relays in-game chat into a Discord channel.",
	version = "1.0.5"
}

public void OnPluginStart()
{
	RegConsoleCmd("calladmin", Cmd_CallAdmin, "Call admin from discord");
	
	hostname = FindConVar("hostname");

	char[] sError = new char[256];

	if(!LoadConfig(sError, 256))
	{
		SetFailState("Couldn't load the configuration file. Error: %s", sError);
	}
	
	AddCommandListener(Say_Event, "say");
	AddCommandListener(SayTeam_Event, "say_team");
	AddCommandListener(CallVote_Event, "callvote");
	AddCommandListener(Vote_Event, "vote");
}

bool LoadConfig(char[] error, int maxlen)
{
	char[] sPath = new char[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "configs/discord.cfg");

	Dynamic dConfigFile = Dynamic();

	if(!dConfigFile.ReadKeyValues(sPath))
	{
		dConfigFile.Dispose();

		FormatEx(error, maxlen, "Couldn't access \"%s\". Make sure that the file exists and has correct permissions set.", sPath);

		return false;
	}

	dConfigFile.GetString("WebhookURL", gS_WebhookURL, 1024);

	if(StrContains(gS_WebhookURL, "https://discordapp.com/api/webhooks") == -1)
	{
		FormatEx(error, maxlen, "Please change the value of WebhookURL in the configuration file (\"%s\") to a valid URL. Current value is \"%s\".", sPath, gS_WebhookURL);

		return false;
	}

	return true;
}

void EscapeString(char[] string, int maxlen)
{
	ReplaceString(string, maxlen, "@", "＠");
	ReplaceString(string, maxlen, "'", "\'");
	ReplaceString(string, maxlen, "\"", "＂");
}

void EscapeStringAllowAt(char[] string, int maxlen)
{
	ReplaceString(string, maxlen, "'", "\'");
	ReplaceString(string, maxlen, "\"", "＂");
}

public Action:Say_Event(client, const String:cmd[], argc)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}
	
	decl String:strMsg[255];
	GetCmdArgString(strMsg, 255);
	StripQuotes(strMsg);
	
	decl String:sAuthID[64];
	GetClientAuthId(client, AuthId_Engine, sAuthID, 64);
	
	decl String:strName[64];
	GetClientName(client, strName, sizeof(strName));
	
	DiscordMessage(sAuthID, strName, strMsg);
	
	return Plugin_Continue;
}

public Action:SayTeam_Event(client, const String:cmd[], argc)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}
	
	decl String:strMsg[255];
	GetCmdArgString(strMsg, 255);
	StripQuotes(strMsg);
	
	decl String:sAuthID[64];
	GetClientAuthId(client, AuthId_Engine, sAuthID, 64);
	
	decl String:strName[64];
	GetClientName(client, strName, sizeof(strName));
	
	DiscordMessage(sAuthID, strName, strMsg, true);
	
	return Plugin_Continue;
}

DiscordMessage(const String:strAuthID[], const String:strName[], const String:strMessage[], bool bTeamChat = false)
{
	char[] sHostname = new char[32];
	hostname.GetString(sHostname, 32);
	EscapeString(sHostname, 32);
	
	char[] sFormat = new char[1024];
	FormatEx(sFormat, 1024, "{\"username\":\"%s\", \"content\":\"{msg}\"}", "In-Game Chat");

	char[] sTime = new char[10];
	FormatTime(sTime, 10, "%H:%I:%S");

	char[] sNewMessage = new char[1024];
	
	if(bTeamChat)
	{
		FormatEx(sNewMessage, 1024, "**[%s] (TEAM) %s :** %s", strAuthID, strName, strMessage);
	}
	else
	{
		FormatEx(sNewMessage, 1024, "**[%s] %s :** %s", strAuthID, strName, strMessage);
	}
	
	if(StrContains(sNewMessage, "@admin") > -1)
	{
		ReplaceString(sNewMessage, 1024, "@admin", "<@&313894579680051200>");
	}
	
	EscapeStringAllowAt(sNewMessage, 1024);
	//EscapeString(sNewMessage, 1024);
	ReplaceString(sFormat, 1024, "{msg}", sNewMessage);
	
	if((!StrEqual(g_szMessageTime, sTime, false)) || (!StrEqual(g_szMessage, sNewMessage, false)))
	{
		Format(g_szMessageTime, sizeof(g_szMessageTime), "%s", sTime);
		Format(g_szMessage, sizeof(g_szMessage), "%s", sNewMessage);
		
		Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, gS_WebhookURL);
		SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", sFormat, strlen(sFormat));
		SteamWorks_SetHTTPCallbacks(hRequest, view_as<SteamWorksHTTPRequestCompleted>(OnRequestComplete));
		SteamWorks_SendHTTPRequest(hRequest);
	}
}

public void OnRequestComplete(Handle hRequest, bool bFailed, bool bRequestSuccessful, EHTTPStatusCode eStatusCode)
{
	delete hRequest;
}

public Action:Cmd_CallAdmin(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "Usage: calladmin <reason>");
		return Plugin_Handled;
	}
	
	char szReason[500];
	GetCmdArgString(szReason, sizeof(szReason));
	
	decl String:sAuthID[64];
	GetClientAuthId(client, AuthId_Engine, sAuthID, 64);
	
	decl String:strName[64];
	GetClientName(client, strName, sizeof(strName));
	EscapeString(strName, 64);

	char[] sFormat = new char[1024];
	FormatEx(sFormat, 1024, "{\"username\":\"%s\", \"content\":\"{msg}\"}", "In-Game Admin Notification");
	
	char[] sNewMessage = new char[1024];
	FormatEx(sNewMessage, 1024, "**[%s] %s** is calling for <@&313894579680051200>```%s```", sAuthID, strName, szReason);
	EscapeStringAllowAt(sNewMessage, 1024);
	ReplaceString(sFormat, 1024, "{msg}", sNewMessage);
	
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, gS_WebhookURL);
	SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", sFormat, strlen(sFormat));
	SteamWorks_SetHTTPCallbacks(hRequest, view_as<SteamWorksHTTPRequestCompleted>(OnRequestComplete));
	SteamWorks_SendHTTPRequest(hRequest);
	
	PrintToChat(client, "\x0759b0f9[INS] \x01Please wait for the next available admin to reach you...");
	return Plugin_Handled;
}

public Action:CallVote_Event(client, const String:cmd[], argc)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}
	
	decl String:strAuthID[64];
	GetClientAuthId(client, AuthId_Engine, strAuthID, 64);
	
	decl String:strName[64];
	GetClientName(client, strName, sizeof(strName));
	
	if(argc == 1)
	{
		decl String:Cmd1[64];
		GetCmdArg(1, Cmd1, sizeof(Cmd1));
		
		char[] sNewMessage = new char[1024];
		FormatEx(sNewMessage, 1024, "**[%s] %s** started a **%s** vote", strAuthID, strName, Cmd1);
		
		char[] sFormat = new char[1024];
		FormatEx(sFormat, 1024, "{\"username\":\"%s\", \"content\":\"{msg}\"}", "In-Game Vote System");
		
		ReplaceString(sFormat, 1024, "{msg}", sNewMessage);
	
		Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, gS_WebhookURL);
		SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", sFormat, strlen(sFormat));
		SteamWorks_SetHTTPCallbacks(hRequest, view_as<SteamWorksHTTPRequestCompleted>(OnRequestComplete));
		SteamWorks_SendHTTPRequest(hRequest);
	}
	else if(argc == 2)
	{
		decl String:Cmd1[64];
		decl String:Cmd2[64];

		GetCmdArg(1, Cmd1, sizeof(Cmd1));
		GetCmdArg(2, Cmd2, sizeof(Cmd2));
		
		char[] sNewMessage = new char[1024];
		if(StrContains(Cmd2, " ") > -1)
		{
			decl String:strCmd2Info[4][64];
			ExplodeString(Cmd2, " ", strCmd2Info, sizeof(strCmd2Info), sizeof(strCmd2Info[]));
			
			if(GetClientOfUserId(StringToInt(strCmd2Info[0])) != 0)
			{
				int nTarget = GetClientOfUserId(StringToInt(strCmd2Info[0]));
			
				decl String:sAuthIDTarget[64];
				GetClientAuthId(nTarget, AuthId_Engine, sAuthIDTarget, 64);
				
				decl String:strNameTarget[64];
				GetClientName(nTarget, strNameTarget, sizeof(strNameTarget));
			
				FormatEx(sNewMessage, 1024, "**[%s] %s** started a **%s** vote on **[%s] %s** with reason **%s**", strAuthID, strName, Cmd1, sAuthIDTarget, strNameTarget, strCmd2Info[1]);
			}
			else
			{
				FormatEx(sNewMessage, 1024, "**[%s] %s** started a **%s** vote, **%s %s**", strAuthID, strName, Cmd1, strCmd2Info[0], strCmd2Info[1]);
			}
		}
		else
		{
			FormatEx(sNewMessage, 1024, "**[%s] %s** started a **%s** vote, **%s**", strAuthID, strName, Cmd1, Cmd2);
		}
		
		char[] sFormat = new char[1024];
		FormatEx(sFormat, 1024, "{\"username\":\"%s\", \"content\":\"{msg}\"}", "In-Game Vote System");
		
		ReplaceString(sFormat, 1024, "{msg}", sNewMessage);
	
		Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, gS_WebhookURL);
		SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", sFormat, strlen(sFormat));
		SteamWorks_SetHTTPCallbacks(hRequest, view_as<SteamWorksHTTPRequestCompleted>(OnRequestComplete));
		SteamWorks_SendHTTPRequest(hRequest);
	}
	
	return Plugin_Continue;
}

public Action:Vote_Event(client, const String:cmd[], argc)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}
	
	if(argc != 1)
	{
		return Plugin_Continue;
	}
	
	decl String:Cmd1[64];
	GetCmdArg(1, Cmd1, sizeof(Cmd1));
	
	decl String:strAuthID[64];
	GetClientAuthId(client, AuthId_Engine, strAuthID, 64);
	
	decl String:strName[64];
	GetClientName(client, strName, sizeof(strName));
	
	char[] szOption = new char[32];
	if(StrContains(Cmd1, "option1") > -1)
	{
		FormatEx(szOption, 32, "Yes");
	}
	else if(StrContains(Cmd1, "option2") > -1)
	{
		FormatEx(szOption, 32, "No");
	}
	else
	{
		return Plugin_Continue;
	}
	
	char[] sNewMessage = new char[1024];
	FormatEx(sNewMessage, 1024, "**[%s] %s** voted **%s**", strAuthID, strName, szOption);
	
	char[] sFormat = new char[1024];
	FormatEx(sFormat, 1024, "{\"username\":\"%s\", \"content\":\"{msg}\"}", "In-Game Vote System");
	
	ReplaceString(sFormat, 1024, "{msg}", sNewMessage);

	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, gS_WebhookURL);
	SteamWorks_SetHTTPRequestRawPostBody(hRequest, "application/json", sFormat, strlen(sFormat));
	SteamWorks_SetHTTPCallbacks(hRequest, view_as<SteamWorksHTTPRequestCompleted>(OnRequestComplete));
	SteamWorks_SendHTTPRequest(hRequest);
	
	return Plugin_Continue;
}

bool:IsValidClient(client) 
{
	if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
		return false; 
	
	return true; 
}