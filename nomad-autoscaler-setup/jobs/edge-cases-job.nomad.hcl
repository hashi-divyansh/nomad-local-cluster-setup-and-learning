job "edge-cases-job" {
  datacenters = ["dc1"]
  type        = "service"

  group "edge-cases-job" {
    count = 0

    network {
      port "http" {
        to = 5678
      }
    }

    task "app" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo:0.2.3"
        args  = ["-text=edge-cases-test"]
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    scaling {
      enabled = true
      min     = 0
      max     = 10

      policy {
        evaluation_interval = "15s"
        cooldown            = "30s"

        # CASE 1: target-value scale UP [ALREADY TESTED 2026-05-11]
        # Confirmed: 1→2→3→5→8→10(capped) with factor=1.5
        check "case1-scale-up" {
          source = "prometheus"
          query  = "vector(75)"
          schedule {
            start    = "42 05 * * *"
            duration = "3m"
          }
          strategy "target-value" {
            target = "50"
          }
        }

        # CASE 2: target-value scale DOWN [ALREADY TESTED 2026-05-11]
        # Confirmed: 8→4→2 with factor=0.5
        check "case2-scale-down" {
          source = "prometheus"
          query  = "vector(25)"
          schedule {
            start    = "45 05 * * *"
            duration = "2m"
          }
          strategy "target-value" {
            target = "50"
          }
        }

        # CASE 3: cooldown crossing window boundary
        # 1min window, fixed-value=7 fires every 15s near end
        # Last scale ~05:48:45, cooldown=30s expires ~05:49:15
        # Window closes at 05:48 UTC → cooldown bleeds ~15s past close
        check "case3-cooldown-crossing" {
          source = "prometheus"
          query  = "vector(1)"
          schedule {
            start    = "48 05 * * *"
            duration = "1m"
          }
          strategy "fixed-value" {
            value = "7"
          }
        }

        # CASE 4: window shorter than evaluation interval
        # duration=10s < evaluation_interval=15s → may be silently skipped
        check "case4-short-window" {
          source = "prometheus"
          query  = "vector(1)"
          schedule {
            start    = "50 05 * * *"
            duration = "10s"
          }
          strategy "fixed-value" {
            value = "9"
          }
        }

        # CASE 5: sequential non-overlapping windows
        # 1min gap after case4, then fresh window opens
        check "case5-sequential-window" {
          source = "prometheus"
          query  = "vector(1)"
          schedule {
            start    = "52 05 * * *"
            duration = "1m"
          }
          strategy "fixed-value" {
            value = "4"
          }
        }

        # BASELINE: always-active floor at count=1
        check "off-peak-floor" {
          source = "prometheus"
          query  = "vector(1)"
          strategy "fixed-value" {
            value = "1"
          }
        }

        target "nomad-target" {
          job   = "edge-cases-job"
          group = "edge-cases-job"
        }
      }
    }
  }
}
