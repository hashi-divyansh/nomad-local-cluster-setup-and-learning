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
        cooldown            = "10s"

        # scale case
        check "scheduled-job-scale-to-two" {
          # source = "prometheus"
          # query  = "vector(1)"

          schedule {
            start    = "30 10 * * *"
            duration = "1m"
          }

          strategy "fixed-value" {
            value = 2
          }
        }

       # descale case
        check "scheduled-job-descale-to-one" {
          # source = "prometheus"
          # query  = "vector(1)"

          schedule {
            start    = "40 10 * * *"
            duration = "1m"
          }

          strategy "fixed-value" {
            value = 1
          }
        }

        # again scale
        check "scheduled-job-scale-three" {
          # source = "prometheus"
          # query  = "vector(1)"

          schedule {
            start    = "36 10 * * *"
            duration = "1m"
          }

          strategy "fixed-value" {
            value = 5
          }
        }

        # Always active
        check "scheduled-job-always-active" {
          # source = "prometheus"
          # query  = "vector(1)"

          strategy "fixed-value" {
            value = 0
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
