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

## Current Secrets in Manifests

⚠️ **WARNING**: The following files currently contain hardcoded sensitive data and should be updated:

### Files with Secrets:
1. **`manifests/traefik/01-cloudflare-secret.yaml`**
   - Contains: Cloudflare API token (base64 encoded)
   - **Action Required**: Replace with actual token or use sealed secrets

2. **`manifests/cert-manager/01-cloudflare-secret.yaml`**
   - Contains: Cloudflare API token placeholder
   - **Action Required**: Update with actual token

3. **`manifests/traefik/03-dashboard-auth.yaml`**
   - Contains: Traefik dashboard password hash
   - **Action Required**: Generate new password with `htpasswd -nb admin yourpassword`

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

The manifests in this repository currently contain:
- Base64-encoded secrets (NOT encryption, just encoding)
- Hardcoded domain names
- Specific IP addresses

**For fresh deployments**, update these files with your actual values before applying to cluster.

## Migration Path

To migrate to proper secret management:

1. **Immediate**: Use `.env` file locally (not committed to Git)
2. **Short-term**: Manually create secrets in cluster:
   ```bash
   kubectl create secret generic cloudflare-api-token \
     --from-literal=api-token=$CLOUDFLARE_API_TOKEN \
     -n kube-system
   ```
3. **Long-term**: Implement Sealed Secrets or External Secrets Operator

## Questions?

See [GitOps Setup Documentation](./GITOPS_SETUP.md) for more information about the deployment workflow.
