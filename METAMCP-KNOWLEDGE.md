# MetaMCP Infrastructure Knowledge Base

This document provides context for Claude Code to understand the MCP (Model Context Protocol) infrastructure in this k3s cluster.

## Current Architecture (December 2025)

### Overview
```
┌────────────────────────────────────────────────────────┐
│              Claude Code Client                        │
│      https://metamcp.k3s.dahan.house/metamcp          │
└───────────────────┬────────────────────────────────────┘
                    │ (API Key Auth)
                    ▼
┌────────────────────────────────────────────────────────┐
│              MetaMCP Gateway                           │
│  • Web UI for server management                        │
│  • Tool filtering & cherry-picking                     │
│  • Namespace organization                              │
│  • API key authentication                              │
└──┬────────────┬────────────┬──────────────────────────┘
   │            │            │
   ▼            ▼            ▼
┌─────────┐ ┌─────────┐ ┌──────────────────┐
│k3s-proxy│ │  code   │ │  Future servers  │
│         │ │executor │ │  (add via GitOps)│
└─────────┘ └─────────┘ └──────────────────┘
```

### Core Components

#### 1. MetaMCP Gateway
- **Purpose**: Centralized MCP server aggregator with web UI
- **Namespace**: `metamcp`
- **URL**: https://metamcp.k3s.dahan.house
- **Image**: ghcr.io/metatool-ai/metamcp:latest
- **Database**: PostgreSQL 16
- **Ports**: 12008 (frontend), 12009 (backend)

**Key Features**:
- Web dashboard for managing servers
- Tool cherry-picking (select specific tools to expose)
- Namespace-based organization
- API key authentication for secure access
- Real-time server status monitoring
- Built-in MCP inspector for debugging

#### 2. k3s-proxy (Cluster Services MCP)
- **Purpose**: Provides MCP tools for cluster services
- **Namespace**: `mcp-proxy`
- **URL**: http://mcp-proxy.mcp-proxy.svc.cluster.local:80/mcp
- **Transport**: SSE (Server-Sent Events)

**Exposed Services**:
- AdGuard Home (DNS management)
- Authentik (SSO/Identity)
- Rancher (Cluster management)
- Home Assistant (IoT)
- n8n (Workflow automation)
- Traefik (Ingress)
- PostgreSQL (Database)
- RustDesk (Remote desktop)
- Nautobot (Network automation)

#### 3. code-executor (Python Sandbox)
- **Purpose**: Token-efficient code execution with API access
- **Namespace**: `mcp-executor`
- **URL**: http://mcp-code-executor.mcp-executor.svc.cluster.local:80/mcp
- **Transport**: SSE

**Key Features**:
- Python code execution in isolated sandbox
- Pre-configured Portainer API client
- Token efficiency: ~200 tokens vs 10,000+ for traditional tools
- Automatic cleanup after execution

**Available in sandbox**:
```python
import portainer_client as pc

# Pre-authenticated Portainer access
containers = pc.list_containers(endpoint_id=1)
pc.start_container(endpoint_id=1, container_id="...")
pc.container_logs(endpoint_id=1, container_id="...", tail=100)
```

## Understanding User Prompts

### When User Says: "Deploy [service] MCP"

**Examples**:
- "Deploy authentik MCP"
- "Deploy Home Assistant MCP"
- "Add PostgreSQL MCP server"

**What This Means**:
1. User wants to add a new MCP server for that service
2. The service is likely already running in k3s
3. Need to create MCP server manifests that expose tools for that service

**How to Respond**:

1. **Check if service exists**:
   ```bash
   kubectl get svc -A | grep authentik
   ```

2. **Determine service type**:
   - REST API → Create HTTP MCP server
   - GraphQL → Create GraphQL MCP wrapper
   - CLI tool → Create STDIO MCP server

3. **Create manifests** using the template in `scripts/add-mcp-server.sh`

4. **Add to MetaMCP** via ConfigMap or Web UI

### When User Says: "List all containers in Portainer"

**What This Means**:
User wants to execute Python code via the code-executor to interact with Portainer.

**How to Respond**:
```python
import portainer_client as pc

containers = pc.list_containers(endpoint_id=1, all=True)

result = []
for c in containers:
    result.append({
        'name': c['Names'][0].lstrip('/'),
        'image': c['Image'],
        'status': c['Status'],
        'state': c['State']
    })

print(f"Total containers: {len(result)}")
for container in result:
    print(f"- {container['name']}: {container['state']} ({container['image']})")
```

This leverages the code-executor's token efficiency.

## GitOps Workflow

### Adding a New MCP Server

**Method 1: Via ConfigMap (Quick)**
```bash
# 1. Edit ConfigMap
kubectl edit configmap metamcp-config -n metamcp

# 2. Add server to servers.json section:
{
  "my-new-server": {
    "type": "SSE",
    "url": "http://service.namespace.svc.cluster.local:80/mcp",
    "description": "What this server does",
    "enabled": true
  }
}

# 3. MetaMCP auto-reloads (no restart needed)
```

**Method 2: Via GitHub (Production)**
```bash
# 1. Create server definition file
# File: mcp-config/servers/my-service.json
{
  "name": "my-service",
  "type": "SSE",
  "url": "http://my-service.namespace.svc.cluster.local:80/mcp",
  "description": "My service MCP tools",
  "enabled": true
}

# 2. Run update script
./scripts/update-metamcp-servers.sh

# This merges all server files and updates ConfigMap
```

**Method 3: Via Web UI**
1. Open https://metamcp.k3s.dahan.house
2. Login with credentials
3. Navigate to **Servers** → **Add New**
4. Fill in form
5. Click **Save**

## Common Operations

### Check MetaMCP Status
```bash
kubectl get pods -n metamcp
kubectl logs -n metamcp -l app.kubernetes.io/component=server
```

