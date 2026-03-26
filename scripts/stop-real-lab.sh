#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/remote-lib.sh"

LAB_ENV_FILE="${LAB_ENV_FILE:-$ROOT_DIR/env/real-lab.env}"

if [[ -f "$LAB_ENV_FILE" ]]; then
  echo "Loading lab deployment config from $LAB_ENV_FILE"
  load_env_file "$LAB_ENV_FILE"
else
  echo "Lab deployment config not found: $LAB_ENV_FILE" >&2
  exit 1
fi

require_var CORE_ENV_FILE
require_var ALICE_SSH_TARGET
require_var ALICE_DETECTOR_ENV
require_var ALICE_POLARIZER_ENV
require_var BOB_SSH_TARGET
require_var BOB_DETECTOR_ENV
require_var BOB_POLARIZER_ENV

REMOTE_DEPLOY_ROOT="${REMOTE_DEPLOY_ROOT:-~/measurement-plane-deployment}"
ALICE_REMOTE_DEPLOY_ROOT="${ALICE_REMOTE_DEPLOY_ROOT:-$REMOTE_DEPLOY_ROOT}"
BOB_REMOTE_DEPLOY_ROOT="${BOB_REMOTE_DEPLOY_ROOT:-$REMOTE_DEPLOY_ROOT}"

echo "Stopping Alice polarization controller on $ALICE_SSH_TARGET..."
stop_remote_agent "$ALICE_SSH_TARGET" "$ALICE_REMOTE_DEPLOY_ROOT" "$ALICE_POLARIZER_ENV" "stop-polarization-controller.sh"

echo "Stopping Alice detection agent on $ALICE_SSH_TARGET..."
stop_remote_agent "$ALICE_SSH_TARGET" "$ALICE_REMOTE_DEPLOY_ROOT" "$ALICE_DETECTOR_ENV" "stop-detection-agent.sh"

echo "Stopping Bob polarization controller on $BOB_SSH_TARGET..."
stop_remote_agent "$BOB_SSH_TARGET" "$BOB_REMOTE_DEPLOY_ROOT" "$BOB_POLARIZER_ENV" "stop-polarization-controller.sh"

echo "Stopping Bob detection agent on $BOB_SSH_TARGET..."
stop_remote_agent "$BOB_SSH_TARGET" "$BOB_REMOTE_DEPLOY_ROOT" "$BOB_DETECTOR_ENV" "stop-detection-agent.sh"

echo "Stopping core stack on central node..."
stop_core_detached "$CORE_ENV_FILE"

echo
echo "Real-lab deployment stopped."
