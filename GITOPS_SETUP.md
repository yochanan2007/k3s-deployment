# GitOps Setup Documentation - Flux CD

**Date**: 2025-12-21
**Cluster**: k3s at 10.0.0.210
**Repository**: https://github.com/yochanan2007/k3s-deployment
**GitOps Tool**: Flux CD v2.7.5

## Overview

This K3s cluster is configured with a complete GitOps workflow using Flux CD. Any changes pushed to the GitHub repository are automatically detected and applied to the cluster within minutes.

## Architecture

```
GitHub Repository (main branch)
        |
        | (Flux pulls every 1 minute)
        v
Flux Source Controller
        |
        | (Detects changes)
        v
Flux Kustomize Controller
        |
        | (Applies manifests)
        v
K3s Cluster Resources
```

## Components Installed

### Flux CD v2.7.5
- **Namespace**: flux-system
- **Components**:
  - source-controller: Monitors Git repositories
  - kustomize-controller: Applies Kustomize manifests
  - helm-controller: Manages Helm releases
  - notification-controller: Sends notifications
  - image-reflector-controller: Scans image repositories
  - image-automation-controller: Updates image tags

### GitRepository Resource
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: k3s-deployment
  namespace: flux-system
spec:
  interval: 1m0s
  url: https://github.com/yochanan2007/k3s-deployment
  ref:
    branch: main
```

**Configuration**:
- Repository URL: https://github.com/yochanan2007/k3s-deployment
- Branch: main
- Sync Interval: 1 minute
- Access: Public repository (no authentication needed)

### Kustomization Resource
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: k3s-deployment
  namespace: flux-system
spec:
  interval: 5m0s
  path: ./manifests
  prune: true
  sourceRef:
    kind: GitRepository
    name: k3s-deployment
  timeout: 2m0s
  wait: false
```

**Configuration**:
- Manifest Path: ./manifests
- Reconciliation Interval: 5 minutes
- Pruning: Enabled (removes resources deleted from Git)
- Wait for Ready: Disabled (allows deployments requiring manual setup)
- Timeout: 2 minutes

## Managed Resources

All Kubernetes manifests in the `manifests/` directory are automatically managed:

### AdGuard Home (namespace: adguard)
- Namespace
- PersistentVolumeClaims (config: 1Gi, data: 10Gi)
- Deployment (1 replica)
- Services (LoadBalancer + ClusterIP)
- Ingress (Traefik)

### Traefik (namespace: kube-system)
- Cloudflare API Secret
- HelmChartConfig (modifies built-in K3s Traefik)
- Dashboard Authentication Secret
- Dashboard IngressRoute

