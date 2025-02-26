#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

ide_controller=ide1
name="born2beroot"

VBoxManage storagectl "$name" --name "$ide_controller" --remove

VBoxManage modifyvm "$name" --boot1=disk

