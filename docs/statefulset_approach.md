# Kafka StatefulSet Approach

This document explains the StatefulSet approach for deploying Kafka on Kubernetes, which is an alternative to the default Strimzi Operator approach.

## Overview

The StatefulSet approach directly manages Kafka and Zookeeper using Kubernetes StatefulSets, providing more granular control over the deployment but requiring more operational knowledge.

## Architecture

```
graph TB
    A[Kafka Client] --> B[Kafka Service]
    B --> C[Kafka StatefulSet]
    C --> D[Zookeeper Service]
    D --> E[Zookeeper StatefulSet]
    C --> F[Persistent Volumes]
    E --> G[Persistent Volumes]
```

## Components

### Zookeeper StatefulSet

- **Replicas**: 3 (for high availability)
- **Image**: confluentinc/cp-zookeeper:7.5.0
- **Storage**: 20Gi gp3 PersistentVolumes
- **Ports**: 2181 (client), 2888 (peer), 3888 (leader-election)

### Kafka StatefulSet

- **Replicas**: 3 (for high availability)
- **Image**: confluentinc/cp-kafka:7.5.0
- **Storage**: 50Gi gp3 PersistentVolumes
- **Ports**: 9092 (client)

### Services

1. **zookeeper** - ClusterIP service for client connections
2. **zookeeper-headless** - Headless service for peer communication
3. **kafka-service** - LoadBalancer service for external client connections
4. **kafka-headless** - Headless service for internal Kafka communication

## Advantages

1. **Direct Control**: Full control over Kafka and Zookeeper configurations
2. **No Operator Dependency**: Doesn't require the Strimzi operator
3. **Customization**: Easier to customize for specific requirements
4. **Learning**: Better for understanding Kafka internals

## Disadvantages

1. **Operational Complexity**: Requires more operational knowledge
2. **Manual Management**: No automatic rebalancing or rolling updates
3. **Monitoring**: Requires manual setup of monitoring and alerting
4. **Maintenance**: More manual work for upgrades and maintenance

## Configuration

The StatefulSet approach can be enabled by setting the `kafka_deployment_type` variable to `"statefulset"` in your terraform.tfvars file:

```hcl
kafka_deployment_type = "statefulset"
```

## Testing

After deployment, you can test the Kafka cluster using the provided client:

```bash
# Get the Kafka service endpoint
kubectl get svc kafka-service -n kafka -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Set the bootstrap server
export KAFKA_BOOTSTRAP=<hostname>:9092

# Produce a message
python kafka/kafka_client.py --produce "Hello, StatefulSet Kafka!"

# Consume messages
python kafka/kafka_client.py --consume
```

## Health Checks

Use the provided test script to verify the deployment:

```bash
python kafka/test_statefulset.py
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n kafka
```

### Check Logs

```bash
kubectl logs -n kafka zookeeper-0
kubectl logs -n kafka kafka-0
```

### Check Services

```bash
kubectl get svc -n kafka
```