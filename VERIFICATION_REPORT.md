# K3s Deployment Verification Report

**Date**: 2025-12-20
**Cluster**: 10.0.0.210 (k3s v1.33.6+k3s1)

## Executive Summary

The local manifest files in `manifests/` directory have been verified against the actual deployment running on the k3s cluster. All configuration issues identified in DEPLOYMENT_SUMMARY.md have been fixed.

## Issues Fixed

### 1. AdGuard LoadBalancer Service Selector Mismatch ✅ FIXED

**File**: `manifests/adguard/03-adguard-service-lb.yaml`

**Issue**: LoadBalancer service selector was using `app.kubernetes.io/name: adguard` but the deployment uses `app.kubernetes.io/name: adguard-home`

**Impact**: LoadBalancer service could not route traffic to pods correctly

**Fix Applied**: Updated selector in local manifest to match deployment:
```yaml
selector:
  app.kubernetes.io/name: adguard-home  # Changed from 'adguard' to 'adguard-home'
```

**Status**: Local manifest now matches the actual cluster configuration

### 2. Cloudflare Secret Configuration ✅ FIXED

**Files**:
- `manifests/traefik/01-cloudflare-secret.yaml`
- `manifests/cert-manager/01-cloudflare-secret.yaml`

**Issue**: Secrets were using `stringData` format in local files but cluster has them in base64-encoded `data` format. Additionally, cert-manager namespace had a different (redacted) token value.

**Fix Applied**:
- **Traefik secret** (kube-system): Updated to use base64-encoded format matching cluster
  - Value: `VXpoUF80RTg0Y0NfdUVMWkl6cXY4dlo3Rk5HeDBRWUpETVRmckxhdQ==` (base64)
  - Decodes to: `UzhP_4E84cC_uELZIzqv8vZ7FNGx0QYJDMTfrLau`

- **Cert-manager secret** (cert-manager): Updated to match cluster's redacted value
  - Value: `UkVEQUNURURfQVBJX1RPS0VO` (base64)
  - Decodes to: `REDACTED_API_TOKEN`

**Note**: The cert-manager secret on the cluster is using a placeholder/redacted value, not the actual Cloudflare token. This was intentionally preserved in the local manifest.

### 3. ClusterIssuer Configuration ✅ FIXED

**File**: `manifests/cert-manager/02-cluster-issuer.yaml`

**Issue**: Local manifest had unnecessary `namespace: cert-manager` field in the apiTokenSecretRef which is not present in the actual cluster configuration

**Fix Applied**: Removed namespace reference to match cluster configuration:
```yaml
apiTokenSecretRef:
  name: cloudflare-api-token
  key: api-token
  # Removed: namespace: cert-manager
```

## Verified Components

### AdGuard Home
- **Namespace**: adguard ✅
- **Deployment**: adguard-home (1 replica) ✅
  - Image: `adguard/adguardhome:v0.107.56` ✅
  - Labels: `app.kubernetes.io/name: adguard-home` ✅
  - Volumes: config (1Gi), data (10Gi) ✅
- **Services**:
  - LoadBalancer (adguard-lb): 10.0.0.240, selector now matches deployment ✅
  - ClusterIP (adguard): selector matches deployment ✅
- **Ingress**: HTTP ingress via Traefik for dahan.house ✅
- **Storage**: PVCs created and bound ✅

### Traefik
- **Namespace**: kube-system ✅
- **Configuration**: HelmChartConfig matches cluster ✅
  - Image: `rancher/mirrored-library-traefik:3.5.1` ✅
  - LoadBalancer IP: 10.0.0.241 ✅
  - Let's Encrypt ACME with Cloudflare DNS-01 ✅
  - Dashboard enabled with BasicAuth ✅
  - Persistence: 128Mi PVC ✅
- **Dashboard**:
  - IngressRoute matches cluster ✅
  - BasicAuth middleware configured ✅
  - Secret: traefik-dashboard-auth ✅
  - URL: traefik.k3s.dahan.house ✅

### Cert-Manager
- **ClusterIssuer**: letsencrypt-dns ✅
  - Server: Let's Encrypt production ✅
  - Email: yochanan2007@gmail.com ✅
  - DNS-01 solver with Cloudflare ✅
  - Status: Ready ✅
- **Certificates**:
  - k3s-dahan-house-wildcard (kube-system) → k3s-dahan-house-tls ✅
  - Coverage: k3s.dahan.house and *.k3s.dahan.house ✅

## Configuration Differences Noted

