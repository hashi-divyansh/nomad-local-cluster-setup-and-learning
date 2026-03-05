# Questions and Answers

---

**4) Are the Ansible role files production-ready?**

**Answer:**
They are suitable for learning and development. Production deployments usually add checksums for downloads, validation steps, and more error handling.

---

**5) Why was there no Nomad cluster leader even though all servers were running?**

**Answer:**
The servers could not resolve each other because /etc/resolv.conf was changed to public DNS. Fix: add /etc/hosts entries via Ansible so server VM names resolve.

---

**6) Can I run multiple webapp instances on one client VM? How are ports assigned?**

**Answer:**
Yes. Nomad assigns dynamic host ports for each allocation. Service discovery is done via the Nomad CLI/API unless you add Consul.

---

**7) Do I need Consul or a load balancer to test autoscaling?**

**Answer:**
No. For testing autoscaling, dynamic ports are sufficient. Consul and a load balancer are optional for production-grade service discovery.

---

**8) Do I need to install nomad-autoscaler separately?**

**Answer:**
The autoscaler can be deployed either as a Nomad job or as a systemd service. The systemd service approach is recommended for production as it runs independently on Nomad servers and does not require a Nomad allocation.

---

**9) Will the autoscaler run on every client VM?**

**Answer:**
No. The autoscaler job has count = 1, so it runs a single instance on one client. Increase the count if you want multiple instances.

---

**10) What is the complete architecture of this setup?**

**Answer:**
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

---

**11) What are the manual setup steps if I don't want to use `make provision`?**

**Answer:**
```bash
# Step 1: Deploy Infrastructure with Terraform
cd nomad-autoscaler-setup-3
terraform init
terraform apply -auto-approve

# If your public key is not ~/.ssh/id_ed25519.pub:
terraform apply -auto-approve -var="ssh_public_key_path=~/.ssh/id_rsa.pub"

# Step 2: Generate Ansible Inventory
cd ansible
python3 inventory/generate_inventory.py

# Override SSH settings if needed:
ANSIBLE_USER=root ANSIBLE_PRIVATE_KEY_FILE=~/.ssh/id_ed25519 python3 inventory/generate_inventory.py

# Step 3: Configure VMs with Ansible
cd ansible
ansible-playbook playbooks/site.yml
```

**Provisioning time:** ~5-8 minutes total (Terraform + Ansible)

---

**12) How do I troubleshoot if services are missing after Terraform?**

**Answer:**
```bash
# Re-generate inventory from latest Terraform outputs
cd ansible
python3 inventory/generate_inventory.py

# Run Ansible again
make ansible

# Validate SSH access from host
ANSIBLE_CONFIG=ansible/ansible.cfg ANSIBLE_ROLES_PATH=ansible/roles ansible -i ansible/inventory/hosts.yml all -m ping
```

---

**13) How do I troubleshoot DNS issues inside VMs?**

**Answer:**
```bash
# Check DNS is configured by Ansible
orb -m server-vm-0 cat /etc/resolv.conf

# Verify external connectivity
orb -m server-vm-0 ping -c 1 releases.hashicorp.com
```

---

**14) How do I troubleshoot if Nomad is not running?**

**Answer:**
```bash
# Check service status
orb -m server-vm-0 systemctl status nomad

# Check logs
orb -m server-vm-0 journalctl -u nomad -n 50

# Verify binary exists
orb -m server-vm-0 nomad -v
```

---

**15) How do I check if servers can reach each other when there's no cluster leader?**

**Answer:**
```bash
# Check server members
orb -m server-vm-0 nomad server members

# Check if servers can reach each other
orb -m server-vm-0 ping server-vm-1.orb.local
```

---

**16) What should I do if a Nomad client fails to register with the cluster?**

**Answer:**
First, verify the client is running and can reach the server VMs:
```bash
# Check client status
orb -m client-vm-0 systemctl status nomad

# Check Nomad client logs
orb -m client-vm-0 journalctl -u nomad -n 50

# Verify connectivity to servers
orb -m client-vm-0 ping server-vm-0.orb.local
orb -m client-vm-0 curl -I http://server-vm-0.orb.local:4646/
```

If the client still doesn't register, restart the Nomad service:
```bash
orb -m client-vm-0 sudo systemctl restart nomad
```

---

**17) Why should I use localhost URLs instead of .orb.local URLs in my browser?**

**Answer:**
Chrome blocks `.local` domains due to security policies. Use `localhost` URLs (http://localhost:4646, http://localhost:9090) in your browser. The `.orb.local` URLs work for CLI tools like `curl` and `nomad` commands.

**UI Access:**
- **Nomad UI**: http://localhost:4646/ui/jobs (or http://server-vm-0.orb.local:4646 for CLI)
- **Prometheus UI**: http://localhost:9090/graph (or http://prometheus-vm.orb.local:9090 for CLI)

---

**18) What are the expected outputs when verifying cluster health?**

**Answer:**
**Check if Nomad servers have formed a quorum:**
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

**Check client nodes registered:**
```bash
orb -m server-vm-0 nomad node status
```

---

**19) How do I monitor autoscaler logs in real-time?**

**Answer:**
```bash
# Follow autoscaler logs
nomad alloc logs -f $(nomad job allocs autoscaler | grep running | head -1 | awk '{print $1}')

# Check current allocation count
nomad job status webapp
```

---

**20) Where can I find learning resources for Nomad Autoscaler?**

**Answer:**
- [Nomad Autoscaler Guide](https://developer.hashicorp.com/nomad/tools/autoscaling)
- [Nomad Scaling Policies](https://developer.hashicorp.com/nomad/docs/job-specification/scaling)
- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)

---

**21) How do I build an executable for Linux machines?**

**Answer:**
```bash
GOOS=linux GOARCH=amd64 go build -o ./bin/my-app-linux
```
---