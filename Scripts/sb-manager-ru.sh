#!/bin/bash

textcolor='\033[1;34m'
red='\033[1;31m'
grey='\033[1;30m'
clear='\033[0m'

check_root() {
    if [[ $EUID -ne 0 ]]
    then
        echo ""
        echo -e "${red}Ошибка: эту команду нужно запускать от имени root, сначала введите команду \"sudo -i\"${clear}"
        echo ""
        exit 1
    fi
}

banner() {
    echo ""
    echo "╔══╗ ╔══╗ ╦══╗"
    echo "║    ║    ║  ║"
    echo "╚══╗ ╚══╗ ╠══╣"
    echo "   ║    ║ ║  ║"
    echo "╚══╝ ╚══╝ ╩══╝"
}

templates() {
    wget -q -O /var/www/${subspath}/template-1.json https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Config-Templates/client.json

    if [ $? -eq 0 ]
    then
        outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/template-1.json)

        if [ ! -f /etc/haproxy/auth.lua ] && [[ $(jq -r '.inbounds[] | select(.tag=="trojan-in") | .transport.type' /etc/sing-box/config.json) == "ws" ]]
        then
            mv -f /var/www/${subspath}/template-1.json /var/www/${subspath}/template.json
        elif [ ! -f /etc/haproxy/auth.lua ] && [[ $(jq -r '.inbounds[] | select(.tag=="trojan-in") | .transport.type' /etc/sing-box/config.json) == "httpupgrade" ]]
        then
            echo "$(jq ".outbounds[${outboundnum}].transport.type = \"httpupgrade\"" /var/www/${subspath}/template-1.json)" > /var/www/${subspath}/template.json
            rm /var/www/${subspath}/template-1.json
        else
            echo "$(jq "del(.outbounds[${outboundnum}].transport.type) | del(.outbounds[${outboundnum}].transport.path)" /var/www/${subspath}/template-1.json)" > /var/www/${subspath}/template.json
            rm /var/www/${subspath}/template-1.json
        fi

        outboundnum=""
    fi

    if [ ! -f /var/www/${subspath}/template-loc.json ] && [ -f /var/www/${subspath}/template.json ] && [ $(jq -e . < /var/www/${subspath}/template.json &>/dev/null; echo $?) -eq 0 ] && [ -s /var/www/${subspath}/template.json ]
    then
        cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
    fi
}

