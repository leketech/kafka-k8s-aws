# Deploying Kafka with StatefulSet Implementation

This guide provides step-by-step instructions for deploying Kafka using the StatefulSet approach.

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0 installed
3. kubectl installed and configured
4. An AWS account with permissions to create:
   - EKS cluster
   - S3 bucket for Terraform state
   - DynamoDB table for state locking

## Deployment Steps

### 1. Configure Backend

Update [backend-local.hcl](file:///mnt/c/Users/Leke/kafka/kafka-k8s-aws/backend-local.hcl) with your actual S3 bucket and DynamoDB table names:

```hcl
region         = "us-east-1"
bucket         = "your-actual-terraform-state-bucket-name"
key            = "kafka-eks/terraform.tfstate"
dynamodb_table = "your-actual-dynamodb-table-name"
```

### 2. Set Deployment Type

Ensure [terraform.tfvars](file:///mnt/c/Users/Leke/kafka/kafka-k8s-aws/terraform.tfvars) has the StatefulSet deployment type:

```hcl
kafka_deployment_type = "statefulset"
```

### 3. Initialize Terraform

Run one of these commands:

**Option A: Using backend configuration file**
```bash
terraform init -backend-config=backend-local.hcl
```

**Option B: Using command-line arguments**
```bash
terraform init \
  -backend-config="bucket=your-actual-terraform-state-bucket-name" \
  -backend-config="key=kafka-eks/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=your-actual-dynamodb-table-name"
```

### 4. Validate Configuration

```bash
terraform validate
```

### 5. Review Plan

```bash
terraform plan
```

### 6. Deploy

```bash
terraform apply
```

## What Gets Deployed

With the StatefulSet approach, you'll get:

1. **ZooKeeper StatefulSet**:
   - 3 pods (zookeeper-0, zookeeper-1, zookeeper-2)
   - Persistent volumes for data storage
   - Headless service (zookeeper-headless) and regular service (zookeeper)

2. **Kafka StatefulSet**:
   - 3 pods (kafka-statefulset-0, kafka-statefulset-1, kafka-statefulset-2)
   - Persistent volumes for data storage
   - Headless service (kafka-headless) and LoadBalancer service (kafka-service)

3. **Fluent Bit**:
   - DaemonSet running on all nodes
   - ConfigMap with CloudWatch configuration

## Verification

After deployment, verify the resources:

```bash
kubectl get pods -n kafka
kubectl get svc -n kafka
```

## Testing

Use the provided Kafka client to test producer/consumer functionality:

```bash
# Get the Kafka service endpoint
kubectl get svc kafka-service -n kafka

# Set the bootstrap server (replace with actual hostname)
export KAFKA_BOOTSTRAP=<hostname>:9092

# Produce a message
python kafka/kafka_client.py --produce "Hello, StatefulSet Kafka!"

# Consume messages
python kafka/kafka_client.py --consume
```

## Cleanup

To remove all resources:

```bash
terraform destroy
```