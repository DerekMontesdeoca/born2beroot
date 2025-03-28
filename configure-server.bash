#! /usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

script_dir=$(dirname "$0")

source "$script_dir/.env"

# Firewall
apt-get install ufw -y
if ! (ufw status | grep -q 'Status: active' \
    && ufw status numbered | grep -q -P '\[ 1] 4242/tcp.*ALLOW' \
    && ufw status numbered | grep -q -P '\[ 2] 4242/tcp.*ALLOW');
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
enforcing = 1
EOF

# Password expiry.
sed -i "/^PASS_MAX_DAYS/s/.*/PASS_MAX_DAYS\t30/" "/etc/login.defs"
sed -i "/^PASS_MIN_DAYS/s/.*/PASS_MIN_DAYS\t2/" "/etc/login.defs"
sed -i "/^PASS_WARN_AGE/s/.*/PASS_WARN_AGE\t7/" "/etc/login.defs"

# Change expiry of root because /etc/login.defs only affects new accounts.
chage --mindays 2 --maxdays 30 --warndays 7 root

# Add non-root user
if ! id $ENV_USERNAME; then
    adduser --disabled-password --gecos "" "$ENV_USERNAME"
    echo "$ENV_USERNAME:${ENV_USER_PASSWORD}" | chpasswd
fi

if ! getent group "user42"; then
    addgroup "user42"
fi

if ! id --groups --name "$ENV_USERNAME" \
    | tr ' ' $'\n' \
    | grep --quiet --line-regexp "user42"
then
    usermod --append --groups "user42" "$ENV_USERNAME"
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

usermod --append --groups "sudo" "root"
usermod --append --groups "sudo" "$ENV_USERNAME"

# Set up monitoring.
install --mode 755 --group "root" --owner "root" \
    "$script_dir/monitoring.sh" "/usr/local/bin"
crontab - << EOF
SHELL=/usr/bin/bash
PATH=/usr/local/bin:/usr/bin:/usr/sbin

*/10 * * * * monitoring.sh | wall -n
EOF

# ============ Install Wordpress ============ #
 
apt-get install --yes unzip curl php lighttpd mariadb-server pwgen \
    php php-mysql php-cgi

systemctl disable --now apache2
systemctl stop lighttpd

if ! command -v wp; then
    curl -O "https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
    chmod 755 "wp-cli.phar"
    mv "wp-cli.phar" "/usr/local/bin/wp"
fi

lighty-enable-mod fastcgi || true
lighty-enable-mod fastcgi-php || true
lighty-enable-mod accesslog || true

if [[ ! -d "wordpress" ]]; then
    curl --fail --location --remote-name "https://wordpress.org/latest.zip"
    trap "rm -f ~/latest.zip" EXIT
    unzip "latest.zip"
fi

env $(cat "$script_dir/.env") envsubst < "$script_dir/create-db.sql" | mysql

awk '
/DB_NAME/ {$3 = "'\'"$ENV_WORDPRESS_DATABASE"\''"}
/DB_USER/ {$3 = "'\'"$ENV_WORDPRESS_DATABASE_USER"\''"}
/DB_PASSWORD/ {$3 = "'\'"$ENV_WORDPRESS_DATABASE_USER_PASSWORD"\''"}
/put your unique phrase here/ {
    "pwgen -s 64 1" | getline phrase
    gsub("put your unique phrase here", phrase)
    close ("pwgen -s 64 1")
}
{print}' "wordpress/wp-config-sample.php" > "wordpress/wp-config.php"

rsync -azv "wordpress/" "/var/www/html"
chmod -R 755 "/var/www/html"
chown -R "www-data:www-data" "/var/www/html" 

systemctl enable --now lighttpd

ufw allow in from any to any port 80

default_interface=$(ip route | awk '/default/ {print $5}')
ip_addr=$(ip -br addr show "$default_interface" \
    | awk '{split($3, ip, "/"); print ip[1]}')

su "www-data" --shell "/bin/bash" -c \
    "\
wp core install \
    --path=\"/var/www/html\" \
    --url=\"$ip_addr\" \
    --title=\"$ENV_WORDPRESS_TITLE\" \
    --admin_user=\"$ENV_WORDPRESS_ADMIN_USER\" \
    --admin_email=\"$ENV_WORDPRESS_ADMIN_EMAIL\" \
    --admin_password=\"$ENV_WORDPRESS_ADMIN_PASSWORD\""

# ============ #

# Fail2ban: protection against brute force attacks.
apt-get install --yes fail2ban 
cat << EOF > "/etc/fail2ban/jail.d/jail.custom"
[DEFAULT]
backend = auto
bantime = 10m
maxretry = 5
findtime = 30m
logtarget = SYSTEMD-JOURNAL

[sshd]
enabled = true
backend = systemd

[lighttpd]
backend = polling
enabled = true
port = http,https
logpath = /var/log/lighttpd/access.log
action = ufw
filter = lighttpd_auth
EOF

systemctl enable fail2ban
systemctl restart fail2ban

# Remove script from .profile
sed -i '/\/root\/born2beroot\/configure-server.bash/d' "/root/.profile"
shred -u "/root/born2beroot/.env"
rm -rf "/root/born2beroot"
