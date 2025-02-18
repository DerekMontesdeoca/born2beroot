#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

name=$1

if ! VBoxManage list vms | grep -q $name; then
    exit 1
fi

VBoxManage createvm \
    --name $name \
    --basefolder=. \
    --ostype=Debian_64 \
    --register

VBoxManage modifyvm $name \
    --memory=1024 \
    --cpus=2 \
    --nic1=bridged \
    --bridge-adapter1=$(ip route | grep default | awk '{printf $5}')

curl -L -o sha256sum 'https://debian.uvigo.es/debian-cd/current/amd64/iso-cd/SHA256SUMS'
curl -L -o 'debian_12_9_0_amd64' 'https://debian.uvigo.es/debian-cd/current/amd64/iso-cd/debian-12.9.0-amd64-netinst.iso'

