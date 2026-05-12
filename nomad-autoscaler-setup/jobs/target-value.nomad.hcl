job "target-value-job" {
  datacenters = ["dc1"]
  type        = "service"

  group "target-value-job" {
    count = 0

    network {
      port "http" {
        to = 5678
      }
    }

    task "app" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo:0.2.3"
        args  = ["-text=target-value-test"]
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    scaling {
      enabled = true
      min     = 0
      max     = 10

      policy {
        evaluation_interval = "15s"
        cooldown            = "30s"

        check "peak-hours-cpu-scaling" {
          source = "prometheus"
          query  = "vector(75)"   # simulates 75% CPU load for testing
          schedule {
            start    = "53 17 * * *"   # ~5 min
            duration = "30m"
          }
          strategy "target-value" {
            target = "50"
          }
        }

        check "off-peak-floor" {
          source = "prometheus"
          query  = "vector(1)"
          strategy "fixed-value" {
            value = "1"
          }
        }

        target "nomad-target" {
          job   = "target-value-job"
          group = "target-value-job"
        }
      }
    }
  }
}
