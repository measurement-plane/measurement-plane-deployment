#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/env/detection-agent.env}"

CONTAINER_NAME="${CONTAINER_NAME:-detection_agent_container}"
IMAGE_NAME="${IMAGE_NAME:-ghcr.io/measurement-plane/detection-agent:latest}"
BROKER_URL="${BROKER_URL:-nats://localhost:4222}"
ENDPOINT="${ENDPOINT:-/timetagger/alice}"
TT_TYPE="${TT_TYPE:-swabian}"
TT_SERIAL="${TT_SERIAL:-2138000XI2}"
PPS_CHANNEL="${PPS_CHANNEL:-8}"
TT_CHANNELS="${TT_CHANNELS:-1|2|3|4|5|6|7|8}"
MAX_EVENTS="${MAX_EVENTS:-10000000}"
BUFFER_SECONDS="${BUFFER_SECONDS:-10}"
VIRTUAL_SECONDS="${VIRTUAL_SECONDS:-20}"
VIRTUAL_EVENTS_PER_SECOND="${VIRTUAL_EVENTS_PER_SECOND:-500000}"
VIRTUAL_SEED="${VIRTUAL_SEED:-12345}"
VIRTUAL_DATASET_FILE="${VIRTUAL_DATASET_FILE:-}"
TT_TRIGGER_LEVELS="${TT_TRIGGER_LEVELS:-1=0.5,2=0.5,3=0.5,4=0.5,5=0.5,6=0.5,7=0.5,8=0.5}"
TT_EVENT_DIVIDERS="${TT_EVENT_DIVIDERS:-1=10,2=10,3=10,4=10}"
TT_DEAD_TIMES="${TT_DEAD_TIMES:-}"
TT_DELAYS="${TT_DELAYS:-}"
DOCKER_EXTRA_ARGS="${DOCKER_EXTRA_ARGS:-}"
TIMETAGGER_USB_AUTO_ATTACH="${TIMETAGGER_USB_AUTO_ATTACH:-true}"
TIMETAGGER_USB_HARDWARE_ID="${TIMETAGGER_USB_HARDWARE_ID:-151f:0023}"
FOLLOW_LOGS="${FOLLOW_LOGS:-true}"
LOG_TAIL="${LOG_TAIL:-100}"

load_env_file() {
  local env_path="$1"
  local line key value

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
  done < "$env_path"
}

if [[ -f "$ENV_FILE" ]]; then
  echo "Loading config from $ENV_FILE"
  load_env_file "$ENV_FILE"
fi

is_true() {
  case "${1,,}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

is_windows_shell() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_windows_timetagger_attached() {
  local device_line

  if ! is_windows_shell || [[ "${TT_TYPE,,}" != "swabian" ]] || ! is_true "$TIMETAGGER_USB_AUTO_ATTACH"; then
    return
  fi

  if ! command -v usbipd.exe >/dev/null 2>&1; then
    echo "Error: usbipd-win is required to expose the Time Tagger to Docker Desktop."
    exit 1
  fi

  device_line="$(usbipd.exe list 2>/dev/null | tr -d '\r' | grep -i "$TIMETAGGER_USB_HARDWARE_ID" || true)"
  if [[ -z "$device_line" ]]; then
    echo "Error: no Time Tagger USB device with hardware ID $TIMETAGGER_USB_HARDWARE_ID was found."
    exit 1
  fi

  if [[ "$device_line" == *"Attached"* ]]; then
    echo "Time Tagger USB device is already attached to Docker Desktop."
    return
  fi

  if [[ "$device_line" == *"Not shared"* ]]; then
    echo "Error: the Time Tagger USB device has not been shared with usbipd-win."
    echo "Run this once from an Administrator PowerShell, then retry:"
    echo "  usbipd bind --hardware-id $TIMETAGGER_USB_HARDWARE_ID"
    exit 1
  fi

  echo "Attaching Time Tagger USB device $TIMETAGGER_USB_HARDWARE_ID to Docker Desktop..."
  if ! usbipd.exe attach --wsl --hardware-id "$TIMETAGGER_USB_HARDWARE_ID"; then
    echo "Error: failed to attach the Time Tagger to Docker Desktop."
    echo "Confirm Docker Desktop is running, then retry."
    exit 1
  fi
}

echo "Stopping and removing existing detection-agent container (if any)..."
docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo "Pulling detection-agent image..."
docker pull "$IMAGE_NAME"

ensure_windows_timetagger_attached

echo "Starting detection-agent container..."
DOCKER_CMD="MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' docker run -d --name \"$CONTAINER_NAME\""
DOCKER_CMD+=" --privileged"
if [[ "$BROKER_URL" == *"host.docker.internal"* ]] && [[ "$DOCKER_EXTRA_ARGS" != *"--add-host=host.docker.internal:host-gateway"* ]]; then
  DOCKER_CMD+=" --add-host=host.docker.internal:host-gateway"
fi
DOCKER_CMD+=" -e BROKER_URL=\"$BROKER_URL\""
DOCKER_CMD+=" -e ENDPOINT=\"$ENDPOINT\""
DOCKER_CMD+=" -e TT_TYPE=\"$TT_TYPE\""
DOCKER_CMD+=" -e TT_SERIAL=\"$TT_SERIAL\""
DOCKER_CMD+=" -e PPS_CHANNEL=\"$PPS_CHANNEL\""
DOCKER_CMD+=" -e TT_CHANNELS=\"$TT_CHANNELS\""
DOCKER_CMD+=" -e MAX_EVENTS=\"$MAX_EVENTS\""
DOCKER_CMD+=" -e BUFFER_SECONDS=\"$BUFFER_SECONDS\""
DOCKER_CMD+=" -e VIRTUAL_SECONDS=\"$VIRTUAL_SECONDS\""
DOCKER_CMD+=" -e VIRTUAL_EVENTS_PER_SECOND=\"$VIRTUAL_EVENTS_PER_SECOND\""
DOCKER_CMD+=" -e VIRTUAL_SEED=\"$VIRTUAL_SEED\""
DOCKER_CMD+=" -e VIRTUAL_DATASET_FILE=\"$VIRTUAL_DATASET_FILE\""
DOCKER_CMD+=" -e TT_TRIGGER_LEVELS=\"$TT_TRIGGER_LEVELS\""
DOCKER_CMD+=" -e TT_EVENT_DIVIDERS=\"$TT_EVENT_DIVIDERS\""
DOCKER_CMD+=" -e TT_DEAD_TIMES=\"$TT_DEAD_TIMES\""
DOCKER_CMD+=" -e TT_DELAYS=\"$TT_DELAYS\""

if [[ -n "$DOCKER_EXTRA_ARGS" ]]; then
  DOCKER_CMD+=" $DOCKER_EXTRA_ARGS"
fi

DOCKER_CMD+=" \"$IMAGE_NAME\""

if ! eval "$DOCKER_CMD"; then
  echo "Error: Failed to start detection-agent container."
  exit 1
fi

echo "Detection agent deployed:"
echo "  container: $CONTAINER_NAME"
echo "  endpoint : $ENDPOINT"
echo "  broker   : $BROKER_URL"

if is_true "$FOLLOW_LOGS"; then
  echo "Following logs; press Ctrl+C to stop viewing them. The container will keep running."
  docker logs --tail "$LOG_TAIL" --follow "$CONTAINER_NAME"
fi
