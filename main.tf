# ---- Create VPC for EKS ----
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0" # Updated to newer version to fix deprecation warning

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  # Enable DNS support for EKS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required for EKS
  tags = {
    "kubernetes.io/cluster/kafka-eks" = "shared"
  }
}

# ---- Create EKS Cluster ----
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.2"

  cluster_name    = "kafka-eks"
  cluster_version = "1.31"  # Updated from 1.28 to 1.31
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  # Enable IAM roles for service accounts
  enable_irsa = true

  # Enable public access to the cluster endpoint
  cluster_endpoint_public_access = true
  
  # Restrict public access to specific CIDR blocks (optional)
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # Disable cluster creator auto-permissions (we'll manage manually)
  enable_cluster_creator_admin_permissions = false

  # Configure access entries for IAM users/roles
  access_entries = {
    admin = {
      principal_arn     = "arn:aws:iam::907849381252:user/admin"
      type              = "STANDARD"
      
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    eks_nodes = {
      desired_size = 3  # Increase to fit all pods
      max_size     = 4
      min_size     = 2

      instance_types = ["t3.medium"]
      # key_name      = "your-key-pair" # optional
      
      # Ensure proper IAM role for nodes
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy  = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
      
      # Add tags for Kubernetes
      tags = {
        "kubernetes.io/cluster/kafka-eks" = "owned"
      }
    }
  }
  
  # Add cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_443 = {
      description = "Node groups to cluster API"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      source_node_security_group = true
    }
    ingress_nodes_kubelet = {
      description = "Kubelet traffic from nodes"
      protocol    = "tcp"
      from_port   = 10250
      to_port     = 10250
      type        = "ingress"
      source_node_security_group = true
    }
  }
  
  # Add node security group rules
  node_security_group_additional_rules = {
    ingress_cluster_443 = {
      description                   = "Cluster API to node groups"
      protocol                      = "tcp"
      from_port                     = 443
      to_port                       = 443
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_nodes_ephemeral_ports_tcp = {
      description                   = "Node to node ingress on ephemeral ports"
      protocol                      = "tcp"
      from_port                     = 1025
      to_port                       = 65535
      type                          = "ingress"
      source_node_security_group    = true
    }
    # Add egress rules for nodes to communicate with the internet
    egress_all = {
      description = "Allow all egress traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    # Allow DNS resolution
    egress_dns_tcp = {
      description                   = "DNS resolution TCP"
      protocol                      = "tcp"
      from_port                     = 53
      to_port                       = 53
      type                          = "egress"
      cidr_blocks                   = ["0.0.0.0/0"]
    }
    egress_dns_udp = {
      description                   = "DNS resolution UDP"
      protocol                      = "udp"
      from_port                     = 53
      to_port                       = 53
      type                          = "egress"
      cidr_blocks                   = ["0.0.0.0/0"]
    }
  }
}

# ============================================================================
# EBS CSI Driver IAM Role
# ============================================================================
data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_arn, "/^(.*provider/)/", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_arn, "/^(.*provider/)/", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "ebs-csi-driver-${module.eks.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ============================================================================
# EBS CSI Driver Addon
# ============================================================================
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.50.1-eksbuild.1"  # Updated to a supported version
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.ebs_csi_driver
  ]
}

# ============================================================================
# Kubernetes Resources Module
# ============================================================================
module "kubernetes" {
  source                      = "./modules/kubernetes"
  aws_region                  = var.aws_region
  cluster_name                = "kafka-eks"
  kafka_deployment_type       = var.kafka_deployment_type
  namespace                   = "kafka"  # Use a custom namespace
  count                       = var.create_kubernetes_resources ? 1 : 0

  # Don't pass the aliased provider - use the default one
  # providers = {
  #   kubernetes.eks = kubernetes.eks
  # }

  # Ensure this module only runs after the EKS cluster is fully created
  # AND the data sources have been populated
  depends_on = [
    module.eks,
    data.aws_eks_cluster.kafka,
    data.aws_eks_cluster_auth.kafka
  ]
}