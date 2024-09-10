# Sing-Box-Reverse-Proxy

[**Russian version**](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/README.md)

### Trojan and VLESS proxy with TLS termination on NGINX or HAProxy
This script is designed to fully configure a hidden proxy server with NGINX or HAProxy camouflage. Two setup methods:
- All requests to the proxy are processed by NGINX, and the server works as a proxy only if the request contains the correct path (WebSocket transport)
- All requests to the proxy are processed by HAProxy, and the server works as a proxy only if the request contains the correct Trojan password (TCP transport)
<br/>

> [!IMPORTANT]
> Recommended OS: Debian 12 or Ubuntu 22.04/24.04. You will also need your own domain linked to your Cloudflare account. Run as root on a newly installed system. It's recommended to update and reboot the system before running this script.

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

Run this command to add/delete users, to synchronize the settings in client configs or to manage WARP domains:

```
sbmanager
```

Then follow the instructions:

![pic-2-en](https://github.com/user-attachments/assets/d82312eb-96c1-4020-be4e-fa3afa9d27a9)

Options 4 and 5 synchronize the settings in client configs of all users, which eliminates the need to edit the config of each user separately.

### Client setup:
[Android and iOS](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/Client-Guidelines/Sing-Box-Android-iOS-en.pdf)

[Windows 10 and 11](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/Client-Guidelines/Sing-Box-Windows-10-11-en.pdf)

[Linux:](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/README-ENG.md#client-setup) run the command below.
```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Sing-Box-NGINX-WS/master/sb-pc-linux.sh)
```
