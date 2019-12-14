pid_file = "./pidfile"

vault {
        address = "https://3.136.26.192:8200"
}

auto_auth {
        method "aws" {
                mount_path = "auth/aws-subaccount"
                config = {
                        type = "iam"
                        role = "foobar"
                }
        }

        sink "file" {
                config = {
                        path = "/tmp/sink"
                }
        }

}

cache {
        use_auto_auth_token = true
}

listener "tcp" {
         address = "127.0.0.1:8100"
         tls_disable = true
}

template {
  source      = ""
  destination = ""
}
