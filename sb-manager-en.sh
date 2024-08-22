#!/bin/bash

textcolor='\033[1;36m'
red='\033[1;31m'
clear='\033[0m'

if [[ $EUID -ne 0 ]]
then
    echo ""
    echo -e "${red}Error: this script should be run as root${clear}"
    echo ""
    exit 1
fi

serverip=$(curl -s ipinfo.io/ip)

domain=$(ls /etc/letsencrypt/renewal)
domain=${domain%".conf"}

trojanpath=$(jq -r '.inbounds[] | select(.tag=="trojan-ws-in") | .transport.path' /etc/sing-box/config.json)
trojanpath=${trojanpath#"/"}

vlesspath=$(jq -r '.inbounds[] | select(.tag=="vless-ws-in") | .transport.path' /etc/sing-box/config.json)
vlesspath=${vlesspath#"/"}

subspath=$(grep "location ~ ^/" /etc/nginx/nginx.conf)
subspath=${subspath#"        location ~ ^/"}
subspath=${subspath%" {"}

curl -s -o /var/www/${subspath}/template.json https://raw.githubusercontent.com/BLUEBL0B/Sing-Box-NGINX-WS/master/Config-Examples/Client-Trojan-WS.json

tempip=$(jq -r '.dns.servers[] | select(has("client_subnet")) | .client_subnet' /var/www/${subspath}/template.json)
tempdomain=$(jq -r '.outbounds[] | select(.tag=="proxy") | .server' /var/www/${subspath}/template.json)

username=""

echo ""
echo ""
while [[ "$option" != "6" ]]
do
    echo -e "${textcolor}Select an option:${clear}"
    echo "1 - Show the list of users"
    echo "2 - Add a new user"
    echo "3 - Delete a user"
    echo "4 - Sync settings in all client configs with Github"
    echo "5 - Sync settings in all client configs with local template (custom settings)"
    echo "6 - Exit"
    read option
    echo ""
    case $option in
        1)
        usernum=$(ls -A1 /var/www/${subspath} | grep "WS.json" | wc -l)
        usernum=$(expr ${usernum} / 2)
        echo -e "${textcolor}Number of users:${clear} ${usernum}"
        ls -A1 /var/www/${subspath} | grep "WS.json" | sed "s/-TRJ-WS\.json//g" | sed "s/-VLESS-WS\.json//g" | uniq
        echo ""
        echo ""
        ;;
        2)
        if [ ! -f /var/www/${subspath}/template-loc.json ]
        then
            cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
        fi

        if [ $(jq -e . < /var/www/${subspath}/template-loc.json &>/dev/null; echo $?) -ne 0 ]
        then
            echo -e "${red}Error: template-loc.json contains mistakes, corrections needed${clear}"
            echo ""
            echo -e "Press ${textcolor}Enter${clear} to exit or enter ${textcolor}reset${clear} to reset the template to default version"
            read resettemp
            if [[ "$resettemp" == "reset" ]]
            then
                rm /var/www/${subspath}/template-loc.json
                cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
                echo ""
                echo "The template was reset to its default version"
                echo ""
            fi
            echo ""
            continue
        fi

        while [[ $username != "x" ]]
        do
            while [ -z "$username" ]
            do
                echo -e "Enter the name of the new user or enter ${textcolor}x${clear} to exit:"
                read username
                echo ""
                while [[ -f /var/www/${subspath}/${username}-TRJ-WS.json ]]
                do
                    echo -e "${red}Error: this user already exists${clear}"
                    echo ""
                    echo -e "Enter the name of the new user or enter ${textcolor}x${clear} to exit:"
                    read username
                    echo ""
                done
            done
            if [[ $username == "x" ]]
            then
                echo ""
                username=""
                continue 2
            fi
            echo "Enter the password for Trojan or leave this empty to generate a random password:"
            read trjpass
            echo ""
            while [[ $(jq "any(.inbounds[].users[]; .password == \"$trjpass\")" /etc/sing-box/config.json) == "true" ]] && [ ! -z "$trjpass" ]
            do
                echo -e "${red}Error: this password is already assigned to another user${clear}"
                echo ""
                echo "Enter the password for Trojan or leave this empty to generate a random password:"
                read trjpass
                echo ""
            done
            echo "Enter the UUID for VLESS or leave this empty to generate a random UUID:"
            read uuid
            echo ""
            while [[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]] && [ ! -z "$uuid" ]
            do
                echo -e "${red}Error: this is not an UUID${clear}"
                echo ""
                echo "Enter the UUID for VLESS or leave this empty to generate a random UUID:"
                read uuid
                echo ""
            done
            while [[ $(jq "any(.inbounds[].users[]; .password == \"$uuid\")" /etc/sing-box/config.json) == "true" ]] && [ ! -z "$uuid" ]
            do
                echo -e "${red}Error: this UUID is already assigned to another user${clear}"
                echo ""
                echo "Enter the UUID for VLESS or leave this empty to generate a random UUID:"
                read uuid
                echo ""
                while [[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]] && [ ! -z "$uuid" ]
                do
                    echo -e "${red}Error: this is not an UUID${clear}"
                    echo ""
                    echo "Enter the UUID for VLESS or leave this empty to generate a random UUID:"
                    read uuid
                    echo ""
                done
            done

            if [ -z "$trjpass" ]
            then
                trjpass=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
            fi

            if [ -z "$uuid" ]
            then
                uuid=$(sing-box generate uuid)
            fi

            inboundnum=$(jq '[.inbounds[].tag] | index("trojan-ws-in")' /etc/sing-box/config.json)
            echo "$(jq ".inbounds[${inboundnum}].users[.inbounds[${inboundnum}].users | length] |= . + {\"name\":\"${username}\",\"password\":\"${trjpass}\"}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
            inboundnum=$(jq '[.inbounds[].tag] | index("vless-ws-in")' /etc/sing-box/config.json)
            echo "$(jq ".inbounds[${inboundnum}].users[.inbounds[${inboundnum}].users | length] |= . + {\"name\":\"${username}\",\"uuid\":\"${uuid}\"}" /etc/sing-box/config.json)" > /etc/sing-box/config.json

            systemctl restart sing-box.service

            cp /var/www/${subspath}/template-loc.json /var/www/${subspath}/${username}-TRJ-WS.json
            outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-TRJ-WS.json)
            echo "$(jq ".outbounds[${outboundnum}].password = \"${trjpass}\" | .outbounds[${outboundnum}].transport.path = \"/${trojanpath}\"" /var/www/${subspath}/${username}-TRJ-WS.json)" > /var/www/${subspath}/${username}-TRJ-WS.json
            sed -i -e "s/$tempdomain/$domain/g" -e "s/$tempip/$serverip/g" /var/www/${subspath}/${username}-TRJ-WS.json

            cp /var/www/${subspath}/template-loc.json /var/www/${subspath}/${username}-VLESS-WS.json
            outboundnum=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-VLESS-WS.json)
            echo "$(jq ".outbounds[${outboundnum}].password = \"${uuid}\" | .outbounds[${outboundnum}].transport.path = \"/${vlesspath}\" | .outbounds[${outboundnum}].type = \"vless\" | .outbounds[${outboundnum}] |= with_entries(.key |= if . == \"password\" then \"uuid\" else . end)" /var/www/${subspath}/${username}-VLESS-WS.json)" > /var/www/${subspath}/${username}-VLESS-WS.json
            sed -i -e "s/$tempdomain/$domain/g" -e "s/$tempip/$serverip/g" /var/www/${subspath}/${username}-VLESS-WS.json

            echo -e "Added user ${textcolor}${username}${clear}:"
            echo "https://${domain}/${subspath}/${username}-TRJ-WS.json"
            echo "https://${domain}/${subspath}/${username}-VLESS-WS.json"
            echo ""
            username=""
        done
        echo ""
        ;;
        3)
        while [[ $username != "x" ]]
        do
            echo -e "Enter the name of the user or enter ${textcolor}x${clear} to exit:"
            read username
            echo ""
            if [[ $username == "x" ]]
            then
                echo ""
                username=""
                continue 2
            fi
            while [[ ! -f /var/www/${subspath}/${username}-TRJ-WS.json ]]
            do
                echo -e "${red}Error: a user with this name does not exist${clear}"
                echo ""
                echo -e "Enter the name of the user or enter ${textcolor}x${clear} to exit:"
                read username
                echo ""
                if [[ $username == "x" ]]
                then
                    echo ""
                    username=""
                    continue 3
                fi
            done

            inboundnum=$(jq '[.inbounds[].tag] | index("trojan-ws-in")' /etc/sing-box/config.json)
            echo "$(jq </etc/sing-box/config.json "del(.inbounds[${inboundnum}].users[] | select(.name==\"${username}\"))")" > /etc/sing-box/config.json
            inboundnum=$(jq '[.inbounds[].tag] | index("vless-ws-in")' /etc/sing-box/config.json)
            echo "$(jq </etc/sing-box/config.json "del(.inbounds[${inboundnum}].users[] | select(.name==\"${username}\"))")" > /etc/sing-box/config.json

            systemctl restart sing-box.service

            rm /var/www/${subspath}/${username}-TRJ-WS.json /var/www/${subspath}/${username}-VLESS-WS.json

            echo -e "Deleted user ${textcolor}${username}${clear}"
            echo ""
        done
        echo ""
        ;;
        4)
        echo -e "${textcolor}ATTENTION!${clear}"
        echo "The settings in Trojan and VLESS client configs of all users will be synchronized with the latest version on Github (for Russia)"
        echo ""
        echo -e "Press ${textcolor}Enter${clear} to synchronize the settings or enter ${textcolor}x${clear} to exit:"
        read sync

        if [[ "$sync" == "x" ]]
        then
            echo ""
            echo ""
            sync=""
            continue
        fi

        if [ $(ls -A1 /var/www/${subspath} | grep "WS.json" | wc -l) -eq 0 ]
        then
            echo -e "${red}Error: no users found${clear}"
            echo ""
            echo ""
            continue
        fi

        for file in /var/www/${subspath}/*-WS.json
        do
            if grep -q ": \"trojan\"" "$file"
            then
                protocol="trojan"
                cred=$(jq -r '.outbounds[] | select(.tag=="proxy") | .password' ${file})
            else
                protocol="vless"
                cred=$(jq -r '.outbounds[] | select(.tag=="proxy") | .uuid' ${file})
            fi
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

        echo "Synchronization of the settings is completed"
        echo ""
        echo ""
        ;;
        5)
        if [ ! -f /var/www/${subspath}/template-loc.json ]
        then
            cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
        fi

        echo -e "${textcolor}ATTENTION!${clear}"
        echo -e "You can manually edit the settings in ${textcolor}/var/www/${subspath}/template-loc.json${clear} template"
        echo "The settings in this file will be applied to Trojan and VLESS client configs of all users"
        echo ""
        echo -e "Press ${textcolor}Enter${clear} to synchronize the settings or enter ${textcolor}x${clear} to exit:"
        read sync

        if [[ "$sync" == "x" ]]
        then
            echo ""
            echo ""
            sync=""
            continue
        fi

        if [ $(ls -A1 /var/www/${subspath} | grep "WS.json" | wc -l) -eq 0 ]
        then
            echo -e "${red}Error: no users found${clear}"
            echo ""
            echo ""
            continue
        fi

        if [ $(jq -e . < /var/www/${subspath}/template-loc.json &>/dev/null; echo $?) -ne 0 ]
        then
            echo -e "${red}Error: template-loc.json contains mistakes, corrections needed${clear}"
            echo ""
            echo -e "Press ${textcolor}Enter${clear} to exit or enter ${textcolor}reset${clear} to reset the template to default version"
            read resettemp
            if [[ "$resettemp" == "reset" ]]
            then
                rm /var/www/${subspath}/template-loc.json
                cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
                echo ""
                echo "The template was reset to its default version"
                echo ""
            fi
            echo ""
            continue
        fi

        loctempip=$(jq -r '.dns.servers[] | select(has("client_subnet")) | .client_subnet' /var/www/${subspath}/template-loc.json)
        loctempdomain=$(jq -r '.outbounds[] | select(.tag=="proxy") | .server' /var/www/${subspath}/template-loc.json)

        for file in /var/www/${subspath}/*-WS.json
        do
            if grep -q ": \"trojan\"" "$file"
            then
                protocol="trojan"
                cred=$(jq -r '.outbounds[] | select(.tag=="proxy") | .password' ${file})
            else
                protocol="vless"
                cred=$(jq -r '.outbounds[] | select(.tag=="proxy") | .uuid' ${file})
            fi
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

        echo "Synchronization of the settings is completed"
        echo ""
        echo ""
        ;;
        *)
        exit 0
    esac
done