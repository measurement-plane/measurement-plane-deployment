#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

cd "$ROOT_DIR"

echo "Hard cleanup of any previous Measurement Plane core containers..."

docker rm -f \
  measurement_plane_gui \
  experiment-orchestrator \
  coincidences_analyzer_agent_container \
  polarization_analyzer_container \
  apc_service_container \
  nats 2>/dev/null || true

echo "Pruning old networks..."
docker network prune -f

echo "Pulling core images..."
docker compose --env-file "$ENV_FILE" pull

echo "Starting core stack in attached mode..."
echo "Press Ctrl+C to stop the stack."
docker compose --env-file "$ENV_FILE" up --force-recreate
