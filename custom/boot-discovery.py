#!/usr/bin/env python3

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


ESP_GUID = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
KNOWN_LOADERS = {
    "steamos": (("steamos", "\\efi\\steamos\\steamcl.efi"),),
    "bazzite": (("shim", "\\efi\\fedora\\shimx64.efi"),),
    "cachyos": (
        ("limine", "\\efi\\limine\\limine_x64.efi"),
        ("systemd-boot", "\\efi\\systemd\\systemd-bootx64.efi"),
        ("grub", "\\efi\\cachyos\\grubx64.efi"),
        ("refind", "\\efi\\refind\\refind_x64.efi"),
    ),
}


def parse_os_release(text):
    values = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value.strip().strip('"\'')
    os_id = values.get("ID", "unknown").lower()
    profile = os_id if os_id in KNOWN_LOADERS else "generic"
    return {
        "id": os_id,
        "profile": profile,
        "name": values.get("PRETTY_NAME", values.get("NAME", os_id)),
        "version_id": values.get("VERSION_ID", ""),
        "build_id": values.get("BUILD_ID", ""),
    }


def flatten_devices(devices):
    flattened = []
    for device in devices:
        current = {key: value for key, value in device.items() if key != "children"}
        flattened.append(current)
        flattened.extend(flatten_devices(device.get("children") or []))
    return flattened


def is_esp(device):
    return (
        device.get("type") == "part"
        and str(device.get("parttype") or "").lower() == ESP_GUID
    )


def normalize_efi_path(path):
    return "\\" + path.replace("/", "\\").lstrip("\\")


def loader_for(profile, files):
    normalized = {normalize_efi_path(path).lower(): normalize_efi_path(path) for path in files}
    for kind, wanted in KNOWN_LOADERS.get(profile, ()):
        if wanted in normalized:
            return {"kind": kind, "path": normalized[wanted], "validated": True}
    return None


def partition_record(device):
    device_path = str(device.get("path") or "")
    pkname = device.get("pkname") or ""
    if not device_path.startswith("/dev/") or not pkname:
        raise ValueError("EFI partition is missing a stable device or parent disk")
    try:
        partition = int(device.get("partn"))
    except (TypeError, ValueError) as error:
        raise ValueError("EFI partition number is missing") from error
    if partition < 1:
        raise ValueError("EFI partition number is invalid")
    disk = pkname if pkname.startswith("/dev/") else f"/dev/{pkname}"
    return {
        "device": device_path,
        "disk": disk,
        "partition": partition,
        "partuuid": str(device.get("partuuid") or "").lower(),
        "mountpoints": [point for point in (device.get("mountpoints") or []) if point],
    }


def parse_firmware(text):
    boot_order = []
    entries = []
    for line in text.splitlines():
        if line.startswith("BootOrder:"):
            boot_order = [item.strip().upper() for item in line.split(":", 1)[1].split(",") if item.strip()]
            continue
        match = re.match(r"Boot([0-9A-Fa-f]{4})\*?\s+([^\t]+)(?:\t(.*))?$", line)
        if not match:
            continue
        entry_id, label, device_path = match.groups()
        entries.append(
            {
                "id": entry_id.upper(),
                "label": label.strip(),
                "device_path": device_path or "",
            }
        )
    return {"boot_order": boot_order, "entries": entries}


def generic_loader_for(esp, files, entries):
    partuuid = str(esp.get("partuuid") or "").lower()
    if not partuuid:
        return None
    available = {normalize_efi_path(path).lower(): normalize_efi_path(path) for path in files}
    excluded = (
        "\\efi\\microsoft\\",
        "\\efi\\clover\\",
        "\\efi\\boot\\bootx64.efi",
    )
    matches = []
    for entry in entries:
        device_path = entry["device_path"]
        guid = re.search(r"GPT,([0-9A-Fa-f-]{36}),", device_path, re.IGNORECASE)
        path_start = device_path.lower().find("\\efi\\")
        if not guid or guid.group(1).lower() != partuuid or path_start < 0:
            continue
        path = normalize_efi_path(device_path[path_start:])
        actual = available.get(path.lower())
        if actual and not actual.lower().startswith(excluded):
            matches.append((entry, actual))
    if len(matches) != 1:
        return None
    entry, path = matches[0]
    return {
        "kind": "generic",
        "path": path,
        "label": entry["label"],
        "validated": False,
    }


