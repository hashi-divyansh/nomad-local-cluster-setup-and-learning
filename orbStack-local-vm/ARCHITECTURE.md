# Nomad Architecture Explanation

## 🏗️ Your Cluster Setup

### VMs Created by Terraform:

```
SERVERS (Control Plane):          CLIENTS (Workers):
┌─────────────┐                   ┌─────────────┐
│ server-vm-0 │ ◄──┐             │ client-vm-0 │
└─────────────┘    │             └─────────────┘
                   │                     │
┌─────────────┐    │                     │
│ server-vm-1 │ ◄──┼─────────────────────┤
└─────────────┘    │                     │
                   │                     │
┌─────────────┐    │                     │
│ server-vm-2 │ ◄──┴─────────────────────┘
└─────────────┘         Clients connect
                        to servers
```

## 📝 Configuration Breakdown

### In `cloud-init-client.yaml` (Nomad Client Config):

```yaml
client {
  enabled = true
  servers = ["server-vm-0:4647", "server-vm-1:4647", "server-vm-2:4647"]
  #          ↑ This tells clients WHERE to find the servers
}
```

**Why `server-vm-0`, not `client-vm-0`?**
- Clients need to **connect to servers**, not to themselves
- Servers handle scheduling and cluster coordination
- Clients register themselves with servers and wait for work

### In `cloud-init-server.yaml` (Nomad Server Config):

```yaml
server {
  enabled = true
  bootstrap_expect = 3  # Expect 3 servers to form a cluster
  
  server_join {
    retry_join = ["server-vm-0", "server-vm-1", "server-vm-2"]
    #             ↑ Servers connect to EACH OTHER to form consensus
  }
}
```

**Why do servers list themselves?**
- Servers need to find **each other** to form a cluster
- They use Raft consensus protocol to elect a leader
- Each server tries to connect to the others

## 🎯 What Each VM Does

### Server VMs (`server-vm-0`, `server-vm-1`, `server-vm-2`):
- ✅ Store cluster state
- ✅ Schedule jobs
- ✅ Elect a leader
- ✅ Handle API requests
- ✅ Coordinate the cluster
- ❌ Do NOT run workloads

### Client VMs (`client-vm-0`, `client-vm-1`, `client-vm-2`):
- ✅ Run jobs/tasks/containers
- ✅ Report status to servers
- ✅ Execute workloads
- ❌ Do NOT make scheduling decisions

## 🔍 How to Verify the Names

### 1. List all VMs:
```bash
orb list
```
**Expected output:**
```
client-vm-0
client-vm-1
client-vm-2
server-vm-0
server-vm-1
server-vm-2
```

### 2. Check server cluster:
```bash
orb -m server-vm-0 "nomad server members"
```
**Shows:**
- server-vm-0 (Leader: true/false)
- server-vm-1 (Leader: true/false)
- server-vm-2 (Leader: true/false)

### 3. Check connected clients:
```bash
orb -m server-vm-0 "nomad node status"
```
**Shows:**
- client-vm-0 (Status: ready)
- client-vm-1 (Status: ready)
- client-vm-2 (Status: ready)

### 4. From a client, check which servers it's connected to:
```bash
orb -m client-vm-0 "cat /etc/nomad.d/client.hcl"
```
**Shows:**
```hcl
servers = ["server-vm-0:4647", "server-vm-1:4647", "server-vm-2:4647"]
```

## 🤔 Common Confusion

**Q: Why don't clients have `client-vm-0` in their config?**
**A:** Because clients don't connect to other clients. They only connect to servers.

**Q: When do I see `client-vm-0` mentioned?**
**A:** 
1. In `terraform output` - VM names
2. In `orb list` - VM listing
3. In `nomad node status` - Client node names
4. In job allocations - Where jobs are running

**Q: Can I connect to a client VM?**
**A:** Yes! 
```bash
orb -m client-vm-0 "nomad version"
```

## 📊 Real Example

When you run a Nomad job:

```bash
# Submit job to server
orb -m server-vm-0 "nomad job run my-job.nomad"

# Server decides which CLIENT to run it on
# Let's say it picks client-vm-1

# Check where it's running
orb -m server-vm-0 "nomad job status my-job"
# Output shows: Running on client-vm-1
```

## ✅ Summary

Your configuration is **CORRECT**:
- ✅ Clients list **servers** in their config (correct!)
- ✅ Servers list **other servers** in their config (correct!)
- ✅ VM names: `client-vm-{0,1,2}` and `server-vm-{0,1,2}` (correct!)

The names `client-vm-0`, `client-vm-1`, `client-vm-2` are used:
1. As VM hostnames (set by Terraform)
2. In Nomad's node list (automatically registered)
3. When viewing job allocations
4. When connecting via `orb -m client-vm-0`

But they are **NOT** in the client config file because clients don't connect to other clients!
