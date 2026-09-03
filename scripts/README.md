# Deployment script map

## Recommended GUI-managed workflow

- `deploy-core.sh` and `stop-core.sh`: central Measurement Plane platform.
- `bootstrap-supervisor-node.sh`: one-time enrollment of a Linux resource server.
- `create-supervisor-node-bundle.sh`: enrollment when SSH bootstrap is not used.
- `init-supervisor-pki.sh`: private control-plane CA and topology client identity.

After enrollment, do not run an agent deploy script on the resource server.
Register the server and deploy, start, stop, restart, remove, and inspect agents
from **GUI → Infrastructure**. Those operations use mTLS, not SSH.

## Development-only acceptance lab

- `run-local-virtual-gui.sh`: builds the current source tree and starts the local
  core stack used with `../vm-lab`. Although the hardware drivers are virtual,
  capability discovery and measurement traffic are real NATS traffic.
- `deploy-laptop-virtual-lab.sh` and `stop-laptop-virtual-lab.sh`: older
  single-laptop fixture that starts virtual agents directly. It is retained only
  for compatibility and is not the GUI-managed workflow.

## Legacy direct deployment

The following predate the mTLS supervisor and remain only for existing Windows
hardware hosts or migration:

- `deploy-detection-agent.sh`, `stop-detection-agent.sh`
- `deploy-polarization-controller.sh`, `stop-polarization-controller.sh`
- `deploy-real-lab.sh`, `stop-real-lab.sh`, `remote-lib.sh`
- `start.sh`, `stop.sh` compatibility aliases

Do not use the legacy `real-lab` launcher for a new installation. It copies the
deployment repository over SSH and manages agents directly, whereas the current
architecture installs one constrained supervisor and performs ongoing operations
through its authenticated API.
