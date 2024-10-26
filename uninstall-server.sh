#!/bin/bash

textcolor='\033[0;36m'
textcolor_light='\033[1;36m'
red='\033[1;31m'
clear='\033[0m'

check_root() {
    if [[ $EUID -ne 0 ]]
    then
        echo ""
        echo -e "${red}Error: this script should be run as root${clear}"
        echo ""
        exit 1
    fi
}

enter_language() {
    echo ""
    echo ""
    echo -e "${textcolor}Select the language:${clear}"
    echo "1 - Russian"
    echo "2 - English"
    read language
    echo ""
    echo ""
}

get_data() {
    if [ -f /etc/nginx/nginx.conf ]
    then
        subspath=$(grep "location ~ ^/" /etc/nginx/nginx.conf | head -n 1)
        subspath=${subspath#*"location ~ ^/"}
        subspath=${subspath%" {"*}
    fi
}

ask_remove() {
    if [[ "${language}" == "1" ]]
    then
        echo -e "${red}ВАЖНО:${clear} при удалении не всех пакетов может потребоваться ручное исправление конфигурации оставшихся"
        echo ""
        echo -e "${textcolor}Введите номера, соответствующие пакетам, которые хотите удалить (например, 2345):${clear}"
        echo "0 - Выйти"
        echo "1 - Удалить все перечисленные ниже пакеты"
    else
        echo -e "${red}IMPORTANT:${clear} if you do not remove all the packages, you may need to manually correct the configuration of the remaining ones"
        echo ""
        echo -e "${textcolor}Enter the numbers of the packages you want to delete (e. g. 2345):${clear}"
        echo "0 - Exit"
        echo "1 - Delete all the packages listed below"
    fi
    echo "2 - Sing-Box"
    echo "3 - WARP"
    echo "4 - UFW"
    echo "5 - Unattended upgrades"
    if [[ "${language}" == "1" ]]
    then
        echo "6 - Certbot, python3-certbot-dns-cloudflare и сертификаты"
    else
        echo "6 - Certbot, python3-certbot-dns-cloudflare and certificates"
    fi
    echo "7 - NGINX"
    if dpkg -s haproxy &>/dev/null
    then
        echo "8 - HAProxy"
    fi
    read removenum
    echo ""
    echo ""

    if [[ ! "${removenum}" =~ ['12345678'] ]] || [[ "${removenum}" =~ "0" ]]
    then
        exit 0
    fi

    if [[ "${removenum}" =~ "1" ]]
    then
        removenum="2345678"
    fi
}

remove_sing_box() {
    if [[ "${removenum}" =~ "2" ]] && dpkg -s sing-box &>/dev/null
    then
        echo -e "${textcolor_light}Removing Sing-Box...${clear}"
        systemctl stop sing-box.service
        systemctl disable sing-box.service
        apt purge sing-box -y

        if [ -f /etc/nginx/nginx.conf ] && [ -d /var/www/${subspath} ]
        then
            rm -rf /var/www/${subspath}
        fi

        echo ""
    fi
}

remove_warp() {
    if [[ "${removenum}" =~ "3" ]] && dpkg -s cloudflare-warp &>/dev/null
    then
        echo -e "${textcolor_light}Removing WARP...${clear}"
        systemctl stop warp-svc.service
        systemctl disable warp-svc.service
        apt purge cloudflare-warp -y

        if [ -d /etc/systemd/system/warp-svc.service.d ]
        then
            rm -rf /etc/systemd/system/warp-svc.service.d
        fi

        echo ""
    fi
}

remove_ufw() {
    if [[ "${removenum}" =~ "4" ]] && dpkg -s ufw &>/dev/null
    then
        echo -e "${textcolor_light}Removing UFW...${clear}"
        ufw disable
        apt purge ufw -y
        echo ""
    fi
}

remove_unattended_upgrades() {
    if [[ "${removenum}" =~ "5" ]] && dpkg -s unattended-upgrades &>/dev/null
    then
        echo -e "${textcolor_light}Removing unattended-upgrades...${clear}"
        systemctl stop unattended-upgrades
        systemctl disable unattended-upgrades

        if [ -d /var/log/unattended-upgrades ]
        then
            rm -rf /var/log/unattended-upgrades
        fi

        apt purge unattended-upgrades -y
        echo ""
    fi
}

remove_certbot() {
    if [[ "${removenum}" =~ "6" ]] && dpkg -s certbot &>/dev/null
    then
        echo -e "${textcolor_light}Removing Certbot, python3-certbot-dns-cloudflare and certificates...${clear}"
        apt purge certbot python3-certbot-dns-cloudflare -y
        crontab -l | sed '/certbot -q renew/d' | crontab -
        echo ""
    fi
}

remove_nginx() {
    if [[ "${removenum}" =~ "7" ]] && dpkg -s nginx-full &>/dev/null
    then
        echo -e "${textcolor_light}Removing NGINX...${clear}"
        systemctl stop nginx.service
        systemctl disable nginx.service

        if [ -f /etc/nginx/nginx.conf ] && [ -d /var/www/${subspath} ]
        then
            rm -rf /var/www/${subspath}
        fi

        apt purge nginx-full -y

        echo ""
    fi
}

remove_haproxy() {
    if [[ "${removenum}" =~ "8" ]] && dpkg -s haproxy &>/dev/null
    then
        echo -e "${textcolor_light}Removing HAProxy...${clear}"
        systemctl stop haproxy.service
        systemctl disable haproxy.service

        if [ -d /var/lib/haproxy ]
        then
            rm -rf /var/lib/haproxy
        fi

        if [ -d /etc/haproxy ]
        then
            rm -rf /etc/haproxy
        fi

        apt purge haproxy -y
        echo ""
    fi
}

remove_other() {
    echo -e "${textcolor_light}Removing unused packages...${clear}"
    yes | apt autoremove && apt autoclean && apt clean

    if [[ "${removenum}" =~ ['123678'] ]] && [ -f /usr/local/bin/sbmanager ]
    then
        rm /usr/local/bin/sbmanager
    fi

    echo ""
    echo ""
}

final_message() {
    if [[ "${language}" == "1" ]]
    then
        echo -e "${textcolor}Выбранные пакеты удалены${clear}"
    else
        echo -e "${textcolor}Selected packages have been deleted${clear}"
    fi

    echo ""
}

check_root
enter_language
get_data
ask_remove
remove_sing_box
remove_warp
remove_ufw
remove_unattended_upgrades
remove_certbot
remove_nginx
remove_haproxy
remove_other
final_message
