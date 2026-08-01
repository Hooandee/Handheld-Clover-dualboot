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

DETECTION_HELPER="$DIR/custom/device-detection.sh"
if [ -f "$DETECTION_HELPER" ]
then
	. "$DETECTION_HELPER"
else
	printf 'FAIL shared device-detection helper is missing\n'
	fail=1
fi

if command -v detect_native_resolution > /dev/null 2>&1
then
	DRM_FIXTURE=$(mktemp -d)
	expect_resolution() { # raw expected
		rm -rf "$DRM_FIXTURE/card0-eDP-1"
		mkdir -p "$DRM_FIXTURE/card0-eDP-1"
		printf '%s\n' "$1" > "$DRM_FIXTURE/card0-eDP-1/modes"
		got=$(CLOVER_DRM_ROOT="$DRM_FIXTURE" detect_native_resolution)
		if [ "$got" = "$2" ]
		then
			printf 'ok   panel mode %-12s -> %s\n' "'$1'" "${got:-<none>}"
		else
			printf 'FAIL panel mode %-12s -> %s (expected %s)\n' \
				"'$1'" "${got:-<none>}" "${2:-<none>}"
			fail=1
		fi
	}

	expect_resolution 1920x1200 1920x1200
	expect_resolution 1200x1920 1920x1200
	expect_resolution garbage ""
	expect_resolution "" ""
	rm -rf "$DRM_FIXTURE"
fi

if command -v controller_driver_enabled > /dev/null 2>&1
then
	expect_driver() { # policy noninteractive answer expected
		got=$(controller_driver_enabled "$1" "$2" "$3")
		if [ "$got" = "$4" ]
		then
			printf 'ok   controller policy=%-4s noninteractive=%s answer=%-3s -> %s\n' \
				"$1" "$2" "${3:-<none>}" "$got"
		else
			printf 'FAIL controller policy=%s noninteractive=%s answer=%s -> %s (expected %s)\n' \
				"$1" "$2" "${3:-<none>}" "$got" "$4"
			fail=1
		fi
	}

	expect_driver xpad 1 "" yes
	expect_driver none 0 y no
	expect_driver ask 1 y no
	expect_driver ask 0 y yes
	expect_driver ask 0 n no
	expect_driver "" 1 y no
fi

if command -v resolve_install_profile > /dev/null 2>&1
then
	expect_profile() { # board product family vendor expected
		got=$(CLOVER_DRM_ROOT="$DRM_FIXTURE" resolve_install_profile "$1" "$2" "$3" "$4")
		if [ "$got" = "$5" ]
		then
			printf 'ok   install profile product=%-20s -> %s\n' "'$2'" "$got"
		else
			printf 'FAIL install profile product=%s -> %s (expected %s)\n' \
				"'$2'" "$got" "$5"
			fail=1
		fi
	}

	rm -rf "$DRM_FIXTURE"
	mkdir -p "$DRM_FIXTURE"
	expect_profile "" 83N6000MSB "" Lenovo \
		"Legion Go S|1920x1200|registry|none"
	expect_profile RC72LA "" "" ASUSTeK \
		"ROG Ally X|1920x1080|registry|xpad"
	expect_profile "" "Claw 8 AI+ A2VM" "" MSI \
		"MSI Claw 8 AI+|1920x1200|registry|ask"
	expect_profile WeirdBoard WeirdProduct "" Unknown \
		"Generic handheld||none|ask"

	mkdir -p "$DRM_FIXTURE/card0-eDP-1"
	printf '%s\n' 1200x1920 > "$DRM_FIXTURE/card0-eDP-1/modes"
	expect_profile WeirdBoard WeirdProduct "" Unknown \
		"Generic handheld|1920x1200|drm|ask"
	rm -rf "$DRM_FIXTURE"
else
	printf 'FAIL resolve_install_profile is missing\n'
	fail=1
fi

echo "---"
if [ "$fail" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; exit 1; fi
