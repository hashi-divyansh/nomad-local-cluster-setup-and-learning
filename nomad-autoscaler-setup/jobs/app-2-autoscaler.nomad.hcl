job "scheduled-job" {
  datacenters = ["dc1"]
  type        = "service"

  group "scheduled-job" {
    # Start from zero and let autoscaler drive count changes.
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
        args  = ["-text=scheduled-job"]
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

        # 14:28-14:29 UTC -> target count 1
        check "scheduled-job-scale-to-one" {
          source = "prometheus"
          query  = "vector(1)"

          schedule {
            start    = "28 14 * * *"
            duration = "1m"
          }

          strategy "fixed-value" {
            value = 1
          }
        }

        # 14:30-14:31 UTC -> target count 2
        check "scheduled-job-scale-to-two" {
          source = "prometheus"
          query  = "vector(1)"

          schedule {
            start    = "30 14 * * *"
            duration = "1m"
          }

          strategy "fixed-value" {
            value = 2
          }
        }

        # 14:32-14:33 UTC -> target count 1
        check "scheduled-job-scale-back-to-one" {
          source = "prometheus"
          query  = "vector(1)"

          schedule {
            start    = "32 14 * * *"
            duration = "1m"
          }

          strategy "fixed-value" {
            value = 1
          }
        }

        target "nomad-target" {
          job   = "scheduled-job"
          group = "scheduled-job"
        }
      }
    }
  }
}