# Onboarding a new resource server with mTLS

This guide starts with a new Ubuntu or Debian server and ends with a server that appears in **GUI → Infrastructure** and can deploy, start, stop, restart, inspect, and stream logs from Measurement Plane resource agents.

## What must be done once

A completely empty server cannot accept a command from the GUI because it has no trusted control service yet. One bootstrap installation is therefore unavoidable. The bootstrap installs the small `measurement-plane-resource-supervisor` systemd service and gives it a node-specific TLS identity. After that installation, normal operation does not use SSH: all GUI control travels through the supervisor's mTLS API.

The supervisor has no general shell endpoint. It supports only health, allow-listed resource-agent deployment, status, start, stop, restart, removal, bounded logs, and live logs.

## Server and network requirements

The target should have:

- Ubuntu or Debian with systemd and a supported Python 3;
- an IP address or DNS name routable from the machine running `topology-service`;
- a stable address, because that exact IP/DNS name is placed in its server certificate;
- inbound TCP port `9443` allowed from the topology-service host only;
- enough disk/RAM for Docker and the selected agents;
- Internet access during bootstrap if Python or Docker must be installed;
- Internet access when an allow-listed image is not already cached locally.

The target does **not** have to be on the same subnet. It only needs bidirectional routed TCP connectivity from topology-service to port `9443`. A same-subnet static IP is the simplest laboratory arrangement. Across routed networks, VPNs, or NAT, use the stable address that topology-service actually connects to and configure the corresponding port forward.

For an offline target, install Python 3 and Docker from local packages and preload the two permitted images before running the bundle installer.

## Information to collect from a new server

You need only the following values before enrollment:

| Value | How to obtain it | Where it is used |
| --- | --- | --- |
| Stable IP address or DNS name | On Linux, run `ip -br address` or `hostname -I`; choose the address reachable from the control plane | Certificate SAN and GUI supervisor address |
| SSH user and port | The account used for initial administration; SSH normally uses port `22` | One-time bootstrap only |
| Supervisor port | Use `9443` unless the lab assigns another port | Firewall and GUI mTLS port |
| Control-plane IP | On the platform server, inspect `ip -br address`; use the address the resource server routes back to | Restrict the supervisor firewall rule |
| NATS URL | `nats://CONTROL_PLANE_IP:4222` in a normal routed lab | Agent deployment form |
| Agent settings | Unique endpoint, device type, channels and physical serial/addresses | Agent deployment form |

Do not use `localhost` in the NATS URL: from the resource-agent container that
would refer to the resource server itself. Docker Desktop and Lima test networks
may need a special gateway hostname; the QLab exception is documented below.

Before enrollment, verify both directions:

```bash
# From the control-plane host:
ping SERVER_IP
ssh SSH_USER@SERVER_IP

# From the resource server (after NATS is running):
nc -vz CONTROL_PLANE_IP 4222
```

ICMP may be disabled by policy, so a failed `ping` is not conclusive; SSH and the
TCP checks are the useful tests.

## Recommended firewall rule

Replace `CONTROL_PLANE_IP` with the source address seen by the server:

```bash
sudo ufw allow from CONTROL_PLANE_IP to any port 9443 proto tcp
sudo ufw status
```

Do not expose port `9443` broadly to the Internet. mTLS rejects unauthenticated clients, but network restriction remains useful defense in depth.

## Option A: one-command bootstrap over temporary SSH

From `measurement-plane-deployment` on the control laptop:

```bash
./scripts/bootstrap-supervisor-node.sh \
  alice \
  10.10.101.25 \
  admin@10.10.101.25 \
  9443 \
  22
```

Arguments are:

1. unique node name;
2. exact IP address or DNS name that topology-service will use;
3. temporary SSH target;
4. supervisor listen port, normally `9443`;
5. temporary SSH port, normally `22`.

The command creates a node-specific bundle, copies it over verified SSH, runs its installer with `sudo`, removes the remote temporary bundle, and starts the supervisor. SSH can be disabled afterward if it is not otherwise required.

## Option B: bootstrap without control-plane SSH

Generate the bundle on the control laptop:

```bash
./scripts/create-supervisor-node-bundle.sh alice 10.10.101.25 9443
```

The resulting archive is placed under:

```text
dist/resource-supervisor-alice.tar.gz
```

Transfer that archive by USB, an administrator file-transfer mechanism, or any existing secure channel. On the new server run:

```bash
mkdir -p /tmp/resource-supervisor-install
cd /tmp/resource-supervisor-install
tar -xzf /path/to/resource-supervisor-alice.tar.gz
sudo ./install.sh
```

After confirming the service is active, securely delete the transferred archive because it contains that server's private key. It does not contain the supervisor CA private key or topology client private key.

