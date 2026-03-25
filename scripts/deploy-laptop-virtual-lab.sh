#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ALICE_DETECTOR_ENV="${ALICE_DETECTOR_ENV:-$ROOT_DIR/env/detection-agent-virtual-alice.env}"
BOB_DETECTOR_ENV="${BOB_DETECTOR_ENV:-$ROOT_DIR/env/detection-agent-virtual-bob.env}"
ALICE_POLARIZER_ENV="${ALICE_POLARIZER_ENV:-$ROOT_DIR/env/polarization-controller-virtual-alice.env}"
BOB_POLARIZER_ENV="${BOB_POLARIZER_ENV:-$ROOT_DIR/env/polarization-controller-virtual-bob.env}"
CORE_ENV_FILE="${CORE_ENV_FILE:-$ROOT_DIR/env/core-virtual-lab.env}"

cleanup() {
  echo
  echo "Stopping laptop virtual lab setup..."
  ENV_FILE="$ALICE_DETECTOR_ENV" "$SCRIPT_DIR/stop-detection-agent.sh" || true
  ENV_FILE="$BOB_DETECTOR_ENV" "$SCRIPT_DIR/stop-detection-agent.sh" || true
  ENV_FILE="$ALICE_POLARIZER_ENV" "$SCRIPT_DIR/stop-polarization-controller.sh" || true
  ENV_FILE="$BOB_POLARIZER_ENV" "$SCRIPT_DIR/stop-polarization-controller.sh" || true
  ENV_FILE="$CORE_ENV_FILE" "$SCRIPT_DIR/stop-core.sh" || true
}

trap cleanup INT TERM

echo "Starting virtual detectors..."
ENV_FILE="$ALICE_DETECTOR_ENV" "$SCRIPT_DIR/deploy-detection-agent.sh"
ENV_FILE="$BOB_DETECTOR_ENV" "$SCRIPT_DIR/deploy-detection-agent.sh"

echo "Starting virtual polarization controllers..."
ENV_FILE="$ALICE_POLARIZER_ENV" "$SCRIPT_DIR/deploy-polarization-controller.sh"
ENV_FILE="$BOB_POLARIZER_ENV" "$SCRIPT_DIR/deploy-polarization-controller.sh"

echo "Starting core stack..."
echo "Press Ctrl+C to stop the full virtual lab."
ENV_FILE="$CORE_ENV_FILE" "$SCRIPT_DIR/deploy-core.sh"

cleanup
