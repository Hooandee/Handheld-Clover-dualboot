#!/bin/bash

# Exercises clover-ctl read/write against a throwaway copy of the real
# config.plist. Pure userspace (CLOVER_CONFIG override skips the root paths),
# so it runs anywhere. Run: bash test/test-clover-ctl.sh

DIR=$(cd "$(dirname "$0")/.." && pwd)
CTL="$DIR/clover-ctl"
TMP=$(mktemp)
cp "$DIR/custom/config.plist" "$TMP"
export CLOVER_CONFIG="$TMP"
export CLOVER_CTL_ALLOW_NONROOT=1
EFI=$(mktemp -d)
export CLOVER_EFI_PATH="$EFI"
mkdir -p "$EFI/clover/themes"

fail=0
expect() { # description actual expected
	if [ "$2" = "$3" ]; then
		echo "ok   $1 -> $2"
	else
		echo "FAIL $1 -> '$2' (expected '$3')"
		fail=1
	fi
}

# reads against the shipped config.plist defaults
expect "get theme"        "$(bash "$CTL" get theme)"        "Eclipse"
expect "get resolution"   "$(bash "$CTL" get resolution)"   "1280x800"
expect "get timeout"      "$(bash "$CTL" get timeout)"      "15"
expect "get default-os"   "$(bash "$CTL" get default-os)"   "steamos"

# config writes round-trip
bash "$CTL" set-resolution 1920x1080 > /dev/null
expect "set/get resolution" "$(bash "$CTL" get resolution)" "1920x1080"

mkdir -p "$EFI/clover/themes/Catalina"
bash "$CTL" set-theme Missing > /dev/null 2>&1; expect "set-theme rejects a missing theme" "$?" "1"
bash "$CTL" set-theme Catalina > /dev/null
expect "set/get theme"      "$(bash "$CTL" get theme)"      "Catalina"
rm -rf "$EFI/clover/themes/Catalina"

bash "$CTL" set-timeout 5 > /dev/null
expect "set/get timeout"    "$(bash "$CTL" get timeout)"    "5"

bash "$CTL" set-default-os windows > /dev/null
expect "default-os windows" "$(bash "$CTL" get default-os)" "windows"
bash "$CTL" set-default-os bazzite > /dev/null
expect "default-os bazzite" "$(bash "$CTL" get default-os)" "bazzite"
bash "$CTL" set-default-os lastos > /dev/null
expect "default-os lastos"  "$(bash "$CTL" get default-os)" "lastos"
bash "$CTL" set-default-loader '\EFI\limine\limine_x64.efi' > /dev/null
expect "dynamic CachyOS loader becomes default" "$(bash "$CTL" get default-os)" "cachyos"

VOLUME_DISCOVERY=$(mktemp)
cat > "$VOLUME_DISCOVERY" <<'EOF'
#!/usr/bin/env python3
import json
print(json.dumps({
    "linux_loader": {
        "path": "\\EFI\\limine\\limine_x64.efi",
        "partuuid": "55555555-5555-5555-5555-555555555555"
    },
    "windows": {
        "device": "/dev/sdb1",
        "partuuid": "11111111-1111-1111-1111-111111111111"
    },
    "problems": []
}))
EOF
chmod +x "$VOLUME_DISCOVERY"
CLOVER_DISCOVERY="$VOLUME_DISCOVERY" bash "$CTL" set-default-os windows > /dev/null
expect "Windows default selects its separate ESP GUID" \
	"$(python3 -c 'import plistlib,sys; print(plistlib.load(open(sys.argv[1], "rb"))["Boot"]["DefaultVolume"])' "$TMP")" \
	"11111111-1111-1111-1111-111111111111"
CLOVER_DISCOVERY="$VOLUME_DISCOVERY" bash "$CTL" set-default-loader '\EFI\limine\limine_x64.efi' > /dev/null
expect "Linux default selects its separate ESP GUID" \
	"$(python3 -c 'import plistlib,sys; print(plistlib.load(open(sys.argv[1], "rb"))["Boot"]["DefaultVolume"])' "$TMP")" \
	"55555555-5555-5555-5555-555555555555"
