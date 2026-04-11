# =============================================================================
# Dockerfile — Dev Agent Docker container (Hermes + OpenCode + Claude Code + SSH)
# Base: Ubuntu 24.04 | Python 3.12 | Node.js 22 LTS | Go 1.22
# =============================================================================
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG GO_VERSION=1.22.5

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential gcc g++ make cmake \
        curl wget git ripgrep jq unzip zip less vim nano \
        bash-completion \
        ca-certificates gnupg lsb-release \
        openssh-server \
        python3 python3-pip python3-venv python3-dev \
        libffi-dev libssl-dev \
        locales \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANGUAGE=en_US:en

ARG NODE_VERSION=22.14.0
RUN ARCH=$(dpkg --print-architecture) \
    && case "$ARCH" in \
         amd64) NODE_ARCH=x64 ;; \
         arm64) NODE_ARCH=arm64 ;; \
         *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
       esac \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
       | tar -xJ -C /usr/local --strip-components=1 \
    && npm install -g npm@latest

RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" \
       | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:/root/go/bin:${PATH}"

RUN mkdir -p /run/sshd /root/.ssh \
    && chmod 700 /root/.ssh \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config \
    && echo 'AcceptEnv TERM' >> /etc/ssh/sshd_config \
    && ssh-keygen -A

EXPOSE 22

COPY . /opt/hermes
WORKDIR /opt/hermes

RUN pip install --no-cache-dir -e ".[all]" --break-system-packages
RUN npm install -g opencode-ai
RUN npm install -g @anthropic-ai/claude-code
RUN npm install -g @larksuite/cli

COPY dev-agent-docker/entrypoint.sh /usr/local/bin/dev-agent-docker-entrypoint.sh
RUN chmod +x /usr/local/bin/dev-agent-docker-entrypoint.sh

ENV HERMES_HOME=/root/.hermes \
    PATH="/root/.local/bin:/usr/local/go/bin:/root/go/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

RUN echo 'export PATH="/root/.local/bin:/usr/local/go/bin:/root/go/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"' >> /root/.bashrc \
    && echo '[[ -f /usr/share/bash-completion/bash_completion ]] && source /usr/share/bash-completion/bash_completion' >> /root/.bashrc \
    && echo 'export PATH="/root/.local/bin:/usr/local/go/bin:/root/go/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"' >> /root/.profile \
    && echo 'PATH="/root/.local/bin:/usr/local/go/bin:/root/go/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"' > /etc/environment

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/dev-agent-docker-entrypoint.sh"]
CMD ["sleep", "infinity"]
