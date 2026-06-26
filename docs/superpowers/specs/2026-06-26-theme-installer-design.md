# Theme installer + Decky "coming soon" — design

Date: 2026-06-26 · Branch: `feature/theme-installer` (off `major-upgrade`)

## Goal

Two changes to the Desktop control panel (`gui/clover_desktop.py`, PySide6) and the
engine (`clover-ctl`):

1. Mark the **Game Mode (Decky)** section as "coming soon" and disable its install
   button until the Decky feature is merged.
2. Let the user **install Clover themes from the
   [CloverThemes](https://github.com/CloverHackyColor/CloverThemes) repo** directly from
   the Themes page — pick one or more, download and install them — and **manage/remove**
   installed themes. The ESP is tiny, so a hard cap of **5 themes total** applies; at the
   cap the user must remove a theme before installing another.

Out of scope: the Decky (React) frontend — it stays disabled. React best-practices do not
apply; this is Python/PySide6 + bash.

## Architecture

Logic lives in `clover-ctl` (the engine); the GUI shells out to it and renders the result —
the repo's standing rule. Network/JSON work is done with `python3` invoked inline from bash,
matching the existing `install-decky` precedent (the engine stays self-contained and
language-agnostic to frontends).

```
GUI (PySide6) ──sudo──> clover-ctl install-theme <name> ──curl/python3──> GitHub (CloverThemes)
                                    │
                                    └─> /tmp (selective download) ─free-space check─> ESP/clover/themes/<name>
```

## Engine: new `clover-ctl` subcommands

A constant `THEME_LIMIT=5`. The cap counts **all** theme folders in `clover/themes`
(including the factory-bundled Apocalypse/Catalina/Eclipse/Mojave).

- **`list-remote-themes`** (no root): GET the CloverThemes contents API, print theme folder
  names (one per line), skipping dotfolders. Read-only, no EFI needed.
- **`install-theme <name>`** (root + efi):
  - Sanitize: reject names containing `/` or `..`.
  - Refuse if already installed.
  - Enforce the cap: count dirs in `clover/themes`; if `>= THEME_LIMIT`, `die` with a clear
    message telling the user to remove a theme first.
  - Resolve the default branch, walk the git tree filtered to `<name>/`, download each file
    via `raw.githubusercontent.com` into a temp dir.
  - **Free-space check**: refuse (and clean up) if the downloaded theme would not fit in the
    ESP's free space.
  - Move the temp dir into `clover/themes/<name>`. Clean the temp dir on any failure.
- **`remove-theme <name>`** (root + efi): sanitize; **refuse to remove the currently-active
  theme**; remove `clover/themes/<name>`.

Help text is updated. A gated `CLOVER_EFI_PATH` env override is added (mirrors the existing
`CLOVER_CONFIG`) so the cap/remove logic is testable offline.

## GUI: Themes page

Same page, no separate dialog for management:

- The active-theme combo stays as-is.
- A **"Installed themes"** list with a **Remove** button per theme (disabled for the active
  theme).
- An **"Install themes"** button opens a `QDialog`: the remote theme list as checkboxes, a
  header showing **"X/5 installed"** and remaining slots, and a confirm that is blocked when
  the selection would exceed free slots (with a message to remove a theme first).
- `Engine` gains `remote_themes()`, `install_theme(name)`, `remove_theme(name)`.
- All new strings added to both the `es` and `en` catalogs.

## Game Mode page

- Add a "Coming soon" label/badge to the description.
- `btn.setEnabled(False)` on the install button.
- New i18n string `gamemode_soon` (es/en).

## Tests (`test/test-clover-ctl.sh`)

Offline-testable via `CLOVER_EFI_PATH` + `CLOVER_CONFIG`:

- `install-theme` rejects names containing `/`.
- The 5-theme cap is enforced (pre-create 5 dirs, expect refusal).
- `remove-theme` refuses to remove the active theme.

Network paths (`list-remote-themes`, the download in `install-theme`) are not unit-tested
offline.

## Error handling

- Missing network / GitHub error: `die` with a readable message; frontend shows it.
- Theme doesn't fit ESP: refuse, clean temp, clear message.
- All destructive paths sanitize the theme name and never touch the `.orig` backups or
  anything outside `clover/themes/`.
