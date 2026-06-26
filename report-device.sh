#!/bin/bash

# Prints the hardware identifiers needed to add a handheld to the installer.
# Read-only and needs no root. Paste the output into a device-request issue.
# Only model identifiers are printed - never the serial number or UUID.

echo "===== Handheld-Clover device report ====="

for field in sys_vendor product_name product_family board_name
do
	value=$(cat /sys/class/dmi/id/$field 2> /dev/null)
	printf '%-14s: %s\n' "$field" "${value:-(unavailable)}"
done

echo ""
echo "Internal panel (native mode is listed first):"
found=no
for modes in /sys/class/drm/*eDP*/modes /sys/class/drm/*DSI*/modes /sys/class/drm/*LVDS*/modes
do
	[ -f "$modes" ] || continue
	found=yes
	printf '  %-20s native=%s\n' "$(basename "$(dirname "$modes")")" "$(head -n1 "$modes")"
done
[ "$found" = yes ] || echo "  (no internal panel detected)"

echo ""
os=$(grep -E '^PRETTY_NAME=' /etc/os-release 2> /dev/null | cut -d = -f 2- | tr -d '"')
echo "OS: ${os:-(unknown)}"
echo "========================================="
echo "Open an issue with the block above to request support for this device."
