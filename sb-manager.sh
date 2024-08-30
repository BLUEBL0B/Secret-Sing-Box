#!/bin/bash

textcolor='\033[0;36m'
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

templates() {
    curl -s -o /var/www/${subspath}/template.json https://raw.githubusercontent.com/BLUEBL0B/Sing-Box-NGINX-WS/master/Config-Examples/Client-Trojan-WS.json

    if [ ! -f /var/www/${subspath}/template-loc.json ]
    then
        cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
    fi
}

get_data() {
    serverip=$(curl -s ipinfo.io/ip)

    domain=$(grep "ssl_certificate" /etc/nginx/nginx.conf | head -n 1)
    domain=${domain#*"/live/"}
    domain=${domain%"/"*}

    trojanpath=$(jq -r '.inbounds[] | select(.tag=="trojan-ws-in") | .transport.path' /etc/sing-box/config.json)
    trojanpath=${trojanpath#"/"}

    vlesspath=$(jq -r '.inbounds[] | select(.tag=="vless-ws-in") | .transport.path' /etc/sing-box/config.json)
    vlesspath=${vlesspath#"/"}

    subspath=$(grep "location ~ ^/" /etc/nginx/nginx.conf | head -n 1)
    subspath=${subspath#*"location ~ ^/"}
    subspath=${subspath%" {"*}

    templates

    tempip=$(jq -r '.dns.servers[] | select(has("client_subnet")) | .client_subnet' /var/www/${subspath}/template.json)
    tempdomain=$(jq -r '.outbounds[] | select(.tag=="proxy") | .server' /var/www/${subspath}/template.json)
    echo ""
}

validate_local_template() {
    if [ $(jq -e . < /var/www/${subspath}/template-loc.json &>/dev/null; echo $?) -ne 0 ]
    then
        echo -e "${red}Ошибка: структура template-loc.json нарушена, требуются исправления${clear}"
        echo ""
        echo -e "Нажмите ${textcolor}Enter${clear}, чтобы выйти, или введите ${textcolor}reset${clear}, чтобы сбросить шаблон до исходной версии"
        read resettemp
        if [[ "$resettemp" == "reset" ]]
        then
            rm /var/www/${subspath}/template-loc.json
            cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
            echo ""
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
    while [[ -f /var/www/${subspath}/${username}-TRJ-WS.json ]] || [ -z "$username" ]
    do
        if [[ -f /var/www/${subspath}/${username}-TRJ-WS.json ]]
        then
            echo -e "${red}Ошибка: пользователь с таким именем уже существует${clear}"
            echo ""
        elif [ -z "$username" ]
        then
            :
        fi
        echo -e "Введите имя нового пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
        read username
        [[ ! -z $username ]] && echo ""
    done
}

check_trjpass() {
    while [[ $(jq "any(.inbounds[].users[]; .password == \"$trjpass\")" /etc/sing-box/config.json) == "true" ]] && [ ! -z "$trjpass" ]
    do
        echo -e "${red}Ошибка: этот пароль уже закреплён за другим пользователем${clear}"
        echo ""
        echo "Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
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
        echo "Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
        read uuid
        [[ ! -z $uuid ]] && echo ""
    done
}

enter_user_data_add() {
    echo -e "Введите имя нового пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
    read username
    [[ ! -z $username ]] && echo ""
    check_username_add
    exit_username
    echo "Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
    read trjpass
    [[ ! -z $trjpass ]] && echo ""
    check_trjpass
    echo "Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
    read uuid
    [[ ! -z $uuid ]] && echo ""
    check_uuid
}

generate_pass() {
    if [ -z "$trjpass" ]
    then
        trjpass=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    fi

    if [ -z "$uuid" ]
    then
        uuid=$(sing-box generate uuid)
    fi
}

add_to_server_conf() {
    inboundnum=$(jq '[.inbounds[].tag] | index("trojan-ws-in")' /etc/sing-box/config.json)
    echo "$(jq ".inbounds[${inboundnum}].users[.inbounds[${inboundnum}].users | length] |= . + {\"name\":\"${username}\",\"password\":\"${trjpass}\"}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    inboundnum=$(jq '[.inbounds[].tag] | index("vless-ws-in")' /etc/sing-box/config.json)
    echo "$(jq ".inbounds[${inboundnum}].users[.inbounds[${inboundnum}].users | length] |= . + {\"name\":\"${username}\",\"uuid\":\"${uuid}\"}" /etc/sing-box/config.json)" > /etc/sing-box/config.json

    systemctl restart sing-box.service
}

add_to_client_conf() {
    cp /var/www/${subspath}/template-loc.json /var/www/${subspath}/${username}-TRJ-WS.json
    outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-TRJ-WS.json)
    echo "$(jq ".outbounds[${outboundnum}].password = \"${trjpass}\" | .outbounds[${outboundnum}].transport.path = \"/${trojanpath}\"" /var/www/${subspath}/${username}-TRJ-WS.json)" > /var/www/${subspath}/${username}-TRJ-WS.json
    sed -i -e "s/$tempdomain/$domain/g" -e "s/$tempip/$serverip/g" /var/www/${subspath}/${username}-TRJ-WS.json

    cp /var/www/${subspath}/template-loc.json /var/www/${subspath}/${username}-VLESS-WS.json
    outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-VLESS-WS.json)
    echo "$(jq ".outbounds[${outboundnum}].password = \"${uuid}\" | .outbounds[${outboundnum}].transport.path = \"/${vlesspath}\" | .outbounds[${outboundnum}].type = \"vless\" | .outbounds[${outboundnum}] |= with_entries(.key |= if . == \"password\" then \"uuid\" else . end)" /var/www/${subspath}/${username}-VLESS-WS.json)" > /var/www/${subspath}/${username}-VLESS-WS.json
    sed -i -e "s/$tempdomain/$domain/g" -e "s/$tempip/$serverip/g" /var/www/${subspath}/${username}-VLESS-WS.json

    echo -e "Пользователь ${textcolor}${username}${clear} добавлен:"
    echo "https://${domain}/${subspath}/${username}-TRJ-WS.json"
    echo "https://${domain}/${subspath}/${username}-VLESS-WS.json"
    echo ""
}

check_username_del() {
    while [[ ! -f /var/www/${subspath}/${username}-TRJ-WS.json ]]
    do
        echo -e "${red}Ошибка: пользователь с таким именем не существует${clear}"
        echo ""
        echo -e "Введите имя пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
        read username
        echo ""
        exit_username
    done
}

enter_user_data_del() {
    echo -e "Введите имя пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
    read username
    echo ""
    exit_username
    check_username_del
}

del_from_server_conf() {
    inboundnum=$(jq '[.inbounds[].tag] | index("trojan-ws-in")' /etc/sing-box/config.json)
    echo "$(jq </etc/sing-box/config.json "del(.inbounds[${inboundnum}].users[] | select(.name==\"${username}\"))")" > /etc/sing-box/config.json
    inboundnum=$(jq '[.inbounds[].tag] | index("vless-ws-in")' /etc/sing-box/config.json)
    echo "$(jq </etc/sing-box/config.json "del(.inbounds[${inboundnum}].users[] | select(.name==\"${username}\"))")" > /etc/sing-box/config.json

    systemctl restart sing-box.service
}

del_client_conf() {
    rm /var/www/${subspath}/${username}-TRJ-WS.json /var/www/${subspath}/${username}-VLESS-WS.json
    echo -e "Пользователь ${textcolor}${username}${clear} удалён"
    echo ""
}

sync_github_message() {
    echo -e "${textcolor}ВНИМАНИЕ!${clear}"
    echo "Настройки в клиентских конфигах Trojan и VLESS всех пользователей будут синхронизированы с последней версией на Github"
    echo ""
    echo -e "Нажмите ${textcolor}Enter${clear}, чтобы синхронизировать настройки, или введите ${textcolor}x${clear}, чтобы выйти:"
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
    if [ $(ls -A1 /var/www/${subspath} | grep "WS.json" | wc -l) -eq 0 ]
    then
        echo -e "${red}Ошибка: пользователи отсутствуют${clear}"
        echo ""
        main_menu
    fi
}

get_pass() {
    if grep -q ": \"trojan\"" "$file"
    then
        protocol="trojan"
        cred=$(jq -r '.outbounds[] | select(.tag=="proxy") | .password' ${file})
    else
        protocol="vless"
        cred=$(jq -r '.outbounds[] | select(.tag=="proxy") | .uuid' ${file})
    fi
}

sync_client_configs_github() {
    for file in /var/www/${subspath}/*-WS.json
    do
        get_pass
        rm ${file}
        cp /var/www/${subspath}/template.json ${file}
        if [[ "$protocol" == "trojan" ]]
        then
            outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' ${file})
            echo "$(jq ".outbounds[${outboundnum}].password = \"${cred}\" | .outbounds[${outboundnum}].transport.path = \"/${trojanpath}\"" ${file})" > ${file}
            sed -i -e "s/$tempdomain/$domain/g" -e "s/$tempip/$serverip/g" ${file}
        else
            outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' ${file})
            echo "$(jq ".outbounds[${outboundnum}].password = \"${cred}\" | .outbounds[${outboundnum}].transport.path = \"/${vlesspath}\" | .outbounds[${outboundnum}].type = \"vless\" | .outbounds[${outboundnum}] |= with_entries(.key |= if . == \"password\" then \"uuid\" else . end)" ${file})" > ${file}
            sed -i -e "s/$tempdomain/$domain/g" -e "s/$tempip/$serverip/g" ${file}
        fi
        cred=""
        outboundnum=""
    done

    echo "Синхронизация настроек завершена"
    echo ""
}

sync_local_message() {
    echo -e "${textcolor}ВНИМАНИЕ!${clear}"
    echo -e "Вы можете вручную отредактировать настройки в шаблоне ${textcolor}/var/www/${subspath}/template-loc.json${clear}"
    echo "Настройки в этом файле будут применены к клиентским конфигам Trojan и VLESS всех пользователей"
    echo ""
    echo -e "Нажмите ${textcolor}Enter${clear}, чтобы синхронизировать настройки, или введите ${textcolor}x${clear}, чтобы выйти:"
    read sync
}

sync_client_configs_local() {
    loctempip=$(jq -r '.dns.servers[] | select(has("client_subnet")) | .client_subnet' /var/www/${subspath}/template-loc.json)
    loctempdomain=$(jq -r '.outbounds[] | select(.tag=="proxy") | .server' /var/www/${subspath}/template-loc.json)

    for file in /var/www/${subspath}/*-WS.json
    do
        get_pass
        rm ${file}
        cp /var/www/${subspath}/template-loc.json ${file}
        if [[ "$protocol" == "trojan" ]]
        then
            outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' ${file})
            echo "$(jq ".outbounds[${outboundnum}].password = \"${cred}\" | .outbounds[${outboundnum}].transport.path = \"/${trojanpath}\"" ${file})" > ${file}
            sed -i -e "s/$loctempdomain/$domain/g" -e "s/$loctempip/$serverip/g" ${file}
        else
            outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' ${file})
            echo "$(jq ".outbounds[${outboundnum}].password = \"${cred}\" | .outbounds[${outboundnum}].transport.path = \"/${vlesspath}\" | .outbounds[${outboundnum}].type = \"vless\" | .outbounds[${outboundnum}] |= with_entries(.key |= if . == \"password\" then \"uuid\" else . end)" ${file})" > ${file}
            sed -i -e "s/$loctempdomain/$domain/g" -e "s/$loctempip/$serverip/g" ${file}
        fi
        cred=""
        outboundnum=""
    done

    echo "Синхронизация настроек завершена"
    echo ""
}

show_users() {
    usernum=$(ls -A1 /var/www/${subspath} | grep "WS.json" | wc -l)
    usernum=$(expr ${usernum} / 2)
    echo -e "${textcolor}Количество пользователей:${clear} ${usernum}"
    ls -A1 /var/www/${subspath} | grep "WS.json" | sed "s/-TRJ-WS\.json//g" | sed "s/-VLESS-WS\.json//g" | uniq
    echo ""
    main_menu
}

add_users() {
    validate_local_template
    while [[ $username != "x" ]] && [[ $username != "х" ]]
    do
        enter_user_data_add
        generate_pass
        add_to_server_conf
        add_to_client_conf
    done
    main_menu
}

delete_users() {
    while [[ $username != "x" ]] && [[ $username != "х" ]]
    do
        enter_user_data_del
        del_from_server_conf
        del_client_conf
    done
    main_menu
}

sync_with_github() {
    sync_github_message
    exit_sync
    check_users
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

main_menu() {
    echo ""
    echo -e "${textcolor}Выберите действие:${clear}"
    echo "1 - Вывести список пользователей"
    echo "2 - Добавить нового пользователя"
    echo "3 - Удалить пользователя"
    echo "4 - Синхронизировать настройки во всех клиентских конфигах с Github"
    echo "5 - Синхронизировать настройки во всех клиентских конфигах с локальным шаблоном (свои настройки)"
    echo "6 - Выйти"
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
        sync_with_github
        ;;
        5)
        sync_with_local_temp
        ;;
        *)
        exit 0
    esac
}

check_root
get_data
main_menu