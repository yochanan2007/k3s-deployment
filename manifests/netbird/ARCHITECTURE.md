# Netbird Deployment Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Netbird VPN Network                             │
│                         (100.x.x.x/16 Range)                            │
│                                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐             │
│  │ Netbird Peer │    │ Netbird Peer │    │ Netbird Peer │             │
│  │  (Laptop)    │    │  (Desktop)   │    │  (Server)    │             │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘             │
│         │                    │                    │                      │
│         └────────────────────┴────────────────────┘                      │
│                              │                                           │
│                    WireGuard Encrypted Tunnel                            │
│                              │                                           │
│                              ▼                                           │
│         ┌────────────────────────────────────────────┐                  │
│         │   k3s Cluster - Netbird Client Pod         │                  │
│         │   Hostname: k3s-netbird-client             │                  │
│         │   NetBird IP: 100.x.x.x (assigned)         │                  │
│         └────────────────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────────────┘

                              │
                              │
                              ▼

┌─────────────────────────────────────────────────────────────────────────┐
│                    k3s Cluster (10.0.0.210)                             │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ Namespace: netbird                                             │    │
│  │                                                                 │    │
│  │  ┌─────────────────────────────────────────────────────────┐  │    │
│  │  │ Deployment: netbird-client                              │  │    │
│  │  │                                                          │  │    │
│  │  │  ┌────────────────────────────────────────────────┐     │  │    │
│  │  │  │ Pod: netbird-client-xxxxxxxxxx-xxxxx          │     │  │    │
│  │  │  │                                                │     │  │    │
│  │  │  │  Container: netbird                            │     │  │    │
│  │  │  │  - Image: netbirdio/netbird:latest            │     │  │    │
│  │  │  │  - Capabilities: NET_ADMIN, SYS_ADMIN, SYS_R  │     │  │    │
│  │  │  │  - Port: 80                                    │     │  │    │
│  │  │  │                                                │     │  │    │
│  │  │  │  Volumes:                                      │     │  │    │
│  │  │  │  - /etc/netbird -> PVC: netbird-config (1Gi)  │     │  │    │
│  │  │  │                                                │     │  │    │
│  │  │  │  Environment:                                  │     │  │    │
│  │  │  │  - NB_SETUP_KEY: [from secret]                │     │  │    │
│  │  │  │  - NB_HOSTNAME: k3s-netbird-client            │     │  │    │
│  │  │  │  - TZ: America/New_York                        │     │  │    │
│  │  │  └────────────────────────────────────────────────┘     │  │    │
│  │  │                                                          │  │    │
│  │  │  Resources:                                              │  │    │
│  │  │  - Requests: 128Mi memory, 100m CPU                     │  │    │
│  │  │  - Limits: 512Mi memory, 500m CPU                       │  │    │
│  │  └─────────────────────────────────────────────────────────┘  │    │
│  │                              │                                 │    │
│  │                              │                                 │    │
│  │                              ▼                                 │    │
│  │  ┌──────────────────────────────────────────────────────┐    │    │
│  │  │ Service: netbird (ClusterIP)                         │    │    │
│  │  │ - Type: ClusterIP                                    │    │    │
│  │  │ - Port: 80 -> Pod:80                                 │    │    │
│  │  │ - Selector: app.kubernetes.io/name=netbird-client    │    │    │
│  │  └──────────────────────────────────────────────────────┘    │    │
│  │                              │                                 │    │
│  │                              ▼                                 │    │
│  │  ┌──────────────────────────────────────────────────────┐    │    │
│  │  │ Service: netbird-lb (LoadBalancer)                   │    │    │
│  │  │ - Type: LoadBalancer                                 │    │    │
│  │  │ - External IP: 10.0.200.x (MetalLB auto-assigned)   │    │    │
│  │  │ - Port: 80 -> Pod:80                                 │    │    │
│  │  │ - Selector: app.kubernetes.io/name=netbird-client    │    │    │
│  │  └──────────────────────────────────────────────────────┘    │    │
│  │                              │                                 │    │
│  │                              │                                 │    │
│  │  ┌──────────────────────────────────────────────────────┐    │    │
│  │  │ PersistentVolumeClaim: netbird-config                │    │    │
│  │  │ - Size: 1Gi                                          │    │    │
│  │  │ - StorageClass: local-path                           │    │    │
│  │  │ - Access: ReadWriteOnce                              │    │    │
│  │  └──────────────────────────────────────────────────────┘    │    │
│  │                                                                │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ Namespace: kube-system                                         │    │
│  │                                                                 │    │
│  │  ┌─────────────────────────────────────────────────────────┐  │    │
│  │  │ Ingress: netbird-ingress (Traefik)                     │  │    │
│  │  │ - Host: netbird.k3s.dahan.house                        │  │    │
│  │  │ - TLS: netbird-tls (cert-manager)                      │  │    │
│  │  │ - Backend: netbird:80                                  │  │    │
│  │  │ - Entrypoints: web (80), websecure (443)              │  │    │
│  │  │                                                         │  │    │
│  │  │  ┌──────────────────────────────────────────────┐     │  │    │
│  │  │  │ Certificate: netbird-tls                     │     │  │    │
│  │  │  │ - Issuer: letsencrypt-dns (ClusterIssuer)    │     │  │    │
│  │  │  │ - DNS: netbird.k3s.dahan.house               │     │  │    │
│  │  │  │ - Provider: Cloudflare DNS-01                │     │  │    │
│  │  │  │ - Secret: netbird-tls                        │     │  │    │
│  │  │  └──────────────────────────────────────────────┘     │  │    │
│  │  └─────────────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ Namespace: metallb-system                                      │    │
│  │                                                                 │    │
│  │  ┌─────────────────────────────────────────────────────────┐  │    │
│  │  │ IPAddressPool: first-pool                               │  │    │
│  │  │ - Range: 10.0.200.1 - 10.0.200.250                      │  │    │
│  │  │ - Auto-assign: true                                     │  │    │
│  │  └─────────────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘

                              │
                              │
                              ▼

