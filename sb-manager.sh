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

curl -s -o /var/www/${subspath}/template.json https://raw.githubusercontent.com/BLUEBL0B/Sing-Box-NGINX-WS/master/Config-Examples/Client-Trojan-WS.json

tempip=$(jq -r '.dns.servers[] | select(has("client_subnet")) | .client_subnet' /var/www/${subspath}/template.json)
tempdomain=$(jq -r '.outbounds[] | select(.tag=="proxy") | .server' /var/www/${subspath}/template.json)

echo ""
echo ""
while [[ "$option" != "6" ]]
do
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
        usernum=$(ls -A1 /var/www/${subspath} | grep "WS.json" | wc -l)
        usernum=$(expr ${usernum} / 2)
        echo -e "${textcolor}Количество пользователей:${clear} ${usernum}"
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
            echo ""
            continue
        fi

        while [[ $username != "x" ]] && [[ $username != "х" ]]
        do
            echo -e "Введите имя нового пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
            read username
            echo ""
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
                echo ""
            done
            if [[ $username == "x" ]] || [[ $username == "х" ]]
            then
                echo ""
                username=""
                continue 2
            fi
            echo "Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
            read trjpass
            echo ""
            while [[ $(jq "any(.inbounds[].users[]; .password == \"$trjpass\")" /etc/sing-box/config.json) == "true" ]] && [ ! -z "$trjpass" ]
            do
                echo -e "${red}Ошибка: этот пароль уже закреплён за другим пользователем${clear}"
                echo ""
                echo "Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
                read trjpass
                echo ""
            done
            echo "Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
            read uuid
            echo ""
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
                echo ""
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

            echo -e "Пользователь ${textcolor}${username}${clear} добавлен:"
            echo "https://${domain}/${subspath}/${username}-TRJ-WS.json"
            echo "https://${domain}/${subspath}/${username}-VLESS-WS.json"
            echo ""
        done
        echo ""
        ;;
        3)
        while [[ $username != "x" ]] && [[ $username != "х" ]]
        do
            echo -e "Введите имя пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
            read username
            echo ""
            if [[ $username == "x" ]] || [[ $username == "х" ]]
            then
                echo ""
                username=""
                continue 2
            fi
            while [[ ! -f /var/www/${subspath}/${username}-TRJ-WS.json ]]
            do
                echo -e "${red}Ошибка: пользователь с таким именем не существует${clear}"
                echo ""
                echo -e "Введите имя пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
                read username
                echo ""
                if [[ $username == "x" ]] || [[ $username == "х" ]]
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

            echo -e "Пользователь ${textcolor}${username}${clear} удалён"
            echo ""
        done
        echo ""
        ;;
        4)
        echo -e "${textcolor}ВНИМАНИЕ!${clear}"
        echo "Настройки в клиентских конфигах Trojan и VLESS всех пользователей будут синхронизированы с последней версией на Github"
        echo ""
        echo -e "Нажмите ${textcolor}Enter${clear}, чтобы синхронизировать настройки, или введите ${textcolor}x${clear}, чтобы выйти:"
        read sync

        if [[ "$sync" == "x" ]] || [[ "$sync" == "х" ]]
        then
            echo ""
            echo ""
            sync=""
            continue
        fi

        if [ $(ls -A1 /var/www/${subspath} | grep "WS.json" | wc -l) -eq 0 ]
        then
            echo -e "${red}Ошибка: пользователи отсутствуют${clear}"
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

        echo "Синхронизация настроек завершена"
        echo ""
        echo ""
        ;;
        5)
        if [ ! -f /var/www/${subspath}/template-loc.json ]
        then
            cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
        fi

        echo -e "${textcolor}ВНИМАНИЕ!${clear}"
        echo -e "Вы можете вручную отредактировать настройки в шаблоне ${textcolor}/var/www/${subspath}/template-loc.json${clear}"
        echo "Настройки в этом файле будут применены к клиентским конфигам Trojan и VLESS всех пользователей"
        echo ""
        echo -e "Нажмите ${textcolor}Enter${clear}, чтобы синхронизировать настройки, или введите ${textcolor}x${clear}, чтобы выйти:"
        read sync

        if [[ "$sync" == "x" ]] || [[ "$sync" == "х" ]]
        then
            echo ""
            echo ""
            sync=""
            continue
        fi

        if [ $(ls -A1 /var/www/${subspath} | grep "WS.json" | wc -l) -eq 0 ]
        then
            echo -e "${red}Ошибка: пользователи отсутствуют${clear}"
            echo ""
            echo ""
            continue
        fi

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

        echo "Синхронизация настроек завершена"
        echo ""
        echo ""
        ;;
        *)
        exit 0
    esac
done