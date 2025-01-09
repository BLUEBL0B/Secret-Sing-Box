#!/bin/bash

rulesetpath=$(grep "alias /var/www/" /etc/nginx/nginx.conf | head -n 1)
rulesetpath=${rulesetpath#*"alias /var/www/"}
rulesetpath=${rulesetpath%"/;"*}

rulesetlist=$(ls -A1 /var/www/${rulesetpath} | grep -v ".1")

for k in $(seq 1 $(echo "$rulesetlist" | wc -l))
do
    ruleset=$(echo "$rulesetlist" | sed -n "${k}p")
    wget -q -O /var/www/${rulesetpath}/${ruleset}.1 https://github.com/SagerNet/sing-geosite/raw/rule-set/${ruleset}
    if [ $? -eq 0 ]
    then
        mv -f /var/www/${rulesetpath}/${ruleset}.1 /var/www/${rulesetpath}/${ruleset}
    fi
done

wget -q -O /var/www/${rulesetpath}/torrent-clients.json.1 https://raw.githubusercontent.com/FPPweb3/sb-rule-sets/main/torrent-clients.json

if [ $? -eq 0 ]
then
    mv -f /var/www/${rulesetpath}/torrent-clients.json.1 /var/www/${rulesetpath}/torrent-clients.json
fi

wget -q -O /var/www/${rulesetpath}/geoip-ru.srs.1 https://github.com/SagerNet/sing-geoip/raw/rule-set/geoip-ru.srs

if [ $? -eq 0 ]
then
    mv -f /var/www/${rulesetpath}/geoip-ru.srs.1 /var/www/${rulesetpath}/geoip-ru.srs
fi
