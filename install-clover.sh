#!/bin/bash

clear


echo Clover Dual Boot Install Script for SteamOS and Bazzite
echo Created by ryanrudolf, extended by Hooandee
echo Doing preliminary sanity checks ...
sleep 2

# define variables here
CLOVER=$(efibootmgr | grep -i Clover | colrm 9 | colrm 1 4)
REFIND=$(efibootmgr | grep -i rEFInd | colrm 9 | colrm 1 4)
ESP=$(df /dev/nvme0n1p1 --output=avail | tail -n1)
CLOVER_VERSION=5172
CLOVER_URL=https://github.com/CloverHackyColor/CloverBootloader/releases/download/$CLOVER_VERSION/Clover-$CLOVER_VERSION-X64.iso.7z
CLOVER_ARCHIVE=$(curl -s -O -L -w "%{filename_effective}" $CLOVER_URL)
CLOVER_BASE=$(basename -s .7z $CLOVER_ARCHIVE)
CLOVER_EFI=\\EFI\\clover\\cloverx64.efi
BOARD_NAME=$(cat /sys/class/dmi/id/board_name)
PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name)

# every supported handheld except the Steam Deck needs the XBOX 360 controller
# UEFI driver so its built-in gamepad works inside the Clover boot menu
XPAD_DRIVER=yes

# helper - write a screen resolution (eg 1920x1080) into the Clover config.plist
set_resolution() {
	sed -i '/<key>ScreenResolution<\/key>/!b;n;c\\t\t<string>'"$1"'<\/string>' custom/config.plist
}

# helper - detect the internal panel native resolution from the kernel (works
# without a display server). Handheld panels are frequently mounted rotated, so
# the result is normalized to landscape (width >= height) which is what Clover wants.
detect_native_resolution() {
	local modes res w h
	for modes in /sys/class/drm/*eDP*/modes /sys/class/drm/*DSI*/modes /sys/class/drm/*LVDS*/modes
	do
		[ -f "$modes" ] || continue
		res=$(head -n1 "$modes" 2> /dev/null)
		case "$res" in
			*x*) ;;
			*) continue ;;
		esac
		w=${res%%x*}
		h=${res##*x}
		case "$w$h" in
			*[!0-9]*) continue ;;
		esac
		if [ "$h" -gt "$w" ]
		then
			echo "${h}x${w}"
		else
			echo "${w}x${h}"
		fi
		return 0
	done
	return 1
}

# load the device registry and match this device by its DMI strings
if [ ! -f custom/device-registry.sh ]
then
	echo Error: custom/device-registry.sh not found - run this script from the repo directory.
	exit
fi
. custom/device-registry.sh
DEVICE_MATCH=$(lookup_device "$BOARD_NAME" "$PRODUCT_NAME")

if [ -n "$DEVICE_MATCH" ]
then
	DEVICE_NAME=${DEVICE_MATCH%|*}
	DEVICE_ACTION=${DEVICE_MATCH##*|}
	case "$DEVICE_ACTION" in
		blocked)
			echo Script is running on unsupported model - $DEVICE_NAME.
			echo Unsupported device! Exiting immediately.
			exit
			;;
		nodriver)
			echo Script is running on supported model - $DEVICE_NAME.
			echo No further edits needed to the config.plist.
			XPAD_DRIVER=no
			;;
		*)
			echo Script is running on supported model - $DEVICE_NAME.
			echo Creating config specific for $DEVICE_NAME.
			set_resolution "$DEVICE_ACTION"
			;;
	esac

# unknown device - fall back to generic handheld mode (experimental)
else
	echo ----------------------------------------------------------------------
	echo This device is not in the tested list:
	echo "    board_name   : $BOARD_NAME"
	echo "    product_name : $PRODUCT_NAME"
	echo ----------------------------------------------------------------------
	echo Clover can still be installed in generic handheld mode.
	echo Only continue if this is an x86 handheld / mini PC that you want to dual boot.
	AUTO_RES=$(detect_native_resolution)
	if [ -n "$AUTO_RES" ]
	then
		echo Auto-detected native screen resolution: $AUTO_RES
	else
		echo Could not auto-detect the resolution - the Clover default 1280x800 will be used.
		echo You can change it later from the Clover Toolbox.
	fi
	if [ "${CLOVER_NONINTERACTIVE:-}" = 1 ]
	then
		GENERIC_CONFIRM=y
	else
		read -p "Proceed in generic handheld mode? (y/N): " GENERIC_CONFIRM
	fi
	if [ "$GENERIC_CONFIRM" != "y" ] && [ "$GENERIC_CONFIRM" != "Y" ]
	then
		echo Aborting at user request.
		exit
	fi
	if [ -n "$AUTO_RES" ]
	then
		echo Creating config for generic handheld using $AUTO_RES.
		set_resolution "$AUTO_RES"
	fi
