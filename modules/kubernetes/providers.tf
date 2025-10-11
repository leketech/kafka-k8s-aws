# Provider alias for the Kubernetes module
# This will be passed from the root module
provider "kubernetes" {
  alias = "k8s_module"
}