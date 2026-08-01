#!/bin/bash

# define variables here
CLOVER=$(efibootmgr | grep -i Clover | colrm 9 | colrm 1 4)
CLOVER_VERSION=5160
CLOVER_EFI=\\EFI\\clover\\cloverx64.efi
BIOS_VERSION=$(cat /sys/class/dmi/id/bios_version)
MODEL=$(cat /sys/class/dmi/id/board_name)
ESP_PARTITION=$(df -h | grep nvme0n1p1 | tr -s " " | cut -d " " -f 1)
OS_Name=$(grep PRETTY_NAME /etc/os-release | cut -d "=" -f 2)
OS_Version_Bazzite=$(grep OSTREE_VERSION /etc/os-release | cut -d "=" -f 2)
OS_Version_SteamOS=$(grep VERSION_ID /etc/os-release | cut -d "=" -f 2)
OS_Build=$(grep BUILD_ID /etc/os-release | cut -d "=" -f 2)
KERNEL_VERSION=$(uname -r | cut -d "-" -f 1-5)
ESP_MOUNT_POINT=$(df -h | grep nvme0n1p1 | tr -s " " | cut -d " " -f 6)
ESP_ALLOCATED_SPACE=$(df -h | grep nvme0n1p1 | tr -s " " | cut -d " " -f 2)
ESP_USED_SPACE=$(df -h | grep nvme0n1p1 | tr -s " " | cut -d " " -f 3)
ESP_FREE_SPACE=$(df -h | grep nvme0n1p1 | tr -s " " | cut -d " " -f 4)
OWNER=$(grep '1000:1000' /etc/passwd | cut -d ":" -f1)
CloverStatus=/home/$OWNER/1Clover-tools/status.txt

# check if Bazzite or SteamOS
grep -i bazzite /etc/os-release &> /dev/null
if [ $? -eq 0 ]
then
	OS=bazzite
	EFI_PATH=/boot/efi/EFI
	EFI_NAME=\\EFI\\fedora\\shimx64.efi
	echo Script is running on supported OS - $OS version $OS_Version_Bazzite build $OS_Build > $CloverStatus
else
	grep -i SteamOS /etc/os-release &> /dev/null
	if [ $? -eq 0 ]
	then
		OS=SteamOS
		EFI_PATH=/esp/efi
		EFI_NAME=\\EFI\\steamos\\steamcl.efi
		echo Script is running on supported OS - $OS version $OS_Version_SteamOS build $OS_Build > $CloverStatus
	else
		echo This is neither Bazzite nor SteamOS! > $CloverStatus
		echo Exiting immediately! >> $CloverStatus
		exit
	fi
fi

echo Clover $CLOVER_VERSION Boot Manager - $(date) >> $CloverStatus
echo Steam Deck Model : $MODEL with  BIOS version $BIOS_VERSION >> $CloverStatus

echo Kernel Version : $KERNEL_VERSION >> $CloverStatus

# check for dump files
dumpfiles=$(ls -l /sys/firmware/efi/efivars/dump-type* 2> /dev/null | wc -l)

if [ $dumpfiles -gt 0 ]
then
	echo EFI dump files exists - cleanup completed. >> $CloverStatus
	sudo rm -f /sys/firmware/efi/efivars/dump-type*
else
	echo EFI dump files does not exist - no action needed. >> $CloverStatus
fi

# Sanity Check - are the needed EFI entries available?
efibootmgr | grep -i Clover &> /dev/null
if [ $? -eq 0 ]
then
	echo Clover EFI entry exists! No need to re-add Clover. >> $CloverStatus
else
	echo Clover EFI entry is not found. Need to re-ad Clover. >> $CloverStatus
	efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Clover - GUI Boot Manager" -l "$CLOVER_EFI" &> /dev/null
fi

efibootmgr | grep -i $OS &> /dev/null
if [ $? -eq 0 ]
then
	echo $OS EFI entry exists! No need to re-add $OS. >> $CloverStatus
else
	echo SteamOS EFI entry is not found. Need to re-add $OS. >> $CloverStatus
	efibootmgr -c -d /dev/nvme0n1 -p 1 -L "$OS" -l "$EFI_NAME" &> /dev/null
fi

# verify/refresh the restorable Windows loader before disabling its canonical path
CLOVER_CTL=/etc/clover-dualboot/clover-ctl
if [ -x "$CLOVER_CTL" ] \
	&& CLOVER_EFI_PATH="$EFI_PATH" "$CLOVER_CTL" protect-windows-efi >> "$CloverStatus" 2>&1
then
	echo Windows EFI protection verified. >> "$CloverStatus"
else
	echo Windows EFI protection failed - refusing to move the loader. >> "$CloverStatus"
	exit 1
fi

# re-arrange the boot order and make Clover the priority!
Clover=$(efibootmgr | grep -i Clover | colrm 9 | colrm 1 4)
OtherOS=$(efibootmgr | grep -i $OS | colrm 9 | colrm 1 4)
efibootmgr -o $Clover,$OtherOS &> /dev/null

echo "*** Current state of EFI entries ****" >> $CloverStatus
efibootmgr | grep -iv 'Boot2\|PXE' >> $CloverStatus
echo "*** Current state of EFI partition ****" >> $CloverStatus
echo ESP partition: $ESP_PARTITION >> $CloverStatus
echo ESP mount point: $ESP_MOUNT_POINT >> $CloverStatus
echo ESP allocated space: $ESP_ALLOCATED_SPACE >> $CloverStatus
echo ESP used space: $ESP_USED_SPACE >> $CloverStatus
echo ESP free space: $ESP_FREE_SPACE >> $CloverStatus

chown $OWNER:$OWNER $CloverStatus