fi

# check if Bazzite or SteamOS
grep -i bazzite /etc/os-release &> /dev/null
if [ $? -eq 0 ]
then
	OS=bazzite
	EFI_PATH=/boot/efi/EFI
	BOOTX64=$EFI_PATH/BOOT/BOOTX64.EFI
	echo Script is running on supported OS - $OS.
else
	grep -i SteamOS /etc/os-release &> /dev/null
	if [ $? -eq 0 ]
	then
		OS=SteamOS
		EFI_PATH=/esp/efi
		BOOTX64=$EFI_PATH/boot/bootx64.efi
		echo Script is running on supported OS - $OS.
	else
		echo This is neither Bazzite nor SteamOS!
		echo Exiting immediately!
		exit
	fi
fi

# check if  dual boot configuration is supported
blkid | grep nvme0n1p1\: | grep Microsoft
if [ $? -eq 0 ]
then
	echo Unsupported dual boot configuration detected.
	echo Make sure $OS is installed before Windows!
	exit
else
	echo Dual boot configuration supported.
fi

if [ -n "${CLOVER_SUDO_PASS:-}" ]
then
	current_password="$CLOVER_SUDO_PASS"
	echo -e "$current_password\n" | sudo -S ls &> /dev/null
	if [ $? -eq 0 ]
	then
		echo Sudo password is good!
	else
		echo Sudo password is wrong! Exiting.
		exit
	fi
elif [ "$(passwd --status $(whoami) | tr -s " " | cut -d " " -f 2)" == "P" ]
then
	read -s -p "Please enter current sudo password: " current_password ; echo
	echo Checking if the sudo password is correct.
	echo -e "$current_password\n" | sudo -S ls &> /dev/null

	if [ $? -eq 0 ]
	then
		echo Sudo password is good!
	else
		echo Sudo password is wrong! Re-run the script and make sure to enter the correct sudo password!
		exit
	fi
else
	echo Sudo password is blank! Setup a sudo password first and then re-run script!
	passwd
	exit
fi

# sanity check - is there enough space on esp
mkdir ~/temp-ESP
echo -e "$current_password\n" | sudo -S mount /dev/nvme0n1p1 ~/temp-ESP
if [ $? -eq 0 ]
then
	echo ESP has been mounted.
else
	echo Error mounting ESP.
	rmdir ~/temp-ESP
	exit
fi

if [ $ESP -ge 15000 ]
then
	echo ESP partition has $ESP KB free space.
	echo ESP partition has enough free space.
	echo -e "$current_password\n" | sudo -S umount ~/temp-ESP
	rmdir ~/temp-ESP
else
	echo ESP partition has $ESP KB free space.
	echo Not enough space on the ESP partition!
 	echo -e "$current_password\n" | sudo -S du -hd2 /esp
	echo -e "$current_password\n" | sudo -S umount ~/temp-ESP
	rmdir ~/temp-ESP
	exit
fi

# sanity check - is rEFInd installed?
efibootmgr | grep -i refind
if [ $? -ne 0 ]
then
	echo rEFInd is not detected! Proceeding with the Clover install.
else
	echo rEFInd seems to be installed! Performing best effort to uninstall rEFInd!
	for rEFInd_boot in $REFIND
	do
		echo -e "$current_password\n" | sudo -S efibootmgr -b $rEFInd_boot -B &> /dev/null
	done
	echo -e "$current_password\n" | sudo -S systemctl disable bootnext-refind.service &> /dev/null
	echo -e "$current_password\n" | sudo -S systemctl disable rEFInd_bg_randomizer.service
	echo -e "$current_password\n" | sudo -S rm -rf $EFI_PATH/refind &> /dev/null
	echo -e "$current_password\n" | sudo -S steamos-readonly disable
	echo -e "$current_password\n" | sudo -S rm /etc/systemd/system/bootnext-refind.service &> /dev/null
	echo -e "$current_password\n" | sudo -S rm -f /etc/systemd/system/rEFInd_bg_randomizer.service
	echo -e "$current_password\n" | sudo -S pacman-key --init
	echo -e "$current_password\n" | sudo -S pacman-key --populate archlinux
	echo -e "$current_password\n" | sudo -S pacman -R --noconfirm SteamDeck_rEFInd
	echo -e "$current_password\n" | sudo -S steamos-readonly enable
	rm -fr ~/.local/SteamDeck_rEFInd
	rm -rf ~/.SteamDeck_rEFInd &> /dev/null
	rm -f ~/Desktop/SteamDeck_rEFInd.desktop

	# check again if rEFInd is gone?
	efibootmgr | grep -i refind
	if [ $? -ne 0 ]
	then
		echo rEFInd has been successfully uninstalled! Proceeding with the Clover install.
	else
		echo rEFInd is still installed. Please manually uninstall rEFInd first!
		exit
	fi
