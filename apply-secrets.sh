#!/bin/bash
# Script to create Kubernetes secrets from .env file
# This script should be run on the k3s master node

set -e

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    echo "Please copy .env file to this directory first"
    exit 1
fi

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

echo "Creating secrets in k3s cluster..."

# Create Cloudflare API token secret for kube-system (Traefik)
echo "Creating cloudflare-api-token secret in kube-system namespace..."
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=$CLOUDFLARE_API_TOKEN \
  -n kube-system \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Cloudflare API token secret for cert-manager
echo "Creating cloudflare-api-token secret in cert-manager namespace..."
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=$CLOUDFLARE_API_TOKEN \
  -n cert-manager \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Cloudflare API token secret for adguard
echo "Creating cloudflare-api-token secret in adguard namespace..."
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=$CLOUDFLARE_API_TOKEN \
  -n adguard \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Traefik dashboard auth secret
echo "Creating traefik-dashboard-auth secret in kube-system namespace..."
kubectl create secret generic traefik-dashboard-auth \
  --from-literal=users="$TRAEFIK_DASHBOARD_AUTH" \
  -n kube-system \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Cloudflare API token secret for authentik
echo "Creating cloudflare-api-token secret in authentik namespace..."
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=$CLOUDFLARE_API_TOKEN \
  -n authentik \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Authentik PostgreSQL credentials
echo "Creating authentik-postgresql secret in authentik namespace..."
kubectl create secret generic authentik-postgresql \
  --from-literal=username=$AUTHENTIK_DB_USER \
  --from-literal=password=$AUTHENTIK_DB_PASSWORD \
  -n authentik \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Authentik secret key
echo "Creating authentik-secret-key secret in authentik namespace..."
kubectl create secret generic authentik-secret-key \
  --from-literal=secret_key=$AUTHENTIK_SECRET_KEY \
  -n authentik \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Cloudflare API token secret for cattle-system (Rancher)
echo "Creating cloudflare-api-token secret in cattle-system namespace..."
kubectl create secret generic cloudflare-api-token \
  --from-literal=api-token=$CLOUDFLARE_API_TOKEN \
  -n cattle-system \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✅ All secrets created successfully!"
echo ""
echo "Note: These secrets are now stored in the cluster."
echo "The .env file should be kept secure and never committed to Git."
