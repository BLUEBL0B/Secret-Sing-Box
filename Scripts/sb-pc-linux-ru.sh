#!/bin/bash

textcolor='\033[1;34m'
red='\033[1;31m'
clear='\033[0m'

check_root() {
	if [[ $EUID -ne 0 ]]
	then
		echo ""
		echo -e "${red}Ошибка: этот скрипт нужно запускать от имени root, сначала введите команду \"sudo -i\"${clear}"
		echo ""
		exit 1
	fi
}

check_sbmanager() {
	if [[ -f /usr/local/bin/sbmanager ]] && [[ ! -f /usr/local/bin/proxylist ]]
	then
		echo ""
		echo -e "${red}Ошибка: этот скрипт нужно запускать на клиенте, а не на сервере${clear}"
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

install_sing_box() {
	if [[ ! -f /usr/local/bin/proxylist ]]
	then
		touch /usr/local/bin/proxylist
	fi

	if [ $(sing-box version &> /dev/null; echo $?) -ne 0 ]
	then
		echo ""
		echo -e "${textcolor}Sing-Box не установлен${clear}"
		echo ""
		echo -e "${textcolor}[?]${clear} Нажмите ${textcolor}Enter${clear}, чтобы установить, или введите ${textcolor}x${clear}, чтобы выйти:"
		read sbinstall
		exit_install

		echo -e "${textcolor}Установка Sing-Box...${clear}"
		curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
		chmod a+r /etc/apt/keyrings/sagernet.asc
		echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | tee /etc/apt/sources.list.d/sagernet.list > /dev/null
		apt-get update
		apt-get install sing-box -y
		systemctl disable sing-box.service

		echo ""
		echo -e "${textcolor}Sing-Box установлен${clear}"
		echo ""
		echo -e "Его можно обновлять командой ${textcolor}apt-get install sing-box${clear}"
		echo ""
		main_menu
	fi
}

exit_install() {
	if [[ "$sbinstall" == "x" ]] || [[ "$sbinstall" == "х" ]]
	then
		echo ""
		exit 0
	fi
}

exit_add_proxy() {
	if [[ "$link" == "x" ]] || [[ "$link" == "х" ]]
	then
		link=""
		main_menu
	fi
}

exit_del_proxy() {
	if [[ "$delcomm" == "x" ]] || [[ "$delcomm" == "х" ]]
	then
		delcomm=""
		main_menu
	fi
}

check_link() {
	while [[ -z $link ]] || [[ "$(curl -s -o /dev/null -w "%{http_code}" ${link})" == "000" ]] || [[ "$(curl -s -o /dev/null -w "%{http_code}" ${link})" == "404" ]]
	do
		if [[ -z $link ]]
		then
			:
		else
			echo -e "${red}Ошибка: ссылка введена неправильно или сервер недоступен${clear}"
			echo ""
		fi
		echo -e "${textcolor}[?]${clear} Введите ссылку на ваш клиентский конфиг или введите ${textcolor}x${clear}, чтобы выйти:"
		read link
		[[ ! -z $link ]] && echo ""
		exit_add_proxy
	done
}

check_command_add() {
	while [[ -f /usr/local/bin/${newcomm} ]] || [[ $newcomm =~ " " ]] || [[ $newcomm =~ '$' ]] || [[ -z $newcomm ]]
	do
		if [[ -f /usr/local/bin/${newcomm} ]]
		then
			echo -e "${red}Ошибка: эта команда уже существует в /usr/local/bin${clear}"
			echo ""
		elif [[ $newcomm =~ " " ]] || [[ $newcomm =~ '$' ]]
		then
			echo -e "${red}Ошибка: команда не должна содержать пробелы и \$${clear}"
			echo ""
		elif [[ -z $newcomm ]]
		then
			:
		fi
		echo -e "${textcolor}[?]${clear} Введите команду для нового прокси:"
		read newcomm
		[[ ! -z $newcomm ]] && echo ""
	done
}

check_command_del() {
	while [[ -z $delcomm ]] || [[ ! -f /usr/local/bin/${delcomm} ]]
	do
		if [[ -z $delcomm ]]
		then
			:
		else
			echo -e "${red}Ошибка: эта команда не существует в /usr/local/bin${clear}"
			echo ""
		fi
		echo -e "${textcolor}[?]${clear} Введите удаляемую команду для прокси или введите ${textcolor}x${clear}, чтобы выйти:"
		read delcomm
		[[ ! -z $delcomm ]] && echo ""
		exit_del_proxy
	done
}

show_proxies() {
	proxynum=$(cat /usr/local/bin/proxylist | wc -l)
	echo -e "${textcolor}Количество прокси:${clear} ${proxynum}"
	cat /usr/local/bin/proxylist | sed "s/#//g"
	echo ""
	main_menu
}

add_proxies() {
	while [[ $link != "x" ]] && [[ $link != "х" ]]
	do
		echo -e "${textcolor}[?]${clear} Введите ссылку на ваш клиентский конфиг или введите ${textcolor}x${clear}, чтобы выйти:"
		read link
		[[ ! -z $link ]] && echo ""
		exit_add_proxy
		check_link
		echo -e "${textcolor}[?]${clear} Введите команду для нового прокси:"
		read newcomm
		[[ ! -z $newcomm ]] && echo ""
		check_command_add

		touch /usr/local/bin/${newcomm}
		cat > /usr/local/bin/${newcomm} <<-EOF
		#!/bin/bash
		textcolor='\033[1;34m'
		red='\033[1;31m'
		clear='\033[0m'
		if [[ \$EUID -ne 0 ]]
		then
		    echo ""
		    echo -e "\${red}Ошибка: эту команду нужно запускать с sudo или от имени root\${clear}"
		    echo ""
		    exit 1
		fi
		wget -q -O /etc/sing-box/config.json ${link}
		systemctl start sing-box.service
		echo ""
		echo -e "\${textcolor}Sing-Box запущен\${clear}"
		echo "Не закрывайте это окно, пока Sing-Box работает"
		echo -e "Введите \${textcolor}x\${clear}, чтобы отключиться:"
		while [[ \$run != "x" ]] && [[ \$run != "х" ]]
		do
		    read run
		done
		run=""
		echo ""
		systemctl stop sing-box.service
		EOF
		chmod +x /usr/local/bin/${newcomm}
		echo "#${newcomm}" >> /usr/local/bin/proxylist

		echo -e "Команда ${textcolor}${newcomm}${clear} добавлена, используйте её для подключения к прокси"
		echo ""
	done

	main_menu
}

delete_proxies() {
	while [[ $delcomm != "x" ]] && [[ $delcomm != "х" ]]
	do
		echo -e "${textcolor}[?]${clear} Введите удаляемую команду для прокси или введите ${textcolor}x${clear}, чтобы выйти:"
		read delcomm
		[[ ! -z $delcomm ]] && echo ""
		exit_del_proxy
		check_command_del

		rm /usr/local/bin/${delcomm}
		sed -i "/#$delcomm/d" /usr/local/bin/proxylist
		echo -e "Команда ${textcolor}${delcomm}${clear} удалена"
		echo ""
	done

	main_menu
}

main_menu() {
	echo ""
	echo -e "${textcolor}Выберите действие:${clear}"
	echo "0 - Выйти"
	echo "1 - Вывести список прокси"
	echo "2 - Добавить новый прокси"
	echo "3 - Удалить прокси"
	read option
	echo ""

	case $option in
		1)
		show_proxies
		;;
		2)
		add_proxies
		;;
		3)
		delete_proxies
		;;
		*)
		exit 0
	esac
}

check_root
check_sbmanager
banner
install_sing_box
main_menu