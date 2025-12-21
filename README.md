# K3s GitOps Repository

This repository contains Kubernetes manifests for a K3s cluster managed via Fleet GitOps.

## Overview

This is a GitOps-managed K3s cluster deployment using Rancher Fleet. Changes pushed to this repository are automatically synchronized to the cluster.

### Deployed Applications

- **AdGuard Home**: DNS-based ad blocker and privacy protection
- **Traefik**: Ingress controller with Let's Encrypt integration
- **Cert-Manager**: Automated certificate management

## Repository Structure

```
.
├── manifests/                    # Kubernetes manifests
│   ├── adguard/                 # AdGuard Home deployment
│   │   ├── 00-namespace.yaml
│   │   ├── 01-adguard-pvc.yaml
│   │   ├── 02-adguard-deployment.yaml
│   │   ├── 03-adguard-service-lb.yaml
│   │   ├── 04-adguard-service-cluster.yaml
│   │   └── 05-adguard-ingress-traefik.yaml
│   ├── traefik/                 # Traefik configuration
│   │   ├── 01-cloudflare-secret.yaml
│   │   ├── 02-traefik-config.yaml
│   │   ├── 03-dashboard-auth.yaml
│   │   └── 04-dashboard-ingressroute.yaml
│   └── cert-manager/            # Certificate management
│       ├── 01-cloudflare-secret.yaml
│       ├── 02-cluster-issuer.yaml
│       └── 03-wildcard-certificate.yaml
├── fleet.yaml                    # Fleet GitOps configuration
├── DEPLOYMENT_SUMMARY.md        # Deployment documentation
├── VERIFICATION_REPORT.md       # Verification results
└── README.md                    # This file
```

## GitOps Workflow

### How It Works

1. **Commit Changes**: Make changes to manifests and commit to this repository
2. **Push to GitHub**: Push commits to the `main` branch
3. **Fleet Sync**: Fleet detects changes and syncs them to the cluster
4. **Automatic Apply**: Kubernetes resources are automatically updated

### Fleet Configuration

The cluster monitors this repository via a `GitRepo` resource in the `fleet-local` namespace. Fleet polls the repository every 15 seconds for changes.

```yaml
apiVersion: fleet.cattle.io/v1alpha1
kind: GitRepo
metadata:
  name: k3s-manifests
  namespace: fleet-local
spec:
  repo: https://github.com/yochanan2007/k3s.git
  branch: main
  paths:
  - manifests/
```

## Cluster Information

### Infrastructure
- **K3s Version**: v1.33.6+k3s1
- **Node**: k3s (control-plane)
- **MetalLB IP Pool**: 10.0.0.240-241

### Service Endpoints

| Service | Type | IP/Domain | Ports |
|---------|------|-----------|-------|
| AdGuard Home | LoadBalancer | 10.0.0.240 | HTTP:80, DNS:53 |
| AdGuard Ingress | Ingress | dahan.house | HTTP:80 |
| Traefik | LoadBalancer | 10.0.0.241 | HTTP:80, HTTPS:443 |
| Traefik Dashboard | IngressRoute | traefik.k3s.dahan.house | HTTPS:443 |

### Certificates

- **ClusterIssuer**: letsencrypt-dns (Let's Encrypt production with Cloudflare DNS-01)
- **Wildcard Certificate**: k3s.dahan.house, *.k3s.dahan.house

## Making Changes

### Step-by-Step Guide

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yochanan2007/k3s.git
   cd k3s
   ```

2. **Make your changes**:
   - Edit manifest files in `manifests/` directory
   - Test locally if possible

3. **Commit changes**:
   ```bash
   git add manifests/
   git commit -m "Description of changes"
   ```

4. **Push to GitHub**:
   ```bash
   git push origin main
   ```

5. **Verify sync**:
   ```bash
   # Check Fleet status
   kubectl get gitrepo -n fleet-local

   # Check bundle status
   kubectl get bundles -n fleet-local

   # Check deployed resources
   kubectl get all -n <namespace>
   ```

### Best Practices

1. **Test Before Committing**: Validate YAML syntax using `kubectl apply --dry-run=client`
2. **Small Commits**: Make atomic commits for easier troubleshooting
3. **Descriptive Messages**: Write clear commit messages explaining the "why"
4. **Review Changes**: Check Fleet sync status after pushing

## Secrets Management

### Important Security Notes

This repository contains secrets in base64-encoded format. For production use, consider:

1. **SealedSecrets**: Encrypt secrets before committing
2. **External Secrets Operator**: Pull secrets from external vaults
3. **SOPS**: Encrypt sensitive data with GPG/KMS

### Current Secrets

The following secrets need rotation/updating for production:

- `manifests/traefik/01-cloudflare-secret.yaml`: Cloudflare API token
- `manifests/cert-manager/01-cloudflare-secret.yaml`: Cloudflare API token (placeholder)
- `manifests/traefik/03-dashboard-auth.yaml`: Traefik dashboard credentials

## Monitoring Fleet

### Check GitRepo Status
```bash
kubectl get gitrepo -n fleet-local
kubectl describe gitrepo k3s-manifests -n fleet-local
```

### Check Bundle Status
```bash
kubectl get bundles -n fleet-local
kubectl describe bundle k3s-manifests -n fleet-local
```

### View Fleet Logs
```bash
# Fleet controller logs
kubectl logs -n cattle-fleet-system deployment/fleet-controller

# GitJob logs
kubectl logs -n cattle-fleet-system deployment/gitjob
```

## Troubleshooting

### Fleet Not Syncing

1. **Check GitRepo status**:
   ```bash
   kubectl get gitrepo -n fleet-local -o yaml
   ```

2. **Verify repository accessibility**:
   - Ensure GitHub repository is public or credentials are configured
   - Check network connectivity from cluster

3. **Check Fleet controller logs**:
   ```bash
   kubectl logs -n cattle-fleet-system deployment/fleet-controller -f
   ```

### Resources Not Applying

1. **Check bundle status**:
   ```bash
   kubectl get bundles -n fleet-local
   kubectl describe bundle <bundle-name> -n fleet-local
   ```

2. **Verify manifest syntax**:
   ```bash
   kubectl apply --dry-run=client -f manifests/
   ```

3. **Check resource events**:
   ```bash
   kubectl get events -n <namespace> --sort-by='.lastTimestamp'
   ```

## Documentation

- **DEPLOYMENT_SUMMARY.md**: Detailed deployment information
- **VERIFICATION_REPORT.md**: Manifest verification against cluster state
- **manifests/README.md**: Manifest-specific documentation

## Links

- **GitHub Repository**: https://github.com/yochanan2007/k3s
- **Fleet Documentation**: https://fleet.rancher.io/
- **K3s Documentation**: https://docs.k3s.io/

## License

This configuration is for personal/internal use.

## Maintainer

yochanan2007 (yochanan2007@gmail.com)
