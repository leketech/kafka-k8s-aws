output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_token" {
  description = "EKS cluster auth token"
  value       = data.aws_eks_cluster_auth.kafka.token
  sensitive   = true
}

output "kubeconfig" {
  description = "Command to configure kubectl to connect to the EKS cluster"
  value       = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region}"
}

output "kafka_bootstrap_host" {
  description = "Command to get the external Kafka bootstrap hostname (run after deployment completes)"
  value       = "kubectl get svc my-kafka-kafka-external-bootstrap -n kafka -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}