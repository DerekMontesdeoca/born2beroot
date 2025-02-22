#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

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
    cryptsetup --batch-mode luksFormat "$cryptpart"
fi
if [[ ! -e "/dev/mapper/sda5_crypt" ]]; then
    cryptsetup open --type luks "$cryptpart" "$cryptmapping_name"
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
if ! file -sL /dev/sda1 | grep -q 'FAT (32 bit)'; then
    mkfs.vfat -F32 /dev/sda1
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
    if ! file -sL | grep -q ext4; then
        mkfs.ext4 "/dev/mapper/$vg-$lv"
    fi
done
if ! file -sL | grep -q 'Linux swap file'; then
    mkswap "/dev/mapper/$vg-swap"
fi

# Mount filesystems.
installation_root=/mnt
mkdir -p "$installation_root"
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
if ! swapon -s "/dev/mapper/$vg-swap"; then
    swapon "/dev/mapper/$vg-swap"
fi

# Bind mount system dirs.
system_dirs=(
    "/proc"
    "/dev"
    "/sys"
    "/run"
)
for dir in "${system_dirs[@]}"; do
    if ! findmnt "$dir"; then
        mount -o X-mount.mkdir --rbind "$dir" "$installation_root/$dir"
    fi
done

# Install minimal debian.
if [[ ! -d "$installation_root/usr/bin" ]]; then
    debootstrap --arch=amd64 stable "$installation_root"
fi

# Generate fstab.
cat > "$installation_root/etc/fstab" << EOF
/dev/sda1 /boot vfat defaults,nodev,nosuid,noexec,fmask=0177,dmask=0077 0 2
/dev/mapper/$vg-root / ext4 defaults 0 1
/dev/mapper/$vg-home /home ext4 defaults 0 1
/dev/mapper/$vg-srv /srv ext4 defaults 0 1
/dev/mapper/$vg-tmp /tmp ext4 defaults 0 1
/dev/mapper/$vg-var /var ext4 defaults 0 1
/dev/mapper/$vg-var--log /var/log ext4 defaults 0 1
/dev/mapper/$vg-swap none swap defaults 0 1
EOF

# Generate crypttab.
if [[ ! -f "$installation_root/etc/crypttab" ]]; then
    cryptpart_uuid=$(blkid | grep "$cryptpart" | awk '{print $2}' | grep -oP '"\K[^"]+')
    cat > "$installation_root/etc/crypttab" << EOF
$cryptmapping_name UUID=$cryptpart_uuid none luks,tries=3
EOF
fi

# Copy apt keys to new system.
rsync -azv "/usr/share/keyrings/" "$installation_root/etc/trusted.gpg.d/"

# chroot into new system.
chroot $installation_root
