#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "boomix"
#define PLUGIN_VERSION "1.00"

#define MAX_PLUGIN_NAME 50
#define MAX_TEMPLATE_LENGTH 350

#include <sourcemod>
#include <boompanel3>
#include <websocket>
#include <json>

#pragma newdecls required

WebsocketHandle socket = INVALID_WEBSOCKET_HANDLE;
ConVar CVAR_WebsocketPort;
JSON_Array WSclients;
JSON_Array WSplugins;
GlobalForward g_OnPluginLoad;
KeyValues kv;


public Plugin myinfo = 
{
	name = "BoomPanel 3",
	author = PLUGIN_AUTHOR,
	description = "BoomPanel 3 - Main core file for admin panel",
	version = PLUGIN_VERSION,
	url = "https://boompanel.com"
};

public void OnPluginStart()
{
	CVAR_WebsocketPort = CreateConVar("bp_websocket_port", "7897", "Websocket port");
	WSclients = new JSON_Array();
	WSplugins = new JSON_Array();

	//Call forward that plugin loaded
	CreateTimer(0.1, PluginLoad);
	
	//Main websocket commands
	RegConsoleCmd("sm_BPnavigation", CMD_Navigation);
	RegAdminCmd("sm_BPtemplate", CMD_Template, ADMFLAG_RCON);
	
	//Load admins file
	UpdateAdminsKV();
}

public Action PluginLoad(Handle tmr, any data)
{
	Call_StartForward(g_OnPluginLoad);
	Call_Finish();
}

public Action CMD_Template(int client, int args)
{
	if(client > 0) return Plugin_Handled;
	
	//Get data
	JSON_Object WSplugin = new JSON_Object();
	char cSearching[MAX_PLUGIN_NAME], cPluginName[MAX_PLUGIN_NAME];
	WebsocketHandle socketClient = view_as<WebsocketHandle>(iGetLastSender());
	JSON_Object WSclient = GetWSClient(socketClient);
	GetCmdArg(1, cSearching, sizeof(cSearching));

	//Go through all loaded plugins
	for (int i = 0; i < WSplugins.Length; i++) {
		
		//Get loop plugin name
		WSplugin = WSplugins.GetObject(i);
		WSplugin.GetString("name", cPluginName, sizeof(cPluginName));
		
		//Found the correct plugin template
		if (StrEqual(cSearching, cPluginName)) {

			//Check if client has permissions to view this template
			int iPluginFlags = WSplugin.GetInt("flags");
			if (!bHasAccessToCommand(WSclient, "sm_BPtestCommand", iPluginFlags)) {
				BoomPanel3_SendNotification(view_as<int>(socketClient), BP3_NOTIFICATION_ERROR, "Error", "You dont have permissions to view this template");
				return Plugin_Handled;
			}
			
			//Get template path
			char cTemplateFile[MAX_TEMPLATE_LENGTH];
			WSplugin.GetString("template", cTemplateFile, sizeof(cTemplateFile));
			
			//Open template file
			char path[MAX_TEMPLATE_LENGTH + 150];
			BuildPath( Path_SM, path, sizeof( path ), "configs/BoomPanel3/%s", cTemplateFile);
			File file = OpenFile(path, "r");
			if (file == null) { 
				PrintToServer("File %s not found", cTemplateFile);
				return Plugin_Handled;
			}
			
			//Send all template code to WS client
			JSON_Object obj = new JSON_Object();
			obj.SetString("type", "templateline");
			char line[1000], output[1000]; 
			while (!file.EndOfFile() && file.ReadLine(line, sizeof(line))) { 
				obj.SetString("data", line);
				obj.Encode(output, sizeof(output));
				WSSend(socketClient, output);
			}
			
			obj.SetString("type", "templateend");
			obj.SetString("data", "");
			obj.Encode(output, sizeof(output));
			WSSend(socketClient, output);
		}
	}
	
	
	return Plugin_Handled;	
}

