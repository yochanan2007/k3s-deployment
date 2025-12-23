# MetaMCP - Unified MCP Server Gateway

## Overview

MetaMCP is a centralized MCP aggregator, orchestrator, middleware, and gateway that provides a web UI for managing all your MCP servers from one dashboard.

**Web UI:** https://metamcp.k3s.dahan.house
**MCP Endpoint:** https://metamcp.k3s.dahan.house/metamcp/<endpoint-name>/sse

## Features

- 🎛️ **Web UI Dashboard**: Visual interface for managing all MCP servers
- 🔄 **Dynamic Server Management**: Add/remove/configure servers without pod restarts
- 📊 **Tool Cherry-Picking**: Select specific tools to expose per namespace
- 🔐 **API Key Authentication**: Secure access to MCP endpoints
- 🔌 **Multiple Transports**: STDIO, SSE, and HTTP support
- 🏷️ **Namespaces**: Group servers and organize tools logically
- 🧪 **Built-in Inspector**: Debug and test MCP servers

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Claude Code                          │
│            https://metamcp.k3s.dahan.house/mcp              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                      MetaMCP Server                          │
│  - Web UI (port 12008)                                      │
│  - PostgreSQL backend                                       │
│  - Tool filtering & namespaces                              │
│  - API key authentication                                   │
└─┬──────────────┬──────────────┬───────────────────────────┘
  │              │              │
  ▼              ▼              ▼
