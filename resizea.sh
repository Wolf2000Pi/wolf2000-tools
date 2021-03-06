#!/bin/bash


fdisk_first() {
p1_start=`fdisk -l /dev/mmcblk0 | grep mmcblk0p1 | awk '{print $1}'`
echo "Found the start point of mmcblk0p1: $p1_start"
fdisk /dev/mmcblk0 << __EOF__ >> /dev/null
d
n
p
1
$p1_start


p
w
__EOF__

sync
touch /root/.resizea
echo "Ok, Partition wird vergrößert, Bitte machen sie einen reboot"
}

resizea_fs() {
echo "Activating the new size"
resize2fs /dev/mmcblk0p1 >> /dev/null
echo "Done!"
echo "Enjoy your new space!"
cd /etc/cron.d/
rm -r resizea2start
}

if [ -f /root/.resizea ]; then
resizea_fs
else
fdisk_first
fi

