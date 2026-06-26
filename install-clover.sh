#!/bin/bash

clear

# language: ask interactively, or honor a preselected CLOVER_LANG (default es)
CLOVER_LANG=${CLOVER_LANG:-}
case "$CLOVER_LANG" in
	es|en) ;;
	*)
		if [ "${CLOVER_NONINTERACTIVE:-}" = 1 ]
		then
			CLOVER_LANG=es
		else
			echo "Idioma / Language:"
			echo "  1) Español   2) English"
			read -p "> " lang_choice
			case "$lang_choice" in
				2|en|EN|english|English) CLOVER_LANG=en ;;
				*) CLOVER_LANG=es ;;
			esac
		fi
		;;
esac
export CLOVER_LANG

# msg <key> [args] - print a UI string in the selected language
msg() {
	local k=$1; shift
	local es en
	case "$k" in
		banner_title) es='Script de instalación de Clover Dual Boot para SteamOS y Bazzite'; en='Clover Dual Boot Install Script for SteamOS and Bazzite' ;;
		banner_author) es='Creado por ryanrudolf, ampliado por Hooandee'; en='Created by ryanrudolf, extended by Hooandee' ;;
		sanity_checks) es='Realizando comprobaciones preliminares ...'; en='Doing preliminary sanity checks ...' ;;
		registry_missing) es='Error: no se encontró custom/device-registry.sh - ejecuta este script desde el directorio del repositorio.'; en='Error: custom/device-registry.sh not found - run this script from the repo directory.' ;;
		blocked_model) es='Ejecutándose en un modelo no compatible - %s.'; en='Script is running on unsupported model - %s.' ;;
		blocked_exit) es='¡Dispositivo no compatible! Saliendo inmediatamente.'; en='Unsupported device! Exiting immediately.' ;;
		supported_model) es='Ejecutándose en un modelo compatible - %s.'; en='Script is running on supported model - %s.' ;;
		no_edits_needed) es='No se necesitan más cambios en config.plist.'; en='No further edits needed to the config.plist.' ;;
		creating_config) es='Creando configuración específica para %s.'; en='Creating config specific for %s.' ;;
		not_in_list) es='Este dispositivo no está en la lista probada:'; en='This device is not in the tested list:' ;;
		generic_possible) es='Clover aún puede instalarse en modo genérico para handhelds.'; en='Clover can still be installed in generic handheld mode.' ;;
		generic_warn) es='Continúa solo si esto es un handheld / mini PC x86 que quieres en dual boot.'; en='Only continue if this is an x86 handheld / mini PC that you want to dual boot.' ;;
		autodetected_res) es='Resolución nativa detectada automáticamente: %s'; en='Auto-detected native screen resolution: %s' ;;
		could_not_detect) es='No se pudo detectar la resolución - se usará el valor por defecto de Clover 1280x800.'; en='Could not auto-detect the resolution - the Clover default 1280x800 will be used.' ;;
		change_later_toolbox) es='Puedes cambiarla luego desde el Clover Toolbox.'; en='You can change it later from the Clover Toolbox.' ;;
		generic_prompt) es='¿Continuar en modo genérico para handhelds? (s/N): '; en='Proceed in generic handheld mode? (y/N): ' ;;
		aborting) es='Cancelando a petición del usuario.'; en='Aborting at user request.' ;;
		creating_generic) es='Creando configuración para handheld genérico usando %s.'; en='Creating config for generic handheld using %s.' ;;
		running_on_os) es='Ejecutándose en un SO compatible - %s.'; en='Script is running on supported OS - %s.' ;;
		neither_os) es='¡Esto no es ni Bazzite ni SteamOS!'; en='This is neither Bazzite nor SteamOS!' ;;
		exiting_now) es='¡Saliendo inmediatamente!'; en='Exiting immediately!' ;;
		unsupported_dualboot) es='Configuración de dual boot no compatible detectada.'; en='Unsupported dual boot configuration detected.' ;;
		install_os_first) es='¡Asegúrate de instalar %s antes que Windows!'; en='Make sure %s is installed before Windows!' ;;
		dualboot_supported) es='Configuración de dual boot compatible.'; en='Dual boot configuration supported.' ;;
		sudo_good) es='¡La contraseña de sudo es correcta!'; en='Sudo password is good!' ;;
		sudo_wrong_exit) es='¡La contraseña de sudo es incorrecta! Saliendo.'; en='Sudo password is wrong! Exiting.' ;;
		enter_sudo) es='Introduce tu contraseña de sudo actual: '; en='Please enter current sudo password: ' ;;
		checking_sudo) es='Comprobando si la contraseña de sudo es correcta.'; en='Checking if the sudo password is correct.' ;;
		sudo_wrong_rerun) es='¡Contraseña de sudo incorrecta! Vuelve a ejecutar el script e introduce la contraseña correcta.'; en='Sudo password is wrong! Re-run the script and make sure to enter the correct sudo password!' ;;
		sudo_blank) es='¡La contraseña de sudo está vacía! Configura una contraseña de sudo y vuelve a ejecutar el script.'; en='Sudo password is blank! Setup a sudo password first and then re-run script!' ;;
		esp_mounted) es='La ESP ha sido montada.'; en='ESP has been mounted.' ;;
		esp_mount_err) es='Error al montar la ESP.'; en='Error mounting ESP.' ;;
		esp_free) es='La partición ESP tiene %s KB de espacio libre.'; en='ESP partition has %s KB free space.' ;;
		esp_enough) es='La partición ESP tiene suficiente espacio libre.'; en='ESP partition has enough free space.' ;;
		esp_not_enough) es='¡No hay suficiente espacio en la partición ESP!'; en='Not enough space on the ESP partition!' ;;
		refind_not_detected) es='¡No se detecta rEFInd! Continuando con la instalación de Clover.'; en='rEFInd is not detected! Proceeding with the Clover install.' ;;
		refind_detected) es='¡Parece que rEFInd está instalado! Intentando desinstalar rEFInd.'; en='rEFInd seems to be installed! Performing best effort to uninstall rEFInd!' ;;
		refind_uninstalled) es='¡rEFInd se desinstaló correctamente! Continuando con la instalación de Clover.'; en='rEFInd has been successfully uninstalled! Proceeding with the Clover install.' ;;
		refind_still) es='rEFInd sigue instalado. ¡Desinstala rEFInd manualmente primero!'; en='rEFInd is still installed. Please manually uninstall rEFInd first!' ;;
		clover_downloaded) es='¡Clover se ha descargado del repositorio de github!'; en='Clover has been downloaded from the github repo!' ;;
		clover_download_err) es='¡Error al descargar Clover!'; en='Error downloading Clover!' ;;
		iso_mounted) es='¡La ISO de Clover ha sido montada!'; en='Clover ISO has been mounted!' ;;
		iso_mount_err) es='¡Error al montar la ISO!'; en='Error mounting ISO!' ;;
		installing_xpad) es='Instalando el driver UEFI del mando XBOX 360 para que el gamepad integrado funcione en Clover.'; en='Installing XBOX 360 controller UEFI driver so the built-in gamepad works in Clover.' ;;
		xpad_ok) es='Driver UEFI de XBOX 360 instalado correctamente.'; en='Successfully installed XBOX 360 UEFI driver.' ;;
		xpad_err) es='Error al instalar el driver UEFI de XBOX 360.'; en='Error installing XBOX 360 UEFI driver.' ;;
		on_steamdeck) es='Ejecutándose en una Steam Deck.'; en='Script is running on a Steam Deck.' ;;
		xpad_not_needed) es='No se necesita el driver UEFI de XBOX 360.'; en='XBOX 360 UEFI driver not needed.' ;;
		bootx64_orig_found) es='%s.orig encontrado - no se necesita acción.'; en='%s.orig found - no action needed.' ;;
		bootx64_backup_missing) es='Copia de seguridad de %s no encontrada.'; en='%s backup not found.' ;;
		bootx64_copy_done) es='Copia de Clover EFI a %s - hecho.'; en='Copy Clover EFI to %s - done.' ;;
		win_backup_exists) es='Existe copia de la EFI de Windows. Comprobando si hay que desactivar la EFI de Windows.'; en='Windows EFI backup exists. Check if Windows EFI needs to be disabled.' ;;
		win_disabled_done) es='Había que desactivar la EFI de Windows - hecho.'; en='Windows EFI needs to be disabled - done.' ;;
		win_already_disabled) es='La EFI de Windows ya está desactivada - no se necesita acción.'; en='Windows EFI is already disabled - no action needed.' ;;
		win_backup_missing) es='No existe copia de la EFI de Windows.'; en='Windows EFI backup does not exist.' ;;
		clover_installed_ok) es='¡Clover se ha instalado correctamente en la partición EFI del sistema!'; en='Clover has been successfully installed to the EFI system partition!' ;;
		clover_install_fail) es='Vaya, algo salió mal. Clover no está instalado.'; en='Whoopsie something went wrong. Clover is not installed.' ;;
		final_config) es='Realizando la configuración final para %s.'; en='Making final configuration for %s.' ;;
		esp_labeled) es='La partición ESP ya tiene etiqueta - no se necesita acción.'; en='ESP partition is already labeled - no action needed.' ;;
		esp_label_done) es='Etiqueta de la partición ESP completada.'; en='ESP partition label has been completed.' ;;
		desktop_icon_toolbox) es='¡Se ha creado el icono de escritorio para Clover Toolbox!'; en='Desktop icon for Clover Toolbox has been created!' ;;
		desktop_app_installed) es='¡La app de escritorio de Clover ha sido instalada!'; en='Clover desktop app has been installed!' ;;
		install_completed) es='¡Instalación de Clover completada en %s!'; en='Clover install completed on %s!' ;;
		*) es="$k"; en="$k" ;;
	esac
	# shellcheck disable=SC2059
	if [ "$CLOVER_LANG" = en ]; then printf "$en\n" "$@"; else printf "$es\n" "$@"; fi
}

