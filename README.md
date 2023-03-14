## OpenWrt installation instructions for Askey RT4230W REV6 / RAC2V1K

### Requirements

- An Askey RT4230W REV6 router with non-SAC2V1K firmware:
  - If your router has "Username: admin, Password: admin" on the top back label, you are ok.
  - But if your router has a QR code on the top back label, you unfortunately have a device with SAC2V1K firmware.
    You will need to disassemble the router to install OpenWrt via its serial interface.
- A linux box (Windows Subsystem for Linux and macOS should also work but have not been tested).
- Ethernet connection to the router (Wi-Fi connection should also work but has not been tested).
- Installed software: ssh, scp, and sshpass. (A TFTP server is not required.)

### Preparation

1. Clone this repository.
2. [Download](https://firmware-selector.openwrt.org/?target=ipq806x%2Fgeneric&id=askey_rt4230w-rev6) OpenWrt initramfs (kernel) and squashfs (sysupgrade) images for this router to the checkout directory.
3. Download [RAC2V1K-SSH.zip](https://raw.githubusercontent.com/lmore377/openwrt-rt4230w/master/RAC2V1K-SSH.zip), the SSH hack for this router, and review its [README](https://pastebin.com/raw/ub8Um4ug).
4. Connect to the router via Ethernet or Wi-Fi using manual IP 192.168.1.2 or DHCP.
5. Log into the stock router firmware at http://192.168.1.1/ with the default username/password (admin/admin).
6. Navigate to `Advanced > Status > System Information` and take note of the currently running stock firmware version.
7. Determine and extract the hacked configuration file that corresponds to the running firmware from `RAC2V1K-SSH.zip`. If the firmware is newer than what is listed in the zip, choose the latest available file.
8. Navigate to `Advanced > Admin > Configuration` and use the restore from file option to upload the chosen configuration file. The router will reboot.
9. Edit file `stock4230w` and uncomment the SSH username and password corresponding to the your stock firmware version.
10. Pop up a terminal in the checkout directory and verify SSH access by typing:
```
./stock4230w ssh '$HOST "cat /proc/version"'
```
- Output should be similar to:
```
Linux version 3.14.77 (jenkins@ci-server) (gcc version 5.2.0 (OpenWrt GCC 5.2.0 r35193) ) #1 SMP PREEMPT Thu Nov 15 03:39:25 UTC 2018
```

### Backup the stock firmware

1. Create and transfer backups of all MTD partitions:
```
./stock4230w ssh '$HOST sh' <mtd-backup.sh
./stock4230w scp -O '$HOST:/tmp/lanchon/mtd-backup.tar .'
./stock4230w ssh '$HOST "rm /tmp/lanchon/mtd-backup.tar"'
```
2. Create and transfer backups of all UBI volumes:
```
./stock4230w ssh '$HOST sh' <ubi-backup.sh
./stock4230w scp -O '$HOST:/tmp/lanchon/ubi-backup.tar .'
./stock4230w ssh '$HOST "rm /tmp/lanchon/ubi-backup.tar"'
```
- You might need these backups down the road, so store them.

### Install OpenWrt

Make sure you have backups of the stock firmware (see previous section); each device is different.

1. Install the initramfs recovery image:
```
./stock4230w scp -O 'openwrt-[...]-askey_rt4230w-rev6-initramfs-uImage $HOST:/tmp/recovery.bin'
./stock4230w ssh '$HOST sh' <install-recovery.sh
```
- Note that the router has two copies of the stock OS. Depending on which one is currently running, the install script might need to install the recovery image in an area that will be erased
by sysupgrade in the following install step. The install script will let you know if this is the case. Consider reinstalling recovery immediately after finishing the regular OpenWrt install.
The recovery image will run automatically if the main OS ever gets corrupted, for example due to an interrupted sysupgrade.
2. Sysupgrade to the squashfs image:
- Reboot router and connect to http://192.168.1.1/cgi-bin/luci/admin/system/flash.
- Click on `Flash image...` and choose the squashfs image.
3. Reconnect to http://192.168.1.1/ and profit!

### Reinstall the recovery image if required

You can skip this procedure if the install script above did not recommend it.

1. WARNING: This process will wipe the current router configuration. Take a configuration backup if required.
2. [Download](https://firmware-selector.openwrt.org/?target=ipq806x%2Fgeneric&id=askey_rt4230w-rev6) the OpenWrt initramfs (kernel) image for this router.
3. Boot the router in failsafe mode by holding down the WPS button when the blue led starts to flash rapidly. The led will turn red when in failsafe mode.
4. Connect to the router via Ethernet or Wi-Fi using manual IP 192.168.1.2 or DHCP.
5. Pop up a terminal and create a UBI volume to host the recovery image by typing:
```
ssh root@192.168.1.1 'ubirmvol /dev/ubi0 -N rootfs_data && ubimkvol /dev/ubi0 -N recovery -n 9 -s 12MiB && ubimkvol /dev/ubi0 -N rootfs_data -m'
```
6. Reboot the router in normal mode and reconnect to it if necessary.
7. Write the recovery image to the UBI volume with:
```
scp -O openwrt-[...]-askey_rt4230w-rev6-initramfs-uImage root@192.168.1.1:/tmp/recovery.bin
ssh root@192.168.1.1 'ubiupdatevol /dev/ubi0_9 /tmp/recovery.bin && rm /tmp/recovery.bin'
```
8. Restore the router configuration if applicable.

### Install a recovery image if you installed OpenWrt through any other method

A recovery image will run automatically if the main OS ever gets corrupted, for example due to an interrupted sysupgrade.
Recovery will allow you to reinstall the main OS without needing access the serial interface, thus avoiding a soft-brick.
The associated boot configuration will also cause the router to attempt a TFTP boot if main and recovery OSes are both corrupt.
If you originally installed OpenWrt following the instructions above, you already have a recovery image installed.
You can follow these steps to install a recovery image if you installed OpenWrt through any other method.

WARNING: This procedure modifies your bootloader configuration. In case of issues, the possibility of a soft-brick cannot be ruled out.

1. Follow the steps of section "[Reinstall the recovery image if required](#reinstall-the-recovery-image-if-required)" except for the last step: do not restore the configuration just yet.
2. Update boot configuration with this multi-line command, which should be copied and pasted in one go to the terminal, pressing ENTER after pasting:
```
ssh root@192.168.1.1 "fw_setenv -s -" <<"EOF"

boot_setup_512M set mtdids nand0=nand0 && set mtdparts mtdparts=nand0:416M@0x2400000(mtd_ubi)
boot_setup_256M set mtdids nand0=nand0 && set mtdparts mtdparts=nand0:220M@0x2400000(mtd_ubi)

boot_ubi_main ubi part mtd_ubi && ubi read 0x44000000 kernel && bootm
boot_ubi_recovery ubi part mtd_ubi && ubi read 0x44000000 recovery && bootm

boot_main run boot_setup_512M; run boot_ubi_main; run boot_setup_256M; run boot_ubi_main
boot_recovery run boot_setup_512M; run boot_ubi_recovery; run boot_setup_256M; run boot_ubi_recovery
boot_main_or_recovery run boot_setup_512M; run boot_ubi_main; run boot_ubi_recovery; run boot_setup_256M; run boot_ubi_main; run boot_ubi_recovery

boot_tftp test -n "$ipaddr" || set ipaddr 192.168.1.1; test -n "$serverip" || set serverip 192.168.1.2; tftpboot recovery.bin && bootm

boot_custom test -n "$boot_pre" && run boot_pre; run boot_main_or_recovery; run boot_tftp

bootcmd run boot_custom
bootdelay 2

EOF

echo "Exit code: $? (zero means no error)"
```
3. Reboot the router.
4. Restore the router configuration if applicable.

### Update the recovery image

There is usually no reason to upgrade the recovery image. This is provided for completeness.

1. [Download](https://firmware-selector.openwrt.org/?target=ipq806x%2Fgeneric&id=askey_rt4230w-rev6) the OpenWrt initramfs (kernel) image for this router.
2. Pop up a terminal and write the recovery image (replace 192.168.1.1 with the address of your router):
```
scp -O openwrt-[...]-askey_rt4230w-rev6-initramfs-uImage root@192.168.1.1:/tmp/recovery.bin
ssh root@192.168.1.1 'ubiupdatevol /dev/ubi0_9 /tmp/recovery.bin && rm /tmp/recovery.bin'
```

