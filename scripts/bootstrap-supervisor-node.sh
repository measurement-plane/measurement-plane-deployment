#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 3 ] || [ "$#" -gt 5 ]; then
    echo "Usage: $0 NODE_NAME CERTIFICATE_ADDRESS SSH_TARGET [SUPERVISOR_PORT] [SSH_PORT]" >&2
    echo "Example: $0 alice 192.168.10.25 admin@192.168.10.25 9443 22" >&2
    exit 2
fi

NODE_NAME="$1"
CERT_ADDRESS="$2"
SSH_TARGET="$3"
SUPERVISOR_PORT="${4:-9443}"
SSH_PORT="${5:-22}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE="$($SCRIPT_DIR/create-supervisor-node-bundle.sh "$NODE_NAME" "$CERT_ADDRESS" "$SUPERVISOR_PORT")"
REMOTE_DIR="/tmp/measurement-plane-supervisor-$NODE_NAME"

ssh -p "$SSH_PORT" "$SSH_TARGET" "mkdir -p '$REMOTE_DIR'"
scp -P "$SSH_PORT" "$BUNDLE" "$SSH_TARGET:$REMOTE_DIR/bundle.tar.gz"
ssh -t -p "$SSH_PORT" "$SSH_TARGET" "cd '$REMOTE_DIR' && tar -xzf bundle.tar.gz && sudo ./install.sh; cd / && sudo rm -rf '$REMOTE_DIR'"

echo
echo "Bootstrap finished. Add $CERT_ADDRESS:$SUPERVISOR_PORT in GUI → Infrastructure → Remote nodes."