msg banner_title
msg banner_author
msg sanity_checks
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
	msg registry_missing
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
			msg blocked_model "$DEVICE_NAME"
			msg blocked_exit
			exit
			;;
		nodriver)
			msg supported_model "$DEVICE_NAME"
			msg no_edits_needed
			XPAD_DRIVER=no
			;;
		*)
			msg supported_model "$DEVICE_NAME"
			msg creating_config "$DEVICE_NAME"
			set_resolution "$DEVICE_ACTION"
			;;
	esac

# unknown device - fall back to generic handheld mode (experimental)
else
	echo ----------------------------------------------------------------------
	msg not_in_list
	echo "    board_name   : $BOARD_NAME"
	echo "    product_name : $PRODUCT_NAME"
	echo ----------------------------------------------------------------------
	msg generic_possible
	msg generic_warn
	AUTO_RES=$(detect_native_resolution)
	if [ -n "$AUTO_RES" ]
	then
		msg autodetected_res "$AUTO_RES"
	else
		msg could_not_detect
		msg change_later_toolbox
	fi
	if [ "${CLOVER_NONINTERACTIVE:-}" = 1 ]
	then
		GENERIC_CONFIRM=y
	else
		read -p "$(msg generic_prompt)" GENERIC_CONFIRM
	fi
	case "$GENERIC_CONFIRM" in
		y|Y|s|S) ;;
		*) msg aborting; exit ;;
	esac
	if [ -n "$AUTO_RES" ]
	then
		msg creating_generic "$AUTO_RES"
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
	msg running_on_os "$OS"
