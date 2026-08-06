import glob
import json
import os
import subprocess

import decky


def _find_ctl():
    candidates = [
        os.path.expanduser("~/1Clover-tools/clover-ctl"),
        os.path.join(decky.DECKY_PLUGIN_DIR, "bin", "clover-ctl"),
    ]
    candidates += glob.glob("/home/*/1Clover-tools/clover-ctl")
    for c in candidates:
        if c and os.path.exists(c):
            return c
    return "clover-ctl"


def _lang_file():
    dirs = glob.glob("/home/*/1Clover-tools")
    base = dirs[0] if dirs else os.path.expanduser("~/1Clover-tools")
    return os.path.join(base, "lang")


class Plugin:
    async def _main(self):
        self.ctl = _find_ctl()
        decky.logger.info("clover-ctl resolved to %s", self.ctl)

    async def _unload(self):
        pass

    def _run(self, args):
        # the backend runs as root (plugin.json flags: ["root"]), so clover-ctl
        # gets the privileges it needs without a password prompt
        proc = subprocess.run([self.ctl, *args], capture_output=True, text=True)
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()

    def _action(self, args):
        rc, out, err = self._run(args)
        return {"ok": rc == 0, "message": out or err}

    async def get_status(self):
        rc, out, err = self._run(["status"])
        if rc != 0:
            return {"error": err or "status failed"}
        try:
            return json.loads(out)
        except json.JSONDecodeError:
            return {"error": "could not parse status"}

    async def get_maintenance_log(self):
        return self._action(["maintenance-log"])

    async def list_themes(self):
        rc, out, _ = self._run(["list-themes"])
        return out.splitlines() if rc == 0 and out else []

    async def set_default_os(self, os_name):
        return self._action(["set-default-os", os_name])

    async def set_default_loader(self, loader):
        return self._action(["set-default-loader", loader])

    async def repair_boot_priority(self, allow_generic=False):
        args = ["repair-boot-priority"]
        if allow_generic:
            args.append("--allow-generic")
        return self._action(args)

    async def set_resolution(self, value):
        return self._action(["set-resolution", value])

    async def set_theme(self, name):
        return self._action(["set-theme", name])

    async def set_timeout(self, secs):
        return self._action(["set-timeout", str(secs)])

    async def set_service(self, action):
        return self._action(["service", action])

    async def get_lang(self):
        env = os.environ.get("CLOVER_LANG")
        if env in ("es", "en"):
            return env
        try:
            with open(_lang_file()) as f:
                val = f.read().strip()
            if val in ("es", "en"):
                return val
        except OSError:
            pass
        return "es"

    async def set_lang(self, lang):
        if lang not in ("es", "en"):
            return {"ok": False}
        path = _lang_file()
        try:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as f:
                f.write(lang + "\n")
        except OSError:
            return {"ok": False}
        try:
            # keep the file owned by the real user, not root, so the GUI can write it too
            owner = os.stat(os.path.dirname(path))
            os.chown(path, owner.st_uid, owner.st_gid)
        except OSError:
            pass
        return {"ok": True}
