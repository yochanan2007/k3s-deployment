# MCP Proxy Deployment Guide

This guide walks through deploying the MCP Proxy server to your k3s cluster.

## Prerequisites

1. Docker installed for building the image
2. Access to k3s cluster at 10.0.0.210
3. SSH key configured at `C:/Users/John/.ssh/docker_key`
4. kubectl configured to access the cluster (or SSH access)
5. Docker registry (local or remote) for storing the image

## Deployment Steps

### Option 1: Automated Deployment (Recommended)

Use the provided deployment script:

```bash
cd manifests/mcp-proxy
chmod +x build-and-deploy.sh

# Build image, push to registry, and deploy
./build-and-deploy.sh all

# Or run steps individually
./build-and-deploy.sh build   # Build Docker image
./build-and-deploy.sh push    # Push to registry
./build-and-deploy.sh deploy  # Deploy to k3s
./build-and-deploy.sh status  # Check deployment status
```

### Option 2: Manual Deployment

#### Step 1: Build Docker Image

```bash
cd manifests/mcp-proxy
docker build -t mcp-proxy:1.0.0 .
```

#### Step 2: Push to Registry

If using a local registry:
```bash
docker tag mcp-proxy:1.0.0 localhost:5000/mcp-proxy:1.0.0
docker push localhost:5000/mcp-proxy:1.0.0
```

Or load directly into k3s (for testing):
```bash
docker save mcp-proxy:1.0.0 | ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210 "sudo k3s ctr images import -"
```

#### Step 3: Update Configuration

Edit `01-config.yaml` to set your GitHub repository URL:
```yaml
CONFIG_REPO_URL: "https://raw.githubusercontent.com/YOURUSERNAME/k3s-deployment/main/mcp-proxy-config.json"
```

#### Step 4: Apply Manifests

```bash
# Via SSH
ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210

# Apply in order
kubectl apply -f /path/to/00-namespace.yaml
kubectl apply -f /path/to/01-config.yaml
kubectl apply -f /path/to/02-rbac.yaml
kubectl apply -f /path/to/03-secrets.yaml
kubectl apply -f /path/to/04-deployment.yaml
kubectl apply -f /path/to/05-service.yaml
kubectl apply -f /path/to/06-ingress.yaml
kubectl apply -f /path/to/07-certificate.yaml

# Or apply entire directory
kubectl apply -f /path/to/manifests/mcp-proxy/
```

#### Step 5: Verify Deployment

```bash
# Check pods
kubectl get pods -n mcp-proxy

# Check services
kubectl get svc -n mcp-proxy

# Check ingress
kubectl get ingress -n mcp-proxy

# Check certificate
kubectl get certificate -n mcp-proxy

# View logs
kubectl logs -n mcp-proxy deployment/mcp-proxy-server -f
```

## Configuration

### GitOps Configuration File

The server reads its configuration from GitHub. Ensure the file at the configured URL (`mcp-proxy-config.json`) is accessible:

```json
{
  "version": "1.0.0",
  "services": { ... },
  "tools": {
    "kubernetes_enabled": true,
    "adguard_enabled": true,
    ...
  }
}
```

The server will:
- Fetch this config on startup
- Reload every 5 minutes automatically
- Fall back to defaults if fetch fails

### API Tokens (Optional)

If you want to use Authentik or Rancher APIs, generate tokens and add them to the secret:

```bash
# Generate Authentik API token (via UI or API)
AUTHENTIK_TOKEN="your-token-here"

# Generate Rancher API token (via UI)
RANCHER_TOKEN="token-xxxxx:xxxxxxxxx"

# Update secret
kubectl create secret generic mcp-proxy-api-tokens \
  --from-literal=AUTHENTIK_API_TOKEN="${AUTHENTIK_TOKEN}" \
  --from-literal=RANCHER_API_TOKEN="${RANCHER_TOKEN}" \
  --namespace=mcp-proxy \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart deployment to pick up new secrets
kubectl rollout restart deployment/mcp-proxy-server -n mcp-proxy
```

## Accessing the MCP Proxy

### Health Check

```bash
curl https://mcp.k3s.dahan.house/health
```

Expected response:
```json
{
  "status": "healthy",
  "version": "1.0.0"
}
```

### MCP Endpoint

The MCP endpoint is available at:
```
https://mcp.k3s.dahan.house/mcp
```

### From Claude Code

Update your `.mcp.json`:
```json
{
  "mcpServers": {
    "k3s-cluster": {
      "type": "http",
      "url": "https://mcp.k3s.dahan.house/mcp"
    }
  }
}
```

## Troubleshooting

### Pod not starting

```bash
# Check events
kubectl describe pod -n mcp-proxy

# Check logs
kubectl logs -n mcp-proxy deployment/mcp-proxy-server

# Common issues:
# - Image pull error: Ensure image is in registry and ImagePullPolicy is correct
# - RBAC issues: Check ServiceAccount permissions
# - Config issues: Check ConfigMap values
```

### Config not loading from GitHub

The server will log errors if config fetch fails. Check logs:
```bash
kubectl logs -n mcp-proxy deployment/mcp-proxy-server | grep -i config
```

Possible issues:
- URL incorrect in ConfigMap
- GitHub rate limiting (use authentication or local config)
- Network policies blocking egress

### Certificate not issuing

```bash
# Check certificate status
kubectl describe certificate mcp-tls -n mcp-proxy

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

Ensure:
- ClusterIssuer `letsencrypt-dns` exists
- Cloudflare API token is valid
- DNS record for `mcp.k3s.dahan.house` points to Traefik LoadBalancer

### kubectl commands failing in pod

Ensure RBAC permissions are correct:
```bash
# Test from pod
kubectl exec -n mcp-proxy deployment/mcp-proxy-server -- kubectl get pods -A

# Check ServiceAccount
kubectl get serviceaccount mcp-proxy -n mcp-proxy -o yaml

# Check ClusterRoleBinding
kubectl get clusterrolebinding mcp-proxy-binding -o yaml
```

## Monitoring

### View Logs

```bash
# Follow logs
kubectl logs -n mcp-proxy deployment/mcp-proxy-server -f

# Last 100 lines
kubectl logs -n mcp-proxy deployment/mcp-proxy-server --tail=100

# Previous pod (if crashed)
kubectl logs -n mcp-proxy deployment/mcp-proxy-server --previous
```

### Resource Usage

```bash
kubectl top pod -n mcp-proxy
```

### Events

```bash
kubectl get events -n mcp-proxy --sort-by='.lastTimestamp'
```

## Updating

### Update Configuration

Simply edit `mcp-proxy-config.json` in GitHub and push. The server will reload it automatically within 5 minutes.

Or force reload by restarting:
```bash
kubectl rollout restart deployment/mcp-proxy-server -n mcp-proxy
```

### Update Server Code

1. Make changes to `mcp-proxy-server.js`
2. Rebuild image with new tag
3. Update deployment image
4. Rollout restart

```bash
./build-and-deploy.sh all
```

## Security Considerations

1. **RBAC**: The proxy has ClusterRole permissions. Review `02-rbac.yaml` carefully.
2. **Network**: Consider adding NetworkPolicy to restrict egress.
3. **Authentication**: Currently no auth on MCP endpoint. Add Traefik middleware for BasicAuth if needed.
4. **Secrets**: API tokens are stored as Kubernetes secrets. Use external secret management for production.
5. **Image**: Build from source and scan for vulnerabilities before deploying.

## Uninstalling

```bash
kubectl delete namespace mcp-proxy
kubectl delete clusterrole mcp-proxy-role
kubectl delete clusterrolebinding mcp-proxy-binding
```
