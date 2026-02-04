#!/bin/bash
#
# Backup UUID for swap partition or lvm
#
VG_NAME="vg"
SWAP_LVM="swap"
SWAP_DEV="/dev/mapper/${VG_NAME}-${SWAP_LVM}"
#
blkid -s UUID -o value "${SWAP_DEV}" > swap_UUID.txt
#
# Backup LUKS header
CRYPT="/dev/sda3"
cryptsetup luksHeaderBackup "${CRYPT}" --header-backup-file "luks_header.bin"
#
# Backup UUID for physical volume (pv)
#
PV_NAME="xyz-unlocked"
blkid -s UUID -o value "/dev/mapper/${PV_NAME}" > pv_UUID.txt
#
# Backup volue group configuration
#
vgcfgbackup -q -f vg_backup.txt "${VG_NAME}"
#
## BACKUP efibootmgr information
BOOTLOADER_ID="DCDebian"
efibootmgr | grep "${BOOTLOADER_ID}" > efibootmgr.txt
