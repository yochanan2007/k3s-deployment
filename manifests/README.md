# K3s Deployment Manifests

This directory contains Kubernetes manifests gathered from the k3s cluster at 10.0.0.210.

## Current Cluster Status

### Infrastructure
- **K3s Version**: v1.33.6+k3s1
- **Node**: k3s (control-plane, master)
- **Status**: Running for 19 hours
- **MetalLB IPs**:
  - Traefik LoadBalancer: 10.0.0.241
  - AdGuard LoadBalancer: 10.0.0.240

### Deployed Applications

#### AdGuard Home (namespace: adguard)
- **Status**: Running (1/1 replicas)
- **Image**: adguard/adguardhome:v0.107.56
- **Access**:
  - LoadBalancer: 10.0.0.240 (HTTP:80, DNS:53/TCP, DNS:53/UDP)
  - Ingress: dahan.house (HTTP only)
- **Storage**:
  - Config PVC: 1Gi
  - Data PVC: 10Gi

#### Traefik (namespace: kube-system)
- **Status**: Running
- **Image**: rancher/mirrored-library-traefik:3.5.1
- **Features**:
  - Let's Encrypt integration with Cloudflare DNS challenge
  - Dashboard at traefik.k3s.dahan.house (HTTPS with basic auth)
  - LoadBalancer IP: 10.0.0.241
- **Configuration**: HelmChartConfig with ACME resolver

#### Cert-Manager (namespace: cert-manager)
- **Status**: Running
- **Components**:
  - cert-manager
  - cert-manager-cainjector
  - cert-manager-webhook
- **ClusterIssuer**: letsencrypt-dns (Cloudflare DNS-01 challenge)
- **Certificates**:
  - k3s-dahan-house-wildcard (Ready) - covers k3s.dahan.house and *.k3s.dahan.house

#### Rancher (namespace: cattle-system)
- **Status**: Running
- **Access**: rancher.my.org
- **Certificate**: tls-rancher-ingress (Ready)

### Additional Components
- **MetalLB**: Deployed (controller + speaker)
- **Fleet**: Deployed for GitOps
- **Metrics Server**: Running

## Directory Structure

```
manifests/
├── adguard/
│   ├── 00-namespace.yaml
│   ├── 01-adguard-pvc.yaml
│   ├── 02-adguard-deployment.yaml
│   ├── 03-adguard-service-lb.yaml
│   ├── 04-adguard-service-cluster.yaml
│   └── 05-adguard-ingress-traefik.yaml
├── traefik/
│   ├── 01-cloudflare-secret.yaml
│   ├── 02-traefik-config.yaml
│   ├── 03-dashboard-auth.yaml
│   └── 04-dashboard-ingressroute.yaml
└── cert-manager/
    ├── 01-cloudflare-secret.yaml
    ├── 02-cluster-issuer.yaml
    └── 03-wildcard-certificate.yaml
```

## Secrets to Update

Before deploying to a new cluster, update these secrets:

1. **Cloudflare API Token** (in multiple files):
   - `manifests/traefik/01-cloudflare-secret.yaml`
   - `manifests/cert-manager/01-cloudflare-secret.yaml`
   - Current value: `UzhP_4E84cC_uELZIzqv8vZ7FNGx0QYJDMTfrLau`

2. **Traefik Dashboard Auth** (`manifests/traefik/03-dashboard-auth.yaml`):
   - Current user: `admin:$apr1$k6.O1y93$0x1W7Z6lSY0NgS4Ds/CEW1`
   - Generate new with: `htpasswd -nb admin yourpassword`

## Configuration Notes

### Email Address
- Let's Encrypt email: `yochanan2007@gmail.com` (used in Traefik config)

### Domain Names
- Main domain: `dahan.house`
- K3s subdomain: `k3s.dahan.house`
- Traefik dashboard: `traefik.k3s.dahan.house`
- Rancher: `rancher.my.org`

### Issues Found

1. **AdGuard Service Selector Mismatch**:
   - LoadBalancer service (`03-adguard-service-lb.yaml`) uses selector: `app.kubernetes.io/name: adguard`
   - Should be: `app.kubernetes.io/name: adguard-home` (to match deployment labels)

2. **Namespace Mismatch for Cloudflare Secret**:
   - Traefik expects secret in `kube-system` namespace
   - Cert-manager expects secret in `cert-manager` namespace
   - Need to create the secret in both namespaces

## Next Steps

1. Review and update all secrets with production values
2. Fix the AdGuard service selector issue
3. Ensure Cloudflare API token secret exists in both required namespaces
4. Set up proper DNS records for all domains
5. Review MetalLB IP allocation strategy
