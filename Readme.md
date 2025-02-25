# BORN2BEROOT

## TODO

- [x] Change boot partition to ext4.
- [ ] Come up with better names for the scripts.
- [ ] Should I use .bash or .sh? Research it.


## Assignment Requirements

- [x] Create encrypted partitions with LVM. For the bonus, create the following partition table:
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
- [x] Mount 
- [x] Set hostname to {login}42.
- [x] Set up root passwd and admin user.
- [ ] Set up the following users:
    - root
    - {user}
- [ ] Make sure that {user} user belongs to the groups user42 and sudo.
- [ ] Install ssh server.
- [ ] Configure ssh server. 
- [ ] Execute SSH on port 4242.
- [ ] Make sure SSH is unavailable for root.
- [ ] Configure firewall to only allow inc 4242.
- [ ] Learn how to change the hostname for the defense.
- [ ] Set password policy:
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
- [ ] Set up sudo and configure it:
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
- [ ] Learn how to create a user and assign it to a group for the defense.
- [ ] After setting up configuration files, change all passwords on the VM, including root.
- [ ] Create a monitoring script called monitoring.sh:
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
- [ ] Set up WordPress
- [ ] Set up lighttpd
- [ ] Set up MariaDB
- [ ] Set up PHP
- [ ] Set up a service that you consider useful. (Docker? boto3?)


## Steps to Complete the Assginment

### Install Minimal Debian
Start by installing a minimal debian using debootsrap from a live ISO.
1. Configure locale.
2. Adjust time.
3. Install lvm2 cryptsetup parted.
4. Make partitions.
5. LuksFormat main partition.
6. Open main partition.
7. Make PVs and create VGs and LVs.
8. Make filesystems.
9. Create a chroot directory.
10. Mount new partitions to chroot dir.
11. Debootstrap into chroot dir.
12. Copy apt keyrings into chroot dir.
12. Mount system dirs into chroot dir with make-rslave.
13. chroot into chroot dir.
14. apt update and upgrade.
15. Set up hostname.
16. Install, uncomment and generate locale.
17. Generate loopback network interface and default dhcp interface.
18. Create fstab.
19. Create crypttab.
20. Install lvm2, cryptsetup, cryptsetup-initramfs and grub.
21. Install kernel.
22. Update initramfs.
23. Install grub.
24. Update grub.
25. Exit chroot.
26. umount partitions.
27. Reboot.

### Configure the System
Now, with the system running and updated, install all the programs and set all the configuration to meet the requirements of the assignment.
1.

## Learning Topics

