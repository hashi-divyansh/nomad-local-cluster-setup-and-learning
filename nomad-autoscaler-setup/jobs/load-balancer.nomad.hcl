job "load-balancer" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 100

  group "haproxy" {
    count = 1

    network {
      port "http" {
        static = 8080
      }
      port "stats" {
        static = 1936
      }
    }

    service {
      name     = "load-balancer"
      port     = "http"
      provider = "consul"

      tags = [
        "http",
        "load-balancer"
      ]
    }

    task "haproxy" {
      driver = "docker"

      config {
        image = "haproxy:2.8-alpine"
        ports = ["http", "stats"]
        volumes = [
          "local/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg"
        ]
      }

      template {
        data = <<EOH
global
  log stdout local0
  log stdout local1 notice
  stats timeout 30s
  user root
  group root

defaults
  log     global
  mode    http
  option  httplog
  option  dontlognull
  timeout connect 5000
  timeout client  50000
  timeout server  50000

listen stats
  bind 0.0.0.0:1936
  stats enable
  stats uri /
  stats show-legends
  stats refresh 30s

frontend http_in
  bind 0.0.0.0:8080
  default_backend webapp_backend

backend webapp_backend
  balance roundrobin
  mode http
  option httpchk GET /
  {{ range service "webapp" }}
  server {{ .ID }} {{ .Address }}:{{ .Port }} check
  {{ end }}
EOH
        destination = "local/haproxy.cfg"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "delay"
      }
    }
  }
}
