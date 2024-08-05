#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.2.1"
#define PLUGIN_DESCRIPTION "Allows grabbing carried props from other players' hands"

public Plugin myinfo = {
	name        = "[NMRiH] Item Snatching",
	author      = "Dysphie",
	description = PLUGIN_DESCRIPTION,
	version     = PLUGIN_VERSION,
	url         = "https://github.com/dysphie/nmrih-item-snatch"
};

#define NMR_MAXPLAYERS 9

ConVar cvEnabled;
ConVar cvCooldown;
float nextPickupTime[NMR_MAXPLAYERS+1];

public void OnPluginStart()
{
	CreateConVar("nmr_item_snatch_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION,
    	FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	cvEnabled = CreateConVar("sm_item_snatch_enabled", "1", "Enables or disables item snatching");
	cvCooldown = CreateConVar("sm_item_snatch_cooldown", "3.0", "Time in seconds between item snatches");
	AutoExecConfig(true, "plugin.item-snatch");
}

public void OnClientConnected(int client)
{
	nextPickupTime[client] = 0.0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (cvEnabled.BoolValue && StrEqual(classname, "player_pickup")) {
		SDKHook(entity, SDKHook_Spawn, OnPickupSpawned);
	}
}
	
void OnPickupSpawned(int entity)
{
	RequestFrame(GetAttachedEntity, EntIndexToEntRef(entity));
}

void GetAttachedEntity(int pickup_ref)
{
	int pickup = EntRefToEntIndex(pickup_ref);
	if (pickup == -1) {
		return;
	}

	int entity = GetEntPropEnt(pickup, Prop_Data, "m_attachedEntity");
	int client = GetEntPropEnt(pickup, Prop_Data, "m_hParent");

	if (entity == -1 || !IsEntityPlayer(client) || !IsPlayerAlive(client)) {
		return;
	}

	if (!CheckCommandAccess(client, "can_item_snatch", 0)) {
		return;
	}

	float curTime = GetGameTime();
	if (curTime < nextPickupTime[client]) {
		return;
	}

	char classname[15];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == client || !IsClientInGame(i) || !IsPlayerAlive(i))
			continue;

		int useEnt = GetEntPropEnt(i, Prop_Data, "m_hUseEntity");
		if (useEnt == -1) {
			continue;
		}

		GetEntityClassname(useEnt, classname, sizeof(classname));

		if (StrEqual(classname, "player_pickup") &&
			GetEntPropEnt(useEnt, Prop_Data, "m_attachedEntity") == entity)
		{
			if (CheckCommandAccess(i, "item_snatch_immunity", ADMFLAG_BAN)) {
				continue;
			}

			AcceptEntityInput(useEnt, "Use", i);
			nextPickupTime[i] = curTime + cvCooldown.FloatValue;
		}
	}
}

bool IsEntityPlayer(int entity)
{
	return 0 < entity <= MaxClients && IsClientInGame(entity);
}