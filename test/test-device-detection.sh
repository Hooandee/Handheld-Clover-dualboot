#!/bin/bash

# Verifies the device registry resolves every known handheld to the same
# behavior the installer used before the registry refactor. Pure logic, no
# root and no /sys access - safe to run anywhere. Run: bash test/test-device-detection.sh

DIR=$(cd "$(dirname "$0")/.." && pwd)
. "$DIR/custom/device-registry.sh"

fail=0
check() { # board product expected
	got=$(lookup_device "$1" "$2")
	if [ "$got" = "$3" ]
	then
		printf 'ok   board=%-8s product=%-24s -> %s\n' "'$1'" "'$2'" "$got"
	else
		printf 'FAIL board=%-8s product=%-24s -> %s (expected %s)\n' "'$1'" "'$2'" "$got" "$3"
		fail=1
	fi
}

check Jupiter ""                      "Steam Deck|nodriver"
check Galileo ""                      "Steam Deck|nodriver"
check "" 83L3                         "Legion Go S|1920x1200"
check "" 83Q2                         "Legion Go S|1920x1200"
check "" 83Q3                         "Legion Go S|1920x1200"
check "" 83N6                         "Legion Go S|blocked"
check "" 83E1                         "Legion Go|2560x1600"
check "" 83N0                         "Legion Go 2|1920x1200"
check "" 83N1                         "Legion Go 2|1920x1200"
check RC71L ""                        "Asus ROG Ally|1920x1080"
check RC72LA ""                       "Asus ROG Ally X|1920x1080"
check RC73YA ""                       "Asus ROG Xbox Ally|1920x1080"
check RC73XA ""                       "Asus ROG Xbox Ally X|1920x1080"
check "" "ONEXPLAYER 2 PRO ARP23P"    "Onexplayer 2 Pro|2560x1600"
check WeirdBoard WeirdProduct         ""

echo "---"
if [ "$fail" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; exit 1; fi
