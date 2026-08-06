#!/bin/bash

install_layout_vars() {
	python3 -c '
import json, shlex, sys
d = json.load(sys.stdin)
def emit(name, value):
    print(name + "=" + shlex.quote(str(value)))
target = d.get("clover_target") or {}
windows = d.get("windows") or {}
loader = d.get("linux_loader") or {}
host = d.get("host_os") or {}
emit("INSTALL_LAYOUT_SAFE", "yes" if d.get("safe_to_write") else "no")
emit("INSTALL_OS_PROFILE", host.get("profile", "unknown"))
emit("INSTALL_OS_NAME", host.get("name", "Unknown Linux"))
emit("INSTALL_TARGET_DEVICE", target.get("device", ""))
emit("INSTALL_TARGET_DISK", target.get("disk", ""))
emit("INSTALL_TARGET_PARTITION", target.get("partition", ""))
emit("INSTALL_TARGET_PARTUUID", target.get("partuuid", ""))
emit("INSTALL_TARGET_MOUNT", next(iter(target.get("mountpoints") or []), ""))
emit("INSTALL_WINDOWS_DEVICE", windows.get("device", ""))
emit("INSTALL_WINDOWS_MOUNT", next(iter(windows.get("mountpoints") or []), ""))
emit("INSTALL_WINDOWS_STATE", windows.get("state", ""))
emit("INSTALL_LINUX_LOADER", loader.get("path", ""))
emit("INSTALL_LINUX_PARTUUID", loader.get("partuuid", ""))
emit("INSTALL_LAYOUT_PROBLEMS", ",".join(d.get("problems") or []))
emit("INSTALL_ORIGINAL_BOOT_ORDER", ",".join(d.get("firmware", {}).get("boot_order") or []))
emit("INSTALL_ORIGINAL_CLOVER_IDS", ",".join(d.get("clover", {}).get("entry_ids") or []))
'
}

install_clover_ids_from_firmware() {
	partuuid=$1
	python3 -c '
import re, sys
guid = sys.argv[1].casefold()
matches = []
for line in sys.stdin:
    entry = re.match(r"Boot([0-9A-Fa-f]{4})\*?\s", line)
    path_guid = re.search(r"GPT,([0-9A-Fa-f-]{36}),", line, re.IGNORECASE)
    if (entry and path_guid and path_guid.group(1).casefold() == guid
            and "\\efi\\clover\\cloverx64.efi" in line.casefold()):
        matches.append(entry.group(1).upper())
print(",".join(sorted(set(matches))))
' "$partuuid"
}

install_csv_difference() {
	new_values=$1
	old_values=$2
	difference=""
	old_ifs=$IFS
	IFS=,
	for value in $new_values
	do
		case ",$old_values," in *",$value,"*) continue ;; esac
		[ -z "$difference" ] && difference=$value || difference="$difference,$value"
	done
	IFS=$old_ifs
	printf '%s\n' "$difference"
}

install_efi_root() {
	mountpoint=$1
	[ -d "$mountpoint" ] || return 1
	for child in "$mountpoint"/*
	do
		[ -d "$child" ] || continue
		name=$(basename "$child" | tr '[:upper:]' '[:lower:]')
		[ "$name" = efi ] && { printf '%s\n' "$child"; return 0; }
	done
	return 1
}

install_bootx64_path() {
	efi_root=$1
	boot_dir=""
	for child in "$efi_root"/*
	do
		[ -d "$child" ] || continue
		[ "$(basename "$child" | tr '[:upper:]' '[:lower:]')" = boot ] \
			&& { boot_dir=$child; break; }
	done
	existing=""
	[ -z "$boot_dir" ] || existing=$(find "$boot_dir" -mindepth 1 -maxdepth 1 -type f -iname bootx64.efi 2> /dev/null | head -n1)
	if [ -n "$existing" ]
	then
		printf '%s\n' "$existing"
	else
		printf '%s\n' "$efi_root/BOOT/BOOTX64.EFI"
	fi
}

install_add_generic_entry() {
	config=$1
	loader=$2
	partuuid=$3
	title=$4
	python3 - "$config" "$loader" "$partuuid" "$title" <<'PY'
import os
import plistlib
import sys
import tempfile

config, loader, partuuid, title = sys.argv[1:]
if not loader.lower().startswith("\\efi\\") or not loader.lower().endswith(".efi"):
    raise SystemExit("invalid generic EFI loader")
if len(partuuid) != 36:
    raise SystemExit("generic EFI partition GUID is missing")
with open(config, "rb") as handle:
    plist = plistlib.load(handle)
entries = plist["GUI"]["Custom"]["Entries"]
matching = next(
    (entry for entry in entries if str(entry.get("Path", "")).casefold() == loader.casefold()),
    None,
)
if matching is not None:
    matching["Volume"] = partuuid.upper()
    matching["Title"] = title
    matching["FullTitle"] = title
else:
    entries.append(
        {
            "Image": "os_linux",
            "Path": loader,
            "Volume": partuuid.upper(),
            "Title": title,
            "Type": "Linux",
            "FullTitle": title,
        }
    )
mode = os.stat(config).st_mode & 0o777
fd, temporary = tempfile.mkstemp(prefix=".clover-config-", dir=os.path.dirname(config) or ".")
try:
    with os.fdopen(fd, "wb") as handle:
        plistlib.dump(plist, handle, sort_keys=False)
        handle.flush()
        os.fsync(handle.fileno())
    os.chmod(temporary, mode)
    os.replace(temporary, config)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
PY
}
