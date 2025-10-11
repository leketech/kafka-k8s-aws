# kafka-k8s-aws
Apache Kafka on Kubernetes (EKS) using either the Strimzi operator or native StatefulSet, integrate it with AWS services, and test it with a simple producer/consumer.

## Overview
This project provides two approaches for deploying Apache Kafka on Amazon EKS:
1. **Strimzi Operator Approach** (default) - Uses the Strimzi Kubernetes operator for managing Kafka
2. **Native StatefulSet Approach** - Uses Kubernetes StatefulSets for direct control over Kafka and Zookeeper deployments

## Prerequisites
- AWS CLI configured
- Terraform >= 1.0
- kubectl
- An AWS account with appropriate permissions

## Deployment Approaches

### Strimzi Operator Approach (Default)
This approach uses the Strimzi operator to manage Kafka clusters. It provides a higher-level abstraction and handles many operational concerns automatically.

### Native StatefulSet Approach
This approach deploys Kafka and Zookeeper directly using Kubernetes StatefulSets, providing more granular control over the deployment but requiring more operational knowledge.

To use the StatefulSet approach, set the `kafka_deployment_type` variable to `"statefulset"` in your terraform.tfvars file:
```hcl
kafka_deployment_type = "statefulset"
```

For detailed information about the StatefulSet approach, see [StatefulSet Approach Documentation](docs/statefulset_approach.md).

## Backend Configuration

This project uses S3 backend for storing Terraform state. For local development:

1. Update `backend-local.hcl` with your actual S3 bucket name and DynamoDB table name

2. Initialize Terraform with the backend configuration:
   ```bash
   terraform init -backend-config=backend-local.hcl
   ```

Alternatively, you can provide the backend configuration directly as command-line arguments:
```bash
terraform init \
  -backend-config="bucket=my-terraform-state-kafka-eks-12345" \
  -backend-config="key=kafka-eks/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-locks"
```

## Quick Start
1. Clone this repository
2. Configure your AWS credentials
3. Update `terraform.tfvars` with your desired configuration
4. Configure the backend as described above
5. Run `terraform init -backend-config=backend-local.hcl`
6. Run `terraform apply`

## Directory Structure
- `.github/workflows/` - GitHub Actions for CI/CD
- `kafka/` - Kafka configurations and client code
- `modules/` - Terraform modules for different components
- `cloudwatch/` - CloudWatch dashboard configurations
- `docs/` - Documentation files

## Testing
Use the provided Python client in `kafka/kafka_client.py` to test your Kafka deployment.