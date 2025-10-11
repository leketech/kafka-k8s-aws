resource "aws_iam_role" "eks_admin" {
  name = "eks-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::907849381252:root"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "eks_admin_policy" {
  name = "eks-admin-policy"
  role = aws_iam_role.eks_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:*",
          "ec2:*",
          "iam:PassRole",
          "iam:GetRole",
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:ListRoles",
          "cloudformation:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the role to the EKS cluster as an access entry
resource "aws_eks_access_entry" "eks_admin" {
  cluster_name  = "kafka-eks"
  principal_arn = aws_iam_role.eks_admin.arn
  type          = "STANDARD"
}