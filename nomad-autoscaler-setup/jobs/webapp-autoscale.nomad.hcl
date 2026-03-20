# jobs/webapp-autoscale.nomad.hcl
job "webapp" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 1  # Start with 1 tasks

    scaling {
      enabled = true
      min     = 1
      max     = 10

      policy {
        cooldown            = "30s"
        evaluation_interval = "10s"

        check "avg_cpu_up" {
          source = "prometheus"
          query  = "avg(avg_over_time(nomad_client_allocs_cpu_total_percent{job=\"nomad-clients\", exported_job=\"webapp\"}[1m]))"
          query_instant = true
          group  = "avg_cpu"

          strategy "threshold" {
            lower_bound           = 0.1
            upper_bound           = 100
            delta                 = 1
            within_bounds_trigger = 1
          }
        }

        check "avg_cpu_down" {
          source = "prometheus"
          query  = "avg(avg_over_time(nomad_client_allocs_cpu_total_percent{job=\"nomad-clients\", exported_job=\"webapp\"}[1m]))"
          query_instant = true
          group  = "avg_cpu"

          strategy "threshold" {
            lower_bound           = 0
            upper_bound           = 0.05
            delta                 = -1
            within_bounds_trigger = 1
          }
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
        type        = "http"
        path        = "/"
        interval    = "10s"
        timeout     = "2s"
        method      = "GET"
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