#!/bin/bash

set -e

MOUNT_DIR=$(mktemp -d -t "WB-RFS.XXXXXXX")
SERIAL=$(cat "/var/lib/wirenboard/short_sn.conf")
ROOTFS_DEV=$(mount | grep "on / type ext4" | awk '{print $1}')

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
    echo "Content-Disposition: attachment; filename=\"rootfs_${SERIAL}.tar.gz\""
    echo "Content-Type: application/gzip"
    echo ""
    cd "$MOUNT_DIR"
    sudo tar -czf - . | pigz
fi
