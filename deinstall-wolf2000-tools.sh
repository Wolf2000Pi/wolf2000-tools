#!/bin/sh
#
echo
echo -e "\033[36m deinstaller für Wolf2000-Tools\033[0m"
echo
echo -e "\033[36m Author:     Wolf2000\033[0m"
echo -e "\033[36m Version:         1.0\033[0m"
echo -e "\033[36m https://forum-bpi.de\033[0m"
echo
echo -e "\033[32m Wollen sie Wolf2000-Tools Deinstallieren\033[0m"
echo -e "\033[32m Ihre Antwort, n/j:\033[0m"
read answer
#echo Das installieren wurde abgebrochen
echo  Ihre Antwort war: $answer
# if [ "$answer" = "j" ]
if [ "$answer" != "n" ]
 then rm -r wolf2000-tools && 
 rm -r deinstall-wolf2000-tools.sh &&
 cd /usr/bin/ && 
 rm -r omv-install-2.x.sh omv-install-3.x.sh wolf2000-config resize
echo
echo
echo -e "\033[32m Das wars Wolf2000-Tools ist Deinstalliert\033[0m"
else echo -e "\033[31m Die Installation wurde abgebrochen\033[0m"
fi
