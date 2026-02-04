#!/bin/bash
#
##
##############################################################################################################################################################################
#
## Partitions for backup
#
# PARTLABEL 
declare -A PARTITIONS=(["EFI"]="vfat" ["WINMSR"]="raw" ["WINOS"]="ntfs" ["WINREC"]="ntfs" ["WINDATA"]="ntfs" )
#
# PARTLABEL + LABEL
# declare -A PARTITIONS=(["EFI"]="vfat" ["WINMSR"]="raw" ["WinOS"]="ntfs" ["WinRec"]="ntfs" ["WinData"]="ntfs" )
#
# PARTLABEL + LABEL + lvm names
# declare -A PARTITIONS=(["EFI"]="vfat" ["BootFs"]="ext2" ["vg-root"]="ext4" ["vg-home"]="ext4" )
#
##############################################################################################################################################################################
#
## MAIN
## Backup directory
#
BACKUP_DESCRIPTION="WIN_SNAPSHOT"
#
BACKUP_DIR="$(date +%Y%m%d%H%M%S)_${BACKUP_DESCRIPTION}"
mkdir "${BACKUP_DIR}"
touch "./${BACKUP_DIR}/files.txt"
#
for PART in "${!PARTITIONS[@]}"; 
do
	echo "################################################################################################################"
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
	## 7zip compression
	#
	FILE_NAME="$(echo ${LABEL} | tr '[:upper:]' '[:lower:]').img.7z"
	#
	if [ -f "./${BACKUP_DIR}/$FILE_NAME" ];
	then
		echo "File ${FILE_NAME} exist, skipping creatiion of backup."
	else
		if [ "${FILE_SYSTEM}" = "raw" ];
		then
			## 7zip compression
			#
			echo "Creation raw image for partition with ${LABEL} label with 7zip compression tool"
			partclone.dd -s "${DEV_PATH}" -o - -z 20971520 -N  | 7z a -bd -t7z "./${BACKUP_DIR}/$FILE_NAME" -si -m0=lzma2 -mx=1 -mmt12 1>/dev/null
			sha256sum "./${BACKUP_DIR}/$FILE_NAME" >> "./${BACKUP_DIR}/files.txt"
			#
		else
			## 7zip compression
			#
			echo "Creation partclone image for partition with  ${LABEL} label with "${FILE_SYSTEM}" filesystem and 7zip compression tool"
			partclone.$FILE_SYSTEM -c -s "${DEV_PATH}" -o - -z 20971520 -N  | 7z a -bd -t7z "./${BACKUP_DIR}/$FILE_NAME" -si -m0=lzma2 -mx=1 -mmt12 1>/dev/null
			sha256sum "./${BACKUP_DIR}/$FILE_NAME" >> "./${BACKUP_DIR}/files.txt"
			#
		fi
	fi
	
done
#
##############################################################################################################################################################################
## BACKUP of GPT Partition table
## MAIN DISK
#
echo "################################################################################################################"
echo "Backup main partition table..."
# MAIN_DISK="/dev/sda"
MAIN_DISK="/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNF0M910268J"
MAIN_BACKUP_FILE="./${BACKUP_DIR}/main_table.bin"
#
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
echo "################################################################################################################"
echo "Backup second partition table..."
# SECOND_DISK="/dev/sdb"
SECOND_DISK="/dev/disk/by-id/nvme-Samsung_SSD_980_1TB_S649NJ0R214022Y"
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
echo "################################################################################################################"
#
##############################################################################################################################################################################
## Setting permision for backup files
chown -R 1000:1000 "./${BACKUP_DIR}"
#
##############################################################################################################################################################################

