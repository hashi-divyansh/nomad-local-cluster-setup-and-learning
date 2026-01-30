# Consul Service Discovery Solution

## 🎯 The Problem

When you deploy nginx on 3 different VMs, each has a different IP address:
- client-vm-0: `192.168.139.67:8080`
- client-vm-1: `192.168.139.68:8080`
- client-vm-2: `192.168.139.69:8080`

**Problems:**
- ❌ You need to remember all 3 IP addresses
- ❌ If a VM restarts, the IP might change
- ❌ No automatic load balancing between instances
- ❌ Hard to add or remove instances dynamically

## ✅ The Solution: Consul

**Consul** provides:
- ✅ **Service Discovery**: Access all nginx instances via a single name: `nginx.service.consul`
- ✅ **Health Checking**: Automatically removes unhealthy instances
- ✅ **DNS-based Load Balancing**: Automatically distributes traffic across healthy instances
- ✅ **Dynamic Updates**: Automatically detects when instances are added or removed

---

## 🚀 How It Works

```
Your Browser/App
       ↓
http://nginx.service.consul:8080
       ↓
   Consul DNS (resolves to healthy instances)
       ↓
Round-robin between:
  → 192.168.139.67:8080 ✓
  → 192.168.139.68:8080 ✓
  → 192.168.139.69:8080 ✓
```

---

## 📦 Setup Instructions

### Step 1: Deploy VMs with Consul

You have two options:

#### Option A: Fresh Deployment

If starting fresh, update your `main.tf` to use the new cloud-init files:

```hcl
# For server VMs
user_data = file("${path.module}/cloud-init-consul-server.yaml")

# For client VMs
user_data = file("${path.module}/cloud-init-consul-client.yaml")
```

Then:
```bash
terraform destroy -auto-approve
terraform apply -auto-approve
```

#### Option B: Add Consul to Existing VMs

Install Consul on existing VMs by running these commands on each VM.

**On Server VMs (server-vm-0, server-vm-1, server-vm-2):**

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

# Create Consul config
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

# Update Nomad config to integrate with Consul
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

**On Client VMs (client-vm-0, client-vm-1, client-vm-2):**

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

# Create Consul config
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

# Update Nomad config to integrate with Consul
sudo tee -a /etc/nomad.d/client.hcl > /dev/null <<'EOF'

consul {
  address = "127.0.0.1:8500"
  auto_advertise = true
}
EOF

# Restart Nomad
sudo systemctl restart nomad
```

### Step 2: Verify Consul Cluster

```bash
# Check Consul members (run on any server VM)
consul members

# Expected output:
# Node         Address           Status  Type    Build   Protocol  DC   Partition  Segment
# server-vm-0  192.168.139.x:... alive   server  1.17.0  2         dc1  default    <all>
# server-vm-1  192.168.139.x:... alive   server  1.17.0  2         dc1  default    <all>
# server-vm-2  192.168.139.x:... alive   server  1.17.0  2         dc1  default    <all>
# client-vm-0  192.168.139.x:... alive   client  1.17.0  2         dc1  default    <default>
# client-vm-1  192.168.139.x:... alive   client  1.17.0  2         dc1  default    <default>
# client-vm-2  192.168.139.x:... alive   client  1.17.0  2         dc1  default    <default>
```

### Step 3: Deploy Nginx with Consul Integration

```bash
# Stop the old nginx job
nomad job stop nginx-demo

# Deploy the new Consul-integrated nginx job
nomad job run /tmp/nginx-consul.nomad.hcl
```

### Step 4: Verify Service Registration

```bash
# Check registered services in Consul
consul catalog services

# Get details about nginx service
consul catalog service nginx

# Expected output shows all 3 instances with their addresses
```

---

## 🌐 Accessing Nginx via Consul

### Method 1: Using Consul DNS (Recommended)

Once Consul is running, you can access nginx using DNS:

```bash
# From any VM in the cluster
curl http://nginx.service.consul:8080

# This will automatically load balance between all healthy instances
```

### Method 2: Query Consul API

```bash
# Get all nginx service instances
curl http://localhost:8500/v1/catalog/service/nginx | jq

# Get healthy instances only
curl http://localhost:8500/v1/health/service/nginx?passing | jq
```

### Method 3: Using Consul DNS from Your Host Machine

Configure your host machine to use Consul DNS:

```bash
# On your Mac, you can query Consul DNS via a server VM
dig @server-vm-0.orb.local -p 8600 nginx.service.consul

# Or use curl with any instance
curl http://$(dig @server-vm-0.orb.local -p 8600 nginx.service.consul +short | head -1):8080
```

---

## 🎨 Consul Web UI

Access the Consul UI to see all registered services:

```
http://server-vm-0.orb.local:8500
```

From the UI you can:
- ✅ View all registered services
- ✅ See health status of each instance
- ✅ Monitor service checks
- ✅ View the service topology

---

## 🔄 Benefits You Get

### 1. **Single Point of Access**
Instead of:
```bash
curl http://192.168.139.67:8080
curl http://192.168.139.68:8080
curl http://192.168.139.69:8080
```

You use:
```bash
curl http://nginx.service.consul:8080
```

### 2. **Automatic Load Balancing**
Consul DNS returns all healthy instances in round-robin fashion.

### 3. **Health Checking**
If one nginx instance fails, Consul automatically removes it from DNS responses.

### 4. **Service Discovery**
Applications can discover services dynamically without hardcoded IPs.

### 5. **Scale Up/Down Easily**
```bash
# Scale to 5 instances
nomad job run -var="count=5" nginx-consul.nomad.hcl

# Consul automatically includes new instances in DNS
```

---

## 🧪 Testing Load Balancing

Run this to see load balancing in action:

```bash
# Run 10 requests and see which instances respond
for i in {1..10}; do
  echo "Request $i:"
  curl -s http://nginx.service.consul:8080 | grep -o '<h1>.*</h1>'
done
```

---

## 📊 Architecture Diagram

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

## 🔍 Useful Consul Commands

```bash
# List all services
consul catalog services

# Get service details
consul catalog service nginx

# Check service health
consul health service nginx

# Watch for service changes
consul watch -type=service -service=nginx

# Query DNS
dig @127.0.0.1 -p 8600 nginx.service.consul

# Get service addresses
consul catalog service nginx -detailed
```

---

## ⚡ Quick Reference

| Action | Command |
|--------|---------|
| Access nginx via Consul | `curl http://nginx.service.consul:8080` |
| List all services | `consul catalog services` |
| Check nginx health | `consul health service nginx` |
| View Consul UI | `http://server-vm-0.orb.local:8500` |
| Get service IPs | `dig @localhost -p 8600 nginx.service.consul` |

---

## 🎯 Summary

**Before Consul:**
- ❌ Need to track 3 different IPs
- ❌ Manual load balancing
- ❌ No health checking
- ❌ Hard to scale

**After Consul:**
- ✅ Single service name: `nginx.service.consul`
- ✅ Automatic load balancing
- ✅ Health checking built-in
- ✅ Easy to scale up/down
- ✅ Dynamic service discovery
