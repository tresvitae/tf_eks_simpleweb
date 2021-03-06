terraform {
  backend "remote" {
    organization = "tresvitae"

    workspaces {
      name = "eks_simpleweb"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    null = {
      source = "hashicorp/null"
      version = "3.1.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
  required_version = ">= 0.14"
}

data "aws_availability_zones" "available" {
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "terraform-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]

  enable_nat_gateway   = true
  enable_vpn_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}

resource "aws_security_group" "worker_group_mgmt_two" {
  name_prefix = "worker_group_mgmt_two"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "192.168.0.0/16",
    ]
  }
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_management"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
}

## KUBERNETES ##
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.21"
  subnets         = module.vpc.private_subnets

  tags = {
    Environment = "development"
  }

  vpc_id = module.vpc.vpc_id

  workers_group_defaults = {
    root_volume_type = "gp2"
  }

  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = "t2.small"
      spot_price                    = "0.015"
      additional_userdata           = "echo foo bar"
      asg_desired_capacity          = 2
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
    },
    {
      name                          = "worker-group-2"
      instance_type                 = "t2.medium"
      spot_price                    = "0.025"
      additional_userdata           = "echo foo bar"
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_two.id]
      asg_desired_capacity          = 1
    },
  ]
}

resource "aws_iam_role_policy_attachment" "metrics_policy" {
  role       = module.eks.worker_iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name = "eks-nginx-deployment"
    labels = {
      App = "TheExampleApp"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "TheExampleApp"
      }
    }
    template {
      metadata {
        labels = {
          App = "TheExampleApp"
        }
      }
      spec {
        container {
          image = "nginx:1.7.8"
          name  = "eks-nginx"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx-service" {
  metadata {
    name = "nginx-example"
  }
  spec {
    selector = {
      App = kubernetes_deployment.nginx.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
  provisioner "local-exec" {
    command = "${path.module}/install-cloudwatch-ci.sh"
  }
}

# HPA with behavior autoscaling
resource "kubernetes_horizontal_pod_autoscaler" "example" {
  metadata {
    name = "nginx-hpa"
  }

  spec {
    min_replicas = 2
    max_replicas = 5

    scale_target_ref {
      kind = "Deployment"
      name = "TheExampleApp"
    }

    behavior {
      scale_down {
        stabilization_window_seconds = 300
        select_policy                = "Min"
        policy {
          period_seconds = 120
          type           = "Pods"
          value          = 1
        }

        policy {
          period_seconds = 310
          type           = "Percent"
          value          = 100
        }
      }
      scale_up {
        stabilization_window_seconds = 600
        select_policy                = "Max"
        policy {
          period_seconds = 180
          type           = "Percent"
          value          = 100
        }
        policy {
          period_seconds = 600
          type           = "Pods"
          value          = 5
        }
      }
    }
  }
}

data "aws_sns_topic" "sns" {
  name = aws_sns_topic.topic.name
}
resource "aws_sns_topic" "topic" {
  name = "eks_topic"
}
resource "aws_sns_topic_subscription" "subscribers" {
  topic_arn = data.aws_sns_topic.sns.arn
  protocol  = "email"
  endpoint  = "patryk.futa@gmail.com"
}