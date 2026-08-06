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
		banner_title) es='Instalador universal de Clover Dual Boot para Linux UEFI y Windows'; en='Universal Clover Dual Boot installer for UEFI Linux and Windows' ;;
		banner_author) es='Creado por ryanrudolf, ampliado por Hooandee'; en='Created by ryanrudolf, extended by Hooandee' ;;
		sanity_checks) es='Realizando comprobaciones preliminares ...'; en='Doing preliminary sanity checks ...' ;;
		registry_missing) es='Error: faltan los archivos de detección de dispositivos - ejecuta este script desde el directorio del repositorio.'; en='Error: device detection files are missing - run this script from the repo directory.' ;;
		supported_model) es='Ejecutándose en un modelo compatible - %s.'; en='Script is running on supported model - %s.' ;;
		creating_config) es='Creando configuración específica para %s.'; en='Creating config specific for %s.' ;;
		not_in_list) es='Este dispositivo no está en la lista probada:'; en='This device is not in the tested list:' ;;
		generic_possible) es='Clover aún puede instalarse en modo genérico para handhelds.'; en='Clover can still be installed in generic handheld mode.' ;;
		generic_warn) es='Continúa solo si esto es un handheld / mini PC x86 que quieres en dual boot.'; en='Only continue if this is an x86 handheld / mini PC that you want to dual boot.' ;;
		autodetected_res) es='Resolución nativa detectada automáticamente: %s'; en='Auto-detected native screen resolution: %s' ;;
		registry_res) es='Usando la resolución conocida para este modelo: %s'; en='Using the known resolution for this model: %s' ;;
		could_not_detect) es='No se pudo detectar la resolución - se usará el valor por defecto de Clover 1280x800.'; en='Could not auto-detect the resolution - the Clover default 1280x800 will be used.' ;;
		change_later_toolbox) es='Puedes cambiarla luego desde el Clover Toolbox.'; en='You can change it later from the Clover Toolbox.' ;;
		generic_prompt) es='¿Continuar en modo genérico para handhelds? (s/N): '; en='Proceed in generic handheld mode? (y/N): ' ;;
		controller_disabled) es='El driver UEFI del mando XBOX 360 queda desactivado para evitar incompatibilidades en este modelo.'; en='The XBOX 360 controller UEFI driver is disabled to avoid compatibility issues on this model.' ;;
		controller_optional) es='No hay compatibilidad verificada del mando integrado dentro de Clover para este modelo.'; en='Built-in controller compatibility inside Clover is not verified for this model.' ;;
		controller_prompt) es='¿Probar el driver UEFI del mando XBOX 360? (s/N): '; en='Try the XBOX 360 controller UEFI driver? (y/N): ' ;;
		aborting) es='Cancelando a petición del usuario.'; en='Aborting at user request.' ;;
		creating_generic) es='Creando configuración para handheld genérico usando %s.'; en='Creating config for generic handheld using %s.' ;;
		running_on_os) es='Ejecutándose en un SO compatible - %s.'; en='Script is running on supported OS - %s.' ;;
		neither_os) es='Esta distribución todavía no tiene un perfil validado.'; en='This distribution does not have a validated profile yet.' ;;
		generic_os_warn) es='Se ha encontrado un cargador EFI existente, pero este perfil Linux es genérico y requiere confirmación.'; en='An existing EFI loader was found, but this generic Linux profile requires confirmation.' ;;
		generic_os_prompt) es='¿Continuar con el cargador EFI detectado en modo genérico? (s/N): '; en='Continue with the detected EFI loader in generic mode? (y/N): ' ;;
		layout_failed) es='No se puede modificar el arranque: el mapa EFI es ambiguo o incompleto (%s).'; en='Boot cannot be modified: the EFI layout is ambiguous or incomplete (%s).' ;;
		layout_detected) es='Mapa validado: %s en %s; ESP de Windows: %s.'; en='Validated layout: %s on %s; Windows ESP: %s.' ;;
		windows_not_found) es='No se ha detectado Windows; Clover se instalará sin modificar ningún cargador de Windows.'; en='Windows was not detected; Clover will be installed without modifying any Windows loader.' ;;
		exiting_now) es='¡Saliendo inmediatamente!'; en='Exiting immediately!' ;;
		sudo_good) es='¡La contraseña de sudo es correcta!'; en='Sudo password is good!' ;;
		sudo_wrong_exit) es='¡La contraseña de sudo es incorrecta! Saliendo.'; en='Sudo password is wrong! Exiting.' ;;
		enter_sudo) es='Introduce tu contraseña de sudo actual: '; en='Please enter current sudo password: ' ;;
		checking_sudo) es='Comprobando si la contraseña de sudo es correcta.'; en='Checking if the sudo password is correct.' ;;
		sudo_wrong_rerun) es='¡Contraseña de sudo incorrecta! Vuelve a ejecutar el script e introduce la contraseña correcta.'; en='Sudo password is wrong! Re-run the script and make sure to enter the correct sudo password!' ;;
		sudo_blank) es='¡La contraseña de sudo está vacía! Configura una contraseña de sudo y vuelve a ejecutar el script.'; en='Sudo password is blank! Setup a sudo password first and then re-run script!' ;;
		esp_mount_err) es='Error al montar la ESP.'; en='Error mounting ESP.' ;;
		esp_free) es='La partición ESP tiene %s KB de espacio libre.'; en='ESP partition has %s KB free space.' ;;
		esp_enough) es='La partición ESP tiene suficiente espacio libre.'; en='ESP partition has enough free space.' ;;
		esp_not_enough) es='¡No hay suficiente espacio en la partición ESP!'; en='Not enough space on the ESP partition!' ;;
		refind_not_detected) es='¡No se detecta rEFInd! Continuando con la instalación de Clover.'; en='rEFInd is not detected! Proceeding with the Clover install.' ;;
		refind_detected) es='Se ha detectado rEFInd. Se conservarán sus archivos, servicios y entrada UEFI; Clover se añadirá sin borrar el gestor existente.'; en='rEFInd was detected. Its files, services and UEFI entry will be preserved; Clover will be added without deleting the existing manager.' ;;
		clover_downloaded) es='¡Clover se ha descargado del repositorio de github!'; en='Clover has been downloaded from the github repo!' ;;
		clover_download_err) es='¡Error al descargar Clover!'; en='Error downloading Clover!' ;;
		iso_mounted) es='¡La ISO de Clover ha sido montada!'; en='Clover ISO has been mounted!' ;;
		iso_mount_err) es='¡Error al montar la ISO!'; en='Error mounting ISO!' ;;
		installing_xpad) es='Instalando el driver UEFI del mando XBOX 360 para que el gamepad integrado funcione en Clover.'; en='Installing XBOX 360 controller UEFI driver so the built-in gamepad works in Clover.' ;;
		xpad_ok) es='Driver UEFI de XBOX 360 instalado correctamente.'; en='Successfully installed XBOX 360 UEFI driver.' ;;
		xpad_err) es='Error al instalar el driver UEFI de XBOX 360.'; en='Error installing XBOX 360 UEFI driver.' ;;
		xpad_remove_err) es='No se pudo retirar un driver UEFI de XBOX 360 anterior.'; en='Could not remove a previous XBOX 360 UEFI driver.' ;;
		xpad_not_needed) es='El driver UEFI de XBOX 360 no se instalará.'; en='The XBOX 360 UEFI driver will not be installed.' ;;
		bootx64_copy_done) es='Copia de Clover EFI a %s - hecho.'; en='Copy Clover EFI to %s - done.' ;;
		bootx64_copy_failed) es='No se pudo instalar de forma segura el cargador de Clover en %s. Se ha restaurado el cargador original.'; en='Could not safely install the Clover loader at %s. The original loader was restored.' ;;
		win_disabled_done) es='Había que desactivar la EFI de Windows - hecho.'; en='Windows EFI needs to be disabled - done.' ;;
		win_protect_failed) es='No se pudo proteger la EFI de Windows. La instalación se detiene sin mover su cargador.'; en='Could not protect the Windows EFI. Installation stopped without moving its loader.' ;;
		clover_installed_ok) es='¡Clover se ha instalado correctamente en la partición EFI del sistema!'; en='Clover has been successfully installed to the EFI system partition!' ;;
		clover_install_fail) es='Vaya, algo salió mal. Clover no está instalado.'; en='Whoopsie something went wrong. Clover is not installed.' ;;
		final_config) es='Realizando la configuración final para %s.'; en='Making final configuration for %s.' ;;
		desktop_icon_toolbox) es='¡Se ha creado el icono de escritorio para Clover Toolbox!'; en='Desktop icon for Clover Toolbox has been created!' ;;
		desktop_app_installed) es='¡La app de escritorio de Clover ha sido instalada!'; en='Clover desktop app has been installed!' ;;
		tools_install_failed) es='No se pudieron instalar todos los archivos de Clover Tools. La instalación se detiene.'; en='Could not install all Clover Tools files. Installation stopped.' ;;
		service_install_failed) es='No se pudo instalar o iniciar el servicio de Clover. La instalación se detiene.'; en='Could not install or start the Clover service. Installation stopped.' ;;
		desktop_app_failed) es='No se pudo instalar el lanzador de la app de escritorio.'; en='Could not install the desktop app launcher.' ;;
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
CLOVER_VERSION=5172
CLOVER_URL=https://github.com/CloverHackyColor/CloverBootloader/releases/download/$CLOVER_VERSION/Clover-$CLOVER_VERSION-X64.iso.7z
CLOVER_SHA256=80f84f688a1303e2920dc44cd7355dda0b7a34e98ab29df295ecd65e99802bcb
BOARD_NAME=$(cat /sys/class/dmi/id/board_name 2> /dev/null)
PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name 2> /dev/null)
PRODUCT_FAMILY=$(cat /sys/class/dmi/id/product_family 2> /dev/null)
SYS_VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2> /dev/null)

