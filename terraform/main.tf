terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.58.0"
    }
  }
}
provider "aws" {
  region = "eu-west-2"
}
# Needed for the HTTPS certificates used in cloud front
provider "aws" {
  alias  = "acm_provider"
  region = "us-east-1"
}
module "state" {
  source = "./modules/state/"
}
module "web" {
  source = "./modules/web/"
}
module "logic" {
  source = "./modules/db"
    }
