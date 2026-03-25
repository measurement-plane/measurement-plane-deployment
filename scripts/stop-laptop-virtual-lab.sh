#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ALICE_DETECTOR_ENV="${ALICE_DETECTOR_ENV:-$ROOT_DIR/env/detection-agent-virtual-alice.env}"
BOB_DETECTOR_ENV="${BOB_DETECTOR_ENV:-$ROOT_DIR/env/detection-agent-virtual-bob.env}"
ALICE_POLARIZER_ENV="${ALICE_POLARIZER_ENV:-$ROOT_DIR/env/polarization-controller-virtual-alice.env}"
BOB_POLARIZER_ENV="${BOB_POLARIZER_ENV:-$ROOT_DIR/env/polarization-controller-virtual-bob.env}"

ENV_FILE="$ALICE_DETECTOR_ENV" "$SCRIPT_DIR/stop-detection-agent.sh"
ENV_FILE="$BOB_DETECTOR_ENV" "$SCRIPT_DIR/stop-detection-agent.sh"
ENV_FILE="$ALICE_POLARIZER_ENV" "$SCRIPT_DIR/stop-polarization-controller.sh"
ENV_FILE="$BOB_POLARIZER_ENV" "$SCRIPT_DIR/stop-polarization-controller.sh"
"$SCRIPT_DIR/stop-core.sh"
