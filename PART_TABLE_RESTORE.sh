#!/bin/bash
##############################################################################################################################################################################
#!/bin/bash
##
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
# MAIN_DISK="/dev/sda"
MAIN_DISK="/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNF0M910268J"
MAIN_BACKUP_FILE="./${BACKUP_DIR}/main_table.bin"
# SECOND_DISK="/dev/sdb"
SECOND_DISK="/dev/disk/by-id/nvme-Samsung_SSD_980_1TB_S649NJ0R214022Y"
SECOND_BACKUP_FILE="./${BACKUP_DIR}/second_table.bin"
##
#
echo "################################################################################################################"
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
echo "################################################################################################################"
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
echo "################################################################################################################"
##