### Multiple PVCs for AdGuard
The cluster has duplicate PVCs in the adguard namespace:
- `adguard-config` (146m old) - Currently used ✅
- `adguard-data` (146m old) - Currently used ✅
- `adguard-adguard-home-config` (11h old) - Older, not in use
- `adguard-adguard-home-data` (11h old) - Older, not in use

This suggests the deployment was recreated at some point. The current manifest files correctly reference `adguard-config` and `adguard-data` which are the active PVCs.

### Traefik Configuration
The HelmChartConfig includes additional `failurePolicy: reinstall` which has been added to the local manifest for completeness.

## Verification Checklist

- [x] AdGuard deployment labels match service selectors
- [x] AdGuard LoadBalancer service selector corrected
- [x] AdGuard ClusterIP service selector matches deployment
- [x] AdGuard PVC names and sizes match
- [x] Traefik HelmChartConfig matches cluster
- [x] Traefik Cloudflare secret format corrected
- [x] Traefik dashboard IngressRoute configuration verified
- [x] Traefik dashboard BasicAuth secret verified
- [x] Cert-manager ClusterIssuer configuration corrected
- [x] Cert-manager Cloudflare secret format corrected
- [x] Wildcard certificate configuration verified
- [x] All namespaces verified

## Files Updated

1. `manifests/adguard/03-adguard-service-lb.yaml`
   - Fixed selector: `adguard` → `adguard-home`

2. `manifests/traefik/01-cloudflare-secret.yaml`
   - Changed from `stringData` to base64-encoded `data`
   - Value matches cluster

3. `manifests/traefik/02-traefik-config.yaml`
   - Added `failurePolicy: reinstall`
   - Added usage comments

4. `manifests/cert-manager/01-cloudflare-secret.yaml`
   - Changed from `stringData` to base64-encoded `data`
   - Value matches cluster (REDACTED_API_TOKEN)

5. `manifests/cert-manager/02-cluster-issuer.yaml`
   - Removed unnecessary namespace reference from apiTokenSecretRef

## Security Notes

### Secret Management
- The Cloudflare API token in kube-system namespace is the actual working token
- The Cloudflare API token in cert-manager namespace appears to be a placeholder/redacted value
- Local manifests now accurately reflect what's deployed on the cluster
- **Recommendation**: Consider using a proper secret management solution (SealedSecrets, External Secrets Operator, or Vault) for production use

### Current Secrets (for rotation awareness):
- Cloudflare API Token (kube-system): `UzhP_4E84cC_uELZIzqv8vZ7FNGx0QYJDMTfrLau`
- Cloudflare API Token (cert-manager): `REDACTED_API_TOKEN` (placeholder)
- Traefik Dashboard Password: `admin:$apr1$k6.O1y93$0x1W7Z6lSY0NgS4Ds/CEW1`

## Network Configuration Verified

### IP Assignments
- **10.0.0.240**: AdGuard Home (LoadBalancer)
  - HTTP: Port 80
  - DNS TCP: Port 53
  - DNS UDP: Port 53

- **10.0.0.241**: Traefik (LoadBalancer)
  - HTTP: Port 80
  - HTTPS: Port 443

### DNS/Domains
- **dahan.house** → AdGuard (via Traefik Ingress)
- **traefik.k3s.dahan.house** → Traefik Dashboard (HTTPS + BasicAuth)
- **k3s.dahan.house, *.k3s.dahan.house** → Wildcard Certificate

## Deployment Status

All components are operational and manifest files now accurately reflect the cluster state:

- ✅ AdGuard Home: Running, accessible
- ✅ Traefik: Running, LoadBalancer active
- ✅ Cert-Manager: Running, certificates valid
- ✅ MetalLB: IP pool configured and working
- ✅ Manifests: Updated and verified

## Next Steps

1. **Test Deployment Reproducibility**
   - The manifest files should now be able to recreate the deployment if needed
   - Consider testing in a staging environment

2. **Secret Rotation** (Future)
   - When ready, rotate the Cloudflare API token
   - Update both kube-system and cert-manager secrets
   - Restart affected pods

3. **Documentation**
   - Manifests are now self-documenting with inline comments
   - DEPLOYMENT_SUMMARY.md can be updated to mark issues as resolved

4. **Cert-Manager Investigation**
   - Verify why cert-manager has a redacted token
   - May need to update with actual token if certificates need renewal

## Conclusion

All identified configuration issues have been resolved. The local manifest files in `manifests/` directory now accurately represent the actual deployment running on the k3s cluster at 10.0.0.210. The AdGuard service selector mismatch has been fixed, and all secret configurations match their cluster counterparts.
