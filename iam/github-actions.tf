# Get AWS account ID
data "aws_caller_identity" "current" {}

# GitHub Actions OIDC Provider (auto-thumbprint)
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"  # ← no trailing spaces!
  client_id_list  = ["sts.amazonaws.com"]
  # thumbprint_list omitted → auto-fetched by Terraform
}

# GitHub Actions OIDC Role (restricted to your repo)
resource "aws_iam_role" "github_actions_role" {
  name = "GitHubActionsKafkaDeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          },
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:leketech/kafka-k8s-aws:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

# Least-privilege permissions policy
resource "aws_iam_role_policy" "github_actions_permissions" {
  name = "terraform-kafka-permissions"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "eks:CreateCluster",
          "eks:UpdateClusterConfig",
          "eks:DeleteCluster",
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:CreateNodegroup",
          "eks:DeleteNodegroup",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:Describe*",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "iam:PassRole",
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AmazonEKS*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/terraform-eks-*"
        ]
      },
      {
        Effect = "Allow",
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
        Resource = [
          "arn:aws:s3:::${var.terraform_state_bucket}",
          "arn:aws:s3:::${var.terraform_state_bucket}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"],
        Resource = "arn:aws:dynamodb:*:*:table/${var.dynamodb_table}"
      },
      {
        Effect = "Allow",
        Action = [
          "elasticloadbalancing:Describe*",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancer"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:PutDashboard",
          "cloudwatch:PutMetricAlarm",
          "logs:CreateLogGroup"
        ],
        Resource = "*"
      }
    ]
  })
}