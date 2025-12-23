# MCP Executor Orchestrator

## Overview

The MCP Executor runs multiple MCP servers in a single namespace using a GitOps-managed orchestrator.

All MCP servers are configured via JSON files in `mcp-config/executor/` and auto-deploy when pushed to GitHub.

## Architecture

```
┌──────────────────────────────────────────────┐
│  mcp-orchestrator pod                        │
│  ┌────────────────────────────────────────┐  │
│  │  Git Sync (every 5 min)                │  │
│  │  Pulls: mcp-config/executor/*.json     │  │
│  └──────────────┬─────────────────────────┘  │
│                 │                             │
│                 ├─► Spawns processes         │
│                 │                             │
│  ┌──────────────▼──────────────┐             │
│  │  code-executor (port 3000)  │             │
│  │  Python sandbox + Portainer │             │
│  └─────────────────────────────┘             │
│                                               │
│  ┌─────────────────────────────┐             │
│  │  authentik-mcp (port 3001)  │             │
│  │  @cdmx/authentik-mcp        │             │
│  └─────────────────────────────┘             │
│                                               │
│  ┌─────────────────────────────┐             │
│  │  [future servers] (3002+)   │             │
│  └─────────────────────────────┘             │
└──────────────────────────────────────────────┘
```

## Files

- **05-orchestrator-deployment.yaml**: Main orchestrator that spawns MCP servers
- **06-orchestrator-service.yaml**: Service exposing ports 3001-3010

## GitOps Workflow

### Adding a New MCP Server

1. **Create config**: `mcp-config/executor/my-server.json`
   ```json
   {
     "name": "my-server",
     "enabled": true,
     "description": "What it does",
     "command": "npx",
     "args": ["-y", "@package/name"],
     "port": 3002
   }
   ```

2. **Commit and push**:
   ```bash
   git add mcp-config/executor/my-server.json
   git commit -m "feat: Add my-server MCP"
   git push origin main
   ```

3. **Auto-deploys in ~5 minutes** (git sync interval)

4. **Add to MetaMCP**:
   ```bash
   # Create MetaMCP server config
   cat > mcp-config/servers/my-server.json << EOF
   {
     "name": "my-server",
     "type": "SSE",
     "url": "http://mcp-orchestrator.mcp-executor.svc.cluster.local:3002",
     "enabled": true
   }
   EOF

   # Update MetaMCP
   ./scripts/update-metamcp-servers.sh
   ```

### Using the Helper Script

```bash
./scripts/add-executor-server.sh my-server @package/mcp-server 3002
```

This creates the config file template for you to customize.

## Configuration Format

See `mcp-config/executor/README.md` for full config format documentation.

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Unique server identifier |
| `enabled` | boolean | Enable/disable server |
| `description` | string | Human-readable description |
| `command` | string | Command to run (usually `npx`) |
| `args` | array | Command arguments |
| `port` | number | Port number (3001-3010) |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `env` | object | Environment variables |
| `metadata` | object | Additional info (tools, package, etc.) |

## Environment Variables

Use `${VAR_NAME}` in args or env to substitute from secrets:

```json
{
  "args": ["--token", "${AUTHENTIK_TOKEN}"],
  "env": {
    "API_KEY": "${MY_SECRET}"
  }
}
```

Secrets are loaded from `mcp-executor-secrets` (if it exists).

## Port Allocation

- **3000**: Reserved for code-executor (existing)
- **3001**: authentik-mcp
- **3002-3010**: Available for new servers

Service exposes all ports 3001-3010 by default.

## Deployment

```bash
kubectl apply -f manifests/mcp-executor/05-orchestrator-deployment.yaml
kubectl apply -f manifests/mcp-executor/06-orchestrator-service.yaml
```

## Monitoring

```bash
# Check orchestrator status
kubectl get pods -n mcp-executor -l app=mcp-orchestrator

# View logs (shows all spawned servers)
kubectl logs -n mcp-executor -l app=mcp-orchestrator -f

# Check which servers are running
kubectl logs -n mcp-executor -l app=mcp-orchestrator | grep "Running servers"
```

## Troubleshooting

### Server not starting

1. Check config syntax:
   ```bash
   cat mcp-config/executor/my-server.json | jq .
   ```

2. Check orchestrator logs:
   ```bash
   kubectl logs -n mcp-executor -l app=mcp-orchestrator --tail=100
   ```

3. Verify port not in use

### Changes not applying

- Git sync interval is 5 minutes
- Force reload: `kubectl rollout restart deployment/mcp-orchestrator -n mcp-executor`

### Port conflicts

Each server needs a unique port. Check `mcp-config/executor/*.json` for used ports.

## Current Servers

| Server | Port | Package | Description |
|--------|------|---------|-------------|
| code-executor | 3000 | (custom) | Python sandbox + Portainer |
| authentik-mcp | 3001 | @cdmx/authentik-mcp | Authentik SSO management |

## Adding Environment Secrets

If your MCP server needs secrets:

```bash
kubectl create secret generic mcp-executor-secrets \
  -n mcp-executor \
  --from-literal=MY_TOKEN=abc123 \
  --from-literal=API_KEY=xyz789
```

Then reference in config:
```json
{
  "args": ["--token", "${MY_TOKEN}"]
}
```

## Benefits of This Architecture

✅ **GitOps**: Config-as-code, version controlled
✅ **Auto-deploy**: Push to GitHub → auto-applies
✅ **Centralized**: All MCP servers in one namespace
✅ **Easy to add**: Just create a JSON config file
✅ **Process management**: Automatic restarts on crash
✅ **Token efficient**: Shares resources, minimal overhead

## Comparison with Separate Deployments

**Orchestrator Approach (Current)**:
- ✅ One pod for all MCP servers
- ✅ Lower resource overhead
- ✅ Simple GitOps workflow
- ✅ Easy to add new servers
- ❌ Single point of failure

**Separate Deployments**:
- ✅ Isolated failures
- ✅ Individual resource limits
- ❌ More manifests to manage
- ❌ Higher resource overhead
- ❌ More complex GitOps

We chose the orchestrator approach for simplicity and resource efficiency.