else
	grep -i SteamOS /etc/os-release &> /dev/null
	if [ $? -eq 0 ]
	then
		OS=SteamOS
		EFI_PATH=/esp/efi
		BOOTX64=$EFI_PATH/boot/bootx64.efi
		msg running_on_os "$OS"
	else
		msg neither_os
		msg exiting_now
		exit
	fi
fi

# check if  dual boot configuration is supported
blkid | grep nvme0n1p1\: | grep Microsoft
if [ $? -eq 0 ]
then
	msg unsupported_dualboot
	msg install_os_first "$OS"
	exit
else
	msg dualboot_supported
fi

if [ -n "${CLOVER_SUDO_PASS:-}" ]
then
	current_password="$CLOVER_SUDO_PASS"
	echo -e "$current_password\n" | sudo -S ls &> /dev/null
	if [ $? -eq 0 ]
	then
		msg sudo_good
	else
		msg sudo_wrong_exit
		exit
	fi
elif [ "$(passwd --status $(whoami) | tr -s " " | cut -d " " -f 2)" == "P" ]
then
	read -s -p "$(msg enter_sudo)" current_password ; echo
	msg checking_sudo
	echo -e "$current_password\n" | sudo -S ls &> /dev/null

	if [ $? -eq 0 ]
	then
		msg sudo_good
	else
		msg sudo_wrong_rerun
		exit
	fi
else
	msg sudo_blank
	passwd
	exit
fi

# sanity check - is there enough space on esp
mkdir ~/temp-ESP
echo -e "$current_password\n" | sudo -S mount /dev/nvme0n1p1 ~/temp-ESP
if [ $? -eq 0 ]
then
	msg esp_mounted
else
	msg esp_mount_err
	rmdir ~/temp-ESP
	exit
fi

if [ $ESP -ge 15000 ]
then
	msg esp_free "$ESP"
	msg esp_enough
	echo -e "$current_password\n" | sudo -S umount ~/temp-ESP
	rmdir ~/temp-ESP
else
	msg esp_free "$ESP"
	msg esp_not_enough
 	echo -e "$current_password\n" | sudo -S du -hd2 /esp
	echo -e "$current_password\n" | sudo -S umount ~/temp-ESP
	rmdir ~/temp-ESP
	exit
fi

# sanity check - is rEFInd installed?
efibootmgr | grep -i refind
if [ $? -ne 0 ]
then
	msg refind_not_detected
else
	msg refind_detected
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
		msg refind_uninstalled
	else
		msg refind_still
		exit
	fi
fi

# obtain Clover ISO
7z x $CLOVER_ARCHIVE -aoa $CLOVER_BASE &> /dev/null
if [ $? -eq 0 ]
then
	msg clover_downloaded
else
	msg clover_download_err
	exit
