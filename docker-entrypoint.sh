#!/bin/sh
set -eu

user=android
group=android
ssh_dir=/home/${user}/.ssh
authorized_keys=${ssh_dir}/authorized_keys
host_key=/etc/ssh/host-keys/ssh_host_ed25519_key

if [ -z "${SSH_AUTHORIZED_KEYS:-}" ]; then
    echo "SSH_AUTHORIZED_KEYS must contain at least one public key" >&2
    exit 64
fi

install -d -m 0700 -o "${user}" -g "${group}" "${ssh_dir}"
printf '%s\n' "${SSH_AUTHORIZED_KEYS}" > "${authorized_keys}"
chown "${user}:${group}" "${authorized_keys}"
chmod 0600 "${authorized_keys}"

install -d -m 0700 /etc/ssh/host-keys
if [ ! -s "${host_key}" ]; then
    ssh-keygen -q -t ed25519 -N '' -f "${host_key}"
fi

install -d -m 0755 /run/sshd
exec "$@"
