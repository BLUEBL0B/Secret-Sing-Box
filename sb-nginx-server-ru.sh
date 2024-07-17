#!/bin/bash

serverip=$(curl -s ipinfo.io/ip)

textcolor='\033[1;36m'
red='\033[1;31m'
clear='\033[0m'


### ВВОД ДАННЫХ ###
echo ""
echo ""
echo -e "${textcolor}ВНИМАНИЕ!${clear}"
echo "Перед запуском скрипта рекомендуется выполнить следующие действия:"
echo -e "1) Обновить систему командой ${textcolor}apt update && apt full-upgrade -y${clear}"
echo -e "2) Перезагрузить сервер командой ${textcolor}reboot${clear}"
echo -e "3) При наличии своего сайта отправить на сервер папку с его файлами командой ${textcolor}scp -r /home/USERNAME/SITE_FOLDER root@${serverip}:/root${clear}"
echo "4) Подключиться к серверу заново"
echo ""
echo -e "Если это сделано, то нажмите ${textcolor}Enter${clear}, чтобы продолжить"
echo -e "В противном случае нажмите ${textcolor}Ctrl + C${clear}"
read BigRedButton
echo ""
echo "Введите новый порт SSH:"
read sshp
echo ""
while [ $sshp -gt 65535 ]
do
    echo -e "${red}Ошибка: номер порта не может быть больше 65535${clear}"
    echo ""
    echo "Введите новый порт SSH:"
    read sshp
    echo ""
