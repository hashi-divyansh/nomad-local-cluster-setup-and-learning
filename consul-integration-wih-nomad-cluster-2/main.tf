terraform {
  required_providers {
    orbstack = {
      source  = "robertdebock/orbstack"
      version = ">= 3.1.0"
    }
  }
}

provider "orbstack" {}


# Create client VMs with Consul + Nomad
resource "orbstack_machine" "client_vm" {
  count = 3
  name  = "client-vm-${count.index}"
  image = "debian:bookworm" # Debian - lightweight and stable (~100-150MB vs 600MB Ubuntu)

  # Cloud-init configuration with Consul client + Nomad client
  cloud_init = file("${path.module}/cloud-init-consul-client.yaml")
}

# Create server VMs with Consul + Nomad
resource "orbstack_machine" "server_vm" {
  count = 3
  name  = "server-vm-${count.index}"
  image = "debian:bookworm" # Debian - lightweight and stable (~100-150MB vs 600MB Ubuntu)

  # Cloud-init configuration with Consul server + Nomad server
  cloud_init = file("${path.module}/cloud-init-consul-server.yaml")
}
