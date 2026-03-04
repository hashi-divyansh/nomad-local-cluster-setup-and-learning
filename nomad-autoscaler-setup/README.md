# Nomad Autoscaler Setup with OrbStack

Learn HashiCorp Nomad Autoscaler using OrbStack VMs. Provisions 3 Nomad servers, 3 client nodes, and 1 Prometheus VM using Terraform + Ansible.

## Quick Start

**Prerequisites:** macOS with OrbStack, Terraform, Python 3, Ansible, SSH key pair

**Setup Cluster:**
```bash
make provision
```

This command runs Terraform to create VMs, generates Ansible inventory, and configures all nodes. Takes ~5-8 minutes.

**Verify Cluster:**
```bash
orb -m server-vm-0 nomad server members
orb -m server-vm-0 nomad node status
```

**Access UIs:**
- Nomad: http://localhost:4646/ui/jobs
- Consul: http://server-vm-0.orb.local:8500/ui (Service discovery & health checks)
- Prometheus: http://localhost:9090/graph
- HAProxy Load Balancer Stats: http://client-vm-1.orb.local:1936 (allocated dynamically to client nodes)

## Test Autoscaling

**Deploy jobs:**
```bash
nomad job run jobs/autoscaler.nomad.hcl
nomad job run jobs/webapp-autoscale.nomad.hcl
nomad job run jobs/load-balancer.nomad.hcl  # Load balancer with service discovery
```

**Generate load:**
```bash
# Access through load balancer (automatically discovers all webapp instances)
make load-test WEBAPP_URL=http://localhost:8080
```

**Monitor scaling and service discovery:**
```bash
nomad job status webapp
# Check registered services in Consul
curl http://server-vm-0.orb.local:8500/v1/catalog/service/webapp | jq .
```

**View HAProxy stats:**
```bash
# Access HAProxy stats UI (port 1936)
nomad alloc logs <load-balancer-allocation-id> haproxy
```

## Clean Up

```bash
make destroy
```

---

**Project file structure?**
```
nomad-autoscaler-setup-3/
├── main.tf                      # Terraform config
├── cloud-init-bootstrap.yaml.tmpl # Minimal SSH + Python bootstrap for all VMs
├── ansible/                     # VM configuration via Ansible
│   ├── inventory/               # Dynamic inventory generation
│   ├── playbooks/               # Ansible playbooks
│   ├── roles/                   # Ansible roles (base, nomad_server, nomad_client, prometheus)
│   └── group_vars/              # Variable definitions
├── jobs/                        # Nomad job files
└── README.md                    # Quick start guide
```

---

**For detailed information, troubleshooting, and architecture details, see [question.md](question.md)**
**For Consul service discovery setup, see [CONSUL_SETUP.md](CONSUL_SETUP.md)**