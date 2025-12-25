# K3s Cluster Accessible URLs and Endpoints

This document catalogs all externally accessible services, URLs, and endpoints on the k3s cluster at 10.0.0.210.

Generated: 2025-12-25

---

## Web Services (HTTPS via Traefik Ingress)

All services below are accessible via HTTPS through Traefik (10.0.200.2) with automatic Let's Encrypt certificates.

### Infrastructure & Management

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| **Traefik Dashboard** | https://traefik.k3s.dahan.house | 443 | Ingress controller management UI |
| **Rancher** | https://rancher.k3s.dahan.house | 443 | Kubernetes cluster management |
| **Portainer** | https://portainer.k3s.dahan.house | 443 | Container management platform |
| **Homer Dashboard** | https://homer.k3s.dahan.house | 443 | Service dashboard (this dashboard) |

### Authentication & Security

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| **Authentik** | https://auth.k3s.dahan.house | 443 | Identity provider & SSO platform |
| **Vaultwarden** | https://vault.k3s.dahan.house | 443 | Password manager (Bitwarden compatible) |
| **AdGuard Home** | https://adguard.k3s.dahan.house | 443 | DNS filtering & ad blocking |

### Networking & VPN

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| **NetBird Dashboard** | https://netbird.k3s.dahan.house | 443 | VPN management dashboard |
| **NetBird Management API** | https://netbird-api.k3s.dahan.house | 443 | NetBird management API |
| **NetBird Signal Server** | https://netbird-signal.k3s.dahan.house | 443 | NetBird signaling service |
| **Pangolin (NetBird UI)** | https://pangolin.k3s.dahan.house | 443 | NetBird web interface |
| **RustDesk Web Client** | https://rustdesk.k3s.dahan.house | 443 | Remote desktop web interface |

### Automation & Development

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| **n8n** | https://n8n.k3s.dahan.house | 443 | Workflow automation platform |
| **MCP Proxy** | https://mcp.k3s.dahan.house | 443 | Model Context Protocol proxy |
| **MetaMCP** | https://metamcp.k3s.dahan.house | 443 | MCP orchestration service |
| **MCP Code Executor** | https://mcp-executor.k3s.dahan.house | 443 | Code execution service |
| **Claude Code Home** | https://claude.k3s.dahan.house | 443 | Claude Code development environment |

### Network Infrastructure Management

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| **NetBox** | https://netbox.k3s.dahan.house | 443 | IP address management (IPAM) & DCIM |
| **Nautobot** | https://nautobot.k3s.dahan.house | 443 | Network automation platform |

### Home Automation

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| **Home Assistant** | https://home.k3s.dahan.house | 443 | Home automation platform |

---

## LoadBalancer Services (Direct IP Access)

MetalLB IP Pool: 10.0.200.1 - 10.0.200.255

### Core Services

| Service | External IP | Ports | Description |
|---------|-------------|-------|-------------|
| **Traefik** | 10.0.200.2 | 80, 443, 21118, 21119 | Main ingress controller |
| **AdGuard Home** | 10.0.200.1 | 80 (HTTP), 53 (DNS TCP/UDP) | DNS filtering & ad blocking |

### Authentication & Management

| Service | External IP | Ports | Description |
|---------|-------------|-------|-------------|
| **Authentik** | 10.0.200.3 | 80, 443 | Identity provider |
| **Rancher** | 10.0.200.4 | 80, 443 | Cluster management |

### Remote Access & VPN

| Service | External IP | Ports | Description |
|---------|-------------|-------|-------------|
| **RustDesk HBBS** | 10.0.200.5 | 21115, 21116 (TCP/UDP), 21118, 21114 | RustDesk rendezvous server |
| **RustDesk HBBR** | 10.0.200.6 | 21117, 21119 | RustDesk relay server |
| **Pangolin (NetBird)** | 10.0.200.242 | 80, 443 | NetBird web UI |
| **Gerbil (NetBird UDP)** | 10.0.200.243 | 51820 (UDP), 21820 (UDP) | NetBird WireGuard endpoint |
| **Pangolin API** | 10.0.200.244 | 80 | NetBird API endpoint |

