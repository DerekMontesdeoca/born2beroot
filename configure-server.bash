#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

script_dir=$(dirname "$0")

set -a
source "$script_dir/.env"
set +a

# Firewall
apt-get install ufw -y
if ufw status | grep -q 'Status: active' \
    && ufw status numbered | grep -q -P '\[ 1] 4242/tcp.*ALLOW' \
    && ufw status numbered | grep -q -P '\[ 2] 4242/tcp.*ALLOW';
then
    ufw --force reset
    ufw logging on
    ufw logging full
    ufw default allow outgoing
    ufw default deny incoming
    ufw default deny routed
    ufw allow in proto tcp from any to any port "$ENV_SSH_PORT"
    ufw enable
    ufw status verbose | grep -q 'Status: active'
fi

# Check AppArmor
apt-get install --yes apparmor
aa-status | grep -q 'apparmor module is loaded'

# systemd-timesync
apt-get install --yes systemd-timesyncd
systemctl status --no-pager systemd-timesyncd

# ssh
apt-get install --yes ssh
if ! systemctl status --no-pager sshd; then
    systemctl enable ssh
fi
if [[ ! -f "/etc/ssh/sshd_config.old" ]]; then
    cp "/etc/ssh/sshd_config" "/etc/ssh/sshd_config.old"
fi
cat > "/etc/ssh/sshd_config" << EOF 
AcceptEnv LANG LC_*
X11Forwarding no
Port 4242
PermitRootLogin no
PermitEmptyPasswords no
MaxSessions 3
MaxAuthTries 3
PasswordAuthentication yes
PubKeyAuthentication yes
ClientAliveInterval 60
ClientAliveCountMax 3
UsePAM yes
EOF

systemctl restart ssh

# pwquality
apt-get install --yes libpam-pwquality

if [[ ! -f "/etc/security/pwquality.conf.old" ]]; then
    cp "/etc/security/pwquality.conf" "/etc/security/pwquality.conf.old" 
fi
cat << EOF > "/etc/security/pwquality.conf"
difok = 7
minlen = 10
lcredit = -1
dcredit = -1
ucredit = -1
maxrepeat = 3
usercheck = 1
enforce_for_root
EOF

# Password expiry.
sed -i "/^PASS_MAX_DAYS/s/.*/PASS_MAX_DAYS\t30/" "/etc/login.defs"
sed -i "/^PASS_MIN_DAYS/s/.*/PASS_MIN_DAYS\t2/" "/etc/login.defs"
sed -i "/^PASS_WARN_AGE/s/.*/PASS_WARN_AGE\t7/" "/etc/login.defs"

# Add non-root user
if ! id $ENV_USERNAME; then
    adduser --disabled-password --gecos "" "$ENV_USERNAME"
    echo "$ENV_USERNAME:${ENV_USER_PASSWORD}" | chpasswd
fi

if ! getent group "$ENV_HOSTNAME"; then
    addgroup "$ENV_HOSTNAME"
fi

if ! id --groups --name "$ENV_USERNAME" | tr ' ' $'\n' | grep -q "^${ENV_HOSTNAME}$"; then
    usermod --append --groups "$ENV_HOSTNAME" "$ENV_USERNAME"
fi

# Set up sudo
apt-get install --yes sudo

mkdir -p "/var/log/sudo"

tee << EOF >(visudo -c "/dev/stdin" > /dev/null) | cat > "/etc/sudoers.d/custom"
Defaults passwd_tries=3
Defaults badpass_message="How many times do you need to type the password to learn it?"
Defaults log_input
Defaults log_output
Defaults iolog_dir="/var/log/sudo"
Defaults iolog_file="%Y%m%d_%{user}_%{command}_%{seq}"
Defaults requiretty
EOF

usermod --append --groups "sudo" "$ENV_USERNAME"

# Set up monitoring.
install --mode 755 --group "root" --owner "root" \
    "$script_dir/monitoring.sh" "/usr/local/bin"
crontab - << EOF
SHELL=/usr/bin/bash
PATH=/usr/local/bin:/usr/bin:/usr/sbin

*/10 * * * * monitoring.sh | wall -n
EOF

# Remove script from .profile
sed -i '/\/root\/born2beroot\/configure-server.bash/d' "/root/.profile"
shred -u "/root/born2beroot/.env"
rm -rf "/root/born2beroot"
