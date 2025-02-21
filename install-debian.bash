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

# installation_root=debian
# mkdir -p "$installation_root"
# debootstrap --arch=amd64 stable "$installation_root"
