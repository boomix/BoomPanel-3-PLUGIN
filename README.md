# BoomPanel-3-PLUGIN
---

## What is BoomPanel 3?
BoomPanel 3 is new kind of admin panel, with the big difference, where frontend is made with Vue.js, and 
sourcemod/SRCDS server runs as backend for the panel. For communication to server panel is using websockets.


## Why to use it?
Not only that the panel is lightning fast, because the connection directly from client to server, it is also model/plugin based. So in short, any Sourcemod plugin developer easly is able to create their own page in this panel, as far as they understand simple html and javascript. The panel can be used to configure that particular plugin or to display any kind of data from the server almost real time. It fully supports Sourcemod admin flags, meaning you can have multiple admins in panel with different permissions.


## Requirements
* [Socket (3.0.2): Socket extension for SourceMod](https://github.com/JoinedSenses/sm-ext-socket/releases)
* [[DEV] WebSocket Server - Direct connection between webbrowser and gameserver](https://forums.alliedmods.net/showthread.php?t=182615)

## Installation
* Download master branch and extract zip in your server
* Install needed requirements
* Edit file `addons/sourcemod/configs/BoomPanel3/admins.cfg` and add yourself as panel admin
* Test out if plugin loads up fine, if not, the edit convar `bp_websocket_ip` with the correct server IP
* If you want to change socket port, change convar `bp_websocket_port` (default `27021`)
* Now you can install other plugins that do support BoomPanel3, and you can install [BoomPanel3 web/PWA client](https://boompanel.com) and add your server in settings
