#!/bin/bash

textcolor='\033[0;36m'
red='\033[1;31m'
clear='\033[0m'

check_root() {
	if [[ $EUID -ne 0 ]]
	then
		echo ""
		echo -e "${red}Error: this script should be run as root, use \"sudo -i\" command${clear}"
		echo ""
		exit 1
	fi
}

enter_language() {
	echo ""
	echo -e "${textcolor}Select the language:${clear}"
	echo "1 - Russian"
	echo "2 - English"
	read language
	echo ""
}

enter_data_ru() {
	while [[ -z $link ]]
	do
		echo -e "${textcolor}[?]${clear} Введите ссылку на ваш клиентский конфиг:"
		read link
		echo ""
	done
	echo -e "${textcolor}[?]${clear} Введите новую команду для этого прокси (и запомните её):"
	read newcomm
	echo ""
	while [ -f /usr/local/bin/${newcomm} ] || [[ -z $newcomm ]]
	do
		if [ -f /usr/local/bin/${newcomm} ]
		then
			echo -e "${red}Ошибка: эта команда уже существует в /usr/local/bin${clear}"
			echo ""
		elif [[ -z $newcomm ]]
		then
			:
		fi
		echo -e "${textcolor}[?]${clear} Введите новую команду для этого прокси (и запомните её):"
		read newcomm
		echo ""
	done
}

create_sbupdate_ru() {
	if [ ! -d /etc/sing-box ]
	then
		echo "Установка Sing-Box..."
		echo ""
		touch /usr/local/bin/sbupdate
		cat > /usr/local/bin/sbupdate <<-EOF
		#!/bin/bash
		red='\033[1;31m'
		clear='\033[0m'
		if [[ \$EUID -ne 0 ]]
		then
		    echo ""
		    echo -e "\${red}Ошибка: эту команду нужно запускать от имени root\${clear}"
		    echo ""
		    exit 1
		fi
		curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
		chmod a+r /etc/apt/keyrings/sagernet.asc
		echo "deb [arch=\`dpkg --print-architecture\` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | tee /etc/apt/sources.list.d/sagernet.list > /dev/null
		apt-get update
		apt-get install sing-box -y
		systemctl disable sing-box.service
		EOF
		chmod +x /usr/local/bin/sbupdate
		sbupdate
		echo ""
		echo "Sing-Box установлен"
		echo ""
	fi
}

create_proxy_command_ru() {
	touch /usr/local/bin/${newcomm}
	cat > /usr/local/bin/${newcomm} <<-EOF
	#!/bin/bash
	textcolor='\033[1;36m'
	red='\033[1;31m'
	clear='\033[0m'
	if [[ \$EUID -ne 0 ]]
	then
	    echo ""
	    echo -e "\${red}Ошибка: эту команду нужно запускать от имени root\${clear}"
	    echo ""
	    exit 1
	fi
	curl -s -o /etc/sing-box/config.json ${link}
	systemctl start sing-box.service
	echo ""
	echo "Sing-Box запущен"
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
}

message_ru() {
	echo -e "Вы можете использовать команду ${textcolor}${newcomm}${clear} для подключения к прокси и команду ${textcolor}sbupdate${clear} для обновления Sing-Box"
	echo ""
	echo "Если вы хотите добавить больше клиентских конфигов, то запустите этот скрипт ещё раз"
	echo ""
}

enter_data_en() {
	while [[ -z $link ]]
	do
		echo -e "${textcolor}[?]${clear} Enter your client config link:"
		read link
		echo ""
	done
	echo -e "${textcolor}[?]${clear} Enter the new command for this proxy (and remember it):"
	read newcomm
	echo ""
	while [ -f /usr/local/bin/${newcomm} ] || [[ -z $newcomm ]]
	do
		if [ -f /usr/local/bin/${newcomm} ]
		then
			echo -e "${red}Error: this command already exists in /usr/local/bin${clear}"
			echo ""
		elif [[ -z $newcomm ]]
		then
			:
		fi
		echo -e "${textcolor}[?]${clear} Enter the new command for this proxy (and remember it):"
		read newcomm
		echo ""
	done
}

create_sbupdate_en() {
	if [ ! -d /etc/sing-box ]
	then
		echo "Installing Sing-Box..."
		echo ""
		touch /usr/local/bin/sbupdate
		cat > /usr/local/bin/sbupdate <<-EOF
		#!/bin/bash
		red='\033[1;31m'
		clear='\033[0m'
		if [[ \$EUID -ne 0 ]]
		then
		    echo ""
		    echo -e "\${red}Error: this command should be run as root\${clear}"
		    echo ""
		    exit 1
		fi
		curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
		chmod a+r /etc/apt/keyrings/sagernet.asc
		echo "deb [arch=\`dpkg --print-architecture\` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | tee /etc/apt/sources.list.d/sagernet.list > /dev/null
		apt-get update
		apt-get install sing-box -y
		systemctl disable sing-box.service
		EOF
		chmod +x /usr/local/bin/sbupdate
		sbupdate
		echo ""
		echo "Sing-Box is installed"
		echo ""
	fi
}

create_proxy_command_en() {
	touch /usr/local/bin/${newcomm}
	cat > /usr/local/bin/${newcomm} <<-EOF
	#!/bin/bash
	textcolor='\033[1;36m'
	red='\033[1;31m'
	clear='\033[0m'
	if [[ \$EUID -ne 0 ]]
	then
	    echo ""
	    echo -e "\${red}Error: this command should be run as root\${clear}"
	    echo ""
	    exit 1
	fi
	curl -s -o /etc/sing-box/config.json ${link}
	systemctl start sing-box.service
	echo ""
	echo "Started Sing-Box"
	echo "Do not close this window while Sing-Box is running"
	echo -e "Enter \${textcolor}x\${clear} to disconnect:"
	while [[ \$run != "x" ]] && [[ \$run != "х" ]]
	do
	    read run
	done
	run=""
	echo ""
	systemctl stop sing-box.service
	EOF
	chmod +x /usr/local/bin/${newcomm}
}

message_en() {
	echo -e "You can use ${textcolor}${newcomm}${clear} command to connect to the proxy and ${textcolor}sbupdate${clear} command to update Sing-Box"
	echo ""
	echo "Run this script again if you want to add more client configs"
	echo ""
}

check_root
enter_language
if [[ "$language" == "1" ]]
then
	enter_data_ru
	create_sbupdate_ru
	create_proxy_command_ru
	message_ru
else
	enter_data_en
	create_sbupdate_en
	create_proxy_command_en
	message_en
fi