public Action CMD_Navigation(int client, int args)
{
	if (client > 0)
		return Plugin_Handled;
		
	WebsocketHandle socketClient = view_as<WebsocketHandle>(iGetLastSender());
	
	//Put all loaded plugins inside array
	JSON_Array arr = new JSON_Array();
	char cPluginName[MAX_PLUGIN_NAME], cIcon[50];
	JSON_Object WSplugin = new JSON_Object();
	JSON_Object WSclient = GetWSClient(socketClient);
	for (int i = 0; i < WSplugins.Length; ++i) {
		WSplugin = WSplugins.GetObject(i);
		WSplugin.GetString("name", cPluginName, sizeof(cPluginName));
		WSplugin.GetString("icon", cIcon, sizeof(cIcon));
		bool bShow = WSplugin.GetBool("show");

		//Check if client has permissions for this plugin
		int iPluginFlags = WSplugin.GetInt("flags");
		if (bHasAccessToCommand(WSclient, "sm_BPtestCommand", iPluginFlags)) {
			JSON_Object obj = new JSON_Object();
			obj.SetString("name", cPluginName);
			obj.SetString("icon", cIcon);
			obj.SetBool("show", bShow);
			arr.PushObject(obj);	
		}
	}

	//Send all loaded plugins
	char output[1000];
	JSON_Object obj = new JSON_Object();
	obj.SetString("type", "navigation");
	obj.SetObject("data", arr);
	obj.Encode(output, sizeof(output));
	WSSend(socketClient, output);
		
	return Plugin_Handled;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("boompanel3");
	CreateNative("BoomPanel3_RegisterPlugin", Native_RegisterPlugin);
	CreateNative("BoomPanel3_GetSocketID", Native_GetSocketID);
	CreateNative("BoomPanel3_ReturnData", Native_ReturnData);
	CreateNative("BoomPanel3_ReturnDataAll", Native_ReturnDataAll);
	CreateNative("BoomPanel3_SendNotification", Native_SendNotification);
	g_OnPluginLoad = CreateGlobalForward("BoomPanel3_OnPluginLoad", ET_Ignore);
	
	return APLRes_Success;
}

public int Native_SendNotification(Handle plugin, int numParams)
{
	//Get data
	char cType[50], cTitle[50], cMessage[1000];
	WebsocketHandle client = GetNativeCell(1);
	GetNativeString(2, cType, sizeof(cType));
	GetNativeString(3, cTitle, sizeof(cTitle));
	GetNativeString(4, cMessage, sizeof(cMessage));

	//Send data to WS
	char data[1500];
	JSON_Object obj = new JSON_Object();
	obj.SetString("type", "notification");
	obj.SetString("notification_type", cType);
	obj.SetString("title", cTitle);
	obj.SetString("message", cMessage);
	obj.Encode(data, sizeof(data));
	WSSend(client, data);
	obj.Cleanup();
}

public int Native_RegisterPlugin(Handle plugin, int numParams)
{
	//Get native data
	char cPluginName[MAX_PLUGIN_NAME], cTemplateFile[MAX_TEMPLATE_LENGTH], cIcon[30];
	GetNativeString(1, cPluginName, sizeof(cPluginName));
	GetNativeString(2, cTemplateFile, sizeof(cTemplateFile));
	GetNativeString(3, cIcon, sizeof(cIcon));
	bool bShow = (GetNativeCell(4) == 0) ? false : true;
	int flags = GetNativeCell(5);

	//Delete if such plugin is already registred
	JSON_Object WSplugin = new JSON_Object();
	for (int i = 0; i < WSplugins.Length; ++i) {
		WSplugin = WSplugins.GetObject(i);
		char cName[MAX_PLUGIN_NAME];
		WSplugin.GetString("name", cName, sizeof(cName));
		if (StrEqual(cName, cPluginName)) {
			WSplugins.Remove(i);
		}
	}

	//Register plugin
	WSplugin = new JSON_Object();
	WSplugin.SetString("name", cPluginName);
	WSplugin.SetString("template", cTemplateFile);
	WSplugin.SetString("icon", cIcon);
	WSplugin.SetBool("show", bShow);
	WSplugin.SetInt("flags", flags);
	WSplugins.PushObject(WSplugin);
}

public int Native_ReturnDataAll(Handle plugin, int numParams)
{
	//Get data
	int size;
	GetNativeStringLength(1, size);
	size += 1;
	char[] dataName = new char[size];
	GetNativeString(1, dataName, size);
	JSON_Array JSONdata = view_as<JSON_Array>(GetNativeCell(2));
	
	//Send data
	SendJSONToWebsocket(INVALID_WEBSOCKET_HANDLE, dataName, JSONdata);

	//Clear JSON
	JSONdata.Cleanup();
	delete JSONdata;
}

