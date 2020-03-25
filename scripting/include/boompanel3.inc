#if defined _boompanel3_included
 #endinput
#endif
#define _boompanel3_included

#define BP3_NOTIFICATION_WARN "warn"
#define BP3_NOTIFICATION_ERROR "error"
#define BP3_NOTIFICATION_INFO "info"
#define BP3_NOTIFICATION_SUCCESS "success"

/**
* Add plugin to BoomPanel3 navigation
*
* @param name				Name of the plugin
* @param template			Template file containing page html/css/javascript
* @param icon				Navigation icon, if empty default icon will be shown
* @param showInNavigation	Do you want to show this plugin page in left navigation or this is just jump to page
* @param flag				Admin flag to access the page, 0 for all admins to have access
* @return					void
*/
native void BoomPanel3_RegisterPlugin(char[] name, char[] template, char[] icon = "fa-puzzle-piece", bool showInNavigation = true, int flag = 0);

/**
* Send notification message
*
* @param socketID		socketID, that you can get from BoomPanel3_GetSocketID
* @param type			Success message
* @param title			Title for the notification
* @param message		Message for notification
* @return				void
*/
native void BoomPanel3_SendNotification(int socketID, char[] type, char[] title, char[] message);

/**
* When you want to send data to one websocket client
*
* @param socketID			socketID, that you can get from BoomPanel3_GetSocketID
* @param dataName			name of the data that will be used inside template
* @param JSON_Array			array of data
* @return					void 
*/
native void BoomPanel3_ReturnData(int socketID, char[] dataName, JSON_Array data);

/**
* When you want to send data to all websocket cients
*
* @param dataName			name of the data that will be used inside template
* @param JSON_Array			array of data
* @return					void
*/
native void BoomPanel3_ReturnDataAll(char[] dataName, JSON_Array data);


/**
* Get command sender name
*
* @param client				data (json/text/string)
* @return					void
*/
//native void BoomPanel3_GetClientName(char[] data);


/**
* Get command sender socket ID
*
* @return					sender socket ID
*/
native int BoomPanel3_GetSocketID();


/*
	This is called when BoomPanel3 is realoaded and needs to 
	get all navigation plugins again
*/
forward void BoomPanel3_OnPluginLoad();

public void __pl_boompanel3__SetNTVOptional() 
{
	MarkNativeAsOptional("BoomPanel3_GetSocketID");
}