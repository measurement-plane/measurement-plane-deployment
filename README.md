# Measurement Plane Deployment

One-command deployment of:

- NATS broker
- Experiment Orchestrator
- Measurement Plane GUI
- Coincidences Analyzer Agent
- Polarization Analyzer Agent

## Requirements

- Docker ≥ 24
- Docker Compose plugin

## Start the system

```bash
cd measurement-plane-deployment
chmod +x scripts/*.sh
./scripts/start.sh
