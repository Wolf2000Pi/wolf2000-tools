#!/bin/sh
#
echo
echo -e "\033[36m Autoinstaller für Wolf2000-Tools\033[0m"
echo
echo -e "\033[36m Author:     Wolf2000\033[0m"
echo -e "\033[36m Version:         1.0\033[0m"
echo -e "\033[36m https://forum-bpi.de\033[0m"
echo
echo -e "\033[32m Wollen sie Wolf2000-Tools installieren\033[0m"
echo -e "\033[32m Ihre Antwort, n/j:\033[0m"
read answer
#echo Das installieren wurde abgebrochen
echo  Ihre Antwort war: $answer
# if [ "$answer" = "j" ]
if [ "$answer" != "n" ]
 then chmod 777 wolf2000-config.sh omv-install-2.x.sh omv-install-3.x.sh resize.sh resizea.sh &&
sleep 1
cp deinstall-wolf2000-tools.sh /root/ &&
sleep 1
cp wolf2000-config.sh /usr/bin/wolf2000-config &&
sleep 1
cp omv-install-3.x.sh /usr/bin/omv-install-2.x.sh &&
sleep 1
cp omv-install-2.x.sh /usr/bin/omv-install-3.x.sh &&
sleep 1 
cp resize.sh /usr/bin/resize
sleep 1
cp resizea.sh /usr/bin/resizea
sleep 1
cd &&
sleep 1
chmod 777 deinstall-wolf2000-tools.sh &&
sleep 1
cd &&
wolf2000-config
echo
echo
echo -e "\033[32m Das wars Wolf2000-Tools\033[0m"
else echo -e "\033[31m Die Installation wurde abgebrochen\033[0m"
fi