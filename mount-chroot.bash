#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'


if [[ ! -e "/dev/mapper/sda5_crypt" ]]; then
    cryptsetup open --type luks "$cryptpart" "$cryptmapping_name"
fi

installation_root=/mnt
mkdir -p "$installation_root"
umount -R -l "$installation_root" || true
fss=(
    "/dev/mapper/$vg-root"
    "/dev/sda1"
    "/dev/mapper/$vg-home"
    "/dev/mapper/$vg-srv"
    "/dev/mapper/$vg-tmp"
    "/dev/mapper/$vg-var"
    "/dev/mapper/$vg-var--log"
)
mountpoints=(
    "/"
    "/boot"
    "/home"
    "/srv"
    "/tmp"
    "/var"
    "/var/log"
)
for i in "${!fss[@]}"; do
    if ! findmnt "${fss[$i]}"; then
        mount -o X-mount.mkdir \
            "${fss[$i]}" \
            "$installation_root/${mountpoints[$i]}"
    fi
done
swap_uuid=$(blkid -s UUID -o value "/dev/mapper/$vg-swap")
if ! swapon --show=UUID | grep -q "$swap_uuid" ; then
    swapon "/dev/mapper/$vg-swap"
fi

chroot "$installation_root" /bin/bash
