#!/bin/bash
#
# Fleet GitOps Setup Script for K3s Cluster
# This script configures Fleet to watch the GitHub repository
#
# Usage: bash cluster-setup.sh
# Or: curl -sSL https://raw.githubusercontent.com/yochanan2007/k3s/main/cluster-setup.sh | bash

set -e

echo "=== Fleet GitOps Setup for K3s ==="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}ERROR: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

echo -e "${GREEN}kubectl found${NC}"

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${NC}"
    echo "Make sure your kubeconfig is configured correctly"
    exit 1
fi

echo -e "${GREEN}Cluster connection successful${NC}"
echo ""

# Check Fleet is installed
echo "Checking Fleet installation..."
if ! kubectl get namespace cattle-fleet-system &> /dev/null; then
    echo -e "${RED}ERROR: Fleet is not installed (cattle-fleet-system namespace not found)${NC}"
    echo "Please install Fleet first: https://fleet.rancher.io/installation"
    exit 1
fi

echo -e "${GREEN}Fleet is installed${NC}"

# Check Fleet controller is running
FLEET_READY=$(kubectl get deployment fleet-controller -n cattle-fleet-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "$FLEET_READY" = "0" ]; then
    echo -e "${YELLOW}WARNING: Fleet controller is not ready${NC}"
    echo "Checking Fleet controller status..."
    kubectl get deployment fleet-controller -n cattle-fleet-system
else
    echo -e "${GREEN}Fleet controller is running (${FLEET_READY} replicas ready)${NC}"
fi
echo ""

# Check if fleet-local namespace exists
echo "Checking fleet-local namespace..."
if ! kubectl get namespace fleet-local &> /dev/null; then
    echo -e "${YELLOW}Creating fleet-local namespace...${NC}"
    kubectl create namespace fleet-local
    echo -e "${GREEN}Namespace created${NC}"
else
    echo -e "${GREEN}fleet-local namespace exists${NC}"
fi
echo ""

# Check if GitRepo already exists
echo "Checking for existing GitRepo..."
if kubectl get gitrepo k3s-manifests -n fleet-local &> /dev/null; then
    echo -e "${YELLOW}GitRepo 'k3s-manifests' already exists${NC}"
    echo ""
    echo "Current status:"
    kubectl get gitrepo k3s-manifests -n fleet-local
    echo ""
    read -p "Do you want to delete and recreate it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing GitRepo..."
        kubectl delete gitrepo k3s-manifests -n fleet-local
        echo -e "${GREEN}Deleted${NC}"
        sleep 2
    else
        echo "Keeping existing GitRepo. Exiting."
        exit 0
    fi
fi
echo ""

# Create GitRepo resource
echo "Creating Fleet GitRepo resource..."

cat <<EOF | kubectl apply -f -
---
apiVersion: fleet.cattle.io/v1alpha1
kind: GitRepo
metadata:
  name: k3s-manifests
  namespace: fleet-local
spec:
  repo: https://github.com/yochanan2007/k3s.git
  branch: main
  paths:
  - manifests/
  pollingInterval: 15s
  targets: []
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}GitRepo created successfully!${NC}"
else
    echo -e "${RED}Failed to create GitRepo${NC}"
    exit 1
fi
echo ""

# Wait for GitRepo to initialize
echo "Waiting for GitRepo to initialize (10 seconds)..."
sleep 10
echo ""

# Check GitRepo status
echo "Checking GitRepo status..."
kubectl get gitrepo k3s-manifests -n fleet-local
echo ""

# Show detailed status
echo "Detailed GitRepo status:"
kubectl describe gitrepo k3s-manifests -n fleet-local | grep -A 5 "Status:"
echo ""

# Check bundles
echo "Checking Fleet Bundles..."
kubectl get bundles -n fleet-local
echo ""

# Show summary
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "GitRepo 'k3s-manifests' has been created in namespace 'fleet-local'"
echo "Fleet will now automatically sync from: https://github.com/yochanan2007/k3s"
echo ""
echo "Monitoring commands:"
echo -e "${YELLOW}  kubectl get gitrepo k3s-manifests -n fleet-local${NC}"
echo -e "${YELLOW}  kubectl describe gitrepo k3s-manifests -n fleet-local${NC}"
echo -e "${YELLOW}  kubectl get bundles -n fleet-local${NC}"
echo -e "${YELLOW}  kubectl logs -n cattle-fleet-system deployment/fleet-controller -f${NC}"
echo ""
echo "To verify deployed resources:"
echo -e "${YELLOW}  kubectl get all -n adguard${NC}"
echo -e "${YELLOW}  kubectl get all -n cert-manager${NC}"
echo -e "${YELLOW}  kubectl get helmchartconfig traefik -n kube-system${NC}"
echo ""
echo -e "${GREEN}GitOps is now active! Push changes to GitHub main branch to auto-deploy.${NC}"
