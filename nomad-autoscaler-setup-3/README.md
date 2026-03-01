# Nomad Autoscaler Setup with OrbStack

Complete infrastructure setup for learning HashiCorp Nomad Autoscaler using OrbStack VMs, Terraform, minimal cloud-init bootstrap, and Ansible.

## Architecture

**Infrastructure Components:**
- **3 Nomad Servers** (`server-vm-0`, `server-vm-1`, `server-vm-2`) - Clustered with 3-node quorum
- **3 Nomad Clients** (`client-vm-0`, `client-vm-1`, `client-vm-2`) - Worker nodes with Docker enabled
- **1 Prometheus VM** (`prometheus-vm`) - Metrics collection for autoscaling decisions

**Technology Stack:**
- **OS**: Debian Bookworm (ARM64)
- **Provisioning**: Terraform + minimal cloud-init + Ansible
- **Orchestration**: Nomad 1.7.3
- **Monitoring**: Prometheus 2.50.1
- **Container Runtime**: Docker (on client nodes)

## Prerequisites

- macOS with OrbStack installed
- Terraform >= 1.0
- Python 3 on macOS host
- Ansible installed on macOS host
- SSH key pair available on host (default: `~/.ssh/id_ed25519`)
- Access to HashiCorp releases and GitHub

## Setup

### 1. Deploy Infrastructure with Terraform

```bash
cd nomad-autoscaler-setup-3
terraform init
terraform apply -auto-approve
```

If your public key is not `~/.ssh/id_ed25519.pub`:

```bash
terraform apply -auto-approve -var="ssh_public_key_path=~/.ssh/id_rsa.pub"
```

### 2. Generate Ansible Inventory

```bash
cd ansible
python3 inventory/generate_inventory.py
```

If needed, override SSH settings:

```bash
ANSIBLE_USER=root ANSIBLE_PRIVATE_KEY_FILE=~/.ssh/id_ed25519 python3 inventory/generate_inventory.py
```

### 3. Configure VMs with Ansible

```bash
cd ansible
ansible-playbook playbooks/site.yml
```

Optional one-command flow from repo root:

```bash
make provision
```

**Provisioning time:** ~5-8 minutes total (Terraform + Ansible)

### 4. Verify Cluster Health

Check Nomad servers formed quorum:
```bash
orb -m server-vm-0 nomad server members
```

Expected output:
```
Name              Address         Port  Status  Leader  Raft Version
server-vm-0.orb.  192.168.x.x     4648  alive   true    3
server-vm-1.orb.  192.168.x.x     4648  alive   false   3
server-vm-2.orb.  192.168.x.x     4648  alive   false   3
```

Check client nodes registered:
```bash
orb -m server-vm-0 nomad node status
```

### 5. Access UIs

**Nomad UI:**
- URL: http://localhost:4646/ui/jobs
- Direct (for curl/CLI): http://server-vm-0.orb.local:4646

**Prometheus UI:**
- URL: http://localhost:9090/graph
- Direct (for curl/CLI): http://prometheus-vm.orb.local:9090

> **Note:** Use `localhost` URLs in your browser. Chrome blocks `.local` domains due to security policies. The `.orb.local` URLs work for CLI tools like `curl` and `nomad` commands.

## DNS Configuration

OrbStack VMs use read-only `/etc/resolv.conf` symlinks. Ansible handles this by:
1. Deleting the symlink during role execution
2. Writing new resolv.conf with public DNS (1.1.1.1, 8.8.8.8)
3. Ensuring release downloads work during provisioning

## Nomad Configuration

### Server Config (`/etc/nomad.d/server.hcl`)
- Bootstrap: 3-node quorum
- Auto-join: DNS-based discovery via `.orb.local`
- UI: Enabled on port 4646
- Advertise: Auto-discovery using `{{ GetPrivateIP }}`

### Client Config (`/etc/nomad.d/client.hcl`)
- Driver: Docker enabled
- Server discovery: Retry join to all 3 servers
- Auto-register with server pool

## Prometheus Targets

Configured to scrape:
- **Nomad Servers**: `server-vm-{0,1,2}.orb.local:4646/v1/metrics`
- **Nomad Clients**: `client-vm-{0,1,2}.orb.local:4646/v1/metrics`
- **Prometheus**: `localhost:9090`

## Deployed Webapp

The webapp autoscaling job is now deployed and running. Access it via the dynamic port assigned by Nomad:

### Running Status

![Webapp Running Port](./webapp-running-port.png)

The webapp is currently accessible at **192.168.139.135:28915** with the following specs:
- **Image**: nginx:alpine
- **Initial Allocations**: 2
- **CPU per allocation**: 100 MHz
- **Memory per allocation**: 128 MB
- **Min instances**: 2
- **Max instances**: 10
- **Scaling target**: 70% CPU usage

### Verification

![Curl Webapp Response](./curl-to-webapp.png)

```bash
# Get current deployment port from allocation
nomad job allocs webapp

# Test accessibility
curl 192.168.139.135:28915
```

Expected response: Default nginx welcome page

### Scaling Configuration

