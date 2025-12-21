# MCP Proxy for k3s Cluster

This directory contains the Model Context Protocol (MCP) proxy server for programmatic access to all services running in the k3s cluster.

## Overview

The MCP Proxy provides a unified interface for AI agents and automation tools to interact with cluster services including:

- **AdGuard Home**: DNS filtering and ad blocking
- **Authentik**: SSO and identity management
- **PostgreSQL**: Database operations
- **Rancher**: Cluster management
- **Kubernetes API**: Direct cluster operations
- **RustDesk**: Remote desktop server (future)

## Architecture

```
┌─────────────────┐
│   MCP Client    │ (Claude Code, n8n, etc.)
└────────┬────────┘
         │ HTTP/SSE
         ▼
┌─────────────────────────────────────┐
│      MCP Proxy Server (Pod)         │
│  ┌─────────────────────────────┐   │
│  │   GitOps Config Loader      │   │
│  │   (Fetches from GitHub)     │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │   Tool Handlers             │   │
│  │   - Kubernetes              │   │
│  │   - AdGuard                 │   │
│  │   - Authentik               │   │
│  │   - PostgreSQL              │   │
│  │   - Rancher                 │   │
│  └─────────────────────────────┘   │
└───────┬─────────────────────────────┘
        │ Internal Cluster Network
        ▼
┌───────────────────────────────────┐
│     k3s Services                  │
│  ┌──────────┐  ┌──────────┐      │
│  │ AdGuard  │  │Authentik │      │
│  └──────────┘  └──────────┘      │
│  ┌──────────┐  ┌──────────┐      │
│  │PostgreSQL│  │ Rancher  │      │
│  └──────────┘  └──────────┘      │
└───────────────────────────────────┘
```

## GitOps Configuration

The MCP Proxy automatically fetches its configuration from GitHub at startup and periodically reloads it:

- **Configuration File**: `/mcp-proxy-config.json` in repository root
- **Reload Interval**: 5 minutes (configurable)
- **Features**: Enable/disable specific tools, configure service endpoints

## Available Tools

### Kubernetes Tools
- `k8s_get_pods`: List pods in namespace or cluster-wide
- `k8s_get_services`: List services
- `k8s_get_deployments`: List deployments
- `k8s_describe_resource`: Get detailed resource information

### AdGuard Home Tools
- `adguard_get_status`: Get server status and statistics
- `adguard_query_log`: Query DNS query logs

### PostgreSQL Tools
- `postgres_query`: Execute SELECT queries
- `postgres_list_tables`: List database tables

### Authentik Tools
- `authentik_get_users`: List users (requires API token)
- `authentik_get_applications`: List configured applications

### Rancher Tools
- `rancher_get_clusters`: List managed clusters (requires API token)

## Available Resources

- `k3s://cluster/status`: Overall cluster health
- `k3s://services/all`: Complete service inventory

## Building the Docker Image

```bash
cd manifests/mcp-proxy
docker build -t mcp-proxy:1.0.0 .
```

## Running Locally (Development)

```bash
npm install
TRANSPORT_MODE=stdio node mcp-proxy-server.js
```

## Deployment

The server is deployed as a Kubernetes Deployment with:
- **Namespace**: `mcp-proxy`
- **Service**: ClusterIP on port 3010
- **Ingress**: HTTPS via Traefik at `mcp.k3s.dahan.house`
- **Certificate**: Uses wildcard cert `k3s-dahan-house-tls`

Apply manifests in order:
```bash
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-config.yaml
kubectl apply -f 02-rbac.yaml
kubectl apply -f 03-deployment.yaml
kubectl apply -f 04-service.yaml
kubectl apply -f 05-ingress.yaml
kubectl apply -f 06-certificate.yaml
```

## Security

### RBAC Permissions
The proxy runs with a ServiceAccount that has permissions to:
- Read pods, services, deployments across allowed namespaces
- Execute commands in pods (for PostgreSQL queries via kubectl exec)

### API Tokens
Some services require API tokens configured as Kubernetes secrets:
- `AUTHENTIK_API_TOKEN`: For Authentik API access
- `RANCHER_API_TOKEN`: For Rancher API access

### Network Policies
The proxy only has access to:
- Internal cluster services (via ClusterIP DNS)
- GitHub for config fetching
- No external internet access except config repo

## Connecting from MCP Clients

### Claude Code (.mcp.json)
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

### n8n
Use the "HTTP Request" node with:
- URL: `https://mcp.k3s.dahan.house/mcp`
- Method: POST
- Content-Type: `application/json`

## Health Monitoring

Health endpoint: `https://mcp.k3s.dahan.house/health`

Returns:
```json
{
  "status": "healthy",
  "version": "1.0.0"
}
```

## Troubleshooting

### Config not loading from GitHub
Check the pod logs:
```bash
kubectl logs -n mcp-proxy deployment/mcp-proxy-server
```

The server will fall back to default configuration if GitHub fetch fails.

### kubectl commands failing
Ensure the ServiceAccount has correct RBAC permissions:
```bash
kubectl get rolebinding -n mcp-proxy
kubectl describe rolebinding mcp-proxy-binding -n mcp-proxy
```

### Service API calls failing
Check that service endpoints are correct and accessible:
```bash
kubectl exec -n mcp-proxy deployment/mcp-proxy-server -- curl http://adguard.adguard.svc.cluster.local/control/status
```

## Future Enhancements

- Add support for n8n workflow management
- Add support for Home Assistant integration
- Add support for Portainer container management
- Implement caching layer for frequent queries
- Add Prometheus metrics endpoint
- Implement rate limiting
- Add WebSocket transport support
