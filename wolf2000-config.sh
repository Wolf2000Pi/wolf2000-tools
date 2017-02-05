#!/bin/sh
# Part of Wolf2000-Tools https://github.com/Wolf2000Pi/wolf2000-tools
# Version 3.9
# by Wolf2000

INTERACTIVE=True
ASK_TO_REBOOT=0
BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf
CONFIG=/boot/config.txt

calc_wt_size() {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error 
  # output from tput. However in this case, tput detects neither stdout or 
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=19
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

# $1 is 0 to disable overscan, 1 to disable it




do_change_pass() {
  whiptail --msgbox "You will now be asked to enter a new password for the pi user" 20 60 1
  passwd root &&
  whiptail --msgbox "Passwort wurde erfolgreich geändert" 20 60 1
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
Bitte beachten Sie: Das der Hostname!
Nur die ASCII-Buchstaben "a" bis "z" enthalten (Groß-und Kleinschreibung),
Die Ziffern '0' bis '9' und der Bindestrich.
Hostnamen-Labels können nicht mit einem Bindestrich beginnen oder enden.
Es sind keine anderen Symbole, Interpunktionszeichen oder Leerzeichen zulässig. 
\
" 20 70 1

  CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
  NEW_HOSTNAME=$(whiptail --inputbox "Please enter a hostname" 20 60 "$CURRENT_HOSTNAME" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
    ASK_TO_REBOOT=1
  fi
}

do_memory_split() { # Memory Split
  if [ -e /boot/start_cd.elf ]; then
    # New-style memory split setting
    if ! mountpoint -q /boot; then
      return 1
    fi
    ## get current memory split from /boot/config.txt
    CUR_GPU_MEM=$(get_config_var gpu_mem $CONFIG)
    [ -z "$CUR_GPU_MEM" ] && CUR_GPU_MEM=64
    ## ask users what gpu_mem they want
    NEW_GPU_MEM=$(whiptail --inputbox "How much memory should the GPU have?  e.g. 16/32/64/128/256" \
      20 70 -- "$CUR_GPU_MEM" 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then
      set_config_var gpu_mem "$NEW_GPU_MEM" $CONFIG
      ASK_TO_REBOOT=1
    fi
  else # Old firmware so do start.elf renaming
    get_current_memory_split
    MEMSPLIT=$(whiptail --menu "Set memory split.\n$MEMSPLIT_DESCRIPTION" 20 60 10 \
      "240" "240MiB for ARM, 16MiB for VideoCore" \
      "224" "224MiB for ARM, 32MiB for VideoCore" \
      "192" "192MiB for ARM, 64MiB for VideoCore" \
      "128" "128MiB for ARM, 128MiB for VideoCore" \
      3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then
      set_memory_split ${MEMSPLIT}
      ASK_TO_REBOOT=1
    fi
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

do_devicetree() {
  CURRENT_SETTING="enabled" # assume not disabled
  DEFAULT=
  if [ -e $CONFIG ] && grep -q "^device_tree=$" $CONFIG; then
    CURRENT_SETTING="disabled"
    DEFAULT=--defaultno
  fi

  whiptail --yesno "Would you like the kernel to use Device Tree?" $DEFAULT 20 60 2
  RET=$?
  if [ $RET -eq 0 ]; then
    sed $CONFIG -i -e "s/^\(device_tree=\)$/#\1/"
    sed $CONFIG -i -e "s/^#\(device_tree=.\)/\1/"
    SETTING=enabled
  elif [ $RET -eq 1 ]; then
    sed $CONFIG -i -e "s/^#\(device_tree=\)$/\1/"
    sed $CONFIG -i -e "s/^\(device_tree=.\)/#\1/"
    if ! grep -q "^device_tree=$" $CONFIG; then
      printf "device_tree=\n" >> $CONFIG
    fi
    SETTING=disabled
  else
    return 0
  fi
  TENSE=is
  REBOOT=
  if [ $SETTING != $CURRENT_SETTING ]; then
    TENSE="will be"
    REBOOT=" after a reboot"
    ASK_TO_REBOOT=1
  fi
  whiptail --msgbox "Device Tree $TENSE $SETTING$REBOOT" 20 60 1
}


disable_raspi_config_at_boot() {
  if [ -e /etc/profile.d/raspi-config.sh ]; then
    rm -f /etc/profile.d/raspi-config.sh
    sed -i /etc/inittab \
      -e "s/^#\(.*\)#\s*RPICFG_TO_ENABLE\s*/\1/" \
      -e "/#\s*RPICFG_TO_DISABLE/d"
    telinit q
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

do_finish() {
  disable_raspi_config_at_boot
  if [ $ASK_TO_REBOOT -eq 1 ]; then
    whiptail --yesno "Would you like to reboot now?" 20 60 2
    if [ $? -eq 0 ]; then # yes
      sync
      reboot
    fi
  fi
  exit 0
}

# $1 = filename, $2 = key name
get_json_string_val() {
  sed -n -e "s/^[[:space:]]*\"$2\"[[:space:]]*:[[:space:]]*\"\(.*\)\"[[:space:]]*,$/\1/p" $1
}

do_apply_os_config() {
  [ -e /boot/os_config.json ] || return 0
  NOOBSFLAVOUR=$(get_json_string_val /boot/os_config.json flavour)
  NOOBSLANGUAGE=$(get_json_string_val /boot/os_config.json language)
  NOOBSKEYBOARD=$(get_json_string_val /boot/os_config.json keyboard)

  if [ -n "$NOOBSFLAVOUR" ]; then
    printf "Setting flavour to %s based on os_config.json from NOOBS. May take a while\n" "$NOOBSFLAVOUR"

    if printf "%s" "$NOOBSFLAVOUR" | grep -q "Scratch"; then
      disable_raspi_config_at_boot
      enable_boot_to_scratch
    else
      printf "Unrecognised flavour. Ignoring\n"
    fi
  fi

  # TODO: currently ignores en_gb settings as we assume we are running in a 
  # first boot context, where UK English settings are default
  case "$NOOBSLANGUAGE" in
    "en")
      if [ "$NOOBSKEYBOARD" = "gb" ]; then
        DEBLANGUAGE="" # UK english is the default, so ignore
      else
        DEBLANGUAGE="en_US.UTF-8"
      fi
      ;;
    "de")
      DEBLANGUAGE="de_DE.UTF-8"
      ;;
    "fi")
      DEBLANGUAGE="fi_FI.UTF-8"
      ;;
    "fr")
      DEBLANGUAGE="fr_FR.UTF-8"
      ;;
    "hu")
      DEBLANGUAGE="hu_HU.UTF-8"
      ;;
    "ja")
      DEBLANGUAGE="ja_JP.UTF-8"
      ;;
    "nl")
      DEBLANGUAGE="nl_NL.UTF-8"
      ;;
    "pt")
      DEBLANGUAGE="pt_PT.UTF-8"
      ;;
    "ru")
      DEBLANGUAGE="ru_RU.UTF-8"
      ;;
    "zh_CN")
      DEBLANGUAGE="zh_CN.UTF-8"
      ;;
    *)
      printf "Language '%s' not handled currently. Run sudo raspi-config to set up" "$NOOBSLANGUAGE"
      ;;
  esac

  if [ -n "$DEBLANGUAGE" ]; then
    printf "Setting language to %s based on os_config.json from NOOBS. May take a while\n" "$DEBLANGUAGE"
    cat << EOF | debconf-set-selections
