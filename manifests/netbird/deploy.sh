#!/bin/bash

# Netbird Deployment Script
# This script deploys Netbird client to the k3s cluster

set -e

echo "========================================="
echo "Deploying Netbird Client to k3s Cluster"
echo "========================================="
echo ""

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Apply manifests in order
echo "1. Creating namespace..."
kubectl apply -f "$SCRIPT_DIR/00-namespace.yaml"
echo ""

echo "2. Creating PersistentVolumeClaim..."
kubectl apply -f "$SCRIPT_DIR/01-netbird-pvc.yaml"
echo ""

echo "3. Deploying Netbird client..."
kubectl apply -f "$SCRIPT_DIR/02-netbird-deployment.yaml"
echo ""

echo "4. Creating ClusterIP service..."
kubectl apply -f "$SCRIPT_DIR/03-netbird-service.yaml"
echo ""

echo "5. Creating LoadBalancer service..."
kubectl apply -f "$SCRIPT_DIR/04-netbird-service-lb.yaml"
echo ""

echo "6. Creating Ingress..."
kubectl apply -f "$SCRIPT_DIR/05-netbird-ingress.yaml"
echo ""

echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""

echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=netbird-client -n netbird --timeout=120s || true
echo ""

echo "Current status:"
echo "---------------"
kubectl get all -n netbird
echo ""

echo "LoadBalancer IP:"
echo "----------------"
kubectl get svc netbird-lb -n netbird -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo ""
echo ""

echo "Ingress:"
echo "--------"
kubectl get ingress -n netbird
echo ""

echo "========================================="
echo "View logs with:"
echo "  kubectl logs -n netbird -l app.kubernetes.io/name=netbird-client -f"
echo ""
echo "Check Netbird status:"
echo "  kubectl exec -n netbird -it <pod-name> -- netbird status"
echo "========================================="
