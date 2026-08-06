#!/bin/bash

DIR=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
CALLS="$TMP/calls"
STATUS="$TMP/status.txt"
FAKE_CTL="$TMP/clover-ctl"
fail=0

expect() {
	if [ "$2" = "$3" ]; then
		echo "ok   $1 -> $2"
	else
		echo "FAIL $1 -> '$2' (expected '$3')"
		fail=1
	fi
}

cat > "$FAKE_CTL" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$CALLS"
[ "\$1" = repair-boot-priority ] || exit 9
printf '%s\n' 'Clover boot priority repaired and verified'
EOF
chmod +x "$FAKE_CTL"

CLOVER_CTL="$FAKE_CTL" CLOVER_STATUS="$STATUS" \
	bash "$DIR/custom/clover-bootmanager.sh" > /dev/null 2>&1
expect "service exits successfully" "$?" "0"
expect "service performs only verified priority repair" "$(cat "$CALLS")" "repair-boot-priority"
case "$(cat "$STATUS")" in
	*'Clover boot priority repaired and verified'*) expect "service records repair result" yes yes ;;
	*) expect "service records repair result" "$(cat "$STATUS")" "repair result" ;;
esac

CONSENT="$TMP/allow-generic"
printf '%s\n' yes > "$CONSENT"
: > "$CALLS"
CLOVER_CTL="$FAKE_CTL" CLOVER_STATUS="$STATUS" CLOVER_GENERIC_CONSENT="$CONSENT" \
	bash "$DIR/custom/clover-bootmanager.sh" > /dev/null 2>&1
expect "persisted generic consent reaches priority repair" \
	"$(cat "$CALLS")" "repair-boot-priority --allow-generic"

rm -rf "$TMP"
echo "---"
if [ "$fail" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; exit 1; fi
