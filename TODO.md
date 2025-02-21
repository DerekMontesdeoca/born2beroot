# BORN2BEROOT

## Learning

[ ] VirtualBox
[ ] Networking
- Bridge
- Nat
- NatNetwork
- Hostonly
- Internal Network
- Null
- None

[ ] What is different in Debian from General Linux?
[ ] LVM, cryptswap 
- [ArchWiki - LVM](https://wiki.archlinux.org/title/LVM)

[ ] AppArmor
[ ] command ss
[ ] command aa-status
[ ] command ufw
[ ] TTY
[ ] command nmap - Useful and almost essential for networking and security

## Server Checklist

[ ] Installed GRUB? (grub-install /dev/sda)
[ ] Installed Kernel? (apt install linux-image-amd64)
[ ] Configured /etc/fstab?
[ ] Configured Network? (/etc/network/interfaces)
[ ] Set Locale & Timezone? (locale-gen, dpkg-reconfigure tzdata)
[ ] Created a User? (adduser myuser)
[ ] Generated initramfs? (update-initramfs -u)
[ ] Updated sources.list?
[ ] Enabled essential services? (systemctl enable cron ssh)

[ ] Load a live iso into the virtual machine.
[ ] Load and execute script.
[ ] Install parted, cryptsetup, lvm2.
[ ] Create a partition to make LVM on LUKS.
[ ] Add a password to new LUKS partition.
[ ] Open LUKS partition.
[ ] Create logical volumes with LVM.
[ ] Create a dir for the new debian.
[ ] Mount lvs on debian dir.
[ ] Mount with --rbind sys, dev, run.
[ ] Mount proc with -t proc.
[ ] chroot into new debian.
[ ] Update apt keys adding them to gpg with gpg --keyserver --recv-keys.
[ ] Update apt sources list.
[ ] do apt update
[ ] 


[ ] Create encrypted partitions with LVM. For the bonus, create the following partition table:
- storage unit with 30.8G 
    - 500M -> /boot
    - 1k
    - 30.3 G
        - LVM GROUP on a crypt part
            - root -> /
            - swap -> \[SWAP]
            - home -> /home
            - var -> /var
            - srv -> /srv
            - tmp -> /tmp
            - var--log -> /var/log
- rom with 1024M
[ ] Mount 

[ ] Set hostname to {login}42.
[ ] Set up root passwd and admin user.
[ ] Set up the following users:
- root
- {user}

[ ] Make sure that {user} user belongs to the groups user42 and sudo.
[ ] Install ssh server.
[ ] Configure ssh server. 
[ ] Execute SSH on port 4242.
[ ] Make sure SSH is unavailable for root.
[ ] Configure firewall to only allow inc 4242.
[ ] Learn how to change the hostname for the defense.
[ ] Set password policy:
- 30 day expiration period.
- 2 day minimum for changing password.
- Notifications for users with password expiration period <= 7 days.
- Password strength policy:
    - Minlength: 10 chars
    - 1 Upper
    - 1 Lower
    - 1 Number
    - No 3 consecutive chars
    - Username not allowed
    - Non-root only: At least 7 chars that don't belong to the old password.

[ ] Set up sudo and configure it:
- 3 Tries max.
- Display custom message when inputting an incorrect password using sudo.
- Log input and output of sudo commands on /var/log/sudo/.
- TTY must be activated for (security reasons?).
- Restrict usable dirs for sudo to:
    - /usr/local/sbin
    - /usr/local/bin
    - /usr/sbin
    - /usr/bin
    - /sbin
    - /bin
    - /snap/bin

[ ] Learn how to create a user and assign it to a group for the defense.
[ ] After setting up configuration files, change all passwords on the VM, including root.
[ ] Create a monitoring script called monitoring.sh:
- Use /usr/bin/bash
- Show info every 10 minutes (Check out wall). wall banner is optional.
  No errors must be present.
- Set it up with cron and learn.
- Learn how to stop the cron job without modifying the script.
- The script must show the following information:
    - Architecture and kernel version
    - Number of physical cores
    - Number of virtual cores
    - Available RAM on your server and its usage as a percentage.
    - Usage as a percentage of your cores.
    - Date and time of of last reboot.
    - If LVM is active
    - Number of active connections
    - IPv4 address of your server and its MAC
    - Number of commands executed with sudo

[ ] Set up WordPress
[ ] Set up lighttpd
[ ] Set up MariaDB
[ ] Set up PHP
[ ] Set up a service that you consider useful. (Docker? boto3?)

