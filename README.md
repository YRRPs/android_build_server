# Android build server

Persistent Debian-based Android and LineageOS build environment with key-only SSH access. Source checkout, ccache, SSH identity, signing workflow, and local OTA deployment survive container recreation.

## Requirements

- Docker Engine with Compose v2
- Host storage for Android source and ccache
- Public SSH key for every authorized operator
- Host clone of [`Yim-s-Riced-ROM-Project/project`](https://github.com/Yim-s-Riced-ROM-Project/project)
- Existing external Docker network `proxy-net`

## Configure

```bash
cp .env.example .env
```

Set:

- `SSH_AUTHORIZED_KEYS` to trusted public key.
- `SSH_BIND_ADDRESS` to VPN/LAN address.
- `USER_UID` and `USER_GID` to host storage owner.
- `YRRP_PROJECT_PATH` to absolute host path of canonical project clone.
- `OTA_PUBLIC_BASE_URL` to user-managed public HTTPS origin before signing releases.

For multiple SSH keys, export one multiline value before startup.

## Start

```bash
mkdir -p workspace ccache
docker compose config -q
docker compose up -d --build
docker compose ps
```

Connect using configured address and port:

```bash
ssh -p 4242 android@127.0.0.1
```

Android source lives at `/opt/android`. Compiler cache lives at `/ccache`. Canonical release tooling is mounted read-only at `/opt/yrrp/project`.

## Release signing and OTA deployment

Run only canonical mounted script:

```bash
/opt/yrrp/project/scripts/sign-lineage-build.sh
```

Successful release-key signing automatically builds latest-only local OTA image and replaces labeled `yrrp-ota-server` on `proxy-net`. Deployment health failure restores previous healthy release.

Signing requires valid `OTA_PUBLIC_BASE_URL`, reachable Docker daemon, public OTA base image, and existing `proxy-net`.

## Persistence and upgrades

Compose bind mounts preserve source and ccache. Named volume `ssh-host-keys` preserves server identity. Stop active builds before recreating builder.

```bash
docker compose pull
docker compose up -d
docker compose ps
```

Local `docker compose up -d --build` remains supported for development.

## Security model

Builder is trusted, single-tenant host reachable only through VPN. SSH uses public-key authentication and rewrites `authorized_keys` at startup. User `android` has passwordless sudo inside container.

Builder mounts `/var/run/docker.sock`. Docker socket access is equivalent to unrestricted root authority on TrueNAS host: any builder operator or compromised build can create privileged containers, mount host filesystems, read host data, and replace services. Read-only socket mounting would not remove this authority.

This accepted exception requires:

- VPN-restricted, key-only SSH;
- trusted operators and source;
- socket mounted only into builder;
- canonical project scripts mounted read-only;
- OTA deployer refusing non-YRRP containers and images;
- OTA serving container never receiving Docker socket.

See [OWASP Docker Security Cheat Sheet Rule 1](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html#rule-1---do-not-expose-the-docker-daemon-socket-even-to-the-containers).

Keep `.env`, private keys, signing keys, source output, target-files, and release artifacts outside Git and container image build contexts.

## Published image

GitHub Actions publishes amd64 builder image:

```text
ghcr.io/yim-s-riced-rom-project/android-build-server:main
```

Pull requests build without publishing. Main, version tags, and manual runs publish SBOM/provenance-enabled images.
