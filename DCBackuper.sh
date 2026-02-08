#!/bin/bash
## Script usage function
#
function PrintUsage()
{
	echo "########################################################################################################################"
	echo "Pleae use: ./DCBackuper.sh 'operation'."
	echo "Posible value of operation are:"
	echo "a) backup - creating backup of partitions."
	echo "b) restore - restoring backup of partitions.", 
	echo "c) part-table-restore - restoring partition table configuration."
	echo "d) check - checking backup images files."
	echo "e) backup-luks-lvm" - backup luks and lvm information.
	echo "For example: "
	echo "./DCBackuper.sh restore"
	echo "########################################################################################################################"
}
######################################################################################################################################################
#
## Function for making backup.
#
function MakeBackup()
{
	## Creating backup directory
	#
	mkdir "${BACKUP_DIR}"
	touch "./${BACKUP_DIR}/files.txt"
	#
	for PART in "${!PARTITIONS[@]}"; 
	do
		echo "########################################################################################################################"
		PARTITION="${PART}"
		FILE_SYSTEM="${PARTITIONS[$PARTITION]}"
		echo "Creating backup for ${PARTITION} partition and ${FILE_SYSTEM} filesystem."
		PARTLABEL_DEV="/dev/disk/by-partlabel/${PARTITION}"
		if [[ -b "${PARTLABEL_DEV}" ]];
		then
			DEV_PATH=${PARTLABEL_DEV}
			echo "Device file for ${PARTITION} has been found based on PARTLABEL value."
		else
			LABEL_DEV="/dev/disk/by-label/${PARTITION}"
			if [[ -b "${LABEL_DEV}" ]];
			then
				DEV_PATH=${LABEL_DEV}
				echo "Device file for ${PARTITION} partition has been found based on LABEL value."
			else
				LVM_PATH="/dev/mapper/${PARTITION}"
				if [[ -b "${LVM_PATH}" ]];
				then
					DEV_PATH=${LVM_PATH}
					echo "Device file for ${PARTITION} partition has been found based on LVM name."
				else
					DEV_NAME_PATH="/dev/${PARTITION}"
					if [[ -b "${DEV_NAME_PATH}" ]];
					then
						DEV_PATH="${DEV_NAME_PATH}"
						echo "Device file for ${PARTITION} partition has been found based on device file name."
					else
						echo "Device file for ${PARTITION} partition has not been found (skipping)."
						continue
					fi
				fi
			fi
		fi
		FILE_NAME="$(echo ${PARTITION} | tr '[:upper:]' '[:lower:]').img.7z"
		FILE_PATH="./${BACKUP_DIR}/${FILE_NAME}"
		if [ -f "${FILE_PATH}" ];
		then
			echo "File ${FILE_NAME} exist in ${BACKUP_DIR} directory, skipping creation of backup file."
		else
			if [ "${FILE_SYSTEM}" = "raw" ];
			then
				echo "Creation 7-zip archive of raw image for ${PARTITION} partition."
				partclone.dd -s "${DEV_PATH}" -o - -z 20971520 -N  | 7z a -bd -t7z "${FILE_PATH}" -si -m0=lzma2 -mx=1 -mmt8 1>/dev/null
				
			else
				echo "Creation 7-zip archive of partclone image for ${PARTITION} partition."
				partclone.$FILE_SYSTEM -c -s "${DEV_PATH}" -o - -z 20971520 -N  | 7z a -bd -t7z "${FILE_PATH}" -si -m0=lzma2 -mx=1 -mmt8 >/dev/null
			fi
			if [[ -f ${FILE_PATH} ]];
			then
				echo "Backup file for ${PARTITION} partition has been created."
				sha256sum "${FILE_PATH}" >> "./${BACKUP_DIR}/files.txt"
			else
				echo "Creating backup file for ${PARTITION} failed."
			fi
		fi
	done
	#
	## BACKUP of GPT Partition tables
	## MAIN DISK
	#
	echo "########################################################################################################################"
	echo "Creating backup of partition table for main disk."
	#
	MAIN_BACKUP_PATH="./${BACKUP_DIR}/${MAIN_FILE}"
	if [ -b "${MAIN_DISK}" ] ;
		echo "Main disk device has been found."
	then
		if [ -f "${MAIN_BACKUP_PATH}" ] ;
		then
			echo "File ${MAIN_FILE} exist in ${BACKUP_DIR}, skipping creation of backup."
		else
			dd if=${MAIN_DISK} of="${MAIN_BACKUP_PATH}" bs=512 count=34 status=none && sync
			if [[ -f "${MAIN_BACKUP_PATH}" ]];
			then
				echo "Backup of partition table for main disk has been created."
				sha256sum "${MAIN_BACKUP_PATH}" >> "./${BACKUP_DIR}/files.txt"
			else
				echo "Backup of partition table for main disk has been failed."
			fi
		fi	
	else
		echo "Main disk device has not been found."
		echo "Partition table backup for main disk has not been created."
	fi
	#
	## SECOND DISK
	#
	echo "########################################################################################################################"
	echo "Creating backup of partition table for second disk"
	SECOND_BACKUP_PATH="./${BACKUP_DIR}/${SECOND_FILE}"
	#
	if [ -b "${SECOND_DISK}" ] ; 
	then
		echo "Second disk device has been found."
		if [ -f "${SECOND_BACKUP_PATH}" ] ;
		then
			echo "File ${SECOND_FILE} exist in ${BACKUP_DIR}, skipping creation of backup."
		else
			dd if=${SECOND_DISK} of="${SECOND_BACKUP_PATH}" bs=512 count=34 status=none && sync
			if [[ -f "${SECOND_BACKUP_PATH}" ]];
			then
				echo "Backup of partition table for second disk has been created."
				sha256sum "${SECOND_BACKUP_PATH}" >> "./${BACKUP_DIR}/files.txt"
			else
				echo "Backup of partition table for second disk has been failed"
			fi
		fi
	else
		echo "Second disk device has not been found."
		echo "Partition table backup for second disk has not been created."
	fi
	echo "########################################################################################################################"
	chown -R 1000:1000 "./${BACKUP_DIR}"
}
######################################################################################################################################################
#
## Function for read backup dir name
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
######################################################################################################################################################
## Function for restore backup
#
function RestoreBackup
{
	for PART in "${!PARTITIONS[@]}"; 
	do
		echo "########################################################################################################################"
		PARTITION="${PART}"
		FILE_SYSTEM="${PARTITIONS[$PARTITION]}"
		echo "Restoring ${PARTITION} partition with ${FILE_SYSTEM} filesystem."
		PARTLABEL_DEV="/dev/disk/by-partlabel/${PARTITION}"
		if [[ -b "${PARTLABEL_DEV}" ]];
		then
			DEV_PATH=${PARTLABEL_DEV}
			echo "Device file for ${PARTITION} partition has been found based on PARTLABEL value."
		else
			LABEL_DEV="/dev/disk/by-label/${PARTITION}"
			if [[ -b "${LABEL_DEV}" ]];
			then
				DEV_PATH=${LABEL_DEV}
				echo "Device file for ${PARTITION} partition has been found based on LABEL value."
			else
				LVM_PATH="/dev/mapper/${PARTITION}"
				if [[ -b "${LVM_PATH}" ]];
				then
					DEV_PATH=${LVM_PATH}
					echo "Device file for ${PARTITION} partition has been found based on LVM name."
				else
					DEV_NAME_PATH="/dev/${PARTITION}"
					if [[ -b "${DEV_NAME_PATH}" ]];
					then
						DEV_PATH="${DEV_NAME_PATH}"
                                        	echo "Device file for ${PARTITION} partition has been found based on device file name."
					else
						echo "Device file for ${PARTITION} partition has not been found (skipping)."
                                        	continue
					fi
				fi
			fi
		fi
		FILE_NAME="$(echo ${PARTITION} | tr '[:upper:]' '[:lower:]').img.7z"
		FILE_PATH="./${BACKUP_DIR}/${FILE_NAME}"
		#
		if [[ -f ${FILE_PATH} ]];
		then
			if [ "${FILE_SYSTEM}" = "raw" ];
			then
				echo "Restoring raw image for ${PARTITION} partition."
				7z x -bd -so "${FILE_PATH}" | partclone.dd -s - -o "${DEV_PATH}" -z 20971520 -N
			else
				echo "Restoring partclone image for ${PARTITION} partition with ${FILE_SYSTEM} filesystem."
				7z x -bd -so "${FILE_PATH}" | partclone.$FILE_SYSTEM -r -s - -o "${DEV_PATH}" -z 20971520 -N
			fi
		else
			echo "Backup file for $LABEL doesn't exists (skipping)."
			continue
		fi
	done
	echo "########################################################################################################################"
	#
}
######################################################################################################################################################
#
## Function for restore of partition table from backup file.
#
function PartTableRestore
{
	MAIN_BACKUP_PATH="./${BACKUP_DIR}/${MAIN_FILE}"
	SECOND_BACKUP_PATH="./${BACKUP_DIR}/${SECOND_FILE}"
	echo "########################################################################################################################"
	echo "Attempt of restoring partition table for main disk."
	if [ -f "${MAIN_BACKUP_PATH}" ] && [ -b "${MAIN_DISK}" ] ; 
	then
	    echo "Device and backup file found."
	    TMP=$(lsblk -d -n -o PTTYPE "${MAIN_DISK}")
	    if [ -z "${TMP}" ] ;
	    then
		echo "No existing partition table has been found on main disk device."
		echo "Restoring partition table for main device."
		dd if="${MAIN_BACKUP_PATH}" of="${MAIN_DISK}" bs=512 status=none && sync
		echo "Fixing backup partition table ( re-creating backup partition table )."
		sgdisk -e "${MAIN_DISK}" >/dev/null 2>&1
		echo "Verification."
		sgdisk -v "${MAIN_DISK}"
	    else
		echo "There has been found previous partition table (${TMP})"
		echo "Skipping"
	    fi
	else
	    echo "Device or backup file does not exist."
	fi
	##
	echo "########################################################################################################################"
	echo "Attempt of restoring partition table for second disk"
	if [ -f "${SECOND_BACKUP_PATH}" ] && [ -b "${SECOND_DISK}" ] ; 
	then
	    echo "Device and backup file found."
	    TMP=$(lsblk -d -n -o PTTYPE "${SECOND_DISK}")
	    if [ -z "${TMP}" ] ;
	    then
		echo "No existing partition table has been found on second disk device."
		echo "Restoring partition table for second device"
		dd if="${SECOND_BACKUP_PATH}" of="${SECOND_DISK}" bs=512 status=none && sync
		echo "Fixing backup partition table ( re-creating backup partition table )"
		sgdisk -e "${SECOND_DISK}" >/dev/null 2>&1
		echo "Verification"
		sgdisk -v "${SECOND_DISK}"
	    else
		echo "There has been found previous partition table (${TMP})"
		echo "Skipping"
	    fi
	else
	    echo "Device or backup file does not exist"
	fi
	echo "########################################################################################################################"
}
######################################################################################################################################################
#
## Function for checking images
#
function CheckImage()
{
	for PART in "${!PARTITIONS[@]}"; 
	do
		echo "########################################################################################################################"
		PARTITION="${PART}"
		FILE_SYSTEM="${PARTITIONS[$PARTITION]}"
		echo "Checking partition image file for ${PARTITION} and ${FILE_SYSTEM} filesystem."
		FILE_NAME="$(echo ${PARTITION} | tr '[:upper:]' '[:lower:]').img.7z"
		FILE_PATH="./${BACKUP_DIR}/${FILE_NAME}"
		if [[ -f ${FILE_PATH} ]];
		then	
			echo "Checking integrity of 7zip archive."
			7z t "${FILE_PATH}" 1>/dev/null
			if [[ $? -eq 0 ]];
			then
				echo "No errors found for ${FILE_NAME} archive." 
			else
				echo "Checking integrity of ${FILE_NAME} has been failed."
			fi
			echo "Checking image file with partclone.chkimg"
			if [ "${FILE_SYSTEM}" = "raw" ];
			then
				echo "Archive ${FILE_NAME} does not contain partclone image."
				echo "Checking image file is not possible."
			else
				7z x -bd -so "${FILE_PATH}" | partclone.chkimg -s - -N
			fi
		else
			echo "Backup ${FILE_NAME} file doesn't exists (skipping)."
			continue
		fi
	done
	echo "########################################################################################################################"
}
######################################################################################################################################################
## Function for creating backup luks and lvm information
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
## Main progam
#
## Sourcing config file.
#
CONFIG_FILE="DCBackuper.conf"
# CONFIG_FILE="Linux.conf"
#
if [[ -f "./${CONFIG_FILE}" ]];
then
	source "./${CONFIG_FILE}"
else
	echo "Config file has not been found."
	echo "Make sure that proper config file exist in directory where script is located."
	exit 1
fi
##
echo "########################################################################################################################"
if [[ $# -eq 1 ]];
then
	case $1 in
		"backup")
			echo "Creating Backup."
			MakeBackup
			;;

		"restore")
			echo "Restoring backup."
			BACKUP_DIR=""
			BackupDirRead
			RestoreBackup
			;;

		"part-table-restore")
			echo "part-table-restore"
			BACKUP_DIR=""
			BackupDirRead
			PartTableRestore
			;;

		"check")
			echo "Checking backup image files."
			BACKUP_DIR=""
			BackupDirRead
			CheckImage
			;;

		"backup-luks-lvm")
			echo "Creating backup of luks and lvm information"
			BACKUP_DIR=""
			BackupDirRead
			MakeBackupLuksLVM
			;;

		*)
			echo "Invalid script argument."
			PrintUsage
			;;

	esac

elif [[ $#  -gt 1 ]];
then
	echo "To many script arguments."
	PrintUsage
else
	echo "You did not specify script argument."
	PrintUsage
fi
#
######################################################################################################################################################
