# Consul + Nomad Integration Architecture

## 🏗️ Why Install Consul on Both Server AND Client VMs?

### Short Answer:
**Yes, you MUST install Consul on both server and client VMs for service discovery to work.**

---

## 📊 Architecture Explained

```
┌────────────────────────────────────────────────────────────┐
│                    Consul Server Cluster                    │
│         (server-vm-0, server-vm-1, server-vm-2)            │
├────────────────────────────────────────────────────────────┤
│  Role: Consul Servers                                       │
│  - Maintain service catalog (centralized database)          │
│  - Provide leader election & consensus                      │
│  - Serve Consul UI (port 8500)                             │
│  - Answer DNS queries (port 8600)                          │
│  - Store service health check results                       │
└───────────────┬────────────────────────────────────────────┘
                │
                │ Gossip Protocol (LAN) + RPC
                │
┌───────────────┴────────────────────────────────────────────┐
│                    Consul Clients                           │
│         (client-vm-0, client-vm-1, client-vm-2)            │
├────────────────────────────────────────────────────────────┤
│  Role: Consul Agents                                        │
│  - Register services running locally (nginx, etc.)          │
│  - Perform health checks on local services                  │
│  - Forward API/DNS requests to Consul servers              │
│  - Report service status to servers                        │
│  - Enable Nomad to auto-register services                  │
└────────────────────────────────────────────────────────────┘
```

---

## 🔍 Detailed Breakdown

### Consul Server VMs (server-vm-0, 1, 2)

**Configuration:** `server = true` in consul config

**Responsibilities:**
1. **Service Catalog**: Store the master list of all services
2. **Health Data**: Maintain health check results
3. **DNS Server**: Answer queries like `nginx.service.consul`
4. **API Server**: Provide REST API for service discovery
5. **UI Server**: Web interface at `http://server-vm-0.orb.local:8500`
6. **Raft Consensus**: 3 servers provide high availability

**Ports Used:**
- `8500` - HTTP API & UI
- `8600` - DNS
- `8301` - LAN Gossip
- `8300` - Server RPC

---

### Consul Client VMs (client-vm-0, 1, 2)

**Configuration:** `server = false` in consul config

**Responsibilities:**
1. **Service Registration**: When nginx starts on client-vm-0, the local Consul agent registers it
2. **Health Checking**: Continuously checks if nginx is healthy
3. **Status Reporting**: Reports health to Consul servers
4. **Query Forwarding**: Routes DNS/API requests to servers
5. **Nomad Integration**: Allows Nomad to register services automatically

**Ports Used:**
- `8500` - HTTP API (local queries)
- `8600` - DNS (local queries)
- `8301` - LAN Gossip
- `8502` - gRPC (for Consul Connect)

---

## 🎯 What Happens in Practice

### Scenario: Deploying Nginx on 3 Client VMs

#### Step 1: Nomad schedules nginx on client-vm-0
```
client-vm-0 (Nomad Client)
    ↓
Starts nginx container
    ↓
client-vm-0 (Consul Client) detects new service
    ↓
Registers "nginx" with Consul Server
```

#### Step 2: Consul tracks all instances
```
Consul Servers maintain:
┌─────────────────────────────────────┐
│ Service: nginx                      │
├─────────────────────────────────────┤
│ Instance 1: client-vm-0:8080 ✓     │
│ Instance 2: client-vm-1:8080 ✓     │
│ Instance 3: client-vm-2:8080 ✓     │
└─────────────────────────────────────┘
```

#### Step 3: DNS query resolution
```
Your App: curl http://nginx.service.consul:8080
    ↓
Consul DNS (on any VM)
    ↓
Returns all healthy instances:
    - 192.168.139.67:8080
    - 192.168.139.68:8080
    - 192.168.139.69:8080
    (round-robin)
```

---

## ❌ What If You Skip Consul Clients?

### Without Consul on Client VMs:

```
❌ Nomad starts nginx on client-vm-0
❌ No local Consul agent to register the service
❌ Consul servers don't know about nginx
❌ DNS query "nginx.service.consul" returns nothing
❌ Service discovery fails!
```

**Problem Flow:**
```
client-vm-0: Nginx running ✓
             Consul agent ✗
             ↓
Consul Servers: No service registered
                ↓
DNS Query: nginx.service.consul
           ↓
Result: NXDOMAIN (not found)
```

---

## ✅ With Consul on Client VMs:

