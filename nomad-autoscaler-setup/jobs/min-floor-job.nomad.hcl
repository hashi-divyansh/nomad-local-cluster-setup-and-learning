job "min-floor-job" {
  datacenters = ["dc1"]
  type        = "service"

  group "min-floor-job" {
    count = 2

    network {
      port "http" {
        to = 5678
      }
    }

    task "app" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo:0.2.3"
        args  = ["-text=min-floor-test"]
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    scaling {
      enabled = true
      min     = 2
      max     = 10

      policy {
        evaluation_interval = "15s"
        cooldown            = "30s"

        # FLOOR TEST A: fixed-value=0 always active → must floor at min=2
        check "always-wants-zero" {
          source = "prometheus"
          query  = "vector(1)"
          strategy "fixed-value" {
            value = "0"
          }
        }

        # BOOTSTRAP: scale to 6 first at 05:42 UTC
        check "bootstrap-scale-up" {
          source = "prometheus"
          query  = "vector(1)"
          schedule {
            start    = "42 05 * * *"
            duration = "1m"
          }
          strategy "fixed-value" {
            value = "6"
          }
        }

        # FLOOR TEST B: target-value trying to go below min
        # vector(10)/target=50 → factor=0.2 → 6→1→0 but must floor at min=2
        check "target-value-below-min" {
          source = "prometheus"
          query  = "vector(10)"
          schedule {
            start    = "43 05 * * *"
            duration = "10m"
          }
          strategy "target-value" {
            target = "50"
          }
        }

        target "nomad-target" {
          job   = "min-floor-job"
          group = "min-floor-job"
        }
      }
    }
  }
}
