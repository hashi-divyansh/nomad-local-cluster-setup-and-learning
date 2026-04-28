job "nomad-autoscaler" {
  datacenters = ["dc1"]
  type        = "service"

  group "autoscaler" {
    count = 1

    restart {
      attempts = 2
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    task "autoscaler" {
      driver = "raw_exec"

      artifact {
        source      = "http://host.orb.internal:8888/bin/nomad-autoscaler"
        destination = "local/"
      }

      template {
        destination = "local/run.sh"
        perms       = "0755"
        data        = <<-EOF
          #!/bin/sh
          set -e
          chmod +x "${NOMAD_TASK_DIR}/local/nomad-autoscaler"
          exec "${NOMAD_TASK_DIR}/local/nomad-autoscaler" agent \
            -config "${NOMAD_TASK_DIR}/local/autoscaler.hcl"
        EOF
      }

      template {
        destination = "local/autoscaler.hcl"
        data        = <<-EOF
          nomad {
            address = "http://server-vm-0.orb.local:4646"
          }

          apm "${NOMAD_APM_DRIVER}" {
            driver = "${NOMAD_APM_DRIVER}"
            config = {
              address = "${NOMAD_APM_ADDRESS}"
            }
          }

          strategy "target-value" {
            driver = "target-value"
          }

          strategy "threshold" {
            driver = "threshold"
          }

          strategy "fixed-value" {
            driver = "fixed-value"
          }
        EOF
      }

      env {
        NOMAD_APM_DRIVER  = "prometheus"
        NOMAD_APM_ADDRESS = "http://prometheus-vm.orb.local:9090"
      }

      config {
        command = "${NOMAD_TASK_DIR}/local/run.sh"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
