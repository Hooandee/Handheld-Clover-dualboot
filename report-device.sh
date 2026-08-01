#!/bin/bash

# Prints the hardware identifiers needed to add a handheld to the installer.
# Read-only and needs no root. Paste the output into a device-request issue.
# Only model identifiers are printed - never the serial number or UUID.

DIR=$(cd "$(dirname "$0")" && pwd)
SYS_ROOT=${CLOVER_SYS_ROOT:-}
DMI_ROOT="$SYS_ROOT/sys/class/dmi/id"
CLOVER_DRM_ROOT=${CLOVER_DRM_ROOT:-$SYS_ROOT/sys/class/drm}
export CLOVER_DRM_ROOT
. "$DIR/custom/device-registry.sh"
. "$DIR/custom/device-detection.sh"

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
		detected_profile) es='Perfil detectado'; en='Detected profile' ;;
		native_resolution) es='Resolución nativa'; en='Native resolution' ;;
		fallback_resolution) es='Resolución de respaldo'; en='Fallback resolution' ;;
		controller_policy) es='Política del mando UEFI'; en='UEFI controller policy' ;;
		*) es="$k"; en="$k" ;;
	esac
	if [ "$CLOVER_LANG" = en ]; then printf '%s\n' "$en"; else printf '%s\n' "$es"; fi
}

echo "===== Handheld-Clover device report ====="

for field in sys_vendor product_name product_family board_name
do
	value=$(cat "$DMI_ROOT/$field" 2> /dev/null)
	printf '%-14s: %s\n' "$field" "${value:-$(msg unavailable)}"
done

SYS_VENDOR=$(cat "$DMI_ROOT/sys_vendor" 2> /dev/null)
PRODUCT_NAME=$(cat "$DMI_ROOT/product_name" 2> /dev/null)
PRODUCT_FAMILY=$(cat "$DMI_ROOT/product_family" 2> /dev/null)
BOARD_NAME=$(cat "$DMI_ROOT/board_name" 2> /dev/null)
DEVICE_MATCH=$(lookup_device "$BOARD_NAME" "$PRODUCT_NAME" "$PRODUCT_FAMILY" "$SYS_VENDOR")
if [ -n "$DEVICE_MATCH" ]
then
	CONTROLLER_POLICY=${DEVICE_MATCH##*|}
	DEVICE_MATCH=${DEVICE_MATCH%|*}
	FALLBACK_RESOLUTION=${DEVICE_MATCH##*|}
	DEVICE_NAME=${DEVICE_MATCH%|*}
else
	DEVICE_NAME="Generic handheld"
	FALLBACK_RESOLUTION=""
	CONTROLLER_POLICY=ask
fi
NATIVE_RESOLUTION=$(detect_native_resolution)
printf '%s: %s\n' "$(msg detected_profile)" "$DEVICE_NAME"
printf '%s: %s\n' "$(msg native_resolution)" "${NATIVE_RESOLUTION:-$(msg unavailable)}"
printf '%s: %s\n' "$(msg fallback_resolution)" "${FALLBACK_RESOLUTION:-$(msg unavailable)}"
printf '%s: %s\n' "$(msg controller_policy)" "$CONTROLLER_POLICY"

echo ""
msg panel_header
found=no
for modes in "$CLOVER_DRM_ROOT"/*eDP*/modes "$CLOVER_DRM_ROOT"/*DSI*/modes "$CLOVER_DRM_ROOT"/*LVDS*/modes
do
	[ -f "$modes" ] || continue
	found=yes
	printf '  %-20s native=%s\n' "$(basename "$(dirname "$modes")")" "$(head -n1 "$modes")"
done
[ "$found" = yes ] || msg no_panel

echo ""
os=$(grep -E '^PRETTY_NAME=' "$SYS_ROOT/etc/os-release" 2> /dev/null | cut -d = -f 2- | tr -d '"')
echo "OS: ${os:-$(msg unknown)}"
echo "========================================="
msg request_issue
