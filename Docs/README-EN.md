# Secret Sing-Box

![logo](https://github.com/user-attachments/assets/33ab0dac-ed6a-4254-8386-c4b09bf9a312)

[**Russian version**](https://github.com/A-Zuro/Secret-Sing-Box/blob/main/README.md)

### Easy setup of Trojan and VLESS proxy with TLS termination on NGINX or HAProxy
This script is designed to fully and quickly configure a secure proxy server with [Sing-Box](https://sing-box.sagernet.org) core and [NGINX](https://nginx.org/en/) or [HAProxy](https://www.haproxy.org) camouflage. Two setup methods:

- All requests to the proxy are received by NGINX, the requests are passed to Sing-Box only if they contain the correct path (WebSocket or HTTPUpgrade transport)

![nginx-en](https://github.com/user-attachments/assets/8b832294-f14f-4c8b-876e-30b1d160fd1e)

- All requests to the proxy are received by HAProxy, then Trojan passwords are read from the first 56 bytes of the request by using a Lua script, the requests are passed to Sing-Box only if they contain the correct Trojan password (TCP transport) — [FPPweb3](https://github.com/FPPweb3) method

![haproxy-en](https://github.com/user-attachments/assets/a9753846-4f40-414d-b4eb-4c37b4e9de14)

Both setup methods make it impossible to detect Sing-Box from the outside, which improves security.

> [!IMPORTANT]
> Recommended OS for the server: Debian 11/12 or Ubuntu 22.04/24.04. Just 512 MB of RAM, 5 GB of disk space and 1 processor core are sufficient. You will also need an IPv4 on the server and your own domain ([How to set it up?](https://github.com/A-Zuro/Secret-Sing-Box/blob/main/Docs/cf-settings-en.md)). Run as root on a newly installed system. It's recommended to update and reboot the system before running this script.

> [!NOTE]
> With routing rules for Russia. Open ports on the server: 443 and SSH.
>
> This project is created for educational and demonstration purposes. Please make sure that your actions are legal before using it.
 
### Includes:
1) Sing-Box server setup
2) NGINX or HAProxy reverse proxy and website setup on port 443
3) TLS certificates with auto renewal
4) Security setup (optional)
5) Multiplexing to optimise connections and to solve TLS in TLS problem
6) Enable BBR
7) WARP setup
8) Optional setup of proxy chains of two or more servers
9) An option to setup connection to custom Cloudflare IP on the client
10) Client Sing-Box configs with routing rules for Russia
11) Automated management of user config files
12) Page for convenient distribution of subscriptions
 
### Server setup:

To setup the server, run this command on it:

```
bash <(curl -Ls https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/install-server.sh)
```

Then just enter the necessary information:

![pic-1-en](https://github.com/user-attachments/assets/8d78bb20-eb5c-4074-865e-a858869a6103)

> [!CAUTION]
> Passwords, UUIDs, paths and other data in the image above are for example purposes only. Do not use them on your server.

In the end, the script will show your links to client configs and to subscription page, it's recommended to save them.

-----

To display additional settings, run this command:

```
sbmanager
```

Then follow the instructions:

![pic-2-en](https://github.com/user-attachments/assets/3a40dea9-2b7c-4480-b2f2-fae986376502)

Option 5 synchronizes the settings in client configs of all users, which eliminates the need to edit the config of each user separately. If new rule sets are added to the configs by using option 5.2, they will be automatically downloaded on the server if they are from [SagerNet](https://github.com/SagerNet/sing-geosite/tree/rule-set).

### WARP+ keys:

To activate a WARP+ key, enter this command (replace the key with yours):

```
warp-cli registration license CMD5m479-Y5hS6y79-U06c5mq9
```

### Client setup:
> [!IMPORTANT]
> On some devices, "stack": "system" in tun interface settings in client configs might not work. In such cases, it is recommended to replace it with "gvisor" by using option 4 in sbmanager.

[Android and iOS](https://github.com/A-Zuro/Secret-Sing-Box/blob/main/Docs/Sing-Box-Android-iOS-en.md). The guide is given for Android, the app interface is different on iOS, but it has similar settings.

[Windows](https://github.com/A-Zuro/Secret-Sing-Box/blob/main/Docs/Sing-Box-Windows-en.md). This method is recommended due to more complete routing settings, but you can also import the link to [Hiddify](https://github.com/hiddify/hiddify-app/releases/latest) client app. If some apps are not proxied when using Hiddify, change the config options > service mode > VPN.

[Linux](https://github.com/A-Zuro/Secret-Sing-Box/blob/main/Docs/README-EN.md#client-setup). Run the command below and follow the instructions or use [Hiddify](https://github.com/hiddify/hiddify-app/releases/latest) client app.
```
bash <(curl -Ls https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/sb-pc-linux-en.sh)
```

### Stargazers over time:
[![Stargazers over time](https://starchart.cc/A-Zuro/Secret-Sing-Box.svg?variant=adaptive)](https://starchart.cc/A-Zuro/Secret-Sing-Box)
