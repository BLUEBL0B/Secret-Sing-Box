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

trojanpath=$(jq -r '.inbounds[0].transport.path' /etc/sing-box/config.json)
trojanpath=${trojanpath#"/"}

vlesspath=$(jq -r '.inbounds[1].transport.path' /etc/sing-box/config.json)
vlesspath=${vlesspath#"/"}

subspath=$(grep "location ~ ^/" /etc/nginx/nginx.conf)
subspath=${subspath#"        location ~ ^/"}
subspath=${subspath%" {"}

curl -s -o /var/www/${subspath}/template.json https://raw.githubusercontent.com/BLUEBL0B/Sing-Box-NGINX-WS/master/Config-Examples/Client-Trojan-WS.json

echo ""
echo ""
echo -e "${textcolor}Select the language:${clear}"
echo "1 - Russian"
echo "2 - English"
read language
echo ""
echo ""
while [[ "$option" != "6" ]]
do
    if [[ "$language" == "1" ]]
    then
        echo -e "${textcolor}Выберите действие:${clear}"
        echo "1 - Вывести список пользователей"
        echo "2 - Добавить нового пользователя"
        echo "3 - Удалить пользователя"
        echo "4 - Синхронизировать клиентские правила маршрутизации с Github"
        echo "5 - Синхронизировать клиентские правила маршрутизации с локальным шаблоном"
        echo "6 - Выйти"
        read option
        echo ""
        case $option in
            1)
            usernum=$(ls -A1 /var/www/${subspath} | grep "WS.json" | wc -l)
            usernum=$(expr ${usernum} / 2)
            echo -e "Количество пользователей: ${textcolor}${usernum}${clear}"
            ls -A1 /var/www/${subspath} | grep "WS.json" | sed "s/-TRJ-WS\.json//g" | sed "s/-VLESS-WS\.json//g" | uniq
            echo ""
            echo ""
            ;;
            2)
            while [[ $username != "stop" ]]
            do
                echo -e "Введите имя нового пользователя или введите ${textcolor}stop${clear}, чтобы закончить:"
                read username
                echo ""
                while [[ -f /var/www/${subspath}/${username}-TRJ-WS.json ]]
                do
                    echo -e "${red}Ошибка: пользователь с таким именем уже существует${clear}"
                    echo ""
                    echo -e "Введите имя нового пользователя или введите ${textcolor}stop${clear}, чтобы закончить:"
                    read username
                    echo ""
                done
                if [[ $username == "stop" ]]
                then
                    echo ""
                    username=""
                    continue 2
                fi
                echo "Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
                read trjpass
                echo ""
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

                if [ -z "$trjpass" ]
                then
                    trjpass=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
                fi

                if [ -z "$uuid" ]
                then
                    uuid=$(sing-box generate uuid)
                fi

                echo "$(jq ".inbounds[0].users[.inbounds[0].users | length] |= . + {\"name\":\"${username}\",\"password\":\"${trjpass}\"}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
                echo "$(jq ".inbounds[1].users[.inbounds[1].users | length] |= . + {\"name\":\"${username}\",\"uuid\":\"${uuid}\"}" /etc/sing-box/config.json)" > /etc/sing-box/config.json

                systemctl restart sing-box.service

                cp /var/www/${subspath}/template.json /var/www/${subspath}/${username}-TRJ-WS.json
                sed -i -e "s/YOUR-SERVER-IP/$serverip/g" -e "s/YOUR-DOMAIN/$domain/g" -e "s/YOUR-TROJAN-PASSWORD/$trjpass/g" -e "s/YOUR-TROJAN-PATH/$trojanpath/g" /var/www/${subspath}/${username}-TRJ-WS.json
                cp /var/www/${subspath}/${username}-TRJ-WS.json /var/www/${subspath}/${username}-VLESS-WS.json
                sed -i -e "s/$trjpass/$uuid/g" -e "s/$trojanpath/$vlesspath/g" -e 's/: "trojan"/: "vless"/g' -e 's/"password": /"uuid": /g' /var/www/${subspath}/${username}-VLESS-WS.json

                echo -e "Пользователь ${textcolor}${username}${clear} добавлен:"
                echo "https://${domain}/${subspath}/${username}-TRJ-WS.json"
                echo "https://${domain}/${subspath}/${username}-VLESS-WS.json"
                echo ""
            done
            echo ""
            ;;
            3)
            while [[ $username != "stop" ]]
            do
                echo -e "Введите имя пользователя или введите ${textcolor}stop${clear}, чтобы закончить:"
                read username
                echo ""
                if [[ $username == "stop" ]]
                then
                    echo ""
                    username=""
                    continue 2
                fi
                while [[ ! -f /var/www/${subspath}/${username}-TRJ-WS.json ]]
                do
                    echo -e "${red}Ошибка: пользователь с таким именем не существует${clear}"
                    echo ""
                    echo -e "Введите имя пользователя или введите ${textcolor}stop${clear}, чтобы закончить:"
                    read username
                    echo ""
                    if [[ $username == "stop" ]]
                    then
                        echo ""
                        username=""
                        continue 3
                    fi
                done

                echo "$(jq </etc/sing-box/config.json "del(.inbounds[0].users[] | select(.name==\"${username}\"))")" > /etc/sing-box/config.json
                echo "$(jq </etc/sing-box/config.json "del(.inbounds[1].users[] | select(.name==\"${username}\"))")" > /etc/sing-box/config.json

                systemctl restart sing-box.service

                rm /var/www/${subspath}/${username}-TRJ-WS.json /var/www/${subspath}/${username}-VLESS-WS.json

                echo -e "Пользователь ${textcolor}${username}${clear} удалён"
                echo ""
            done
            echo ""
            ;;
            4)
            echo -e "${textcolor}ВНИМАНИЕ!${clear}"
            echo "Правила маршрутизации во всех клиентских конфигах будут синхронизированы с последней версией на Github"
            echo ""
            echo -e "Нажмите ${textcolor}Enter${clear}, чтобы синхронизировать правила, или введите ${textcolor}stop${clear}, чтобы выйти:"
            read sync

            if [[ "$sync" == "stop" ]]
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
                if grep -q "trojan" "$file"
                then
                    protocol="trojan"
                    cred=$(jq -r '.outbounds[3].password' ${file})
                else
                    protocol="vless"
                    cred=$(jq -r '.outbounds[3].uuid' ${file})
                fi
                rm ${file}
                cp /var/www/${subspath}/template.json ${file}
                if [[ "$protocol" == "trojan" ]]
                then
                    sed -i -e "s/YOUR-SERVER-IP/$serverip/g" -e "s/YOUR-DOMAIN/$domain/g" -e "s/YOUR-TROJAN-PASSWORD/$cred/g" -e "s/YOUR-TROJAN-PATH/$trojanpath/g" ${file}
                else
                    sed -i -e "s/YOUR-SERVER-IP/$serverip/g" -e "s/YOUR-DOMAIN/$domain/g" -e "s/YOUR-TROJAN-PASSWORD/$cred/g" -e "s/YOUR-TROJAN-PATH/$vlesspath/g" -e 's/: "trojan"/: "vless"/g' -e 's/"password": /"uuid": /g' ${file}
                fi
                cred=""
            done

            echo "Синхронизация правил завершена"
            echo ""
            echo ""
            ;;
            5)
            if [ ! -f /var/www/${subspath}/template-loc.json ]
            then
                cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
            fi

            echo -e "${textcolor}ВНИМАНИЕ!${clear}"
            echo -e "Вы можете вручную отредактировать правила маршрутизации в шаблоне ${textcolor}/var/www/${subspath}/template-loc.json${clear}"
            echo "Правила в этом файле будут применены ко всем клиентским конфигам"
            echo ""
            echo -e "Нажмите ${textcolor}Enter${clear}, чтобы синхронизировать правила, или введите ${textcolor}stop${clear}, чтобы выйти:"
            read sync

            if [[ "$sync" == "stop" ]]
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
                echo -e "${red}Ошибка: структура /var/www/${subspath}/template-loc.json нарушена, требуются исправления${clear}"
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

            for file in /var/www/${subspath}/*-WS.json
            do
                if grep -q "trojan" "$file"
                then
                    protocol="trojan"
                    cred=$(jq -r '.outbounds[3].password' ${file})
                else
                    protocol="vless"
                    cred=$(jq -r '.outbounds[3].uuid' ${file})
                fi
                rm ${file}
                cp /var/www/${subspath}/template-loc.json ${file}
                if [[ "$protocol" == "trojan" ]]
                then
                    sed -i -e "s/YOUR-SERVER-IP/$serverip/g" -e "s/YOUR-DOMAIN/$domain/g" -e "s/YOUR-TROJAN-PASSWORD/$cred/g" -e "s/YOUR-TROJAN-PATH/$trojanpath/g" ${file}
                else
                    sed -i -e "s/YOUR-SERVER-IP/$serverip/g" -e "s/YOUR-DOMAIN/$domain/g" -e "s/YOUR-TROJAN-PASSWORD/$cred/g" -e "s/YOUR-TROJAN-PATH/$vlesspath/g" -e 's/: "trojan"/: "vless"/g' -e 's/"password": /"uuid": /g' ${file}
                fi
                cred=""
            done

            echo "Синхронизация правил завершена"
            echo ""
            echo ""
            ;;
            *)
            exit 0
        esac
    else
        echo -e "${textcolor}Select an option:${clear}"
        echo "1 - Show the list of users"
        echo "2 - Add a new user"
        echo "3 - Delete a user"
        echo "4 - Sync client routing rules with Github"
        echo "5 - Sync client routing rules with local template"
        echo "6 - Exit"
        read option
        echo ""
        case $option in
            1)
            usernum=$(ls -A1 /var/www/${subspath} | grep "WS.json" | wc -l)
            usernum=$(expr ${usernum} / 2)
            echo -e "Number of users: ${textcolor}${usernum}${clear}"
            ls -A1 /var/www/${subspath} | grep "WS.json" | sed "s/-TRJ-WS\.json//g" | sed "s/-VLESS-WS\.json//g" | uniq
            echo ""
            echo ""
            ;;
            2)
            while [[ $username != "stop" ]]
            do
                echo -e "Enter the name of the new user or enter ${textcolor}stop${clear} to exit:"
                read username
                echo ""
                while [[ -f /var/www/${subspath}/${username}-TRJ-WS.json ]]
                do
                    echo -e "${red}Error: this user already exists${clear}"
                    echo ""
                    echo -e "Enter the name of the new user or enter ${textcolor}stop${clear} to exit:"
                    read username
                    echo ""
                done
                if [[ $username == "stop" ]]
                then
                    echo ""
                    username=""
                    continue 2
                fi
                echo "Enter the password for Trojan or leave this empty to generate a random password:"
                read trjpass
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

                if [ -z "$trjpass" ]
                then
                    trjpass=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
                fi

                if [ -z "$uuid" ]
                then
                    uuid=$(sing-box generate uuid)
                fi

                echo "$(jq ".inbounds[0].users[.inbounds[0].users | length] |= . + {\"name\":\"${username}\",\"password\":\"${trjpass}\"}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
                echo "$(jq ".inbounds[1].users[.inbounds[1].users | length] |= . + {\"name\":\"${username}\",\"uuid\":\"${uuid}\"}" /etc/sing-box/config.json)" > /etc/sing-box/config.json

                systemctl restart sing-box.service

                cp /var/www/${subspath}/template.json /var/www/${subspath}/${username}-TRJ-WS.json
                sed -i -e "s/YOUR-SERVER-IP/$serverip/g" -e "s/YOUR-DOMAIN/$domain/g" -e "s/YOUR-TROJAN-PASSWORD/$trjpass/g" -e "s/YOUR-TROJAN-PATH/$trojanpath/g" /var/www/${subspath}/${username}-TRJ-WS.json
                cp /var/www/${subspath}/${username}-TRJ-WS.json /var/www/${subspath}/${username}-VLESS-WS.json
                sed -i -e "s/$trjpass/$uuid/g" -e "s/$trojanpath/$vlesspath/g" -e 's/: "trojan"/: "vless"/g' -e 's/"password": /"uuid": /g' /var/www/${subspath}/${username}-VLESS-WS.json

                echo -e "Added user ${textcolor}${username}${clear}:"
                echo "https://${domain}/${subspath}/${username}-TRJ-WS.json"
                echo "https://${domain}/${subspath}/${username}-VLESS-WS.json"
                echo ""
            done
            echo ""
            ;;
            3)
            while [[ $username != "stop" ]]
            do
                echo -e "Enter the name of the user or enter ${textcolor}stop${clear} to exit:"
                read username
                echo ""
                if [[ $username == "stop" ]]
                then
                    echo ""
                    username=""
                    continue 2
                fi
                while [[ ! -f /var/www/${subspath}/${username}-TRJ-WS.json ]]
                do
                    echo -e "${red}Error: a user with this name does not exist${clear}"
                    echo ""
                    echo -e "Enter the name of the user or enter ${textcolor}stop${clear} to exit:"
                    read username
                    echo ""
                    if [[ $username == "stop" ]]
                    then
                        echo ""
                        username=""
                        continue 3
                    fi
                done

                echo "$(jq </etc/sing-box/config.json "del(.inbounds[0].users[] | select(.name==\"${username}\"))")" > /etc/sing-box/config.json
                echo "$(jq </etc/sing-box/config.json "del(.inbounds[1].users[] | select(.name==\"${username}\"))")" > /etc/sing-box/config.json

                systemctl restart sing-box.service

                rm /var/www/${subspath}/${username}-TRJ-WS.json /var/www/${subspath}/${username}-VLESS-WS.json

                echo -e "Deleted user ${textcolor}${username}${clear}"
                echo ""
            done
            echo ""
            ;;
            4)
            echo -e "${textcolor}ATTENTION!${clear}"
            echo "The routing rules in all client configs will be synchronized with the latest version on Github (for Russia)"
            echo ""
            echo -e "Press ${textcolor}Enter${clear} to synchronize the rules or enter ${textcolor}stop${clear} to exit:"
            read sync

            if [[ "$sync" == "stop" ]]
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
                if grep -q "trojan" "$file"
                then
                    protocol="trojan"
                    cred=$(jq -r '.outbounds[3].password' ${file})
                else
                    protocol="vless"
                    cred=$(jq -r '.outbounds[3].uuid' ${file})
                fi
                rm ${file}
                cp /var/www/${subspath}/template.json ${file}
                if [[ "$protocol" == "trojan" ]]
                then
                    sed -i -e "s/YOUR-SERVER-IP/$serverip/g" -e "s/YOUR-DOMAIN/$domain/g" -e "s/YOUR-TROJAN-PASSWORD/$cred/g" -e "s/YOUR-TROJAN-PATH/$trojanpath/g" ${file}
                else
                    sed -i -e "s/YOUR-SERVER-IP/$serverip/g" -e "s/YOUR-DOMAIN/$domain/g" -e "s/YOUR-TROJAN-PASSWORD/$cred/g" -e "s/YOUR-TROJAN-PATH/$vlesspath/g" -e 's/: "trojan"/: "vless"/g' -e 's/"password": /"uuid": /g' ${file}
                fi
                cred=""
            done

            echo "Synchronization of the rules is completed"
            echo ""
            echo ""
            ;;
            5)
            if [ ! -f /var/www/${subspath}/template-loc.json ]
            then
                cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
            fi

            echo -e "${textcolor}ATTENTION!${clear}"
            echo -e "You can manually edit the routing rules in ${textcolor}/var/www/${subspath}/template-loc.json${clear} template"
            echo "The rules in this file will be applied to all client configs"
            echo ""
            echo -e "Press ${textcolor}Enter${clear} to synchronize the rules or enter ${textcolor}stop${clear} to exit:"
            read sync

            if [[ "$sync" == "stop" ]]
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
                echo -e "${red}Error: /var/www/${subspath}/template-loc.json contains mistakes, corrections needed${clear}"
                echo ""
                echo -e "Press ${textcolor}Enter${clear} to exit or enter ${textcolor}reset${clear} to reset the template to default version"
                read resettemp
                if [[ "$resettemp" == "reset" ]]
                then
                    rm /var/www/${subspath}/template-loc.json
                    cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
                    echo ""
                    echo "The template was reset to default version"
                    echo ""
                fi
                echo ""
                continue
            fi

            for file in /var/www/${subspath}/*-WS.json
            do
                if grep -q "trojan" "$file"
                then
                    protocol="trojan"
                    cred=$(jq -r '.outbounds[3].password' ${file})
                else
                    protocol="vless"
                    cred=$(jq -r '.outbounds[3].uuid' ${file})
                fi
                rm ${file}
                cp /var/www/${subspath}/template-loc.json ${file}
                if [[ "$protocol" == "trojan" ]]
                then
                    sed -i -e "s/YOUR-SERVER-IP/$serverip/g" -e "s/YOUR-DOMAIN/$domain/g" -e "s/YOUR-TROJAN-PASSWORD/$cred/g" -e "s/YOUR-TROJAN-PATH/$trojanpath/g" ${file}
                else
                    sed -i -e "s/YOUR-SERVER-IP/$serverip/g" -e "s/YOUR-DOMAIN/$domain/g" -e "s/YOUR-TROJAN-PASSWORD/$cred/g" -e "s/YOUR-TROJAN-PATH/$vlesspath/g" -e 's/: "trojan"/: "vless"/g' -e 's/"password": /"uuid": /g' ${file}
                fi
                cred=""
            done

            echo "Synchronization of the rules is completed"
            echo ""
            echo ""
            ;;
            *)
            exit 0
        esac
    fi
done
