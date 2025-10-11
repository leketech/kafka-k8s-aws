terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

# ======================================================================
# STRIMZI KAFKA OPERATOR DEPLOYMENT
# ======================================================================
resource "helm_release" "strimzi" {
  count      = var.kafka_deployment_type == "strimzi" ? 1 : 0
  name       = "strimzi-kafka-operator"
  repository = "https://strimzi.io/charts/"
  chart      = "strimzi-kafka-operator"
  version    = "0.40.0"  # Updated to a newer version
  namespace  = var.namespace

  create_namespace = true

  set {
    name  = "watchNamespaces"
    value = "{${var.namespace}}"
  }
}

# ======================================================================
# STRIMZI CLUSTER CREATION (if using Strimzi)
# ======================================================================
resource "null_resource" "kafka_cluster" {
  count = var.kafka_deployment_type == "strimzi" ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF | kubectl apply -f -
      apiVersion: kafka.strimzi.io/v1beta2
      kind: Kafka
      metadata:
        name: kafka-cluster
        namespace: ${var.namespace}
      spec:
        kafka:
          version: "3.7.0"
          replicas: ${var.kafka_replicas}
          listeners:
            - name: plain
              port: 9092
              type: internal
              tls: false
            - name: tls
              port: 9093
              type: internal
              tls: true
          config:
            offsets.topic.replication.factor: 3
            transaction.state.log.replication.factor: 3
            transaction.state.log.min.isr: 2
            default.replication.factor: 3
            min.insync.replicas: 2
            inter.broker.protocol.version: "3.7"
          storage:
            type: persistent-claim
            size: ${var.kafka_storage_size}
            class: ${var.storage_class}
            deleteClaim: false
        zookeeper:
          replicas: 3
          storage:
            type: persistent-claim
            size: ${var.zookeeper_storage_size}
            class: ${var.storage_class}
            deleteClaim: false
        entityOperator:
          topicOperator: {}
          userOperator: {}
      EOF
    EOT
  }

  depends_on = [helm_release.strimzi]
}

# ======================================================================
# STATEFULSET DEPLOYMENT (Manual Kafka & Zookeeper)
# ======================================================================

resource "kubernetes_namespace" "kafka" {
  count = var.kafka_deployment_type == "statefulset" && var.namespace != "default" ? 1 : 0

  metadata {
    name = var.namespace
  }
}

# -------------------------- #
# Zookeeper Headless Service #
# -------------------------- #
resource "kubernetes_service" "zookeeper_headless" {
  count = var.kafka_deployment_type == "statefulset" ? 1 : 0

  metadata {
    name      = "zookeeper-headless"
    namespace = var.namespace
  }

  spec {
    cluster_ip = "None"
    selector = {
      app = "zookeeper"
    }

    port {
      port        = 2181
      target_port = 2181
      name        = "client"
    }
    port {
      port        = 2888
      target_port = 2888
      name        = "follower"
    }
    port {
      port        = 3888
      target_port = 3888
      name        = "election"
    }
  }
}

