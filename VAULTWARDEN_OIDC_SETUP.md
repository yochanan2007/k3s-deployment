# Vaultwarden OIDC/SSO Integration with Authentik

This document describes the Vaultwarden OIDC/OAuth authentication setup integrated with Authentik.

## Overview

Vaultwarden has been configured to support Single Sign-On (SSO) using OpenID Connect (OIDC) with Authentik as the identity provider.

**Date Configured:** 2025-12-25
**Vaultwarden Version:** 1.34.3-8801b47d (testing image)
**Vaultwarden URL:** https://vault.k3s.dahan.house
**Authentik URL:** https://auth.k3s.dahan.house

## Authentik Configuration

### Application Details
- **Application Name:** Vaultwarden
- **Application Slug:** vaultwarden
- **Provider Type:** OAuth2/OpenID Connect
- **Provider Name:** Vaultwarden OIDC Provider

### OAuth2 Provider Settings
- **Client ID:** `UGSwelihDhR83yFx0pwrzGxsGZCxmpimY4B7ibkH`
- **Client Secret:** `am8ldLvu2wfjGTQs1OPv66GwgX4ggFbX7ngNBrIcp86jTt4fP4s2zYEdEjA8TbIW3CDnp9lzTVpjPHC0MzLY9f0uZdQZ5nuPhxmdUSkw9cxAX3LLg12BoGWYkJI919hi`
- **Client Type:** Confidential
- **Redirect URI:** `https://vault.k3s.dahan.house/identity/connect/oidc-signin`
- **Authorization Flow:** Authorize Application (e29c45b9-326c-4823-80f6-1342cf180a1c)
- **Invalidation Flow:** Logout (33329793-b65d-4b1f-8087-f9d57ee74b5d)
- **Access Token Validity:** 10 minutes
- **SSO Authority URL:** `https://auth.k3s.dahan.house/application/o/vaultwarden/`

### Scopes
The following OpenID scopes are configured:
- `openid` - Basic OpenID authentication
- `email` - Email address
- `profile` - User profile information
- `offline_access` - Refresh token support

## Vaultwarden Configuration

### Image Version
**IMPORTANT:** OIDC/SSO support is only available in the `:testing` tagged images. The stable release (v1.34.3) does NOT contain SSO features.

- **Image:** `vaultwarden/server:testing`
- **Image Pull Policy:** Always (to get latest testing updates)

### Environment Variables

The following SSO environment variables are configured in the deployment:

```yaml
SSO_ENABLED: "true"
SSO_AUTHORITY: "https://auth.k3s.dahan.house/application/o/vaultwarden/"
SSO_CLIENT_ID: "<from-secret>"
SSO_CLIENT_SECRET: "<from-secret>"
SSO_SCOPES: "openid email profile offline_access"
SSO_ALLOW_UNKNOWN_EMAIL_VERIFICATION: "false"
SSO_CLIENT_CACHE_EXPIRATION: "0"
SSO_ONLY: "false"  # Allows both SSO and traditional email/password login
SSO_SIGNUPS_MATCH_EMAIL: "true"  # Auto-links SSO login to existing accounts
```

### Kubernetes Resources

**Secret:** `manifests/vaultwarden/01b-oidc-secret.yaml`
- Stores SSO_CLIENT_ID and SSO_CLIENT_SECRET
- Referenced by deployment via secretKeyRef

**Deployment:** `manifests/vaultwarden/02-deployment.yaml`
- Updated to use `vaultwarden/server:testing` image
- Configured with SSO environment variables
- Maintains backward compatibility with traditional login

## User Experience

### Login Flow

1. **Traditional Login (Still Available)**
   - Users can log in with email + password as before
   - This is NOT disabled (SSO_ONLY=false)

2. **SSO Login (New)**
   - On the login page, users enter their email address
   - Click "Use single sign-on" button
   - Redirected to Authentik for authentication
   - After successful Authentik login, redirected back to Vaultwarden
   - If email matches existing account, automatically linked (SSO_SIGNUPS_MATCH_EMAIL=true)

### Account Linking

The configuration includes `SSO_SIGNUPS_MATCH_EMAIL: "true"` which means:
- If a user logs in via SSO and their Authentik email matches an existing Vaultwarden account email, the accounts are automatically linked
- No manual account creation or linking required
- First-time SSO users with no matching email will create a new account

## Deployment Process

### GitOps Workflow
Changes were committed to the main branch and pushed to GitHub, triggering automatic deployment via Fleet GitOps.