# helper - write a screen resolution (eg 1920x1080) into the Clover config.plist
set_resolution() {
	sed -i '/<key>ScreenResolution<\/key>/!b;n;c\\t\t<string>'"$1"'<\/string>' "$WORK_CONFIG"
}

if [ ! -f custom/device-registry.sh ] || [ ! -f custom/device-detection.sh ] \
	|| [ ! -f custom/boot-discovery.py ] || [ ! -f custom/install-layout.sh ]
then
	msg registry_missing
	exit 1
fi
WORK_CONFIG=$(mktemp "${TMPDIR:-/tmp}/clover-config.XXXXXX") \
	|| { msg registry_missing; exit 1; }
cp custom/config.plist "$WORK_CONFIG" || { rm -f "$WORK_CONFIG"; msg registry_missing; exit 1; }
cleanup_work_config() { rm -f "$WORK_CONFIG"; }
trap cleanup_work_config EXIT
trap 'exit 1' HUP INT TERM
. custom/device-registry.sh
. custom/device-detection.sh
. custom/install-layout.sh
DEVICE_MATCH=$(lookup_device "$BOARD_NAME" "$PRODUCT_NAME" "$PRODUCT_FAMILY" "$SYS_VENDOR")
INSTALL_PROFILE=$(resolve_install_profile "$BOARD_NAME" "$PRODUCT_NAME" "$PRODUCT_FAMILY" "$SYS_VENDOR")
CONTROLLER_POLICY=${INSTALL_PROFILE##*|}
INSTALL_PROFILE=${INSTALL_PROFILE%|*}
RESOLUTION_SOURCE=${INSTALL_PROFILE##*|}
INSTALL_PROFILE=${INSTALL_PROFILE%|*}
SCREEN_RESOLUTION=${INSTALL_PROFILE##*|}
DEVICE_NAME=${INSTALL_PROFILE%|*}

if [ -n "$DEVICE_MATCH" ]
then
	msg supported_model "$DEVICE_NAME"

# unknown device - fall back to generic handheld mode (experimental)
else
	echo ----------------------------------------------------------------------
	msg not_in_list
	echo "    board_name   : $BOARD_NAME"
	echo "    product_name : $PRODUCT_NAME"
	echo "    product_family: $PRODUCT_FAMILY"
	echo "    sys_vendor   : $SYS_VENDOR"
	echo ----------------------------------------------------------------------
	msg generic_possible
	msg generic_warn
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
fi

if [ -n "$SCREEN_RESOLUTION" ]
then
	if [ "$RESOLUTION_SOURCE" = drm ]
	then
		msg autodetected_res "$SCREEN_RESOLUTION"
	else
		msg registry_res "$SCREEN_RESOLUTION"
	fi
	if [ -n "$DEVICE_MATCH" ]
	then
		msg creating_config "$DEVICE_NAME"
	else
		msg creating_generic "$SCREEN_RESOLUTION"
	fi
	set_resolution "$SCREEN_RESOLUTION"
else
	msg could_not_detect
	msg change_later_toolbox
fi

CONTROLLER_ANSWER=""
if [ "$CONTROLLER_POLICY" = ask ]
then
	msg controller_optional
	if [ "${CLOVER_NONINTERACTIVE:-}" != 1 ]
	then
		read -p "$(msg controller_prompt)" CONTROLLER_ANSWER
	fi
elif [ "$CONTROLLER_POLICY" = none ]
then
	msg controller_disabled
fi
XPAD_DRIVER=$(controller_driver_enabled "$CONTROLLER_POLICY" "${CLOVER_NONINTERACTIVE:-0}" "$CONTROLLER_ANSWER")

OS_ID=$(grep -E '^ID=' /etc/os-release 2> /dev/null | head -n1 | cut -d= -f2- | tr -d '"' | tr '[:upper:]' '[:lower:]')
ALLOW_GENERIC_OS=no
case "$OS_ID" in
	steamos) OS=SteamOS ;;
	bazzite) OS=Bazzite ;;
	cachyos) OS=CachyOS ;;
	*)
		OS=${OS_ID:-Linux}
		msg neither_os
		msg generic_os_warn
		if [ "${CLOVER_ALLOW_GENERIC_OS:-}" = 1 ]
		then
			GENERIC_OS_CONFIRM=y
		elif [ "${CLOVER_NONINTERACTIVE:-}" = 1 ]
		then
			GENERIC_OS_CONFIRM=n
		else
			read -p "$(msg generic_os_prompt)" GENERIC_OS_CONFIRM
		fi
		case "$GENERIC_OS_CONFIRM" in
			y|Y|s|S) ALLOW_GENERIC_OS=yes ;;
			*) msg exiting_now; exit 1 ;;
		esac
		;;
