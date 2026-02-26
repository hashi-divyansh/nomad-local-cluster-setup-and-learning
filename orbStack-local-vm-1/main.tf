terraform {
  required_providers {
    orbstack = {
      source  = "robertdebock/orbstack"
      version = ">= 3.1.0"
    }
  }
}

provider "orbstack" {}


# Create a machine that will be set as the default
resource "orbstack_machine" "client_vm" {
  count = 3
  name  = "client-vm-${count.index}"
  image = "debian:bookworm" # Debian - lightweight and stable (~100-150MB vs 600MB Ubuntu)

  # Cloud-init configuration - runs inside the VM during first boot
  cloud_init = file("${path.module}/cloud-init-client.yaml")
}

# Create another machine (not default)
resource "orbstack_machine" "server_vm" {
  count = 3
  name  = "server-vm-${count.index}"
  image = "debian:bookworm" # Debian - lightweight and stable (~100-150MB vs 600MB Ubuntu)

  # Cloud-init configuration - runs inside the VM during first boot
  cloud_init = file("${path.module}/cloud-init-server.yaml")
}

# Output the default machine name
output "default_machine_name" {
  value = orbstack_machine.client_vm[*].name
}

# Output whether the default machine is set
output "is_default_machine" {
  value = orbstack_machine.server_vm[*].name
}