locales   locales/locales_to_be_generated multiselect     $DEBLANGUAGE UTF-8
EOF
    rm /etc/locale.gen
    dpkg-reconfigure -f noninteractive locales
    update-locale LANG="$DEBLANGUAGE"
    cat << EOF | debconf-set-selections
locales   locales/default_environment_locale select       $DEBLANGUAGE
EOF
  fi

  if [ -n "$NOOBSKEYBOARD" -a "$NOOBSKEYBOARD" != "gb" ]; then
    printf "Setting keyboard layout to %s based on os_config.json from NOOBS. May take a while\n" "$NOOBSKEYBOARD"
    sed -i /etc/default/keyboard -e "s/^XKBLAYOUT.*/XKBLAYOUT=\"$NOOBSKEYBOARD\"/"
    dpkg-reconfigure -f noninteractive keyboard-configuration
    invoke-rc.d keyboard-setup start
  fi
  return 0
}

#
# Command line options for non-interactive use
#
for i in $*
do
  case $i in
  --memory-split)
    OPT_MEMORY_SPLIT=GET
    printf "Not currently supported\n"
    exit 1
    ;;
  --memory-split=*)
    OPT_MEMORY_SPLIT=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
    printf "Not currently supported\n"
    exit 1
    ;;
  --expand-rootfs)
    INTERACTIVE=False
    do_expand_rootfs
    printf "Please reboot\n"
    exit 0
    ;;
  --apply-os-config)
    INTERACTIVE=False
    do_apply_os_config
    exit $?
    ;;
  *)
    # unknown option
    ;;
  esac
