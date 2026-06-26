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

bash "$CTL" set-theme Catalina > /dev/null
expect "set/get theme"      "$(bash "$CTL" get theme)"      "Catalina"

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
bash "$CTL" help > /dev/null 2>&1;            expect "help exits 0" "$?" "0"
bash "$CTL" bogus > /dev/null 2>&1;           expect "unknown cmd exits 1" "$?" "1"

# status emits parseable-looking JSON carrying the current values
status=$(bash "$CTL" status)
case "$status" in
	*'"resolution":"1920x1080"'*'"theme":"Catalina"'*) expect "status JSON reflects writes" yes yes ;;
	*) expect "status JSON reflects writes" "$status" "<json with resolution+theme>" ;;
esac

rm -f "$TMP" "$TMP.cloverctl.tmp"
echo "---"
if [ "$fail" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; exit 1; fi
