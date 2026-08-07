#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

cd "$ROOT_DIR"

echo "Stopping core stack..."
docker compose --env-file "$ENV_FILE" down --remove-orphans

echo "Force removing any leftover core containers..."
docker rm -f \
  measurement_plane_gui \
  experiment-orchestrator \
  coincidences_analyzer_agent_container \
  polarization_analyzer_container \
  twtt_capability_container \
  apc_service_container \
  nats 2>/dev/null || true
