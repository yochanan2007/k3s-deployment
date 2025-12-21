# Authentik 2025.10.3 Fresh Installation Summary

**Date**: 2025-12-21
**Previous Version**: 2024.12.1 (with Redis)
**New Version**: 2025.10.3 (Redis removed)
**Branch**: authentik-fresh-install-2025.10.3
**Pushed to**: claude-edits (as per CLAUDE.md requirements)

## Summary

Successfully prepared the k3s-deployment repository for a fresh Authentik 2025.10.3 installation. The major change in this version is the **removal of Redis**, which is no longer required as of Authentik 2025.10.

## Changes Made

### 1. Removed Redis Components

Deleted three Redis manifest files:
- `manifests/authentik/04-redis-pvc.yaml`
- `manifests/authentik/05-redis-statefulset.yaml`
- `manifests/authentik/06-redis-service.yaml`

### 2. Updated Authentik Deployments

**File**: `manifests/authentik/07-authentik-server-deployment.yaml`
- Updated image tag: `2024.12.1` → `2025.10.3`
- Removed Redis environment variables:
  - `AUTHENTIK_REDIS__HOST`
  - `AUTHENTIK_REDIS__PORT`

**File**: `manifests/authentik/08-authentik-worker-deployment.yaml`
- Updated image tag: `2024.12.1` → `2025.10.3`
- Removed Redis environment variables:
  - `AUTHENTIK_REDIS__HOST`
  - `AUTHENTIK_REDIS__PORT`

### 3. Updated Documentation

**File**: `AUTHENTIK_DEPLOYMENT.md`
- Added version information (2025.10.3)
- Updated architecture diagram (removed Redis)
- Updated deployment order (removed Redis steps)
- Updated service table (removed Redis entry)
- Updated resource allocation section (removed Redis)
- Updated health checks section (removed Redis)
- Updated troubleshooting section (removed Redis verification)

**File**: `AUTHENTIK_REINSTALL_STEPS.md` (NEW)
- Complete step-by-step reinstallation guide
- Secret backup procedures
- Deployment destruction steps
- Fresh installation instructions
- Verification procedures

### 4. Preserved Components

