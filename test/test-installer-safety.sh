#!/bin/bash

DIR=$(cd "$(dirname "$0")/.." && pwd)
INSTALLER="$DIR/install-clover.sh"
fail=0

check_absent() {
	description=$1
	pattern=$2
	if grep -Eq "$pattern" "$INSTALLER"
	then
		echo "FAIL $description"
		fail=1
	else
		echo "ok   $description"
	fi
}

check_present() {
	description=$1
	pattern=$2
	if grep -Eq "$pattern" "$INSTALLER"
	then
		echo "ok   $description"
	else
		echo "FAIL $description"
		fail=1
	fi
}

bash -n "$INSTALLER" || fail=1
check_absent "installer has no fixed NVMe partition target" '/dev/nvme0n1p1'
check_absent "installer never deletes rEFInd entries" 'efibootmgr[[:space:]].*-B.*[Rr][Ee][Ff][Ii][Nn][Dd]'
check_absent "installer never removes rEFInd files or packages" '(rm|pacman -R).*[Rr][Ee][Ff][Ii][Nn][Dd]'
check_absent "installer does not edit the repository config template" 'sed -i .*custom/config\.plist'
check_absent "installer does not use a broad Clover archive glob" 'rm Clover-.*\*'
check_present "installer stages Clover before publishing" 'clover\.installing'
check_present "installer mounts discovered ESPs with restricted options" 'rw,nosuid,nodev,noexec'
check_present "installer downloads into an isolated temporary directory" 'clover-download\.XXXXXX'
check_present "installer pins the official Clover archive SHA-256" 'CLOVER_SHA256=[0-9a-f]{64}'
check_present "installer verifies the Clover archive before extraction" 'sha256sum -c'
check_present "installer keeps the original BootOrder for rollback" 'INSTALL_ORIGINAL_BOOT_ORDER'
check_present "installer removes only newly created Clover firmware entries on rollback" 'install_csv_difference.*POST_REPAIR_CLOVER_IDS.*INSTALL_ORIGINAL_CLOVER_IDS'
check_present "installer restores the canonical fallback on rollback" 'restore-clover-loader'
check_present "installer restores an active Windows loader on rollback" 'restore-windows-efi'
check_present "installer commits only after all UI and service setup" 'INSTALL_COMMITTED=yes'

echo "---"
if [ "$fail" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; exit 1; fi
