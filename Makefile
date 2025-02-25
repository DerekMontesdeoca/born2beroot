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
	rm -f debian_live_12_9_0_amd64-standard.iso sha256sum signature

.PHONY: start create destroy clean
