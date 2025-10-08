variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  type        = string
}

variable "cluster_token" {
  description = "EKS cluster auth token"
  type        = string
}

variable "kafka_deployment_type" {
  description = "Choose between 'strimzi' or 'statefulset' for Kafka deployment"
  type        = string
  default     = "strimzi"
}