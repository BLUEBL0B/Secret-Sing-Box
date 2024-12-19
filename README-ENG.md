# Secret Sing-Box

[**Russian version**](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/README.md)

### Trojan and VLESS proxy with TLS termination on NGINX or HAProxy
This script is designed to fully configure a secure proxy server with [Sing-Box](https://sing-box.sagernet.org) core and [NGINX](https://nginx.org/en/) or [HAProxy](https://www.haproxy.org) camouflage. Two setup methods:
- All requests to the proxy are processed by NGINX, the requests are passed to Sing-Box only if they contain the correct path (WebSocket or HTTPUpgrade transport)
- All requests to the proxy are processed by HAProxy, the requests are passed to Sing-Box only if they contain the correct Trojan password (TCP transport) — [FPPweb3](https://github.com/FPPweb3) method

Both setup methods make it impossible to detect Sing-Box from the outside, which improves security.

> [!IMPORTANT]
> Recommended OS: Debian 11/12 or Ubuntu 22.04/24.04. You will also need your own domain linked to your Cloudflare account ([How to set it up?](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/cf-settings-en.md)). Run as root on a newly installed system. It's recommended to update and reboot the system before running this script.
>
> This project is created for educational and demonstration purposes. Please make sure that your actions are legal before using it.

> [!NOTE]
> With routing rules for Russia. Open ports on the server: 443 and SSH.
 
### Includes:
1) Sing-Box server setup
2) NGINX or HAProxy reverse proxy and website setup on port 443
3) Security setup (optional)
4) Cloudflare SSL certificates with auto renewal
5) WARP setup
6) Enable BBR
7) Client Sing-Box configs with routing rules for Russia
8) Automated management of user config files
9) Optional setup of proxy chains of two or more servers
 
### Usage:

To configure the server, run this command:

```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/install-server.sh)
```

Then just enter the necessary information:

![pic-1-en](https://github.com/user-attachments/assets/1ac0340b-4400-481f-a84a-51027a406685)

The script will show your client links in the end.

-----

To display additional settings, run this command:

```
sbmanager
```

Then follow the instructions:

![pic-2-en](https://github.com/user-attachments/assets/a2ee3d75-0dcf-4dda-a7d7-30657a5b8a1e)

Options 5 and 6 synchronize the settings in client configs of all users, which eliminates the need to edit the config of each user separately.

### WARP+ keys:

To activate a WARP+ key, enter this command (replace the key with yours):

```
warp-cli registration license CMD5m479-Y5hS6y79-U06c5mq9
```

### Client setup:
[Android and iOS:](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/Client-Guidelines/Sing-Box-Android-iOS-en.md) on some Android devices, especially older ones, "stack": "system" in tun interface settings in client configs might not work. In such cases, it is recommended to replace it with "gvisor" by using option 4 in sbmanager.

[Windows:](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/Client-Guidelines/Sing-Box-Windows-en.md) this method is recommended due to more complete routing settings, but you can also import the link to [Hiddify](https://github.com/hiddify/hiddify-app/releases/latest) client app.

[Linux:](https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/README-ENG.md#client-setup) run the command below and follow the instructions. Or use [Hiddify](https://github.com/hiddify/hiddify-app/releases/latest) client app.
```
bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/sb-pc-linux.sh)
```

### You can support the project if it's helpful to you:
- USDT (BEP20): 0xe2FeA540a9F1f85C2bfA3e6949c722393B5d636A
- USDT (ERC20): 0xe2FeA540a9F1f85C2bfA3e6949c722393B5d636A
- Bitcoin (BIP84): bc1qhn2ghk3pcpsrr6l9ywfryvqfzvyx8gs2wnpz89
- Litecoin (BIP84): ltc1q7quvcq3gtlwf2yuk370vhf2syad8ee4we9huj4
- Toncoin: UQCWmIBsU-EZJSH3rhghbtSOtKQBmb5y74mkjbohpDWZ6l-H

### Stargazers over time:
[![Stargazers over time](https://starchart.cc/BLUEBL0B/Secret-Sing-Box.svg?variant=adaptive)](https://starchart.cc/BLUEBL0B/Secret-Sing-Box)
