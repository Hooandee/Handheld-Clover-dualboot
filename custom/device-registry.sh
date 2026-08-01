#!/bin/bash

# Device capabilities used by the Clover installer.
# Columns are pipe-separated:
#
#   match_field | match_mode | match_value | friendly_name | fallback_resolution | controller_policy | required_vendor
#
# match_field       : board, product, family or vendor
# match_mode        : exact, prefix or contains
# controller_policy : xpad installs UsbXbox360Dxe.efi
#                     none never installs it on this hardware
#                     ask lets an interactive user opt in, defaulting to none

DEVICE_REGISTRY="\
board|exact|Jupiter|Steam Deck|1280x800|none|VALVE
board|exact|Galileo|Steam Deck OLED|1280x800|none|VALVE
board|exact|RC71L|ROG Ally|1920x1080|xpad|ASUSTEK
board|exact|RC72LA|ROG Ally X|1920x1080|xpad|ASUSTEK
board|exact|RC73YA|ROG Xbox Ally|1920x1080|xpad|ASUSTEK
board|exact|RC73XA|ROG Xbox Ally X|1920x1080|xpad|ASUSTEK
product|contains|ROG Xbox Ally X|ROG Xbox Ally X|1920x1080|xpad|ASUSTEK
product|contains|ROG Xbox Ally|ROG Xbox Ally|1920x1080|xpad|ASUSTEK
product|contains|ROG Ally X|ROG Ally X|1920x1080|xpad|ASUSTEK
product|contains|ROG Ally|ROG Ally|1920x1080|xpad|ASUSTEK
product|prefix|83N6|Legion Go S|1920x1200|none|LENOVO
product|prefix|83L3|Legion Go S|1920x1200|xpad|LENOVO
product|prefix|83Q2|Legion Go S|1920x1200|xpad|LENOVO
product|prefix|83Q3|Legion Go S|1920x1200|xpad|LENOVO
product|prefix|83N0|Legion Go 2|1920x1200|xpad|LENOVO
product|prefix|83N1|Legion Go 2|1920x1200|xpad|LENOVO
product|prefix|83E1|Legion Go|2560x1600|xpad|LENOVO
family|contains|Legion Go S|Legion Go S|1920x1200|none|LENOVO
family|contains|Legion Go 2|Legion Go 2|1920x1200|xpad|LENOVO
product|contains|Claw 8 AI+|MSI Claw 8 AI+|1920x1200|ask|MICRO-STAR
product|contains|Claw 8 AI+|MSI Claw 8 AI+|1920x1200|ask|MSI
product|exact|ONEXPLAYER 2 PRO ARP23P|OneXPlayer 2 Pro|2560x1600|xpad|ONE-NETBOOK"

normalize_dmi_value() {
	printf '%s' "$1" \
		| sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
		| tr '[:lower:]' '[:upper:]'
}

registry_candidate() {
	case "$1" in
		board) printf '%s' "$2" ;;
		product) printf '%s' "$3" ;;
		family) printf '%s' "$4" ;;
		vendor) printf '%s' "$5" ;;
		*) return 1 ;;
	esac
}

registry_matches() {
	case "$1" in
		exact) [ "$2" = "$3" ] ;;
		prefix) case "$2" in "$3"*) return 0 ;; *) return 1 ;; esac ;;
		contains) case "$2" in *"$3"*) return 0 ;; *) return 1 ;; esac ;;
		*) return 1 ;;
	esac
}

# Echoes "friendly_name|fallback_resolution|controller_policy" on a hit.
lookup_device() {
	local board="$1" product="$2" family="${3:-}" vendor="${4:-}"
	local field mode value name resolution controller required_vendor
	local candidate wanted normalized_vendor wanted_vendor
	normalized_vendor=$(normalize_dmi_value "$vendor")
	while IFS='|' read -r field mode value name resolution controller required_vendor
	do
		[ -n "$field" ] || continue
		if [ -n "$required_vendor" ]
		then
			wanted_vendor=$(normalize_dmi_value "$required_vendor")
			registry_matches contains "$normalized_vendor" "$wanted_vendor" || continue
		fi
		candidate=$(registry_candidate "$field" "$board" "$product" "$family" "$vendor") \
			|| continue
		candidate=$(normalize_dmi_value "$candidate")
		wanted=$(normalize_dmi_value "$value")
		if registry_matches "$mode" "$candidate" "$wanted"
		then
			printf '%s|%s|%s\n' "$name" "$resolution" "$controller"
			return 0
		fi
	done <<EOF
$DEVICE_REGISTRY
EOF
	return 1
}
