#!/bin/bash
set -e

echo "Hard cleanup of any previous Measurement Plane containers..."

docker rm -f \
  measurement_plane_gui \
  experiment-orchestrator \
  coincidences_analyzer_agent_container \
  polarization_analyzer_container \
  nats 2>/dev/null || true

echo "Pruning old networks..."
docker network prune -f

echo "Pulling images..."
docker compose pull

echo "Starting stack..."
docker compose up -d --force-recreate

echo ""
echo "System ready:"
echo "GUI          → http://localhost:8050"
echo "Orchestrator → http://localhost:8080"
