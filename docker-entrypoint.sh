#!/usr/bin/env bash
set -uo pipefail

# Best-effort: map host.docker.internal to the default gateway.
# Guarded so it can never hang or block startup on platforms where
# /sbin/ip route or /etc/hosts behave differently (e.g. restricted
# network namespaces, read-only /etc/hosts, no default route).
if command -v /sbin/ip >/dev/null 2>&1 && [ -w /etc/hosts ]; then
    gw="$(timeout 3 /sbin/ip route 2>/dev/null | awk '/default/ { print $3; exit }')"
    if [ -n "${gw:-}" ]; then
        if ! grep -q "host.docker.internal" /etc/hosts 2>/dev/null; then
            echo "${gw}  host.docker.internal" >> /etc/hosts || true
        fi
    fi
fi

if [ -f "${BTCPAY_SSHAUTHORIZEDKEYS:-}" ] && [ -n "${BTCPAY_SSHKEYFILE:-}" ]; then
    if ! [ -f "$BTCPAY_SSHKEYFILE" ] || ! [ -f "$BTCPAY_SSHKEYFILE.pub" ]; then
        rm -f "$BTCPAY_SSHKEYFILE" "$BTCPAY_SSHKEYFILE.pub"
        echo "Creating BTCPay Server SSH key File..."
        ssh-keygen -t ed25519 -f "$BTCPAY_SSHKEYFILE" -q -P "" -m PEM -C btcpayserver > /dev/null
        # Let's make sure the SSHAUTHORIZEDKEYS doesn't have our key yet
        # Because the file is mounted, set -i does not work
        sed '/btcpayserver$/d' "$BTCPAY_SSHAUTHORIZEDKEYS" > "$BTCPAY_SSHAUTHORIZEDKEYS.new"
        cat "$BTCPAY_SSHAUTHORIZEDKEYS.new" > "$BTCPAY_SSHAUTHORIZEDKEYS"
        rm -rf "$BTCPAY_SSHAUTHORIZEDKEYS.new"
    fi
    if [ -f "$BTCPAY_SSHKEYFILE.pub" ] && \
       ! grep -q "btcpayserver$" "$BTCPAY_SSHAUTHORIZEDKEYS"; then
        echo "Adding BTCPay Server SSH key to authorized keys"
        cat "$BTCPAY_SSHKEYFILE.pub" >> "$BTCPAY_SSHAUTHORIZEDKEYS"
    fi
fi

echo "Starting BTCPayServer..."
exec dotnet BTCPayServer.dll
