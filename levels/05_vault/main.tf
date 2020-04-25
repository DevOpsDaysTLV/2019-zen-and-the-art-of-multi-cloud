# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 0.12 syntax, which means it is no longer compatible with any versions below 0.12.
# ----------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 0.12"
}

# ---------------------------------------------------------------------------------------------------------------------
# AUTOMATICALLY LOOK UP THE LATEST PRE-BUILT AMI
#
# !! WARNING !! These exmaple AMIs are meant only convenience when initially testing this repo. Do NOT use these example
# AMIs in a production setting because it is important that you consciously think through the configuration you want
# in your own production AMI.
#
# ---------------------------------------------------------------------------------------------------------------------

data "aws_ami" "base" {
  most_recent = true

  # If we change the AWS Account in which test are run, update this value.
  owners = ["self"]

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "name"
    values = ["DevOpsDaysTLV2019-Zen-*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL SERVER NODES
# ---------------------------------------------------------------------------------------------------------------------

module "ooc_clients" {
  source = "github.com/hashicorp/terraform-aws-consul.git//modules/consul-cluster?ref=v0.7.3"

  cluster_name  = "ooc-client"
  cluster_size  = 1
  instance_type = "t2.micro"
#  spot_price    = var.spot_price

  # The EC2 Instances will use these tags to automatically discover each other and form a cluster
  cluster_tag_key   = var.cluster_tag_key
  cluster_tag_value = "ooc-client"

  ami_id    = "${data.aws_ami.base.image_id}"
  user_data = "${data.template_file.user_data_client.rendered}"

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnet_ids.default.ids

  # To make testing easier, we allow Consul and SSH requests from any IP address here but in a production
  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  allowed_ssh_cidr_blocks = ["0.0.0.0/0"]

  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
  ssh_key_name                = var.ssh_key_name

  tags = [
    {
      key                 = "Environment"
      value               = "DevOpsDaysTLV2019-Zen"
      propagate_at_launch = true
    }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# THE INBOUND/OUTBOUND RULES FOR THE SECURITY GROUP COME FROM THE NOMAD-SECURITY-GROUP-RULES MODULE
# ---------------------------------------------------------------------------------------------------------------------

module "nomad_security_group_rules" {
  source = "github.com/hashicorp/terraform-aws-nomad.git//modules/nomad-security-group-rules?ref=v0.6.0"

  security_group_id           = module.ooc_clients.security_group_id
  allowed_inbound_cidr_blocks = var.allowed_inbound_cidr_blocks

  http_port = 4646
  rpc_port  = 4647
  serf_port = 4648
}

resource "aws_security_group_rule" "allow_nomad_dynamic_inbound" {
  type        = "ingress"
  from_port   = 80
  to_port     = 65535 # Don't do it in prod
  protocol    = "tcp"
  cidr_blocks = var.allowed_inbound_cidr_blocks

  security_group_id = module.ooc_clients.security_group_id
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH CONSUL SERVER EC2 INSTANCE WHEN IT'S BOOTING
# This script will configure and start Consul
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data_client" {
  template = file("user-data-client.sh")

  vars = {
    cluster_tag_key   = var.cluster_tag_key
    cluster_tag_value = "ooc-client"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY IN THE DEFAULT VPC AND SUBNETS
# Using the default VPC and subnets makes this example easy to run and test, but it means Consul is accessible from the
# public Internet. For a production deployment, we strongly recommend deploying into a custom VPC with private subnets.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  filter {
    name   = "tag:Name"
    values = ["devopsdays"]
  }
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_region" "current" {
}

data "aws_instances" "vault_servers" {

  filter {
    name   = "tag:Name"
    values = ["DevOpsDaysTLV2019-Zen-server"]
  }
}

#-------------------------------------------------
output "one_vault_addr" {
  value = data.aws_instances.vault_servers.public_ips[0]
}

#--------------------------------------------------
resource "aws_security_group" "allow_from_vpc" {
  name        = "allow_from_vpc"
  description = "Allow all traffic from VPC"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }
}
