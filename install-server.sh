#!/bin/bash

textcolor='\033[0;36m'
textcolor_light='\033[1;36m'
red='\033[1;31m'
clear='\033[0m'

check_os() {
    if ! grep -q "bullseye" /etc/os-release && ! grep -q "bookworm" /etc/os-release && ! grep -q "jammy" /etc/os-release && ! grep -q "noble" /etc/os-release
    then
        echo ""
        echo -e "${red}Error: only Debian 11/12 and Ubuntu 22.04/24.04 are supported${clear}"
        echo ""
        exit 1
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]
    then
        echo ""
        echo -e "${red}Error: this script should be run as root${clear}"
        echo ""
        exit 1
    fi
}

check_sbmanager() {
    if [ -f /usr/local/bin/sbmanager ]
    then
        echo ""
        echo -e "${red}Error: the script has already been run, no need to run it again${clear}"
        echo ""
        exit 1
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

banner() {
    echo ""
    echo ""
    echo "╔══╗ ╔═══ ╔══╗ ╦══╗ ╔═══ ══╦══"
    echo "║    ║    ║    ║  ║ ║      ║  "
    echo "╚══╗ ╠═══ ║    ╠╦═╝ ╠═══   ║  "
    echo "   ║ ║    ║    ║╚╗  ║      ║  "
    echo "╚══╝ ╚═══ ╚══╝ ╩ ╚═ ╚═══   ╩  "
    echo ""
    echo "╔══╗ ╦ ╦╗  ╦ ╔══╗    ╦══╗ ╔══╗ ═╗  ╔"
    echo "║    ║ ║╚╗ ║ ║       ║  ║ ║  ║  ╚╗╔╝"
    echo "╚══╗ ║ ║ ║ ║ ║ ═╗ ══ ╠══╣ ║  ║  ╔╬╝ "
    echo "   ║ ║ ║ ╚╗║ ║  ║    ║  ║ ║  ║ ╔╝╚╗ "
    echo "╚══╝ ╩ ╩  ╚╩ ╚══╝    ╩══╝ ╚══╝ ╝  ╚═"
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

start_message_ru() {
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo "Запускайте скрипт на чистой системе"
    echo "Перед запуском скрипта рекомендуется выполнить следующие действия:"
    echo -e "1) Обновить систему командой ${textcolor}apt update && apt full-upgrade -y${clear}"
    echo -e "2) Перезагрузить сервер командой ${textcolor}reboot${clear}"
    echo -e "3) При наличии своего сайта отправить папку с его файлами в ${textcolor}/root${clear} директорию сервера"
    echo ""
    echo -e "Если это сделано, то нажмите ${textcolor}Enter${clear}, чтобы продолжить"
    echo -e "В противном случае нажмите ${textcolor}Ctrl + C${clear} для завершения работы скрипта"
    echo ""
    read BigRedButton
}

start_message_en() {
    echo -e "${red}ATTENTION!${clear}"
    echo "Run the script on a newly installed system"
    echo "Before running the script, it's recommended to do the following:"
    echo -e "1) Update the system (${textcolor}apt update && apt full-upgrade -y${clear})"
    echo -e "2) Reboot the server (${textcolor}reboot${clear})"
    echo -e "3) If you have your own website then send the folder with its contents to the ${textcolor}/root${clear} directory of the server"
    echo ""
    echo -e "If it's done then press ${textcolor}Enter${clear} to continue"
    echo -e "If not then press ${textcolor}Ctrl + C${clear} to exit the script"
    echo ""
    read BigRedButton
}

start_message() {
    if [[ "${language}" == "1" ]]
    then
        start_message_ru
    else
        start_message_en
    fi
}

select_variant_ru() {
    echo "Выберите вариант настройки прокси:"
    echo "1 - Терминирование TLS на NGINX, протоколы Trojan и VLESS, транспорт WebSocket"
    echo "2 - Терминирование TLS на HAProxy, протокол Trojan, выбор бэкенда Sing-Box или NGINX по паролю Trojan"
    read variant
    echo ""
}

select_variant_en() {
    echo "Select a proxy setup option:"
    echo "1 - TLS termination on NGINX, Trojan and VLESS protocols, WebSocket transport"
    echo "2 - TLS termination on HAProxy, Trojan protocol, Sing-Box or NGINX backend selection based on Trojan passwords"
    read variant
    echo ""
}

select_variant() {
    if [[ "${language}" == "1" ]]
    then
        select_variant_ru
    else
        select_variant_en
    fi
}

crop_domain() {
    if [[ "$domain" == "www."* ]]
    then
        domain=${domain#"www."}
    fi
}

crop_redirect_domain() {
    if [[ "$redirect" == "www."* ]]
    then
        redirect=${redirect#"www."}
    fi
}

crop_trojan_path() {
    if [[ "$trojanpath" == "/"* ]]
    then
        trojanpath=${trojanpath#"/"}
    fi
}

crop_vless_path() {
    if [[ "$vlesspath" == "/"* ]]
    then
        vlesspath=${vlesspath#"/"}
    fi
}

crop_subscription_path() {
    if [[ "$subspath" == "/"* ]]
    then
        subspath=${subspath#"/"}
    fi
}

check_ssh_port_ru() {
    while [[ ! $sshp =~ ^[0-9]+$ ]] || [ $sshp -eq 80 ] || [ $sshp -eq 443 ] || [ $sshp -eq 10443 ] || [ $sshp -eq 11443 ] || [ $sshp -eq 40000 ] || [ $sshp -gt 65535 ]
    do
        if [[ ! $sshp =~ ^[0-9]+$ ]]
        then
            echo -e "${red}Ошибка: введённое значение не является числом${clear}"
        elif [ $sshp -eq 80 ] || [ $sshp -eq 443 ] || [ $sshp -eq 10443 ] || [ $sshp -eq 11443 ] || [ $sshp -eq 40000 ]
        then
            echo -e "${red}Ошибка: порты 80, 443, 10443, 11443 и 40000 будут заняты${clear}"
        elif [ $sshp -gt 65535 ]
        then
            echo -e "${red}Ошибка: номер порта не может быть больше 65535${clear}"
        fi
        echo ""
        echo "Введите новый номер порта SSH или 22 (не рекомендуется):"
        read sshp
        echo ""
    done
}

check_ssh_port_en() {
    while [[ ! $sshp =~ ^[0-9]+$ ]] || [ $sshp -eq 80 ] || [ $sshp -eq 443 ] || [ $sshp -eq 10443 ] || [ $sshp -eq 11443 ] || [ $sshp -eq 40000 ] || [ $sshp -gt 65535 ]
    do
        if [[ ! $sshp =~ ^[0-9]+$ ]]
        then
            echo -e "${red}Error: this is not a number${clear}"
        elif [ $sshp -eq 80 ] || [ $sshp -eq 443 ] || [ $sshp -eq 10443 ] || [ $sshp -eq 11443 ] || [ $sshp -eq 40000 ]
        then
            echo -e "${red}Error: ports 80, 443, 10443, 11443 and 40000 will be taken${clear}"
        elif [ $sshp -gt 65535 ]
        then
            echo -e "${red}Error: port number can't be greater than 65535${clear}"
        fi
        echo ""
        echo "Enter new SSH port number or 22 (not recommended):"
        read sshp
        echo ""
    done
}

check_username_ru() {
    while [[ $username =~ " " ]] || [[ $username =~ '$' ]] || [[ -z $username ]]
    do
        if [[ $username =~ " " ]] || [[ $username =~ '$' ]]
        then
            echo -e "${red}Ошибка: имя пользователя не должно содержать пробелы и \$${clear}"
            echo ""
        elif [[ -z $username ]]
        then
            :
        fi
        echo "Введите имя нового пользователя или root (не рекомендуется):"
        read username
        echo ""
    done
}

check_username_en() {
    while [[ $username =~ " " ]] || [[ $username =~ '$' ]] || [[ -z $username ]]
    do
        if [[ $username =~ " " ]] || [[ $username =~ '$' ]]
        then
            echo -e "${red}Error: username should not contain spaces and \$${clear}"
            echo ""
        elif [[ -z $username ]]
        then
            :
        fi
        echo "Enter your username or root (not recommended):"
        read username
        echo ""
    done
}

check_password_ru() {
    while [[ $password =~ " " ]] || [[ -z $password ]]
    do
        if [[ $password =~ " " ]]
        then
            echo -e "${red}Ошибка: пароль не должен содержать пробелы${clear}"
            echo ""
        elif [[ -z $password ]]
        then
            :
        fi
        echo "Введите пароль SSH для пользователя:"
        read password
        echo ""
    done
}

check_password_en() {
    while [[ $password =~ " " ]] || [[ -z $password ]]
    do
        if [[ $password =~ " " ]]
        then
            echo -e "${red}Error: password should not contain spaces${clear}"
            echo ""
        elif [[ -z $password ]]
        then
            :
        fi
        echo "Enter new SSH password:"
        read password
        echo ""
    done
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

check_cf_token_ru() {
    echo "Проверка домена, API токена/ключа и почты..."
    get_test_response

    while [[ -z $(echo $test_response | grep "\"${testdomain}\"") ]] || [[ -z $(echo $test_response | grep "\"#dns_records:edit\"") ]] || [[ -z $(echo $test_response | grep "\"#dns_records:read\"") ]] || [[ -z $(echo $test_response | grep "\"#zone:read\"") ]]
    do
        domain=""
        email=""
        cftoken=""
        echo ""
        echo -e "${red}Ошибка: неправильно введён домен, API токен/ключ или почта${clear}"
        echo ""
        while [[ -z $domain ]]
        do
            echo "Введите ваш домен:"
            read domain
            echo ""
        done
        crop_domain
        while [[ -z $email ]]
        do
            echo "Введите вашу почту, зарегистрированную на Cloudflare:"
            read email
            echo ""
        done
        while [[ -z $cftoken ]]
        do
            echo "Введите ваш API токен Cloudflare (Edit zone DNS) или Cloudflare global API key:"
            read cftoken
            echo ""
        done
        echo "Проверка домена, API токена/ключа и почты..."
        get_test_response
    done

    echo "Успешно!"
    echo ""
}

check_cf_token_en() {
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
            echo "Enter your domain name:"
            read domain
            echo ""
        done
        crop_domain
        while [[ -z $email ]]
        do
            echo "Enter your email registered on Cloudflare:"
            read email
            echo ""
        done
        while [[ -z $cftoken ]]
        do
            echo "Enter your Cloudflare API token (Edit zone DNS) or Cloudflare global API key:"
            read cftoken
            echo ""
        done
        echo "Checking domain name, API token/key and email..."
        get_test_response
    done

    echo "Success!"
    echo ""
}

check_uuid_ru() {
    while [[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]] && [ ! -z "$uuid" ]
    do
        echo -e "${red}Ошибка: введённое значение не является UUID${clear}"
        echo ""
        echo "Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
        read uuid
        [[ ! -z $uuid ]] && echo ""
    done
}

check_uuid_en() {
    while [[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]] && [ ! -z "$uuid" ]
    do
        echo -e "${red}Error: this is not an UUID${clear}"
        echo ""
        echo "Enter your UUID for VLESS or leave this empty to generate a random UUID:"
        read uuid
        [[ ! -z $uuid ]] && echo ""
    done
}

check_vless_path_ru() {
    while [ "$trojanpath" = "$vlesspath" ] && [ ! -z "$vlesspath" ]
    do
        echo -e "${red}Ошибка: пути для Trojan и VLESS не должны совпадать${clear}"
        echo ""
        echo "Введите путь для VLESS или оставьте пустым для генерации случайного пути:"
        read vlesspath
        [[ ! -z $vlesspath ]] && echo ""
        crop_vless_path
    done
}

check_vless_path_en() {
    while [ "$trojanpath" = "$vlesspath" ] && [ ! -z "$vlesspath" ]
    do
        echo -e "${red}Error: paths for Trojan and VLESS must be different${clear}"
        echo ""
        echo "Enter your path for VLESS or leave this empty to generate a random path:"
        read vlesspath
        [[ ! -z $vlesspath ]] && echo ""
        crop_vless_path
    done
}

check_subscription_path_ru() {
    while ([ "$trojanpath" = "$subspath" ] || [ "$vlesspath" = "$subspath" ]) && [ ! -z "$subspath" ]
    do
        echo -e "${red}Ошибка: пути для Trojan, VLESS и подписки должны быть разными${clear}"
        echo ""
        echo "Введите путь для подписки или оставьте пустым для генерации случайного пути:"
        read subspath
        [[ ! -z $subspath ]] && echo ""
        crop_subscription_path
    done
}

check_subscription_path_en() {
    while ([ "$trojanpath" = "$subspath" ] || [ "$vlesspath" = "$subspath" ]) && [ ! -z "$subspath" ]
    do
        echo -e "${red}Error: paths for Trojan, VLESS and subscription must be different${clear}"
        echo ""
        echo "Enter your subscription path or leave this empty to generate a random path:"
        read subspath
        [[ ! -z $subspath ]] && echo ""
        crop_subscription_path
    done
}

check_sitedir_ru() {
    while [ ! -d /root/${sitedir} ] || [ -z "$sitedir" ]
    do
        echo -e "${red}Ошибка: папка c введённым названием не существует в /root${clear}"
        echo ""
        echo "Введите название папки с файлами вашего сайта, загруженной в /root:"
        read sitedir
        echo ""
    done
}

check_sitedir_en() {
    while [ ! -d /root/${sitedir} ] || [ -z "$sitedir" ]
    do
        echo -e "${red}Error: this folder doesn't exist in the /root directory${clear}"
        echo ""
        echo "Enter the name of the folder with your website contents uploaded to /root:"
        read sitedir
        echo ""
    done
}

check_index_ru() {
    while [ ! -f /root/${sitedir}/${index} ] || [ -z "$index" ]
    do
        echo -e "${red}Ошибка: файл c введённым названием не существует в /root/${sitedir}${clear}"
        echo ""
        echo "Введите название index файла вашего сайта:"
        read index
        echo ""
    done
}

check_index_en() {
    while [ ! -f /root/${sitedir}/${index} ] || [ -z "$index" ]
    do
        echo -e "${red}Error: this file doesn't exist in the /root/${sitedir} directory${clear}"
        echo ""
        echo "Enter the name of the index file of your website:"
        read index
        echo ""
    done
}

check_timezone_ru() {
    while [ ! -f /usr/share/zoneinfo/${timezone} ]
    do
        echo -e "${red}Ошибка: введённого часового пояса не существует в /usr/share/zoneinfo, проверьте правильность написания${clear}"
        echo ""
        echo "Введите часовой пояс для установки времени на сервере (например, Europe/Amsterdam):"
        read timezone
        echo ""
    done
}

check_timezone_en() {
    while [ ! -f /usr/share/zoneinfo/${timezone} ]
    do
        echo -e "${red}Error: this timezone doesn't exist in /usr/share/zoneinfo, check your spelling${clear}"
        echo ""
        echo "Enter the timezone to set the time on the server (e.g. Europe/Amsterdam):"
        read timezone
        echo ""
    done
}

nginx_login() {
    comment1="#"
    comment2=" "
    comment3=" "
    redirect="${domain}"
    sitedir="html"
    index="index.html index.htm"
}

nginx_redirect() {
    comment1=" "
    comment2="#"
    comment3=" "
    sitedir="html"
    index="index.html index.htm"
    while [[ -z $redirect ]]
    do
        if [[ "${language}" == "1" ]]
        then
            echo "Введите домен, на который будет идти перенаправление:"
        else
            echo "Enter the domain to which requests will be redirected:"
        fi
        read redirect
        echo ""
    done
    crop_redirect_domain
}

nginx_site_ru() {
    comment1=" "
    comment2=" "
    comment3="#"
    redirect="${domain}"
    echo "Введите название папки с файлами вашего сайта, загруженной в /root:"
    read sitedir
    echo ""
    check_sitedir_ru
    echo "Введите название index файла вашего сайта:"
    read index
    echo ""
    check_index_ru
}

nginx_site_en() {
    comment1=" "
    comment2=" "
    comment3="#"
    redirect="${domain}"
    echo "Enter the name of the folder with your website contents uploaded to /root:"
    read sitedir
    echo ""
    check_sitedir_en
    echo "Enter the name of the index file of your website:"
    read index
    echo ""
    check_index_en
}

nginx_site() {
    if [[ "${language}" == "1" ]]
    then
        nginx_site_ru
    else
        nginx_site_en
    fi
}

nginx_options() {
    case $option in
        2)
        nginx_redirect
        ;;
        3)
        nginx_site
        ;;
        *)
        nginx_login
    esac
}

enter_data_ru_ws() {
    echo "Введите новый номер порта SSH или 22 (не рекомендуется):"
    read sshp
    echo ""
    check_ssh_port_ru
    echo "Введите имя нового пользователя или root (не рекомендуется):"
    read username
    echo ""
    check_username_ru
    echo "Введите пароль SSH для пользователя:"
    read password
    echo ""
    check_password_ru
    while [[ -z $domain ]]
    do
        echo "Введите ваш домен:"
        read domain
        echo ""
    done
    crop_domain
    while [[ -z $email ]]
    do
        echo "Введите вашу почту, зарегистрированную на Cloudflare:"
        read email
        echo ""
    done
    while [[ -z $cftoken ]]
    do
        echo "Введите ваш API токен Cloudflare (Edit zone DNS) или Cloudflare global API key:"
        read cftoken
        echo ""
    done
    check_cf_token_ru
    echo "Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
    read trjpass
    [[ ! -z $trjpass ]] && echo ""
    echo "Введите путь для Trojan или оставьте пустым для генерации случайного пути:"
    read trojanpath
    [[ ! -z $trojanpath ]] && echo ""
    crop_trojan_path
    echo "Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
    read uuid
    [[ ! -z $uuid ]] && echo ""
    check_uuid_ru
    echo "Введите путь для VLESS или оставьте пустым для генерации случайного пути:"
    read vlesspath
    [[ ! -z $vlesspath ]] && echo ""
    crop_vless_path
    check_vless_path_ru
    echo "Введите путь для подписки или оставьте пустым для генерации случайного пути:"
    read subspath
    [[ ! -z $subspath ]] && echo ""
    crop_subscription_path
    check_subscription_path_ru
    echo "Выберите вариант настройки NGINX (1 по умолчанию):"
    echo "1 - Будет спрашивать логин и пароль вместо сайта"
    echo "2 - Будет перенаправлять на другой домен"
    echo "3 - Свой сайт (при наличии)"
    read option;
    echo ""
    nginx_options
    echo "Введите часовой пояс для установки времени на сервере (например, Europe/Amsterdam):"
    read timezone
    echo ""
    check_timezone_ru
}

enter_data_en_ws() {
    echo "Enter new SSH port number or 22 (not recommended):"
    read sshp
    echo ""
    check_ssh_port_en
    echo "Enter your username or root (not recommended):"
    read username
    echo ""
    check_username_en
    echo "Enter new SSH password:"
    read password
    echo ""
    check_password_en
    while [[ -z $domain ]]
    do
        echo "Enter your domain name:"
        read domain
        echo ""
    done
    crop_domain
    while [[ -z $email ]]
    do
        echo "Enter your email registered on Cloudflare:"
        read email
        echo ""
    done
    while [[ -z $cftoken ]]
    do
        echo "Enter your Cloudflare API token (Edit zone DNS) or Cloudflare global API key:"
        read cftoken
        echo ""
    done
    check_cf_token_en
    echo "Enter your password for Trojan or leave this empty to generate a random password:"
    read trjpass
    [[ ! -z $trjpass ]] && echo ""
    echo "Enter your path for Trojan or leave this empty to generate a random path:"
    read trojanpath
    [[ ! -z $trojanpath ]] && echo ""
    crop_trojan_path
    echo "Enter your UUID for VLESS or leave this empty to generate a random UUID:"
    read uuid
    [[ ! -z $uuid ]] && echo ""
    check_uuid_en
    echo "Enter your path for VLESS or leave this empty to generate a random path:"
    read vlesspath
    [[ ! -z $vlesspath ]] && echo ""
    crop_vless_path
    check_vless_path_en
    echo "Enter your subscription path or leave this empty to generate a random path:"
    read subspath
    [[ ! -z $subspath ]] && echo ""
    crop_subscription_path
    check_subscription_path_en
    echo "Select NGINX setup option (1 by default):"
    echo "1 - Will show a login popup asking for username and password"
    echo "2 - Will redirect to another domain"
    echo "3 - Your own website (if you have one)"
    read option;
    echo ""
    nginx_options
    echo "Enter the timezone to set the time on the server (e.g. Europe/Amsterdam):"
    read timezone
    echo ""
    check_timezone_en
}

enter_data_ru_haproxy() {
    echo "Введите новый номер порта SSH или 22 (не рекомендуется):"
    read sshp
    echo ""
    check_ssh_port_ru
    echo "Введите имя нового пользователя или root (не рекомендуется):"
    read username
    echo ""
    check_username_ru
    echo "Введите пароль SSH для пользователя:"
    read password
    echo ""
    check_password_ru
    while [[ -z $domain ]]
    do
        echo "Введите ваш домен:"
        read domain
        echo ""
    done
    crop_domain
    while [[ -z $email ]]
    do
        echo "Введите вашу почту, зарегистрированную на Cloudflare:"
        read email
        echo ""
    done
    while [[ -z $cftoken ]]
    do
        echo "Введите ваш API токен Cloudflare (Edit zone DNS) или Cloudflare global API key:"
        read cftoken
        echo ""
    done
    check_cf_token_ru
    echo "Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
    read trjpass
    [[ ! -z $trjpass ]] && echo ""
    echo "Введите путь для подписки или оставьте пустым для генерации случайного пути:"
    read subspath
    [[ ! -z $subspath ]] && echo ""
    crop_subscription_path
    echo "Выберите вариант настройки NGINX (1 по умолчанию):"
    echo "1 - Будет спрашивать логин и пароль вместо сайта"
    echo "2 - Будет перенаправлять на другой домен"
    echo "3 - Свой сайт (при наличии)"
    read option;
    echo ""
    nginx_options
    echo "Введите часовой пояс для установки времени на сервере (например, Europe/Amsterdam):"
    read timezone
    echo ""
    check_timezone_ru
}

enter_data_en_haproxy() {
    echo "Enter new SSH port number or 22 (not recommended):"
    read sshp
    echo ""
    check_ssh_port_en
    echo "Enter your username or root (not recommended):"
    read username
    echo ""
    check_username_en
    echo "Enter new SSH password:"
    read password
    echo ""
    check_password_en
    while [[ -z $domain ]]
    do
        echo "Enter your domain name:"
        read domain
        echo ""
    done
    crop_domain
    while [[ -z $email ]]
    do
        echo "Enter your email registered on Cloudflare:"
        read email
        echo ""
    done
    while [[ -z $cftoken ]]
    do
        echo "Enter your Cloudflare API token (Edit zone DNS) or Cloudflare global API key:"
        read cftoken
        echo ""
    done
    check_cf_token_en
    echo "Enter your password for Trojan or leave this empty to generate a random password:"
    read trjpass
    [[ ! -z $trjpass ]] && echo ""
    echo "Enter your subscription path or leave this empty to generate a random path:"
    read subspath
    [[ ! -z $subspath ]] && echo ""
    crop_subscription_path
    echo "Select NGINX setup option (1 by default):"
    echo "1 - Will show a login popup asking for username and password"
    echo "2 - Will redirect to another domain"
    echo "3 - Your own website (if you have one)"
    read option;
    echo ""
    nginx_options
    echo "Enter the timezone to set the time on the server (e.g. Europe/Amsterdam):"
    read timezone
    echo ""
    check_timezone_en
}

enter_data() {
    if [[ "${language}" == "1" ]] && [[ "${variant}" == "1" ]]
    then
        enter_data_ru_ws
    elif [[ "${language}" == "1" ]] && [[ "${variant}" != "1" ]]
    then
        enter_data_ru_haproxy
    elif [[ "${language}" != "1" ]] && [[ "${variant}" == "1" ]]
    then
        enter_data_en_ws
    elif [[ "${language}" != "1" ]] && [[ "${variant}" != "1" ]]
    then
        enter_data_en_haproxy
    fi
    echo ""
    echo ""
}

set_timezone() {
    echo -e "${textcolor_light}Setting up timezone...${clear}"
    timedatectl set-timezone ${timezone}
    date
    echo ""
}

enable_bbr() {
    echo -e "${textcolor_light}Setting up BBR...${clear}"
    if [[ ! "$(sysctl net.core.default_qdisc)" == *"= fq" ]]
    then
        echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    fi

    if [[ ! "$(sysctl net.ipv4.tcp_congestion_control)" == *"bbr" ]]
    then
        echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    fi

    sysctl -p
    echo ""
}

install_packages() {
    echo -e "${textcolor_light}Installing packages...${clear}"
    apt install sudo ufw certbot python3-certbot-dns-cloudflare gnupg2 nginx-full unattended-upgrades openssl sed jq net-tools htop -y

    if [ ! -d /usr/share/keyrings ]
    then
        mkdir /usr/share/keyrings
    fi

    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(grep "VERSION_CODENAME=" /etc/os-release | cut -d "=" -f 2) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
    apt-get update && apt-get install cloudflare-warp -y

    if [ ! -d /etc/apt/keyrings ]
    then
        mkdir /etc/apt/keyrings
    fi

    curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
    chmod a+r /etc/apt/keyrings/sagernet.asc
    echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | tee /etc/apt/sources.list.d/sagernet.list > /dev/null
    apt-get update
    apt-get install sing-box -y

    if [[ "${variant}" != "1" ]]
    then
        apt install haproxy -y
    fi

    echo ""
}

create_user() {
    if [[ "$username" != "root" ]]
    then
        echo -e "${textcolor_light}Creating user ${username}...${clear}"
        useradd -m -s $(which bash) -G sudo ${username}
    fi
    echo "${username}:${password}" | chpasswd
    echo ""
}

setup_ssh() {
    if [[ "$username" != "root" ]] || [ $sshp -ne 22 ]
    then
        echo -e "${textcolor_light}Changing SSH settings...${clear}"
    fi

    if [[ "$username" == "root" ]]
    then
        sed -i -e "s/#Port/Port/g" -e "s/Port 22/Port ${sshp}/g" -e "s/#PasswordAuthentication /PasswordAuthentication /g" /etc/ssh/sshd_config
        if [ ! -d /root/.ssh ]
        then
            mkdir /root/.ssh
        fi
    else
        sed -i -e "s/#Port/Port/g" -e "s/Port 22/Port ${sshp}/g" -e "s/#PermitRootLogin/PermitRootLogin/g" -e "s/PermitRootLogin yes/PermitRootLogin no/g" -e "s/#PasswordAuthentication /PasswordAuthentication /g" /etc/ssh/sshd_config
        mkdir /home/${username}/.ssh
        chown ${username}:sudo /home/${username}/.ssh
        chmod 700 /home/${username}/.ssh
    fi

    if grep -q "noble" /etc/os-release
    then
        sed -i "s/22/${sshp}/g" /lib/systemd/system/ssh.socket
        systemctl daemon-reload
        systemctl restart ssh.socket
    fi

    systemctl restart ssh.service
    echo ""
}

setup_ufw() {
    echo -e "${textcolor_light}Setting up UFW...${clear}"
    ufw allow ${sshp}/tcp
    ufw allow 443/tcp
    ufw allow 80/tcp
    # Protection from Reality certificate stealing:
    ufw insert 1 deny from ${serverip}/22 &> /dev/null
    echo ""
    yes | ufw enable
    echo ""
    ufw status
}

unattended_upgrades() {
    echo -e "${textcolor_light}Setting up unattended upgrades...${clear}"
    echo 'Unattended-Upgrade::Mail "root";' >> /etc/apt/apt.conf.d/50unattended-upgrades
    echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
    dpkg-reconfigure -f noninteractive unattended-upgrades
    systemctl restart unattended-upgrades
    echo ""
}

setup_security() {
    create_user
    setup_ssh
    setup_ufw
    unattended_upgrades
}

certificates() {
    echo -e "${textcolor_light}Requesting a certificate...${clear}"
    touch /etc/letsencrypt/cloudflare.credentials
    chown root:root /etc/letsencrypt/cloudflare.credentials
    chmod 600 /etc/letsencrypt/cloudflare.credentials

    if [[ "$cftoken" =~ [A-Z] ]]
    then
        echo "dns_cloudflare_api_token = ${cftoken}" >> /etc/letsencrypt/cloudflare.credentials
    else
        echo "dns_cloudflare_email = ${email}" >> /etc/letsencrypt/cloudflare.credentials
        echo "dns_cloudflare_api_key = ${cftoken}" >> /etc/letsencrypt/cloudflare.credentials
    fi

    certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 --rsa-key-size 4096 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive

    { crontab -l; echo "0 5 1 */2 * certbot -q renew"; } | crontab -

    if [[ "${variant}" == "1" ]]
    then
        echo "renew_hook = systemctl reload nginx" >> /etc/letsencrypt/renewal/${domain}.conf
        echo ""
        openssl dhparam -out /etc/nginx/dhparam.pem 2048
    else
        echo "renew_hook = cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem && systemctl restart haproxy" >> /etc/letsencrypt/renewal/${domain}.conf
        echo ""
        openssl dhparam -out /etc/haproxy/dhparam.pem 2048
    fi

    echo ""
}

setup_warp() {
    echo -e "${textcolor_light}Setting up WARP...${clear}"
    yes | warp-cli registration new
    warp-cli mode proxy
    warp-cli proxy port 40000
    warp-cli connect
    mkdir /etc/systemd/system/warp-svc.service.d
    echo "[Service]" >> /etc/systemd/system/warp-svc.service.d/override.conf
    echo "LogLevelMax=3" >> /etc/systemd/system/warp-svc.service.d/override.conf
    systemctl daemon-reload
    systemctl restart warp-svc.service
    echo ""
}

generate_pass() {
    if [ -z "$trjpass" ]
    then
        trjpass=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    fi

    if [ -z "$trojanpath" ] && [[ "${variant}" == "1" ]]
    then
        trojanpath=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    fi

    if [ -z "$uuid" ] && [[ "${variant}" == "1" ]]
    then
        uuid=$(cat /proc/sys/kernel/random/uuid)
    fi

    if [ -z "$vlesspath" ] && [[ "${variant}" == "1" ]]
    then
        vlesspath=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    fi

    if [ -z "$subspath" ]
    then
        subspath=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    fi
}

server_config() {
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
        "server": "dns-block",
        "disable_cache": true
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
      "tag": "trojan-in",
      "listen": "127.0.0.1",
      "listen_port": 10443,
      "sniff": true,
      "users": [
        {
          "name": "1-me",
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
      "tag": "vless-in",
      "listen": "127.0.0.1",
      "listen_port": 11443,
      "sniff": true,
      "users": [
        {
          "name": "1-me",
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
        "outbound": "block"
      },
      {
        "protocol": "quic",
        "outbound": "block"
      },
      {
        "rule_set": [
          "geoip-ru",
          "gov-ru",
          "openai",
          "telegram"
        ],
        "domain_suffix": [
          ".ru",
          ".su",
          ".ru.com",
          ".ru.net",
          "rutracker.org",
          "habr.com",
          "ntc.party",
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
          "proactivebackend-pa.googleapis.com",
          "canva.com"
        ],
        "domain_keyword": [
          "xn--",
          "generativelanguage",
          "generativeai"
        ],
        "outbound": "warp"
      },
      {
        "rule_set": [
          "google"
        ],
        "outbound": "IPv4"
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
        "tag": "openai",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-openai.srs"
      },
      {
        "tag": "telegram",
        "type": "remote",
        "format": "binary",
        "url": "https://github.com/SagerNet/sing-geosite/raw/rule-set/geosite-telegram.srs"
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
      "enabled": true
    }
  }
}
EOF

if [[ "${variant}" != "1" ]]
then
    inboundnumbervl=$(jq '[.inbounds[].tag] | index("vless-in")' /etc/sing-box/config.json)
    inboundnumbertr=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
    echo "$(jq "del(.inbounds[${inboundnumbertr}].transport.type) | del(.inbounds[${inboundnumbertr}].transport.path) | del(.inbounds[${inboundnumbervl}])" /etc/sing-box/config.json)" > /etc/sing-box/config.json
fi

systemctl enable sing-box.service
systemctl start sing-box.service
}

client_config() {
mkdir /var/www/${subspath}
touch /var/www/${subspath}/1-me-TRJ-CLIENT.json

cat > /var/www/${subspath}/1-me-TRJ-CLIENT.json <<EOF
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
        "server": "dns-block",
        "disable_cache": true
      },
      {
        "rule_set": [
          "openai",
          "telegram"
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
          "yandex",
          "vk",
          "mailru",
          "zoom",
          "reddit",
          "twitch",
          "tumblr",
          "4chan",
          "pinterest",
          "deviantart",
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
      "interface_name": "tun0",
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
        "255.255.255.255/32"
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
        "outbound": "direct"
      },
      {
        "rule_set": [
          "category-ads-all"
        ],
        "outbound": "block"
      },
      {
        "rule_set": [
          "openai",
          "telegram"
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
          "yandex",
          "vk",
          "mailru",
          "zoom",
          "reddit",
          "twitch",
          "tumblr",
          "4chan",
          "pinterest",
          "deviantart",
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
      "enabled": true
    }
  }
}
EOF

if [[ "${variant}" == "1" ]]
then
    cp /var/www/${subspath}/1-me-TRJ-CLIENT.json /var/www/${subspath}/1-me-VLESS-CLIENT.json
    sed -i -e "s/$trjpass/$uuid/g" -e "s/$trojanpath/$vlesspath/g" -e 's/: "trojan"/: "vless"/g' -e 's/"password": /"uuid": /g' /var/www/${subspath}/1-me-VLESS-CLIENT.json
else
    outboundnumber=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/1-me-TRJ-CLIENT.json)
    echo "$(jq "del(.outbounds[${outboundnumber}].transport.type) | del(.outbounds[${outboundnumber}].transport.path)" /var/www/${subspath}/1-me-TRJ-CLIENT.json)" > /var/www/${subspath}/1-me-TRJ-CLIENT.json
fi
}

setup_sing_box() {
    echo -e "${textcolor_light}Setting up Sing-Box...${clear}"
    generate_pass
    server_config
    client_config
    echo ""
}

for_nginx_options() {
    if [[ "$option" == "3" ]]
    then
        mv /root/${sitedir} /var/www
    fi

    if [[ "$option" != "2" ]] && [[ "$option" != "3" ]]
    then
        touch /etc/nginx/.htpasswd
    fi
}

nginx_config_1() {
append='"~^(,[ \\t]*)*([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?(;([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?)*([ \\t]*,([ \\t]*([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?(;([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?)*)?)*$" "$http_forwarded, $proxy_forwarded_elem"'

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
        ${append};

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

        # Diffie-Hellman parameter for DHE ciphersuites
        ssl_dhparam                          /etc/nginx/dhparam.pem;

        # Security headers
        add_header X-XSS-Protection          "1; mode=block" always;
        add_header X-Content-Type-Options    "nosniff" always;
        add_header Referrer-Policy           "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy   "default-src 'self' http: https: ws: wss: data: blob: 'unsafe-inline'; frame-ancestors 'self';" always;
        add_header Permissions-Policy        "interest-cohort=()" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
        add_header X-Frame-Options           "SAMEORIGIN";
        proxy_hide_header X-Powered-By;

        # Disable direct IP access
        if (\$host = ${serverip}) {
            return 444;
        }

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

        # Subsciption
        location ~ ^/${subspath} {
            default_type application/json;
            root /var/www;
        }

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

        server_name _;

        # Disable direct IP access
        if (\$host = ${serverip}) {
            return 444;
        }

        return 301  https://${domain}\$request_uri;
    }
}
EOF

systemctl enable nginx
nginx -t
systemctl reload nginx
}

nginx_config_2() {
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

    # Load configs
    include /etc/nginx/conf.d/*.conf;

    # Site
    server {
        listen                               127.0.0.1:11443 default_server;
        server_name                          _;
      ${comment1}${comment2}root                                 /var/www/${sitedir};
      ${comment1}${comment2}index                                ${index};

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

        # Subsciption
        location ~ ^/${subspath} {
            default_type application/json;
            root /var/www;
        }

        # gzip
        gzip            on;
        gzip_vary       on;
        gzip_proxied    any;
        gzip_comp_level 6;
        gzip_types      text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;
    }
}
EOF

systemctl enable nginx
nginx -t
systemctl reload nginx
}

setup_nginx() {
    echo -e "${textcolor_light}Setting up NGINX...${clear}"
    for_nginx_options
    if [[ "${variant}" == "1" ]]
    then
        nginx_config_1
    else
        nginx_config_2
    fi
    echo ""
}

auth_lua() {
passhash=$(echo -n "${trjpass}" | openssl dgst -sha224 | sed 's/.* //')
placeholder=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
placeholderhash=$(echo -n "${placeholder}" | openssl dgst -sha224 | sed 's/.* //')

cat > /etc/haproxy/auth.lua <<EOF
local passwords = {
    ["${passhash}"] = true,
    ["${placeholderhash}"] = true		-- Placeholder
}

function trojan_auth(txn)
    local status, data = pcall(function() return txn.req:dup() end)
    if status and data then
        -- Uncomment to enable logging of all received data
        -- core.Info("Received data from client: " .. data)
        local sniffed_password = string.sub(data, 1, 56)
        -- Uncomment to enable logging of sniffed password hashes
        -- core.Info("Sniffed password: " .. sniffed_password)
        if passwords[sniffed_password] then
            return "trojan"
        end
    end
    return "http"
end

core.register_fetches("trojan_auth", trojan_auth)
EOF
}

config_haproxy() {
mkdir /etc/haproxy/certs
cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem

cat > /etc/haproxy/haproxy.cfg <<EOF
global
        # Uncomment to enable system logging
        # log /dev/log local0
        # log /dev/log local1 notice
        log /dev/log local2 warning
        lua-load /etc/haproxy/auth.lua
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin
        stats timeout 30s
        user haproxy
        group haproxy
        daemon

        # Mozilla Intermediate
        # ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305
        # ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        # ssl-default-bind-options prefer-client-ciphers no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets
        # ssl-default-server-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305
        # ssl-default-server-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        # ssl-default-server-options no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets

        # Mozilla Modern
        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-bind-options prefer-client-ciphers no-sslv3 no-tlsv10 no-tlsv11 no-tlsv12 no-tls-tickets
        ssl-default-server-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-server-options no-sslv3 no-tlsv10 no-tlsv11 no-tlsv12 no-tls-tickets

        # You must first generate DH parameters - [ openssl dhparam -out /etc/haproxy/dhparam.pem 2048 ]
        ssl-dh-param-file /etc/haproxy/dhparam.pem

defaults
        mode http
        log global
        option tcplog
        option  dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000

frontend haproxy-tls
        mode tcp
        timeout client 1h
        bind :::443 v4v6 ssl crt /etc/haproxy/certs/${domain}.pem alpn h2,http/1.1
        acl host_ip hdr(host) -i ${serverip}
        tcp-request content reject if host_ip
        tcp-request inspect-delay 5s
        tcp-request content accept if { req_ssl_hello_type 1 }
        use_backend %[lua.trojan_auth]
        default_backend http

backend trojan
        mode tcp
        timeout server 1h
        server sing-box 127.0.0.1:10443

backend http
        mode http
        # Web server
        server nginx 127.0.0.1:11443

frontend haproxy-http
        bind :::80 v4v6
        mode http
        acl host_ip hdr(host) -i ${serverip}
        http-request reject if host_ip
        # For HTTPS Redirect
        default_backend https-redirect
        # For HTTP Web Server
        # default_backend http

backend https-redirect
        mode http
        http-request redirect scheme https
EOF

systemctl enable haproxy.service
haproxy -f /etc/haproxy/haproxy.cfg -c
systemctl restart haproxy.service
}

setup_haproxy() {
    if [[ "${variant}" != "1" ]]
    then
        echo -e "${textcolor_light}Setting up HAProxy...${clear}"
        auth_lua
        config_haproxy
        echo ""
    fi
}

add_sbmanager() {
    if [[ "${language}" == "1" ]]
    then
        curl -s -o /usr/local/bin/sbmanager https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/sb-manager.sh
    else
        curl -s -o /usr/local/bin/sbmanager https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/sb-manager-en.sh
    fi

    chmod +x /usr/local/bin/sbmanager

    if [[ "${variant}" != "1" ]]
    then
        curl -s -o /var/www/${subspath}/template.json https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Config-Examples-HAProxy/Client-Trojan-HAProxy.json
    else
        curl -s -o /var/www/${subspath}/template.json https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Config-Examples-WS/Client-Trojan-WS.json
    fi

    if [ $(jq -e . < /var/www/${subspath}/template.json &>/dev/null; echo $?) -eq 0 ] && [ -s /var/www/${subspath}/template.json ]
    then
        cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
    else
        cp /var/www/${subspath}/1-me-TRJ-CLIENT.json /var/www/${subspath}/template-loc.json
    fi
}

final_message_ru() {
    echo -e "${textcolor}Если выше не возникло ошибок, то настройка завершена!${clear}"
    echo ""
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo "Для повышения безопасности сервера рекомендуется выполнить следующие действия:"
    echo -e "1) Отключиться от сервера ${textcolor}Ctrl + D${clear}"
    echo -e "2) Если нет ключей SSH, то сгенерировать их на своём ПК командой ${textcolor}ssh-keygen -t rsa -b 4096${clear}"
    echo "3) Отправить публичный ключ на сервер"
    echo -e "   Команда для Linux: ${textcolor}ssh-copy-id -p ${sshp} ${username}@${serverip}${clear}"
    echo -e "   Команда для Windows: ${textcolor}type \$env:USERPROFILE\.ssh\id_rsa.pub | ssh -p ${sshp} ${username}@${serverip} \"cat >> ~/.ssh/authorized_keys\"${clear}"
    echo -e "4) Подключиться к серверу ещё раз командой ${textcolor}ssh -p ${sshp} ${username}@${serverip}${clear}"
    echo -e "5) Открыть конфиг sshd командой ${textcolor}sudo nano /etc/ssh/sshd_config${clear} и в PasswordAuthentication заменить yes на no"
    echo -e "6) Перезапустить SSH командой ${textcolor}sudo systemctl restart ssh.service${clear}"
    echo ""
    echo -e "Для начала работы прокси может потребоваться перезагрузка сервера командой ${textcolor}sudo reboot${clear}"
    echo ""
    if [[ "${variant}" == "1" ]]
    then
        echo -e "${textcolor}Конфиги для клиента доступны по ссылкам:${clear}"
        echo "https://${domain}/${subspath}/1-me-TRJ-CLIENT.json"
        echo "https://${domain}/${subspath}/1-me-VLESS-CLIENT.json"
    else
        echo -e "${textcolor}Конфиг для клиента доступен по ссылке:${clear}"
        echo "https://${domain}/${subspath}/1-me-TRJ-CLIENT.json"
        echo ""
        echo -e "${red}ВАЖНО:${clear} чтобы этот вариант настройки работал, в DNS записях Cloudflare должно стоять \"DNS only\", а не \"Proxied\""
    fi
}

final_message_en() {
    echo -e "${textcolor}If there are no errors above then the setup is complete!${clear}"
    echo ""
    echo -e "${red}ATTENTION!${clear}"
    echo "To increase the security of the server it's recommended to do the following:"
    echo -e "1) Disconnect from the server by pressing ${textcolor}Ctrl + D${clear}"
    echo -e "2) If you don't have SSH keys then generate them on your PC (${textcolor}ssh-keygen -t rsa -b 4096${clear})"
    echo "3) Send the public key to the server"
    echo -e "   Command for Linux: ${textcolor}ssh-copy-id -p ${sshp} ${username}@${serverip}${clear}"
    echo -e "   Command for Windows: ${textcolor}type \$env:USERPROFILE\.ssh\id_rsa.pub | ssh -p ${sshp} ${username}@${serverip} \"cat >> ~/.ssh/authorized_keys\"${clear}"
    echo -e "4) Connect to the server again (${textcolor}ssh -p ${sshp} ${username}@${serverip}${clear})"
    echo -e "5) Open sshd config (${textcolor}sudo nano /etc/ssh/sshd_config${clear}) and change PasswordAuthentication value from yes to no"
    echo -e "6) Restart SSH (${textcolor}sudo systemctl restart ssh.service${clear})"
    echo ""
    echo -e "It might be required to reboot the server for the proxy to start working (${textcolor}sudo reboot${clear})"
    echo ""
    if [[ "${variant}" == "1" ]]
    then
        echo -e "${textcolor}Client configs are available here:${clear}"
        echo "https://${domain}/${subspath}/1-me-TRJ-CLIENT.json"
        echo "https://${domain}/${subspath}/1-me-VLESS-CLIENT.json"
    else
        echo -e "${textcolor}Client config is available here:${clear}"
        echo "https://${domain}/${subspath}/1-me-TRJ-CLIENT.json"
        echo ""
        echo -e "${red}IMPORTANT:${clear} for this setup method to work, your DNS records in Cloudflare must be set to \"DNS only\", not \"Proxied\""
    fi
}

final_message() {
    echo ""
    echo ""
    if [[ "${language}" == "1" ]]
    then
        final_message_ru
    else
        final_message_en
    fi
    echo ""
    echo ""
}

check_os
check_root
check_sbmanager
get_ip
banner
enter_language
start_message
select_variant
enter_data
set_timezone
enable_bbr
install_packages
setup_security
certificates
setup_warp
setup_sing_box
setup_nginx
setup_haproxy
add_sbmanager
final_message
