#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <clientprefs>

#pragma semicolon 1

#define SOUNDFORMAT ".mp3"
#define SOUNDQUANTITY 4	// except zero

#define SPteam 1
#define TRteam 2
#define CTteam 3

#define SPcolor "{gray}"
#define TRcolor "{red}"
#define CTcolor "{blue}"

public Plugin myinfo =
{
	name = "Whistle to Players",
	author = "UDaV73rus",
	description = "Press E at player to whistle",
	version = "1.0",
	url = "https://github.com/UDaV73rus/whistleplugin"
};
/* TO-DO
- spectators can hear whistles
- ?client prefs (disable of E, disable sounds)
- ?advert
*/

new Handle:cv_enable;
new Handle:cv_restrictteam;
new Handle:cv_message;
new Handle:cv_cooldown;
new Handle:cv_maxdistance;
new Handle:cv_moneytoloose;
new Handle:cv_loosechance;
new Handle:cv_funnychance;
new Handle:cv_pitchmin;
new Handle:cv_pitchmax;

new g_LastButtons[MAXPLAYERS+1];
new g_LastUse[MAXPLAYERS+1];
new g_Offset_Account = -1;

bool g_bPlayerSpotted[MAXPLAYERS+1];
int g_iPlayerManager = -1;
int g_iPlayerSpotted = -1;

new bool:g_isFlashed[MAXPLAYERS+1];
new Handle:g_hFlashTimer[MAXPLAYERS+1];
new g_iOffset_flFlashDuration = -1;

public void OnMapStart()
{
	if((g_iPlayerManager = GetPlayerResourceEntity()) == -1)
		return;
	g_iPlayerSpotted = FindSendPropInfo("CCSPlayerResource", "m_bPlayerSpotted");
	SDKHook(g_iPlayerManager, SDKHook_ThinkPost, PlayerManager_ThinkPost);

	decl String:whistlepath[128];
	for(int i = 0; i <= SOUNDQUANTITY; i++)	// 0 - fun sound. Other - default sounds
	{
		Format(whistlepath, 128, "whistleudav/whistle%i%s", i, SOUNDFORMAT);
		PrecacheSound(whistlepath, true);

		Format(whistlepath, 128, "sound/whistleudav/whistle%i%s", i, SOUNDFORMAT);
		AddFileToDownloadsTable(whistlepath);
	}
}

