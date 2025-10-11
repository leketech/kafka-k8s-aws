# Namespace for Kafka & Zookeeper deployment
variable "namespace" {
  description = "Kubernetes namespace for Kafka deployment"
  type        = string
  default     = "kafka"
}

# Number of Kafka replicas (brokers)
variable "kafka_replicas" {
  description = "Number of Kafka broker replicas"
  type        = number
  default     = 3
}

# Storage class to use for persistent volumes
variable "storage_class" {
  description = "Storage class for Kafka and Zookeeper persistent volumes"
  type        = string
  default     = "gp2"
}

# Kafka persistent volume size
variable "kafka_storage_size" {
  description = "Persistent volume size for Kafka"
  type        = string
  default     = "10Gi"
}

# Zookeeper persistent volume size
variable "zookeeper_storage_size" {
  description = "Persistent volume size for Zookeeper"
  type        = string
  default     = "10Gi"
}

# Deployment type: "statefulset" or "strimzi"
variable "kafka_deployment_type" {
  description = "Choose between 'strimzi', 'statefulset', or 'helm' for Kafka deployment"
  type        = string
  default     = "strimzi"
  
  validation {
    condition     = contains(["strimzi", "statefulset", "helm"], var.kafka_deployment_type)
    error_message = "kafka_deployment_type must be either 'strimzi', 'statefulset', or 'helm'."
  }
}

# AWS region where the EKS cluster is deployed
variable "aws_region" {
  description = "AWS region for the Kubernetes cluster"
  type        = string
  default     = "us-east-1"
}

# Name of the EKS cluster
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "kafka-eks"
}
