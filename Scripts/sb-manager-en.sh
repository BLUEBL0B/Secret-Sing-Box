#!/bin/bash

textcolor='\033[1;34m'
red='\033[1;31m'
grey='\033[1;30m'
clear='\033[0m'

check_root() {
    if [[ $EUID -ne 0 ]]
    then
        echo ""
        echo -e "${red}Error: this command should be run as root, use \"sudo -i\" command${clear}"
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

replace_template() {
    if [ $? -eq 0 ]
    then
        mv -f /var/www/${subspath}/template.json.1 /var/www/${subspath}/template.json
    fi
}

templates() {
    if [ ! -f /etc/haproxy/auth.lua ] && [[ $(jq -r '.inbounds[] | select(.tag=="trojan-in") | .transport.type' /etc/sing-box/config.json) == "ws" ]]
    then
        wget -q -O /var/www/${subspath}/template.json.1 https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Config-Templates/Client-Trojan-WS.json
        replace_template
    elif [ ! -f /etc/haproxy/auth.lua ] && [[ $(jq -r '.inbounds[] | select(.tag=="trojan-in") | .transport.type' /etc/sing-box/config.json) == "httpupgrade" ]]
    then
        wget -q -O /var/www/${subspath}/template.json.1 https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Config-Templates/Client-Trojan-HTTPUpgrade.json
        replace_template
    else
        wget -q -O /var/www/${subspath}/template.json.1 https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Config-Templates/Client-Trojan-HAProxy.json
        replace_template
    fi

    if [ ! -f /var/www/${subspath}/template-loc.json ]
    then
        cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
    fi
}

get_ip() {
    serverip=$(curl -s https://cloudflare.com/cdn-cgi/trace | grep "ip" | cut -d "=" -f 2)

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
        echo -e "${red}Error: failed to download data from GitHub${clear}"
        echo ""
        main_menu
    fi
}

validate_local_template() {
    if [ $(jq -e . < /var/www/${subspath}/template-loc.json &>/dev/null; echo $?) -ne 0 ] || [ ! -s /var/www/${subspath}/template-loc.json ] || [[ $(jq 'any(.inbounds[]; .tag == "tun-in")' /var/www/${subspath}/template-loc.json) == "false" ]] || [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /var/www/${subspath}/template-loc.json) == "false" ]]
    then
        echo -e "${red}Error: template-loc.json contains mistakes, corrections needed${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Enter ${textcolor}reset${clear} to reset the template to default version or enter ${textcolor}x${clear} to exit:"
        read resettemp
        echo ""
        if [[ "$resettemp" == "reset" ]]
        then
            validate_template
            rm /var/www/${subspath}/template-loc.json
            cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
            echo "The template has been reset to its default version"
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
            echo -e "${red}Error: this user already exists${clear}"
            echo ""
        elif [ -z "$username" ]
        then
            :
        elif [[ ! $username =~ ^[a-zA-Z0-9_-]+$ ]]
        then
            echo -e "${red}Error: the username should contain only letters, numbers, _ and - symbols${clear}"
            echo ""
        fi
        echo -e "${textcolor}[?]${clear} Enter the name of the new user or enter ${textcolor}x${clear} to exit:"
        read username
        [[ ! -z $username ]] && echo ""
    done
}

check_trjpass() {
    while ([[ $trjpass =~ '"' ]] || [[ $(jq "any(.inbounds[].users[]; .password == \"$trjpass\")" /etc/sing-box/config.json) == "true" ]]) && [ ! -z "$trjpass" ]
    do
        if [[ $trjpass =~ '"' ]]
        then
            echo -e "${red}Error: Trojan password should not contain quotes \"${clear}"
        else
            echo -e "${red}Error: this password is already assigned to another user${clear}"
        fi
        echo ""
        echo -e "${textcolor}[?]${clear} Enter the password for Trojan or leave this empty to generate a random password:"
        read trjpass
        [[ ! -z $trjpass ]] && echo ""
    done
}

