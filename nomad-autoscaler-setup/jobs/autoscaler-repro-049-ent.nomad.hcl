job "autoscaler-repro-049-ent" {
  datacenters = ["dc1"]
  type        = "service"

  group "autoscaler" {
    count = 1

    # Reproduce panic behavior quickly and move to dead state after retries.
    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    task "autoscaler" {
      driver = "docker"

      config {
        image   = "hashicorp/nomad-autoscaler-enterprise:0.4.9-ent"
        command = "nomad-autoscaler"
        args = [
          "agent",
          "-config",
          "${NOMAD_TASK_DIR}/autoscaler.hcl",
          "-enable-debug"
        ]
      }

      template {
        destination = "${NOMAD_TASK_DIR}/autoscaler.hcl"
        data = <<-EOF
          plugin_dir = "/plugins"

          nomad {
            address = "http://server-vm-0.orb.local:4646"
          }

          apm "nomad" {
            driver = "nomad-apm"
            config = {
              address = "http://server-vm-0.orb.local:4646"
            }
          }

          apm "prometheus" {
            driver = "prometheus"
            config = {
              address = "http://prometheus-vm.orb.local:9090"
            }
          }

          dynamic_application_sizing {
            evaluate_after = "30s"
          }

          strategy "target-value" {
            driver = "target-value"
          }

          policy_eval {
            ack_timeout    = "5m"
            delivery_limit = 4
            workers = {
              cluster      = 10
              horizontal   = 10
              vertical_mem = 10
              vertical_cpu = 10
            }
          }
        EOF
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