get_ip() {
    serverip=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep "ip" | cut -d "=" -f 2)

    if [[ ! $serverip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
    then
        serverip=$(curl -s ipinfo.io/ip)
    fi

    if [[ ! $serverip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
    then
        serverip=$(curl -s 2ip.io)
    fi
}

get_data() {
    get_ip

    if [ -f /etc/haproxy/auth.lua ]
    then
        domain=$(grep "/etc/haproxy/certs/" /etc/haproxy/haproxy.cfg | head -n 1)
        domain=${domain#*"/etc/haproxy/certs/"}
        domain=${domain%".pem"*}
    else
        domain=$(grep "ssl_certificate" /etc/nginx/nginx.conf | head -n 1)
        domain=${domain#*"/live/"}
        domain=${domain%"/"*}

        trojanpath=$(jq -r '.inbounds[] | select(.tag=="trojan-in") | .transport.path' /etc/sing-box/config.json)
        trojanpath=${trojanpath#"/"}

        vlesspath=$(jq -r '.inbounds[] | select(.tag=="vless-in") | .transport.path' /etc/sing-box/config.json)
        vlesspath=${vlesspath#"/"}
    fi

    subspath=$(grep "location ~ ^/" /etc/nginx/nginx.conf | head -n 1)
    subspath=${subspath#*"location ~ ^/"}
    subspath=${subspath%" {"*}

    rulesetpath=$(grep "alias /var/www/" /etc/nginx/nginx.conf | head -n 1)
    rulesetpath=${rulesetpath#*"alias /var/www/"}
    rulesetpath=${rulesetpath%"/;"*}

    templates

    tempip=$(jq -r '.dns.servers[] | select(has("client_subnet")) | .client_subnet' /var/www/${subspath}/template.json)
    tempdomain=$(jq -r '.outbounds[] | select(.tag=="proxy") | .server' /var/www/${subspath}/template.json)

    if [ -z ${tempip} ]
    then
        tempip=$(jq -r '.route.rules[] | select(has("ip_cidr")) | .ip_cidr[0]' /var/www/${subspath}/template.json)
    fi

    temprulesetpath=$(jq -r ".route.rule_set[-1].url" /var/www/${subspath}/template.json)
    temprulesetpath=${temprulesetpath#*"https://${tempdomain}/"}
    temprulesetpath=${temprulesetpath%"/"*}
}

validate_template() {
    if [ $(jq -e . < /var/www/${subspath}/template.json &>/dev/null; echo $?) -ne 0 ] || [ ! -s /var/www/${subspath}/template.json ]
    then
        echo -e "${red}Ошибка: не удалось загрузить данные с GitHub${clear}"
        echo ""
        main_menu
    fi
}

validate_local_template() {
    if [ $(jq -e . < /var/www/${subspath}/template-loc.json &>/dev/null; echo $?) -ne 0 ] || [ ! -s /var/www/${subspath}/template-loc.json ] || [[ $(jq 'any(.inbounds[]; .tag == "tun-in")' /var/www/${subspath}/template-loc.json) == "false" ]] || [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /var/www/${subspath}/template-loc.json) == "false" ]]
    then
        echo -e "${red}Ошибка: структура template-loc.json нарушена, требуются исправления${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Введите ${textcolor}reset${clear}, чтобы сбросить шаблон до исходной версии, или введите ${textcolor}x${clear}, чтобы выйти:"
        read resettemp
        echo ""
        if [[ "$resettemp" == "reset" ]]
        then
            validate_template
            rm /var/www/${subspath}/template-loc.json
            cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
            echo "Шаблон сброшен до исходной версии"
            echo ""
        fi
        main_menu
    fi
}

exit_username() {
    if [[ $username == "x" ]] || [[ $username == "х" ]]
    then
        username=""
        main_menu
    fi
}

check_username_add() {
    while [[ -f /var/www/${subspath}/${username}-TRJ-CLIENT.json ]] || [[ ! $username =~ ^[a-zA-Z0-9_-]+$ ]] || [ -z "$username" ]
    do
        if [[ -f /var/www/${subspath}/${username}-TRJ-CLIENT.json ]]
        then
            echo -e "${red}Ошибка: пользователь с таким именем уже существует${clear}"
            echo ""
        elif [ -z "$username" ]
        then
            :
        elif [[ ! $username =~ ^[a-zA-Z0-9_-]+$ ]]
        then
            echo -e "${red}Ошибка: имя пользователя должно содержать только английские буквы, цифры, символы _ и -${clear}"
            echo ""
        fi
        echo -e "${textcolor}[?]${clear} Введите имя нового пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
        read username
        [[ ! -z $username ]] && echo ""
    done
}

check_trjpass() {
    while ([[ $trjpass =~ '"' ]] || [[ $(jq "any(.inbounds[].users[]; .password == \"$trjpass\")" /etc/sing-box/config.json) == "true" ]]) && [ ! -z "$trjpass" ]
    do
        if [[ $trjpass =~ '"' ]]
        then
            echo -e "${red}Ошибка: пароль Trojan не должен содержать кавычки \"${clear}"
        else
            echo -e "${red}Ошибка: этот пароль уже закреплён за другим пользователем${clear}"
        fi
        echo ""
        echo -e "${textcolor}[?]${clear} Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
        read trjpass
        [[ ! -z $trjpass ]] && echo ""
    done
}

check_uuid() {
    while ([[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]] || [[ $(jq "any(.inbounds[].users[]; .uuid == \"$uuid\")" /etc/sing-box/config.json) == "true" ]]) && [ ! -z "$uuid" ]
    do
        if [[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]
        then
            echo -e "${red}Ошибка: введённое значение не является UUID${clear}"
        elif [[ $(jq "any(.inbounds[].users[]; .uuid == \"$uuid\")" /etc/sing-box/config.json) == "true" ]]
        then
            echo -e "${red}Ошибка: этот UUID уже закреплён за другим пользователем${clear}"
        fi
        echo ""
        echo -e "${textcolor}[?]${clear} Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
        read uuid
        [[ ! -z $uuid ]] && echo ""
    done
}

enter_user_data_add_ws() {
    echo -e "${textcolor}[?]${clear} Введите имя нового пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
    read username
    [[ ! -z $username ]] && echo ""
    check_username_add
    exit_username
    echo -e "${textcolor}[?]${clear} Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
    read trjpass
    [[ ! -z $trjpass ]] && echo ""
    check_trjpass
    echo -e "${textcolor}[?]${clear} Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
    read uuid
    [[ ! -z $uuid ]] && echo ""
    check_uuid
}

enter_user_data_add_haproxy() {
    echo -e "${textcolor}[?]${clear} Введите имя нового пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
    read username
    [[ ! -z $username ]] && echo ""
    check_username_add
    exit_username
    echo -e "${textcolor}[?]${clear} Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
    read trjpass
    [[ ! -z $trjpass ]] && echo ""
    check_trjpass
}

enter_user_data_add() {
    if [ -f /etc/haproxy/auth.lua ]
    then
        enter_user_data_add_haproxy
    else
        enter_user_data_add_ws
    fi
}

generate_pass() {
    if [ -z "$trjpass" ]
    then
        trjpass=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    fi

    if [ ! -f /etc/haproxy/auth.lua ] && [ -z "$uuid" ]
    then
        uuid=$(sing-box generate uuid)
    fi
}

add_to_server_conf() {
    inboundnum=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
    echo "$(jq ".inbounds[${inboundnum}].users[.inbounds[${inboundnum}].users | length] |= . + {\"name\":\"${username}\",\"password\":\"${trjpass}\"}" /etc/sing-box/config.json)" > /etc/sing-box/config.json

    if [ ! -f /etc/haproxy/auth.lua ]
    then
        inboundnum=$(jq '[.inbounds[].tag] | index("vless-in")' /etc/sing-box/config.json)
        echo "$(jq ".inbounds[${inboundnum}].users[.inbounds[${inboundnum}].users | length] |= . + {\"name\":\"${username}\",\"uuid\":\"${uuid}\"}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    systemctl reload sing-box.service
}

add_to_client_conf() {
    cp /var/www/${subspath}/template.json /var/www/${subspath}/${username}-TRJ-CLIENT.json
    outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-TRJ-CLIENT.json)
    if [ ! -f /etc/haproxy/auth.lua ]
    then
        echo "$(jq ".outbounds[${outboundnum}].password = \"${trjpass}\" | .outbounds[${outboundnum}].transport.path = \"/${trojanpath}\"" /var/www/${subspath}/${username}-TRJ-CLIENT.json)" > /var/www/${subspath}/${username}-TRJ-CLIENT.json
    else
        echo "$(jq ".outbounds[${outboundnum}].password = \"${trjpass}\"" /var/www/${subspath}/${username}-TRJ-CLIENT.json)" > /var/www/${subspath}/${username}-TRJ-CLIENT.json
    fi
    sed -i -e "s/$tempdomain/$domain/g" -e "s/$tempip/$serverip/g" -e "s/$temprulesetpath/$rulesetpath/g" /var/www/${subspath}/${username}-TRJ-CLIENT.json

    if [ ! -f /etc/haproxy/auth.lua ]
    then
        cp /var/www/${subspath}/template.json /var/www/${subspath}/${username}-VLESS-CLIENT.json
        outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-VLESS-CLIENT.json)
        echo "$(jq ".outbounds[${outboundnum}].password = \"${uuid}\" | .outbounds[${outboundnum}].transport.path = \"/${vlesspath}\" | .outbounds[${outboundnum}].type = \"vless\" | .outbounds[${outboundnum}] |= with_entries(.key |= if . == \"password\" then \"uuid\" else . end)" /var/www/${subspath}/${username}-VLESS-CLIENT.json)" > /var/www/${subspath}/${username}-VLESS-CLIENT.json
        sed -i -e "s/$tempdomain/$domain/g" -e "s/$tempip/$serverip/g" -e "s/$temprulesetpath/$rulesetpath/g" /var/www/${subspath}/${username}-VLESS-CLIENT.json
    fi

    echo -e "Пользователь ${textcolor}${username}${clear} добавлен:"
    echo "https://${domain}/${subspath}/${username}-TRJ-CLIENT.json"
    if [ ! -f /etc/haproxy/auth.lua ]
    then
        echo "https://${domain}/${subspath}/${username}-VLESS-CLIENT.json"
    fi
    echo ""
}

add_to_auth_lua() {
    if [ -f /etc/haproxy/auth.lua ]
    then
        passhash=$(echo -n "${trjpass}" | openssl dgst -sha224 | sed 's/.* //')
        sed -i "2i \ \ \ \ [\"${passhash}\"] = true," /etc/haproxy/auth.lua
        systemctl reload haproxy.service
    fi
}

check_username_del() {
    while [[ ! -f /var/www/${subspath}/${username}-TRJ-CLIENT.json ]]
    do
        echo -e "${red}Ошибка: пользователь с таким именем не существует${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Введите имя пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
        read username
        echo ""
        exit_username
    done
}

enter_user_data_del() {
    echo -e "${textcolor}[?]${clear} Введите имя пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
    read username
    echo ""
    exit_username
    check_username_del
}

del_from_server_conf() {
    inboundnum=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
    echo "$(jq </etc/sing-box/config.json "del(.inbounds[${inboundnum}].users[] | select(.name==\"${username}\"))")" > /etc/sing-box/config.json

    if [ ! -f /etc/haproxy/auth.lua ]
    then
        inboundnum=$(jq '[.inbounds[].tag] | index("vless-in")' /etc/sing-box/config.json)
        echo "$(jq </etc/sing-box/config.json "del(.inbounds[${inboundnum}].users[] | select(.name==\"${username}\"))")" > /etc/sing-box/config.json
    fi

    systemctl reload sing-box.service
}

del_client_conf() {
    if [ ! -f /etc/haproxy/auth.lua ]
    then
        rm /var/www/${subspath}/${username}-TRJ-CLIENT.json /var/www/${subspath}/${username}-VLESS-CLIENT.json
    else
        rm /var/www/${subspath}/${username}-TRJ-CLIENT.json
    fi
    echo -e "Пользователь ${textcolor}${username}${clear} удалён"
    echo ""
}

del_from_auth_lua() {
    if [ -f /etc/haproxy/auth.lua ]
    then
        inboundnum=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
        trjpass=$(jq -r ".inbounds[${inboundnum}].users[] | select(.name==\"${username}\") | .password" /etc/sing-box/config.json)
        passhash=$(echo -n "${trjpass}" | openssl dgst -sha224 | sed 's/.* //')
        sed -i "/$passhash/d" /etc/haproxy/auth.lua
        systemctl reload haproxy.service
    fi
}

sync_github_message() {
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo "Настройки в клиентских конфигах всех пользователей будут синхронизированы с последней версией на GitHub"
    echo ""
    echo -e "${textcolor}[?]${clear} Нажмите ${textcolor}Enter${clear}, чтобы синхронизировать настройки, или введите ${textcolor}x${clear}, чтобы выйти:"
    read sync
}

exit_sync() {
    if [[ "$sync" == "x" ]] || [[ "$sync" == "х" ]]
    then
        echo ""
        sync=""
        main_menu
    fi
}

check_users() {
    if [ $(ls -A1 /var/www/${subspath} | grep "CLIENT.json" | wc -l) -eq 0 ]
    then
        echo -e "${red}Ошибка: пользователи отсутствуют${clear}"
        echo ""
        main_menu
    fi
}

get_pass() {
    stack=$(jq -r '.inbounds[] | select(.tag=="tun-in") | .stack' ${file})

    if grep -q ": \"trojan\"" "$file"
    then
        protocol="trojan"
        cred=$(jq -r '.outbounds[] | select(.tag=="proxy") | .password' ${file})
    else
        protocol="vless"
        cred=$(jq -r '.outbounds[] | select(.tag=="proxy") | .uuid' ${file})
    fi

    if [[ $(jq '.outbounds[] | select(.tag=="proxy") | .transport | has("headers")' ${file}) == "true" ]]
    then
        cfip=$(jq -r '.outbounds[] | select(.tag=="proxy") | .server' ${file})
    fi
}

edit_configs_sync() {
    for file in /var/www/${subspath}/*-CLIENT.json
    do
        get_pass
        rm ${file}
        cp /var/www/${subspath}/${sync_template_file} ${file}
        inboundnum=$(jq '[.inbounds[].tag] | index("tun-in")' ${file})
        outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' ${file})

        if [[ "$protocol" == "trojan" ]] && [ -f /etc/haproxy/auth.lua ]
        then
            echo "$(jq ".inbounds[${inboundnum}].stack = \"${stack}\" | .outbounds[${outboundnum}].password = \"${cred}\"" ${file})" > ${file}
        elif [[ "$protocol" == "trojan" ]] && [ ! -f /etc/haproxy/auth.lua ]
        then
            echo "$(jq ".inbounds[${inboundnum}].stack = \"${stack}\" | .outbounds[${outboundnum}].password = \"${cred}\" | .outbounds[${outboundnum}].transport.path = \"/${trojanpath}\"" ${file})" > ${file}
        else
            echo "$(jq ".inbounds[${inboundnum}].stack = \"${stack}\" | .outbounds[${outboundnum}].password = \"${cred}\" | .outbounds[${outboundnum}].transport.path = \"/${vlesspath}\" | .outbounds[${outboundnum}].type = \"vless\" | .outbounds[${outboundnum}] |= with_entries(.key |= if . == \"password\" then \"uuid\" else . end)" ${file})" > ${file}
        fi

        if [[ "$sync_template_file" == "template.json" ]]
        then
            sed -i -e "s/$tempdomain/$domain/g" -e "s/$tempip/$serverip/g" -e "s/$temprulesetpath/$rulesetpath/g" ${file}
        else
            sed -i -e "s/$loctempdomain/$domain/g" -e "s/$loctempip/$serverip/g" -e "s/$loctemprulesetpath/$rulesetpath/g" ${file}
        fi

        if [[ ! -z $cfip ]]
        then
            echo "$(jq ".outbounds[${outboundnum}].server = \"${cfip}\" | .outbounds[${outboundnum}].transport.headers |= {\"Host\":\"${domain}\"} | .route.rule_set[].download_detour = \"proxy\"" ${file})" > ${file}
        fi

        cfip=""
        cred=""
        inboundnum=""
        outboundnum=""
    done
}

sync_client_configs_github() {
    sync_template_file="template.json"
    edit_configs_sync

    for i in $(seq 0 $(expr $(jq ".route.rule_set | length" /var/www/${subspath}/template.json) - 1))
    do
        ruleset_link=$(jq -r ".route.rule_set[${i}].url" /var/www/${subspath}/template.json)
        ruleset=${ruleset_link#"https://${tempdomain}/${temprulesetpath}/"}
        if [ ! -f /var/www/${rulesetpath}/${ruleset} ]
        then
            wget -q -P /var/www/${rulesetpath} https://github.com/SagerNet/sing-geosite/raw/rule-set/${ruleset}
        fi
    done

    chmod -R 755 /var/www/${rulesetpath}
    echo "Синхронизация настроек с GitHub завершена"
    echo ""
}

sync_local_message() {
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo -e "Вы можете вручную отредактировать настройки в шаблоне ${textcolor}/var/www/${subspath}/template-loc.json${clear}"
    echo "Настройки в этом файле будут применены к клиентским конфигам всех пользователей"
    echo "При редактировании не меняйте значения \"tag\" у \"inbounds\" и \"outbounds\""
    echo ""
    echo -e "${textcolor}[?]${clear} Нажмите ${textcolor}Enter${clear}, чтобы синхронизировать настройки, или введите ${textcolor}x${clear}, чтобы выйти:"
    read sync
}

sync_client_configs_local() {
    loctempip=$(jq -r '.dns.servers[] | select(has("client_subnet")) | .client_subnet' /var/www/${subspath}/template-loc.json)
    loctempdomain=$(jq -r '.outbounds[] | select(.tag=="proxy") | .server' /var/www/${subspath}/template-loc.json)

    if [ -z ${loctempip} ]
    then
        loctempip=$(jq -r '.route.rules[] | select(has("ip_cidr")) | .ip_cidr[0]' /var/www/${subspath}/template-loc.json)
    fi

    loctemprulesetpath=$(jq -r ".route.rule_set[-1].url" /var/www/${subspath}/template-loc.json)
    loctemprulesetpath=${loctemprulesetpath#*"https://${loctempdomain}/"}
    loctemprulesetpath=${loctemprulesetpath%"/"*}

    sync_template_file="template-loc.json"
    edit_configs_sync

    if [[ $(jq ".route.rule_set | length" /var/www/${subspath}/template-loc.json) =~ ^[0-9]+$ ]] && [[ $(jq ".route.rule_set | length" /var/www/${subspath}/template-loc.json) != "0" ]]
    then
        for i in $(seq 0 $(expr $(jq ".route.rule_set | length" /var/www/${subspath}/template-loc.json) - 1))
        do
            ruleset_link=$(jq -r ".route.rule_set[${i}].url" /var/www/${subspath}/template-loc.json)
            ruleset=${ruleset_link#"https://${loctempdomain}/${loctemprulesetpath}/"}
            if [ ! -f /var/www/${rulesetpath}/${ruleset} ]
            then
                wget -q -P /var/www/${rulesetpath} https://github.com/SagerNet/sing-geosite/raw/rule-set/${ruleset}
            fi
        done
    fi

    chmod -R 755 /var/www/${rulesetpath}
    echo "Синхронизация настроек с локальным шаблоном завершена"
    echo ""
}

show_users() {
    usernum=$(ls -A1 /var/www/${subspath} | grep "CLIENT.json" | wc -l)
    if [ ! -f /etc/haproxy/auth.lua ]
    then
        usernum=$(expr ${usernum} / 2)
    fi
    echo -e "${textcolor}Количество пользователей:${clear} ${usernum}"
    ls -A1 /var/www/${subspath} | grep "CLIENT.json" | sed "s/-TRJ-CLIENT\.json//g" | sed "s/-VLESS-CLIENT\.json//g" | uniq
    echo ""
    main_menu
}

add_users() {
    validate_template
    while [[ $username != "x" ]] && [[ $username != "х" ]]
    do
        enter_user_data_add
        generate_pass
        add_to_auth_lua
        add_to_server_conf
        add_to_client_conf
    done
    main_menu
}

delete_users() {
    while [[ $username != "x" ]] && [[ $username != "х" ]]
    do
        enter_user_data_del
        del_from_auth_lua
        del_from_server_conf
        del_client_conf
    done
    main_menu
}

stack_text() {
    echo -e "${textcolor}[?]${clear} Выберите \"stack\" для пользователя ${textcolor}${username}${clear}:"
    echo "0 - Выйти"
    echo "1 - \"system\" (системный стек, лучшая производительность, значение по умолчанию)    ${stack_sel_1}"
    echo "2 - \"gvisor\" (запускается в userspace, рекомендуется, если не работает \"system\")   ${stack_sel_2}"
    echo "3 - \"mixed\" (смешанный вариант: \"system\" для TCP, \"gvisor\" для UDP)                ${stack_sel_3}"
    read stackoption
    echo ""
}

change_stack() {
    while [[ $username != "x" ]] && [[ $username != "х" ]]
    do
        enter_user_data_del

        if [[ $(jq -r '.inbounds[] | select(.tag=="tun-in") | .stack' /var/www/${subspath}/${username}-TRJ-CLIENT.json) == "system" ]]
        then
            stack_sel_1="[Выбрано]"
            stack_sel_2=""
            stack_sel_3=""
        elif [[ $(jq -r '.inbounds[] | select(.tag=="tun-in") | .stack' /var/www/${subspath}/${username}-TRJ-CLIENT.json) == "gvisor" ]]
        then
            stack_sel_1=""
            stack_sel_2="[Выбрано]"
            stack_sel_3=""
        elif [[ $(jq -r '.inbounds[] | select(.tag=="tun-in") | .stack' /var/www/${subspath}/${username}-TRJ-CLIENT.json) == "mixed" ]]
        then
            stack_sel_1=""
            stack_sel_2=""
            stack_sel_3="[Выбрано]"
        fi

        stack_text

        case $stackoption in
            1)
            stack_value="system"
            ;;
            2)
            stack_value="gvisor"
            ;;
            3)
            stack_value="mixed"
            ;;
            *)
            main_menu
        esac

        inboundnum=$(jq '[.inbounds[].tag] | index("tun-in")' /var/www/${subspath}/${username}-TRJ-CLIENT.json)
        echo "$(jq ".inbounds[${inboundnum}].stack = \"${stack_value}\"" /var/www/${subspath}/${username}-TRJ-CLIENT.json)" > /var/www/${subspath}/${username}-TRJ-CLIENT.json

        if [ ! -f /etc/haproxy/auth.lua ]
        then
            inboundnum=$(jq '[.inbounds[].tag] | index("tun-in")' /var/www/${subspath}/${username}-VLESS-CLIENT.json)
            echo "$(jq ".inbounds[${inboundnum}].stack = \"${stack_value}\"" /var/www/${subspath}/${username}-VLESS-CLIENT.json)" > /var/www/${subspath}/${username}-VLESS-CLIENT.json
        fi

        inboundnum=""
        echo -e "Изменение \"stack\" у пользователя ${textcolor}${username}${clear} завершено, для применения новых настроек обновите конфиг на клиенте"
        echo ""
    done
}

sync_with_github() {
    sync_github_message
    exit_sync
    check_users
    validate_template
    sync_client_configs_github
    main_menu
}

sync_with_local_temp() {
    sync_local_message
    exit_sync
    check_users
    validate_local_template
    sync_client_configs_local
    main_menu
}

sync_client_configs() {
    echo -e "${textcolor}Выберите вариант синхронизации:${clear}"
    echo "0 - Выйти"
    echo "1 - Синхронизировать с GitHub"
    echo "2 - Синхронизировать с локальным шаблоном (свои настройки)"
    read syncoption
    echo ""

    case $syncoption in
        1)
        sync_with_github
        ;;
        2)
        sync_with_local_temp
        ;;
        *)
        main_menu
    esac
}

check_cfip() {
    while [[ ! $cfip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
    do
        echo -e "${red}Ошибка: введённое значение не является IP${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Введите выбранный IP Cloudflare:"
        read cfip
        echo ""
    done
}

set_cf_ip() {
    echo -e "${textcolor}[?]${clear} Введите выбранный IP Cloudflare:"
    read cfip
    echo ""
    check_cfip

    outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-TRJ-CLIENT.json)
    echo "$(jq ".outbounds[${outboundnum}].server = \"${cfip}\" | .outbounds[${outboundnum}].transport.headers |= {\"Host\":\"${domain}\"} | .route.rule_set[].download_detour = \"proxy\"" /var/www/${subspath}/${username}-TRJ-CLIENT.json)" > /var/www/${subspath}/${username}-TRJ-CLIENT.json

    outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-VLESS-CLIENT.json)
    echo "$(jq ".outbounds[${outboundnum}].server = \"${cfip}\" | .outbounds[${outboundnum}].transport.headers |= {\"Host\":\"${domain}\"} | .route.rule_set[].download_detour = \"proxy\"" /var/www/${subspath}/${username}-VLESS-CLIENT.json)" > /var/www/${subspath}/${username}-VLESS-CLIENT.json

    echo -e "Изменение настроек для пользователя ${textcolor}${username}${clear} завершено, установлен IP ${textcolor}${cfip}${clear}"
    outboundnum=""
    cfip=""
    echo ""
}

remove_cf_ip() {
    outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-TRJ-CLIENT.json)
    echo "$(jq ".outbounds[${outboundnum}].server = \"${domain}\" | del(.outbounds[${outboundnum}].transport.headers) | del(.route.rule_set[].download_detour)" /var/www/${subspath}/${username}-TRJ-CLIENT.json)" > /var/www/${subspath}/${username}-TRJ-CLIENT.json

    outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-VLESS-CLIENT.json)
    echo "$(jq ".outbounds[${outboundnum}].server = \"${domain}\" | del(.outbounds[${outboundnum}].transport.headers) | del(.route.rule_set[].download_detour)" /var/www/${subspath}/${username}-VLESS-CLIENT.json)" > /var/www/${subspath}/${username}-VLESS-CLIENT.json

    outboundnum=""
    echo -e "Изменение настроек для пользователя ${textcolor}${username}${clear} завершено"
    echo ""
}

cf_text() {
    echo -e "${textcolor}[?]${clear} Выберите опцию для пользователя ${textcolor}${username}${clear}:"
    echo "0 - Выйти"
    echo "1 - Настроить/сменить выбранный IP Cloudflare   ${cf_ip_status}"
    echo "2 - Убрать выбранный IP Cloudflare"
    read cfoption
    echo ""
}

cf_ip_settings() {
    if [ -f /etc/haproxy/auth.lua ]
    then
        echo -e "${red}Ошибка: этот пункт только для вариантов настройки с транспортом WebSocket или HTTPUpgrade${clear}"
        echo ""
        main_menu
    fi

    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo "Этот пункт рекомендуется в случае недоступности IP, который Cloudflare выделил вашему домену для проксирования"
    echo "Нужно просканировать диапазоны IP Cloudflare с вашего устройства и самостоятельно выбрать оптимальный IP"
    echo "Инструкция: https://github.com/A-Zuro/Secret-Sing-Box/blob/main/Docs/cf-scan-ip-ru.md"
    echo ""

    while [[ $username != "x" ]] && [[ $username != "х" ]]
    do
        enter_user_data_del
        sel_cfip=$(jq -r '.outbounds[] | select(.tag=="proxy") | .server' /var/www/${subspath}/${username}-TRJ-CLIENT.json)

        if [[ $sel_cfip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
        then
            cf_ip_status="[Выбрано: ${sel_cfip}]"
        else
            cf_ip_status="[IP Cloudflare не выбран]"
        fi

        cf_text

        while [[ $(jq '.outbounds[] | select(.tag=="proxy") | .transport | has("headers")' /var/www/${subspath}/${username}-TRJ-CLIENT.json) == "false" ]] && [[ $cfoption == "2" ]]
        do
            echo -e "${red}Ошибка: IP Cloudflare итак не указан в конфиге этого пользователя${clear}"
            echo ""
            cf_text
        done

        case $cfoption in
            1)
            set_cf_ip
            ;;
            2)
            remove_cf_ip
            ;;
            *)
            main_menu
        esac
    done
}

show_warp_domains() {
    echo -e "${textcolor}Список доменов/суффиксов WARP:${clear}"
    jq -r '.route.rules[] | select(.outbound=="warp") | .domain_suffix[]' /etc/sing-box/config.json
    echo ""
    main_menu
}

exit_add_warp() {
    if [[ $newwarp == "x" ]] || [[ $newwarp == "х" ]]
    then
        newwarp=""
        main_menu
    fi
}

exit_del_warp() {
    if [[ $delwarp == "x" ]] || [[ $delwarp == "х" ]]
    then
        delwarp=""
        main_menu
    fi
}

crop_newwarp() {
    if [[ "$newwarp" == "https://"* ]]
    then
        newwarp=${newwarp#"https://"}
    fi

    if [[ "$newwarp" == "http://"* ]]
    then
        newwarp=${newwarp#"http://"}
    fi

    if [[ "$newwarp" =~ "/" ]]
    then
        newwarp=$(echo "${newwarp}" | cut -d "/" -f 1)
    fi
}

check_warp_domain_add() {
    while [[ -n $(jq '.route.rules[] | select(.outbound=="warp") | .domain_suffix[]' /etc/sing-box/config.json | grep "\"${newwarp}\"") ]] || [ -z "$newwarp" ]
    do
        if [ -z "$newwarp" ]
        then
            :
        else
            echo -e "${red}Ошибка: этот домен/суффикс уже добавлен в WARP${clear}"
            echo ""
        fi
        echo -e "${textcolor}[?]${clear} Введите новый домен/суффикс для WARP или введите ${textcolor}x${clear}, чтобы закончить:"
        read newwarp
        echo ""
        exit_add_warp
        crop_newwarp
    done
}

check_warp_domain_del() {
    while [[ -z $(jq '.route.rules[] | select(.outbound=="warp") | .domain_suffix[]' /etc/sing-box/config.json | grep "\"${delwarp}\"") ]] || [ -z "$delwarp" ]
    do
        echo -e "${red}Ошибка: этот домен/суффикс не добавлен в WARP${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Введите домен/суффикс для удаления из WARP или введите ${textcolor}x${clear}, чтобы закончить:"
        read delwarp
        echo ""
        exit_del_warp
    done
}

add_warp_domains() {
    warpnum=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
    while [[ $newwarp != "x" ]] && [[ $newwarp != "х" ]]
    do
        echo -e "${textcolor}[?]${clear} Введите новый домен/суффикс для WARP или введите ${textcolor}x${clear}, чтобы закончить:"
        read newwarp
        echo ""
        crop_newwarp
        check_warp_domain_add
        exit_add_warp
        echo "$(jq ".route.rules[${warpnum}].domain_suffix[.route.rules[${warpnum}].domain_suffix | length]? += \"${newwarp}\"" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        systemctl reload sing-box.service
        echo -e "Домен/суффикс ${textcolor}${newwarp}${clear} добавлен в WARP"
        echo ""
    done
}

delete_warp_domains() {
    warpnum=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
    while [[ $delwarp != "x" ]] && [[ $delwarp != "х" ]]
    do
        echo -e "${textcolor}[?]${clear} Введите домен/суффикс для удаления из WARP или введите ${textcolor}x${clear}, чтобы закончить:"
        read delwarp
        echo ""
        exit_del_warp
        check_warp_domain_del
        echo "$(jq "del(.route.rules[${warpnum}].domain_suffix[] | select(. == \"${delwarp}\"))" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        systemctl reload sing-box.service
        echo -e "Домен/суффикс ${textcolor}${delwarp}${clear} удалён из WARP"
        echo ""
    done
}

exit_enter_nextlink() {
    if [[ $nextlink == "x" ]] || [[ $nextlink == "х" ]]
    then
        nextlink=""
        main_menu
    fi
}

check_nextlink() {
    nextconfig=$(curl -s ${nextlink})

    while [ $(jq -e . >/dev/null 2>&1 <<< "${nextconfig}"; echo $?) -ne 0 ] || [[ $(echo "${nextconfig}" | jq 'any(.outbounds[]; .tag == "proxy")') == "false" ]] || [ -z "${nextconfig}" ]
    do
        nextlink=""
        echo -e "${red}Ошибка: неверная ссылка на конфиг или следующий сервер не отвечает${clear}"
        echo ""
        while [[ -z $nextlink ]]
        do
            echo -e "${textcolor}[?]${clear} Введите ссылку на клиентский конфиг со следующего сервера в цепочке или введите ${textcolor}x${clear}, чтобы выйти:"
            read nextlink
            echo ""
            exit_enter_nextlink
        done
        nextconfig=$(curl -s ${nextlink})
    done
}

chain_end() {
    config_temp=$(curl -s https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Config-Templates/config.json)

    if [ $(jq -e . >/dev/null 2>&1 <<< "${config_temp}"; echo $?) -eq 0 ] && [ -n "${config_temp}" ]
    then
        warp_rule=$(echo "${config_temp}" | jq '.route.rules[] | select(.outbound=="warp")')
        warpnum=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
        echo "$(jq ".route.rules[${warpnum}] |= . + ${warp_rule}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    else
        echo -e "${red}Ошибка: не удалось загрузить данные с GitHub${clear}"
        echo ""
        main_menu
    fi

    echo "$(jq 'del(.route.rules[] | select(.outbound=="proxy")) | del(.outbounds[] | select(.tag=="proxy"))' /etc/sing-box/config.json)" > /etc/sing-box/config.json

    if [[ $(jq 'any(.outbounds[]; .tag == "IPv4")' /etc/sing-box/config.json) == "false" ]]
    then
        echo "$(jq '.outbounds[.outbounds | length] |= . + {"type":"direct","tag":"IPv4","domain_strategy":"ipv4_only"}' /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    if [[ $(jq 'any(.route.rules[]; .outbound == "IPv4")' /etc/sing-box/config.json) == "false" ]]
    then
        echo "$(jq '.route.rules[.route.rules | length] |= . + {"rule_set":["google"],"outbound":"IPv4"}' /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    rule_sets=(google telegram openai)

    for ruleset_tag in "${rule_sets[@]}"
    do
        if [[ $(jq "any(.route.rule_set[]; .tag == \"${ruleset_tag}\")" /etc/sing-box/config.json) == "false" ]]
        then
            echo "$(jq ".route.rule_set[.route.rule_set | length] |= . + {\"tag\":\"${ruleset_tag}\",\"type\":\"local\",\"format\":\"binary\",\"path\":\"/var/www/${rulesetpath}/geosite-${ruleset_tag}.srs\"}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        fi
    done

    sed -i -e "s/$temprulesetpath/$rulesetpath/g" /etc/sing-box/config.json

    for i in $(seq 0 $(expr $(jq ".route.rules[${warpnum}].rule_set | length" /etc/sing-box/config.json) - 1))
    do
        ruleset_tag=$(jq -r ".route.rules[${warpnum}].rule_set[${i}]" /etc/sing-box/config.json)

        if [[ $(jq "any(.route.rule_set[]; .tag == \"${ruleset_tag}\")" /etc/sing-box/config.json) == "false" ]]
        then
            echo "$(jq ".route.rule_set[.route.rule_set | length] |= . + {\"tag\":\"${ruleset_tag}\",\"type\":\"local\",\"format\":\"binary\",\"path\":\"/var/www/${rulesetpath}/geosite-${ruleset_tag}.srs\"}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        fi

        if [ ! -f /var/www/${rulesetpath}/geosite-${ruleset_tag}.srs ]
        then
            wget -q -P /var/www/${rulesetpath} https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-${ruleset_tag}.srs
            chmod -R 755 /var/www/${rulesetpath}
        fi
    done

    systemctl reload sing-box.service

    echo "Изменение настроек завершено"
    echo ""
    main_menu
}

chain_middle() {
    nextlink=""
    while [[ -z $nextlink ]]
    do
        echo -e "${textcolor}[?]${clear} Введите ссылку на клиентский конфиг со следующего сервера в цепочке или введите ${textcolor}x${clear}, чтобы выйти:"
        read nextlink
        echo ""
    done
    exit_enter_nextlink
    check_nextlink

    nextoutbound=$(echo "${nextconfig}" | jq '.outbounds[] | select(.tag=="proxy")')
    warpnum=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)

    if [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) == "false" ]]
    then
        proxy_num=$(jq '.outbounds | length' /etc/sing-box/config.json)
        proxy_rule_num=$(jq '.route.rules | length' /etc/sing-box/config.json)
    else
        proxy_num=$(jq '[.outbounds[].tag] | index("proxy")' /etc/sing-box/config.json)
        proxy_rule_num=$(jq '[.route.rules[].outbound] | index("proxy")' /etc/sing-box/config.json)
    fi

    if [ -f /etc/haproxy/auth.lua ]
    then
        echo "$(jq ".route.rules[${proxy_rule_num}] |= . + {\"inbound\":[\"trojan-in\"],\"outbound\":\"proxy\"} | .outbounds[${proxy_num}] |= . + ${nextoutbound}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    else
        echo "$(jq ".route.rules[${proxy_rule_num}] |= . + {\"inbound\":[\"trojan-in\",\"vless-in\"],\"outbound\":\"proxy\"} | .outbounds[${proxy_num}] |= . + ${nextoutbound}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

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

    systemctl reload sing-box.service

    echo "Изменение настроек завершено"
    echo ""
    main_menu
}

chain_text() {
    echo -e "${textcolor}[?]${clear} Выберите положение сервера в цепочке:"
    echo "0 - Выйти"
    echo "1 - Настроить этот сервер как конечный в цепочке или единственный                     ${chain_sel_1}"
    echo "2 - Настроить этот сервер как промежуточный в цепочке или поменять следующий сервер   ${chain_sel_2}"
    read chain_option
    echo ""
}

chain_setup() {
    if [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) == "false" ]]
    then
        chain_sel_1="[Выбрано]"
        chain_sel_2=""
    else
        chain_sel_1=""
        chain_sel_2="[Выбрано: $(jq -r '.outbounds[] | select(.tag=="proxy") | .server' /etc/sing-box/config.json)]"
    fi

    chain_text

    while [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) == "false" ]] && [[ $chain_option == "1" ]]
    do
        echo -e "${red}Ошибка: этот сервер уже настроен как конечный в цепочке или единственный${clear}"
        echo ""
        chain_text
    done

    case $chain_option in
        1)
        chain_end
        ;;
        2)
        chain_middle
        ;;
        *)
        main_menu
    esac
}

exit_renew_cert() {
    if [[ $certrenew == "x" ]] || [[ $certrenew == "х" ]]
    then
        echo ""
        certrenew=""
        main_menu
    fi
}

cert_final_text() {
    if [ $? -eq 0 ]
    then
        echo ""
        echo "Сертификат успешно выпущен"
    else
        echo ""
        echo -e "${red}Ошибка: сертификат не выпущен${clear}"
    fi
}

reissue_cert() {
    email=""
    while [[ -z $email ]]
    do
        if [ -f /etc/letsencrypt/cloudflare.credentials ]
        then
            echo -e "${textcolor}[?]${clear} Введите вашу почту, зарегистрированную на Cloudflare:"
        else
            echo -e "${textcolor}[?]${clear} Введите вашу почту для выпуска сертификата:"
        fi
        read email
        echo ""
    done

    rm -rf /etc/letsencrypt/live/${domain} &> /dev/null
    rm -rf /etc/letsencrypt/archive/${domain} &> /dev/null
    rm /etc/letsencrypt/renewal/${domain}.conf &> /dev/null

    echo -e "${textcolor}Получение сертификата...${clear}"
    if [ -f /etc/letsencrypt/cloudflare.credentials ]
    then
        certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive
        cert_final_text
        ufw_close_80=""
    else
        ufw allow 80 &> /dev/null
        certbot certonly --standalone --preferred-challenges http --agree-tos --email ${email} -d ${domain} --no-eff-email --non-interactive
        cert_final_text
        ufw delete allow 80 &> /dev/null
        ufw_close_80=" && ufw delete allow 80"
    fi

    if [ ! -f /etc/haproxy/auth.lua ] && [ -f /etc/letsencrypt/renewal/${domain}.conf ]
    then
        echo "renew_hook = systemctl reload nginx${ufw_close_80}" >> /etc/letsencrypt/renewal/${domain}.conf
        systemctl start nginx.service
    elif [ -f /etc/haproxy/auth.lua ] && [ -f /etc/letsencrypt/renewal/${domain}.conf ]
    then
        echo "renew_hook = cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem && systemctl reload haproxy${ufw_close_80}" >> /etc/letsencrypt/renewal/${domain}.conf
        cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem
        systemctl start haproxy.service
    fi

    echo ""
    main_menu
}

renew_cert() {
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo "В скрипт встроено автоматическое обновление сертификата раз в 2 месяца, и ручное обновление рекомендуется только в случае сбоев"
    echo "При обновлении сертификата более 5 раз в неделю можно достичь лимита Let's Encrypt, что потребует ожидания для следующего обновления"
    echo ""
    echo -e "${textcolor}[?]${clear} Нажмите ${textcolor}Enter${clear}, чтобы обновить сертификат, или введите ${textcolor}x${clear}, чтобы выйти:"
    read certrenew
    exit_renew_cert

    if [ ! -f /etc/letsencrypt/live/${domain}/fullchain.pem ]
    then
        reissue_cert
    fi

    echo -e "${textcolor}Обновление сертификата...${clear}"
    if [ -f /etc/letsencrypt/cloudflare.credentials ]
    then
        certbot renew --force-renewal
        cert_final_text
    else
        ufw allow 80 &> /dev/null && certbot renew --force-renewal
        cert_final_text
    fi

    echo ""
    main_menu
}

exit_change_domain() {
    if [[ $domain == "x" ]] || [[ $domain == "х" ]]
    then
        domain="${old_domain}"
        main_menu
    fi
}

crop_domain() {
    if [[ "$domain" == "https://"* ]]
    then
        domain=${domain#"https://"}
    fi

    if [[ "$domain" == "http://"* ]]
    then
        domain=${domain#"http://"}
    fi

    if [[ "$domain" == "www."* ]]
    then
        domain=${domain#"www."}
    fi

    if [[ "$domain" =~ "/" ]]
    then
        domain=$(echo "${domain}" | cut -d "/" -f 1)
    fi
}

get_test_response() {
    testdomain=$(echo "${domain}" | rev | cut -d '.' -f 1-2 | rev)

    if [[ "$cftoken" =~ [A-Z] ]]
    then
        test_response=$(curl --silent --request GET --url https://api.cloudflare.com/client/v4/zones --header "Authorization: Bearer ${cftoken}" --header "Content-Type: application/json")
    else
        test_response=$(curl --silent --request GET --url https://api.cloudflare.com/client/v4/zones --header "X-Auth-Key: ${cftoken}" --header "X-Auth-Email: ${email}" --header "Content-Type: application/json")
    fi
}

enter_domain_data() {
    domain=""
    email=""
    cftoken=""
    echo ""
    while [[ -z $domain ]]
    do
        echo -e "${textcolor}[?]${clear} Введите новый домен или введите ${textcolor}x${clear}, чтобы выйти:"
        read domain
        echo ""
    done
    exit_change_domain
    crop_domain
    while [[ -z $email ]]
    do
        echo -e "${textcolor}[?]${clear} Введите вашу почту${email_text}:"
        read email
        echo ""
    done
    if [[ "${validation_type}" == "1" ]]
    then
        while [[ -z $cftoken ]]
        do
            echo -e "${textcolor}[?]${clear} Введите ваш API токен Cloudflare (Edit zone DNS) или Cloudflare global API key:"
            read cftoken
            echo ""
        done
    fi
}

check_cf_token() {
    echo "Проверка домена, API токена/ключа и почты..."
    get_test_response

    while [[ -z $(echo $test_response | grep "\"${testdomain}\"") ]] || [[ -z $(echo $test_response | grep "\"#dns_records:edit\"") ]] || [[ -z $(echo $test_response | grep "\"#dns_records:read\"") ]] || [[ -z $(echo $test_response | grep "\"#zone:read\"") ]]
    do
        echo ""
        echo -e "${red}Ошибка: неправильно введён домен, API токен/ключ или почта${clear}"
        enter_domain_data
        echo "Проверка домена, API токена/ключа и почты..."
        get_test_response
    done

    echo "Успешно!"
    echo ""
}

issue_cert_dns_cf() {
    if [[ "$cftoken" =~ [A-Z] ]]
    then
        echo "dns_cloudflare_api_token = ${cftoken}" > /etc/letsencrypt/cloudflare.credentials
    else
        echo "dns_cloudflare_email = ${email}" > /etc/letsencrypt/cloudflare.credentials
        echo "dns_cloudflare_api_key = ${cftoken}" >> /etc/letsencrypt/cloudflare.credentials
    fi

    chown root:root /etc/letsencrypt/cloudflare.credentials
    chmod 600 /etc/letsencrypt/cloudflare.credentials

    echo -e "${textcolor}Получение сертификата...${clear}"
    certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive

    if [ $? -ne 0 ]
    then
        sleep 3
        echo ""
        rm -rf /etc/letsencrypt/live/${domain} &> /dev/null
        rm -rf /etc/letsencrypt/archive/${domain} &> /dev/null
        rm /etc/letsencrypt/renewal/${domain}.conf &> /dev/null
        echo -e "${textcolor}Получение сертификата: 2-я попытка...${clear}"
        certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive
    fi

    ufw_close_80=""
    crontab -l | sed 's/ufw allow 80 && //g' | crontab -
}

issue_cert_standalone() {
    rm /etc/letsencrypt/cloudflare.credentials &> /dev/null
    ufw allow 80 &> /dev/null

    echo -e "${textcolor}Получение сертификата...${clear}"
    certbot certonly --standalone --preferred-challenges http --agree-tos --email ${email} -d ${domain} --no-eff-email --non-interactive

    if [ $? -ne 0 ]
    then
        sleep 3
        echo ""
        rm -rf /etc/letsencrypt/live/${domain} &> /dev/null
        rm -rf /etc/letsencrypt/archive/${domain} &> /dev/null
        rm /etc/letsencrypt/renewal/${domain}.conf &> /dev/null
        echo -e "${textcolor}Получение сертификата: 2-я попытка...${clear}"
        certbot certonly --standalone --preferred-challenges http --agree-tos --email ${email} -d ${domain} --no-eff-email --non-interactive
    fi

    ufw delete allow 80 &> /dev/null
    ufw_close_80=" && ufw delete allow 80"

    if [[ -z $(crontab -l | grep "ufw allow 80") ]]
    then
        crontab -l | sed 's/certbot -q renew --force-renewal/ufw allow 80 \&\& certbot -q renew --force-renewal/' | crontab -
    fi
}

change_domain() {
    old_domain="${domain}"
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo "Не забудьте создать А запись для нового домена и заменить домен в ссылках для клиентов"
    echo ""
    echo -e "Текущий домен: ${textcolor}${old_domain}${clear}"
    if [ -f /etc/letsencrypt/cloudflare.credentials ]
    then
        echo -e "Метод валидации сертификатов: ${textcolor}DNS Cloudflare${clear}"
    else
        echo -e "Метод валидации сертификатов: ${textcolor}Standalone${clear}"
    fi
    echo ""
    echo -e "${textcolor}[?]${clear} Выберите метод валидации сертификатов для нового домена:"
    echo "0 - Выйти"
    echo "1 - DNS Cloudflare (если ваш домен прикреплён к Cloudflare)"
    echo "2 - Standalone (если ваш домен прикреплён к другому сервису)"
    read validation_type

    case $validation_type in
        1)
        email_text=", зарегистрированную на Cloudflare"
        enter_domain_data
        check_cf_token
        ;;
        2)
        email_text=" для выпуска сертификата"
        echo ""
        echo -e "${red}ВНИМАНИЕ!${clear}"
        echo "Обязательно проверьте правильность написания домена"
        enter_domain_data
        ;;
        *)
        echo ""
        domain="${old_domain}"
        main_menu
    esac

    rm -rf /etc/letsencrypt/live/${old_domain} &> /dev/null
    rm -rf /etc/letsencrypt/archive/${old_domain} &> /dev/null
    rm /etc/letsencrypt/renewal/${old_domain}.conf &> /dev/null

    if [[ "${validation_type}" == "1" ]]
    then
        issue_cert_dns_cf
    else
        issue_cert_standalone
    fi

    if [ ! -f /etc/haproxy/auth.lua ]
    then
        echo "renew_hook = systemctl reload nginx${ufw_close_80}" >> /etc/letsencrypt/renewal/${domain}.conf
        sed -i -e "s/$old_domain/$domain/g" /etc/nginx/nginx.conf
        systemctl reload nginx.service
        if [ $? -ne 0 ]
        then
            systemctl start nginx.service
        fi
    else
        echo "renew_hook = cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem && systemctl reload haproxy${ufw_close_80}" >> /etc/letsencrypt/renewal/${domain}.conf
        cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem
        sed -i -e "s/$old_domain/$domain/g" /etc/haproxy/haproxy.cfg
        systemctl reload haproxy.service
        if [ $? -ne 0 ]
        then
            systemctl start haproxy.service
        fi
    fi

    for file in /var/www/${subspath}/*-CLIENT.json
    do
        sed -i -e "s/$old_domain/$domain/g" ${file}
    done

    sed -i -e "s/$old_domain/$domain/g" /var/www/${subspath}/sub.html

    echo ""
    echo -e "Домен ${textcolor}${old_domain}${clear} заменён на ${textcolor}${domain}${clear}"

    echo ""
    main_menu
}

disable_ipv6() {
    if ! grep -q "net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf
    then
        echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
    fi

    if ! grep -q "net.ipv6.conf.default.disable_ipv6 = 1" /etc/sysctl.conf
    then
        echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
    fi

    if ! grep -q "net.ipv6.conf.lo.disable_ipv6 = 1" /etc/sysctl.conf
    then
        echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
    fi

    echo -e "${textcolor}IPv6 отключён:${clear}"
    sysctl -p

    if [[ -z $(crontab -l | grep "@reboot sysctl -p") ]]
    then
        { crontab -l; echo "@reboot sysctl -p"; } | crontab -
    fi

    echo ""
    main_menu
}

enable_ipv6() {
    sed -i "/net.ipv6.conf.all.disable_ipv6 = 1/d" /etc/sysctl.conf
    sed -i "/net.ipv6.conf.default.disable_ipv6 = 1/d" /etc/sysctl.conf
    sed -i "/net.ipv6.conf.lo.disable_ipv6 = 1/d" /etc/sysctl.conf

    echo -e "${textcolor}IPv6 включён:${clear}"
    sysctl -p

    if [[ ! -z $(crontab -l | grep "@reboot sysctl -p") ]]
    then
        crontab -l | sed "/@reboot sysctl -p/d" | crontab -
    fi

    echo ""
    main_menu
}

show_paths() {
    echo -e "${textcolor}Страница выдачи подписок пользователей:${clear}"
    echo -e "https://${domain}/${subspath}/sub.html${grey}?name=$(ls -A1 /var/www/${subspath} | grep "CLIENT.json" | sed "s/-TRJ-CLIENT\.json//g" | sed "s/-VLESS-CLIENT\.json//g" | uniq | tail -n 1)${clear}"
    echo "Серым показан пример автозаполнения поля с именем пользователя"
    echo ""

    echo -e "${textcolor}Конфигурация сервисов:${clear}"
    echo "Конфиг Sing-Box                        /etc/sing-box/config.json"
    echo "Конфиг NGINX                           /etc/nginx/nginx.conf"
    if [ -f /etc/haproxy/haproxy.cfg ]
    then
        echo "Конфиг HAProxy                         /etc/haproxy/haproxy.cfg"
        echo "Скрипт, считывающий пароли Trojan      /etc/haproxy/auth.lua"
    fi
    echo ""

    echo -e "${textcolor}Контент, доставляемый с помощью NGINX:${clear}"
    echo "Директория подписки                    /var/www/${subspath}/"
    echo "Директория c наборами правил           /var/www/${rulesetpath}/"
    sitedir=$(grep "/var/www/" /etc/nginx/nginx.conf | head -n 1)
    sitedir=${sitedir#*"/var/www/"}
    sitedir=${sitedir%";"*}
    if [[ "$sitedir" =~ "/" ]]
    then
        sitedir=$(echo "${sitedir}" | cut -d "/" -f 1)
    fi
    if [ -d /var/www/${sitedir} ]
    then
        echo "Директория cайта                       /var/www/${sitedir}/"
    fi
    echo ""

    echo -e "${textcolor}Сертификаты и вспомогательные файлы:${clear}"
    echo "Директория с сертификатами             /etc/letsencrypt/live/${domain}/"
    if [ -f /etc/haproxy/certs/${domain}.pem ]
    then
        echo "Объединённый файл с сертификатами      /etc/haproxy/certs/${domain}.pem"
    fi
    echo "Конфиг обновления сертификатов         /etc/letsencrypt/renewal/${domain}.conf"
    if [ -f /etc/letsencrypt/cloudflare.credentials ]
    then
        echo "Файл с API токеном/ключом Cloudflare   /etc/letsencrypt/cloudflare.credentials"
    fi
    echo ""

    echo -e "${textcolor}Скрипты:${clear}"
    echo "Этот скрипт (меню настроек)            /usr/local/bin/sbmanager"
    echo "Скрипт, обновляющий наборы правил      /usr/local/bin/rsupdate"
    echo ""
    echo ""
    exit 0
}

update_ssb() {
    export version="1.2.2"
    export language="1"
    export -f get_ip
    export -f templates
    export -f get_data
    export -f check_users
    export -f validate_template
    export -f get_pass
    export -f edit_configs_sync
    export -f sync_client_configs_github

    if [ $(wget -q -O /dev/null https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/update-server.sh; echo $?) -eq 0 ]
    then
        bash <(curl -Ls https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/update-server.sh)
        exit 0
    else
        echo -e "${red}Ошибка: не удалось загрузить данные с GitHub${clear}"
        echo ""
        main_menu
    fi
}

main_menu() {
    echo ""
    echo -e "${textcolor}Выберите действие:${clear}"
    echo "0 - Выйти"
    echo "1 - Вывести список пользователей"
    echo "2 - Добавить нового пользователя"
    echo "3 - Удалить пользователя"
    echo "---------------------------------"
    echo "4 - Поменять \"stack\" в tun-интерфейсе у пользователя"
    echo "5 - Синхронизировать настройки во всех клиентских конфигах"
    echo "6 - Настроить на клиенте подключение к выбранному IP Cloudflare"
    echo "---------------------------------"
    echo "7 - Вывести список доменов/суффиксов WARP"
    echo "8 - Добавить домен/суффикс в WARP"
    echo "9 - Удалить домен/суффикс из WARP"
    echo "10 - Настроить/убрать цепочку из двух и более серверов"
    echo "---------------------------------"
    echo "11 - Обновить сертификат вручную"
    echo "12 - Сменить домен"
    echo "---------------------------------"
    echo "13 - Отключить IPv6 на сервере"
    echo "14 - Включить IPv6 на сервере"
    echo "---------------------------------"
    echo "15 - Показать пути до конфигов и других значимых файлов"
    echo "16 - Обновить"
    read option
    echo ""

    case $option in
        1)
        show_users
        ;;
        2)
        add_users
        ;;
        3)
        delete_users
        ;;
        4)
        change_stack
        ;;
        5)
        sync_client_configs
        ;;
        6)
        cf_ip_settings
        ;;
        7)
        show_warp_domains
        ;;
        8)
        add_warp_domains
        ;;
        9)
        delete_warp_domains
        ;;
        10)
        chain_setup
        ;;
        11)
        renew_cert
        ;;
        12)
        change_domain
        ;;
        13)
        disable_ipv6
        ;;
        14)
        enable_ipv6
        ;;
        15)
        show_paths
        ;;
        16)
        update_ssb
        ;;
        *)
        exit 0
    esac
}

check_root
banner
get_data
main_menu