fi

# mount Clover ISO
mkdir ~/temp-clover &> /dev/null
echo -e "$current_password\n" | sudo -S mount $CLOVER_BASE ~/temp-clover &> /dev/null
if [ $? -eq 0 ]
then
	msg iso_mounted
else
	msg iso_mount_err
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
	msg installing_xpad
	echo -e "$current_password\n" | sudo -S cp custom/UsbXbox360Dxe.efi $EFI_PATH/clover/drivers/uefi
	if [ $? -eq 0 ]
	then
		msg xpad_ok
	else
		msg xpad_err
		exit
	fi
else
	msg on_steamdeck
	msg xpad_not_needed
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
	msg bootx64_orig_found "$BOOTX64"
else
	msg bootx64_backup_missing "$BOOTX64"
	echo -e "$current_password\n" | sudo -S cp $BOOTX64 $BOOTX64.orig
	echo -e "$current_password\n" | sudo -S cp $EFI_PATH/clover/cloverx64.efi $BOOTX64
	msg bootx64_copy_done "$BOOTX64"
fi

# check if Windows EFI needs to be disabled!
echo -e "$current_password\n" | sudo -S test -e $EFI_PATH/Microsoft/Boot/bootmgfw.efi.orig
if [ $? -eq 0 ]
then
	msg win_backup_exists
	echo -e "$current_password\n" | sudo -S test -e $EFI_PATH/Microsoft/Boot/bootmgfw.efi
	if [ $? -eq 0 ]
	then
		echo -e "$current_password\n" | sudo -S mv $EFI_PATH/Microsoft/Boot/bootmgfw.efi $EFI_PATH/Microsoft/bootmgfw.efi &> /dev/null
		msg win_disabled_done
	else
		msg win_already_disabled
	fi
else
	msg win_backup_missing
	echo -e "$current_password\n" | sudo -S cp $EFI_PATH/Microsoft/Boot/bootmgfw.efi $EFI_PATH/Microsoft/Boot/bootmgfw.efi.orig &> /dev/null
	echo -e "$current_password\n" | sudo -S mv $EFI_PATH/Microsoft/Boot/bootmgfw.efi $EFI_PATH/Microsoft/bootmgfw.efi &> /dev/null
	msg win_disabled_done
fi

# re-arrange the boot order and make Clover the priority!
echo -e "$current_password\n" | sudo -S efibootmgr -n $CLOVER &> /dev/null
echo -e "$current_password\n" | sudo -S efibootmgr -o $CLOVER &> /dev/null

# Final sanity check
efibootmgr | grep "Clover - GUI" &> /dev/null
if [ $? -eq 0 ]
then
	msg clover_installed_ok
else
	msg clover_install_fail
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

mkdir -p ~/1Clover-tools
printf '%s\n' "$CLOVER_LANG" > ~/1Clover-tools/lang

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
	msg final_config "$OS"
	mkdir -p ~/.local/share/kservices5/ServiceMenus
	cp custom/open_as_root.desktop ~/.local/share/kservices5/ServiceMenus
	echo -e "$current_password\n" | sudo -S cp custom/clover-whitelist.conf /etc/atomic-update.conf.d
else
	msg final_config "$OS"
	echo -e "$current_password\n" | sudo -S blkid | grep nvme0n1p1 | grep esp &> /dev/null
	if [ $? -eq 0 ]
	then
		msg esp_labeled
	else
		echo -e "$current_password\n" | sudo -S fatlabel /dev/nvme0n1p1 esp &> /dev/null
		msg esp_label_done
	fi

	# set bazzite as the default boot in Clover config
	echo -e "$current_password\n" | sudo -S sed -i '/<key>DefaultLoader<\/key>/!b;n;c\\t\t<string>\\efi\\fedora\\shimx64\.efi<\/string>' $EFI_PATH/clover/config.plist

fi

# create desktop icon for Clover Toolbox
ln -s ~/1Clover-tools/Clover-Toolbox.sh ~/Desktop/Clover-Toolbox &> /dev/null
msg desktop_icon_toolbox

# install the Clover desktop app launcher (apps menu + desktop shortcut)
mkdir -p ~/.local/share/applications
sed -e "s|^Exec=.*|Exec=$HOME/1Clover-tools/gui/clover-desktop|" -e "s|^Icon=.*|Icon=$HOME/1Clover-tools/gui/clover.png|" ~/1Clover-tools/gui/clover-dualboot.desktop > ~/.local/share/applications/clover-dualboot.desktop
chmod +x ~/.local/share/applications/clover-dualboot.desktop
cp ~/.local/share/applications/clover-dualboot.desktop ~/Desktop/ &> /dev/null
chmod +x ~/Desktop/clover-dualboot.desktop &> /dev/null
msg desktop_app_installed

msg install_completed "$OS"
