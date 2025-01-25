#!/bin/bash

textcolor='\033[1;34m'
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

install_sing_box() {
	if [[ ! -f /usr/local/bin/proxylist ]]
	then
		touch /usr/local/bin/proxylist
	fi

	if [ $(sing-box version &> /dev/null; echo $?) -ne 0 ]
	then
		echo ""
		echo -e "${textcolor}Sing-Box is not installed${clear}"
		echo ""
		echo -e "${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to install it or enter ${textcolor}x${clear} to exit:"
		read sbinstall
		exit_install

		echo -e "${textcolor}Installing Sing-Box...${clear}"
		curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
		chmod a+r /etc/apt/keyrings/sagernet.asc
		echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | tee /etc/apt/sources.list.d/sagernet.list > /dev/null
		apt-get update
		apt-get install sing-box -y
		systemctl disable sing-box.service

		echo ""
		echo -e "${textcolor}Sing-Box is installed${clear}"
		echo ""
		echo -e "It can be updated with ${textcolor}apt-get install sing-box${clear} command"
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
	while [[ -z $link ]] || [[ "$(curl -s -o /dev/null -w "%{http_code}" ${link})" == "000" ]]
	do
		if [[ -z $link ]]
		then
			:
		else
			echo -e "${red}Error: the link is incorrect or the server is not available${clear}"
			echo ""
		fi
		echo -e "${textcolor}[?]${clear} Enter your client config link or enter ${textcolor}x${clear} to exit:"
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
			echo -e "${red}Error: this command already exists in /usr/local/bin${clear}"
			echo ""
		elif [[ $newcomm =~ " " ]] || [[ $newcomm =~ '$' ]]
		then
			echo -e "${red}Error: the command should not contain spaces and \$${clear}"
			echo ""
		elif [[ -z $newcomm ]]
		then
			:
		fi
		echo -e "${textcolor}[?]${clear} Enter the command for the new proxy:"
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
			echo -e "${red}Error: this command does not exist in /usr/local/bin${clear}"
			echo ""
		fi
		echo -e "${textcolor}[?]${clear} Enter the proxy command you want to delete or enter ${textcolor}x${clear} to exit:"
		read delcomm
		[[ ! -z $delcomm ]] && echo ""
		exit_del_proxy
	done
}

show_proxies() {
	proxynum=$(cat /usr/local/bin/proxylist | wc -l)
	echo -e "${textcolor}Number of proxies:${clear} ${proxynum}"
	cat /usr/local/bin/proxylist | sed "s/#//g"
	echo ""
	main_menu
}

add_proxies() {
	while [[ $link != "x" ]] && [[ $link != "х" ]]
	do
		echo -e "${textcolor}[?]${clear} Enter your client config link or enter ${textcolor}x${clear} to exit:"
		read link
		[[ ! -z $link ]] && echo ""
		exit_add_proxy
		check_link
		echo -e "${textcolor}[?]${clear} Enter the command for the new proxy:"
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
		    echo -e "\${red}Error: this command should be run with sudo or as root\${clear}"
		    echo ""
		    exit 1
		fi
		wget -q -O /etc/sing-box/config.json ${link}
		systemctl start sing-box.service
		echo ""
		echo -e "\${textcolor}Started Sing-Box\${clear}"
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
		echo "#${newcomm}" >> /usr/local/bin/proxylist

		echo -e "Command ${textcolor}${newcomm}${clear} has been added, use it to connect to the proxy"
		echo ""
	done

	main_menu
}

delete_proxies() {
	while [[ $delcomm != "x" ]] && [[ $delcomm != "х" ]]
	do
		echo -e "${textcolor}[?]${clear} Enter the proxy command you want to delete or enter ${textcolor}x${clear} to exit:"
		read delcomm
		[[ ! -z $delcomm ]] && echo ""
		exit_del_proxy
		check_command_del

		rm /usr/local/bin/${delcomm}
		sed -i "/#$delcomm/d" /usr/local/bin/proxylist
		echo -e "Command ${textcolor}${delcomm}${clear} has been deleted"
		echo ""
	done

	main_menu
}

main_menu() {
	echo ""
	echo -e "${textcolor}Select an option:${clear}"
	echo "0 - Exit"
    echo "1 - Show the list of proxies"
    echo "2 - Add a new proxy"
    echo "3 - Delete a proxy"
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
install_sing_box
main_menu