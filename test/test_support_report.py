#!/usr/bin/env python3

import sys
import json
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "custom"))

from support_report import (  # noqa: E402
    Redactor,
    build_bundle,
    collect_bundle,
    save_bundle,
)


class SupportReportTests(unittest.TestCase):
    def test_cli_uses_the_calling_users_home_for_redaction(self):
        script = Path(__file__).resolve().parents[1] / "custom" / "support_report.py"
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ctl = root / "clover-ctl"
            discovery = root / "boot-discovery.py"
            output = root / "report.json"
            private_home = "/home/fictional-user"
            ctl.write_text("#!/bin/sh\nprintf '{}\\n'\n", encoding="utf-8")
            discovery.write_text("#!/bin/sh\nprintf '{}\\n'\n", encoding="utf-8")
            ctl.chmod(0o755)
            discovery.chmod(0o755)
            proc = subprocess.run(
                [
                    sys.executable,
                    str(script),
                    "--ctl",
                    str(ctl),
                    "--discovery",
                    str(discovery),
                    "--output",
                    str(output),
                    "--home",
                    private_home,
                    "--description",
                    f"config is under {private_home}/1Clover-tools",
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            report = output.read_text(encoding="utf-8") if output.exists() else ""

        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertNotIn(private_home, report)
        self.assertIn("~/1Clover-tools", report)

    def test_redactor_removes_personal_ids_but_preserves_uuid_relationships(self):
        uuid = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        redactor = Redactor(
            home="/home/private", hostname="private-host", username="private"
        )
        result = redactor.object(
            {
                "layout": {"partuuid": uuid, "entry": f"HD(1,GPT,{uuid},0x800)"},
                "path": "/home/private/1Clover-tools/status.txt",
                "hostname": "private-host",
                "user": "private ran the command",
                "line": "serial: DEVICE123456 mac aa:bb:cc:dd:ee:ff",
                "formats": "mac aa-bb-cc-dd-ee-ff id 123456789012",
            }
        )

        rendered = str(result)
        self.assertNotIn(uuid, rendered)
        self.assertEqual(result["layout"]["partuuid"], "[uuid-1]")
        self.assertIn("[uuid-1]", result["layout"]["entry"])
        self.assertEqual(result["path"], "~/1Clover-tools/status.txt")
        self.assertEqual(result["hostname"], "[redacted]")
        self.assertNotIn("private", result["user"].lower())
        self.assertNotIn("DEVICE123456", rendered)
        self.assertNotIn("aa:bb:cc:dd:ee:ff", rendered)
        self.assertNotIn("aa-bb-cc-dd-ee-ff", rendered)
        self.assertNotIn("123456789012", rendered)
        self.assertEqual(
            Redactor(hostname="x", username="q").text("host x user q"),
            "host HOST user [user]",
        )

    def test_bundle_includes_distro_boot_health_and_bounded_logs(self):
        bundle = build_bundle(
            category="boot-priority",
            description="Clover does not appear first",
            environment={"os": {"id": "cachyos", "name": "CachyOS"}},
            boot={"clover_status": "fallback_only", "loader_kind": "limine"},
            logs={"service": "x" * 90000},
            redactor=Redactor(home="/home/deck", hostname="deckbox"),
        )

        self.assertEqual(bundle["app"], "clover-dualboot")
        self.assertEqual(bundle["category"], "boot-priority")
        self.assertEqual(bundle["environment"]["os"]["id"], "cachyos")
        self.assertEqual(bundle["boot"]["loader_kind"], "limine")
        self.assertLessEqual(len(bundle["logs"]["service"]), 40000)

    def test_report_file_is_private(self):
        bundle = {"app": "clover-dualboot", "schema": 1, "text": "boot issue"}
        with tempfile.TemporaryDirectory() as tmp:
            path = save_bundle(bundle, Path(tmp) / "report.json")
            mode = stat.S_IMODE(path.stat().st_mode)
            saved = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(mode, 0o600)
        self.assertEqual(saved, bundle)

    def test_collector_reads_safe_identity_and_boot_diagnostics(self):
        reads = []
        files = {
            "/etc/os-release": 'ID=cachyos\nPRETTY_NAME="CachyOS"\nVERSION_ID=2026\n',
            "/sys/class/dmi/id/sys_vendor": "Example Vendor\n",
            "/sys/class/dmi/id/product_name": "Example Handheld\n",
            "/sys/class/dmi/id/product_family": "Example Family\n",
            "/sys/class/dmi/id/board_name": "Example Board\n",
        }

        def read_text(path):
            reads.append(path)
            return files.get(path)

        def run(command):
            if command[-1] == "--mount-unmounted":
                return json.dumps({"host_os": {"profile": "cachyos"}, "clover": {"status": "registered"}})
            if command[-1] == "status":
                return json.dumps({"loader_kind": "limine", "clover_first": True})
            if command[0] == "uname":
                return "6.18.1-cachyos\n"
            if command[0] == "mokutil":
                return "SecureBoot disabled\n"
            if command[0] == "journalctl":
                return "service repaired BootOrder\n"
            return ""

        bundle = collect_bundle(
            category="boot-priority",
            description="Clover is not first",
            ctl_path="/opt/clover/clover-ctl",
            discovery_path="/opt/clover/boot-discovery.py",
            home="/home/deck",
            hostname="deckbox",
            read_text=read_text,
            run=run,
        )

        self.assertEqual(bundle["category"], "boot-priority")
        self.assertEqual(bundle["description"], "Clover is not first")
        self.assertNotIn("categories", bundle)
        self.assertNotIn("text", bundle)
        self.assertEqual(bundle["environment"]["os"]["id"], "cachyos")
        self.assertEqual(bundle["environment"]["dmi"]["product_name"], "Example Handheld")
        self.assertNotIn("product_name", bundle["environment"])
        self.assertEqual(bundle["boot"]["layout"]["clover"]["status"], "registered")
        self.assertEqual(bundle["boot"]["status"]["loader_kind"], "limine")
        self.assertNotIn("/sys/class/dmi/id/product_serial", reads)

if __name__ == "__main__":
    unittest.main()
