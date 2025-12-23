# MetaMCP Setup Guide

Complete guide for setting up and using MetaMCP with Claude Code.

## Quick Start (5 Minutes)

### 1. Access MetaMCP Web UI

Open https://metamcp.k3s.dahan.house in your browser.

**First-time login**: MetaMCP should allow you to create an admin account on first access.

### 2. Configure MCP Servers

In MetaMCP dashboard:

1. Navigate to **Servers** → **Add Server**

2. Add **k3s-proxy**:
   - Name: `k3s-proxy`
   - URL: `http://mcp-proxy.mcp-proxy.svc.cluster.local:80/mcp`
   - Transport: `SSE`
   - Description: `K3s cluster services`
   - Click **Save**

3. Add **code-executor**:
   - Name: `code-executor`
   - URL: `http://mcp-code-executor.mcp-executor.svc.cluster.local:80/mcp`
   - Transport: `SSE`
   - Description: `Python execution with Portainer`
   - Click **Save**

Wait a few seconds for servers to connect. Status should show "Connected" ✅

### 3. Generate API Key

1. In MetaMCP, go to **Settings** → **API Keys**
2. Click **Generate New Key**
3. **Copy the key immediately** (shown once!)
4. Store it securely

### 4. Configure Claude Code

1. Open Claude Code settings
2. Find MCP configuration file (usually `.mcp.json`)
3. Update with:

```json
{
  "mcpServers": {
    "k3s-metamcp": {
      "url": "https://metamcp.k3s.dahan.house/metamcp/default/sse",
      "transport": "sse",
      "headers": {
        "Authorization": "Bearer YOUR_API_KEY_HERE"
      }
    }
  }
}
```

4. Replace `YOUR_API_KEY_HERE` with your actual API key
5. Save and restart Claude Code

### 5. Test Connection

In Claude Code, ask:
```
List all Portainer containers
```

I should respond with a list of containers using the code-executor!

---

## Detailed Configuration

### MetaMCP Architecture

```
Claude Code
    ↓ (HTTPS + API Key)
MetaMCP Gateway (https://metamcp.k3s.dahan.house)
    ↓
├─ k3s-proxy (10+ cluster service tools)
└─ code-executor (Python sandbox with Portainer)
```

### Server Configuration Options

#### Option A: Via Web UI (Recommended for beginners)

1. Login to https://metamcp.k3s.dahan.house
2. **Servers** → **Add Server**
3. Fill in form and save
4. Immediate effect (no restart)

#### Option B: Via ConfigMap (For advanced users)

```bash
# Edit ConfigMap
kubectl edit configmap metamcp-config -n metamcp

# Add to servers.json section:
{
  "my-server": {
    "type": "SSE",
    "url": "http://service.namespace.svc.cluster.local:80/mcp",
    "description": "My service",
    "enabled": true
  }
}
```

#### Option C: Via GitOps (For production)

```bash
# 1. Create server config file
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

# 3. Commit to git
git add mcp-config/servers/my-service.json
git commit -m "feat: Add my-service MCP server"
git push origin main
```

### Tool Filtering (Security)

Limit which tools AI can access:

1. In MetaMCP UI: **Namespaces** → **Edit**
2. Select tools to expose:
   - ✅ `code-executor:execute_python`
   - ✅ `k3s-proxy:adguard_get_status`
   - ❌ `k3s-proxy:kubernetes_delete_pod` (blocked)
3. Save changes

This prevents AI from accessing dangerous operations.

### API Key Management

**Best Practices**:
- Generate separate keys for different users/clients
- Rotate keys periodically
- Revoke keys if compromised
- Use descriptive names: "claude-code-prod", "testing", etc.

**To Rotate**:
1. Generate new key in MetaMCP
2. Update Claude Code .mcp.json
3. Test connection works
4. Revoke old key

---

## Common Use Cases

### Use Case 1: List Containers

**Prompt to Claude**:
```
Show me all containers in Portainer
```

**What Happens**:
1. Claude uses `code-executor` server
2. Executes Python in sandbox:
   ```python
   import portainer_client as pc
   containers = pc.list_containers(endpoint_id=1)
   print(f"Total: {len(containers)}")
   ```
3. Returns summary (~200 tokens used)

**Why Token-Efficient**:
- Traditional MCP: Load all container data → 10,000+ tokens
- Code execution: Process in sandbox → 200 tokens

### Use Case 2: Manage AdGuard

**Prompt to Claude**:
```
Check AdGuard Home status
```

**What Happens**:
1. Claude uses `k3s-proxy` server
2. Calls `adguard_get_status` tool
3. Returns DNS statistics

### Use Case 3: Deploy New Service

**When You Say**: "Deploy authentik MCP"

**I Will**:
1. Check if Authentik service exists in k3s
2. Create MCP server configuration for Authentik
3. Add to MetaMCP via GitOps workflow
4. Test connectivity
5. Document available tools

---

## Adding New Services

### Automated Method

Use the helper script:

```bash
./scripts/add-mcp-server.sh authentik authentik 9000 SSE
```

This will:
- Create `mcp-config/servers/authentik-mcp.json`
- Optionally update MetaMCP ConfigMap
- Show next steps

### Manual Method

