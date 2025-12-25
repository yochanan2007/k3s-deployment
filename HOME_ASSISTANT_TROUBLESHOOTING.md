# Home Assistant Troubleshooting Report

**Date:** 2025-12-25
**Issue:** Home Assistant not responding on DNS name, LoadBalancer IP unclear
**Status:** RESOLVED

## Problem Summary

Home Assistant was deployed with:
- Pod running successfully
- LoadBalancer service with IP assigned (`10.0.200.8`)
- DNS correctly resolving `home.k3s.dahan.house` to Traefik (`10.0.200.2`)
- IngressRoute configured correctly

However, accessing Home Assistant via the DNS name resulted in `400: Bad Request` errors.

## Root Cause

Home Assistant was rejecting requests from the Traefik reverse proxy because it was not configured to trust forwarded headers. The error logs showed:

```
ERROR (MainThread) [homeassistant.components.http.forwarded]
A request from a reverse proxy was received from 10.42.0.233,
but your HTTP integration is not set-up for reverse proxies
```

## Investigation Steps

1. **Verified pod status:**
   ```bash
   kubectl get pods -n home-assistant
   # Result: home-assistant-547647bb5b-2bwhn   1/1     Running
   ```

2. **Checked services:**
   ```bash
   kubectl get svc -n home-assistant
   # Found LoadBalancer IP: 10.0.200.8
   ```

3. **Verified DNS resolution:**
   ```bash
   nslookup home.k3s.dahan.house
   # Result: 10.0.200.2 (Traefik - correct)
   ```

4. **Tested connectivity:**
   - Direct pod access: Working
   - LoadBalancer IP: Working (HTTP 405 for HEAD, HTML for GET)
   - DNS name via Traefik: 400 Bad Request

5. **Examined logs:**
   ```bash
   kubectl logs -n home-assistant deployment/home-assistant
   # Found reverse proxy configuration error
   ```

## Solution Applied

Added HTTP reverse proxy configuration to Home Assistant's `configuration.yaml` file in the PVC:

```yaml
# HTTP Configuration for reverse proxy
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 10.42.0.0/16   # Pod CIDR
    - 10.43.0.0/16   # Service CIDR
```

**Commands executed:**
```bash
# Add configuration to existing configuration.yaml in PVC
kubectl exec -n home-assistant deployment/home-assistant -- bash -c 'cat >> /config/configuration.yaml << "EOF"

# HTTP Configuration for reverse proxy
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 10.42.0.0/16   # Pod CIDR
    - 10.43.0.0/16   # Service CIDR
EOF
'

# Restart deployment to apply changes
kubectl rollout restart deployment/home-assistant -n home-assistant
```

## Verification

After applying the fix and restarting the pod:

1. **HTTPS via DNS name (through Traefik):**
   ```bash
   curl -k https://home.k3s.dahan.house
   # Result: Successfully serving Home Assistant HTML
   ```

2. **HTTP via LoadBalancer IP:**
   ```bash
   curl http://10.0.200.8:8123
   # Result: Successfully serving Home Assistant HTML
   ```

3. **Logs verification:**
   - No more reverse proxy errors
   - Only normal Home Assistant warnings (device connection issues)

## Current Configuration

### Network Access Points

- **DNS Name:** `home.k3s.dahan.house` (HTTPS via Traefik at 10.0.200.2)
- **LoadBalancer IP:** `10.0.200.8:8123` (HTTP direct access)
- **ClusterIP:** `10.43.125.242:8123` (internal cluster access)

### Services

1. **home-assistant** (ClusterIP)
   - Port: 8123
   - Used by IngressRoute

2. **home-assistant-lb** (LoadBalancer)
   - External IP: 10.0.200.8
   - Port: 8123
   - Direct access from network

### Certificate

- **Name:** `home-assistant-k3s-dahan-house`
- **Secret:** `home-assistant-tls`
- **Status:** Ready
- **Domain:** `home.k3s.dahan.house`

## Notes

### ConfigMap Status

The manifest file `D:\claude\k3s-deployment\manifests\home-assistant\01a-home-assistant-config.yaml` contains a ConfigMap with the correct reverse proxy configuration, but this ConfigMap:

1. Was never applied to the cluster
2. Is not mounted in the current deployment
3. Is not referenced in the deployment manifest

The current deployment uses a PersistentVolumeClaim (`home-assistant-config`) for `/config` storage, and the configuration was updated directly in the PVC.

### Future Considerations

For proper GitOps workflow, consider:

1. **Option A: Continue with PVC approach**
   - Configuration persists in PVC
   - Changes made via kubectl exec or web UI
   - ConfigMap file can be removed from manifests

2. **Option B: Migrate to ConfigMap approach**
   - Update deployment to mount ConfigMap
   - Ensures configuration is tracked in Git
   - Requires careful migration to preserve existing Home Assistant data

For now, the PVC approach is working correctly and Home Assistant is fully accessible.

## MetalLB IP Pool Update

Note: The CLAUDE.md file mentions MetalLB pool `10.0.0.240-241`, but the actual deployed configuration uses `10.0.200.1-10.0.200.250`. This is the correct production configuration.

All LoadBalancer services are using IPs from this range:
- 10.0.200.1 - AdGuard
- 10.0.200.2 - Traefik
- 10.0.200.3 - Authentik
- 10.0.200.8 - Home Assistant
- etc.

## Resolution

**Status:** RESOLVED
**Home Assistant is now fully accessible via:**
- `https://home.k3s.dahan.house` (recommended, uses HTTPS with certificate)
- `http://10.0.200.8:8123` (direct LoadBalancer access)
