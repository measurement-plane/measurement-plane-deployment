#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PKI_DIR="${SUPERVISOR_PKI_DIR:-$ROOT_DIR/secrets/supervisor-pki}"
umask 077
mkdir -p "$PKI_DIR/nodes"

CA_NEEDS_ROTATION=false
if [ -f "$PKI_DIR/ca.crt" ] && ! openssl x509 -in "$PKI_DIR/ca.crt" -noout -text | grep -q 'Certificate Sign'; then
    CA_NEEDS_ROTATION=true
fi
if [ ! -f "$PKI_DIR/ca.key" ] || [ ! -f "$PKI_DIR/ca.crt" ] || [ "$CA_NEEDS_ROTATION" = true ]; then
    echo "Creating the private Measurement Plane supervisor CA..."
    openssl genrsa -out "$PKI_DIR/ca.key" 4096
    openssl req -x509 -new -sha256 -days 3650 \
        -key "$PKI_DIR/ca.key" \
        -out "$PKI_DIR/ca.crt" \
        -subj "/CN=Measurement Plane Resource Supervisor CA/O=Measurement Plane" \
        -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
        -addext "keyUsage=critical,keyCertSign,cRLSign" \
        -addext "subjectKeyIdentifier=hash"
    rm -f "$PKI_DIR/ca.srl"
fi

CLIENT_NEEDS_ROTATION=false
if [ -f "$PKI_DIR/topology-client.crt" ] && ! openssl x509 -in "$PKI_DIR/topology-client.crt" -noout -text | grep -q 'CA:FALSE'; then
    CLIENT_NEEDS_ROTATION=true
fi
if [ ! -f "$PKI_DIR/topology-client.key" ] || [ ! -f "$PKI_DIR/topology-client.crt" ] || [ "$CLIENT_NEEDS_ROTATION" = true ] || [ "$CA_NEEDS_ROTATION" = true ]; then
    echo "Creating the topology-service mTLS client identity..."
    openssl genrsa -out "$PKI_DIR/topology-client.key" 3072
    openssl req -new -sha256 \
        -key "$PKI_DIR/topology-client.key" \
        -out "$PKI_DIR/topology-client.csr" \
        -subj "/CN=topology-service/O=Measurement Plane"
    printf 'basicConstraints=critical,CA:FALSE\nextendedKeyUsage=clientAuth\nkeyUsage=critical,digitalSignature\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid,issuer\n' > "$PKI_DIR/topology-client.ext"
    openssl x509 -req -sha256 -days 825 \
        -in "$PKI_DIR/topology-client.csr" \
        -CA "$PKI_DIR/ca.crt" -CAkey "$PKI_DIR/ca.key" -CAcreateserial \
        -extfile "$PKI_DIR/topology-client.ext" \
        -out "$PKI_DIR/topology-client.crt"
    rm -f "$PKI_DIR/topology-client.csr" "$PKI_DIR/topology-client.ext"
fi

chmod 600 "$PKI_DIR"/*.key
chmod 644 "$PKI_DIR"/*.crt
echo "Supervisor PKI is ready in $PKI_DIR"
