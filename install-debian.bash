#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

set -a
source "$(dirname "$0")"/.env
set +a

setterm -repeat off # Avoid character repetition.

if [[ "$EUID" -ne 0 ]]; then
    echo "Elevated privileges required."
    exit 1
fi

# Update and install required packages for debian isntallation.
apt update && apt upgrade -y
apt install debootstrap dosfstools parted lvm2 cryptsetup systemd-timesyncd -y

# Sync Time.
if ! systemctl status systemd-timesyncd --no-pager; then
    systemctl restart systemd-timesyncd
    systemctl status systemd-timesyncd --no-pager
fi

# Make Partitions.
if ! lsblk | grep -q sda1 \
    || ! lsblk | grep -q sda2 \
    || ! lsblk | grep -q sda5 \
    || ! parted -s /dev/sda p | grep -q msdos;
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
cryptmapping_name="sda5_crypt"
cryptmapping="/dev/mapper/$cryptmapping_name"
cryptpart="/dev/sda5"
if ! cryptsetup isLuks /dev/sda5; then
    echo "$ENV_LUKS_PASSWORD" | cryptsetup --batch-mode luksFormat "$cryptpart"
fi
if [[ ! -e "/dev/mapper/sda5_crypt" ]]; then
    echo "$ENV_LUKS_PASSWORD" \
        | cryptsetup open --type luks "$cryptpart" "$cryptmapping_name"
fi

# Wait for the crypt_map to be active.
if ! timeout 5 bash -c "while [[ ! -e \"$cryptmapping\" ]]; do sleep 0.2; done"
then
    echo "Timed out waiting for $cryptmapping" >&2
    exit 1
fi

# Create LVM.
if [[ -z $(pvs) ]]; then
    pvcreate "$cryptmapping"
fi

vg=LVMGroup
if [[ -z $(vgs) ]]; then
    vgcreate "$vg" "$cryptmapping"
fi

if [[ -z $(lvs) ]]; then
    lvcreate --size 10G --name root "$vg"
    lvcreate --size 5G --name home "$vg"
    lvcreate --size 3G --name var "$vg"
    lvcreate --size 3G --name srv "$vg"
    lvcreate --size 3G --name tmp "$vg"
    lvcreate --size 4G --name var-log "$vg"
    lvcreate --extents 100%FREE --name swap "$vg"
fi

# Format partitions.
if ! file -sL "/dev/sda1" | grep -q 'ext4'; then
    mkfs.ext4 "/dev/sda1"
fi
ext4_lvs=(
    "root"
    "home"
    "var"
    "srv"
    "tmp"
    "var--log"
)
for lv in "${ext4_lvs[@]}"; do
    if ! file -sL "/dev/mapper/$vg-$lv" | grep -q ext4; then
        mkfs.ext4 "/dev/mapper/$vg-$lv"
    fi
done
if ! file -sL "/dev/mapper/$vg-swap" | grep -q 'Linux swap file'; then
    mkswap "/dev/mapper/$vg-swap"
fi

# Mount filesystems.
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

# Install minimal debian.
if [[ ! -d "$installation_root/usr/bin" ]]; then
    debootstrap --arch=amd64 stable "$installation_root"
fi

# Bind mount system dirs.
system_dirs=(
    "/dev"
    "/run"
    "/sys"
    "/proc"
)
for dir in "${system_dirs[@]}"; do
    if ! findmnt "$(realpath "$installation_root/$dir")"; then
        mount -o X-mount.mkdir --rbind --make-rslave \
            "$dir" "$(realpath "$installation_root/$dir")"
    fi
done

# Generate fstab.
bootpart_uuid=$(blkid -s UUID -o value "/dev/sda1")
cat > "$installation_root/etc/fstab" << EOF
UUID=$bootpart_uuid /boot ext4 defaults,nodev,nosuid,noexec 0 2
/dev/mapper/$vg-root / ext4 defaults 0 1
/dev/mapper/$vg-home /home ext4 defaults 0 2
/dev/mapper/$vg-srv /srv ext4 defaults 0 2
/dev/mapper/$vg-tmp /tmp ext4 defaults 0 2
/dev/mapper/$vg-var /var ext4 defaults 0 2
/dev/mapper/$vg-var--log /var/log ext4 defaults 0 2
/dev/mapper/$vg-swap none swap defaults 0 0
EOF

# Generate crypttab.
if [[ ! -f "$installation_root/etc/crypttab" ]]; then
    cryptpart_uuid=$(blkid -s UUID -o value "$cryptpart")
    cat > "$installation_root/etc/crypttab" << EOF
$cryptmapping_name UUID=$cryptpart_uuid none luks,tries=3
EOF
fi

# Copy apt keys to new system.
rsync -azv "/usr/share/keyrings/" "$installation_root/etc/apt/trusted.gpg.d/"

# chroot into new system.
cp -r "$(dirname "$0")" "$installation_root/root/born2beroot"
chroot $installation_root "/usr/bin/bash" "/root/born2beroot/configure-chroot.bash"

# Add server configuration script to profile.
echo "/root/born2beroot/configure-server.bash" >> "/root/.profile"

# Manually umount the system.
if [[ -n $(swapon --show) ]]; then
    swapoff "/dev/mapper/$vg-swap"
fi
umount -R $installation_root

reboot
