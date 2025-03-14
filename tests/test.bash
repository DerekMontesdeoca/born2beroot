#! /usr/bin/bash

set -xeuo pipefail

# sshd listening on port 4242.
ss --tcp --listen --numeric --oneline --no-header --ipv4 --processes sport 4242 \
    | grep --quiet "sshd"


# debian_version is latest stable.
stable_version=$(curl --silent --fail \
    'https://deb.debian.org/debian/dists/stable/Release' \
    | grep --ignore-case "version" | awk -F': ' '{print $2}')

[[ "$stable_version" == "$(cat "/etc/debian_version")" ]]

# Firewall
command -v ufw
ufw status verbose | grep --quiet 'Status: active'
ufw status verbose | grep --line-regexp "Default: deny (incoming), allow \
(outgoing), disabled (routed)"
ufw status numbered | grep --quiet --extended-regexp --ignore-case \
    --line-regexp '\[[[:space:]]*[[:digit:]]+\][[:space:]]+4242/tcp[[:space:]]'\
'+allow in[[:space:]]+anywhere[[:space:]]*'

# Hostname
[[ $(hostname) == "dmontesd42" ]]
[[ $(cat "/etc/hostname") == "dmontesd42" ]]
grep --quiet "dmontesd42" "/etc/hosts"

# User
getent passwd "root"
getent passwd "dmontesd"
user_groups=$(id --groups --name "dmontesd" | tr ' ' $'\n')
echo "${user_groups[*]}" | grep --quiet --line-regexp "user42"
echo "${user_groups[*]}" | grep --quiet --line-regexp "sudo" 

# Account expiration and age
awk -F':' '
/^dmontesd|root/ {
    if (!($4 == 2 && $5 == 30 && $6 == 7))
        exit 1
}' "/etc/shadow"

awk '
/^PASS_MAX_DAYS/ {if ($2 != 30) exit 1}
/^PASS_MIN_DAYS/ {if ($2 != 2) exit 1}
/^PASS_WARN_DAYS/ {if ($2 != 7) exit 1}
' "/etc/login.defs"

# pwquality

