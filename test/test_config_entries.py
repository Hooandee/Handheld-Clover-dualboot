#!/usr/bin/env python3

import plistlib
import unittest
from pathlib import Path


CONFIG = Path(__file__).resolve().parents[1] / "custom" / "config.plist"


class CloverConfigEntryTests(unittest.TestCase):
    def test_validated_linux_loaders_have_menu_entries(self):
        with CONFIG.open("rb") as handle:
            config = plistlib.load(handle)
        entries = config["GUI"]["Custom"]["Entries"]
        by_path = {str(entry.get("Path", "")).lower(): entry for entry in entries}

        self.assertIn("\\efi\\steamos\\steamcl.efi", by_path)
        self.assertIn("\\efi\\fedora\\shimx64.efi", by_path)
        self.assertIn("\\efi\\limine\\limine_x64.efi", by_path)
        self.assertIn("\\efi\\systemd\\systemd-bootx64.efi", by_path)
        self.assertIn("\\efi\\cachyos\\grubx64.efi", by_path)
        self.assertIn("\\efi\\refind\\refind_x64.efi", by_path)
        self.assertIn(
            "CachyOS",
            by_path["\\efi\\limine\\limine_x64.efi"]["FullTitle"],
        )
        self.assertNotIn(
            "Pop!_OS",
            by_path["\\efi\\systemd\\systemd-bootx64.efi"]["FullTitle"],
        )


if __name__ == "__main__":
    unittest.main()
