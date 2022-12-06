set -e

echo
if [[ "$(cat /sys/class/mtd/mtd20/name)" == "rootfs" ]]; then
	echo "currently active OS slot: primary OS slot (mtd20)"
	rootfs_active=20
	rootfs_inactive=21
	echo "WARNING: the recovery initramfs firmware will be installed in the secondary OS slot"
	echo "and will be erased when you sysupgrade to a squashfs firmware to finish the install."
	echo "it is recommended that you manually reinstall a recovery firmware after sysupgrade."
elif [[ "$(cat /sys/class/mtd/mtd21/name)" == "rootfs" ]]; then
	echo "currently active OS slot: secondary OS slot (mtd21)"
	rootfs_active=21
	rootfs_inactive=20
	echo "NOTE: the recovery initramfs firmware will be installed in the primary OS slot and"
	echo "will survive the sysupgrade-to-squashfs step required later to finish the install."
	echo "you do not need to manually reinstall a recovery firmware after sysupgrade."
else
	echo "error: could not determine currently active OS slot"
	exit 1
fi

echo
echo "checking for downloaded initramfs recovery image"
ls -l /tmp/recovery.bin

echo
echo "creating ubi partition"
ubiformat /dev/mtd$rootfs_inactive
ubiattach -m $rootfs_inactive -d 9

echo
echo "creating recovery volume"
#ubirmvol /dev/ubi9 -N recovery || true
ubimkvol /dev/ubi9 -N recovery -n 9 -s 12MiB
echo "installing recovery"
ubiupdatevol /dev/ubi9_9 /tmp/recovery.bin

echo
echo "setting up u-boot environment"
fw_setenv -s - <<"EOF"

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

sync

echo
echo "erasing unused partitions"
mtd erase /dev/mtd22
mtd erase /dev/mtd$rootfs_active

echo
echo "all done!"
echo
echo "a reboot should now take you to the recovery initramfs firmware"
echo "from there do a sysupgrade to a squashfs firmware to finish the install"
echo

