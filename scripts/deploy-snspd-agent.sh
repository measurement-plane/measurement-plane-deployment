#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/env/snspd-agent.env}"

CONTAINER_NAME="${CONTAINER_NAME:-snspd_agent}"
IMAGE_NAME="${IMAGE_NAME:-ghcr.io/measurement-plane/snspd-agent:latest}"
BROKER_URL="${BROKER_URL:-nats://localhost:4222}"
ENDPOINT="${ENDPOINT:-/snspd/fury}"
SNSPD_DRIVER_TYPE="${SNSPD_DRIVER_TYPE:-opus}"
SNSPD_TTY="${SNSPD_TTY:-/dev/ttyACM0}"
SNSPD_LOG_DIR="${SNSPD_LOG_DIR:-}"
DOCKER_EXTRA_ARGS="${DOCKER_EXTRA_ARGS:-}"

# Agent settings passed through to the container when set.
PASSTHROUGH_VARS=(
  SNSPD_NAME SNSPD_SERIAL
  SNSPD_T2K_CAL SNSPD_T40K_CAL SNSPD_T2K_THERM_CH SNSPD_T40K_THERM_CH
  SNSPD_MAX_BIAS_UA SNSPD_DEFAULT_MAX_BIAS_UA SNSPD_BIAS_RAMP_STEP_UA SNSPD_BIAS_RAMP_DELAY_S
  SNSPD_MAX_OPERATING_T_K SNSPD_GATE_S SNSPD_POLL_INTERVAL_S
  VIRTUAL_CHANNELS VIRTUAL_SEED
)

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

echo "Stopping and removing existing snspd-agent container (if any)..."
docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo "Pulling snspd-agent image..."
docker pull "$IMAGE_NAME"

echo "Starting snspd-agent container..."
DOCKER_CMD="MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' docker run -d --name \"$CONTAINER_NAME\""
if [[ "$BROKER_URL" == *"host.docker.internal"* ]] && [[ "$DOCKER_EXTRA_ARGS" != *"--add-host=host.docker.internal:host-gateway"* ]]; then
  DOCKER_CMD+=" --add-host=host.docker.internal:host-gateway"
fi
if [[ "$SNSPD_DRIVER_TYPE" != "virtual" ]]; then
  # Map the resolved device (e.g. a /dev/serial/by-id link) to the same path in the
  # container, so the QOELEC driver's VID/PID discovery reads the matching sysfs entry.
  SNSPD_DEV="$(readlink -f "$SNSPD_TTY")"
  if [[ ! -e "$SNSPD_DEV" ]]; then
    echo "Error: SNSPD device $SNSPD_TTY not found." >&2
    exit 1
  fi
  DOCKER_CMD+=" --device=\"$SNSPD_DEV:$SNSPD_DEV\""
  DOCKER_CMD+=" --group-add dialout"
fi
if [[ -n "$SNSPD_LOG_DIR" ]]; then
  mkdir -p "$SNSPD_LOG_DIR"
  DOCKER_CMD+=" -v \"$SNSPD_LOG_DIR:/logs\""
  DOCKER_CMD+=" -e SNSPD_LOG_DIR=/logs"
fi
DOCKER_CMD+=" -e BROKER_URL=\"$BROKER_URL\""
DOCKER_CMD+=" -e ENDPOINT=\"$ENDPOINT\""
DOCKER_CMD+=" -e SNSPD_DRIVER_TYPE=\"$SNSPD_DRIVER_TYPE\""
for var in "${PASSTHROUGH_VARS[@]}"; do
  if [[ -n "${!var:-}" ]]; then
    DOCKER_CMD+=" -e $var=\"${!var}\""
  fi
done

if [[ -n "$DOCKER_EXTRA_ARGS" ]]; then
  DOCKER_CMD+=" $DOCKER_EXTRA_ARGS"
fi

DOCKER_CMD+=" \"$IMAGE_NAME\""

if ! eval "$DOCKER_CMD"; then
  echo "Error: Failed to start snspd-agent container."
  exit 1
fi

echo "SNSPD agent deployed:"
echo "  container: $CONTAINER_NAME"
echo "  endpoint : $ENDPOINT"
echo "  broker   : $BROKER_URL"
echo "  driver   : $SNSPD_DRIVER_TYPE"
