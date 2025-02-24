#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

D_HOSTNAME=dmontesd42

# Update and upgrade the system.
apt update
apt upgrade -y

# Set up locale.
apt install --no-install-recommends locales -y
if [[ ! -f "/etc/locale.gen" ]] || ! grep '^[^#]' "/etc/locale.gen"; then
    sed -i '/en_US.UTF-8/ s/# //' /etc/locale.gen
    locale-gen
    echo -e "\nexport LANG=en_US.UTF-8" > /etc/profile
fi

# Set root password.
if [[ $(passwd --status root | awk '{print $2}') != 'P' ]]; then
    passwd
fi

# ============ Network Configuration ============ #

echo -e "$D_HOSTNAME" > /etc/hostname

# lo interface
if [[ ! -f "/etc/network/interfaces.d/lo" ]]; then
    cat > "/etc/network/interfaces.d/lo" << EOF
auto lo
iface lo inet loopback
EOF
fi

# DHCP default interface
interface_name=$(
    ip -o link show \
        | grep -v lo \
        | head -n1 \
        | awk '{print $2}' \
        | grep -Po '.+[^:]'
)
if [[ ! -f "/etc/network/interfaces.d/$interface_name" ]]; then
    cat > "/etc/network/interfaces.d/$interface_name" << EOF
auto $interface_name
iface $interface_name inet dhcp
EOF
fi

# ============ #

# Install the kernel.
apt install --no-install-recommends -y linux-image-amd64

# Install boot loader.
apt install --no-install-recommends -y grub-pc
grub-install /dev/sda1
update-grub
