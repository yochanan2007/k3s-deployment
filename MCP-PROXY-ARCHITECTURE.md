# MCP Proxy Architecture Documentation

## Executive Summary

This document describes the Model Context Protocol (MCP) proxy server implementation for the k3s cluster at 10.0.0.210. The MCP proxy provides unified programmatic access to all cluster services via the MCP standard, enabling AI agents and automation tools to interact with deployed applications.

## Architecture Overview

### High-Level Design

```
┌─────────────────────────────────────────────────────────────────┐
│                        External Clients                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Claude Code  │  │     n8n      │  │ Custom Apps  │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                   │
└─────────┼──────────────────┼──────────────────┼──────────────────┘
          │                  │                  │
          │         HTTPS (MCP over SSE)        │
          │                  │                  │
┌─────────▼──────────────────▼──────────────────▼──────────────────┐
│                     Internet / WAN                                │
└─────────────────────────────┬─────────────────────────────────────┘
                              │
┌─────────────────────────────▼─────────────────────────────────────┐
│                    Traefik Ingress Controller                      │
│              (10.0.200.2 - mcp.k3s.dahan.house)                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  - TLS Termination (Let's Encrypt cert)                    │  │
│  │  - Disable buffering for SSE streaming                     │  │
│  │  - Route to mcp-proxy.mcp-proxy.svc.cluster.local         │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────┬─────────────────────────────────────┘
                              │
┌─────────────────────────────▼─────────────────────────────────────┐
│                   mcp-proxy Namespace                              │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │           MCP Proxy Server (Pod)                          │    │
│  │  ┌────────────────────────────────────────────────────┐  │    │
│  │  │  Node.js Application                                │  │    │
│  │  │  - @modelcontextprotocol/sdk                        │  │    │
│  │  │  - Express.js (HTTP/SSE transport)                  │  │    │
│  │  │  - GitOps config loader                             │  │    │
│  │  └────────────────────────────────────────────────────┘  │    │
│  │  ┌────────────────────────────────────────────────────┐  │    │
│  │  │  ServiceAccount: mcp-proxy                          │  │    │
│  │  │  - ClusterRole: read pods, services, deployments    │  │    │
│  │  │  - Pod exec permissions (for PostgreSQL queries)    │  │    │
│  │  └────────────────────────────────────────────────────┘  │    │
│  └──────────────────────────────────────────────────────────┘    │
└─────────────────────────────┬─────────────────────────────────────┘
                              │
                              │ Internal Cluster Network
                              │ (ClusterIP DNS)
                              │
┌─────────────────────────────▼─────────────────────────────────────┐
│                     k3s Cluster Services                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
│  │   AdGuard    │  │  Authentik   │  │  PostgreSQL  │            │
│  │  (adguard    │  │ (authentik   │  │ (authentik   │            │
│  │  namespace)  │  │  namespace)  │  │  namespace)  │            │
│  └──────────────┘  └──────────────┘  └──────────────┘            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
│  │   Rancher    │  │  RustDesk    │  │  Kubernetes  │            │
│  │ (cattle-     │  │  (rustdesk   │  │     API      │            │
│  │  system)     │  │  namespace)  │  │   (default)  │            │
│  └──────────────┘  └──────────────┘  └──────────────┘            │
└───────────────────────────────────────────────────────────────────┘
```

### Component Architecture

#### 1. MCP Proxy Server
- **Language**: Node.js (v18+)
- **Framework**: Express.js for HTTP server
- **MCP SDK**: `@modelcontextprotocol/sdk` (official implementation)
- **Transport**: HTTP with Server-Sent Events (SSE) for streaming
- **Container**: Alpine Linux with kubectl installed

#### 2. Configuration Management (GitOps)
- **Pattern**: Pull-based configuration from GitHub
- **Config File**: `mcp-proxy-config.json` in repository root
- **Reload Mechanism**: Automatic reload every 5 minutes
- **Fallback**: Local default configuration if fetch fails

#### 3. Service Integration

The proxy integrates with the following cluster services:

| Service | Namespace | Access Method | Tools Provided |
|---------|-----------|---------------|----------------|
| Kubernetes API | default | kubectl CLI | get_pods, get_services, get_deployments, describe_resource |
| AdGuard Home | adguard | HTTP API | get_status, query_log |
| Authentik | authentik | HTTP API + Token | get_users, get_applications |
| PostgreSQL | authentik | kubectl exec | query, list_tables |
| Rancher | cattle-system | HTTP API + Token | get_clusters |
| RustDesk | rustdesk | (Planned) | (Future) |

### Network Topology