## Add the server to the GUI

1. Open the GUI and log in.
2. Open **Infrastructure**.
3. Under **Remote nodes**, enter a display name, the certified IP address, and port `9443`.
4. Click **Add remote node**.
5. Click **Test**.

A successful test reports the certificate-authenticated node name, supervisor version, and Docker version. A certificate whose SAN does not match the entered address is rejected.

The GUI's status has this meaning:

- **connected**: mTLS succeeded and the supervisor can reach Docker;
- **unreachable**: routing, firewall, service, or certificate verification failed;
- the text under the status is the current reason returned by the topology
  service. **Check now** simply performs that health probe immediately; it does
  not install or modify anything.

You can then choose the node under **Deploy resource agent**. Deployment and every later action use mTLS:

- **Deploy** pulls or reuses the fixed agent image and starts it;
- **Refresh** reads its current Docker state;
- **Start** starts an exited container;
- **Stop** stops it but keeps its configuration;
- **Restart** restarts it;
- **Remove** deletes the managed container;
- **Logs** opens a live authenticated stream and includes the recent tail.

Agent containers use `--restart unless-stopped`, and the supervisor itself is enabled through systemd. Both therefore return after a server reboot, except an agent explicitly stopped by the operator remains stopped.

## Deploy an agent from the GUI

1. Select the connected remote server.
2. Select **Detection agent** or **Polarization controller agent**.
3. Enter a stable, unique endpoint such as `/timetagger/alice`.
4. Enter the NATS broker URL reachable from that server, normally
   `nats://CONTROL_PLANE_IP:4222`.
5. Choose **Virtual test driver** only for a hardware-free acceptance test. Choose
   **Physical hardware** for the real device and supply its serial or controller
   addresses.
6. Click **Deploy agent** and follow the progress card under that server.
7. Wait for **ready**. If the container is running but the agent is not ready,
   read its displayed reason and open **Live logs**.

The supervisor pulls the allow-listed image directly from GHCR on the resource
server and creates the container there. The GUI does not copy an image or source
repository and does not open an SSH session for deployments.

Once ready, the agent advertises its resources on NATS. Only then does it appear
in topology-node resource selectors. Adding a server to Infrastructure does not
automatically add an optical topology node; create that node separately in the
main Topology workspace and bind it to the advertised resource.

## What the installer changes

The bundle installer:

- installs Python 3, Docker, and CA certificates through `apt` when missing;
- installs code in `/opt/measurement-plane/resource-supervisor`;
- installs configuration and the node identity in `/etc/measurement-plane/resource-supervisor`;
- sets the private key to mode `0600`;
- creates and enables `measurement-plane-resource-supervisor.service`;
- starts Docker and the supervisor.

Useful local diagnostic commands are:

```bash
sudo systemctl status measurement-plane-resource-supervisor
sudo journalctl -u measurement-plane-resource-supervisor -f
sudo ss -lntp | grep 9443
sudo docker ps -a
```

These commands are for server administration. They are not needed for normal GUI operation.

## Certificate ownership and rotation

The private CA and topology-service client identity live under the ignored directory `measurement-plane-deployment/secrets/supervisor-pki`. Back up the CA key securely and never copy it to a resource server. Every server receives only:

- the public CA certificate;
- its own server certificate;
- its own server private key.

Re-running the bootstrap command updates the supervisor and rotates that node's server certificate. Restart topology-service after rotating the topology client certificate or CA. If the CA itself is replaced, every node must receive a new certificate before the control plane can reconnect.

## QLab Lima mapping

The two local VMs listen on guest port `9443`. Lima forwards them to the macOS/Docker Desktop host:

| Node | Address used by topology-service | Port | Guest endpoint |
| --- | --- | --- | --- |
| QLab Alice | `192.168.65.254` | `9445` | `qlab-alice:9443` |
| QLab Bob | `192.168.65.254` | `9446` | `qlab-bob:9443` |

Both certificates contain IP SAN `192.168.65.254`, because that is the address verified by the Dockerized topology client. Real servers normally use their direct IP and port `9443` without forwarding.

## Troubleshooting

- **Connection refused or timeout:** check routing, port `9443`, firewall, and `systemctl status`.
- **Certificate verify failed / hostname mismatch:** the GUI address differs from the address used when creating the bundle. Issue a new bundle for the correct stable IP or DNS name.
- **Client certificate required:** the caller is not topology-service or its client identity is not mounted.
- **Image pull denied:** authenticate Docker to GHCR if needed or preload the allow-listed image.
- **Agent starts but is not shown alive:** verify its NATS broker address is reachable from the resource server/container.
- **Unmanaged-container refusal:** the requested name already belongs to a container not created by the supervisor. Rename or remove that container through server administration; the supervisor will not overwrite it.
