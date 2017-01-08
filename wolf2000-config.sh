#!/bin/sh
# Part of Wolf2000-Tools https://github.com/Wolf2000Pi/wolf2000-tools
# Version 3.2
# by Wolf2000

INTERACTIVE=True
ASK_TO_REBOOT=0
BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf
#CONFIG=/boot/config.txt

calc_wt_size() {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error 
  # output from tput. However in this case, tput detects neither stdout or 
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=17
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}

do_about() {
  whiptail --msgbox "\
Habe mir das raspi-config hergenommen und verändert.
Ich hoffe ihr seid zufrieden?
Für Schäden übernehme ich Keine Haftung!
@Wolf2000.\
" 20 70 1
}

set_config_var() {
  lua - "$1" "$2" "$3" <<EOF > "$3.bak"
local key=assert(arg[1])
local value=assert(arg[2])
local fn=assert(arg[3])
local file=assert(io.open(fn))
local made_change=false
for line in file:lines() do
  if line:match("^#?%s*"..key.."=.*$") then
    line=key.."="..value
    made_change=true
  end
  print(line)
end

if not made_change then
  print(key.."="..value)
end
EOF
mv "$3.bak" "$3"
}

get_config_var() {
  lua - "$1" "$2" <<EOF
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
for line in file:lines() do
  local val = line:match("^#?%s*"..key.."=(.*)$")
  if (val ~= nil) then
    print(val)
    break
  end
end
EOF
}

do_change_pass() {
  whiptail --msgbox "You will now be asked to enter a new password for the pi user" 20 60 1
  passwd root &&
  whiptail --msgbox "Password changed successfully" 20 60 1
}

do_configure_keyboard() {
  dpkg-reconfigure keyboard-configuration &&
  printf "Reloading keymap. This may take a short while\n" &&
  invoke-rc.d keyboard-setup start
}

do_change_locale() {
  dpkg-reconfigure locales
}

do_change_timezone() {
  dpkg-reconfigure tzdata
}

do_change_hostname() {
  whiptail --msgbox "\
Please note: RFCs mandate that a hostname's labels \
may contain only the ASCII letters 'a' through 'z' (case-insensitive), 
the digits '0' through '9', and the hyphen.
Hostname labels cannot begin or end with a hyphen. 
No other symbols, punctuation characters, or blank spaces are permitted.\
" 20 70 1

  CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
  NEW_HOSTNAME=$(whiptail --inputbox "Please enter a hostname" 20 60 "$CURRENT_HOSTNAME" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
    ASK_TO_REBOOT=1
  fi
}

do_ssh() {
  if [ -e /var/log/regen_ssh_keys.log ] && ! grep -q "^finished" /var/log/regen_ssh_keys.log; then
    whiptail --msgbox "Initial ssh key generation still running. Please wait and try again." 20 60 2
    return 1
  fi
  whiptail --yesno "Would you like the SSH server enabled or disabled?" 20 60 2 \
    --yes-button Enable --no-button Disable
  RET=$?
  if [ $RET -eq 0 ]; then
    update-rc.d ssh enable &&
    invoke-rc.d ssh start &&
    whiptail --msgbox "SSH server enabled" 20 60 1
  elif [ $RET -eq 1 ]; then
    update-rc.d ssh disable &&
    whiptail --msgbox "SSH server disabled" 20 60 1
  else
    return $RET
  fi
}

do_audio() {
  AUDIO_OUT=$(whiptail --menu "Choose the audio output" 20 60 10 \
    "0" "Auto" \
    "1" "Force 3.5mm ('headphone') jack" \
    "2" "Force HDMI" \
    3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    amixer cset numid=3 "$AUDIO_OUT"
  fi
}

do_internationalisation_menu() {
  FUN=$(whiptail --title "Banana Pi Software Configuration Tool (Wolf2000-config)" --menu "Internationalisation Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "I1 Change Locale" "Wo bist Du zu Hause" \
    "I2 Change Timezone" "Meine Uhr geht nach der Wiener Wasserleitungen" \
    "I3 Change Keyboard Layout" "Tastatur-Einstellungen" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      I1\ *) do_change_locale ;;
      I2\ *) do_change_timezone ;;
      I3\ *) do_configure_keyboard ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

do_advanced_menu() {
  FUN=$(whiptail --title "Banana Pi Software Configuration Tool (Wolf2000-config)" --menu "Advanced Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "A1 Hostname" "Setzen Sie den sichtbaren Namen für die Pi im Netzwerk" \
    "A2 SSH" "Enable/Disable ein/aus um sich mit dem Putty zu verbinden zu können" \
    "A3 Audio" "Sucht audio einstellung für HDMI oder 3.5mm jack" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      A1\ *) do_change_hostname ;;
      A2\ *) do_ssh ;;
      A3\ *) do_audio ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

do_omv3() {
  chmod 777 omv-install-3.x.sh
  omv-install-3.x.sh
  printf "Einen Moment ich starte in 1Sek Wolf2000-config\n" &&
  sleep 1 &&
  exec wolf2000-config
}

do_omv2() {
  chmod 777 omv-install-2.x.sh
  omv-install-2.x.sh
  printf "Einen Moment ich starte in 1Sek Wolf2000-config\n" &&
  sleep 1 &&
  exec wolf2000-config
}

do_update() {
  apt-get update &&
  apt-get upgrade &&
  printf "Einen Moment ich starte in 1Sek Wolf2000-config\n" &&
  sleep 1 &&
  exec wolf2000-config
}

do_update_wolf2000() {
  rm -r /root/wolf2000-tools/ &&
  git clone https://github.com/Wolf2000Pi/wolf2000-tools.git &&
  cd /root/wolf2000-tools &&
  chmod 777 wolf2000-config.sh omv-install-2.x.sh omv-install-3.x.sh &&
  cd /usr/bin/ &&
  rm -r omv-install-2.x.sh omv-install-3.x.sh wolf2000-config &&
  cp /root/wolf2000-tools/wolf2000-config.sh /usr/bin/wolf2000-config &&
  cp /root/wolf2000-tools/omv-install-3.x.sh /root/wolf2000-tools/omv-install-2.x.sh /usr/bin &&
  cd &&
  exec wolf2000-config
}

#
# Interactive use loop
#
calc_wt_size
while true; do
  FUN=$(whiptail --title "Banana Pi Software Configuration Tool (Wolf2000-config)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
    "1 Change User Password" "Root Password ändern" \
    "2 Internationalisation Options" "Sprache-Zeit-Tastatur " \
    "3 Advanced Options" "Configure advanced settings" \
	"4 Update System" "Update und upgrade" \
	"5 Openmediavault Version 2" "Installation Unter Debian Wheezy" \
	"6 Openmediavault Version 3" "Installation Unter Debian Jessie" \
	"7 About wolf2000-config" "Bitte Lesen" \
	"8 Update" "Wolf2000-Tools Updaten" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    do_finish
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      1\ *) do_change_pass ;;
      2\ *) do_internationalisation_menu ;;
      3\ *) do_advanced_menu ;;
      4\ *) do_update ;;
	  5\ *) do_omv2 ;;
	  6\ *) do_omv3 ;;
	  7\ *) do_about ;;
	  8\ *) do_update_wolf2000 ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  else
    exit 1
  fi
done


