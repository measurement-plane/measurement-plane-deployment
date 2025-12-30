#!/bin/bash
set -e

echo "Starting Measurement Plane stack..."
docker compose pull
docker compose up -d

echo ""
echo "System ready:"
echo "GUI            → http://localhost:8050"
echo "Orchestrator   → http://localhost:8080"
