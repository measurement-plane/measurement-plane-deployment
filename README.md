# Measurement Plane Deployment

This repository is now the single deployment entry point for the Measurement Plane system.

It supports two deployment modes:

- `core`: deploy the central services on a central node
- `resource agents`: deploy resource agents individually on the machines connected to the physical resources

The old `detection-agent-ops` and `polarization-controller-ops` wrappers are no longer needed. Their deployment behavior has been consolidated here.

## What Lives Here

### Core deployment

The core stack is deployed with Docker Compose and includes:

- NATS broker
- Experiment Orchestrator
- Measurement Plane GUI
- Coincidences Analyzer Agent
- Polarization Analyzer Agent

This is the deployment you run on the central node.

### Resource-agent deployment

This repository also contains standalone scripts for deploying:

- `detection-agent`
- `polarization-controller`

These are intended to run on resource-adjacent hosts, typically one machine per connected device or lab node.

## Layout

- `docker-compose.yml`: central core stack
- `.env`: environment for the core compose deployment
- `env/detection-agent.env.example`: example configuration for a detection agent node
- `env/polarization-controller.env.example`: example configuration for a polarization controller node
- `scripts/deploy-core.sh`: deploy the central core stack
- `scripts/stop-core.sh`: stop the central core stack
- `scripts/deploy-detection-agent.sh`: deploy one detection agent container
- `scripts/stop-detection-agent.sh`: stop one detection agent container
- `scripts/deploy-polarization-controller.sh`: deploy one polarization controller container
- `scripts/stop-polarization-controller.sh`: stop one polarization controller container
- `scripts/deploy-laptop-virtual-lab.sh`: one-command laptop startup for the core stack plus two virtual detectors and two virtual polarization controllers
- `scripts/stop-laptop-virtual-lab.sh`: stop that laptop setup explicitly
- `scripts/start.sh`: compatibility wrapper for `deploy-core.sh`
- `scripts/stop.sh`: compatibility wrapper for `stop-core.sh`

## Requirements

- Docker >= 24
- Docker Compose plugin
- Linux is recommended for the resource-agent deployments

## Core Deployment

Use this on the central node.

### Configure the core environment

Edit `.env` as needed:

```env
BROKER_URL=nats://nats:4222
ORCHESTRATOR_URL=http://experiment-orchestrator:8080
```

These values are used by the compose stack internally.

### Start the core stack

```bash
cd measurement-plane-deployment
chmod +x scripts/*.sh
./scripts/deploy-core.sh
```

`deploy-core.sh` runs in attached mode and streams logs in the terminal. Press `Ctrl+C` to stop the stack.

You can also keep using:

```bash
./scripts/start.sh
```

### Stop the core stack

```bash
./scripts/stop-core.sh
```

Or:

```bash
./scripts/stop.sh
```

### Core endpoints

- GUI: `http://localhost:8050`
- Orchestrator API: `http://localhost:8080`
- NATS: `localhost:4222`

## Detection Agent Deployment

Use this on a machine connected to the Time Tagger resource.

### Configure

Copy the example file and edit it:

```bash
cp env/detection-agent.env.example env/detection-agent.env
```

Important settings:

- `BROKER_URL`: where the central NATS broker is reachable from this container
- `ENDPOINT`: agent endpoint advertised on the Measurement Plane
- `TT_TYPE`: driver backend, for example `swabian` or `virtual`
- `TT_SERIAL`: Time Tagger serial number
- `PPS_CHANNEL`: PPS channel number
- `TT_CHANNELS`: enabled detector channels
- `TT_TRIGGER_LEVELS`: per-channel trigger thresholds
- `TT_EVENT_DIVIDERS`: per-channel event thinning ratios
- `TT_DEAD_TIMES`: optional per-channel dead times
- `TT_DELAYS`: optional per-channel delays

If a value contains shell metacharacters such as `|`, quote it in the env file, for example:

```env
TT_CHANNELS="1|2|3|4|8"
```

Virtual mode settings:

- `VIRTUAL_SECONDS`: number of per-second dummy snapshots stored in the looping dataset
- `VIRTUAL_EVENTS_PER_SECOND`: number of time tags generated per channel per second
- `VIRTUAL_SEED`: deterministic random seed for reproducible synthetic data
- `VIRTUAL_DATASET_FILE`: optional explicit path for the generated `.npz` dataset inside the container

### Deploy

```bash
./scripts/deploy-detection-agent.sh
```

If you want to use a different config file:

```bash
ENV_FILE=/path/to/custom-detection-agent.env ./scripts/deploy-detection-agent.sh
```

### Stop

```bash
./scripts/stop-detection-agent.sh
```

Notes:

- The detection-agent deploy script runs the container with `--privileged`.
- If you run detection-agent containers separately on the same laptop as the core stack, set `BROKER_URL=nats://host.docker.internal:4222`.
- If your Docker/network setup needs extra flags, set `DOCKER_EXTRA_ARGS` in the env file. On Linux a common choice is `--add-host=host.docker.internal:host-gateway`.
- On Git Bash for Windows, endpoint values such as `/timetagger/alice` are passed without MSYS path conversion by the deploy script, so the advertised endpoint stays exactly `/timetagger/alice`.

