# jobs/webapp-autoscale.nomad.hcl
job "webapp" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 1

    scaling {
      enabled = true
      min     = 1
      max     = 10

      policy {
        evaluation_interval = "15s"
        cooldown            = "30s"

        # Always-on CPU autoscaling outside schedule window.
        check "cpu_up" {
          source        = "prometheus"
          query         = "100 * avg(avg_over_time(nomad_client_allocs_cpu_total_percent{exported_job='webapp',task='web'}[1m]))"
          query_instant = true

          strategy "threshold" {
            upper_bound           = 70
            delta                 = 1
            within_bounds_trigger = "noop"
          }
        }

        check "cpu_down" {
          source        = "prometheus"
          query         = "100 * avg(avg_over_time(nomad_client_allocs_cpu_total_percent{exported_job='webapp',task='web'}[1m]))"
          query_instant = true

          strategy "threshold" {
            lower_bound           = 20
            delta                 = -1
            within_bounds_trigger = "noop"
          }
        }

        # Active only during schedule window (UTC)
        check "scheduled-fixed-scale" {
          source = "prometheus"
          query  = "vector(1)"

          schedule {
            start    = "37 10 * * *"
            duration = "1m"
          }

          strategy "fixed-value" {
            value = 2
          }
        }

        target "nomad-target" {
          job   = "webapp"
          group = "web"
        }
      }
    }

    network {
      port "http" {
        to = 80
      }
    }

    service {
      name     = "webapp"
      port     = "http"
      provider = "consul"

      tags = [
        "load-balancer",
        "http",
        "web"
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
        method   = "GET"
      }

      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "web" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        ports = ["http"]
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}