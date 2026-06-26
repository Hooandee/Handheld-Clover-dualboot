# Clover Dual Boot for Handheld PCs — SteamOS / Bazzite + Windows

Install [Clover](https://github.com/CloverHackyColor/CloverBootloader), a graphical boot manager, to dual boot SteamOS (or Bazzite) and Windows — and other OSes too — on the Steam Deck and other x86 handhelds.

Based on the original [SteamDeck-Clover-dualboot](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot) by ryanrudolf ([@10MinuteSteamDeckGamer](https://www.youtube.com/@10MinuteSteamDeckGamer)). This fork broadens handheld support and simplifies installation.

## What's included
* **Clover** - the graphical boot manager that does the heavy lifting.
* **Clover Toolbox** - a simple GUI to configure Clover (themes, screen resolution, uninstall, and more).
* **Boot-manager systemd service** - sanity-checks the dual boot on every startup and repairs the boot entries automatically if a BIOS / OS / Windows update breaks them.
* **XBOX 360 controller UEFI driver** by [SkorionOS](https://github.com/SkorionOS/UsbXbox360Dxe) / [chenx-dust](https://github.com/chenx-dust/UsbXbox360Dxe) so the built-in gamepad of non-Steam-Deck handhelds works inside the Clover boot menu.
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

**Other handhelds** are supported through a generic mode: the installer auto-detects your panel's native resolution from the kernel and asks to continue, so most x86 handhelds work without any code changes.

> ⚠️ **Not supported:** Lenovo Legion Go S `83N6` is blocked because the XBOX 360 controller UEFI driver is incompatible with it.

### Using the controller in the Clover menu
On every handheld except the Steam Deck, the installer adds an XBOX 360 controller UEFI driver so the built-in gamepad works in the boot menu:
* **D-pad** - move / arrow keys
* **A** = Enter, **B** = Esc
* **Right trigger** = left click, **Left trigger** = right click
* If the D-pad doesn't respond, use the left thumbstick to move the mouse pointer.

If Clover ever appears to hang on a Legion Go (the driver can keep polling the controller), remove the driver and reboot:
```bash
sudo rm /esp/efi/clover/drivers/uefi/UsbXbox360Dxe.efi
```

## Disclaimer
Do this at your own risk. Provided for educational and research purposes only, with no warranty.

## Installation (SteamOS / Bazzite)

### Requirements - read this first
* **Install SteamOS / Bazzite _before_ Windows.** The installer refuses to run if Windows owns the EFI system partition.
* **Disable Secure Boot** in the BIOS/UEFI - required on non-Steam-Deck handhelds (ROG Ally, Legion Go, etc.).
* **Set a sudo password** in SteamOS / Bazzite - the installer needs it and will stop if it is blank.

### 1. Prepare Windows
Boot to Windows and open an elevated Command Prompt or PowerShell, then run:
1. ```cmd
   bcdedit.exe -set "{globalsettings}" highestmode on
   ```
2. ```cmd
   reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f
   ```

### 2. Install on SteamOS / Bazzite

> ⚡ **Easy install (SteamOS & Bazzite)** - boot into Desktop Mode, open a terminal (konsole), and paste this single command:
>
> ```bash
> cd ~ && rm -rf Handheld-Clover-dualboot && git clone https://github.com/Hooandee/Handheld-Clover-dualboot && cd Handheld-Clover-dualboot && chmod +x install-Clover.sh && ./install-Clover.sh
> ```
>
> It removes any old copy, clones this repo, and runs the installer in one step. Prefer to do it by hand? Use the numbered steps below.

1. Boot into SteamOS / Bazzite, then go into Desktop Mode and open a terminal (konsole).<br>
2. Clone the github repo. <br>
   ```cmd
   cd ~/
   ```
   ```cmd
   git clone https://github.com/Hooandee/Handheld-Clover-dualboot
   ```
   
   If it errors that folder already exists, delete the old folder first - <br>
   ```cmd
   rm -rf ~/Handheld-Clover-dualboot
   ```
   
   Then perform the clone again - <br>
   ```cmd
   git clone https://github.com/Hooandee/Handheld-Clover-dualboot
   ```
   
3. Execute the script! <br>
   ```cmd
   cd ~/Handheld-Clover-dualboot
   ```
   ```cmd
   chmod +x install-Clover.sh
   ```
   ```cmd
   ./install-Clover.sh
   ```
   
     ![image](https://github.com/user-attachments/assets/043d8e7c-9d57-48b2-a1ad-f93c94cf3e9f)

4. The script will check if sudo passwword is already set. <br>
    - If it is already set, enter the current sudo password and the script will continue.
    - If wrong password is provided the script will exit immdediately. Re-run the script and enter the correct sudo password!
    - If the sudo password is blank / not yet set by the end user, the script will prompt to setup the sudo password. Re-run the script to continue.
    - Script will continue to run and perform sanity checks all throughout the install process.
                     
5. Reboot your handheld. Clover is installed - you'll see a GUI to choose which OS to boot. Use the D-pad and press A to confirm (see the controller mapping above).<br>
![image](https://user-images.githubusercontent.com/98122529/214861561-bb63c209-14ee-492a-a506-2a87665f52d3.png)<br>

**6a. OPTIONAL - If you have Windows installed on SDCARD (not recommended) or External SSD you need to do this additional step -**\
`sudo cp custom/config_sdcard.plist /esp/efi/clover/config.plist`

<b>6b. OPTIONAL - Scheduled Task for Windows. Use this only if you have Windows installed on microSD / external SSD and if Windows keeps hijacking the bootloader!</b>
<details>
<summary><b>Use this only if you have Windows installed on microSD / external SSD and if Windows keeps hijacking the bootloader!</b></summary>

1. Download the ZIP by pressing the GREEN CODE BUTTON, then select Download ZIP.<br>

![image](https://user-images.githubusercontent.com/98122529/212368293-2b5f59ac-b480-4f72-b7c5-3122e57476e4.png)<br>

2. Go to your Downloads folder and then extract the zip.<br>
3. Right click CloverWindows.bat and select RUNAS Administrator.<br>
![image](https://user-images.githubusercontent.com/98122529/212368736-c9b10eb0-ecfe-4ccb-b035-1aa55f959d94.png)<br>

4. The script will automatically create the C:\1Clover-tools folder and copy the files in there. <br>
5. It will also automatically create the Scheduled Task called CloverTask-donotdelete. <br>
![image](https://user-images.githubusercontent.com/98122529/212368944-9be9e55a-ce96-43d8-9fb0-bf5f17a2bcc8.png)<br>

6. Go to Task Scheduler and the CloverTask will show up in there.<br>
7. Right-click the CloverTask and select Properties.<br>
![image](https://user-images.githubusercontent.com/98122529/212369284-76266936-d9d6-495e-aaf9-44d3abb7b129.png)<br>

8. Under the General tab, make sure it looks like this. Change it if it doesn't then press OK.<br>
![image](https://user-images.githubusercontent.com/98122529/212369626-8a02f229-3a94-45d0-ad1f-929a4a7e51be.png)<br>

9. Right click the task and select RUN.<br>
![image](https://user-images.githubusercontent.com/98122529/212369786-6a973906-a849-4c60-85cb-556963754997.png)<br>

10. Close Task Scheduler. Go to C:\1Clover-tools and look for the file called status.txt.<br>
11. Open status.txt and the Clover GUID should be the same as the bootsequence. Sample below.<br>
![image](https://user-images.githubusercontent.com/98122529/212370053-2bd6dbd8-3d21-43a9-8498-cd0f156c6b9c.png)<br>

12. Reboot and you should see a GUI to select which OS to boot from! Use the DPAD and press A to confirm your choice. You can also use the trackpad to control the mouse pointer and use the RIGHT SHOULDER BUTTON for LEFT-CLICK.<br>
![image](https://user-images.githubusercontent.com/98122529/214861561-bb63c209-14ee-492a-a506-2a87665f52d3.png)<br>
</details>

## Why Use this Clover install script for dual boot?!?
1. Makes as little changes as possible to the SteamOS / Windows installation.
2. Makes dual boot with SteamOS / Windows easy with a nice GUI.
3. No extra config needed for Ventoy, Batocera, Kali, Ubuntu and Fedora. (if there are other OS you want to be added just let me know)
4. Automatically and easily re-create the dual boot entries if it gets broken by a BIOS / SteamOS / Windows update. No need to type manual commands!
5. Supports random themes (Mojave and Catalina bundled in the install script), add / remove themes, icons, background using Dolphin File Manager.

## Screenshots
**Apocalypse - SteamOS, Windows and Batocera (microSD)**
![image](https://user-images.githubusercontent.com/98122529/233867354-4d554a4e-1e1f-42f7-968a-31a8c0b677b2.png)

**Clover Toolbox**
![image](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot/assets/98122529/8308d81f-99f6-4751-abf1-3ebb8436322a)

<details>
<summary><b>More Screenshots Here</b></summary>

<b>Custom Windows Splash Screen</b><br>
![image](https://user-images.githubusercontent.com/98122529/233867095-5946c34a-5e63-41e4-bc56-5e8d6a261d0f.png)<br>

<b>Gothic - SteamOS, Windows, Batocera (microSD) and Fedora</b><br>
![image](https://user-images.githubusercontent.com/98122529/233867306-15377bfa-91e7-4f9d-abea-d346be6099be.png)<br>

<b>Catalina - SteamOS, Windows, and Batocera (microSD)</b><br>
![image](https://user-images.githubusercontent.com/98122529/214861561-bb63c209-14ee-492a-a506-2a87665f52d3.png)<br>

<b>Crystal - SteamOS, Windows, Batocera (microSD) and Fedora</b><br>
![image](https://user-images.githubusercontent.com/98122529/233867450-b87b0704-38b7-41a5-89e6-b39567b440ac.png)<br>

<b>Rick and Morty - SteamOS, Windows, Batocera (microSD) and Fedora</b><br>
![image](https://user-images.githubusercontent.com/98122529/233867485-d91f4bae-4139-431a-9fb1-730f3c74f5f1.png)<br>

<b>Select which OS will be the default in the Clover GUI boot menu</b><br>
![image](https://user-images.githubusercontent.com/98122529/229242673-0966ef48-9b6b-41ba-8269-2e8c1d9caca1.png)<br>

<b>Catalina - SteamOS, Windows, Batocera (microSD) and Fedora</b><br>
![image](https://user-images.githubusercontent.com/98122529/224508836-c170c472-da02-441e-9709-6950d3d47332.png)<br>

<b>Mojave - SteamOS, Windows, Ventoy (microSD) and Fedora</b><br>
![image](https://user-images.githubusercontent.com/98122529/224508862-6fd10d7c-eb96-4a0e-aeff-d59034e6bd7c.png)<br>

<b>Mojave - SteamOS, Windows and Batocera (microSD)</b><br>
![image](https://user-images.githubusercontent.com/98122529/214861730-66b21114-09bd-43f4-ae30-f1c3efb24d4a.png)<br>

<b>Mojave - SteamOS, Windows on Internal SSD and Windows on External SSD / microSD</b><br>
![image](https://user-images.githubusercontent.com/98122529/232523110-77cd7616-cca4-40c4-9a5e-cbc003afae80.png)
![image](https://user-images.githubusercontent.com/98122529/232523294-21c5ed46-ee02-4688-b65f-e3ea15b6bcd8.png)

<b>Mojave - SteamOS, Windows, Ubuntu and Kali (pic not mine)</b><br>
![image](https://user-images.githubusercontent.com/98122529/224509169-ae7e41ae-a870-4227-a16f-d79e7877bea5.png)<br>

<b>Easily add / remove themes using Dolphin File Manager</b><br>
![image](https://user-images.githubusercontent.com/98122529/214928509-7d6cae5e-107e-4bcd-baa7-2051f6ddb269.png)<br>
</details>

## How to Add / Remove Themes
<details>
<summary><b>Read this first - ESP partition size</b></summary>
The esp partition is only 64MB in size. This is where SteamOS, Windows and Clover EFI entries are saved.<br>
The free space on the esp partition is around ~25MB. Make sure the themes you download don't exceed this size!<br>
You can have multiple themes installed and Clover will automatically pick a random theme on every reboot!<br>
</details>

<details>
<summary><b>Read this first - custom icons</b></summary>
When adding your own theme, make sure to name your custom SteamOS and Batocera icons as follows - <br>
os_steamos.icns<br>
os_batocera.icns<br>
This are just regular PNG files, but you have to rename them to have the icns file extension.<br>
Sample icons are saved in custom\iconset folder. Thanks to WindowsOnDeck reddit members u/ch3vr0n5 and u/ChewyYui !!!<br>
</details>

<details>
<summary><b>Steps to Add / Delete Themes</b></summary>
1. Boot into Desktop Mode and then open Dolphin File Manager.<br>
2. Navigate to /esp on the lower left side. It will say "Could not enter folder /esp"<br>

   ![image](https://user-images.githubusercontent.com/98122529/214927546-75e5cd14-1c0a-499d-8491-d5221e20f3a8.png)<br>

3. Right-click and select "Open as Root."<br>
   ![image](https://user-images.githubusercontent.com/98122529/214929527-f9e9a435-f715-4803-88f9-5b30e043a84c.png)<br>

4. Enter the sudo password when prompted.<br>

   ![image](https://user-images.githubusercontent.com/98122529/214928042-eda04c7e-41d0-4d0f-9ae8-6aa3003b5032.png)<br>
   

5. A new folder will appear for the esp partition.<br>
   Take note of the free space located in the lower right side. On this example the free space is around 26MB.<br>
   ![image](https://user-images.githubusercontent.com/98122529/215268989-56a661dc-e2c5-40fb-b57e-9b49a4de93a7.png)<br>

6. Visit the [Clover Themes github](https://github.com/CloverHackyColor/CloverThemes) to download the themes. Make sure the themes you download doesn't exceed the free space of the esp partition from step5.<br>

7. Navigate to efi > clover > themes. It will show a list of themes installed. By default it will show 3 - random, Catalina and Mojave.<br>
   ![image](https://user-images.githubusercontent.com/98122529/214928509-7d6cae5e-107e-4bcd-baa7-2051f6ddb269.png)<br>

8. **Don't delete the random folder!** It is needed so that when there are multiple themes installed, Clover will randomly pick a theme on every reboot.<br>
9. Delete the themes you don't want and copy / paste new themes that you have downloaded.<br>
10. Reboot and enjoy the new theme!<br>
</details>

## FAQ / Troubleshooting
Read this for your Common Questions and Answers! This will be regularly updated and some of the answers in here are contributions from the [WindowsOnDeck reddit community!](https://www.reddit.com/r/WindowsOnDeck/)

### How to Update to a Newer Version?!?
From time to time I update this repo for new version of the script. It may include bug fixes, new features or an updated Clover EFI version. \
To update to a new version -
1. Go to Desktop Mode and launch Clover Toolbox.
2. Select Uninstall
3. Clone the repo again to get the latest version and perform the install steps.

<details>
<summary><b>Q0. Windows on microSD / external SSD doesn't get picked up automatically!</b></summary>
1. Make sure that it is setup as GPT and Windows-to-Go in Rufus. <br>

![image](https://user-images.githubusercontent.com/98122529/229247790-8511dc09-b56e-4e3f-ae59-bd11b21fc07c.png)<br>
</details>

<details>
<summary><b>Q1. Windows shows strange vertical lines at the center when booting up!</b></summary>

![image](https://user-images.githubusercontent.com/98122529/211201387-36311ba8-7ac4-44e7-938c-25d5ed2a3e5f.png)<br>
1. Boot to Windows.<br>
2. Open command prompt with admin privileges and enter the command -<br>
   bcdedit.exe -set {globalsettings} highestmode on<br>
</details>
      
<details>
<summary><b>Q2. Windows boots up in garbled graphics!</b></summary>
   
![image](https://user-images.githubusercontent.com/98122529/211198222-5cce38ff-3f20-4386-8715-c408fea6a4b0.png)<br>

1. Boot to SteamOS.<br>
2. Go to Desktop Mode.<br>
3. Double-click Clover Toolbox desktop icon. <br>
4. Select the item called Service and press OK. <br>

![image](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot/assets/98122529/f7299f1a-989b-4f0b-864f-3a527162a6b5)
   
5. Press the item called Disable and press OK. <br>
![image](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot/assets/98122529/0be15a60-6513-4608-8642-412dd0a7646e)
   
![image](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot/assets/98122529/decb3a9d-7499-4df1-b7a4-abd3e23fa892)

6. Reboot and it will automatically boot to Windows. <br>

7. Open command prompt with admin privileges and enter the command -<br>
   bcdedit.exe -set {globalsettings} highestmode on <br>

8. Make sure screen orientation is set to Landscape.<br>
9. If everything looks good then shutdown the Steam Deck.<br>
10. Press VOLDOWN + POWER and select SteamOS from the list.<br>
11. Follow step2 onwards, and on step 5 select the item called Enable. <br>
   
![image](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot/assets/98122529/2fd5b3ef-5247-49da-886c-2095e3ce44f3)
   
![image](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot/assets/98122529/d9c5ecd2-0426-40fd-8fb0-88f38ba54b55)
   
12. Reboot and it will go back to Clover!
</details>

<details>
<summary><b>Q3. I need to perform a GPU / APU driver upgrade in Windows. What do I do?</b></summary>
1. Boot to SteamOS.<br>
2. Go to Desktop Mode.<br>
3. Double-click Clover Toolbox desktop icon. <br>
4. Select the item called Service and press OK. <br>

![image](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot/assets/98122529/f7299f1a-989b-4f0b-864f-3a527162a6b5)
   
5. Press the item called Disable and press OK. <br>
![image](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot/assets/98122529/0be15a60-6513-4608-8642-412dd0a7646e)
   
![image](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot/assets/98122529/decb3a9d-7499-4df1-b7a4-abd3e23fa892)

6. Reboot and it will automatically boot to Windows. <br>
7. Install the GPU / APU driver upgrade and reboot Windows.<br>
8. Make sure screen orientation is set to Landscape.<br>
9. If everything looks good then shutdown the Steam Deck.<br>
10. Press VOLDOWN + POWER and select SteamOS from the list.<br>
11. Follow step2 onwards, and on step 5 select the item called Enable. <br>
   
![image](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot/assets/98122529/2fd5b3ef-5247-49da-886c-2095e3ce44f3)
   
![image](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot/assets/98122529/d9c5ecd2-0426-40fd-8fb0-88f38ba54b55)
   
12. Reboot and it will go back to Clover!
</details>
       
<details>
<summary><b>Q4. I reinstalled Windows and now it boots directly to Windows instead of Clover!</b></summary>
1. Shutdown the Steam Deck. While powered OFF, press VOLDOWN + POWER and select SteamOS from the list.<br>
2. Script will automatically fix the dual boot entries! Reboot and it will go back to Clover!<br>
</details>

<details>
<summary><b>Q5. Windows automatically installed updates and on reboot it goes automatically to Windows!</b></summary>
1. Shutdown the Steam Deck. While powered OFF, press VOLDOWN + POWER and select SteamOS from the list.<br>
2. Script will automatically fix the dual boot entries! Reboot and it will go back to Clover!<br>
</details>

<details>
<summary><b>Q6. There was a SteamOS update and it wiped all my boot entries!</b></summary>
This happens even if not using dualboot / Clover / rEFInd.<br>
1. Shutdown the Steam Deck. While powered OFF, press VOLUP + POWER.<br>
2. Go to Boot from File > efi > steamos > steamcl.efi<br>
3. Script will automatically fix the dual boot entries! Reboot and it will go back to Clover!<br>
</details>

<details>
<summary><b>Q7. The time is always getting messed up!</b></summary>
1. Boot to Windows. <br>
2. Open command prompt with admin privileges and enter the command -<br>
   reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f <br> <br>
3. Reboot the Steam Deck for changes to take effect. <br>
</details>

<details>
<summary><b>Q8. I see 'Error mounting ISO!' when attempting to run the Clover script!</b></summary>
This can happen if you have an old version of SteamOS installed or have installed SteamOS from the recovery image which is missing 7zip.<br>
1. Boot to SteamOS. <br>
2. Perform a System Update by going to Steam > Settings > System > Check for Updates <br>
3. Once update has completed, restart in to SteamOS. <br>
4. Go to Desktop Mode and rerun the Clover script. <br>
</details>

<details>
<summary><b>Q9. I hate Clover / I want to just dual boot the manual way / A better script came along and I want to uninstall your work!</b></summary>
1. Boot into SteamOS.<br>
2. Go to Desktop Mode.<br>
3. Double-click Clover Toolbox desktop icon. <br>
4. Select the item called Uninstall and press OK. <br>
   
![image](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot/assets/98122529/dced41a9-74e3-4dca-a90d-38e0e373614a)

4. Clover will be uninstalled and on next reboot it will automatically load Windows. Clover has been uninstalled!<br>
</details>

## Known issues
### Issues with external display with resolution higher than 1080p
If Steam Deck is connected to an external display with a resolution **higher than 1080p** (1440p, 4K, etc.), there are some issues that Clover may cause.
* Clover screen **will be rotated**. See images below for examples. Once an OS is started, the screen should show in the correct orientation.
* Windows **may show BSoD** or otherwise **fail to boot**. See these issues for the reference: [#43](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot/issues/43), [#85](https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot/issues/85)

| Resolution | Clover screen |
|-|-|
| 1080p | ![Clover on 1080p display](https://user-images.githubusercontent.com/98122529/230472962-0c981a47-2677-4766-80ad-c2b27d7f62c7.png) |
| 4K | ![Clover on 4K display](https://user-images.githubusercontent.com/98122529/230472728-b73bc18f-563d-4149-9d18-27792d6031b7.png) |

Because of these issues, when using an external display, it is recommended to use a display with 1080p or lower resolution.

If you use a display with a resolution higher than 1080p anyway, a workaround for these issues is available to make Windows boot normally and make Clover screen show in the correct orientation only on the external display.
1. Open Clover Toolbox.
1. Select "Resolution".
1. Change the resolution option to "DeckSight".

Note that this workaround **will make Clover screen rotated on Steam Deck's built-in display** when it is not connected to an external display.

## Acknowledgement / Thanks
Thanks to jlobue10 for his rEFInd script [available here.](https://github.com/jlobue10/SteamDeck_rEFInd) This Clover script was inspired by jlobue10's rEFInd script.

And in no particular order -<br>
- the Clover team / sergey for creating this awesome software. <br>
- Christoph Pfisterer for creating rEFIt which Clover is a fork of. <br>
- ss64.com for my quick online reference guide on command line switches! I also use this at work when scripting using bash / batch / powershell. <br>
- deckwizard for testing the initial Clover script. <br>
- arkag for the code enhancement to pull the ISO directly from Clover repo. <br>
- community contributed icons / logos for SteamOS and Batocera (thanks to WindowsOnDeck reddit members u/ch3vr0n5 and u/ChewyYui). <br>
- baldsealion for creating the custom splash screen for Windows. <br>
- Kodi Ross from FB Steam Deck Community for the Rick and Morty theme. <br>
- insanelymac and its forum members for creating beautiful Clover themes. <br>
- and the rest of WindowsOnDeck reddit community / discord server!<br>
- PS I forgot to mention LOUP the author of the OpenAsRoot KDE extension.
