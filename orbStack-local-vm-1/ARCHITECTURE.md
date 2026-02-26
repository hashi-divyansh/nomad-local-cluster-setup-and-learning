# Nomad Architecture Explanation

## 🏗️ Cluster Setup

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

## 🛠️ Important Commands

> **Note:** These commands should be executed from one of the Nomad servers (e.g., `server-vm-0`, `server-vm-1`, or `server-vm-2`)

### Check Job Status
```bash
nomad job status
```
**Use case:** Lists all running jobs in the cluster

### Check Detailed Job Status
```bash
nomad job status -verbose example
```
**Use case:** Shows detailed information about a specific job named "example", including allocations, task groups, and deployment status

### Check Server Members
```bash
nomad server members
```
**Use case:** Lists all Nomad servers in the cluster and shows which one is the leader

### Check Client Node Status
```bash
nomad node status
```
**Use case:** Shows the status of all client nodes (workers) in the cluster, including their readiness and resource availability

