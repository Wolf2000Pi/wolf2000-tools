#!/bin/sh
#
echo
echo -e "\033[36m Autoinstaller für Wolf2000-Tools\033[0m"
echo
echo -e "\033[36m Author:     Wolf2000\033[0m"
echo -e "\033[36m Version:         1.0\033[0m"
echo -e "\033[36m https://forum-bpi.de\033[0m"
echo
echo -e "\033[32m Wolle sie Wolf2000-Tools installieren\033[0m"
echo -e "\033[32m Ihre Antwort, n/j:\033[0m"
read answer
#echo Das installieren wurde abgebrochen
echo  Ihre Antwort war: $answer
# if [ "$answer" = "j" ]
if [ "$answer" != "n" ]
 then git clone https://github.com/Wolf2000Pi/wolf2000-tools.git &&
sleep 1
cd /root/wolf2000-tools &&
sleep 1
chmod 777 wolf2000-config.sh omv-install-2.x.sh omv-install-3.x.sh deinstall-wolf2000-tools.sh install-wolf2000-tools.sh &&
sleep 1
cp wolf2000-tools/deinstall-wolf2000-tools.sh / &&
sleep 1
cp wolf2000-config.sh /usr/bin/wolf2000-config &&
sleep 1
cp /root/wolf2000-tools/omv-install-3.x.sh /root/wolf2000-tools/omv-install-2.x.sh /usr/bin &&
sleep 1
cd &&
sleep 1
wolf2000-config
echo
echo
echo -e "\033[32m Das wars Wolf2000-Tools\033[0m"
else echo -e "\033[31m Die Installation wurde abgebrochen\033[0m"
fi