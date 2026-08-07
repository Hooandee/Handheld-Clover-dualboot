#!/usr/bin/env python3

import json
import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
DISCOVERY = REPO / "custom" / "boot-discovery.py"
ESP_PARTTYPE = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"

SPEC = importlib.util.spec_from_file_location("boot_discovery", DISCOVERY)
BOOT_DISCOVERY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BOOT_DISCOVERY)


def esp_partition(path, parent, partition, mountpoints, partuuid=None):
    record = {
        "path": path,
        "kname": path.removeprefix("/dev/"),
        "pkname": parent,
        "partn": partition,
        "type": "part",
        "fstype": "vfat",
        "parttype": ESP_PARTTYPE,
        "mountpoints": mountpoints,
    }
    if partuuid:
        record["partuuid"] = partuuid
    return record


class BootDiscoveryTests(unittest.TestCase):
    def run_fixture(
        self,
        *,
        os_release,
        blockdevices,
        efi_files,
        efibootmgr="",
        allow_generic=False,
    ):
        with tempfile.TemporaryDirectory() as tmp:
            fixture = Path(tmp)
            (fixture / "os-release").write_text(os_release, encoding="utf-8")
            (fixture / "lsblk.json").write_text(
                json.dumps({"blockdevices": blockdevices}), encoding="utf-8"
            )
            (fixture / "efi-files.json").write_text(
                json.dumps(efi_files), encoding="utf-8"
            )
            (fixture / "efibootmgr.txt").write_text(efibootmgr, encoding="utf-8")
            command = ["python3", str(DISCOVERY), "--fixture", str(fixture)]
            if allow_generic:
                command.append("--allow-generic")
            proc = subprocess.run(
                command,
                text=True,
                capture_output=True,
                check=False,
            )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        return json.loads(proc.stdout)

    def test_windows_first_cachyos_uses_linux_esp_without_conflating_windows(self):
        layout = self.run_fixture(
            os_release='ID=cachyos\nPRETTY_NAME="CachyOS"\n',
            blockdevices=[
                {
                    "path": "/dev/nvme0n1",
                    "kname": "nvme0n1",
                    "type": "disk",
                    "children": [
                        esp_partition("/dev/nvme0n1p1", "nvme0n1", 1, ["/windows-esp"],
                            "11111111-1111-1111-1111-111111111111"),
                        esp_partition("/dev/nvme0n1p5", "nvme0n1", 5, ["/boot"],
                            "55555555-5555-5555-5555-555555555555"),
                        {
                            "path": "/dev/nvme0n1p6",
                            "kname": "nvme0n1p6",
                            "pkname": "nvme0n1",
                            "partn": 6,
                            "type": "part",
                            "fstype": "btrfs",
                            "mountpoints": ["/"],
                        },
                    ],
                }
            ],
            efi_files={
                "/dev/nvme0n1p1": ["EFI/Microsoft/Boot/bootmgfw.efi"],
                "/dev/nvme0n1p5": ["EFI/limine/limine_x64.efi"],
            },
            efibootmgr=(
                "BootCurrent: 0002\nBootOrder: 0001,0002\n"
                "Boot0001* Windows Boot Manager\tHD(1,GPT,11111111-1111-1111-1111-111111111111,0x800,0x100000)/\\EFI\\Microsoft\\Boot\\bootmgfw.efi\n"
                "Boot0002* CachyOS\tHD(5,GPT,55555555-5555-5555-5555-555555555555,0x0,0x0)/\\EFI\\limine\\limine_x64.efi\n"
            ),
        )

        self.assertTrue(layout["safe_to_write"])
        self.assertEqual(layout["host_os"]["profile"], "cachyos")
        self.assertEqual(layout["linux_loader"]["kind"], "limine")
        self.assertEqual(layout["linux_loader"]["path"], "\\EFI\\limine\\limine_x64.efi")
        self.assertEqual(layout["clover_target"]["device"], "/dev/nvme0n1p5")
        self.assertEqual(layout["clover_target"]["disk"], "/dev/nvme0n1")
        self.assertEqual(layout["clover_target"]["partition"], 5)
        self.assertEqual(layout["windows"]["device"], "/dev/nvme0n1p1")
        self.assertEqual(
            layout["windows"]["partuuid"],
            "11111111-1111-1111-1111-111111111111",
        )

    def test_fallback_only_clover_is_reported_as_needing_nvram_repair(self):
        layout = self.run_fixture(
            os_release='ID=steamos\nPRETTY_NAME="SteamOS"\nVERSION_ID=3\n',
            blockdevices=[
                {
                    "path": "/dev/nvme0n1",
                    "kname": "nvme0n1",
                    "type": "disk",
                    "children": [
                        esp_partition("/dev/nvme0n1p1", "nvme0n1", 1, ["/esp"],
                            "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
                        {
                            "path": "/dev/nvme0n1p2",
                            "kname": "nvme0n1p2",
                            "pkname": "nvme0n1",
                            "partn": 2,
                            "type": "part",
                            "fstype": "btrfs",
                            "mountpoints": ["/"],
                        },
                    ],
                },
                {
                    "path": "/dev/nvme1n1",
                    "kname": "nvme1n1",
                    "type": "disk",
                    "children": [
                        esp_partition("/dev/nvme1n1p1", "nvme1n1", 1,
                            ["/run/media/windows-esp"],
                            "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
                    ],
                },
            ],
            efi_files={
                "/dev/nvme0n1p1": [
                    "EFI/steamos/steamcl.efi",
                    "EFI/Clover/cloverx64.efi",
                    "EFI/BOOT/BOOTX64.EFI",
                ],
                "/dev/nvme1n1p1": ["EFI/Microsoft/Boot/bootmgfw.efi"],
            },
            efibootmgr=(
                "BootCurrent: 0002\n"
                "BootOrder: 0002,0001,0007\n"
                "Boot0001* Windows Boot Manager\tHD(1,GPT,bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb,0x800,0x100000)/\\EFI\\Microsoft\\Boot\\bootmgfw.efi\n"
                "Boot0002* SteamOS\tHD(1,GPT,aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa,0x800,0x100000)/\\EFI\\steamos\\steamcl.efi\n"
                "Boot0007* UEFI Network\tPciRoot(0x0)/Pci(0x1f,0x6)\n"
            ),
        )

        self.assertTrue(layout["safe_to_write"])
        self.assertEqual(layout["clover_target"]["device"], "/dev/nvme0n1p1")
        self.assertEqual(layout["clover"]["status"], "fallback_only")
        self.assertTrue(layout["clover"]["repair_needed"])
        self.assertEqual(layout["firmware"]["boot_order"], ["0002", "0001", "0007"])

    def test_stale_clover_label_on_another_partition_is_not_trusted(self):
        layout = self.run_fixture(
            os_release='ID=steamos\nPRETTY_NAME="SteamOS"\n',
            blockdevices=[
                {
                    "path": "/dev/sda",
                    "kname": "sda",
                    "type": "disk",
                    "children": [
                        esp_partition("/dev/sda2", "sda", 2, ["/esp"],
                            "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
                    ],
                }
            ],
            efi_files={
                "/dev/sda2": [
                    "EFI/steamos/steamcl.efi",
                    "EFI/Clover/cloverx64.efi",
                    "EFI/BOOT/BOOTX64.EFI",
                ]
            },
            efibootmgr=(
                "BootOrder: 0008,0002\n"
                "Boot0008* Clover Rescue USB\tHD(1,GPT,eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee,0x800,0x100000)/\\EFI\\rescue\\bootx64.efi\n"
                "Boot0002* SteamOS\tHD(2,GPT,aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa,0x800,0x100000)/\\EFI\\steamos\\steamcl.efi\n"
            ),
        )

        self.assertEqual(layout["clover"]["entry_ids"], [])
        self.assertEqual(layout["clover"]["status"], "fallback_only")
        self.assertTrue(layout["clover"]["repair_needed"])

    def test_bazzite_on_sata_selects_its_esp_when_windows_is_on_nvme(self):
        layout = self.run_fixture(
            os_release='ID=bazzite\nPRETTY_NAME="Bazzite 43"\nVERSION_ID=43\n',
            blockdevices=[
                {
                    "path": "/dev/sda",
                    "kname": "sda",
                    "type": "disk",
                    "children": [
                        esp_partition("/dev/sda2", "sda", 2, ["/boot/efi"]),
                        {
                            "path": "/dev/sda3",
                            "kname": "sda3",
                            "pkname": "sda",
                            "partn": 3,
                            "type": "part",
                            "fstype": "btrfs",
                            "mountpoints": ["/"],
                        },
                    ],
                },
                {
                    "path": "/dev/nvme0n1",
                    "kname": "nvme0n1",
                    "type": "disk",
                    "children": [
                        esp_partition("/dev/nvme0n1p1", "nvme0n1", 1,
                            ["/run/media/windows"])
                    ],
                },
            ],
            efi_files={
                "/dev/sda2": ["EFI/fedora/shimx64.efi"],
                "/dev/nvme0n1p1": ["EFI/Microsoft/Boot/bootmgfw.efi"],
            },
        )

        self.assertTrue(layout["safe_to_write"])
        self.assertEqual(layout["host_os"]["profile"], "bazzite")
        self.assertEqual(layout["linux_loader"]["kind"], "shim")
        self.assertEqual(layout["clover_target"]["disk"], "/dev/sda")
        self.assertEqual(layout["clover_target"]["partition"], 2)
        self.assertEqual(layout["windows"]["device"], "/dev/nvme0n1p1")

    def test_cachyos_systemd_boot_on_emmc_is_a_valid_linux_target(self):
        layout = self.run_fixture(
            os_release='ID=cachyos\nPRETTY_NAME="CachyOS Handheld Edition"\n',
            blockdevices=[
                {
                    "path": "/dev/mmcblk0",
                    "kname": "mmcblk0",
                    "type": "disk",
                    "children": [
                        esp_partition("/dev/mmcblk0p2", "mmcblk0", 2, ["/boot"]),
                        {
                            "path": "/dev/mmcblk0p3",
                            "kname": "mmcblk0p3",
                            "pkname": "mmcblk0",
                            "partn": 3,
                            "type": "part",
                            "fstype": "btrfs",
                            "mountpoints": ["/"],
                        },
                    ],
                }
            ],
            efi_files={
                "/dev/mmcblk0p2": ["EFI/systemd/systemd-bootx64.efi"],
            },
        )

        self.assertTrue(layout["safe_to_write"])
        self.assertEqual(layout["linux_loader"]["kind"], "systemd-boot")
        self.assertEqual(
            layout["linux_loader"]["path"],
            "\\EFI\\systemd\\systemd-bootx64.efi",
        )
        self.assertEqual(layout["clover_target"]["disk"], "/dev/mmcblk0")
        self.assertEqual(layout["clover_target"]["partition"], 2)

    def test_cachyos_desktop_grub_and_refind_are_valid_linux_targets(self):
        for kind, path in (
            ("grub", "EFI/cachyos/grubx64.efi"),
            ("refind", "EFI/refind/refind_x64.efi"),
        ):
            with self.subTest(kind=kind):
                layout = self.run_fixture(
                    os_release='ID=cachyos\nPRETTY_NAME="CachyOS Desktop"\n',
                    blockdevices=[
                        {
                            "path": "/dev/sda",
                            "kname": "sda",
                            "type": "disk",
                            "children": [
                                esp_partition("/dev/sda1", "sda", 1, ["/boot"],
                                    "dddddddd-dddd-dddd-dddd-dddddddddddd")
                            ],
                        }
                    ],
                    efi_files={"/dev/sda1": [path]},
                )

                self.assertTrue(layout["safe_to_write"])
                self.assertEqual(layout["linux_loader"]["kind"], kind)
                self.assertEqual(
                    layout["linux_loader"]["path"],
                    "\\" + path.replace("/", "\\"),
                )

    def test_unknown_distro_uses_matching_nvram_loader_only_after_confirmation(self):
        common = {
            "os_release": 'ID=ubuntu\nPRETTY_NAME="Ubuntu 26.04 LTS"\n',
            "blockdevices": [
                {
                    "path": "/dev/sda",
                    "kname": "sda",
                    "type": "disk",
                    "children": [
                        esp_partition("/dev/sda1", "sda", 1, ["/boot/efi"],
                            "cccccccc-cccc-cccc-cccc-cccccccccccc"),
                        {
                            "path": "/dev/sda2",
                            "kname": "sda2",
                            "pkname": "sda",
                            "partn": 2,
                            "type": "part",
                            "fstype": "ext4",
                            "mountpoints": ["/"],
                        },
                    ],
                }
            ],
            "efi_files": {"/dev/sda1": ["EFI/ubuntu/shimx64.efi"]},
            "efibootmgr": (
                "BootOrder: 0004\n"
                "Boot0004* Ubuntu\tHD(1,GPT,cccccccc-cccc-cccc-cccc-cccccccccccc,0x800,0x100000)/\\EFI\\ubuntu\\shimx64.efi\n"
            ),
        }

        unconfirmed = self.run_fixture(**common)
        confirmed = self.run_fixture(**common, allow_generic=True)

        self.assertFalse(unconfirmed["safe_to_write"])
        self.assertTrue(unconfirmed["requires_confirmation"])
        self.assertTrue(confirmed["safe_to_write"])
        self.assertEqual(confirmed["host_os"]["profile"], "generic")
        self.assertFalse(confirmed["linux_loader"]["validated"])
        self.assertEqual(confirmed["linux_loader"]["kind"], "generic")
        self.assertEqual(confirmed["linux_loader"]["path"], "\\EFI\\ubuntu\\shimx64.efi")

    def test_live_mode_scans_a_mounted_esp(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            esp = root / "esp"
            loader = esp / "EFI" / "steamos" / "steamcl.efi"
            loader.parent.mkdir(parents=True)
            loader.write_bytes(b"steam-loader")
            os_release = root / "os-release"
            os_release.write_text('ID=steamos\nPRETTY_NAME="SteamOS"\n', encoding="utf-8")

            bin_dir = root / "bin"
            bin_dir.mkdir()
            lsblk_data = {
                "blockdevices": [
                    {
                        "path": "/dev/nvme0n1",
                        "kname": "nvme0n1",
                        "type": "disk",
                        "children": [
                            esp_partition("/dev/nvme0n1p1", "nvme0n1", 1, [str(esp)],
                                "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")
                        ],
                    }
                ]
            }
            lsblk = bin_dir / "lsblk"
            lsblk.write_text(
                "#!/bin/sh\nprintf '%s\\n' '" + json.dumps(lsblk_data) + "'\n",
                encoding="utf-8",
            )
            lsblk.chmod(0o755)
            efibootmgr = bin_dir / "efibootmgr"
            efibootmgr.write_text(
                "#!/bin/sh\nprintf '%s\\n' 'BootOrder: 0002' 'Boot0002* SteamOS\\tHD(1,GPT,aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa,0x800,0x100000)/\\EFI\\steamos\\steamcl.efi'\n",
                encoding="utf-8",
            )
            efibootmgr.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = str(bin_dir) + os.pathsep + env["PATH"]
            env["CLOVER_OS_RELEASE_PATH"] = str(os_release)
            proc = subprocess.run(
                ["python3", str(DISCOVERY)],
                text=True,
                capture_output=True,
                check=False,
                env=env,
            )

        self.assertEqual(proc.returncode, 0, proc.stderr)
        layout = json.loads(proc.stdout)
        self.assertTrue(layout["safe_to_write"])
        self.assertEqual(layout["linux_loader"]["path"], "\\EFI\\steamos\\steamcl.efi")

    def test_unscanned_second_esp_blocks_writes(self):
        layout = self.run_fixture(
            os_release='ID=steamos\nPRETTY_NAME="SteamOS"\n',
            blockdevices=[
                {
                    "path": "/dev/nvme0n1",
                    "kname": "nvme0n1",
                    "type": "disk",
                    "children": [
                        esp_partition("/dev/nvme0n1p1", "nvme0n1", 1, ["/esp"])
                    ],
                },
                {
                    "path": "/dev/nvme1n1",
                    "kname": "nvme1n1",
                    "type": "disk",
                    "children": [
                        esp_partition("/dev/nvme1n1p1", "nvme1n1", 1, [])
                    ],
                },
            ],
            efi_files={"/dev/nvme0n1p1": ["EFI/steamos/steamcl.efi"]},
        )

        self.assertFalse(layout["safe_to_write"])
        self.assertEqual(layout["unscanned_esps"], ["/dev/nvme1n1p1"])
        self.assertIn("esp_unscanned", layout["problems"])

    def test_protected_windows_loader_is_still_detected(self):
        layout = self.run_fixture(
            os_release='ID=steamos\nPRETTY_NAME="SteamOS"\n',
            blockdevices=[
                {
                    "path": "/dev/nvme0n1",
                    "kname": "nvme0n1",
                    "type": "disk",
                    "children": [
                        esp_partition("/dev/nvme0n1p1", "nvme0n1", 1, ["/esp"])
                    ],
                }
            ],
            efi_files={
                "/dev/nvme0n1p1": [
                    "EFI/steamos/steamcl.efi",
                    "EFI/Microsoft/Boot/bootmgfw.efi.orig",
                    "EFI/Microsoft/bootmgfw.efi",
                ]
            },
        )

        self.assertIsNotNone(layout["windows"])
        self.assertEqual(layout["windows"]["device"], "/dev/nvme0n1p1")
        self.assertEqual(layout["windows"]["state"], "protected")

    def test_live_scan_keeps_protected_windows_backup_in_inventory(self):
        with tempfile.TemporaryDirectory() as tmp:
            esp = Path(tmp) / "esp"
            files = (
                esp / "EFI" / "steamos" / "steamcl.efi",
                esp / "EFI" / "Microsoft" / "Boot" / "bootmgfw.efi.orig",
                esp / "EFI" / "Microsoft" / "bootmgfw.efi",
            )
            for path in files:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"loader")
            device = esp_partition(
                "/dev/nvme0n1p1",
                "nvme0n1",
                1,
                [str(esp)],
                "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            )
            lsblk = {"blockdevices": [device]}
            inventory = BOOT_DISCOVERY.scan_mounted_efi_files(lsblk)
            layout = BOOT_DISCOVERY.discover(
                'ID=steamos\nPRETTY_NAME="SteamOS"\n',
                lsblk,
                inventory,
                "",
            )

        self.assertIsNotNone(layout["windows"])
        self.assertEqual(layout["windows"]["state"], "protected")

    def test_live_mode_temporarily_mounts_unmounted_esps_read_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            esp = root / "esp"
            loader = esp / "EFI" / "steamos" / "steamcl.efi"
            loader.parent.mkdir(parents=True)
            loader.write_bytes(b"steam-loader")
            os_release = root / "os-release"
            os_release.write_text('ID=steamos\nPRETTY_NAME="SteamOS"\n', encoding="utf-8")
            calls = root / "calls"

            bin_dir = root / "bin"
            bin_dir.mkdir()
            lsblk_data = {
                "blockdevices": [
                    {
                        "path": "/dev/nvme0n1",
                        "kname": "nvme0n1",
                        "type": "disk",
                        "children": [
                            esp_partition("/dev/nvme0n1p1", "nvme0n1", 1, [str(esp)])
                        ],
                    },
                    {
                        "path": "/dev/nvme1n1",
                        "kname": "nvme1n1",
                        "type": "disk",
                        "children": [
                            esp_partition("/dev/nvme1n1p1", "nvme1n1", 1, [])
                        ],
                    },
                ]
            }
            (bin_dir / "lsblk").write_text(
                "#!/bin/sh\nprintf '%s\\n' '" + json.dumps(lsblk_data) + "'\n",
                encoding="utf-8",
            )
            (bin_dir / "efibootmgr").write_text(
                "#!/bin/sh\nprintf '%s\\n' 'BootOrder: 0002,0001'\n",
                encoding="utf-8",
            )
            (bin_dir / "mount").write_text(
                "#!/bin/sh\n"
                "for arg do target=$arg; done\n"
                f"printf '%s\\n' \"$*\" >> '{calls}'\n"
                "mkdir -p \"$target/EFI/Microsoft/Boot\"\n"
                "printf windows > \"$target/EFI/Microsoft/Boot/bootmgfw.efi\"\n",
                encoding="utf-8",
            )
            (bin_dir / "umount").write_text(
                "#!/bin/sh\n" f"printf 'umount %s\\n' \"$1\" >> '{calls}'\n",
                encoding="utf-8",
            )
            for command in bin_dir.iterdir():
                command.chmod(0o755)

            env = os.environ.copy()
            env["PATH"] = str(bin_dir) + os.pathsep + env["PATH"]
            env["CLOVER_OS_RELEASE_PATH"] = str(os_release)
            proc = subprocess.run(
                ["python3", str(DISCOVERY), "--mount-unmounted"],
                text=True,
                capture_output=True,
                check=False,
                env=env,
            )

            calls_text = calls.read_text(encoding="utf-8") if calls.exists() else ""

        self.assertEqual(proc.returncode, 0, proc.stderr)
        layout = json.loads(proc.stdout)
        self.assertTrue(layout["safe_to_write"])
        self.assertEqual(layout["windows"]["device"], "/dev/nvme1n1p1")
        self.assertIn("-o ro,nosuid,nodev,noexec /dev/nvme1n1p1", calls_text)
        self.assertIn("umount ", calls_text)

    def test_unrelated_fat_data_partition_is_not_treated_as_an_esp(self):
        layout = self.run_fixture(
            os_release='ID=steamos\nPRETTY_NAME="SteamOS"\n',
            blockdevices=[{
                "path": "/dev/sda", "kname": "sda", "type": "disk", "children": [
                    {
                        "path": "/dev/sda1", "kname": "sda1", "pkname": "sda",
                        "partn": 1, "partuuid": "11111111-1111-1111-1111-111111111111",
                        "type": "part", "fstype": "vfat", "parttype": "0700",
                        "mountpoints": [],
                    },
                    esp_partition("/dev/sda2", "sda", 2, ["/esp"],
                        "22222222-2222-2222-2222-222222222222"),
                ],
            }],
            efi_files={"/dev/sda2": ["EFI/steamos/steamcl.efi"]},
        )

        self.assertTrue(layout["safe_to_write"])
        self.assertNotIn("/dev/sda1", layout["unscanned_esps"])
        self.assertEqual(layout["clover_target"]["device"], "/dev/sda2")


if __name__ == "__main__":
    unittest.main()
