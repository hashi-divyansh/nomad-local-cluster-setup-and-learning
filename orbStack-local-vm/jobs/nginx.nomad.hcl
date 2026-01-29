job "nginx-demo" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 3 # This will spread 3 instances across your client VMs

    network {
      port "http" {
        static = 8080
        to     = 80  # This tells Nomad: VM 8080 -> Container 80
      }
    }

    service {
      name     = "nginx-service"
      port     = "http"
      provider = "nomad"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "nginx-server" {
      driver = "docker"

      config {
        image = "nginx:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 200 # MHz
        memory = 128 # MB
      }
    }
  }
}