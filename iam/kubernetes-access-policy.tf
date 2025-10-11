resource "aws_iam_policy" "kubernetes_access" {
  name        = "kubernetes-access-policy"
  description = "Policy for Kubernetes cluster access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeUpdate",
          "eks:ListUpdates"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:PassRole",
          "iam:ListRoles"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the EKS admin role
resource "aws_iam_role_policy_attachment" "kubernetes_access" {
  policy_arn = aws_iam_policy.kubernetes_access.arn
  role       = aws_iam_role.eks_admin.name
}