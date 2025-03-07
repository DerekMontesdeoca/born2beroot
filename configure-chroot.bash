#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'
 
# Add necessary apt repos.
cat << EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian stable main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security stable-security main contrib non-free non-free-firmware updates
deb http://deb.debian.org/debian stable-updates main contrib non-free non-free-software
EOF

# Update and upgrade the system.
apt-get update
apt-get upgrade -y

# Set up locale.
apt-get install --no-install-recommends locales -y
if [[ ! -f "/etc/locale.gen" ]] || ! grep '^[^#]' "/etc/locale.gen"; then
    sed -i '/en_US.UTF-8/ s/# //' /etc/locale.gen
    locale-gen
    echo -e "\nexport LANG=en_US.UTF-8" > /etc/profile
fi

# Set root password.
if [[ $(passwd --status root | awk '{print $2}') != 'P' ]]; then
    echo "root:$ENV_ROOT_PASSWORD" | chpasswd
fi

# ============ Network Configuration ============ #

echo "$ENV_HOSTNAME" > "/etc/hostname"

echo -e "127.0.1.1\t$ENV_HOSTNAME"  >> "/etc/hosts"

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
apt-get install --no-install-recommends -y \
    linux-image-amd64 cryptsetup cryptsetup-initramfs lvm2
update-initramfs -u -k all

# Install boot loader.
apt-get install --no-install-recommends -y grub-pc
grub-install /dev/sda
update-grub
