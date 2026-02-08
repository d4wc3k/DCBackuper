____

- ## Install required packages

	```bash
	#
	# update package database
	apt update
	# install packages
	apt install partclone pigz gdisk rar unrar efibootmgr 
	#
	```

____

- ## Prepare target location

  	```bash
	#
	# create dir for mount point
	mkdir -p /backup
	# mount backup partition
	mount /dev/sda1 /backup/
	# prepare target dir
	cd /backup
	# unpack encrypted rar archive (optional)
	rar x BACKUP.rar
	#
	# go to directory with backup files
	cd BACKUP
	#
	```

___

- ## Restore partition table with dd util

	```bash
	# restore 
	DISK="/dev/sdb"
	dd if=part_table.bin of=${DISK} bs=512 status=progress && sync 
	# fix partition table with sgdisk
	sgdisk -e ${DISK}
	# verification with gdisk and 'v' option
	gdisk ${DISK}
	#
	```

___

- ## Restore luks header

	```bash
	#
	CRYPT="/dev/sdb3"
	cryptsetup luksHeaderRestore "${CRYPT}" --header-backup-file luks_header.bin
	# open encrypted luks partition
	cryptsetup open "${CRYPT}" xyz-unlocked
	#
	```

___

- ## Recreate physical volume (pv)

	```bash
	#
	PV_UUID=$(cat pv_UUID.txt)
	pvcreate --uuid "${PV_UUID}" --norestorefile /dev/mapper/xyz-unlocked
	#
	```

____

- ## Restore volume group configuration

	```bash
	# restore
	vgcfgrestore -f vg_backup.txt vg
	# activiate logical volume for vg volume group
	vgchange -a y vg
	#
	```

___

- ## Restore partition with partclone

	```bash
	#
	# root partition
	pigz -d -c root.img.gz | partclone.ext4 -z 10485760 --source - -r -o  /dev/mapper/vg-root
	# boot partition
	pigz -d -c boot.img.gz | partclone.ext2 -z 10485760 --source - -r -o /dev/sdb2
	# efi partition
	pigz -d -c efi.img.gz | partclone.vfat -z 10485760 --source - -r -o  /dev/sdb1
	# home partition
	pigz -d -c home.img.gz | partclone.ext4 -z 10485760 --source - -r -o  /dev/mapper/vg-home
	#
	#
	```
	
___

- ## Recreate swap parition

	```bash
	#
	SWAP_UUID=$(cat swap_UUID.txt)
	 mkswap -L SWAP -U "${SWAP_UUID}" /dev/mapper/vg-swap
	#
	```

___

- ## Add existing bootloader

	```bash
	efibootmgr -c -d /dev/sda -p 1 -L "debian" -l '\EFI\debian\grubx64.efi'
	```
___

- ## Reinstall grub (Optional)

```bash
# prepare chroot
mkdir -p /target
mount /dev/mapper/vg-root /target
mount /dev/sda2 /target/boot
mount /dev/sda1 /target/boot/efi
mount /dev/mapper/vg-home /target/home
mount --bind /dev /target/dev
mount --bind /dev/pts /target/dev/pts
mount --bind /proc /target/proc
mount --bind /sys /target/sys
mount --bind /run /target/run
mount --bind /sys/firmware/efi/efivars /target/sys/firmware/efi/efivars
# perform chroot
chroot /target /bin/bash -l
# commands in chroot
export PS1="|chroot| ${PS1}"
cd
grub-install --target=x86_64-efi --efi-directory=/boot/efi
update-initramfs -ck all;update-grub2
# exit chroot
exit
umount /target/sys/firmware/efi/efivars
umount /target/run
umount /target/sys
umount /target/proc
umount /target/dev/pts
umount /target/dev
umount /target/home
umount /target/boot/efi
umount /target/boot
umount /target
rm -fr /target
#
```

____

- ## Finish things

	```bash
	#
	# sync
	sync
	# destroy decrypted backup files (optional)
	shred -v --iterations=3 --zero --remove=wipesync *
	cd ..
	rm -fr BACKUP
	#
	# umount backup partition
	cd
	umount /backup
	# deactivate volume group
	vgchange -a n vg
	# lock encryped luks partition
	cryptsetup close xyz-unlocked
	#
	#
	```
	
___



___ 