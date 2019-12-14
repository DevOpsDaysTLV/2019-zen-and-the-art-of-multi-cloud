module "devops-k8" {
  version = "7.0.0"
  source       = "terraform-aws-modules/eks/aws"
  cluster_name = "dod2019"
  subnets      = data.aws_subnet_ids.selected.ids
  vpc_id       = data.aws_vpc.default.id

  kubeconfig_aws_authenticator_command = "aws" 
  kubeconfig_aws_authenticator_command_args = ["eks","get-token","--cluster-name","dod2019"]  
  worker_additional_security_group_ids = [data.aws_security_group.allow_from_vpc.id]
  worker_groups = [
    {
      instance_type = "t2.large"
      asg_max_size  = 3
      asg_desired_capacity = 3
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

##############################

data "aws_security_group" "allow_from_vpc" {
      filter {
        name = "group-name"
        values = ["allow_from_vpc"]
      }
}


#############################
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
