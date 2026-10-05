#!/bin/sh
set -eu

user=android
group=android
ssh_dir=/home/${user}/.ssh
authorized_keys=${ssh_dir}/authorized_keys
host_key=/etc/ssh/host-keys/ssh_host_ed25519_key
docker_socket=/var/run/docker.sock

if [ -z "${SSH_AUTHORIZED_KEYS:-}" ]; then
    echo "SSH_AUTHORIZED_KEYS must contain at least one public key" >&2
    exit 64
fi

if [ -e "${docker_socket}" ]; then
    if [ ! -S "${docker_socket}" ]; then
        echo "${docker_socket} exists but is not a Unix socket" >&2
        exit 65
    fi
    docker_gid=$(stat -c '%g' "${docker_socket}")
    docker_group=$(getent group "${docker_gid}" | cut -d: -f1 || true)
    if [ -z "${docker_group}" ]; then
        docker_group=docker-host
        groupadd --gid "${docker_gid}" "${docker_group}"
    fi
    usermod -aG "${docker_group}" "${user}"
else
    echo "Warning: ${docker_socket} is absent; OTA deployment will be unavailable" >&2
fi

install -d -m 0700 -o "${user}" -g "${group}" "${ssh_dir}"
printf '%s\n' "${SSH_AUTHORIZED_KEYS}" > "${authorized_keys}"
chown "${user}:${group}" "${authorized_keys}"
chmod 0600 "${authorized_keys}"

install -d -m 0700 /etc/ssh/host-keys
if [ ! -s "${host_key}" ]; then
    ssh-keygen -q -t ed25519 -N '' -f "${host_key}"
fi

install -d -m 0755 -o root -g root /run/sshd
exec "$@"
