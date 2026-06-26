#!/bin/bash
#
# Graphical, no-terminal installer for Clover dual-boot. Double-click this (or
# its launcher) and it wraps install-Clover.sh with zenity dialogs: one password
# prompt and a progress window, nothing to type. zenity ships on SteamOS and
# Bazzite (the Clover Toolbox already uses it).

set -u
DIR=$(cd "$(dirname "$0")" && pwd)
cd "$DIR" || exit 1

if ! command -v zenity > /dev/null 2>&1
then
	echo "zenity is required for the graphical installer" >&2
	exit 1
fi

# friendly device name from the registry (best effort)
BOARD=$(cat /sys/class/dmi/id/board_name 2> /dev/null)
PRODUCT=$(cat /sys/class/dmi/id/product_name 2> /dev/null)
NAME="this handheld"
if [ -f custom/device-registry.sh ]
then
	. custom/device-registry.sh
	match=$(lookup_device "$BOARD" "$PRODUCT")
	[ -n "$match" ] && NAME=${match%|*}
fi

zenity --question --width 480 --title "Clover Dual Boot" \
	--text "Install the Clover boot menu on <b>$NAME</b>?\n\nThis switches your bootloader so you can choose SteamOS / Bazzite or Windows at startup. Your current bootloader is backed up first, and you can undo it anytime from the Clover app.\n\nYou'll be asked for your password next." || exit 0

PASS=$(zenity --password --title "Clover Dual Boot") || exit 0
if ! printf '%s\n' "$PASS" | sudo -S -v 2> /dev/null
then
	zenity --error --width 360 --title "Clover Dual Boot" --text "That password was rejected."
	exit 1
fi

LOG=$(mktemp)
# run the installer non-interactively and mirror its output into a pulsating
# progress window (lines prefixed with '# ' become the live status text)
CLOVER_SUDO_PASS="$PASS" CLOVER_NONINTERACTIVE=1 bash install-Clover.sh 2>&1 \
	| tee "$LOG" \
	| sed -u 's/^/# /' \
	| zenity --progress --pulsate --no-cancel --auto-close --width 540 \
		--title "Installing Clover" --text "Starting..."

if grep -q "Clover install completed" "$LOG"
then
	zenity --info --width 460 --title "Clover Dual Boot" \
		--text "Clover is installed!\n\nReboot to see the boot menu. You can change the default OS, theme, resolution and more from the <b>Clover Dual Boot</b> app."
else
	zenity --error --width 560 --title "Clover Dual Boot" \
		--text "The install did not finish. Last messages:\n\n$(tail -n 8 "$LOG")"
fi
rm -f "$LOG"
