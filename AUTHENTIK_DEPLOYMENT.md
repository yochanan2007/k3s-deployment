# Authentik Deployment Guide

## Overview

Authentik is an open-source Identity Provider (IdP) focused on flexibility and versatility. This deployment follows the standard K3s deployment patterns with PostgreSQL as the backend database.

**Current Version**: 2025.10.3

**Important**: Starting with version 2025.10, Authentik no longer requires Redis for caching. Redis has been removed from this deployment.

## Architecture

```
authentik/
├── PostgreSQL 16 (StatefulSet)
│   └── 10Gi persistent storage
├── Authentik Server (Deployment)
│   └── Web interface on port 9000
└── Authentik Worker (Deployment)
    └── Background task processing
```

## Deployment Steps

### 1. Update Environment Configuration

Before deploying, you MUST update the `.env` file with secure values:

```bash
# Edit the .env file
nano .env
```

Update these values:

```bash
# Generate a secure PostgreSQL password (example):
AUTHENTIK_DB_PASSWORD=$(openssl rand -base64 32)

# Generate Authentik secret key (CRITICAL - never change after first install):
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60)
```

**IMPORTANT**: The `AUTHENTIK_SECRET_KEY` is used for cookie signing and unique user IDs. **NEVER** change this value after the initial installation, or all user sessions and some user data will become invalid!

### 2. Apply Secrets to the Cluster

The secrets are managed via the `apply-secrets.sh` script and are NOT committed to Git for security.

SSH into your K3s cluster and run:

```bash
# Copy the .env file to the k3s master node
scp .env k3s-master:/tmp/.env

# SSH to the k3s master
ssh k3s-master

# Run the secrets script
cd /path/to/k3s-deployment
cp /tmp/.env .
chmod +x apply-secrets.sh
./apply-secrets.sh
```

This will create:
- `cloudflare-api-token` secret in `authentik` namespace (for cert-manager DNS-01 challenges)
- `authentik-postgresql` secret with database credentials
- `authentik-secret-key` secret for Authentik application

### 3. Verify Flux Deployment

Since Flux CD is configured to auto-sync from the main branch, the deployment should start automatically after pushing to GitHub.

Monitor the deployment:

```bash
# Watch the authentik namespace
kubectl get pods -n authentik -w

# Check Flux reconciliation
flux get kustomizations

# Check certificate status
kubectl get certificate -n authentik
```

### 4. Expected Deployment Order

The manifests are numbered to ensure proper deployment order:

