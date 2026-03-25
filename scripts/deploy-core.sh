#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo "Hard cleanup of any previous Measurement Plane core containers..."

docker rm -f \
  measurement_plane_gui \
  experiment-orchestrator \
  coincidences_analyzer_agent_container \
  polarization_analyzer_container \
  nats 2>/dev/null || true

echo "Pruning old networks..."
docker network prune -f

echo "Pulling core images..."
docker compose pull

echo "Starting core stack in attached mode..."
echo "Press Ctrl+C to stop the stack."
docker compose up --force-recreate