done

#if [ "GET" = "${OPT_MEMORY_SPLIT:-}" ]; then
#  set -u # Fail on unset variables
#  get_current_memory_split
#  echo $CURRENT_MEMSPLIT
#  exit 0
#fi

# Everything else needs to be run as root
if [ $(id -u) -ne 0 ]; then
  printf "Script must be run as root. Try 'sudo raspi-config'\n"
  exit 1
fi

if [ -n "${OPT_MEMORY_SPLIT:-}" ]; then
  set -e # Fail when a command errors
  set_memory_split "${OPT_MEMORY_SPLIT}"
  exit 0
fi

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

do_Openmediavault_menu() {
  FUN=$(whiptail --title "Banana Pi Software Configuration Tool (Wolf2000-config)" --menu "Openmediavault Optionen" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
	"O1 Openmediavault Version 2"     "Installation Unter Debian Wheezy" \
    "O2 Openmediavault Version 3"     "Installation Unter Debian Jessie" \
    "O3 Openmediavault Plugins"       "resetperms locate apttool sensors " \
	"O4 Openmediavault MiniDLNA"      "Medienserver für DLNA/UPnP-Geräte" \
	"O5 Openmediavault Remotedesktop" "Desktop XFCE (Remote Desktop)" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      O1\ *) do_omv2 ;;
      O2\ *) do_omv3 ;;
      O3\ *) do_omv_plugins ;;
	  O4\ *) do_omv_minidlna ;;
	  O5\ *) do_omv_remotedesktop ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

do_omv_plugins() {
apt-get --yes --force-yes --allow-unauthenticated install openmediavault-resetperms openmediavault-locate openmediavault-apttool openmediavault-sensors 
exec wolf2000-config
}

do_omv_minidlna() {
apt-get --yes --force-yes --allow-unauthenticated install openmediavault-minidlna
exec wolf2000-config
}

do_omv_remotedesktop() {
apt-get --yes --force-yes --allow-unauthenticated install openmediavault-remotedesktop
exec wolf2000-config
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
#  chmod +x omv-install-3.x.sh
  omv-install-3.x.sh
  printf "Einen Moment ich starte in 1Sek Wolf2000-config\n" &&
  sleep 1 &&
  exec wolf2000-config
}

do_omv2() {
#  chmod +x omv-install-2.x.sh
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
  chmod +x wolf2000-config.sh omv-install-2.x.sh omv-install-3.x.sh &&
  cd /usr/bin/ &&
  rm -r omv-install-2.x.sh omv-install-3.x.sh wolf2000-config &&
  cp /root/wolf2000-tools/wolf2000-config.sh /usr/bin/wolf2000-config &&
  cp /root/wolf2000-tools/omv-install-3.x.sh /root/wolf2000-tools/omv-install-2.x.sh /usr/bin &&
  cd &&
  exec wolf2000-config
}

do_resize() {
cp /root/wolf2000-tools/resize2start /etc/cron.d/
exec resize
}

do_resizea() {
cp /root/wolf2000-tools/resizea2start /etc/cron.d/
exec resizea
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
    "9 Resize 2" "Speicher vergößern für Images mit zwei Partionen" \
   "10 Resize 1" "Speicher vergößern für Images mit einer Partion" \
   "11 Tsest 1" "Test omv" \
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
	  9\ *) do_resize ;;
	 10\ *) do_resizea ;;
	 11\ *) do_Openmediavault_menu ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  else
    exit 1
  fi
done


