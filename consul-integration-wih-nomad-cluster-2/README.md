# Nomad + Consul Cluster Integration Guide

A comprehensive guide for setting up and using a Nomad cluster with Consul service discovery on OrbStack VMs.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Consul Setup](#consul-setup)
- [Deploying Jobs](#deploying-jobs)
- [Service Discovery](#service-discovery)
- [Accessing Services](#accessing-services)
- [Testing & Verification](#testing--verification)
- [Using Nomad Pack](#using-nomad-pack)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This setup provides:
- **3 Server VMs**: Running Nomad + Consul servers
- **3 Client VMs**: Running Nomad + Consul clients
- **Service Discovery**: Automatic service registration via Consul
- **Load Balancing**: DNS-based load balancing across healthy instances
- **Health Checking**: Automatic health monitoring and failover

### Key Benefits

✅ Single service name instead of tracking multiple IPs  
✅ Automatic load balancing via Consul DNS  
✅ Built-in health checking  
✅ Dynamic service discovery  
✅ Easy scaling up/down  

---

## 🏗️ Architecture

### Why Consul on Both Server AND Client VMs?

**Consul Servers** (server-vm-0, 1, 2):
- Store the master service catalog
- Provide DNS service (port 8600)
- Serve the Consul UI (port 8500)
- Handle leader election and consensus

**Consul Clients** (client-vm-0, 1, 2):
- Register services running locally (nginx, etc.)
- Perform health checks on local services
- Forward DNS/API requests to Consul servers
- Enable Nomad to auto-register services

```
┌────────────────────────────────────────────────┐
│          Consul Server Cluster                 │
│    (Stores service catalog, provides DNS)      │
└─────────────────┬──────────────────────────────┘
                  │ Gossip Protocol + RPC
┌─────────────────┴──────────────────────────────┐
│          Consul Clients                        │
│    (Register & monitor local services)         │
└────────────────────────────────────────────────┘
```

### Service Discovery Flow

```
Your App: curl http://nginx.service.consul:8080
    ↓
Consul DNS (port 8600)
    ↓
Returns all healthy instances:
    - 192.168.139.113:8080
    - 192.168.139.64:8080
    - 192.168.139.193:8080
```

---

## 🚀 Quick Start

### Prerequisites

- OrbStack installed on macOS
- Terraform installed
- Basic understanding of Nomad and Consul

### Deploy the Cluster

```bash
# Navigate to project directory
cd consul-integration-wih-nomad-cluster

# Initialize Terraform
terraform init

# Deploy all VMs
terraform apply -auto-approve

# Wait 2-3 minutes for cloud-init to complete
```

### Verify Installation

```bash
# Check Consul cluster
orb -m server-vm-0 "consul members"

# Expected: 6 members (3 servers + 3 clients, all alive)

# Check Nomad cluster
orb -m server-vm-0 "nomad server members"
orb -m server-vm-0 "nomad node status"
```

---

## 📦 Consul Setup

### Option A: Fresh Deployment

Use the provided cloud-init files:
- `cloud-init-consul-server.yaml` - For server VMs
- `cloud-init-consul-client.yaml` - For client VMs

Terraform will automatically configure everything.

### Option B: Add to Existing VMs

#### On Server VMs:

```bash
# SSH into each server VM
orb -m server-vm-0

# Install Consul
sudo mkdir -p /etc/consul.d /opt/consul/data
cd /tmp
wget -q https://releases.hashicorp.com/consul/1.17.0/consul_1.17.0_linux_arm64.zip
unzip consul_1.17.0_linux_arm64.zip
sudo mv consul /usr/local/bin/
sudo chmod +x /usr/local/bin/consul

# Create Consul server config
sudo tee /etc/consul.d/server.hcl > /dev/null <<'EOF'
datacenter = "dc1"
data_dir = "/opt/consul/data"
log_level = "INFO"

server = true
bootstrap_expect = 3

bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"

retry_join = ["server-vm-0.orb.local", "server-vm-1.orb.local", "server-vm-2.orb.local"]

ui_config {
  enabled = true
}

connect {
  enabled = true
}
EOF

# Create systemd service
sudo tee /etc/systemd/system/consul.service > /dev/null <<'EOF'
[Unit]
Description=Consul Server
Documentation=https://www.consul.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

# Start Consul
sudo systemctl daemon-reload
sudo systemctl enable consul
sudo systemctl start consul

# Update Nomad to use Consul
sudo tee -a /etc/nomad.d/server.hcl > /dev/null <<'EOF'

consul {
  address = "127.0.0.1:8500"
  auto_advertise = true
  server_auto_join = true
  client_auto_join = true
}
EOF

# Restart Nomad
sudo systemctl restart nomad
```

#### On Client VMs:

```bash
# SSH into each client VM
orb -m client-vm-0

# Install Consul
sudo mkdir -p /etc/consul.d /opt/consul/data
cd /tmp
wget -q https://releases.hashicorp.com/consul/1.17.0/consul_1.17.0_linux_arm64.zip
unzip consul_1.17.0_linux_arm64.zip
sudo mv consul /usr/local/bin/
sudo chmod +x /usr/local/bin/consul

# Create Consul client config
sudo tee /etc/consul.d/client.hcl > /dev/null <<'EOF'
datacenter = "dc1"
data_dir = "/opt/consul/data"
log_level = "INFO"

server = false

bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"

retry_join = ["server-vm-0.orb.local", "server-vm-1.orb.local", "server-vm-2.orb.local"]

connect {
  enabled = true
}

ports {
  grpc = 8502
}
EOF

# Create systemd service
sudo tee /etc/systemd/system/consul.service > /dev/null <<'EOF'
[Unit]
Description=Consul Client
Documentation=https://www.consul.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

# Start Consul
sudo systemctl daemon-reload
sudo systemctl enable consul
sudo systemctl start consul

# Update Nomad to use Consul
sudo tee -a /etc/nomad.d/client.hcl > /dev/null <<'EOF'

consul {
  address = "127.0.0.1:8500"
  auto_advertise = true
}
EOF

# Restart Nomad
sudo systemctl restart nomad
```

---

## 🎯 Deploying Jobs

### Using Standard Nomad Jobs

Your Nomad job file should include Consul service registration:

```hcl
job "nginx-demo" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 3

    network {
      port "http" {
        static = 8080
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:latest"
        ports = ["http"]
      }

      service {
        name     = "nginx-service"
        port     = "http"
        provider = "consul"  # ← Register with Consul
        
        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
```

Deploy the job:

```bash
# SSH into any server VM
orb -m server-vm-0

# Run the job
nomad job run /path/to/nginx.nomad.hcl

# Check status
nomad job status nginx-demo
```

### Using Nomad Pack

**Nomad Pack** is a templating and packaging tool that makes it easy to deploy pre-configured jobs.

#### Install Nomad Pack

```bash
# SSH into server VM
orb -m server-vm-0

# Download and install nomad-pack
cd /tmp
wget https://releases.hashicorp.com/nomad-pack/0.1.0/nomad-pack_0.1.0_linux_arm64.zip
unzip nomad-pack_0.1.0_linux_arm64.zip
sudo mv nomad-pack /usr/local/bin/
sudo chmod +x /usr/local/bin/nomad-pack

# Verify installation
nomad-pack version
```

#### Using Nomad Pack

```bash
# Initialize nomad-pack (downloads community registry)
nomad-pack registry add default github.com/hashicorp/nomad-pack-community-registry

# List available packs
nomad-pack registry list

# Deploy a pack (e.g., nginx)
nomad-pack run nginx --var="count=3" --var="datacenter=dc1"

# Check pack status
nomad-pack status nginx

# Stop a pack
nomad-pack stop nginx

# Destroy a pack
nomad-pack destroy nginx
```

#### Create Custom Packs

```bash
# Generate a new pack
nomad-pack generate my-app

# This creates a directory structure:
# my-app/
#   ├── metadata.hcl
#   ├── variables.hcl
#   ├── templates/
#   │   └── my-app.nomad.tpl
#   └── README.md

# Edit templates and deploy
nomad-pack run ./my-app
```

---

## 🔍 Service Discovery

### How It Works

1. **Service Registration**: When Nomad starts a task with `provider = "consul"`, it registers the service with the local Consul agent
2. **Health Checking**: Consul continuously monitors service health
3. **DNS Resolution**: Consul DNS resolves service names to healthy instance IPs
4. **Load Balancing**: DNS returns instances in round-robin fashion

### The `provider = "consul"` Setting

In your Nomad job file:

```hcl
service {
  name     = "nginx-service"
  port     = "http"
  provider = "consul"  # ← Required for Consul service discovery
  
  check {
    type     = "http"
    path     = "/"
    interval = "10s"
    timeout  = "2s"
  }
}
```

**Without `provider = "consul"`**: Service is registered in Nomad's native registry only  
**With `provider = "consul"`**: Service is registered in Consul for cluster-wide discovery

### Querying Services

#### Via Consul DNS (inside VMs):

```bash
# Get service IPs
dig @localhost -p 8600 nginx-service.service.consul

# Access via DNS name
curl http://nginx-service.service.consul:8080
```

#### Via Consul API:

```bash
# List all services
curl http://localhost:8500/v1/catalog/services | jq

# Get service details
curl http://localhost:8500/v1/catalog/service/nginx-service | jq

# Get only healthy instances
curl http://localhost:8500/v1/health/service/nginx-service?passing | jq
```

---

## 🌐 Accessing Services

### From Inside VMs

```bash
# Access via Consul DNS (works inside any VM)
curl http://nginx-service.service.consul:8080

# Access via Consul API
curl http://localhost:8500/v1/catalog/service/nginx-service
```

### From Your Mac Browser

The `.service.consul` domain only works inside VMs. You have several options:

#### Option 1: Direct IP Access (Easiest)

Access services directly using VM IPs:

```
http://192.168.139.113:8080  (client-vm-0)
http://192.168.139.64:8080   (client-vm-1)
http://192.168.139.193:8080  (client-vm-2)
```

#### Option 2: Configure macOS DNS Resolver

Make `.consul` domains work on your Mac:

```bash
# Create resolver directory
sudo mkdir -p /etc/resolver

# Add Consul DNS resolver (using server-vm-0 IP)
echo "nameserver 192.168.139.112
port 8600" | sudo tee /etc/resolver/consul

# Verify
cat /etc/resolver/consul

# Test DNS resolution
dig nginx-service.service.consul

# Now you can use in browser
open http://nginx-service.service.consul:8080
```

#### Option 3: Query Consul from Mac

```bash
# Get service IPs
dig @192.168.139.112 -p 8600 nginx-service.service.consul +short

# Or use Consul API
curl http://192.168.139.112:8500/v1/catalog/service/nginx-service | jq -r '.[].ServiceAddress'
```

### Accessing UIs

**Consul UI:**
```
http://192.168.139.112:8500/ui
```

**Nomad UI:**
```
http://192.168.139.112:4646/ui
```

---

## 🧪 Testing & Verification

### Quick Test Commands

Run these from your Mac terminal:

```bash
# 1. Check Consul cluster
orb -m server-vm-0 consul members

# 2. Check Consul services
orb -m server-vm-0 consul catalog services

# 3. Check nginx service details
orb -m server-vm-0 'curl -s http://localhost:8500/v1/health/service/nginx-service?passing | jq'

# 4. Test DNS resolution
orb -m server-vm-0 'dig @localhost -p 8600 nginx-service.service.consul +short'

# 5. Test nginx access via Consul DNS
orb -m server-vm-0 'curl -s http://nginx-service.service.consul:8080 | head -5'

# 6. Test direct access from your Mac
curl http://192.168.139.113:8080
curl http://192.168.139.64:8080
curl http://192.168.139.193:8080
```

### Test Load Balancing

```bash
# SSH into a VM
orb -m server-vm-0

# Run 10 requests to see load balancing
for i in {1..10}; do
  echo "Request $i:"
  curl -s http://nginx-service.service.consul:8080 | grep -i "welcome"
done
```

### Expected Results

**Consul Members:**
```
server-vm-0  192.168.139.112:8301  alive   server  1.17.0  2  dc1
server-vm-1  192.168.139.224:8301  alive   server  1.17.0  2  dc1
server-vm-2  192.168.139.20:8301   alive   server  1.17.0  2  dc1
client-vm-0  192.168.139.113:8301  alive   client  1.17.0  2  dc1
client-vm-1  192.168.139.64:8301   alive   client  1.17.0  2  dc1
client-vm-2  192.168.139.193:8301  alive   client  1.17.0  2  dc1
```

**Consul Services:**
```
consul
nginx-service
nomad
nomad-client
```

---

## 🔧 Troubleshooting

### Service Not Registering in Consul

1. **Check Nomad-Consul integration:**
   ```bash
   sudo cat /etc/nomad.d/server.hcl | grep -A 5 consul
   ```

2. **Verify Consul is running:**
   ```bash
   sudo systemctl status consul
   consul members
   ```

3. **Check job configuration:**
   ```bash
   nomad job status nginx-demo
   nomad alloc logs <allocation-id>
   ```

4. **Restart the job:**
   ```bash
   nomad job stop nginx-demo
   nomad job run /path/to/nginx.nomad.hcl
   ```

### DNS Resolution Not Working

1. **Inside VMs**: The `.service.consul` domain should work automatically
   ```bash
   orb -m server-vm-0 'dig @localhost -p 8600 nginx-service.service.consul'
   ```

2. **From Mac**: Configure `/etc/resolver/consul` as shown above

3. **Check Consul DNS:**
   ```bash
   orb -m server-vm-0 'sudo systemctl status consul'
   orb -m server-vm-0 'sudo netstat -tlnp | grep 8600'
   ```

### Service Not Accessible

1. **Check if containers are running:**
   ```bash
   orb -m client-vm-0 'sudo docker ps'
   ```

2. **Check port binding:**
   ```bash
   orb -m client-vm-0 'sudo netstat -tlnp | grep 8080'
   ```

3. **Test locally first:**
   ```bash
   orb -m client-vm-0 'curl localhost:8080'
   ```

4. **Check firewall:**
   ```bash
   orb -m client-vm-0 'sudo iptables -L -n | grep 8080'
   ```

### Consul Cluster Issues

1. **Check all members are alive:**
   ```bash
   orb -m server-vm-0 consul members
   ```

2. **Check leader:**
   ```bash
   orb -m server-vm-0 'curl -s http://localhost:8500/v1/status/leader'
   ```

3. **Check logs:**
   ```bash
   orb -m server-vm-0 'sudo journalctl -u consul -n 50'
   ```

4. **Restart Consul if needed:**
   ```bash
   orb -m server-vm-0 'sudo systemctl restart consul'
   ```

---

## 📚 Useful Commands

### Consul Commands

```bash
# List all services
consul catalog services

# Get service details
consul catalog service nginx-service

# Check service health
consul health service nginx-service

# Watch for service changes
consul watch -type=service -service=nginx-service

# Query DNS
dig @127.0.0.1 -p 8600 nginx-service.service.consul

# Get service addresses
consul catalog service nginx-service -detailed
```

### Nomad Commands

```bash
# List jobs
nomad job status

# Get job details
nomad job status nginx-demo

# View allocation logs
nomad alloc logs <allocation-id>

# Stop a job
nomad job stop nginx-demo

# Scale a job
nomad job scale nginx-demo <group-name>=5

# View node status
nomad node status
```

### Nomad Pack Commands

```bash
# List available packs
nomad-pack registry list

# Get pack info
nomad-pack info nginx

# Run a pack
nomad-pack run nginx

# Check pack status
nomad-pack status nginx

# Stop a pack
nomad-pack stop nginx

# Destroy a pack
nomad-pack destroy nginx
```

---

## 📊 Architecture Summary

```
┌─────────────────────────────────────────────────────┐
│                   Your Application                   │
│              http://nginx.service.consul:8080        │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              Consul DNS (Port 8600)                  │
│         Returns all healthy nginx instances          │
└──────────────────────┬──────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
    ┌────────┐    ┌────────┐    ┌────────┐
    │ Nginx  │    │ Nginx  │    │ Nginx  │
    │  VM-0  │    │  VM-1  │    │  VM-2  │
    │ :8080  │    │ :8080  │    │ :8080  │
    └────────┘    └────────┘    └────────┘
```

---

## 🎯 Quick Reference

| Action | Command |
|--------|---------|
| Access service via Consul | `curl http://nginx-service.service.consul:8080` |
| List all services | `consul catalog services` |
| Check service health | `consul health service nginx-service` |
| View Consul UI | `http://192.168.139.112:8500/ui` |
| View Nomad UI | `http://192.168.139.112:4646/ui` |
| Deploy Nomad job | `nomad job run job.nomad.hcl` |
| Deploy Nomad pack | `nomad-pack run nginx` |
| Get service IPs | `dig @localhost -p 8600 nginx-service.service.consul` |

---

## 🎓 Key Takeaways

1. **Consul must be on all VMs** - both servers and clients for service discovery to work
2. **Use `provider = "consul"`** in Nomad job files to enable Consul service discovery
3. **`.service.consul` domains** only work inside VMs (configure DNS resolver on Mac for browser access)
4. **Direct IP access** works from anywhere - use this for quick testing
5. **Nomad Pack** simplifies deployment with pre-configured templates
6. **Health checks** ensure only healthy instances receive traffic
7. **Round-robin DNS** provides automatic load balancing

---

## 🚀 Next Steps

1. ✅ Deploy the cluster using Terraform
2. ✅ Verify Consul cluster with `consul members`
3. ✅ Deploy a test job (nginx)
4. ✅ Verify service registration in Consul UI
5. ✅ Test service discovery via DNS
6. ✅ Configure macOS DNS resolver for browser access
7. ✅ Install Nomad Pack for easier deployments
8. ✅ Scale your services and watch Consul update automatically

---

## 📝 Additional Resources

- [Nomad Documentation](https://www.nomadproject.io/docs)
- [Consul Documentation](https://www.consul.io/docs)
- [Nomad Pack Documentation](https://github.com/hashicorp/nomad-pack)
- [OrbStack Documentation](https://docs.orbstack.dev/)

---

**Happy orchestrating! 🎉**
