output "strimzi_release_name" {
  description = "Strimzi Helm release name"
  value       = helm_release.strimzi.name
}

output "strimzi_chart_version" {
  description = "Strimzi Helm chart version"
  value       = helm_release.strimzi.version
}