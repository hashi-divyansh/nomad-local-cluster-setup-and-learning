# jobs/nginx-scheduled-scale.nomad.hcl
job "nginx-scheduled-scale" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 1

    network {
      port "http" {
        to = 80
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    scaling {
      enabled = true
      min     = 1
      max     = 4

      policy {
        evaluation_interval = "15s"
        cooldown            = "30s"

        # UTC, strict 5-field cron
        # Active every even minute for 1 minute
        schedule {
          start    = "*/2 * * * *"
          duration = "1m"
        }

        check "scheduled-fixed-scale" {
          source = "prometheus"
          query  = "scalar(1)"

          strategy "fixed-value" {
            config {
              value = 2
            }
          }
        }

        target "nomad" {
          job   = "nginx-scheduled-scale"
          group = "web"
        }
      }
    }
  }
}