**Commit:** b7dd436
**Message:** "feat: Add Authentik OIDC/OAuth authentication to Vaultwarden"

### Manual Application (Fallback)
If Fleet is not configured, changes can be applied manually:

```bash
# Apply OIDC secret
kubectl apply -f manifests/vaultwarden/01b-oidc-secret.yaml

# Apply updated deployment
kubectl apply -f manifests/vaultwarden/02-deployment.yaml

# Verify deployment
kubectl get pods -n vaultwarden
kubectl describe pod -n vaultwarden -l app.kubernetes.io/name=vaultwarden
```

## Verification

### Pod Status
```bash
kubectl get pods -n vaultwarden
# Should show: vaultwarden-64cf5f7456-c4nst   1/1     Running
```

### Image Verification
```bash
kubectl describe pod -n vaultwarden -l app.kubernetes.io/name=vaultwarden | grep Image:
# Should show: vaultwarden/server:testing
```

### Environment Variables
```bash
kubectl exec -n vaultwarden deployment/vaultwarden -- env | grep SSO
# Should show all SSO_* variables configured correctly
```

### Application Logs
```bash
kubectl logs -n vaultwarden deployment/vaultwarden | head -20
# Should show: Version 1.34.3-8801b47d (testing image)
# Should show: Rocket has launched from http://0.0.0.0:80
```

## Testing SSO Login

To test the OIDC login flow:

1. Navigate to https://vault.k3s.dahan.house
2. On the login page, enter your email address that exists in Authentik
3. Click "Use single sign-on" button
4. You should be redirected to Authentik (https://auth.k3s.dahan.house)
5. Authenticate with your Authentik credentials
6. After successful authentication, you'll be redirected back to Vaultwarden
7. You should be logged into your Vaultwarden vault

### Expected Behavior
- ✅ Redirect to Authentik login page
- ✅ Successful authentication at Authentik
- ✅ Redirect back to Vaultwarden
- ✅ Automatic login to Vaultwarden vault
- ✅ If email matches existing account, automatically linked

### Troubleshooting

**If SSO login fails:**

1. Check Vaultwarden logs:
   ```bash
   kubectl logs -n vaultwarden deployment/vaultwarden --tail=100
   ```

2. Verify OIDC discovery endpoint is accessible:
   ```bash
   curl https://auth.k3s.dahan.house/application/o/vaultwarden/.well-known/openid-configuration
   ```

3. Check environment variables are set correctly:
   ```bash
   kubectl exec -n vaultwarden deployment/vaultwarden -- env | grep SSO
   ```

4. Verify Authentik application is configured correctly:
   - Log into Authentik admin interface
   - Navigate to Applications > Vaultwarden
   - Verify redirect URI matches: `https://vault.k3s.dahan.house/identity/connect/oidc-signin`

## Security Considerations

### Client Secret Storage
- Client secret is stored in Kubernetes secret `vaultwarden-oidc`
- Secret is referenced via `secretKeyRef` in deployment
- Secret is NOT exposed in deployment YAML or environment variable listings

### Dual Authentication
- SSO_ONLY is set to "false", allowing both SSO and traditional login
- This provides flexibility during transition period
- Can be set to "true" to enforce SSO-only authentication if desired

### Email Verification
- SSO_ALLOW_UNKNOWN_EMAIL_VERIFICATION is set to "false"
- Requires email verification status from Authentik
- Ensures only verified email addresses can authenticate

## References

- **Vaultwarden SSO Documentation:** https://github.com/dani-garcia/vaultwarden/wiki/Enabling-SSO-support-using-OpenId-Connect
- **Authentik Integration Guide:** https://integrations.goauthentik.io/security/vaultwarden/
- **Vaultwarden SSO PR:** https://github.com/dani-garcia/vaultwarden/pull/3899

## Maintenance Notes

### Future Updates
- The `:testing` image is used to get SSO support
- Monitor Vaultwarden releases for when SSO is merged into stable
- When SSO is available in stable release, update image tag to `:latest`

### Monitoring
- Check pod status regularly: `kubectl get pods -n vaultwarden`
- Monitor logs for SSO-related errors: `kubectl logs -n vaultwarden deployment/vaultwarden`
- Verify OIDC endpoint availability from within cluster

### Backup
- Ensure regular backups of the `vaultwarden-oidc` secret
- Document client credentials in secure password manager
- Keep copy of Authentik provider configuration

---

**Last Updated:** 2025-12-25
**Updated By:** Claude Code (Sonnet 4.5)
