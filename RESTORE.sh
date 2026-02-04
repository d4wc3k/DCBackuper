#!/bin/bash
#
# PARTLABELS
declare -A PARTITIONS=(["EFI"]="vfat" ["WINMSR"]="raw" ["WINOS"]="ntfs" ["WINREC"]="ntfs" ["WINDATA"]="ntfs" )
#
# PARTLABELS + LABELS
# declare -A PARTITIONS=(["EFI"]="vfat" ["WINMSR"]="raw" ["WinOS"]="ntfs" ["WinRec"]="ntfs" ["WinData"]="ntfs" )
#
# PARTLABEL + LABEL + lvm names
# declare -A PARTITIONS=(["EFI"]="vfat" ["BOOT"]="ext2" ["vg-root"]="ext4" ["vg-home"]="ext4" )
#
##############################################################################################################################################################################
#
## Read backup directory name
#
DIR_NAME_NEEDS_TO_BE_SET=true
while $DIR_NAME_NEEDS_TO_BE_SET
do
	read -p "Enter backup directory name: " BACKUP_DIR
	if [[ -d "./${BACKUP_DIR}" ]];
	then
		DIR_NAME_NEEDS_TO_BE_SET=false
		echo "Backup directory has been found."
	else
		echo "Backup directory has been found, please try again."
	fi
done
#
## MAIN 
#
for PART in "${!PARTITIONS[@]}"; 
do
	echo "################################################################################################################"
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
	## 7zip compression
	#
	FILE_NAME="./${BACKUP_DIR}/$(echo ${LABEL} | tr '[:upper:]' '[:lower:]').img.7z"
	#
	if [[ -f ${FILE_NAME} ]];
	then
		if [ "${FILE_SYSTEM}" = "raw" ];
		then
			echo "Restoring raw image for partition with $LABEL label."
			## 7zip compression
			#
			7z x -bd -so "${FILE_NAME}" | partclone.dd -s - -o "${DEV_PATH}" -z 20971520 -N
			#
		else
			echo "Restoring partclone image for partition with $LABEL label and ${FILE_SYSTEM} filesystem."
			## 7zip compression
			#
			7z x -bd -so "${FILE_NAME}" | partclone.$FILE_SYSTEM -r -s - -o "${DEV_PATH}" -z 20971520 -N
			#
		fi
	else
		echo "Backup file for $LABEL doesn't exists (skipping)."
		continue
	fi
	echo "################################################################################################################"
done
#
##############################################################################################################################################################################
