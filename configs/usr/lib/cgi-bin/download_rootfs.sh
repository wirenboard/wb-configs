#!/bin/bash

set -e

run_pigz() {
	# if there are more than 1 core, use half of them
	cpu_cores=$(nproc --all)
	if [ $cpu_cores -gt 1 ]; then
    		pigz -p $(($cpu_cores/2))
	else
    		pigz
	fi
}

MOUNT_DIR=$(mktemp -d -t "WB-RFS.XXXXXXX")
SERIAL=$(cat "/var/lib/wirenboard/short_sn.conf")
ROOTFS_DEV=$(mount | grep "on / type ext4" | awk '{print $1}')
printf -v date '%(%Y%m%d_%H%M)T' -1

function cleanup()
{
    sudo umount -f "$MOUNT_DIR" || true
    rm -r "$MOUNT_DIR"
}

trap cleanup EXIT

sudo mount "$ROOTFS_DEV" "$MOUNT_DIR"

if [ -z "$(ls -A $MOUNT_DIR)" ]; then
    echo "Status: 500"
    echo ""
    echo "Error mounting rootfs"
else
    echo "Status: 200"
    echo "Content-Disposition: attachment; filename=\"rootfs_${SERIAL}_${date}.tar.gz\""
    echo "Content-Type: application/octet-stream"
    echo ""
    cd "$MOUNT_DIR"
    sudo tar --exclude='tmp' --exclude='var/tmp' -cf - * | run_pigz
fi
