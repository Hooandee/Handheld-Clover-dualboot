#!/usr/bin/env python3

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "gui"))

from boot_options import build_boot_options  # noqa: E402


class BootOptionsTests(unittest.TestCase):
    def test_cachyos_status_builds_only_installed_boot_choices(self):
        options = build_boot_options(
            {
                "available_os": [
                    {"id": "windows", "label": "Windows"},
                    {
                        "id": "cachyos",
                        "label": "CachyOS",
                        "loader": "\\EFI\\limine\\limine_x64.efi",
                        "validated": True,
                    },
                    {"id": "lastos", "label": "Last used"},
                ]
            },
            last_used_label="Última usada",
            unvalidated_label="no validado",
        )

        self.assertEqual([option["label"] for option in options], ["Windows", "CachyOS", "Última usada"])
        self.assertEqual(options[0]["command"], ["set-default-os", "windows"])
        self.assertEqual(
            options[1]["command"],
            ["set-default-loader", "\\EFI\\limine\\limine_x64.efi"],
        )
        self.assertEqual(options[2]["command"], ["set-default-os", "lastos"])

    def test_generic_linux_is_visible_but_marked_unvalidated(self):
        options = build_boot_options(
            {
                "available_os": [
                    {
                        "id": "generic",
                        "label": "Ubuntu",
                        "loader": "\\EFI\\ubuntu\\shimx64.efi",
                        "validated": False,
                    }
                ]
            },
            last_used_label="Last used",
            unvalidated_label="unvalidated",
        )

        self.assertEqual(options[0]["label"], "Ubuntu (unvalidated)")
        self.assertEqual(options[0]["command"][0], "set-default-loader")


if __name__ == "__main__":
    unittest.main()
