provider "aws" {
  region = "us-east-1"
}

variable "stage" {
  type    = "string"
  default = "development"
}

terraform {
  backend "s3" {
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config {
    bucket = "terraform-state-${var.stage}"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  common_tags = {
    Terraform = "True"
    Stage     = "${var.stage}"
  }
}

locals {
  log_queue_name             = "logging-queue-${var.stage}"
  dead_letter_log_queue_name = "logging-dead-letter-queue-${var.stage}"
}
