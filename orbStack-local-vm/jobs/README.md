# Nomad Jobs

This directory contains Nomad job specifications for deploying applications to your local Nomad cluster.

## 📁 Available Jobs

| Job File | Description |
|----------|-------------|
| `nginx.nomad.hcl` | Deploys 3 nginx instances across client VMs |

---

## 🚀 How to Run a Nomad Job

> **💡 Tip:** Open the terminal of any Nomad server VM directly (via OrbStack UI or `orb -m server-vm-0`) and run the commands below directly without the `orb -m` prefix.

### Step 1: Verify Nomad Cluster is Running

First, ensure your Nomad server and clients are up:

```bash
# Check server status
nomad server members

# Check client nodes
nomad node status
```

### Step 2: Create the Job File

Create the nginx job file on the server:

```bash
# Create the job file
cat > /tmp/nginx.nomad.hcl << 'EOF'
job "nginx-demo" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 3

    network {
      port "http" {
        static = 8080
        to     = 80
      }
    }

    task "nginx-server" {
      driver = "docker"

      config {
        image = "nginx:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}
EOF
```

### Step 3: Run the Job

```bash
# Run the job
nomad job run /tmp/nginx.nomad.hcl
```

### Step 4: Verify Job Status

```bash
# Check job status
nomad job status nginx-demo

# Check allocations
nomad job allocs nginx-demo

# View running allocations with more details
nomad alloc status -short $(nomad job allocs -t '{{range .}}{{.ID}}{{end}}' nginx-demo | head -1)
```

---

## 🌐 Accessing Nginx from Browser

![Nginx Server](nginx_server.png)

### Option 1: Using Client VM IP Address (Recommended)

Get the IP address of your client VMs and access nginx directly:

```bash
# Get the IP of client VMs (run on any client VM terminal)
hostname -I
```

Then access nginx in your browser using the IP:

```
http://192.168.139.67:8080/
```

> **Note:** Replace `192.168.139.67` with your actual client VM IP address.

### Option 2: Using Client VM's OrbStack Hostname

OrbStack automatically creates `.orb.local` hostnames for each VM. Since nginx runs on port `8080`:

```bash
# Get client VM hostnames
orb list
```

Access nginx in your browser:

| Client VM | URL |
|-----------|-----|
| client-vm-0 | http://client-vm-0.orb.local:8080 |
| client-vm-1 | http://client-vm-1.orb.local:8080 |
| client-vm-2 | http://client-vm-2.orb.local:8080 |

> **Note:** Since the job has `count = 3` with a static port `8080`, Nomad will schedule one nginx instance per client VM.

### Option 3: Using curl from Terminal

```bash
# Test from host machine
curl http://client-vm-0.orb.local:8080

# Or test using IP address
curl http://192.168.139.67:8080/
```


