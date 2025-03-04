# Secret Sing-Box (SSB)

[**Russian version**](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/README.md)

### Easy setup of Trojan and VLESS proxy with TLS termination on NGINX or HAProxy
This script is designed to fully and quickly configure a secure proxy server with [Sing-Box](https://sing-box.sagernet.org) core and [NGINX](https://nginx.org/en/) or [HAProxy](https://www.haproxy.org) camouflage. Two setup methods:

- All requests to the proxy are received by NGINX, the requests are passed to Sing-Box only if they contain the correct path (WebSocket or HTTPUpgrade transport)

![nginx-en](https://github.com/user-attachments/assets/8b832294-f14f-4c8b-876e-30b1d160fd1e)

- All requests to the proxy are received by HAProxy, then Trojan passwords are read from the first 56 bytes of the request by using a Lua script, the requests are passed to Sing-Box only if they contain the correct Trojan password (TCP transport) — [FPPweb3](https://github.com/FPPweb3) method

![haproxy-en](https://github.com/user-attachments/assets/a9753846-4f40-414d-b4eb-4c37b4e9de14)

Both setup methods make it impossible to detect Sing-Box from the outside, which improves security.

> [!IMPORTANT]
> Recommended OS for the server: Debian 11/12 or Ubuntu 22.04/24.04. Just 512 MB of RAM, 5 GB of disk space and 1 processor core are sufficient. You will also need an IPv4 on the server and your own domain linked to your Cloudflare account ([How to set it up?](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/Docs/cf-settings-en.md)). Run as root on a newly installed system. It's recommended to update and reboot the system before running this script.

> [!NOTE]
> With routing rules for Russia. Open ports on the server: 443 and SSH.
>
> This project is created for educational and demonstration purposes. Please make sure that your actions are legal before using it.
 
### Includes:
1) Sing-Box server setup
2) NGINX or HAProxy reverse proxy and website setup on port 443
3) Cloudflare TLS certificates with auto renewal
4) Security setup (optional)
5) Multiplexing to optimise connections and to solve TLS in TLS problem
6) Enable BBR
7) WARP setup
8) Optional setup of proxy chains of two or more servers
9) Client Sing-Box configs with routing rules for Russia
10) Automated management of user config files
11) Page for convenient distribution of subscriptions
 
### Server setup:

To setup the server, run this command on it:

```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Scripts/install-server.sh)
```

Then just enter the necessary information:

![pic-1-en](https://github.com/user-attachments/assets/7dc408a9-6357-49c3-a58a-d3da90c4ced4)

> [!CAUTION]
> Passwords, UUIDs, paths and other data in the image above are for example purposes only. Do not use them on your server.

In the end, the script will show your links to client configs and to subscription page, it's recommended to save them.

-----

To display additional settings, run this command:

```
sbmanager
```

Then follow the instructions:

![pic-2-en](https://github.com/user-attachments/assets/bedfa287-1943-422b-84c7-8d8397822e61)

Option 5 synchronizes the settings in client configs of all users, which eliminates the need to edit the config of each user separately. If new rule sets are added to the configs by using option 5.2, they will be automatically downloaded on the server if they are from [SagerNet](https://github.com/SagerNet/sing-geosite/tree/rule-set).

### WARP+ keys:

To activate a WARP+ key, enter this command (replace the key with yours):

```
warp-cli registration license CMD5m479-Y5hS6y79-U06c5mq9
```

### Client setup:
> [!IMPORTANT]
> On some devices, "stack": "system" in tun interface settings in client configs might not work. In such cases, it is recommended to replace it with "gvisor" by using option 4 in sbmanager.

[Android and iOS](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/Docs/Sing-Box-Android-iOS-en.md). The guide is given for Android, the app interface is different on iOS, but it has similar settings.

[Windows](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/Docs/Sing-Box-Windows-en.md). This method is recommended due to more complete routing settings, but you can also import the link to [Hiddify](https://github.com/hiddify/hiddify-app/releases/latest) client app. If some apps are not proxied when using Hiddify, change the config options > service mode > VPN.

[Linux](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/Docs/README-EN.md#client-setup). Run the command below and follow the instructions or use [Hiddify](https://github.com/hiddify/hiddify-app/releases/latest) client app.
```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Scripts/sb-pc-linux-en.sh)
```

### You can support the project if it's helpful to you:
- USDT (BEP20): 0xe2FeA540a9F1f85C2bfA3e6949c722393B5d636A
- Litecoin (BIP84): ltc1q7quvcq3gtlwf2yuk370vhf2syad8ee4we9huj4
- Toncoin (TON): UQCWmIBsU-EZJSH3rhghbtSOtKQBmb5y74mkjbohpDWZ6l-H

Or you can give it a star :star:

### Stargazers over time:
[![Stargazers over time](https://starchart.cc/BLUEBL0B/Secret-Sing-Box.svg?variant=adaptive)](https://starchart.cc/BLUEBL0B/Secret-Sing-Box)
