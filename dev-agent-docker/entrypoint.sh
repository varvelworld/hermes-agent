#!/bin/bash
set -e

HERMES_HOME="${HERMES_HOME:-/root/.hermes}"
INSTALL_DIR="/opt/hermes"
LARK_CLI_DATA_DIR="${LARKSUITE_CLI_DATA_DIR:-/root/.lark-cli/data}"

mkdir -p /root/.ssh
chmod 700 /root/.ssh

sed -i '/^http_proxy=/d;/^https_proxy=/d;/^HTTP_PROXY=/d;/^HTTPS_PROXY=/d;/^no_proxy=/d' /etc/environment
if [ -n "$http_proxy" ]; then
    printf 'http_proxy=%s\nhttps_proxy=%s\nHTTP_PROXY=%s\nHTTPS_PROXY=%s\nno_proxy=%s\n' \
        "$http_proxy" "$https_proxy" "$HTTP_PROXY" "$HTTPS_PROXY" "$no_proxy" >> /etc/environment
    cat > /etc/profile.d/proxy.sh <<EOF
export http_proxy=$http_proxy
export https_proxy=$https_proxy
export HTTP_PROXY=$HTTP_PROXY
export HTTPS_PROXY=$HTTPS_PROXY
export no_proxy=$no_proxy
EOF
else
    rm -f /etc/profile.d/proxy.sh
fi

if [ -f /tmp/host_pubkey ]; then
    cat /tmp/host_pubkey >> /root/.ssh/authorized_keys
fi
if [ -f /tmp/authorized_keys ]; then
    cat /tmp/authorized_keys >> /root/.ssh/authorized_keys
fi

if [ -f /root/.ssh/authorized_keys ]; then
    sort -u /root/.ssh/authorized_keys -o /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
fi

mkdir -p "$HERMES_HOME"/{cron,sessions,logs,hooks,memories,skills}

LEGACY_LARK_KEYCHAIN_DIR="/root/.local/share/lark-cli"
TARGET_LARK_KEYCHAIN_DIR="$LARK_CLI_DATA_DIR/lark-cli"
if [ -d "$LEGACY_LARK_KEYCHAIN_DIR" ] && [ ! -d "$TARGET_LARK_KEYCHAIN_DIR" ]; then
    mkdir -p "$(dirname "$TARGET_LARK_KEYCHAIN_DIR")"
    cp -R "$LEGACY_LARK_KEYCHAIN_DIR" "$TARGET_LARK_KEYCHAIN_DIR"
fi

if [ ! -f "$HERMES_HOME/.env" ] && [ -f "$INSTALL_DIR/.env.example" ]; then
    cp "$INSTALL_DIR/.env.example" "$HERMES_HOME/.env"
fi

if [ ! -f "$HERMES_HOME/config.yaml" ] && [ -f "$INSTALL_DIR/cli-config.yaml.example" ]; then
    cp "$INSTALL_DIR/cli-config.yaml.example" "$HERMES_HOME/config.yaml"
fi

if [ ! -f "$HERMES_HOME/SOUL.md" ] && [ -f "$INSTALL_DIR/docker/SOUL.md" ]; then
    cp "$INSTALL_DIR/docker/SOUL.md" "$HERMES_HOME/SOUL.md"
fi

if [ -d "$INSTALL_DIR/skills" ] && [ -f "$INSTALL_DIR/tools/skills_sync.py" ]; then
    python3 "$INSTALL_DIR/tools/skills_sync.py" 2>/dev/null || true
fi

echo "Starting SSH server..."
/usr/sbin/sshd -D &
SSHD_PID=$!

echo "Starting Hermes gateway..."
hermes gateway &
GATEWAY_PID=$!

cleanup() {
    kill "$GATEWAY_PID" 2>/dev/null || true
    kill "$SSHD_PID" 2>/dev/null || true
    wait "$GATEWAY_PID" 2>/dev/null || true
    wait "$SSHD_PID" 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

echo "=========================================="
echo "  Dev Agent Docker Ready"
echo "=========================================="
echo "  SSH:      ssh -p 2222 root@localhost"
echo "  Hermes:   hermes"
echo "  Gateway:  running in background"
echo "  OpenCode: opencode"
echo "  Claude:   claude"
echo "=========================================="

wait -n "$SSHD_PID" "$GATEWAY_PID"
EXIT_CODE=$?
kill "$GATEWAY_PID" 2>/dev/null || true
kill "$SSHD_PID" 2>/dev/null || true
wait "$GATEWAY_PID" 2>/dev/null || true
wait "$SSHD_PID" 2>/dev/null || true
exit "$EXIT_CODE"