┌─────────────────────────────────────────────────────────────────────────┐
│                         Network Access Paths                            │
│                                                                          │
│  1. Internal Cluster Access:                                            │
│     Service: netbird.netbird.svc.cluster.local:80                      │
│     └─> ClusterIP Service -> Pod:80                                    │
│                                                                          │
│  2. External LoadBalancer Access:                                       │
│     http://10.0.200.x:80 (MetalLB IP)                                  │
│     └─> LoadBalancer Service -> Pod:80                                 │
│                                                                          │
│  3. HTTPS Ingress Access:                                               │
│     https://netbird.k3s.dahan.house                                    │
│     └─> Traefik (443) -> Ingress -> Service:80 -> Pod:80              │
│                                                                          │
│  4. VPN Peer-to-Peer Access:                                            │
│     NetBird IP: 100.x.x.x (WireGuard tunnel)                           │
│     └─> Direct encrypted tunnel to other Netbird peers                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Traffic Flow

### HTTPS Request Flow

```
User Browser
    │
    │ 1. HTTPS Request
    │    https://netbird.k3s.dahan.house
    ▼
DNS Resolution
    │ netbird.k3s.dahan.house -> 10.0.200.2 (Traefik LoadBalancer)
    ▼
Traefik Ingress Controller
    │ 2. TLS Termination (cert-manager certificate)
    │ 3. Route matching (host: netbird.k3s.dahan.house)
    ▼
Netbird ClusterIP Service (netbird:80)
    │ 4. Service selector matches pod labels
    ▼
Netbird Client Pod
    │ 5. Container responds on port 80
    ▼
Response flows back through same path
```

### VPN Connection Flow

```
Netbird Peer
    │
    │ 1. WireGuard Encrypted Tunnel
    │    Peer IP: 100.x.x.x
    ▼
Netbird Management Server
    │ 2. Peer discovery and handshake
    ▼
k3s Netbird Client Pod
    │ 3. Establish direct peer-to-peer connection
    │    or relay if direct not possible
    ▼
Encrypted Communication
    │ 4. All traffic encrypted via WireGuard
    │    Direct access to k3s services
    ▼
k3s Cluster Resources
```

## Component Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                    Dependencies                             │
└─────────────────────────────────────────────────────────────┘

Netbird Client Pod
    ├─> Requires: Namespace (netbird)
    ├─> Requires: PVC (netbird-config) for state persistence
    ├─> Requires: Secret (netbird-setup-key) for authentication
    ├─> Requires: Capabilities (NET_ADMIN, SYS_ADMIN, SYS_RESOURCE)
    └─> Connects to: Netbird Management Server (internet)

ClusterIP Service
    └─> Selects: Pods with label app.kubernetes.io/name=netbird-client

LoadBalancer Service
    ├─> Selects: Pods with label app.kubernetes.io/name=netbird-client
    └─> Requires: MetalLB (for IP assignment)

Ingress
    ├─> Requires: Traefik (IngressController)
    ├─> Routes to: netbird ClusterIP Service
    └─> Uses: TLS Certificate from cert-manager

Certificate
    ├─> Requires: cert-manager
    ├─> Requires: ClusterIssuer (letsencrypt-dns)
    └─> Uses: Cloudflare DNS-01 challenge
