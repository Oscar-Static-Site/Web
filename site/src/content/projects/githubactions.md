---
title: "Using github actions for Continuous deployment"
date: 2024-01-07T13:13 
draft: false
---


# Image deployment and ci using Github actions.

All the code can be find in the following [repo](https://github.com/oscar-todo-app/todo-app) in the infra cluster folder. 

## First we need to allow our Github org to push images to ECR.
 
To do this we can:

- Use AWS keys (easier but less secure)
- Use OpenID connect (harder but more secure) [Info](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) 

I chose the later:

First we need to set up a GitHub org [info](https://github.com/topics/github-organization). 

Second we will need some terraform code to link both things together


First we need a ECR repository.

``` terraform 

resource "aws_ecr_repository" "repository" {
  name = var.name
}
```

Second we will need to give permissions to push to the repo:

``` terraform

data "aws_iam_policy_document" "github_actions" {
  statement {
    actions = [
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.repository.arn]
  }

  statement {
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_actions" {
  name        = "github-actions-${var.name}"
  description = "Grant Github Actions the ability to push to ${var.name} from oscarsjlh/${var.name}"
  policy      = data.aws_iam_policy_document.github_actions.json
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}



data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.organization}/${var.name}:*"]
    }
  }
}
```


And once we have that the link with AWS:

``` terraform 

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["a031c46782e6e6c662c2c87c76da9aa62ccabd8e"]
}

```


And then we can create a github action to build an push our code to the repo, and once is push we can commit that tag to our Gitops folder and it will update it automatically.

Kind of a long one but the flow would be:
- 1st we checkout the code. 

- We authorize to AWS and get the credentials for docker. 

- Run docker build the image and tag it with the commit sha.

- Do some regex to update the manifest.

- Finally commit and push the changes.

``` yaml 
name: ecr build

on:
  push:
    paths:
      - src/**
    branches: ["main"]

env:
  AWS_REGION: "eu-west-2"
  AWS_ACCOUNT_ID:
  TAGS: "477601539816.dkr.ecr.eu-west-2.amazonaws.com/todo-app"
jobs:
  deploy:
    name: Push to ECR
    runs-on: ubuntu-latest

    permissions:
      id-token: write
      contents: write

    steps:
      - name: checkout
        with:
          ssh-key: ${{ secrets.BOT_ACCESS_TOKEN }}
        uses: actions/checkout@v4
      - name: setup AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ env.AWS_ACCOUNT_ID }}:role/github-actions-oscar-todo-app-todo-app
          aws-region: ${{ env.AWS_REGION }}
      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push Docker image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: "{{defaultContext}}:src"
          cache-from: type=gha
          cache-to: type=gha,mode=max
          push: true
          platforms: linux/amd64
          tags: ${{ env.TAGS }}:${{ github.sha }}
          labels: ${{ steps.meta.outputs.labels }}
      - name: Update manifest
        working-directory: ./k8s/todo-template
        run: |
          echo 'Sha digest is: ${{ steps.build.outputs.digest }}'
          sha="${{ github.sha }}"
          sed -i "s/\(imageTag: \).*/\1$sha/" Values.yaml
          git config --global user.name 'Img updater'
          git config --global user.emal 'imgupdater@noreply.com'
          git commit -am "Update sha to $sha"
          git push
```

