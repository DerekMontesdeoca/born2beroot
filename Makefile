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

start:
	VBoxManage startvm $(NAME)

destroy:
	VBoxManage unregistervm $(NAME) --delete-all

clean:
	rm -f debian_12_9_0_amd64.iso sha256sum signature debian-iso

.PHONY: start create destroy clean
