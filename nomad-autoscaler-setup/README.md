# Nomad Autoscaler Setup with OrbStack

This project uses Datadog as the autoscaler APM source.

## What gets provisioned

- 3 Nomad servers: `server-vm-0..2`
- 3 Nomad clients: `client-vm-0..2`
- Datadog Agent on all Nomad servers and clients
- Nomad Autoscaler systemd service on Nomad servers

## Scaling configuration

- Source: `datadog`
- Query metric: `nomad.nomad_client_allocs_cpu_total_percent`
- Evaluation interval: `10s`
- Cooldown: `30s`
- Range: `1..10`

## Datadog credentials (Ansible Vault)

1. Copy `ansible/group_vars/all/vault.example.yml` to `ansible/group_vars/all/vault.yml`.
2. Fill in `datadog_api_key` and `datadog_app_key`.
3. Encrypt the file:

```bash
ansible-vault encrypt ansible/group_vars/all/vault.yml
```

4. Run provisioning with a vault password prompt:

```bash
cd nomad-autoscaler-setup
make provision
```

If your Ansible config does not already provide a vault password source, run playbooks with `--ask-vault-pass`.

`make provision` now resolves Datadog credentials in this order:

1. `ansible/group_vars/all/vault.yml` (if present)
2. Local file `.datadog.env` (created once via `make setup-datadog-creds`)
3. Environment variables `DD_API_KEY` and `DD_APP_KEY`

Set local credentials once so future `make provision` runs are non-interactive:

```bash
make setup-datadog-creds
```

You can also provide credentials via environment variables (fallback when Vault vars are not set):

```bash
export DD_API_KEY="<your-datadog-api-key>"
export DD_APP_KEY="<your-datadog-app-key>"
make provision
```

To pass Vault flags through make:

```bash
make ansible ANSIBLE_EXTRA_ARGS="--ask-vault-pass"
```

## Verify

```bash
NOMAD_ADDR=http://server-vm-0.orb.local:4646 nomad node status
orb -m server-vm-0 sudo systemctl status nomad-autoscaler
orb -m server-vm-0 sudo systemctl status datadog-agent
orb -m client-vm-0 sudo systemctl status datadog-agent
orb -m server-vm-0 sudo /opt/datadog-agent/bin/agent/agent status | grep -A5 -i openmetrics
```

## UIs

- Nomad: `http://server-vm-0.orb.local:4646/ui`
- Consul: `http://server-vm-0.orb.local:8500/ui`
- Datadog: `https://app.datadoghq.com` (or your Datadog site)

## Important files

- `main.tf`
- `ansible/playbooks/site.yml`
- `ansible/roles/datadog/`
- `ansible/roles/nomad_autoscaler/templates/autoscaler.hcl.j2`
- `jobs/webapp-autoscale.nomad.hcl`

## Cleanup

```bash
make destroy
```
