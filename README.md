# Measurement Plane Deployment

This repository is the single deployment entry point for the Measurement Plane platform.

It supports:

- core deployment on a central node
- standalone resource-agent deployment for `detection-agent`
- standalone resource-agent deployment for `polarization-controller`
- one-command local virtual-lab deployment

## Core Stack

The core deployment now includes:

- NATS broker
- experiment orchestrator
- Measurement Plane GUI
- coincidences analyzer
- polarization analyzer
- APC service

The APC service is part of the core stack because it talks to a remote APC over its API. It is not deployed as a resource agent next to a device host.

## Layout

- `docker-compose.yml`: core stack definition
- `.env`: default core environment
- `env/core-virtual-lab.env`: tracked env file for the local virtual-lab setup
- `env/detection-agent.env.example`: example detection-agent configuration
- `env/polarization-controller.env.example`: example polarization-controller configuration
- `scripts/deploy-core.sh`: start the core stack
- `scripts/stop-core.sh`: stop the core stack
- `scripts/deploy-detection-agent.sh`: deploy one detection resource agent
- `scripts/stop-detection-agent.sh`: stop one detection resource agent
- `scripts/deploy-polarization-controller.sh`: deploy one polarization-control resource agent
- `scripts/stop-polarization-controller.sh`: stop one polarization-control resource agent
- `scripts/deploy-laptop-virtual-lab.sh`: launch the local virtual lab
- `scripts/stop-laptop-virtual-lab.sh`: stop the local virtual lab

## Core Deployment

The core scripts support `ENV_FILE`. If not provided, they use `.env`.

Example default run:

```bash
./scripts/deploy-core.sh
```

Example explicit env file:

```bash
ENV_FILE=env/core-virtual-lab.env ./scripts/deploy-core.sh
```

Example core variables:

```env
BROKER_URL=nats://nats:4222
ORCHESTRATOR_URL=http://experiment-orchestrator:8080
APC_ENDPOINT=/apc/main
APC_DRIVER_TYPE=qunnect
APC_API_BASE_URL=http://10.0.0.25:8000/qunnect-api
APC_DEVICE_ID=apc-01
APC_REQUEST_TIMEOUT_S=10
APC_VERIFY_SSL=true
```

Notes:

- `deploy-core.sh` runs attached and streams logs in the terminal
- press `Ctrl+C` to stop it
- `stop-core.sh` can also stop it from another terminal

Core endpoints:

- GUI: `http://localhost:8050`
- orchestrator API: `http://localhost:8080`
- NATS: `localhost:4222`

## Detection Agent Deployment

Use `detection-agent` on a host connected to a time-tagger resource.

Copy and edit the example:

```bash
cp env/detection-agent.env.example env/detection-agent.env
```

Deploy:

```bash
ENV_FILE=env/detection-agent.env ./scripts/deploy-detection-agent.sh
```

Stop:

```bash
ENV_FILE=env/detection-agent.env ./scripts/stop-detection-agent.sh
```

For laptop testing, use `BROKER_URL=nats://host.docker.internal:4222`.

## Polarization Controller Deployment

Use `polarization-controller` on a host connected to the waveplate controller hardware.

Copy and edit the example:

```bash
cp env/polarization-controller.env.example env/polarization-controller.env
```

Deploy:

```bash
ENV_FILE=env/polarization-controller.env ./scripts/deploy-polarization-controller.sh
```

Stop:

```bash
ENV_FILE=env/polarization-controller.env ./scripts/stop-polarization-controller.sh
```

Important settings:

- `BROKER_URL`
- `ENDPOINT`
- `HWP_ADDR`
- `QWP_ADDR`
- `DRIVER_TYPE`

For `DRIVER_TYPE=virtual` or `DRIVER_TYPE=dummy`, the deploy script does not map physical devices.

## Local Virtual Lab

The one-command laptop launcher starts:

- two virtual detection agents
- two virtual polarization controllers
- the core stack with the APC service in virtual mode

Run:

```bash
./scripts/deploy-laptop-virtual-lab.sh
```

This script uses:

- `env/detection-agent-virtual-alice.env`
- `env/detection-agent-virtual-bob.env`
- `env/polarization-controller-virtual-alice.env`
- `env/polarization-controller-virtual-bob.env`
- `env/core-virtual-lab.env`

If you want different files:

```bash
ALICE_DETECTOR_ENV=env/my-detector-alice.env \
BOB_DETECTOR_ENV=env/my-detector-bob.env \
ALICE_POLARIZER_ENV=env/my-polarizer-alice.env \
BOB_POLARIZER_ENV=env/my-polarizer-bob.env \
CORE_ENV_FILE=env/my-core.env \
./scripts/deploy-laptop-virtual-lab.sh
```

Stop it from another terminal:

```bash
./scripts/stop-laptop-virtual-lab.sh
```

## Deployment Model

- `detection-agent` and `polarization-controller` are resource agents and can be deployed independently on resource-adjacent hosts
- `apc-service` is a core-side capability and should be deployed with the core stack
- `apc-service` keeps a small public contract: `start`, `stop`, and `check_link`
- `polarization-analyzer` continues to use the same APC-aware workflow, but it now talks to the standalone APC service instead of APC logic embedded in the polarization-controller repo
- if needed, analyzer calls can override the default APC target by passing only `ip_address`, `port`, and `device_id` in the APC parameter block
