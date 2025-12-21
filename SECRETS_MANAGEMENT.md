# Secrets Management

## Overview

Sensitive information (API tokens, passwords, domain names) should **NEVER** be committed to Git. This repository uses a `.env` file pattern for managing sensitive data locally.

## Setup

1. **Copy the example file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your actual values:**
   ```bash
   # Edit with your preferred editor
   nano .env
   # or
   code .env
   ```

3. **Fill in all required values:**
   - `CLOUDFLARE_API_TOKEN`: Your Cloudflare API token for DNS-01 challenges
   - `LETSENCRYPT_EMAIL`: Email for Let's Encrypt notifications
   - `DOMAIN_BASE`: Your primary domain
   - `K3S_SUBDOMAIN`: Your K3s subdomain
   - `TRAEFIK_DASHBOARD_AUTH`: BasicAuth credentials (generate with `htpasswd`)

4. **Copy `.env` file to k3s master node:**
   ```bash
   scp .env user@k3s-server:/path/to/k3s-deployment/
   ```

5. **Apply secrets to cluster:**
   ```bash
   # On the k3s master node
   cd /path/to/k3s-deployment
   chmod +x apply-secrets.sh
   ./apply-secrets.sh
   ```

## Secret Management Approach

✅ **Secrets are now managed outside of Git:**

The following secret files are **NOT tracked in Git**:
1. **`manifests/traefik/01-cloudflare-secret.yaml`** - Cloudflare API token for Traefik
2. **`manifests/cert-manager/01-cloudflare-secret.yaml`** - Cloudflare API token for cert-manager
3. **`manifests/adguard/05-cloudflare-secret.yaml`** - Cloudflare API token for AdGuard
4. **`manifests/traefik/03-dashboard-auth.yaml`** - Traefik dashboard authentication

These secrets are created directly in the cluster using the `apply-secrets.sh` script, which reads values from your local `.env` file.

## Recommended: Use Sealed Secrets

For production environments, consider using [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets):

```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Seal a secret
kubeseal --format yaml < secret.yaml > sealed-secret.yaml

# Commit the sealed secret (safe to commit!)
git add sealed-secret.yaml
git commit -m "Add sealed secret"
```

## Security Best Practices

1. **Never commit `.env` file** - It's already in `.gitignore`
2. **Rotate secrets regularly** - Especially API tokens and passwords
3. **Use different secrets per environment** - Dev, staging, production
4. **Audit secret access** - Review who has access to secrets
5. **Use sealed secrets or external secret management** for production

## External Secret Management Options

### For Production:
- **Sealed Secrets**: Kubernetes-native, encrypted secrets in Git
- **External Secrets Operator**: Sync from AWS Secrets Manager, Azure Key Vault, etc.
- **HashiCorp Vault**: Enterprise-grade secret management
- **SOPS (Mozilla)**: Encrypt secrets in Git with age/PGP

## Current Deployment State

✅ **Secrets are now managed securely:**
- Secret YAML files are NOT committed to Git (excluded via `.gitignore`)
- Secrets are created from `.env` file using `apply-secrets.sh` script
- `.env` file contains actual sensitive values and stays local only
- Domain names and configuration remain in manifest files (non-sensitive)

**For fresh deployments:**
1. Copy `.env.example` to `.env` and fill in your values
2. Copy `.env` to your k3s server
3. Run `./apply-secrets.sh` on the k3s server to create secrets

## Migration Path

Current status: ✅ **Step 1 Complete**

1. ✅ **Immediate**: Secrets moved to `.env` file (not committed to Git)
2. ✅ **Short-term**: Automated script (`apply-secrets.sh`) creates secrets in cluster
3. **Long-term**: Consider implementing Sealed Secrets or External Secrets Operator for GitOps compatibility

## Questions?

See [GitOps Setup Documentation](./GITOPS_SETUP.md) for more information about the deployment workflow.
