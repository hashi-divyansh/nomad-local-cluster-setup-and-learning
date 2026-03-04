# Consul Service Discovery Integration

This setup adds HashiCorp Consul for service discovery to your Nomad autoscaler cluster. This enables automatic load balancing when the autoscaler scales your webapp instances.

## Components Added

### 1. **Consul Servers** (runs on nomad_servers)
- **Role:** Consul cluster management
- **Configuration:** [ansible/roles/consul/templates/server.hcl.j2](../../ansible/roles/consul/templates/server.hcl.j2)
- **Count:** 3 (same servers as Nomad servers)
- **Ports:**
  - 8500: HTTP API
  - 8501: HTTPS API
  - 8600: DNS
  - 8300: Server RPC
  - 8301: LAN Serf
  - 8302: WAN Serf

### 2. **Consul Clients** (runs on nomad_clients)
- **Role:** Service registration and health checking
- **Configuration:** [ansible/roles/consul/templates/client.hcl.j2](../../ansible/roles/consul/templates/client.hcl.j2)
- **Integration:** Works with Nomad to auto-register services

### 3. **Nomad Integration**
- **Server Config:** Added Consul block to [nomad_server/templates/server.hcl.j2](../../ansible/roles/nomad_server/templates/server.hcl.j2)
- **Client Config:** Added Consul block to [nomad_client/templates/client.hcl.j2](../../ansible/roles/nomad_client/templates/client.hcl.j2)
- **Auto-join:** Nomad and Consul automatically discover each other

### 4. **Service Registration**
The webapp job now includes:
- **Service Block:** Registers with Consul as "webapp"
- **Health Checks:**
  - HTTP health check on path "/"
  - TCP health check on the exposed port
  - Checks run every 10 seconds

### 5. **Load Balancer (HAProxy)**
Job: [jobs/load-balancer.nomad.hcl](load-balancer.nomad.hcl)

The load balancer:
- Discovers webapp services from Consul
- Uses round-robin load balancing
- Automatically scales with your webapp instances
- Listens on port 8080
- Stats UI available on port 1936

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Users                                │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────┐
        │   HAProxy Load Balancer  │ (port 8080)
        │  (Nomad Job)             │
        └──────────────┬───────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
    ┌────────┐  ┌────────┐  ┌────────┐
    │ Webapp │  │ Webapp │  │ Webapp │  (auto-scaled instances)
    │  v1    │  │  v2    │  │  v3    │
    └───┬────┘  └───┬────┘  └───┬────┘
        │           │           │
        └───────────┼───────────┘
                    │
                    ▼
        ┌──────────────────────────────────┐
        │  Consul Service Registry         │
        │  (Track all webapp instances)    │
        │  (Health checks every 10s)       │
        └──────────────────────────────────┘
        
        Nomad Autoscaler monitors CPU
        └─ Scales webapp instances up/down
        └─ Consul automatically discovers new instances
        └─ HAProxy immediately routes traffic to new instances
```

## Deployment

### Prerequisites
Your existing setup with Nomad and Prometheus is already running.

### Steps to Deploy

1. **Ensure Ansible inventory is current:**
   ```bash
   cd nomad-autoscaler-setup
   python3 ansible/inventory/generate_inventory.py
   ```

2. **Deploy Consul to all nodes:**
   ```bash
   make provision
   ```
   (This runs the updated playbooks that now include Consul role)

3. **Verify Consul cluster:**
   ```bash
   nomad node status
   nomad service list
   ```

4. **Deploy the webapp job with service discovery:**
   ```bash
   nomad job run jobs/webapp-autoscale.nomad.hcl
   ```

5. **Deploy the HAProxy load balancer:**
   ```bash
   nomad job run jobs/load-balancer.nomad.hcl
   ```

6. **Access the services:**
   - **HAProxy Stats UI:** http://localhost:1936 (via Nomad tunnel)
   - **Consul UI:** http://server-vm-0.orb.local:8500
   - **Nomad UI:** http://server-vm-0.orb.local:4646
   - **Load Balancer:** http://localhost:8080 (via Nomad tunnel)

## Verifying Service Discovery

### Check registered services in Consul:
```bash
curl http://server-vm-0.orb.local:8500/v1/catalog/service/webapp
```

### Check Nomad services:
```bash
nomad service list
nomad service info webapp
```

### Monitor registered instances when autoscaling:
```bash
watch -n 2 'curl -s http://server-vm-0.orb.local:8500/v1/catalog/service/webapp | jq length'
```

The count will increase/decrease as autoscaler scales your webapp.

## Scaling Behavior

1. **Autoscaler detects high CPU:**
   - Nomad spins up new webapp instances
   
2. **Nomad registers with Consul:**
   - Each new instance is automatically registered
   - Health checks begin
   
3. **HAProxy discovers new services:**
   - Consul notifies HAProxy of new instances
   - HAProxy reloads configuration
   
4. **Traffic flows to all instances:**
   - Round-robin balancing across all healthy instances
   - Failed instances are automatically removed
   
5. **Autoscaler scales down:**
   - Instances are gracefully drained
   - HAProxy removes from rotation
   - Consul deregisters the service

## Configuration Files Modified

- `ansible/group_vars/all.yml` - Added Consul version and URLs
- `ansible/playbooks/site.yml` - Added Consul roles before Nomad
- `ansible/roles/nomad_server/templates/server.hcl.j2` - Added Consul integration
- `ansible/roles/nomad_client/templates/client.hcl.j2` - Added Consul integration
- `jobs/webapp-autoscale.nomad.hcl` - Added service registration block

## New Files Created

- `ansible/roles/consul/` - Complete Consul Ansible role
  - `defaults/main.yml` - Consul version variables
  - `handlers/main.yml` - Restart handlers
  - `tasks/main.yml` - Installation and configuration
  - `templates/server.hcl.j2` - Consul server configuration
  - `templates/client.hcl.j2` - Consul client configuration
- `jobs/load-balancer.nomad.hcl` - HAProxy load balancer job

## DNS Service Discovery (Optional)

Consul provides DNS on port 8600 on all nodes. Your services can be discovered with:
- `webapp.service.consul` - For direct service lookup
- `<instance-name>.webapp.service.consul` - For specific instance

Example from a Nomad task:
```bash
curl http://webapp.service.consul:8080
```

## Troubleshooting

### Consul not starting:
```bash
ssh root@server-vm-0.orb.local
journalctl -u consul -f
```

### Service not registering:
```bash
# Check Nomad logs
nomad logs <allocation-id> <task-name>

# Check Consul registration
curl http://server-vm-0.orb.local:8500/v1/catalog/service/webapp | jq .
```

### HAProxy not discovering services:
```bash
# Check HAProxy logs
nomad logs <haproxy-allocation-id> haproxy

# Verify Consul connection
consul catalog services -detailed
```

## Next Steps

1. **Secure Consul:** Enable TLS certificates
2. **Add more checks:** Add custom health checks per your app needs
3. **Enable ACLs:** Restrict service registration permissions
4. **Add monitoring:** Integrate Consul with Prometheus for full observability
5. **Production setup:** Use separate Consul cluster for HA/DR
