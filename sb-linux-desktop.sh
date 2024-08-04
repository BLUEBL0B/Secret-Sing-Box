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

echo ""
echo -e "${textcolor}Select the language:${clear}"
echo "1 - Russian"
echo "2 - English"
read language
echo ""
if [[ "$language" == "1" ]]
then
	echo "Введите ссылку на ваш клиентский конфиг:"
	read link
	echo ""
	echo "Введите новую команду для этого прокси (и запомните её):"
	read newcomm
	echo ""
	if [ ! -d /etc/sing-box ]
	then
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
	echo -e "Введите команду \${textcolor}stop\${clear}, чтобы отключиться:"
	while [[ \$run != "stop" ]]
	do
	    read run
	done
	echo ""
	systemctl stop sing-box.service
	EOF
	chmod +x /usr/local/bin/${newcomm}
	echo -e "Вы можете использовать команду ${textcolor}${newcomm}${clear} для запуска Sing-Box и команду ${textcolor}sbupdate${clear} для его обновления"
	echo ""
	echo "Если вы хотите добавить больше клиентских конфигов, то запустите этот скрипт ещё раз"
else
	echo "Enter your client config link:"
	read link
	echo ""
	echo "Enter the new command for this proxy (and write it down):"
	read newcomm
	echo ""
	if [ ! -d /etc/sing-box ]
	then
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
	echo -e "Enter \${textcolor}stop\${clear} command to disconnect:"
	while [[ \$run != "stop" ]]
	do
	    read run
	done
	echo ""
	systemctl stop sing-box.service
	EOF
	chmod +x /usr/local/bin/${newcomm}
	echo -e "You can use ${textcolor}${newcomm}${clear} command to run Sing-Box and ${textcolor}sbupdate${clear} command to update it"
	echo ""
	echo "Run this script again if you want to add more client configs"
fi
echo ""