rm -f "$VOLUME_DISCOVERY"

# auto resolution: no panel here, so it should fail cleanly (not write garbage)
bash "$CTL" set-resolution auto > /dev/null 2>&1
expect "auto fails cleanly, value unchanged" "$(bash "$CTL" get resolution)" "1920x1080"

# validation + help
bash "$CTL" set-timeout abc > /dev/null 2>&1; expect "reject bad timeout (exit!=0)" "$?" "1"
EMPTY_CONFIG=$(mktemp)
CLOVER_CONFIG="$EMPTY_CONFIG" bash "$CTL" set-timeout 7 > /dev/null 2>&1
expect "config write fails when the key is missing" "$?" "1"
rm -f "$EMPTY_CONFIG" "$EMPTY_CONFIG.cloverctl.tmp"
PAIR_CONFIG=$(mktemp)
awk '/<key>DefaultVolume<\/key>/ { getline; next } { print }' "$DIR/custom/config.plist" > "$PAIR_CONFIG"
CLOVER_CONFIG="$PAIR_CONFIG" bash "$CTL" set-default-os windows > /dev/null 2>&1
expect "multi-key config write fails when one key is missing" "$?" "1"
expect "failed multi-key write leaves loader unchanged" "$(CLOVER_CONFIG="$PAIR_CONFIG" bash "$CTL" get default-os)" "steamos"
rm -f "$PAIR_CONFIG" "$PAIR_CONFIG.cloverctl.tmp"
bash "$CTL" help > /dev/null 2>&1;            expect "help exits 0" "$?" "0"
case "$(bash "$CTL" help)" in
	*submit-report*) expect "help exposes only the working local report flow" yes no ;;
	*) expect "help exposes only the working local report flow" no no ;;
esac
bash "$CTL" bogus > /dev/null 2>&1;           expect "unknown cmd exits 1" "$?" "1"
MAINTENANCE_LOG=$(mktemp)
printf 'fictional maintenance result\n' > "$MAINTENANCE_LOG"
expect "maintenance log is available to the graphical frontends" \
	"$(CLOVER_STATUS="$MAINTENANCE_LOG" bash "$CTL" maintenance-log)" \
	"fictional maintenance result"
rm -f "$MAINTENANCE_LOG"

# status emits parseable-looking JSON carrying the current values
status=$(bash "$CTL" status)
case "$status" in
	*'"resolution":"1920x1080"'*'"theme":"Catalina"'*) expect "status JSON reflects writes" yes yes ;;
	*) expect "status JSON reflects writes" "$status" "<json with resolution+theme>" ;;
esac

# theme install/remove — offline paths only (sanitize, 5-theme cap, active-theme guard)
bash "$CTL" install-theme "evil/path" > /dev/null 2>&1; expect "install-theme rejects slash" "$?" "1"

# Clover ships a special "random" selector alongside four real themes. It must
# not consume a theme slot or fresh installs can never add their first theme.
FAKEBIN=$(mktemp -d)
printf '%s\n' '#!/bin/sh' 'mkdir -p "$4"' 'printf "<plist/>\\n" > "$4/theme.plist"' > "$FAKEBIN/python3"
chmod +x "$FAKEBIN/python3"
mkdir -p "$EFI/clover/themes/"{random,A,B,C,D}
PATH="$FAKEBIN:$PATH" bash "$CTL" install-theme NewOne > /dev/null 2>&1
expect "random selector does not consume a theme slot" "$?" "0"
expect "theme below cap was installed" "$([ -d "$EFI/clover/themes/NewOne" ] && echo yes || echo no)" "yes"
status=$(bash "$CTL" status)
case "$status" in
	*'"theme_count":5'*) expect "status excludes random from theme count" yes yes ;;
	*) expect "status excludes random from theme count" "$status" "<json with theme_count=5>" ;;
