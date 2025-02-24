#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

cryptpart="/dev/sda5"
cryptmapping_name="sda5_crypt"
if [[ ! -e "/dev/mapper/sda5_crypt" ]]; then
    cryptsetup open --type luks "$cryptpart" "$cryptmapping_name"
fi

installation_root=/mnt
mkdir -p "$installation_root"
umount -R -l "$installation_root" || true
vg="LVMGroup"
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
            "$(realpath $installation_root/${mountpoints[$i]})"
    fi
done
swap_uuid=$(blkid -s UUID -o value "/dev/mapper/$vg-swap")
if ! swapon --show=UUID | grep -q "$swap_uuid" ; then
    swapon "/dev/mapper/$vg-swap"
fi

system_dirs=(
    "/dev"
    "/run"
)
if ! findmnt "$installation_root/proc"; then
    mount -t proc "/proc" "$(realpath $installation_root/proc)"
fi
if ! findmnt "$installation_root/sys"; then
    mount -t sysfs "/proc" "$(realpath $installation_root/sys)"
fi
for dir in "${system_dirs[@]}"; do
    if ! findmnt "$installation_root/$dir"; then
        mount -o X-mount.mkdir --rbind --make-rslave \
            "$dir" "$(realpath $installation_root/$dir)"
    fi
done

chroot "$installation_root" /bin/bash
