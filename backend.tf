# Backend configuration for local development
# Copy this file to backend-local.tf and update with your values
#
# terraform init -backend-config=backend-local.tf

# terraform {
#   backend "s3" {
#     region         = "us-east-1"
#     bucket         = "your-terraform-state-bucket"
#     key            = "kafka-eks/terraform.tfstate"
#     dynamodb_table = "your-terraform-locks-table"
#   }
# }