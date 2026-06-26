#!/bin/bash

# Device registry for the Clover installer. Sourced by install-Clover.sh.
# To add a handheld, add one row below. Columns are pipe-separated:
#
#   match_field | match_value | friendly_name | action
#
#   match_field  : "board"   matches /sys/class/dmi/id/board_name
#                  "product" matches /sys/class/dmi/id/product_name
#   action       : a "WxH" resolution to set in Clover (controller driver installed)
#                  "nodriver" -> supported, no resolution change, no controller driver (Steam Deck)
#                  "blocked"  -> known incompatible, installer refuses to run

DEVICE_REGISTRY="\
board|Jupiter|Steam Deck|nodriver
board|Galileo|Steam Deck|nodriver
product|83L3|Legion Go S|1920x1200
product|83Q2|Legion Go S|1920x1200
product|83Q3|Legion Go S|1920x1200
product|83N6|Legion Go S|blocked
product|83E1|Legion Go|2560x1600
product|83N0|Legion Go 2|1920x1200
product|83N1|Legion Go 2|1920x1200
board|RC71L|Asus ROG Ally|1920x1080
board|RC72LA|Asus ROG Ally X|1920x1080
board|RC73YA|Asus ROG Xbox Ally|1920x1080
board|RC73XA|Asus ROG Xbox Ally X|1920x1080
product|ONEXPLAYER 2 PRO ARP23P|Onexplayer 2 Pro|2560x1600"

# Match the given board_name / product_name against the registry.
# Echoes "friendly_name|action" and returns 0 on a hit, returns 1 otherwise.
lookup_device() {
	local board="$1" product="$2" field value name action
	while IFS='|' read -r field value name action
	do
		[ -n "$field" ] || continue
		case "$field" in
			board)   [ "$board" = "$value" ]   && { echo "$name|$action"; return 0; } ;;
			product) [ "$product" = "$value" ] && { echo "$name|$action"; return 0; } ;;
		esac
	done <<EOF
$DEVICE_REGISTRY
EOF
	return 1
}
