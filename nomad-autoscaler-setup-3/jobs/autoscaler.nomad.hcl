# jobs/autoscaler.nomad.hcl
job "autoscaler" {
  datacenters = ["dc1"]
  type        = "service"

  group "autoscaler" {
    count = 1

    task "autoscaler" {
      driver = "docker"

      config {
        image = "hashicorp/nomad-autoscaler:latest"
        args  = ["agent", "-config", "/local/autoscaler.hcl"]
      }

      template {
        data = <<EOH
nomad {
  address = "http://server-vm-0.orb.local:4646"
}

apm "prometheus" {
  driver = "prometheus"
  config = {
    address = "http://prometheus-vm.orb.local:9090"
  }
}

strategy "target-value" {
  driver = "target-value"
}
EOH

        destination = "local/autoscaler.hcl"
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}