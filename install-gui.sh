#!/bin/bash
#
# Graphical, no-terminal installer for Clover dual-boot. Double-click this (or
# its launcher) and it wraps install-clover.sh with zenity dialogs: one password
# prompt and a progress window, nothing to type. zenity ships on SteamOS and
# Bazzite (the Clover Toolbox already uses it).

set -u
DIR=$(cd "$(dirname "$0")" && pwd)
cd "$DIR" || exit 1

# language: honor CLOVER_LANG, else the saved pref, else es; passed to the installer
CLOVER_LANG=${CLOVER_LANG:-}
case "$CLOVER_LANG" in
	es|en) ;;
	*)
		CLOVER_LANG=$(cat ~/1Clover-tools/lang 2> /dev/null)
		case "$CLOVER_LANG" in es|en) ;; *) CLOVER_LANG=es ;; esac
		;;
esac
export CLOVER_LANG

msg() {
	local k=$1; shift
	local es en
	case "$k" in
		zenity_missing) es='zenity es necesario para el instalador gráfico'; en='zenity is required for the graphical installer' ;;
		this_handheld) es='este handheld'; en='this handheld' ;;
		confirm_install) es='¿Instalar el menú de arranque Clover en <b>%s</b>?\n\nEsto cambia tu cargador de arranque para que puedas elegir SteamOS / Bazzite o Windows al iniciar. Tu cargador actual se respalda primero, y puedes deshacerlo cuando quieras desde la app de Clover.\n\nA continuación se te pedirá la contraseña.'; en='Install the Clover boot menu on <b>%s</b>?\n\nThis switches your bootloader so you can choose SteamOS / Bazzite or Windows at startup. Your current bootloader is backed up first, and you can undo it anytime from the Clover app.\n\nYou'"'"'ll be asked for your password next.' ;;
		pass_rejected) es='Esa contraseña fue rechazada.'; en='That password was rejected.' ;;
		starting) es='Iniciando...'; en='Starting...' ;;
		installing_title) es='Instalando Clover'; en='Installing Clover' ;;
		install_ok) es='¡Clover está instalado!\n\nReinicia para ver el menú de arranque. Puedes cambiar el SO por defecto, el tema, la resolución y más desde la app <b>Clover Dual Boot</b>.'; en='Clover is installed!\n\nReboot to see the boot menu. You can change the default OS, theme, resolution and more from the <b>Clover Dual Boot</b> app.' ;;
		install_fail) es='La instalación no terminó. Últimos mensajes:\n\n%s'; en='The install did not finish. Last messages:\n\n%s' ;;
		*) es="$k"; en="$k" ;;
	esac
	# shellcheck disable=SC2059
	if [ "$CLOVER_LANG" = en ]; then printf "$en" "$@"; else printf "$es" "$@"; fi
}

if ! command -v zenity > /dev/null 2>&1
then
	msg zenity_missing >&2; echo >&2
	exit 1
fi

# friendly device name from the registry (best effort)
BOARD=$(cat /sys/class/dmi/id/board_name 2> /dev/null)
PRODUCT=$(cat /sys/class/dmi/id/product_name 2> /dev/null)
NAME=$(msg this_handheld)
if [ -f custom/device-registry.sh ]
then
	. custom/device-registry.sh
	match=$(lookup_device "$BOARD" "$PRODUCT")
	[ -n "$match" ] && NAME=${match%|*}
fi

zenity --question --width 480 --title "Clover Dual Boot" \
	--text "$(msg confirm_install "$NAME")" || exit 0

PASS=$(zenity --password --title "Clover Dual Boot") || exit 0
if ! printf '%s\n' "$PASS" | sudo -S -v 2> /dev/null
then
	zenity --error --width 360 --title "Clover Dual Boot" --text "$(msg pass_rejected)"
	exit 1
fi

LOG=$(mktemp)
# run the installer non-interactively and mirror its output into a pulsating
# progress window (lines prefixed with '# ' become the live status text)
CLOVER_SUDO_PASS="$PASS" CLOVER_NONINTERACTIVE=1 CLOVER_LANG="$CLOVER_LANG" bash install-clover.sh 2>&1 \
	| tee "$LOG" \
	| sed -u 's/^/# /' \
	| zenity --progress --pulsate --no-cancel --auto-close --width 540 \
		--title "$(msg installing_title)" --text "$(msg starting)"

# match either language's completion line (see install_completed in install-clover.sh)
if grep -qE "Clover install completed|Instalación de Clover completada" "$LOG"
then
	zenity --info --width 460 --title "Clover Dual Boot" \
		--text "$(msg install_ok)"
else
	zenity --error --width 560 --title "Clover Dual Boot" \
		--text "$(msg install_fail "$(tail -n 8 "$LOG")")"
fi
rm -f "$LOG"
