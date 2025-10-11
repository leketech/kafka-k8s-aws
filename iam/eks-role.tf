data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eks_inline_policy" {
  statement {
    actions = [
      "ec2:Describe*",
      "eks:Describe*",
      "eks:List*",
      "iam:Get*",
      "iam:List*",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role" "this" {
  name               = "eks-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy" "eks_inline" {
  name   = "eks-inline-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.eks_inline_policy.json
}