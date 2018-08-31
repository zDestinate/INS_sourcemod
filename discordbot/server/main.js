//Discord
var Discord = require("discord.js");
var bot = new Discord.Client();

//Rcon
var Rcon = require("rcon");
var rconConnection = new Rcon('IP here', port, 'rcon_password here');
//Example: new Rcon('192.168.1.256', 27015, 'killyouall123');


console.log("[SERVER] Server started");

//Rcon
rconConnection.on('auth', function() {
	console.log("[RCON] Authed!");
}).on('response', function(str) {
	console.log("[RCON] Response: " + str);
}).on('end', function() {
	console.log("[RCON] Socket closed!");
});

//Establish rcon connection
rconConnection.connect();


//Discord bot events
//Bot connected to discord and its ready
bot.on('ready', () => {
	console.log('[INS-DISCORD] Successfully Loaded');
	bot.user.setActivity('Insurgency', { type: 'PLAYING' });
});

//Bot reconnecting
bot.on('reconnecting', () => {
	console.log('[INS-DISCORD] Reconnecting');
});

//When a user on discord send a message
bot.on("message", msg => {
	if(msg.author.bot) return;
	
	//Filter out channel so only the channel 'ins-ingame-chat' can send message to in game
	if(msg.channel.name != 'ins-ingame-chat') return;
	
	var nickname = msg.member.displayName;
	var username = msg.author.username;
	var message = msg.content;
	
	//Filter out ```
	if(message.indexOf("```") !== -1)
	{
		const send_message = 'An Error Occur```Unable to send that message```';
		msg.channel.send(send_message);
		return;
	}
	
	//msg.channel.send(msg.author.toString() + ' said ' + message);
	
	//After it passed all the check we send a rcon message to the in-game server
	//In-game server will print out to all chat using that cvar
	rconConnection.send('discordchat ' + username + ' : ' + message);
	
	console.log('[INS-DISCORD] ' + username + ' : ' + message)
});

//Discord bot token (Require you to create your own discord bot in https://discordapp.com/developers/applications/)
bot.login("Your bot token here");