┌──────────┐  ┌──────────┐  ┌──────────────────────┐
│ k3s-proxy│  │   code   │  │  Future servers      │
│          │  │ executor │  │  (add via GitOps)    │
└──────────┘  └──────────┘  └──────────────────────┘
```

## Deployed Components

### 1. MetaMCP Server
- **Namespace:** `metamcp`
- **Image:** `ghcr.io/metatool-ai/metamcp:latest`
- **Port:** 12008
- **Resources:** 512Mi-2Gi RAM, 200m-1000m CPU

### 2. PostgreSQL Database
- **Image:** `postgres:16-alpine`
- **Storage:** 5Gi PVC (local-path)
- **Resources:** 256Mi-512Mi RAM, 100m-500m CPU

## Current MCP Servers

MetaMCP aggregates these MCP servers:

### 1. **k3s-proxy** (Internal Cluster Services)
- **URL:** http://mcp-proxy.mcp-proxy.svc.cluster.local:80/mcp
- **Type:** SSE (Server-Sent Events)
- **Tools:** AdGuard, Authentik, Rancher, Home Assistant, n8n, etc.
- **Status:** ✅ Enabled

### 2. **code-executor** (Python Sandbox)
- **URL:** http://mcp-code-executor.mcp-executor.svc.cluster.local:80/mcp
- **Type:** SSE
- **Tool:** execute_python (with pre-configured Portainer client)
- **Token Efficiency:** ~200 tokens vs 10,000+ for traditional tools
- **Status:** ✅ Enabled

## GitOps Workflow for Adding New Servers

### Option 1: Via ConfigMap (Recommended for Simple Cases)

1. **Edit the ConfigMap:**
   ```bash
   kubectl edit configmap metamcp-config -n metamcp
   ```

2. **Add your server to `servers.json`:**
   ```json
   {
     "k3s-proxy": { ... },
     "code-executor": { ... },
     "my-new-server": {
       "type": "SSE",
       "url": "http://my-service.my-namespace.svc.cluster.local:80/mcp",
       "description": "My new MCP server",
       "enabled": true
     }
   }
   ```

3. **Save and exit** - MetaMCP will auto-reload configuration

### Option 2: Via GitHub (Recommended for Production)

1. **Create a new file in `mcp-config/servers/`:**
   ```bash
   # Create file: mcp-config/servers/authentik-mcp.json
   {
     "name": "authentik-sso",
     "type": "SSE",
     "url": "http://authentik-mcp.authentik.svc.cluster.local:80/mcp",
     "description": "Authentik SSO management tools",
     "enabled": true,
     "namespace": "sso-tools"
   }
   ```

2. **Commit and push to GitHub:**
   ```bash
   git add mcp-config/servers/authentik-mcp.json
   git commit -m "feat: Add Authentik MCP server"
   git push origin main
   ```

3. **Apply via script:**
   ```bash
   ./scripts/update-metamcp-servers.sh
   ```

   This script will:
   - Merge all `mcp-config/servers/*.json` files
   - Update the ConfigMap
   - Trigger MetaMCP reload

### Option 3: Via Web UI

1. Navigate to https://metamcp.k3s.dahan.house
2. Go to **Servers** → **Add New Server**
3. Fill in the form:
   - **Name:** my-new-server
   - **Type:** SSE/STDIO/HTTP
   - **URL:** http://service.namespace.svc.cluster.local/mcp
   - **Description:** What this server does
4. Click **Save**

## Deployment

### Initial Deployment

```bash
# 1. Update secrets (required!)
vim manifests/metamcp/k8s/02-secrets.yaml
# Change: POSTGRES_PASSWORD, BETTER_AUTH_SECRET

# 2. Generate Better Auth Secret
openssl rand -base64 32

# 3. Apply all manifests
cat manifests/metamcp/k8s/*.yaml | ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210 "kubectl apply -f -"

# 4. Wait for deployment
ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210 "kubectl get pods -n metamcp -w"

# 5. Check logs
ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210 "kubectl logs -n metamcp -l app.kubernetes.io/component=server --tail=50"
```

### Update Configuration

```bash
# Edit ConfigMap
kubectl edit configmap metamcp-config -n metamcp

# MetaMCP will auto-reload (no restart needed)
```

### Update MetaMCP Version

```bash
# MetaMCP uses 'latest' tag, so just restart to pull new image
kubectl rollout restart deployment/metamcp -n metamcp
```

## Configuration

### Environment Variables

Set in `k8s/02-secrets.yaml`:
- `POSTGRES_USER`: Database user (default: metamcp_user)
- `POSTGRES_PASSWORD`: **CHANGE THIS!**
- `POSTGRES_DB`: Database name (default: metamcp_db)
- `BETTER_AUTH_SECRET`: **CHANGE THIS!** (32+ characters)

Set in `k8s/03-config.yaml`:
- `APP_URL`: https://metamcp.k3s.dahan.house
- `NODE_ENV`: production
- `POSTGRES_HOST`: metamcp-postgres

### Server Configuration Format

In `servers.json` ConfigMap:
```json
{
  "server-name": {
    "type": "SSE|STDIO|HTTP",
    "url": "http://service.namespace.svc.cluster.local:80/mcp",
    "description": "What this server provides",
    "enabled": true,
    "namespace": "optional-namespace-for-grouping",
    "env": {
      "OPTIONAL_VAR": "value"
    }
  }
}
```

### Namespace & Endpoint Example

**Namespace:** Group related servers
```json
{
  "namespace": "cluster-management",
  "servers": ["k3s-proxy", "rancher-tools"]
}
```

**Endpoint:** Expose namespace as MCP endpoint
```
https://metamcp.k3s.dahan.house/metamcp/cluster-management/sse
```

## Security

### API Key Authentication

1. **Generate API Key in Web UI:**
   - Navigate to https://metamcp.k3s.dahan.house
   - Go to **Settings** → **API Keys**
   - Click **Generate New Key**
   - Copy the key (shown once!)

2. **Use API Key in Claude Code:**
   ```json
   {
     "mcpServers": {
       "k3s-metamcp": {
         "url": "https://metamcp.k3s.dahan.house/metamcp/<endpoint>/sse",
         "transport": "sse",
         "headers": {
           "Authorization": "Bearer YOUR_API_KEY_HERE"
         }
       }
     }
   }
   ```

### Tool Filtering

1. **Via Web UI:**
   - Navigate to **Namespaces** → **Edit**
   - Select which tools to expose
   - Save changes

2. **Via ConfigMap:**
   ```json
   {
     "namespace": "safe-tools",
     "allowed_tools": [
       "code-executor:execute_python",
       "k3s-proxy:adguard_get_status"
     ],
     "blocked_tools": [
       "k3s-proxy:kubernetes_delete_pod"
     ]
   }
   ```

### OIDC/SSO (Future)

To enable Authentik SSO:
1. Create OAuth2/OIDC provider in Authentik
2. Update `k8s/02-secrets.yaml` with OIDC variables
3. Restart MetaMCP deployment

## Verification

### Check Deployment Status

```bash
# Check pods
kubectl get pods -n metamcp

# Check services
kubectl get svc -n metamcp

# Check ingress
kubectl get ingress -n metamcp

# Check certificate
kubectl get certificate -n metamcp
```

### Test Web UI

```bash
# Check health
curl -k https://metamcp.k3s.dahan.house/api/health

# Should return: {"status":"ok"}
```

### Test MCP Endpoint

```bash
# List servers
curl -k https://metamcp.k3s.dahan.house/api/servers

# Should return JSON array of configured servers
```

## Troubleshooting

### Pod Not Starting

```bash
# Check logs
kubectl logs -n metamcp -l app.kubernetes.io/component=server

# Common issues:
# - Database not ready: Wait for postgres pod
# - Missing secrets: Update 02-secrets.yaml
# - Image pull error: Check ghcr.io access
```

### Database Connection Errors

```bash
# Check postgres pod
kubectl get pods -n metamcp -l app.kubernetes.io/component=database

# Test connection from metamcp pod
kubectl exec -n metamcp deployment/metamcp -- pg_isready -h metamcp-postgres -U metamcp_user
```

### Server Not Showing Up

```bash
# Check server URL is reachable from metamcp pod
kubectl exec -n metamcp deployment/metamcp -- wget -O- http://mcp-proxy.mcp-proxy.svc.cluster.local:80/health

# Check ConfigMap
kubectl get configmap metamcp-config -n metamcp -o yaml
```

### Certificate Issues

```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Describe certificate
kubectl describe certificate metamcp-tls -n metamcp

# Force renewal
kubectl delete secret metamcp-tls -n metamcp
```

## Migration from mcp-hub

**Differences:**
- ✅ Full web UI (vs API-only)
- ✅ API key authentication
- ✅ Tool filtering
- ✅ PostgreSQL backend (vs stateless)
- ✅ Namespaces for organization

**Configuration Changes:**
- Old: Edit ConfigMap `mcp-hub-config`
- New: Edit ConfigMap `metamcp-config` OR use Web UI

**Endpoint Changes:**
- Old: `https://mcp-hub.k3s.dahan.house/mcp`
- New: `https://metamcp.k3s.dahan.house/metamcp/<endpoint>/sse`

## Files

- `k8s/00-namespace.yaml` - Namespace definition
- `k8s/01-postgres-pvc.yaml` - PostgreSQL storage
- `k8s/02-secrets.yaml` - Secrets (passwords, auth keys)
- `k8s/03-config.yaml` - Application config + server registry
- `k8s/04-postgres-deployment.yaml` - PostgreSQL deployment
- `k8s/05-postgres-service.yaml` - PostgreSQL service
- `k8s/06-metamcp-deployment.yaml` - MetaMCP deployment
- `k8s/07-metamcp-service.yaml` - MetaMCP service
- `k8s/08-ingress.yaml` - Traefik ingress with TLS

## Resources

- [MetaMCP GitHub](https://github.com/metatool-ai/metamcp)
- [MetaMCP Documentation](https://docs.metamcp.com/)
- [Official Docker Image](https://github.com/metatool-ai/metamcp/pkgs/container/metamcp)
