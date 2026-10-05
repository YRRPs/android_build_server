FROM debian:trixie

ARG USER=android
ARG USER_UID=1000
ARG USER_GID=1000

ENV CCACHE_DIR=/ccache \
    CCACHE_MAXSIZE=100G \
    CCACHE_NOCOMPRESS=true \
    USE_CCACHE=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        adb \
        bc \
        bison \
        build-essential \
        ca-certificates \
        ccache \
        curl \
        e2fsprogs \
        erofs-utils \
        fastboot \
        flex \
        g++-multilib \
        gcc-multilib \
        git \
        git-lfs \
        gnupg \
        gperf \
        imagemagick \
        libdw-dev \
        less \
        lib32readline-dev \
        lib32z1-dev \
        libelf-dev \
        libgnutls28-dev \
        libsdl1.2-dev \
        libssl-dev \
        libxml2 \
        libxml2-utils \
        lz4 \
        lzop \
        nano \
        openssh-client \
        openssh-server \
        pngcrush \
        protobuf-compiler \
        python-is-python3 \
        python3 \
        python3-protobuf \
        rsync \
        screen \
        schedtool \
        squashfs-tools \
        sudo \
        unzip \
        xsltproc \
        xxd \
        zip \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${USER_GID}" "${USER}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/bash "${USER}" \
    && printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "${USER}" > "/etc/sudoers.d/${USER}" \
    && chmod 0440 "/etc/sudoers.d/${USER}" \
    && install -d -o "${USER}" -g "${USER}" /opt/android /ccache /home/${USER}/.ssh /etc/ssh/host-keys /run/sshd

RUN curl --fail --location --show-error --silent \
        https://storage.googleapis.com/git-repo-downloads/repo \
        --output /usr/local/bin/repo \
    && chmod 0755 /usr/local/bin/repo

RUN printf '%s\n' \
        'HostKey /etc/ssh/host-keys/ssh_host_ed25519_key' \
        'PasswordAuthentication no' \
        'KbdInteractiveAuthentication no' \
        'PermitRootLogin no' \
        'PubkeyAuthentication yes' \
        'AllowUsers android' \
        'X11Forwarding no' \
        'GatewayPorts no' \
        'SetEnv PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
        > /etc/ssh/sshd_config.d/android.conf

COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

WORKDIR /opt/android
EXPOSE 22

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
