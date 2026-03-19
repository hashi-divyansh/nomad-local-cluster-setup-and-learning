terraform {
  required_providers {
    orbstack = {
      source  = "robertdebock/orbstack"
      version = ">= 3.1.0"
    }
  }
}

provider "orbstack" {}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
  description = "Path to the SSH public key that cloud-init adds to root authorized_keys"

  validation {
    condition     = fileexists(pathexpand(var.ssh_public_key_path))
    error_message = "The SSH public key file does not exist. Set ssh_public_key_path to a valid file path."
  }
}


# Create a machine that will be set as the default
resource "orbstack_machine" "client_vm" {
  count = 3
  name  = "client-vm-${count.index}"
  image = "debian:bookworm" # Debian - lightweight and stable (~100-150MB vs 600MB Ubuntu)

  cloud_init = templatefile("${path.module}/cloud-init-bootstrap.yaml.tmpl", {
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  })
}

# Create another machine (not default)
resource "orbstack_machine" "server_vm" {
  count = 3
  name  = "server-vm-${count.index}"
  image = "debian:bookworm" # Debian - lightweight and stable (~100-150MB vs 600MB Ubuntu)

  cloud_init = templatefile("${path.module}/cloud-init-bootstrap.yaml.tmpl", {
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  })
}

# Create Prometheus monitoring VM (for autoscaler APM)
resource "orbstack_machine" "prometheus_vm" {
  name  = "prometheus-vm"
  image = "debian:bookworm"

  cloud_init = templatefile("${path.module}/cloud-init-bootstrap.yaml.tmpl", {
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  })
}

# Output the client machines
output "client_machines" {
  value = orbstack_machine.client_vm[*].name
}

# Output server machines
output "server_machines" {
  value = orbstack_machine.server_vm[*].name
}

# Output Prometheus VM
output "prometheus_machine" {
  value = orbstack_machine.prometheus_vm.name
}

# Output access URLs
output "prometheus_url" {
  value       = "http://prometheus-vm.orb.local:9090"
  description = "Prometheus UI endpoint (after VM boots)"
}

output "nomad_ui_url" {
  value       = "http://server-vm-0.orb.local:4646"
  description = "Nomad Web UI (after servers boot)"
}

output "client_vm_connections" {
  value = [
    for vm in orbstack_machine.client_vm : {
      name     = vm.name
      ssh_host = vm.ssh_host
      ssh_port = vm.ssh_port
    }
  ]
  description = "Client VM SSH connection details for Ansible inventory generation"
}

output "server_vm_connections" {
  value = [
    for vm in orbstack_machine.server_vm : {
      name     = vm.name
      ssh_host = vm.ssh_host
      ssh_port = vm.ssh_port
    }
  ]
  description = "Server VM SSH connection details for Ansible inventory generation"
}

output "prometheus_vm_connection" {
  value = {
    name     = orbstack_machine.prometheus_vm.name
    ssh_host = orbstack_machine.prometheus_vm.ssh_host
    ssh_port = orbstack_machine.prometheus_vm.ssh_port
  }
  description = "Prometheus VM SSH connection details for Ansible inventory generation"
}

