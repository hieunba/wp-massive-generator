provider "aws" {
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name   = "wp-vpc"
  cidr   = var.cidr_block

  azs             = var.azs[var.region]
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = var.enable_nat_gateway
  enable_vpn_gateway = var.enable_vpn_gateway

  tags = {
    Generator = "true"
  }
}