esac
msg running_on_os "$OS"

if [ -n "${CLOVER_SUDO_PASS:-}" ]
then
	current_password="$CLOVER_SUDO_PASS"
	echo -e "$current_password\n" | sudo -S ls &> /dev/null
	if [ $? -eq 0 ]
	then
		msg sudo_good
	else
		msg sudo_wrong_exit
		exit 1
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
		exit 1
	fi
else
	msg sudo_blank
	passwd
	exit
fi

as_root() {
	printf '%s\n' "$current_password" | sudo -S "$@"
}

DISCOVERY_ARGS=(--mount-unmounted)
[ "$ALLOW_GENERIC_OS" = yes ] && DISCOVERY_ARGS+=(--allow-generic)
INSTALL_LAYOUT=$(as_root python3 custom/boot-discovery.py "${DISCOVERY_ARGS[@]}") \
	|| { msg layout_failed discovery_failed; exit 1; }
INSTALL_VARS=$(printf '%s' "$INSTALL_LAYOUT" | install_layout_vars) \
	|| { msg layout_failed invalid_discovery_output; exit 1; }
eval "$INSTALL_VARS"
[ "$INSTALL_LAYOUT_SAFE" = yes ] \
	|| { msg layout_failed "${INSTALL_LAYOUT_PROBLEMS:-unknown}"; exit 1; }
