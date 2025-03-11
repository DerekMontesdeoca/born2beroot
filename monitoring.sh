#! /usr/bin/bash

set -euo pipefail

cpu_load=$(awk '
BEGIN {
    prev_total = 0
    prev_idle = 0
    for (i = 0; i < 2; i++) {
        if (i != 0) {
            system("sleep 1")
            prev_total = total
            prev_idle = idle
        }
        getline < "/proc/stat"
        close("/proc/stat")
        total = 0
        for (j = 2; j <= NF; j++)
            total += $j
        idle = $5
    }
    printf "%.1f %%\n", (1 - (idle - prev_idle) / (total - prev_total)) * 100
}')
default_interface=$(ip route | awk '/default/ {print $5}')
ip_addr=$(ip -br addr show "$default_interface" \
    | awk '{split($3, ip, "/"); print ip[1]}')
mac_addr=$(ip -br link show "$default_interface" | awk '{print $3}')
tcp_conns=$(ss --tcp state established | awk 'END {printf "%d", NR - 1}')
mem_usage=$(free --mebi \
    | awk '/Mem/ {printf "%d/%dMB (%.2f %%)", $3, $2, $3/$2*100}')
disk_usage=$(df --total --human-readable \
    | awk 'END {printf "%s/%s (%s)", $3, $2, $5}')
physical_cores=$(lscpu | awk -F ': *' '
/Core\(s\) per socket/ {cores=$2}
/Socket\(s\)/ {sockets=$2}
END {printf "%d", sockets*cores}')

cat << EOF

#Architecture: $(uname --all)
#CPU physical : $physical_cores
#vCPU : $(lscpu | awk '/^CPU\(s\)/ {print $2}')
#Memory Usage: $mem_usage
#Disk Usage: $disk_usage
#CPU load: $cpu_load
#Last boot: $(uptime -s)
#LVM use: $(if lvscan | grep -q 'ACTIVE'; then echo 'yes'; else echo 'no'; fi)
#TCP Connections : $tcp_conns ESTABLISHED
#User log: $(who -u | awk '{users[$1] = 1} END {print length(users)}')
#Network: IP $ip_addr ($mac_addr)
#Sudo : $(find "/var/log/sudo" -mindepth 3 -maxdepth 3 -type d | wc -l) cmd
EOF
