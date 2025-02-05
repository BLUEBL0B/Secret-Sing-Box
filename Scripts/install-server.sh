#!/bin/bash

textcolor='\033[1;34m'
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
        echo -e "${red}Error: this script should be run as root, use \"sudo -i\" command${clear}"
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

check_if_updated() {
    if [[ "${language}" == "1" ]]
    then
        echo ""
        echo -e "${textcolor}[?]${clear} Вы точно обновили систему и перезагрузили сервер перед запуском скрипта?"
        echo "1 - Обновить и перезагрузить"
        echo "2 - Продолжить (система была обновлена и перезагружена)"
        read systemupdated
    else
        echo ""
        echo -e "${textcolor}[?]${clear} Are you sure you have updated the system and rebooted the server before running the script?"
        echo "1 - Update and reboot"
        echo "2 - Continue (the system has been updated and rebooted)"
        read systemupdated
    fi

    if [[ "${systemupdated}" == "1" ]]
    then
        echo ""
        apt update && apt full-upgrade -y
        sleep 1.5
        echo ""
        reboot
        exit 0
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

crop_redirect_domain() {
    if [[ "$redirect" == "https://"* ]]
    then
        redirect=${redirect#"https://"}
    fi

    if [[ "$redirect" == "http://"* ]]
    then
        redirect=${redirect#"http://"}
    fi

    if [[ "$redirect" == "www."* ]]
    then
        redirect=${redirect#"www."}
    fi

    if [[ "$redirect" =~ "/" ]]
    then
        redirect=$(echo "${redirect}" | cut -d "/" -f 1)
    fi
}

crop_site_link() {
    if [[ "$sitelink" == "https://"* ]]
    then
        sitelink=${sitelink#"https://"}
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

crop_rulesetpath() {
    if [[ "$rulesetpath" == "/"* ]]
    then
        rulesetpath=${rulesetpath#"/"}
    fi
}

edit_index() {
    if [[ "$index" != "/"* ]]
    then
        index="/${index}"
    fi

    if [[ "$index" == *"/" ]]
    then
        index=${index%"/"}
    fi
}

check_ssh_port_ru() {
    while [[ ! $sshp =~ ^[0-9]+$ ]] || [ $sshp -eq 443 ] || [ $sshp -eq 10443 ] || [ $sshp -eq 11443 ] || [ $sshp -eq 40000 ] || [ $sshp -gt 65535 ]
    do
        if [[ ! $sshp =~ ^[0-9]+$ ]]
        then
            echo -e "${red}Ошибка: введённое значение не является числом${clear}"
        elif [ $sshp -eq 443 ] || [ $sshp -eq 10443 ] || [ $sshp -eq 11443 ] || [ $sshp -eq 40000 ]
        then
            echo -e "${red}Ошибка: порты 443, 10443, 11443 и 40000 будут заняты${clear}"
        elif [ $sshp -gt 65535 ]
        then
            echo -e "${red}Ошибка: номер порта не может быть больше 65535${clear}"
        fi
        echo ""
        echo -e "${textcolor}[?]${clear} Введите новый номер порта SSH или 22 (рекомендуется номер более 1024):"
        read sshp
        echo ""
    done
}

check_ssh_port_en() {
    while [[ ! $sshp =~ ^[0-9]+$ ]] || [ $sshp -eq 443 ] || [ $sshp -eq 10443 ] || [ $sshp -eq 11443 ] || [ $sshp -eq 40000 ] || [ $sshp -gt 65535 ]
    do
        if [[ ! $sshp =~ ^[0-9]+$ ]]
        then
            echo -e "${red}Error: this is not a number${clear}"
        elif [ $sshp -eq 443 ] || [ $sshp -eq 10443 ] || [ $sshp -eq 11443 ] || [ $sshp -eq 40000 ]
        then
            echo -e "${red}Error: ports 443, 10443, 11443 and 40000 will be taken${clear}"
        elif [ $sshp -gt 65535 ]
        then
            echo -e "${red}Error: port number can't be greater than 65535${clear}"
        fi
        echo ""
        echo -e "${textcolor}[?]${clear} Enter new SSH port number or 22 (number above 1024 is recommended):"
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
        echo -e "${textcolor}[?]${clear} Введите имя нового пользователя или root (рекомендуется не root):"
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
        echo -e "${textcolor}[?]${clear} Enter your username or root (non-root user is recommended):"
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
        echo -e "${textcolor}[?]${clear} Введите пароль SSH для пользователя (рекомендуется сложный пароль):"
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
        echo -e "${textcolor}[?]${clear} Enter new SSH password (a complex password is recommended):"
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
            echo -e "${textcolor}[?]${clear} Введите ваш домен:"
            read domain
            echo ""
        done
        crop_domain
        while [[ -z $email ]]
        do
            echo -e "${textcolor}[?]${clear} Введите вашу почту, зарегистрированную на Cloudflare:"
            read email
            echo ""
        done
        while [[ -z $cftoken ]]
        do
            echo -e "${textcolor}[?]${clear} Введите ваш API токен Cloudflare (Edit zone DNS) или Cloudflare global API key:"
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
            echo -e "${textcolor}[?]${clear} Enter your domain name:"
            read domain
            echo ""
        done
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

check_uuid_ru() {
    while [[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]] && [ ! -z "$uuid" ]
    do
        echo -e "${red}Ошибка: введённое значение не является UUID${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
        read uuid
        [[ ! -z $uuid ]] && echo ""
    done
}

check_uuid_en() {
    while [[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]] && [ ! -z "$uuid" ]
    do
        echo -e "${red}Error: this is not an UUID${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Enter your UUID for VLESS or leave this empty to generate a random UUID:"
        read uuid
        [[ ! -z $uuid ]] && echo ""
    done
}

check_vless_path_ru() {
    while [ "$trojanpath" = "$vlesspath" ] && [ ! -z "$vlesspath" ]
    do
        echo -e "${red}Ошибка: пути для Trojan и VLESS не должны совпадать${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Введите путь для VLESS или оставьте пустым для генерации случайного пути:"
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
        echo -e "${textcolor}[?]${clear} Enter your path for VLESS or leave this empty to generate a random path:"
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
        echo -e "${textcolor}[?]${clear} Введите путь для подписки или оставьте пустым для генерации случайного пути:"
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
        echo -e "${textcolor}[?]${clear} Enter your subscription path or leave this empty to generate a random path:"
        read subspath
        [[ ! -z $subspath ]] && echo ""
        crop_subscription_path
    done
}

check_rulesetpath_ru() {
    while ([ "$trojanpath" = "$rulesetpath" ] || [ "$vlesspath" = "$rulesetpath" ] || [ "$subspath" = "$rulesetpath" ]) && [ ! -z "$rulesetpath" ]
    do
        echo -e "${red}Ошибка: пути для Trojan, VLESS, подписки и наборов правил должны быть разными${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Введите путь для наборов правил (rule sets) или оставьте пустым для генерации случайного пути:"
        read rulesetpath
        [[ ! -z $rulesetpath ]] && echo ""
        crop_rulesetpath
    done
}

check_rulesetpath_en() {
    while ([ "$trojanpath" = "$rulesetpath" ] || [ "$vlesspath" = "$rulesetpath" ] || [ "$subspath" = "$rulesetpath" ]) && [ ! -z "$rulesetpath" ]
    do
        echo -e "${red}Error: paths for Trojan, VLESS, subscription and rule sets must be different${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Enter your path for rule sets or leave this empty to generate a random path:"
        read rulesetpath
        [[ ! -z $rulesetpath ]] && echo ""
        crop_rulesetpath
    done
}

check_redirect_domain_ru() {
    while [[ "$(curl -s -o /dev/null -w "%{http_code}" https://${redirect}/)" == "000" ]] || [[ -z $redirect ]]
    do
        if [[ -z $redirect ]]
        then
            :
        else
            echo -e "${red}Ошибка: домен введён неправильно или не имеет HTTPS${clear}"
            echo ""
        fi
        echo -e "${textcolor}[?]${clear} Введите домен, на который будет идти перенаправление:"
        read redirect
        echo ""
        crop_redirect_domain
    done
}

check_redirect_domain_en() {
    while [[ "$(curl -s -o /dev/null -w "%{http_code}" https://${redirect}/)" == "000" ]] || [[ -z $redirect ]]
    do
        if [[ -z $redirect ]]
        then
            :
        else
            echo -e "${red}Error: this domain is invalid or does not have HTTPS${clear}"
            echo ""
        fi
        echo -e "${textcolor}[?]${clear} Enter the domain to which requests will be redirected:"
        read redirect
        echo ""
        crop_redirect_domain
    done
}

check_index_ru() {
    while [ ! -f /root${index} ] || [ -z "$index" ]
    do
        echo -e "${red}Ошибка: файл /root${index} не существует${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Введите путь до index файла внутри папки вашего сайта (например, /site_folder/index.html):"
        read index
        echo ""
        edit_index
    done
}

check_index_en() {
    while [ ! -f /root${index} ] || [ -z "$index" ]
    do
        echo -e "${red}Error: file /root${index} doesn't exist${clear}"
        echo ""
        echo -e "${textcolor}[?]${clear} Enter the path to the index file inside the folder of your website (e. g., /site_folder/index.html):"
        read index
        echo ""
        edit_index
    done
}

check_site_link_ru() {
    while [[ "$(curl -s -o /dev/null -w "%{http_code}" https://${sitelink})" == "000" ]] || [[ -z $sitelink ]] || [ $(wget -q -O /dev/null https://${sitelink}; echo $?) -ne 0 ]
    do
        if [[ -z $sitelink ]]
        then
            :
        else
            echo -e "${red}Ошибка: сайт недоступен по данной ссылке или не имеет HTTPS${clear}"
            echo ""
        fi
        echo -e "${textcolor}[?]${clear} Введите ссылку на главную страницу выбранного сайта:"
        read sitelink
        echo ""
        crop_site_link
    done
}

check_site_link_en() {
    while [[ "$(curl -s -o /dev/null -w "%{http_code}" https://${sitelink})" == "000" ]] || [[ -z $sitelink ]] || [ $(wget -q -O /dev/null https://${sitelink}; echo $?) -ne 0 ]
    do
        if [[ -z $sitelink ]]
        then
            :
        else
            echo -e "${red}Error: the website is not available or does not have HTTPS${clear}"
            echo ""
        fi
        echo -e "${textcolor}[?]${clear} Enter the link to the main page of the selected website:"
        read sitelink
        echo ""
        crop_site_link
    done
}

nginx_login() {
    comment1="#"
    comment2=""
    comment3=""
    redirect="${domain}"
    sitedir="html"
    index="index.html index.htm"
}

nginx_redirect() {
    comment1=""
    comment2="#"
    comment3=""
    sitedir="html"
    index="index.html index.htm"

    if [[ "${language}" == "1" ]]
    then
        echo -e "${textcolor}[?]${clear} Введите домен, на который будет идти перенаправление:"
        read redirect
        echo ""
        crop_redirect_domain
        check_redirect_domain_ru
    else
        echo -e "${textcolor}[?]${clear} Enter the domain to which requests will be redirected:"
        read redirect
        echo ""
        crop_redirect_domain
        check_redirect_domain_en
    fi
}

nginx_copy_site() {
    comment1=""
    comment2=""
    comment3="#"
    redirect="${domain}"

    if [[ "${language}" == "1" ]]
    then
        echo -e "${red}ВНИМАНИЕ!${clear}"
        echo "Некоторые сайты могут содержать большие файлы или большое число страниц, которые могут занять много места на диске"
        echo "Функционал некоторых сайтов может быть частично утрачен"
        echo "Вы выбираете какой-либо сайт на свой страх и риск"
        echo ""
        echo -e "${textcolor}[?]${clear} Введите ссылку на главную страницу выбранного сайта:"
        read sitelink
        echo ""
        crop_site_link
        check_site_link_ru
    else
        echo -e "${red}ATTENTION!${clear}"
        echo "Some websites might contain large files or large number of pages, which may take a lot of disk space"
        echo "Some websites may partially lose their functionality"
        echo "You choose the website at your own risk"
        echo ""
        echo -e "${textcolor}[?]${clear} Enter the link to the main page of the selected website:"
        read sitelink
        echo ""
        crop_site_link
        check_site_link_en
    fi
}

nginx_site() {
    comment1=""
    comment2=""
    comment3="#"
    redirect="${domain}"

    if [[ "${language}" == "1" ]]
    then
        echo -e "${textcolor}[?]${clear} Введите путь до index файла внутри папки вашего сайта (например, /site_folder/index.html):"
        read index
        echo ""
        edit_index
        check_index_ru
    else
        echo -e "${textcolor}[?]${clear} Enter the path to the index file inside the folder of your website (e. g., /site_folder/index.html):"
        read index
        echo ""
        edit_index
        check_index_en
    fi
}

nginx_options() {
    case $option in
        2)
        nginx_redirect
        ;;
        3)
        nginx_copy_site
        ;;
        4)
        nginx_site
        ;;
        *)
        nginx_login
    esac
}

enter_ssh_data_ru() {
    if [[ "${sshufw}" != "2" ]]
    then
        echo -e "${textcolor}[?]${clear} Введите новый номер порта SSH или 22 (рекомендуется номер более 1024):"
        read sshp
        echo ""
        check_ssh_port_ru
        echo -e "${textcolor}[?]${clear} Введите имя нового пользователя или root (рекомендуется не root):"
        read username
        echo ""
        check_username_ru
        echo -e "${textcolor}[?]${clear} Введите пароль SSH для пользователя (рекомендуется сложный пароль):"
        read password
        echo ""
        check_password_ru
    fi
}

enter_ssh_data_en() {
    if [[ "${sshufw}" != "2" ]]
    then
        echo -e "${textcolor}[?]${clear} Enter new SSH port number or 22 (number above 1024 is recommended):"
        read sshp
        echo ""
        check_ssh_port_en
        echo -e "${textcolor}[?]${clear} Enter your username or root (non-root user is recommended):"
        read username
        echo ""
        check_username_en
        echo -e "${textcolor}[?]${clear} Enter new SSH password (a complex password is recommended):"
        read password
        echo ""
        check_password_en
    fi
}

enter_data_ru() {
    echo ""
    while [[ -z $domain ]]
    do
        echo -e "${textcolor}[?]${clear} Введите ваш домен:"
        read domain
        echo ""
    done
    crop_domain
    while [[ -z $email ]]
    do
        echo -e "${textcolor}[?]${clear} Введите вашу почту, зарегистрированную на Cloudflare:"
        read email
        echo ""
    done
    while [[ -z $cftoken ]]
    do
        echo -e "${textcolor}[?]${clear} Введите ваш API токен Cloudflare (Edit zone DNS) или Cloudflare global API key:"
        read cftoken
        echo ""
    done
    check_cf_token_ru
    echo -e "${textcolor}[?]${clear} Выберите вариант настройки прокси:"
    echo "1 - Терминирование TLS на NGINX, протоколы Trojan и VLESS, транспорт WebSocket или HTTPUpgrade"
    echo "2 - Терминирование TLS на HAProxy, протокол Trojan, выбор бэкенда Sing-Box или NGINX по паролю Trojan"
    read variant
    echo ""
    if [[ "${variant}" == "1" ]]
    then
        echo -e "${textcolor}[?]${clear} Выберите транспорт:"
        echo "1 - WebSocket"
        echo "2 - HTTPUpgrade"
        read transport
        echo ""
    fi
    echo -e "${textcolor}[?]${clear} Выберите вариант настройки NGINX/HAProxy:"
    echo "1 - Будет спрашивать логин и пароль вместо сайта, 401 Unauthorized"
    echo "2 - Будет перенаправлять на другой домен, 301 Moved Permanently"
    echo "3 - Скопировать чужой сайт на свой сервер, тестовая опция"
    echo "4 - Свой сайт (при наличии), тестовая опция"
    read option;
    echo ""
    nginx_options
    echo -e "${textcolor}[?]${clear} Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
    read trjpass
    [[ ! -z $trjpass ]] && echo ""
    if [[ "${variant}" == "1" ]]
    then
        echo -e "${textcolor}[?]${clear} Введите путь для Trojan или оставьте пустым для генерации случайного пути:"
        read trojanpath
        [[ ! -z $trojanpath ]] && echo ""
        crop_trojan_path
        echo -e "${textcolor}[?]${clear} Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
        read uuid
        [[ ! -z $uuid ]] && echo ""
        check_uuid_ru
        echo -e "${textcolor}[?]${clear} Введите путь для VLESS или оставьте пустым для генерации случайного пути:"
        read vlesspath
        [[ ! -z $vlesspath ]] && echo ""
        crop_vless_path
        check_vless_path_ru
    fi
    echo -e "${textcolor}[?]${clear} Введите путь для подписки или оставьте пустым для генерации случайного пути:"
    read subspath
    [[ ! -z $subspath ]] && echo ""
    crop_subscription_path
    check_subscription_path_ru
    echo -e "${textcolor}[?]${clear} Введите путь для наборов правил (rule sets) или оставьте пустым для генерации случайного пути:"
    read rulesetpath
    [[ ! -z $rulesetpath ]] && echo ""
    crop_rulesetpath
    check_rulesetpath_ru
    echo -e "${textcolor}[?]${clear} Нужна ли настройка безопасности (SSH, UFW и unattended-upgrades)?"
    echo "1 - Да (в случае нестандартных настроек у хостера или ошибки при вводе данных можно потерять доступ к серверу)"
    echo "2 - Нет"
    read sshufw
    echo ""
    enter_ssh_data_ru
}

enter_data_en() {
    echo ""
    while [[ -z $domain ]]
    do
        echo -e "${textcolor}[?]${clear} Enter your domain name:"
        read domain
        echo ""
    done
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
    check_cf_token_en
    echo -e "${textcolor}[?]${clear} Select a proxy setup option:"
    echo "1 - TLS termination on NGINX, Trojan and VLESS protocols, WebSocket or HTTPUpgrade transport"
    echo "2 - TLS termination on HAProxy, Trojan protocol, Sing-Box or NGINX backend selection based on Trojan passwords"
    read variant
    echo ""
    if [[ "${variant}" == "1" ]]
    then
        echo -e "${textcolor}[?]${clear} Select transport:"
        echo "1 - WebSocket"
        echo "2 - HTTPUpgrade"
        read transport
        echo ""
    fi
    echo -e "${textcolor}[?]${clear} Select NGINX/HAProxy setup option:"
    echo "1 - Will show a login popup asking for username and password, 401 Unauthorized"
    echo "2 - Will redirect to another domain, 301 Moved Permanently"
    echo "3 - Copy someone else's website to your server, experimental option"
    echo "4 - Your own website (if you have one), experimental option"
    read option;
    echo ""
    nginx_options
    echo -e "${textcolor}[?]${clear} Enter your password for Trojan or leave this empty to generate a random password:"
    read trjpass
    [[ ! -z $trjpass ]] && echo ""
    if [[ "${variant}" == "1" ]]
    then
        echo -e "${textcolor}[?]${clear} Enter your path for Trojan or leave this empty to generate a random path:"
        read trojanpath
        [[ ! -z $trojanpath ]] && echo ""
        crop_trojan_path
        echo -e "${textcolor}[?]${clear} Enter your UUID for VLESS or leave this empty to generate a random UUID:"
        read uuid
        [[ ! -z $uuid ]] && echo ""
        check_uuid_en
        echo -e "${textcolor}[?]${clear} Enter your path for VLESS or leave this empty to generate a random path:"
        read vlesspath
        [[ ! -z $vlesspath ]] && echo ""
        crop_vless_path
        check_vless_path_en
    fi
    echo -e "${textcolor}[?]${clear} Enter your subscription path or leave this empty to generate a random path:"
    read subspath
    [[ ! -z $subspath ]] && echo ""
    crop_subscription_path
    check_subscription_path_en
    echo -e "${textcolor}[?]${clear} Enter your path for rule sets or leave this empty to generate a random path:"
    read rulesetpath
    [[ ! -z $rulesetpath ]] && echo ""
    crop_rulesetpath
    check_rulesetpath_en
    echo -e "${textcolor}[?]${clear} Do you need security setup (SSH, UFW and unattended-upgrades)?"
    echo "1 - Yes (in case of hoster's non-standard settings or a mistake while entering data, access to the server might be lost)"
    echo "2 - No"
    read sshufw
    echo ""
    enter_ssh_data_en
}

enter_data() {
    if [[ "${language}" == "1" ]]
    then
        enter_data_ru
    else
        enter_data_en
    fi
    echo ""
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
    apt install sudo coreutils wget certbot python3-certbot-dns-cloudflare cron gnupg2 ca-certificates lsb-release openssl sed jq net-tools htop -y

    if grep -q "bullseye" /etc/os-release || grep -q "bookworm" /etc/os-release
    then
        apt install debian-archive-keyring -y
    else
        apt install ubuntu-keyring -y
    fi

    if [[ "${sshufw}" != "2" ]]
    then
        apt install ufw unattended-upgrades -y
    fi

    if [ ! -d /usr/share/keyrings ]
    then
        mkdir /usr/share/keyrings
    fi

    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(grep "VERSION_CODENAME=" /etc/os-release | cut -d "=" -f 2) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
    apt-get update && apt-get install cloudflare-warp -y
    #wget https://pkg.cloudflareclient.com/pool/$(grep "VERSION_CODENAME=" /etc/os-release | cut -d "=" -f 2)/main/c/cloudflare-warp/cloudflare-warp_2024.6.497-1_amd64.deb
    #dpkg -i cloudflare-warp_2024.6.497-1_amd64.deb
    #apt-mark hold cloudflare-warp

    if [ ! -d /etc/apt/keyrings ]
    then
        mkdir /etc/apt/keyrings
    fi

    curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
    chmod a+r /etc/apt/keyrings/sagernet.asc
    echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | tee /etc/apt/sources.list.d/sagernet.list > /dev/null
    apt-get update
    apt-get install sing-box -y
    apt-mark hold sing-box

    curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
    gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg
    if grep -q "bullseye" /etc/os-release || grep -q "bookworm" /etc/os-release
    then
        echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/debian `lsb_release -cs` nginx" | tee /etc/apt/sources.list.d/nginx.list
    else
        echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" | tee /etc/apt/sources.list.d/nginx.list
    fi
    echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | tee /etc/apt/preferences.d/99nginx
    apt update
    apt install nginx -y

    if [ ! -d /var/www ]
    then
        mkdir /var/www
    fi

    if [[ "${variant}" != "1" ]]
    then
        apt install haproxy -y
    fi

    journalctl --vacuum-time=7days

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
        sed -i -e "s/.*Port .*/Port ${sshp}/g" -e "s/.*PermitRootLogin no.*/PermitRootLogin yes/g" -e "s/.*#PermitRootLogin.*/PermitRootLogin yes/g" -e "s/.*#PasswordAuthentication .*/PasswordAuthentication yes/g" -e "s/.*PasswordAuthentication no.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
        if [ ! -d /root/.ssh ]
        then
            mkdir /root/.ssh
        fi
    else
        sed -i -e "s/.*Port .*/Port ${sshp}/g" -e "s/.*PermitRootLogin yes.*/PermitRootLogin no/g" -e "s/.*#PermitRootLogin.*/PermitRootLogin no/g" -e "s/.*#PasswordAuthentication .*/PasswordAuthentication yes/g" -e "s/.*PasswordAuthentication no.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
        if [ ! -d /home/${username}/.ssh ]
        then
            mkdir /home/${username}/.ssh
        fi
        chown ${username}:sudo /home/${username}/.ssh
        chmod 700 /home/${username}/.ssh
    fi

    if grep -q "noble" /etc/os-release
    then
        sed -i "s/.*ListenStream.*/ListenStream=${sshp}/g" /lib/systemd/system/ssh.socket
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
    systemctl enable unattended-upgrades.service
    echo ""
}

setup_security() {
    if [[ "${sshufw}" != "2" ]]
    then
        create_user
        setup_ssh
        setup_ufw
        unattended_upgrades
    fi
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

    certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive

    if [ $? -ne 0 ]
    then
        sleep 3
        echo ""
        rm -rf /etc/letsencrypt/live/${domain} &> /dev/null
        rm -rf /etc/letsencrypt/archive/${domain} &> /dev/null
        rm /etc/letsencrypt/renewal/${domain}.conf &> /dev/null
        echo -e "${textcolor_light}Requesting a certificate: 2nd attempt...${clear}"
        certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive
    fi

    { crontab -l; echo "0 2 1 */2 * certbot -q renew --force-renewal"; } | crontab -

    if [[ "${variant}" == "1" ]]
    then
        echo "renew_hook = systemctl reload nginx" >> /etc/letsencrypt/renewal/${domain}.conf
        echo ""
        openssl dhparam -out /etc/nginx/dhparam.pem 2048
    else
        echo "renew_hook = cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem && systemctl reload haproxy" >> /etc/letsencrypt/renewal/${domain}.conf
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
    systemctl enable warp-svc.service
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

    if [ -z "$rulesetpath" ]
    then
        rulesetpath=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    fi

    userkey=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 9)
}

download_rule_sets() {
    mkdir /var/www/${rulesetpath}

    wget -P /var/www/${rulesetpath} https://raw.githubusercontent.com/FPPweb3/sb-rule-sets/main/torrent-clients.json
    wget -P /var/www/${rulesetpath} https://github.com/SagerNet/sing-geoip/raw/rule-set/geoip-ru.srs

    for i in $(seq 0 $(expr $(jq ".route.rule_set | length" /var/www/${subspath}/1${userkey}-TRJ-CLIENT.json) - 1))
    do
        ruleset_link=$(jq -r ".route.rule_set[${i}].url" /var/www/${subspath}/1${userkey}-TRJ-CLIENT.json)
        ruleset=${ruleset_link#"https://${domain}/${rulesetpath}/"}
        wget -P /var/www/${rulesetpath} https://github.com/SagerNet/sing-geosite/raw/rule-set/${ruleset}
    done

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

    wget -O /usr/local/bin/rsupdate https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Scripts/ruleset-update.sh
    chmod +x /usr/local/bin/rsupdate
    { crontab -l; echo "10 2 * * * /usr/local/bin/rsupdate"; } | crontab -
}

server_config() {
systemctl stop sing-box.service
systemctl disable sing-box.service

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
      "users": [
        {
          "name": "1${userkey}",
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
      "users": [
        {
          "name": "1${userkey}",
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
        "action": "sniff"
      },
      {
        "protocol": "dns",
        "action": "hijack-dns"
      },
      {
        "rule_set": [
          "category-ads-all"
        ],
        "action": "reject",
        "method": "drop"
      },
      {
        "protocol": "quic",
        "action": "reject",
        "method": "drop"
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
          "aistudio.google.com",
          "makersuite.google.com",
          "alkalimakersuite-pa.clients6.google.com",
          "alkalicore-pa.clients6.google.com",
          "aida.googleapis.com",
          "generativelanguage.googleapis.com",
          "proactivebackend-pa.googleapis.com",
          "geller-pa.googleapis.com",
          "deepmind.com",
          "deepmind.google",
          "generativeai.google",
          "ai.google.dev",
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
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geoip-ru.srs"
      },
      {
        "tag": "gov-ru",
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geosite-category-gov-ru.srs"
      },
      {
        "tag": "google",
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geosite-google.srs"
      },
      {
        "tag": "openai",
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geosite-openai.srs"
      },
      {
        "tag": "telegram",
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geosite-telegram.srs"
      },
      {
        "tag": "category-ads-all",
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geosite-category-ads-all.srs"
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

if [[ "${transport}" == "2" ]]
then
    inboundnumbervl=$(jq '[.inbounds[].tag] | index("vless-in")' /etc/sing-box/config.json)
    inboundnumbertr=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
    echo "$(jq ".inbounds[${inboundnumbertr}].transport.type = \"httpupgrade\" | .inbounds[${inboundnumbervl}].transport.type = \"httpupgrade\"" /etc/sing-box/config.json)" > /etc/sing-box/config.json
fi

if [[ "${variant}" != "1" ]]
then
    inboundnumbervl=$(jq '[.inbounds[].tag] | index("vless-in")' /etc/sing-box/config.json)
    inboundnumbertr=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
    echo "$(jq "del(.inbounds[${inboundnumbertr}].transport.type) | del(.inbounds[${inboundnumbertr}].transport.path) | del(.inbounds[${inboundnumbervl}])" /etc/sing-box/config.json)" > /etc/sing-box/config.json
fi

download_rule_sets

systemctl enable sing-box.service
systemctl start sing-box.service
}

client_config() {
mkdir /var/www/${subspath}
touch /var/www/${subspath}/1${userkey}-TRJ-CLIENT.json

cat > /var/www/${subspath}/1${userkey}-TRJ-CLIENT.json <<EOF
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
          "wikipedia.org"
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
          "aliexpress"
        ],
        "rule_set": [
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
          "torrent-clients"
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
      "address": "172.19.0.1/28",
      "auto_route": true,
      "strict_route": true,
      "sniff_override_destination": true
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
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
        "action": "sniff"
      },
      {
        "protocol": "dns",
        "action": "hijack-dns"
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
        "action": "reject",
        "method": "drop"
      },
      {
        "rule_set": [
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
          "wikipedia.org"
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
          "aliexpress"
        ],
        "ip_cidr": [
          "${serverip}"
        ],
        "rule_set": [
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
          "torrent-clients"
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
        "type": "remote",
        "tag": "torrent-clients",
        "format": "source",
        "url": "https://${domain}/${rulesetpath}/torrent-clients.json"
      },
      {
        "tag": "gov-ru",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-category-gov-ru.srs"
      },
      {
        "tag": "yandex",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-yandex.srs"
      },
      {
        "tag": "telegram",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-telegram.srs"
      },
      {
        "tag": "vk",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-vk.srs"
      },
      {
        "tag": "mailru",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-mailru.srs"
      },
      {
        "tag": "zoom",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-zoom.srs"
      },
      {
        "tag": "reddit",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-reddit.srs"
      },
      {
        "tag": "twitch",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-twitch.srs"
      },
      {
        "tag": "tumblr",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-tumblr.srs"
      },
      {
        "tag": "4chan",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-4chan.srs"
      },
      {
        "tag": "pinterest",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-pinterest.srs"
      },
      {
        "tag": "deviantart",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-deviantart.srs"
      },
      {
        "tag": "duckduckgo",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-duckduckgo.srs"
      },
      {
        "tag": "yahoo",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-yahoo.srs"
      },
      {
        "tag": "mozilla",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-mozilla.srs"
      },
      {
        "tag": "category-android-app-download",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-category-android-app-download.srs"
      },
      {
        "tag": "aptoide",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-aptoide.srs"
      },
      {
        "tag": "samsung",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-samsung.srs"
      },
      {
        "tag": "huawei",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-huawei.srs"
      },
      {
        "tag": "apple",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-apple.srs"
      },
      {
        "tag": "microsoft",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-microsoft.srs"
      },
      {
        "tag": "nvidia",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-nvidia.srs"
      },
      {
        "tag": "xiaomi",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-xiaomi.srs"
      },
      {
        "tag": "hp",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-hp.srs"
      },
      {
        "tag": "asus",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-asus.srs"
      },
      {
        "tag": "lenovo",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-lenovo.srs"
      },
      {
        "tag": "lg",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-lg.srs"
      },
      {
        "tag": "oracle",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-oracle.srs"
      },
      {
        "tag": "adobe",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-adobe.srs"
      },
      {
        "tag": "blender",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-blender.srs"
      },
      {
        "tag": "drweb",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-drweb.srs"
      },
      {
        "tag": "gitlab",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-gitlab.srs"
      },
      {
        "tag": "debian",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-debian.srs"
      },
      {
        "tag": "canonical",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-canonical.srs"
      },
      {
        "tag": "python",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-python.srs"
      },
      {
        "tag": "doi",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-doi.srs"
      },
      {
        "tag": "elsevier",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-elsevier.srs"
      },
      {
        "tag": "sciencedirect",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-sciencedirect.srs"
      },
      {
        "tag": "clarivate",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-clarivate.srs"
      },
      {
        "tag": "sci-hub",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-sci-hub.srs"
      },
      {
        "tag": "duolingo",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-duolingo.srs"
      },
      {
        "tag": "aljazeera",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-aljazeera.srs"
      },
      {
        "tag": "category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-category-ads-all.srs"
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

if [[ "${transport}" == "2" ]]
then
    outboundnumber=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/1${userkey}-TRJ-CLIENT.json)
    echo "$(jq ".outbounds[${outboundnumber}].transport.type = \"httpupgrade\"" /var/www/${subspath}/1${userkey}-TRJ-CLIENT.json)" > /var/www/${subspath}/1${userkey}-TRJ-CLIENT.json
fi

if [[ "${variant}" == "1" ]]
then
    cp /var/www/${subspath}/1${userkey}-TRJ-CLIENT.json /var/www/${subspath}/1${userkey}-VLESS-CLIENT.json
    sed -i -e "s/$trjpass/$uuid/g" -e "s/$trojanpath/$vlesspath/g" -e 's/: "trojan"/: "vless"/g' -e 's/"password": /"uuid": /g' /var/www/${subspath}/1${userkey}-VLESS-CLIENT.json
else
    outboundnumber=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/1${userkey}-TRJ-CLIENT.json)
    echo "$(jq "del(.outbounds[${outboundnumber}].transport.type) | del(.outbounds[${outboundnumber}].transport.path)" /var/www/${subspath}/1${userkey}-TRJ-CLIENT.json)" > /var/www/${subspath}/1${userkey}-TRJ-CLIENT.json
fi
}

setup_sing_box() {
    echo -e "${textcolor_light}Setting up Sing-Box...${clear}"
    generate_pass
    client_config
    server_config
    echo ""
}

for_nginx_options() {
    if [[ "${variant}" == "1" ]] && [[ "$option" != "2" ]] && [[ "$option" != "3" ]] && [[ "$option" != "4" ]]
    then
        touch /etc/nginx/.htpasswd
    fi

    if [[ "$option" == "3" ]]
    then
        wget -P /var/www --mirror --convert-links --adjust-extension --page-requisites --no-parent https://${sitelink}

        mkdir ./testdir
        wget -q -P ./testdir https://${sitelink}
        index=$(ls ./testdir)
        rm -rf ./testdir

        if [[ "$sitelink" =~ "/" ]]
        then
            sitedir=$(echo "${sitelink}" | cut -d "/" -f 1)
        else
            sitedir="${sitelink}"
        fi

        chmod -R 755 /var/www/${sitedir}
        filelist=$(find /var/www/${sitedir} -name ${index})
        slashnum=1000

        for k in $(seq 1 $(echo "$filelist" | wc -l))
        do
            testfile=$(echo "$filelist" | sed -n "${k}p")
            if [ $(echo "${testfile}" | tr -cd '/' | wc -c) -lt ${slashnum} ]
            then
                resultfile="${testfile}"
                slashnum=$(echo "${testfile}" | tr -cd '/' | wc -c)
            fi
        done

        sitedir=${resultfile#"/var/www/"}
        sitedir=${sitedir%"/${index}"}
        echo ""
    fi

    if [[ "$option" == "4" ]]
    then
        sitedir=$(echo "${index}" | cut -d "/" -f 2)
        mv /root/${sitedir} /var/www
        chmod -R 755 /var/www/${sitedir}
        sitedir=${index#"/"}
        index=$(echo "${index}" | rev | cut -d "/" -f 1 | rev)
        sitedir=${sitedir%"/${index}"}
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

    # Site
    server {
        listen                               443 ssl default_server;
        listen                               [::]:443 ssl default_server;
        http2                                on;
        server_name                          ${domain} *.${domain};
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
            ${comment2}${comment3}auth_basic "Restricted Content";
            ${comment2}${comment3}auth_basic_user_file /etc/nginx/.htpasswd;
            ${comment1}${comment3}return 301 https://${redirect}\$request_uri;
        ${comment3}}

        # Subsciption
        location ~ ^/${subspath} {
            default_type application/json;
            root /var/www;
        }

        # Rule sets
        location /${rulesetpath}/ {
            alias /var/www/${rulesetpath}/;
            add_header Content-disposition "attachment";
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
}
EOF

systemctl enable nginx
nginx -t
systemctl restart nginx
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

        # Subsciption
        location ~ ^/${subspath} {
            default_type application/json;
            root /var/www;
        }

        # Rule sets
        location /${rulesetpath}/ {
            alias /var/www/${rulesetpath}/;
            add_header Content-disposition "attachment";
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
systemctl restart nginx
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
        ssl-default-bind-options prefer-client-ciphers no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets
        ssl-default-server-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-server-options no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets

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
        ${comment3}use_backend http-sub if { path /${subspath} } || { path_beg /${subspath}/ } || { path /${rulesetpath} } || { path_beg /${rulesetpath}/ }
        use_backend %[lua.trojan_auth]
        default_backend http

backend trojan
        mode tcp
        timeout server 1h
        server sing-box 127.0.0.1:10443

backend http
        mode http
        timeout server 1h
        ${comment2}${comment3}http-request auth unless { http_auth(mycredentials) }
        ${comment1}${comment3}http-request redirect code 301 location https://${redirect}/
        ${comment1}${comment2}server nginx 127.0.0.1:11443

${comment3}backend http-sub
        ${comment3}mode http
        ${comment3}timeout server 1h
        ${comment3}server nginx 127.0.0.1:11443

${comment2}${comment3}userlist mycredentials
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
    echo -e "${textcolor_light}Adding sbmanager...${clear}"

    if [[ "${language}" == "1" ]]
    then
        wget -O /usr/local/bin/sbmanager https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Scripts/sb-manager-ru.sh
    else
        wget -O /usr/local/bin/sbmanager https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Scripts/sb-manager-en.sh
    fi

    chmod +x /usr/local/bin/sbmanager

    if [[ "${variant}" == "1" ]] && [[ "${transport}" != "2" ]]
    then
        wget -O /var/www/${subspath}/template.json https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Config-Templates/Client-Trojan-WS.json
    elif [[ "${variant}" == "1" ]] && [[ "${transport}" == "2" ]]
    then
        wget -O /var/www/${subspath}/template.json https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Config-Templates/Client-Trojan-HTTPUpgrade.json
    else
        wget -O /var/www/${subspath}/template.json https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Config-Templates/Client-Trojan-HAProxy.json
    fi

    if [ -f /var/www/${subspath}/template.json ] && [ $(jq -e . < /var/www/${subspath}/template.json &>/dev/null; echo $?) -eq 0 ] && [ -s /var/www/${subspath}/template.json ]
    then
        cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
    else
        cp /var/www/${subspath}/1${userkey}-TRJ-CLIENT.json /var/www/${subspath}/template-loc.json
    fi
}

add_sub_page() {
    echo -e "${textcolor_light}Adding subscription page...${clear}"

    if [[ "${variant}" == "1" ]] && [[ "${language}" == "1" ]]
    then
        wget -O /var/www/${subspath}/sub.html https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Subscription-Page/sub-ru.html
    elif [[ "${variant}" == "1" ]] && [[ "${language}" != "1" ]]
    then
        wget -O /var/www/${subspath}/sub.html https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Subscription-Page/sub-en.html
    elif [[ "${variant}" != "1" ]] && [[ "${language}" == "1" ]]
    then
        wget -O /var/www/${subspath}/sub.html https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Subscription-Page/sub-ru-hapr.html
    else
        wget -O /var/www/${subspath}/sub.html https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Subscription-Page/sub-en-hapr.html
    fi

    sed -i -e "s/DOMAIN/$domain/g" -e "s/SUBSCRIPTION-PATH/$subspath/g" /var/www/${subspath}/sub.html

    wget -O /var/www/${subspath}/background.jpg https://raw.githubusercontent.com/BLUEBL0B/Secret-Sing-Box/master/Subscription-Page/background.jpg
}

final_message_ru() {
    echo -e "${textcolor}Если выше не возникло ошибок, то настройка завершена!${clear}"
    echo ""
    if [[ "${sshufw}" != "2" ]]
    then
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
    else
        echo -e "${red}ВНИМАНИЕ!${clear}"
        echo "Вы пропустили настройку безопасности"
        echo "Настоятельно рекомендуется почитать о безопасности сервера и выполнить настройку самостоятельно"
    fi
    echo ""
    echo -e "${red}ВАЖНО:${clear}"
    echo -e "Для начала работы прокси может потребоваться перезагрузка сервера командой ${textcolor}sudo reboot${clear}"
    if [[ "${variant}" == "1" ]]
    then
        echo ""
        echo -e "${textcolor}Конфиги для клиента доступны по ссылкам:${clear}"
        echo "https://${domain}/${subspath}/1${userkey}-TRJ-CLIENT.json"
        echo "https://${domain}/${subspath}/1${userkey}-VLESS-CLIENT.json"
        echo ""
        echo -e "${textcolor}Страница выдачи подписок пользователей:${clear}"
        echo "https://${domain}/${subspath}/sub.html"
        echo -e "Ваше имя пользователя - ${textcolor}1${userkey}${clear}"
    else
        echo "Чтобы этот вариант настройки работал, в DNS записях Cloudflare должно стоять \"DNS only\", а не \"Proxied\""
        echo ""
        echo -e "${textcolor}Конфиг для клиента доступен по ссылке:${clear}"
        echo "https://${domain}/${subspath}/1${userkey}-TRJ-CLIENT.json"
        echo ""
        echo -e "${textcolor}Страница выдачи подписок пользователей:${clear}"
        echo "https://${domain}/${subspath}/sub.html"
        echo -e "Ваше имя пользователя - ${textcolor}1${userkey}${clear}"
    fi
    echo ""
    echo -e "Для вывода дополнительных настроек используйте команду ${textcolor}sbmanager${clear}"
    if [ ! -f /etc/letsencrypt/live/${domain}/fullchain.pem ]
    then
        echo ""
        echo -e "${red}Ошибка: сертификат не выпущен, введите команду \"sbmanager\" и выберите пункт 11${clear}"
    fi
}

final_message_en() {
    echo -e "${textcolor}If there are no errors above then the setup is complete!${clear}"
    echo ""
    if [[ "${sshufw}" != "2" ]]
    then
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
    else
        echo -e "${red}ATTENTION!${clear}"
        echo "You have skipped security setup"
        echo "It is highly recommended to find information about server security and to configure it yourself"
    fi
    echo ""
    echo -e "${red}IMPORTANT:${clear}"
    echo -e "It might be required to reboot the server for the proxy to start working (${textcolor}sudo reboot${clear})"
    if [[ "${variant}" == "1" ]]
    then
        echo ""
        echo -e "${textcolor}Client configs are available here:${clear}"
        echo "https://${domain}/${subspath}/1${userkey}-TRJ-CLIENT.json"
        echo "https://${domain}/${subspath}/1${userkey}-VLESS-CLIENT.json"
        echo ""
        echo -e "${textcolor}Subscription page:${clear}"
        echo "https://${domain}/${subspath}/sub.html"
        echo -e "Your username is ${textcolor}1${userkey}${clear}"
    else
        echo "For this setup method to work, your DNS records in Cloudflare must be set to \"DNS only\", not \"Proxied\""
        echo ""
        echo -e "${textcolor}Client config is available here:${clear}"
        echo "https://${domain}/${subspath}/1${userkey}-TRJ-CLIENT.json"
        echo ""
        echo -e "${textcolor}Subscription page:${clear}"
        echo "https://${domain}/${subspath}/sub.html"
        echo -e "Your username is ${textcolor}1${userkey}${clear}"
    fi
    echo ""
    echo -e "To display additional settings, run ${textcolor}sbmanager${clear} command"
    if [ ! -f /etc/letsencrypt/live/${domain}/fullchain.pem ]
    then
        echo ""
        echo -e "${red}Error: certificate has not been issued, enter \"sbmanager\" command and select option 11${clear}"
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
check_if_updated
enter_data
enable_bbr
install_packages
setup_security
certificates
setup_warp
setup_sing_box
setup_nginx
setup_haproxy
add_sbmanager
add_sub_page
final_message