public int Native_ReturnData(Handle plugin, int numParams)
{
	
	//Get data
	WebsocketHandle client = GetNativeCell(1);
	int size;
	GetNativeStringLength(2, size);
	size += 1;
	char[] dataName = new char[size];
	GetNativeString(2, dataName, size);
	JSON_Array JSONdata = view_as<JSON_Array>(GetNativeCell(3));
	
	//Send data
	SendJSONToWebsocket(client, dataName, JSONdata);
	
	//Clear JSON
	JSONdata.Cleanup();
	delete JSONdata;

}

void SendJSONToWebsocket(WebsocketHandle client, char[] dataName, JSON_Array arr) {

	char data[5000];
	
	//Send that data starts
	JSON_Object obj = new JSON_Object();
	obj.SetString("type", "datastart");
	obj.SetString("name", dataName);
	obj.Encode(data, sizeof(data));
	WSSend(client, data);
	obj.Cleanup();
	
	//Send all data
	for (int i = 0; i < arr.Size - 1; i++) {
		JSON_Object dataObj = arr.GetObject(i);
		if(dataObj != INVALID_HANDLE) {
			dataObj.Encode(data, sizeof(data));
			obj.SetString("type", "data");
			obj.SetString("name", dataName);
			obj.SetString("data", data);
			obj.Encode(data, sizeof(data));
			WSSend(client, data);
			obj.Cleanup();
		}
	}
	
	//Send that data ends
	obj.SetString("type", "dataend");
	obj.SetString("name", dataName);
	obj.Encode(data, sizeof(data));
	WSSend(client, data);
	obj.Cleanup();

}

void WSSend(WebsocketHandle client, char[] data) {
	if (client != INVALID_WEBSOCKET_HANDLE) {
		Websocket_Send(client, SendType_Text, data);
	} else {
		WebsocketHandle socketClient;
		JSON_Object WSclient = new JSON_Object();
		for (int i = 0; i < WSclients.Length; ++i) {
			WSclient = WSclients.GetObject(i);
			socketClient = view_as<WebsocketHandle>(WSclient.GetInt("socketid"));
			Websocket_Send(socketClient, SendType_Text, data);
		}
	}
}

public int Native_GetSocketID(Handle plugin, int numParams)
{
	return iGetLastSender();
}

int iGetLastSender() 
{

	JSON_Object WSclient = new JSON_Object();
	for (int i = 0; i < WSclients.Length; ++i) {
		WSclient = WSclients.GetObject(i);
		int tick = WSclient.GetInt("lastcmd");
		if (tick != -1) {
			WSclient.SetInt("lastcmd", -1);
			return WSclient.GetInt("socketid");
		}
	}

	return -1;
}


public Action OnWebsocketIncoming(WebsocketHandle websocket, WebsocketHandle newWebsocket, const char[] remoteIP, int remotePort, char protocols[256], char getPath[2000])
{

	Format(protocols, sizeof(protocols), "");

	//Update admins keyvalues
	UpdateAdminsKV();
	
	//If there are no admins in file, do not try to login
	if (!kv.GotoFirstSubKey()) 
	{
		return Plugin_Handled;
	}

	//Go throughout admins
	char username[120], steamid[50], password[120], flags[15];
	do
	{
		//Get key values
		kv.GetSectionName(username, sizeof(username));
		kv.GetString("steamid", steamid, sizeof(steamid));
		kv.GetString("password", password, sizeof(password));
		kv.GetString("flags", flags, sizeof(flags));
		
		//Try to login
		char login[250];
		Format(login, sizeof(login), "/?steamid=%s&password=%s", steamid, password);
		if(StrEqual(getPath, login)) {
			
			//Give handshake
			PrintToServer("Websocket logged in: %s", username);
			Websocket_HookChild(newWebsocket, OnWebsocketReceive, OnWebsocketDisconnect, OnChildWebsocketError);

			//Add new socket client to JSON socket clients
			JSON_Object WSclient = new JSON_Object();
			WSclient.SetString("steamid", 	steamid);
			WSclient.SetString("password", 	password);
			WSclient.SetString("username", 	username);
			WSclient.SetString("flags", 	flags);
			WSclient.SetInt("tick", 		-1);
			WSclient.SetInt("socketid", 	view_as<int>(newWebsocket));
			WSclients.PushObject(WSclient);
		}
	} while (kv.GotoNextKey());

	//Go back to first line of keyvalue file
	kv.Rewind();
	
	return Plugin_Continue;
}

