#!/usr/bin/env python3
"""
Test script for Kafka StatefulSet deployment.
This script checks if the Kafka StatefulSet pods are running correctly.
"""

import subprocess
import sys
import time

def run_command(command):
    """Run a shell command and return the output."""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running command '{command}': {e}")
        print(f"stderr: {e.stderr}")
        return None

def check_pods(namespace, label):
    """Check if pods with the given label are running in the namespace."""
    command = f"kubectl get pods -n {namespace} -l {label} -o jsonpath='{{.items[*].status.phase}}'"
    output = run_command(command)
    
    if output is None:
        return False
    
    phases = output.split()
    return all(phase == "Running" for phase in phases)

def get_pod_names(namespace, label):
    """Get names of pods with the given label in the namespace."""
    command = f"kubectl get pods -n {namespace} -l {label} -o jsonpath='{{.items[*].metadata.name}}'"
    output = run_command(command)
    
    if output is None:
        return []
    
    return output.split()

def check_kafka_statefulset():
    """Check if Kafka StatefulSet is deployed and running."""
    print("Checking Kafka StatefulSet deployment...")
    
    # Check if the kafka namespace exists
    namespaces = run_command("kubectl get namespaces")
    if "kafka" not in namespaces:
        print("❌ Kafka namespace not found")
        return False
    
    # Check Zookeeper pods
    print("Checking Zookeeper pods...")
    zk_pods_running = check_pods("kafka", "app=zookeeper")
    if zk_pods_running:
        print("✅ All Zookeeper pods are running")
        zk_pod_names = get_pod_names("kafka", "app=zookeeper")
        print(f"   Zookeeper pods: {', '.join(zk_pod_names)}")
    else:
        print("❌ Some Zookeeper pods are not running")
        return False
    
    # Check Kafka pods
    print("Checking Kafka pods...")
    kafka_pods_running = check_pods("kafka", "app=kafka")
    if kafka_pods_running:
        print("✅ All Kafka pods are running")
        kafka_pod_names = get_pod_names("kafka", "app=kafka")
        print(f"   Kafka pods: {', '.join(kafka_pod_names)}")
    else:
        print("❌ Some Kafka pods are not running")
        return False
    
    # Check services
    print("Checking Kafka services...")
    services = run_command("kubectl get svc -n kafka -o jsonpath='{.items[*].metadata.name}'")
    if services and "kafka-service" in services and "kafka-headless" in services:
        print("✅ Kafka services are available")
    else:
        print("❌ Kafka services not found")
        return False
    
    print("✅ Kafka StatefulSet deployment is healthy!")
    return True

def main():
    """Main function."""
    print("Kafka StatefulSet Health Check")
    print("=" * 30)
    
    # Check if kubectl is available
    if run_command("kubectl version --client") is None:
        print("❌ kubectl is not available. Please install kubectl and configure it to connect to your cluster.")
        sys.exit(1)
    
    # Check if we can connect to the cluster
    if run_command("kubectl cluster-info") is None:
        print("❌ Cannot connect to Kubernetes cluster. Please ensure kubectl is configured correctly.")
        sys.exit(1)
    
    # Check Kafka StatefulSet
    if not check_kafka_statefulset():
        print("\n❌ Kafka StatefulSet health check failed!")
        sys.exit(1)
    
    print("\n🎉 All checks passed! Kafka StatefulSet is running correctly.")

if __name__ == "__main__":
    main()