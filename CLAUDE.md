# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **k3s deployment repository** containing Kubernetes manifests for a production k3s cluster at **10.0.0.210** (accessible via MCP as user `johnd`). The manifests are verified copies of the actual running cluster and serve as both documentation and disaster recovery resources.

### Cluster Architecture

**Infrastructure Stack:**
- **K3s**: v1.33.6+k3s1 (single-node control plane)
- **MetalLB**: Bare-metal LoadBalancer (IP pool: 10.0.0.240-241)
- **Traefik**: Ingress controller with Let's Encrypt ACME (Cloudflare DNS-01)
- **Cert-Manager**: Certificate management with ClusterIssuer
- **Rancher**: Cluster management with Fleet GitOps

**Deployed Applications:**
- **AdGuard Home** (10.0.0.240): DNS filtering + ad blocking
- **Traefik Dashboard** (traefik.k3s.dahan.house): Ingress management UI

**Network Topology:**
- 10.0.200.1 → AdGuard Home (HTTP:80, DNS:53 TCP/UDP)
- 10.0.200.2 → Traefik (HTTP:80, HTTPS:443)
- dahan.house → Primary domain
- *.k3s.dahan.house → Wildcard cert for services

## Deployment Workflow

**CRITICAL: All cluster changes MUST follow this GitOps workflow:**

### GitOps Architecture
- **Fleet GitOps** (Rancher) watches the `main` branch of this repository
- Any changes merged to `main` are **automatically deployed** to the k3s cluster
- NEVER apply changes directly via `kubectl` - always use Git

### Standard Workflow

1. **Update Manifests Locally**
   - ALWAYS modify manifest files in `manifests/` directory first
   - NEVER apply changes directly to cluster via kubectl
   - Validate YAML syntax before committing

2. **Commit to claude-edits Branch**
   - Commit all changes to `claude-edits` branch
   - Use descriptive commit messages following conventional commits format:
     - `feat:` for new features
     - `fix:` for bug fixes
     - `docs:` for documentation changes
     - `refactor:` for refactoring
   - Include all related manifest files in the commit

3. **Push to GitHub**
   - Push `claude-edits` branch to GitHub
   - Changes will be reviewed before merging

4. **Merge to Main (Triggers Deployment)**
   - **DEFAULT**: Do NOT merge to main automatically
   - **ONLY** merge to main when user explicitly approves
   - User will review changes in `claude-edits` branch first
   - **Upon merge to main**: Fleet GitOps automatically deploys to cluster

**Git Commands:**
```bash
# Stage changes
git add manifests/

# Commit with conventional commit message
git commit -m "feat: Add RustDesk web client and ingress configuration"

# Push to claude-edits branch
git push origin claude-edits

# Merge to main (ONLY when user approves) - triggers Fleet deployment
git checkout main
git merge claude-edits
git push origin main
```

**Exception:** User may explicitly say "this time you can merge to main" - only then proceed with merge.

### Fleet GitOps Behavior
- **Watches**: `main` branch
- **Auto-sync**: Enabled (changes deployed automatically)
- **Reconciliation**: Fleet continuously monitors and applies changes
- **Rollback**: Git revert commits will automatically roll back deployments

### Verification After Deployment
After merging to main, Fleet will deploy changes within ~1-2 minutes. Verify with:
```bash
# Check Fleet bundle status
kubectl get bundles -A

# Check application status
kubectl get pods -n <namespace>

# Check specific resources
kubectl get all -n <namespace>
```

## Working with the Cluster

### Remote Access via MCP

The cluster is accessible through MCP (Model Context Protocol) configured in `.mcp.json`. Use these tools:
- `mcp__localproxy__k3s_execute-command`: Run kubectl/shell commands on the cluster
- `mcp__localproxy__k3s_download`: Download files from cluster to local
- `mcp__localproxy__k3s_upload`: Upload files from local to cluster

**Example:** Query cluster status
```bash
mcp__localproxy__k3s_execute-command: kubectl get pods -A
```

### Direct SSH Access

For direct terminal access to the servers, use these SSH commands with the private key:

**K3s Cluster:**
```bash
ssh -i "C:/Users/John/.ssh/docker_key" johnd@10.0.0.210
```
- User: `johnd`
- Access: kubectl commands for cluster management

**Docker2 Host:**
```bash
ssh -i "C:/Users/John/.ssh/docker_key" root@docker2
```
- User: `root`
- Access: Docker daemon and container management

**Note:** The hostname `docker2` must resolve to 10.0.0.120 in your hosts file or DNS.

### Verification Workflow

When updating manifests, always verify against the running cluster:
1. Read actual cluster state: `kubectl get <resource> -n <namespace> -o yaml`
2. Compare with local manifest files
3. Update local files to match cluster (NOT the other way around)
4. Document discrepancies in VERIFICATION_REPORT.md

