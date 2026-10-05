#!/bin/bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
project_path=${YRRP_TEST_PROJECT_PATH:-${scratch}/project}
image=yrrp-android-builder-entrypoint-test
container=yrrp-android-builder-entrypoint-test-$$

if [ -z "${YRRP_TEST_PROJECT_PATH:-}" ]; then
    mkdir -p "${project_path}/scripts"
    printf '#!/bin/sh\nexit 0\n' > "${project_path}/scripts/sign-lineage-build.sh"
    chmod +x "${project_path}/scripts/sign-lineage-build.sh"
fi

cleanup() {
    docker rm -f "${container}" >/dev/null 2>&1 || true
    docker image rm -f "${image}" >/dev/null 2>&1 || true
    rm -rf "${scratch}"
}
trap cleanup EXIT

docker build -t "${image}" "${repo}"
docker run -d \
    --name "${container}" \
    -e 'SSH_AUTHORIZED_KEYS=ssh-ed25519 AAAA_SYNTHETIC test' \
    --tmpfs /run \
    --tmpfs /tmp:exec,mode=1777 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${project_path}:/opt/yrrp/project:ro" \
    "${image}" >/dev/null

for _ in $(seq 1 30); do
    if docker exec "${container}" /usr/sbin/sshd -t >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
docker exec "${container}" /usr/sbin/sshd -t

docker exec "${container}" docker version >/dev/null
docker exec "${container}" docker buildx version >/dev/null
docker exec "${container}" docker compose version >/dev/null

socket_gid=$(docker exec "${container}" stat -c '%g' /var/run/docker.sock)
docker exec "${container}" id -G android | tr ' ' '\n' | grep -qx "${socket_gid}"
docker exec "${container}" test -x /opt/yrrp/project/scripts/sign-lineage-build.sh
if docker exec "${container}" touch /opt/yrrp/project/.write-test 2>/dev/null; then
    echo 'canonical project mount is writable' >&2
    exit 1
fi

printf 'Builder Docker socket contract passed\n'