### Cert-Manager (namespace: cert-manager)
- Cloudflare API Secret
- ClusterIssuer (Let's Encrypt DNS-01)
- Wildcard Certificate (*.k3s.dahan.house)

## GitOps Workflow

### How It Works

1. **Developer pushes changes** to GitHub repository
   ```bash
   git add manifests/
   git commit -m "Update deployment"
   git push origin main
   ```

2. **Flux detects changes** (within 1 minute)
   - Source Controller polls GitHub every minute
   - Downloads new commit if detected
   - Creates artifact for Kustomize Controller

3. **Flux applies changes** (within 5 minutes or immediately)
   - Kustomize Controller builds manifests
   - Applies changes using server-side apply
   - Updates cluster state to match Git

4. **Cluster is updated**
   - Resources are created, updated, or deleted
   - Flux reports status back to Kubernetes

### Making Changes

#### Method 1: Direct GitHub Edit
1. Navigate to https://github.com/yochanan2007/k3s-deployment
2. Edit files in `manifests/` directory
3. Commit changes
4. Wait up to 1 minute for Flux to detect
5. Wait up to 5 minutes for application (or force reconciliation)

#### Method 2: Git Clone and Push
```bash
# Clone repository
git clone https://github.com/yochanan2007/k3s-deployment.git
cd k3s-deployment

# Make changes
vim manifests/adguard/02-adguard-deployment.yaml

# Commit and push
git add manifests/
git commit -m "Update AdGuard configuration"
git push origin main
```

#### Method 3: Force Immediate Reconciliation
```bash
# Trigger GitRepository sync
kubectl annotate gitrepository k3s-deployment -n flux-system \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

# Trigger Kustomization apply
kubectl annotate kustomization k3s-deployment -n flux-system \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

## Monitoring and Verification

### Check Flux Status
```bash
# View all Flux resources
kubectl get gitrepositories,kustomizations -n flux-system

# Check GitRepository status
kubectl get gitrepository k3s-deployment -n flux-system

# Check Kustomization status
kubectl get kustomization k3s-deployment -n flux-system

# View detailed status
kubectl describe kustomization k3s-deployment -n flux-system
```

### Expected Output
```
NAME             AGE    READY   STATUS
k3s-deployment   10m    True    Applied revision: main@sha1:a106ca1...
```

### Check Flux Logs
```bash
# Source controller logs (Git polling)
kubectl logs -n flux-system deployment/source-controller --tail=50

# Kustomize controller logs (apply operations)
kubectl logs -n flux-system deployment/kustomize-controller --tail=50
```

### Verify Resource Sync
```bash
# Check if deployment has latest annotations
kubectl get deployment -n adguard adguard-home -o yaml | grep annotations -A 5

# View applied revision
kubectl get kustomization k3s-deployment -n flux-system \
  -o jsonpath='{.status.lastAppliedRevision}'
```

## Tested Scenarios

### Test 1: Annotation Update (2025-12-21)
**Change**: Added GitOps test annotations to AdGuard deployment
```yaml
metadata:
  annotations:
    gitops.test/timestamp: "2025-12-21T06:52:00Z"
    gitops.test/message: "Testing automatic GitOps sync with Flux CD"
```

**Result**:
- Commit: a106ca138b9377634278bdec939fa679397fdaf6
- Detected: Within 10 seconds (forced reconciliation)
- Applied: Successfully
- Verification: Annotations visible on deployment

## Troubleshooting

### Issue: Kustomization Not Reconciling
**Symptoms**: Status shows old revision
**Solution**:
```bash
# Force reconciliation
kubectl annotate kustomization k3s-deployment -n flux-system \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

# Check for errors
kubectl describe kustomization k3s-deployment -n flux-system
```

### Issue: GitRepository Not Updating
**Symptoms**: Git revision is stale
**Solution**:
```bash
# Force Git sync
kubectl annotate gitrepository k3s-deployment -n flux-system \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

# Check source controller logs
kubectl logs -n flux-system deployment/source-controller --tail=100
```

### Issue: Resource Conflicts
**Symptoms**: Kustomization shows "conflict" error
**Solution**:
1. Check for duplicate resources in different namespaces
2. Ensure proper namespace declarations in manifests
3. Review Kustomize build errors:
   ```bash
   kubectl describe kustomization k3s-deployment -n flux-system | grep -A 10 Error
   ```

### Issue: Deployment Not Ready
**Symptoms**: Resources exist but pods not running
**Solution**:
1. Flux applies manifests but doesn't wait for readiness (wait: false)
2. Check pod status separately:
   ```bash
   kubectl get pods -n adguard
   kubectl logs -n adguard <pod-name>
   ```

## Security Considerations

### Current Setup
- **Public Repository**: No secrets needed for Flux to access GitHub
- **Plaintext Secrets**: Secrets are base64-encoded but visible in Git
- **No Encryption**: Sensitive data is not encrypted at rest in Git

### Recommended Improvements

#### 1. Use Mozilla SOPS for Secret Encryption
```bash
# Install SOPS
curl -LO https://github.com/mozilla/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops
chmod +x /usr/local/bin/sops

# Encrypt secrets
sops --encrypt --age <age-key> \
  manifests/traefik/01-cloudflare-secret.yaml > \
  manifests/traefik/01-cloudflare-secret.enc.yaml

# Configure Flux to decrypt
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=age-key.txt
```

#### 2. Use Sealed Secrets
```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Seal a secret
kubeseal --format yaml < secret.yaml > sealed-secret.yaml

# Commit sealed secret to Git
git add sealed-secret.yaml
```

#### 3. Use External Secrets Operator
- Store secrets in external vault (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault)
- Reference secrets in manifests without storing sensitive data in Git

## Backup and Disaster Recovery

### Backup Strategy
1. **Git as Source of Truth**: All configurations stored in GitHub
2. **PVC Data**: Not managed by GitOps, needs separate backup
3. **Flux Configuration**: Stored in this documentation

### Recovery Procedure
```bash
# 1. Install Flux on new cluster
kubectl apply -f https://github.com/fluxcd/flux2/releases/download/v2.7.5/install.yaml

# 2. Wait for Flux to be ready
kubectl wait --for=condition=ready pod --all -n flux-system --timeout=120s

# 3. Create GitRepository
kubectl apply -f - <<EOF
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: k3s-deployment
  namespace: flux-system
spec:
  interval: 1m0s
  url: https://github.com/yochanan2007/k3s-deployment
  ref:
    branch: main
EOF

# 4. Create Kustomization
kubectl apply -f - <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: k3s-deployment
  namespace: flux-system
spec:
  interval: 5m0s
  path: ./manifests
  prune: true
  sourceRef:
    kind: GitRepository
    name: k3s-deployment
  timeout: 2m0s
  wait: false
EOF

# 5. Verify deployment
kubectl get kustomizations -n flux-system
```

## Best Practices

### 1. Commit Messages
Use clear, descriptive commit messages:
```
✅ Good: "Update AdGuard to v0.107.57 and increase memory limits"
❌ Bad: "update stuff"
```

### 2. Testing Changes
- Test manifests locally with `kubectl apply --dry-run=client`
- Use separate branches for major changes
- Consider staging environment for testing

### 3. Manifest Organization
- Keep related resources in same directory
- Use numeric prefixes for ordering (00-, 01-, 02-)
- Add comments explaining non-obvious configurations

### 4. Monitoring
- Regularly check Flux status: `kubectl get kustomizations -n flux-system`
- Set up alerts for reconciliation failures
- Monitor Flux controller logs

### 5. Version Pinning
- Pin image tags (avoid `latest`)
- Pin Flux version in installation
- Document version changes in commit messages

## Advanced Configuration

### Multi-Environment Setup
```yaml
# environments/production/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: production
  namespace: flux-system
spec:
  interval: 10m
  path: ./environments/production
  prune: true
  sourceRef:
    kind: GitRepository
    name: k3s-deployment
```

### Notifications
Configure Flux to send notifications to Slack/Discord:
```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta1
kind: Provider
metadata:
  name: slack
  namespace: flux-system
spec:
  type: slack
  channel: gitops-alerts
  address: https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

### Dependency Management
Ensure cert-manager runs before resources that need certificates:
```yaml
spec:
  dependsOn:
    - name: cert-manager
```

## Summary

The GitOps setup is fully functional with:

- ✅ Flux CD installed and running
- ✅ GitHub repository connected
- ✅ Automatic synchronization (1-minute polling)
- ✅ Manifest application (5-minute reconciliation)
- ✅ Tested and verified with live changes
- ✅ Documentation complete

**Key Benefits**:
- Infrastructure as Code (IaC)
- Audit trail via Git history
- Easy rollback (git revert)
- Declarative configuration
- Automatic drift correction

**Repository**: https://github.com/yochanan2007/k3s-deployment
