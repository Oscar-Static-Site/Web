terraform {
  backend "s3" {
    bucket = "tfstate-oscar"
    region = "eu-west-2"
  }
}