1. **Create server config**:
   ```bash
   # File: mcp-config/servers/authentik-mcp.json
   {
     "name": "authentik-sso",
     "type": "SSE",
     "url": "http://authentik.authentik.svc.cluster.local:9000/mcp",
     "description": "Authentik SSO management",
     "enabled": true
   }
   ```

2. **Update MetaMCP**:
   ```bash
   ./scripts/update-metamcp-servers.sh
   ```

3. **Verify**:
   - Check MetaMCP UI for new server
   - Status should be "Connected"

---

## Troubleshooting

### MetaMCP UI Not Loading

**Check pods**:
```bash
kubectl get pods -n metamcp
```

All should be Running (1/1):
- `metamcp-xxxxx` - Main app
- `metamcp-postgres-xxxxx` - Database

**Check logs**:
```bash
kubectl logs -n metamcp -l app.kubernetes.io/component=server --tail=50
```

**Common Fix**:
```bash
# Restart deployment
kubectl rollout restart deployment/metamcp -n metamcp
```

### Server Not Connecting

**Verify URL is reachable**:
```bash
kubectl exec -n metamcp deployment/metamcp -- wget -O- http://SERVER_URL/health
```

**Check service exists**:
```bash
kubectl get svc -n <namespace>
```

**Verify ConfigMap**:
```bash
kubectl get configmap metamcp-config -n metamcp -o jsonpath='{.data.servers\.json}' | jq
```

### Claude Code Can't Connect

**Check API key is valid**:
- Login to MetaMCP UI
- Settings → API Keys
- Verify key exists and is not expired

**Check .mcp.json syntax**:
```json
{
  "mcpServers": {
    "k3s-metamcp": {
      "url": "https://metamcp.k3s.dahan.house/metamcp/default/sse",
      "transport": "sse",
      "headers": {
        "Authorization": "Bearer YOUR_KEY"
      }
    }
  }
}
```

**Test endpoint manually**:
```bash
curl -k -H "Authorization: Bearer YOUR_KEY" https://metamcp.k3s.dahan.house/metamcp/default/sse
```

### Code Execution Not Working

**Check code-executor pod**:
```bash
kubectl get pods -n mcp-executor
kubectl logs -n mcp-executor -l app.kubernetes.io/name=mcp-executor
```

**Verify Portainer credentials**:
```bash
kubectl get secret mcp-executor-env -n mcp-executor -o yaml
```

**Test from MetaMCP**:
- Use built-in Inspector
- Select code-executor
- Try execute_python tool
- Run: `print("Hello from code-executor")`

---

## Security Considerations

### Network Security
- MetaMCP accessible via HTTPS only (TLS certificate)
- Internal services use ClusterIP (not externally exposed)
- API key required for all access

### Authentication Options

**Current**: API Key authentication (enabled)
**Future**: OIDC/SSO with Authentik

To enable OIDC later:
1. Create OIDC provider in Authentik
2. Update `manifests/metamcp/k8s/02-secrets.yaml`
3. Uncomment OIDC_ variables
4. Restart MetaMCP

### Tool Access Control

**Allow specific tools**:
```json
{
  "namespace": "safe-operations",
  "allowed_tools": [
    "code-executor:execute_python",
    "k3s-proxy:adguard_get_status"
  ]
}
```

**Block dangerous tools**:
```json
{
  "namespace": "restricted",
  "blocked_tools": [
    "k3s-proxy:kubernetes_delete_pod",
    "k3s-proxy:kubernetes_exec_pod"
  ]
}
```

---

## Maintenance

### Update MetaMCP

```bash
# MetaMCP uses :latest tag, so just restart
kubectl rollout restart deployment/metamcp -n metamcp

# Wait for new pod
kubectl get pods -n metamcp -w
```

### Backup Configuration

```bash
# Backup ConfigMap
kubectl get configmap metamcp-config -n metamcp -o yaml > metamcp-config-backup.yaml

# Backup Secrets
kubectl get secret metamcp-secrets -n metamcp -o yaml > metamcp-secrets-backup.yaml

# Backup Database (if needed)
kubectl exec -n metamcp metamcp-postgres-xxxxx -- pg_dump -U metamcp_user metamcp_db > metamcp-db-backup.sql
```

### Monitor Performance

**Check resource usage**:
```bash
kubectl top pods -n metamcp
```

**View logs**:
```bash
# Backend logs
kubectl logs -n metamcp -l app.kubernetes.io/component=server -c metamcp --tail=100

# Database logs
kubectl logs -n metamcp -l app.kubernetes.io/component=database --tail=100
```

---

## Next Steps

1. ✅ MetaMCP deployed and accessible
2. ✅ Servers configured (k3s-proxy, code-executor)
3. ✅ API key generated
4. ✅ Claude Code connected
5. ⏳ Test Portainer access
6. ⏳ Add more services as needed
7. ⏳ Configure tool filtering
8. ⏳ Enable OIDC/SSO (optional)

---

**Need Help?**

- **MetaMCP Docs**: https://docs.metamcp.com/
- **MetaMCP GitHub**: https://github.com/metatool-ai/metamcp
- **This Repo**: Check `METAMCP-KNOWLEDGE.md` for detailed architecture

**Last Updated**: December 23, 2025