[ -n "$INSTALL_TARGET_DEVICE" ] && [ -n "$INSTALL_TARGET_DISK" ] \
	&& [ -n "$INSTALL_TARGET_PARTITION" ] && [ -n "$INSTALL_TARGET_PARTUUID" ] \
	|| { msg layout_failed missing_target; exit 1; }
if [ "$INSTALL_OS_PROFILE" = generic ]
then
	install_add_generic_entry "$WORK_CONFIG" "$INSTALL_LINUX_LOADER" \
		"$INSTALL_LINUX_PARTUUID" "$INSTALL_OS_NAME" \
		|| { msg layout_failed generic_menu_entry_failed; exit 1; }
fi

TEMP_TARGET_MOUNT=""
TEMP_WINDOWS_MOUNT=""
TEMP_ISO_MOUNT=""
DOWNLOAD_DIR=""
CLOVER_STAGE=""
CLOVER_PREVIOUS=""
INSTALL_TRANSACTION_ACTIVE=no
INSTALL_COMMITTED=no
CLOVER_PUBLISHED=no
HAD_CLOVER=no
FALLBACK_PUBLISHED=no
BOOT_PRIORITY_CHANGED=no
POST_REPAIR_CLOVER_IDS=""
WINDOWS_PROTECTED=no
SERVICE_STARTED=no
SERVICE_WAS_ENABLED=no
GENERIC_MARKER_EXISTED=no
BOOTX64_BACKUP_PREEXISTED=no
BOOTX64_MARKER_PREEXISTED=no
cleanup_install_mounts() {
	cleanup_work_config
	if [ "$INSTALL_TRANSACTION_ACTIVE" = yes ] && [ "$INSTALL_COMMITTED" != yes ]
	then
		if [ "$SERVICE_STARTED" = yes ] && [ "$SERVICE_WAS_ENABLED" != yes ]
		then
			as_root systemctl disable --now clover-bootmanager.service > /dev/null 2>&1 || true
		fi
		if [ "$GENERIC_MARKER_EXISTED" = yes ]
		then
			as_root sh -c 'umask 022; printf "%s\n" confirmed > /etc/clover-dualboot/allow-generic' > /dev/null 2>&1 || true
		else
			as_root rm -f /etc/clover-dualboot/allow-generic > /dev/null 2>&1 || true
		fi
		if [ "$WINDOWS_PROTECTED" = yes ] && [ "$INSTALL_WINDOWS_STATE" = active ]
		then
			as_root env CLOVER_EFI_PATH="$EFI_PATH" \
				CLOVER_WINDOWS_EFI_PATH="$WINDOWS_EFI_PATH" ./clover-ctl restore-windows-efi > /dev/null 2>&1 || true
		fi
		if [ "$BOOT_PRIORITY_CHANGED" = yes ]
		then
			new_clover_ids=$(install_csv_difference "$POST_REPAIR_CLOVER_IDS" "$INSTALL_ORIGINAL_CLOVER_IDS")
			old_ifs=$IFS
			IFS=,
			for boot_id in $new_clover_ids
			do
				case "$boot_id" in ???? ) as_root efibootmgr -b "$boot_id" -B > /dev/null 2>&1 || true ;; esac
			done
			IFS=$old_ifs
			[ -z "$INSTALL_ORIGINAL_BOOT_ORDER" ] || as_root efibootmgr -o "$INSTALL_ORIGINAL_BOOT_ORDER" > /dev/null 2>&1 || true
		fi
		if [ "$FALLBACK_PUBLISHED" = yes ]
		then
			as_root env CLOVER_EFI_PATH="$EFI_PATH" CLOVER_BOOTX_PATH="$BOOTX64" \
				./clover-ctl restore-clover-loader "$EFI_PATH/clover/cloverx64.efi" > /dev/null 2>&1 || true
			[ "$BOOTX64_BACKUP_PREEXISTED" = yes ] || as_root rm -f "$BOOTX64.orig" > /dev/null 2>&1 || true
			[ "$BOOTX64_MARKER_PREEXISTED" = yes ] || as_root rm -f "$BOOTX64.clover-no-original" > /dev/null 2>&1 || true
		fi
		if [ "$CLOVER_PUBLISHED" = yes ] && [ -n "${EFI_PATH:-}" ]
		then
			as_root rm -rf "$EFI_PATH/clover" > /dev/null 2>&1 || true
			if [ "$HAD_CLOVER" = yes ] && [ -d "$CLOVER_PREVIOUS" ]
			then
				as_root mv "$CLOVER_PREVIOUS" "$EFI_PATH/clover" > /dev/null 2>&1 || true
			fi
		fi
		INSTALL_TRANSACTION_ACTIVE=no
	fi
	if [ -n "$CLOVER_STAGE" ] && [ -e "$CLOVER_STAGE" ]
	then
		as_root rm -rf "$CLOVER_STAGE" > /dev/null 2>&1 || true
	fi
	if [ -n "$CLOVER_PREVIOUS" ] && [ -d "$CLOVER_PREVIOUS" ] \
		&& [ -n "${EFI_PATH:-}" ] && [ ! -d "$EFI_PATH/clover" ]
	then
		as_root mv "$CLOVER_PREVIOUS" "$EFI_PATH/clover" > /dev/null 2>&1 || true
	fi
	if [ -n "$TEMP_ISO_MOUNT" ]
	then
		as_root umount "$TEMP_ISO_MOUNT" > /dev/null 2>&1 || true
		rmdir "$TEMP_ISO_MOUNT" 2> /dev/null || true
	fi
	if [ -n "$DOWNLOAD_DIR" ]
	then
		rm -rf "$DOWNLOAD_DIR"
	fi
	if [ -n "$TEMP_WINDOWS_MOUNT" ]
	then
		as_root umount "$TEMP_WINDOWS_MOUNT" > /dev/null 2>&1 || true
		rmdir "$TEMP_WINDOWS_MOUNT" 2> /dev/null || true
	fi
	if [ -n "$TEMP_TARGET_MOUNT" ]
	then
		as_root umount "$TEMP_TARGET_MOUNT" > /dev/null 2>&1 || true
		rmdir "$TEMP_TARGET_MOUNT" 2> /dev/null || true
	fi
}
trap cleanup_install_mounts EXIT
trap 'exit 1' HUP INT TERM