#### External Access
- **Domain**: mcp.k3s.dahan.house
- **Protocol**: HTTPS (TLS 1.2+)
- **Certificate**: Let's Encrypt via cert-manager
- **Ingress**: Traefik with SSE-optimized configuration

#### Internal Access
- **Service Type**: ClusterIP
- **Port**: 80 (maps to container port 3010)
- **DNS**: mcp-proxy.mcp-proxy.svc.cluster.local

#### Outbound Connections
- GitHub (raw.githubusercontent.com): Config fetching
- Cluster services (*.svc.cluster.local): Service APIs

### Security Architecture

#### RBAC Configuration

**ServiceAccount**: `mcp-proxy` (mcp-proxy namespace)

**ClusterRole Permissions**:
```yaml
- Resources: pods, services, namespaces, nodes
  Verbs: get, list, watch
- Resources: deployments, statefulsets, daemonsets
  Verbs: get, list, watch
- Resources: pods/exec
  Verbs: create, get
- Resources: ingresses, ingressroutes
  Verbs: get, list
- Resources: certificates
  Verbs: get, list
```

**Scope**: Cluster-wide read access, pod exec for PostgreSQL queries

#### Secrets Management

**API Tokens Secret**: `mcp-proxy-api-tokens`
- AUTHENTIK_API_TOKEN: Authentik API bearer token
- RANCHER_API_TOKEN: Rancher API key

**Certificate Secret**: `mcp-tls`
- Managed by cert-manager
- Auto-renewed via Let's Encrypt

#### Container Security
- Non-root user (UID 1001)
- No privilege escalation
- Dropped all capabilities
- Read-only root filesystem (where possible)

### Data Flow

#### MCP Request Flow

1. **Client → Traefik**
   - Client sends HTTPS POST to https://mcp.k3s.dahan.house/mcp
   - Traefik terminates TLS
   - Traefik disables buffering for SSE streaming

2. **Traefik → MCP Proxy**
   - Request forwarded to mcp-proxy.mcp-proxy.svc.cluster.local:80
   - Load balances across pod replicas (currently 1)

3. **MCP Proxy → Tool Handler**
   - Express.js routes to SSE transport
   - MCP SDK parses request
   - Dispatches to appropriate tool handler

4. **Tool Handler → Service**
   - **Kubernetes tools**: Execute kubectl commands
   - **HTTP APIs**: Make HTTP requests to service ClusterIP
   - **PostgreSQL**: kubectl exec into pod, run psql commands
   - **Authenticated APIs**: Include bearer token from secret

5. **Response → Client**
   - Tool handler returns result to MCP SDK
   - SDK formats response per MCP protocol
   - Express.js streams via SSE
   - Traefik forwards to client

#### Configuration Update Flow

1. **Startup**: Proxy fetches config from GitHub
2. **Periodic Reload**: Every 5 minutes, re-fetch config
3. **Parse & Validate**: Validate JSON structure
4. **Apply Changes**: Update tool enablement flags
5. **Fallback**: If fetch fails, keep current config

### Monitoring & Observability

#### Health Checks

**Liveness Probe**:
- Endpoint: `/health`
- Interval: 30s
- Timeout: 3s
- Failure threshold: 3

**Readiness Probe**:
- Endpoint: `/health`
- Interval: 10s
- Timeout: 3s
- Failure threshold: 3

#### Logging

**Stdout/Stderr**: All logs to stdout for kubectl logs
**Log Levels**:
- INFO: Startup, config loads, requests
- ERROR: API failures, config fetch errors

**Key Log Events**:
- Server startup
- Config loaded/failed
- Tool invocations
- Service API errors
- Health check failures

#### Metrics (Future)

Planned metrics endpoint:
- Request count by tool
- Request duration by tool
- Service API latency
- Config reload success/failure
- Active connections

### Scalability Considerations

#### Current Deployment
- **Replicas**: 1 (single instance)
- **Resources**:
  - Request: 100m CPU, 128Mi RAM
  - Limit: 500m CPU, 512Mi RAM

#### Scaling Strategy

**Horizontal Scaling**:
- Can scale to multiple replicas
- Service load balances across pods
- SSE connections are stateless

**Limitations**:
- kubectl exec creates new process per query
- Consider connection pooling for PostgreSQL
- Consider caching for frequently accessed data

**Future Optimizations**:
- Replace kubectl exec with native PostgreSQL client
- Implement request caching
- Add Redis for shared state
- Implement rate limiting per client

### High Availability

#### Current State
- Single replica (no HA)
- Ingress provides external load balancing
- Service provides internal load balancing

