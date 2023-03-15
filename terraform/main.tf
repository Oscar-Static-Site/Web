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
module "state" {
  source = "./modules/state/"
}
module "web" {
  source = "./modules/web/"
  
}
