#!/bin/sh
set -eu

group_name="$(awk -F: -v gid="${BORG_GID}" '$3 == gid { print $1; exit }' /etc/group)"
if [ -z "$group_name" ]; then
  addgroup -S -g "${BORG_GID}" "${BORG_USER}"
  group_name="${BORG_USER}"
fi

if ! id -u "${BORG_USER}" >/dev/null 2>&1; then
  adduser -S -D -u "${BORG_UID}" -h "/home/${BORG_USER}" -s /bin/sh -G "$group_name" "${BORG_USER}"
fi

passwd -d "${BORG_USER}" >/dev/null 2>&1 || true

install -d -o "${BORG_UID}" -g "${BORG_GID}" -m 755 "/home/${BORG_USER}"
install -d -o "${BORG_UID}" -g "${BORG_GID}" -m 700 "/home/${BORG_USER}/.ssh"
install -d -o "${BORG_UID}" -g "${BORG_GID}" -m 750 /var/backup/borg

tr -d '\r' < /config/authorized_keys > "/home/${BORG_USER}/.ssh/authorized_keys"
chown "${BORG_UID}:${BORG_GID}" "/home/${BORG_USER}/.ssh/authorized_keys"
chmod 600 "/home/${BORG_USER}/.ssh/authorized_keys"

install -d -m 755 /run/sshd
install -d -m 755 /var/empty

if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
  ssh-keygen -A
fi

cat > /etc/ssh/sshd_config <<EOF
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AllowUsers ${BORG_USER}
AuthorizedKeysFile /home/${BORG_USER}/.ssh/authorized_keys
LogLevel VERBOSE
PidFile /run/sshd.pid
ChrootDirectory none
EOF

exec "$@"