The following remain unchanged:
- PostgreSQL 16 StatefulSet (10Gi storage)
- Authentik Server deployment
- Authentik Worker deployment
- Services (ClusterIP and LoadBalancer)
- Ingress (Traefik with cert-manager)
- Certificate (Let's Encrypt wildcard)

## Git Status

**Branch**: `authentik-fresh-install-2025.10.3`
**Commit**: e832df5
**Pushed to**: `origin/claude-edits`

**Changes committed**:
```
M  AUTHENTIK_DEPLOYMENT.md
A  AUTHENTIK_REINSTALL_STEPS.md
D  manifests/authentik/04-redis-pvc.yaml
D  manifests/authentik/05-redis-statefulset.yaml
D  manifests/authentik/06-redis-service.yaml
M  manifests/authentik/07-authentik-server-deployment.yaml
M  manifests/authentik/08-authentik-worker-deployment.yaml
```

## Next Steps - CLUSTER OPERATIONS REQUIRED

You must now execute the following steps **on the K3s cluster (10.0.0.210)** to complete the reinstallation:

### Phase 1: Backup Secrets

```bash
# SSH to K3s cluster
ssh johnd@10.0.0.210

# Backup PostgreSQL credentials
kubectl get secret authentik-postgresql -n authentik -o yaml > /tmp/backup-authentik-postgresql-secret.yaml

# Backup Authentik secret key
kubectl get secret authentik-secret-key -n authentik -o yaml > /tmp/backup-authentik-secret-key.yaml

# Verify backups exist
ls -lh /tmp/backup-authentik-*.yaml
```

### Phase 2: Destroy Current Deployment

```bash
# Delete all Authentik resources (reverse order)
kubectl delete -f manifests/authentik/12-authentik-certificate.yaml
kubectl delete -f manifests/authentik/11-authentik-ingress.yaml
kubectl delete -f manifests/authentik/10-authentik-service-lb.yaml
kubectl delete -f manifests/authentik/09-authentik-service-cluster.yaml
kubectl delete -f manifests/authentik/08-authentik-worker-deployment.yaml
kubectl delete -f manifests/authentik/07-authentik-server-deployment.yaml
kubectl delete -f manifests/authentik/06-redis-service.yaml
kubectl delete -f manifests/authentik/05-redis-statefulset.yaml
kubectl delete -f manifests/authentik/04-redis-pvc.yaml
kubectl delete -f manifests/authentik/03-postgresql-service.yaml
kubectl delete -f manifests/authentik/02-postgresql-statefulset.yaml
kubectl delete -f manifests/authentik/01-postgresql-pvc.yaml

# Verify all resources are deleted
kubectl get all -n authentik
```

### Phase 3: Pull Updated Manifests

```bash
# Navigate to k3s-deployment repository
cd /path/to/k3s-deployment

# Fetch latest changes
git fetch origin

# Checkout the new branch (or merge to main first if preferred)
git checkout claude-edits

# Verify Redis files are deleted
ls -la manifests/authentik/
```

### Phase 4: Restore Secrets

```bash
# Apply backed-up secrets
kubectl apply -f /tmp/backup-authentik-postgresql-secret.yaml
kubectl apply -f /tmp/backup-authentik-secret-key.yaml

# Verify secrets exist
kubectl get secrets -n authentik
```

### Phase 5: Deploy Authentik 2025.10.3

```bash
# Apply updated manifests in order
kubectl apply -f manifests/authentik/00-namespace.yaml
kubectl apply -f manifests/authentik/01-postgresql-pvc.yaml
kubectl apply -f manifests/authentik/02-postgresql-statefulset.yaml
kubectl apply -f manifests/authentik/03-postgresql-service.yaml
# Note: Redis files (04-06) are now DELETED
kubectl apply -f manifests/authentik/07-authentik-server-deployment.yaml
kubectl apply -f manifests/authentik/08-authentik-worker-deployment.yaml
kubectl apply -f manifests/authentik/09-authentik-service-cluster.yaml
kubectl apply -f manifests/authentik/10-authentik-service-lb.yaml
kubectl apply -f manifests/authentik/11-authentik-ingress.yaml
kubectl apply -f manifests/authentik/12-authentik-certificate.yaml
```

### Phase 6: Verify Deployment

```bash
# Watch pods come up
kubectl get pods -n authentik -w

# Expected pods:
# - postgresql-0
# - authentik-server-xxx
# - authentik-worker-xxx
# (NO redis-0 anymore!)

# Check all resources
kubectl get all -n authentik

# Check certificate
kubectl get certificate -n authentik
kubectl describe certificate authentik-k3s-dahan-house -n authentik

# Check logs
kubectl logs -n authentik -l app.kubernetes.io/component=server --tail=50
kubectl logs -n authentik -l app.kubernetes.io/component=worker --tail=50

# Test health endpoints
kubectl exec -n authentik -l app.kubernetes.io/component=server -- curl -s http://localhost:9000/-/health/live/
kubectl exec -n authentik -l app.kubernetes.io/component=worker -- ak healthcheck

# Test external access (after certificate is Ready)
curl -k https://auth.k3s.dahan.house/-/health/live/
```

## Verification Checklist

- [ ] Secrets backed up before destruction
- [ ] Old deployment completely destroyed
- [ ] PostgreSQL data preserved (if using persistent volume)
- [ ] Updated manifests deployed successfully
- [ ] No Redis pods running (expected)
- [ ] PostgreSQL pod running
- [ ] Authentik server pod running
- [ ] Authentik worker pod running
- [ ] LoadBalancer IP assigned
- [ ] Certificate issued (status: Ready)
- [ ] HTTPS access working: https://auth.k3s.dahan.house
- [ ] Health endpoints responding
- [ ] No Redis-related errors in logs

## Architecture After Installation

```
authentik namespace (10.0.0.210)
├── PostgreSQL 16 (StatefulSet)
│   ├── Pod: postgresql-0
│   ├── Storage: 10Gi PVC
│   └── Service: postgresql:5432 (ClusterIP)
├── Authentik Server (Deployment)
│   ├── Image: ghcr.io/goauthentik/server:2025.10.3
│   ├── Ports: 9000 (HTTP), 9443 (HTTPS), 9300 (metrics)
│   └── Health: /-/health/live/, /-/health/ready/
├── Authentik Worker (Deployment)
│   ├── Image: ghcr.io/goauthentik/server:2025.10.3
│   ├── Port: 9300 (metrics)
│   └── Health: ak healthcheck
├── Services
│   ├── authentik (ClusterIP): 80, 443
│   └── authentik-lb (LoadBalancer): 80, 443
├── Ingress
│   ├── Host: auth.k3s.dahan.house
│   ├── Controller: Traefik
│   └── TLS: cert-manager + Let's Encrypt
└── Certificate
    ├── Name: authentik-k3s-dahan-house
    ├── Secret: authentik-k3s-dahan-house-tls
    └── Issuer: letsencrypt-dns (DNS-01 via Cloudflare)
```

## Important Notes

1. **Redis is Gone**: Version 2025.10.3 does NOT use Redis. Do not try to deploy Redis manifests.

2. **Secret Preservation**: The backed-up secrets (PostgreSQL credentials and Authentik secret key) are CRITICAL. Without them:
   - PostgreSQL authentication will fail
   - User sessions will be invalidated
   - Some user data may become inaccessible

3. **PostgreSQL Data**: If the PostgreSQL PVC was preserved during destruction, all existing user accounts and configurations will be retained.

4. **Environment Variables**: The manifests no longer contain `AUTHENTIK_REDIS__HOST` or `AUTHENTIK_REDIS__PORT`. This is expected and correct.

5. **Manual Merge to Main**: As per CLAUDE.md, the changes are pushed to `claude-edits` branch. You must manually merge to `main` when ready.

## Troubleshooting

### If Pods Fail to Start

```bash
# Check pod status
kubectl describe pod -n authentik <pod-name>

# Check logs
kubectl logs -n authentik <pod-name>

# Common issues:
# - Missing secrets: kubectl get secrets -n authentik
# - PostgreSQL not ready: kubectl logs -n authentik postgresql-0
# - Resource limits: Check node resources with kubectl top nodes
```

### If Certificate Doesn't Issue

```bash
# Check certificate details
kubectl describe certificate authentik-k3s-dahan-house -n authentik

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check challenge status
kubectl get challenges -n authentik
kubectl describe challenge -n authentik <challenge-name>

# Verify Cloudflare secret exists
kubectl get secret cloudflare-api-token -n authentik
```

### If Ingress Doesn't Work

```bash
# Check ingress
kubectl describe ingress authentik-ingress -n authentik

# Check Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

# Verify LoadBalancer IP
kubectl get svc authentik-lb -n authentik
```

## Files to Review

1. `D:\claude\k3s-deployment\AUTHENTIK_REINSTALL_STEPS.md` - Complete reinstallation guide
2. `D:\claude\k3s-deployment\AUTHENTIK_DEPLOYMENT.md` - Updated deployment documentation
3. `D:\claude\k3s-deployment\manifests\authentik\07-authentik-server-deployment.yaml` - Server deployment (2025.10.3)
4. `D:\claude\k3s-deployment\manifests\authentik\08-authentik-worker-deployment.yaml` - Worker deployment (2025.10.3)

## References

- [Authentik 2025.10 Release Notes](https://goauthentik.io/docs/releases/2025.10)
- [Authentik Kubernetes Installation](https://docs.goauthentik.io/install-config/install/kubernetes/)
- Repository: https://github.com/yochanan2007/k3s-deployment/tree/claude-edits
