#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/env/polarization-controller.env}"

CONTAINER_NAME="${CONTAINER_NAME:-polarization_controller}"
IMAGE_NAME="${IMAGE_NAME:-ghcr.io/measurement-plane/polarization-controller:latest}"
BROKER_URL="${BROKER_URL:-nats://localhost:4222}"
ENDPOINT="${ENDPOINT:-/polarization_controller}"
HWP_ADDR="${HWP_ADDR:-/dev/ttyUSB0}"
QWP_ADDR="${QWP_ADDR:-/dev/ttyUSB1}"
DRIVER_TYPE="${DRIVER_TYPE:-kenesis}"
DOCKER_EXTRA_ARGS="${DOCKER_EXTRA_ARGS:-}"

if [[ -f "$ENV_FILE" ]]; then
  echo "Loading config from $ENV_FILE"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"

    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    if [[ "$line" != *=* ]]; then
      continue
    fi

    key="${line%%=*}"
    value="${line#*=}"

    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"

    if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    fi

    printf -v "$key" '%s' "$value"
    export "$key"
  done < "$ENV_FILE"
fi

echo "Stopping and removing existing polarization-controller container (if any)..."
docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo "Pulling polarization-controller image..."
docker pull "$IMAGE_NAME"

echo "Starting polarization-controller container..."
DOCKER_CMD="MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' docker run -d --name \"$CONTAINER_NAME\""
if [[ "$DRIVER_TYPE" != "virtual" && "$DRIVER_TYPE" != "dummy" ]]; then
  DOCKER_CMD+=" --device=\"$HWP_ADDR\""
  DOCKER_CMD+=" --device=\"$QWP_ADDR\""
  DOCKER_CMD+=" --group-add dialout"
fi
DOCKER_CMD+=" -e BROKER_URL=\"$BROKER_URL\""
DOCKER_CMD+=" -e ENDPOINT=\"$ENDPOINT\""
DOCKER_CMD+=" -e HWP_ADDR=\"$HWP_ADDR\""
DOCKER_CMD+=" -e QWP_ADDR=\"$QWP_ADDR\""
DOCKER_CMD+=" -e DRIVER_TYPE=\"$DRIVER_TYPE\""

if [[ -n "$DOCKER_EXTRA_ARGS" ]]; then
  DOCKER_CMD+=" $DOCKER_EXTRA_ARGS"
fi

DOCKER_CMD+=" \"$IMAGE_NAME\""

if ! eval "$DOCKER_CMD"; then
  echo "Error: Failed to start polarization-controller container."
  exit 1
fi

echo "Polarization controller deployed:"
echo "  container: $CONTAINER_NAME"
echo "  endpoint : $ENDPOINT"
echo "  broker   : $BROKER_URL"
echo "  driver   : $DRIVER_TYPE"
