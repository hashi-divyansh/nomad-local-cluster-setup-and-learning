# Nomad Autoscaler Setup with OrbStack

This project uses Prometheus as the autoscaler APM source.

## What gets provisioned

- 3 Nomad servers: `server-vm-0..2`
- 3 Nomad clients: `client-vm-0..2`
- 1 Prometheus VM: `prometheus-vm`
- Nomad Autoscaler systemd service on Nomad servers

## Scaling configuration

- Source: `prometheus`
- Query: `avg(nomad_client_host_cpu_total_percent{job="nomad-clients"})`
- Target CPU: `30`
- Evaluation interval: `10s`
- Cooldown: `30s`
- Range: `1..10`

## Quick start

```bash
cd nomad-autoscaler-setup
make provision
```

## Verify

```bash
NOMAD_ADDR=http://server-vm-0.orb.local:4646 nomad node status
orb -m server-vm-0 sudo systemctl status nomad-autoscaler
orb -m prometheus-vm sudo systemctl status prometheus
curl -s http://prometheus-vm.orb.local:9090/api/v1/targets | jq '.data.activeTargets[] | {scrapeUrl, health}'
```

## UIs

- Nomad: `http://server-vm-0.orb.local:4646/ui`
- Consul: `http://server-vm-0.orb.local:8500/ui`
- Prometheus: `http://prometheus-vm.orb.local:9090/graph`

## Important files

- `main.tf`
- `ansible/playbooks/site.yml`
- `ansible/roles/prometheus/`
- `ansible/roles/nomad_autoscaler/templates/autoscaler.hcl.j2`
- `jobs/webapp-autoscale.nomad.hcl`

## Note

Legacy InfluxDB/Telegraf roles still exist in the repo for reference, but the default deployment path now uses Prometheus.

## Cleanup

```bash
make destroy
```
