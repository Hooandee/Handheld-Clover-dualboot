#!/usr/bin/env python3
"""Desktop UI for the Clover dual-boot tools - a thin frontend over clover-ctl.

Sidebar navigation with one page per area. Privileged actions run via
`sudo clover-ctl ...`; the password is asked once and reused for the session.
"""

import json
import os
import shutil
import subprocess
import sys

from PySide6.QtCore import QSize
from PySide6.QtGui import QIcon
from PySide6.QtWidgets import (
    QApplication, QComboBox, QFormLayout, QFrame, QGridLayout, QHBoxLayout,
    QInputDialog, QLabel, QLineEdit, QListWidget, QListWidgetItem, QMainWindow,
    QMessageBox, QPushButton, QStackedWidget, QStyle, QVBoxLayout, QWidget,
)


def find_ctl():
    env = os.environ.get("CLOVER_CTL")
    if env and os.path.exists(env):
        return os.path.abspath(env)
    here = os.path.dirname(os.path.abspath(__file__))
    for c in (os.path.join(here, "..", "clover-ctl"),
              os.path.expanduser("~/1Clover-tools/clover-ctl"),
              shutil.which("clover-ctl")):
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
        pw, ok = QInputDialog.getText(parent, "Authentication",
                                      "Enter your sudo password:",
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

    def logos(self, parent):
        rc, out, _ = self.run(["list-logos"], parent, root=False)
        return out.splitlines() if rc == 0 and out else []


class CloverWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.engine = Engine()
        self.setWindowTitle("Clover Dual Boot")
        self.resize(660, 470)

        central = QWidget()
        self.setCentralWidget(central)
        layout = QHBoxLayout(central)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        self.sidebar = QListWidget()
        self.sidebar.setIconSize(QSize(22, 22))
        self.sidebar.setFixedWidth(170)
        self.sidebar.setFrameShape(QFrame.Shape.NoFrame)
        self.stack = QStackedWidget()

        pages = [
            ("Status", "dialog-information", QStyle.StandardPixmap.SP_MessageBoxInformation, self._status_page),
            ("Boot", "drive-harddisk", QStyle.StandardPixmap.SP_DriveHDIcon, self._boot_page),
            ("Display", "video-display", QStyle.StandardPixmap.SP_DesktopIcon, self._display_page),
            ("Themes", "preferences-desktop-theme", QStyle.StandardPixmap.SP_FileDialogContentsView, self._themes_page),
            ("Game Mode", "input-gaming", QStyle.StandardPixmap.SP_ComputerIcon, self._gamemode_page),
            ("Advanced", "applications-system", QStyle.StandardPixmap.SP_FileDialogDetailedView, self._advanced_page),
        ]
        for title, icon_name, fallback, builder in pages:
            self.sidebar.addItem(QListWidgetItem(self._icon(icon_name, fallback), title))
            self.stack.addWidget(builder())

        self.sidebar.currentRowChanged.connect(self.stack.setCurrentIndex)
        layout.addWidget(self.sidebar)
        layout.addWidget(self.stack, 1)

        self.sidebar.setCurrentRow(0)
        self.refresh()

    def _icon(self, name, fallback):
        ic = QIcon.fromTheme(name)
        return ic if not ic.isNull() else self.style().standardIcon(fallback)

    def _page(self, title):
        page = QWidget()
        v = QVBoxLayout(page)
        v.setContentsMargins(18, 14, 18, 14)
        v.addWidget(QLabel(f"<h2>{title}</h2>"))
        return page, v

    def _apply_row(self, widget, handler):
        wrap = QWidget()
        h = QHBoxLayout(wrap)
        h.setContentsMargins(0, 0, 0, 0)
        h.addWidget(widget, 1)
        btn = QPushButton("Apply")
        btn.clicked.connect(handler)
        h.addWidget(btn)
        return wrap

    def _status_page(self):
        page, v = self._page("Current state")
        grid = QGridLayout()
        self.status_fields = {}
        rows = [("OS", "os"), ("Clover installed", "installed"),
                ("Default boot", "default_os"), ("Service", "service"),
                ("Resolution", "resolution"), ("Theme", "theme"),
                ("Timeout (s)", "timeout"), ("Windows active", "windows_active")]
        for i, (label, key) in enumerate(rows):
            grid.addWidget(QLabel(f"<b>{label}</b>"), i, 0)
            val = QLabel("…")
            self.status_fields[key] = val
            grid.addWidget(val, i, 1)
        grid.setColumnStretch(1, 1)
        v.addLayout(grid)
        v.addStretch(1)
        row = QHBoxLayout()
        refresh = QPushButton(self._icon("view-refresh", QStyle.StandardPixmap.SP_BrowserReload), "Refresh")
        refresh.clicked.connect(self.refresh)
        report = QPushButton(self._icon("document-save", QStyle.StandardPixmap.SP_DialogSaveButton), "Save bug report")
        report.clicked.connect(self.save_report)
        row.addWidget(refresh)
        row.addWidget(report)
        row.addStretch(1)
        v.addLayout(row)
        return page

    def _boot_page(self):
        page, v = self._page("Boot")
        form = QFormLayout()
        self.default_combo = QComboBox()
        for label, _ in DEFAULT_OS:
            self.default_combo.addItem(label)
        form.addRow("Default boot OS", self._apply_row(self.default_combo, self.apply_default_os))
        v.addLayout(form)
        v.addSpacing(12)
        v.addWidget(QLabel("<b>Quick actions</b>"))
        row = QHBoxLayout()
        win = QPushButton("Boot to Windows next")
        win.clicked.connect(self.boot_windows)
        clv = QPushButton("Re-enable Clover")
        clv.clicked.connect(self.enable_clover)
        row.addWidget(win)
        row.addWidget(clv)
        v.addLayout(row)
        v.addStretch(1)
        return page

    def _display_page(self):
        page, v = self._page("Display")
        form = QFormLayout()
        self.res_combo = QComboBox()
        self.res_combo.setEditable(True)
        self.res_combo.addItems(RES_PRESETS)
        form.addRow("Screen resolution", self._apply_row(self.res_combo, self.apply_resolution))
        self.timeout_combo = QComboBox()
        self.timeout_combo.addItems(TIMEOUTS)
        form.addRow("Boot menu timeout (s)", self._apply_row(self.timeout_combo, self.apply_timeout))
        v.addLayout(form)
        v.addStretch(1)
        return page

    def _themes_page(self):
        page, v = self._page("Theme")
        form = QFormLayout()
        self.theme_combo = QComboBox()
        form.addRow("Clover theme", self._apply_row(self.theme_combo, self.apply_theme))
        v.addLayout(form)
        v.addWidget(QLabel("Themes live on the EFI partition. \"random\" rotates on each boot."))
        v.addSpacing(14)
        v.addWidget(QLabel("<b>Boot logo</b>"))
        logo_row = QWidget()
        lh = QHBoxLayout(logo_row)
        lh.setContentsMargins(0, 0, 0, 0)
        self.logo_combo = QComboBox()
        lh.addWidget(self.logo_combo, 1)
        set_logo = QPushButton("Set")
        set_logo.clicked.connect(self.apply_logo)
        reset_logo = QPushButton("Restore default")
        reset_logo.clicked.connect(self.reset_logo)
        lh.addWidget(set_logo)
        lh.addWidget(reset_logo)
        v.addWidget(logo_row)
        v.addStretch(1)
        return page

    def _gamemode_page(self):
        page, v = self._page("Game Mode (Decky)")
        v.addWidget(QLabel("Install the Decky plugin to control Clover from Game Mode\n"
                           "(default OS, resolution, theme, timeout, boot-to-Windows)."))
        btn = QPushButton(self._icon("input-gaming", QStyle.StandardPixmap.SP_ComputerIcon),
                          "Install / update Decky plugin")
        btn.clicked.connect(self.install_decky)
        v.addWidget(btn)
        v.addStretch(1)
        return page

    def _advanced_page(self):
        page, v = self._page("Advanced")
        form = QFormLayout()
        self.batocera_combo = QComboBox()
        self.batocera_combo.addItems(["v39 (and newer)", "v38 (and older)"])
        form.addRow("Batocera version", self._apply_row(self.batocera_combo, self.apply_batocera))
        v.addLayout(form)
        v.addWidget(QLabel("Only needed if you boot Batocera from a microSD / USB."))
        v.addSpacing(16)
        v.addWidget(QLabel("<b>Danger zone</b>"))
        v.addWidget(QLabel("Remove Clover and restore the Windows bootloader."))
        uninstall = QPushButton(self._icon("edit-delete", QStyle.StandardPixmap.SP_TrashIcon), "Uninstall Clover")
        uninstall.clicked.connect(self.uninstall)
        v.addWidget(uninstall)
        v.addStretch(1)
        return page

    def refresh(self):
        st = self.engine.status(self)
        if not st:
            self.statusBar().showMessage("Could not read Clover status (is it installed?)")
            return
        for key, lbl in self.status_fields.items():
            lbl.setText(str(st.get(key, "—")))
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
        if self.logo_combo.count() == 0:
            logos = self.engine.logos(self)
            if logos:
                self.logo_combo.addItems(logos)
        self.statusBar().showMessage("Ready")

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
            self.statusBar().showMessage("✓ " + ok_msg)
            self.refresh()
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

    def save_report(self):
        rc, out, err = self.engine.run(["diagnostics"], self)
        if rc == 0:
            QMessageBox.information(self, "Clover", f"Bug report saved to:\n{out}")
        elif err != "cancelled":
            QMessageBox.warning(self, "Clover", err or out or "Could not write the report.")

    def apply_logo(self):
        if self.logo_combo.currentText():
            self._apply(["set-logo", self.logo_combo.currentText()], "Boot logo updated.")

    def reset_logo(self):
        self._apply(["reset-logo"], "Boot logo restored to default.")

    def apply_batocera(self):
        value = "v39" if self.batocera_combo.currentIndex() == 0 else "v38"
        self._apply(["set-batocera", value], f"Batocera config set to {value}.")

    def uninstall(self):
        if QMessageBox.warning(
                self, "Uninstall Clover",
                "This removes Clover and restores the Windows bootloader. Continue?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                QMessageBox.StandardButton.No) != QMessageBox.StandardButton.Yes:
            return
        rc, out, err = self.engine.run(["uninstall"], self)
        if rc == 0:
            QMessageBox.information(self, "Clover",
                                    (out or "Clover uninstalled.") + "\n\nReboot to return to Windows.")
            self.close()
        elif err != "cancelled":
            QMessageBox.warning(self, "Clover", err or out or "Uninstall failed.")


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Clover Dual Boot")
    win = CloverWindow()
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
