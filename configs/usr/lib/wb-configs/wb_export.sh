#!/bin/bash

set -euo pipefail

export PATH=/usr/sbin:/usr/bin:/sbin:/bin
unset TAR_OPTIONS

if (( $# != 1 )); then
    echo "Usage: ${0##*/} {rootfs|configs|everything}" >&2
    exit 2
fi

case "$1" in
    rootfs)
        tar_options=(
            --one-file-system
            --directory /
            --exclude='./tmp'
            --exclude='./var/tmp'
        )

        if [[ ! -e /dev/mmcblk0p6 ]]; then
            tar_options+=(--exclude='./mnt/data')
        fi

        exec /usr/bin/tar "${tar_options[@]}" --create --file - -- .
        ;;

    configs)
        exec /usr/bin/tar \
            --exclude='/var/tmp' \
            --exclude='/var/log' \
            --exclude='/mnt/data/root/zigbee2mqtt/data/log' \
            --create --file - -- \
            /etc \
            /mnt/data/etc \
            /var \
            /mnt/data/root/zigbee2mqtt/data \
            /mnt/data/makesimple/.SprutHub
        ;;

    everything)
        archive_paths=(/)

        if [[ -e /dev/mmcblk0p6 ]]; then
            archive_paths+=(/mnt/data)
        fi

        exec /usr/bin/tar --one-file-system --create --file - -- "${archive_paths[@]}"
        ;;

    *)
        echo "Usage: ${0##*/} {rootfs|configs|everything}" >&2
        exit 2
        ;;
esac
