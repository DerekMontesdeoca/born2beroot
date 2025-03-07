#! /usr/bin/bash

set -euo pipefail

default_interface=$(ip route | grep default | awk '{print $5}')
ip_addr=$(ip -br addr show "$default_interface" \
    | awk '{split($3, ip, "/"); print ip[1]}')
mac_addr=$(ip -br link show "$default_interface" | awk '{print $3}')

cat << EOF
#Architecture: $(uname --all)
#CPU physical : $(lscpu | awk -F ': *' '
/Core\(s\) per socket/ {cores=$2}
/Socket\(s\)/ {sockets=$2}
END {printf "%d" sockets*cores}')
#vCPU : $(lscpu | grep '^CPU(s)' | awk '{print $2}')
#Memory Usage: $(free --mebi | grep 'Mem' | awk '{printf "%d/%dMB (%.2f %%)", $3, $2, $3/$2*100}')
#Disk Usage: $(df --total --human-readable | tail -n1 | awk '{printf "%s/%s (%s)", $3, $2, $5}')
#CPU load: $(grep '^cpu\>' "/proc/stat" | awk '
{
    sum=0;
    for (i=2; i<=NF; i++)
        sum+=$i
    printf "%.1f %%\n", (1 - $5/sum) * 100
}')
#Last boot: $(uptime -s)
#LVM use: $(if lvscan | grep -q 'ACTIVE'; then echo 'yes'; else echo 'no'; fi)
#TCP Connections : $(ss --tcp state established | awk '{printf "%d", $1 - 1}') ESTABLISHED
#User log: $(who -u | wc -l)
#Network: IP $ip_addr ($mac_addr)
#Sudo : $(find "/var/log/sudo" -mindepth 3 -maxdepth 3 -type d | wc -l) cmd
