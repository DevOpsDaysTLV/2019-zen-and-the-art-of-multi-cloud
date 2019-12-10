module "devops-k8" {
  version = "7.0.0"
  source       = "terraform-aws-modules/eks/aws"
  cluster_name = "dod2019"
  subnets      = data.aws_subnet_ids.selected.ids
  vpc_id       = data.aws_vpc.default.id

  worker_groups = [
    {
      instance_type = "m5.large"
      asg_max_size  = 3
      tags = [{
        key                 = "Terraform"
        value               = "true"
        propagate_at_launch = true
      }]
    }
  ]

  tags = {
    environment = "devopsdays"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_subnet_ids" "selected" {
      vpc_id = data.aws_vpc.default.id
      filter {
        name = "tag:Name"
        values = ["devopsdays-public"]
      }
}
data "aws_vpc" "default" {
  filter {
    name   = "tag:Name"
    values = ["devopsdays"]
  }
}
