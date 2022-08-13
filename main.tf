terraform {
  backend "s3" {
    bucket         = "staff-infrastructure-monitoring-cluster-tf-state"
    dynamodb_table = "staff-infrastructure-monitoring-cluster-tf-lock-table"
    region         = "eu-west-2"
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "main"

  assume_role {
    role_arn = var.assume_role
  }
}

data "aws_availability_zones" "available_zones" {
  state = "available"
}

module "label" {
  source           = "./modules/label"
  name             = "mojo-ima"
  application_name = var.application_name
}

module "vpc_label" {
  source           = "./modules/label"
  name             = "mojo-ima-vpc"
  application_name = var.application_name
}

module "vpc" {
  source          = "./modules/vpc"
  prefix          = module.vpc_label.id
  cidr            = "10.0.0.0/22"
  region          = var.aws_region
  available_zones = data.aws_availability_zones.available_zones.zone_ids
  tags            = module.vpc_label.tags

  providers = {
    aws = aws.main
  }
}

module "eks_label" {
  source           = "./modules/label"
  name             = "mojo-ima-eks"
  application_name = var.application_name
}

module "eks" {
  create                      = var.create_eks
  source                      = "./modules/eks"
  prefix                      = module.eks_label.id
  vpc_id                      = module.vpc.vpc_id
  private_subnets             = module.vpc.private_subnets
  private_subnets_cidr_blocks = module.vpc.private_subnets_cidr_blocks
  tags                        = module.eks_label.tags

  providers = {
    aws = aws.main
  }
}
