provider "aws" {
  region  = "us-east-1"
  version = "1.23.0"
}

variable "stage" {
  type    = "string"
  default = "development"
}

locals {
  common_tags = {
    Terraform = "True"
    Stage     = "${var.stage}"
  }
}

resource "aws_s3_bucket" "state_s3_bucket" {
  bucket = "hollowverse-terraform-state-${var.stage}"
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = "${local.common_tags}"
}

resource aws_dynamodb_table "state_lock_dynamodb_table" {
  name = "hollowverse-state-lock-${var.stage}"

  attribute {
    name = "LockID"
    type = "S"
  }

  hash_key = "LockID"

  write_capacity = 5
  read_capacity  = 5

  tags = "${local.common_tags}"
}
