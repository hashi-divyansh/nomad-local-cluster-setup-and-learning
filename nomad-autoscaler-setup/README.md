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
- Prometheus: http://localhost:9090/graph

## Test Autoscaling

**Deploy jobs:**
```bash
nomad job run jobs/autoscaler.nomad.hcl
nomad job run jobs/webapp-autoscale.nomad.hcl
```

**Generate load:**
```bash
# Find webapp port
nomad job allocs webapp

# Run load test
make load-test WEBAPP_URL=http://<client-ip>:<port>
```

**Monitor scaling:**
```bash
nomad job status webapp
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
