#!/bin/bash

set -u

CLOVER_CTL=${CLOVER_CTL:-/etc/clover-dualboot/clover-ctl}
OWNER=${SUDO_USER:-$(id -un 1000 2> /dev/null || echo deck)}
HOME_DIR=$(getent passwd "$OWNER" 2> /dev/null | cut -d: -f6)
[ -n "$HOME_DIR" ] || HOME_DIR="/home/$OWNER"
CLOVER_STATUS=${CLOVER_STATUS:-$HOME_DIR/1Clover-tools/status.txt}
GENERIC_CONSENT=${CLOVER_GENERIC_CONSENT:-/etc/clover-dualboot/allow-generic}

mkdir -p "$(dirname "$CLOVER_STATUS")" || exit 1

{
	echo "Clover boot maintenance - $(date)"
	echo "## OS"
	grep -E '^(ID|ID_LIKE|PRETTY_NAME|VERSION_ID|BUILD_ID|VARIANT_ID)=' /etc/os-release 2> /dev/null || true
	echo "## Device"
	for field in sys_vendor product_name board_name
	do
		printf '%s: ' "$field"
		cat "/sys/class/dmi/id/$field" 2> /dev/null || echo unavailable
	done
	echo "## Kernel"
	uname -r
	echo "## Repair"
	[ -f "$CLOVER_CTL" ] || { echo "Clover controller not found: $CLOVER_CTL"; exit 1; }
	python_check=$(command -v python3 2> /dev/null)
	[ -n "$python_check" ] || { echo "python3 is required for boot discovery"; exit 1; }
	repair_args=(repair-boot-priority)
	[ -f "$GENERIC_CONSENT" ] && repair_args+=(--allow-generic)
	"$CLOVER_CTL" "${repair_args[@]}"
} > "$CLOVER_STATUS" 2>&1
result=$?

chmod 640 "$CLOVER_STATUS" 2> /dev/null || true
chown "$OWNER":"$OWNER" "$CLOVER_STATUS" 2> /dev/null || true
exit "$result"