### Databases & Backend

| Service | External IP | Ports | Description |
|---------|-------------|-------|-------------|
| **PostgreSQL** | 10.0.200.7 | 5432 | Shared PostgreSQL database |

### Applications

| Service | External IP | Ports | Description |
|---------|-------------|-------|-------------|
| **Home Assistant** | 10.0.200.8 | 8123 | Home automation |
| **n8n** | 10.0.200.9 | 5678 | Workflow automation |
| **Homer** | 10.0.200.10 | 8080 | Service dashboard |
| **NetBox** | 10.0.200.11 | 8080 | IPAM/DCIM |
| **Portainer** | 10.0.200.12 | 9000, 9443, 8000 | Container management |
| **Nautobot** | 10.0.200.13 | 8080 | Network automation |
| **Claude Code Home** | 10.0.200.14 | 22 (SSH) | Development environment |
| **Vaultwarden** | 10.0.200.15 | 80 | Password manager |

---

## Homer Dashboard Configuration

Below is the recommended structure for Homer's `config.yml` to organize these services:

### Service Categories

**Infrastructure & Management**
- Traefik Dashboard
- Rancher
- Portainer
- Homer (self-reference)

**Authentication & Security**
- Authentik
- Vaultwarden
- AdGuard Home

**Networking & VPN**
- NetBird Dashboard
- Pangolin (NetBird UI)
- RustDesk
- NetBox (IPAM)
- Nautobot

**Automation & Development**
- n8n
- MCP Proxy
- MetaMCP
- MCP Code Executor
- Claude Code Home

**Home & IoT**
- Home Assistant

### Homer config.yml Format

```yaml
services:
  - name: "Infrastructure & Management"
    icon: "fas fa-server"
    items:
      - name: "Traefik Dashboard"
        logo: "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/traefik.png"
        subtitle: "Ingress Controller"
        url: "https://traefik.k3s.dahan.house"
        target: "_blank"

      - name: "Rancher"
        logo: "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/rancher.png"
        subtitle: "Kubernetes Management"
        url: "https://rancher.k3s.dahan.house"
        target: "_blank"

      - name: "Portainer"
        logo: "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/portainer.png"
        subtitle: "Container Management"
        url: "https://portainer.k3s.dahan.house"
        target: "_blank"

  - name: "Authentication & Security"
    icon: "fas fa-shield-alt"
    items:
      - name: "Authentik"
        logo: "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/authentik.png"
        subtitle: "Identity Provider"
        url: "https://auth.k3s.dahan.house"
        target: "_blank"

      - name: "Vaultwarden"
        logo: "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/vaultwarden.png"
        subtitle: "Password Manager"
        url: "https://vault.k3s.dahan.house"
        target: "_blank"

      - name: "AdGuard Home"
        logo: "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/adguard-home.png"
        subtitle: "DNS & Ad Blocking"
        url: "https://adguard.k3s.dahan.house"
        target: "_blank"

  - name: "Networking & VPN"
    icon: "fas fa-network-wired"
    items:
      - name: "NetBird"
        logo: "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/netbird.png"
        subtitle: "VPN Dashboard"
        url: "https://netbird.k3s.dahan.house"
        target: "_blank"

      - name: "Pangolin"
        subtitle: "NetBird Web UI"
        url: "https://pangolin.k3s.dahan.house"
        target: "_blank"

      - name: "RustDesk"
        logo: "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/rustdesk.png"
        subtitle: "Remote Desktop"
        url: "https://rustdesk.k3s.dahan.house"
        target: "_blank"

      - name: "NetBox"
        logo: "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/netbox.png"
        subtitle: "IPAM & DCIM"
        url: "https://netbox.k3s.dahan.house"
        target: "_blank"

      - name: "Nautobot"
        subtitle: "Network Automation"
        url: "https://nautobot.k3s.dahan.house"
        target: "_blank"

  - name: "Automation & Development"
    icon: "fas fa-code"
    items:
      - name: "n8n"
        logo: "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/n8n.png"
        subtitle: "Workflow Automation"
        url: "https://n8n.k3s.dahan.house"
        target: "_blank"

      - name: "MCP Proxy"
        subtitle: "Model Context Protocol"
        url: "https://mcp.k3s.dahan.house"
        target: "_blank"

      - name: "MetaMCP"
        subtitle: "MCP Orchestration"
        url: "https://metamcp.k3s.dahan.house"
        target: "_blank"

      - name: "MCP Code Executor"
        subtitle: "Code Execution Service"
        url: "https://mcp-executor.k3s.dahan.house"
        target: "_blank"

      - name: "Claude Code Home"
        subtitle: "Development Environment"
        url: "https://claude.k3s.dahan.house"
        target: "_blank"

  - name: "Home & IoT"
    icon: "fas fa-home"
    items:
      - name: "Home Assistant"
        logo: "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/home-assistant.png"
        subtitle: "Home Automation"
        url: "https://home.k3s.dahan.house"
        target: "_blank"
```

