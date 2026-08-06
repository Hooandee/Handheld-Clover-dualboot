#!/usr/bin/env python3

import argparse
import json
import os
import re
import tempfile
import subprocess
import sys
import socket
from datetime import datetime, timezone
from pathlib import Path


UUID_RE = re.compile(
    r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b"
)
MAC_RE = re.compile(
    r"\b(?:(?:[0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}|"
    r"[0-9a-fA-F]{4}\.[0-9a-fA-F]{4}\.[0-9a-fA-F]{4})\b"
)
NUMERIC_ID_RE = re.compile(r"\b\d{8,}\b")
HOME_RE = re.compile(r"/home/[^/\s:\"']+")
PRIVATE_KEY_RE = re.compile(r"serial|hostname|host_name|\bmac\b|mac_?addr", re.IGNORECASE)
SERIAL_LABEL_RE = re.compile(
    r"((?:board|product|chassis|system|baseboard)?_?serial(?:\s*number)?)(\s*[:=]\s*)(\S+)",
    re.IGNORECASE,
)
SERIAL_RUN_RE = re.compile(
    r"\b(?=[A-Za-z0-9]*[A-Za-z])(?=[A-Za-z0-9]*\d)[A-Za-z0-9]{10,}\b"
)
MAX_LOG_TEXT = 40000
OS_RELEASE_KEYS = (
    "ID",
    "ID_LIKE",
    "PRETTY_NAME",
    "VERSION_ID",
    "BUILD_ID",
    "VARIANT_ID",
    "IMAGE_ID",
    "OSTREE_VERSION",
)
DMI_FIELDS = ("sys_vendor", "product_name", "product_family", "board_name")


class Redactor:
    def __init__(self, *, home=None, hostname=None, username=None):
        self.home = (home or "").rstrip("/")
        self.hostname = hostname or ""
        self.username = username or ""
        self.uuid_aliases = {}

    def _uuid_alias(self, match):
        value = match.group(0).lower()
        if value not in self.uuid_aliases:
            self.uuid_aliases[value] = f"[uuid-{len(self.uuid_aliases) + 1}]"
        return self.uuid_aliases[value]

    def text(self, value):
        if not isinstance(value, str):
            return value
        text = value
        if self.home:
            text = text.replace(self.home, "~")
        text = HOME_RE.sub("~", text)
        if self.hostname:
            text = re.sub(re.escape(self.hostname), "HOST", text, flags=re.IGNORECASE)
        if self.username:
            text = re.sub(
                rf"\b{re.escape(self.username)}\b",
                "[user]",
                text,
                flags=re.IGNORECASE,
            )
        text = MAC_RE.sub("[mac]", text)
        text = NUMERIC_ID_RE.sub("[number-id]", text)
        text = UUID_RE.sub(self._uuid_alias, text)
        text = SERIAL_LABEL_RE.sub(lambda match: f"{match.group(1)}{match.group(2)}[serial]", text)
        text = SERIAL_RUN_RE.sub("[serial]", text)
        return text

    def object(self, value):
        if isinstance(value, dict):
            result = {}
            for key, item in value.items():
                if isinstance(key, str) and PRIVATE_KEY_RE.search(key):
                    result[key] = "[redacted]"
                else:
                    result[key] = self.object(item)
            return result
        if isinstance(value, (list, tuple)):
            return [self.object(item) for item in value]
        return self.text(value)


def _bounded_logs(logs):
    bounded = {}
    for name, value in (logs or {}).items():
        if isinstance(value, str):
            bounded[name] = value[-MAX_LOG_TEXT:]
        else:
            bounded[name] = value
    return bounded


def build_bundle(*, category, description, environment, boot, logs, redactor):
    bundle = {
        "schema": 1,
        "app": "clover-dualboot",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "category": str(category or "other"),
        "description": str(description or ""),
        "environment": environment or {},
        "boot": boot or {},
        "logs": _bounded_logs(logs),
    }
    return redactor.object(bundle)


def parse_os_release(text):
    values = {}
    for raw in (text or "").splitlines():
        if "=" not in raw or raw.lstrip().startswith("#"):
            continue
        key, value = raw.split("=", 1)
        if key in OS_RELEASE_KEYS:
            values[key.lower()] = value.strip().strip('"\'')
    return values


def _read_text(path):
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None


def _run(command):
    try:
        proc = subprocess.run(
            command,
            text=True,
            capture_output=True,
            check=False,
            timeout=20,
        )
        output = proc.stdout if proc.stdout else proc.stderr
        return output[-MAX_LOG_TEXT:]
    except (OSError, subprocess.SubprocessError):
        return ""


def _json_or_empty(text):
    try:
        value = json.loads(text or "")
        return value if isinstance(value, dict) else {}
    except json.JSONDecodeError:
        return {}


def collect_bundle(
    *,
    category,
    description,
    ctl_path,
    discovery_path,
    home,
    hostname,
    username="",
    read_text=_read_text,
    run=_run,
):
    os_info = parse_os_release(read_text("/etc/os-release"))
    dmi = {}
    for field in DMI_FIELDS:
        value = read_text(f"/sys/class/dmi/id/{field}")
        dmi[field] = (value or "").strip()
    layout = _json_or_empty(run([sys.executable, discovery_path, "--mount-unmounted"]))
    status = _json_or_empty(run([ctl_path, "status"]))
    environment = {
        "os": os_info,
        "dmi": dmi,
        "kernel": run(["uname", "-r"]).strip(),
        "secure_boot": run(["mokutil", "--sb-state"]).strip(),
        "plugin_version": run([ctl_path, "version"]).strip(),
    }
    logs = {
        "service": run(
            [
                "journalctl",
                "-b",
                "-u",
                "clover-bootmanager.service",
                "-n",
                "400",
                "--no-pager",
            ]
        )
    }
    return build_bundle(
        category=category,
        description=description,
        environment=environment,
        boot={"layout": layout, "status": status},
        logs=logs,
        redactor=Redactor(home=home, hostname=hostname, username=username),
    )


def save_bundle(bundle, path):
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{target.name}.", dir=target.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            fd = -1
            json.dump(bundle, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        os.replace(temporary, target)
        os.chmod(target, 0o600)
    except Exception:
        if fd >= 0:
            os.close(fd)
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise
    return target


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--ctl", required=True)
    parser.add_argument("--discovery", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--category", default="system")
    parser.add_argument("--description", default="")
    parser.add_argument("--home", default=os.path.expanduser("~"))
    parser.add_argument("--user", default="")
    args = parser.parse_args(argv)
    try:
        hostname = socket.gethostname()
    except OSError:
        hostname = ""
    home = args.home
    bundle = collect_bundle(
        category=args.category,
        description=args.description,
        ctl_path=args.ctl,
        discovery_path=args.discovery,
        home=home,
        hostname=hostname,
        username=args.user,
    )
    path = save_bundle(bundle, args.output)
    print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
