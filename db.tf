variable "db_name" {
  type    = "string"
  default = "hollowverse"
}

variable "db_password" {
  type = "string"
}

variable "db_username" {
  type    = "string"
  default = "user"
}

resource "aws_sns_topic" "db_alarms" {
  name = "${var.db_name}-db-alarms-${var.stage}"
}

resource "aws_secretsmanager_secret" "db_secret" {
  name        = "${var.stage}/database-9"
  description = "Database connection configuration"
  depends_on  = ["aws_rds_cluster.db_cluster"]

  # Must be between 7 and 30
  recovery_window_in_days = 7

  tags = "${local.common_tags}"
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

resource "aws_db_subnet_group" "main_db_subnet_group" {
  name = "db-subnet-group-${var.stage}"

  # Databases should typically be in private subnets, for security reasons.
  # Access from other resources is later allowed via security groups.

  # Note: once the subnet group is created, changing this value won't have any
  # effect.
  subnet_ids = ["${module.vpc.database_subnets}"]
  tags = "${local.common_tags}"
}

# Geneate an ID when an environment is initialised
resource "random_id" "snapshot_suffix" {
  # `keepers` determine what keeps this random ID from changing every
  # time `terraform apply` is executed.
  keepers = {
    id = "${aws_db_subnet_group.main_db_subnet_group.name}"
  }

  byte_length = 8
}

resource "aws_rds_cluster" "db_cluster" {
  cluster_identifier = "${var.db_name}-cluster-${var.stage}"

  # When this cluster is destroyed, a snapshot of the database data will be
  # automatically created and stored in RDS.
  skip_final_snapshot = "${var.stage == "production" ? false : true}"

  final_snapshot_identifier = "hollowverse-${var.stage}-${random_id.snapshot_suffix.hex}"

  apply_immediately = "${var.stage == "production" ? false : true}"

  # IMPORTANT: chaging the engine will destroy the cluster and force the
  # creation of a new one.
  engine = "aurora"

  engine_mode    = "serverless"
  engine_version = "5.6.10a"

  storage_encrypted               = true
  port                            = 3306
  database_name                   = "${var.db_name}"
  master_username                 = "${var.db_username}"
  master_password                 = "${var.db_password}"
  vpc_security_group_ids          = ["${aws_security_group.allow_db_access_security_group.id}"]
  db_subnet_group_name            = "${aws_db_subnet_group.main_db_subnet_group.name}"
  db_cluster_parameter_group_name = "${aws_rds_cluster_parameter_group.cluster_parameter_group.name}"

  # Launch this cluster from snapshot
  snapshot_identifier = "before-migration-to-terraform"
}

# The database cluster will use this security group to make
# the database port open for other resources to access
resource aws_security_group "allow_db_access_security_group" {
  vpc_id = "${module.vpc.vpc_id}"
  name   = "Allow access to the database"

  tags = "${local.common_tags}"

  ingress {
    protocol        = "tcp"
    from_port       = 3306
    to_port         = 3306
    security_groups = ["${aws_security_group.access_db_security_group.id}"]
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = -1
    from_port   = 0
    to_port     = 0
  }
}

# Put resources in this security group to be able to access
# the database. For example, when launching the API Lambda,
# set the security group to the ID of this one and the
# lambda function will be able to connect to the database.
resource aws_security_group "access_db_security_group" {
  vpc_id = "${module.vpc.vpc_id}"
  name   = "Resources in this security group can access the database"

  tags = "${local.common_tags}"

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = -1
    from_port   = 0
    to_port     = 0
  }
}

resource "aws_rds_cluster_parameter_group" "cluster_parameter_group" {
  name   = "${var.db_name}-${var.stage}-cluster-parameter-group"
  family = "aurora5.6"

  tags = "${local.common_tags}"
}

# IAM Role + Policy attach for Enhanced Monitoring
data "aws_iam_policy_document" "monitoring_rds_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring_role" {
  name               = "rds-enhanced-monitoring-${var.stage}"
  assume_role_policy = "${data.aws_iam_policy_document.monitoring_rds_assume_role_policy.json}"
}

output "database_endpoint" {
  value = "${aws_rds_cluster.db_cluster.endpoint}"
}

output "database_access_security_group" {
  value       = "${aws_security_group.access_db_security_group.id}"
  description = "Resources in this security group can connect to the database"
}
