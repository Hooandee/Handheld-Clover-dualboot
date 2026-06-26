# Clover Dual Boot — Decky plugin

A Game Mode panel for the Clover dual-boot tools. The plugin's Python backend
calls `clover-ctl` as root (Decky runs `root`-flagged backends elevated), so
changing the default OS, resolution, theme, timeout, and "boot to Windows next"
all work without a password prompt.

It expects `clover-ctl` to be present at `~/1Clover-tools/clover-ctl` (where the
main installer places it). The backend also searches `/home/*/1Clover-tools/`
and the plugin's own `bin/` as fallbacks.

## Easiest: one click from the desktop app
Open the **Clover Dual Boot** desktop app and click **Install / update Decky
plugin**. It drops a prebuilt copy (downloaded from the latest release, or a
local build if you made one) into `~/homebrew/plugins/` and reloads Decky - no
Node needed on the handheld.

## Build it yourself (dev machine with Node + pnpm)

```bash
cd decky
pnpm install
pnpm build        # outputs dist/index.js
```

## Install onto the handheld

Decky loads plugins from `~/homebrew/plugins/`. Copy the built plugin there:

```
~/homebrew/plugins/Clover Dual Boot/
    plugin.json
    main.py
    dist/index.js
```

Then restart Decky Loader (or, in Decky's Developer settings, use **Reload**).

Requirements: Decky Loader installed, and Clover already installed via the main
script (so `clover-ctl` and the systemd service exist).

## Notes
- `flags: ["root"]` in `plugin.json` is required so the backend can run
  `clover-ctl` with the privileges it needs.
- This is an early version — expect to iterate after testing on-device.
