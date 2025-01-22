#!/bin/bash

textcolor='\033[0;36m'
red='\033[1;31m'
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
    serverip=$(curl -s ipinfo.io/ip)

    if [[ ! $serverip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
    then
        serverip=$(curl -s 2ip.io)
    fi

    if [[ ! $serverip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
    then
        serverip=$(curl -s ifconfig.me)
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

    temprulesetpath=$(jq -r ".route.rule_set[-1].url" /var/www/${subspath}/template.json)
    temprulesetpath=${temprulesetpath#*"https://${tempdomain}/"}
    temprulesetpath=${temprulesetpath%"/"*}

    echo ""
}

validate_template() {
    if [ $(jq -e . < /var/www/${subspath}/template.json &>/dev/null; echo $?) -ne 0 ] || [ ! -s /var/www/${subspath}/template.json ]
    then
        echo -e "${red}Error: failed to load data from Github${clear}"
        echo ""
        exit 1
    fi
}

validate_local_template() {
    if [ $(jq -e . < /var/www/${subspath}/template-loc.json &>/dev/null; echo $?) -ne 0 ] || [ ! -s /var/www/${subspath}/template-loc.json ]
    then
        echo -e "${red}Error: template-loc.json contains mistakes, corrections needed${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to exit or enter ${textcolor}reset${clear} to reset the template to default version"
        read resettemp
        if [[ "$resettemp" == "reset" ]]
        then
            echo ""
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
    while [[ -f /var/www/${subspath}/${username}-TRJ-CLIENT.json ]] || [[ $username =~ " " ]] || [[ $username =~ '$' ]] || [ -z "$username" ]
    do
        if [[ -f /var/www/${subspath}/${username}-TRJ-CLIENT.json ]]
        then
            echo -e "${red}Error: this user already exists${clear}"
            echo ""
        elif [[ $username =~ " " ]] || [[ $username =~ '$' ]]
        then
            echo -e "${red}Error: username should not contain spaces and \$${clear}"
            echo ""
        elif [ -z "$username" ]
        then
            :
        fi
        echo -e "${textcolor}[?]${clear} Enter the name of the new user or enter ${textcolor}x${clear} to exit:"
        read username
        [[ ! -z $username ]] && echo ""
    done
}

check_trjpass() {
    while [[ $(jq "any(.inbounds[].users[]; .password == \"$trjpass\")" /etc/sing-box/config.json) == "true" ]] && [ ! -z "$trjpass" ]
    do
        echo -e "${red}Error: this password is already assigned to another user${clear}"
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
    echo "The settings in client configs of all users will be synchronized with the latest version on Github (for Russia)"
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

    echo "Synchronization of the settings is completed"
    echo ""
}

sync_local_message() {
    echo -e "${red}ATTENTION!${clear}"
    echo -e "You can manually edit the settings in ${textcolor}/var/www/${subspath}/template-loc.json${clear} template"
    echo "The settings in this file will be applied to client configs of all users"
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

check_warp_domain_add() {
    while [[ -n $(jq '.route.rules[] | select(.outbound=="warp") | .domain_suffix[]' /etc/sing-box/config.json | grep "\"${newwarp}\"") ]]
    do
        echo -e "${red}Error: this domain/suffix is already added to WARP${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Enter a new domain/suffix for WARP routing or enter ${textcolor}x${clear} to exit:"
        read newwarp
        echo ""
        exit_add_warp
    done
}

check_warp_domain_del() {
    while [[ -z $(jq '.route.rules[] | select(.outbound=="warp") | .domain_suffix[]' /etc/sing-box/config.json | grep "\"${delwarp}\"") ]]
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

    if [[ $(jq 'any(.route.rule_set[]; .tag == "google")' /etc/sing-box/config.json) == "false" ]] && [ $(jq -e . >/dev/null 2>&1 <<< "${config_temp}"; echo $?) -eq 0 ] && [ -n "${config_temp}" ]
    then
        google_set=$(echo "${config_temp}" | jq '.route.rule_set[] | select(.tag=="google")')
        echo "$(jq ".route.rule_set[.route.rule_set | length] |= . + ${google_set}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    if [[ $(jq 'any(.route.rule_set[]; .tag == "telegram")' /etc/sing-box/config.json) == "false" ]] && [ $(jq -e . >/dev/null 2>&1 <<< "${config_temp}"; echo $?) -eq 0 ] && [ -n "${config_temp}" ]
    then
        telegram_set=$(echo "${config_temp}" | jq '.route.rule_set[] | select(.tag=="telegram")')
        echo "$(jq ".route.rule_set[.route.rule_set | length] |= . + ${telegram_set}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    if [[ $(jq 'any(.route.rule_set[]; .tag == "openai")' /etc/sing-box/config.json) == "false" ]] && [ $(jq -e . >/dev/null 2>&1 <<< "${config_temp}"; echo $?) -eq 0 ] && [ -n "${config_temp}" ]
    then
        openai_set=$(echo "${config_temp}" | jq '.route.rule_set[] | select(.tag=="openai")')
        echo "$(jq ".route.rule_set[.route.rule_set | length] |= . + ${openai_set}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    sed -i -e "s/$temprulesetpath/$rulesetpath/g" /etc/sing-box/config.json

    systemctl reload sing-box.service

    echo "Settings changed"
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

    if [[ $(jq 'any(.route.rule_set[]; .tag == "google")' /etc/sing-box/config.json) == "true" ]]
    then
        echo "$(jq </etc/sing-box/config.json 'del(.route.rule_set[] | select(.tag=="google"))')" > /etc/sing-box/config.json
    fi

    if [[ $(jq 'any(.route.rule_set[]; .tag == "telegram")' /etc/sing-box/config.json) == "true" ]]
    then
        echo "$(jq </etc/sing-box/config.json 'del(.route.rule_set[] | select(.tag=="telegram"))')" > /etc/sing-box/config.json
    fi

    if [[ $(jq 'any(.route.rule_set[]; .tag == "openai")' /etc/sing-box/config.json) == "true" ]]
    then
        echo "$(jq </etc/sing-box/config.json 'del(.route.rule_set[] | select(.tag=="openai"))')" > /etc/sing-box/config.json
    fi

    systemctl reload sing-box.service

    echo "Settings changed"
    echo ""
    main_menu
}

chain_setup() {
    echo -e "${textcolor}[?]${clear} Select the position of the server in the chain:"
    echo "0 - Exit"
    if [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) == "false" ]]
    then
        echo "1 - Configure this server as the end of the chain or the only one                  [Selected]"
        echo "2 - Configure this server as intermediate in the chain or change the next server"
    else
        echo "1 - Configure this server as the end of the chain or the only one"
        echo "2 - Configure this server as intermediate in the chain or change the next server   [Selected]"
    fi
    read chain_option
    echo ""

    while [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) == "false" ]] && [[ $chain_option == "1" ]]
    do
        echo -e "${red}Error: this server is already configured as the end of the chain or the only one${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Select the position of the server in the chain:"
        echo "0 - Exit"
        echo "1 - Configure this server as the end of the chain or the only one                  [Selected]"
        echo "2 - Configure this server as intermediate in the chain or change the next server"
        read chain_option
        echo ""
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

change_stack() {
    echo -e "${textcolor}[?]${clear} Enter the name of the user or enter ${textcolor}x${clear} to exit:"
    read username
    echo ""
    exit_username
    check_username_del

    echo -e "${textcolor}[?]${clear} Select \"stack\" value for user ${username}:"
    echo "0 - Exit"
    if [[ $(jq -r '.inbounds[] | select(.tag=="tun-in") | .stack' /var/www/${subspath}/${username}-TRJ-CLIENT.json) == "system" ]]
    then
        echo "1 - \"system\" (system stack, the best performance, default value)             [Selected]"
    else
        echo "1 - \"system\" (system stack, the best performance, default value)"
    fi
    if [[ $(jq -r '.inbounds[] | select(.tag=="tun-in") | .stack' /var/www/${subspath}/${username}-TRJ-CLIENT.json) == "gvisor" ]]
    then
        echo "2 - \"gvisor\" (runs in userspace, is recommended if \"system\" isn't working)   [Selected]"
    else
        echo "2 - \"gvisor\" (runs in userspace, is recommended if \"system\" isn't working)"
    fi
    if [[ $(jq -r '.inbounds[] | select(.tag=="tun-in") | .stack' /var/www/${subspath}/${username}-TRJ-CLIENT.json) == "mixed" ]]
    then
        echo "3 - \"mixed\" (mixed variant: \"system\" for TCP, \"gvisor\" for UDP)              [Selected]"
    else
        echo "3 - \"mixed\" (mixed variant: \"system\" for TCP, \"gvisor\" for UDP)"
    fi
    read stackoption
    echo ""

    inboundnum=$(jq '[.inbounds[].tag] | index("tun-in")' /var/www/${subspath}/${username}-TRJ-CLIENT.json)

    case $stackoption in
        1)
        echo "$(jq ".inbounds[${inboundnum}].stack = \"system\"" /var/www/${subspath}/${username}-TRJ-CLIENT.json)" > /var/www/${subspath}/${username}-TRJ-CLIENT.json
        ;;
        2)
        echo "$(jq ".inbounds[${inboundnum}].stack = \"gvisor\"" /var/www/${subspath}/${username}-TRJ-CLIENT.json)" > /var/www/${subspath}/${username}-TRJ-CLIENT.json
        ;;
        3)
        echo "$(jq ".inbounds[${inboundnum}].stack = \"mixed\"" /var/www/${subspath}/${username}-TRJ-CLIENT.json)" > /var/www/${subspath}/${username}-TRJ-CLIENT.json
        ;;
        *)
        main_menu
    esac

    if [ ! -f /etc/haproxy/auth.lua ]
    then
        inboundnum=$(jq '[.inbounds[].tag] | index("tun-in")' /var/www/${subspath}/${username}-VLESS-CLIENT.json)

        case $stackoption in
            2)
            echo "$(jq ".inbounds[${inboundnum}].stack = \"gvisor\"" /var/www/${subspath}/${username}-VLESS-CLIENT.json)" > /var/www/${subspath}/${username}-VLESS-CLIENT.json
            ;;
            3)
            echo "$(jq ".inbounds[${inboundnum}].stack = \"mixed\"" /var/www/${subspath}/${username}-VLESS-CLIENT.json)" > /var/www/${subspath}/${username}-VLESS-CLIENT.json
            ;;
            *)
            echo "$(jq ".inbounds[${inboundnum}].stack = \"system\"" /var/www/${subspath}/${username}-VLESS-CLIENT.json)" > /var/www/${subspath}/${username}-VLESS-CLIENT.json
        esac
    fi

    inboundnum=""
    echo "The \"stack\" value changed, update the config on the client app to apply new settings"
    echo ""
    main_menu
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
        echo "renew_hook = systemctl reload nginx" >> /etc/letsencrypt/renewal/${domain}.conf
        sed -i -e "s/$old_domain/$domain/g" /etc/nginx/nginx.conf
        systemctl reload nginx.service
        if [ $? -ne 0 ]
        then
            systemctl start nginx.service
        fi
    else
        echo "renew_hook = cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem && systemctl reload haproxy" >> /etc/letsencrypt/renewal/${domain}.conf
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

    echo -e "${textcolor}IPv6 is not disabled:${clear}"
    sysctl -p

    if [[ ! -z $(crontab -l | grep "@reboot sysctl -p") ]]
    then
        crontab -l | sed "/@reboot sysctl -p/d" | crontab -
    fi

    echo ""
    main_menu
}

main_menu() {
    echo ""
    echo -e "${textcolor}Select an option:${clear}"
    echo "0 - Exit"
    echo "------------------------"
    echo "1 - Show the list of users"
    echo "2 - Add a new user"
    echo "3 - Delete a user"
    echo "------------------------"
    echo "4 - Change \"stack\" in tun interface of the user"
    echo "5 - Sync settings in all client configs with Github"
    echo "6 - Sync settings in all client configs with local template (custom settings)"
    echo "------------------------"
    echo "7 - Show the list of domains/suffixes routed through WARP"
    echo "8 - Add a new domain/suffix to WARP routing"
    echo "9 - Delete a domain/suffix from WARP routing"
    echo "------------------------"
    echo "10 - Setup/remove a chain of two or more servers"
    echo "------------------------"
    echo "11 - Renew certificate manually"
    echo "12 - Change domain"
    echo "------------------------"
    echo "13 - Disable IPv6 on the server"
    echo "14 - Enable IPv6 on the server"
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
        sync_with_github
        ;;
        6)
        sync_with_local_temp
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
        *)
        exit 0
    esac
}

check_root
get_data
main_menu
