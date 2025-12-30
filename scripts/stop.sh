#!/bin/bash
set -e

echo "Stopping stack..."
docker compose down --remove-orphans

echo "Force removing any leftovers..."
docker rm -f \
  measurement_plane_gui \
  experiment-orchestrator \
  coincidences_analyzer_agent_container \
  polarization_analyzer_container \
  nats 2>/dev/null || true
