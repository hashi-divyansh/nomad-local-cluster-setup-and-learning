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
          # Monitor peak CPU usage over 1-minute window
          # Scales when CPU allocation exceeds target threshold
          query  = "max_over_time(nomad_client_allocs_cpu_total_percent{task='web'}[1m])"

          strategy "target-value" {
            target = 50  # Scale when CPU exceeds 50% of 500 MHz allocation
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