The webapp job is configured with:
- **Cooldown**: 30 seconds between scaling actions
- **Evaluation Interval**: 10 seconds
- **Metrics Source**: Prometheus
- **Query**: `avg(nomad_client_allocs_cpu_total_percent{task='web'})`
- **Strategy**: Target-value at 70% CPU threshold

When CPU usage exceeds 70%, Nomad Autoscaler will automatically scale to a maximum of 10 instances. When demand drops, it scales back down to the minimum of 2 instances.

## Next Steps: Nomad Autoscaler

### 1. Generate Load & Test Autoscaling

Install the load testing tool and generate traffic:

```bash
# Install hey load tester
brew install hey

# Generate load for 5 minutes with 100 concurrent connections
hey -z 5m -c 100 -q 50 http://192.168.139.135:28915
```

### 2. Monitor Scaling in Real-time

**Watch instance count increase:**
```bash
# Watch webapp allocations
nomad job status webapp

# Or use the Nomad UI
# http://localhost:4646/ui/jobs/webapp@default
```

**Check autoscaler logs:**
```bash
# Get running autoscaler allocation ID
ALLOC_ID=$(nomad job allocs autoscaler | grep running | head -1 | awk '{print $1}')

# Follow logs
nomad alloc logs -f $ALLOC_ID
```

**Monitor CPU metrics in Prometheus:**
1. Open http://localhost:9090/graph
2. Query: `nomad_client_allocs_cpu_total_percent{task='web'}`
3. Watch CPU climb above 70% threshold

### 3. Scale-Down Testing

Once load generation stops, observe:
- Cooldown period (30s) before scale-down evaluation
- Gradual reduction back to 2 minimum instances
- Total time from peak to baseline

## Autoscaler Configuration Examples

The examples below show how to configure Nomad Autoscaler for different scenarios:

### Basic Scaling Policy

```hcl
job "webapp" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 2

    scaling {
      enabled = true
      min     = 2
      max     = 10

      policy {
        cooldown            = "30s"
        evaluation_interval = "10s"

        check "cpu_usage" {
          source = "prometheus"
          query  = "avg(nomad_client_allocs_cpu_total_percent{task='web'})"

          strategy "target-value" {
            target = 70
          }
        }
      }
    }

    task "web" {
      driver = "docker"
      config {
        image = "nginx:alpine"
        ports = ["http"]
      }
      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
```

### Autoscaler Job Configuration

Reference configuration for running Nomad Autoscaler as a job:

```hcl
job "autoscaler" {
  datacenters = ["dc1"]
  type        = "service"

  group "autoscaler" {
    count = 1

    task "autoscaler" {
      driver = "docker"

      config {
        image = "hashicorp/nomad-autoscaler:latest"
        args  = ["agent", "-config", "/local/autoscaler.hcl"]
      }

      template {
        data = <<EOH
nomad {
  address = "http://server-vm-0.orb.local:4646"
}

apm "prometheus" {
  driver = "prometheus"
  config = {
    address = "http://prometheus-vm.orb.local:9090"
  }
}

strategy "target-value" {
  driver = "target-value"
}
EOH
        destination = "local/autoscaler.hcl"
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}
```

## Load Testing 
```bash
# Install hey if you don't have it
brew install hey

# Generate load for 5 minutes
hey -z 5m -c 100 -q 50 http://192.168.139.135:24850
```

## Troubleshooting

### Terraform creates VMs but services are missing
```bash
# Re-generate inventory from latest Terraform outputs
cd ansible
python3 inventory/generate_inventory.py

# Run Ansible again
make ansible

# Validate SSH access from host
ANSIBLE_CONFIG=ansible/ansible.cfg ANSIBLE_ROLES_PATH=ansible/roles ansible -i ansible/inventory/hosts.yml all -m ping
```

### DNS issues inside VMs
```bash
# Check DNS is configured by Ansible
orb -m server-vm-0 cat /etc/resolv.conf

# Verify external connectivity
orb -m server-vm-0 ping -c 1 releases.hashicorp.com
```

### Nomad not running
```bash
# Check service status
orb -m server-vm-0 systemctl status nomad

# Check logs
orb -m server-vm-0 journalctl -u nomad -n 50

# Verify binary exists
orb -m server-vm-0 nomad -v
```

### No cluster leader
```bash
# Check server members
orb -m server-vm-0 nomad server members

# Check if servers can reach each other
orb -m server-vm-0 ping server-vm-1.orb.local
```

### Rebuild entire infrastructure
```bash
terraform destroy -auto-approve
terraform apply -auto-approve
```

## File Structure

```
nomad-autoscaler-setup-3/
├── main.tf                      # Terraform config
├── cloud-init-bootstrap.yaml.tmpl # Minimal SSH + Python bootstrap for all VMs
├── ansible/                     # VM configuration via Ansible
│   ├── inventory/
│   ├── playbooks/
│   ├── roles/
│   └── group_vars/
├── jobs/                        # Nomad job files (create for autoscaler)
└── README.md                    # This file
```

## Learning Resources

- [Nomad Autoscaler Guide](https://developer.hashicorp.com/nomad/tools/autoscaling)
- [Nomad Scaling Policies](https://developer.hashicorp.com/nomad/docs/job-specification/scaling)
- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)

## Clean Up

```bash
terraform destroy -auto-approve
```

This will remove all VMs and their data.
