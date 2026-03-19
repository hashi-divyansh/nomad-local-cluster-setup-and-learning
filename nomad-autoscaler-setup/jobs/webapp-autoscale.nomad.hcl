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

        check "cpu_usage" {
          source = "prometheus"
          # Monitor average Nomad client CPU utilization via Prometheus.
          query  = "avg(nomad_client_host_cpu_total_percent{job=\"nomad-clients\"})"

          strategy "target-value" {
            target = 30  # Scale when CPU exceeds 30% for faster scaling
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