done
echo "Введите имя пользователя:"
read username
echo ""
echo "Введите пароль пользователя:"
read password
echo ""
echo "Введите ваш домен:"
read domain
echo ""
if [[ "$domain" == "www."* ]]
then
    domain=${domain#"www."}
fi
echo "Введите вашу почту, зарегистрированную на Cloudflare:"
read email
echo ""
echo "Введите ваш Cloudflare API token, имеющий права редактирования DNS, либо Cloudflare global API key:"
read cfkey
echo ""
echo "Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
read trjpass
echo ""
echo "Введите путь для Trojan или оставьте пустым для генерации случайного пути:"
read trojanpath
echo ""
if [[ "$trojanpath" == "/"* ]]
then
    trojanpath=${trojanpath#"/"}
fi
echo "Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
read uuid
echo ""
while [[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]] && [ ! -z "$uuid" ]
do
    echo -e "${red}Ошибка: введённое значение не является UUID${clear}"
    echo ""
    echo "Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
    read uuid
    echo ""
done
echo "Введите путь для VLESS или оставьте пустым для генерации случайного пути:"
read vlesspath
echo ""
if [[ "$vlesspath" == "/"* ]]
then
    vlesspath=${vlesspath#"/"}
fi
while [ "$trojanpath" = "$vlesspath" ] && [ ! -z "$vlesspath" ]
do
    echo -e "${red}Ошибка: пути для Trojan и VLESS не должны совпадать${clear}"
    echo ""
    echo "Введите путь для VLESS или оставьте пустым для генерации случайного пути:"
    read vlesspath
    echo ""
    if [[ "$vlesspath" == "/"* ]]
    then
        vlesspath=${vlesspath#"/"}
    fi
done
echo "Выберите вариант настройки NGINX (1 по умолчанию):"
echo "1 - Будет спрашивать логин и пароль вместо сайта"
echo "2 - Будет перенаправлять на другой домен"
echo "3 - Свой сайт (при наличии)"
read option;
echo ""
case $option in
    2)
    comment1=" "
    comment2="#"
    comment3=" "
    sitedir="html"
    index="index.html index.htm"
    echo "Введите домен, на который будет идти перенаправление:"
    read redirect
    echo ""
    if [[ "$redirect" == "www."* ]]
    then
        redirect=${redirect#"www."}
    fi
    ;;
    3)
    comment1=" "
    comment2=" "
    comment3="#"
    redirect="${domain}"
    echo "Введите название папки с файлами вашего сайта, загруженной в /root:"
    read sitedir
    echo ""
    while [ ! -d /root/${sitedir} ] || [ -z "$sitedir" ]
    do
        echo -e "${red}Ошибка: папка c введённым названием не существует в /root${clear}"
        echo ""
        echo "Введите название папки с файлами вашего сайта:"
        read sitedir
        echo ""
    done
    echo "Введите название index файла вашего сайта:"
    read index
    echo ""
    while [ ! -f /root/${sitedir}/${index} ] || [ -z "$index" ]
    do
        echo -e "${red}Ошибка: файл c введённым названием не существует в /root/${sitedir}${clear}"
        echo ""
        echo "Введите название index файла вашего сайта:"
        read index
        echo ""
    done
    ;;
    *)
    comment1="#"
    comment2=" "
    comment3=" "
    redirect="${domain}"
    sitedir="html"
    index="index.html index.htm"
esac
echo "Введите часовой пояс для установки времени на сервере (например, Europe/Amsterdam):"
read timezone
echo ""
while [ ! -f /usr/share/zoneinfo/${timezone} ]
do
    echo -e "${red}Ошибка: введённого часового пояса не существует в /usr/share/zoneinfo, проверьте правильность написания${clear}"
    echo ""
    echo "Введите часовой пояс для установки времени на сервере (например, Europe/Amsterdam):"
    read timezone
    echo ""
done
echo ""
echo ""

timedatectl set-timezone ${timezone}


### BBR ###
if ! sysctl net.core.default_qdisc | grep 'fq'
then
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
fi

if ! sysctl net.ipv4.tcp_congestion_control | grep 'bbr'
then
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
fi

sysctl -p
echo ""


### УСТАНОВКА ПАКЕТОВ ###
apt install sudo ufw certbot python3-certbot-dns-cloudflare gnupg2 nginx-full unattended-upgrades -y

curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
apt-get update && apt-get install cloudflare-warp -y

curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
chmod a+r /etc/apt/keyrings/sagernet.asc
echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | tee /etc/apt/sources.list.d/sagernet.list > /dev/null
apt-get update
apt-get install sing-box -y


### БЕЗОПАСНОСТЬ ###
useradd -m -s $(which bash) -G sudo ${username}
echo "${username}:${password}" | chpasswd

cat > /etc/ssh/sshd_config <<EOF
# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# This sshd was compiled with PATH=/usr/local/bin:/usr/bin:/bin:/usr/games

# The strategy used for options in the default sshd_config shipped with
# OpenSSH is to specify options with their default value where
# possible, but leave them commented.  Uncommented options override the
# default value.

Include /etc/ssh/sshd_config.d/*.conf

Port ${sshp}
#AddressFamily any
#ListenAddress 0.0.0.0
#ListenAddress ::

#HostKey /etc/ssh/ssh_host_rsa_key
#HostKey /etc/ssh/ssh_host_ecdsa_key
#HostKey /etc/ssh/ssh_host_ed25519_key

# Ciphers and keying
#RekeyLimit default none

# Logging
#SyslogFacility AUTH
#LogLevel INFO

# Authentication:

#LoginGraceTime 2m
PermitRootLogin no
#StrictModes yes
#MaxAuthTries 6
#MaxSessions 10

#PubkeyAuthentication yes

# Expect .ssh/authorized_keys2 to be disregarded by default in future.
#AuthorizedKeysFile     .ssh/authorized_keys .ssh/authorized_keys2

#AuthorizedPrincipalsFile none

#AuthorizedKeysCommand none
#AuthorizedKeysCommandUser nobody

# For this to work you will also need host keys in /etc/ssh/ssh_known_hosts
#HostbasedAuthentication no
# Change to yes if you don't trust ~/.ssh/known_hosts for
# HostbasedAuthentication
#IgnoreUserKnownHosts no
# Don't read the user's ~/.rhosts and ~/.shosts files
#IgnoreRhosts yes

# To disable tunneled clear text passwords, change to no here!
PasswordAuthentication yes
#PermitEmptyPasswords no

# Change to yes to enable challenge-response passwords (beware issues with
# some PAM modules and threads)
KbdInteractiveAuthentication no

# Kerberos options
#KerberosAuthentication no
#KerberosOrLocalPasswd yes
#KerberosTicketCleanup yes
#KerberosGetAFSToken no

# GSSAPI options
#GSSAPIAuthentication no
#GSSAPICleanupCredentials yes
#GSSAPIStrictAcceptorCheck yes
#GSSAPIKeyExchange no

# Set this to 'yes' to enable PAM authentication, account processing,
# and session processing. If this is enabled, PAM authentication will
# be allowed through the KbdInteractiveAuthentication and
# PasswordAuthentication.  Depending on your PAM configuration,
# PAM authentication via KbdInteractiveAuthentication may bypass
# the setting of "PermitRootLogin prohibit-password".
# If you just want the PAM account and session checks to run without
# PAM authentication, then enable this but set PasswordAuthentication
# and KbdInteractiveAuthentication to 'no'.
UsePAM yes

#AllowAgentForwarding yes
#AllowTcpForwarding yes
#GatewayPorts no
X11Forwarding yes
#X11DisplayOffset 10
#X11UseLocalhost yes
#PermitTTY yes
PrintMotd no
#PrintLastLog yes
#TCPKeepAlive yes
#PermitUserEnvironment no
#Compression delayed
#ClientAliveInterval 0
#ClientAliveCountMax 3
#UseDNS no
#PidFile /run/sshd.pid
#MaxStartups 10:30:100
#PermitTunnel no
#ChrootDirectory none
#VersionAddendum none

# no default banner path
#Banner none

# Allow client to pass locale environment variables
AcceptEnv LANG LC_*

# override default of no subsystems
Subsystem       sftp    /usr/lib/openssh/sftp-server

# Example of overriding settings on a per-user basis
#Match User anoncvs
#       X11Forwarding no
#       AllowTcpForwarding no
#       PermitTTY no
#       ForceCommand cvs server
EOF

systemctl restart ssh.service

ufw allow ${sshp}/tcp
ufw allow 443/tcp
ufw allow 80/tcp
yes | ufw enable

echo 'Unattended-Upgrade::Mail "root";' >> /etc/apt/apt.conf.d/50unattended-upgrades
echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades
systemctl restart unattended-upgrades


### СЕРТИФИКАТЫ ###
touch cloudflare.credentials
chown root:root cloudflare.credentials
chmod 600 cloudflare.credentials

echo "dns_cloudflare_email = ${email}" >> /root/cloudflare.credentials
echo "dns_cloudflare_api_key = ${cfkey}" >> /root/cloudflare.credentials

certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/cloudflare.credentials --dns-cloudflare-propagation-seconds 30 --rsa-key-size 4096 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive

{ crontab -l; echo "0 0 1 */2 * certbot -q renew"; } | crontab -
echo "renew_hook = systemctl reload nginx" >> /etc/letsencrypt/renewal/${domain}.conf
echo ""


### WARP ###
echo "WARP"
yes | warp-cli registration new
warp-cli mode proxy
warp-cli proxy port 40000
warp-cli connect
echo ""


### SING-BOX ###
systemctl enable sing-box.service
systemctl start sing-box.service

if [ -z "$trjpass" ]
then
    trjpass=$(sing-box generate uuid)
fi

if [ -z "$trojanpath" ]
then
    trojanpath=$(sing-box generate uuid)
fi

if [ -z "$uuid" ]
then
    uuid=$(sing-box generate uuid)
fi

if [ -z "$vlesspath" ]
then
    vlesspath=$(sing-box generate uuid)
fi

cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "level": "fatal",
    "output": "box.log",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "dns-remote",
        "address": "tls://1.1.1.1"
      },
      {
        "tag": "dns-block",
        "address": "rcode://success"
      }
    ],
    "rules": [
      {
        "rule_set": [
          "category-ads-all"
        ],
        "server": "dns-block"
      },
      {
        "outbound": "any",
        "server": "dns-remote"
      }
    ]
  },
  "inbounds": [
    {
      "type": "trojan",
      "tag": "trojan-ws-in",
      "listen": "127.0.0.1",
      "listen_port": 10443,
      "sniff": true,
      "users": [
        {
          "name": "me",
          "password": "${trjpass}"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/${trojanpath}"
      },
      "multiplex": {
        "enabled": true,
        "padding": true
      }
    },
    {
      "type": "vless",
      "tag": "vless-ws-in",
      "listen": "127.0.0.1",
      "listen_port": 11443,
      "sniff": true,
      "users": [
        {
          "name": "me",
          "uuid": "${uuid}"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/${vlesspath}"
      },
      "multiplex": {
        "enabled": true,
        "padding": true
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "direct",
      "tag": "IPv4",
      "domain_strategy": "ipv4_only"
    },
    {
      "type": "socks",
      "tag": "warp",
      "server": "127.0.0.1",
      "server_port": 40000
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "rule_set": [
          "category-ads-all"
        ],
        "protocol": "quic",
        "outbound": "block"
      },
      {
        "rule_set": [
          "google"
        ],
        "outbound": "IPv4"
      },
      {
        "rule_set": [
          "geoip-ru",
          "gov-ru"
        ],
        "domain_suffix": [
          ".ru",
          ".su",
          ".ru.com",
          ".ru.net",
          "rutracker.org",
          "habr.com",
          "ntc.party",
          "meduza.io",
          "svoboda.org"
        ],
        "domain_keyword": [
          "xn--"
        ],
        "outbound": "warp"
      }
    ],
    "rule_set": [
      {
        "tag": "geoip-ru",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs"
      },
      {
        "tag": "gov-ru",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-category-gov-ru.srs"
      },
      {
        "tag": "google",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-google.srs"
      },
      {
        "tag": "category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-category-ads-all.srs"
      }
    ]
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "cache.db"
    }
  }
}
EOF

