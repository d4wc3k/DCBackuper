#!/bin/bash
#
##
######################################################################################################################################################
#
## Definition of partitions for backup operation
## PARTLABEL
#
declare -A PARTITIONS=(["EFI"]="vfat" ["WINMSR"]="raw" ["WINOS"]="ntfs" ["WINREC"]="ntfs" ["WINDATA"]="ntfs" )
# declare -A PARTITIONS=(["EFI"]="vfat" ["WINMSR"]="raw" ["WINOS"]="ntfs" ["WINREC"]="ntfs")
#
## PARTLABEL + LABEL
# declare -A PARTITIONS=(["EFI"]="vfat" ["WINMSR"]="raw" ["WinOS"]="ntfs" ["WinRec"]="ntfs" ["WinData"]="ntfs" )
#
## PARTLABEL + LABEL + lvm names
# declare -A PARTITIONS=(["EFI"]="vfat" ["BootFs"]="ext2" ["vg-root"]="ext4" ["vg-home"]="ext4" )
#
######################################################################################################################################################
#
## Devices files paths
#
## MAIN
# MAIN_DISK="/dev/sda"
# MAIN_DISK="/dev/nvme0n1"
MAIN_DISK="/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNF0M910268J"
#
## SECOND
# SECOND_DISK="/dev/sdb"
# SECOND_DISK="/dev/nvme0n2p1"
SECOND_DISK="/dev/disk/by-id/nvme-Samsung_SSD_980_1TB_S649NJ0R214022Y"
#
######################################################################################################################################################
#
## BACKUP folder name
# BACKUP_DIR="$(date +%Y_%m_%d_%H_%M)_WIN_CLEAN/BASIC"
BACKUP_DIR="$(date +%Y_%m_%d_%H_%M)_WIN_SNAPSHOT"
#
######################################################################################################################################################
#
## Script usage function
#
function PrintUsage()
{
	echo "########################################################################################################################"
	echo "Pleae use: ./DCBackuper.sh 'operation'."
	echo "Posible value of operation are:"
	echo "a) backup - creating backup"
	echo "b) restore - restoring backup", 
	echo "c) part-table-restore - restoring partition table configuration"
	echo "d) check - checking backup images files"
	echo "For example: ./DCBackuper.sh restore"
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
		LABEL="${PART}"
		FILE_SYSTEM="${PARTITIONS[$LABEL]}"
		echo "Processing partition with ${LABEL} label and ${FILE_SYSTEM} filesystem."
		PARTLABEL_DEV="/dev/disk/by-partlabel/${LABEL}"
		if [[ -h "${PARTLABEL_DEV}" ]];
		then
			DEV_PATH=${PARTLABEL_DEV}
			echo "Device file for ${LABEL} label has been found."
		else
			LABEL_DEV="/dev/disk/by-label/${LABEL}"
			if [[ -h "${LABEL_DEV}" ]];
			then
				DEV_PATH=${LABEL_DEV}
				echo "Device file for ${LABEL} label has been found."
			else
				LVM_PATH="/dev/mapper/${LABEL}"
				if [[ -h "${LVM_PATH}" ]];
				then
					DEV_PATH=${LVM_PATH}
					echo "Device file for ${LABEL} label has been found."
				else
					echo "Device file for ${LABEL} label has not been found (skipping)."
					continue
				fi
			fi
		fi
		FILE_NAME="$(echo ${LABEL} | tr '[:upper:]' '[:lower:]').img.7z"
		if [ -f "./${BACKUP_DIR}/$FILE_NAME" ];
		then
			echo "File ${FILE_NAME} exist, skipping creatiion of backup."
		else
			if [ "${FILE_SYSTEM}" = "raw" ];
			then
				echo "Creation raw image for partition with ${LABEL} label with 7zip compression tool"
				partclone.dd -s "${DEV_PATH}" -o - -z 20971520 -N  | 7z a -bd -t7z "./${BACKUP_DIR}/$FILE_NAME" -si -m0=lzma2 -mx=1 -mmt12 1>/dev/null
				sha256sum "./${BACKUP_DIR}/$FILE_NAME" >> "./${BACKUP_DIR}/files.txt"
			else
				echo "Creation partclone image for partition with  ${LABEL} label with "${FILE_SYSTEM}" filesystem and 7zip compression tool"
				partclone.$FILE_SYSTEM -c -s "${DEV_PATH}" -o - -z 20971520 -N  | 7z a -bd -t7z "./${BACKUP_DIR}/$FILE_NAME" -si -m0=lzma2 -mx=1 -mmt12 >/dev/null
				sha256sum "./${BACKUP_DIR}/$FILE_NAME" >> "./${BACKUP_DIR}/files.txt"
			fi
		fi
		
	done
	#
	## BACKUP of GPT Partition tables
	## MAIN DISK
	#
	echo "########################################################################################################################"
	echo "Backup main partition table..."
	MAIN_BACKUP_FILE="./${BACKUP_DIR}/main_table.bin"
	if [ -b "${MAIN_DISK}" ] ;
		echo "Main disk device has been found."
	then
		if [ -f "./${MAIN_BACKUP_FILE}" ] ;
		then
			echo "File ${MAIN_BACKUP_FILE} exist, skipping creation of backup."
		else
			dd if=${MAIN_DISK} of="${MAIN_BACKUP_FILE}" bs=512 count=34 status=none && sync 
			sha256sum "./${MAIN_BACKUP_FILE}" >> "./${BACKUP_DIR}/files.txt"
		fi	
	else
		echo "Main disk device has not been found."
	fi
	#
	## SECOND DISK
	#
	echo "########################################################################################################################"
	echo "Backup second partition table..."
	SECOND_BACKUP_FILE="./${BACKUP_DIR}/second_table.bin"
	#
	if [ -b "${SECOND_DISK}" ] ; 
	then
		echo "Second disk device has been found."
		if [ -f "./${SECOND_BACKUP_FILE}" ] ;
		then
			echo "File ${SECOND_BACKUP_FILE} exist, skipping creation of backup."
		else
			dd if=${SECOND_DISK} of="${SECOND_BACKUP_FILE}" bs=512 count=34 status=none && sync 
			sha256sum "./${SECOND_BACKUP_FILE}" >> "./${BACKUP_DIR}/files.txt"
		fi
	else
		echo "Second disk device has not been found."
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
			echo "Backup directory was found"
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
		LABEL="${PART}"
		FILE_SYSTEM="${PARTITIONS[$LABEL]}"
		echo "Processing partition with ${LABEL} label and ${FILE_SYSTEM} filesystem"
		PARTLABEL_DEV="/dev/disk/by-partlabel/${LABEL}"
		if [[ -h "${PARTLABEL_DEV}" ]];
		then
			DEV_PATH=${PARTLABEL_DEV}
			echo "Device file for ${LABEL} label has been found."
		else
			LABEL_DEV="/dev/disk/by-label/${LABEL}"
			if [[ -h "${LABEL_DEV}" ]];
			then
				DEV_PATH=${LABEL_DEV}
				echo "Device file for ${LABEL} label has been found."
			else
				LVM_PATH="/dev/mapper/${LABEL}"
				if [[ -h "${LVM_PATH}" ]];
				then
					DEV_PATH=${LVM_PATH}
					echo "Device file for ${LABEL} label has been found."
				else
					echo "Device file for ${LABEL} label has not been found (skipping)."
					continue
				fi
			fi
		fi
		FILE_NAME="./${BACKUP_DIR}/$(echo ${LABEL} | tr '[:upper:]' '[:lower:]').img.7z"
		if [[ -f ${FILE_NAME} ]];
		then
			if [ "${FILE_SYSTEM}" = "raw" ];
			then
				echo "Restoring raw image for partition with $LABEL label."
				7z x -bd -so "${FILE_NAME}" | partclone.dd -s - -o "${DEV_PATH}" -z 20971520 -N
			else
				echo "Restoring partclone image for partition with $LABEL label and ${FILE_SYSTEM} filesystem."
				7z x -bd -so "${FILE_NAME}" | partclone.$FILE_SYSTEM -r -s - -o "${DEV_PATH}" -z 20971520 -N
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
	MAIN_BACKUP_FILE="./${BACKUP_DIR}/main_table.bin"
	SECOND_BACKUP_FILE="./${BACKUP_DIR}/second_table.bin"
	echo "########################################################################################################################"
	echo "Attempt of restoring partition table for main disk"
	if [ -f "./${MAIN_BACKUP_FILE}" ] && [ -b "${MAIN_DISK}" ] ; 
	then
	    echo "Device and backup file found."
	    TMP=$(lsblk -d -n -o PTTYPE "${MAIN_DISK}")
	    if [ -z "${TMP}" ] ;
	    then
		echo "No existing partition table has been found on main disk device."
		echo "Restoring partition table for main device"
		dd if="${MAIN_BACKUP_FILE}" of="${MAIN_DISK}" bs=512 status=none && sync
		echo "Fixing backup partition table ( replication from main )"
		sgdisk -e "${MAIN_DISK}" >/dev/null 2>&1
		echo "Verification"
		sgdisk -v "${MAIN_DISK}"
	    else
		echo "There has been found previous partition table (${TMP})"
		echo "Skipping"
	    fi
	else
	    echo "Device or backup file does not exist"
	fi
	##
	echo "########################################################################################################################"
	echo "Attempt of restoring partition table for second disk"
	if [ -f "./${SECOND_BACKUP_FILE}" ] && [ -b "${SECOND_DISK}" ] ; 
	then
	    echo "Device and backup file found."
	    TMP=$(lsblk -d -n -o PTTYPE "${SECOND_DISK}")
	    if [ -z "${TMP}" ] ;
	    then
		echo "No existing partition table has been found on second disk device."
		echo "Restoring partition table for second device"
		dd if="${SECOND_BACKUP_FILE}" of="${SECOND_DISK}" bs=512 status=none && sync
		echo "Fixing backup partition table ( replication from main )"
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
			LABEL="${PART}"
			FILE_SYSTEM="${PARTITIONS[$LABEL]}"
			echo "Checking partition image with ${LABEL} label and ${FILE_SYSTEM} filesystem"
			#
			FILE_NAME="./${BACKUP_DIR}/$(echo ${LABEL} | tr '[:upper:]' '[:lower:]').img.7z"
			#
			if [[ -f ${FILE_NAME} ]];
			then	
				echo "Checking integrity of 7zip archive."
				7z t "${FILE_NAME}" 1>/dev/null
				if [[ $? -eq 0 ]];
				then
					echo "No errors found for $(basename ${FILE_NAME}) image file." 
				else
					echo "Checking integrity of archive for $(basename ${FILE_NAME}) file failed."
				fi
				echo "Checking image file with partclone.chkimg"
				if [ "${FILE_SYSTEM}" = "raw" ];
				then
					echo "Archive $(basename ${FILE_NAME}) does not contain partclone image."
					echo "Checking image file is not possible."
				else
					7z x -bd -so "${FILE_NAME}" | partclone.chkimg -s - -N
				fi
			else
				echo "Backup file for $LABEL doesn't exists (skipping)."
				continue
			fi
		done
}
######################################################################################################################################################
#
## Main progam
#
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
