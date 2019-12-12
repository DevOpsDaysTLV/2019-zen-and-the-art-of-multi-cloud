job "fabio" {
  datacenters = ["DevOpsDaysTLV2019-Zen"]
  type = "system"
  update {
    stagger = "5s"
    max_parallel = 1
  }

  group "fabio" {
    task "fabio" {
      driver = "exec"
      config {
        command = "fabio-1.5.13-go1.13.4-linux_amd64"
      }

      artifact {
        source = "https://github.com/eBay/fabio/releases/download/v1.5.13/fabio-1.5.13-go1.13.4-linux_amd64"
      }

      resources {
        cpu = 500
        memory = 128
        network {
          mbits = 10

          port "http" {
            static = 9999
          }
          port "ui" {
            static = 9998
          }
        }
      }
    }
  }
}
