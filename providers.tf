terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

# ----------------------
# AWS Provider
# ----------------------
provider "aws" {
  region = var.aws_region
}

# ----------------------
# Data sources for EKS cluster information
# These will only work AFTER the cluster is created
# ----------------------
data "aws_eks_cluster" "kafka" {
  name = "kafka-eks"

  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "kafka" {
  name = "kafka-eks"

  depends_on = [module.eks]
}

# ----------------------
# Kubernetes Provider with exec for authentication
# ----------------------
provider "kubernetes" {
  host                   = data.aws_eks_cluster.kafka.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.kafka.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      "kafka-eks",
      "--region",
      var.aws_region
    ]
  }
}

# ----------------------
# Helm Provider
# ----------------------
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.kafka.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.kafka.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        "kafka-eks",
        "--region",
        var.aws_region
      ]
    }
  }
}