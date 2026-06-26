# Clover Dual Boot for Handheld PCs, SteamOS / Bazzite + Windows

> 🇪🇸 ¿Prefieres español? La guía en español está aquí: [README.md](README.md)

> 🚧 **Heads up:** a big update to the project is on the way. Some things will change soon, so bear with me if something doesn't quite line up yet.

Install [Clover](https://github.com/CloverHackyColor/CloverBootloader), a graphical boot manager, to dual boot SteamOS (or Bazzite) and Windows (and other OSes too) on the Steam Deck and other x86 handhelds. The installer detects your device, makes as few changes to your system as possible, and adds a boot menu that repairs itself when a BIOS, OS or Windows update breaks the boot entries.

This project is based on the original work by ryanrudolf, [SteamDeck-Clover-dualboot](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot). Here I have extended it to support more handhelds and to make installation simpler.

## What's included
* **Clover**, the graphical boot manager that does the heavy lifting.
* **Clover Toolbox**, a simple GUI to configure Clover (themes, resolution, uninstall and more).
* **Boot-manager service** that checks the dual boot on every startup and auto-repairs broken boot entries.
* **XBOX 360 controller UEFI driver** by [SkorionOS](https://github.com/SkorionOS/UsbXbox360Dxe) and [chenx-dust](https://github.com/chenx-dust/UsbXbox360Dxe), so the built-in gamepad of non-Steam-Deck handhelds works inside the Clover menu.
* **Eclipse theme** by [chris1111](https://github.com/chris1111/).

## Supported devices

| Handheld | Detected as | Clover resolution |
|---|---|---|
| Steam Deck LCD / OLED | `Jupiter` / `Galileo` | 1280x800 (default) |
| ASUS ROG Ally | `RC71L` | 1920x1080 |
| ASUS ROG Ally X | `RC72LA` | 1920x1080 |
| ASUS ROG Xbox Ally | `RC73YA` | 1920x1080 |
| ASUS ROG Xbox Ally X | `RC73XA` | 1920x1080 |
| Lenovo Legion Go | `83E1` | 2560x1600 |
| Lenovo Legion Go 2 | `83N0` / `83N1` | 1920x1200 |
| Lenovo Legion Go S | `83L3` / `83Q2` / `83Q3` | 1920x1200 |
| OneXPlayer 2 Pro | `ONEXPLAYER 2 PRO ARP23P` | 2560x1600 |

Got **another handheld**? It works in generic mode: the installer reads your panel's native resolution from the kernel and asks you to continue, so most x86 handhelds install without touching any code.

> ⚠️ **Not supported:** the Lenovo Legion Go S `83N6` is blocked because the XBOX 360 controller UEFI driver is not compatible with it.

### Using the controller inside the Clover menu
On every handheld except the Steam Deck, the installer adds the XBOX 360 controller UEFI driver so the built-in gamepad works in the boot menu:
* **D-pad**: move (arrow keys)
* **A** = Enter, **B** = Esc
* **Right trigger** = left click, **left trigger** = right click
* If the D-pad doesn't respond, use the left thumbstick to move the mouse pointer.

If Clover hangs on a Legion Go (the driver sometimes keeps polling the controller), delete the driver and reboot:
```bash
sudo rm /esp/efi/clover/drivers/uefi/UsbXbox360Dxe.efi
```

## Disclaimer
Do this at your own risk. Provided for educational and research purposes only, with no warranty.

## Installation

### Requirements, read these first
* **Install SteamOS / Bazzite _before_ Windows.** The installer will not run if Windows owns the EFI system partition.
* **Disable Secure Boot** in the BIOS/UEFI. It is required on non-Steam-Deck handhelds (ROG Ally, Legion Go, etc.).
* **Set a sudo password** in SteamOS / Bazzite. The installer needs it and stops if it is blank.

### 1. Prepare Windows
Boot into Windows, open an elevated Command Prompt or PowerShell, and run:
```cmd
bcdedit.exe -set "{globalsettings}" highestmode on
reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f
```

### 2. Install on SteamOS / Bazzite
Go into Desktop Mode, open a terminal (Konsole), and paste this single line:

```bash
cd ~ && rm -rf Handheld-Clover-dualboot && git clone https://github.com/Hooandee/Handheld-Clover-dualboot && cd Handheld-Clover-dualboot && chmod +x install-clover.sh && ./install-clover.sh
```

It removes any old copy, clones the repo, and runs the installer. The script checks your sudo password and runs sanity checks along the way. When it finishes, **reboot** and you'll get the Clover menu to pick your OS (D-pad and **A** to confirm).

<details>
<summary><b>Optional: Windows on microSD or external SSD</b></summary>

If Windows lives on a microSD or external SSD, after installing run:
```bash
sudo cp custom/config_sdcard.plist /esp/efi/clover/config.plist
```

If Windows still keeps hijacking the boot, set up the scheduled task on the Windows side: run `CloverWindows/CloverWindows.bat` as Administrator. It creates `C:\1Clover-tools`, installs a scheduled task called `CloverTask-donotdelete`, then in Task Scheduler open the task properties, tick **Run whether user is logged on or not** and **Do not store password**, and run it once.
</details>

### Updating to a newer version
Open Clover Toolbox, hit **Uninstall**, clone the repo again, and repeat the install.

## Known issues
**External display above 1080p (1440p, 4K).** Clover's screen may come out rotated, and Windows may fail to boot or show a blue screen. If you can, use a 1080p-or-lower display. Workaround: Clover Toolbox, **Resolution**, **DeckSight** option (note: this rotates Clover's screen on the Deck's built-in panel when no external display is connected).

## FAQ / Troubleshooting (original guide, work in progress)
> These answers come from the original [SteamDeck-Clover-dualboot](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot) project and I'm still reviewing and adapting them to this fork. Some steps are Steam Deck specific and may not match other handhelds yet. Work in progress.

<details>
<summary><b>Windows on microSD or external SSD isn't detected</b></summary>
Make sure you set it up as GPT and Windows-To-Go in Rufus.
</details>

<details>
<summary><b>Windows boots with vertical lines or garbled graphics</b></summary>
In Windows (admin Command Prompt): <code>bcdedit.exe -set {globalsettings} highestmode on</code>. If it's still garbled, boot straight to Windows once (Clover Toolbox, Service, Disable), fix the display, then re-enable the service.
</details>

<details>
<summary><b>Windows boots directly instead of Clover (after a reinstall or Windows update)</b></summary>
Shut down. With the device powered off, press <b>VOL DOWN + POWER</b> and pick SteamOS. The boot-manager service repairs the entries on its own. Reboot and Clover is back.
</details>

<details>
<summary><b>A SteamOS update wiped my boot entries</b></summary>
Shut down. With the device powered off, press <b>VOL UP + POWER</b> and go to <b>Boot from File &gt; efi &gt; steamos &gt; steamcl.efi</b>. The service repairs the entries on the next boot.
</details>

<details>
<summary><b>The clock keeps drifting out of sync</b></summary>
In Windows (admin Command Prompt): <code>reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f</code> and reboot.
</details>

<details>
<summary><b>I see 'Error mounting ISO!' when running the script</b></summary>
Your SteamOS may be missing 7zip (common on recovery-image installs). Run a System Update (Steam, Settings, System, Check for Updates), reboot, and run the script again.
</details>

<details>
<summary><b>I want to uninstall Clover</b></summary>
Clover Toolbox, <b>Uninstall</b>. On the next reboot it goes straight to Windows. Done.
</details>

## Credits
Based on the original [SteamDeck-Clover-dualboot](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot) project.

And a huge thank you to the community of my channel, [youtube.com/c/hooandee](https://youtube.com/c/hooandee), for the constant support. 💚
