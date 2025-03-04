################################################################################
# BORN2BEROOT
################################################################################

NAME := born2beroot
DEBIAN_VERSION := 12.9

################################################################################
# Rules
################################################################################

create:
	./deploy-vm.bash $(NAME)

remove_iso:
	./prepare-first-boot.bash

start:
	VBoxManage startvm $(NAME)

destroy:
	VBoxManage unregistervm $(NAME) --delete-all

clean:
	rm -f debian-live-12.9.0-amd64-standard.iso sha256sum signature

.PHONY: start create destroy clean
