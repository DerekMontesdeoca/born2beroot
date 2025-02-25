#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

ide_controller=ide1

VBoxManage storagectl "$name" \
    --name="$ide_controller" \
    --remove

VBoxManage modifyvm "$name" \
    --memory=2048 \
    --boot1=disk

