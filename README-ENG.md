# Sing-Box Reverse Proxy

[**Russian version**](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/README.md)

### Trojan and VLESS proxy with TLS termination on NGINX or HAProxy
This script is designed to fully configure a hidden proxy server with [Sing-Box](https://sing-box.sagernet.org) core and [NGINX](https://nginx.org/en/) or [HAProxy](https://www.haproxy.org) camouflage. Two setup methods:
- All requests to the proxy are processed by NGINX, the requests are passed to Sing-Box only if they contain the correct path (WebSocket transport)
- All requests to the proxy are processed by HAProxy, the requests are passed to Sing-Box only if they contain the correct Trojan password (TCP transport) — [FPPweb3](https://github.com/FPPweb3) method

Both setup methods make it impossible to detect Sing-Box from the outside.

> [!IMPORTANT]
> Recommended OS: Debian 11/12 or Ubuntu 22.04/24.04. You will also need your own domain linked to your Cloudflare account. Run as root on a newly installed system. It's recommended to update and reboot the system before running this script.

> [!NOTE]
> With routing rules for Russia.
 
### Includes:
1) Sing-Box server setup
2) NGINX or HAProxy reverse proxy and website setup on port 443
3) Security setup including unattended-upgrades
4) Cloudflare SSL certificates with auto renewal
5) WARP setup
6) Enable BBR
7) Client Sing-Box configs with routing rules for Russia
8) Automated management of user config files
 
### Usage:

To configure the server, run this command:

```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Sing-Box-NGINX-WS/master/install-server.sh)
```

Then just enter the necessary information:

![pic-1-en](https://github.com/user-attachments/assets/e6ab259b-5ed0-4881-aa83-a52e6e81ac6d)

The script will show your client links in the end.

-----

To display additional settings, run this command:

```
sbmanager
```

Then follow the instructions:

![pic-2-en](https://github.com/user-attachments/assets/d82312eb-96c1-4020-be4e-fa3afa9d27a9)

Options 4 and 5 synchronize the settings in client configs of all users, which eliminates the need to edit the config of each user separately.

To enable AdGuard DNS on the client, use option 5 and specify "tls://94.140.14.14" instead of "tls://1.1.1.1" in the config template. This may reduce performance due to slower domain resolution compared to 1.1.1.1.

### WARP+ keys:

To activate a WARP+ key, enter this command (replace the key with yours):

```
warp-cli registration license CMD5m479-Y5hS6y79-U06c5mq9
```

### Client setup:
[Android and iOS](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/Client-Guidelines/Sing-Box-Android-iOS-en.pdf)

[Windows 10 and 11](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/Client-Guidelines/Sing-Box-Windows-10-11-en.pdf)

[Linux:](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/README-ENG.md#client-setup) run the command below.
```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Sing-Box-NGINX-WS/master/sb-pc-linux.sh)
```
Then follow the instructions.