module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.32.0"

  name = "vpc-${var.stage}"

  cidr            = "10.0.0.0/16"
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = "${local.common_tags}"
}