esac
rm -rf "$EFI/clover/themes/"{A,B,C,D,NewOne}

mkdir -p "$EFI/clover/.theme-operation.lock"
printf '%s\n' "$$" > "$EFI/clover/.theme-operation.lock/pid"
PATH="$FAKEBIN:$PATH" bash "$CTL" install-theme NewOne > /dev/null 2>&1
expect "install-theme refuses a concurrent install" "$?" "1"
expect "concurrent install did not publish a theme" "$([ -d "$EFI/clover/themes/NewOne" ] && echo yes || echo no)" "no"
rm -f "$EFI/clover/.theme-operation.lock/pid"
rmdir "$EFI/clover/.theme-operation.lock"

mkdir -p "$EFI/clover/themes/Alpha"
PATH="$FAKEBIN:$PATH" bash "$CTL" install-theme alpha > /dev/null 2>&1
expect "install-theme rejects case-insensitive duplicate" "$?" "1"
rm -rf "$EFI/clover/themes/Alpha" "$EFI/clover/themes/alpha"

mkdir -p "$EFI/clover/themes/"{A,B,C,D,E}
bash "$CTL" install-theme NewOne > /dev/null 2>&1; expect "install-theme enforces 5-theme cap" "$?" "1"
rm -rf "$EFI/clover/themes/"{A,B,C,D,E}

mkdir -p "$EFI/clover/themes/Eclipse"
bash "$CTL" set-theme Eclipse > /dev/null
bash "$CTL" remove-theme Eclipse > /dev/null 2>&1; expect "remove-theme refuses active theme" "$?" "1"

rm -rf "$EFI/clover/themes/Eclipse"
mkdir -p "$EFI/clover/themes/eCLIPSE"
bash "$CTL" remove-theme eCLIPSE > /dev/null 2>&1
expect "remove-theme compares active theme case-insensitively" "$?" "1"
expect "case-variant active theme was preserved" "$([ -d "$EFI/clover/themes/eCLIPSE" ] && echo yes || echo no)" "yes"

mkdir -p "$EFI/clover/themes/Mojave"
bash "$CTL" remove-theme Mojave > /dev/null 2>&1; expect "remove-theme exit 0 for inactive theme" "$?" "0"
expect "remove-theme deleted the dir" "$([ -d "$EFI/clover/themes/Mojave" ] && echo yes || echo no)" "no"

bash "$CTL" remove-theme "../etc" > /dev/null 2>&1; expect "remove-theme rejects traversal" "$?" "1"
bash "$CTL" remove-theme "." > /dev/null 2>&1; expect "remove-theme rejects dot" "$?" "1"
bash "$CTL" remove-theme random > /dev/null 2>&1; expect "remove-theme preserves random selector" "$?" "1"

# Windows EFI protection is transactional and refreshes the restorable backup
# when Windows places a newer loader back in its canonical path.
WIN_BOOT="$EFI/Microsoft/Boot"
mkdir -p "$WIN_BOOT"
printf 'windows-v1\n' > "$WIN_BOOT/bootmgfw.efi"
bash "$CTL" protect-windows-efi > /dev/null 2>&1
expect "first Windows EFI protection succeeds" "$?" "0"
expect "canonical Windows loader was disabled" "$([ -e "$WIN_BOOT/bootmgfw.efi" ] && echo yes || echo no)" "no"
expect "restorable Windows backup was created" "$(cat "$WIN_BOOT/bootmgfw.efi.orig")" "windows-v1"
expect "disabled Windows loader was preserved" "$(cat "$EFI/Microsoft/bootmgfw.efi")" "windows-v1"

