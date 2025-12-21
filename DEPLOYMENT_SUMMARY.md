# K3s Deployment Summary

## Cluster Information

**Server**: 10.0.0.210 (k3s node)
**K3s Version**: v1.33.6+k3s1
**Cluster Age**: ~19 hours
**Status**: Fully operational

## Gathered Configurations

All configuration files have been downloaded from `/home/johnd/` on the k3s server and organized into the `manifests/` directory locally.

### Infrastructure Components

#### 1. MetalLB
- **Status**: Running
- **Purpose**: LoadBalancer implementation for bare metal
- **IP Pool**: 10.0.0.240-241 (confirmed in use)

#### 2. Traefik Ingress Controller
- **Version**: rancher/mirrored-library-traefik:3.5.1
- **LoadBalancer IP**: 10.0.0.241
- **Features**:
  - Let's Encrypt ACME with Cloudflare DNS-01 challenge
  - Dashboard enabled at `traefik.k3s.dahan.house` (HTTPS + BasicAuth)
  - Prometheus metrics enabled
  - Certificate persistence (128Mi PVC)
- **Configuration**: HelmChartConfig in kube-system namespace

#### 3. Cert-Manager
- **Status**: Running
- **ClusterIssuer**: letsencrypt-dns (Cloudflare DNS-01)
- **Active Certificates**:
  - `k3s-dahan-house-wildcard` → Secret: `k3s-dahan-house-tls`
  - `tls-rancher-ingress` → Secret: `tls-rancher-ingress`

### Application Deployments

#### AdGuard Home
- **Namespace**: adguard
- **Image**: adguard/adguardhome:v0.107.56
- **Status**: Running (1/1 replicas)
- **Access Points**:
  - LoadBalancer: 10.0.0.240 (HTTP:80, DNS:53 TCP/UDP)
  - Ingress: dahan.house (HTTP)
- **Storage**:
  - config: 1Gi PVC
  - data: 10Gi PVC

#### Rancher
- **Namespace**: cattle-system
- **Status**: Running
- **URL**: rancher.my.org (HTTPS with TLS certificate)
- **Additional Components**:
  - Fleet GitOps system
  - System upgrade controller
  - Rancher Turtles (CAPI integration)

## Configuration Files Organized

```
manifests/
├── README.md                              # Detailed documentation
├── adguard/
│   ├── 00-namespace.yaml                  # adguard namespace
│   ├── 01-adguard-pvc.yaml               # Storage (1Gi config + 10Gi data)
│   ├── 02-adguard-deployment.yaml        # Main deployment
│   ├── 03-adguard-service-lb.yaml        # LoadBalancer service (10.0.0.240)
│   ├── 04-adguard-service-cluster.yaml   # ClusterIP service
│   └── 05-adguard-ingress-traefik.yaml   # HTTP ingress
├── traefik/
│   ├── 01-cloudflare-secret.yaml         # Cloudflare API token
│   ├── 02-traefik-config.yaml            # HelmChartConfig with ACME
│   ├── 03-dashboard-auth.yaml            # BasicAuth for dashboard
│   └── 04-dashboard-ingressroute.yaml    # Dashboard IngressRoute (HTTPS)
└── cert-manager/
    ├── 01-cloudflare-secret.yaml         # Cloudflare API token for DNS-01
    ├── 02-cluster-issuer.yaml            # Let's Encrypt ClusterIssuer
    └── 03-wildcard-certificate.yaml      # *.k3s.dahan.house certificate
```

## Key Findings and Issues

### 1. Service Selector Mismatch (AdGuard)
**File**: `manifests/adguard/03-adguard-service-lb.yaml`
**Issue**: LoadBalancer service selector uses `app.kubernetes.io/name: adguard` but deployment uses `app.kubernetes.io/name: adguard-home`
**Impact**: LoadBalancer service cannot route traffic to pods
**Fix Required**: Update service selector to match deployment labels

### 2. Cloudflare Secret Namespace Requirements
**Locations**:
- Traefik needs it in `kube-system` namespace
- Cert-manager needs it in `cert-manager` namespace

**Current State**: Secret exists in `kube-system` (for Traefik)
**Action**: Ensure secret also exists in `cert-manager` namespace

### 3. Secrets to Rotate
- **Cloudflare API Token**: `UzhP_4E84cC_uELZIzqv8vZ7FNGx0QYJDMTfrLau`
  - Used in: Traefik and Cert-Manager
- **Traefik Dashboard Password**: `admin:$apr1$k6.O1y93$0x1W7Z6lSY0NgS4Ds/CEW1`

### 4. Email Configuration
- Let's Encrypt notifications: `yochanan2007@gmail.com`

## Network Configuration

### Domain Names
- **Primary**: dahan.house
- **K3s Subdomain**: k3s.dahan.house
- **Wildcard Certificate**: *.k3s.dahan.house
- **Traefik Dashboard**: traefik.k3s.dahan.house
- **Rancher**: rancher.my.org

### IP Addresses (MetalLB Pool)
- 10.0.0.240 - AdGuard Home (HTTP + DNS)
- 10.0.0.241 - Traefik (HTTP:80 + HTTPS:443)

## Current Cluster Services

### kube-system namespace
- traefik (LoadBalancer: 10.0.0.241)
- coredns
- metrics-server
- local-path-provisioner

### adguard namespace
- adguard (ClusterIP)
- adguard-lb (LoadBalancer: 10.0.0.240)

### cert-manager namespace
- cert-manager
- cert-manager-cainjector
- cert-manager-webhook

### cattle-system namespace
- rancher
- rancher-webhook
- system-upgrade-controller

### metallb-system namespace
- metallb-controller
- metallb-speaker

## Next Actions

1. **Fix AdGuard Service Selector**
   - Update `manifests/adguard/03-adguard-service-lb.yaml`
   - Change selector from `adguard` to `adguard-home`

2. **Review Secrets Strategy**
   - Decide if we want to keep Cloudflare token in version control
   - Consider using SealedSecrets or external secret management

3. **DNS Configuration**
   - Verify all domains point to correct IPs
   - Ensure dahan.house → 10.0.0.240 (AdGuard)
   - Ensure *.k3s.dahan.house → 10.0.0.241 (Traefik)

4. **Certificate Verification**
   - Check cert-manager logs for certificate issuance
   - Verify wildcard cert covers all required domains

5. **Testing Plan**
   - Test AdGuard at http://10.0.0.240 and http://dahan.house
   - Test Traefik dashboard at https://traefik.k3s.dahan.house
   - Verify DNS resolution through AdGuard

## MCP Connection Details

The `.mcp.json` file is configured to connect to the k3s server at 10.0.0.210:22 as user `johnd`.
