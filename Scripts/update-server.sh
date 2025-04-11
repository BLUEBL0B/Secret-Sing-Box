#!/bin/bash

textcolor='\033[1;34m'
textcolor_light='\033[1;36m'
red='\033[1;31m'
clear='\033[0m'

check_parent() {
    if [[ -z $version ]]
    then
        echo ""
        echo -e "${red}Error: this script should be run from sbmanager, not manually${clear}"
        echo ""
        exit 1
    fi
}

check_update() {
    new_version="1.2.0"

    if [[ "${version}" == "${new_version}" ]]
    then
        if [[ "${language}" == "1" ]]
        then
            echo -e "Установлена последняя версия: ${textcolor}v${version}${clear}"
        else
            echo -e "The latest version is already installed: ${textcolor}v${version}${clear}"
        fi
        echo ""
        exit 0
    fi

    if [[ "${language}" == "1" ]]
    then
        echo -e "Текущая версия: ${textcolor}v${version}${clear}"
        echo -e "Доступна новая версия: ${textcolor}v${new_version}${clear}"
    else
        echo -e "Current version: ${textcolor}v${version}${clear}"
        echo -e "New version is available: ${textcolor}v${new_version}${clear}"
    fi
}

extract_values() {
    inboundnumbertr=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
    userstr=$(jq ".inbounds[${inboundnumbertr}].users" /etc/sing-box/config.json)

    if [ ! -f /etc/haproxy/auth.lua ]
    then
        inboundnumbervl=$(jq '[.inbounds[].tag] | index("vless-in")' /etc/sing-box/config.json)
        usersvl=$(jq ".inbounds[${inboundnumbervl}].users" /etc/sing-box/config.json)
        transport=$(jq -r '.inbounds[] | select(.tag=="trojan-in") | .transport.type' /etc/sing-box/config.json)
    fi

    warp_domain_suffix=$(cat /etc/sing-box/config.json | jq '.route.rules[] | select(.outbound=="warp") | .domain_suffix')

    if [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) == "true" ]]
    then
        nextoutbound=$(cat /etc/sing-box/config.json | jq '.outbounds[] | select(.tag=="proxy")')
    fi
}

insert_values() {
    inboundnumbertr=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
    inboundnumbervl=$(jq '[.inbounds[].tag] | index("vless-in")' /etc/sing-box/config.json)

    echo "$(jq </etc/sing-box/config.json "del(.inbounds[${inboundnumbertr}].users[0])")" > /etc/sing-box/config.json
    echo "$(jq ".inbounds[${inboundnumbertr}].users |= . + ${userstr}" /etc/sing-box/config.json)" > /etc/sing-box/config.json

    if [ ! -f /etc/haproxy/auth.lua ]
    then
        echo "$(jq </etc/sing-box/config.json "del(.inbounds[${inboundnumbervl}].users[0])")" > /etc/sing-box/config.json
        echo "$(jq ".inbounds[${inboundnumbervl}].users |= . + ${usersvl}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    echo "$(jq ".inbounds[${inboundnumbertr}].transport.path = \"/${trojanpath}\" | .inbounds[${inboundnumbervl}].transport.path = \"/${vlesspath}\"" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    warpnum=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
    echo "$(jq ".route.rules[${warpnum}].domain_suffix = [] | .route.rules[${warpnum}].domain_suffix |= . + ${warp_domain_suffix}" /etc/sing-box/config.json)" > /etc/sing-box/config.json

    if [[ "${transport}" == "httpupgrade" ]]
    then
        echo "$(jq ".inbounds[${inboundnumbertr}].transport.type = \"httpupgrade\" | .inbounds[${inboundnumbervl}].transport.type = \"httpupgrade\"" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    if [ -f /etc/haproxy/auth.lua ]
    then
        echo "$(jq "del(.inbounds[${inboundnumbertr}].transport.type) | del(.inbounds[${inboundnumbertr}].transport.path) | del(.inbounds[${inboundnumbervl}])" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    if [[ ! -z ${nextoutbound} ]]
    then
        insert_chain
    fi

    sed -i -e "s/$temprulesetpath/$rulesetpath/g" /etc/sing-box/config.json
}

