#!/bin/bash

DIR=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
fail=0

expect() {
	if [ "$2" = "$3" ]; then
		echo "ok   $1 -> $2"
	else
		echo "FAIL $1 -> '$2' (expected '$3')"
		fail=1
	fi
}

. "$DIR/custom/install-layout.sh"

layout='{"safe_to_write":true,"requires_confirmation":false,"host_os":{"profile":"cachyos","name":"CachyOS"},"linux_loader":{"kind":"limine","path":"\\EFI\\limine\\limine_x64.efi"},"clover_target":{"device":"/dev/nvme0n1p5","disk":"/dev/nvme0n1","partition":5,"partuuid":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","mountpoints":["/boot"]},"windows":{"device":"/dev/nvme0n1p1","disk":"/dev/nvme0n1","partition":1,"mountpoints":[],"state":"active"},"clover":{"entry_ids":["0009"]},"firmware":{"boot_order":["0002","0001","0009"]},"problems":[]}'
eval "$(printf '%s' "$layout" | install_layout_vars)"

expect "layout is safe" "$INSTALL_LAYOUT_SAFE" "yes"
expect "CachyOS profile is retained" "$INSTALL_OS_PROFILE" "cachyos"
expect "target device is dynamic" "$INSTALL_TARGET_DEVICE" "/dev/nvme0n1p5"
expect "target disk is dynamic" "$INSTALL_TARGET_DISK" "/dev/nvme0n1"
expect "target partition is dynamic" "$INSTALL_TARGET_PARTITION" "5"
expect "Linux loader is retained" "$INSTALL_LINUX_LOADER" "\EFI\limine\limine_x64.efi"
expect "Windows-first ESP remains separate" "$INSTALL_WINDOWS_DEVICE" "/dev/nvme0n1p1"
expect "original BootOrder is retained for rollback" "$INSTALL_ORIGINAL_BOOT_ORDER" "0002,0001,0009"
expect "original Clover IDs are retained for rollback" "$INSTALL_ORIGINAL_CLOVER_IDS" "0009"
expect "original Windows state is retained for rollback" "$INSTALL_WINDOWS_STATE" "active"

firmware_output='Boot0009* Clover - GUI Boot Manager HD(5,GPT,aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa,0x800,0x100000)/File(\EFI\clover\cloverx64.efi)
Boot000A* Stale Clover HD(1,GPT,bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb,0x800,0x100000)/File(\EFI\clover\cloverx64.efi)
Boot000B* Linux HD(5,GPT,aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa,0x800,0x100000)/File(\EFI\Linux\linux.efi)'
ids=$(printf '%s\n' "$firmware_output" | install_clover_ids_from_firmware "$INSTALL_TARGET_PARTUUID")
expect "rollback IDs require the exact target ESP and loader" "$ids" "0009"
expect "CSV difference isolates newly created entries" "$(install_csv_difference '0009,000A' '0009')" "000A"

mkdir -p "$TMP/esp/efi/BOOT" "$TMP/esp/efi/vendor"
printf canonical > "$TMP/esp/efi/BOOT/bootx64.efi"
printf vendor > "$TMP/esp/efi/vendor/bootx64.efi"
expect "EFI directory lookup ignores case" "$(install_efi_root "$TMP/esp")" "$TMP/esp/efi"
expect "canonical fallback ignores vendor BOOTX64 names" \
	"$(install_bootx64_path "$TMP/esp/efi")" "$TMP/esp/efi/BOOT/bootx64.efi"
rm -rf "$TMP/esp/efi/BOOT"
expect "missing canonical fallback uses EFI/BOOT" \
	"$(install_bootx64_path "$TMP/esp/efi")" "$TMP/esp/efi/BOOT/BOOTX64.EFI"

GENERIC_CONFIG="$TMP/generic.plist"
cp "$DIR/custom/config.plist" "$GENERIC_CONFIG"
install_add_generic_entry "$GENERIC_CONFIG" '\EFI\ubuntu\shimx64.efi' \
	'cccccccc-cccc-cccc-cccc-cccccccccccc' 'Ubuntu 26.04'
generic_entry=$(python3 - "$GENERIC_CONFIG" <<'PY'
import plistlib, sys
p = plistlib.load(open(sys.argv[1], "rb"))
entries = p["GUI"]["Custom"]["Entries"]
e = next(x for x in entries if x.get("Path", "").lower() == "\\efi\\ubuntu\\shimx64.efi")
print(f'{e["Volume"]}|{e["FullTitle"]}')
PY
)
expect "confirmed generic loader gets a scoped visible menu entry" "$generic_entry" \
	"CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC|Ubuntu 26.04"

rm -rf "$TMP"
echo "---"
if [ "$fail" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; exit 1; fi
