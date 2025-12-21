# Pre-Deployment Checklist

Before deploying the MCP Proxy to the k3s cluster, complete these steps:

## 1. Update GitHub Repository URL

Edit `01-config.yaml` and update the CONFIG_REPO_URL to point to your actual GitHub repository:

```yaml
CONFIG_REPO_URL: "https://raw.githubusercontent.com/YOURUSERNAME/k3s-deployment/main/mcp-proxy-config.json"
```

Replace `YOURUSERNAME` with your actual GitHub username.

## 2. Build and Push Docker Image

The deployment requires a Docker image. You have two options:

### Option A: Use a Docker Registry

```bash
# Build the image
cd manifests/mcp-proxy
docker build -t mcp-proxy:1.0.0 .

# Tag for your registry
docker tag mcp-proxy:1.0.0 YOUR_REGISTRY/mcp-proxy:1.0.0

# Push to registry
docker push YOUR_REGISTRY/mcp-proxy:1.0.0

# Update 04-deployment.yaml with the full image path
sed -i 's|image: mcp-proxy:1.0.0|image: YOUR_REGISTRY/mcp-proxy:1.0.0|' 04-deployment.yaml
```

### Option B: Load Directly into k3s (Testing Only)

```bash
# Build the image
cd manifests/mcp-proxy
docker build -t mcp-proxy:1.0.0 .

# Save and load into k3s
docker save mcp-proxy:1.0.0 | ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210 "sudo k3s ctr images import -"

# Update deployment to use IfNotPresent
# (Already set in 04-deployment.yaml)
```

## 3. Commit Configuration to GitHub

Make sure `mcp-proxy-config.json` is committed to the repository root:

```bash
git add mcp-proxy-config.json
git commit -m "Add MCP proxy configuration"
git push origin main
```

## 4. Configure API Tokens (Optional)

If you want to enable Authentik or Rancher API access:

### Generate Authentik API Token
1. Log into Authentik at https://auth.k3s.dahan.house
2. Go to Admin Interface → Tokens
3. Create new token with appropriate permissions
4. Save the token value

### Generate Rancher API Token
1. Log into Rancher at https://rancher.k3s.dahan.house
2. Click your user icon → API & Keys
3. Create new API key
4. Save the token value

### Update the Secret
Edit `03-secrets.yaml` and replace the empty strings:

```yaml
stringData:
  AUTHENTIK_API_TOKEN: "your-actual-authentik-token"
  RANCHER_API_TOKEN: "your-actual-rancher-token"
```

## 5. Verify Prerequisites

Ensure these exist in the cluster:

```bash
# Check ClusterIssuer for certificates
ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210 "kubectl get clusterissuer letsencrypt-dns"

# Check Traefik is running
ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210 "kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik"

# Check wildcard cert exists (optional - cert-manager will create new one if needed)
ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210 "kubectl get certificate -A | grep k3s-dahan-house"
```

## 6. Deploy

Once all prerequisites are met:

```bash
# Deploy all manifests
cd manifests/mcp-proxy
for f in *.yaml; do
  echo "Applying $f..."
  cat "$f" | ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210 "kubectl apply -f -"
done

# Check deployment status
ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210 "kubectl get all -n mcp-proxy"

# Watch pod startup
ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210 "kubectl logs -n mcp-proxy -l app.kubernetes.io/name=mcp-proxy -f"
```

## 7. Verify Deployment

```bash
# Check health endpoint
curl https://mcp.k3s.dahan.house/health

# Check certificate
ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210 "kubectl get certificate mcp-tls -n mcp-proxy"

# Test MCP endpoint (will need MCP client)
# Update .mcp.json and test with Claude Code
```

## 8. Update .mcp.json

After successful deployment, update your local `.mcp.json`:

```json
{
  "mcpServers": {
    "localproxy": {
      "type": "http",
      "url": "http://localhost:3006/mcp"
    },
    "k3s-cluster": {
      "type": "http",
      "url": "https://mcp.k3s.dahan.house/mcp"
    }
  }
}
```

Restart Claude Code to load the new MCP server.

## Troubleshooting

If deployment fails, check:

1. **Image pull errors**: Verify image exists in registry or was loaded into k3s
2. **RBAC errors**: Check ServiceAccount and ClusterRoleBinding exist
3. **Config errors**: Verify GitHub URL is accessible and returns valid JSON
4. **Certificate errors**: Check cert-manager logs and ClusterIssuer status
5. **Network errors**: Verify Traefik ingress is routing correctly

See DEPLOYMENT.md for detailed troubleshooting steps.
