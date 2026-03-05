# Nomad Autoscaler Setup with OrbStack

HashiCorp Nomad Autoscaler with InfluxDB/Telegraf monitoring. Provisions 3 Nomad servers, 3 client nodes, and InfluxDB VM using Terraform + Ansible + custom autoscaler binary.

## Architecture

**Infrastructure:**
- **Nomad Cluster**: 3 servers + 3 clients with Consul service discovery
- **InfluxDB 1.8**: Docker container for time-series metrics storage
- **Telegraf**: Docker agent on all nodes collecting system and Docker metrics
- **Autoscaler**: Custom Linux ARM64 binary running as systemd service on servers
- **HAProxy**: Load balancer with dynamic Consul-based service discovery

**Scaling Policy:**
- **Metric Source**: InfluxDB `telegraf` database (Telegraf CPU metrics)
- **CPU Threshold**: 30% utilization (optimized for responsive scaling)
- **Min/Max Count**: 1-10 instances
- **Evaluation Interval**: 10 seconds
- **Cooldown Period**: 30 seconds between scaling actions

**Data Flow:**
```
Telegraf (all nodes)
    ↓
InfluxDB (telegraf database)
    ↓
Nomad Autoscaler (queries every 10s)
    ↓
Scale up/down webapp instances
    ↓
HAProxy (auto-discovers via Consul)
    ↓
Distribute load across all healthy instances
```

## Quick Start

**Prerequisites:** macOS with OrbStack, Terraform, Python 3, Ansible

### 1. Provision Cluster

```bash
cd nomad-autoscaler-setup
make provision
```

This command:
- Runs `terraform init && terraform apply` to create VMs
- Pre-pulls Docker images on all client nodes (nginx:alpine, telegraf:latest, influxdb:1.8)
- Generates Ansible inventory from Terraform outputs
- Deploys and starts all services (Nomad, Consul, InfluxDB, Telegraf, Autoscaler, HAProxy)

**Estimated time:** 5-10 minutes

### 2. Verify All Services

```bash
# Verify Nomad cluster health
NOMAD_ADDR=http://server-vm-0.orb.local:4646 nomad node status

# Verify autoscaler is running
orb -m server-vm-0 sudo systemctl status nomad-autoscaler

# Verify Telegraf collecting metrics
orb -m server-vm-0 docker ps --filter "name=telegraf"

# Verify InfluxDB has metrics data
orb -m influxdb-vm curl -s 'http://localhost:8086/query?db=telegraf' --data-urlencode 'q=SHOW MEASUREMENTS'

# List jobs deployed
NOMAD_ADDR=http://server-vm-0.orb.local:4646 nomad job status
```

### 3. Access Web Consoles

| Service | URL | Purpose |
|---------|-----|---------|
| **Nomad UI** | http://server-vm-0.orb.local:4646/ui | Monitor jobs, allocations, nodes |
| **Consul UI** | http://server-vm-0.orb.local:8500/ui | Service discovery, health checks |
| **HAProxy Stats** | http://192.168.139.232:1936/stats | Load balancer status and metrics |
| **InfluxDB** | http://influxdb-vm.orb.local:8086 | Query metrics (no web UI in v1.8) |

## Testing Autoscaling

### Generate Load and Monitor

**Terminal 1 - Watch Job Status:**
```bash
watch -n 2 'NOMAD_ADDR=http://server-vm-0.orb.local:4646 nomad job status webapp'
```

**Terminal 2 - Watch Autoscaler Decisions:**
```bash
orb -m server-vm-0 sudo journalctl -u nomad-autoscaler -f | grep -E "(scaling|from=|to=)"
```

**Terminal 3 - Generate Load:**
```bash
# First, find the load balancer IP
NOMAD_ADDR=http://server-vm-0.orb.local:4646 nomad alloc status $(nomad job allocations load-balancer -json | jq -r '.[0].ID') | grep "Nomad Addr"

# Then generate load (replace WEBAPP_URL with actual LB IP:port)
make load-test WEBAPP_URL=http://192.168.139.232:8080 HEY_FLAGS='-z 5m -c 200 -q 100'
```

### Expected Scaling Behavior

**Timeline (with 30% CPU threshold):**

| Time | Event | Observation |
|------|-------|-------------|
| 0s | Load test starts | 200 concurrent clients, 100 req/s |
| 0-30s | CPU builds up | Usage climbs past 30% threshold |
| 30-40s | Autoscaler detects high CPU | Evaluation interval triggers, evaluates metrics |
| 40-50s | **First scale-up triggered** | Nomad schedules additional webapp instance |
| 50-60s | **Second scale-up triggered** | Another instance scheduled |
| 60s+ | Continues scaling | Up to max 10 instances |
| Load stops | CPU drops below 30% | No more scale-up actions |
| +30s | **Cooldown expires** | Scale-down begins if still low |
| +40s+ | **Scales down** | Reduces to 1-2 instances |