printf 'windows-v2\n' > "$WIN_BOOT/bootmgfw.efi"
bash "$CTL" protect-windows-efi > /dev/null 2>&1
expect "Windows update protection succeeds" "$?" "0"
expect "backup refreshes to the updated loader" "$(cat "$WIN_BOOT/bootmgfw.efi.orig")" "windows-v2"
expect "previous known backup is retained" "$(cat "$WIN_BOOT/bootmgfw.efi.orig.prev")" "windows-v1"
expect "disabled loader refreshes to the update" "$(cat "$EFI/Microsoft/bootmgfw.efi")" "windows-v2"

printf 'windows-v3\n' > "$EFI/Microsoft/bootmgfw.efi"
bash "$CTL" protect-windows-efi > /dev/null 2>&1
expect "stale backup refresh succeeds without canonical loader" "$?" "0"
expect "stale backup refreshes from preserved loader" "$(cat "$WIN_BOOT/bootmgfw.efi.orig")" "windows-v3"
expect "stale backup rotation retains prior version" "$(cat "$WIN_BOOT/bootmgfw.efi.orig.prev")" "windows-v2"

SEPARATE_WIN_EFI=$(mktemp -d)
mkdir -p "$SEPARATE_WIN_EFI/Microsoft/Boot"
printf 'windows-separate\n' > "$SEPARATE_WIN_EFI/Microsoft/Boot/bootmgfw.efi"
CLOVER_WINDOWS_EFI_PATH="$SEPARATE_WIN_EFI" bash "$CTL" protect-windows-efi > /dev/null 2>&1
expect "Windows protection supports a separate ESP" "$?" "0"
expect "separate Windows loader backup is verified" "$(cat "$SEPARATE_WIN_EFI/Microsoft/Boot/bootmgfw.efi.orig")" "windows-separate"
expect "separate Windows canonical loader is disabled" "$([ -e "$SEPARATE_WIN_EFI/Microsoft/Boot/bootmgfw.efi" ] && echo yes || echo no)" "no"
CLOVER_WINDOWS_EFI_PATH="$SEPARATE_WIN_EFI" bash "$CTL" restore-windows-efi > /dev/null 2>&1
expect "Windows restoration supports a separate ESP" "$?" "0"
expect "restored Windows loader is verified" "$(cat "$SEPARATE_WIN_EFI/Microsoft/Boot/bootmgfw.efi")" "windows-separate"
rm -rf "$SEPARATE_WIN_EFI"

rm -f "$WIN_BOOT/bootmgfw.efi" "$WIN_BOOT/bootmgfw.efi.orig" \
	"$WIN_BOOT/bootmgfw.efi.orig.prev" "$EFI/Microsoft/bootmgfw.efi"
bash "$CTL" protect-windows-efi > /dev/null 2>&1
expect "missing Windows loader and backup fails closed" "$?" "1"

BOOT_DIR="$EFI/boot"
mkdir -p "$BOOT_DIR"
printf 'original-loader\n' > "$BOOT_DIR/bootx64.efi"
printf 'clover-loader\n' > "$EFI/cloverx64.efi"
CLOVER_BOOTX_PATH="$BOOT_DIR/bootx64.efi" bash "$CTL" install-clover-loader "$EFI/cloverx64.efi" > /dev/null 2>&1
expect "verified Clover loader publication succeeds" "$?" "0"
expect "original BOOTX64 backup is preserved" "$(cat "$BOOT_DIR/bootx64.efi.orig")" "original-loader"
expect "Clover loader becomes canonical BOOTX64" "$(cat "$BOOT_DIR/bootx64.efi")" "clover-loader"
: > "$BOOT_DIR/bootx64.efi.orig"
CLOVER_BOOTX_PATH="$BOOT_DIR/bootx64.efi" bash "$CTL" install-clover-loader "$EFI/cloverx64.efi" > /dev/null 2>&1
expect "empty BOOTX64 backup fails closed" "$?" "1"

EMPTY_FALLBACK=$(mktemp -d)
mkdir -p "$EMPTY_FALLBACK/BOOT"
printf 'clover-new-fallback\n' > "$EMPTY_FALLBACK/cloverx64.efi"
CLOVER_BOOTX_PATH="$EMPTY_FALLBACK/BOOT/BOOTX64.EFI" \
	bash "$CTL" install-clover-loader "$EMPTY_FALLBACK/cloverx64.efi" > /dev/null 2>&1