---

## Network Architecture

### DNS Resolution
- **Primary Domain**: dahan.house
- **K3s Subdomain**: *.k3s.dahan.house
- **DNS Server**: AdGuard Home (10.0.200.1:53)
- **Certificate Authority**: Let's Encrypt (via Traefik & Cert-Manager)

### Traffic Flow
1. External requests → Traefik LoadBalancer (10.0.200.2:443)
2. Traefik terminates TLS using Let's Encrypt wildcard certificate
3. Traefik routes to ClusterIP services based on host header
4. Services handle requests internally

### Direct Access Points
- LoadBalancer IPs bypass Traefik for specific protocols (DNS, SSH, VPN)
- Database services (PostgreSQL) accessible via LoadBalancer for external tools
- VPN services (RustDesk, NetBird) use dedicated UDP ports

---

## Service Purposes

### Core Infrastructure
- **Traefik**: HTTP/HTTPS ingress with automatic TLS
- **Rancher**: GitOps via Fleet, cluster monitoring
- **AdGuard Home**: Network-wide ad blocking and DNS filtering
- **Portainer**: Docker/Kubernetes container management UI

### Security & Access
- **Authentik**: SSO/SAML/OAuth2 identity provider
- **Vaultwarden**: Self-hosted Bitwarden password manager
- **NetBird**: Zero-trust mesh VPN (WireGuard-based)
- **RustDesk**: Self-hosted remote desktop (TeamViewer alternative)

### Network Management
- **NetBox**: IP address management (IPAM) and datacenter infrastructure management (DCIM)
- **Nautobot**: Network source of truth and automation platform

### Automation & AI
- **n8n**: Low-code workflow automation (Zapier alternative)
- **MCP Proxy**: Claude AI model context protocol gateway
- **MetaMCP**: MCP orchestration and routing
- **MCP Code Executor**: Sandboxed code execution for AI agents
- **Claude Code Home**: Development environment with SSH access

### Home Automation
- **Home Assistant**: IoT device control and automation

---

## Notes

1. **All HTTPS services** use Let's Encrypt certificates via Traefik
2. **LoadBalancer IPs** are managed by MetalLB (10.0.200.x range)
3. **Ingress** is handled by Traefik with automatic certificate renewal
4. **GitOps**: All manifests in this repo are auto-deployed via Rancher Fleet
5. **DNS**: Configure clients to use 10.0.200.1 for ad blocking

## Related Documentation

- **CLAUDE.md**: Repository guidelines and GitOps workflow
- **manifests/**: Kubernetes YAML files for all services
- **DEPLOYMENT_SUMMARY.md**: Initial cluster discovery
- **VERIFICATION_REPORT.md**: Configuration audit log
