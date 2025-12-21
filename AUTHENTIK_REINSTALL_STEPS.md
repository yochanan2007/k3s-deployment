# Authentik Reinstallation Steps - 2025.10.3

**Date**: 2025-12-21
**Previous Version**: 2024.12.1 (with Redis)
**New Version**: 2025.10.3 (Redis removed)

**IMPORTANT:** Execute these commands on the K3s cluster (10.0.0.210) as user `johnd`

## Key Changes in 2025.10.3

- Redis is NO LONGER REQUIRED (removed in version 2025.10)
- Redis manifests (04-06) have been deleted
- All Redis environment variables removed from server and worker deployments
- PostgreSQL remains as the only backend database

## Phase 1: Backup Secrets (REQUIRED BEFORE DESTRUCTION)

```bash
# Backup PostgreSQL credentials
kubectl get secret authentik-postgresql -n authentik -o yaml > /tmp/backup-authentik-postgresql-secret.yaml

# Backup Authentik secret key
kubectl get secret authentik-secret-key -n authentik -o yaml > /tmp/backup-authentik-secret-key.yaml

# Verify backups exist
ls -lh /tmp/backup-authentik-*.yaml
```

## Phase 2: Destroy Current Deployment

```bash
# Delete all Authentik resources in order (reverse of deployment)
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

# Verify all resources are deleted (except namespace and PVCs if you want to preserve data)
kubectl get all -n authentik

# Optional: Delete secrets if you want fresh ones (NOT RECOMMENDED - will lose data)
# kubectl delete secret authentik-postgresql -n authentik
# kubectl delete secret authentik-secret-key -n authentik
```

## Phase 3: Restore Secrets (After new manifests are ready)

```bash
# Apply the backed-up secrets back to the cluster
kubectl apply -f /tmp/backup-authentik-postgresql-secret.yaml
kubectl apply -f /tmp/backup-authentik-secret-key.yaml

# Verify secrets are restored
kubectl get secrets -n authentik
```

## Phase 4: Deploy New Version (After git updates)

```bash
# Apply updated manifests in order
kubectl apply -f manifests/authentik/00-namespace.yaml
kubectl apply -f manifests/authentik/01-postgresql-pvc.yaml
kubectl apply -f manifests/authentik/02-postgresql-statefulset.yaml
kubectl apply -f manifests/authentik/03-postgresql-service.yaml
# Note: Redis manifests (04-06) are REMOVED in 2025.10.3
kubectl apply -f manifests/authentik/07-authentik-server-deployment.yaml
kubectl apply -f manifests/authentik/08-authentik-worker-deployment.yaml
kubectl apply -f manifests/authentik/09-authentik-service-cluster.yaml
kubectl apply -f manifests/authentik/10-authentik-service-lb.yaml
kubectl apply -f manifests/authentik/11-authentik-ingress.yaml
kubectl apply -f manifests/authentik/12-authentik-certificate.yaml
```

## Phase 5: Verification

```bash
# Check pods are running
kubectl get pods -n authentik -w

# Check services
kubectl get svc -n authentik

# Check certificate
kubectl get certificate -n authentik

# Check logs
kubectl logs -n authentik -l app.kubernetes.io/component=server --tail=50
kubectl logs -n authentik -l app.kubernetes.io/component=worker --tail=50

# Test access
curl -k https://auth.k3s.dahan.house/-/health/live/
```

## Notes

- **Redis Removal:** Version 2025.10.3 no longer uses Redis for caching
- **PostgreSQL:** Retained for persistent data storage
- **Secrets:** Must be backed up before destruction to preserve credentials
- **PVCs:** PostgreSQL PVC should be retained to preserve user data
