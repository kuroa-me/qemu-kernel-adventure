#!/bin/sh
rm rootfsbear.ext4
qemu-img create rootfs.ext4 2G
mkfs.ext4 -F rootfs.ext4
mount -t ext4 -o loop rootfs.ext4 /mnt
cp -r rootfs/. /mnt
umount /mnt