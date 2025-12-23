# MCP Executor Server Configurations

This directory contains configuration files for MCP servers that run in the `mcp-executor` namespace.

## How It Works (GitOps)

1. **Create a config file** in this directory (e.g., `my-server.json`)
2. **Commit and push** to GitHub
3. **Auto-deployment** happens within 5 minutes via GitOps sync
4. **MCP server starts** automatically in the mcp-executor pod

## Config File Format

```json
{
  "name": "server-name",
  "enabled": true,
  "description": "What this server does",
  "command": "npx",
  "args": [
    "-y",
    "@package/name",
    "--option",
    "value"
  ],
  "env": {
    "ENV_VAR": "value"
  },
  "port": 3001,
  "metadata": {
    "package": "@package/name",
    "added": "2025-12-23",
    "tools": ["tool1", "tool2"]
  }
}
```

## Configuration Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique server name (lowercase, no spaces) |
| `enabled` | Yes | Set to `true` to start, `false` to disable |
| `description` | Yes | Human-readable description |
| `command` | Yes | Command to run (usually `npx`) |
| `args` | Yes | Array of command arguments |
| `env` | No | Environment variables (supports `${VAR}` substitution from secrets) |
| `port` | Yes | Port number for this MCP server (3001+) |
| `metadata` | No | Additional information for documentation |

## Environment Variable Substitution

You can use `${VAR_NAME}` in `args` or `env` values to reference Kubernetes secrets:

```json
{
  "args": ["--token", "${AUTHENTIK_TOKEN}"],
  "env": {
    "API_KEY": "${MY_SECRET_KEY}"
  }
}
```

The orchestrator will replace these with values from the `mcp-executor-secrets` secret.

## Port Allocation

- **3000**: Reserved for Portainer code executor (existing)
- **3001**: authentik-mcp
- **3002**: Available for next server
- **3003**: Available for next server
- etc.

## Example Configs

### Authentik MCP Server
```json
{
  "name": "authentik-mcp",
  "enabled": true,
  "description": "Authentik SSO management",
  "command": "npx",
  "args": [
    "-y",
    "@cdmx/authentik-mcp",
    "--base-url",
    "http://authentik-server.authentik.svc.cluster.local:9000/api/v3",
    "--token",
    "${AUTHENTIK_TOKEN}"
  ],
  "env": {
    "AUTHENTIK_TOKEN": "your-token-here"
  },
  "port": 3001
}
```

### Custom MCP Server
```json
{
  "name": "my-custom-mcp",
  "enabled": true,
  "description": "My custom MCP server",
  "command": "npx",
  "args": [
    "-y",
    "@myorg/my-mcp-server",
    "--config",
    "/config/settings.json"
  ],
  "port": 3002
}
```

## Disabling a Server

Set `enabled: false` to stop a server without deleting the config:

```json
{
  "name": "authentik-mcp",
  "enabled": false,
  ...
}
```

## Troubleshooting

**Server not starting:**
1. Check logs: `kubectl logs -n mcp-executor -l app=mcp-orchestrator`
2. Verify config syntax (valid JSON)
3. Check port conflicts (each server needs unique port)

**Environment variables not working:**
1. Check secret exists: `kubectl get secret mcp-executor-secrets -n mcp-executor`
2. Verify variable name matches secret key

**Changes not applying:**
1. GitOps sync runs every 5 minutes
2. Force sync: `kubectl rollout restart deployment/mcp-orchestrator -n mcp-executor`

## Adding New Servers

1. Create `mcp-config/executor/your-server.json`
2. Fill in all required fields
3. Choose an unused port number
4. Commit: `git add mcp-config/executor/your-server.json`
5. Push: `git push origin main`
6. Wait ~5 minutes for auto-deployment

## MetaMCP Integration

After deployment, add to MetaMCP:
- Name: (from config `name` field)
- URL: `http://mcp-orchestrator.mcp-executor.svc.cluster.local:<port>`
- Transport: SSE
- Description: (from config `description` field)

Port is from the config file's `port` field.
