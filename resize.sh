#!/bin/bash

fdisk_first() {
p2_start=`fdisk -l /dev/mmcblk0 | grep mmcblk0p2 | awk '{print $2}'`
echo "Found the start point of mmcblk0p2: $p2_start"
fdisk /dev/mmcblk0 << __EOF__ >> /dev/null
d
2
n
p
2
$p2_start

p
w
__EOF__

sync
touch /root/.resize
echo "Ok, Partition wird vergrößert, Bitte machen sie einen reboot"
}

resize_fs() {
echo "Activating the new size"
resize2fs /dev/mmcblk0p2 >> /dev/null
echo "Done!"
echo "Enjoy your new space!"
rm -rf /root/.resize
cd /etc/cron.d/
rm -r resize2start
}

if [ -f /root/.resize ]; then
resize_fs
else
fdisk_first
fi
