# Nomad Autoscaler Namespace Test Setup

This repository provisions a Nomad cluster on OrbStack and configures a custom Nomad Autoscaler build for namespace-focused testing.

## What This Setup Includes

- 3 Nomad servers + 3 Nomad clients
- Consul for service discovery
- InfluxDB 1.8 as APM data source
- Telegraf agents (Docker) on servers and clients
- Nomad Autoscaler as a systemd service on servers
- HAProxy Nomad job with separate ports per namespace test path

## Current Namespace Behavior

Autoscaler config template:
- `ansible/roles/nomad_autoscaler/templates/autoscaler.hcl.j2`

Current setting:
- `namespace = ["*"]`

This means autoscaler tracks policies in all namespaces (`default`, `ns1`, `ns2`, etc.).

If you want scoped tracking, change it to an explicit list, for example:
- `namespace = ["ns1", "ns2"]`
- `namespace = ["default", "ns1", "ns2"]`

## Quick Start

```bash
cd nomad-autoscaler-setup
make provision
```

`make provision` does:
1. `terraform init`
2. `terraform apply -auto-approve`
3. inventory generation
4. full Ansible playbook run

## What Is Auto-Created

Nomad namespaces are created during server role configuration:
- `ns1`
- `ns2`

Source:
- `ansible/roles/nomad_server/defaults/main.yml`
- `ansible/roles/nomad_server/tasks/main.yml`

Jobs are not auto-submitted by Ansible in the current setup.

## Submit Test Jobs

Use Nomad UI (`http://server-vm-0.orb.local:4646/ui`) or CLI.

Recommended test jobs:
- `jobs/webapp-autoscale.nomad.hcl` (default namespace service: `webapp`)
- `jobs/webapp-autoscale-ns1.nomad.hcl` (namespace `ns1`, service: `webapp-ns1`)
- `jobs/webapp-autoscale-ns2.nomad.hcl` (namespace `ns2`, service: `webapp-ns2`)

Load balancer job:
- `jobs/load-balancer.nomad.hcl`

## Load Balancer Ports

HAProxy exposes separate frontends to keep namespace tests isolated:

- `:8080` -> backend `webapp` (default namespace)
- `:8081` -> backend `webapp-ns1`
- `:8082` -> backend `webapp-ns2`
- `:1936` -> HAProxy stats

## Test Autoscaler by Namespace

### 1. Verify autoscaler runtime config

```bash
orb -m server-vm-0 sudo cat /etc/nomad-autoscaler/autoscaler.hcl
```

### 2. Watch autoscaler decisions

```bash
orb -m server-vm-0 sudo journalctl -u nomad-autoscaler -f
```

Look for namespace info in policy target config, such as:
- `Namespace:default`
- `Namespace:ns1`
- `Namespace:ns2`

### 3. Generate namespace-specific load

```bash
make load-test WEBAPP_URL=http://<lb-ip>:8080/
make load-test WEBAPP_URL=http://<lb-ip>:8081/
make load-test WEBAPP_URL=http://<lb-ip>:8082/
```

### 4. Watch job scaling

```bash
NOMAD_ADDR=http://server-vm-0.orb.local:4646 nomad job status webapp
NOMAD_ADDR=http://server-vm-0.orb.local:4646 nomad job status -namespace=ns1 webapp-ns1
NOMAD_ADDR=http://server-vm-0.orb.local:4646 nomad job status -namespace=ns2 webapp-ns2
```

## Validate Cluster Health

```bash
# Clients ready
NOMAD_ADDR=http://server-vm-0.orb.local:4646 nomad node status

# Job status
NOMAD_ADDR=http://server-vm-0.orb.local:4646 nomad job status

# Autoscaler service
orb -m server-vm-0 sudo systemctl status nomad-autoscaler --no-pager

# InfluxDB reachable from server
orb -m server-vm-0 curl -I http://influxdb-vm.orb.local:8086/ping
```

## Common Commands

```bash
# Apply playbook changes only
make ansible

# Validate Nomad job files
nomad job validate jobs/load-balancer.nomad.hcl

# Destroy everything
make destroy
```

## Notes

- A single LB URL does not guarantee isolated namespace tests; use the dedicated ports above.
- If autoscaler namespace is not `[*]`, jobs outside configured namespaces will not scale.
- Telegraf container status on clients can be checked with:
  - `orb -m client-vm-0 sudo docker ps | grep telegraf`
  - `orb -m client-vm-1 sudo docker ps | grep telegraf`
  - `orb -m client-vm-2 sudo docker ps | grep telegraf`