systemctl restart sing-box.service

touch /home/${username}/TRJ-WS.json /home/${username}/VLESS-WS.json

cat > /home/${username}/TRJ-WS.json <<EOF
{
  "log": {
    "level": "fatal",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "dns-remote",
        "address": "tls://1.1.1.1",
        "client_subnet": "${serverip}"
      },
      {
        "tag": "dns-local",
        "address": "tls://1.1.1.1"
      },
      {
        "tag": "dns-block",
        "address": "rcode://success"
      }
    ],
    "rules": [
      {
        "rule_set": [
          "category-ads-all"
        ],
        "server": "dns-block"
      },
      {
        "domain_suffix": [
          "gemini.google.com",
          "bard.google.com",
          "generativelanguage.googleapis.com",
          "ai.google.dev",
          "aida.googleapis.com",
          "aistudio.google.com",
          "alkalimakersuite-pa.clients6.google.com",
          "makersuite.google.com",
          "deepmind.com",
          "deepmind.google",
          "generativeai.google",
          "proactivebackend-pa.googleapis.com"
        ],
        "domain_keyword": [
          "generativelanguage"
        ],
        "rule_set": [
          "openai"
        ],
        "server": "dns-remote"
      },
      {
        "domain_suffix": [
          ".ru",
          ".su",
          ".ru.com",
          ".ru.net",
          "${domain}",
          "wikipedia.org",
          "independent.co.uk"
        ],
        "domain_keyword": [
          "xn--",
          "researchgate",
          "springer",
          "nextcloud",
          "skype",
          "wiki",
          "kaspersky",
          "stepik",
          "likee",
          "snapchat",
          "yappy",
          "pikabu",
          "okko",
          "wink",
          "kion",
          "viber",
          "roblox",
          "ozon",
          "wildberries",
          "aliexpress",
          "theguardian",
          "politico",
          "washingtonpost"
        ],
        "rule_set": [
          "geoip-ru",
          "gov-ru",
          "whatsapp",
          "yandex",
          "telegram",
          "vk",
          "mailru",
          "discord",
          "zoom",
          "reddit",
          "twitch",
          "tumblr",
          "4chan",
          "tiktok",
          "pinterest",
          "deviantart",
          "google",
          "duckduckgo",
          "yahoo",
          "mozilla",
          "category-android-app-download",
          "aptoide",
          "samsung",
          "huawei",
          "apple",
          "microsoft",
          "nvidia",
          "xiaomi",
          "hp",
          "asus",
          "lenovo",
          "lg",
          "oracle",
          "adobe",
          "blender",
          "drweb",
          "gitlab",
          "debian",
          "canonical",
          "python",
          "doi",
          "elsevier",
          "sciencedirect",
          "clarivate",
          "sci-hub",
          "duolingo",
          "aljazeera",
          "cnn",
          "reuters",
          "bloomberg",
          "nytimes"
        ],
        "server": "dns-local"
      },
      {
        "inbound": [
          "tun-in"
        ],
        "server": "dns-remote"
      }
    ],
    "final": "dns-local"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "singbox_tun",
      "stack": "system",
      "mtu": 9000,
      "inet4_address": "172.19.0.1/28",
      "auto_route": true,
      "strict_route": true,
      "inet4_route_exclude_address": [
        "10.0.0.0/8",
        "100.64.0.0/10",
        "169.254.0.0/16",
        "172.16.0.0/12",
        "192.0.0.0/24",
        "192.0.2.0/24",
        "192.88.99.0/24",
        "192.168.0.0/16",
        "198.51.100.0/24",
        "203.0.113.0/24",
        "224.0.0.0/4",
        "255.255.255.255/32",
        "239.255.255.250/32"
      ],
      "sniff": true,
      "sniff_override_destination": true
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    },
    {
      "type": "trojan",
      "tag": "proxy",
      "server": "${domain}",
      "server_port": 443,
      "password": "${trjpass}",
      "tls": {
        "enabled": true,
        "server_name": "${domain}",
        "utls": {
          "enabled": true,
          "fingerprint": "randomized"
        }
      },
      "multiplex": {
        "enabled": true,
        "padding": true
      },
      "transport": {
        "type": "ws",
        "path": "/${trojanpath}"
      }
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "protocol": "quic",
        "outbound": "block"
      },
      {
        "rule_set": [
          "category-ads-all"
        ],
        "outbound": "block"
      },
      {
        "domain_suffix": [
          "gemini.google.com",
          "bard.google.com",
          "generativelanguage.googleapis.com",
          "ai.google.dev",
          "aida.googleapis.com",
          "aistudio.google.com",
          "alkalimakersuite-pa.clients6.google.com",
          "makersuite.google.com",
          "deepmind.com",
          "deepmind.google",
          "generativeai.google",
          "proactivebackend-pa.googleapis.com"
        ],
        "domain_keyword": [
          "generativelanguage"
        ],
        "rule_set": [
          "openai"
        ],
        "outbound": "proxy"
      },
      {
        "domain_suffix": [
          ".ru",
          ".su",
          ".ru.com",
          ".ru.net",
          "${domain}",
          "wikipedia.org",
          "independent.co.uk"
        ],
        "domain_keyword": [
          "xn--",
          "researchgate",
          "springer",
          "nextcloud",
          "skype",
          "wiki",
          "kaspersky",
          "stepik",
          "likee",
          "snapchat",
          "yappy",
          "pikabu",
          "okko",
          "wink",
          "kion",
          "viber",
          "roblox",
          "ozon",
          "wildberries",
          "aliexpress",
          "theguardian",
          "politico",
          "washingtonpost"
        ],
        "rule_set": [
          "geoip-ru",
          "gov-ru",
          "whatsapp",
          "yandex",
          "telegram",
          "vk",
          "mailru",
          "discord",
          "zoom",
          "reddit",
          "twitch",
          "tumblr",
          "4chan",
          "tiktok",
          "pinterest",
          "deviantart",
          "google",
          "duckduckgo",
          "yahoo",
          "mozilla",
          "category-android-app-download",
          "aptoide",
          "samsung",
          "huawei",
          "apple",
          "microsoft",
          "nvidia",
          "xiaomi",
          "hp",
          "asus",
          "lenovo",
          "lg",
          "oracle",
          "adobe",
          "blender",
          "drweb",
          "gitlab",
          "debian",
          "canonical",
          "python",
          "doi",
          "elsevier",
          "sciencedirect",
          "clarivate",
          "sci-hub",
          "duolingo",
          "aljazeera",
          "cnn",
          "reuters",
          "bloomberg",
          "nytimes"
        ],
        "outbound": "direct"
      },
      {
        "inbound": [
          "tun-in"
        ],
        "outbound": "proxy"
      }
    ],
    "rule_set": [
      {
        "tag": "geoip-ru",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geoip/raw/rule-set/geoip-ru.srs"
      },
      {
        "tag": "gov-ru",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-category-gov-ru.srs"
      },
      {
        "tag": "whatsapp",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-whatsapp.srs"
      },
      {
        "tag": "yandex",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-yandex.srs"
      },
      {
        "tag": "telegram",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-telegram.srs"
      },
      {
        "tag": "vk",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-vk.srs"
      },
      {
        "tag": "mailru",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-mailru.srs"
      },
      {
        "tag": "discord",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-discord.srs"
      },
      {
        "tag": "zoom",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-zoom.srs"
      },
      {
        "tag": "reddit",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-reddit.srs"
      },
      {
        "tag": "twitch",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-twitch.srs"
      },
      {
        "tag": "tumblr",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-tumblr.srs"
      },
      {
        "tag": "4chan",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-4chan.srs"
      },
      {
        "tag": "tiktok",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-tiktok.srs"
      },
      {
        "tag": "pinterest",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-pinterest.srs"
      },
      {
        "tag": "deviantart",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-deviantart.srs"
      },
      {
        "tag": "google",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-google.srs"
      },
      {
        "tag": "duckduckgo",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-duckduckgo.srs"
      },
      {
        "tag": "yahoo",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-yahoo.srs"
      },
      {
        "tag": "mozilla",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-mozilla.srs"
      },
      {
        "tag": "category-android-app-download",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-category-android-app-download.srs"
      },
      {
        "tag": "aptoide",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-aptoide.srs"
      },
      {
        "tag": "samsung",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-samsung.srs"
      },
      {
        "tag": "huawei",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-huawei.srs"
      },
      {
        "tag": "apple",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-apple.srs"
      },
      {
        "tag": "microsoft",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-microsoft.srs"
      },
      {
        "tag": "nvidia",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-nvidia.srs"
      },
      {
        "tag": "xiaomi",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-xiaomi.srs"
      },
      {
        "tag": "hp",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-hp.srs"
      },
      {
        "tag": "asus",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-asus.srs"
      },
      {
        "tag": "lenovo",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-lenovo.srs"
      },
      {
        "tag": "lg",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-lg.srs"
      },
      {
        "tag": "oracle",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-oracle.srs"
      },
      {
        "tag": "adobe",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-adobe.srs"
      },
      {
        "tag": "blender",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-blender.srs"
      },
      {
        "tag": "drweb",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-drweb.srs"
      },
      {
        "tag": "gitlab",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-gitlab.srs"
      },
      {
        "tag": "debian",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-debian.srs"
      },
      {
        "tag": "canonical",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-canonical.srs"
      },
      {
        "tag": "python",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-python.srs"
      },
      {
        "tag": "doi",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-doi.srs"
      },
      {
        "tag": "elsevier",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-elsevier.srs"
      },
      {
        "tag": "sciencedirect",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-sciencedirect.srs"
      },
      {
        "tag": "clarivate",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-clarivate.srs"
      },
      {
        "tag": "sci-hub",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-sci-hub.srs"
      },
      {
        "tag": "duolingo",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-duolingo.srs"
      },
      {
        "tag": "aljazeera",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-aljazeera.srs"
      },
      {
        "tag": "cnn",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-cnn.srs"
      },
      {
        "tag": "reuters",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-reuters.srs"
      },
      {
        "tag": "bloomberg",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-bloomberg.srs"
      },
      {
        "tag": "nytimes",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-nytimes.srs"
      },
      {
        "tag": "openai",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-openai.srs"
      },
      {
        "tag": "category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-category-ads-all.srs"
      }
    ],
    "auto_detect_interface": true,
    "override_android_vpn": true
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "cache.db"
    }
  }
}
EOF

