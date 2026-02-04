___

- ## Install required packages

	```bash
	#
	# update package database
	apt update
	# install packages
	apt install partclone pigz gdisk rar unrar
	#
	```

___

- ## Prepare target location

  	```bash
	#
	# create dir for mount point
	mkdir -p /backup
	# mount backup partition
	mount /dev/sda1 /backup/
	# prepare target dir
	cd /backup
	mkdir BACKUP
	cd BACKUP
	#
	```

___

- ## Unlock encrypted luks partition

	```bash
	#
	cryptsetup open /dev/sdb3 xyz-unlocked
	#
	```
___

- ## Make partitions backup with partclone

	```bash
	#
	# root partition
	partclone.ext4 -z 10485760 -c -s /dev/mapper/vg-root --output - | pigz -c --fast -b 1024 --rsyncable > root.img.gz
	#
	# boot partition
	partclone.ext2 -z 10485760 -c -s /dev/sdb2 --output - | pigz -c --fast -b 1024 --rsyncable > boot.img.gz
	#
	# efi partition
	partclone.vfat -z 10485760 -c -s /dev/sdb1 --output - | pigz -c --fast -b 1024 --rsyncable > efi.img.gz
	#
	# home partition
	partclone.ext4 -z 10485760 -c -s /dev/mapper/vg-home --output - | pigz -c --fast -b 1024 --rsyncable > home.img.gz
	#
	```

___

- ## Backup partition table with dd util

	```bash
	#
	DISK="/dev/sdb"
	dd if=${DISK} of="part_table.bin" bs=512 count=34 status=progress && sync
	#
	```

___

- ## Backup swap UUID

	```bash
	#
	blkid -s UUID -o value /dev/mapper/vg-swap > swap_UUID.txt
	#
	```

___

- ## Backup luks header

	```bash
	#
	CRYPT="/dev/sdb3"
	cryptsetup luksHeaderBackup "${CRYPT}" --header-backup-file "luks_header.bin"
	#
	```

___

- ## Backup UUID for physical volume (pv)

	```bash
	#
	blkid -s UUID -o value /dev/mapper/xyz-unlocked > pv_UUID.txt
	#
	```
  
____

- ## Backup volue group configuration

	```bash
	#
	vgcfgbackup -f vg_backup.txt vg
	#
	```

___

- ## encrypt backup with rar (optional)

	```bash
	# go to mount point directory
	cd /backup
	# create encrypted rar archive
	THREAD=$(nproc)
	rar a -k -m1 -md32m -mt${THREAD} -rr20 -hp BACKUP.rar BACKUP/
	#
	# test archive
	rar t BACKUP.rar
	# 
	# clean data with shred
	cd BACKUP
	shred -v --iterations=3 --zero --remove=wipesync *
	cd ..
	rm -fr BACKUP
	#
	```


____

- ## Finish things

	```bash
	#
	# umount backup partition
	cd
	umount /backup
	# deactivate volume group
	vgchange -a n vg
	# lock encryped luks partition
	cryptsetup close xyz-unlocked
	#
	```


___