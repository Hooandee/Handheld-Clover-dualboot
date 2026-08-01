# Clover Dual Boot for Handheld PCs, SteamOS / Bazzite + Windows

> 🇪🇸 ¿Prefieres español? La guía en español está aquí: [README.md](README.md)

Install [Clover](https://github.com/CloverHackyColor/CloverBootloader), a graphical boot manager, to dual boot SteamOS (or Bazzite) and Windows (and other OSes too) on the Steam Deck and other x86 handhelds. The installer detects your device, makes as few changes to your system as possible, and adds a boot menu that repairs itself when a BIOS, OS or Windows update breaks the boot entries.

This project is based on the original work by ryanrudolf, [SteamDeck-Clover-dualboot](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot). Here I have extended it to support more handhelds and to make installation simpler.

## What's included
* **Clover**, the graphical boot manager that does the heavy lifting.
* **Clover desktop app**, a bilingual graphical control panel for the default OS, resolution, timeout, boot logo, themes, diagnostics and uninstall.
* **Theme installer**, built into the app: downloads from CloverThemes, protects the active theme and checks EFI partition space.
* **Clover Toolbox**, retained as the classic compatibility interface.
* **Boot-manager service** that checks the dual boot on every startup and auto-repairs broken boot entries.
* **XBOX 360 controller UEFI driver** by [SkorionOS](https://github.com/SkorionOS/UsbXbox360Dxe), [chenx-dust](https://github.com/chenx-dust/UsbXbox360Dxe) and [jlobue10](https://github.com/jlobue10/UsbXbox360Dxe), enabled only on models with known compatibility.
* **Eclipse theme** by [chris1111](https://github.com/chris1111/).

## Supported devices

| Handheld | Detected as | Clover resolution |
|---|---|---|
| Steam Deck LCD / OLED | `Jupiter` / `Galileo` | 1280x800 (default) |
| ASUS ROG Ally | `RC71L` | 1920x1080 |
| ASUS ROG Ally X | `RC72LA` | 1920x1080 |
| ASUS ROG Xbox Ally | `RC73YA` | 1920x1080 |
| ASUS ROG Xbox Ally X | `RC73XA` | 1920x1080 |
| Lenovo Legion Go | `83E1…` | 2560x1600 |
| Lenovo Legion Go 2 | `83N0…` / `83N1…` | 1920x1200 |
| Lenovo Legion Go S | `83L3…` / `83Q2…` / `83Q3…` / `83N6…` | 1920x1200 |
| MSI Claw 8 AI+ | `Claw 8 AI+…` | 1920x1200 |
| OneXPlayer 2 Pro | `ONEXPLAYER 2 PRO ARP23P` | 2560x1600 |

The ellipsis means full SKU strings are also recognized, for example `83N6000MSB`. The installer prefers the native resolution reported by the kernel and uses the table resolution as a fallback.

Got **another handheld**? It works in safe generic mode: the installer reads your panel's native resolution from the kernel and asks you to continue. It does not automatically install UEFI drivers without known compatibility.

### Using the controller inside the Clover menu
On models with known compatibility, including the Legion Go S `83N6`, the installer adds the XBOX 360 controller UEFI driver so the built-in gamepad works in the boot menu. It is disabled on the Steam Deck; on unverified models the installer asks before adding it.
* **D-pad**: change the selected option
* **A** = confirm, **B** = back
* **Right trigger** = left click, **left trigger** = right click
* Both thumbsticks also move the pointer.

Touch input only works when the device firmware exposes a UEFI pointer device. On the Legion Go S `83N6`, the touchscreen is connected over I²C and is not available to Clover; use the built-in controller, touchpad or a USB keyboard.

If a particular firmware has trouble with the controller driver, disable it and reboot:
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

It removes any old copy, clones the repo, and runs the installer. The script checks your sudo password and runs sanity checks along the way. When it finishes, the **Clover Dual Boot** app is available in the applications menu and on the desktop. **Reboot** and you'll get the Clover menu to pick your OS (D-pad and **A** to confirm).

<details>
<summary><b>Optional: Windows on microSD or external SSD</b></summary>

If Windows lives on a microSD or external SSD, after installing run:
```bash
sudo cp custom/config_sdcard.plist /esp/efi/clover/config.plist
```

If Windows still keeps hijacking the boot, set up the scheduled task on the Windows side: run `CloverWindows/CloverWindows.bat` as Administrator. It creates `C:\1Clover-tools`, installs a scheduled task called `CloverTask-donotdelete`, then in Task Scheduler open the task properties, tick **Run whether user is logged on or not** and **Do not store password**, and run it once.
</details>

### Updating to a newer version
Open the Clover Dual Boot app, go to **Advanced**, select **Uninstall**, clone the repo again, and repeat the install.

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
