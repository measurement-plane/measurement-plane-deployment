#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
CORE_CHANNEL="${CORE_CHANNEL:-latest}"
COMPOSE_ARGS=()

if [[ "$CORE_CHANNEL" == "dev" ]]; then
  COMPOSE_ARGS=(-f docker-compose.yml -f docker-compose.dev.yml)
elif [[ "$CORE_CHANNEL" != "latest" ]]; then
  echo "Unsupported CORE_CHANNEL '$CORE_CHANNEL' (expected 'latest' or 'dev')." >&2
  exit 2
fi

cd "$ROOT_DIR"

"$SCRIPT_DIR/init-supervisor-pki.sh"

echo "Hard cleanup of any previous Measurement Plane core containers..."

docker rm -f \
  measurement_plane_gui \
  measurement_plane_api \
  topology_service \
  experiment-orchestrator \
  coincidences_analyzer_agent_container \
  polarization_analyzer_container \
  twtt_capability_container \
  entanglement_distribution_container \
  apc_service_container \
  nats 2>/dev/null || true

echo "Pruning old networks..."
docker network prune -f

echo "Pulling core images..."
docker compose --env-file "$ENV_FILE" "${COMPOSE_ARGS[@]}" pull

echo "Starting core stack in attached mode..."
echo "Press Ctrl+C to stop the stack."
docker compose --env-file "$ENV_FILE" "${COMPOSE_ARGS[@]}" up --force-recreate
