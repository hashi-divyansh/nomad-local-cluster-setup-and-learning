# OrbStack VM with Cloud-Init Configuration

This Terraform configuration creates multiple VMs using OrbStack and configures them using **cloud-init**, which runs scripts **inside** the VMs during their first boot.

## 📋 Prerequisites

Before you begin, ensure you have the following installed on your system:

### Install OrbStack
```bash
brew install orbstack
```

### Install Terraform
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

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
