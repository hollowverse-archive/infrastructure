
variable "db_name" {
  type = "string"
  default = "hollowverse"
}

variable "db_password" {
  type = "string"
}

variable "db_username" {
  type = "string"
  default = "root"
}

locals {
  db_name_with_stage = "${var.db_name}-${var.stage}"
}

resource "aws_sns_topic" "db_alarms" {
  name = "${local.db_name_with_stage}-db-alarms"
}

resource "aws_secretsmanager_secret" "db_secret" {
  name = "${var.stage}/database"
}

resource "aws_secretsmanager_secret_version" "db_secret_latest" {
  secret_id     = "${aws_secretsmanager_secret.db_secret.id}"
  secret_string = "${jsonencode(map(
    "host", "${module.hollowverse_db_aurora.cluster_endpoint}",
    "port", 3306,
    "dbname", "${var.db_name}",
    "username", "${var.db_username}",
    "password", "${var.db_password}",
  ))}"
}


module "hollowverse_db_aurora" {
  source                          = "claranet/aurora/aws"

  # IMPORTANT: Changing the engine will DESTROY
  # the currently running database (if any) and create a new, empty one
  engine                          = "aurora-mysql"
  engine-version                  = "5.7.12"

  name                            = "${var.db_name}"
  envname                         = "${var.stage}"
  envtype                         = "${var.stage}"

  subnets                         = ["${module.vpc.private_subnets}"]
  azs                             = ["us-east-1a", "us-east-1b"]

  replica_count                   = "1"
  security_groups                 = ["${aws_security_group.allow_all.id}"]
  instance_type                   = "db.t2.medium"

  username                        = "${var.db_username}"
  password                        = "${var.db_password}"

  backup_retention_period         = "1"
  final_snapshot_identifier       = "${local.db_name_with_stage}-snapshot-final"
  storage_encrypted               = "true"
  apply_immediately               = "true"
  monitoring_interval             = "10"

  cw_alarms                       = true
  cw_sns_topic                    = "${aws_sns_topic.db_alarms.id}"

  db_parameter_group_name         = "${aws_db_parameter_group.aurora_db_57_parameter_group.id}"
  db_cluster_parameter_group_name = "${aws_rds_cluster_parameter_group.aurora_57_cluster_parameter_group.id}"
}

resource aws_security_group "allow_all" {
  vpc_id = "${module.vpc.vpc_id}"
  name = "Allow access to the database"

  ingress {
    protocol    = "tcp"
    from_port   = "3306"
    to_port     = "3306"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_parameter_group" "aurora_db_57_parameter_group" {
  name        = "${local.db_name_with_stage}-aurora-db-57-parameter-group"
  family      = "aurora-mysql5.7"
}

resource "aws_rds_cluster_parameter_group" "aurora_57_cluster_parameter_group" {
  name        = "${local.db_name_with_stage}-aurora-57-cluster-parameter-group"
  family      = "aurora-mysql5.7"
}
