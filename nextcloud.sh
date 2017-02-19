#!/bin/bash 

echo
echo -e "\033[36m Nextcloud\033[0m"
echo
echo -e "\033[36m Author:     Wolf2000\033[0m"
echo -e "\033[36m Version:         0.1\033[0m"
echo -e "\033[36m https://forum-bpi.de\033[0m"
echo
echo -e "\033[32m Wollen sie Nextcloud installieren\033[0m"
echo -e "\033[32m Ihre Antwort, n/j:\033[0m"
read answer
#echo Das installieren wurde abgebrochen
echo  Ihre Antwort war: $answer
# if [ "$answer" = "j" ]
if [ "$answer" != "n" ]
  then apt-get update &&
sleep 1
apt-get --yes --force-yes --allow-unauthenticated install apache2 php5 php5-gd sqlite php5-sqlite php5-curl &&
sleep 1
service apache2 restart &&
sleep 1
wget https://download.nextcloud.com/server/releases/nextcloud-11.0.1.zip &&
sleep 1
mv nextcloud-11.0.1.zip /var/www/html &&
sleep 1
cd /var/www/html &&
sleep 1
unzip -q nextcloud-11.0.1.zip &&
sleep 1
rm nextcloud-11.0.1.zip &&
sleep 1
mkdir -p /var/www/html/nextcloud/data &&
sleep 1
chown www-data:www-data /var/www/html/nextcloud/data &&
sleep 1
chmod 750 /var/www/html/nextcloud/data &&
sleep 1
cd /var/www/html/nextcloud &&
sleep 1
chown www-data:www-data config apps &&
sleep 1
init 6
echo
echo
echo -e "\033[32m Das wars Nextcloud Installiert\033[0m"
else echo -e "\033[31m Die Installation wurde abgebrochen\033[0m"
fi