### Virtual detection-agent deployment

To run a virtual detection-agent, copy the example env file and change at least:

```env
CONTAINER_NAME=detection_agent_virtual_alice
BROKER_URL=nats://host.docker.internal:4222
ENDPOINT=/timetagger/alice
TT_TYPE=virtual
PPS_CHANNEL=8
TT_CHANNELS="1|2|3|4|8"
VIRTUAL_SECONDS=20
VIRTUAL_EVENTS_PER_SECOND=500000
VIRTUAL_SEED=12345
```

Then deploy:

```bash
ENV_FILE=env/detection-agent-virtual-alice.env ./scripts/deploy-detection-agent.sh
```

You can deploy multiple virtual detection agents by creating multiple env files with different:

- `CONTAINER_NAME`
- `ENDPOINT`
- `VIRTUAL_SEED`
- optionally `TT_CHANNELS`

Example second virtual agent:

```env
CONTAINER_NAME=detection_agent_virtual_bob
BROKER_URL=nats://host.docker.internal:4222
ENDPOINT=/timetagger/bob
TT_TYPE=virtual
VIRTUAL_SEED=67890
```

## One-Command Laptop Setup

If you want to run the full local stack with two virtual detectors and two virtual polarization controllers, use:

```bash
./scripts/deploy-laptop-virtual-lab.sh
```

That wrapper:

- starts the virtual Alice detector from `env/detection-agent-virtual-alice.env`
- starts the virtual Bob detector from `env/detection-agent-virtual-bob.env`
- starts the virtual Alice polarization controller from `env/polarization-controller-virtual-alice.env`
- starts the virtual Bob polarization controller from `env/polarization-controller-virtual-bob.env`
- starts the core stack in attached mode and streams logs in the terminal

Press `Ctrl+C` to stop the full setup. The wrapper will stop:

- both virtual detection-agent containers
- both virtual polarization-controller containers
- the core Docker Compose stack

If you want to use different env files, override them inline:

```bash
ALICE_DETECTOR_ENV=env/my-detector-alice.env \
BOB_DETECTOR_ENV=env/my-detector-bob.env \
ALICE_POLARIZER_ENV=env/my-polarizer-alice.env \
BOB_POLARIZER_ENV=env/my-polarizer-bob.env \
./scripts/deploy-laptop-virtual-lab.sh
```

You can also stop the same setup explicitly from another terminal:

```bash
./scripts/stop-laptop-virtual-lab.sh
```

## Polarization Controller Deployment

Use this on a machine connected to the polarization-controller resource.

### Configure

Copy the example file and edit it:

```bash
cp env/polarization-controller.env.example env/polarization-controller.env
```

Important settings:

- `BROKER_URL`: where the central NATS broker is reachable from this container
- `ENDPOINT`: agent endpoint advertised on the Measurement Plane
- `HWP_ADDR`: device path for the half-wave plate controller
- `QWP_ADDR`: device path for the quarter-wave plate controller
- `DRIVER_TYPE`: backend driver type

### Deploy

```bash
./scripts/deploy-polarization-controller.sh
```

If you want to use a different config file:

```bash
ENV_FILE=/path/to/custom-polarization-controller.env ./scripts/deploy-polarization-controller.sh
```

### Stop

```bash
./scripts/stop-polarization-controller.sh
```

Notes:

- For `DRIVER_TYPE=kenesis`, the script maps the configured HWP and QWP devices into the container and adds the container to the `dialout` group.
- For `DRIVER_TYPE=virtual` or `DRIVER_TYPE=dummy`, no physical device mapping is used.
- If your Docker runtime requires additional flags, set `DOCKER_EXTRA_ARGS` in the env file.

### Virtual polarization-controller deployment

To run a virtual polarization controller, use `DRIVER_TYPE=virtual`:

```env
CONTAINER_NAME=polarization_controller_virtual_alice
BROKER_URL=nats://host.docker.internal:4222
ENDPOINT=/polarizer/alice
DRIVER_TYPE=virtual
```

Then deploy:

```bash
ENV_FILE=env/polarization-controller-virtual-alice.env ./scripts/deploy-polarization-controller.sh
```

You can deploy multiple virtual polarization controllers by creating multiple env files with different:

- `CONTAINER_NAME`
- `ENDPOINT`

## Recommended Deployment Pattern

### Central node

Run:

- `scripts/deploy-core.sh`

### Hardware node with a Time Tagger

Run:

- `scripts/deploy-detection-agent.sh`

### Hardware node with a polarization controller

Run:

- `scripts/deploy-polarization-controller.sh`

This keeps all deployment entry points in one repo while still allowing each node to deploy only the services it actually needs.

## Migration Note

The deployment scripts that used to live in:

- `detection-agent-ops`
- `polarization-controller-ops`

have been consolidated into this repository.
