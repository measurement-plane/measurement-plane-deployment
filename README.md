# Measurement Plane Deployment

This repository is the single deployment entry point for the Measurement Plane platform.

It supports:

- core deployment on a central node
- standalone resource-agent deployment for `detection-agent`
- standalone resource-agent deployment for `polarization-controller`
- one-command local virtual-lab deployment
- one-command real-lab deployment from a central node over SSH

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
- `env/real-lab.env.example`: example multi-node real-lab deployment config
- `env/detection-agent.env.example`: example detection-agent configuration
- `env/detection-agent-alice.env.example`: example Alice detection-agent config
- `env/detection-agent-bob.env.example`: example Bob detection-agent config
- `env/polarization-controller.env.example`: example polarization-controller configuration
- `env/polarization-controller-alice.env.example`: example Alice polarization-controller config
- `env/polarization-controller-bob.env.example`: example Bob polarization-controller config
- `scripts/deploy-core.sh`: start the core stack
- `scripts/stop-core.sh`: stop the core stack
- `scripts/deploy-detection-agent.sh`: deploy one detection resource agent
- `scripts/stop-detection-agent.sh`: stop one detection resource agent
- `scripts/deploy-polarization-controller.sh`: deploy one polarization-control resource agent
- `scripts/stop-polarization-controller.sh`: stop one polarization-control resource agent
- `scripts/deploy-laptop-virtual-lab.sh`: launch the local virtual lab
- `scripts/stop-laptop-virtual-lab.sh`: stop the local virtual lab
- `scripts/deploy-real-lab.sh`: deploy the full real lab from the central node
- `scripts/stop-real-lab.sh`: stop the full real lab from the central node

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

## Real Lab Deployment

The real-lab deployment model is:

- central node runs the core stack
- Alice host runs the Alice hardware-adjacent agents
- Bob host runs the Bob hardware-adjacent agents
- the central node deploys the remote hosts over SSH

The remote hosts do not need the repo preinstalled manually. The deployment script synchronizes the
`measurement-plane-deployment` directory to the target path and then runs the existing per-node deployment scripts there.

Before deploying a remote agent, the helper checks whether Docker is reachable on the remote host. If the Docker daemon is not running, it tries to start it using common service commands.

### SSH Recommendation

Use SSH keys or SSH config aliases.

Do not store SSH passwords in this repository or in tracked env files.

Recommended:

```sshconfig
Host alice-qnet
    HostName 10.0.0.21
    User labuser
    IdentityFile ~/.ssh/qnet_lab

Host bob-qnet
    HostName 10.0.0.22
    User labuser
    IdentityFile ~/.ssh/qnet_lab
```

Then your real-lab env can use:

```env
ALICE_SSH_TARGET=alice-qnet
BOB_SSH_TARGET=bob-qnet
```

### Setup

1. Copy the example lab config:

```bash
cp env/real-lab.env.example env/real-lab.env
```

2. Create the real hardware env files referenced there, for example:

```bash
cp env/detection-agent-alice.env.example env/detection-agent-alice.env
cp env/detection-agent-bob.env.example env/detection-agent-bob.env
cp env/polarization-controller-alice.env.example env/polarization-controller-alice.env
cp env/polarization-controller-bob.env.example env/polarization-controller-bob.env
```

3. Update:

- `env/real-lab.env`
- `env/detection-agent-alice.env`
- `env/detection-agent-bob.env`
- `env/polarization-controller-alice.env`
- `env/polarization-controller-bob.env`
- your central-node core env file, typically `.env`

Important:

- on remote Alice/Bob hosts, set `BROKER_URL` to the central node's reachable QNet IP, for example:
  - `nats://10.0.0.10:4222`
- detection and polarization controller endpoints should be unique and stable
- remote hosts must have Docker, `bash`, `tar`, and SSH access enabled
- here `bash` means a normal Linux shell environment on the remote node, not Git Bash on Windows
- if Docker is installed but the daemon is not running after a reboot, the deployment helper tries to start it automatically
- if your lab hosts require a nonstandard Docker start command, set `REMOTE_DOCKER_START_CMD` in `env/real-lab.env`

### Deploy

From the central node:

```bash
LAB_ENV_FILE=env/real-lab.env ./scripts/deploy-real-lab.sh
```

This will:

- deploy the core locally in detached mode
- synchronize the deployment repo to Alice and Bob
- deploy detection and polarization-controller containers on both remote hosts

### Stop

From the central node:

```bash
LAB_ENV_FILE=env/real-lab.env ./scripts/stop-real-lab.sh
```

### Dry Run

To print what would be executed without actually deploying:

```bash
DRY_RUN=1 LAB_ENV_FILE=env/real-lab.env ./scripts/deploy-real-lab.sh
```

## Deployment Model

- `detection-agent` and `polarization-controller` are resource agents and can be deployed independently on resource-adjacent hosts
- in a real lab, those resource agents should run on the remote hardware-adjacent hosts and connect back to the central node broker
- `apc-service` is a core-side capability and should be deployed with the core stack
- `apc-service` keeps a small public contract: `start`, `stop`, and `check_link`
- `polarization-analyzer` continues to use the same APC-aware workflow, but it now talks to the standalone APC service instead of APC logic embedded in the polarization-controller repo
- if needed, analyzer calls can override the default APC target by passing only `ip_address`, `port`, and `device_id` in the APC parameter block
