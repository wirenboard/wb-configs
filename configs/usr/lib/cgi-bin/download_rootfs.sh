#!/bin/bash

set -e

MOUNT_DIR=$(mktemp -d -t "WB-RFS.XXXXXXX")

function cleanup()
{
    sudo umount -f $MOUNT_DIR || true
    rm -r $MOUNT_DIR
}

trap cleanup EXIT

sudo mount /dev/mmcblk0p3 $MOUNT_DIR

if [ -d "$MOUNT_DIR/etc" ]; then
    echo "Status: 200"
    echo 'Content-Disposition: attachment; filename="rootfs.tar.gz"'
    echo "Content-Type: application/gzip"
    echo ""
    sudo tar -czf - $MOUNT_DIR
else
    echo "Status: 500"
    echo ""
    echo "Error mounting rootfs"
fi
