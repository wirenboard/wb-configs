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

if [ -d "$MOUNT_DIR/etc" ]; then
    echo "Status: 200"
    echo "Content-Disposition: attachment; filename=\"rootfs_${SERIAL}.tar.gz\""
    echo "Content-Type: application/gzip"
    echo ""
    sudo tar -czf - "$MOUNT_DIR"
else
    echo "Status: 500"
    echo ""
    echo "Error mounting rootfs"
fi