cat > /home/${username}/VLESS-WS.json <<EOF
{
  "log": {
    "level": "fatal",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "dns-remote",
        "address": "tls://1.1.1.1",
        "client_subnet": "${serverip}"
      },
      {
        "tag": "dns-local",
        "address": "tls://1.1.1.1"
      },
      {
        "tag": "dns-block",
        "address": "rcode://success"
      }
    ],
    "rules": [
      {
        "rule_set": [
          "category-ads-all"
        ],
        "server": "dns-block"
      },
      {
        "domain_suffix": [
          "gemini.google.com",
          "bard.google.com",
          "generativelanguage.googleapis.com",
          "ai.google.dev",
          "aida.googleapis.com",
          "aistudio.google.com",
          "alkalimakersuite-pa.clients6.google.com",
          "makersuite.google.com",
          "deepmind.com",
          "deepmind.google",
          "generativeai.google",
          "proactivebackend-pa.googleapis.com"
        ],
        "domain_keyword": [
          "generativelanguage"
        ],
        "rule_set": [
          "openai"
        ],
        "server": "dns-remote"
      },
      {
        "domain_suffix": [
          ".ru",
          ".su",
          ".ru.com",
          ".ru.net",
          "${domain}",
          "wikipedia.org",
          "independent.co.uk"
        ],
        "domain_keyword": [
          "xn--",
          "researchgate",
          "springer",
          "nextcloud",
          "skype",
          "wiki",
          "kaspersky",
          "stepik",
          "likee",
          "snapchat",
          "yappy",
          "pikabu",
          "okko",
          "wink",
          "kion",
          "viber",
          "roblox",
          "ozon",
          "wildberries",
          "aliexpress",
          "theguardian",
          "politico",
          "washingtonpost"
        ],
        "rule_set": [
          "geoip-ru",
          "gov-ru",
          "whatsapp",
          "yandex",
          "telegram",
          "vk",
          "mailru",
          "discord",
          "zoom",
          "reddit",
          "twitch",
          "tumblr",
          "4chan",
          "tiktok",
          "pinterest",
          "deviantart",
          "google",
          "duckduckgo",
          "yahoo",
          "mozilla",
          "category-android-app-download",
          "aptoide",
          "samsung",
          "huawei",
          "apple",
          "microsoft",
          "nvidia",
          "xiaomi",
          "hp",
          "asus",
          "lenovo",
          "lg",
          "oracle",
          "adobe",
          "blender",
          "drweb",
          "gitlab",
          "debian",
          "canonical",
          "python",
          "doi",
          "elsevier",
          "sciencedirect",
          "clarivate",
          "sci-hub",
          "duolingo",
          "aljazeera",
          "cnn",
          "reuters",
          "bloomberg",
          "nytimes"
        ],
        "server": "dns-local"
      },
      {
        "inbound": [
          "tun-in"
        ],
        "server": "dns-remote"
      }
    ],
    "final": "dns-local"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "singbox_tun",
      "stack": "system",
      "mtu": 9000,
      "inet4_address": "172.19.0.1/28",
      "auto_route": true,
      "strict_route": true,
      "inet4_route_exclude_address": [
        "10.0.0.0/8",
        "100.64.0.0/10",
        "169.254.0.0/16",
        "172.16.0.0/12",
        "192.0.0.0/24",
        "192.0.2.0/24",
        "192.88.99.0/24",
        "192.168.0.0/16",
        "198.51.100.0/24",
        "203.0.113.0/24",
        "224.0.0.0/4",
        "255.255.255.255/32",
        "239.255.255.250/32"
      ],
      "sniff": true,
      "sniff_override_destination": true
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    },
    {
      "type": "vless",
      "tag": "proxy",
      "server": "${domain}",
      "server_port": 443,
      "uuid": "${uuid}",
      "tls": {
        "enabled": true,
        "server_name": "${domain}",
        "utls": {
          "enabled": true,
          "fingerprint": "randomized"
        }
      },
      "multiplex": {
        "enabled": true,
        "padding": true
      },
      "transport": {
        "type": "ws",
        "path": "/${vlesspath}"
      }
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "protocol": "quic",
        "outbound": "block"
      },
      {
        "rule_set": [
          "category-ads-all"
        ],
        "outbound": "block"
      },
      {
        "domain_suffix": [
          "gemini.google.com",
          "bard.google.com",
          "generativelanguage.googleapis.com",
          "ai.google.dev",
          "aida.googleapis.com",
          "aistudio.google.com",
          "alkalimakersuite-pa.clients6.google.com",
          "makersuite.google.com",
          "deepmind.com",
          "deepmind.google",
          "generativeai.google",
          "proactivebackend-pa.googleapis.com"
        ],
        "domain_keyword": [
          "generativelanguage"
        ],
        "rule_set": [
          "openai"
        ],
        "outbound": "proxy"
      },
      {
        "domain_suffix": [
          ".ru",
          ".su",
          ".ru.com",
          ".ru.net",
          "${domain}",
          "wikipedia.org",
          "independent.co.uk"
        ],
        "domain_keyword": [
          "xn--",
          "researchgate",
          "springer",
          "nextcloud",
          "skype",
          "wiki",
          "kaspersky",
          "stepik",
          "likee",
          "snapchat",
          "yappy",
          "pikabu",
          "okko",
          "wink",
          "kion",
          "viber",
          "roblox",
          "ozon",
          "wildberries",
          "aliexpress",
          "theguardian",
          "politico",
          "washingtonpost"
        ],
        "rule_set": [
          "geoip-ru",
          "gov-ru",
          "whatsapp",
          "yandex",
          "telegram",
          "vk",
          "mailru",
          "discord",
          "zoom",
          "reddit",
          "twitch",
          "tumblr",
          "4chan",
          "tiktok",
          "pinterest",
          "deviantart",
          "google",
          "duckduckgo",
          "yahoo",
          "mozilla",
          "category-android-app-download",
          "aptoide",
          "samsung",
          "huawei",
          "apple",
          "microsoft",
          "nvidia",
          "xiaomi",
          "hp",
          "asus",
          "lenovo",
          "lg",
          "oracle",
          "adobe",
          "blender",
          "drweb",
          "gitlab",
          "debian",
          "canonical",
          "python",
          "doi",
          "elsevier",
          "sciencedirect",
          "clarivate",
          "sci-hub",
          "duolingo",
          "aljazeera",
          "cnn",
          "reuters",
          "bloomberg",
          "nytimes"
        ],
        "outbound": "direct"
      },
      {
        "inbound": [
          "tun-in"
        ],
        "outbound": "proxy"
      }
    ],
    "rule_set": [
      {
        "tag": "geoip-ru",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geoip/raw/rule-set/geoip-ru.srs"
      },
      {
        "tag": "gov-ru",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-category-gov-ru.srs"
      },
      {
        "tag": "whatsapp",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-whatsapp.srs"
      },
      {
        "tag": "yandex",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-yandex.srs"
      },
      {
        "tag": "telegram",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-telegram.srs"
      },
      {
        "tag": "vk",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-vk.srs"
      },
      {
        "tag": "mailru",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-mailru.srs"
      },
      {
        "tag": "discord",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-discord.srs"
      },
      {
        "tag": "zoom",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-zoom.srs"
      },
      {
        "tag": "reddit",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-reddit.srs"
      },
      {
        "tag": "twitch",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-twitch.srs"
      },
      {
        "tag": "tumblr",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-tumblr.srs"
      },
      {
        "tag": "4chan",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-4chan.srs"
      },
      {
        "tag": "tiktok",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-tiktok.srs"
      },
      {
        "tag": "pinterest",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-pinterest.srs"
      },
      {
        "tag": "deviantart",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-deviantart.srs"
      },
      {
        "tag": "google",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-google.srs"
      },
      {
        "tag": "duckduckgo",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-duckduckgo.srs"
      },
      {
        "tag": "yahoo",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-yahoo.srs"
      },
      {
        "tag": "mozilla",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-mozilla.srs"
      },
      {
        "tag": "category-android-app-download",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-category-android-app-download.srs"
      },
      {
        "tag": "aptoide",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-aptoide.srs"
      },
      {
        "tag": "samsung",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-samsung.srs"
      },
      {
        "tag": "huawei",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-huawei.srs"
      },
      {
        "tag": "apple",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-apple.srs"
      },
      {
        "tag": "microsoft",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-microsoft.srs"
      },
      {
        "tag": "nvidia",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-nvidia.srs"
      },
      {
        "tag": "xiaomi",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-xiaomi.srs"
      },
      {
        "tag": "hp",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-hp.srs"
      },
      {
        "tag": "asus",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-asus.srs"
      },
      {
        "tag": "lenovo",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-lenovo.srs"
      },
      {
        "tag": "lg",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-lg.srs"
      },
      {
        "tag": "oracle",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-oracle.srs"
      },
      {
        "tag": "adobe",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-adobe.srs"
      },
      {
        "tag": "blender",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-blender.srs"
      },
      {
        "tag": "drweb",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-drweb.srs"
      },
      {
        "tag": "gitlab",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-gitlab.srs"
      },
      {
        "tag": "debian",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-debian.srs"
      },
      {
        "tag": "canonical",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-canonical.srs"
      },
      {
        "tag": "python",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-python.srs"
      },
      {
        "tag": "doi",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-doi.srs"
      },
      {
        "tag": "elsevier",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-elsevier.srs"
      },
      {
        "tag": "sciencedirect",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-sciencedirect.srs"
      },
      {
        "tag": "clarivate",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-clarivate.srs"
      },
      {
        "tag": "sci-hub",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-sci-hub.srs"
      },
      {
        "tag": "duolingo",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-duolingo.srs"
      },
      {
        "tag": "aljazeera",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-aljazeera.srs"
      },
      {
        "tag": "cnn",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-cnn.srs"
      },
      {
        "tag": "reuters",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-reuters.srs"
      },
      {
        "tag": "bloomberg",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-bloomberg.srs"
      },
      {
        "tag": "nytimes",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-nytimes.srs"
      },
      {
        "tag": "openai",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-openai.srs"
      },
      {
        "tag": "category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-category-ads-all.srs"
      }
    ],
    "auto_detect_interface": true,
    "override_android_vpn": true
  },
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "cache.db"
    }
  }
}
EOF