**Monitor scaling in Nomad UI:**
- Job: `webapp` → "Allocations" tab shows instance count changing
- Each allocation shows CPU usage in real-time graphs

### Verify Load Balancer is Routing

```bash
# Check all healthy webapp backends registered in Consul
curl -s http://server-vm-0.orb.local:8500/v1/catalog/service/webapp | jq '.[] | {Node, ServiceAddress, ServicePort, ServiceID}'

# Test direct routing through HAProxy
curl -v http://192.168.139.232:8080/ | head -20

# Check HAProxy stats (backend health, session counts, response codes)
curl -s 'http://192.168.139.232:1936/stats' | grep -A 5 "webapp"
```

## Monitoring Metrics

### Query InfluxDB

**List all databases:**
```bash
curl -G 'http://influxdb-vm.orb.local:8086/query' --data-urlencode "q=SHOW DATABASES"
```

**Query Telegraf metrics (system data):**
```bash
# CPU metrics from all nodes
curl -G 'http://influxdb-vm.orb.local:8086/query?db=telegraf' \
  --data-urlencode 'q=SELECT mean("usage_user") + mean("usage_system") FROM "cpu" WHERE "cpu"="cpu-total" AND time > now() - 5m'

# Memory metrics
curl -G 'http://influxdb-vm.orb.local:8086/query?db=telegraf' \
  --data-urlencode 'q=SELECT "used_percent" FROM "mem" WHERE time > now() - 5m'

# Disk I/O metrics
curl -G 'http://influxdb-vm.orb.local:8086/query?db=telegraf' \
  --data-urlencode 'q=SELECT * FROM "diskio" LIMIT 10'
```

**Verify Telegraf is running on all nodes:**
```bash
for vm in server-vm-0 server-vm-1 server-vm-2 client-vm-0 client-vm-1 client-vm-2; do
  echo "=== $vm ==="
  orb -m $vm docker ps --filter "name=telegraf" --format "{{.Names}}: {{.Status}}"
done
```

## Troubleshooting

### Autoscaler Not Scaling

**Check autoscaler is running:**
```bash
orb -m server-vm-0 sudo systemctl status nomad-autoscaler
orb -m server-vm-0 sudo journalctl -u nomad-autoscaler -n 50 --no-pager
```

**Verify InfluxDB connectivity:**
```bash
orb -m server-vm-0 curl -I http://influxdb-vm.orb.local:8086/ping
```

**Check autoscaler configuration:**
```bash
orb -m server-vm-0 sudo cat /etc/nomad-autoscaler/autoscaler.hcl
```

**Verify autoscaler is querying telegraf database:**
```bash
# Look for "apm" in logs
orb -m server-vm-0 sudo journalctl -u nomad-autoscaler | grep -i "apm\|influx\|telegraf" | tail -20
```

### Tasks Not Starting / Image Pull Timeouts

- Docker images are **pre-pulled** during provisioning to prevent timeouts
- If allocations fail, check they're using pre-cached images:

```bash
orb -m client-vm-0 docker images | grep -E "nginx|telegraf|influxdb"
```

### Load Balancer Not Routing Traffic

```bash
# Verify webapp is registered in Consul with correct health
curl -s http://server-vm-0.orb.local:8500/v1/catalog/service/webapp | jq '.[] | {Node, ServiceAddress, ServicePort, Checks}'

# Verify HAProxy backend is UP (not DOWN)
curl -s 'http://192.168.139.232:1936/stats' | grep "webapp" | grep -v "^#"

# Check HAProxy logs in allocation
NOMAD_ADDR=http://server-vm-0.orb.local:4646 nomad alloc logs $(nomad job allocations load-balancer -json | jq -r '.[0].ID') haproxy
```

### InfluxDB Not Collecting Metrics

```bash
# Verify InfluxDB container is running
orb -m influxdb-vm docker ps --filter "name=influxdb"

# Check InfluxDB logs
orb -m influxdb-vm docker logs influxdb --tail 50

# Test connectivity from autoscaler
orb -m server-vm-0 curl -I http://influxdb-vm.orb.local:8086/ping

# Verify telegraf database exists
curl -G 'http://influxdb-vm.orb.local:8086/query' --data-urlencode "q=SHOW DATABASES"
```

### Telegraf Not Writing Metrics to InfluxDB

```bash
# Check Telegraf logs
orb -m server-vm-0 docker logs telegraf-server-vm-0 --tail 50

# Verify Telegraf connectivity to InfluxDB
orb -m server-vm-0 docker exec telegraf-server-vm-0 \
  curl -I http://influxdb-vm.orb.local:8086/ping
```

## Configuration Files

