provider "aws" {
  region = "us-east-1"
}

variable "stage" {
  type = "string"
  default = "development"
}

locals {
  common_tags = {
    Terraform = "True"
    Stage = "${var.stage}"
  }
}

locals {
  log_queue_name = "logging-queue-${var.stage}"
  dead_letter_log_queue_name = "logging-dead-letter-queue-${var.stage}"
}
