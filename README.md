# Sing-Box-NGINX-WebSocket

### Trojan and VLESS WebSocket proxy with TLS termination on NGINX

> [!IMPORTANT]
> Recommended OS: Debian 12. Run as root. It's recommended to update and reboot the system before running this script.

> [!NOTE]
> In Russian and with routing rules for Russia.
 
### Includes:
1) Sing-Box server setup
2) NGINX reverse proxy and website setup
3) Basic security setup including unattended-upgrades
4) WARP setup
5) Cloudflare SSL certificates
6) Enable BBR
7) Client Sing-Box configs with routing rules for Russia
 
### Usage:

```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Sing-Box-NGINX-WS/master/sb_nginx_server.sh)
```
If you want to set up your *__own website__* on the server then upload the folder with its contents to *__/root__* directory before running the script, and the script will set it up for you.

### Client setup guidelines (In Russian):
[Android and iOS](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/Sing-Box-Android-iOS.pdf)

[Windows 10 and 11](https://github.com/BLUEBL0B/Sing-Box-NGINX-WS/blob/main/Sing-Box-Windows-10-11.pdf)
