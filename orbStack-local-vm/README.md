# OrbStack VM with Cloud-Init Configuration

This Terraform configuration creates multiple VMs using OrbStack and configures them using **cloud-init**, which runs scripts **inside** the VMs during their first boot.

## 📁 Files Structure

```
orbStack-local-vm/
├── main.tf                      # Terraform configuration
├── cloud-init-client.yaml       # Cloud-init for Nomad client VMs
├── cloud-init-server.yaml       # Cloud-init for Nomad server VMs
├── setup-client.sh             # (Legacy - kept for reference)
└── setup.server.sh             # (Legacy - kept for reference)
```

## 🚀 What is Cloud-Init?

Cloud-init is an industry-standard method for VM initialization. When you use cloud-init:

- **Scripts run INSIDE the VM** during first boot
- **No external dependencies** - doesn't require SSH or orb commands from host
- **Idempotent** - only runs once on first boot
- **Standard format** - works across different platforms (AWS, Azure, GCP, etc.)

## 📝 Cloud-Init Configuration Sections

### 1. **package_update & packages**
```yaml
package_update: true
packages:
  - wget
  - unzip
  - curl
```
- Updates package lists and installs required packages

### 2. **write_files**
```yaml
write_files:
  - path: /etc/nomad.d/client.hcl
    permissions: '0644'
    content: |
      # Your configuration here
```
- Creates configuration files before running commands
- Perfect for systemd services and application configs

### 3. **runcmd**
```yaml
runcmd:
  - mkdir -p /opt/nomad/data
  - wget https://releases.hashicorp.com/nomad/1.7.3/nomad_1.7.3_linux_arm64.zip
  - systemctl start nomad
```
- Runs commands in sequence
- Downloads and installs Nomad
- Starts services

## 🔧 How to Use

### 1. **Initialize Terraform**
```bash
terraform init
```

### 2. **Plan the deployment**
```bash
terraform plan
```

### 3. **Apply the configuration**
```bash
terraform apply
```

### 4. **Verify VMs are running**
```bash
orb list
```

### 5. **Check cloud-init logs inside VM**
```bash
orb -m client-vm-0 "sudo cat /var/log/cloud-init-output.log"
```

### 6. **Verify Nomad installation**
```bash
orb -m client-vm-0 "nomad version"
orb -m server-vm-0 "nomad server members"
```

## 📦 What Gets Installed

### On Client VMs:
- ✅ Nomad binary (1.7.3)
- ✅ Nomad client configuration
- ✅ Systemd service for auto-start
- ✅ Required dependencies (wget, unzip, curl)

### On Server VMs:
- ✅ Nomad binary (1.7.3)
- ✅ Nomad server configuration (3-node cluster)
- ✅ Systemd service for auto-start
- ✅ Required dependencies (wget, unzip, curl)

## 🎯 Customizing Cloud-Init

### To install a different tool (e.g., Consul):

Edit `cloud-init-client.yaml` or `cloud-init-server.yaml`:

```yaml
runcmd:
  # Add your custom commands
  - cd /tmp
  - wget https://releases.hashicorp.com/consul/1.17.0/consul_1.17.0_linux_arm64.zip
  - unzip consul_1.17.0_linux_arm64.zip
  - mv consul /usr/local/bin/
  - chmod +x /usr/local/bin/consul
  # ... additional setup
```

### To change the Nomad version:

Update the version in the `runcmd` section:

```yaml
runcmd:
  - wget -q https://releases.hashicorp.com/nomad/1.8.0/nomad_1.8.0_linux_arm64.zip
```

## 🆚 Comparison: Cloud-Init vs Local-Exec

| Feature | Cloud-Init (Current) | Local-Exec (Previous) |
|---------|---------------------|----------------------|
| **Runs** | Inside VM | From host machine |
| **Requires** | Cloud-init support | SSH/orb access |
| **Speed** | Parallel execution | Sequential |
| **Standard** | Industry standard | Terraform-specific |
| **Portable** | Works anywhere | Platform-dependent |
| **Idempotent** | Yes (first boot only) | Depends on script |

## 🐛 Troubleshooting

### Check if cloud-init ran successfully:
```bash
orb -m client-vm-0 "cloud-init status"
```

### View full cloud-init logs:
```bash
orb -m client-vm-0 "sudo cat /var/log/cloud-init-output.log"
```

### Check if Nomad is running:
```bash
orb -m client-vm-0 "sudo systemctl status nomad"
```

### Manually trigger cloud-init (for testing):
```bash
orb -m client-vm-0 "sudo cloud-init clean"
orb -m client-vm-0 "sudo cloud-init init"
```

## 📚 Additional Resources

- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Nomad Documentation](https://developer.hashicorp.com/nomad/docs)
- [OrbStack Provider](https://registry.terraform.io/providers/robertdebock/orbstack/latest/docs)

## 🎉 Benefits of This Approach

1. **Cleaner Terraform code** - No complex provisioners
2. **Faster deployment** - VMs configure themselves in parallel
3. **More reliable** - Standard Linux initialization system
4. **Easier to maintain** - Cloud-init configs are well-documented
5. **Portable** - Same configs work on any cloud provider