insert_chain() {
    proxy_num=$(jq '.outbounds | length' /etc/sing-box/config.json)
    proxy_rule_num=$(jq '.route.rules | length' /etc/sing-box/config.json)

    if [ -f /etc/haproxy/auth.lua ]
    then
        echo "$(jq ".route.rules[${proxy_rule_num}] |= . + {\"inbound\":[\"trojan-in\"],\"outbound\":\"proxy\"} | .outbounds[${proxy_num}] |= . + ${nextoutbound}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    else
        echo "$(jq ".route.rules[${proxy_rule_num}] |= . + {\"inbound\":[\"trojan-in\",\"vless-in\"],\"outbound\":\"proxy\"} | .outbounds[${proxy_num}] |= . + ${nextoutbound}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    warpnum=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
    echo "$(jq ".route.rules[${warpnum}] |= . + {\"rule_set\":[\"geoip-ru\",\"gov-ru\"],\"domain_suffix\":[\".ru\",\".su\",\".ru.com\",\".ru.net\"],\"domain_keyword\":[\"xn--\"],\"outbound\":\"warp\"}" /etc/sing-box/config.json)" > /etc/sing-box/config.json

    if [[ $(jq 'any(.outbounds[]; .tag == "IPv4")' /etc/sing-box/config.json) == "true" ]]
    then
        echo "$(jq </etc/sing-box/config.json 'del(.outbounds[] | select(.tag=="IPv4"))')" > /etc/sing-box/config.json
    fi

    if [[ $(jq 'any(.route.rules[]; .outbound == "IPv4")' /etc/sing-box/config.json) == "true" ]]
    then
        echo "$(jq </etc/sing-box/config.json 'del(.route.rules[] | select(.outbound=="IPv4"))')" > /etc/sing-box/config.json
    fi

    rule_sets=(google telegram openai)

    for ruleset_tag in "${rule_sets[@]}"
    do
        if [[ $(jq "any(.route.rule_set[]; .tag == \"${ruleset_tag}\")" /etc/sing-box/config.json) == "true" ]]
        then
            echo "$(jq </etc/sing-box/config.json "del(.route.rule_set[] | select(.tag==\"${ruleset_tag}\"))")" > /etc/sing-box/config.json
        fi
    done
}

update_services() {
    echo ""

    if [[ "${language}" == "1" ]]
    then
        echo -e "${textcolor_light}Обновление пакетов...${clear}"
    else
        echo -e "${textcolor_light}Updating packages...${clear}"
    fi

    systemctl stop sing-box.service
    systemctl stop warp-svc.service
    systemctl stop nginx.service

    if [ -f /etc/haproxy/auth.lua ]
    then
        systemctl stop haproxy.service
    fi

    if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]
    then
        systemctl stop unattended-upgrades
    fi

    extract_values
    cp /etc/sing-box/config.json /etc/sing-box/config.json.0
    wget -O /etc/sing-box/config.json.1 https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Config-Templates/config.json

    if [ $? -eq 0 ]
    then
        mv -f /etc/sing-box/config.json.1 /etc/sing-box/config.json
        insert_values
    fi

    for i in $(seq 0 $(expr $(jq ".route.rule_set | length" /etc/sing-box/config.json) - 1))
    do
        ruleset_link=$(jq -r ".route.rule_set[${i}].path" /etc/sing-box/config.json)
        ruleset=${ruleset_link#"/var/www/${rulesetpath}/"}
        if [ ! -f ${ruleset_link} ]
        then
            wget -P /var/www/${rulesetpath} https://github.com/SagerNet/sing-geosite/raw/rule-set/${ruleset}
        fi
    done

    chmod -R 755 /var/www/${rulesetpath}

    apt-mark unhold sing-box
    apt update -y && apt -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" full-upgrade -y
    apt-mark hold sing-box
    apt autoremove -y && apt autoclean -y
    systemctl daemon-reload

    systemctl start sing-box.service
    systemctl start warp-svc.service
    systemctl start nginx.service

    if [ -f /etc/haproxy/auth.lua ]
    then
        systemctl start haproxy.service
    fi

    if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]
    then
        systemctl start unattended-upgrades
    fi

    echo ""
}

check_sync_client() {
    if [[ "${language}" == "1" ]]
    then
        echo -e "${textcolor_light}Синхронизация настроек в клиентских конфигах с GitHub...${clear}"
    else
        echo -e "${textcolor_light}Syncing settings in client configs with GitHub...${clear}"
    fi
    
    check_users
    validate_template

    if [[ "${stop_sync}" != "1" ]]
    then
        sync_client_configs_github
    fi
}

update_sub_page() {
    if [[ "${language}" == "1" ]]
    then
        echo -e "${textcolor_light}Обновление страницы выдачи подписок...${clear}"
    else
        echo -e "${textcolor_light}Updating subscription page...${clear}"
    fi

    if [ ! -f /etc/haproxy/auth.lua ] && [[ "${language}" == "1" ]]
    then
        sub_page_file="sub-ru.html"
    elif [ ! -f /etc/haproxy/auth.lua ] && [[ "${language}" != "1" ]]
    then
        sub_page_file="sub-en.html"
    elif [ -f /etc/haproxy/auth.lua ] && [[ "${language}" == "1" ]]
    then
        sub_page_file="sub-ru-hapr.html"
    else
        sub_page_file="sub-en-hapr.html"
    fi

    wget -O /var/www/${subspath}/sub.html https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Subscription-Page/${sub_page_file}
    wget -O /var/www/${subspath}/background.jpg https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Subscription-Page/background.jpg
    sed -i -e "s/DOMAIN/$domain/g" -e "s/SUBSCRIPTION-PATH/$subspath/g" /var/www/${subspath}/sub.html
}

update_scripts() {
    if [[ "${language}" == "1" ]]
    then
        echo -e "${textcolor_light}Обновление скриптов...${clear}"
    else
        echo -e "${textcolor_light}Updating scripts...${clear}"
    fi

    if [[ "${language}" == "1" ]]
    then
        sbmanager_file="sb-manager-ru.sh"
    else
        sbmanager_file="sb-manager-en.sh"
    fi

    wget -O /usr/local/bin/sbmanager https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Scripts/${sbmanager_file}
    wget -O /usr/local/bin/rsupdate https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Scripts/ruleset-update.sh
    chmod +x /usr/local/bin/sbmanager /usr/local/bin/rsupdate
    echo ""
}

final_message() {
    if [[ "${language}" == "1" ]]
    then
        echo -e "${textcolor}Установка обновления v${new_version} завершена!${clear}"
        echo "Перезагружать сервер не обязательно"
        echo ""
        echo "При проблемах с Sing-Box запустите команду:"
        echo "cp -f /etc/sing-box/config.json.0 /etc/sing-box/config.json && systemctl restart sing-box"
    else
        echo -e "${textcolor}The update v${new_version} has been installed!${clear}"
        echo "It is not necessary to reboot the server"
        echo ""
        echo "If you are having problems with Sing-Box, run this command:"
        echo "cp -f /etc/sing-box/config.json.0 /etc/sing-box/config.json && systemctl restart sing-box"
    fi

    echo ""
    echo ""
    sleep 1
    exit 0
}

main_menu() {
    stop_sync="1"
}

update_menu() {
    echo ""
    if [[ "${language}" == "1" ]]
    then
        echo -e "${textcolor}[?]${clear} Выберите вариант обновления:"
        echo "0 - Выйти"
        echo "1 - Обновить всё"
        echo "2 - Обновить без синхронизации клиентских конфигов с GitHub"
    else
        echo -e "${textcolor}[?]${clear} Select an update option:"
        echo "0 - Exit"
        echo "1 - Update everything"
        echo "2 - Update without syncing client configs with GitHub"
    fi
    read update_option
    echo ""

    case $update_option in
        1)
        update_services
        check_sync_client
        update_sub_page
        update_scripts
        final_message
        ;;
        2)
        update_services
        update_sub_page
        update_scripts
        final_message
        ;;
        *)
        exit 0
    esac
}

check_parent
check_update
get_data
update_menu