### VirtualBox
[VBoxManage Manual](https://www.virtualbox.org/manual/ch08.html)<br>
Hypervisor for virtual machines.
#### Commands
- createvm - Create a vm with os type and name
- modifyvm - Assign boot, memory, cpus, resources
- storagectl - Add and remove physical storage controllers.
- storageattach - Attach media to controllers.
- startvm - start vm
- createmedium - Create storage mediums like virtual disks.
- unregistervm - Unregister and delete vm.

### udev
[ArchWiki](https://wiki.archlinux.org/title/Udev)<br>
udev is the Linux device manager responsible for dynamic device detection and management. It runs in user space and interacts with the kernel's device events, processing them asynchronously.
- Belongs to the systemd family and only works with systemd.
- Creates device nodes dynamically in /dev.
- Uses and applies naming rules for devices.
- Triggers scripts or actions when devices are pluggeed in or removed.
- Provides persistent naming for devices based on UUID.

#### Device Connection Flow
1. Kernel detects a device and triggers a new event.
2. udev daemon (udevd) receives the event and matches it to rules in /etc/udev/rules.d/
3. udev applies rules like:
    - Create device in /dev
    - Set permissions.
    - Create symlinks.
    - Execute scripts.
4. Device is available for use.

### Network via /etc/network/interfaces.d (ifup ifdown)
Manages basic networking and comes default with most linux configurations, although most distros prefer using networkd (systemd) or network manager (nmcli).
#### Loopback
```
auto lo
iface lo inet loopback
```
- auto - The device should be mounted on boot.
- inet - IPv4 protocol.
- loopback - Specifies loopback device. Loopback devices allow a machine to communicate with itself in a safe way without having to go through the physical hardware interface. Typically set to 127.0.0.1 or localhost.

#### dhcp
```
auto $interface_name
iface $interface_name inet dhcp
```
- dhcp - Queries the dhcp server for an ip.

### VBox Networking
Networks in Virtual Box machines come as virtual networks that connect the host with the guest. The following configurations are offered:
- Not attached: Represents a network card that is present but has no connection, as if no Ethernet cables was plugged into the card.
- Bridged networking: Creates a bridged connection, making the guest its own member of the network.
- Nat: Network address translation by the host, making the guest unaccessible from the outside but allowing it to communicate from within.
- Nat networking: Same as nat but allows multiple guests to communicate amongst each other.
- Host-only networking: Provides a network only for host and guests.
- Internal networking: Provides a network only for guests.

### ISO repackaging
ISO's can be modified to include different things. For example, you can modify an ISO image for debian to include scripts or programs required to perform the installation.
1. The ISO image needs to be mounted to the FS on a loopback device /dev/loopX. You can check loopback devices using `losetup`. `mount` should be able to automatically recognize that -o loop is required, but if it doesn't, you may have to specify `mount -o loop`. 
2. Copy the contents to a writable dir, as ISO images are read-only.
3. Modify the contents.
4. Repackage the ISO using `xorriso`. However, specific options required for the command need to be researched further.
A possible workaround for mounting is using `xorriso` on "ossirox" mode, which allows for removing and adding files.

### dm-crypt / cryptsetup / dmsetup / LUKS
[ArchWiki](https://wiki.archlinux.org/title/Dm-crypt/System_configuration)<br>
These commands and technologies are all related to disk encryption and mapping.<br>
<br>
**dm-crypt** is the linux kernel's device mapper crypto target. Device mapper is infrastructure in the Linux kernel that provide a generic way to create virtual layers of block devices. Writes to this device will be encrypted  and read decrypted. dm-crypt works at the kernel level, translating on the fly.<br>
<br>
**cryptsetup** is what you use to interface with dm-crypt as it runs on user-space.<br>
<br>
**dmsetup** is the low-level device mapper interface for managing devices in Linux.
- List mappings with `dmsetup ls`.
- Get detailed info with `dmsetup info luks-234234`.
- Remove a mapped device `dmsetup remove luks-123948`.
<br>

**LUKS (Linux Unified Key Setup)** is a disk encryption standard in Linux. LUKS includes a standardized metadata header tha allows for:
- Multiple key slots
- Secure passphrase changes
- Hardware compatibility with bootloaders
- Key stretching?
<br>

The main use for these commands is encrypting disks and partitions. Basic commands for using cryptsetup with LUKS for encrypting a partition are the following:
```sh
# Format a new partition with LUKS. You can provide a passphrase or a key.
cryptsetup luksFormat /dev/sda5

# Decrypt a partition with LUKS. The partition will be mapped to 
# /dev/mapper/sda5_crypt
cryptsetup open --type LUKS /dev/sda5 sda5_crypt

cryptsetup close /dev/mapper/sda5_crypt

# Ask if a partition has a LUKS header.
cryptsetup isLuks /dev/sda5
```
** If you want to close a luks partition that has LVM on it, make sure to deactivate the volume groups from the partition to avoid it telling you the partition is busy.<br>
If you are using LVM you can have LVM on LUKS or LUKS on LVM. They both have their trade-offs and caveats.<br>

#### Booting with encrypted disks
The main issue with encrypting the system comes with booting. When you boot, the bootloader won't be able to find the root partition because it is encrypted. In order to decrypt it, the initial ram filesystem (initramfs) needs to load the required programs in order to decrypt the partitions and mount them. In debian this is done automatically when setting up your crypttab, updating your initramfs and updating you bootloader. 

#### crypttab (Crypto Table Mapping)
fstab for crypt. Practically works in the same way. Located at /etc/crypttab, this file specifies which crypt targets to mount automatically. This is meant to be used for fs's that should be decrypted after root has loaded, however, debian uses this files to configure your initramfs, making the process a lot easier and allowing you to specify on this file all the devices you want decrypted. You still need to update you initramfs and your bootloader.
The format is the following:
```
# ============ /etc/crypttab ============ #

# Example crypttab file. Fields are: name, underlying device, passphrase, cryptsetup options.

# Mount /dev/lvm/swap re-encrypting it with a fresh key each reboot
swap	/dev/lvm/swap	/dev/urandom	swap,cipher=aes-xts-plain64,size=256,sector-size=4096

# Mount /dev/lvm/tmp as /dev/mapper/tmp using plain dm-crypt with a random passphrase, making its contents unrecoverable after it is dismounted.
tmp	/dev/lvm/tmp	/dev/urandom	tmp,cipher=aes-xts-plain64,size=256 

# Mount /dev/lvm/home as /dev/mapper/home using LUKS, and prompt for the passphrase at boot time.
home   /dev/lvm/home

# Mount /dev/sdb1 as /dev/mapper/backup using LUKS, with a passphrase stored in a file.
backup /dev/sdb1       /home/alice/backup.key

# Unlock /dev/sdX using the only available TPM, naming it myvolume
myvolume	/dev/sdX	none	tpm2-device=auto

```
I learned that discard option allows for special trim optimizations for SSD's. But discard only allows the optimizations to be allowed to bypass the encryption, if you actually want the optimizations, you need to enable them, e.g. continuous or scheduled TRIM.

### LVM
[ArchWiki](https://wiki.archlinux.org/title/LVM)

### hostname
### initramfs
### Grub
### fstab
### Locales
### Keyrings
### Chroot
### Linux kernel images
### mount (--make-rslave --bind -o --X-mount.mkdir)
### boot partition
### MBR vs GPT
### Alignment on partitions
### lsblk
### blkid
### TTY
### lsof
### fuser
### findmnt
### AppArmor
### ss
### aa-status
### ufw
### nmap - Useful and almost essential for networking and security

