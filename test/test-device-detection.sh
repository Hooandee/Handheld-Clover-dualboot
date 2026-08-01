#!/bin/bash

# Verifies the device registry resolves every known handheld to the same
# behavior the installer used before the registry refactor. Pure logic, no
# root and no /sys access - safe to run anywhere. Run: bash test/test-device-detection.sh

DIR=$(cd "$(dirname "$0")/.." && pwd)
. "$DIR/custom/device-registry.sh"

fail=0
check() { # board product family vendor expected
	got=$(lookup_device "$1" "$2" "$3" "$4")
	if [ "$got" = "$5" ]
	then
		printf 'ok   board=%-8s product=%-24s -> %s\n' "'$1'" "'$2'" "$got"
	else
		printf 'FAIL board=%-8s product=%-24s -> %s (expected %s)\n' "'$1'" "'$2'" "$got" "$5"
		fail=1
	fi
}

check Jupiter "" "" Valve            "Steam Deck|1280x800|none"
check Galileo "" "" Valve            "Steam Deck OLED|1280x800|none"
check "" 83L3 "" Lenovo               "Legion Go S|1920x1200|xpad"
check "" 83L30030US "" Lenovo         "Legion Go S|1920x1200|xpad"
check "" 83Q2ABC "" Lenovo            "Legion Go S|1920x1200|xpad"
check "" 83Q3ABC "" Lenovo            "Legion Go S|1920x1200|xpad"
check "" 83N6 "" Lenovo               "Legion Go S|1920x1200|none"
check "" 83N6000MSB "" LENOVO         "Legion Go S|1920x1200|none"
check "" UnknownSku "Legion Go S 8APU1" Lenovo \
	"Legion Go S|1920x1200|none"
check "" 83E1ABC "" Lenovo            "Legion Go|2560x1600|xpad"
check "" 83N0ABC "" Lenovo            "Legion Go 2|1920x1200|xpad"
check "" 83N1ABC "" Lenovo            "Legion Go 2|1920x1200|xpad"
check RC71L "" "" ASUSTeK            "ROG Ally|1920x1080|xpad"
check RC72LA "" "" ASUSTeK           "ROG Ally X|1920x1080|xpad"
check RC73YA "" "" ASUSTeK           "ROG Xbox Ally|1920x1080|xpad"
check rc73xa "" "" ASUSTeK           "ROG Xbox Ally X|1920x1080|xpad"
check "" "ROG Ally RC71L_RC71L" "" ASUSTeK \
	"ROG Ally|1920x1080|xpad"
check "" "ROG Ally X RC72LA_RC72LA" "" ASUSTeK \
	"ROG Ally X|1920x1080|xpad"
check "" "ROG Xbox Ally RC73YA_RC73YA" "" ASUSTeK \
	"ROG Xbox Ally|1920x1080|xpad"
check "" "ROG Xbox Ally X RC73XA" "" ASUSTeK \
	"ROG Xbox Ally X|1920x1080|xpad"
check "" "Claw 8 AI+ A2VM" "" MSI     "MSI Claw 8 AI+|1920x1200|ask"
check "" "ONEXPLAYER 2 PRO ARP23P" "" ONE-NETBOOK \
	"OneXPlayer 2 Pro|2560x1600|xpad"
check WeirdBoard WeirdProduct "" Unknown ""

echo "---"
if [ "$fail" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; exit 1; fi
