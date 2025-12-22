# MCP Proxy Secrets Update Guide

The MCP proxy requires API tokens and credentials to access all your K3s services. These are stored as a Kubernetes Secret.

## Location of Secret

**Kubernetes Secret:** `mcp-proxy-env` in namespace `mcp-proxy`

**Manifest File:** `D:\claude\k3s-deployment\manifests\mcp-proxy\03-secrets.yaml`

## How to Update Secrets

### Method 1: Edit the manifest file and re-apply (Recommended)

1. Edit `manifests/mcp-proxy/03-secrets.yaml`
2. Replace all `CHANGEME_*` values with your actual tokens
3. Apply to cluster:
   ```bash
   kubectl apply -f manifests/mcp-proxy/03-secrets.yaml
   ```
4. Restart MCP proxy to load new secrets:
   ```bash
   kubectl rollout restart deployment/mcp-proxy-server -n mcp-proxy
   ```

### Method 2: Direct kubectl edit (Quick updates)

```bash
kubectl edit secret mcp-proxy-env -n mcp-proxy
```

Then restart the deployment:
```bash
kubectl rollout restart deployment/mcp-proxy-server -n mcp-proxy
```

## Required Tokens and Where to Get Them

### 1. AdGuard Home
- **Variables:** `ADGUARD_USERNAME`, `ADGUARD_PASSWORD`
- **Where:** Your AdGuard admin credentials
- **URL:** http://10.0.0.240 or AdGuard web interface

### 2. Authentik API Token
- **Variable:** `AUTHENTIK_API_TOKEN`
- **Where:** https://auth.k3s.dahan.house/if/admin/#/core/tokens
- **Steps:**
  1. Log in to Authentik admin
  2. Go to Directory → Tokens
  3. Click "Create" → "Token"
  4. Set description and expiry
  5. Copy the token

### 3. Rancher API Token
- **Variable:** `RANCHER_API_TOKEN`
- **Where:** https://rancher.k3s.dahan.house/dashboard/account
- **Steps:**
  1. Click your profile icon
  2. Go to "API & Keys"
  3. Click "Create API Key"
  4. Set description and scope
  5. Copy token (format: `token-xxxxx:xxxxxxxxxx`)

### 4. Home Assistant Long-Lived Access Token
- **Variable:** `HOMEASSISTANT_TOKEN`
- **Where:** https://home.k3s.dahan.house/profile
- **Steps:**
  1. Go to your profile
  2. Scroll to "Long-Lived Access Tokens"
  3. Click "Create Token"
  4. Name it "MCP Proxy"
  5. Copy the token immediately (shown only once)

### 5. n8n API Key
- **Variable:** `N8N_API_KEY`
- **Where:** https://n8n.k3s.dahan.house/settings/api
- **Steps:**
  1. Go to Settings → API
  2. Click "Create API Key"
  3. Copy the key

### 6. Portainer
- **Variables:** `PORTAINER_USERNAME`, `PORTAINER_PASSWORD`
- **Where:** Your Portainer admin credentials
- **URL:** https://portainer.k3s.dahan.house

### 7. Nautobot API Token
- **Variable:** `NAUTOBOT_API_TOKEN`
- **Already Set:** `0123456789abcdef0123456789abcdef01234567`
- **To Create New:** https://nautobot.k3s.dahan.house/user/api-tokens/
- **Steps:**
  1. Log in to Nautobot (admin / nautobot123)
  2. Go to your profile → API Tokens
  3. Click "Add Token"
  4. Copy the token

### 8. PostgreSQL
- **Variables:** `POSTGRES_USERNAME`, `POSTGRES_PASSWORD`
- **Default User:** `superset`
- **Set your password:** The password you use for postgres

### 9. GitHub Token
- **Variable:** `GITHUB_TOKEN`
- **Where:** https://github.com/settings/tokens
- **Steps:**
  1. Go to Settings → Developer settings → Personal access tokens → Tokens (classic)
  2. Click "Generate new token (classic)"
  3. Set description: "MCP Proxy Config Access"
  4. Select scope: `repo` (or just `public_repo` for public repos)
  5. Click "Generate token"
  6. Copy the token immediately

## Example Update Command

```bash
# SSH to K3s server
ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210

# Edit the secret
kubectl edit secret mcp-proxy-env -n mcp-proxy

# Or delete and recreate from manifest
cd /tmp/k3s-deployment
git pull
kubectl delete secret mcp-proxy-env -n mcp-proxy
kubectl apply -f manifests/mcp-proxy/03-secrets.yaml

# Restart deployment to load new secrets
kubectl rollout restart deployment/mcp-proxy-server -n mcp-proxy

# Check status
kubectl get pods -n mcp-proxy
kubectl logs -n mcp-proxy -l app.kubernetes.io/name=mcp-proxy --tail=50
```

## Security Best Practices

1. ✅ Secrets are stored in Kubernetes (encrypted at rest if enabled)
2. ✅ Never commit real tokens to Git (only CHANGEME placeholders)
3. ✅ Rotate tokens regularly (every 90 days recommended)
4. ✅ Use least-privilege tokens when possible
5. ✅ Monitor token usage in service logs

## Verification

After updating secrets, verify the MCP proxy can access services:

```bash
# Check pod logs for errors
kubectl logs -n mcp-proxy -l app.kubernetes.io/name=mcp-proxy --tail=100

# Test health endpoint
kubectl exec -n mcp-proxy deployment/mcp-proxy-server -- curl -s http://localhost:3010/health

# Check from outside cluster
curl -k https://mcp.k3s.dahan.house/health
```