```

## Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Security Layers                          │
└─────────────────────────────────────────────────────────────┘

1. Network Layer:
   - WireGuard encryption for all VPN traffic
   - TLS/HTTPS for web access (Let's Encrypt)
   - Network isolation via namespace

2. Authentication:
   - Netbird setup key (stored in Kubernetes Secret)
   - Peer authentication via Netbird management server
   - Certificate-based TLS

3. Authorization:
   - Kubernetes RBAC (namespace scoped)
   - Netbird access control policies
   - Pod security context with limited capabilities

4. Container Security:
   - Required capabilities: NET_ADMIN, SYS_ADMIN, SYS_RESOURCE
   - Resource limits enforced
   - Non-root user (if configured)

5. Data Protection:
   - Persistent storage for configuration
   - Secrets encrypted at rest (Kubernetes default)
   - Encrypted VPN tunnels
```

## Monitoring Points

```
┌─────────────────────────────────────────────────────────────┐
│              Key Monitoring Metrics                         │
└─────────────────────────────────────────────────────────────┘

Pod Health:
├─> Pod Status (Running/CrashLoopBackOff)
├─> Container Restarts
├─> Resource Usage (CPU/Memory)
└─> Liveness/Readiness Probes (if configured)

Network:
├─> LoadBalancer IP Assignment
├─> Ingress Accessibility
├─> Certificate Validity
└─> DNS Resolution

Netbird Specific:
├─> Management Connection Status
├─> Signal Connection Status
├─> Active Peers Count
├─> VPN Tunnel Status
└─> Connection Latency

Logs:
├─> Pod Logs (kubectl logs)
├─> Traefik Logs (routing)
├─> Cert-manager Logs (certificates)
└─> MetalLB Logs (IP assignment)
```

## Deployment Order

```
Fleet GitOps Auto-Deployment Sequence:

1. Namespace Creation
   └─> netbird namespace

2. Storage Provisioning
   └─> PVC: netbird-config (1Gi)

3. Workload Deployment
   └─> Deployment: netbird-client
       └─> Creates Pod with container

4. Service Exposure
   ├─> ClusterIP Service: netbird
   └─> LoadBalancer Service: netbird-lb
       └─> MetalLB assigns IP from pool

5. External Access
   └─> Ingress: netbird-ingress
       └─> Traefik configures routing
           └─> Cert-manager issues certificate
               └─> Cloudflare DNS-01 validation
                   └─> Certificate stored in Secret
```

## High Availability Considerations

Current Configuration:
- Single replica (replicas: 1)
- Single PVC (ReadWriteOnce)
- Not designed for HA

For HA (Future):
- Multiple replicas would require separate setup keys
- Each replica would be a separate Netbird peer
- Shared configuration storage would need different approach
- Consider StatefulSet for stable network identities

## Scaling Considerations

Vertical Scaling:
```yaml
resources:
  requests:
    memory: "128Mi"  # Can increase for more peers
    cpu: "100m"      # Can increase for higher throughput
  limits:
    memory: "512Mi"  # Adjust based on monitoring
    cpu: "500m"      # Adjust based on traffic
```

Horizontal Scaling:
- Not recommended for VPN client
- Each pod would be a separate peer
- Consider routing peers for subnet access instead

## Integration Points

External Systems:
- Netbird Management Server (cloud or self-hosted)
- Netbird Signal Server (for peer coordination)
- STUN/TURN servers (for NAT traversal)
- Cloudflare DNS (for certificate validation)
- Let's Encrypt (for certificate issuance)

Internal Systems:
- MetalLB (IP allocation)
- Traefik (ingress routing)
- Cert-manager (TLS certificates)
- Local-path provisioner (storage)
- Fleet GitOps (deployment automation)

## Data Flow

Configuration Data:
```
netbird-config PVC (1Gi)
    └─> Mounted at /etc/netbird
        ├─> Peer private key
        ├─> Connection state
        ├─> Routing configuration
        └─> Local settings

Preserved across pod restarts
```

Environment Data:
```
Environment Variables
    ├─> NB_SETUP_KEY (from Secret)
    │   └─> Used for initial authentication
    ├─> NB_HOSTNAME
    │   └─> Identifies peer in network
    └─> TZ
        └─> Timezone for logs
```

## Network Topology

```
Internet
    │
    ├─> HTTPS (443) -> Traefik (10.0.200.2)
    │       └─> netbird.k3s.dahan.house
    │           └─> Netbird Pod
    │
    ├─> HTTP (80) -> LoadBalancer (10.0.200.x)
    │       └─> Netbird Pod
    │
    └─> WireGuard -> Netbird Management
            └─> Peer Discovery
                └─> Direct P2P or Relay
                    └─> Netbird Pod (100.x.x.x)
```

## Summary

This architecture provides:
- Secure VPN connectivity via WireGuard
- Multiple access methods (HTTPS, LoadBalancer, VPN)
- Automatic certificate management
- Persistent configuration storage
- Resource-limited container
- GitOps-based deployment
- Comprehensive monitoring points

The deployment integrates seamlessly with existing k3s infrastructure (Traefik, cert-manager, MetalLB) while providing secure peer-to-peer VPN connectivity through Netbird.
