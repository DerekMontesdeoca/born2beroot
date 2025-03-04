#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

name="$1"

if VBoxManage list vms | grep -q "$name"; then
    echo "$name vm already exists"
    exit 1
fi

# ============ Create the VM ============ #

VBoxManage createvm \
    --name "$name" \
    --basefolder=. \
    --ostype=Debian_64 \
    --register

VBoxManage modifyvm "$name" \
    --memory=2048 \
    --cpus=2 \
    --nic1=bridged \
    --bridge-adapter1="$(ip route | grep default | awk '{printf $5}')" \
    --graphicscontroller=vboxsvga \
    --vram=20


# ============ Create ide controller for boot ============ #

ide_controller=ide1

VBoxManage storagectl "$name" \
    --name="$ide_controller" \
    --add=ide \
    --bootable=on


debian_iso_file='debian-live-12.9.0-amd64-standard.iso'

if [[ ! -f $debian_iso_file ]]; then 
    debian_iso_url='https://debian.uvigo.es/debian-cd/current-live/amd64/iso-hybrid/'"$debian_iso_file"
    signature_url='https://debian.uvigo.es/debian-cd/current-live/amd64/iso-hybrid/SHA256SUMS.sign'
    signature_file='signature'
    keyserver_url='hkps://keyring.debian.org:443'
    sha256sum_url='https://debian.uvigo.es/debian-cd/current-live/amd64/iso-hybrid/SHA256SUMS'
    sha256sum_file='sha256sum'

    curl -fLo signature "$signature_url"
    key_id=$(gpg --list-packets signature | awk '/signature/ {print $NF}')
    gpg --keyserver  "$keyserver_url" --recv-keys "0x$key_id"
    curl -fLo "$sha256sum_file" "$sha256sum_url"
    gpg --verify "$signature_file" "$sha256sum_file"
    curl -fLJo "$debian_iso_file" "$debian_iso_url"
    grep "$debian_iso_file$" "$sha256sum_file" | sha256sum -c
fi

VBoxManage storageattach "$name" \
    --storagectl="$ide_controller" \
    --port=0 \
    --device=0 \
    --type=dvddrive \
    --medium="$debian_iso_file"

# ============ Add SATA Disk ============ #

sata_controller=sata1

VBoxManage storagectl "$name" \
    --name="$sata_controller" \
    --add=sata \
    --portcount=1 \
    --bootable=off

disk=disk1.vdi

if [[ ! -f $disk ]]; then
    VBoxManage createmedium disk \
        --filename="$disk" \
        --size=31540 \
        --format=VDI
fi

VBoxManage storageattach "$name" \
    --storagectl="$sata_controller" \
    --port=0 \
    --device=0\
    --type=hdd \
    --medium="$disk"
