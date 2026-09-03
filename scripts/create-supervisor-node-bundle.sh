#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 NODE_NAME CERTIFICATE_ADDRESS [SUPERVISOR_PORT] [OUTPUT_FILE]" >&2
    exit 2
fi

NODE_NAME="$1"
CERT_ADDRESS="$2"
SUPERVISOR_PORT="${3:-9443}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$(cd "$ROOT_DIR/.." && pwd)"
PKI_DIR="${SUPERVISOR_PKI_DIR:-$ROOT_DIR/secrets/supervisor-pki}"
OUTPUT_FILE="${4:-$ROOT_DIR/dist/resource-supervisor-${NODE_NAME}.tar.gz}"

if [[ ! "$NODE_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}$ ]]; then
    echo "NODE_NAME contains unsupported characters" >&2
    exit 2
fi
if [[ ! "$SUPERVISOR_PORT" =~ ^[0-9]+$ ]] || [ "$SUPERVISOR_PORT" -lt 1 ] || [ "$SUPERVISOR_PORT" -gt 65535 ]; then
    echo "SUPERVISOR_PORT must be between 1 and 65535" >&2
    exit 2
fi

"$SCRIPT_DIR/init-supervisor-pki.sh" >&2
NODE_PKI="$PKI_DIR/nodes/$NODE_NAME"
mkdir -p "$NODE_PKI" "$(dirname "$OUTPUT_FILE")"
umask 077

SAN_TYPE="DNS"
if python3 -c 'import ipaddress,sys; ipaddress.ip_address(sys.argv[1])' "$CERT_ADDRESS" 2>/dev/null; then
    SAN_TYPE="IP"
elif [[ ! "$CERT_ADDRESS" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{0,252}$ ]]; then
    echo "CERTIFICATE_ADDRESS must be a valid IP address or DNS name" >&2
    exit 2
fi

openssl genrsa -out "$NODE_PKI/server.key" 3072
openssl req -new -sha256 \
    -key "$NODE_PKI/server.key" \
    -out "$NODE_PKI/server.csr" \
    -subj "/CN=$NODE_NAME/O=Measurement Plane"
printf 'basicConstraints=critical,CA:FALSE\nsubjectAltName=%s:%s\nextendedKeyUsage=serverAuth\nkeyUsage=critical,digitalSignature,keyEncipherment\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid,issuer\n' "$SAN_TYPE" "$CERT_ADDRESS" > "$NODE_PKI/server.ext"
openssl x509 -req -sha256 -days 825 \
    -in "$NODE_PKI/server.csr" \
    -CA "$PKI_DIR/ca.crt" -CAkey "$PKI_DIR/ca.key" -CAcreateserial \
    -extfile "$NODE_PKI/server.ext" \
    -out "$NODE_PKI/server.crt"
rm -f "$NODE_PKI/server.csr" "$NODE_PKI/server.ext"

BUNDLE_DIR="$(mktemp -d)"
trap 'rm -rf "$BUNDLE_DIR"' EXIT
cp -R "$WORKSPACE_DIR/resource-supervisor/resource_supervisor" "$BUNDLE_DIR/"
find "$BUNDLE_DIR/resource_supervisor" -type d -name __pycache__ -prune -exec rm -rf {} +
cp "$WORKSPACE_DIR/resource-supervisor/install.sh" "$BUNDLE_DIR/"
mkdir -p "$BUNDLE_DIR/pki"
cp "$PKI_DIR/ca.crt" "$BUNDLE_DIR/pki/ca.crt"
cp "$NODE_PKI/server.crt" "$BUNDLE_DIR/pki/server.crt"
cp "$NODE_PKI/server.key" "$BUNDLE_DIR/pki/server.key"
cat > "$BUNDLE_DIR/config.json" <<JSON
{
  "nodeName": "$NODE_NAME",
  "listen": "0.0.0.0",
  "port": $SUPERVISOR_PORT,
  "caCertificate": "/etc/measurement-plane/resource-supervisor/ca.crt",
  "serverCertificate": "/etc/measurement-plane/resource-supervisor/server.crt",
  "serverKey": "/etc/measurement-plane/resource-supervisor/server.key",
  "pullPolicy": "if_not_present",
  "allowedImages": {
    "detection_agent": "ghcr.io/measurement-plane/detection-agent:latest",
    "polarization_controller_agent": "ghcr.io/measurement-plane/polarization-controller:latest"
  }
}
JSON
chmod +x "$BUNDLE_DIR/install.sh"
tar -C "$BUNDLE_DIR" -czf "$OUTPUT_FILE" .
chmod 600 "$OUTPUT_FILE"
echo "$OUTPUT_FILE"