**Critical:** This repository tracks the cluster state, not the desired state. Local manifests should mirror what's actually deployed.

## Manifest Structure

Files are organized by component with numbered prefixes for apply order:

```
manifests/
├── adguard/          # AdGuard Home DNS filtering
│   ├── 00-namespace.yaml
│   ├── 01-adguard-pvc.yaml           # Storage: 1Gi config + 10Gi data
│   ├── 02-adguard-deployment.yaml
│   ├── 03-adguard-service-lb.yaml    # MetalLB: 10.0.0.240
│   ├── 04-adguard-service-cluster.yaml
│   └── 05-adguard-ingress-traefik.yaml
├── traefik/          # Ingress controller configuration
│   ├── 01-cloudflare-secret.yaml     # API token for DNS-01 (kube-system)
│   ├── 02-traefik-config.yaml        # HelmChartConfig modifying k3s builtin
│   ├── 03-dashboard-auth.yaml        # BasicAuth + Middleware
│   └── 04-dashboard-ingressroute.yaml
└── cert-manager/     # Certificate management
    ├── 01-cloudflare-secret.yaml     # API token for DNS-01 (cert-manager)
    ├── 02-cluster-issuer.yaml        # letsencrypt-dns
    └── 03-wildcard-certificate.yaml  # *.k3s.dahan.house
```

### Traefik Configuration Notes

**HelmChartConfig Special Behavior:**
- `manifests/traefik/02-traefik-config.yaml` is a **HelmChartConfig** resource
- It modifies k3s's built-in Traefik deployment (not a standalone Helm release)
- After applying: `kubectl apply -f 02-traefik-config.yaml`, k3s automatically updates Traefik
- Includes `failurePolicy: reinstall` for safe redeployment

**Traefik vs Cert-Manager DNS-01:**
- Traefik uses built-in ACME resolver for its own dashboard certificate
- Cert-Manager uses ClusterIssuer for application certificates (wildcard)
- Both require Cloudflare API token but in different namespaces

### Label Consistency

**Critical:** Service selectors must exactly match deployment labels:
- AdGuard deployment labels: `app.kubernetes.io/name: adguard-home`
- AdGuard service selectors: Must use `adguard-home` (NOT `adguard`)
- Mismatch breaks LoadBalancer routing

## Secret Management

### Cloudflare API Token
- **Location 1**: `kube-system` namespace (for Traefik ACME)
- **Location 2**: `cert-manager` namespace (for ClusterIssuer)
- **Format**: Base64-encoded in `data` field (not `stringData`)
- **Note**: cert-manager secret currently contains placeholder `REDACTED_API_TOKEN`

### Traefik Dashboard Auth
- BasicAuth secret: `traefik-dashboard-auth` (kube-system)
- Generate new password: `htpasswd -nb admin yourpassword`
- Hash format: APR1 (indicated by `$apr1$` prefix)

### Email for Let's Encrypt
- Currently: `yochanan2007@gmail.com`
- Used in both Traefik config and cert-manager ClusterIssuer

## Common Operations

### Query Cluster Resources
```bash
kubectl get all -n adguard
kubectl get certificate -A
kubectl get helmchartconfig -n kube-system
kubectl get clusterissuer
```

### Verify Certificate Status
```bash
kubectl describe certificate k3s-dahan-house-wildcard -n kube-system
kubectl get secret k3s-dahan-house-tls -n kube-system -o yaml
```

### Check LoadBalancer IPs
```bash
kubectl get svc -A | grep LoadBalancer
```

### Apply Manifest Changes
```bash
# Apply in order (00-*, 01-*, etc.)
kubectl apply -f manifests/adguard/00-namespace.yaml
kubectl apply -f manifests/adguard/01-adguard-pvc.yaml
# ... etc

# Or apply entire directory
kubectl apply -f manifests/adguard/
```

## Documentation Files

- **DEPLOYMENT_SUMMARY.md**: Initial cluster discovery and configuration inventory
- **VERIFICATION_REPORT.md**: Verification audit log with fixes applied (2025-12-20)
- **manifests/README.md**: Detailed manifest documentation with secrets and network info

## Important Constraints

1. **No Direct Cluster Modifications**: This repository documents existing state. To change cluster, update on cluster first, then sync manifests.

2. **Secret Redaction**: cert-manager Cloudflare secret is intentionally redacted. When deploying fresh, update with actual token.

3. **PVC Naming**: AdGuard uses `adguard-config` and `adguard-data` (not `adguard-adguard-home-*` which are older unused PVCs).

4. **Rancher Not Included**: Rancher manifests are not in this repository. Only AdGuard, Traefik, and cert-manager configs are tracked.

5. **Domain Dependencies**: All domains (dahan.house, *.k3s.dahan.house) must resolve to correct MetalLB IPs for ingress to work.