### View Configured Servers
```bash
kubectl get configmap metamcp-config -n metamcp -o jsonpath='{.data.servers\.json}' | jq
```

### Restart MetaMCP
```bash
kubectl rollout restart deployment/metamcp -n metamcp
```

### Update MetaMCP Version
```bash
# Uses :latest tag, so just restart to pull new image
kubectl rollout restart deployment/metamcp -n metamcp
```

### Test Server Connectivity
```bash
# From within MetaMCP pod
kubectl exec -n metamcp deployment/metamcp -- wget -O- http://mcp-proxy.mcp-proxy.svc.cluster.local:80/health
```

## Security Configuration

### API Key Authentication

**Generate Key**:
1. Login to https://metamcp.k3s.dahan.house
2. Settings → API Keys
3. Click "Generate New Key"
4. Copy immediately (shown once!)

**Use in Claude Code**:
```json
{
  "mcpServers": {
    "k3s-metamcp": {
      "url": "https://metamcp.k3s.dahan.house/metamcp/default/sse",
      "transport": "sse",
      "headers": {
        "Authorization": "Bearer YOUR_API_KEY"
      }
    }
  }
}
```

### Tool Filtering

**Via Web UI**:
1. Navigate to **Namespaces** → **Edit**
2. Select/deselect tools to expose
3. Save

**Via Configuration**:
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
1. Create OIDC provider in Authentik
2. Update `manifests/metamcp/k8s/02-secrets.yaml`
3. Uncomment OIDC variables
4. Apply: `kubectl apply -f manifests/metamcp/k8s/02-secrets.yaml`
5. Restart: `kubectl rollout restart deployment/metamcp -n metamcp`

## File Locations

### Configuration
- **MetaMCP Manifests**: `manifests/metamcp/k8s/*.yaml`
- **Server Definitions**: ConfigMap `metamcp-config` in namespace `metamcp`
- **Secrets**: Secret `metamcp-secrets` in namespace `metamcp`

### Scripts
- **Add Server**: `scripts/add-mcp-server.sh`
- **Update Servers**: `scripts/update-metamcp-servers.sh`
- **Deploy All**: `scripts/deploy-metamcp.sh`

### Documentation
- **Main README**: `manifests/metamcp/README.md`
- **This File**: `METAMCP-KNOWLEDGE.md`
- **Architecture**: `MCP-PROXY-ARCHITECTURE.md`

## Troubleshooting

### MetaMCP Pod Not Starting

**Check logs**:
```bash
kubectl logs -n metamcp -l app.kubernetes.io/component=server --tail=100
```

**Common issues**:
- Database migration failed → Check PostgreSQL is running
- Permission errors → Check HOME env vars set to /tmp
- Image pull error → Verify ghcr.io access

### Server Not Showing in MetaMCP

**Verify server is reachable**:
```bash
kubectl exec -n metamcp deployment/metamcp -- wget -O- http://SERVER_URL/health
```

**Check ConfigMap**:
```bash
kubectl get configmap metamcp-config -n metamcp -o yaml
```

### Token Efficiency Not Working

**Verify code-executor is configured**:
```bash
kubectl get pods -n mcp-executor
kubectl logs -n mcp-executor -l app.kubernetes.io/name=mcp-executor
```

**Check server is in MetaMCP**:
- Login to MetaMCP UI
- Verify "code-executor" appears in server list
- Status should be "Connected"

## Migration Notes

### From mcp-hub to MetaMCP

**What Changed**:
- ✅ Web UI added (was API-only)
- ✅ PostgreSQL backend (was stateless)
- ✅ API key auth (was open)
- ✅ Tool filtering (was all-or-nothing)
- ✅ Better namespace organization

**Configuration Updates**:
- Old endpoint: `https://mcp-hub.k3s.dahan.house/mcp`
- New endpoint: `https://metamcp.k3s.dahan.house/metamcp/<namespace>/sse`

**Data Migration**:
No data migration needed - servers are reconfigured from scratch in MetaMCP.

## Best Practices

### 1. Use Token-Efficient Patterns

**Bad** (10,000+ tokens):
```
Use k3s-proxy:portainer_list_containers tool
```

**Good** (~200 tokens):
```python
# Via code-executor
import portainer_client as pc
containers = pc.list_containers(endpoint_id=1)
# Process in sandbox, return summary only
```

### 2. Organize by Namespace

Group related servers:
- `cluster-management`: k3s-proxy, rancher-tools
- `code-execution`: code-executor, python-sandbox
- `monitoring`: prometheus-mcp, grafana-mcp

### 3. Use Descriptive Names

**Bad**: `server1`, `test`, `new`
**Good**: `authentik-sso`, `home-assistant-iot`, `postgres-db`

### 4. Version Control

Always commit server configurations to git:
```bash
git add mcp-config/servers/new-server.json
git commit -m "feat: Add new-server MCP integration"
git push origin main
```

## Future Enhancements

### Planned Features
- [ ] Kubernetes service discovery (auto-detect services)
- [ ] Helm chart for easier deployment
- [ ] Prometheus metrics export
- [ ] Multi-cluster support
- [ ] Rate limiting per API key
- [ ] Advanced RBAC with Authentik groups

### To Add More Services

When environment grows, follow this pattern:

1. **Deploy Service** (if not already running)
2. **Create MCP Server** for that service
3. **Add to MetaMCP** via GitOps or UI
4. **Test Tools** using MetaMCP inspector
5. **Document** in this knowledge base
6. **Update** .mcp.json in Claude Code

---

**Last Updated**: December 23, 2025
**MetaMCP Version**: Latest (ghcr.io/metatool-ai/metamcp:latest)
**Cluster**: k3s at 10.0.0.210
