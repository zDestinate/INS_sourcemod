#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = {
	name = "[INS] Discord Chat",
	description = "This is a discord chat connect directly to game",
	author = "Neko-",
	version = "1.0.0",
};

public OnPluginStart() 
{
	RegAdminCmd("discordchat", DiscordChat, ADMFLAG_ROOT, "Send by discord");
}

public Action:DiscordChat(client, args)
{
	decl String:Message[255];
	GetCmdArgString(Message, 255);
	StripQuotes(Message);
	TrimString(Message);
	
	PrintToChatAll("\x077289DA[Discord] \x01%s", Message);
	
	return Plugin_Handled;
}