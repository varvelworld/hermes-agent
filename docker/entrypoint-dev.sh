#!/bin/bash
# =============================================================================
# entrypoint-dev.sh — Dev Agent container bootstrap
# 1. Import SSH public key from mounted volume
# 2. Initialize Hermes config (first-run only)
# 3. Start sshd daemon
# 4. Execute CMD (default: sleep infinity)
# =============================================================================
set -e

HERMES_HOME="${HERMES_HOME:-/root/.hermes}"
INSTALL_DIR="/opt/hermes"
LARK_CLI_DATA_DIR="${LARKSUITE_CLI_DATA_DIR:-/root/.lark-cli/data}"

# ---------------------------------------------------------------------------
# SSH: import host public key
# ---------------------------------------------------------------------------
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Persist proxy settings so SSH sessions inherit them
# Write to both /etc/environment (PAM) and /etc/profile.d/ (login shells)
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

# Support mounting a single pubkey file or an authorized_keys file
if [ -f /tmp/host_pubkey ]; then
    cat /tmp/host_pubkey >> /root/.ssh/authorized_keys
fi
if [ -f /tmp/authorized_keys ]; then
    cat /tmp/authorized_keys >> /root/.ssh/authorized_keys
fi

# Deduplicate keys
if [ -f /root/.ssh/authorized_keys ]; then
    sort -u /root/.ssh/authorized_keys -o /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
fi

# ---------------------------------------------------------------------------
# Hermes: bootstrap config files into HERMES_HOME
# ---------------------------------------------------------------------------
mkdir -p "$HERMES_HOME"/{cron,sessions,logs,hooks,memories,skills}

# ---------------------------------------------------------------------------
# Lark CLI: migrate Linux keychain-backed encrypted files to persistent dir
# ---------------------------------------------------------------------------
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

# Sync bundled skills (manifest-based, preserves user edits)
if [ -d "$INSTALL_DIR/skills" ] && [ -f "$INSTALL_DIR/tools/skills_sync.py" ]; then
    python3 "$INSTALL_DIR/tools/skills_sync.py" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Start SSH daemon + Hermes gateway in one container
# ---------------------------------------------------------------------------
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
echo "  Dev Agent Container Ready"
echo "=========================================="
echo "  SSH:      ssh -p 2222 root@localhost"
echo "  Hermes:   hermes"
echo "  Gateway:  running in background"
echo "  OpenCode: opencode"
echo "  Claude:   claude"
echo "=========================================="

# If either critical process exits, stop the container so Docker can restart it.
wait -n "$SSHD_PID" "$GATEWAY_PID"
EXIT_CODE=$?
kill "$GATEWAY_PID" 2>/dev/null || true
kill "$SSHD_PID" 2>/dev/null || true
wait "$GATEWAY_PID" 2>/dev/null || true
wait "$SSHD_PID" 2>/dev/null || true
exit "$EXIT_CODE"

# ---------------------------------------------------------------------------
# Execute CMD
# ---------------------------------------------------------------------------
# CMD is intentionally unused: this container is managed by sshd + gateway.
exit 0
