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

declare -A rules
rules=(PASS_MAX_DAYS 30 PASS_MIN_DAYS 2 PASS_WARN_AGE 7)
for rule in "${!rules[@]}"; do
    grep "^$rule" "/etc/login.defs" | awk '{if ($2 != '"${rules[$rule]}"') exit 1}' 
done

# pwquality
rules=(
    minlen 10 ucredit -1 dcredit -1 lcredit -1 maxrepeat 3 usercheck 1 
    enforcing 1 difok 7 enforce_for_root
)
for rule in "${!rules[@]}"; do
    grep "^$rule" "/etc/security/pwquality.conf" \
        | awk -v rule="${rules[$rule]}" '{if ($3 != rule) exit 1}' 
done

# Sudoers
sudoers_files=("/etc/sudoers" $(find "/etc/sudoers.d" -type f))
rules=(
    passwd_tries 3 badpass_message "" log_input "" log_output ""
    iolog_dir "\"/var/log/sudo\"" requiretty "" secure_path ""
)
for rule in "${!rules[@]}"; do
    grep --no-filename "^Defaults[[:space:]]*$rule" "${sudoers_files[@]}" \
        | awk -F'=' -v value="${rules[$rule]}" '{if (value != "" && $2 != value) exit 1}'
done

