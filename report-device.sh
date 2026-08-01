#!/bin/bash

# Prints the hardware identifiers needed to add a handheld to the installer.
# Read-only and needs no root. Paste the output into a device-request issue.
# Only model identifiers are printed - never the serial number or UUID.

CLOVER_LANG=${CLOVER_LANG:-}
case "$CLOVER_LANG" in
	es|en) ;;
	*)
		CLOVER_LANG=$(cat ~/1Clover-tools/lang 2> /dev/null)
		case "$CLOVER_LANG" in es|en) ;; *) CLOVER_LANG=es ;; esac
		;;
esac

msg() {
	local k=$1
	local es en
	case "$k" in
		panel_header) es='Panel interno (el modo nativo aparece primero):'; en='Internal panel (native mode is listed first):' ;;
		no_panel) es='  (no se detectó panel interno)'; en='  (no internal panel detected)' ;;
		request_issue) es='Abre una incidencia con el bloque de arriba para solicitar soporte para este dispositivo.'; en='Open an issue with the block above to request support for this device.' ;;
		unavailable) es='(no disponible)'; en='(unavailable)' ;;
		unknown) es='(desconocido)'; en='(unknown)' ;;
		*) es="$k"; en="$k" ;;
	esac
	if [ "$CLOVER_LANG" = en ]; then printf '%s\n' "$en"; else printf '%s\n' "$es"; fi
}

echo "===== Handheld-Clover device report ====="

for field in sys_vendor product_name product_family board_name
do
	value=$(cat /sys/class/dmi/id/$field 2> /dev/null)
	printf '%-14s: %s\n' "$field" "${value:-$(msg unavailable)}"
done

echo ""
msg panel_header
found=no
for modes in /sys/class/drm/*eDP*/modes /sys/class/drm/*DSI*/modes /sys/class/drm/*LVDS*/modes
do
	[ -f "$modes" ] || continue
	found=yes
	printf '  %-20s native=%s\n' "$(basename "$(dirname "$modes")")" "$(head -n1 "$modes")"
done
[ "$found" = yes ] || msg no_panel

echo ""
os=$(grep -E '^PRETTY_NAME=' /etc/os-release 2> /dev/null | cut -d = -f 2- | tr -d '"')
echo "OS: ${os:-$(msg unknown)}"
echo "========================================="
msg request_issue
