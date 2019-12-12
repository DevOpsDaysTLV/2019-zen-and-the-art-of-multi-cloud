job "nginx" {
  datacenters = ["DevOpsDaysTLV2019-Zen"]

  type = "service"

  update {
    max_parallel = 3
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    progress_deadline = "10m"
    auto_revert = false
    canary = 0
  }

  migrate {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    healthy_deadline = "5m"
  }

  group "web" {

    count = 9

    restart {
      attempts = 2
      interval = "30m"
      delay = "15s"
      mode = "fail"
    }

    task "server" {

      driver = "docker"

      config {
        image = "nginx"
        volumes = [
          # Use relative paths to rebind paths already in the allocation dir
           "html:/usr/share/nginx/html"
        ]
        port_map {
          http = 80
        }
      }

      resources {
        cpu    = 100 # 500 MHz
        memory = 64 # 256MB
        network {
          mbits = 10
          port "http" {}
        }
      }

      service {
        name = "nginx"
        tags = ["urlprefix-/"]
        port = "http"
        check {
          name           = "alive"
          type           = "tcp"
          interval       = "3s"
          timeout        = "2s"
          initial_status = "critical"
        }
      }


      template {
        data          = <<EORC
DevOpsDays Tel Aviv 2019
bind_port:   {{ env "NOMAD_PORT_http" }}
scratch_dir: {{ env "NOMAD_TASK_DIR" }}
node_id:     {{ env "node.unique.id" }}
aws_as:      {{ env "attr.platform.aws.placement.availability-zone" }}

kv_magic:  {{ keyOrDefault "dod" "No magic here"}}
EORC

        destination   = "html/index.html"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }

    }
  }
}
