variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
  sensitive   = false

  validation {
    condition = contains([
      "us-east-1", "us-east-2", "us-west-1", "us-west-2",
      "eu-west-1", "eu-central-1", "ap-southeast-1", "ap-northeast-1"
      # Add more as needed
    ], var.aws_region)
    error_message = "The aws_region value must be a valid AWS region identifier."
  }
}

variable "cluster_name" {
  description = "EKS cluster name (must be lowercase, DNS-compatible)"
  type        = string
  default     = "kafka-eks"
  sensitive   = false

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name)) && length(var.cluster_name) <= 32
    error_message = "Cluster name must be lowercase, alphanumeric, hyphens only, and ≤32 chars."
  }
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "m5.large"
  sensitive   = false

  validation {
    condition     = length(split(".", var.node_instance_type)) >= 2
    error_message = "Instance type must be in format like 'm5.large', 't3.medium', etc."
  }
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform remote state (required for team use)"
  type        = string
  sensitive   = false

  # No default → forces user to set it (good for remote state)
}

variable "dynamodb_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  sensitive   = false

  # No default → required
}

variable "kafka_deployment_type" {
  description = "Choose between 'strimzi' or 'statefulset' for Kafka deployment"
  type        = string
  default     = "strimzi"
  sensitive   = false

  validation {
    condition     = contains(["strimzi", "statefulset"], var.kafka_deployment_type)
    error_message = "kafka_deployment_type must be either 'strimzi' or 'statefulset'."
  }
}