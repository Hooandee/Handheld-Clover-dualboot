#!/usr/bin/env python3
"""Desktop UI for the Clover dual-boot tools. A thin frontend over clover-ctl.

Every privileged action is performed by `sudo clover-ctl ...`; the password is
asked once and reused for the session (same model as the old zenity Toolbox).
"""

import json
import os
import shutil
import subprocess
import sys

from PySide6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QFormLayout, QGroupBox,
    QLabel, QPushButton, QComboBox, QInputDialog, QLineEdit, QMessageBox,
)
from PySide6.QtCore import Qt


def find_ctl():
    env = os.environ.get("CLOVER_CTL")
    if env and os.path.exists(env):
        return os.path.abspath(env)
    here = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(here, "..", "clover-ctl"),
        os.path.expanduser("~/1Clover-tools/clover-ctl"),
        shutil.which("clover-ctl"),
    ]
    for c in candidates:
        if c and os.path.exists(c):
            return os.path.abspath(c)
    return "clover-ctl"


CTL = find_ctl()
RES_PRESETS = ["Auto-detect", "1280x800", "1920x1080", "1920x1200", "2560x1600"]
TIMEOUTS = ["1", "5", "10", "15", "60"]
DEFAULT_OS = [("Windows", "windows"), ("SteamOS", "steamos"),
              ("Bazzite", "bazzite"), ("Last used", "lastos")]


class Engine:
    """Runs clover-ctl, elevating with a once-asked sudo password."""

    def __init__(self):
        self.password = None

    def ensure_auth(self, parent):
        if self.password is not None:
            return True
        pw, ok = QInputDialog.getText(
            parent, "Authentication", "Enter your sudo password:",
            QLineEdit.EchoMode.Password)
        if not ok:
            return False
        check = subprocess.run(["sudo", "-S", "-v"], input=pw + "\n",
                               text=True, capture_output=True)
        if check.returncode != 0:
            QMessageBox.critical(parent, "Clover", "That sudo password was rejected.")
            return False
        self.password = pw
        return True

    def run(self, args, parent, root=True):
        if root:
            if not self.ensure_auth(parent):
                return 1, "", "cancelled"
            proc = subprocess.run(["sudo", "-S", CTL, *args],
                                  input=(self.password or "") + "\n",
                                  text=True, capture_output=True)
        else:
            proc = subprocess.run([CTL, *args], text=True, capture_output=True)
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()

    def status(self, parent):
        rc, out, _ = self.run(["status"], parent)
        if rc != 0:
            return None
        try:
            return json.loads(out)
        except json.JSONDecodeError:
            return None

    def themes(self, parent):
        rc, out, _ = self.run(["list-themes"], parent)
        return out.splitlines() if rc == 0 and out else []


class CloverWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.engine = Engine()
        self.setWindowTitle("Clover Dual Boot")
        self.setMinimumWidth(460)

        root = QVBoxLayout(self)

        self.status_label = QLabel("Loading…")
        self.status_label.setWordWrap(True)
        status_box = QGroupBox("Current state")
        sb = QVBoxLayout(status_box)
        sb.addWidget(self.status_label)
        root.addWidget(status_box)

        controls = QGroupBox("Settings")
        form = QFormLayout(controls)

        self.default_combo = QComboBox()
        for label, _ in DEFAULT_OS:
            self.default_combo.addItem(label)
        form.addRow("Default boot OS", self._with_apply(self.default_combo, self.apply_default_os))

        self.res_combo = QComboBox()
        self.res_combo.setEditable(True)
        self.res_combo.addItems(RES_PRESETS)
        form.addRow("Screen resolution", self._with_apply(self.res_combo, self.apply_resolution))

        self.theme_combo = QComboBox()
        form.addRow("Theme", self._with_apply(self.theme_combo, self.apply_theme))

        self.timeout_combo = QComboBox()
        self.timeout_combo.addItems(TIMEOUTS)
        form.addRow("Boot menu timeout (s)", self._with_apply(self.timeout_combo, self.apply_timeout))

        root.addWidget(controls)

        service_box = QGroupBox("Boot control")
        srow = QHBoxLayout(service_box)
        win_btn = QPushButton("Boot to Windows next")
        win_btn.clicked.connect(self.boot_windows)
        clover_btn = QPushButton("Re-enable Clover")
        clover_btn.clicked.connect(self.enable_clover)
        srow.addWidget(win_btn)
        srow.addWidget(clover_btn)
        root.addWidget(service_box)

        gm_box = QGroupBox("Game Mode (Decky)")
        grow = QHBoxLayout(gm_box)
        decky_btn = QPushButton("Install / update Decky plugin")
        decky_btn.clicked.connect(self.install_decky)
        grow.addWidget(decky_btn)
        root.addWidget(gm_box)

        bottom = QHBoxLayout()
        refresh = QPushButton("Refresh")
        refresh.clicked.connect(self.refresh)
        quit_btn = QPushButton("Quit")
        quit_btn.clicked.connect(self.close)
        bottom.addStretch()
        bottom.addWidget(refresh)
        bottom.addWidget(quit_btn)
        root.addLayout(bottom)

        self.refresh()

    def _with_apply(self, widget, handler):
        wrap = QWidget()
        lay = QHBoxLayout(wrap)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.addWidget(widget, 1)
        btn = QPushButton("Apply")
        btn.clicked.connect(handler)
        lay.addWidget(btn)
        return wrap

    def refresh(self):
        st = self.engine.status(self)
        if not st:
            self.status_label.setText("Could not read Clover status (is it installed?).")
            return
        self.status_label.setText(
            f"OS: {st.get('os')}    Clover installed: {st.get('installed')}\n"
            f"Default boot: {st.get('default_os')}    Service: {st.get('service')}\n"
            f"Resolution: {st.get('resolution')}    Theme: {st.get('theme')}    "
            f"Timeout: {st.get('timeout')}s")
        # reflect current values in the controls
        self._select(self.res_combo, st.get("resolution"))
        self._select(self.timeout_combo, st.get("timeout"))
        for i, (_, value) in enumerate(DEFAULT_OS):
            if value == st.get("default_os"):
                self.default_combo.setCurrentIndex(i)
        if self.theme_combo.count() == 0:
            themes = self.engine.themes(self)
            if themes:
                self.theme_combo.addItems(themes)
        self._select(self.theme_combo, st.get("theme"))

    def _select(self, combo, value):
        if value is None:
            return
        idx = combo.findText(str(value))
        if idx >= 0:
            combo.setCurrentIndex(idx)
        elif combo.isEditable():
            combo.setCurrentText(str(value))

    def _apply(self, args, ok_msg):
        rc, out, err = self.engine.run(args, self)
        if rc == 0:
            self.refresh()
            self.status_label.setText(self.status_label.text() + f"\n\n✓ {ok_msg}")
        elif err != "cancelled":
            QMessageBox.warning(self, "Clover", err or out or "Command failed.")

    def apply_default_os(self):
        value = DEFAULT_OS[self.default_combo.currentIndex()][1]
        self._apply(["set-default-os", value], f"Default boot set to {value}.")

    def apply_resolution(self):
        text = self.res_combo.currentText().strip()
        value = "auto" if text == "Auto-detect" else text
        self._apply(["set-resolution", value], "Resolution updated.")

    def apply_theme(self):
        if self.theme_combo.currentText():
            self._apply(["set-theme", self.theme_combo.currentText()], "Theme updated.")

    def apply_timeout(self):
        self._apply(["set-timeout", self.timeout_combo.currentText()], "Timeout updated.")

    def boot_windows(self):
        if QMessageBox.question(self, "Clover",
                                "Hand the next boot to Windows and disable the Clover service?") \
                == QMessageBox.StandardButton.Yes:
            self._apply(["service", "disable"], "Next boot will go to Windows.")

    def enable_clover(self):
        self._apply(["service", "enable"], "Clover service re-enabled.")

    def install_decky(self):
        rc, out, err = self.engine.run(["install-decky"], self)
        if rc == 0:
            QMessageBox.information(self, "Clover", out or "Decky plugin installed.")
        elif err != "cancelled":
            QMessageBox.warning(self, "Clover", err or out or "Could not install the Decky plugin.")


def main():
    app = QApplication(sys.argv)
    win = CloverWindow()
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