expect "Clover fallback can be installed when no fallback existed" "$?" "0"
expect "new fallback contains Clover" "$(cat "$EMPTY_FALLBACK/BOOT/BOOTX64.EFI")" "clover-new-fallback"
expect "missing-original marker is recorded" "$([ -f "$EMPTY_FALLBACK/BOOT/BOOTX64.EFI.clover-no-original" ] && echo yes || echo no)" "yes"
CLOVER_BOOTX_PATH="$EMPTY_FALLBACK/BOOT/BOOTX64.EFI" \
	bash "$CTL" restore-clover-loader "$EMPTY_FALLBACK/cloverx64.efi" > /dev/null 2>&1
expect "restore returns to an originally absent fallback" "$?" "0"
expect "restore removes only the verified Clover fallback" "$([ -e "$EMPTY_FALLBACK/BOOT/BOOTX64.EFI" ] && echo yes || echo no)" "no"
expect "restore removes the missing-original marker" "$([ -e "$EMPTY_FALLBACK/BOOT/BOOTX64.EFI.clover-no-original" ] && echo yes || echo no)" "no"
rm -rf "$EMPTY_FALLBACK"

BOOT_TEST=$(mktemp -d)
BOOT_ESP="$BOOT_TEST/esp"
BOOT_BIN="$BOOT_TEST/bin"
BOOT_STATE="$BOOT_TEST/efiboot-state"
BOOT_CALLS="$BOOT_TEST/efiboot-calls"
mkdir -p "$BOOT_ESP/EFI/steamos" "$BOOT_ESP/EFI/Clover" "$BOOT_ESP/EFI/BOOT" "$BOOT_BIN"
printf steam > "$BOOT_ESP/EFI/steamos/steamcl.efi"
printf clover > "$BOOT_ESP/EFI/Clover/cloverx64.efi"
printf clover > "$BOOT_ESP/EFI/BOOT/BOOTX64.EFI"
printf '%s\n' 'ID=steamos' 'PRETTY_NAME="SteamOS"' > "$BOOT_TEST/os-release"
printf '%s\n' \
	'BootOrder: 0002,0001,0007' \
	'Boot0001* Windows Boot Manager	HD(1,GPT,bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb,0x800,0x100000)/\EFI\Microsoft\Boot\bootmgfw.efi' \
	'Boot0002* SteamOS	HD(2,GPT,aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa,0x800,0x100000)/\EFI\steamos\steamcl.efi' \
	'Boot0007* UEFI Network	PciRoot(0x0)/Pci(0x1f,0x6)' > "$BOOT_STATE"
cat > "$BOOT_BIN/lsblk" <<EOF
#!/bin/sh
printf '%s\n' '{"blockdevices":[{"path":"/dev/sda","kname":"sda","type":"disk","children":[{"path":"/dev/sda2","kname":"sda2","pkname":"sda","partn":2,"partuuid":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","type":"part","fstype":"vfat","parttype":"c12a7328-f81f-11d2-ba4b-00a0c93ec93b","mountpoints":["$BOOT_ESP"]}]}]}'
EOF
cat > "$BOOT_BIN/efibootmgr" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$CLOVER_EFIBOOT_CALLS"
case "${1:-}" in
	-c)
		if [ "${CLOVER_EFIBOOT_SCRAMBLE_CREATE:-}" = 1 ]; then
			new_order=0001,0002,0007,0009
		else
			new_order=0002,0001,0007,0009
		fi
		sed "s/^BootOrder:.*/BootOrder: $new_order/" "$CLOVER_EFIBOOT_STATE" > "$CLOVER_EFIBOOT_STATE.tmp"
		printf '%s\n' 'Boot0009* Clover - GUI Boot Manager	HD(2,GPT,aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa,0x800,0x100000)/\EFI\clover\cloverx64.efi' >> "$CLOVER_EFIBOOT_STATE.tmp"
		mv "$CLOVER_EFIBOOT_STATE.tmp" "$CLOVER_EFIBOOT_STATE"
		;;
	-o)
		sed "s/^BootOrder:.*/BootOrder: $2/" "$CLOVER_EFIBOOT_STATE" > "$CLOVER_EFIBOOT_STATE.tmp"
		mv "$CLOVER_EFIBOOT_STATE.tmp" "$CLOVER_EFIBOOT_STATE"
		;;
	-b)
		sed "/^Boot$2/d" "$CLOVER_EFIBOOT_STATE" > "$CLOVER_EFIBOOT_STATE.tmp"
		mv "$CLOVER_EFIBOOT_STATE.tmp" "$CLOVER_EFIBOOT_STATE"
		;;
