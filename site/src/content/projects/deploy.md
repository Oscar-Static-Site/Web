---
title: "Deploying a 3 tier app in AWS with Terraform"
date: 2024-01-07T13:13 
draft: false
---

# Deploying a 3 tier app with terraform using AWS.

To deploy a 3 tier app (api + db), we're going to be using AWS eks service and Amazon RDS for the DB.

All the code can be find in the following [repo](https://github.com/oscar-todo-app/todo-app) in the infra cluster folder. 

## First we will need to create a VPC with a private and public subnets.
We will need:

- 3 public subnets, for k8s, (pods and services, and control panel) and the db.
- 3 Public subnets for loadbalncer and to reach the internet from pods.

## Terraform code for this:


For this I made use the module provided by aws to make things simpler.

``` terraform 

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.4.0"

  name                 = "todo-vpc"
  cidr                 = "172.16.0.0/16"
  azs                  = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  private_subnets      = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  public_subnets       = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }

```

### Once we have this we need our cluster again we use AWS modules for this:

``` terraform 

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.28"

  enable_irsa                    = true
  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  eks_managed_node_groups = {
    general = {
      desired_size = 1
      min_size     = 1
      max_size     = 1

      labels = {
        role = "general"
      }

      instance_types = ["t3a.xlarge"]
      capacity_type  = "ON_DEMAND"
    }
  }
}
```

### And for the db:

First of all, we need to generate a random pass for the db, and then store it in AWS secert's manager
If we wanted better separation we could create another vpc for the db and then link them together with [VPC peering](https://docs.aws.amazon.com/vpc/latest/peering/what-is-vpc-peering.html) 

``` terraform 

resource "random_password" "todo-pass" {
  length           = 16
  special          = false
  override_special = ""

}

resource "aws_db_subnet_group" "todo-db-subnet-group" {
  name       = "todo-db-subnet-group"
  subnet_ids = var.subnets
}

resource "aws_secretsmanager_secret" "db-pass" {
  recovery_window_in_days = 0
  name                    = "db-pass-new"
}

resource "aws_secretsmanager_secret_version" "db-pass-v" {
  secret_id     = aws_secretsmanager_secret.db-pass.id
  secret_string = random_password.todo-pass.result
}


resource "aws_security_group" "todo-db-group" {
  name        = "todo-db-group"
  description = "Allow postgress"
  vpc_id      = var.vpcID
}
resource "aws_db_instance" "todo-db" {
  identifier             = "todo-db"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "16.1"
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
  vpc_security_group_ids = [aws_security_group.todo-db-group.id]
  username               = "todo"
  password               = random_password.todo-pass.result
  db_name                = "todo"
  db_subnet_group_name   = aws_db_subnet_group.todo-db-subnet-group.name
}
```

### Finally we need an aws security group to allow traffic from k8s to the DB

``` terraform

resource "aws_security_group_rule" "todo-db" {
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
  description              = "Allow all inbound for Postgres"
  security_group_id        = aws_security_group.todo-db-group.id
  source_security_group_id = var.secGroupID
}


```
