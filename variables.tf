variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
  sensitive   = false

  validation {
    condition = contains([
      "us-east-1", "us-east-2", "us-west-1", "us-west-2",
      "eu-west-1", "eu-central-1", "ap-southeast-1", "ap-northeast-1"
    ], var.aws_region)
    error_message = "The aws_region value must be a valid AWS region identifier."
  }
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "kafka-eks"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform remote state (required for team use)"
  type        = string
  sensitive   = false
}

variable "dynamodb_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  sensitive   = false
}

variable "kafka_deployment_type" {
  description = "Choose between 'strimzi', 'statefulset', or 'helm' for Kafka deployment"
  type        = string
  default     = "strimzi"
  sensitive   = false

  validation {
    condition     = contains(["strimzi", "statefulset", "helm"], var.kafka_deployment_type)
    error_message = "kafka_deployment_type must be either 'strimzi', 'statefulset', or 'helm'."
  }
}

variable "create_kubernetes_resources" {
  description = "Whether to create Kubernetes resources"
  type        = bool
  default     = true
}