### NGINX ###
if [ $option -eq 3 ]
then
    mv /root/${sitedir} /var/www
fi

if [ $option -ne 2 ] && [ $option -ne 3 ]
then
    touch /etc/nginx/.htpasswd
fi

append='~^(,[ \\t]*)*([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?(;([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?)*([ \\t]*,([ \\t]*([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?(;([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?)*)?)*$" "$http_forwarded, $proxy_forwarded_elem'

cat > /etc/nginx/nginx.conf <<EOF
user                 www-data;
pid                  /run/nginx.pid;
worker_processes     auto;
worker_rlimit_nofile 65535;

# Load modules
include              /etc/nginx/modules-enabled/*.conf;

events {
    multi_accept       on;
    worker_connections 65535;
}

http {
    sendfile                  on;
    tcp_nopush                on;
    tcp_nodelay               on;
    server_tokens             off;
    types_hash_max_size       2048;
    types_hash_bucket_size    64;
    client_max_body_size      16M;

    # Timeout
    keepalive_timeout         60s;
    keepalive_requests        1000;
    reset_timedout_connection on;

    # MIME
    include                   mime.types;
    default_type              application/octet-stream;

    # Logging
    access_log                off;
    error_log                 off;

    # SSL
    ssl_session_timeout       1d;
    ssl_session_cache         shared:SSL:10m;
    ssl_session_tickets       off;

    # Mozilla Intermediate configuration
    ssl_protocols             TLSv1.2 TLSv1.3;
    ssl_ciphers               TLS13_AES_128_GCM_SHA256:TLS13_AES_256_GCM_SHA384:TLS13_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305;

    # OCSP Stapling
    ssl_stapling              on;
    ssl_stapling_verify       on;
    resolver                  1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4 208.67.222.222 208.67.220.220 valid=60s;
    resolver_timeout          2s;

    # Connection header for WebSocket reverse proxy
    map \$http_upgrade \$connection_upgrade {
        default upgrade;
        ""      close;
    }

    map \$remote_addr \$proxy_forwarded_elem {

        # IPv4 addresses can be sent as-is
        ~^[0-9.]+$        "for=\$remote_addr";

        # IPv6 addresses need to be bracketed and quoted
        ~^[0-9A-Fa-f:.]+$ "for=\"[\$remote_addr]\"";

        # Unix domain socket names cannot be represented in RFC 7239 syntax
        default           "for=unknown";
    }

    map \$http_forwarded \$proxy_add_forwarded {

        # If the incoming Forwarded header is syntactically valid, append to it
        "${append}";

        # Otherwise, replace it
        default "\$proxy_forwarded_elem";
    }

    # Load configs
    include /etc/nginx/conf.d/*.conf;

    # Site
    server {
        listen                               443 ssl http2 default_server;
        listen                               [::]:443 ssl http2 default_server;
        server_name                          ${domain} www.${domain};
      ${comment1}${comment2}root                                 /var/www/${sitedir};
      ${comment1}${comment2}index                                ${index};

        # SSL
        ssl_certificate                      /etc/letsencrypt/live/${domain}/fullchain.pem;
        ssl_certificate_key                  /etc/letsencrypt/live/${domain}/privkey.pem;
        ssl_trusted_certificate              /etc/letsencrypt/live/${domain}/chain.pem;

        # Security headers
        add_header X-XSS-Protection          "1; mode=block" always;
        add_header X-Content-Type-Options    "nosniff" always;
        add_header Referrer-Policy           "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy   "default-src 'self' http: https: ws: wss: data: blob: 'unsafe-inline'; frame-ancestors 'self';" always;
        add_header Permissions-Policy        "interest-cohort=()" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
        add_header X-Frame-Options           "SAMEORIGIN";
        proxy_hide_header X-Powered-By;

        # . files
        location ~ /\.(?!well-known) {
            deny all;
        }

        # Main location
       ${comment3}location / {
          ${comment2}${comment3}root /var/www/html;
          ${comment2}${comment3}index index.html index.htm;
          ${comment2}${comment3}auth_basic "Login Required";
          ${comment2}${comment3}auth_basic_user_file /etc/nginx/.htpasswd;
          ${comment1}${comment3}return 301 https://${redirect}\$request_uri;
       ${comment3}}

        # Reverse proxy
        location = /${trojanpath} {
            if (\$http_upgrade != "websocket") {
                return 404;
            }
            proxy_pass                         http://127.0.0.1:10443;
            proxy_set_header Host              \$host;
            proxy_http_version                 1.1;
            proxy_cache_bypass                 \$http_upgrade;

            # Proxy SSL
            proxy_ssl_server_name              on;

            # Proxy headers
            proxy_set_header Upgrade           \$http_upgrade;
            proxy_set_header Connection        \$connection_upgrade;
            proxy_set_header X-Real-IP         \$remote_addr;
            proxy_set_header Forwarded         \$proxy_add_forwarded;
            proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Host  \$host;
            proxy_set_header X-Forwarded-Port  \$server_port;

            # Proxy timeouts
            proxy_connect_timeout              60s;
            proxy_send_timeout                 60s;
            proxy_read_timeout                 60s;
        }

        location = /${vlesspath} {
            if (\$http_upgrade != "websocket") {
                return 404;
            }
            proxy_pass                         http://127.0.0.1:11443;
            proxy_set_header Host              \$host;
            proxy_http_version                 1.1;
            proxy_cache_bypass                 \$http_upgrade;

            # Proxy SSL
            proxy_ssl_server_name              on;

            # Proxy headers
            proxy_set_header Upgrade           \$http_upgrade;
            proxy_set_header Connection        \$connection_upgrade;
            proxy_set_header X-Real-IP         \$remote_addr;
            proxy_set_header Forwarded         \$proxy_add_forwarded;
            proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Host  \$host;
            proxy_set_header X-Forwarded-Port  \$server_port;

            # Proxy timeouts
            proxy_connect_timeout              60s;
            proxy_send_timeout                 60s;
            proxy_read_timeout                 60s;
        }

        # gzip
        gzip            on;
        gzip_vary       on;
        gzip_proxied    any;
        gzip_comp_level 6;
        gzip_types      text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;
    }

    # HTTP redirect
    server {
        listen      80;
        listen      [::]:80;

        server_name ${domain} www.${domain};

        return 301 https://\$host\$request_uri;
    }
}
EOF

systemctl reload nginx


echo ""
echo ""
echo ""
echo -e "${textcolor}Если выше не возникло ошибок, то настройка завершена${clear}"
echo ""
echo -e "Конфиги для клиента сохранены в ${textcolor}/home/${username}/TRJ-WS.json${clear} и ${textcolor}/home/${username}/VLESS-WS.json${clear}, скопируйте их на устройство"
echo ""
echo -e "${textcolor}ВНИМАНИЕ!${clear}"
echo "Для повышения безопасности сервера рекомендуется выполнить следующие действия:"
echo -e "1) Отключиться от сервера ${textcolor}Ctrl + D${clear}"
echo -e "2) Если нет ключей SSH, то сгенерировать их на своём ПК командой ${textcolor}ssh-keygen -t rsa -b 4096${clear}"
echo -e "3) Отправить публичный ключ на сервер командой ${textcolor}ssh-copy-id -p ${sshp} ${username}@${serverip}${clear}"
echo -e "4) Подключиться к серверу ещё раз командой ${textcolor}ssh -p ${sshp} ${username}@${serverip}${clear}"
echo -e "5) Открыть конфиг sshd командой ${textcolor}sudo nano /etc/ssh/sshd_config${clear} и в PasswordAuthentication заменить yes на no"
echo -e "6) Перезапустить SSH командой ${textcolor}sudo systemctl restart ssh.service${clear}"
echo ""