public OnPluginStart()
{
	cv_enable = CreateConVar("whs_enable", "1", "Enable whistle plugin. {0/1}", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cv_restrictteam = CreateConVar("whs_restrictteam", "0", "Can whistle to: 0 - everyone, 1 - only ally, 2 - only enemy. {0/1/2}", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	cv_message = CreateConVar("whs_message", "1", "Message to target of whistle. 0 - disable chat messages, 1 - enable chat mesages, 2 - anonimyze chat messages. {0/1/2}", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	cv_cooldown = CreateConVar("whs_cooldown", "5", "Cooldown to whistle (in secs) {1, inf}", FCVAR_NOTIFY, true, 1.0);
	cv_maxdistance = CreateConVar("whs_maxdistance", "800", "Max distance to whistle. (in units) {0, inf}", FCVAR_NOTIFY, true, 0.0);
	cv_moneytoloose = CreateConVar("whs_moneytoloose", "100", "Money to loose by whistle", FCVAR_NOTIFY);
	cv_loosechance = CreateConVar("whs_loosechance", "5", "1/n  Chance to loose money by whistle. 0 - disabled {0, inf}", FCVAR_NOTIFY, true, 0.0);
	cv_funnychance = CreateConVar("whs_funnychance", "50", "1/n  Chance to play fun whistle. 0 - disabled {0, inf}", FCVAR_NOTIFY, true, 0.0);
	cv_pitchmin = CreateConVar("whs_pitchmin", "85", "Lower border of pitch (in %) {1, inf}", FCVAR_NOTIFY, true, 1.0);
	cv_pitchmax = CreateConVar("whs_pitchmax", "120", "Upper border of pitch (in %) {1, inf}", FCVAR_NOTIFY, true, 1.0);
	AutoExecConfig(true, "whistleudav");

	if((g_iOffset_flFlashDuration = FindSendPropInfo("CCSPlayer", "m_flFlashDuration")) == -1)
		SetFailState("Failed to find CCSPlayer::m_flFlashDuration offset");
	HookEvent("player_blind", Event_player_blind);
	HookEvent("player_spawn", Event_player_spawn);
	
	LoadTranslations("whistleudav.phrases");
	
	g_Offset_Account = FindSendPropInfo("CCSPlayer", "m_iAccount");

	RegConsoleCmd("whs", CmdWhistle, "Bind it to button you want, if use-key(E) does not suit for you");
}

public OnClientDisconnect_Post(client)
{
	g_LastButtons[client] = 0;
	CancelTimer(g_hFlashTimer[client]);
	g_hFlashTimer[client] = INVALID_HANDLE;
	g_isFlashed[client] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(GetClientTeam(client) <= SPteam || !IsPlayerAlive(client) || GetConVarInt(cv_enable) == 0)
		return;
	int target = -1;
	if(buttons & IN_USE)
		if(!(g_LastButtons[client] & IN_USE))
		{
			target = GetClientAimTarget(client, true);
			if(IsValidClient(target))
				whistleToTarget(client, target);
		}
	g_LastButtons[client] = buttons;
	
	return;
}

public Action CmdWhistle(client, args)
{
	if(GetClientTeam(client) <= SPteam || !IsPlayerAlive(client) || GetConVarInt(cv_enable) == 0)
		return;
	int target = -1;
	target = GetClientAimTarget(client, true);
	if(IsValidClient(target))
		whistleToTarget(client, target);
	
	return;
}

public whistleToTarget(int client, int target)
{
	// for GetConVars which used more then one time, for not making requests every time, optimization
	int cvMessage = GetConVarInt(cv_message);
	int cvRestrictTeam = GetConVarInt(cv_restrictteam);
	int cvMaxDistance = GetConVarInt(cv_maxdistance);
	int cvFunnyChance = GetConVarInt(cv_funnychance);
	int cvLooseChance = GetConVarInt(cv_loosechance);
	int cvMoneyToLoose = GetConVarInt(cv_moneytoloose);

	decl String:teamcolor[32];	// buffer var
	char clientName[32];
	GetClientName(client, clientName, sizeof(clientName));
	char targetName[32];
	GetClientName(target, targetName, sizeof(targetName));
	int clientTeam = GetClientTeam(client);
	int targetTeam = GetClientTeam(target);
	
	if(!(cvRestrictTeam == 0 || (cvRestrictTeam == 1 && targetTeam == clientTeam) || (cvRestrictTeam == 2 && targetTeam != clientTeam)))
		return;
	
	if(!g_bPlayerSpotted[target] && clientTeam != targetTeam)
		return;
	
	if(g_isFlashed[client])
		return;
		
	float client_pos[3];
	GetClientAbsOrigin(client, client_pos);
	float target_pos[3];
	GetClientAbsOrigin(target, target_pos);
	float distance = GetVectorDistance(client_pos, target_pos);
	if(distance > cvMaxDistance)
	{
		if(targetTeam == TRteam)
			teamcolor = TRcolor;
		else
			teamcolor = CTcolor;
		CPrintToChat(client, "{palegreen}[Whistle]{default} %t {red}%.0f{default}/%i", "Distance", targetName, teamcolor, distance + 1, cvMaxDistance);

		return;
	}
	
	int whistlecd = g_LastUse[client] + GetConVarInt(cv_cooldown) - GetTime();
	if(whistlecd > 0)
	{
		CPrintToChat(client, "{palegreen}[Whistle]{default} %t", "Cooldown", whistlecd);
		return;
	}
	
	int pitch = 100;
	int soundnumber = 0;
	if(!(cvFunnyChance > 0 && GetRandomInt(1, cvFunnyChance) == cvFunnyChance))
	{
		soundnumber = GetRandomInt(1, SOUNDQUANTITY);
		pitch = GetRandomInt(GetConVarInt(cv_pitchmin), GetConVarInt(cv_pitchmax));
	}

	decl String:soundname[128];
	Format(soundname, 128, "whistleudav/whistle%i%s", soundnumber, SOUNDFORMAT);
	EmitSoundToClient(client, soundname, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, pitch);

	if(targetTeam == TRteam)
		teamcolor = TRcolor;
	else
		teamcolor = CTcolor;
	CPrintToChat(client, "{palegreen}[Whistle]{default} %t", "YouWhistleTo", targetName, teamcolor);
	
	if(!IsFakeClient(target))
	{
		EmitSoundToClient(target, soundname, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, pitch);

		if(cvMessage != 0)
		{
			if(clientTeam == TRteam)
				teamcolor = TRcolor;
			else
				teamcolor = CTcolor;
			
			if(cvMessage == 1)
				CPrintToChat(target, "{palegreen}[Whistle]{default} %t", "WhistleToYou", clientName, teamcolor);
			else // cvMesage == 2
			{
				char anonymous[32] = "||||||";
				teamcolor = "{default}";
				CPrintToChat(target, "{palegreen}[Whistle]{default} %t", "WhistleToYou", anonymous, teamcolor);
			}
		}
	}
	
	if(cvLooseChance > 0 && GetRandomInt(1, cvLooseChance) == cvLooseChance)
	{
		if(GetEntData(client, g_Offset_Account) > cvMoneyToLoose)
			SetEntData(client, g_Offset_Account, GetEntData(client, g_Offset_Account) - cvMoneyToLoose);
		else
			SetEntData(client, g_Offset_Account, 0);
		CPrintToChat(client, "{palegreen}[Whistle]{red} %t", "LooseMoney", cvMoneyToLoose);
	}
	g_LastUse[client] = GetTime();
	
	return;
}

public bool:IsValidClient(int client)
{
	if(1 <= client <= MaxClients)
		return true;
	
	return false;
}

// Disable whistle while flashed
public Event_player_blind(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	float duration = GetEntDataFloat(client, g_iOffset_flFlashDuration);
	
	CancelTimer(g_hFlashTimer[client]);
	g_hFlashTimer[client] = CreateTimer(duration, Timer_FlashEnded, client);
	g_isFlashed[client] = true;
}

// Reset flash timer on spawn
public Event_player_spawn(Handle:event, const String:name[], bool:bSilent)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(g_hFlashTimer[client] != INVALID_HANDLE)
	{
		CancelTimer(g_hFlashTimer[client]);
		g_hFlashTimer[client] = INVALID_HANDLE;
		g_isFlashed[client] = false;
	}
}

public Action:Timer_FlashEnded(Handle:hTimer, any:client)
{
	g_hFlashTimer[client] = INVALID_HANDLE;
	g_isFlashed[client] = false;

	return Plugin_Stop;
}

CancelTimer(&Handle:hTimer)
{
	if(hTimer != INVALID_HANDLE)
		KillTimer(hTimer);
}

// Save players spotted by enemy
public void PlayerManager_ThinkPost(int entity)
{
	for(int i = 1; i <= MaxClients; i++)
		if(GetEntData(entity, g_iPlayerSpotted + i, 1))
		{
			if(!g_bPlayerSpotted[i])
				g_bPlayerSpotted[i] = true;
		}
		else
			g_bPlayerSpotted[i] = false;
}