esac
if [ "${CLOVER_EFIBOOT_HIDE_CREATED:-}" = 1 ] && [ "${1:-}" != -c ]; then
	sed '/^Boot0009/d' "$CLOVER_EFIBOOT_STATE"
else
	cat "$CLOVER_EFIBOOT_STATE"
fi
EOF
chmod +x "$BOOT_BIN/lsblk" "$BOOT_BIN/efibootmgr"
CLOVER_OS_RELEASE_PATH="$BOOT_TEST/os-release" \
CLOVER_DISCOVERY="$DIR/custom/boot-discovery.py" \
CLOVER_OPERATION_LOCK="$BOOT_TEST/operation.lock" \
CLOVER_EFIBOOT_STATE="$BOOT_STATE" \
CLOVER_EFIBOOT_CALLS="$BOOT_CALLS" \
PATH="$BOOT_BIN:$PATH" bash "$CTL" repair-boot-priority > /dev/null 2>&1
expect "fallback-only Clover priority repair succeeds" "$?" "0"
expect "repair preserves the full BootOrder" "$(sed -n 's/^BootOrder: //p' "$BOOT_STATE")" "0009,0002,0001,0007"
case "$(cat "$BOOT_CALLS")" in
	*'-c -d /dev/sda -p 2'*'-l \EFI\clover\cloverx64.efi'*) expect "repair uses discovered disk and partition" yes yes ;;
	*) expect "repair uses discovered disk and partition" "$(cat "$BOOT_CALLS")" "efibootmgr create on /dev/sda partition 2" ;;
esac

printf '%s\n' \
	'BootOrder: 0002,0001,0007' \
	'Boot0001* Windows Boot Manager	HD(1,GPT,bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb,0x800,0x100000)/\EFI\Microsoft\Boot\bootmgfw.efi' \
	'Boot0002* SteamOS	HD(2,GPT,aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa,0x800,0x100000)/\EFI\steamos\steamcl.efi' \
	'Boot0007* UEFI Network	PciRoot(0x0)/Pci(0x1f,0x6)' > "$BOOT_STATE"
: > "$BOOT_CALLS"
CLOVER_OS_RELEASE_PATH="$BOOT_TEST/os-release" \
CLOVER_DISCOVERY="$DIR/custom/boot-discovery.py" \
CLOVER_OPERATION_LOCK="$BOOT_TEST/operation.lock" \
CLOVER_EFIBOOT_STATE="$BOOT_STATE" \
CLOVER_EFIBOOT_CALLS="$BOOT_CALLS" \
CLOVER_EFIBOOT_SCRAMBLE_CREATE=1 \
PATH="$BOOT_BIN:$PATH" bash "$CTL" repair-boot-priority > /dev/null 2>&1
expect "repair survives firmware reordering during entry creation" "$?" "0"
expect "repair restores original relative order after firmware scrambling" "$(sed -n 's/^BootOrder: //p' "$BOOT_STATE")" "0009,0002,0001,0007"

