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

target_uid=${ANDROID_UID:-$(id -u "${user}")}
target_gid=${ANDROID_GID:-$(id -g "${user}")}
case ${target_uid}:${target_gid} in
    *[!0-9:]*|:*|*:) echo "ANDROID_UID and ANDROID_GID must be numeric" >&2; exit 66 ;;
esac

current_gid=$(id -g "${user}")
if [ "${current_gid}" != "${target_gid}" ]; then
    target_group=$(getent group "${target_gid}" | cut -d: -f1 || true)
    if [ -n "${target_group}" ]; then
        usermod --gid "${target_group}" "${user}"
    else
        groupmod --gid "${target_gid}" "${group}"
    fi
fi
current_uid=$(id -u "${user}")
if [ "${current_uid}" != "${target_uid}" ]; then
    usermod --uid "${target_uid}" "${user}"
fi
primary_group=$(id -gn "${user}")
chown "${user}:${primary_group}" "/home/${user}"

signing_dir=${YRRP_CERT_DIR:-/opt/yrrp/signing}
if [ -d "${signing_dir}" ]; then
    signing_owner=$(stat -c '%u:%g' "${signing_dir}")
    if [ "${signing_owner}" != "${target_uid}:${target_gid}" ]; then
        echo "${signing_dir} must be owned by ${target_uid}:${target_gid}; found ${signing_owner}" >&2
        exit 67
    fi
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

install -d -m 0700 -o "${user}" -g "${primary_group}" "${ssh_dir}"
printf '%s\n' "${SSH_AUTHORIZED_KEYS}" > "${authorized_keys}"
chown "${user}:${primary_group}" "${authorized_keys}"
chmod 0600 "${authorized_keys}"

install -d -m 0700 /etc/ssh/host-keys
if [ ! -s "${host_key}" ]; then
    ssh-keygen -q -t ed25519 -N '' -f "${host_key}"
fi

install -d -m 0755 -o root -g root /run/sshd
install -d -m 0777 -o root -g utmp /run/screen
exec "$@"
