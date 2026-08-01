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
bash "$CTL" bogus > /dev/null 2>&1;           expect "unknown cmd exits 1" "$?" "1"

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

rm -rf "$EFI" "$FAKEBIN"
rm -f "$TMP" "$TMP.cloverctl.tmp"
echo "---"
if [ "$fail" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; exit 1; fi