#### HA Enhancements (Future)
- Deploy 2+ replicas
- Add PodDisruptionBudget
- Add pod anti-affinity rules
- Implement graceful shutdown
- Add readiness delays

### Disaster Recovery

#### Configuration
- **Source of Truth**: GitHub repository
- **Recovery**: Re-deploy from manifests
- **State**: Stateless (no persistent data)

#### Backup Strategy
- Manifests tracked in Git
- Config tracked in Git
- Secrets documented (not in Git)
- Docker image in registry

#### Recovery Procedure
1. Restore manifests from Git
2. Rebuild/pull Docker image
3. Apply manifests to cluster
4. Recreate secrets from secure storage
5. Verify health checks pass

### Integration Patterns

#### MCP Client Integration

**Claude Code**:
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

**n8n Workflow**:
- Use HTTP Request node
- POST to https://mcp.k3s.dahan.house/mcp
- Content-Type: application/json
- Body: MCP protocol messages

**Custom Applications**:
- Use official MCP SDK
- Connect to https://mcp.k3s.dahan.house/mcp
- Implement MCP client protocol

### Future Roadmap

#### Phase 1: Core Services (Current)
- ✅ Kubernetes API access
- ✅ AdGuard Home integration
- ✅ Authentik integration
- ✅ PostgreSQL integration
- ✅ Rancher integration
- ✅ GitOps configuration

#### Phase 2: Extended Services
- ⬜ n8n workflow management
- ⬜ Home Assistant integration
- ⬜ Portainer container management
- ⬜ NetBox IPAM integration
- ⬜ Homer dashboard integration

#### Phase 3: Advanced Features
- ⬜ Authentication & authorization
- ⬜ Rate limiting per client
- ⬜ Request caching
- ⬜ Prometheus metrics
- ⬜ OpenTelemetry tracing
- ⬜ WebSocket transport
- ⬜ Native PostgreSQL client

#### Phase 4: Production Hardening
- ⬜ High availability (multi-replica)
- ⬜ Circuit breakers
- ⬜ Retry logic with backoff
- ⬜ External secret management (Vault)
- ⬜ Network policies
- ⬜ Admission webhooks
- ⬜ Automated testing

## Technology Stack

### Runtime
- **Node.js**: 18.x (LTS)
- **OS**: Alpine Linux 3.x

### Core Dependencies
- `@modelcontextprotocol/sdk`: ^1.0.0 - Official MCP SDK
- `express`: ^4.21.2 - HTTP server framework
- `axios`: ^1.7.9 - HTTP client for service APIs

### System Tools
- `kubectl`: Latest stable - Kubernetes CLI

### Development Tools
- Docker for containerization
- npm for package management

## Deployment Requirements

### Prerequisites
- k3s cluster (v1.33+)
- Traefik ingress controller
- cert-manager with ClusterIssuer
- MetalLB load balancer
- Docker registry (or k3s image import)

### Resource Requirements
- **Minimum**: 100m CPU, 128Mi RAM
- **Recommended**: 200m CPU, 256Mi RAM
- **Storage**: None (stateless)

### Network Requirements
- **Ingress**: Port 443 (HTTPS)
- **Egress**: GitHub (port 443), cluster services (varies)

## References

### MCP Protocol
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [MCP SDK Documentation](https://github.com/modelcontextprotocol/sdk)
- [MCP Registry](https://registry.modelcontextprotocol.io/)

### Community Resources
- [Official MCP Servers](https://github.com/modelcontextprotocol/servers)
- [achetronic/mcp-proxy](https://github.com/achetronic/mcp-proxy) - Enterprise MCP proxy inspiration
- [Microsoft MCP Gateway](https://github.com/microsoft/mcp-gateway) - Reference architecture
- [Flux MCP Server](https://fluxcd.io/blog/2025/05/ai-assisted-gitops/) - GitOps integration pattern

### Related Documentation
- [DEPLOYMENT.md](manifests/mcp-proxy/DEPLOYMENT.md) - Deployment guide
- [README.md](manifests/mcp-proxy/README.md) - Quick start
- [TODO-BEFORE-DEPLOY.md](manifests/mcp-proxy/TODO-BEFORE-DEPLOY.md) - Pre-deployment checklist
- [CLAUDE.md](CLAUDE.md) - Repository guidelines

## Changelog

### Version 1.0.0 (2025-12-22)
- Initial MCP proxy implementation
- Support for Kubernetes, AdGuard, Authentik, PostgreSQL, Rancher
- GitOps configuration from GitHub
- HTTP/SSE transport
- RBAC with ClusterRole
- Traefik ingress with Let's Encrypt
- Health checks and logging
