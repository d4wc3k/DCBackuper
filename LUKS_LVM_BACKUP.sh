#!/bin/bash
#
######################################################################################################################################################
## LUKS/LVM backup Parameteres
#
## LUKS Header
CRYPT_DEV="/dev/sda3"
LUKS_HEADER_FILE="luks_header"
## LVM phisical volume device
PV_DEV="/dev/mapper/crypt"
PV_FILE="pv_UUID.txt"
## SWAP
SWAP_DEV="/dev/mapper/vg-swap"
SWAP_UUID="swap_UUID.txt"
## Volume group
VG_NAME="vg"
VG_FILE="vg_backup.txt"
## GRUB Loader
GRUB_ID="DEBIAN"
GRUB_BACKUP="efibootmgr.txt"
#
######################################################################################################################################################
#
## Function for reading backup directory
#
function BackupDirRead
{
	echo "########################################################################################################################"
	DIR_NAME_NEEDS_TO_BE_SET=true
	while $DIR_NAME_NEEDS_TO_BE_SET
	do
		read -e -p "Enter backup directory name: " BACKUP_DIR
		if [[ -d "./${BACKUP_DIR}" ]];
		then
			echo "Backup directory was found."
			DIR_NAME_NEEDS_TO_BE_SET=false
		else
			echo "Backup directory has not been found, please try again."
			echo "Following potential backup directories could be found in current folder: "
			ls -l . | grep ^d | awk '{print $9}'
		fi
	done
}
#
######################################################################################################################################################
#
## Function for creating backup files for LUKS/LVM
#
function MakeBackupLuksLVM
{
	echo "########################################################################################################################"
	# LUKS header backup
	echo "Backup LUKS header."
	if [[ -b "${CRYPT_DEV}" ]];
	then
		echo "Encrypted device file has been found."
		TMP=$(blkid -s TYPE -o value "${CRYPT_DEV}")
		if [[ ${TMP} == "crypto_LUKS" ]];
		then
			echo "Defined partition is valid LUKS device"
			cryptsetup luksHeaderBackup "${CRYPT_DEV}" --header-backup-file "./${BACKUP_DIR}/${LUKS_HEADER_FILE}"
			if [[ -f "./${BACKUP_DIR}/${LUKS_HEADER_FILE}" ]];
			then
				echo "LUKS Header backup file has been created."
				sha256sum "./${BACKUP_DIR}/${LUKS_HEADER_FILE}" >> "./${BACKUP_DIR}/files.txt"
			else
				echo "LUKS Header backup file has not been created."
			fi
		else
			echo "Defined partition is not valid LUKS device - skipping."
		fi
	else
		echo "Encrypted device file has not been found - skipping."
	fi
	#
	##
	echo "########################################################################################################################"
	echo "Backup of information about phisical volume (PV)."
	if [[ -b ${PV_DEV} ]];
	then
		echo "Phisical volume device has been found."
		TMP=$(blkid -s TYPE -o value "${PV_DEV}")
		if [[ "${TMP}" == "LVM2_member" ]];
		then
			echo "Defined device is valid LVM2 member."
			blkid -s UUID -o value "${PV_DEV}" > "./${BACKUP_DIR}/${PV_FILE}"
			if [[ -f "./${BACKUP_DIR}/${PV_FILE}" ]];
			then
				echo "Backup file for physical volume information has been created."
				sha256sum "./${BACKUP_DIR}/${PV_FILE}" >> "./${BACKUP_DIR}/files.txt"
			else
				echo "Backup file for physical volume information has not been created."
			fi
		else
			echo "Defined device is not valid LVM2 member - skipping."
		fi
	else
		echo "Phisical volume device has not been found - skipping."
	fi
	echo "########################################################################################################################"
	echo "Backup of swap UUID"
	if [[ -b ${SWAP_DEV} ]];
	then
		echo "Swap device has been found."
		TMP=$(blkid -s TYPE -o value "${SWAP_DEV}")
		if [[ "${TMP}" == "swap" ]];
		then
			echo "Defined device is valid swap device."
			blkid -s UUID -o value "${SWAP_DEV}" > "./${BACKUP_DIR}/${SWAP_UUID}"
			if [[ -f "./${BACKUP_DIR}/${SWAP_UUID}" ]];
			then
				echo "Backup file with UUID of swap has been created."
				sha256sum "./${BACKUP_DIR}/${SWAP_UUID}" >> "./${BACKUP_DIR}/files.txt"
			else
				echo "Backup file with UUID of swap has not been created."
			fi
		else
			echo "Defined device is not formatted as swap  - skipping."
		fi
	else
		echo "Swap device has not been found - skipping."
	fi
	echo "########################################################################################################################"
	echo "Backup information about LVM voloume group."
	vgcfgbackup -q -f "./${BACKUP_DIR}/${VG_FILE}" "${VG_NAME}"
	if [[ -f "./${BACKUP_DIR}/${VG_FILE}" ]];
	then
		echo "Backup file for LVM group information has been created."
		sha256sum "./${BACKUP_DIR}/${VG_FILE}" >> "./${BACKUP_DIR}/files.txt"
	else
		echo "Backup file for LVM group information has been created."
	fi
	echo "########################################################################################################################"
	echo "Backup information about GRUB bootloader."
	efibootmgr -v | grep "${GRUB_ID}" > "./${BACKUP_DIR}/${GRUB_BACKUP}"
	if [[ -f "./${BACKUP_DIR}/${GRUB_BACKUP}" ]];
	then
		echo "Backup file for GRUB loader information has been created."
		sha256sum "./${BACKUP_DIR}/${GRUB_BACKUP}" >> "./${BACKUP_DIR}/files.txt"
	else
		echo "Backup file for GRUB loader information has not been created."
	fi
	echo "########################################################################################################################"
}
######################################################################################################################################################
#
## Main Program
#
BACKUP_DIR=""
BackupDirRead
MakeBackupLuksLVM
#
######################################################################################################################################################