fi

# obtain Clover ISO
7z x $CLOVER_ARCHIVE -aoa $CLOVER_BASE &> /dev/null
if [ $? -eq 0 ]
then
	echo Clover has been downloaded from the github repo!
else
	echo Error downloading Clover!
	exit
fi

# mount Clover ISO
mkdir ~/temp-clover &> /dev/null
echo -e "$current_password\n" | sudo -S mount $CLOVER_BASE ~/temp-clover &> /dev/null
if [ $? -eq 0 ]
then
	echo Clover ISO has been mounted!
else
	echo Error mounting ISO!
	echo -e "$current_password\n" | sudo -S umount ~/temp-clover
	rmdir ~/temp-clover
	exit
fi

# copy Clover files to EFI system partition
echo -e "$current_password\n" | sudo -S cp -Rf ~/temp-clover/efi/clover $EFI_PATH
echo -e "$current_password\n" | sudo -S cp custom/config.plist $EFI_PATH/clover/config.plist
echo -e "$current_password\n" | sudo -S cp -Rf custom/themes/* $EFI_PATH/clover/themes
echo -e "$current_password\n" | sudo -S rm -rf $EFI_PATH/clover/themes/{bgm,cesium,christmas,glass,purple_swirl,theme-sample.plist}

# copy the XBOX 360 controller UEFI driver for every handheld except the Steam Deck
# (the Steam Deck's built-in controller already works in Clover without it)
if [ "$XPAD_DRIVER" = "yes" ]
then
	echo Installing XBOX 360 controller UEFI driver so the built-in gamepad works in Clover.
	echo -e "$current_password\n" | sudo -S cp custom/UsbXbox360Dxe.efi $EFI_PATH/clover/drivers/uefi
	if [ $? -eq 0 ]
	then
		echo Successfully installed XBOX 360 UEFI driver.
	else
		echo Error installing XBOX 360 UEFI driver.
		exit
	fi
else
	echo Script is running on a Steam Deck.
	echo XBOX 360 UEFI driver not needed.
fi

# delete temp directories created and delete the Clover ISO
echo -e "$current_password\n" | sudo -S umount ~/temp-clover
rmdir ~/temp-clover
rm Clover-$CLOVER_VERSION-X64.iso*

# remove previous Clover entries before re-creating them
for entry in $CLOVER
do
	echo -e "$current_password\n" | sudo -S efibootmgr -b $entry -B &> /dev/null
done

# install Clover to the EFI system partition
echo -e "$current_password\n" | sudo -S efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Clover - GUI Boot Manager" -l "$CLOVER_EFI" &> /dev/null

# check if bootx64.efi.orig already exists
echo -e "$current_password\n" | sudo -S test -e $BOOTX64.orig
if [ $? -eq 0 ]
then
	echo $BOOTX64.orig found - no action needed.
else
	echo $BOOTX64 backup not found.
	echo -e "$current_password\n" | sudo -S cp $BOOTX64 $BOOTX64.orig
	echo -e "$current_password\n" | sudo -S cp $EFI_PATH/clover/cloverx64.efi $BOOTX64
	echo Copy Clover EFI to $BOOTX64 - done.
fi

# check if Windows EFI needs to be disabled!
echo -e "$current_password\n" | sudo -S test -e $EFI_PATH/Microsoft/Boot/bootmgfw.efi.orig
if [ $? -eq 0 ]
then
	echo Windows EFI backup exists. Check if Windows EFI needs to be disabled.
	echo -e "$current_password\n" | sudo -S test -e $EFI_PATH/Microsoft/Boot/bootmgfw.efi
	if [ $? -eq 0 ]
	then
		echo -e "$current_password\n" | sudo -S mv $EFI_PATH/Microsoft/Boot/bootmgfw.efi $EFI_PATH/Microsoft/bootmgfw.efi &> /dev/null
		echo Windows EFI needs to be disabled - done.
	else
		echo Windows EFI is already disabled - no action needed.
	fi
else
	echo Windows EFI backup does not exist.
	echo -e "$current_password\n" | sudo -S cp $EFI_PATH/Microsoft/Boot/bootmgfw.efi $EFI_PATH/Microsoft/Boot/bootmgfw.efi.orig &> /dev/null
	echo -e "$current_password\n" | sudo -S mv $EFI_PATH/Microsoft/Boot/bootmgfw.efi $EFI_PATH/Microsoft/bootmgfw.efi &> /dev/null
	echo Windows EFI needs to be disabled - done.
fi

# re-arrange the boot order and make Clover the priority!
echo -e "$current_password\n" | sudo -S efibootmgr -n $CLOVER &> /dev/null
echo -e "$current_password\n" | sudo -S efibootmgr -o $CLOVER &> /dev/null

# Final sanity check
efibootmgr | grep "Clover - GUI" &> /dev/null
if [ $? -eq 0 ]
then
	echo Clover has been successfully installed to the EFI system partition!
else
	echo Whoopsie something went wrong. Clover is not installed.
	exit
fi

# create ~/1Clover-tools and place the scripts in there
mkdir ~/1Clover-tools &> /dev/null
rm -f ~/1Clover-tools/* &> /dev/null
cp custom/Clover-Toolbox.sh ~/1Clover-tools &> /dev/null
echo -e "$current_password\n" | sudo -S cp custom/clover-bootmanager.service custom/clover-bootmanager.sh /etc/systemd/system
cp -R custom/logos ~/1Clover-tools &> /dev/null
cp -R custom/efi ~/1Clover-tools &> /dev/null
cp clover-ctl ~/1Clover-tools &> /dev/null
cp -R gui ~/1Clover-tools &> /dev/null
cp -R decky ~/1Clover-tools &> /dev/null

# make the scripts executable
chmod +x ~/1Clover-tools/Clover-Toolbox.sh ~/1Clover-tools/clover-ctl ~/1Clover-tools/gui/clover-desktop
echo -e "$current_password\n" | sudo -S chmod +x /etc/systemd/system/clover-bootmanager.sh

# start the clover-bootmanager.service
echo -e "$current_password\n" | sudo -S systemctl daemon-reload
echo -e "$current_password\n" | sudo -S systemctl enable --now clover-bootmanager.service
echo -e "$current_password\n" | sudo -S /etc/systemd/system/clover-bootmanager.sh

# custom config if using SteamOS or Bazzite
if [ $OS = SteamOS ]
then
	echo Making final configuration for $OS.
	mkdir -p ~/.local/share/kservices5/ServiceMenus
	cp custom/open_as_root.desktop ~/.local/share/kservices5/ServiceMenus
	echo -e "$current_password\n" | sudo -S cp custom/clover-whitelist.conf /etc/atomic-update.conf.d
else
	echo Making final configuration for $OS.
	echo -e "$current_password\n" | sudo -S blkid | grep nvme0n1p1 | grep esp &> /dev/null
	if [ $? -eq 0 ]
	then
		echo ESP partition is already labeled - no action needed.
	else
		echo -e "$current_password\n" | sudo -S fatlabel /dev/nvme0n1p1 esp &> /dev/null
		echo ESP partition label has been completed.
	fi

	# set bazzite as the default boot in Clover config
	echo -e "$current_password\n" | sudo -S sed -i '/<key>DefaultLoader<\/key>/!b;n;c\\t\t<string>\\efi\\fedora\\shimx64\.efi<\/string>' $EFI_PATH/clover/config.plist

fi

# create desktop icon for Clover Toolbox
ln -s ~/1Clover-tools/Clover-Toolbox.sh ~/Desktop/Clover-Toolbox &> /dev/null
echo -e Desktop icon for Clover Toolbox has been created!

# install the Clover desktop app launcher (apps menu + desktop shortcut)
mkdir -p ~/.local/share/applications
sed "s|^Exec=.*|Exec=$HOME/1Clover-tools/gui/clover-desktop|" ~/1Clover-tools/gui/clover-dualboot.desktop > ~/.local/share/applications/clover-dualboot.desktop
chmod +x ~/.local/share/applications/clover-dualboot.desktop
cp ~/.local/share/applications/clover-dualboot.desktop ~/Desktop/ &> /dev/null
chmod +x ~/Desktop/clover-dualboot.desktop &> /dev/null
echo Clover desktop app has been installed!

echo Clover install completed on $OS!