```
✓ Nomad starts nginx on client-vm-0
✓ Local Consul agent registers nginx
✓ Health checks start automatically
✓ Consul servers update service catalog
✓ DNS queries work immediately
✓ Service discovery succeeds!
```

**Success Flow:**
```
client-vm-0: Nginx running ✓
             Consul agent ✓
             ↓
             Registers with Consul Servers
             ↓
Consul Servers: nginx service catalog updated
                ↓
DNS Query: nginx.service.consul
           ↓
Result: 192.168.139.67:8080 (healthy)
```

---

## 🔧 How Nomad Integrates with Consul

### In Nomad Job Spec:
```hcl
service {
  name     = "nginx"
  port     = "http"
  provider = "consul"  # ← Tells Nomad to use Consul
  
  check {
    type     = "http"
    path     = "/"
    interval = "10s"
  }
}
```

### Behind the Scenes:
1. Nomad allocates nginx to client-vm-0
2. Nomad contacts **local Consul agent** on client-vm-0
3. Consul agent registers the service
4. Consul agent starts health checks
5. Consul agent reports to Consul servers
6. Service becomes discoverable cluster-wide

---

## 📦 Installation Summary

### You Need Consul On:

| VM Type | Consul Role | Why? |
|---------|-------------|------|
| **server-vm-0,1,2** | Server | Store service catalog, provide DNS, serve UI |
| **client-vm-0,1,2** | Client | Register local services, perform health checks |

### Your Terraform Setup is Correct:

```terraform
# ✅ Consul Server + Nomad Server
resource "orbstack_machine" "server_vm" {
  count = 3
  cloud_init = file("cloud-init-consul-server.yaml")
}

# ✅ Consul Client + Nomad Client
resource "orbstack_machine" "client_vm" {
  count = 3
  cloud_init = file("cloud-init-consul-client.yaml")
}
```

---

## 🚀 Deployment Steps

```bash
# 1. Initialize Terraform
terraform init

# 2. Deploy all VMs with Consul + Nomad
terraform apply -auto-approve

# 3. Wait for VMs to boot and install (2-3 minutes)
# Watch logs: orb -m server-vm-0 "sudo tail -f /var/log/cloud-init-output.log"

# 4. Verify Consul cluster
orb -m server-vm-0 "consul members"

# Expected output:
# Node         Address           Status  Type    Build
# server-vm-0  192.168.x.x:8301  alive   server  1.17.0
# server-vm-1  192.168.x.x:8301  alive   server  1.17.0
# server-vm-2  192.168.x.x:8301  alive   server  1.17.0
# client-vm-0  192.168.x.x:8301  alive   client  1.17.0
# client-vm-1  192.168.x.x:8301  alive   client  1.17.0
# client-vm-2  192.168.x.x:8301  alive   client  1.17.0

# 5. Deploy nginx with Consul integration
orb -m server-vm-0 "nomad job run /tmp/nginx-consul.nomad.hcl"

# 6. Check service registration
orb -m server-vm-0 "consul catalog service nginx"

# 7. Test DNS resolution
orb -m server-vm-0 "dig @localhost -p 8600 nginx.service.consul"

# 8. Access nginx via service discovery
orb -m server-vm-0 "curl http://nginx.service.consul:8080"
```

---

## 🎓 Key Concepts

### Consul is a Distributed System

- **Consul Servers**: The "brain" - stores data, makes decisions
- **Consul Clients**: The "eyes and ears" - watch services, report status

### Both Work Together:

```
Consul Clients (on each VM)
    ↓ register services
    ↓ report health
    ↓
Consul Servers (3-node cluster)
    ↓ store catalog
    ↓ provide queries
    ↓
Your Application
    ↓ query DNS
    ↓ discover services
```

---

## 📊 Resource Usage

### Per VM:

| Component | Memory | CPU | Disk |
|-----------|--------|-----|------|
| Consul Server | ~100MB | Low | ~50MB |
| Consul Client | ~50MB | Low | ~30MB |
| Nomad Server | ~100MB | Low | ~50MB |
| Nomad Client | ~50MB | Low | ~30MB |

**Total per Server VM:** ~200MB RAM
**Total per Client VM:** ~100MB RAM (+ your apps)

---

## 🎯 Summary

**Q: Do I need Consul on both server and client VMs?**

**A: YES!**

- **Consul Servers** (on server VMs): Store and serve the service catalog
- **Consul Clients** (on client VMs): Register and monitor local services

**Without Consul clients, Nomad cannot register services, and service discovery won't work.**

Your current Terraform configuration is **perfect** - it installs Consul on all 6 VMs with the correct roles! 🎉
