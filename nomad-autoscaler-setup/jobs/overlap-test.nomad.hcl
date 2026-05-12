job "overlap-test-job" {
  datacenters = ["dc1"]
  type        = "service"

  group "overlap-test-job" {
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
        args  = ["-text=overlap-test"]
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

        # Window A: fixed-value=3, active 18:17 for 10 min
        # Expected: if this wins → count = 3
        check "fixed-value-window" {
          source = "prometheus"
          query  = "vector(1)"
          schedule {
            start    = "17 18 * * *"
            duration = "10m"
          }
          strategy "fixed-value" {
            value = "3"
          }
        }

        # Window B: target-value with vector(75)/target=50 → desires ~1.5x current
        # Active 18:17 for 10 min — overlaps entirely with Window A
        # Expected: if this wins → count grows beyond 3
        check "target-value-window" {
          source = "prometheus"
          query  = "vector(75)"
          schedule {
            start    = "17 18 * * *"
            duration = "10m"
          }
          strategy "target-value" {
            target = "50"
          }
        }

        # Baseline: keeps job at 1 outside both windows
        check "off-peak-floor" {
          source = "prometheus"
          query  = "vector(1)"
          strategy "fixed-value" {
            value = "1"
          }
        }

        target "nomad-target" {
          job   = "overlap-test-job"
          group = "overlap-test-job"
        }
      }
    }
  }
}
