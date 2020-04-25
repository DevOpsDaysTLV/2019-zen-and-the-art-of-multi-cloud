pid_file = "./pidfile"

vault {
        address = "http://3.19.240.186:8200"
}

auto_auth {
        method "aws" {
                config = {
                        type = "iam"
                        role = "dev-role-iam"
                }
        }

        sink "file" {
                config = {
                        path = "/tmp/sink"
                }
        }

}

listener "tcp" {
         address = "127.0.0.1:8100"
         tls_disable = true
}

template {
  source      = "./index.ctmpl"
  destination = "/var/www/html/index.nginx-debian.html"
}
