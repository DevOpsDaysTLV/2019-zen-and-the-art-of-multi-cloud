module "db" {
  source = "terraform-aws-modules/rds/aws"
  version = "2.5.0"
  identifier = "demodb"
  engine            = "mysql"
  engine_version    = "5.7.19"
  instance_class    = "db.t2.large"
  allocated_storage = 5
  storage_encrypted = false
  name     = "dod2019rds"
  username = "root"
  password = "devopsdays4life"
  port     = "3306"
  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"
  tags = {
    Terraform = "true"
  }

  subnet_ids = data.aws_subnet_ids.default.ids
  family = "mysql5.7"
  major_engine_version = "5.7"
  final_snapshot_identifier = "final-snapshot"
  vpc_security_group_ids = [aws_security_group.allow_from_vpc.id]
}
output "rds_endpoint" {
 value = module.db.this_db_instance_endpoint
}

