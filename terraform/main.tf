terraform {
  backend "local" {
  }
}

provider "aws" {
  version = "~> 2.69.0"
}

data "aws_region" "this" {

}

module "messaging" {
  source = "./modules/messaging"
  apigw_name  = var.apigw_name
  region = data.aws_region.this.name
  vpc_id = var.vpc_id
}

