# jobs/webapp-autoscale-ns2.nomad.hcl
job "webapp-ns2" {
  datacenters = ["dc1"]
  type        = "service"
  namespace   = "ns2"

  group "web" {
    count = 1

    scaling {
      enabled = true
      min     = 1
      max     = 10

      policy {
        cooldown            = "30s"
        evaluation_interval = "10s"

        check "cpu_usage" {
          source = "influxdb"
          query  = "SELECT mean(\"usage_system\") + mean(\"usage_user\") FROM \"cpu\" WHERE \"cpu\" = 'cpu-total' AND time > now() - 1m GROUP BY time(10s)"

          strategy "target-value" {
            target = 30
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
      name     = "webapp-ns2"
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