def discover(os_release, lsblk, efi_files, efibootmgr, allow_generic=False):
    host_os = parse_os_release(os_release)
    firmware = parse_firmware(efibootmgr)
    devices = flatten_devices(lsblk.get("blockdevices") or [])
    esps = [device for device in devices if is_esp(device)]
    unscanned_esps = [
        device.get("path") for device in esps if device.get("path") not in efi_files
    ]

    windows_candidates = []
    linux_candidates = []
    clover_candidates = []
    for esp in esps:
        files = efi_files.get(esp.get("path"), [])
        lower_files = {normalize_efi_path(path).lower() for path in files}
        if "\\efi\\microsoft\\boot\\bootmgfw.efi" in lower_files:
            windows_candidates.append((esp, "active"))
        elif (
            "\\efi\\microsoft\\boot\\bootmgfw.efi.orig" in lower_files
            and "\\efi\\microsoft\\bootmgfw.efi" in lower_files
        ):
            windows_candidates.append((esp, "protected"))
        loader = loader_for(host_os["profile"], files)
        if loader is None and host_os["profile"] == "generic":
            loader = generic_loader_for(esp, files, firmware["entries"])
        if loader:
            linux_candidates.append((esp, loader))
        if "\\efi\\clover\\cloverx64.efi" in lower_files:
            clover_candidates.append(
                (esp, "\\efi\\boot\\bootx64.efi" in lower_files)
            )

    preferred_mounts = {"/boot", "/boot/efi", "/esp"}
    mounted_linux = [
        candidate
        for candidate in linux_candidates
        if preferred_mounts.intersection(candidate[0].get("mountpoints") or [])
    ]
    chosen_linux = mounted_linux[0] if len(mounted_linux) == 1 else None
    if chosen_linux is None and len(linux_candidates) == 1:
        chosen_linux = linux_candidates[0]

    chosen_target = clover_candidates[0][0] if len(clover_candidates) == 1 else None
    if chosen_target is None and chosen_linux:
        chosen_target = chosen_linux[0]

    target_partuuid = str((chosen_target or {}).get("partuuid") or "").lower()
    clover_entries = []
    for entry in firmware["entries"]:
        device_path = entry["device_path"]
        guid = re.search(r"GPT,([0-9A-Fa-f-]{36}),", device_path, re.IGNORECASE)
        if (
            guid
            and target_partuuid
            and guid.group(1).lower() == target_partuuid
            and "\\efi\\clover\\cloverx64.efi" in device_path.lower()
        ):
            clover_entries.append(entry)
    clover_status = "absent"
    if len(clover_candidates) == 1:
        if clover_entries:
            clover_status = "registered"
        elif clover_candidates[0][1]:
            clover_status = "fallback_only"
        else:
            clover_status = "installed_unregistered"
    clover_entry_ids = {entry["id"] for entry in clover_entries}
    clover_first = bool(
        firmware["boot_order"]
        and firmware["boot_order"][0] in clover_entry_ids
    )

    requires_confirmation = host_os["profile"] == "generic"
    safe = (
        chosen_linux is not None
        and chosen_target is not None
        and len(clover_candidates) <= 1
        and len(windows_candidates) <= 1
        and not unscanned_esps
        and (not requires_confirmation or allow_generic)
    )
    result = {
        "schema": 1,
        "safe_to_write": safe,
        "requires_confirmation": requires_confirmation,
        "unscanned_esps": unscanned_esps,
        "host_os": host_os,
        "linux_loader": None,
        "clover_target": None,
        "clover": {
            "status": clover_status,
            "entry_ids": sorted(clover_entry_ids),
            "first_in_boot_order": clover_first,
            "repair_needed": clover_status != "registered" or not clover_first,
        },
        "firmware": firmware,
        "windows": None,
        "problems": [],
    }
    if chosen_linux:
        esp, loader = chosen_linux
        result["linux_loader"] = {**partition_record(esp), **loader}
    else:
        result["problems"].append("linux_esp_not_unique")
    if requires_confirmation and not allow_generic:
        result["problems"].append("generic_profile_requires_confirmation")
    if unscanned_esps:
        result["problems"].append("esp_unscanned")
    if chosen_target:
        result["clover_target"] = partition_record(chosen_target)
    if len(clover_candidates) > 1:
        result["problems"].append("clover_esp_not_unique")
    if len(windows_candidates) == 1:
        windows_esp, windows_state = windows_candidates[0]
        result["windows"] = {
            **partition_record(windows_esp),
            "state": windows_state,
        }
    elif len(windows_candidates) > 1:
        result["problems"].append("windows_esp_not_unique")
    return result


