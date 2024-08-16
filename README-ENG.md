# Sing-Box-NGINX-WebSocket

[**Russian version**](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/README.md)

### Trojan and VLESS WebSocket proxy with TLS termination on NGINX
A script for full setup of a hidden proxy server with NGINX camouflage.

> [!IMPORTANT]
> Recommended OS: Debian 12 or Ubuntu 22.04. Run as root on a newly installed system. It's recommended to update and reboot the system before running this script.

> [!NOTE]
> With routing rules for Russia.
 
### Includes:
1) Sing-Box server setup (Trojan and VLESS protocols)
2) NGINX reverse proxy and website setup
3) Basic security setup including unattended-upgrades
4) WARP setup
5) Cloudflare SSL certificates with auto renewal
6) Enable BBR
7) Client Sing-Box configs with routing rules for Russia
 
### Usage:

Run this command:

```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Sing-Box-NGINX-WS/master/sb-nginx-server.sh)
```
Then just enter the necessary information:

![pic-en](https://github.com/user-attachments/assets/cbe29aa6-53db-483e-9529-d524d5141bb4)

The script will show your client links in the end.

-----

Run this command to add/delete users or to synchronize routing rules in client configs:

```
sbmanager
```

Or run this command if the server was set up with an old version of the script:

```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Sing-Box-NGINX-WS/master/sb-manager.sh)
```

Then follow the instructions:

![Screenshot 2024-08-16 223928](https://github.com/user-attachments/assets/a15c10d2-8032-4005-aa99-b5514bb7baaa)

Options 4 and 5 synchronize the routing rules in client configs of all users, which eliminates the need to edit the config of each user separately.

### Client setup:
[Android and iOS](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/Client-Guidelines/Sing-Box-Android-iOS-en.pdf)

[Windows 10 and 11](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/Client-Guidelines/Sing-Box-Windows-10-11-en.pdf)

[Linux:](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/README-ENG.md#client-setup)
```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Sing-Box-NGINX-WS/master/sb-linux-desktop.sh)
```
