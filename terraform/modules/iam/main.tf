terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}


resource "aws_iam_user" "ci-cd" {
  name = "cicd"
}

resource "aws_iam_access_key" "acck" {
  user = aws_iam_user.ci-cd.name
}

output "secret_key" {

  value = aws_iam_access_key.acck.secret

  sensitive = true

}

output "access_key" {

  value = aws_iam_access_key.acck.id

}

resource "aws_iam_user_policy" "ci-cd-policy" {
  name   = "ci-cd-policy"
  user   = aws_iam_user.ci-cd.name
  policy = file("cicd.json")
}
