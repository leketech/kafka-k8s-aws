# IAM Policy for Fluent Bit (logs) + CloudWatch Agent (metrics)
resource "aws_iam_policy" "cloudwatch_k8s_policy" {
  name        = "${var.cluster_name}-cloudwatch-policy"
  description = "Policy for EKS nodes to write to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:TagLogGroup"  # 👈 CRITICAL: Required for Fluent Bit
        ],
        # Scope to your cluster's log groups
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/*:*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:PutMetricData"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeTags"
        ],
        # These are read-only and require "*" (no ARN-level permissions)
        Resource = "*"
      }
    ]
  })
}

# Get AWS account ID for ARN construction
data "aws_caller_identity" "current" {}

# IAM Role for EKS worker nodes
resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  policy_arn = aws_iam_policy.cloudwatch_k8s_policy.arn
  role       = module.eks.iam_role_name
}