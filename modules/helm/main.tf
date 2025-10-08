# ----------------------------
# Helm Releases Module
# ----------------------------

# ----------------------------
# Install Strimzi Operator via Helm
# ----------------------------
resource "helm_release" "strimzi" {
  name       = "strimzi-kafka-operator"
  repository = "https://strimzi.io/charts/"
  chart      = "strimzi-kafka-operator"
  version    = "0.40.0"
  namespace  = var.namespace
}