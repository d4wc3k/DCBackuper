#!/bin/bash
#
######################################################################################################################################################
## Config variables
#
## Partitions for backup, use PARTLABEL, LABEL, LVM name, device name, PARTUUID, UUID
PARTITIONS=("EFI" "WINMSR" "WINOS" "WINREC" "WINDATA" )
#
## First disk device file
FIRST_DISK="/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNF0M910268J"
## Backup file name for partition table backup of first disk
FIRST_PTABLE_BACKUP_FILE="first_ptable_backup.bin"
#
## Second disk device file
SECOND_DISK="/dev/disk/by-id/nvme-Samsung_SSD_980_1TB_S649NJ0R214022Y"
## Backup file name for partition table backup of first disk
SECOND_PTABLE_BACKUP_FILE="second_ptable_backup.bin"
#
## compression for newly created backup files: 7-zip or rar
# COMPRESSION="7-zip"
COMPRESSION="rar"
#
## Standalone compression tools configuration
# Uncomment in order to use standalone version of 7-zip or rar
# RAR_STANDALONE="./rar/rar"
# SEVEN_ZIP_STANDALONE="./7-zip/7zz"
#
## BACKUP folder name
BACKUP_DIR="$(date +%Y_%m_%d_%H_%M)_WIN_SNAPSHOT_${COMPRESSION}"
#
## Parameter for number of threads used by compression.
## default value is 4 threads
THREADS="12"
#
## 7 Zip compression levels
# Possible values: 
# 0 - store, 1 - fastest, 3 - fast, 5 - normal (default), 7 - maximum, 9 - ultra
SEVEN_COMP_LEVEL="1"
#
## rar compression levels
# Possible values: 
# 0 - store, 1 - fastest, 2 - fast, 3 - normal (default), 4 - good, 5 - best
RAR_COMP_LEVEL="1"
#
## rar percentage amount of recovery record
## default selected value is 10 %
## use 0 in order to disable adding recovery record to archive
RAR_RECOVERY_PERC="20"
#
######################################################################################################################################################
#
## Script usage function
#
function PrintUsage()
{
	echo "########################################################################################################################"
	echo "Please use: ./DCBackuper.sh 'operation'."
	echo "Possible value of operation are:"
	echo "a) backup - creating backup of partitions."
	echo "b) restore - restoring backup of partitions.", 
	echo "c) check - checking backup images files."
	echo "For example: "
	echo "./DCBackuper.sh restore"
	echo "########################################################################################################################"
}
#
######################################################################################################################################################
## Function for getting device file based on PARTUUID/UUID/LABEL/PARTLABEL/LVM NAME/DEVICE NAME 
#
function GetDeviceFile()
{	
	PARTITION=$1
	PARTUUID_DEV="/dev/disk/by-partuuid/${PARTITION}"
	if [[ -b "${PARTUUID_DEV}" ]];
	then
		DEV_PATH="${PARTUUID_DEV}"
	else
		UUID_DEV="/dev/disk/by-uuid/${PARTITION}"
		if [[ -b "${UUID_DEV}" ]];
		then
			DEV_PATH="${UUID_DEV}"
		else
			PARTLABEL_DEV="/dev/disk/by-partlabel/${PARTITION}"
			if [[ -b "${PARTLABEL_DEV}" ]];
			then
				DEV_PATH="${PARTLABEL_DEV}"
			else
				LABEL_DEV="/dev/disk/by-label/${PARTITION}"
				if [[ -b "${LABEL_DEV}" ]];
				then
					DEV_PATH="${LABEL_DEV}"
				else
					LVM_PATH="/dev/mapper/${PARTITION}"
					if [[ -b "${LVM_PATH}" ]];
					then
						DEV_PATH="${LVM_PATH}"
					else
						DEV_NAME_PATH="/dev/${PARTITION}"
						if [[ -b "${DEV_NAME_PATH}" ]];
						then
							DEV_PATH="${DEV_NAME_PATH}"
						else
							DEV_PATH="none"
						fi
					fi
				fi
			fi
		fi
	fi
	echo ${DEV_PATH}
}
######################################################################################################################################################
#
## Function for making partitions backup 
#
function MakePartitionsBackup()
{	
	echo "########################################################################################################################"
	mkdir "${BACKUP_DIR}"
	touch "./${BACKUP_DIR}/files.txt"
	#
	for PART in ${PARTITIONS[@]}; 
	do
		echo "Processing ${PART} partition."
		DEVICE_FILE=$(GetDeviceFile "${PART}" )
		if [[ "${DEVICE_FILE}" = "none" ]];
		then
			echo "Device file for ${PART} partition has not been found."
			echo "Skipping creating backup file."
			continue
		else
			echo "Device file for ${PART} partition has been found"
			echo "Device file: ${DEVICE_FILE}"
			FILESYSTEM=$(blkid -s TYPE -o value "${DEVICE_FILE}")
			FILESYSTEM="${FILESYSTEM:-none}"
			echo "File system: ${FILESYSTEM}"
			if [[ "${COMPRESSION}" = "7-zip" ]];
			then
				BACKUP_FILE_NAME="${PART}_${FILESYSTEM}.img.7z"
			else
				BACKUP_FILE_NAME="${PART}_${FILESYSTEM}.img.rar"
			fi
			BACKUP_FILE="./${BACKUP_DIR}/${BACKUP_FILE_NAME}"
			if [[ -f "${BACKUP_FILE}" ]];
			then
				echo "File ${BACKUP_FILE_NAME} exist in ${BACKUP_DIR} directory, skipping creation of backup file."
			else			
				if [[ "${COMPRESSION}" = "7-zip" ]];
				then
					if [[ "${FILESYSTEM}" = "none" || "${FILESYSTEM}" = "swap" ]];
					then
						echo "Creation 7-zip archive of raw image for ${PART} partition."
						partclone.dd -s "${DEVICE_FILE}" -o - -z 10485760 -N  | "${SEVEN_ZIP_COMMAND}" a -bd -t7z "${BACKUP_FILE}" -si -mx"${SEVEN_COMP_LEVEL}" -mmt"${THREADS}" 1>/dev/null
					else
						echo "Creation 7-zip archive of partclone image for ${PART} partition."
						partclone."${FILESYSTEM}" -c -s "${DEVICE_FILE}" -o - -z 10485760 -N  | "${SEVEN_ZIP_COMMAND}" a -bd -t7z "${BACKUP_FILE}" -si -mx"${SEVEN_COMP_LEVEL}" -mmt"${THREADS}" 1>/dev/null
					fi

				else
					if [[ "${FILESYSTEM}" = "none" || "${FILESYSTEM}" = "swap" ]];
					then
						echo "Creation rar archive of raw image for ${PART} partition."
						partclone.dd -s "${DEVICE_FILE}" -o - -z 10485760 -N | "${RAR_COMMAND}" a -idq -k -m"${RAR_COMP_LEVEL}" -mt"${THREADS}" -rr"${RAR_RECOVERY_PERC}" -si"${PART}_${FILESYSTEM}.img" "${BACKUP_FILE}"
					else
						echo "Creation rar archive of partclone image for ${PART} partition."
						partclone."${FILESYSTEM}" -c -s "${DEVICE_FILE}" -o - -z 10485760 -N | "${RAR_COMMAND}" a -idq -k -m"${RAR_COMP_LEVEL}" -mt"${THREADS}" -rr"${RAR_RECOVERY_PERC}" -si"${PART}_${FILESYSTEM}.img" "${BACKUP_FILE}"
					fi
				fi			
				if [[ -f "${BACKUP_FILE}" ]];
				then
					echo "Backup file for ${PART} partition has been created."
					echo "Backup file name: ${BACKUP_FILE_NAME}"
					sha256sum "${BACKUP_FILE}" >> "./${BACKUP_DIR}/files.txt"
				else
					echo "Creating backup file for ${PART} failed."
				fi
			fi
		fi
		echo "########################################################################################################################"
	done
	echo "########################################################################################################################"
}
#
######################################################################################################################################################
#
## Function for making backup of partition table based on two parameters
## a) device file
## b) backup file name
function MakePartitionTableBackup()
{
	DEVICE="$1"
	echo "Disk device file: ${DEVICE}"
	FILE_NAME="$2"
	echo "Target backup file name: ${FILE_NAME}"
	BACKUP_FILE="./${BACKUP_DIR}/${FILE_NAME}"
	#
	if [[ -b "${DEVICE}" ]];
	then
		echo "Device file for disk has been found."
		if [[ -f "${BACKUP_FILE}" ]];
		then
			echo "File ${FILE_NAME} exist in ${BACKUP_DIR}, skipping creation of backup."
		else
			TMP=$(lsblk -d -n -o PTTYPE "${DEVICE}")
			if [[ "${TMP}" = "gpt" ]];
			then
				echo "GPT partition table has been found on device."
				dd if="${DEVICE}" of="${BACKUP_FILE}" bs=512 count=34 status=none && sync
				if [[ -f "${BACKUP_FILE}" && $? -eq 0 ]];
				then
					echo "Backup of partition table for disk has been created."
					sha256sum "${BACKUP_FILE}" >> "./${BACKUP_DIR}/files.txt"
				else
					echo "Backup of partition table for main disk has been failed."
				fi
			else
				echo "GPT partition table has not been found on device."
				echo "Skipping creation of backup"
			fi
		fi
	else
		echo "Device file for disk has not been found."
		echo "Skipping creation of backup"
	fi
	echo "########################################################################################################################"
}
#
######################################################################################################################################################
#
## Function for reading Backup Directory
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
	echo "########################################################################################################################"
}
#
######################################################################################################################################################
#
## Function for restoring partition table for singe device based on 2 parameters
## a) device file
## b) backup file name
#
function RestorePartitionTable
{
	DEVICE="$1"
	echo "Disk device file: ${DEVICE}"
	FILE_NAME="$2"
	BACKUP_FILE="./${BACKUP_DIR}/${FILE_NAME}"
	if [[ -b "${DEVICE}" ]];
	then
		echo "Device file for disk has been found."
		TMP=$(lsblk -d -n -o PTTYPE "${DEVICE}")
		if [[ "${TMP}" = "gpt" ]];
		then
			echo "Existing GPT partition table has been found on device."
			echo "Skipping restoring."
		else
			if [[ -f "${BACKUP_FILE}" ]];
			then	
				echo "Backup File ${FILE_NAME} has been found in ${BACKUP_DIR} directory."
				dd if="${BACKUP_FILE}" of="${DEVICE}" bs=512 status=none && sync
				if [[ $? -eq 0 ]];
				then
					echo "Restoring partition table has been done"
					echo "Fixing backup partition table ( re-creating backup partition table )."
					sgdisk -e "${DEVICE}" >/dev/null 2>&1
					if [[ $? -eq 0 ]];
					then
						echo "Verification: "
						sgdisk -v "${DEVICE}"
					else
						echo "Fixing operation failed."
					fi
				else
					echo "Restoring partition table failed."
				fi
			else
				echo "Backup File ${FILE_NAME} has not been found in ${BACKUP_DIR} directory."
				echo "Skipping restoring."
			fi
		fi
	else
		echo "Device file for disk has not been found."
		echo "Skipping restoring."
	fi
	echo "########################################################################################################################"
}
#
######################################################################################################################################################
#
## Function for restoring partitions from image files 
#
function RestorePartitions
{
	IMAGE_FILES=$(ls ./${BACKUP_DIR}/*.img.* | xargs -n 1 basename | tr '\n' ' ')
	for BACKUP_FILE_NAME in ${IMAGE_FILES[@]};
	do
		echo "Restoring from ${BACKUP_FILE_NAME} backup file."
		BACKUP_FILE="./${BACKUP_DIR}/${BACKUP_FILE_NAME}"
		PART=$(echo "${BACKUP_FILE_NAME}" | cut -d "." -f 1 | cut -d "_" -f 1)
		FILESYSTEM=$(echo "${BACKUP_FILE_NAME}" | cut -d "." -f 1 | cut -d "_" -f 2)
		EXTENSION=$(file -b --extension "${BACKUP_FILE}")
		DEVICE_FILE=$(GetDeviceFile "${PART}" )
                if [[ "${DEVICE_FILE}" = "none" ]];
		then
			echo "Device file for ${BACKUP_FILE_NAME} backup has not been found."
                	echo "Skipping restoring from backup file."
			echo "########################################################################################################################"
                	continue
		else
			echo "Device file for ${BACKUP_FILE_NAME} backup has been found."
			if [[ "${EXTENSION}" = "7z/cb7" ]];
			then
				if ! command -v "${SEVEN_ZIP_COMMAND}"  >/dev/null 2>&1;
				then
					echo "Error, 7-zip compression has not been found."
					echo "########################################################################################################################"
					break
				fi
				if [[ "${FILESYSTEM}" = "none" || "${FILESYSTEM}" = "swap" ]];
                		then
					echo "Restoring raw image from ${BACKUP_FILE_NAME} backup file"
					"${SEVEN_ZIP_COMMAND}" x -bd -so "${BACKUP_FILE}" | partclone.dd -s - -o "${DEVICE_FILE}" -z 10485760 -N
                		else
					echo "Restoring partclone image from ${BACKUP_FILE_NAME} backup file (FILE SYSTEM: ${FILESYSTEM})."
					"${SEVEN_ZIP_COMMAND}" x -bd -so "${BACKUP_FILE}" | partclone."${FILESYSTEM}" -r -s - -o "${DEVICE_FILE}" -z 10485760 -N
                		fi
			elif [[ "${EXTENSION}" = "rar" ]];
			then
				if ! command -v "${RAR_COMMAND}"  >/dev/null 2>&1;
				then
					echo "Error, rar compression has not been found."
					echo "########################################################################################################################"
					break
				fi
				if [[ "${FILESYSTEM}" = "none" || "${FILESYSTEM}" = "swap" ]];
                		then
					echo "Restoring raw image from ${BACKUP_FILE_NAME} backup file"
					"${RAR_COMMAND}" p "${BACKUP_FILE}" | partclone.dd -s - -o "${DEVICE_FILE}" -z 10485760 -N
                		else
					echo "Restoring partclone image from ${BACKUP_FILE_NAME} backup file (FILE SYSTEM: ${FILESYSTEM})."
					"${RAR_COMMAND}" p "${BACKUP_FILE}" | partclone."${FILESYSTEM}" -r -s - -o "${DEVICE_FILE}" -z 10485760 -N
                		fi
			else
				echo "Error ${BACKUP_FILE_NAME} backup file is not rar or 7-zip archive."
			fi
		fi
		echo "########################################################################################################################"
	done
}
#
######################################################################################################################################################
#
## Function for checking backup files.
#
function CheckImages
{
	IMAGE_FILES=$(ls ./${BACKUP_DIR}/*.img.* | xargs -n 1 basename | tr '\n' ' ')
	for BACKUP_FILE_NAME in ${IMAGE_FILES[@]};
	do
		echo "########################################################################################################################"
		echo "Checking ${BACKUP_FILE_NAME} file."
		BACKUP_FILE="./${BACKUP_DIR}/${BACKUP_FILE_NAME}"
		FILESYSTEM=$(echo "${BACKUP_FILE_NAME}" | cut -d "." -f 1 | cut -d "_" -f 2)
 		EXTENSION=$(file -b --extension "${BACKUP_FILE}")
		#
		if [[ "${EXTENSION}" = "7z/cb7" ]];
		then
			if ! command -v "${SEVEN_ZIP_COMMAND}"  >/dev/null 2>&1;
			then
				echo "Error, 7-zip compression has not been found."
				echo "########################################################################################################################"
				break
			fi
			echo "Checking integrity of 7zip archive."
			"${SEVEN_ZIP_COMMAND}" t "${BACKUP_FILE}" 1>/dev/null
			if [[ $? -eq 0 ]];
			then
				echo "No errors found for ${BACKUP_FILE_NAME} archive during integrity check."
				echo "Checking image file with 'partclone.chkimg' tool."
				if [[ "${FILESYSTEM}" = "none" || "${FILESYSTEM}" = "swap" ]];
				then
					echo "Archive ${BACKUP_FILE_NAME} does not contain partclone image."
					echo "Checking image file is not possible."
				else
					"${SEVEN_ZIP_COMMAND}" x -bd -so "${BACKUP_FILE}" | partclone.chkimg -s - -N
				fi
			else
				echo "Checking integrity of ${BACKUP_FILE_NAME} has been failed."
			fi
		elif [[ "${EXTENSION}" = "rar" ]];
		then
			if ! command -v "${RAR_COMMAND}"  >/dev/null 2>&1;
			then
				echo "Error, rar compression has not been found."
				echo "########################################################################################################################"
				break
			fi
			echo "Checking integrity of rar archive."
			"${RAR_COMMAND}" t "${BACKUP_FILE}" 1>/dev/null 
			if [[ $? -eq 0 ]];
			then
				echo "No errors found for ${BACKUP_FILE_NAME} archive during integrity check."
				echo "Checking image file with 'partclone.chkimg' tool"
				if [[ "${FILESYSTEM}" = "none" || "${FILESYSTEM}" = "swap" ]];
				then
					echo "Archive ${BACKUP_FILE_NAME} does not contain partclone image."
					echo "Checking image file is not possible."
				else
					"${RAR_COMMAND}" p "${BACKUP_FILE}" | partclone.chkimg -s - -N
				fi
			else
				echo "Checking integrity of ${BACKUP_FILE_NAME} has been failed."
			fi
		else
			echo "Error ${BACKUP_FILE_NAME} backup file is not rar or 7-zip archive."
		fi
	done
	echo "########################################################################################################################"
}
#
######################################################################################################################################################
#
## Main Program
#
echo "########################################################################################################################"
#
## Checking for standalone version of rar compression tool
#
if [[ -x "${RAR_STANDALONE}" ]];
then
	RAR_COMMAND="${RAR_STANDALONE}"
else
	RAR_COMMAND="rar"
fi
#
## Checking for standalone version of 7-zip compression tool
#
if [[ -x "${SEVEN_ZIP_STANDALONE}" ]];
then
	SEVEN_ZIP_COMMAND="${SEVEN_ZIP_STANDALONE}"
else
	SEVEN_ZIP_COMMAND="7z"
fi
#
## Checking if all needed tools are available
#
REQUIRED_COMMANDS=( "sgdisk" "partclone.chkimg")
#
if [[ "${COMPRESSION}" = "7-zip" ]];
then
	SEVEN_COMP_LEVEL="${SEVEN_COMP_LEVEL:-5}"
	REQUIRED_COMMANDS=( ${REQUIRED_COMMANDS[@]} "${SEVEN_ZIP_COMMAND}" )

elif [[ "${COMPRESSION}" = "rar" ]];
then
	RAR_COMP_LEVEL="${RAR_COMP_LEVEL:-3}"
	RAR_RECOVERY_PERC="${RAR_RECOVERY_PERC:-10}"
	REQUIRED_COMMANDS=( ${REQUIRED_COMMANDS[@]} "${RAR_COMMAND}" )
else
	echo "Invalid compression option set, please check it and correct."
	echo "Allowed value: 'rar' or '7-zip'."
	exit 1
fi
#
echo "Checking for required tools."
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "Not all required tools are available."
	echo "Make sure that partclone, gdisk, 7-zip/rar are installed."
	echo "########################################################################################################################"
        exit 1
    fi
done
echo "All required tools are available."
echo "########################################################################################################################"
#
if [[ $# -eq 1 ]];
then
	case $1 in
		"backup")
			THREADS="${THREADS:-4}"
			echo "Creating Backup."
			echo "Selected compression tool: ${COMPRESSION}."
			MakePartitionsBackup
			# Backup of partition table for first disk
			echo "Creating partition table backup for first disk"
			MakePartitionTableBackup "${FIRST_DISK}" "${FIRST_PTABLE_BACKUP_FILE}"
			# Backup of partition table for second disk
			echo "Creating partition table backup for first disk"
		 	MakePartitionTableBackup "${SECOND_DISK}" "${SECOND_PTABLE_BACKUP_FILE}"
			chown -R 1000:1000 "${BACKUP_DIR}"
			;;

		"restore")
			echo "Restoring backup."
			BACKUP_DIR=""
			BackupDirRead
			# Restoring partition table for first disk
			echo "Restoring partition table for first disk"
			RestorePartitionTable "${FIRST_DISK}" "${FIRST_PTABLE_BACKUP_FILE}"
			# Restoring partition table for second disk
			echo "Restoring partition table for second disk"
			RestorePartitionTable "${SECOND_DISK}" "${SECOND_PTABLE_BACKUP_FILE}"
			RestorePartitions
			;;

		"check")
			echo "Checking backup image files."
			BACKUP_DIR=""
			BackupDirRead
			CheckImages
			;;

		*)
			echo "Invalid script argument."
			PrintUsage
			;;

	esac

elif [[ $#  -gt 1 ]];
then
	echo "Too many script arguments."
	PrintUsage
else
	echo "You did not specify script argument."
	PrintUsage
fi
#
######################################################################################################################################################
