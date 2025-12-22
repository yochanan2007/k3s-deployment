# MCP Configuration

This directory contains MCP (Model Context Protocol) server configurations for accessing K3s services and infrastructure.

## Configuration Files

### mcp-servers.json
Main MCP server configuration that defines:
- **k3s**: SSH access to K3s cluster (10.0.0.210)
- **docker2**: SSH access to Docker host 1 (10.0.0.120)
- **docker3**: SSH access to Docker host 2 (10.0.0.121)
- **github**: GitHub API access
- **k3s-cluster**: HTTP proxy to MCP service running in K3s

### services-config.json
Configuration for all K3s services accessible via the MCP proxy:
- AdGuard Home
- Authentik
- Rancher
- Home Assistant
- n8n
- Portainer
- Nautobot
- PostgreSQL
- Traefik
- RustDesk

## Environment Variables Setup

### Location
Place your `.env` file at: **`D:\claude\k3s-deployment\mcp-config\.env`**

### Instructions
1. Copy `.env.example` to `.env`:
   ```bash
   cp mcp-config/.env.example mcp-config/.env
   ```

2. Edit `mcp-config/.env` with your actual credentials

3. **IMPORTANT**: The `.env` file is gitignored and will NOT be committed to the repository

### Getting API Tokens

#### Authentik API Token
1. Go to https://auth.k3s.dahan.house/if/admin/#/core/tokens
2. Click "Create" → "Token"
3. Set expiry and copy the token

#### Rancher API Token
1. Go to https://rancher.k3s.dahan.house/dashboard/account
2. Click "API Keys" → "Create API Key"
3. Copy the token (format: `token-xxxxx:xxxxxxxxxx`)

#### Home Assistant Token
1. Go to https://home.k3s.dahan.house/profile
2. Scroll to "Long-Lived Access Tokens"
3. Click "Create Token" and copy it

#### n8n API Key
1. Go to https://n8n.k3s.dahan.house/settings/api
2. Generate API key and copy it

#### Portainer
Use the admin credentials you set during first login

#### Nautobot API Token
Already set during deployment: `0123456789abcdef0123456789abcdef01234567`
Or create a new one at: https://nautobot.k3s.dahan.house/user/api-tokens/

## Usage with Claude Code

### Option 1: Local MCP Servers (Recommended for development)
Update your Claude Code `.mcp.json`:
```json
{
  "mcpServers": {
    "k3s": { ... },
    "docker2": { ... },
    "docker3": { ... },
    "github": { ... }
  }
}
```

### Option 2: HTTP Proxy (Recommended for production)
Use the centralized MCP proxy running in K3s:
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

## Security Notes

- Never commit `.env` file to Git
- Rotate API tokens regularly
- Use least-privilege tokens when possible
- The MCP proxy in K3s fetches config from this GitHub repo
- Environment variables are injected via Kubernetes secrets

## MCP Proxy Deployment

The MCP proxy server is deployed in the `mcp-proxy` namespace and:
- Fetches `services-config.json` from this GitHub repo
- Reloads configuration every 5 minutes
- Provides unified access to all services via MCP protocol
- Accessible at: https://mcp.k3s.dahan.house/mcp