public void OnWebsocketReceive(WebsocketHandle websocket, WebsocketSendType iType, const char[] command, const int dataSize)
{
	if(iType == SendType_Text)
	{
		
		//If client has permission send command
		PrintToServer("Command recived: %s | %i", command, websocket);
		JSON_Object WSclient = GetWSClient(websocket);
		if (bHasAccessToCommand(WSclient, command)) 
		{
			WSclient.SetInt("lastcmd", GetGameTickCount());
			ServerCommand(command);
		} else {
			BoomPanel3_SendNotification(view_as<int>(websocket), BP3_NOTIFICATION_ERROR, "Error", "No permissions for this command");
		}
		
	}
}

public JSON_Object GetWSClient(WebsocketHandle websocket) {
	JSON_Object WSclient = new JSON_Object();
	int iSocket = view_as<int>(websocket);
	int iTestSocket = -1;
	for (int i = 0; i < WSclients.Length; ++i) {
		WSclient = WSclients.GetObject(i);
		iTestSocket = WSclient.GetInt("socketid");
		if (iSocket == iTestSocket)
			return WSclient;
	}
	return WSclient;
}

bool bHasAccessToCommand(JSON_Object client, const char[] sCommand, int customflag = 0)
{
	//Get client flags
	char flags[50];
	client.GetString("flags", flags, sizeof(flags));

	//Create fake admin
	AdminFlag flag;
	AdminId admin = CreateAdmin();
	for(int i = 0; i < strlen(flags); i++)
	{
		if(FindFlagByChar(flags[i], flag)) {
			if(!admin.HasFlag(flag, Access_Effective))
				admin.SetFlag(flag, true);
		}
	}

	//Check if admin has access to command
	bool hasAccess = (CheckAccess(admin, sCommand, customflag, false)) ? true : false;
	RemoveAdmin(admin);
	return hasAccess;
}


public void OnWebsocketDisconnect(WebsocketHandle websocket)
{
	WSdiconnect(websocket);
}

public void OnChildWebsocketError(WebsocketHandle websocket, const int errorType, const int errorNum)
{
	LogError("[BoomPanel3] OnChildWebsocketError error: handle: %d, type: %d, errno: %d", websocket, errorType, errorNum);
	WSdiconnect(websocket);
}

public void OnWebsocketMasterError(WebsocketHandle websocket, const int errorType, const int errorNum)
{
	LogError("[BoomPanel3] OnWebsocketMasterError error: handle: %d type: %d, errno: %d", websocket, errorType, errorNum);
	socket = INVALID_WEBSOCKET_HANDLE;
}

public void OnWebsocketMasterClose(WebsocketHandle websocket)
{
	socket = INVALID_WEBSOCKET_HANDLE;
}

public void OnPluginEnd()
{
	if(socket != INVALID_WEBSOCKET_HANDLE)
		Websocket_Close(socket);
}

void WSdiconnect(WebsocketHandle websocket) {
	JSON_Object WSclient = new JSON_Object();
	for (int i = 0; i < WSclients.Length; ++i) {
		WSclient = WSclients.GetObject(i);
		int iTestSocket = WSclient.GetInt("socketid");
		if (iTestSocket == view_as<int>(websocket))
			WSclients.Remove(i);
	}
}

void UpdateAdminsKV() 
{
	kv = new KeyValues("Admins");
	char cAdminFile[250];
	BuildPath(Path_SM, cAdminFile, sizeof(cAdminFile), "configs/BoomPanel3/admins.cfg");
	kv.ImportFromFile(cAdminFile);
}


public void OnAllPluginsLoaded()
{
	//char serverIP[40];
	//GetServerIP(serverIP, sizeof(serverIP));

	if(socket == INVALID_WEBSOCKET_HANDLE)
		socket = Websocket_Open("194.19.248.93", CVAR_WebsocketPort.IntValue, OnWebsocketIncoming, OnWebsocketMasterError, OnWebsocketMasterClose);
}
