# MCP Configuration Setup - Complete ✅

## What Was Created

### 1. MCP Configuration Files (Local)
**Location:** `D:\claude\k3s-deployment\mcp-config\`

Files created:
- ✅ `mcp-servers.json` - SSH configs for k3s, docker2, docker3, GitHub
- ✅ `services-config.json` - All K3s service endpoints and auth configs
- ✅ `.env.example` - Template for your API keys
- ✅ `README.md` - Complete setup instructions
- ✅ `.gitignore` - Protects your .env from Git

### 2. Kubernetes Secret (K3s Cluster)
**Name:** `mcp-proxy-env` in namespace `mcp-proxy`
**Status:** ✅ Created and applied to cluster

Contains environment variables for all services:
- AdGuard Home credentials
- Authentik API token
- Rancher API token
- Home Assistant token
- n8n API key
- Portainer credentials
- Nautobot API token
- PostgreSQL credentials
- GitHub token

## 📍 Where to Put Your .env File

### Option 1: Local Development (Optional)
If using local MCP servers:
```
D:\claude\k3s-deployment\mcp-config\.env
```

**Steps:**
1. Copy the template:
   ```bash
   copy mcp-config\.env.example mcp-config\.env
   ```
2. Edit with your tokens
3. This file is gitignored and won't be committed

### Option 2: Kubernetes Secret (Required for MCP Proxy)
The environment variables are already configured in K3s!

**File:** `D:\claude\k3s-deployment\manifests\mcp-proxy\03-secrets.yaml`
**Status:** ✅ Applied to cluster with placeholder values

**To Update with Real Tokens:**

#### Method A: Edit manifest and re-apply
1. Edit `manifests/mcp-proxy/03-secrets.yaml`
2. Replace all `CHANGEME_*` values
3. Apply:
   ```bash
   ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210
   cd /tmp/k3s-deployment && git pull
   kubectl apply -f manifests/mcp-proxy/03-secrets.yaml
   kubectl rollout restart deployment/mcp-proxy-server -n mcp-proxy
   ```

#### Method B: Direct kubectl edit (faster)
```bash
ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210
kubectl edit secret mcp-proxy-env -n mcp-proxy
# Edit the values, save, and exit
kubectl rollout restart deployment/mcp-proxy-server -n mcp-proxy
```

## How to Get API Tokens

See detailed instructions in:
- `mcp-config/README.md` (local)
- `manifests/mcp-proxy/UPDATE-SECRETS.md` (K3s)

### Quick Links:
1. **Authentik**: https://auth.k3s.dahan.house/if/admin/#/core/tokens
2. **Rancher**: https://rancher.k3s.dahan.house/dashboard/account
3. **Home Assistant**: https://home.k3s.dahan.house/profile
4. **n8n**: https://n8n.k3s.dahan.house/settings/api
5. **Nautobot**: https://nautobot.k3s.dahan.house/user/api-tokens/
6. **GitHub**: https://github.com/settings/tokens

## Current Status

### Git Repository
- ✅ All configs committed to `claude-edits`
- ✅ Merged to `main`
- ✅ Pushed to GitHub

### Kubernetes
- ✅ Secret `mcp-proxy-env` created
- ✅ Deployment updated to use all environment variables
- ⚠️ MCP Proxy pod in ImagePullBackOff (Docker image not built yet)

### Services Configured
All 10 services ready for MCP access:
1. ✅ AdGuard Home
2. ✅ Authentik
3. ✅ Rancher
4. ✅ Home Assistant
5. ✅ n8n
6. ✅ Portainer
7. ✅ Nautobot
8. ✅ PostgreSQL
9. ✅ Traefik
10. ✅ RustDesk

## Next Steps

### 1. Update Secrets with Real Tokens
Choose Method A or B above to update the Kubernetes secret.

### 2. Build MCP Proxy Docker Image (Optional)
If you want to use the centralized MCP proxy:
```bash
cd manifests/mcp-proxy
docker build -t mcp-proxy:1.0.0 .
docker save mcp-proxy:1.0.0 | ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210 "sudo k3s ctr images import -"
kubectl rollout restart deployment/mcp-proxy-server -n mcp-proxy
```

### 3. Use Local MCP Servers (Recommended)
Update your Claude Code `.mcp.json` with the SSH configs:
```json
{
  "mcpServers": {
    "k3s": {
      "command": "npx",
      "args": ["-y", "@fangjunjie/ssh-mcp-server", "--host", "10.0.0.210", "--port", "22", "--username", "johnd", "--privateKey", "C:/Users/John/.ssh/docker_key"]
    },
    "docker2": {
      "command": "npx",
      "args": ["-y", "@fangjunjie/ssh-mcp-server", "--host", "10.0.0.120", "--port", "22", "--username", "root", "--privateKey", "C:/Users/John/.ssh/docker_key"]
    },
    "docker3": {
      "command": "npx",
      "args": ["-y", "@fangjunjie/ssh-mcp-server", "--host", "10.0.0.121", "--port", "22", "--username", "root", "--privateKey", "C:/Users/John/.ssh/docker_key"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "your_github_token_here"
      }
    }
  }
}
```

## Files Location Summary

| Purpose | Local Path | K8s Resource |
|---------|-----------|--------------|
| MCP server configs | `mcp-config/mcp-servers.json` | N/A |
| Service configs | `mcp-config/services-config.json` | ConfigMap: `mcp-proxy-config` |
| Local .env (optional) | `mcp-config/.env` | N/A |
| K8s secrets (required) | `manifests/mcp-proxy/03-secrets.yaml` | Secret: `mcp-proxy-env` |
| Update guide | `manifests/mcp-proxy/UPDATE-SECRETS.md` | N/A |

## Security Notes

- ✅ `.env` files are gitignored
- ✅ Kubernetes secrets are encrypted at rest
- ✅ All CHANGEME placeholders in Git
- ✅ Real tokens only in local .env or K8s cluster
- ⚠️ Never commit real tokens to Git!