| Component | Location | Purpose |
|-----------|----------|---------|
| Nomad Server | `/etc/nomad.d/server.hcl` | Nomad server configuration |
| Nomad Client | `/etc/nomad.d/client.hcl` | Nomad client + Docker driver |
| Consul Server | `/etc/consul.d/server.json` | Consul server setup |
| Autoscaler | `/etc/nomad-autoscaler/autoscaler.hcl` | Autoscaler InfluxDB connection + policies |
| Telegraf | `/etc/telegraf/telegraf.conf` | Telegraf metrics collection config |
| InfluxDB | Docker volume | Persisted metrics database |
| HAProxy | `/etc/haproxy/haproxy.cfg` | Load balancer config (managed by Nomad) |

## Development & Customization

### Rebuild Autoscaler Binary

```bash
# Build for Linux ARM64 (required for OrbStack)
cargo build --release --target aarch64-unknown-linux-gnu

# Copy to bin/ and redeploy
cp target/aarch64-unknown-linux-gnu/release/nomad-autoscaler bin/

# Re-run ansible autoscaler role
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook \
  -i ansible/inventory/hosts.yml \
  ansible/playbooks/site.yml \
  --tags=nomad_autoscaler
```

### Adjust Scaling Policy

Edit [jobs/webapp-autoscale.nomad.hcl](jobs/webapp-autoscale.nomad.hcl):

```hcl
policy {
  cooldown            = "30s"          # Wait between scaling actions
  evaluation_interval = "10s"          # How often to check metrics
  
  check "cpu_usage" {
    target = 30                        # Change CPU threshold here
  }
}

scaling {
  min = 1
  max = 10                             # Adjust max instances
}
```

Then redeploy:
```bash
NOMAD_ADDR=http://server-vm-0.orb.local:4646 nomad job run jobs/webapp-autoscale.nomad.hcl
```

## Cleanup

Destroy all infrastructure:

```bash
cd nomad-autoscaler-setup
make destroy
```

---

## Project Structure

```
nomad-autoscaler-setup/
├── main.tf                              # Terraform: 3 servers, 3 clients, influxdb-vm
├── cloud-init-bootstrap.yaml.tmpl       # VM bootstrap (SSH + Python)
├── Makefile                             # provision, destroy, load-test targets
├── bin/
│   └── nomad-autoscaler                 # Linux ARM64 binary with InfluxDB plugin
├── ansible/
│   ├── playbooks/
│   │   ├── site.yml                     # Main playbook (all roles)
│   │   └── autoscaler-only.yml          # Update autoscaler only
│   ├── roles/
│   │   ├── base/                        # DNS, hostname, /etc/hosts
│   │   ├── consul/                      # Consul server/client agent
│   │   ├── nomad_server/                # Nomad server + systemd
│   │   ├── nomad_client/                # Nomad client + Docker agent + pre-pull images
│   │   ├── influxdb/                    # InfluxDB 1.8 Docker container
│   │   ├── telegraf/                    # Telegraf Docker agent
│   │   └── nomad_autoscaler/            # Install autoscaler binary + systemd service
│   ├── inventory/
│   │   ├── generate_inventory.py        # Generate hosts.yml from Terraform
│   │   └── hosts.yml                    # Ansible inventory (auto-generated)
│   └── group_vars/
│       └── all.yml                      # Global variables (VMs, IPs, credentials)
├── jobs/
│   ├── webapp-autoscale.nomad.hcl       # App with autoscaling policy (30% CPU threshold)
│   ├── load-balancer.nomad.hcl          # HAProxy with Consul service discovery
│   └── autoscaler.nomad.hcl             # (Deprecated - autoscaler runs as systemd now)
├── CONSUL_SETUP.md                      # Detailed Consul configuration notes
├── question.md                          # Problem statement and architecture analysis
└── README.md                            # This file
```

---

## Key Enhancements Made

✅ **Pre-pulled Docker Images**: No more pull timeouts during scaling  
✅ **Optimized CPU Threshold**: Lowered from 50% to 30% for responsive scaling  
✅ **Fixed Database Routing**: Autoscaler queries `telegraf` database (where Telegraf writes)  
✅ **Systemd Autoscaler**: No Nomad job wrapper, direct systemd service  
✅ **HAProxy Service Discovery**: Automatic backend registration via Consul  
✅ **Comprehensive Monitoring**: InfluxDB metrics from all nodes, query examples included  

## References

- [Nomad Autoscaler Docs](https://www.nomadproject.io/docs/autoscaling)
- [InfluxDB 1.8 Docs](https://docs.influxdata.com/influxdb/v1.8/)
- [Telegraf Documentation](https://docs.influxdata.com/telegraf/)
- [Consul Service Discovery](https://www.consul.io/docs/discovery)
