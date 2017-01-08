#!/bin/sh

git clone https://github.com/Wolf2000Pi/wolf2000-tools.git &&
cd wolf2000-tools &&
chmod 777 wolf2000-config.sh omv-install-2.x.sh omv-install-3.x.sh &&
cp wolf2000-config.sh /usr/bin/wolf2000-config &&
cp /root/wolf2000-tools/omv-install-3.x.sh /root/wolf2000-tools/omv-install-2.x.sh /usr/bin &&
cd && 
wolf2000-config