printf '%s\n' \
	'BootOrder: 0002,0001,0007' \
	'Boot0001* Windows Boot Manager\tHD(1,GPT,bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb,0x800,0x100000)/\EFI\Microsoft\Boot\bootmgfw.efi' \
	'Boot0002* SteamOS\tHD(2,GPT,aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa,0x800,0x100000)/\EFI\steamos\steamcl.efi' \
	'Boot0007* UEFI Network\tPciRoot(0x0)/Pci(0x1f,0x6)' > "$BOOT_STATE"
: > "$BOOT_CALLS"
CLOVER_OS_RELEASE_PATH="$BOOT_TEST/os-release" \
CLOVER_DISCOVERY="$DIR/custom/boot-discovery.py" \
CLOVER_OPERATION_LOCK="$BOOT_TEST/operation.lock" \
CLOVER_EFIBOOT_STATE="$BOOT_STATE" CLOVER_EFIBOOT_CALLS="$BOOT_CALLS" \
CLOVER_EFIBOOT_HIDE_CREATED=1 PATH="$BOOT_BIN:$PATH" \
	bash "$CTL" repair-boot-priority > /dev/null 2>&1
expect "unverifiable created Clover entry fails closed" "$?" "1"
case "$(cat "$BOOT_CALLS")" in
	*'-b 0009 -B'*) expect "unverifiable created Clover entry is deleted" yes yes ;;
	*) expect "unverifiable created Clover entry is deleted" "$(cat "$BOOT_CALLS")" "-b 0009 -B" ;;
esac
layout_status=$(CLOVER_OS_RELEASE_PATH="$BOOT_TEST/os-release" \
	CLOVER_DISCOVERY="$DIR/custom/boot-discovery.py" \
	CLOVER_EFIBOOT_STATE="$BOOT_STATE" \
	CLOVER_EFIBOOT_CALLS="$BOOT_CALLS" \
	PATH="$BOOT_BIN:$PATH" bash "$CTL" status)
case "$layout_status" in
	*'"boot_profile":"steamos"'*'"clover_first":false'*'"clover_status":"fallback_only"'*'"target_device":"/dev/sda2"'*)
		expect "status exposes rolled-back boot health" yes yes ;;
	*) expect "status exposes rolled-back boot health" "$layout_status" "dynamic boot health JSON" ;;
esac

mkdir -p "$BOOT_ESP/EFI/Clover/themes/Eclipse"
cp "$DIR/custom/config.plist" "$BOOT_ESP/EFI/Clover/config.plist"
dynamic_default=$(env -u CLOVER_EFI_PATH -u CLOVER_CONFIG \
	CLOVER_OS_RELEASE_PATH="$BOOT_TEST/os-release" \
	CLOVER_DISCOVERY="$DIR/custom/boot-discovery.py" \
	CLOVER_EFIBOOT_STATE="$BOOT_STATE" \
	CLOVER_EFIBOOT_CALLS="$BOOT_CALLS" \
	PATH="$BOOT_BIN:$PATH" bash "$CTL" get default-os)
expect "controller resolves config from discovered ESP" "$dynamic_default" "steamos"

WINDOWS_MOUNT_TEST="$BOOT_TEST/windows-mount"
WINDOWS_MOUNT_LOG="$BOOT_TEST/windows-mount.log"
WINDOWS_DISCOVERY="$BOOT_TEST/windows-discovery.py"
cat > "$WINDOWS_DISCOVERY" <<EOF
#!/usr/bin/env python3
import json, sys
windows = ({"device": "/dev/sdb1", "partuuid": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}
           if "--mount-unmounted" in sys.argv else None)
