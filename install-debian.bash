#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

if [[ "$EUID" -ne 0 ]]; then
    echo "Elevated privileges required."
    exit 1
fi

# Update and install required packages for debian isntallation.
apt update && apt upgrade -y
apt install debootstrap parted lvm2 cryptsetup systemd-timesyncd -y

# Sync Time.
if ! systemctl status systemd-timesyncd; then
    systemctl restart systemd-timesyncd
    systemctl status systemd-timesyncd
fi

# Make Partitions.
if ! lsblk | grep -q sda1 \
    || ! lsblk | grep -q sda2 \
    || ! lsblk | grep -q sda5 \
    || ! parted -s /dev/sda | grep -q msdos;
then
    parted -s /dev/sda mklabel msdos
    parted -s /dev/sda mkpart primary 1MiB 501MiB
    parted -s /dev/sda set 1 boot on 
    parted -s /dev/sda mkpart extended 501MiB 100%
    parted -s /dev/sda mkpart logical 502MiB 100%
    parted -s /dev/sda align-check optimal 1
    parted -s /dev/sda align-check optimal 2
fi

# Create Encrypted Partition.
if ! cryptsetup isLuks /dev/sda5; then
    cryptsetup luksFormat /dev/sda5
    cryptsetup open --type luks /dev/sda5 sda5_crypt
fi

# Create LVM.
if [[ -z $(pvs) ]]; then
    pvcreate /dev/mapper/sda5_crypt
fi
if [[ -z $(vgs) ]]
    vgcreate LVMGroup /dev/mapper/sda5_crypt
fi
if [[ -z $(lvs) ]]; then
    lvcreate --size 10G --name root
    lvcreate --size 5G --name home
    lvcreate --size 3G --name var
    lvcreate --size 3G --name srv
    lvcreate --size 3G --name tmp
    lvcreate --size 4G --name var-log
    lvcreate --extents 100%FREE --name swap
fi

# installation_root=debian
# mkdir -p "$installation_root"
# debootstrap --arch=amd64 stable "$installation_root"