if [ -z "$INSTALL_TARGET_MOUNT" ]
then
	TEMP_TARGET_MOUNT=$(mktemp -d "${TMPDIR:-/tmp}/clover-target.XXXXXX") \
		|| { msg esp_mount_err; exit 1; }
	as_root mount -o rw,nosuid,nodev,noexec "$INSTALL_TARGET_DEVICE" "$TEMP_TARGET_MOUNT" \
		|| { msg esp_mount_err; exit 1; }
	INSTALL_TARGET_MOUNT=$TEMP_TARGET_MOUNT
fi
EFI_PATH=$(install_efi_root "$INSTALL_TARGET_MOUNT") \
	|| { msg layout_failed target_efi_directory_missing; exit 1; }
BOOTX64=$(install_bootx64_path "$EFI_PATH")
[ -e "$BOOTX64.orig" ] && BOOTX64_BACKUP_PREEXISTED=yes
[ -e "$BOOTX64.clover-no-original" ] && BOOTX64_MARKER_PREEXISTED=yes
if as_root systemctl is-enabled clover-bootmanager.service > /dev/null 2>&1
then
	SERVICE_WAS_ENABLED=yes
fi
if as_root test -e /etc/clover-dualboot/allow-generic
then
	GENERIC_MARKER_EXISTED=yes
