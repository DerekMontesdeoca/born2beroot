#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

if [[ "$EUID" -ne 0 ]]; then
    echo "Elevated privileges required."
    exit 1
fi

apt update && apt upgrade -y
apt install debootstrap parted lvm2 cryptsetup systemd-timesyncd -y

# ============ Sync Time ============ #

if ! systemctl status systemd-timesyncd; then
    systemctl restart systemd-timesyncd
    systemctl status systemd-timesyncd
fi

# ============ Make Partitions ============ #

parted -s /dev/sda mklabel msdos
parted -s /dev/sda mkpart primary 1MiB 501MiB
parted -s /dev/sda set 1 boot on 
parted -s /dev/sda mkpart extended 501MiB 100%
parted -s /dev/sda mkpart logical 502MiB 100%
parted -s /dev/sda align-check optimal 1
parted -s /dev/sda align-check optimal 2

# installation_root=debian
# mkdir -p "$installation_root"
# debootstrap --arch=amd64 stable "$installation_root"
