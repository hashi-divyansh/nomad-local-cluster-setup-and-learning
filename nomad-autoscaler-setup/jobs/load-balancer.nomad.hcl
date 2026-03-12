job "load-balancer" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 100

  group "haproxy" {
    count = 1

    network {
      port "default_http" {
        static = 8080
      }
      port "ns1_http" {
        static = 8081
      }
      port "ns2_http" {
        static = 8082
      }
      port "stats" {
        static = 1936
      }
    }

    service {
      name     = "load-balancer"
      port     = "default_http"
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
        ports = ["default_http", "ns1_http", "ns2_http", "stats"]
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

frontend default_http_in
  bind 0.0.0.0:8080
  default_backend webapp_default_backend

frontend ns1_http_in
  bind 0.0.0.0:8081
  default_backend webapp_ns1_backend

frontend ns2_http_in
  bind 0.0.0.0:8082
  default_backend webapp_ns2_backend

backend webapp_default_backend
  balance roundrobin
  mode http
  option httpchk GET /
  {{ range service "webapp" }}
  server {{ .ID }} {{ .Address }}:{{ .Port }} check
  {{ end }}

backend webapp_ns1_backend
  balance roundrobin
  mode http
  option httpchk GET /
  {{ range service "webapp-ns1" }}
  server {{ .ID }} {{ .Address }}:{{ .Port }} check
  {{ end }}

backend webapp_ns2_backend
  balance roundrobin
  mode http
  option httpchk GET /
  {{ range service "webapp-ns2" }}
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
