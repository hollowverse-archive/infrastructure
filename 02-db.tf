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
  name       = "${var.stage}/database-5"
  depends_on = ["aws_rds_cluster.db_cluster"]

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

resource "aws_db_subnet_group" "main" {
  name = "db-subnet-group-${var.stage}"

  # Databases should typically be in private subnets, for security reasons.
  # Access from other resources is later allowed via security groups.
  subnet_ids = ["${module.vpc.private_subnets}"]

  tags = "${local.common_tags}"
}

# Geneate an ID when an environment is initialised
resource "random_id" "db_initialized" {
  # `keepers` determine what keeps this random ID from changing every
  # time `terraform apply` is executed.
  keepers = {
    id = "${aws_db_subnet_group.main.name}"
  }

  byte_length = 8
}

resource "aws_rds_cluster" "db_cluster" {
  cluster_identifier = "${var.db_name}-cluster-${var.stage}"

  # IMPORTANT: Due to what seems to be a bug in AWS provider, this array should
  # list all the availability zones defined in the VPC to avoid re-creating the
  # cluster on every `terraform apply` execution, which would destroy all the
  # data in the databases.
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # When this cluster is destroyed, a snapshot of the database data will be
  # automatically created and stored in RDS.
  skip_final_snapshot = false

  final_snapshot_identifier = "hollowverse-${var.stage}-${random_id.db_initialized.hex}"

  # IMPORTANT: chaging the engine will destroy the cluster and force the
  # creation of a new one.
  engine = "aurora-mysql"

  # IMPORTANT: Do not hardcode `engine_version`, this may force creation of new instances
  # if a new minor version is released and `auto_minor_version_upgrade` is enabled
  # (which it is, by default)

  port                            = 3306
  database_name                   = "${var.db_name}"
  master_username                 = "${var.db_username}"
  master_password                 = "${var.db_password}"
  vpc_security_group_ids          = ["${aws_security_group.allow_db_access.id}"]
  db_subnet_group_name            = "${aws_db_subnet_group.main.name}"
  db_cluster_parameter_group_name = "${aws_rds_cluster_parameter_group.aurora_57_cluster_parameter_group.name}"
}

# The first database instance in the above cluster will be
# the writer. Any other instances defined later will be replicas.
resource "aws_rds_cluster_instance" "cluster_instance_0" {
  identifier = "hollowverse-db-instance-${var.stage}-0"

  cluster_identifier = "${aws_rds_cluster.db_cluster.id}"

  instance_class      = "db.t2.medium"
  publicly_accessible = true

  engine = "aurora-mysql"

  # IMPORTANT: Do not hardcode `engine_version`, this may force creation of new instances
  # if a new minor version is released and `auto_minor_version_upgrade` is enabled
  # (which it is, by default)

  db_subnet_group_name    = "${aws_db_subnet_group.main.name}"
  db_parameter_group_name = "${aws_db_parameter_group.aurora_db_57_parameter_group.name}"
  tags                    = "${local.common_tags}"
}

# The database cluster will use this security group to make
# the database port open for other resources to access
resource aws_security_group "allow_db_access" {
  vpc_id = "${module.vpc.vpc_id}"
  name   = "Allow access to the database"

  tags = "${local.common_tags}"

  ingress {
    protocol        = "tcp"
    from_port       = "3306"
    to_port         = "3306"
    security_groups = ["${aws_security_group.access_db.id}"]
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
resource aws_security_group "access_db" {
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

# Parameter groups in RDS define a preset of configuration settings
# to be applied to any database/cluster defined in that group.
resource "aws_db_parameter_group" "aurora_db_57_parameter_group" {
  name   = "${var.db_name}-${var.stage}-aurora-db-57-parameter-group"
  family = "aurora-mysql5.7"

  tags = "${local.common_tags}"
}

resource "aws_rds_cluster_parameter_group" "aurora_57_cluster_parameter_group" {
  name   = "${var.db_name}-${var.stage}-aurora-57-cluster-parameter-group"
  family = "aurora-mysql5.7"

  tags = "${local.common_tags}"
}