# -------------------------- #
# Zookeeper StatefulSet      #
# -------------------------- #
resource "kubernetes_stateful_set" "zookeeper" {
  count = var.kafka_deployment_type == "statefulset" ? 1 : 0

  metadata {
    name      = "zookeeper"
    namespace = var.namespace
    // Add annotation to force recreation
    annotations = {
      "recreate-timestamp" = timestamp()
    }
  }

  timeouts {
    create = "20m"
    update = "20m"
    delete = "10m"
  }

  wait_for_rollout = false

  spec {
    service_name          = "zookeeper-headless"
    replicas              = 3
    pod_management_policy = "Parallel"

    update_strategy {
      type = "RollingUpdate"
    }

    selector {
      match_labels = {
        app = "zookeeper"
      }
    }

    template {
      metadata {
        labels = {
          app = "zookeeper"
        }
      }

      spec {
        init_container {
          name    = "init-myid"
          image   = "busybox:1.35"
          command = ["sh", "-c"]
          args = [
            "ORDINAL=$${HOSTNAME##*-} && echo $$((ORDINAL + 1)) > /data/myid && echo \"Set myid to $$((ORDINAL + 1))\""
          ]

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
        }

        container {
          name  = "zookeeper"
          image = "zookeeper:3.8"

          port {
            container_port = 2181
            name           = "client"
          }
          port {
            container_port = 2888
            name           = "follower"
          }
          port {
            container_port = 3888
            name           = "election"
          }

          env {
            name  = "ZOO_SERVERS"
            value = "server.1=zookeeper-0.zookeeper-headless.${var.namespace}.svc.cluster.local:2888:3888;2181 server.2=zookeeper-1.zookeeper-headless.${var.namespace}.svc.cluster.local:2888:3888;2181 server.3=zookeeper-2.zookeeper-headless.${var.namespace}.svc.cluster.local:2888:3888;2181"
          }

          env {
            name  = "ZOO_STANDALONE_ENABLED"
            value = "false"
          }

          env {
            name  = "ZOO_ADMINSERVER_ENABLED"
            value = "true"
          }

          env {
            name  = "ZOO_4LW_COMMANDS_WHITELIST"
            value = "srvr,mntr,ruok"
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }

          liveness_probe {
            tcp_socket {
              port = 2181
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          readiness_probe {
            tcp_socket {
              port = 2181
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.storage_class

        resources {
          requests = {
            storage = var.zookeeper_storage_size
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service.zookeeper_headless
  ]
}

# -------------------------- #
# Zookeeper Service          #
# -------------------------- #
resource "kubernetes_service" "zookeeper" {
  count = var.kafka_deployment_type == "statefulset" ? 1 : 0

  metadata {
    name      = "zookeeper"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "zookeeper"
    }

    port {
      port        = 2181
      target_port = 2181
      name        = "client"
    }
  }
}

# -------------------------- #
# Kafka Headless Service     #
# -------------------------- #
resource "kubernetes_service" "kafka_headless" {
  count = var.kafka_deployment_type == "statefulset" ? 1 : 0

  metadata {
    name      = "kafka-headless"
    namespace = var.namespace
  }

  spec {
    cluster_ip = "None"
    selector = {
      app = "kafka"
    }

    port {
      port        = 9092
      target_port = 9092
      name        = "kafka"
    }
  }
}

# -------------------------- #
# Kafka StatefulSet          #
# -------------------------- #
resource "kubernetes_stateful_set" "kafka" {
  count = var.kafka_deployment_type == "statefulset" ? 1 : 0

  metadata {
    name      = "kafka"
    namespace = var.namespace
    // Add annotation to force recreation
    annotations = {
      "recreate-timestamp" = timestamp()
    }
  }

  timeouts {
    create = "20m"
    update = "20m"
    delete = "10m"
  }

  wait_for_rollout = false

  spec {
    service_name          = "kafka-headless"
    replicas              = var.kafka_replicas
    pod_management_policy = "Parallel"

    update_strategy {
      type = "RollingUpdate"
    }

    selector {
      match_labels = {
        app = "kafka"
      }
    }

    template {
      metadata {
        labels = {
          app = "kafka"
        }
      }

      spec {
        container {
          name  = "kafka"
          image = "bitnami/kafka:3.4.0"

          port {
            container_port = 9092
            name           = "kafka"
          }

          env {
            name  = "KAFKA_CFG_ZOOKEEPER_CONNECT"
            value = "zookeeper:2181"
          }
          env {
            name  = "KAFKA_CFG_LISTENERS"
            value = "PLAINTEXT://:9092"
          }
          env {
            name  = "KAFKA_CFG_ADVERTISED_LISTENERS"
            value = "PLAINTEXT://$(POD_NAME).kafka-headless.${var.namespace}.svc.cluster.local:9092"
          }
          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
          env {
            name  = "KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR"
            value = "3"
          }
          env {
            name  = "KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR"
            value = "3"
          }
          env {
            name  = "KAFKA_CFG_TRANSACTION_STATE_LOG_MIN_ISR"
            value = "2"
          }
          env {
            name  = "ALLOW_PLAINTEXT_LISTENER"
            value = "yes"
          }
          env {
            name  = "KAFKA_HEAP_OPTS"
            value = "-Xmx512m -Xms512m"
          }

          resources {
            requests = {
              memory = "1Gi"
              cpu    = "250m"
            }
            limits = {
              memory = "2Gi"
              cpu    = "1000m"
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/bitnami/kafka"
          }

          readiness_probe {
            tcp_socket {
              port = 9092
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          liveness_probe {
            tcp_socket {
              port = 9092
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 6
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.storage_class

        resources {
          requests = {
            storage = var.kafka_storage_size
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service.zookeeper,
    kubernetes_stateful_set.zookeeper
  ]
}

# -------------------------- #
# Kafka Service              #
# -------------------------- #
resource "kubernetes_service" "kafka" {
  count = var.kafka_deployment_type == "statefulset" ? 1 : 0

  metadata {
    name      = "kafka"
    namespace = var.namespace
  }

  spec {
    type = "ClusterIP"
    selector = {
      app = "kafka"
    }

    port {
      port        = 9092
      target_port = 9092
      name        = "kafka"
    }
  }
}