print(json.dumps({
    "host_os": {"name": "SteamOS"},
    "clover_target": {"device": "/dev/sda2", "mountpoints": ["$BOOT_ESP"]},
    "windows": windows,
    "linux_loader": {"path": "\\\\EFI\\\\steamos\\\\steamcl.efi", "partuuid": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"},
    "firmware": {"entries": [
        {"id": "0001", "label": "Windows Boot Manager", "device_path": "HD(1,GPT,bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb,0x800,0x100000)/\\\\EFI\\\\Microsoft\\\\Boot\\\\bootmgfw.efi"}
    ]},
    "problems": []
}))
EOF
cat > "$BOOT_BIN/mount" <<'EOF'
#!/bin/sh
target=${4:-}
printf 'mount %s %s\n' "${3:-}" "$target" >> "$CLOVER_WINDOWS_MOUNT_LOG"
mkdir -p "$target/EFI/Microsoft/Boot" "$target/EFI/Microsoft"
printf 'windows-safe\n' > "$target/EFI/Microsoft/Boot/bootmgfw.efi.orig"
printf 'windows-safe\n' > "$target/EFI/Microsoft/bootmgfw.efi"
EOF
cat > "$BOOT_BIN/umount" <<'EOF'
#!/bin/sh
cmp "$1/EFI/Microsoft/Boot/bootmgfw.efi.orig" "$1/EFI/Microsoft/Boot/bootmgfw.efi" \
	&& printf 'restored\n' >> "$CLOVER_WINDOWS_MOUNT_LOG"
printf 'umount %s\n' "$1" >> "$CLOVER_WINDOWS_MOUNT_LOG"
EOF
cat > "$BOOT_BIN/systemctl" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$WINDOWS_DISCOVERY" "$BOOT_BIN/mount" "$BOOT_BIN/umount" "$BOOT_BIN/systemctl"
: > "$WINDOWS_MOUNT_LOG"
: > "$BOOT_CALLS"
env -u CLOVER_EFI_PATH -u CLOVER_WINDOWS_EFI_PATH \
	CLOVER_DISCOVERY="$WINDOWS_DISCOVERY" \
	CLOVER_WINDOWS_MOUNT_LOG="$WINDOWS_MOUNT_LOG" \
	CLOVER_EFIBOOT_STATE="$BOOT_STATE" CLOVER_EFIBOOT_CALLS="$BOOT_CALLS" \
	PATH="$BOOT_BIN:$PATH" bash "$CTL" service disable > /dev/null 2>&1
expect "service disable restores an initially unmounted Windows ESP" "$?" "0"
case "$(cat "$WINDOWS_MOUNT_LOG")" in
	*'mount /dev/sdb1 '*restored*umount*) expect "temporary Windows mount is scoped and cleaned up" yes yes ;;
	*) expect "temporary Windows mount is scoped and cleaned up" "$(cat "$WINDOWS_MOUNT_LOG")" "mount, restore, umount" ;;
esac
case "$(cat "$BOOT_CALLS")" in
	*'-n 0001'*) expect "BootNext targets the Windows entry on the detected ESP" yes yes ;;
	*) expect "BootNext targets the Windows entry on the detected ESP" "$(cat "$BOOT_CALLS")" "-n 0001" ;;
esac

FAKE_REPORTER="$BOOT_TEST/support_report.py"
REPORT_OUTPUT="$BOOT_TEST/clover-report.json"
cat > "$FAKE_REPORTER" <<'EOF'
import json, os, sys
args = sys.argv[1:]
out = args[args.index("--output") + 1]
with open(out, "w", encoding="utf-8") as handle:
    json.dump({"app": "clover-dualboot", "schema": 1}, handle)
os.chmod(out, 0o600)
print(out)
EOF
report_path=$(CLOVER_REPORTER="$FAKE_REPORTER" CLOVER_REPORT_OUTPUT="$REPORT_OUTPUT" \
	bash "$CTL" diagnostics)
expect "diagnostics uses the structured reporter" "$report_path" "$REPORT_OUTPUT"
expect "structured diagnostic file was created" "$([ -f "$REPORT_OUTPUT" ] && echo yes || echo no)" "yes"

rm -rf "$EFI" "$FAKEBIN" "$BOOT_TEST"
rm -f "$TMP" "$TMP.cloverctl.tmp"
echo "---"
if [ "$fail" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; exit 1; fi
