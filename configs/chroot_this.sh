#!/bin/bash
set -x
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR

[[ -n "$__unshared" ]] || {
	[[ $EUID == 0 ]] || {
		exec sudo -E "$0" "$@"
	}

	# Jump into separate namespace
	export __unshared=1
	exec unshare -umipf "$0" "$@"
}

mkdir -p $DIR/proc
mkdir -p $DIR/sys
mkdir -p $DIR/tmp
mkdir -p $DIR/dev
mkdir -p $DIR/dev/pts

touch $DIR/dev/random
touch $DIR/dev/urandom
touch $DIR/dev/zero
touch $DIR/dev/full
touch $DIR/dev/null

mount -t proc none $DIR/proc
mount -t sysfs none $DIR/sys
mount -t tmpfs none $DIR/tmp

mount --bind /dev/random $DIR/dev/random
mount --bind /dev/urandom $DIR/dev/urandom
mount --bind /dev/zero $DIR/dev/zero
mount --bind /dev/full $DIR/dev/full
mount --bind /dev/null $DIR/dev/null

mount -t devpts devpts $DIR/dev/pts -o "gid=5,mode=620,ptmxmode=666,newinstance"
[[ -L $DIR/dev/ptmx ]] || mount --bind $DIR/dev/pts/ptmx $DIR/dev/ptmx

cleanup_mounts() {
	umount "$DIR/proc"
	umount "$DIR/sys"
	umount "$DIR/tmp"

	umount "$DIR/dev/random"
	umount "$DIR/dev/urandom"
	umount "$DIR/dev/zero"
	umount "$DIR/dev/full"
	umount "$DIR/dev/null"

	umount -R "$DIR/dev/pts"
}
trap cleanup_mounts EXIT

chroot $DIR "$@"