fi

WINDOWS_EFI_PATH=""
if [ -n "$INSTALL_WINDOWS_DEVICE" ]
then
	if [ "$INSTALL_WINDOWS_DEVICE" = "$INSTALL_TARGET_DEVICE" ]
	then
		WINDOWS_EFI_PATH=$EFI_PATH
	else
		if [ -z "$INSTALL_WINDOWS_MOUNT" ]
		then
			TEMP_WINDOWS_MOUNT=$(mktemp -d "${TMPDIR:-/tmp}/clover-windows.XXXXXX") \
				|| { msg esp_mount_err; exit 1; }
			as_root mount -o rw,nosuid,nodev,noexec "$INSTALL_WINDOWS_DEVICE" "$TEMP_WINDOWS_MOUNT" \
				|| { msg esp_mount_err; exit 1; }
			INSTALL_WINDOWS_MOUNT=$TEMP_WINDOWS_MOUNT
		fi
		WINDOWS_EFI_PATH=$(install_efi_root "$INSTALL_WINDOWS_MOUNT") \
			|| { msg layout_failed windows_efi_directory_missing; exit 1; }
	fi
else
	msg windows_not_found
fi

ESP=$(df -Pk "$INSTALL_TARGET_MOUNT" 2> /dev/null | awk 'NR==2 {print $4}')
case "$ESP" in ''|*[!0-9]*) msg esp_mount_err; exit 1 ;; esac
if [ "$ESP" -ge 15000 ]
then
	msg esp_free "$ESP"
	msg esp_enough
else
	msg esp_free "$ESP"
	msg esp_not_enough
	as_root du -hd2 "$INSTALL_TARGET_MOUNT"
	exit 1
fi
msg layout_detected "$INSTALL_OS_NAME" "$INSTALL_TARGET_DEVICE" "${INSTALL_WINDOWS_DEVICE:-none}"

if efibootmgr | grep -qi refind
then
	msg refind_detected
else
	msg refind_not_detected
fi

# obtain Clover ISO
DOWNLOAD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/clover-download.XXXXXX") \
	|| { msg clover_download_err; exit 1; }
CLOVER_ARCHIVE="$DOWNLOAD_DIR/clover.iso.7z"
if curl -fsS -L --proto '=https' --proto-redir '=https' -o "$CLOVER_ARCHIVE" "$CLOVER_URL" \
	&& [ -s "$CLOVER_ARCHIVE" ] \
	&& [ "$(wc -c < "$CLOVER_ARCHIVE")" -le 536870912 ] \
	&& printf '%s  %s\n' "$CLOVER_SHA256" "$CLOVER_ARCHIVE" | sha256sum -c - > /dev/null 2>&1 \
	&& 7z t "$CLOVER_ARCHIVE" &> /dev/null \
	&& 7z x "$CLOVER_ARCHIVE" -aoa -o"$DOWNLOAD_DIR" &> /dev/null
then
	msg clover_downloaded
else
	msg clover_download_err
	exit 1