1. **00-namespace.yaml** - Creates `authentik` namespace
2. **01-03** - PostgreSQL (PVC, StatefulSet, Service)
3. **07-08** - Authentik (Server, Worker deployments)
4. **09-10** - Services (ClusterIP, LoadBalancer)
5. **11** - Ingress (Traefik)
6. **12** - Certificate (Let's Encrypt)

**Note**: Redis manifests (04-06) have been removed as of Authentik 2025.10.3

### 5. Verify Services

Check that all components are running:

```bash
# Check all resources in authentik namespace
kubectl get all -n authentik

# Expected output:
# - postgresql-0 (StatefulSet pod)
# - authentik-server-xxx (Deployment pod)
# - authentik-worker-xxx (Deployment pod)

# Check LoadBalancer IP assignment
kubectl get svc authentik-lb -n authentik

# Check certificate issuance
kubectl get certificate -n authentik
kubectl describe certificate authentik-k3s-dahan-house -n authentik
```

### 6. Verify HTTPS Access

Once the certificate is issued (status: Ready), access Authentik:

**URL**: https://auth.k3s.dahan.house

**IMPORTANT**: When accessing for the first time, you MUST include the trailing slash:

```
https://auth.k3s.dahan.house/if/flow/initial-setup/
```

Without the trailing slash, you'll get a "Not Found" error.

## Initial Setup

### First-Time Configuration

1. Navigate to: `https://auth.k3s.dahan.house/if/flow/initial-setup/`
2. Create your initial admin account (akadmin)
3. Set a strong password
4. You'll be redirected to the Authentik admin interface

### Admin Interface

- **URL**: https://auth.k3s.dahan.house/if/admin/
- **Default username**: akadmin (or what you created)
- **Change password**: Admin Interface > User Settings

## Network Configuration

### Services

| Service | Type | Port | IP |
|---------|------|------|-----|
| authentik | ClusterIP | 80, 443 | Internal only |
| authentik-lb | LoadBalancer | 80, 443 | Auto-assigned from MetalLB pool |
| postgresql | ClusterIP | 5432 | Internal only |

### Ingress

- **Domain**: auth.k3s.dahan.house
- **Ingress Controller**: Traefik v3.5.1
- **TLS**: Let's Encrypt (DNS-01 via Cloudflare)
- **Certificate**: Auto-renewed by cert-manager

## Storage

### PostgreSQL Data

- **PVC**: postgresql-data
- **Size**: 10Gi
- **Access Mode**: ReadWriteOnce
- **Provisioner**: K3s local-path-provisioner

## Resource Allocation

### PostgreSQL

- **Requests**: 250m CPU, 256Mi memory
- **Limits**: 1000m CPU, 1Gi memory

### Authentik Server

- **Requests**: 250m CPU, 512Mi memory
- **Limits**: 1000m CPU, 2Gi memory

### Authentik Worker

- **Requests**: 250m CPU, 512Mi memory
- **Limits**: 1000m CPU, 2Gi memory

## Health Checks

All services have properly configured health checks:

### PostgreSQL

- **Liveness**: pg_isready check every 10s
- **Readiness**: pg_isready check every 10s

### Authentik Server

- **Liveness**: HTTP GET /-/health/live/ every 10s
- **Readiness**: HTTP GET /-/health/ready/ every 5s

### Authentik Worker

- **Liveness**: `ak healthcheck` command every 30s
- **Readiness**: `ak healthcheck` command every 30s

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n authentik

# Check pod logs
kubectl logs -n authentik <pod-name>

# Describe pod for events
kubectl describe pod -n authentik <pod-name>
```

### Database Connection Issues

```bash
# Check PostgreSQL logs
kubectl logs -n authentik postgresql-0

# Verify secret exists
kubectl get secret authentik-postgresql -n authentik

# Test database connection from server pod
kubectl exec -it -n authentik <authentik-server-pod> -- \
  psql -h postgresql -U authentik -d authentik
```

### Certificate Not Issuing

```bash
# Check certificate status
kubectl describe certificate authentik-k3s-dahan-house -n authentik

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check for challenges
kubectl get challenges -n authentik
kubectl describe challenge -n authentik <challenge-name>

# Verify Cloudflare secret exists
kubectl get secret cloudflare-api-token -n authentik
```

### Ingress Not Working

```bash
# Check ingress status
kubectl get ingress -n authentik
kubectl describe ingress authentik-ingress -n authentik

# Check Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

# Verify LoadBalancer IP is assigned
kubectl get svc authentik-lb -n authentik
```

### Worker Not Processing Tasks

```bash
# Check worker logs
kubectl logs -n authentik -l app.kubernetes.io/component=worker

# Check worker health
kubectl exec -it -n authentik -l app.kubernetes.io/component=worker -- ak healthcheck
```

## Backup and Restore

### PostgreSQL Database Backup

```bash
# Create backup
kubectl exec -n authentik postgresql-0 -- \
  pg_dump -U authentik authentik > authentik-backup-$(date +%Y%m%d).sql

# Restore backup
kubectl exec -i -n authentik postgresql-0 -- \
  psql -U authentik authentik < authentik-backup-YYYYMMDD.sql
```

### PVC Backup

For persistent volume backups, use Velero or similar backup solutions configured for K3s.

## Upgrading Authentik

To upgrade Authentik to a newer version:

1. Update the image tag in the deployment manifests:
   - `manifests/authentik/07-authentik-server-deployment.yaml`
   - `manifests/authentik/08-authentik-worker-deployment.yaml`

2. Commit and push changes:

```bash
git add manifests/authentik/
git commit -m "feat: Upgrade Authentik to version X.Y.Z"
git push origin main
```

3. Flux will automatically deploy the new version.

4. Monitor the rollout:

```bash
kubectl rollout status deployment/authentik-server -n authentik
kubectl rollout status deployment/authentik-worker -n authentik
```

## Uninstalling

To remove Authentik from the cluster:

```bash
# Delete all resources
kubectl delete namespace authentik

# This will also delete:
# - All deployments and StatefulSets
# - All services
# - All PVCs and data
# - All secrets
# - The ingress and certificate
```

**WARNING**: This will permanently delete all Authentik data, including user accounts, applications, and configurations. Make sure to backup the PostgreSQL database first!

## Security Considerations

1. **Secret Key**: NEVER commit the `.env` file to Git. It contains sensitive credentials.

2. **PostgreSQL Password**: Use a strong, randomly generated password.

3. **Authentik Secret Key**: This is critical for security. Generate it once and never change it.

4. **Network Policies**: Consider implementing Kubernetes NetworkPolicies to restrict pod-to-pod communication.

5. **RBAC**: Authentik has its own RBAC system. Configure it properly for your organization.

6. **Reverse Proxy**: Authentik is configured to trust X-Forwarded-* headers from the 10.0.0.0/8 network (Traefik).

## Next Steps

After Authentik is deployed:

1. **Configure Applications**: Add your applications to Authentik as OAuth2/OIDC providers
2. **Setup Users and Groups**: Create your organization's users and groups
3. **Configure Flows**: Customize authentication flows for your needs
4. **Enable MFA**: Configure multi-factor authentication policies
5. **Setup Email**: Configure SMTP settings for password resets and notifications
6. **Backup Strategy**: Implement regular PostgreSQL backups

## References

- [Authentik Official Documentation](https://docs.goauthentik.io/)
- [Authentik Kubernetes Install Guide](https://docs.goauthentik.io/install-config/install/kubernetes/)
- [K3s Documentation](https://docs.k3s.io/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Cert-Manager Documentation](https://cert-manager.io/docs/)

## Support

For issues with:
- **Authentik functionality**: Check [Authentik GitHub Issues](https://github.com/goauthentik/authentik/issues)
- **K3s cluster**: Check [K3s GitHub Issues](https://github.com/k3s-io/k3s/issues)
- **This deployment**: Review the troubleshooting section or check the deployment patterns in `DEPLOYMENT_PATTERNS.md`