def scan_mounted_efi_files(lsblk):
    files_by_device = {}
    for device in flatten_devices(lsblk.get("blockdevices") or []):
        if not is_esp(device):
            continue
        found = []
        scanned = False
        for mountpoint in (device.get("mountpoints") or []):
            if not mountpoint:
                continue
            root = Path(mountpoint)
            try:
                children = list(root.iterdir())
                scanned = True
                efi_root = next(child for child in children if child.name.casefold() == "efi")
            except StopIteration:
                continue
            except OSError:
                continue
            try:
                for path in efi_root.rglob("*"):
                    if len(found) >= 512:
                        break
                    if path.is_file() and path.suffix.casefold() == ".efi":
                        found.append(path.relative_to(root).as_posix())
            except OSError:
                continue
        if scanned:
            files_by_device[device.get("path")] = found
    return files_by_device


def scan_unmounted_efi_files(lsblk, files_by_device):
    for device in flatten_devices(lsblk.get("blockdevices") or []):
        device_path = device.get("path")
        if not is_esp(device) or device_path in files_by_device:
            continue
        with tempfile.TemporaryDirectory(prefix="clover-esp-") as mountpoint:
            mounted = False
            try:
                proc = subprocess.run(
                    [
                        "mount",
                        "-o",
                        "ro,nosuid,nodev,noexec",
                        device_path,
                        mountpoint,
                    ],
                    text=True,
                    capture_output=True,
                    check=False,
                )
                if proc.returncode != 0:
                    continue
                mounted = True
                mounted_device = dict(device)
                mounted_device["mountpoints"] = [mountpoint]
                scanned = scan_mounted_efi_files(
                    {"blockdevices": [mounted_device]}
                )
                if device_path in scanned:
                    files_by_device[device_path] = scanned[device_path]
            finally:
                if mounted:
                    proc = subprocess.run(
                        ["umount", mountpoint],
                        text=True,
                        capture_output=True,
                        check=False,
                    )
                    if proc.returncode != 0:
                        raise RuntimeError(
                            f"could not unmount temporary ESP {device_path}: {proc.stderr.strip()}"
                        )
    return files_by_device


def run_capture(command, required):
    proc = subprocess.run(command, text=True, capture_output=True, check=False)
    if required and proc.returncode != 0:
        raise RuntimeError(f"{command[0]} failed: {proc.stderr.strip()}")
    return proc.stdout


def collect_live(mount_unmounted=False):
    os_release_path = Path(os.environ.get("CLOVER_OS_RELEASE_PATH", "/etc/os-release"))
    os_release = os_release_path.read_text(encoding="utf-8")
    lsblk_text = run_capture(
        [
            "lsblk",
            "--json",
            "--paths",
            "--output",
            "PATH,KNAME,PKNAME,PARTN,PARTUUID,TYPE,FSTYPE,PARTTYPE,MOUNTPOINTS,RO,SIZE",
        ],
        required=True,
    )
    lsblk = json.loads(lsblk_text)
    efibootmgr = run_capture(["efibootmgr", "-v"], required=False)
    efi_files = scan_mounted_efi_files(lsblk)
    if mount_unmounted:
        efi_files = scan_unmounted_efi_files(lsblk, efi_files)
    return os_release, lsblk, efi_files, efibootmgr


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--allow-generic", action="store_true")
    parser.add_argument("--mount-unmounted", action="store_true")
    args = parser.parse_args()
    try:
        if args.fixture:
            fixture = args.fixture
            inputs = (
                (fixture / "os-release").read_text(encoding="utf-8"),
                json.loads((fixture / "lsblk.json").read_text(encoding="utf-8")),
                json.loads((fixture / "efi-files.json").read_text(encoding="utf-8")),
                (fixture / "efibootmgr.txt").read_text(encoding="utf-8"),
            )
        else:
            inputs = collect_live(mount_unmounted=args.mount_unmounted)
        result = discover(*inputs, allow_generic=args.allow_generic)
    except (OSError, ValueError, json.JSONDecodeError, RuntimeError) as error:
        print(f"boot discovery failed: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
