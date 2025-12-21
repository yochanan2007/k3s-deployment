# Quick Start Guide - GitOps Setup

## 1. Push to GitHub (Windows PowerShell)

```powershell
cd D:\claude\k3s-deployment
.\setup-git.ps1
```

Or manually:
```powershell
git init
git config user.email "yochanan2007@gmail.com"
git config user.name "yochanan2007"
git add .
git commit -m "Initial commit: K3s GitOps deployment"
git remote add origin https://github.com/yochanan2007/k3s.git
git push -u origin main
```

## 2. Configure Fleet (K3s Cluster)

```bash
# Apply Fleet GitRepo configuration
kubectl apply -f fleet-gitrepo.yaml

# Verify
kubectl get gitrepo -n fleet-local
```

## 3. Monitor Sync

```bash
# Watch GitRepo status (should show "Ready")
kubectl get gitrepo k3s-manifests -n fleet-local -w

# Check bundles
kubectl get bundles -n fleet-local

# Verify resources deployed
kubectl get all -n adguard
```

## 4. Test GitOps (Make a Change)

```powershell
# Edit manifests/adguard/00-namespace.yaml
# Add label: gitops-test: "true"

git add manifests/adguard/00-namespace.yaml
git commit -m "Test: Add label to AdGuard namespace"
git push origin main
```

```bash
# Watch namespace update (15-30 seconds)
kubectl get namespace adguard --show-labels -w
```

## Troubleshooting

### GitHub Push Fails
- Use Personal Access Token (Settings > Developer settings > PAT)
- Token needs `repo` permissions

### Fleet Not Syncing
```bash
# Check Fleet logs
kubectl logs -n cattle-fleet-system deployment/fleet-controller --tail=50

# Force resync
kubectl delete gitrepo k3s-manifests -n fleet-local
kubectl apply -f fleet-gitrepo.yaml
```

### Resources Not Applying
```bash
# Check bundle status
kubectl get bundles -n fleet-local -o yaml

# Check events
kubectl get events -n fleet-local --sort-by='.lastTimestamp'
```

## Daily Workflow

1. Edit manifests locally
2. `git add`, `git commit`, `git push`
3. Wait 15-30 seconds
4. Changes automatically applied to cluster!

## Key Files

- `fleet-gitrepo.yaml` - Fleet configuration to apply to cluster
- `fleet.yaml` - Fleet deployment configuration (in repo)
- `GITOPS_SETUP.md` - Detailed setup instructions
- `setup-git.ps1` - Automated git setup script

## Success Criteria

- [ ] GitHub repo has all manifests
- [ ] `kubectl get gitrepo -n fleet-local` shows STATUS=Ready
- [ ] `kubectl get bundles -n fleet-local` shows bundles Ready
- [ ] Test change syncs from GitHub to cluster
- [ ] Namespace labels update automatically

## Repository

https://github.com/yochanan2007/k3s