check_uuid() {
    while ([[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]] || [[ $(jq "any(.inbounds[].users[]; .uuid == \"$uuid\")" /etc/sing-box/config.json) == "true" ]]) && [ ! -z "$uuid" ]
    do
        if [[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]
        then
            echo -e "${red}Error: this is not an UUID${clear}"
        elif [[ $(jq "any(.inbounds[].users[]; .uuid == \"$uuid\")" /etc/sing-box/config.json) == "true" ]]
        then
            echo -e "${red}Error: this UUID is already assigned to another user${clear}"
        fi
        echo ""
        echo -e "${textcolor}[?]${clear} Enter the UUID for VLESS or leave this empty to generate a random UUID:"
        read uuid
        [[ ! -z $uuid ]] && echo ""
    done
}

enter_user_data_add_ws() {
    echo -e "${textcolor}[?]${clear} Enter the name of the new user or enter ${textcolor}x${clear} to exit:"
    read username
    [[ ! -z $username ]] && echo ""
    check_username_add
    exit_username
    echo -e "${textcolor}[?]${clear} Enter the password for Trojan or leave this empty to generate a random password:"
    read trjpass
    [[ ! -z $trjpass ]] && echo ""
    check_trjpass
    echo -e "${textcolor}[?]${clear} Enter the UUID for VLESS or leave this empty to generate a random UUID:"
    read uuid
    [[ ! -z $uuid ]] && echo ""
    check_uuid
}

enter_user_data_add_haproxy() {
    echo -e "${textcolor}[?]${clear} Enter the name of the new user or enter ${textcolor}x${clear} to exit:"
    read username
    [[ ! -z $username ]] && echo ""
    check_username_add
    exit_username
    echo -e "${textcolor}[?]${clear} Enter the password for Trojan or leave this empty to generate a random password:"
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

    echo -e "Added user ${textcolor}${username}${clear}:"
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
        echo -e "${red}Error: a user with this name does not exist${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Enter the name of the user or enter ${textcolor}x${clear} to exit:"
        read username
        echo ""
        exit_username
    done
}

enter_user_data_del() {
    echo -e "${textcolor}[?]${clear} Enter the name of the user or enter ${textcolor}x${clear} to exit:"
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
    echo -e "Deleted user ${textcolor}${username}${clear}"
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
    echo -e "${red}ATTENTION!${clear}"
    echo "The settings in client configs of all users will be synchronized with the latest version on GitHub (for Russia)"
    echo ""
    echo -e "${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to synchronize the settings or enter ${textcolor}x${clear} to exit:"
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
        echo -e "${red}Error: no users found${clear}"
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

sync_client_configs_github() {
    for file in /var/www/${subspath}/*-CLIENT.json
    do
        get_pass
        rm ${file}
        cp /var/www/${subspath}/template.json ${file}
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

        sed -i -e "s/$tempdomain/$domain/g" -e "s/$tempip/$serverip/g" -e "s/$temprulesetpath/$rulesetpath/g" ${file}

        if [[ ! -z $cfip ]]
        then
            echo "$(jq ".outbounds[${outboundnum}].server = \"${cfip}\" | .outbounds[${outboundnum}].transport.headers |= {\"Host\":\"${domain}\"} | .route.rule_set[].download_detour = \"proxy\"" ${file})" > ${file}
        fi

        cfip=""
        cred=""
        inboundnum=""
        outboundnum=""
    done

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

    echo "Synchronization of the settings is completed"
    echo ""
}

sync_local_message() {
    echo -e "${red}ATTENTION!${clear}"
    echo -e "You can manually edit the settings in ${textcolor}/var/www/${subspath}/template-loc.json${clear} template"
    echo "The settings in this file will be applied to client configs of all users"
    echo "Do not change \"tag\" values in \"inbounds\" and \"outbounds\" while editing"
    echo ""
    echo -e "${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to synchronize the settings or enter ${textcolor}x${clear} to exit:"
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

    for file in /var/www/${subspath}/*-CLIENT.json
    do
        get_pass
        rm ${file}
        cp /var/www/${subspath}/template-loc.json ${file}
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

        sed -i -e "s/$loctempdomain/$domain/g" -e "s/$loctempip/$serverip/g" -e "s/$loctemprulesetpath/$rulesetpath/g" ${file}

        if [[ ! -z $cfip ]]
        then
            echo "$(jq ".outbounds[${outboundnum}].server = \"${cfip}\" | .outbounds[${outboundnum}].transport.headers |= {\"Host\":\"${domain}\"} | .route.rule_set[].download_detour = \"proxy\"" ${file})" > ${file}
        fi

        cfip=""
        cred=""
        inboundnum=""
        outboundnum=""
    done

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

    echo "Synchronization of the settings is completed"
    echo ""
}

show_users() {
    usernum=$(ls -A1 /var/www/${subspath} | grep "CLIENT.json" | wc -l)
    if [ ! -f /etc/haproxy/auth.lua ]
    then
        usernum=$(expr ${usernum} / 2)
    fi
    echo -e "${textcolor}Number of users:${clear} ${usernum}"
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
    echo -e "${textcolor}[?]${clear} Select \"stack\" value for user ${username}:"
    echo "0 - Exit"
    echo "1 - \"system\" (system stack, the best performance, default value)             ${stack_sel_1}"
    echo "2 - \"gvisor\" (runs in userspace, is recommended if \"system\" isn't working)   ${stack_sel_2}"
    echo "3 - \"mixed\" (mixed variant: \"system\" for TCP, \"gvisor\" for UDP)              ${stack_sel_3}"
    read stackoption
    echo ""
}

change_stack() {
    echo -e "${textcolor}[?]${clear} Enter the name of the user or enter ${textcolor}x${clear} to exit:"
    read username
    echo ""
    exit_username
    check_username_del

    if [[ $(jq -r '.inbounds[] | select(.tag=="tun-in") | .stack' /var/www/${subspath}/${username}-TRJ-CLIENT.json) == "system" ]]
    then
        stack_sel_1="[Selected]"
        stack_sel_2=""
        stack_sel_3=""
    elif [[ $(jq -r '.inbounds[] | select(.tag=="tun-in") | .stack' /var/www/${subspath}/${username}-TRJ-CLIENT.json) == "gvisor" ]]
    then
        stack_sel_1=""
        stack_sel_2="[Selected]"
        stack_sel_3=""
    elif [[ $(jq -r '.inbounds[] | select(.tag=="tun-in") | .stack' /var/www/${subspath}/${username}-TRJ-CLIENT.json) == "mixed" ]]
    then
        stack_sel_1=""
        stack_sel_2=""
        stack_sel_3="[Selected]"
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
    stack_value=""
    echo "The \"stack\" value has been changed, update the config on the client app to apply new settings"
    echo ""
    main_menu
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
    echo -e "${textcolor}Select synchronisation option:${clear}"
    echo "0 - Exit"
    echo "1 - Sync with GitHub"
    echo "2 - Sync with local template (custom settings)"
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
        echo -e "${red}Error: the entered value is not an IP${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Enter the custom Cloudflare IP:"
        read cfip
        echo ""
    done
}

set_cf_ip() {
    echo -e "${textcolor}[?]${clear} Enter the custom Cloudflare IP:"
    read cfip
    echo ""
    check_cfip

    outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-TRJ-CLIENT.json)
    echo "$(jq ".outbounds[${outboundnum}].server = \"${cfip}\" | .outbounds[${outboundnum}].transport.headers |= {\"Host\":\"${domain}\"} | .route.rule_set[].download_detour = \"proxy\"" /var/www/${subspath}/${username}-TRJ-CLIENT.json)" > /var/www/${subspath}/${username}-TRJ-CLIENT.json

    outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-VLESS-CLIENT.json)
    echo "$(jq ".outbounds[${outboundnum}].server = \"${cfip}\" | .outbounds[${outboundnum}].transport.headers |= {\"Host\":\"${domain}\"} | .route.rule_set[].download_detour = \"proxy\"" /var/www/${subspath}/${username}-VLESS-CLIENT.json)" > /var/www/${subspath}/${username}-VLESS-CLIENT.json

    echo -e "Changed the settings for the user ${textcolor}${username}${clear}, IP ${textcolor}${cfip}${clear} has been set"
    outboundnum=""
    cfip=""
    echo ""
    main_menu
}

remove_cf_ip() {
    outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-TRJ-CLIENT.json)
    echo "$(jq ".outbounds[${outboundnum}].server = \"${domain}\" | del(.outbounds[${outboundnum}].transport.headers) | del(.route.rule_set[].download_detour)" /var/www/${subspath}/${username}-TRJ-CLIENT.json)" > /var/www/${subspath}/${username}-TRJ-CLIENT.json

    outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-VLESS-CLIENT.json)
    echo "$(jq ".outbounds[${outboundnum}].server = \"${domain}\" | del(.outbounds[${outboundnum}].transport.headers) | del(.route.rule_set[].download_detour)" /var/www/${subspath}/${username}-VLESS-CLIENT.json)" > /var/www/${subspath}/${username}-VLESS-CLIENT.json

    outboundnum=""
    echo -e "Changed the settings for the user ${textcolor}${username}${clear}"
    echo ""
    main_menu
}

cf_text() {
    echo -e "${textcolor}[?]${clear} Select an option:"
    echo "0 - Exit"
    echo "1 - Setup/change custom Cloudflare IP   ${cf_ip_status}"
    echo "2 - Remove custom Cloudflare IP"
    read cfoption
    echo ""
}

cf_ip_settings() {
    if [ -f /etc/haproxy/auth.lua ]
    then
        echo -e "${red}Error: this option is only available for the setup variants with WebSocket or HTTPUpgrade transport${clear}"
        echo ""
        main_menu
    fi

    echo -e "${red}ATTENTION!${clear}"
    echo "This option is recommended in case of unavailability of the IP that Cloudflare allocated to your domain for proxying"
    echo "You need to scan Cloudflare IP ranges from your device and choose the optimal IP by yourself"
    echo "Instruction: https://github.com/BLUEBL0B/Secret-Sing-Box/blob/main/Docs/cf-scan-ip-en.md"
    echo ""

    echo -e "${textcolor}[?]${clear} Enter the name of the user or enter ${textcolor}x${clear} to exit:"
    read username
    echo ""
    exit_username
    check_username_del

    sel_cfip=$(jq -r '.outbounds[] | select(.tag=="proxy") | .server' /var/www/${subspath}/${username}-TRJ-CLIENT.json)

    if [[ $sel_cfip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
    then
        cf_ip_status="[Selected: ${sel_cfip}]"
    else
        cf_ip_status="[Cloudflare IP is not selected]"
    fi

    cf_text

    while [[ $(jq '.outbounds[] | select(.tag=="proxy") | .transport | has("headers")' /var/www/${subspath}/${username}-TRJ-CLIENT.json) == "false" ]] && [[ $cfoption == "2" ]]
    do
        echo -e "${red}Error: the config file of this user does not contain Cloudflare IP anyway${clear}"
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
}

show_warp_domains() {
    echo -e "${textcolor}List of domains/suffixes routed through WARP:${clear}"
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
            echo -e "${red}Error: this domain/suffix is already added to WARP${clear}"
            echo ""
        fi
        echo -e "${textcolor}[?]${clear} Enter a new domain/suffix for WARP routing or enter ${textcolor}x${clear} to exit:"
        read newwarp
        echo ""
        exit_add_warp
        crop_newwarp
    done
}

check_warp_domain_del() {
    while [[ -z $(jq '.route.rules[] | select(.outbound=="warp") | .domain_suffix[]' /etc/sing-box/config.json | grep "\"${delwarp}\"") ]] || [ -z "$delwarp" ]
    do
        echo -e "${red}Error: this domain/suffix is not added to WARP routing${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Enter a domain/suffix to delete from WARP routing or enter ${textcolor}x${clear} to exit:"
        read delwarp
        echo ""
        exit_del_warp
    done
}

add_warp_domains() {
    warpnum=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
    while [[ $newwarp != "x" ]] && [[ $newwarp != "х" ]]
    do
        echo -e "${textcolor}[?]${clear} Enter a new domain/suffix for WARP routing or enter ${textcolor}x${clear} to exit:"
        read newwarp
        echo ""
        crop_newwarp
        check_warp_domain_add
        exit_add_warp
        echo "$(jq ".route.rules[${warpnum}].domain_suffix[.route.rules[${warpnum}].domain_suffix | length]? += \"${newwarp}\"" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        systemctl reload sing-box.service
        echo -e "Domain/suffix ${textcolor}${newwarp}${clear} is added to WARP routing"
        echo ""
    done
}

delete_warp_domains() {
    warpnum=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
    while [[ $delwarp != "x" ]] && [[ $delwarp != "х" ]]
    do
        echo -e "${textcolor}[?]${clear} Enter a domain/suffix to delete from WARP routing or enter ${textcolor}x${clear} to exit:"
        read delwarp
        echo ""
        exit_del_warp
        check_warp_domain_del
        echo "$(jq "del(.route.rules[${warpnum}].domain_suffix[] | select(. == \"${delwarp}\"))" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        systemctl reload sing-box.service
        echo -e "Domain/suffix ${textcolor}${delwarp}${clear} is deleted from WARP routing"
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
        echo -e "${red}Error: invalid link to client config or the next server does not respond${clear}"
        echo ""
        while [[ -z $nextlink ]]
        do
            echo -e "${textcolor}[?]${clear} Enter the link to client config from the next server in the chain or enter ${textcolor}x${clear} to exit:"
            read nextlink
            echo ""
            exit_enter_nextlink
        done
        nextconfig=$(curl -s ${nextlink})
    done
}

chain_end() {
    config_temp=$(curl -s https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Config-Templates/config.json)

    if [ $(jq -e . >/dev/null 2>&1 <<< "${config_temp}"; echo $?) -eq 0 ] && [ -n "${config_temp}" ]
    then
        warp_rule=$(echo "${config_temp}" | jq '.route.rules[] | select(.outbound=="warp")')
        warpnum=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
        echo "$(jq ".route.rules[${warpnum}] |= . + ${warp_rule}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    else
        echo -e "${red}Error: failed to download data from GitHub${clear}"
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

    echo "Settings changed successfully"
    echo ""
    main_menu
}

chain_middle() {
    nextlink=""
    while [[ -z $nextlink ]]
    do
        echo -e "${textcolor}[?]${clear} Enter the link to client config from the next server in the chain or enter ${textcolor}x${clear} to exit:"
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

    echo "Settings changed successfully"
    echo ""
    main_menu
}

chain_text() {
    echo -e "${textcolor}[?]${clear} Select the position of the server in the chain:"
    echo "0 - Exit"
    echo "1 - Configure this server as the end of the chain or the only one                  ${chain_sel_1}"
    echo "2 - Configure this server as intermediate in the chain or change the next server   ${chain_sel_2}"
    read chain_option
    echo ""
}

chain_setup() {
    if [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) == "false" ]]
    then
        chain_sel_1="[Selected]"
        chain_sel_2=""
    else
        chain_sel_1=""
        chain_sel_2="[Selected: $(jq -r '.outbounds[] | select(.tag=="proxy") | .server' /etc/sing-box/config.json)]"
    fi

    chain_text

    while [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) == "false" ]] && [[ $chain_option == "1" ]]
    do
        echo -e "${red}Error: this server is already configured as the end of the chain or the only one${clear}"
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

reissue_cert() {
    email=""
    while [[ -z $email ]]
    do
        echo -e "${textcolor}[?]${clear} Enter your email registered on Cloudflare:"
        read email
        echo ""
    done

    rm -rf /etc/letsencrypt/live/${domain} &> /dev/null
    rm -rf /etc/letsencrypt/archive/${domain} &> /dev/null
    rm /etc/letsencrypt/renewal/${domain}.conf &> /dev/null

    echo -e "${textcolor}Requesting a certificate...${clear}"
    certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive

    if [ $? -eq 0 ]
    then
        echo ""
        echo "Certificate has been issued successfully"
    else
        echo ""
        echo -e "${red}Error: certificate has not been issued${clear}"
    fi

    if [ ! -f /etc/haproxy/auth.lua ] && [ -f /etc/letsencrypt/renewal/${domain}.conf ]
    then
        echo "renew_hook = systemctl reload nginx" >> /etc/letsencrypt/renewal/${domain}.conf
        systemctl start nginx.service
    elif [ -f /etc/haproxy/auth.lua ] && [ -f /etc/letsencrypt/renewal/${domain}.conf ]
    then
        echo "renew_hook = cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem && systemctl reload haproxy" >> /etc/letsencrypt/renewal/${domain}.conf
        cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem
        systemctl start haproxy.service
    fi

    echo ""
    main_menu
}

renew_cert() {
    echo -e "${red}ATTENTION!${clear}"
    echo "The script has a built-in automatic certificate renewal every 2 months, and manual renewal is recommended only in case of failures"
    echo "Renewing a certificate more than 5 times a week can result in reaching the Let's Encrypt limit, requiring you to wait before the next renewal"
    echo ""
    echo -e "${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to renew certificate or enter ${textcolor}x${clear} to exit:"
    read certrenew
    exit_renew_cert

    if [ ! -f /etc/letsencrypt/live/${domain}/fullchain.pem ]
    then
        reissue_cert
    fi

    certbot renew --force-renewal

    if [ $? -eq 0 ]
    then
        echo ""
        echo "Certificate has been renewed successfully"
    else
        echo ""
        echo -e "${red}Error: certificate has not been renewed${clear}"
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

check_cf_token() {
    echo "Checking domain name, API token/key and email..."
    get_test_response

    while [[ -z $(echo $test_response | grep "\"${testdomain}\"") ]] || [[ -z $(echo $test_response | grep "\"#dns_records:edit\"") ]] || [[ -z $(echo $test_response | grep "\"#dns_records:read\"") ]] || [[ -z $(echo $test_response | grep "\"#zone:read\"") ]]
    do
        domain=""
        email=""
        cftoken=""
        echo ""
        echo -e "${red}Error: invalid domain name, API token/key or email${clear}"
        echo ""
        while [[ -z $domain ]]
        do
            echo -e "${textcolor}[?]${clear} Enter your domain name or enter ${textcolor}x${clear} to exit:"
            read domain
            echo ""
        done
        exit_change_domain
        crop_domain
        while [[ -z $email ]]
        do
            echo -e "${textcolor}[?]${clear} Enter your email registered on Cloudflare:"
            read email
            echo ""
        done
        while [[ -z $cftoken ]]
        do
            echo -e "${textcolor}[?]${clear} Enter your Cloudflare API token (Edit zone DNS) or Cloudflare global API key:"
            read cftoken
            echo ""
        done
        echo "Checking domain name, API token/key and email..."
        get_test_response
    done

    echo "Success!"
    echo ""
}

change_domain() {
    old_domain="${domain}"
    domain=""
    email=""
    cftoken=""
    echo -e "${red}ATTENTION!${clear}"
    echo "Don't forget to create an A record for the new domain and change the domain in client config links"
    echo ""
    echo -e "Current domain: ${textcolor}${old_domain}${clear}"
    echo ""

    while [[ -z $domain ]]
    do
        echo -e "${textcolor}[?]${clear} Enter your domain name or enter ${textcolor}x${clear} to exit:"
        read domain
        echo ""
    done
    exit_change_domain
    crop_domain
    while [[ -z $email ]]
    do
        echo -e "${textcolor}[?]${clear} Enter your email registered on Cloudflare:"
        read email
        echo ""
    done
    while [[ -z $cftoken ]]
    do
        echo -e "${textcolor}[?]${clear} Enter your Cloudflare API token (Edit zone DNS) or Cloudflare global API key:"
        read cftoken
        echo ""
    done
    check_cf_token

    if [[ "$cftoken" =~ [A-Z] ]]
    then
        echo "dns_cloudflare_api_token = ${cftoken}" > /etc/letsencrypt/cloudflare.credentials
    else
        echo "dns_cloudflare_email = ${email}" > /etc/letsencrypt/cloudflare.credentials
        echo "dns_cloudflare_api_key = ${cftoken}" >> /etc/letsencrypt/cloudflare.credentials
    fi

    if [ ! -f /etc/letsencrypt/live/${domain}/fullchain.pem ]
    then
        echo -e "${textcolor}Requesting a certificate...${clear}"
        certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive

        if [ $? -ne 0 ]
        then
            sleep 3
            echo ""
            rm -rf /etc/letsencrypt/live/${domain} &> /dev/null
            rm -rf /etc/letsencrypt/archive/${domain} &> /dev/null
            rm /etc/letsencrypt/renewal/${domain}.conf &> /dev/null
            echo -e "${textcolor}Requesting a certificate: 2nd attempt...${clear}"
            certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive
        fi
    else
        echo -e "Found a certificate for the domain ${textcolor}${domain}${clear}"
    fi

    if [ ! -f /etc/haproxy/auth.lua ]
    then
        if ! grep -q "systemctl reload nginx" /etc/letsencrypt/renewal/${domain}.conf
        then
            echo "renew_hook = systemctl reload nginx" >> /etc/letsencrypt/renewal/${domain}.conf
        fi
        sed -i -e "s/$old_domain/$domain/g" /etc/nginx/nginx.conf
        systemctl reload nginx.service
        if [ $? -ne 0 ]
        then
            systemctl start nginx.service
        fi
    else
        if ! grep -q "systemctl reload haproxy" /etc/letsencrypt/renewal/${domain}.conf
        then
            echo "renew_hook = cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem && systemctl reload haproxy" >> /etc/letsencrypt/renewal/${domain}.conf
        fi
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
    echo -e "Domain ${textcolor}${old_domain}${clear} changed to ${textcolor}${domain}${clear}"

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

    echo -e "${textcolor}IPv6 is disabled:${clear}"
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

    echo -e "${textcolor}IPv6 is enabled:${clear}"
    sysctl -p

    if [[ ! -z $(crontab -l | grep "@reboot sysctl -p") ]]
    then
        crontab -l | sed "/@reboot sysctl -p/d" | crontab -
    fi

    echo ""
    main_menu
}

show_paths() {
    echo -e "${textcolor}Subscription page:${clear}"
    echo -e "https://${domain}/${subspath}/sub.html${grey}?name=$(ls -A1 /var/www/${subspath} | grep "CLIENT.json" | sed "s/-TRJ-CLIENT\.json//g" | sed "s/-VLESS-CLIENT\.json//g" | uniq | tail -n 1)${clear}"
    echo "Grey text shows an example of autofilling the username field"
    echo ""

    echo -e "${textcolor}Configuration of the services:${clear}"
    echo "Sing-Box config                      /etc/sing-box/config.json"
    echo "NGINX config                         /etc/nginx/nginx.conf"
    if [ -f /etc/haproxy/haproxy.cfg ]
    then
        echo "HAProxy config                       /etc/haproxy/haproxy.cfg"
        echo "Trojan password reading script       /etc/haproxy/auth.lua"
    fi
    echo ""

    echo -e "${textcolor}Content delivered by NGINX:${clear}"
    echo "Subscription directory               /var/www/${subspath}/"
    echo "Rule set directory                   /var/www/${rulesetpath}/"
    sitedir=$(grep "/var/www/" /etc/nginx/nginx.conf | head -n 1)
    sitedir=${sitedir#*"/var/www/"}
    sitedir=${sitedir%";"*}
    if [[ "$sitedir" =~ "/" ]]
    then
        sitedir=$(echo "${sitedir}" | cut -d "/" -f 1)
    fi
    if [ -d /var/www/${sitedir} ]
    then
        echo "Site directory                       /var/www/${sitedir}/"
    fi
    echo ""

    echo -e "${textcolor}Certificates and accessory files:${clear}"
    echo "Certificate directory                /etc/letsencrypt/live/${domain}/"
    echo "Certificate renewal config           /etc/letsencrypt/renewal/${domain}.conf"
    echo "File with Cloudflare API token/key   /etc/letsencrypt/cloudflare.credentials"
    echo ""

    echo -e "${textcolor}Scripts:${clear}"
    echo "This script (sbmanager)              /usr/local/bin/sbmanager"
    echo "Rule set renewal script              /usr/local/bin/rsupdate"
    echo ""
    echo ""
    exit 0
}

update_ssb() {
    export version="1.1.2"
    export language="2"
    export -f get_ip
    export -f replace_template
    export -f templates
    export -f get_data
    export -f check_users
    export -f validate_template
    export -f get_pass
    export -f sync_client_configs_github

    if [ $(wget -q -O /dev/null https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Scripts/update-server.sh; echo $?) -eq 0 ]
    then
        bash <(curl -Ls https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Scripts/update-server.sh)
        exit 0
    else
        echo -e "${red}Error: failed to download data from GitHub${clear}"
        echo ""
        main_menu
    fi
}

main_menu() {
    echo ""
    echo -e "${textcolor}Select an option:${clear}"
    echo "0 - Exit"
    echo "1 - Show the list of users"
    echo "2 - Add a new user"
    echo "3 - Delete a user"
    echo "---------------------------------"
    echo "4 - Change \"stack\" in tun interface of the user"
    echo "5 - Sync settings in all client configs"
    echo "6 - Setup connection to custom Cloudflare IP on the client"
    echo "---------------------------------"
    echo "7 - Show the list of domains/suffixes routed through WARP"
    echo "8 - Add a new domain/suffix to WARP routing"
    echo "9 - Delete a domain/suffix from WARP routing"
    echo "10 - Setup/remove a chain of two or more servers"
    echo "---------------------------------"
    echo "11 - Renew certificate manually"
    echo "12 - Change domain"
    echo "---------------------------------"
    echo "13 - Disable IPv6 on the server"
    echo "14 - Enable IPv6 on the server"
    echo "---------------------------------"
    echo "15 - Show paths to configs and other important files"
    echo "16 - Update"
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
