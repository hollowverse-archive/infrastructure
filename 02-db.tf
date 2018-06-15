variable "db_name" {
  type    = "string"
  default = "hollowverse"
}

variable "db_password" {
  type = "string"
}

variable "db_username" {
  type    = "string"
  default = "root"
}

resource "aws_sns_topic" "db_alarms" {
  name = "${var.db_name}-db-alarms-${var.stage}"
}

resource "aws_secretsmanager_secret" "db_secret" {
  name = "${var.stage}/database-4"
}

resource "aws_secretsmanager_secret_version" "db_secret_latest" {
  secret_id = "${aws_secretsmanager_secret.db_secret.id}"

  secret_string = "${jsonencode(map(
    "host", "${aws_rds_cluster.db_cluster.endpoint}",
    "port", 3306,
    "dbname", "${var.db_name}",
    "username", "${var.db_username}",
    "password", "${var.db_password}",
  ))}"
}

resource "aws_db_subnet_group" "main" {
  name       = "db-subnet-group-${var.stage}"
  subnet_ids = ["${module.vpc.private_subnets}"]

  tags = "${local.common_tags}"
}

resource "aws_rds_cluster" "db_cluster" {
  cluster_identifier = "hollowverse-aurora-cluster-${var.stage}"

  # IMPORTANT: Due to a bug in AWS provider, this array should list all
  # the availability zones defined in the VPC to avoid re-creating the
  # cluster on every `terraform apply` execution, which would destroy all
  # the data in the databases.
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  skip_final_snapshot = true

  engine = "aurora-mysql"

  port = 3306

  database_name   = "${var.db_name}"
  master_username = "${var.db_username}"
  master_password = "${var.db_password}"

  vpc_security_group_ids          = ["${aws_security_group.allow_db_access.id}"]
  db_subnet_group_name            = "${aws_db_subnet_group.main.name}"
  db_cluster_parameter_group_name = "${aws_rds_cluster_parameter_group.aurora_57_cluster_parameter_group.name}"
}

resource "aws_rds_cluster_instance" "cluster_instance_0" {
  identifier              = "hollowverse-aurora-db-instance-0"
  cluster_identifier      = "${aws_rds_cluster.db_cluster.id}"
  instance_class          = "db.t2.medium"
  publicly_accessible     = true
  engine                  = "aurora-mysql"
  db_subnet_group_name    = "${aws_db_subnet_group.main.name}"
  db_parameter_group_name = "${aws_db_parameter_group.aurora_db_57_parameter_group.name}"
}

resource aws_security_group "allow_db_access" {
  vpc_id = "${module.vpc.vpc_id}"
  name   = "Allow access to the database"

  ingress {
    protocol    = "tcp"
    from_port   = "3306"
    to_port     = "3306"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_parameter_group" "aurora_db_57_parameter_group" {
  name   = "${var.db_name}-${var.stage}-aurora-db-57-parameter-group"
  family = "aurora-mysql5.7"
}

resource "aws_rds_cluster_parameter_group" "aurora_57_cluster_parameter_group" {
  name   = "${var.db_name}-${var.stage}-aurora-57-cluster-parameter-group"
  family = "aurora-mysql5.7"
}