fi
CLOVER_ISOS=("$DOWNLOAD_DIR"/*.iso)
[ "${#CLOVER_ISOS[@]}" -eq 1 ] && [ -f "${CLOVER_ISOS[0]}" ] \
	|| { msg clover_download_err; exit 1; }
CLOVER_BASE=${CLOVER_ISOS[0]}

# mount Clover ISO
TEMP_ISO_MOUNT=$(mktemp -d "${TMPDIR:-/tmp}/clover-iso.XXXXXX") \
	|| { msg iso_mount_err; exit 1; }
as_root mount -o ro,nosuid,nodev,noexec,loop "$CLOVER_BASE" "$TEMP_ISO_MOUNT" &> /dev/null
if [ $? -eq 0 ]
then
	msg iso_mounted
else
	msg iso_mount_err
	exit 1
fi

CLOVER_STAGE="$EFI_PATH/clover.installing"
CLOVER_PREVIOUS="$EFI_PATH/clover.previous"
if ! as_root rm -rf "$CLOVER_STAGE" \
	|| ! as_root cp -Rf "$TEMP_ISO_MOUNT/efi/clover" "$CLOVER_STAGE" \
	|| ! as_root cp "$WORK_CONFIG" "$CLOVER_STAGE/config.plist" \
	|| ! as_root cp -Rf custom/themes/. "$CLOVER_STAGE/themes/" \
	|| ! as_root rm -rf "$CLOVER_STAGE"/themes/{bgm,cesium,christmas,glass,purple_swirl,theme-sample.plist} \
	|| ! as_root test -s "$CLOVER_STAGE/cloverx64.efi" \
	|| ! python3 -c 'import plistlib,sys; plistlib.load(open(sys.argv[1], "rb"))' "$WORK_CONFIG"
then
	msg clover_install_fail
	exit 1
fi

if [ "$XPAD_DRIVER" = "yes" ]
then
	msg installing_xpad
	as_root bash custom/manage-controller-driver.sh install \
		custom/UsbXbox360Dxe.efi "$CLOVER_STAGE/drivers/uefi" \
		custom/xbox360-clover.ini "$EFI_PATH/Xbox360"
	if [ $? -eq 0 ]
	then
		msg xpad_ok
	else
		msg xpad_err
		exit 1
	fi
else
	if ! as_root bash custom/manage-controller-driver.sh remove \
		"$CLOVER_STAGE/drivers/uefi"
	then
		msg xpad_remove_err
		exit 1
	fi
	msg xpad_not_needed
fi

PUBLISH_FAILED=no
as_root rm -rf "$CLOVER_PREVIOUS" || PUBLISH_FAILED=yes
if [ "$PUBLISH_FAILED" = no ] && [ -d "$EFI_PATH/clover" ]
then
	HAD_CLOVER=yes
	as_root mv "$EFI_PATH/clover" "$CLOVER_PREVIOUS" || PUBLISH_FAILED=yes
fi
if [ "$PUBLISH_FAILED" = no ]
then
	as_root mv "$CLOVER_STAGE" "$EFI_PATH/clover" || PUBLISH_FAILED=yes
fi
if [ "$PUBLISH_FAILED" = yes ]
then
	if [ ! -d "$EFI_PATH/clover" ] && [ -d "$CLOVER_PREVIOUS" ]
	then
		as_root mv "$CLOVER_PREVIOUS" "$EFI_PATH/clover" > /dev/null 2>&1 || true
	fi
	msg clover_install_fail
	exit 1
fi
CLOVER_STAGE=""
CLOVER_PUBLISHED=yes
INSTALL_TRANSACTION_ACTIVE=yes

as_root umount "$TEMP_ISO_MOUNT" > /dev/null 2>&1 || true
rmdir "$TEMP_ISO_MOUNT" 2> /dev/null || true
TEMP_ISO_MOUNT=""
rm -rf "$DOWNLOAD_DIR"
DOWNLOAD_DIR=""

# create a verified backup and atomically publish Clover as BOOTX64
if as_root env CLOVER_EFI_PATH="$EFI_PATH" CLOVER_BOOTX_PATH="$BOOTX64" \
	./clover-ctl install-clover-loader "$EFI_PATH/clover/cloverx64.efi"
then
	msg bootx64_copy_done "$BOOTX64"
	FALLBACK_PUBLISHED=yes
else
	msg bootx64_copy_failed "$BOOTX64"
	exit 1
fi

if ! as_root env CLOVER_EFI_PATH="$EFI_PATH" \
	CLOVER_DISCOVERY="$PWD/custom/boot-discovery.py" CLOVER_REQUIRE_DISCOVERY=1 \
	./clover-ctl set-default-loader "$INSTALL_LINUX_LOADER"
then
	msg clover_install_fail
	exit 1
fi

REPAIR_ARGS=()
[ "$ALLOW_GENERIC_OS" = yes ] && REPAIR_ARGS+=(--allow-generic)
if ! as_root env CLOVER_DISCOVERY="$PWD/custom/boot-discovery.py" \
	./clover-ctl repair-boot-priority "${REPAIR_ARGS[@]}"
then
	msg clover_install_fail
	exit 1
fi
BOOT_PRIORITY_CHANGED=yes
POST_REPAIR_CLOVER_IDS=$(as_root efibootmgr -v \
	| install_clover_ids_from_firmware "$INSTALL_TARGET_PARTUUID")
[ -n "$POST_REPAIR_CLOVER_IDS" ] \
	|| { msg clover_install_fail; exit 1; }

if [ -n "$WINDOWS_EFI_PATH" ]
then
	WINDOWS_PROTECTED=yes
	if as_root env CLOVER_EFI_PATH="$EFI_PATH" \
		CLOVER_WINDOWS_EFI_PATH="$WINDOWS_EFI_PATH" ./clover-ctl protect-windows-efi
	then
		msg win_disabled_done
	else
		msg win_protect_failed
		exit 1
	fi
fi
msg clover_installed_ok

# create ~/1Clover-tools and place the scripts in there
mkdir -p ~/1Clover-tools || { msg tools_install_failed; exit 1; }
rm -f ~/1Clover-tools/* &> /dev/null
if ! cp custom/Clover-Toolbox.sh custom/boot-discovery.py custom/install-layout.sh custom/support_report.py clover-ctl ~/1Clover-tools \
	|| ! cp -R custom/logos custom/efi gui decky ~/1Clover-tools \
	|| ! printf '%s\n' "$CLOVER_LANG" > ~/1Clover-tools/lang
then
	msg tools_install_failed
	exit 1
fi
if ! as_root mkdir -p /etc/clover-dualboot \
	|| ! as_root cp clover-ctl /etc/clover-dualboot/clover-ctl \
	|| ! as_root cp custom/boot-discovery.py /etc/clover-dualboot/boot-discovery.py \
	|| ! as_root cp custom/support_report.py /etc/clover-dualboot/support_report.py \
	|| ! as_root chmod +x /etc/clover-dualboot/clover-ctl /etc/clover-dualboot/boot-discovery.py /etc/clover-dualboot/support_report.py \
	|| ! as_root cp custom/clover-bootmanager.service custom/clover-bootmanager.sh /etc/systemd/system
then
	msg service_install_failed
	exit 1
fi
if [ "$ALLOW_GENERIC_OS" = yes ]
then
	as_root sh -c 'umask 022; printf "%s\n" confirmed > /etc/clover-dualboot/allow-generic' \
		|| { msg service_install_failed; exit 1; }
else
	as_root rm -f /etc/clover-dualboot/allow-generic \
		|| { msg service_install_failed; exit 1; }
fi

# make the scripts executable
chmod +x ~/1Clover-tools/Clover-Toolbox.sh ~/1Clover-tools/clover-ctl ~/1Clover-tools/boot-discovery.py ~/1Clover-tools/gui/clover-desktop \
	|| { msg tools_install_failed; exit 1; }
as_root chmod +x /etc/systemd/system/clover-bootmanager.sh \
	|| { msg service_install_failed; exit 1; }

# start the clover-bootmanager.service
SERVICE_STARTED=yes
if ! as_root systemctl daemon-reload \
	|| ! as_root systemctl enable --now clover-bootmanager.service
then
	msg service_install_failed
	exit 1
fi
if ! as_root /etc/systemd/system/clover-bootmanager.sh
then
	msg service_install_failed
	exit 1
fi

msg final_config "$OS"
if [ "$OS" = SteamOS ]
then
	mkdir -p ~/.local/share/kservices5/ServiceMenus
	cp custom/open_as_root.desktop ~/.local/share/kservices5/ServiceMenus
	as_root cp custom/clover-whitelist.conf /etc/atomic-update.conf.d
fi

# create desktop icon for Clover Toolbox
ln -s ~/1Clover-tools/Clover-Toolbox.sh ~/Desktop/Clover-Toolbox &> /dev/null
msg desktop_icon_toolbox

# install the Clover desktop app launcher (apps menu + desktop shortcut)
mkdir -p ~/.local/share/applications
if ! sed -e "s|^Exec=.*|Exec=$HOME/1Clover-tools/gui/clover-desktop|" -e "s|^Icon=.*|Icon=$HOME/1Clover-tools/gui/clover.png|" ~/1Clover-tools/gui/clover-dualboot.desktop > ~/.local/share/applications/clover-dualboot.desktop \
	|| ! chmod +x ~/.local/share/applications/clover-dualboot.desktop \
	|| ! cp ~/.local/share/applications/clover-dualboot.desktop ~/Desktop/ \
	|| ! chmod +x ~/Desktop/clover-dualboot.desktop
then
	msg desktop_app_failed
	exit 1
fi
msg desktop_app_installed

INSTALL_COMMITTED=yes
as_root rm -rf "$CLOVER_PREVIOUS" > /dev/null 2>&1 || true

msg install_completed "$OS"
