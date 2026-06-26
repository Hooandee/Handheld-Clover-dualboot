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

from PySide6.QtCore import QSize, Qt
from PySide6.QtGui import QIcon, QPixmap
from PySide6.QtWidgets import (
    QApplication, QCheckBox, QComboBox, QDialog, QDialogButtonBox, QFormLayout,
    QFrame, QGridLayout, QHBoxLayout, QInputDialog, QLabel, QLineEdit,
    QListWidget, QListWidgetItem, QMainWindow, QMessageBox, QPushButton,
    QScrollArea, QStackedWidget, QStyle, QVBoxLayout, QWidget,
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
TIMEOUTS = ["1", "5", "10", "15", "60"]
THEME_LIMIT = 5  # mirrors clover-ctl: the ESP only fits a handful of themes

VERSION = "1.0.0"
HERE = os.path.dirname(os.path.abspath(__file__))
ICON = os.path.join(HERE, "clover.png")
FLAG_DIR = os.path.join(HERE, "flags")

LANG_FILE = os.path.expanduser("~/1Clover-tools/lang")
DEFAULT_LANG = "es"


def load_lang():
    env = os.environ.get("CLOVER_LANG")
    if env in ("es", "en"):
        return env
    try:
        with open(LANG_FILE) as f:
            val = f.read().strip()
        if val in ("es", "en"):
            return val
    except OSError:
        pass
    return DEFAULT_LANG


def save_lang(lang):
    try:
        os.makedirs(os.path.dirname(LANG_FILE), exist_ok=True)
        with open(LANG_FILE, "w") as f:
            f.write(lang + "\n")
    except OSError:
        pass


STRINGS = {
    "es": {
        "window_title": "Clover Dual Boot",
        "nav_status": "Estado", "nav_boot": "Arranque", "nav_display": "Pantalla",
        "nav_themes": "Temas", "nav_gamemode": "Game Mode", "nav_advanced": "Avanzado",
        "nav_about": "Acerca de",
        "hdr_status": "Estado actual", "hdr_boot": "Arranque", "hdr_display": "Pantalla",
        "hdr_themes": "Tema", "hdr_gamemode": "Game Mode (Decky)", "hdr_advanced": "Avanzado",
        "hdr_about": "Acerca de",
        "btn_apply": "Aplicar",
        "row_os": "SO", "row_installed": "Clover instalado", "row_default_boot": "Arranque por defecto",
        "row_service": "Servicio", "row_resolution": "Resolución", "row_theme": "Tema",
        "row_timeout": "Tiempo de espera (s)", "row_windows_active": "Windows activo",
        "btn_refresh": "Actualizar", "btn_save_report": "Guardar informe de fallo",
        "lbl_default_os": "SO de arranque por defecto", "lbl_quick_actions": "Acciones rápidas",
        "btn_boot_windows": "Arrancar en Windows la próxima vez", "btn_reenable_clover": "Reactivar Clover",
        "lbl_resolution": "Resolución de pantalla", "lbl_timeout": "Tiempo del menú de arranque (s)",
        "lbl_theme": "Tema de Clover",
        "preview_hint": "Elige un tema arriba para previsualizarlo.",
        "themes_note": "Los temas viven en la partición EFI. \"random\" rota en cada arranque.",
        "no_preview": "No hay vista previa para este tema.",
        "lbl_installed_themes": "Temas instalados",
        "btn_remove": "Quitar", "tag_active": "(activo)",
        "btn_install_themes": "Instalar temas",
        "dlg_install_title": "Instalar temas",
        "install_slots": "Instalados: {n}/{max}. Puedes añadir {free} más.",
        "install_pick": "Elige los temas a instalar:",
        "install_loading": "Obteniendo temas disponibles…",
        "install_load_failed": "No se pudo obtener la lista de temas. Revisa tu conexión.",
        "install_full": "Ya tienes el máximo de {max} temas. Quita uno antes de instalar otro.",
        "install_over_limit": "Has elegido demasiados: solo quedan {free} espacios libres.",
        "install_done": "{ok} tema(s) instalado(s).",
        "install_some_failed": "{ok} instalado(s), {fail} fallaron:\n{names}",
        "confirm_remove_theme": "¿Quitar el tema «{name}»?",
        "ok_theme_removed": "Tema eliminado.",
        "lbl_boot_logo": "Logo de arranque", "btn_set": "Establecer", "btn_restore_default": "Restaurar por defecto",
        "gamemode_soon": "Próximamente",
        "gamemode_desc": "Instala el plugin de Decky para controlar Clover desde Game Mode\n"
                         "(SO por defecto, resolución, tema, tiempo de espera, arrancar en Windows).",
        "btn_install_decky": "Instalar / actualizar plugin de Decky",
        "lbl_batocera": "Versión de Batocera",
        "batocera_note": "Solo necesario si arrancas Batocera desde microSD / USB.",
        "danger_zone": "Zona peligrosa",
        "danger_desc": "Eliminar Clover y restaurar el cargador de Windows.",
        "btn_uninstall": "Desinstalar Clover",
        "opt_lastused": "Última usada", "opt_autodetect": "Detección automática",
        "batocera_v39": "v39 (y posteriores)", "batocera_v38": "v38 (y anteriores)",
        "about_html": "<div style='font-size:13pt;'><b>Clover Dual Boot</b></div>"
                      "<p>Versión {v}</p>"
                      "<p>Mantenido y ampliado por <b>Hooandee</b><br>"
                      "<a style='color:#5fd07a;' href='https://youtube.com/c/hooandee'>youtube.com/c/hooandee</a></p>"
                      "<p style='color:#9aa3ad;'>Basado en los scripts originales SteamDeck-Clover-dualboot "
                      "de ryanrudolf. Cargador Clover por el equipo CloverHackyColor.</p>",
        "dlg_auth_title": "Autenticación", "dlg_auth_prompt": "Introduce tu contraseña de sudo:",
        "msg_sudo_rejected": "Esa contraseña de sudo fue rechazada.",
        "status_unreadable": "No se pudo leer el estado de Clover (¿está instalado?)",
        "ready": "Listo", "cmd_failed": "El comando falló.",
        "ok_default_os": "Arranque por defecto cambiado a {value}.",
        "ok_resolution": "Resolución actualizada.", "ok_theme": "Tema actualizado.",
        "ok_timeout": "Tiempo de espera actualizado.",
        "confirm_boot_windows": "¿Pasar el próximo arranque a Windows y desactivar el servicio de Clover?",
        "ok_boot_windows": "El próximo arranque irá a Windows.",
        "ok_clover_enabled": "Servicio de Clover reactivado.",
        "decky_installed": "Plugin de Decky instalado.",
        "decky_failed": "No se pudo instalar el plugin de Decky.",
        "report_saved": "Informe de fallo guardado en:\n{path}",
        "report_failed": "No se pudo escribir el informe.",
        "ok_logo": "Logo de arranque actualizado.", "ok_logo_reset": "Logo de arranque restaurado por defecto.",
        "ok_batocera": "Configuración de Batocera fijada a {value}.",
        "uninstall_title": "Desinstalar Clover",
        "uninstall_confirm": "Esto elimina Clover y restaura el cargador de Windows. ¿Continuar?",
        "uninstall_done": "Clover desinstalado.", "uninstall_reboot": "\n\nReinicia para volver a Windows.",
        "uninstall_failed": "La desinstalación falló.",
        "tip_es": "Español", "tip_en": "English",
    },
    "en": {
        "window_title": "Clover Dual Boot",
        "nav_status": "Status", "nav_boot": "Boot", "nav_display": "Display",
        "nav_themes": "Themes", "nav_gamemode": "Game Mode", "nav_advanced": "Advanced",
        "nav_about": "About",
        "hdr_status": "Current state", "hdr_boot": "Boot", "hdr_display": "Display",
        "hdr_themes": "Theme", "hdr_gamemode": "Game Mode (Decky)", "hdr_advanced": "Advanced",
        "hdr_about": "About",
        "btn_apply": "Apply",
        "row_os": "OS", "row_installed": "Clover installed", "row_default_boot": "Default boot",
        "row_service": "Service", "row_resolution": "Resolution", "row_theme": "Theme",
        "row_timeout": "Timeout (s)", "row_windows_active": "Windows active",
        "btn_refresh": "Refresh", "btn_save_report": "Save bug report",
        "lbl_default_os": "Default boot OS", "lbl_quick_actions": "Quick actions",
        "btn_boot_windows": "Boot to Windows next", "btn_reenable_clover": "Re-enable Clover",
        "lbl_resolution": "Screen resolution", "lbl_timeout": "Boot menu timeout (s)",
        "lbl_theme": "Clover theme",
        "preview_hint": "Pick a theme above to preview it.",
        "themes_note": "Themes live on the EFI partition. \"random\" rotates on each boot.",
        "no_preview": "No preview available for this theme.",
        "lbl_installed_themes": "Installed themes",
        "btn_remove": "Remove", "tag_active": "(active)",
        "btn_install_themes": "Install themes",
        "dlg_install_title": "Install themes",
        "install_slots": "Installed: {n}/{max}. You can add {free} more.",
        "install_pick": "Pick the themes to install:",
        "install_loading": "Fetching available themes…",
        "install_load_failed": "Could not fetch the theme list. Check your connection.",
        "install_full": "You already have the maximum of {max} themes. Remove one before installing another.",
        "install_over_limit": "Too many selected: only {free} free slots left.",
        "install_done": "{ok} theme(s) installed.",
        "install_some_failed": "{ok} installed, {fail} failed:\n{names}",
        "confirm_remove_theme": "Remove the theme “{name}”?",
        "ok_theme_removed": "Theme removed.",
        "lbl_boot_logo": "Boot logo", "btn_set": "Set", "btn_restore_default": "Restore default",
        "gamemode_soon": "Coming soon",
        "gamemode_desc": "Install the Decky plugin to control Clover from Game Mode\n"
                         "(default OS, resolution, theme, timeout, boot-to-Windows).",
        "btn_install_decky": "Install / update Decky plugin",
        "lbl_batocera": "Batocera version",
        "batocera_note": "Only needed if you boot Batocera from a microSD / USB.",
        "danger_zone": "Danger zone",
        "danger_desc": "Remove Clover and restore the Windows bootloader.",
        "btn_uninstall": "Uninstall Clover",
        "opt_lastused": "Last used", "opt_autodetect": "Auto-detect",
        "batocera_v39": "v39 (and newer)", "batocera_v38": "v38 (and older)",
        "about_html": "<div style='font-size:13pt;'><b>Clover Dual Boot</b></div>"
                      "<p>Version {v}</p>"
                      "<p>Maintained and extended by <b>Hooandee</b><br>"
                      "<a style='color:#5fd07a;' href='https://youtube.com/c/hooandee'>youtube.com/c/hooandee</a></p>"
                      "<p style='color:#9aa3ad;'>Built on the original SteamDeck-Clover-dualboot "
                      "scripts by ryanrudolf. Clover bootloader by the CloverHackyColor team.</p>",
        "dlg_auth_title": "Authentication", "dlg_auth_prompt": "Enter your sudo password:",
        "msg_sudo_rejected": "That sudo password was rejected.",
        "status_unreadable": "Could not read Clover status (is it installed?)",
        "ready": "Ready", "cmd_failed": "Command failed.",
        "ok_default_os": "Default boot set to {value}.",
        "ok_resolution": "Resolution updated.", "ok_theme": "Theme updated.",
        "ok_timeout": "Timeout updated.",
        "confirm_boot_windows": "Hand the next boot to Windows and disable the Clover service?",
        "ok_boot_windows": "Next boot will go to Windows.",
        "ok_clover_enabled": "Clover service re-enabled.",
        "decky_installed": "Decky plugin installed.",
        "decky_failed": "Could not install the Decky plugin.",
        "report_saved": "Bug report saved to:\n{path}",
        "report_failed": "Could not write the report.",
        "ok_logo": "Boot logo updated.", "ok_logo_reset": "Boot logo restored to default.",
        "ok_batocera": "Batocera config set to {value}.",
        "uninstall_title": "Uninstall Clover",
        "uninstall_confirm": "This removes Clover and restores the Windows bootloader. Continue?",
        "uninstall_done": "Clover uninstalled.", "uninstall_reboot": "\n\nReboot to return to Windows.",
        "uninstall_failed": "Uninstall failed.",
        "tip_es": "Español", "tip_en": "English",
    },
}


def make_tr(lang):
    table = STRINGS.get(lang, STRINGS["en"])
    fallback = STRINGS["en"]

    def tr(key, **kw):
        s = table.get(key, fallback.get(key, key))
        return s.format(**kw) if kw else s

    return tr


QSS = """
QListWidget#sidebar { background: #20242b; border: none; outline: 0; padding-top: 8px; }
QListWidget#sidebar::item { padding: 10px 14px; margin: 3px 8px; border-radius: 8px; color: #c9d1da; }
QListWidget#sidebar::item:hover { background: #2a2f38; }
QListWidget#sidebar::item:selected { background: #2f9e50; color: white; }
QPushButton { background: #2f9e50; color: white; border: none; border-radius: 7px; padding: 7px 16px; font-weight: 600; }
QPushButton:hover { background: #38b85e; }
QPushButton:pressed { background: #278544; }
QPushButton:disabled { background: #3a4049; color: #8b929c; }
QPushButton#danger { background: #c0392b; }
QPushButton#danger:hover { background: #d8453a; }
QPushButton#flag, QPushButton#flagoff { background: transparent; border: 2px solid transparent; border-radius: 5px; padding: 1px; }
QPushButton#flag { border-color: #2f9e50; }
QPushButton#flag:hover, QPushButton#flagoff:hover { border-color: #3a4049; }
QFrame#card, QLabel#card { background: #20242b; border: 1px solid #2d333d; border-radius: 10px; }
QLabel#card { padding: 8px; color: #aeb6c0; }
QLabel#badge { background: #3a4049; color: #e0a83e; border-radius: 6px; padding: 3px 10px; font-weight: 700; }
"""


class Engine:
    """Runs clover-ctl, elevating with a once-asked sudo password."""

    def __init__(self):
        self.password = None

    def ensure_auth(self, parent):
        if self.password is not None:
            return True
        pw, ok = QInputDialog.getText(parent, parent.t("dlg_auth_title"),
                                      parent.t("dlg_auth_prompt"),
                                      QLineEdit.EchoMode.Password)
        if not ok:
            return False
        check = subprocess.run(["sudo", "-S", "-v"], input=pw + "\n",
                               text=True, capture_output=True)
        if check.returncode != 0:
            QMessageBox.critical(parent, "Clover", parent.t("msg_sudo_rejected"))
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

    def remote_themes(self, parent):
        rc, out, _ = self.run(["list-remote-themes"], parent, root=False)
        return out.splitlines() if rc == 0 and out else []

    def install_theme(self, name, parent):
        return self.run(["install-theme", name], parent)

    def theme_preview(self, name, parent):
        rc, out, _ = self.run(["theme-preview", name], parent)
        return out if rc == 0 else ""


class CloverWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.engine = Engine()
        self._theme_limit = THEME_LIMIT
        self._installed_themes = []
        self.lang = load_lang()
        self.t = make_tr(self.lang)
        self.setWindowIcon(QIcon(ICON))
        self.setStyleSheet(QSS)
        self.resize(680, 480)
        self._build()

    def _set_lang(self, lang):
        if lang == self.lang:
            return
        self.lang = lang
        save_lang(lang)
        self.t = make_tr(lang)
        self._build()

    def _build(self):
        self.setWindowTitle(self.t("window_title"))
        self.default_os = [("Windows", "windows"), ("SteamOS", "steamos"),
                           ("Bazzite", "bazzite"), (self.t("opt_lastused"), "lastos")]
        self.res_presets = [self.t("opt_autodetect"), "1280x800", "1920x1080",
                            "1920x1200", "2560x1600"]

        central = QWidget()
        self.setCentralWidget(central)
        outer = QVBoxLayout(central)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        header = QHBoxLayout()
        header.setContentsMargins(10, 8, 12, 0)
        header.addStretch(1)
        header.addWidget(self._flag_button("es"))
        header.addWidget(self._flag_button("en"))
        outer.addLayout(header)

        body = QHBoxLayout()
        body.setContentsMargins(0, 0, 0, 0)
        body.setSpacing(0)

        self.sidebar = QListWidget()
        self.sidebar.setObjectName("sidebar")
        self.sidebar.setIconSize(QSize(22, 22))
        self.sidebar.setFixedWidth(170)
        self.sidebar.setFrameShape(QFrame.Shape.NoFrame)
        self.stack = QStackedWidget()

        pages = [
            ("nav_status", "dialog-information", QStyle.StandardPixmap.SP_MessageBoxInformation, self._status_page),
            ("nav_boot", "drive-harddisk", QStyle.StandardPixmap.SP_DriveHDIcon, self._boot_page),
            ("nav_display", "video-display", QStyle.StandardPixmap.SP_DesktopIcon, self._display_page),
            ("nav_themes", "preferences-desktop-theme", QStyle.StandardPixmap.SP_FileDialogContentsView, self._themes_page),
            ("nav_gamemode", "input-gaming", QStyle.StandardPixmap.SP_ComputerIcon, self._gamemode_page),
            ("nav_advanced", "applications-system", QStyle.StandardPixmap.SP_FileDialogDetailedView, self._advanced_page),
            ("nav_about", "help-about", QStyle.StandardPixmap.SP_DialogHelpButton, self._about_page),
        ]
        for title_key, icon_name, fallback, builder in pages:
            self.sidebar.addItem(QListWidgetItem(self._icon(icon_name, fallback), self.t(title_key)))
            self.stack.addWidget(builder())

        self.sidebar.currentRowChanged.connect(self.stack.setCurrentIndex)
        body.addWidget(self.sidebar)
        body.addWidget(self.stack, 1)
        outer.addLayout(body, 1)

        self.sidebar.setCurrentRow(0)
        self.refresh()

    def _flag_button(self, lang):
        btn = QPushButton()
        btn.setObjectName("flag" if lang == self.lang else "flagoff")
        icon = QIcon(os.path.join(FLAG_DIR, "es.svg" if lang == "es" else "us.svg"))
        if icon.isNull():
            btn.setText("ES" if lang == "es" else "EN")
        else:
            btn.setIcon(icon)
            btn.setIconSize(QSize(26, 18))
        btn.setFixedSize(40, 28)
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        btn.setToolTip(self.t("tip_es") if lang == "es" else self.t("tip_en"))
        btn.clicked.connect(lambda: self._set_lang(lang))
        return btn

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
        btn = QPushButton(self.t("btn_apply"))
        btn.clicked.connect(handler)
        h.addWidget(btn)
        return wrap

    def _status_page(self):
        page, v = self._page(self.t("hdr_status"))
        grid = QGridLayout()
        self.status_fields = {}
        rows = [("row_os", "os"), ("row_installed", "installed"),
                ("row_default_boot", "default_os"), ("row_service", "service"),
                ("row_resolution", "resolution"), ("row_theme", "theme"),
                ("row_timeout", "timeout"), ("row_windows_active", "windows_active")]
        for i, (label_key, key) in enumerate(rows):
            grid.addWidget(QLabel(f"<b>{self.t(label_key)}</b>"), i, 0)
            val = QLabel("…")
            self.status_fields[key] = val
            grid.addWidget(val, i, 1)
        grid.setColumnStretch(1, 1)
        card = QFrame()
        card.setObjectName("card")
        card_layout = QVBoxLayout(card)
        card_layout.addLayout(grid)
        v.addWidget(card)
        v.addStretch(1)
        row = QHBoxLayout()
        refresh = QPushButton(self._icon("view-refresh", QStyle.StandardPixmap.SP_BrowserReload), self.t("btn_refresh"))
        refresh.clicked.connect(self.refresh)
        report = QPushButton(self._icon("document-save", QStyle.StandardPixmap.SP_DialogSaveButton), self.t("btn_save_report"))
        report.clicked.connect(self.save_report)
        row.addWidget(refresh)
        row.addWidget(report)
        row.addStretch(1)
        v.addLayout(row)
        return page

    def _boot_page(self):
        page, v = self._page(self.t("hdr_boot"))
        form = QFormLayout()
        self.default_combo = QComboBox()
        for label, _ in self.default_os:
            self.default_combo.addItem(label)
        form.addRow(self.t("lbl_default_os"), self._apply_row(self.default_combo, self.apply_default_os))
        v.addLayout(form)
        v.addSpacing(12)
        v.addWidget(QLabel(f"<b>{self.t('lbl_quick_actions')}</b>"))
        row = QHBoxLayout()
        win = QPushButton(self.t("btn_boot_windows"))
        win.clicked.connect(self.boot_windows)
        clv = QPushButton(self.t("btn_reenable_clover"))
        clv.clicked.connect(self.enable_clover)
        row.addWidget(win)
        row.addWidget(clv)
        v.addLayout(row)
        v.addStretch(1)
        return page

    def _display_page(self):
        page, v = self._page(self.t("hdr_display"))
        form = QFormLayout()
        self.res_combo = QComboBox()
        self.res_combo.setEditable(True)
        self.res_combo.addItems(self.res_presets)
        form.addRow(self.t("lbl_resolution"), self._apply_row(self.res_combo, self.apply_resolution))
        self.timeout_combo = QComboBox()
        self.timeout_combo.addItems(TIMEOUTS)
        form.addRow(self.t("lbl_timeout"), self._apply_row(self.timeout_combo, self.apply_timeout))
        v.addLayout(form)
        v.addStretch(1)
        return page

    def _themes_page(self):
        page, v = self._page(self.t("hdr_themes"))
        form = QFormLayout()
        self.theme_combo = QComboBox()
        self.theme_combo.textActivated.connect(self._update_theme_preview)
        form.addRow(self.t("lbl_theme"), self._apply_row(self.theme_combo, self.apply_theme))
        v.addLayout(form)
        self.theme_preview = QLabel(self.t("preview_hint"))
        self.theme_preview.setObjectName("card")
        self.theme_preview.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.theme_preview.setMinimumHeight(180)
        v.addWidget(self.theme_preview)
        self.icon_row = QHBoxLayout()
        self.icon_row.setSpacing(6)
        icon_wrap = QWidget()
        icon_wrap.setLayout(self.icon_row)
        v.addWidget(icon_wrap)
        v.addWidget(QLabel(self.t("themes_note")))
        v.addSpacing(12)
        v.addWidget(QLabel(f"<b>{self.t('lbl_installed_themes')}</b>"))
        self.installed_box = QVBoxLayout()
        self.installed_box.setSpacing(4)
        installed_wrap = QWidget()
        installed_wrap.setLayout(self.installed_box)
        v.addWidget(installed_wrap)
        install_btn = QPushButton(self._icon("list-add", QStyle.StandardPixmap.SP_FileDialogNewFolder),
                                  self.t("btn_install_themes"))
        install_btn.clicked.connect(self.install_themes_dialog)
        v.addWidget(install_btn)
        v.addSpacing(14)
        v.addWidget(QLabel(f"<b>{self.t('lbl_boot_logo')}</b>"))
        logo_row = QWidget()
        lh = QHBoxLayout(logo_row)
        lh.setContentsMargins(0, 0, 0, 0)
        self.logo_combo = QComboBox()
        lh.addWidget(self.logo_combo, 1)
        set_logo = QPushButton(self.t("btn_set"))
        set_logo.clicked.connect(self.apply_logo)
        reset_logo = QPushButton(self.t("btn_restore_default"))
        reset_logo.clicked.connect(self.reset_logo)
        lh.addWidget(set_logo)
        lh.addWidget(reset_logo)
        v.addWidget(logo_row)
        v.addStretch(1)
        return page

    def _gamemode_page(self):
        page, v = self._page(self.t("hdr_gamemode"))
        badge = QLabel(self.t("gamemode_soon"))
        badge.setObjectName("badge")
        v.addWidget(badge)
        v.addWidget(QLabel(self.t("gamemode_desc")))
        btn = QPushButton(self._icon("input-gaming", QStyle.StandardPixmap.SP_ComputerIcon),
                          self.t("btn_install_decky"))
        btn.clicked.connect(self.install_decky)
        btn.setEnabled(False)
        v.addWidget(btn)
        v.addStretch(1)
        return page

    def _advanced_page(self):
        page, v = self._page(self.t("hdr_advanced"))
        form = QFormLayout()
        self.batocera_combo = QComboBox()
        self.batocera_combo.addItems([self.t("batocera_v39"), self.t("batocera_v38")])
        form.addRow(self.t("lbl_batocera"), self._apply_row(self.batocera_combo, self.apply_batocera))
        v.addLayout(form)
        v.addWidget(QLabel(self.t("batocera_note")))
        v.addSpacing(16)
        v.addWidget(QLabel(f"<b>{self.t('danger_zone')}</b>"))
        v.addWidget(QLabel(self.t("danger_desc")))
        uninstall = QPushButton(self._icon("edit-delete", QStyle.StandardPixmap.SP_TrashIcon), self.t("btn_uninstall"))
        uninstall.setObjectName("danger")
        uninstall.clicked.connect(self.uninstall)
        v.addWidget(uninstall)
        v.addStretch(1)
        return page

    def _about_page(self):
        page, v = self._page(self.t("hdr_about"))
        about = QLabel(self.t("about_html", v=VERSION))
        about.setTextFormat(Qt.TextFormat.RichText)
        about.setOpenExternalLinks(True)
        about.setWordWrap(True)
        v.addWidget(about)
        v.addStretch(1)
        return page

    def refresh(self):
        st = self.engine.status(self)
        if not st:
            self.statusBar().showMessage(self.t("status_unreadable"))
            return
        self._theme_limit = st.get("theme_limit", THEME_LIMIT)
        for key, lbl in self.status_fields.items():
            lbl.setText(str(st.get(key, "—")))
        self._tint(self.status_fields.get("service"), st.get("service") == "enabled")
        self._tint(self.status_fields.get("windows_active"), str(st.get("windows_active")).lower() != "true")
        self._select(self.res_combo, st.get("resolution"))
        self._select(self.timeout_combo, st.get("timeout"))
        for i, (_, value) in enumerate(self.default_os):
            if value == st.get("default_os"):
                self.default_combo.setCurrentIndex(i)
        themes = self.engine.themes(self)
        self._installed_themes = themes
        current = [self.theme_combo.itemText(i) for i in range(self.theme_combo.count())]
        if themes and themes != current:
            self.theme_combo.blockSignals(True)
            self.theme_combo.clear()
            self.theme_combo.addItems(themes)
            self.theme_combo.blockSignals(False)
        self._select(self.theme_combo, st.get("theme"))
        self._populate_installed_themes(themes, st.get("theme"))
        if self.logo_combo.count() == 0:
            logos = self.engine.logos(self)
            if logos:
                self.logo_combo.addItems(logos)
        self.statusBar().showMessage(self.t("ready"))

    def _tint(self, label, good):
        if label is not None:
            label.setStyleSheet("color: #3fbf6a;" if good else "color: #e0a83e;")

    def _load_pixmap(self, path):
        pixmap = QPixmap(path)
        if not pixmap.isNull():
            return pixmap
        # fallback for formats Qt's plugins miss (e.g. some .icns) via Pillow
        try:
            import tempfile
            from PIL import Image
            fd, tmp = tempfile.mkstemp(suffix=".png")
            os.close(fd)
            Image.open(path).convert("RGBA").save(tmp)
            pixmap = QPixmap(tmp)
            os.remove(tmp)
            return pixmap
        except Exception:
            return QPixmap()

    def _update_theme_preview(self, name):
        if not name:
            return
        bg = None
        icons = []
        for line in self.engine.theme_preview(name, self).splitlines():
            if "\t" not in line:
                continue
            kind, path = line.split("\t", 1)
            if kind == "background":
                bg = path
            elif kind == "icon":
                icons.append(path)
        bgmap = self._load_pixmap(bg) if bg else QPixmap()
        if not bgmap.isNull():
            self.theme_preview.setPixmap(bgmap.scaledToWidth(380, Qt.TransformationMode.SmoothTransformation))
        else:
            self.theme_preview.setText(self.t("no_preview"))
        self._set_theme_icons(icons)

    def _set_theme_icons(self, icons):
        self._clear_layout(self.icon_row)
        for path in icons[:10]:
            pixmap = self._load_pixmap(path)
            if pixmap.isNull():
                continue
            label = QLabel()
            label.setPixmap(pixmap.scaled(40, 40, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation))
            self.icon_row.addWidget(label)
        self.icon_row.addStretch(1)

    def _clear_layout(self, layout):
        while layout.count():
            w = layout.takeAt(0).widget()
            if w is not None:
                w.deleteLater()

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
            QMessageBox.warning(self, "Clover", err or out or self.t("cmd_failed"))

    def apply_default_os(self):
        value = self.default_os[self.default_combo.currentIndex()][1]
        self._apply(["set-default-os", value], self.t("ok_default_os", value=value))

    def apply_resolution(self):
        text = self.res_combo.currentText().strip()
        value = "auto" if text == self.t("opt_autodetect") else text
        self._apply(["set-resolution", value], self.t("ok_resolution"))

    def apply_theme(self):
        if self.theme_combo.currentText():
            self._apply(["set-theme", self.theme_combo.currentText()], self.t("ok_theme"))

    def _populate_installed_themes(self, themes, active):
        self._clear_layout(self.installed_box)
        for name in themes:
            row = QWidget()
            h = QHBoxLayout(row)
            h.setContentsMargins(0, 0, 0, 0)
            is_active = name == active
            label = QLabel(f"{name}  {self.t('tag_active')}" if is_active else name)
            h.addWidget(label, 1)
            btn = QPushButton(self.t("btn_remove"))
            btn.setEnabled(not is_active)
            btn.clicked.connect(lambda _=False, n=name: self.remove_theme(n))
            h.addWidget(btn)
            self.installed_box.addWidget(row)

    def remove_theme(self, name):
        if QMessageBox.question(self, "Clover", self.t("confirm_remove_theme", name=name)) \
                != QMessageBox.StandardButton.Yes:
            return
        self._apply(["remove-theme", name], self.t("ok_theme_removed"))

    def install_themes_dialog(self):
        limit = self._theme_limit
        installed = self._installed_themes
        free = limit - len(installed)
        if free <= 0:
            QMessageBox.information(self, "Clover", self.t("install_full", max=limit))
            return
        self.statusBar().showMessage(self.t("install_loading"))
        installed_set = set(installed)
        remote = [t for t in self.engine.remote_themes(self) if t not in installed_set]
        self.statusBar().clearMessage()
        if not remote:
            QMessageBox.warning(self, "Clover", self.t("install_load_failed"))
            return

        dlg = QDialog(self)
        dlg.setWindowTitle(self.t("dlg_install_title"))
        dlg.resize(360, 460)
        lay = QVBoxLayout(dlg)
        lay.addWidget(QLabel(self.t("install_slots", n=len(installed), max=limit, free=free)))
        lay.addWidget(QLabel(self.t("install_pick")))
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        inner = QWidget()
        iv = QVBoxLayout(inner)
        boxes = [QCheckBox(name) for name in remote]
        for cb in boxes:
            iv.addWidget(cb)
        iv.addStretch(1)
        scroll.setWidget(inner)
        lay.addWidget(scroll, 1)
        warn = QLabel("")
        warn.setStyleSheet("color: #e0a83e;")
        lay.addWidget(warn)
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        ok_btn = buttons.button(QDialogButtonBox.StandardButton.Ok)
        lay.addWidget(buttons)

        def update():
            selected = sum(cb.isChecked() for cb in boxes)
            ok_btn.setEnabled(0 < selected <= free)
            warn.setText(self.t("install_over_limit", free=free) if selected > free else "")

        for cb in boxes:
            cb.toggled.connect(update)
        update()
        buttons.accepted.connect(dlg.accept)
        buttons.rejected.connect(dlg.reject)
        run_modal = dlg.exec
        if run_modal() != QDialog.DialogCode.Accepted:
            return

        selected = [cb.text() for cb in boxes if cb.isChecked()]
        ok, fails = 0, []
        for name in selected:
            rc, out, err = self.engine.install_theme(name, self)
            if rc == 0:
                ok += 1
            elif err == "cancelled":
                break
            else:
                fails.append(f"{name}: {err or out}")
        self.refresh()
        if fails:
            QMessageBox.warning(self, "Clover", self.t("install_some_failed",
                                ok=ok, fail=len(fails), names="\n".join(fails)))
        elif ok:
            self.statusBar().showMessage("✓ " + self.t("install_done", ok=ok))

    def apply_timeout(self):
        self._apply(["set-timeout", self.timeout_combo.currentText()], self.t("ok_timeout"))

    def boot_windows(self):
        if QMessageBox.question(self, "Clover", self.t("confirm_boot_windows")) \
                == QMessageBox.StandardButton.Yes:
            self._apply(["service", "disable"], self.t("ok_boot_windows"))

    def enable_clover(self):
        self._apply(["service", "enable"], self.t("ok_clover_enabled"))

    def install_decky(self):
        rc, out, err = self.engine.run(["install-decky"], self)
        if rc == 0:
            QMessageBox.information(self, "Clover", out or self.t("decky_installed"))
        elif err != "cancelled":
            QMessageBox.warning(self, "Clover", err or out or self.t("decky_failed"))

    def save_report(self):
        rc, out, err = self.engine.run(["diagnostics"], self)
        if rc == 0:
            QMessageBox.information(self, "Clover", self.t("report_saved", path=out))
        elif err != "cancelled":
            QMessageBox.warning(self, "Clover", err or out or self.t("report_failed"))

    def apply_logo(self):
        if self.logo_combo.currentText():
            self._apply(["set-logo", self.logo_combo.currentText()], self.t("ok_logo"))

    def reset_logo(self):
        self._apply(["reset-logo"], self.t("ok_logo_reset"))

    def apply_batocera(self):
        value = "v39" if self.batocera_combo.currentIndex() == 0 else "v38"
        self._apply(["set-batocera", value], self.t("ok_batocera", value=value))

    def uninstall(self):
        if QMessageBox.warning(
                self, self.t("uninstall_title"), self.t("uninstall_confirm"),
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                QMessageBox.StandardButton.No) != QMessageBox.StandardButton.Yes:
            return
        rc, out, err = self.engine.run(["uninstall"], self)
        if rc == 0:
            QMessageBox.information(self, "Clover",
                                    (out or self.t("uninstall_done")) + self.t("uninstall_reboot"))
            self.close()
        elif err != "cancelled":
            QMessageBox.warning(self, "Clover", err or out or self.t("uninstall_failed"))


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Clover Dual Boot")
    app.setWindowIcon(QIcon(ICON))
    win = CloverWindow()
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
