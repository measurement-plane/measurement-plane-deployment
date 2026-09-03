# Measurement Plane deployment

This repository has one recommended operating model:

1. run the core platform on one control-plane server;
2. enroll each Linux resource server once with the mTLS resource supervisor;
3. add those servers in **GUI → Infrastructure**;
4. deploy and operate detection or polarization-controller agents from the GUI;
5. create the optical topology in the GUI or import its JSON document.

The topology and remote-server inventory are persisted by `topology-service`.
They are not defined in deployment scripts. The standard stack discovers only
agents that are actually advertising on NATS; it does not inject Alice, Bob, or
predefined resource fixtures.

## Start the core platform

Copy the production environment template and replace the credentials:

```bash
cp env/core.env.example .env
```

At minimum, set a long random `AUTH_SECRET` and change the initial GUI password.
Then start the platform:

```bash
./scripts/deploy-core.sh
```

Open <http://localhost:8050>. The stack includes NATS, the web frontend,
measurement API, topology service, experiment orchestrator, coincidences
analyzer, polarization analyzer, TWTT capability, entanglement-distribution
service capability, and APC service.

Stop it from another terminal with:

```bash
./scripts/stop-core.sh
```

## Add a resource server

A server must first receive a small allow-listed supervisor and its mTLS
identity. SSH is used only for this one-time enrollment; agent deployment,
lifecycle, status, and live logs subsequently use the supervisor API.

For a server reachable as `10.10.101.25` with SSH user `admin`:

```bash
./scripts/bootstrap-supervisor-node.sh \
  alice \
  10.10.101.25 \
  admin@10.10.101.25 \
  9443 \
  22
```

Then open **Infrastructure** and add:

- Name: any useful display name, such as `Alice`
- Supervisor address: the exact stable IP/DNS name used in the bootstrap command
- mTLS port: `9443`

The server card reports whether the supervisor, certificate, and Docker engine
are healthy. Select that server in **Deploy resource agent**, fill in the unique
agent endpoint, NATS address as seen from the remote server, and hardware or
virtual-driver settings, then click **Deploy agent**. Progress, readiness,
failure reason, controls, and live logs remain grouped under that server.

The complete preparation and GUI workflow is in
[Resource server onboarding](docs/RESOURCE_SUPERVISOR_ONBOARDING.md).

## Create the topology

Resource-server registration and topology design are separate:

- **Infrastructure** says where agents may run and controls their containers.
- **Topology** describes optical source/analyzer nodes and their links.
- A topology node binds only to resource agents currently discovered through
  their Measurement Plane advertisements.

Use **+ Source** or **+ Polarization analyzer**, drag nodes into place, configure
their live resource bindings, and link two selected nodes. Every change is sent
immediately to `topology-service`; refreshing the page restores its last accepted
topology. Importing JSON goes through the same server-side validation.

## Run entanglement distribution

Create two active **Polarization analyzer** topology nodes. Each node must bind
one live polarization controller plus its H and V time-tagger channels. Open
**Operations → Services**, choose **Entanglement distribution**, and select the
two analyzer nodes. The service resolves those bindings from the topology
service, reports the temporary routing approval, streams the polarization
fringes as they are measured, then displays the tomography basis matrix.

The caller supplies only the two analyzer node IDs. Link-specific coincidence
defaults live in `.env` under `ENTANGLEMENT_*`; calibrate
`ENTANGLEMENT_PEAK0_PS` for the installed optical path before a physical run.

## Local Lima acceptance lab

The sibling `vm-lab` directory is an isolated development fixture for testing
the same GUI-managed workflow without physical devices. It creates two servers
and lets the GUI deploy agents using virtual hardware drivers. It does not
bypass mTLS and no longer injects predefined resources into topology discovery.

```bash
../vm-lab/up.sh
./scripts/run-local-virtual-gui.sh
```

See [`vm-lab/README.md`](../vm-lab/README.md) for its port mappings and first-time
enrollment. Files whose names include `virtual`, `laptop`, `real-lab`, or direct
agent deploy scripts are compatibility/development tooling; they are not part of
the recommended GUI-managed production workflow. See [scripts/README.md](scripts/README.md).

## Security and persistence

- Supervisor PKI is generated under ignored `secrets/supervisor-pki/`; back it up
  securely and never copy the CA private key to a resource server.
- Restrict TCP `9443` to the topology-service host even though mTLS is mandatory.
- Resource servers need outbound access to GHCR and to the NATS broker.
- `topology-data` stores the accepted topology and registered-server inventory.
- Resource-agent containers use `--restart unless-stopped`; the supervisor is a
  systemd service enabled at boot.

## Script map

The normal workflow needs only these scripts:

| Script | Purpose |
| --- | --- |
| `deploy-core.sh` | Start the central platform |
| `stop-core.sh` | Stop the central platform |
| `bootstrap-supervisor-node.sh` | Enroll one resource server once |
| `create-supervisor-node-bundle.sh` | Build an offline/manual enrollment bundle |
| `init-supervisor-pki.sh` | Initialize the control-plane trust material |

All other scripts are catalogued and scoped in [scripts/README.md](scripts/README.md).
