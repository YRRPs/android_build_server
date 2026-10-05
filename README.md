# Android build server

Persistent Debian-based Android and LineageOS build environment with key-only SSH access. Source checkout, ccache, and SSH host identity survive container recreation.

## Requirements

- Docker Engine with Compose v2
- Host storage for Android source and ccache
- Public SSH key for every authorized operator

## Configure

```bash
cp .env.example .env
```

Replace `SSH_AUTHORIZED_KEYS` with a real public key. Set `SSH_BIND_ADDRESS` to a trusted LAN address when remote access is needed. Loopback remains the safe default.

Match `USER_UID` and `USER_GID` to owner of host workspace and ccache directories:

```bash
id -u
id -g
```

For multiple SSH keys, export one multiline value before startup:

```bash
export SSH_AUTHORIZED_KEYS="$(cat ~/.ssh/id_ed25519.pub)
$(cat ~/.ssh/second_builder_key.pub)"
```

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

Android source lives at `/opt/android`. Compiler cache lives at `/ccache`.

## Persistence and upgrades

Compose bind mounts preserve source and ccache. Named volume `ssh-host-keys` preserves server identity.

Before recreation, stop active builds and back up source changes, release keys, and any artifacts kept outside Git:

```bash
docker compose build --pull
docker compose up -d
docker compose ps
```

Deleting `workspace/`, `ccache/`, or `ssh-host-keys` destroys corresponding persistent state.

## Security model

This container is a trusted, single-tenant development host. SSH permits public-key authentication only and rewrites `authorized_keys` at every startup. User `android` has passwordless sudo inside container because Android build and maintenance workflows need administrative tools.

Do not expose SSH directly to public Internet. Restrict `SSH_BIND_ADDRESS` with host firewall or private network controls. Do not mount Docker socket into container. Keep `.env`, private keys, signing keys, source output, and build artifacts outside Git.

Container starts `sshd` as root, then SSH sessions run as `android`. This differs from fully non-root container guidance because OpenSSH supervises port 22 and creates user sessions. Host isolation still depends on Docker daemon, default seccomp/AppArmor policy, and absence of privileged mounts.

Security references:

- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

## Scope

Repository defines one persistent source/build container. Release-trigger workflows and latest-only OTA hosting belong in separate `ota_server` project.
